from __future__ import annotations

import hashlib
import json
import math
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/v586", tags=["RF PRO v5.8.6 FullBand Cursor"])

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
REALTIME_DIR = RUNTIME / "realtime"
REPORT_DIR = RUNTIME / "reports"
for d in (REALTIME_DIR, REPORT_DIR):
    d.mkdir(parents=True, exist_ok=True)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()


def run_cmd(cmd: List[str], timeout: int = 60) -> Dict[str, Any]:
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout, check=False)
        return {
            "cmd": cmd,
            "returncode": p.returncode,
            "stdout": p.stdout[-900000:],
            "stderr": p.stderr[-30000:],
        }
    except subprocess.TimeoutExpired:
        return {"cmd": cmd, "returncode": 124, "stdout": "", "stderr": "timeout"}
    except Exception as exc:
        return {"cmd": cmd, "returncode": -1, "stdout": "", "stderr": repr(exc)}


def parse_sweep(text: str, start_hz: float, stop_hz: float) -> List[Dict[str, float]]:
    rows: List[Dict[str, float]] = []
    for line in (text or "").splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 7:
            continue
        try:
            low = float(parts[2])
            high = float(parts[3])
            bin_hz = float(parts[4])
            vals = [float(x) for x in parts[6:] if x.strip()]
        except Exception:
            continue
        for i, db in enumerate(vals):
            f = low + i * bin_hz + bin_hz / 2.0
            if start_hz <= f <= stop_hz and f <= high:
                rows.append({"freq_hz": round(f, 3), "db": round(db, 2)})
    merged: Dict[int, Dict[str, float]] = {}
    for r in rows:
        k = int(round(r["freq_hz"]))
        if k not in merged or r["db"] > merged[k]["db"]:
            merged[k] = r
    return sorted(merged.values(), key=lambda x: x["freq_hz"])


def synthetic_frame(start_hz: float, stop_hz: float, points: int, seq: int = 0) -> List[Dict[str, float]]:
    width = max(1.0, stop_hz - start_hz)
    points = max(256, min(5000, int(points)))
    carriers = [
        (0.11 + 0.03 * math.sin(seq / 4.0), 42, 0.003),
        (0.32, 31, 0.006),
        (0.48 + 0.07 * math.sin(seq / 6.0), 38, 0.004),
        (0.63, 24, 0.015),
        (0.81 + 0.04 * math.cos(seq / 5.0), 35, 0.005),
    ]
    out: List[Dict[str, float]] = []
    for i in range(points):
        f = start_hz + width * i / (points - 1)
        noise = -96.0 + 2.5 * math.sin(i / 27.0) + 1.7 * math.sin((i + seq) / 11.0)
        db = noise
        x = (f - start_hz) / width
        for pos, amp, sig in carriers:
            g = math.exp(-0.5 * ((x - pos) / sig) ** 2)
            db += amp * g
        out.append({"freq_hz": round(f, 3), "db": round(db, 2)})
    return out


def find_peaks(points: List[Dict[str, float]], threshold_db: float = 7.0, limit: int = 32) -> List[Dict[str, Any]]:
    if len(points) < 3:
        return []
    vals = [p["db"] for p in points]
    med = sorted(vals)[len(vals) // 2]
    peaks = []
    for i in range(1, len(points) - 1):
        p = points[i]
        if p["db"] >= points[i - 1]["db"] and p["db"] >= points[i + 1]["db"] and (p["db"] - med) >= threshold_db:
            peaks.append({
                "freq_hz": p["freq_hz"],
                "freq_mhz": round(p["freq_hz"] / 1e6, 6),
                "db": p["db"],
                "snr_median_db": round(p["db"] - med, 2)
            })
    peaks.sort(key=lambda x: x["db"], reverse=True)
    return peaks[:limit]


def metrics(points: List[Dict[str, float]]) -> Dict[str, Any]:
    if not points:
        return {}
    vals = [p["db"] for p in points]
    med = sorted(vals)[len(vals) // 2]
    pk = max(points, key=lambda p: p["db"])
    active = [p for p in points if p["db"] >= med + 8]
    obw = active[-1]["freq_hz"] - active[0]["freq_hz"] if active else 0
    return {
        "peak_hz": pk["freq_hz"],
        "peak_mhz": round(pk["freq_hz"] / 1e6, 6),
        "peak_db": pk["db"],
        "noise_floor_db": round(med, 2),
        "obw_hz_est": round(obw, 3),
        "active_bins": len(active),
        "points": len(points),
    }


class SweepReq(BaseModel):
    start_hz: float = Field(1_000_000, ge=1_000_000, le=6_000_000_000)
    stop_hz: float = Field(6_000_000_000, ge=1_000_001, le=6_000_000_000)
    rbw_hz: float = Field(1_000_000, ge=2_445, le=5_000_000)
    points: int = Field(2400, ge=256, le=5000)
    use_hackrf: bool = False
    timeout_s: int = Field(90, ge=10, le=600)


@router.get("/fullband/page", response_class=HTMLResponse)
def page():
    p = ROOT / "frontend" / "public" / "rfpro_fullband_v586.html"
    if not p.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {p}")
    return HTMLResponse(p.read_text(encoding="utf-8", errors="ignore"))


@router.get("/fullband/state")
def state():
    return {
        "ok": True,
        "version": "5.8.6",
        "mode": "FULLBAND_CURSOR_RTSA",
        "range_hz": [1_000_000, 6_000_000_000],
        "rbw_hackrf_sweep_hz": [2445, 5_000_000],
        "features": [
            "start/stop/center/span linked controls",
            "manual cursor A/B",
            "RBW",
            "VBW display smoothing",
            "measurement bandwidth overlay",
            "clear/write maxhold average persistence",
            "zero-span style time strip",
            "full band profile"
        ],
        "tools": {
            "hackrf_sweep": shutil.which("hackrf_sweep"),
            "hackrf_info": shutil.which("hackrf_info"),
        }
    }


@router.post("/fullband/sweep")
def fullband_sweep(req: SweepReq):
    start = float(req.start_hz)
    stop = float(req.stop_hz)
    if start < 1_000_000 or stop > 6_000_000_000 or stop <= start:
        raise HTTPException(status_code=400, detail="range valido HackRF: 1 MHz - 6 GHz, stop > start")

    source = "SYNTHETIC"
    raw_status = None
    points: List[Dict[str, float]] = []

    if req.use_hackrf and shutil.which("hackrf_sweep"):
        raw = run_cmd(["hackrf_sweep", "-f", f"{start/1e6:.6f}:{stop/1e6:.6f}", "-w", str(int(req.rbw_hz)), "-1"], timeout=req.timeout_s)
        raw_status = {"returncode": raw["returncode"], "stderr_tail": raw["stderr"][-1200:]}
        if raw["returncode"] == 0:
            points = parse_sweep(raw["stdout"], start, stop)
            if points:
                source = "REAL_HACKRF_SWEEP"

    if not points:
        points = synthetic_frame(start, stop, req.points)

    out = {
        "ok": True,
        "version": "5.8.6",
        "source": source,
        "time": now_iso(),
        "start_hz": start,
        "stop_hz": stop,
        "span_hz": stop - start,
        "center_hz": (start + stop) / 2,
        "rbw_hz": req.rbw_hz,
        "points": points,
        "peaks": find_peaks(points),
        "metrics": metrics(points),
        "raw_status": raw_status
    }
    p = REALTIME_DIR / f"fullband_sweep_{int(time.time())}.json"
    p.write_text(json.dumps({k: v for k, v in out.items() if k != "points"}, indent=2), encoding="utf-8")
    out["report_file"] = p.name
    out["report_sha256"] = sha256_file(p)
    return out


@router.get("/fullband/file/{filename}")
def get_file(filename: str):
    p = (REALTIME_DIR / Path(filename).name).resolve()
    if str(p).startswith(str(REALTIME_DIR.resolve())) and p.exists():
        return FileResponse(p, media_type="application/json", filename=p.name)
    raise HTTPException(status_code=404, detail="file non trovato")
