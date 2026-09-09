from fastapi import APIRouter
from app.domains.mission.services import MissionService
router = APIRouter(prefix="/api/mission", tags=["mission"])
service = MissionService()
@router.get("/status")
def status(): return service.get_status()
