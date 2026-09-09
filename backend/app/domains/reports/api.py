from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

from app.domains.reports.services import ScenarioReportService

router = APIRouter(prefix="/api/reports", tags=["reports"])
service = ScenarioReportService()


@router.get("/latest")
def latest_report():
    return service.latest_report()


@router.get("/scenario/{run_id}")
def scenario_report(run_id: str):
    try:
        return service.report(run_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/export/html/{run_id}", response_class=HTMLResponse)
def export_html(run_id: str):
    try:
        return HTMLResponse(content=service.export_html(run_id), status_code=200)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
