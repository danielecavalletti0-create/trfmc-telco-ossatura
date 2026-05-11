import math
from uuid import uuid4
from typing import Dict, Any, Optional

from app.domains.rf_field.schemas import RfFieldRequest
from app.persistence.repositories import (
    RfFieldRunRepository,
    CloudEventRepository,
    RfObstacleRepository,
)
from app.shared.cloudevents import CloudEvent, ce_type
from app.core.event_bus import event_bus

C0 = 299_792_458.0
MU0 = 4.0 * math.pi * 1e-7
EPS0 = 1.0 / (MU0 * C0 * C0)
ETA0 = math.sqrt(MU0 / EPS0)


class RfFieldService:
    model_name = "MAXWELL_PLANE_WAVE_ANTENNA_FRESNEL_V0_9"

    def __init__(self):
        self.runs = RfFieldRunRepository()
        self.events = CloudEventRepository()
        self.obstacles = RfObstacleRepository()

    def wavelength_m(self, frequency_hz: float) -> float:
        return C0 / frequency_hz

    def angular_frequency_rad_s(self, frequency_hz: float) -> float:
        return 2.0 * math.pi * frequency_hz

    def phase_constant_rad_m(self, frequency_hz: float) -> float:
        return 2.0 * math.pi / self.wavelength_m(frequency_hz)

    def near_far_regions(self, frequency_hz: float, antenna_dimension_m: float) -> Dict[str, float]:
        lam = self.wavelength_m(frequency_hz)
        reactive_near = 0.62 * math.sqrt((antenna_dimension_m ** 3) / lam)
        fraunhofer = 2.0 * (antenna_dimension_m ** 2) / lam
        return {
            "wavelength_m": lam,
            "reactive_near_field_limit_m": reactive_near,
            "fresnel_region_start_m": reactive_near,
            "fraunhofer_far_field_start_m": fraunhofer,
        }

    def normalize_angle(self, angle_deg: float) -> float:
        while angle_deg > 180:
            angle_deg -= 360
        while angle_deg < -180:
            angle_deg += 360
        return angle_deg

    def antenna_gain_dbi(
        self,
        req: RfFieldRequest,
        relative_azimuth_deg: float,
        relative_elevation_deg: float,
    ) -> float:
        ah = min(12.0 * (relative_azimuth_deg / req.horizontal_hpbw_deg) ** 2, req.front_back_ratio_db)
        tilt = req.mechanical_tilt_deg + req.electrical_tilt_deg
        av = min(12.0 * ((relative_elevation_deg + tilt) / req.vertical_hpbw_deg) ** 2, req.front_back_ratio_db)
        attenuation = min(ah + av, req.front_back_ratio_db)
        return req.max_gain_dbi - attenuation

    def antenna_pattern(self, req: RfFieldRequest):
        azimuth = []
        for a in range(-180, 181, 15):
            azimuth.append({
                "angle_deg": a,
                "gain_dbi": round(self.antenna_gain_dbi(req, a, 0.0), 3),
            })

        elevation = []
        for e in range(-45, 46, 5):
            elevation.append({
                "angle_deg": e,
                "gain_dbi": round(self.antenna_gain_dbi(req, 0.0, e), 3),
            })

        return {
            "model": "3GPP-inspired simplified sector pattern",
            "max_gain_dbi": req.max_gain_dbi,
            "horizontal_hpbw_deg": req.horizontal_hpbw_deg,
            "vertical_hpbw_deg": req.vertical_hpbw_deg,
            "mechanical_tilt_deg": req.mechanical_tilt_deg,
            "electrical_tilt_deg": req.electrical_tilt_deg,
            "azimuth": azimuth,
            "elevation": elevation,
        }

    def first_fresnel_radius_m(self, frequency_hz: float, d1_m: float, d2_m: float) -> float:
        lam = self.wavelength_m(frequency_hz)
        if d1_m + d2_m <= 0:
            return 0.0
        return math.sqrt((lam * d1_m * d2_m) / (d1_m + d2_m))

    def tx_position(self, req: RfFieldRequest):
        return {"x_m": 0.0, "y_m": 0.0, "z_m": req.tx_height_m}

    def rx_position(self, req: RfFieldRequest):
        if req.target_asset_id == "UAV-ALPHA-001":
            return {"x_m": 420.0, "y_m": 160.0, "z_m": 120.0}
        return {"x_m": req.distance_m, "y_m": 80.0, "z_m": req.rx_height_m}

    def line_height_at_distance(self, tx, rx, d1_m: float, total_d_m: float) -> float:
        if total_d_m <= 0:
            return tx["z_m"]
        t = d1_m / total_d_m
        return tx["z_m"] + (rx["z_m"] - tx["z_m"]) * t

    def fresnel_clearance(self, req: RfFieldRequest, tx, rx):
        obstacles = self.obstacles.list()
        total_d = math.sqrt((rx["x_m"] - tx["x_m"]) ** 2 + (rx["y_m"] - tx["y_m"]) ** 2)

        checks = []
        for obs in obstacles:
            d1 = math.sqrt((obs["x_m"] - tx["x_m"]) ** 2 + (obs["y_m"] - tx["y_m"]) ** 2)
            d2 = max(total_d - d1, 0.1)
            radius = self.first_fresnel_radius_m(req.frequency_hz, d1, d2)
            ray_h = self.line_height_at_distance(tx, rx, d1, total_d)
            clearance_m = ray_h - obs["height_m"]
            clearance_ratio = clearance_m / radius if radius > 0 else 0.0

            checks.append({
                "obstacle_id": obs["obstacle_id"],
                "obstacle_type": obs["obstacle_type"],
                "material": obs["material"],
                "d1_m": round(d1, 3),
                "d2_m": round(d2, 3),
                "fresnel_radius_m": round(radius, 3),
                "ray_height_m": round(ray_h, 3),
                "obstacle_height_m": obs["height_m"],
                "clearance_m": round(clearance_m, 3),
                "clearance_ratio": round(clearance_ratio, 3),
                "fresnel_state": "CLEAR" if clearance_ratio >= 0.6 else "PARTIAL_BLOCK" if clearance_ratio > 0 else "BLOCKED",
            })

        worst = min(checks, key=lambda x: x["clearance_ratio"]) if checks else None
        return {
            "total_2d_distance_m": round(total_d, 3),
            "checks": checks,
            "worst_case": worst,
        }

    def eirp_w(self, req: RfFieldRequest, gain_dbi: float) -> float:
        eirp_dbm = req.tx_power_dbm + gain_dbi
        return 10 ** ((eirp_dbm - 30.0) / 10.0)

    def field_at_receiver(self, req: RfFieldRequest, tx, rx, gain_dbi: float):
        r = math.sqrt((rx["x_m"] - tx["x_m"]) ** 2 + (rx["y_m"] - tx["y_m"]) ** 2 + (rx["z_m"] - tx["z_m"]) ** 2)
        eirp = self.eirp_w(req, gain_dbi)
        power_density = eirp / (4.0 * math.pi * max(r, 1.0) ** 2)
        electric_field = math.sqrt(power_density * ETA0)
        magnetic_field = electric_field / ETA0
        return {
            "distance_m": round(r, 3),
            "eirp_w": round(eirp, 6),
            "power_density_w_m2": power_density,
            "electric_field_v_m": electric_field,
            "magnetic_field_a_m": magnetic_field,
            "poynting_w_m2": power_density,
            "field_region": "FAR_FIELD" if r >= self.near_far_regions(req.frequency_hz, req.antenna_max_dimension_m)["fraunhofer_far_field_start_m"] else "NEAR_OR_FRESNEL",
        }

    def run_field(self, req: RfFieldRequest):
        tx = self.tx_position(req)
        rx = self.rx_position(req)

        horizontal_bearing_deg = math.degrees(math.atan2(rx["y_m"] - tx["y_m"], rx["x_m"] - tx["x_m"]))
        relative_az = self.normalize_angle(horizontal_bearing_deg - req.azimuth_deg)

        distance_horizontal = math.sqrt((rx["x_m"] - tx["x_m"]) ** 2 + (rx["y_m"] - tx["y_m"]) ** 2)
        elevation_deg = math.degrees(math.atan2(rx["z_m"] - tx["z_m"], max(distance_horizontal, 1.0)))

        gain = self.antenna_gain_dbi(req, relative_az, elevation_deg)

        result = {
            "run_id": f"RF-FIELD-{uuid4().hex[:12].upper()}",
            "mission_id": req.mission_id,
            "model_name": self.model_name,
            "cell_asset_id": req.cell_asset_id,
            "target_asset_id": req.target_asset_id,
            "frequency_hz": req.frequency_hz,
            "constants": {
                "c0_m_s": C0,
                "mu0_h_m": MU0,
                "eps0_f_m": EPS0,
                "eta0_ohm": ETA0,
            },
            "wave": {
                "wavelength_m": self.wavelength_m(req.frequency_hz),
                "omega_rad_s": self.angular_frequency_rad_s(req.frequency_hz),
                "beta_rad_m": self.phase_constant_rad_m(req.frequency_hz),
            },
            "regions": self.near_far_regions(req.frequency_hz, req.antenna_max_dimension_m),
            "antenna": {
                "azimuth_deg": req.azimuth_deg,
                "bearing_to_target_deg": round(horizontal_bearing_deg, 3),
                "relative_azimuth_deg": round(relative_az, 3),
                "elevation_to_target_deg": round(elevation_deg, 3),
                "gain_to_target_dbi": round(gain, 3),
                "pattern": self.antenna_pattern(req),
            },
            "field_at_target": self.field_at_receiver(req, tx, rx, gain),
            "fresnel": self.fresnel_clearance(req, tx, rx),
            "notes": [
                "Simulation-only deterministic RF field model",
                "Plane-wave far-field approximation",
                "Antenna pattern is simplified and not a vendor calibration file",
                "Fresnel clearance is geometric and intended for engineering visualization",
            ],
        }

        return result

    async def run_and_persist(self, req: RfFieldRequest):
        result = self.run_field(req)
        self.runs.add(
            run_id=result["run_id"],
            mission_id=req.mission_id,
            cell_asset_id=req.cell_asset_id,
            target_asset_id=req.target_asset_id,
            model_name=self.model_name,
            frequency_hz=req.frequency_hz,
            data=result,
        )

        event = CloudEvent(
            source="urn:trfmc:rf-field",
            type=ce_type("rf_field", "run_completed"),
            subject=result["run_id"],
            data={
                "mission_id": req.mission_id,
                "correlation_id": f"CORR-{result['run_id']}",
                "run_id": result["run_id"],
                "cell_asset_id": req.cell_asset_id,
                "target_asset_id": req.target_asset_id,
                "field_region": result["field_at_target"]["field_region"],
                "gain_to_target_dbi": result["antenna"]["gain_to_target_dbi"],
                "global_time_cursor_ms": 0,
            },
        )
        event_dict = event.model_dump(mode="json")
        self.events.append(event_dict)
        await event_bus.broadcast(event_dict)

        return {"persisted": True, "run": result, "event": event_dict}

    def list_runs(self):
        return self.runs.list()
