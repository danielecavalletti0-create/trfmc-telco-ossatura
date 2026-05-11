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
