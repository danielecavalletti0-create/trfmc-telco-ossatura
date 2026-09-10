"""
Test del dominio ew_lab: verifica sia il gate di accesso (deve restare
bloccato di default) sia la correttezza fisica dei calcoli.
"""
import math
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.shared import rf_interference as ew
from app.domains.ew_lab.services import EWLabService
from app.domains.ew_lab.schemas import JammerScenarioRequest

client = TestClient(app)


class TestRfInterferenceFormulas:
    """Verifica delle formule EW contro valori noti/derivabili a mano."""

    def test_js_ratio_same_distance_equals_eirp_difference(self):
        """A parita' di distanza e frequenza, J/S = differenza di EIRP
        esatta (la FSPL si cancella)."""
        from app.shared import rf_physics as ph
        freq = 2.4e9
        dist_km = 10.0
        fspl = ph.fspl_db(dist_km * 1000, freq)
        pr_signal = 20.0 - fspl
        js = ew.js_ratio_db(50.0, dist_km, freq, pr_signal)
        assert js == pytest.approx(30.0, abs=0.001)

    def test_bandwidth_correction_known_ratios(self):
        assert ew.bandwidth_correction_db(1e6, 1e6) == pytest.approx(0.0, abs=0.01)
        assert ew.bandwidth_correction_db(2e6, 1e6) == pytest.approx(-3.01, abs=0.01)
        assert ew.bandwidth_correction_db(10e6, 1e6) == pytest.approx(-10.0, abs=0.01)
        # Jammer piu' stretto della vittima: nessuna perdita (min(1,x) tappa a 1)
        assert ew.bandwidth_correction_db(0.5e6, 1e6) == pytest.approx(0.0, abs=0.01)

    def test_burn_through_range_self_consistent(self):
        """Il J/S ricalcolato esattamente al burn-through range deve
        coincidere con la soglia richiesta (round-trip esatto)."""
        d = ew.burn_through_range_km(60.0, 3e9, -100.0, 6.0)
        js_at_d = ew.js_ratio_db(60.0, d, 3e9, -100.0)
        assert js_at_d == pytest.approx(6.0, abs=0.001)

    def test_burn_through_closer_means_stronger_jamming(self):
        d = ew.burn_through_range_km(60.0, 3e9, -100.0, 6.0)
        js_closer = ew.js_ratio_db(60.0, d * 0.5, 3e9, -100.0)
        assert js_closer > 6.0

    def test_fhss_hit_probability_known_fractions(self):
        assert ew.fhss_hit_probability(10e6, 10e6) == pytest.approx(1.0)
        assert ew.fhss_hit_probability(1e6, 10e6) == pytest.approx(0.1)
        assert ew.fhss_hit_probability(0, 10e6) == pytest.approx(0.0)

    def test_cinr_matches_cn_when_interference_negligible(self):
        cinr = ew.cinr_db(-100.0, -130.0, -170.0)
        assert cinr == pytest.approx(-100.0 - (-130.0), abs=0.01)

    def test_cinr_matches_cj_when_interference_dominant(self):
        cinr = ew.cinr_db(-100.0, -130.0, -90.0)
        assert cinr == pytest.approx(-100.0 - (-90.0), abs=0.1)

    def test_cinr_equal_powers_gives_3db_penalty(self):
        """Rumore e interferenza uguali in potenza lineare si sommano:
        -3.01dB esatti rispetto al solo C/N (raddoppio di potenza)."""
        cn_only = -100.0 - (-130.0)
        cinr = ew.cinr_db(-100.0, -130.0, -130.0)
        assert cinr == pytest.approx(cn_only - 3.0103, abs=0.001)

    def test_effective_js_spot_no_correction(self):
        assert ew.effective_js_db(20.0, 1e6, 1e6, "spot") == pytest.approx(20.0)

    def test_effective_js_barrage_matches_bandwidth_correction(self):
        val = ew.effective_js_db(20.0, 10e6, 1e6, "barrage")
        assert val == pytest.approx(10.0, abs=0.01)

    def test_effective_js_unknown_type_raises(self):
        with pytest.raises(ValueError):
            ew.effective_js_db(20.0, 1e6, 1e6, "not-a-real-type")


class TestEWLabService:
    def test_scenario_produces_consistent_link_disrupted_flag(self):
        service = EWLabService()
        req = JammerScenarioRequest(
            jammer_type="barrage",
            jammer_eirp_dbw=60.0,
            jammer_distance_km=5.0,
            jammer_freq_hz=2.4e9,
            jammer_bandwidth_hz=20e6,
            signal_received_power_dbw=-90.0,
            victim_bandwidth_hz=1e6,
            victim_noise_power_dbw=-120.0,
            js_threshold_db=6.0,
        )
        result = service.compute_scenario(req)
        assert result["link_disrupted"] == (result["js_effective_db"] >= 6.0)

    def test_scenario_with_fhss_includes_hit_probability(self):
        service = EWLabService()
        req = JammerScenarioRequest(
            jammer_type="spot",
            jammer_eirp_dbw=40.0,
            jammer_distance_km=20.0,
            jammer_freq_hz=2.4e9,
            jammer_bandwidth_hz=1e6,
            signal_received_power_dbw=-90.0,
            victim_bandwidth_hz=1e6,
            victim_noise_power_dbw=-120.0,
            hopping_bandwidth_hz=10e6,
        )
        result = service.compute_scenario(req)
        assert "fhss_hit_probability" in result
        assert result["fhss_hit_probability"] == pytest.approx(0.1, abs=0.001)

    def test_scenario_without_fhss_omits_hit_probability(self):
        service = EWLabService()
        req = JammerScenarioRequest(
            jammer_type="spot",
            jammer_eirp_dbw=40.0,
            jammer_distance_km=20.0,
            jammer_freq_hz=2.4e9,
            jammer_bandwidth_hz=1e6,
            signal_received_power_dbw=-90.0,
            victim_bandwidth_hz=1e6,
            victim_noise_power_dbw=-120.0,
        )
        result = service.compute_scenario(req)
        assert "fhss_hit_probability" not in result


class TestEWLabAccessGate:
    """Il gate di accesso e' la parte piu' importante da verificare: deve
    restare bloccato di default, in ogni condizione."""

    def test_status_endpoint_always_accessible_and_reports_gate_state(self):
        """Lo status (sola lettura, nessun calcolo di scenario) e' sempre
        accessibile e riporta onestamente lo stato del gate."""
        response = client.get("/api/ew-lab/status")
        assert response.status_code == 200
        data = response.json()
        assert data["mode"] == "SIMULATION_ONLY"
        assert "restricted_enabled" in data

    def test_scenario_endpoint_blocked_by_default(self):
        """Con restricted_enabled=False (default), il calcolo scenario
        deve essere rifiutato con 403, non eseguito silenziosamente."""
        payload = {
            "jammer_type": "spot",
            "jammer_eirp_dbw": 40.0,
            "jammer_distance_km": 20.0,
            "jammer_freq_hz": 2.4e9,
            "jammer_bandwidth_hz": 1e6,
            "signal_received_power_dbw": -90.0,
            "victim_bandwidth_hz": 1e6,
            "victim_noise_power_dbw": -120.0,
        }
        response = client.post("/api/ew-lab/scenario", json=payload)
        assert response.status_code == 403
        assert "restricted_enabled" in response.json()["detail"]

    def test_scenario_endpoint_works_when_explicitly_enabled(self, monkeypatch):
        """Se l'operatore abilita esplicitamente restricted_enabled, il
        calcolo funziona (e' un calcolatore, non un controllo hardware)."""
        from app.core.config import settings
        monkeypatch.setattr(settings, "restricted_enabled", True)

        payload = {
            "jammer_type": "spot",
            "jammer_eirp_dbw": 40.0,
            "jammer_distance_km": 20.0,
            "jammer_freq_hz": 2.4e9,
            "jammer_bandwidth_hz": 1e6,
            "signal_received_power_dbw": -90.0,
            "victim_bandwidth_hz": 1e6,
            "victim_noise_power_dbw": -120.0,
        }
        response = client.post("/api/ew-lab/scenario", json=payload)
        assert response.status_code == 200
        assert "js_raw_db" in response.json()
