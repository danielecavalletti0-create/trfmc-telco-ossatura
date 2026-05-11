from fastapi import APIRouter
from app.domains.time_cursor.schemas import TimeCursorSetRequest
from app.domains.time_cursor.services import TimeCursorService

router = APIRouter(prefix="/api/time-cursor", tags=["global-time-cursor"])
service = TimeCursorService()


@router.get("/status")
def status(mission_id: str = "MISSION-FULL-TELCO-BOOT-001"):
    return service.status(mission_id)


@router.post("/set")
async def set_cursor(req: TimeCursorSetRequest):
    return await service.set_cursor(
        mission_id=req.mission_id,
        cursor_ms=req.cursor_ms,
        reason=req.reason,
    )


@router.get("/timeline")
def timeline(limit: int = 100):
    return service.timeline(limit=limit)
