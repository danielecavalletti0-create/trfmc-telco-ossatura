#!/usr/bin/env bash
set -Eeuo pipefail
set +H

echo "============================================================"
echo "TRFMC / RF PRO v5.8.0 - SIGNAL WORKBENCH PATCH"
echo "RX-only: HackRF + GNU Radio style DSP + WiFi/Pineapple/Blueway read-only"
echo "Data: $(date)"
echo "============================================================"

BASE="$(pwd)"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BASE/runtime/backups/v580_signal_workbench_$TS"

mkdir -p "$BACKUP" \
  "$BASE/backend/routers" \
  "$BASE/frontend/public" \
  "$BASE/runtime/workbench_v580"/{iq,wav,reports,sweeps,rules,tmp}

touch "$BASE/backend/__init__.py" "$BASE/backend/routers/__init__.py"

echo
echo "[1/6] Backup leggero"
cp -a "$BASE/backend" "$BACKUP/backend" 2>/dev/null || true
cp -a "$BASE/frontend/public" "$BACKUP/frontend_public" 2>/dev/null || true

echo
echo "[2/6] Creo router FastAPI backend: backend/routers/workbench_v580.py"

cat > "$BASE/backend/routers/workbench_v580.py" <<'PY'
from __future__ import annotations

import csv
import hashlib
import json
import math
import os
import random
import shutil
import subprocess
import time
import wave
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/v580", tags=["RF PRO v5.8.0 Signal Workbench"])

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
IQ_DIR = RUNTIME / "iq"
WAV_DIR = RUNTIME / "wav"
REPORT_DIR = RUNTIME / "reports"
SWEEP_DIR = RUNTIME / "sweeps"
RULE_DIR = RUNTIME / "rules"
for p in (RUNTIME, IQ_DIR, WAV_DIR, REPORT_DIR, SWEEP_DIR, RULE_DIR):
    p.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------

def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def which(cmd: str) -> Optional[str]:
    return shutil.which(cmd)


def run_cmd(cmd: List[str], timeout: int = 20) -> Dict[str, Any]:
    started = time.time()
    try:
        p = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
        )
        return {
            "cmd": cmd,
            "returncode": p.returncode,
            "stdout": p.stdout[-20000:],
            "stderr": p.stderr[-20000:],
            "elapsed_s": round(time.time() - started, 3),
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "cmd": cmd,
            "returncode": 124,
            "stdout": (exc.stdout or "")[-20000:] if isinstance(exc.stdout, str) else "",
            "stderr": (exc.stderr or "")[-20000:] if isinstance(exc.stderr, str) else "timeout",
            "elapsed_s": round(time.time() - started, 3),
        }


def inside_runtime(path_name: str, base: Path) -> Path:
    name = Path(path_name).name
    p = (base / name).resolve()
    if not str(p).startswith(str(base.resolve())):
        raise HTTPException(status_code=400, detail="Invalid path")
    return p


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def synth_spectrum(start_hz: float, stop_hz: float, points: int = 900) -> List[Dict[str, float]]:
    start_hz = float(start_hz)
    stop_hz = float(stop_hz)
    if stop_hz <= start_hz:
        stop_hz = start_hz + 1_000_000
    points = int(clamp(points, 64, 4096))
    width = stop_hz - start_hz

    carriers = [
        (start_hz + width * 0.18, -54.0, width * 0.010),
        (start_hz + width * 0.37, -42.0, width * 0.006),
        (start_hz + width * 0.62, -49.0, width * 0.014),
        (start_hz + width * 0.81, -58.0, width * 0.004),
    ]

    out = []
    for i in range(points):
        f = start_hz + width * i / (points - 1)
        noise = -92 + 4 * math.sin(i / 23.0) + random.uniform(-2.0, 2.0)
        level = noise
        for cf, peak, sigma in carriers:
            g = math.exp(-0.5 * ((f - cf) / max(sigma, 1.0)) ** 2)
            level = 10 * math.log10(10 ** (level / 10) + 10 ** ((peak * g + noise * (1 - g)) / 10))
        out.append({"freq_hz": round(f, 3), "dbm": round(level, 2)})
    return out


def extract_peaks(points: List[Dict[str, float]], limit: int = 12) -> List[Dict[str, float]]:
    if len(points) < 3:
        return []
    peaks = []
    for i in range(1, len(points) - 1):
        if points[i]["dbm"] > points[i - 1]["dbm"] and points[i]["dbm"] > points[i + 1]["dbm"]:
            peaks.append(points[i])
    peaks.sort(key=lambda x: x["dbm"], reverse=True)
    return peaks[:limit]


def parse_hackrf_sweep_csv(text: str) -> List[Dict[str, float]]:
    """
    hackrf_sweep output normally contains:
    date, time, hz_low, hz_high, hz_bin_width, num_samples, dB, dB, dB...
    This parser is intentionally tolerant.
    """
    rows: List[Dict[str, float]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or "," not in line:
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 7:
            continue
        try:
            hz_low = float(parts[2])
            hz_high = float(parts[3])
            bin_hz = float(parts[4])
            levels = [float(x) for x in parts[6:] if x.strip()]
        except Exception:
            continue
        for idx, db in enumerate(levels):
            f = hz_low + idx * bin_hz
            if f <= hz_high:
                rows.append({"freq_hz": round(f, 3), "dbm": round(db, 2)})
    return rows


def load_iq_int8(path: Path):
    try:
        import numpy as np  # type: ignore
    except Exception:
        return None, "numpy non disponibile"

    data = np.fromfile(path, dtype=np.int8)
    if data.size < 4:
        return None, "file IQ vuoto o troppo piccolo"
    if data.size % 2:
        data = data[:-1]
    iq = data[0::2].astype(np.float32) / 128.0 + 1j * data[1::2].astype(np.float32) / 128.0
    return iq, None


def analyze_iq_file(path: Path, sample_rate: float = 2_000_000.0, fft_size: int = 4096) -> Dict[str, Any]:
    iq, err = load_iq_int8(path)
    if err:
        return {
            "status": "degraded",
            "message": err,
            "spectrum": synth_spectrum(-sample_rate / 2, sample_rate / 2, 512),
            "constellation": [],
            "metrics": {},
        }

    import numpy as np  # type: ignore

    fft_size = int(clamp(fft_size, 256, 65536))
    n = min(len(iq), fft_size)
    if n < 256:
        raise HTTPException(status_code=400, detail="IQ insufficiente per analisi")
    x = iq[:n]
    win = np.blackman(n).astype(np.float32)
    spec = np.fft.fftshift(np.fft.fft(x * win))
    pwr = 20 * np.log10(np.abs(spec) + 1e-12)
    freqs = np.linspace(-sample_rate / 2, sample_rate / 2, n)

    step = max(1, n // 1200)
    spectrum = [{"freq_hz": float(freqs[i]), "dbm": float(round(pwr[i], 2))} for i in range(0, n, step)]

    cstep = max(1, len(iq) // 1500)
    const = [{"i": float(np.real(v)), "q": float(np.imag(v))} for v in iq[0::cstep][:1500]]

    metrics = {
        "samples": int(len(iq)),
        "sample_rate": float(sample_rate),
        "duration_s": round(float(len(iq) / sample_rate), 6),
        "rms": round(float(np.sqrt(np.mean(np.abs(iq) ** 2))), 6),
        "dc_i": round(float(np.mean(np.real(iq))), 6),
        "dc_q": round(float(np.mean(np.imag(iq))), 6),
        "peak_mag": round(float(np.max(np.abs(iq))), 6),
    }
    return {"status": "ok", "spectrum": spectrum, "constellation": const, "metrics": metrics}


def write_wav_mono(path: Path, audio, audio_rate: int = 48000) -> None:
    import numpy as np  # type: ignore

    a = audio.astype(np.float32)
    a = a - np.mean(a)
    mx = float(np.max(np.abs(a)) + 1e-9)
    a = np.clip(a / mx, -1, 1)
    pcm = (a * 32767).astype(np.int16)

    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(audio_rate)
        w.writeframes(pcm.tobytes())


def demod_iq_to_wav(iq_path: Path, mode: str, sample_rate: float) -> Path:
    iq, err = load_iq_int8(iq_path)
    if err:
        raise HTTPException(status_code=500, detail=err)

    import numpy as np  # type: ignore

    mode = mode.lower().strip()
    sr = float(sample_rate)
    if sr < 100_000:
        sr = 2_000_000

    if mode in ("am", "ook", "ask"):
        audio = np.abs(iq)
    elif mode in ("nfm", "wfm", "fm", "fsk"):
        audio = np.angle(iq[1:] * np.conj(iq[:-1]))
    elif mode in ("usb", "lsb", "ssb", "cw"):
        audio = np.real(iq)
    else:
        raise HTTPException(status_code=400, detail=f"Modo demod non supportato in questa patch: {mode}")

    decim = max(1, int(sr // 48000))
    audio = audio[::decim]
    audio = audio[:48000 * 20]

    out = WAV_DIR / f"demod_{mode}_{int(time.time())}.wav"
    write_wav_mono(out, audio, 48000)
    return out


# ---------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------

class SweepRequest(BaseModel):
    start_hz: float = Field(..., gt=0)
    stop_hz: float = Field(..., gt=0)
    bin_hz: float = Field(100_000, ge=100, le=5_000_000)
    points: int = Field(900, ge=64, le=4096)
    use_hackrf: bool = True


class CaptureRequest(BaseModel):
    center_hz: float = Field(..., ge=1_000_000, le=6_000_000_000)
    sample_rate: float = Field(2_000_000, ge=500_000, le=20_000_000)
    seconds: float = Field(1.0, ge=0.05, le=10.0)
    amp_enable: int = Field(0, ge=0, le=1)
    lna_gain: int = Field(16, ge=0, le=40)
    vga_gain: int = Field(16, ge=0, le=62)


class AnalyzeRequest(BaseModel):
    filename: Optional[str] = None
    sample_rate: float = Field(2_000_000, ge=10_000, le=100_000_000)
    fft_size: int = Field(4096, ge=256, le=65536)


class DemodRequest(BaseModel):
    filename: Optional[str] = None
    mode: str = Field("nfm")
    sample_rate: float = Field(2_000_000, ge=10_000, le=100_000_000)


class EventRule(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    enabled: bool = True
    condition: Dict[str, Any] = Field(default_factory=dict)
    action: Dict[str, Any] = Field(default_factory=dict)


# ---------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------

@router.get("/workbench/state")
def state() -> Dict[str, Any]:
    tools = {
        "hackrf_info": which("hackrf_info"),
        "hackrf_sweep": which("hackrf_sweep"),
        "hackrf_transfer": which("hackrf_transfer"),
        "gnuradio_companion": which("gnuradio-companion"),
        "python3": which("python3"),
        "iw": which("iw"),
        "nmcli": which("nmcli"),
        "tshark": which("tshark"),
        "tcpdump": which("tcpdump"),
    }
    hackrf_info = None
    if tools["hackrf_info"]:
        hackrf_info = run_cmd(["hackrf_info"], timeout=8)

    return {
        "status": "online",
        "version": "5.8.0-rf-pro-signal-workbench",
        "rx_only": True,
        "safety": {
            "tx_disabled": True,
            "deauth_disabled": True,
            "evil_twin_disabled": True,
            "credential_capture_disabled": True,
            "note": "Console progettata per laboratorio autorizzato, RX-only e analisi/evidence.",
        },
        "paths": {
            "runtime": str(RUNTIME),
            "iq": str(IQ_DIR),
            "wav": str(WAV_DIR),
            "reports": str(REPORT_DIR),
        },
        "tools": tools,
        "hackrf_info": hackrf_info,
        "timestamp": utc_now(),
    }


@router.post("/workbench/sweep/window")
def sweep_window(req: SweepRequest) -> Dict[str, Any]:
    start = min(req.start_hz, req.stop_hz)
    stop = max(req.start_hz, req.stop_hz)

    if start < 1_000_000 or stop > 6_000_000_000:
        raise HTTPException(status_code=400, detail="HackRF range ammesso: 1 MHz - 6 GHz")
    if stop <= start:
        raise HTTPException(status_code=400, detail="stop_hz deve essere maggiore di start_hz")

    used_real = False
    raw = None
    points: List[Dict[str, float]] = []

    if req.use_hackrf and which("hackrf_sweep"):
        # hackrf_sweep usa frequenze in MHz per -f start:stop.
        f_arg = f"{start/1e6:.6f}:{stop/1e6:.6f}"
        cmd = ["hackrf_sweep", "-f", f_arg, "-w", str(int(req.bin_hz)), "-1"]
        raw = run_cmd(cmd, timeout=45)
        if raw["returncode"] == 0:
            points = parse_hackrf_sweep_csv(raw.get("stdout", ""))
            used_real = len(points) > 0

    if not points:
        points = synth_spectrum(start, stop, req.points)

    peaks = extract_peaks(points, 16)
    report = {
        "status": "ok",
        "real_hackrf": used_real,
        "start_hz": start,
        "stop_hz": stop,
        "bin_hz": req.bin_hz,
        "points": points,
        "peaks": peaks,
        "raw": raw,
        "timestamp": utc_now(),
    }
    out = SWEEP_DIR / f"sweep_{int(start)}_{int(stop)}_{int(time.time())}.json"
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    report["saved"] = str(out)
    return report


@router.post("/workbench/sweep/full")
def sweep_full() -> Dict[str, Any]:
    bands = [
        ("HF/VHF low", 1_000_000, 88_000_000),
        ("FM broadcast", 88_000_000, 108_000_000),
        ("Air/VHF", 108_000_000, 174_000_000),
        ("UHF low", 300_000_000, 520_000_000),
        ("ISM/SRD 868/915", 850_000_000, 930_000_000),
        ("GNSS/L-band witness", 1_000_000_000, 1_700_000_000),
        ("ISM 2.4", 2_400_000_000, 2_500_000_000),
        ("5GHz witness", 5_150_000_000, 5_900_000_000),
    ]
    results = []
    for name, a, b in bands:
        pts = synth_spectrum(a, b, 420)
        results.append({"name": name, "start_hz": a, "stop_hz": b, "peaks": extract_peaks(pts, 5), "points": pts})
    return {"status": "ok", "real_hackrf": False, "note": "Survey multi-banda sintetico/preview. Usa sweep/window per HackRF reale.", "bands": results, "timestamp": utc_now()}


@router.post("/workbench/iq/capture")
def iq_capture(req: CaptureRequest) -> Dict[str, Any]:
    if not which("hackrf_transfer"):
        raise HTTPException(status_code=501, detail="hackrf_transfer non trovato. Installa hackrf-tools oppure usa analisi simulata.")

    samples = int(req.sample_rate * req.seconds)
    samples = int(clamp(samples, 100_000, 120_000_000))
    out = IQ_DIR / f"hackrf_{int(req.center_hz)}_{int(req.sample_rate)}_{samples}_{int(time.time())}.iq8"

    cmd = [
        "hackrf_transfer",
        "-r", str(out),
        "-f", str(int(req.center_hz)),
        "-s", str(int(req.sample_rate)),
        "-n", str(samples * 2),
        "-a", str(int(req.amp_enable)),
        "-l", str(int(req.lna_gain)),
        "-g", str(int(req.vga_gain)),
    ]
    raw = run_cmd(cmd, timeout=max(10, int(req.seconds + 20)))
    ok = raw["returncode"] == 0 and out.exists() and out.stat().st_size > 0
    return {
        "status": "ok" if ok else "error",
        "rx_only": True,
        "file": out.name if out.exists() else None,
        "path": str(out) if out.exists() else None,
        "bytes": out.stat().st_size if out.exists() else 0,
        "sha256": sha256_file(out) if ok else None,
        "cmd": raw,
        "timestamp": utc_now(),
    }


@router.post("/workbench/iq/analyze")
def iq_analyze(req: AnalyzeRequest) -> Dict[str, Any]:
    if req.filename:
        path = inside_runtime(req.filename, IQ_DIR)
    else:
        files = sorted(IQ_DIR.glob("*.iq8"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not files:
            return {
                "status": "simulated",
                "message": "Nessun file IQ disponibile; ritorno spettro sintetico.",
                "spectrum": synth_spectrum(-req.sample_rate / 2, req.sample_rate / 2, 1024),
                "constellation": [],
                "metrics": {},
            }
        path = files[0]

    if not path.exists():
        raise HTTPException(status_code=404, detail="file IQ non trovato")

    result = analyze_iq_file(path, req.sample_rate, req.fft_size)
    result["file"] = path.name
    result["sha256"] = sha256_file(path)
    result["timestamp"] = utc_now()
    return result


@router.post("/workbench/demod/audio")
def demod_audio(req: DemodRequest) -> Dict[str, Any]:
    if req.filename:
        path = inside_runtime(req.filename, IQ_DIR)
    else:
        files = sorted(IQ_DIR.glob("*.iq8"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not files:
            raise HTTPException(status_code=404, detail="Nessun file IQ disponibile per demod audio")
        path = files[0]

    if not path.exists():
        raise HTTPException(status_code=404, detail="file IQ non trovato")

    wav_path = demod_iq_to_wav(path, req.mode, req.sample_rate)
    return {
        "status": "ok",
        "mode": req.mode,
        "source_iq": path.name,
        "wav_file": wav_path.name,
        "wav_url": f"/api/v580/workbench/wav/{wav_path.name}",
        "sha256": sha256_file(wav_path),
        "timestamp": utc_now(),
    }


@router.get("/workbench/wav/{filename}")
def get_wav(filename: str):
    path = inside_runtime(filename, WAV_DIR)
    if not path.exists():
        raise HTTPException(status_code=404, detail="WAV non trovato")
    return FileResponse(path, media_type="audio/wav", filename=path.name)


@router.post("/workbench/event-rule")
def save_rule(rule: EventRule) -> Dict[str, Any]:
    safe = "".join(c if c.isalnum() or c in "-_." else "_" for c in rule.name)
    path = RULE_DIR / f"{safe}.json"
    data = rule.model_dump()
    data["updated_at"] = utc_now()
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return {"status": "ok", "file": path.name, "rule": data}


@router.post("/workbench/evidence")
def evidence() -> Dict[str, Any]:
    files = []
    for d in (IQ_DIR, WAV_DIR, SWEEP_DIR, RULE_DIR):
        for p in sorted(d.glob("*"), key=lambda x: x.stat().st_mtime, reverse=True)[:30]:
            if p.is_file():
                files.append({
                    "name": p.name,
                    "path": str(p),
                    "size": p.stat().st_size,
                    "sha256": sha256_file(p),
                    "mtime": datetime.fromtimestamp(p.stat().st_mtime, timezone.utc).isoformat(),
                })
    report = {
        "status": "ok",
        "version": "5.8.0-rf-pro-signal-workbench",
        "rx_only": True,
        "generated_at": utc_now(),
        "files": files,
    }
    out = REPORT_DIR / f"evidence_{int(time.time())}.json"
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    report["report_file"] = out.name
    return report


@router.get("/workbench/files")
def files() -> Dict[str, Any]:
    result = {}
    for label, d in (("iq", IQ_DIR), ("wav", WAV_DIR), ("sweeps", SWEEP_DIR), ("reports", REPORT_DIR), ("rules", RULE_DIR)):
        result[label] = [
            {
                "name": p.name,
                "size": p.stat().st_size,
                "mtime": datetime.fromtimestamp(p.stat().st_mtime, timezone.utc).isoformat(),
            }
            for p in sorted(d.glob("*"), key=lambda x: x.stat().st_mtime, reverse=True)
            if p.is_file()
        ]
    return {"status": "ok", "files": result}


@router.get("/wifi/metadata")
def wifi_metadata(rescan: bool = Query(False, description="False di default: evita scansioni attive non richieste.")) -> Dict[str, Any]:
    out: Dict[str, Any] = {"status": "ok", "rx_only": True, "timestamp": utc_now(), "commands": {}}

    if which("iw"):
        out["commands"]["iw_dev"] = run_cmd(["iw", "dev"], timeout=6)

    if which("nmcli"):
        cmd = ["nmcli", "-t", "-f", "active,ssid,bssid,chan,rate,signal,security", "dev", "wifi", "list"]
        if rescan:
            cmd += ["--rescan", "yes"]
        else:
            cmd += ["--rescan", "no"]
        nm = run_cmd(cmd, timeout=20)
        rows = []
        for line in nm.get("stdout", "").splitlines():
            parts = line.split(":")
            if len(parts) >= 7:
                rows.append({
                    "active": parts[0],
                    "ssid": parts[1],
                    "bssid": parts[2],
                    "channel": parts[3],
                    "rate": parts[4],
                    "signal": parts[5],
                    "security": ":".join(parts[6:]),
                })
        out["commands"]["nmcli_wifi"] = nm
        out["aps"] = rows
    else:
        out["aps"] = []

    return out


@router.get("/markvii/recon")
def markvii_recon() -> Dict[str, Any]:
    """
    Bridge read-only generico.
    Configura:
      export MARKVII_RECON_URL='http://172.16.42.1:1471/api/...'
      export MARKVII_TOKEN='...'
    Non usa endpoint offensivi e non avvia campagne.
    """
    url = os.environ.get("MARKVII_RECON_URL", "").strip()
    token = os.environ.get("MARKVII_TOKEN", "").strip()
    if not url:
        return {
            "status": "not_configured",
            "message": "Imposta MARKVII_RECON_URL e MARKVII_TOKEN per leggere metadata Recon dal Mark VII.",
            "rx_only": True,
        }

    import urllib.request

    req = urllib.request.Request(url)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            body = r.read(2_000_000).decode("utf-8", "replace")
            try:
                data = json.loads(body)
            except Exception:
                data = {"raw": body}
            return {"status": "ok", "source": "markvii", "rx_only": True, "data": data, "timestamp": utc_now()}
    except Exception as exc:
        return {"status": "error", "source": "markvii", "error": str(exc), "timestamp": utc_now()}


@router.get("/blueway/status")
def blueway_status() -> Dict[str, Any]:
    """
    Bridge read-only.
    Può leggere:
      BLUEWAY_STATUS_URL=http://127.0.0.1:....
      oppure BLUEWAY_STATUS_JSON=/path/status.json
    """
    url = os.environ.get("BLUEWAY_STATUS_URL", "").strip()
    js = os.environ.get("BLUEWAY_STATUS_JSON", "").strip()

    if js:
        p = Path(js)
        if p.exists():
            try:
                return {"status": "ok", "source": "blueway-json", "data": json.loads(p.read_text(encoding="utf-8")), "timestamp": utc_now()}
            except Exception as exc:
                return {"status": "error", "source": "blueway-json", "error": str(exc)}

    if url:
        import urllib.request
        try:
            with urllib.request.urlopen(url, timeout=10) as r:
                body = r.read(2_000_000).decode("utf-8", "replace")
                try:
                    data = json.loads(body)
                except Exception:
                    data = {"raw": body}
                return {"status": "ok", "source": "blueway-url", "data": data, "timestamp": utc_now()}
        except Exception as exc:
            return {"status": "error", "source": "blueway-url", "error": str(exc)}

    return {
        "status": "not_configured",
        "message": "Imposta BLUEWAY_STATUS_URL oppure BLUEWAY_STATUS_JSON.",
        "timestamp": utc_now(),
    }


@router.get("/modem/cellular")
def modem_cellular() -> Dict[str, Any]:
    """
    Osservatore cellulare non invasivo.
    Legge solo informazioni esposte localmente da modem/router tramite comandi standard, se presenti.
    """
    out: Dict[str, Any] = {"status": "ok", "rx_only": True, "timestamp": utc_now(), "commands": {}}
    if which("mmcli"):
        out["commands"]["mmcli_list"] = run_cmd(["mmcli", "-L"], timeout=8)
    if which("qmicli"):
        out["commands"]["qmicli_present"] = {"path": which("qmicli")}
    if which("uqmi"):
        out["commands"]["uqmi_present"] = {"path": which("uqmi")}
    if not out["commands"]:
        out["status"] = "not_available"
        out["message"] = "Nessun tool modem trovato: mmcli/qmicli/uqmi."
    return out
PY

echo
echo "[3/6] Collego router al backend FastAPI principale"

MAIN_FILE=""
for f in "$BASE/backend/main.py" "$BASE/backend/main_engine.py" "$BASE/backend/app.py"; do
  if [ -f "$f" ] && grep -q "FastAPI" "$f"; then
    MAIN_FILE="$f"
    break
  fi
done

if [ -z "$MAIN_FILE" ]; then
  echo "WARN: non ho trovato automaticamente backend/main.py o main_engine.py con FastAPI."
  echo "      Router creato, ma dovrai includerlo manualmente."
else
  if ! grep -q "workbench_v580" "$MAIN_FILE"; then
    cat >> "$MAIN_FILE" <<'PY'

# ---------------------------------------------------------------------
# RF PRO v5.8.0 Signal Workbench router
# ---------------------------------------------------------------------
try:
    from backend.routers.workbench_v580 import router as workbench_v580_router
except Exception:
    try:
        from routers.workbench_v580 import router as workbench_v580_router
    except Exception as exc:
        workbench_v580_router = None
        print("WARN: RF PRO v5.8.0 router non caricato:", exc)

if workbench_v580_router is not None:
    try:
        app.include_router(workbench_v580_router)
        print("RF PRO v5.8.0 Signal Workbench router loaded")
    except Exception as exc:
        print("WARN: impossibile includere RF PRO v5.8.0 router:", exc)
PY
    echo "Router incluso in: $MAIN_FILE"
  else
    echo "Router già presente in: $MAIN_FILE"
  fi
fi

echo
echo "[4/6] Creo frontend pubblico: frontend/public/signal_workbench_v580.html"

cat > "$BASE/frontend/public/signal_workbench_v580.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>RF PRO v5.8.0 · Signal Workbench</title>
  <style>
    :root{
      --bg:#050812; --panel:#0b1324; --panel2:#111c31; --line:#1e3a5f;
      --txt:#d9f3ff; --muted:#7fa6bf; --acc:#22d3ee; --ok:#39ff88;
      --warn:#ffd166; --bad:#ff4d6d; --violet:#9b5cff;
    }
    *{box-sizing:border-box}
    body{
      margin:0; background:
        radial-gradient(circle at 10% 5%, rgba(34,211,238,.18), transparent 30%),
        radial-gradient(circle at 90% 10%, rgba(155,92,255,.15), transparent 26%),
        linear-gradient(180deg,#050812,#03050b 72%);
      color:var(--txt); font-family:Inter,Segoe UI,Roboto,Arial,sans-serif;
      overflow-x:hidden;
    }
    .top{
      position:sticky; top:0; z-index:10; border-bottom:1px solid var(--line);
      background:rgba(5,8,18,.92); backdrop-filter: blur(12px);
      padding:14px 18px; display:flex; gap:14px; align-items:center; justify-content:space-between;
    }
    .brand{display:flex; flex-direction:column; gap:2px}
    .brand h1{font-size:18px; letter-spacing:.12em; margin:0; text-transform:uppercase}
    .brand span{font-size:12px; color:var(--muted)}
    .pill{border:1px solid var(--line); background:rgba(17,28,49,.85); padding:7px 10px; border-radius:999px; color:var(--muted); font-size:12px}
    .pill.ok{color:var(--ok); border-color:rgba(57,255,136,.4)}
    .grid{
      display:grid; grid-template-columns: 1.35fr .85fr; gap:14px;
      padding:14px; max-width:1800px; margin:0 auto;
    }
    .panel{
      border:1px solid var(--line); background:linear-gradient(180deg,rgba(17,28,49,.94),rgba(8,14,27,.94));
      box-shadow:0 0 42px rgba(0,180,255,.08), inset 0 0 0 1px rgba(255,255,255,.025);
      border-radius:18px; overflow:hidden;
    }
    .panel h2{
      margin:0; padding:11px 13px; font-size:13px; letter-spacing:.09em; text-transform:uppercase;
      background:rgba(34,211,238,.06); border-bottom:1px solid var(--line);
      display:flex; justify-content:space-between; align-items:center;
    }
    .panel .body{padding:12px}
    .controls{
      display:grid; grid-template-columns:repeat(6,1fr); gap:8px; margin-bottom:10px;
    }
    label{display:flex; flex-direction:column; gap:4px; font-size:11px; color:var(--muted); text-transform:uppercase; letter-spacing:.06em}
    input,select{
      background:#06101d; border:1px solid #244766; color:var(--txt); border-radius:10px;
      padding:9px 10px; outline:none; font-size:13px;
    }
    button{
      background:linear-gradient(180deg,#0ea5e9,#075985); color:white; border:1px solid #38bdf8;
      border-radius:12px; padding:9px 10px; cursor:pointer; font-weight:700; letter-spacing:.04em;
    }
    button.secondary{background:linear-gradient(180deg,#1f2937,#0f172a); border-color:#334155}
    button.warn{background:linear-gradient(180deg,#b45309,#78350f); border-color:#f59e0b}
    button.good{background:linear-gradient(180deg,#059669,#064e3b); border-color:#34d399}
    button:disabled{opacity:.45; cursor:not-allowed}
    canvas{width:100%; display:block; background:#020617}
    #spectrum{height:360px; border-bottom:1px solid var(--line)}
    #waterfall{height:210px}
    .twocol{display:grid; grid-template-columns:1fr 1fr; gap:14px}
    .threecol{display:grid; grid-template-columns:1fr 1fr 1fr; gap:14px}
    .log{
      background:#030712; border:1px solid #1f3b57; border-radius:12px; padding:10px;
      height:210px; overflow:auto; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px; color:#a7f3d0;
      white-space:pre-wrap;
    }
    table{width:100%; border-collapse:collapse; font-size:12px}
    th,td{border-bottom:1px solid rgba(127,166,191,.18); padding:7px 6px; text-align:left}
    th{color:var(--acc); font-size:11px; text-transform:uppercase; letter-spacing:.06em}
    .cards{display:grid; grid-template-columns:repeat(4,1fr); gap:10px}
    .card{border:1px solid #1f3b57; background:#06101d; border-radius:13px; padding:10px}
    .card b{font-size:18px; color:var(--ok)}
    .card span{display:block; color:var(--muted); font-size:11px; text-transform:uppercase; margin-top:4px}
    .audio{width:100%; margin-top:8px}
    @media(max-width:1200px){.grid,.twocol,.threecol{grid-template-columns:1fr}.controls{grid-template-columns:repeat(2,1fr)}.cards{grid-template-columns:repeat(2,1fr)}}
  </style>
</head>
<body>
  <div class="top">
    <div class="brand">
      <h1>RF PRO v5.8.0 · Signal Workbench</h1>
      <span>HackRF RX · GNU Radio style DSP · IQ Capture · Audio Demod · WiFi/Pineapple/Blueway Read-Only</span>
    </div>
    <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
      <span id="apiState" class="pill">API: checking</span>
      <span class="pill ok">RX-ONLY</span>
      <span class="pill">NO TX · NO DEAUTH · NO EVIL TWIN</span>
    </div>
  </div>

  <div class="grid">
    <section class="panel">
      <h2>Live Spectrum / Waterfall <span id="spanInfo">—</span></h2>
      <div class="body">
        <div class="controls">
          <label>Start MHz<input id="startMHz" value="88"></label>
          <label>Stop MHz<input id="stopMHz" value="108"></label>
          <label>Center MHz<input id="centerMHz" value="100"></label>
          <label>Sample rate<input id="sampleRate" value="2000000"></label>
          <label>RBW / bin Hz<input id="binHz" value="100000"></label>
          <label>Demod
            <select id="demodMode">
              <option value="nfm">NFM</option>
              <option value="wfm">WFM</option>
              <option value="am">AM</option>
              <option value="usb">USB/SSB</option>
              <option value="lsb">LSB/SSB</option>
              <option value="ook">OOK/ASK envelope</option>
              <option value="fsk">FSK discriminator</option>
            </select>
          </label>
        </div>

        <div class="controls">
          <button onclick="sweepWindow()">SWEEP WINDOW</button>
          <button onclick="fullSurvey()" class="secondary">FULL SURVEY</button>
          <button onclick="lockPeak()" class="good">LOCK PEAK</button>
          <button onclick="captureIQ()" class="warn">CAPTURE IQ</button>
          <button onclick="analyzeIQ()">ANALYZE IQ</button>
          <button onclick="demodAudio()">DEMOD AUDIO</button>
        </div>

        <canvas id="spectrum" width="1400" height="360"></canvas>
        <canvas id="waterfall" width="1400" height="210"></canvas>
      </div>
    </section>

    <aside class="panel">
      <h2>Signal Inspector</h2>
      <div class="body">
        <div class="cards">
          <div class="card"><b id="mPeak">—</b><span>Peak dBm</span></div>
          <div class="card"><b id="mFreq">—</b><span>Peak MHz</span></div>
          <div class="card"><b id="mIQ">—</b><span>IQ file</span></div>
          <div class="card"><b id="mMode">—</b><span>Mode</span></div>
        </div>
        <h3 style="font-size:12px;color:var(--acc);letter-spacing:.08em;text-transform:uppercase;margin-top:14px">Peaks / Candidates</h3>
        <div style="height:250px;overflow:auto">
          <table>
            <thead><tr><th>#</th><th>Freq MHz</th><th>dBm</th><th>Action</th></tr></thead>
            <tbody id="peaksTable"></tbody>
          </table>
        </div>
        <audio id="audio" class="audio" controls></audio>
      </div>
    </aside>

    <section class="panel">
      <h2>IQ / Vector Lab</h2>
      <div class="body twocol">
        <canvas id="constellation" width="640" height="360"></canvas>
        <div>
          <div class="log" id="metrics">IQ metrics...</div>
        </div>
      </div>
    </section>

    <section class="panel">
      <h2>WiFi / Mark VII / Blueway / Modem Observers</h2>
      <div class="body">
        <div class="controls" style="grid-template-columns:repeat(4,1fr)">
          <button onclick="wifiMeta()">WIFI METADATA</button>
          <button onclick="markVII()" class="secondary">MARK VII RECON</button>
          <button onclick="blueway()" class="secondary">BLUEWAY STATUS</button>
          <button onclick="modem()" class="secondary">MODEM/CELLULAR</button>
        </div>
        <div class="log" id="observerLog">Observers ready...</div>
      </div>
    </section>

    <section class="panel">
      <h2>Evidence / Files</h2>
      <div class="body">
        <div class="controls" style="grid-template-columns:repeat(3,1fr)">
          <button onclick="evidence()" class="good">CREATE EVIDENCE</button>
          <button onclick="files()" class="secondary">LIST FILES</button>
          <button onclick="state()" class="secondary">REFRESH STATE</button>
        </div>
        <div class="log" id="log">Booting RF PRO v5.8.0...</div>
      </div>
    </section>
  </div>

<script>
const $ = id => document.getElementById(id);
let lastPoints = [];
let lastPeaks = [];
let lastIQ = null;
let selectedPeak = null;
let wfRows = [];

function log(msg, obj=null){
  const t = new Date().toISOString();
  $('log').textContent = `[${t}] ${msg}\n` + (obj ? JSON.stringify(obj,null,2).slice(0,6000) + "\n" : "") + $('log').textContent;
}
function obs(msg, obj=null){
  const t = new Date().toISOString();
  $('observerLog').textContent = `[${t}] ${msg}\n` + (obj ? JSON.stringify(obj,null,2).slice(0,6000) + "\n" : "") + $('observerLog').textContent;
}
async function api(path, opts={}){
  const r = await fetch(path, {headers:{'Content-Type':'application/json'}, ...opts});
  if(!r.ok){
    const tx = await r.text();
    throw new Error(`${r.status} ${tx}`);
  }
  return await r.json();
}
function mhz(v){return Number(v)/1e6}
function hzFromMHz(id){return Number($(id).value)*1e6}

function renderSpectrum(points){
  lastPoints = points || [];
  const c = $('spectrum'), ctx = c.getContext('2d');
  const w=c.width,h=c.height;
  ctx.clearRect(0,0,w,h);
  ctx.fillStyle="#020617"; ctx.fillRect(0,0,w,h);

  for(let i=0;i<10;i++){
    ctx.strokeStyle = i%5===0 ? "rgba(34,211,238,.20)" : "rgba(127,166,191,.08)";
    ctx.beginPath(); ctx.moveTo(0, i*h/10); ctx.lineTo(w, i*h/10); ctx.stroke();
  }
  for(let i=0;i<12;i++){
    ctx.strokeStyle="rgba(127,166,191,.08)";
    ctx.beginPath(); ctx.moveTo(i*w/12,0); ctx.lineTo(i*w/12,h); ctx.stroke();
  }
  if(!points.length) return;

  const minF = points[0].freq_hz, maxF = points[points.length-1].freq_hz;
  const minDb=-120, maxDb=-20;
  ctx.strokeStyle="#22d3ee"; ctx.lineWidth=2; ctx.beginPath();
  points.forEach((p,i)=>{
    const x = (p.freq_hz-minF)/(maxF-minF)*w;
    const y = h - ((p.dbm-minDb)/(maxDb-minDb))*h;
    if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
  });
  ctx.stroke();

  const pk = [...points].sort((a,b)=>b.dbm-a.dbm)[0];
  if(pk){
    const x=(pk.freq_hz-minF)/(maxF-minF)*w;
    const y=h-((pk.dbm-minDb)/(maxDb-minDb))*h;
    ctx.strokeStyle="#39ff88"; ctx.beginPath(); ctx.arc(x,y,6,0,Math.PI*2); ctx.stroke();
    ctx.fillStyle="#d9f3ff"; ctx.fillText(`${(pk.freq_hz/1e6).toFixed(6)} MHz  ${pk.dbm.toFixed(1)} dBm`, x+10, Math.max(18,y-10));
    $('mPeak').textContent = pk.dbm.toFixed(1);
    $('mFreq').textContent = (pk.freq_hz/1e6).toFixed(3);
  }

  $('spanInfo').textContent = `${(minF/1e6).toFixed(3)}–${(maxF/1e6).toFixed(3)} MHz`;
  addWaterfall(points);
}
function addWaterfall(points){
  const c=$('waterfall'), ctx=c.getContext('2d'), w=c.width,h=c.height;
  const row = points.map(p=>p.dbm);
  wfRows.unshift(row);
  wfRows = wfRows.slice(0, h);
  const img = ctx.createImageData(w,h);
  for(let y=0;y<h;y++){
    const src = wfRows[y] || [];
    for(let x=0;x<w;x++){
      const idx = Math.floor(x / w * Math.max(1,src.length-1));
      const db = src[idx] ?? -120;
      const v = Math.max(0, Math.min(1, (db + 110)/70));
      const off=(y*w+x)*4;
      img.data[off] = Math.floor(20 + 40*v);
      img.data[off+1] = Math.floor(40 + 210*v);
      img.data[off+2] = Math.floor(90 + 120*(1-v));
      img.data[off+3] = 255;
    }
  }
  ctx.putImageData(img,0,0);
}
function renderPeaks(peaks){
  lastPeaks = peaks || [];
  const tb=$('peaksTable'); tb.innerHTML="";
  lastPeaks.forEach((p,i)=>{
    const tr=document.createElement('tr');
    tr.innerHTML=`<td>${i+1}</td><td>${(p.freq_hz/1e6).toFixed(6)}</td><td>${p.dbm.toFixed(2)}</td><td><button class="secondary" onclick="selectPeak(${i})">LOCK</button></td>`;
    tb.appendChild(tr);
  });
}
function selectPeak(i){
  selectedPeak=lastPeaks[i];
  if(selectedPeak){
    $('centerMHz').value=(selectedPeak.freq_hz/1e6).toFixed(6);
    log("Peak selezionato come centro", selectedPeak);
  }
}
function lockPeak(){
  if(!lastPeaks.length){ log("Nessun peak disponibile. Esegui prima SWEEP WINDOW."); return; }
  selectPeak(0);
}

async function state(){
  try{
    const j=await api('/api/v580/workbench/state');
    $('apiState').textContent="API: online";
    $('apiState').className="pill ok";
    log("State RF Workbench", j);
  }catch(e){
    $('apiState').textContent="API: offline";
    $('apiState').className="pill";
    log("Errore state: "+e.message);
  }
}
async function sweepWindow(){
  try{
    const body={
      start_hz: hzFromMHz('startMHz'),
      stop_hz: hzFromMHz('stopMHz'),
      bin_hz: Number($('binHz').value),
      points: 1000,
      use_hackrf: true
    };
    log("Sweep window avviato", body);
    const j=await api('/api/v580/workbench/sweep/window',{method:'POST',body:JSON.stringify(body)});
    renderSpectrum(j.points || []);
    renderPeaks(j.peaks || []);
    log("Sweep completato", {real_hackrf:j.real_hackrf, saved:j.saved, peaks:j.peaks});
  }catch(e){log("Errore sweep: "+e.message);}
}
async function fullSurvey(){
  try{
    const j=await api('/api/v580/workbench/sweep/full',{method:'POST',body:'{}'});
    log("Full survey preview completato", j);
    if(j.bands && j.bands[0]){renderSpectrum(j.bands[0].points); renderPeaks(j.bands.flatMap(b=>b.peaks).slice(0,16));}
  }catch(e){log("Errore full survey: "+e.message);}
}
async function captureIQ(){
  try{
    const body={
      center_hz: Number($('centerMHz').value)*1e6,
      sample_rate: Number($('sampleRate').value),
      seconds: 1.0,
      amp_enable: 0,
      lna_gain: 16,
      vga_gain: 16
    };
    log("Capture IQ RX-only avviata", body);
    const j=await api('/api/v580/workbench/iq/capture',{method:'POST',body:JSON.stringify(body)});
    if(j.file){ lastIQ=j.file; $('mIQ').textContent=j.file.slice(0,12)+"…"; }
    log("Capture IQ completata", j);
  }catch(e){log("Errore capture IQ: "+e.message);}
}
async function analyzeIQ(){
  try{
    const body={filename:lastIQ, sample_rate:Number($('sampleRate').value), fft_size:4096};
    const j=await api('/api/v580/workbench/iq/analyze',{method:'POST',body:JSON.stringify(body)});
    renderSpectrum(j.spectrum || []);
    renderConstellation(j.constellation || []);
    $('metrics').textContent=JSON.stringify(j.metrics || j,null,2).slice(0,5000);
    log("IQ analyze completata", {status:j.status,file:j.file,sha256:j.sha256,metrics:j.metrics});
  }catch(e){log("Errore IQ analyze: "+e.message);}
}
function renderConstellation(points){
  const c=$('constellation'), ctx=c.getContext('2d'), w=c.width,h=c.height;
  ctx.fillStyle="#020617"; ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(127,166,191,.15)";
  ctx.beginPath(); ctx.moveTo(w/2,0); ctx.lineTo(w/2,h); ctx.moveTo(0,h/2); ctx.lineTo(w,h/2); ctx.stroke();
  ctx.strokeStyle="rgba(34,211,238,.15)";
  for(let r=60;r<Math.min(w,h)/2;r+=60){ctx.beginPath();ctx.arc(w/2,h/2,r,0,Math.PI*2);ctx.stroke();}
  ctx.fillStyle="#39ff88";
  points.forEach(p=>{
    const x=w/2 + p.i*w*.32;
    const y=h/2 - p.q*h*.32;
    if(x>=0&&x<w&&y>=0&&y<h) ctx.fillRect(x,y,2,2);
  });
}
async function demodAudio(){
  try{
    const body={filename:lastIQ, mode:$('demodMode').value, sample_rate:Number($('sampleRate').value)};
    $('mMode').textContent=body.mode.toUpperCase();
    const j=await api('/api/v580/workbench/demod/audio',{method:'POST',body:JSON.stringify(body)});
    $('audio').src=j.wav_url;
    log("Audio demod completata", j);
  }catch(e){log("Errore demod audio: "+e.message);}
}
async function wifiMeta(){try{const j=await api('/api/v580/wifi/metadata?rescan=false'); obs("WiFi metadata", j);}catch(e){obs("Errore WiFi: "+e.message);}}
async function markVII(){try{const j=await api('/api/v580/markvii/recon'); obs("Mark VII Recon bridge", j);}catch(e){obs("Errore Mark VII: "+e.message);}}
async function blueway(){try{const j=await api('/api/v580/blueway/status'); obs("Blueway bridge", j);}catch(e){obs("Errore Blueway: "+e.message);}}
async function modem(){try{const j=await api('/api/v580/modem/cellular'); obs("Modem/cellular observer", j);}catch(e){obs("Errore modem: "+e.message);}}
async function evidence(){try{const j=await api('/api/v580/workbench/evidence',{method:'POST',body:'{}'}); log("Evidence creato", j);}catch(e){log("Errore evidence: "+e.message);}}
async function files(){try{const j=await api('/api/v580/workbench/files'); log("Files", j);}catch(e){log("Errore files: "+e.message);}}

state();
setTimeout(sweepWindow, 600);
</script>
</body>
</html>
HTML

echo
echo "[5/6] Creo launcher e test"

cat > "$BASE/run_v580_signal_workbench.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

echo "============================================================"
echo "RF PRO v5.8.0 Signal Workbench"
echo "============================================================"
echo "Backend tipico: http://127.0.0.1:8000"
echo "Frontend Vite:  http://127.0.0.1:5173/signal_workbench_v580.html"
echo

if command -v hackrf_info >/dev/null 2>&1; then
  echo "[HackRF]"
  hackrf_info || true
else
  echo "WARN: hackrf_info non trovato. Installa hackrf-tools per usare HackRF reale."
fi

echo
echo "Avvio manuale consigliato, in due terminali:"
echo "  Terminale 1:"
echo "    cd $(pwd)"
echo "    python3 -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload"
echo "    # oppure, se il tuo backend storico usa main_engine:"
echo "    python3 -m uvicorn backend.main_engine:app --host 127.0.0.1 --port 8000 --reload"
echo
echo "  Terminale 2:"
echo "    cd $(pwd)/frontend"
echo "    npm run dev -- --host 127.0.0.1 --port 5173"
echo
echo "Apri:"
echo "  http://127.0.0.1:5173/signal_workbench_v580.html"
SH
chmod +x "$BASE/run_v580_signal_workbench.sh"

cat > "$BASE/test_v580_signal_workbench.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

API="${API:-http://127.0.0.1:8000}"

echo "== STATE =="
curl -s "$API/api/v580/workbench/state" | python3 -m json.tool | sed -n '1,120p'

echo
echo "== SWEEP WINDOW =="
curl -s -X POST "$API/api/v580/workbench/sweep/window" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":88000000,"stop_hz":108000000,"bin_hz":100000,"points":512,"use_hackrf":false}' \
  | python3 -m json.tool | sed -n '1,160p'

echo
echo "== FILES =="
curl -s "$API/api/v580/workbench/files" | python3 -m json.tool | sed -n '1,160p'
SH
chmod +x "$BASE/test_v580_signal_workbench.sh"

echo
echo "[6/6] Report finale"
REPORT="$BASE/runtime/workbench_v580/reports/install_v580_$TS.txt"
{
  echo "TRFMC / RF PRO v5.8.0 Signal Workbench install"
  echo "date=$(date)"
  echo "base=$BASE"
  echo "backup=$BACKUP"
  echo "backend_router=backend/routers/workbench_v580.py"
  echo "frontend_page=frontend/public/signal_workbench_v580.html"
  echo "launcher=run_v580_signal_workbench.sh"
  echo "test=test_v580_signal_workbench.sh"
  echo
  echo "RX-only safety:"
  echo "- TX disabilitato"
  echo "- deauth disabilitato"
  echo "- evil twin disabilitato"
  echo "- credential capture disabilitato"
  echo
  echo "URL:"
  echo "- http://127.0.0.1:5173/signal_workbench_v580.html"
} | tee "$REPORT"

echo
echo "============================================================"
echo "PATCH v5.8.0 COMPLETATA"
echo "Report: $REPORT"
echo "Avvio:"
echo "  ./run_v580_signal_workbench.sh"
echo "============================================================"
