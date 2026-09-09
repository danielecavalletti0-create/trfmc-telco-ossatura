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
from fastapi.responses import FileResponse, HTMLResponse
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

# ---------------------------------------------------------------------
# RF PRO v5.8.0 - Backend-served HTML page
# ---------------------------------------------------------------------
@router.get("/workbench/page", response_class=HTMLResponse)
def workbench_v580_page():
    page = ROOT / "frontend" / "public" / "signal_workbench_v580.html"
    if not page.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {page}")
    return HTMLResponse(page.read_text(encoding="utf-8", errors="ignore"))
