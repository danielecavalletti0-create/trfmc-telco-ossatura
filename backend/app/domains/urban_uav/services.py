"""
app/domains/urban_uav/services.py

Corridoio urbano UAV: lungo una traiettoria tra edifici, calcola per ogni
punto il link budget reale del collegamento C2 stazione-drone, includendo
la diffrazione da ostacolo (edificio) quando la linea di vista diretta e'
bloccata (ITU-R P.526, vedi app/shared/rf_physics.py), e opzionalmente
l'effetto di un jammer (ECM) e la resistenza offerta da frequency hopping
(EECM, vedi app/shared/rf_interference.py).

SIMULATION_ONLY. Nessun controllo hardware, nessuna emissione RF: e' un
calcolatore geometrico + fisico che produce numeri verificabili lungo un
percorso, per costruire una visualizzazione didattica seria invece che
scenografica.
"""
import math
from typing import Dict, Any, List, Optional

from app.shared import rf_physics as ph
from app.shared import rf_interference as ew
from app.domains.urban_uav.schemas import CorridorScenarioRequest, Building, UavWaypoint


def _horizontal_distance(x1: float, y1: float, x2: float, y2: float) -> float:
    return math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)


def _building_los_crossing(
    gs_x: float, gs_y: float, uav_x: float, uav_y: float, b: Building
) -> Optional[float]:
    """
    Ritorna la frazione t in [0,1] del punto medio in cui il segmento
    (proiezione orizzontale della linea stazione-drone) attraversa
    l'impronta rettangolare dell'edificio, oppure None se non lo
    attraversa. Campionamento del segmento (semplificazione dichiarata,
    non intersezione analitica esatta - sufficiente per un edificio ad
    asse allineato con passo fine).
    """
    half_w = b.width_m / 2.0
    half_d = b.depth_m / 2.0
    hits: List[float] = []
    steps = 200
    for i in range(steps + 1):
        t = i / steps
        x = gs_x + (uav_x - gs_x) * t
        y = gs_y + (uav_y - gs_y) * t
        if (b.x_m - half_w <= x <= b.x_m + half_w) and (b.y_m - half_d <= y <= b.y_m + half_d):
            hits.append(t)
    if not hits:
        return None
    return (hits[0] + hits[-1]) / 2.0


class UrbanUavService:
    model_name = "URBAN_UAV_CORRIDOR_KNIFE_EDGE_V1_0"

    def evaluate_waypoint(
        self, req: CorridorScenarioRequest, waypoint: UavWaypoint
    ) -> Dict[str, Any]:
        gs = req.ground_station
        total_horizontal = _horizontal_distance(gs.x_m, gs.y_m, waypoint.x_m, waypoint.y_m)
        total_distance_3d = math.sqrt(
            total_horizontal ** 2 + (waypoint.z_m - gs.z_m) ** 2
        )

        # Trova l'edificio che causa la maggiore ostruzione lungo il percorso
        # (approssimazione a singolo knife-edge dominante, non modello
        # multi-edge Deygout - scelta dichiarata per restare verificabile).
        worst_loss_db = 0.0
        worst_building_id = None
        worst_v = None

        for b in req.buildings:
            t = _building_los_crossing(gs.x_m, gs.y_m, waypoint.x_m, waypoint.y_m, b)
            if t is None:
                continue

            d1 = total_horizontal * t
            d2 = total_horizontal * (1.0 - t)
            if d1 <= 0 or d2 <= 0:
                continue

            los_height_at_crossing = gs.z_m + (waypoint.z_m - gs.z_m) * t
            obstacle_height_above_los = b.height_m - los_height_at_crossing

            loss_db = ph.knife_edge_diffraction_loss_db(
                obstacle_height_above_los, d1, d2, req.frequency_hz
            )
            # Se il muro dell'edificio blocca comunque otticamente (drone
            # sotto il cornicione, non solo diffrazione al bordo), aggiunge
            # la perdita di attraversamento materiale dichiarata.
            if obstacle_height_above_los > 0:
                loss_db += b.material_loss_db * min(1.0, obstacle_height_above_los / max(b.height_m, 1.0))

            if loss_db > worst_loss_db:
                worst_loss_db = loss_db
                worst_building_id = b.building_id
                worst_v = obstacle_height_above_los

        fspl = ph.fspl_db(max(total_distance_3d, 1.0), req.frequency_hz)
        eirp = ph.eirp_dbw(gs.tx_power_dbw, gs.antenna_gain_dbi)
        pr = ph.received_power_dbw(
            eirp, fspl + worst_loss_db, req.uav_antenna_gain_dbi, other_losses_db=0.0
        )
        noise = ph.noise_power_dbw(req.rx_noise_temp_k, req.bandwidth_hz)
        cn_db = pr - noise

        result: Dict[str, Any] = {
            "position": {"x_m": waypoint.x_m, "y_m": waypoint.y_m, "z_m": waypoint.z_m},
            "distance_3d_m": round(total_distance_3d, 1),
            "line_of_sight_blocked": worst_building_id is not None and worst_v is not None and worst_v > 0,
            "blocking_building_id": worst_building_id,
            "diffraction_loss_db": round(worst_loss_db, 2),
            "fspl_db": round(fspl, 2),
            "eirp_dbw": round(eirp, 2),
            "received_power_dbw": round(pr, 2),
            "noise_power_dbw": round(noise, 2),
            "cn_db": round(cn_db, 2),
            "link_ok": cn_db >= req.required_cn_db,
        }

        if req.jammer and req.jammer.enabled:
            jam_dist_km = _horizontal_distance(
                req.jammer.x_m, req.jammer.y_m, waypoint.x_m, waypoint.y_m
            ) / 1000.0
            js_raw = ew.js_ratio_db(req.jammer.eirp_dbw, max(jam_dist_km, 1e-3), req.frequency_hz, pr)
            js_eff = ew.effective_js_db(
                js_raw, req.jammer.bandwidth_hz, req.bandwidth_hz, req.jammer.jammer_type
            )
            # J/S = potenza_jammer - potenza_segnale (vedi rf_interference.
            # js_ratio_db). Quindi potenza_jammer = pr + js_eff, non pr - js_eff
            # (quello darebbe un jammer piu' debole quanto piu' e' efficace).
            interference_dbw = pr + js_eff
            cinr = ew.cinr_db(pr, noise, interference_dbw)

            result["jammer"] = {
                "js_effective_db": round(js_eff, 2),
                "interference_power_dbw": round(interference_dbw, 2),
                "cinr_db": round(cinr, 2),
                "link_ok_under_jamming": cinr >= req.required_cn_db,
            }

            if req.hopping_bandwidth_hz:
                p_hit = ew.fhss_hit_probability(req.jammer.bandwidth_hz, req.hopping_bandwidth_hz)
                result["jammer"]["fhss_hit_probability"] = round(p_hit, 4)
                # EECM: il CINR e' una grandezza logaritmica, non si media
                # correttamente in dB (E[dB] != dB(E[lineare])). Si media
                # invece la potenza di interferenza in scala lineare - sui
                # salti mancati l'interferenza e' assente (0), sui salti
                # colpiti e' quella calcolata sopra - poi si ricava un
                # unico CINR "atteso" riusando la stessa funzione gia'
                # verificata (cinr_db), coerente con come rumore e
                # interferenza si combinano fisicamente.
                interference_linear_w = 10.0 ** (interference_dbw / 10.0)
                avg_interference_linear_w = p_hit * interference_linear_w
                avg_interference_dbw = (
                    10.0 * math.log10(avg_interference_linear_w)
                    if avg_interference_linear_w > 0
                    else -300.0
                )
                expected_cinr = ew.cinr_db(pr, noise, avg_interference_dbw)
                result["jammer"]["fhss_expected_cinr_db"] = round(expected_cinr, 2)

        return result

    def evaluate_corridor(self, req: CorridorScenarioRequest) -> Dict[str, Any]:
        points = [self.evaluate_waypoint(req, wp) for wp in req.path]
        return {
            "model": self.model_name,
            "mode": "SIMULATION_ONLY",
            "waypoint_count": len(points),
            "points": points,
        }
