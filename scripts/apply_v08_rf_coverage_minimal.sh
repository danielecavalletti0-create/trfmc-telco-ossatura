#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

echo "=== APPLY v0.8 RF COVERAGE MINIMAL ==="

mkdir -p backend/app/domains/rf_coverage
touch backend/app/domains/rf_coverage/__init__.py

python3 - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/persistence/models.py")
s = p.read_text()

if "CREATE TABLE IF NOT EXISTS rf_obstacles" not in s:
    block = '''
    ,
    """
    CREATE TABLE IF NOT EXISTS rf_obstacles (
        obstacle_id TEXT PRIMARY KEY,
        obstacle_type TEXT NOT NULL,
        material TEXT NOT NULL,
        x_m REAL NOT NULL,
        y_m REAL NOT NULL,
        width_m REAL NOT NULL,
        depth_m REAL NOT NULL,
        height_m REAL NOT NULL,
        loss_db REAL NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS rf_coverage_runs (
        run_id TEXT PRIMARY KEY,
        mission_id TEXT NOT NULL,
        cell_asset_id TEXT NOT NULL,
        target_asset_id TEXT,
        model_name TEXT NOT NULL,
        frequency_hz REAL NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_rf_coverage_runs_mission
    ON rf_coverage_runs(mission_id);
    """
'''
    s = s.rstrip()
    if s.endswith("]"):
        s = s[:-1] + block + "\n]\n"
    p.write_text(s)

p = Path("backend/app/persistence/repositories.py")
s = p.read_text()

if '"rf_obstacles"' not in s:
    s = s.replace(
        '"time_cursors",',
        '"time_cursors",\n            "rf_obstacles",\n            "rf_coverage_runs",'
    )

if "class RfObstacleRepository:" not in s:
    s += '''


class RfObstacleRepository:
    def upsert(self, obstacle_id: str, obstacle_type: str, material: str,
               x_m: float, y_m: float, width_m: float, depth_m: float,
               height_m: float, loss_db: float, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO rf_obstacles
                (obstacle_id, obstacle_type, material, x_m, y_m, width_m, depth_m,
                 height_m, loss_db, data_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(obstacle_id) DO UPDATE SET
                    obstacle_type=excluded.obstacle_type,
                    material=excluded.material,
                    x_m=excluded.x_m,
                    y_m=excluded.y_m,
                    width_m=excluded.width_m,
                    depth_m=excluded.depth_m,
                    height_m=excluded.height_m,
                    loss_db=excluded.loss_db,
                    data_json=excluded.data_json,
                    updated_at=excluded.updated_at;
                """,
                (obstacle_id, obstacle_type, material, x_m, y_m, width_m,
                 depth_m, height_m, loss_db, as_json(data), ts, ts),
            )

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM rf_obstacles ORDER BY obstacle_type, obstacle_id"
            ).fetchall()
            return [row_to_dict(r) for r in rows]


class RfCoverageRunRepository:
    def add(self, run_id: str, mission_id: str, cell_asset_id: str,
            target_asset_id: Optional[str], model_name: str,
            frequency_hz: float, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO rf_coverage_runs
                (run_id, mission_id, cell_asset_id, target_asset_id,
                 model_name, frequency_hz, data_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (run_id, mission_id, cell_asset_id, target_asset_id,
                 model_name, frequency_hz, as_json(data), ts),
            )

    def list(self, limit: int = 50) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM rf_coverage_runs ORDER BY created_at DESC LIMIT ?",
                (limit,),
            ).fetchall()
            return [row_to_dict(r) for r in rows]
'''
    p.write_text(s)
PY

cat > backend/app/domains/rf_coverage/schemas.py <<'PY'
from pydantic import BaseModel, Field
from typing import Optional


class RfCoverageRequest(BaseModel):
    mission_id: str = "MISSION-FULL-TELCO-BOOT-001"
    cell_asset_id: str = "CELL-N78-A"
    target_asset_id: Optional[str] = "UE-REMOTE-001"
    frequency_hz: float = Field(3.5e9, gt=0)
    tx_power_dbm: float = 43.0
    tx_gain_dbi: float = 18.0
    rx_gain_dbi: float = 0.0
    bandwidth_hz: float = Field(100e6, gt=0)
    noise_figure_db: float = 7.0
    atmospheric_loss_db_per_km: float = 0.02
    grid_extent_m: float = 600.0
    grid_step_m: float = 100.0
PY

cat > backend/app/domains/rf_coverage/services.py <<'PY'
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
PY

cat > backend/app/domains/rf_coverage/api.py <<'PY'
from fastapi import APIRouter
from app.domains.rf_coverage.schemas import RfCoverageRequest
from app.domains.rf_coverage.services import RfCoverageService

router = APIRouter(prefix="/api/rf-coverage", tags=["rf-coverage"])
service = RfCoverageService()


@router.get("/obstacles")
def obstacles():
    return service.list_obstacles()


@router.get("/demo")
def demo():
    return service.run_coverage(RfCoverageRequest())


@router.post("/run")
async def run_coverage(req: RfCoverageRequest):
    return await service.run_and_persist(req)


@router.get("/runs")
def runs():
    return service.list_runs()
PY

cat > backend/app/persistence/api.py <<'PY'
from fastapi import APIRouter

from app.persistence.repositories import (
    PersistenceRepository,
    MissionRepository,
    CloudEventRepository,
    AssetRepository,
    AssetLinkRepository,
    EvidenceRepository,
    DeviceTrustRepository,
    NetworkPathRepository,
    IncidentRepository,
    RfCoverageRunRepository,
    RfObstacleRepository,
)

router = APIRouter(prefix="/api/persistence", tags=["persistence"])


@router.get("/status")
def status():
    return PersistenceRepository().status()


@router.get("/missions")
def missions():
    return MissionRepository().list()


@router.get("/events")
def events(limit: int = 100):
    return CloudEventRepository().list(limit=limit)


@router.get("/assets")
def assets():
    return AssetRepository().list()


@router.get("/asset-links")
def asset_links():
    return AssetLinkRepository().list()


@router.get("/evidence")
def evidence():
    return EvidenceRepository().list()


@router.get("/device-trust")
def device_trust():
    return DeviceTrustRepository().list()


@router.get("/network-paths")
def network_paths():
    return NetworkPathRepository().list()


@router.get("/incidents")
def incidents():
    return IncidentRepository().list()


@router.get("/rf-runs")
def rf_runs():
    return RfCoverageRunRepository().list()


@router.get("/rf-obstacles")
def rf_obstacles():
    return RfObstacleRepository().list()
PY

python3 - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
s = p.read_text()

if "from app.domains.rf_coverage.api import router as rf_coverage_router" not in s:
    s = s.replace(
        "from app.domains.network_fabric.api import router as network_router",
        "from app.domains.network_fabric.api import router as network_router\nfrom app.domains.rf_coverage.api import router as rf_coverage_router"
    )

s = re.sub(r'version="0\.\d+\.0"', 'version="0.8.0"', s)
s = re.sub(r'"version": "0\.\d+\.0"', '"version": "0.8.0"', s)

s = s.replace(
    'description="Telco RF Mission Control Platform — network journey digital twin skeleton."',
    'description="Telco RF Mission Control Platform — RF propagation and urban coverage skeleton."'
)

if "app.include_router(rf_coverage_router)" not in s:
    s = s.replace(
        "app.include_router(network_router)",
        "app.include_router(network_router)\napp.include_router(rf_coverage_router)"
    )

p.write_text(s)
PY

echo "=== VERIFICA SORGENTE v0.8 ==="
grep -n 'version=' backend/app/main.py
grep -n '"version":' backend/app/main.py
grep -R "rf_coverage" -n backend/app/main.py backend/app/domains/rf_coverage | head -n 40
