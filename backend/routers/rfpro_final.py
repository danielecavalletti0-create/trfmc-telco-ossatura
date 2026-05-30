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

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/rfpro", tags=["RF PRO Unified Instrument Console"])

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
IQ_DIR = RUNTIME / "iq"
WAV_DIR = RUNTIME / "wav"
REPORT_DIR = RUNTIME / "reports"
UAV_DIR = RUNTIME / "uav"
RT_DIR = RUNTIME / "realtime"
for d in (IQ_DIR, WAV_DIR, REPORT_DIR, UAV_DIR, RT_DIR):
    d.mkdir(parents=True, exist_ok=True)

UAV_PROFILES = {
    "LOWBAND_TEST_1_5": {"label": "Low-band engineering test 1–5 MHz", "start_hz": 1_000_000, "stop_hz": 5_000_000, "rbw_hz": 100_000, "bucket_hz": 100_000},
    "SRD_433": {"label": "433 MHz telemetry / RC candidate", "start_hz": 433_000_000, "stop_hz": 435_000_000, "rbw_hz": 25_000, "bucket_hz": 25_000},
    "SRD_868_EU": {"label": "868 MHz EU SRD / telemetry candidate", "start_hz": 863_000_000, "stop_hz": 870_000_000, "rbw_hz": 50_000, "bucket_hz": 100_000},
    "ISM_915": {"label": "902–928 MHz ISM / FHSS candidate", "start_hz": 902_000_000, "stop_hz": 928_000_000, "rbw_hz": 100_000, "bucket_hz": 250_000},
    "L_BAND_VIDEO_12_13": {"label": "1.2/1.3 GHz video downlink witness", "start_hz": 1_200_000_000, "stop_hz": 1_360_000_000, "rbw_hz": 500_000, "bucket_hz": 1_000_000},
    "ISM_24_UAV": {"label": "2.4 GHz UAV C2/video/Wi-Fi-like", "start_hz": 2_400_000_000, "stop_hz": 2_483_500_000, "rbw_hz": 250_000, "bucket_hz": 1_000_000},
    "ISM_58_UAV": {"label": "5.8 GHz video/C2 candidate", "start_hz": 5_725_000_000, "stop_hz": 5_875_000_000, "rbw_hz": 500_000, "bucket_hz": 2_000_000},
    "GNSS_L1_WITNESS": {"label": "GNSS L1 interference witness", "start_hz": 1_559_000_000, "stop_hz": 1_610_000_000, "rbw_hz": 250_000, "bucket_hz": 1_000_000},
}


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
        return {"cmd": cmd, "returncode": p.returncode, "stdout": p.stdout[-1000000:], "stderr": p.stderr[-30000:]}
    except subprocess.TimeoutExpired:
        return {"cmd": cmd, "returncode": 124, "stdout": "", "stderr": "timeout"}
    except Exception as exc:
        return {"cmd": cmd, "returncode": -1, "stdout": "", "stderr": repr(exc)}


def parse_sweep_csv(text: str, start_hz: float, stop_hz: float) -> List[Dict[str, float]]:
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
        key = int(round(r["freq_hz"]))
        if key not in merged or r["db"] > merged[key]["db"]:
            merged[key] = r
    return sorted(merged.values(), key=lambda x: x["freq_hz"])


def synthetic_spectrum(start_hz: float, stop_hz: float, points: int = 2200, seq: int = 0) -> List[Dict[str, float]]:
    points = max(256, min(5000, int(points)))
    width = max(1.0, stop_hz - start_hz)
    carriers = [
        (0.10 + 0.04 * math.sin(seq / 6.0), 38, 0.003),
        (0.22, 29, 0.008),
        (0.38 + 0.03 * math.cos(seq / 4.0), 34, 0.004),
        (0.52, 24, 0.014),
        (0.69 + 0.05 * math.sin(seq / 5.0), 36, 0.006),
        (0.86, 30, 0.005),
    ]
    out: List[Dict[str, float]] = []
    for i in range(points):
        x = i / (points - 1)
        f = start_hz + width * x
        noise = -96.0 + 2.3 * math.sin((i + seq) / 19.0) + 1.7 * math.sin(i / 7.0)
        db = noise
        for pos, amp, sigma in carriers:
            db += amp * math.exp(-0.5 * ((x - pos) / sigma) ** 2)
        out.append({"freq_hz": round(f, 3), "db": round(db, 2)})
    return out


def median(values: List[float]) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    return s[len(s) // 2]


def detect_peaks(points: List[Dict[str, float]], threshold_db: float = 7.0, limit: int = 32) -> List[Dict[str, Any]]:
    if len(points) < 3:
        return []
    med = median([p["db"] for p in points])
    out: List[Dict[str, Any]] = []
    for i in range(1, len(points) - 1):
        p = points[i]
        if p["db"] >= points[i - 1]["db"] and p["db"] >= points[i + 1]["db"] and (p["db"] - med) >= threshold_db:
            out.append({
                "freq_hz": p["freq_hz"],
                "freq_mhz": round(p["freq_hz"] / 1e6, 6),
                "db": p["db"],
                "snr_median_db": round(p["db"] - med, 2)
            })
    out.sort(key=lambda x: x["db"], reverse=True)
    return out[:limit]


def spectrum_metrics(points: List[Dict[str, float]]) -> Dict[str, Any]:
    if not points:
        return {}
    vals = [p["db"] for p in points]
    med = median(vals)
    peak = max(points, key=lambda p: p["db"])
    active = [p for p in points if p["db"] >= med + 8.0]
    obw = active[-1]["freq_hz"] - active[0]["freq_hz"] if active else 0.0
    return {
        "peak_hz": peak["freq_hz"],
        "peak_mhz": round(peak["freq_hz"] / 1e6, 6),
        "peak_db": peak["db"],
        "noise_floor_db": round(med, 2),
        "obw_hz_est": round(obw, 3),
        "active_bins": len(active),
        "points": len(points),
    }


def sweep_core(start_hz: float, stop_hz: float, rbw_hz: float, points: int, use_hackrf: bool, timeout_s: int, seq: int = 0) -> Dict[str, Any]:
    if start_hz < 1_000_000 or stop_hz > 6_000_000_000 or stop_hz <= start_hz:
        raise HTTPException(status_code=400, detail="Range valido HackRF: 1 MHz - 6 GHz, stop > start")
    source = "SYNTHETIC"
    raw_status = None
    data: List[Dict[str, float]] = []
    if use_hackrf and shutil.which("hackrf_sweep"):
        raw = run_cmd(["hackrf_sweep", "-f", f"{start_hz/1e6:.6f}:{stop_hz/1e6:.6f}", "-w", str(int(rbw_hz)), "-1"], timeout=timeout_s)
        raw_status = {"returncode": raw["returncode"], "stderr_tail": raw["stderr"][-1500:]}
        if raw["returncode"] == 0:
            data = parse_sweep_csv(raw["stdout"], start_hz, stop_hz)
            if data:
                source = "REAL_HACKRF_SWEEP"
    if not data:
        data = synthetic_spectrum(start_hz, stop_hz, points, seq=seq)
    return {
        "ok": True,
        "version": "FINAL",
        "time": now_iso(),
        "seq": seq,
        "source": source,
        "start_hz": start_hz,
        "stop_hz": stop_hz,
        "center_hz": (start_hz + stop_hz) / 2,
        "span_hz": stop_hz - start_hz,
        "rbw_hz": rbw_hz,
        "points": data,
        "peaks": detect_peaks(data),
        "metrics": spectrum_metrics(data),
        "raw_status": raw_status,
    }


def file_rows(base: Path, suffixes: List[str], limit: int = 200) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for suffix in suffixes:
        for p in base.glob(f"*{suffix}"):
            if p.is_file():
                out.append({
                    "name": p.name,
                    "size": p.stat().st_size,
                    "mtime": datetime.fromtimestamp(p.stat().st_mtime, timezone.utc).isoformat(),
                    "sha256": sha256_file(p),
                })
    return sorted(out, key=lambda x: x["mtime"], reverse=True)[:limit]


class SweepRequest(BaseModel):
    start_hz: float = Field(1_000_000, ge=1_000_000, le=6_000_000_000)
    stop_hz: float = Field(6_000_000_000, ge=1_000_001, le=6_000_000_000)
    rbw_hz: float = Field(1_000_000, ge=2_445, le=5_000_000)
    points: int = Field(2400, ge=256, le=5000)
    use_hackrf: bool = False
    timeout_s: int = Field(90, ge=10, le=600)


class UavSweepRequest(BaseModel):
    profile_id: str = "ISM_24_UAV"
    iterations: int = Field(8, ge=1, le=80)
    threshold_db: float = Field(7.0, ge=1.0, le=60.0)
    use_hackrf: bool = False
    dwell_ms: int = Field(100, ge=0, le=3000)


@router.get("/console", response_class=HTMLResponse)
def console():
    p = ROOT / "frontend" / "public" / "rfpro_unified_console.html"
    if not p.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {p}")
    return HTMLResponse(p.read_text(encoding="utf-8", errors="ignore"))


@router.get("/state")
def state():
    expected = [
        "backend/routers/workbench_v580.py",
        "backend/routers/demod_v581.py",
        "backend/routers/workbench_v582.py",
        "backend/routers/master_v583.py",
        "backend/routers/uav_v584.py",
        "backend/routers/realtime_v585.py",
        "backend/routers/fullband_v586.py",
        "backend/routers/rfpro_final.py",
    ]
    return {
        "ok": True,
        "service": "rfpro-unified-instrument-console",
        "version": "FINAL",
        "mode": "RX_ONLY",
        "entrypoint": "/api/rfpro/console",
        "tools": {
            "hackrf_info": shutil.which("hackrf_info"),
            "hackrf_sweep": shutil.which("hackrf_sweep"),
            "hackrf_transfer": shutil.which("hackrf_transfer"),
            "python": shutil.which("python3"),
        },
        "modules": [{"path": x, "exists": (ROOT / x).exists()} for x in expected],
        "legacy_entrypoints": {
            "v580": "/api/v580/workbench/page",
            "v581": "/api/v581/demod/page",
            "v582": "/api/v582/workbench/page",
            "v583": "/api/v583/master/page",
            "v584": "/api/v584/uav/page",
            "v585": "/api/v585/realtime/page",
            "v586": "/api/v586/fullband/page",
        },
        "safety": {"tx": "disabled", "replay": "disabled", "deauth": "disabled", "evil_twin": "disabled"},
    }


@router.get("/runbook")
def runbook():
    return {
        "ok": True,
        "workflow": [
            "1. Spectrum dock: full-band or local span sweep.",
            "2. Use cursor A/B or peak search to define measurement span.",
            "3. Re-sweep with tighter RBW/VBW and trace mode.",
            "4. Use realtime dock for live waterfall/persistence.",
            "5. Use IQ/Demod dock to capture/analyze/demodulate using v581 where available.",
            "6. Use UAV dock for FHSS and burst RF witness measurements.",
            "7. Use Evidence dock to archive JSON/IQ/WAV with SHA256.",
        ],
        "principle": "One portal, multiple specialized docks; legacy routers remain mounted but are not the main user experience.",
    }


@router.post("/spectrum/sweep")
def spectrum_sweep(req: SweepRequest):
    out = sweep_core(req.start_hz, req.stop_hz, req.rbw_hz, req.points, req.use_hackrf, req.timeout_s)
    report = {k: v for k, v in out.items() if k != "points"}
    p = RT_DIR / f"rfpro_sweep_{int(time.time())}.json"
    p.write_text(json.dumps(report, indent=2), encoding="utf-8")
    out["report_file"] = p.name
    out["report_sha256"] = sha256_file(p)
    return out


@router.websocket("/ws/spectrum")
async def ws_spectrum(ws: WebSocket):
    await ws.accept()
    cfg: Dict[str, Any] = {"start_hz": 1_000_000, "stop_hz": 5_000_000, "rbw_hz": 100_000, "points": 1200, "fps": 2, "use_hackrf": False}
    seq = 0
    try:
        try:
            first = await asyncio.wait_for(ws.receive_text(), timeout=1.0)
            cfg.update(json.loads(first))
        except Exception:
            pass
        while True:
            try:
                frame = await asyncio.to_thread(
                    sweep_core,
                    float(cfg["start_hz"]),
                    float(cfg["stop_hz"]),
                    float(cfg["rbw_hz"]),
                    int(cfg["points"]),
                    bool(cfg["use_hackrf"]),
                    18,
                    seq,
                )
                await ws.send_json(frame)
                seq += 1
            except Exception as exc:
                await ws.send_json({"ok": False, "error": repr(exc), "time": now_iso()})
            try:
                msg = await asyncio.wait_for(ws.receive_text(), timeout=0.001)
                cfg.update(json.loads(msg))
            except asyncio.TimeoutError:
                pass
            except Exception:
                pass
            await asyncio.sleep(1.0 / max(0.2, min(10.0, float(cfg.get("fps", 2)))))
    except WebSocketDisconnect:
        return


@router.get("/uav/profiles")
def uav_profiles():
    return {"ok": True, "profiles": UAV_PROFILES}


@router.post("/uav/fhss")
def uav_fhss(req: UavSweepRequest):
    prof = UAV_PROFILES.get(req.profile_id)
    if not prof:
        raise HTTPException(status_code=404, detail="Profilo UAV non trovato")
    sequence: List[Dict[str, Any]] = []
    channels: Dict[str, Dict[str, Any]] = {}
    prev = None
    transitions = 0
    frames = []
    for i in range(req.iterations):
        frame = sweep_core(prof["start_hz"], prof["stop_hz"], prof["rbw_hz"], 1000, req.use_hackrf, 45, seq=i)
        frames.append({k: v for k, v in frame.items() if k != "points"})
        peaks = frame.get("peaks", [])
        if peaks:
            dom = peaks[0]
            bucket_hz = float(prof["bucket_hz"])
            ch = round(round(dom["freq_hz"] / bucket_hz) * bucket_hz, 3)
            key = str(int(ch))
            rec = channels.setdefault(key, {"channel_hz": ch, "channel_mhz": round(ch / 1e6, 6), "hits": 0, "max_db": -999.0})
            rec["hits"] += 1
            rec["max_db"] = max(rec["max_db"], float(dom["db"]))
            sequence.append({"idx": i, "channel_hz": ch, "channel_mhz": round(ch / 1e6, 6), "peak_db": dom["db"]})
            if prev is not None and ch != prev:
                transitions += 1
            prev = ch
        else:
            sequence.append({"idx": i, "channel_hz": None})
        if req.dwell_ms:
            time.sleep(req.dwell_ms / 1000.0)
    valid = [x for x in sequence if x.get("channel_hz") is not None]
    unique = len(channels)
    rate = transitions / max(1, len(valid) - 1)
    score = min(100.0, 30.0 * unique + 70.0 * rate)
    likelihood = "HIGH_FHSS_CANDIDATE" if unique >= 4 and rate > 0.35 else ("MEDIUM_HOPPING_OR_ADAPTIVE_LINK" if unique >= 2 and rate > 0.15 else ("FIXED_CHANNEL_OR_SINGLE_DOMINANT_CARRIER" if unique == 1 else "LOW_OR_INSUFFICIENT_DATA"))
    out = {
        "ok": True,
        "version": "FINAL",
        "profile_id": req.profile_id,
        "profile": prof,
        "iterations": req.iterations,
        "source_state": frames[-1].get("source") if frames else None,
        "unique_channels": unique,
        "transitions": transitions,
        "transition_rate": round(rate, 4),
        "fhss_score": round(score, 2),
        "likelihood": likelihood,
        "sequence": sequence,
        "channels": sorted(channels.values(), key=lambda x: x["hits"], reverse=True),
        "frames": frames,
        "note": "RF witness RX-only: misura hop/occupancy, non decodifica payload e non interferisce.",
    }
    p = UAV_DIR / f"rfpro_uav_fhss_{int(time.time())}.json"
    p.write_text(json.dumps(out, indent=2), encoding="utf-8")
    out["report_file"] = p.name
    out["report_sha256"] = sha256_file(p)
    return out


@router.get("/evidence/manifest")
def evidence_manifest():
    return {
        "ok": True,
        "iq": file_rows(IQ_DIR, [".iq8", ".iq", ".c8"], 200),
        "wav": file_rows(WAV_DIR, [".wav"], 200),
        "reports": file_rows(REPORT_DIR, [".json"], 300),
        "uav": file_rows(UAV_DIR, [".json"], 200),
        "realtime": file_rows(RT_DIR, [".json"], 200),
    }


@router.get("/file/{bucket}/{filename}")
def get_file(bucket: str, filename: str):
    buckets = {
        "iq": (IQ_DIR, "application/octet-stream"),
        "wav": (WAV_DIR, "audio/wav"),
        "reports": (REPORT_DIR, "application/json"),
        "uav": (UAV_DIR, "application/json"),
        "realtime": (RT_DIR, "application/json"),
    }
    if bucket not in buckets:
        raise HTTPException(status_code=404, detail="bucket non valido")
    base, media = buckets[bucket]
    p = (base / Path(filename).name).resolve()
    if str(p).startswith(str(base.resolve())) and p.exists():
        return FileResponse(p, media_type=media, filename=p.name)
    raise HTTPException(status_code=404, detail="file non trovato")
