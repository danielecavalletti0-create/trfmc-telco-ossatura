from __future__ import annotations

import hashlib
import json
import math
import random
import shutil
import subprocess
import time
import wave
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/rfpro", tags=["RF PRO SDR Polish"])

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
IQ_DIR = RUNTIME / "iq"
WAV_DIR = RUNTIME / "wav"
REPORT_DIR = RUNTIME / "reports"
for d in (IQ_DIR, WAV_DIR, REPORT_DIR):
    d.mkdir(parents=True, exist_ok=True)

BAND_PLAN = [
    {"name": "HF utility", "start_hz": 1_000_000, "stop_hz": 4_000_000, "class": "hf"},
    {"name": "Shortwave Broadcast", "start_hz": 4_750_000, "stop_hz": 5_060_000, "class": "broadcast"},
    {"name": "Shortwave Broadcast", "start_hz": 5_900_000, "stop_hz": 6_200_000, "class": "broadcast"},
    {"name": "27 MHz CB/ISM witness", "start_hz": 26_900_000, "stop_hz": 27_500_000, "class": "srd"},
    {"name": "144 MHz VHF witness", "start_hz": 144_000_000, "stop_hz": 146_000_000, "class": "vhf"},
    {"name": "433 MHz SRD/telemetry", "start_hz": 433_000_000, "stop_hz": 435_000_000, "class": "srd"},
    {"name": "868 MHz EU SRD", "start_hz": 863_000_000, "stop_hz": 870_000_000, "class": "srd"},
    {"name": "GNSS L1 witness", "start_hz": 1_559_000_000, "stop_hz": 1_610_000_000, "class": "gnss"},
    {"name": "2.4 GHz ISM/Wi‑Fi/UAV", "start_hz": 2_400_000_000, "stop_hz": 2_483_500_000, "class": "ism"},
    {"name": "5.8 GHz ISM/video/UAV", "start_hz": 5_725_000_000, "stop_hz": 5_875_000_000, "class": "ism"},
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()


def run_cmd(cmd: List[str], timeout: int = 30) -> Dict[str, Any]:
    t0 = time.time()
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout, check=False)
        return {"cmd": cmd, "returncode": p.returncode, "stdout": p.stdout[-500000:], "stderr": p.stderr[-50000:], "elapsed_s": round(time.time() - t0, 3)}
    except subprocess.TimeoutExpired:
        return {"cmd": cmd, "returncode": 124, "stdout": "", "stderr": "timeout", "elapsed_s": round(time.time() - t0, 3)}
    except Exception as exc:
        return {"cmd": cmd, "returncode": -1, "stdout": "", "stderr": repr(exc), "elapsed_s": round(time.time() - t0, 3)}


def wav_tone(path: Path, freq: float = 750.0, seconds: float = 1.0, rate: int = 48000):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        for i in range(int(seconds * rate)):
            v = int(12000 * math.sin(2 * math.pi * freq * i / rate))
            w.writeframesraw(int(v).to_bytes(2, "little", signed=True))


class CaptureReq(BaseModel):
    center_hz: float = Field(6_101_000, ge=1_000_000, le=6_000_000_000)
    sample_rate: int = Field(2_000_000, ge=1_000_000, le=20_000_000)
    seconds: float = Field(2.0, ge=0.1, le=30.0)
    lna_gain: int = Field(16, ge=0, le=40)
    vga_gain: int = Field(32, ge=0, le=62)
    amp_enable: bool = False
    use_hackrf: bool = False


@router.get("/device/info")
def device_info():
    if not shutil.which("hackrf_info"):
        return {"ok": False, "source": "LOCAL_TOOL_MISSING", "error": "hackrf_info non trovato"}
    raw = run_cmd(["hackrf_info"], timeout=15)
    return {"ok": raw["returncode"] == 0, "source": "hackrf_info", "time": now_iso(), **raw}


@router.get("/bandplan")
def bandplan(start_hz: float = 1_000_000, stop_hz: float = 11_000_000):
    visible = [b for b in BAND_PLAN if b["stop_hz"] >= start_hz and b["start_hz"] <= stop_hz]
    return {"ok": True, "start_hz": start_hz, "stop_hz": stop_hz, "band_plan": visible}


@router.post("/iq/capture")
def iq_capture(req: CaptureReq):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    iq = IQ_DIR / f"rfpro_rx_{int(req.center_hz)}_{req.sample_rate}_{ts}.iq8"
    nbytes = int(req.sample_rate * req.seconds * 2)

    if req.use_hackrf and shutil.which("hackrf_transfer"):
        cmd = ["hackrf_transfer", "-r", str(iq), "-f", str(int(req.center_hz)), "-s", str(int(req.sample_rate)), "-n", str(nbytes), "-l", str(int(req.lna_gain)), "-g", str(int(req.vga_gain))]
        if req.amp_enable:
            cmd += ["-a", "1"]
        raw = run_cmd(cmd, timeout=max(20, int(req.seconds) + 25))
        if raw["returncode"] != 0 or not iq.exists() or iq.stat().st_size <= 0:
            raise HTTPException(status_code=500, detail={"message": "hackrf_transfer RX fallito", "raw": raw})
        source = "REAL_HACKRF_TRANSFER_RX"
    else:
        count = max(2048, min(nbytes, 40_000_000))
        with iq.open("wb") as f:
            for i in range(count // 2):
                phase = 2 * math.pi * 1000.0 * i / req.sample_rate
                iv = int(max(-127, min(127, 80 * math.cos(phase) + random.uniform(-8, 8))))
                qv = int(max(-127, min(127, 80 * math.sin(phase) + random.uniform(-8, 8))))
                f.write(iv.to_bytes(1, "little", signed=True))
                f.write(qv.to_bytes(1, "little", signed=True))
        source = "SYNTHETIC_IQ_WORKFLOW"

    wav = WAV_DIR / f"rfpro_monitor_{ts}.wav"
    wav_tone(wav, 700.0, 1.2, 48000)
    report = {
        "ok": True,
        "version": "SDR_POLISH",
        "source": source,
        "mode": "IQ_CAPTURE_RX_ONLY",
        "iq_file": iq.name,
        "iq_size": iq.stat().st_size,
        "iq_sha256": sha256_file(iq),
        "wav_file": wav.name,
        "wav_url": f"/api/rfpro/file/wav/{wav.name}",
        "center_hz": req.center_hz,
        "sample_rate": req.sample_rate,
        "seconds": req.seconds,
        "time": now_iso(),
    }
    rp = REPORT_DIR / f"rfpro_iq_capture_{ts}.json"
    rp.write_text(json.dumps(report, indent=2), encoding="utf-8")
    report["report_file"] = rp.name
    report["report_sha256"] = sha256_file(rp)
    return report


@router.get("/file/wav/{filename}")
def wav_file(filename: str):
    p = (WAV_DIR / Path(filename).name).resolve()
    if str(p).startswith(str(WAV_DIR.resolve())) and p.exists():
        return FileResponse(p, media_type="audio/wav", filename=p.name)
    raise HTTPException(status_code=404, detail="file non trovato")
