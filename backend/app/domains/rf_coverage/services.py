import math
from uuid import uuid4
from typing import Dict, Any, Optional, List

from app.domains.rf_coverage.schemas import RfCoverageRequest
from app.persistence.repositories import (
    RfObstacleRepository,
    RfCoverageRunRepository,
    CloudEventRepository,
)
from app.shared.cloudevents import CloudEvent, ce_type
from app.core.event_bus import event_bus

K_BOLTZMANN = 1.380649e-23
T0_K = 290.0


class RfCoverageService:
    model_name = "FSPL_PLUS_URBAN_OBSTRUCTION_V0_8"

    def __init__(self):
        self.obstacles = RfObstacleRepository()
        self.runs = RfCoverageRunRepository()
        self.events = CloudEventRepository()

    def seed_default_obstacles(self):
        defaults = [
            ("BLDG-URBAN-001", "BUILDING", "reinforced_concrete", 180, 40, 90, 80, 35, 18),
            ("BLDG-URBAN-002", "BUILDING", "glass_concrete_metal", 320, -120, 120, 90, 42, 22),
            ("TREE-LINE-001", "FOLIAGE", "vegetation", 260, 130, 170, 55, 18, 7),
        ]
        for oid, typ, mat, x, y, w, d, h, loss in defaults:
            self.obstacles.upsert(
                obstacle_id=oid,
                obstacle_type=typ,
                material=mat,
                x_m=x,
                y_m=y,
                width_m=w,
                depth_m=d,
                height_m=h,
                loss_db=loss,
                data={"source": "v0.8_default_obstacle_seed"},
            )

    def list_obstacles(self):
        self.seed_default_obstacles()
        return self.obstacles.list()

    def fspl_db(self, distance_m: float, frequency_hz: float) -> float:
        distance_m = max(distance_m, 1.0)
        return 20.0 * math.log10(distance_m) + 20.0 * math.log10(frequency_hz) - 147.55

    def noise_floor_dbm(self, bandwidth_hz: float, noise_figure_db: float) -> float:
        thermal_w = K_BOLTZMANN * T0_K * bandwidth_hz
        return 10.0 * math.log10(thermal_w / 1e-3) + noise_figure_db

    def distance_3d(self, tx: Dict[str, float], rx: Dict[str, float]) -> float:
        return math.sqrt(
            (tx["x_m"] - rx["x_m"]) ** 2 +
            (tx["y_m"] - rx["y_m"]) ** 2 +
            (tx["z_m"] - rx["z_m"]) ** 2
        )

    def point_inside_obstacle(self, x: float, y: float, obstacle: Dict[str, Any]) -> bool:
        return (
            obstacle["x_m"] - obstacle["width_m"] / 2 <= x <= obstacle["x_m"] + obstacle["width_m"] / 2
            and obstacle["y_m"] - obstacle["depth_m"] / 2 <= y <= obstacle["y_m"] + obstacle["depth_m"] / 2
        )

    def line_intersects_obstacle(self, tx: Dict[str, float], rx: Dict[str, float], obstacle: Dict[str, Any]) -> bool:
        for i in range(1, 40):
            t = i / 40
            x = tx["x_m"] + (rx["x_m"] - tx["x_m"]) * t
            y = tx["y_m"] + (rx["y_m"] - tx["y_m"]) * t
            z = tx["z_m"] + (rx["z_m"] - tx["z_m"]) * t
            if self.point_inside_obstacle(x, y, obstacle) and obstacle["height_m"] >= z:
                return True
        return False

    def obstacle_loss(self, tx: Dict[str, float], rx: Dict[str, float], obstacles: List[Dict[str, Any]]):
        loss = 0.0
        hits = []
        for obs in obstacles:
            if self.line_intersects_obstacle(tx, rx, obs):
                loss += float(obs["loss_db"])
                hits.append(obs["obstacle_id"])
        return loss, hits

    def classify_link(self, snr_db: float, los_state: str) -> str:
        if snr_db >= 20 and los_state == "LOS":
            return "EXCELLENT"
        if snr_db >= 10:
            return "GOOD"
        if snr_db >= 3:
            return "DEGRADED"
        return "CRITICAL"

    def target_position(self, target_asset_id: Optional[str]):
        if target_asset_id == "UAV-ALPHA-001":
            return {"x_m": 420.0, "y_m": 160.0, "z_m": 120.0}
        return {"x_m": 280.0, "y_m": 80.0, "z_m": 1.5}

    def compute_link(self, req: RfCoverageRequest, tx, rx, obstacles, target_asset_id):
        d = self.distance_3d(tx, rx)
        fspl = self.fspl_db(d, req.frequency_hz)
        obs_loss, hits = self.obstacle_loss(tx, rx, obstacles)
        atmospheric = (d / 1000.0) * req.atmospheric_loss_db_per_km
        total_loss = fspl + obs_loss + atmospheric
        rx_power = req.tx_power_dbm + req.tx_gain_dbi + req.rx_gain_dbi - total_loss
        noise = self.noise_floor_dbm(req.bandwidth_hz, req.noise_figure_db)
        snr = rx_power - noise
        los_state = "LOS" if not hits else "NLOS"
        return {
            "target_asset_id": target_asset_id,
            "distance_m": round(d, 3),
            "fspl_db": round(fspl, 3),
            "obstacle_loss_db": round(obs_loss, 3),
            "obstacle_hits": hits,
            "atmospheric_loss_db": round(atmospheric, 3),
            "total_path_loss_db": round(total_loss, 3),
            "rx_power_dbm": round(rx_power, 3),
            "noise_floor_dbm": round(noise, 3),
            "snr_db": round(snr, 3),
            "los_state": los_state,
            "classification": self.classify_link(snr, los_state),
        }

    def run_coverage(self, req: RfCoverageRequest):
        self.seed_default_obstacles()
        obstacles = self.obstacles.list()

        tx = {
            "asset_id": req.cell_asset_id,
            "x_m": 0.0,
            "y_m": 0.0,
            "z_m": 35.0,
            "tx_power_dbm": req.tx_power_dbm,
            "tx_gain_dbi": req.tx_gain_dbi,
            "band": "n78",
        }

        target_link = self.compute_link(
            req,
            tx,
            self.target_position(req.target_asset_id),
            obstacles,
            req.target_asset_id,
        )

        grid = []
        half = req.grid_extent_m / 2
        y = -half
        while y <= half + 0.1:
            x = -half
            while x <= half + 0.1:
                link = self.compute_link(req, tx, {"x_m": x, "y_m": y, "z_m": 1.5}, obstacles, None)
                grid.append({
                    "x_m": x,
                    "y_m": y,
                    "snr_db": link["snr_db"],
                    "rx_power_dbm": link["rx_power_dbm"],
                    "los_state": link["los_state"],
                    "classification": link["classification"],
                })
                x += req.grid_step_m
            y += req.grid_step_m

        summary = {
            "grid_points": len(grid),
            "excellent": sum(1 for p in grid if p["classification"] == "EXCELLENT"),
            "good": sum(1 for p in grid if p["classification"] == "GOOD"),
            "degraded": sum(1 for p in grid if p["classification"] == "DEGRADED"),
            "critical": sum(1 for p in grid if p["classification"] == "CRITICAL"),
            "nlos_points": sum(1 for p in grid if p["los_state"] == "NLOS"),
            "target_classification": target_link["classification"],
            "target_los_state": target_link["los_state"],
        }

        return {
            "run_id": f"RF-COV-{uuid4().hex[:12].upper()}",
            "mission_id": req.mission_id,
            "model_name": self.model_name,
            "cell_asset_id": req.cell_asset_id,
            "frequency_hz": req.frequency_hz,
            "transmitter": tx,
            "obstacles": obstacles,
            "target_link": target_link,
            "coverage_grid": grid,
            "summary": summary,
        }

    async def run_and_persist(self, req: RfCoverageRequest):
        result = self.run_coverage(req)
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
            source="urn:trfmc:rf-coverage",
            type=ce_type("rf_coverage", "run_completed"),
            subject=result["run_id"],
            data={
                "mission_id": req.mission_id,
                "correlation_id": f"CORR-{result['run_id']}",
                "run_id": result["run_id"],
                "cell_asset_id": req.cell_asset_id,
                "target_asset_id": req.target_asset_id,
                "target_classification": result["summary"]["target_classification"],
                "target_los_state": result["summary"]["target_los_state"],
                "nlos_points": result["summary"]["nlos_points"],
                "global_time_cursor_ms": 0,
            },
        )
        event_dict = event.model_dump(mode="json")
        self.events.append(event_dict)
        await event_bus.broadcast(event_dict)

        return {"persisted": True, "run": result, "event": event_dict}

    def list_runs(self):
        return self.runs.list()
