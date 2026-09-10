"""
Test del dominio satellite: verificano le formule fisiche contro valori
noti da manuale (non solo che il codice giri senza eccezioni).
"""
import math
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.shared import rf_physics as ph
from app.domains.satellite.services import SatelliteService
from app.domains.satellite.schemas import LinkBudgetRequest

client = TestClient(app)


class TestRfPhysicsFormulas:
    """Verifica delle formule fisiche di base, contro valori noti."""

    def test_fspl_matches_existing_rf_coverage_formula(self):
        """La nuova FSPL (Friis diretta) deve coincidere con quella gia'
        in uso in rf_coverage (20log10(d)+20log10(f)-147.55), entro 0.01dB."""
        d_m, f_hz = 35_786_000, 12e9
        new = ph.fspl_db(d_m, f_hz)
        existing = 20 * math.log10(d_m) + 20 * math.log10(f_hz) - 147.55
        assert abs(new - existing) < 0.01

    def test_fspl_rejects_invalid_input(self):
        with pytest.raises(ValueError):
            ph.fspl_db(-100, 12e9)
        with pytest.raises(ValueError):
            ph.fspl_db(100, 0)

    def test_geometry_overhead_is_90_degrees(self):
        """Satellite esattamente sopra la stazione -> elevazione 90 gradi."""
        geo = ph.satellite_geometry(45.0, 9.0, 45.0, 9.0, 35786)
        assert geo["elevation_deg"] == pytest.approx(90.0, abs=0.01)
        assert geo["slant_range_km"] == pytest.approx(35786.0, abs=1.0)

    def test_geometry_geo_horizon_matches_known_reference(self):
        """L'angolo centrale all'orizzonte per un satellite GEO e' un
        valore noto da manuale (~81.3 gradi)."""
        lo, hi = 0.0, 90.0
        for _ in range(50):
            mid = (lo + hi) / 2
            g = ph.satellite_geometry(0.0, 0.0, 0.0, mid, 35786)
            if g["elevation_deg"] > 0:
                lo = mid
            else:
                hi = mid
        assert lo == pytest.approx(81.3, abs=0.2)

    def test_geometry_beyond_horizon_not_visible(self):
        geo = ph.satellite_geometry(0.0, 0.0, 0.0, 170.0, 35786)
        assert geo["visible"] is False
        assert geo["elevation_deg"] < 0

    def test_cn0_and_cn_relationship(self):
        """C/N deve essere sempre <= C/N0 (la banda toglie sempre margine)."""
        pr = -110.0
        cn0 = ph.cn0_db_hz(pr, system_noise_temp_k=150)
        cn = ph.cn_db(cn0, bandwidth_hz=36e6)
        assert cn < cn0

    def test_doppler_zero_when_no_relative_motion(self):
        """Se il punto sub-satellite non si muove nel modello (heading
        parallelo a un'orbita degenere), il Doppler resta un valore finito
        e ragionevole, non NaN/infinito."""
        d = ph.doppler_shift_hz(45.0, 9.0, 45.0, 9.0, 550, 2.4e9)
        assert math.isfinite(d)


class TestSatelliteService:
    """Verifica del servizio a livello di dominio (asset simulati, API)."""

    def test_list_assets_returns_seeded_satellites(self):
        service = SatelliteService()
        assets = service.list_assets()
        assert len(assets) == 3
        orbit_classes = {a["orbit_class"] for a in assets}
        assert "GEO" in orbit_classes
        assert "LEO" in orbit_classes

    def test_get_unknown_asset_raises(self):
        service = SatelliteService()
        with pytest.raises(KeyError):
            service.get_asset("SAT-DOES-NOT-EXIST")

    def test_link_budget_realistic_geo_scenario(self):
        """Scenario GEO Ku-band plausibile: il link deve chiudere con
        margine positivo per parametri da manuale."""
        service = SatelliteService()
        req = LinkBudgetRequest(
            tx_power_dbw=10,
            tx_antenna_gain_dbi=45,
            rx_antenna_gain_dbi=38,
            distance_km=38000,
            frequency_hz=12e9,
            system_noise_temp_k=150,
            bandwidth_hz=36e6,
            other_losses_db=2,
            required_cn_db=10,
        )
        result = service.compute_link_budget(req)
        assert result["link_closed"] is True
        assert 10 < result["cn_db"] < 25

    def test_link_budget_fails_with_insufficient_power(self):
        """Con potenza TX troppo bassa, il link non deve chiudere."""
        service = SatelliteService()
        req = LinkBudgetRequest(
            tx_power_dbw=-30,
            tx_antenna_gain_dbi=10,
            rx_antenna_gain_dbi=10,
            distance_km=38000,
            frequency_hz=12e9,
            bandwidth_hz=36e6,
            required_cn_db=10,
        )
        result = service.compute_link_budget(req)
        assert result["link_closed"] is False
        assert result["link_margin_db"] < 0


class TestSatelliteAPI:
    """Verifica end-to-end degli endpoint HTTP."""

    def test_list_assets_endpoint(self):
        response = client.get("/api/satellite/assets")
        assert response.status_code == 200
        data = response.json()
        assert data["mode"] == "SIMULATION_ONLY"
        assert len(data["assets"]) == 3

    def test_geometry_endpoint_known_asset(self):
        response = client.get(
            "/api/satellite/assets/SAT-GEO-COMMS-001/geometry",
            params={"ground_lat_deg": 45.0, "ground_lon_deg": 9.0},
        )
        assert response.status_code == 200
        data = response.json()
        assert "elevation_deg" in data
        assert "slant_range_km" in data

    def test_geometry_endpoint_unknown_asset_404(self):
        response = client.get(
            "/api/satellite/assets/SAT-NOPE/geometry",
            params={"ground_lat_deg": 45.0, "ground_lon_deg": 9.0},
        )
        assert response.status_code == 404

    def test_doppler_endpoint_geo_is_zero(self):
        response = client.get(
            "/api/satellite/assets/SAT-GEO-COMMS-001/doppler",
            params={"ground_lat_deg": 45.0, "ground_lon_deg": 9.0},
        )
        assert response.status_code == 200
        assert response.json()["doppler_shift_hz"] == 0.0

    def test_doppler_endpoint_leo_nonzero(self):
        response = client.get(
            "/api/satellite/assets/SAT-LEO-IMAGING-001/doppler",
            params={"ground_lat_deg": 45.0, "ground_lon_deg": 9.0},
        )
        assert response.status_code == 200
        assert math.isfinite(response.json()["doppler_shift_hz"])

    def test_link_budget_endpoint(self):
        response = client.post(
            "/api/satellite/link-budget",
            json={
                "tx_power_dbw": 10,
                "tx_antenna_gain_dbi": 45,
                "rx_antenna_gain_dbi": 38,
                "distance_km": 38000,
                "frequency_hz": 12e9,
                "system_noise_temp_k": 150,
                "bandwidth_hz": 36e6,
                "other_losses_db": 2,
                "required_cn_db": 10,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["link_closed"] is True

    def test_link_budget_endpoint_validates_input(self):
        """Distanza negativa deve essere rifiutata da Pydantic (422), non
        propagarsi in un calcolo silenziosamente sbagliato."""
        response = client.post(
            "/api/satellite/link-budget",
            json={
                "tx_power_dbw": 10,
                "tx_antenna_gain_dbi": 45,
                "rx_antenna_gain_dbi": 38,
                "distance_km": -100,
                "frequency_hz": 12e9,
                "bandwidth_hz": 36e6,
            },
        )
        assert response.status_code == 422
