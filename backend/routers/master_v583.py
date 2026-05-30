from __future__ import annotations

import json
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, List

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse, FileResponse

router = APIRouter(prefix="/api/v583", tags=["RF PRO v5.8.3 Master Integration"])

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
REPORT_DIR = RUNTIME / "reports"
IQ_DIR = RUNTIME / "iq"
WAV_DIR = RUNTIME / "wav"
REGISTRY = REPORT_DIR / "rfpro_feature_registry_v583.json"
for d in (REPORT_DIR, IQ_DIR, WAV_DIR):
    d.mkdir(parents=True, exist_ok=True)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_registry() -> Dict[str, Any]:
    if not REGISTRY.exists():
        return {"version": "5.8.3", "modules": [], "workflow": [], "warning": "registry missing"}
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def file_rows(base: Path, suffixes: List[str], limit: int = 80) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for suffix in suffixes:
        for p in base.glob(f"*{suffix}"):
            if p.is_file():
                rows.append({
                    "name": p.name,
                    "size": p.stat().st_size,
                    "mtime": datetime.fromtimestamp(p.stat().st_mtime, timezone.utc).isoformat(),
                    "sha256": sha256_file(p)
                })
    return sorted(rows, key=lambda x: x["mtime"], reverse=True)[:limit]


@router.get("/master/page", response_class=HTMLResponse)
def master_page():
    p = ROOT / "frontend" / "public" / "rfpro_master_v583.html"
    if not p.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {p}")
    return HTMLResponse(p.read_text(encoding="utf-8", errors="ignore"))


@router.get("/master/registry")
def registry():
    return load_registry()


@router.get("/master/state")
def state():
    reg = load_registry()
    return {
        "ok": True,
        "version": "5.8.3",
        "service": "rf-pro-master-integration",
        "mode": "RX_ONLY",
        "time": utc_now(),
        "registry_file": str(REGISTRY),
        "modules": reg.get("modules", []),
        "workflow": reg.get("workflow", []),
        "entrypoints": {
            "master": "/api/v583/master/page",
            "restored_workbench": "/api/v582/workbench/page",
            "demod_pro": "/api/v581/demod/page",
            "workbench_engine": "/api/v580/workbench/page"
        }
    }


@router.get("/master/workflow")
def workflow():
    reg = load_registry()
    return {
        "ok": True,
        "version": "5.8.3",
        "workflow": reg.get("workflow", []),
        "operational_chain": {
            "sweep": "/api/v580/workbench/sweep/window",
            "capture_iq": "/api/v580/workbench/iq/capture",
            "analyze_plus": "/api/v581/iq/analyze_plus",
            "channelize_demod": "/api/v581/iq/channelize_demod",
            "evidence": "/api/v580/workbench/evidence",
            "wifi": "/api/v580/wifi/metadata",
            "markvii": "/api/v580/markvii/recon",
            "blueway": "/api/v580/blueway/status",
            "modem": "/api/v580/modem/cellular"
        }
    }


@router.get("/master/files")
def files():
    return {
        "ok": True,
        "version": "5.8.3",
        "iq": file_rows(IQ_DIR, [".iq8", ".iq", ".c8"], 120),
        "wav": file_rows(WAV_DIR, [".wav"], 120),
        "reports": file_rows(REPORT_DIR, [".json"], 160)
    }


@router.get("/master/audit")
def audit():
    reg = load_registry()
    expected_files = [
        ROOT / "backend" / "routers" / "workbench_v580.py",
        ROOT / "backend" / "routers" / "demod_v581.py",
        ROOT / "backend" / "routers" / "workbench_v582.py",
        ROOT / "backend" / "routers" / "master_v583.py",
        ROOT / "frontend" / "public" / "signal_workbench_v582.html",
        ROOT / "frontend" / "public" / "signal_demod_v581.html",
        ROOT / "frontend" / "public" / "rfpro_master_v583.html",
        ROOT / "backend" / "main_v580.py"
    ]
    files = []
    for p in expected_files:
        files.append({
            "path": str(p.relative_to(ROOT)) if str(p).startswith(str(ROOT)) else str(p),
            "exists": p.exists(),
            "size": p.stat().st_size if p.exists() else 0,
            "sha256": sha256_file(p) if p.exists() and p.is_file() else None
        })
    ok = all(x["exists"] for x in files)
    return {
        "ok": ok,
        "version": "5.8.3",
        "time": utc_now(),
        "registry_modules": [m.get("id") for m in reg.get("modules", [])],
        "files": files,
        "note": "Questo audit verifica che i moduli principali non siano stati persi dal filesystem."
    }


@router.get("/master/file/{filename}")
def get_file(filename: str):
    name = Path(filename).name
    for base, media in (
        (WAV_DIR, "audio/wav"),
        (IQ_DIR, "application/octet-stream"),
        (REPORT_DIR, "application/json"),
    ):
        p = (base / name).resolve()
        if str(p).startswith(str(base.resolve())) and p.exists():
            return FileResponse(p, media_type=media, filename=p.name)
    raise HTTPException(status_code=404, detail="file non trovato")
