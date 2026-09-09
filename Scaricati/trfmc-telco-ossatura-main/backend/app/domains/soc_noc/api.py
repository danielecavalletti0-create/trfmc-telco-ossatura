from fastapi import APIRouter
from app.domains.soc_noc.services import SocNocService
router = APIRouter(prefix="/api/soc-noc", tags=["soc-noc"])
service = SocNocService()
@router.get("/model")
def model(): return service.operations_model()
@router.get("/correlation/demo")
def correlation_demo(): return service.demo_correlation()
