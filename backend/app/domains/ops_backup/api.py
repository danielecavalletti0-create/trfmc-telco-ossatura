from fastapi import APIRouter

from app.domains.ops_backup.services import OpsBackupService

router = APIRouter(prefix="/api/ops/backup", tags=["ops-backup"])
service = OpsBackupService()


@router.get("/status")
def status():
    return service.status()


@router.post("/create-runtime")
def create_runtime_backup():
    return service.create_runtime_backup()


@router.get("/list")
def list_backups():
    return service.list_backups()


@router.get("/latest-manifest")
def latest_manifest():
    return service.latest_manifest()
