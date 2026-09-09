from fastapi import APIRouter
from app.domains.telco_mns.services import TelcoMnSService
router = APIRouter(prefix="/api/telco-mns", tags=["telco-mns"])
service = TelcoMnSService()
@router.get("/status")
def status(): return service.status()
