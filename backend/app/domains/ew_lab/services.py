"""
app/domains/ew_lab/services.py

Motore di calcolo per scenari didattici di electronic warfare / anti-jam
(SIMULATION_ONLY, gate di accesso condiviso con app/domains/restricted -
vedi api.py). Ogni numero prodotto qui e' calcolato con le formule
standard di app/shared/rf_interference.py, verificate numericamente in
backend/tests/unit/test_ew_lab.py contro valori derivabili a mano.

Questo modulo NON controlla hardware, non genera forme d'onda, non ha
alcun percorso verso un trasmettitore: prende parametri di scenario e
restituisce numeri (J/S, CINR, burn-through range, probabilita' di hit
per frequency hopping) utili a costruire una visualizzazione didattica di
"cosa succede e perche'" quando un link RF viene disturbato.
"""
from typing import Dict, Any
import math

from app.shared import rf_interference as ew
from app.domains.ew_lab.schemas import JammerScenarioRequest


class EWLabService:
    model_name = "EW_TRAINING_SCENARIO_CALCULATOR_V1_0"

    def compute_scenario(self, req: JammerScenarioRequest) -> Dict[str, Any]:
        js_raw = ew.js_ratio_db(
            req.jammer_eirp_dbw,
            req.jammer_distance_km,
            req.jammer_freq_hz,
            req.signal_received_power_dbw,
        )

        js_effective = ew.effective_js_db(
            js_raw,
            req.jammer_bandwidth_hz,
            req.victim_bandwidth_hz,
            req.jammer_type,
        )

        # Potenza di interferenza equivalente al ricevitore, per il CINR:
        # J_effective_dBW = Pr_segnale - J/S_effettivo (per definizione di J/S)
        # J/S = potenza_jammer - potenza_segnale (per definizione, vedi
        # rf_interference.js_ratio_db). Quindi potenza_jammer = segnale + J/S
        # (non segnale - J/S: quello darebbe un jammer piu' debole quanto
        # piu' e' efficace, l'opposto della realta').
        interference_dbw = req.signal_received_power_dbw + js_effective

        cinr = ew.cinr_db(
            req.signal_received_power_dbw,
            req.victim_noise_power_dbw,
            interference_dbw,
        )

        burn_through_km = ew.burn_through_range_km(
            req.jammer_eirp_dbw,
            req.jammer_freq_hz,
            req.signal_received_power_dbw,
            req.js_threshold_db,
        )

        result = {
            "jammer_type": req.jammer_type,
            "js_raw_db": round(js_raw, 2),
            "js_effective_db": round(js_effective, 2),
            "interference_power_dbw": round(interference_dbw, 2),
            "cinr_db": round(cinr, 2),
            "cn_db_no_jamming": round(req.signal_received_power_dbw - req.victim_noise_power_dbw, 2),
            "burn_through_range_km": round(burn_through_km, 3),
            "link_disrupted": js_effective >= req.js_threshold_db,
            "js_threshold_db": req.js_threshold_db,
        }

        if req.hopping_bandwidth_hz:
            p_hit = ew.fhss_hit_probability(req.jammer_bandwidth_hz, req.hopping_bandwidth_hz)
            result["fhss_hit_probability"] = round(p_hit, 4)
            result["fhss_hop_bandwidth_advantage_db"] = round(
                -10.0 * math.log10(max(p_hit, 1e-9)), 2
            )

        return result
