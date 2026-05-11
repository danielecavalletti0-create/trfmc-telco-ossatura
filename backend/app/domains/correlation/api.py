from fastapi import APIRouter

from app.domains.correlation.services import CorrelationService

router = APIRouter(prefix="/api/correlation", tags=["correlation"])
service = CorrelationService()


@router.get("/graph")
def graph(mission_id: str = "MISSION-FULL-TELCO-BOOT-001", limit: int = 500):
    return service.build_graph(mission_id=mission_id, limit=limit)


@router.get("/assets/{asset_id}")
def asset_view(asset_id: str, mission_id: str = "MISSION-FULL-TELCO-BOOT-001"):
    return service.asset_view(asset_id=asset_id, mission_id=mission_id)


@router.get("/incidents")
def incidents(mission_id: str = "MISSION-FULL-TELCO-BOOT-001"):
    return service.incidents(mission_id=mission_id)
