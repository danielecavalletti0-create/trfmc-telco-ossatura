from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

from app.domains.evidence_vault.services import EvidenceVaultService

router = APIRouter(prefix="/api/vault", tags=["vault"])
service = EvidenceVaultService()


@router.get("/status")
def status():
    return service.status()


@router.post("/archive/latest")
def archive_latest():
    return service.archive_latest()


@router.get("/reports")
def reports():
    return service.list_reports()


@router.get("/reports/{run_id}")
def report(run_id: str):
    try:
        return service.get_report(run_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/reports/{run_id}/html", response_class=HTMLResponse)
def report_html(run_id: str):
    try:
        return HTMLResponse(content=service.get_report_html(run_id), status_code=200)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/snapshot/latest")
def latest_snapshot():
    return service.latest_snapshot()
