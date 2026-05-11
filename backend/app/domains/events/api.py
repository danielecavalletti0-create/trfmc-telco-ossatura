from fastapi import APIRouter
from app.domains.events.services import EventFabricService
router = APIRouter(prefix="/api/events", tags=["event-fabric"])
service = EventFabricService()
@router.get("/demo")
def demo_events(): return service.demo_events()
