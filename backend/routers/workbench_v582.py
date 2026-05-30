from pathlib import Path
from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/api/v582", tags=["RF PRO v5.8.2 Workbench Restored"])
ROOT = Path(__file__).resolve().parents[2]

@router.get("/workbench/page", response_class=HTMLResponse)
def page():
    p = ROOT / "frontend" / "public" / "signal_workbench_v582.html"
    if not p.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {p}")
    return HTMLResponse(p.read_text(encoding="utf-8", errors="ignore"))

@router.get("/selftest")
def selftest():
    return {"ok": True, "version": "5.8.2", "page": "/api/v582/workbench/page"}
