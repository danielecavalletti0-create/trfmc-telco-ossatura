from typing import Optional
from fastapi import APIRouter

from app.domains.restore_readiness.services import RestoreReadinessService

router = APIRouter(prefix="/api/restore", tags=["restore-readiness"])
service = RestoreReadinessService()


@router.get("/readiness")
def readiness():
    return service.readiness()


@router.get("/plan")
def plan():
    return service.plan()


@router.get("/verify-backup")
def verify_backup(archive_name: Optional[str] = None):
    return service.verify_backup(archive_name=archive_name)


@router.get("/drill")
def drill():
    return service.drill()
