"""
app/domains/satellite/services.py

Dominio satellite: link budget e geometria stazione-satellite per scenari
GEO e LEO. Modalita' SIMULATION_ONLY dichiarata - gli asset non sono
tracciati da un propagatore orbitale reale (no SGP4/TLE), ma da un modello
di moto semplificato e apertamente documentato (orbita circolare, velocita'
angolare corretta secondo la terza legge di Keplero). Le formule fisiche
sottostanti (FSPL, link budget, geometria, Doppler) sono verificate contro
valori noti da manuale in backend/tests/unit/test_satellite.py.
"""
import math
import time
from typing import Dict, Any, List

from app.shared import rf_physics as ph
from app.domains.satellite.schemas import LinkBudgetRequest


# ============================================================================
# Asset satellitari simulati (digital twin - nessuna telemetria reale)
# ============================================================================
_SIMULATION_EPOCH = time.time()

SIMULATED_ASSETS: List[Dict[str, Any]] = [
    {
        "asset_id": "SAT-GEO-COMMS-001",
        "name": "GEO Comms Relay 1",
        "orbit_class": "GEO",
        "altitude_km": 35786.0,
        "sub_satellite_lon_deg": 13.0,  # longitudine fissa (GEO)
        "sub_satellite_lat_deg": 0.0,
        "reference_frequency_hz": 12.0e9,  # Ku-band downlink tipico
        "mode": "SIMULATION_ONLY",
    },
    {
        "asset_id": "SAT-LEO-IMAGING-001",
        "name": "LEO Imaging Sat 1",
        "orbit_class": "LEO",
        "altitude_km": 550.0,
        "epoch_lat_deg": 0.0,
        "epoch_lon_deg": 0.0,
        "ground_track_heading_deg": 97.0,  # orbita quasi polare, tipica per imaging
        "reference_frequency_hz": 2.2e9,  # S-band telemetria tipica
        "mode": "SIMULATION_ONLY",
    },
    {
        "asset_id": "SAT-LEO-COMMS-002",
        "name": "LEO Comms Constellation Node 2",
        "orbit_class": "LEO",
        "altitude_km": 780.0,
        "epoch_lat_deg": 20.0,
        "epoch_lon_deg": -40.0,
        "ground_track_heading_deg": 53.0,  # orbita inclinata, tipica per broadband LEO
        "reference_frequency_hz": 11.0e9,  # Ku-band tipico broadband LEO
        "mode": "SIMULATION_ONLY",
    },
]


def _current_sub_satellite_position(asset: Dict[str, Any]) -> Dict[str, float]:
    """
    Posizione sub-satellite corrente. Per GEO e' fissa per definizione
    (velocita' angolare = velocita' di rotazione terrestre, sub-punto
    stazionario). Per LEO si propaga la posizione lungo una rotta a terra
    a rilevamento costante, alla velocita' angolare orbitale corretta
    (approssimazione dichiarata a orbita circolare - vedi doppler_shift_hz
    in rf_physics per la stessa assunzione usata coerentemente).
    """
    if asset["orbit_class"] == "GEO":
        return {
            "lat_deg": asset["sub_satellite_lat_deg"],
            "lon_deg": asset["sub_satellite_lon_deg"],
        }

    elapsed_s = time.time() - _SIMULATION_EPOCH
    omega = ph.orbital_angular_rate_rad_s(asset["altitude_km"])
    angular_travel_deg = math.degrees(omega * elapsed_s) % 360.0

    heading = math.radians(asset["ground_track_heading_deg"])
    lat = asset["epoch_lat_deg"] + angular_travel_deg * math.cos(heading)
    # riporta la latitudine in [-90, 90] con un semplice wrap a "rimbalzo"
    lat = ((lat + 90) % 360) - 90
    if lat > 90:
        lat = 180 - lat
    elif lat < -90:
        lat = -180 - lat

    lon = asset["epoch_lon_deg"] + angular_travel_deg * math.sin(heading) / max(
        1e-6, math.cos(math.radians(lat))
    )
    lon = ((lon + 180) % 360) - 180

    return {"lat_deg": lat, "lon_deg": lon}


class SatelliteService:
    model_name = "GEO_LEO_LINK_BUDGET_AND_GEOMETRY_V1_0"

    def list_assets(self) -> List[Dict[str, Any]]:
        out = []
        for asset in SIMULATED_ASSETS:
            pos = _current_sub_satellite_position(asset)
            out.append(
                {
                    "asset_id": asset["asset_id"],
                    "name": asset["name"],
                    "orbit_class": asset["orbit_class"],
                    "altitude_km": asset["altitude_km"],
                    "sub_satellite_position": pos,
                    "reference_frequency_hz": asset["reference_frequency_hz"],
                    "mode": asset["mode"],
                }
            )
        return out

    def get_asset(self, asset_id: str) -> Dict[str, Any]:
        for asset in SIMULATED_ASSETS:
            if asset["asset_id"] == asset_id:
                return asset
        raise KeyError(f"asset satellite non trovato: {asset_id}")

    def compute_geometry(self, asset_id: str, ground_lat_deg: float, ground_lon_deg: float) -> Dict[str, Any]:
        asset = self.get_asset(asset_id)
        pos = _current_sub_satellite_position(asset)
        geo = ph.satellite_geometry(
            ground_lat_deg, ground_lon_deg,
            pos["lat_deg"], pos["lon_deg"],
            asset["altitude_km"],
        )
        return {
            "asset_id": asset_id,
            "orbit_class": asset["orbit_class"],
            "sub_satellite_position": pos,
            **geo,
        }

    def compute_doppler(self, asset_id: str, ground_lat_deg: float, ground_lon_deg: float) -> Dict[str, Any]:
        asset = self.get_asset(asset_id)
        pos = _current_sub_satellite_position(asset)

        if asset["orbit_class"] == "GEO":
            # GEO: sub-punto stazionario per definizione, Doppler residuo
            # trascurabile (solo micro-variazioni orbitali reali, fuori
            # scopo di questo modello semplificato).
            shift_hz = 0.0
        else:
            shift_hz = ph.doppler_shift_hz(
                ground_lat_deg, ground_lon_deg,
                pos["lat_deg"], pos["lon_deg"],
                asset["altitude_km"],
                asset["reference_frequency_hz"],
                ground_track_heading_deg=asset["ground_track_heading_deg"],
            )

        return {
            "asset_id": asset_id,
            "carrier_frequency_hz": asset["reference_frequency_hz"],
            "doppler_shift_hz": shift_hz,
        }

    def compute_link_budget(self, req: LinkBudgetRequest) -> Dict[str, Any]:
        eirp = ph.eirp_dbw(req.tx_power_dbw, req.tx_antenna_gain_dbi)
        fspl = ph.fspl_db(req.distance_km * 1000.0, req.frequency_hz)
        pr = ph.received_power_dbw(eirp, fspl, req.rx_antenna_gain_dbi, req.other_losses_db)
        cn0 = ph.cn0_db_hz(pr, req.system_noise_temp_k)
        cn = ph.cn_db(cn0, req.bandwidth_hz)
        margin = cn - req.required_cn_db

        return {
            "eirp_dbw": round(eirp, 2),
            "fspl_db": round(fspl, 2),
            "received_power_dbw": round(pr, 2),
            "cn0_db_hz": round(cn0, 2),
            "cn_db": round(cn, 2),
            "required_cn_db": req.required_cn_db,
            "link_margin_db": round(margin, 2),
            "link_closed": margin >= 0,
        }
