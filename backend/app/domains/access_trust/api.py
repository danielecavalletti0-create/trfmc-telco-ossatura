from fastapi import APIRouter
from pydantic import BaseModel
from app.domains.access_trust.services import AccessTrustService
router = APIRouter(prefix="/api/access-trust", tags=["access-trust"])
service = AccessTrustService()
class RatAssessmentRequest(BaseModel):
    previous_rat: str = "5G_NR"
    current_rat: str = "2G_GSM"
    known_cell: bool = False
    normal_coverage: bool = True
class WifiAssessmentRequest(BaseModel):
    expected_security: str = "WPA3_ENTERPRISE"
    observed_security: str = "OPEN"
    inventory_match: bool = False
    same_ssid: bool = True
    known_bssid: bool = False
@router.post("/rat/assess")
def assess_rat(req: RatAssessmentRequest): return service.classify_rat(**req.model_dump())
@router.get("/rat/demo")
def rat_demo(): return service.classify_rat("5G_NR", "2G_GSM", False, True)
@router.post("/wifi/assess")
def assess_wifi(req: WifiAssessmentRequest): return service.classify_wifi(**req.model_dump())
@router.get("/wifi/demo")
def wifi_demo(): return service.classify_wifi("WPA3_ENTERPRISE", "OPEN", False, True, False)
