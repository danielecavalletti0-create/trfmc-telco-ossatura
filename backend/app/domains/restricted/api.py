from fastapi import APIRouter
from app.core.config import settings
router = APIRouter(prefix="/api/restricted", tags=["restricted"])
@router.get("/status")
def status():
    return {"restricted_enabled":settings.restricted_enabled,"status":"LOCKED","required_controls":["PKI","mTLS","smartcard/token hardware","RBAC/ABAC","session binding","workstation binding","immutable audit","RF safety interlock"],"domains":["SIGINT","OSINT_ADVANCED","RED_TEAM","EW_JAMMING_SIMULATION"]}
