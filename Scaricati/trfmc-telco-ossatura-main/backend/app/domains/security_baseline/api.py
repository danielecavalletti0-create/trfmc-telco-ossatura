from fastapi import APIRouter

from app.domains.security_baseline.services import SecurityBaselineService

router = APIRouter(prefix="/api/security", tags=["security"])
service = SecurityBaselineService()


@router.get("/posture")
def posture():
    return service.posture()


@router.get("/access-policy")
def access_policy():
    return service.access_policy()


@router.get("/runtime-checks")
def runtime_checks():
    return service.runtime_checks()


@router.get("/audit-log")
def audit_log(limit: int = 100):
    return service.audit_log(limit=limit)


@router.get("/readiness")
def readiness():
    return service.readiness()
