from __future__ import annotations

import asyncio
import hashlib
import json
import math
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/api/v585", tags=["RF PRO v5.8.5 Realtime UI"])

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
REALTIME_DIR = RUNTIME / "realtime"
REALTIME_DIR.mkdir(parents=True, exist_ok=True)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()


def run_cmd(cmd: List[str], timeout: int = 12) -> Dict[str, Any]:
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout, check=False)
        return {"cmd": cmd, "returncode": p.returncode, "stdout": p.stdout[-600000:], "stderr": p.stderr[-20000:]}
    except Exception as exc:
        return {"cmd": cmd, "returncode": -1, "stdout": "", "stderr": repr(exc)}


def parse_hackrf_sweep(text: str, start_hz: float, stop_hz: float) -> List[Dict[str, float]]:
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


def synthetic_frame(start_hz: float, stop_hz: float, points: int, seq: int) -> List[Dict[str, float]]:
    points = max(128, min(2400, int(points)))
    width = max(1.0, stop_hz - start_hz)
    hop_positions = [0.13, 0.22, 0.31, 0.48, 0.63, 0.77, 0.88]
    hop1 = start_hz + width * hop_positions[seq % len(hop_positions)]
    hop2 = start_hz + width * hop_positions[(seq * 2 + 3) % len(hop_positions)]
    fixed = start_hz + width * 0.52
    out: List[Dict[str, float]] = []
    for i in range(points):
        f = start_hz + width * i / (points - 1)
        noise = -96.0 + 3.5 * math.sin((seq + i) / 17.0) + 2.2 * math.sin(i / 7.0)
        g1 = math.exp(-0.5 * ((f - hop1) / max(width * 0.006, 1.0)) ** 2)
        g2 = math.exp(-0.5 * ((f - hop2) / max(width * 0.004, 1.0)) ** 2)
        g3 = math.exp(-0.5 * ((f - fixed) / max(width * 0.011, 1.0)) ** 2)
        db = noise + 40.0 * g1 + 31.0 * g2 + 22.0 * g3
        out.append({"freq_hz": round(f, 3), "db": round(db, 2)})
    return out


def find_peaks(points: List[Dict[str, float]], limit: int = 16) -> List[Dict[str, Any]]:
    if len(points) < 3:
        return []
    vals = [p["db"] for p in points]
    med = sorted(vals)[len(vals) // 2]
    peaks: List[Dict[str, Any]] = []
    for i in range(1, len(points) - 1):
        p = points[i]
        if p["db"] >= points[i - 1]["db"] and p["db"] >= points[i + 1]["db"] and p["db"] - med >= 7.0:
            peaks.append({
                "freq_hz": p["freq_hz"],
                "freq_mhz": round(p["freq_hz"] / 1e6, 6),
                "db": p["db"],
                "snr_median_db": round(p["db"] - med, 2)
            })
    peaks.sort(key=lambda x: x["db"], reverse=True)
    return peaks[:limit]


def frame_metrics(points: List[Dict[str, float]]) -> Dict[str, Any]:
    if not points:
        return {}
    vals = [p["db"] for p in points]
    pk = max(points, key=lambda p: p["db"])
    noise = sorted(vals)[len(vals) // 2]
    occupied = [p for p in points if p["db"] >= noise + 8.0]
    if occupied:
        obw = occupied[-1]["freq_hz"] - occupied[0]["freq_hz"]
    else:
        obw = 0
    return {
        "peak_mhz": round(pk["freq_hz"] / 1e6, 6),
        "peak_db": round(pk["db"], 2),
        "noise_floor_db": round(noise, 2),
        "obw_hz_est": round(obw, 3),
        "active_bins": len(occupied),
        "points": len(points)
    }


async def sweep_once(start_hz: float, stop_hz: float, bin_hz: float, points: int, seq: int, use_hackrf: bool) -> Dict[str, Any]:
    source = "SYNTHETIC"
    raw_status = None
    data: List[Dict[str, float]] = []

    if use_hackrf and shutil.which("hackrf_sweep"):
        cmd = ["hackrf_sweep", "-f", f"{start_hz/1e6:.6f}:{stop_hz/1e6:.6f}", "-w", str(int(bin_hz)), "-1"]
        raw = await asyncio.to_thread(run_cmd, cmd, 18)
        raw_status = {"returncode": raw.get("returncode"), "stderr_tail": (raw.get("stderr") or "")[-900:]}
        if raw.get("returncode") == 0:
            data = parse_hackrf_sweep(raw.get("stdout", ""), start_hz, stop_hz)
            if data:
                source = "REAL_HACKRF_SWEEP"

    if not data:
        data = synthetic_frame(start_hz, stop_hz, points, seq)

    return {
        "ok": True,
        "version": "5.8.5",
        "seq": seq,
        "time": now_iso(),
        "source": source,
        "start_hz": start_hz,
        "stop_hz": stop_hz,
        "bin_hz": bin_hz,
        "points": data,
        "peaks": find_peaks(data),
        "metrics": frame_metrics(data),
        "raw_status": raw_status
    }


@router.get("/realtime/page", response_class=HTMLResponse)
def page():
    p = ROOT / "frontend" / "public" / "rfpro_realtime_v585.html"
    if not p.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {p}")
    return HTMLResponse(p.read_text(encoding="utf-8", errors="ignore"))


@router.get("/realtime/state")
def state():
    return {
        "ok": True,
        "version": "5.8.5",
        "mode": "RX_ONLY_REALTIME",
        "websocket": "/api/v585/ws/spectrum",
        "tools": {
            "hackrf_sweep": shutil.which("hackrf_sweep"),
            "hackrf_transfer": shutil.which("hackrf_transfer"),
            "hackrf_info": shutil.which("hackrf_info")
        },
        "ui": {
            "layout": "native panels, no iframe nesting",
            "render": "Canvas spectrum + waterfall",
            "transport": "WebSocket JSON frames"
        },
        "safety": {
            "tx": "disabled",
            "replay": "disabled",
            "deauth": "disabled"
        }
    }


@router.get("/realtime/one_frame")
async def one_frame(start_hz: float = 1_000_000, stop_hz: float = 5_000_000, bin_hz: float = 100_000, use_hackrf: bool = False):
    return await sweep_once(start_hz, stop_hz, bin_hz, 1200, 0, use_hackrf)


@router.websocket("/ws/spectrum")
async def ws_spectrum(websocket: WebSocket):
    await websocket.accept()
    seq = 0
    cfg: Dict[str, Any] = {
        "start_hz": 1_000_000.0,
        "stop_hz": 5_000_000.0,
        "bin_hz": 100_000.0,
        "points": 1200,
        "fps": 2.0,
        "use_hackrf": False
    }

    try:
        # first config message is optional; if not received quickly, stream default.
        try:
            msg = await asyncio.wait_for(websocket.receive_text(), timeout=1.0)
            incoming = json.loads(msg)
            cfg.update({k: incoming[k] for k in incoming if k in cfg})
        except asyncio.TimeoutError:
            pass
        except Exception:
            pass

        while True:
            start_hz = float(cfg.get("start_hz", 1_000_000.0))
            stop_hz = float(cfg.get("stop_hz", 5_000_000.0))
            bin_hz = float(cfg.get("bin_hz", 100_000.0))
            points = int(cfg.get("points", 1200))
            fps = max(0.2, min(10.0, float(cfg.get("fps", 2.0))))
            use_hackrf = bool(cfg.get("use_hackrf", False))

            if start_hz < 1_000_000 or stop_hz > 6_000_000_000 or stop_hz <= start_hz:
                await websocket.send_json({"ok": False, "error": "Invalid range: HackRF 1 MHz - 6 GHz, stop > start", "time": now_iso()})
                await asyncio.sleep(1.0 / fps)
                continue

            frame = await sweep_once(start_hz, stop_hz, bin_hz, points, seq, use_hackrf)
            await websocket.send_json(frame)
            seq += 1

            # non-blocking config updates
            try:
                msg = await asyncio.wait_for(websocket.receive_text(), timeout=0.001)
                incoming = json.loads(msg)
                cfg.update({k: incoming[k] for k in incoming if k in cfg})
            except asyncio.TimeoutError:
                pass
            except Exception:
                pass

            await asyncio.sleep(1.0 / fps)

    except WebSocketDisconnect:
        return
    except Exception as exc:
        try:
            await websocket.send_json({"ok": False, "error": repr(exc), "time": now_iso()})
        except Exception:
            pass
        return
