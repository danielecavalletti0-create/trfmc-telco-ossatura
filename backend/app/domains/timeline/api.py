from typing import Optional
from fastapi import APIRouter

from app.domains.timeline.services import TimelineService

router = APIRouter(prefix="/api/timeline", tags=["timeline"])
service = TimelineService()


@router.get("/evidence")
def evidence_timeline(mission_id: Optional[str] = None, limit: int = 300):
    return service.timeline(mission_id=mission_id, limit=limit)


@router.get("/replay")
def mission_replay(mission_id: str = "MISSION-FULL-TELCO-BOOT-001"):
    return service.replay(mission_id=mission_id)


@router.get("/correlation/{correlation_id}")
def correlation(correlation_id: str):
    return service.correlation(correlation_id)
