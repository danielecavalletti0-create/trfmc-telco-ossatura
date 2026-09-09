from fastapi import APIRouter
from app.domains.docs_portal.services import DocsPortalService

router = APIRouter(prefix="/api/docs", tags=["docs"])
service = DocsPortalService()


@router.get("/index")
def index():
    return service.index()


@router.get("/operator-handbook")
def operator_handbook():
    return service.get_doc("operator-handbook")


@router.get("/architecture")
def architecture():
    return service.get_doc("architecture")


@router.get("/backup-restore")
def backup_restore():
    return service.get_doc("backup-restore")


@router.get("/release-chain")
def release_chain():
    return service.get_doc("release-chain")


@router.get("/security")
def security():
    return service.get_doc("security")


@router.get("/commands")
def commands():
    return service.get_doc("commands")
