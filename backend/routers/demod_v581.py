from __future__ import annotations
import hashlib, json, math, time, wave
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional, Tuple, List
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/v581", tags=["RF PRO v5.8.1 Demod PRO"])
ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
IQ_DIR = RUNTIME / "iq"
WAV_DIR = RUNTIME / "wav"
REPORT_DIR = RUNTIME / "reports"
for d in (IQ_DIR, WAV_DIR, REPORT_DIR):
    d.mkdir(parents=True, exist_ok=True)

try:
    import numpy as np
    HAS_NUMPY = True
except Exception:
    np = None
    HAS_NUMPY = False

def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def safe_file(name: Optional[str], base: Path, suffixes: Tuple[str, ...]) -> Path:
    if name:
        p = Path(name)
        if not p.is_absolute():
            p = base / p.name
        p = p.resolve()
    else:
        files: List[Path] = []
        for s in suffixes:
            files += list(base.glob(f"*{s}"))
        files = [x for x in files if x.is_file()]
        if not files:
            raise HTTPException(status_code=404, detail=f"Nessun file disponibile in {base}")
        p = sorted(files, key=lambda x: x.stat().st_mtime, reverse=True)[0].resolve()
    if not str(p).startswith(str(base.resolve())):
        raise HTTPException(status_code=400, detail="Path fuori runtime non ammesso")
    if not p.exists():
        raise HTTPException(status_code=404, detail=f"File non trovato: {p.name}")
    return p

def save_json(prefix: str, data: Dict[str, Any]) -> Dict[str, Any]:
    p = REPORT_DIR / f"{prefix}_{int(time.time())}.json"
    data["created_at"] = utc_now()
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    data["report_file"] = p.name
    data["report_sha256"] = sha256_file(p)
    return data

def load_iq8(path: Path, max_samples: Optional[int] = None):
    if not HAS_NUMPY:
        raise HTTPException(status_code=500, detail="numpy non disponibile")
    raw = np.fromfile(path, dtype=np.int8)
    if raw.size < 4:
        raise HTTPException(status_code=400, detail="file IQ troppo piccolo")
    if raw.size % 2:
        raw = raw[:-1]
    if max_samples:
        raw = raw[: int(max_samples) * 2]
    return raw[0::2].astype(np.float32) / 128.0 + 1j * raw[1::2].astype(np.float32) / 128.0

def write_iq8(path: Path, iq) -> None:
    x = np.empty(iq.size * 2, dtype=np.int8)
    x[0::2] = (np.clip(np.real(iq), -1, 0.999) * 127).astype(np.int8)
    x[1::2] = (np.clip(np.imag(iq), -1, 0.999) * 127).astype(np.int8)
    x.tofile(path)

def lowpass_taps(sr: float, cutoff_hz: float, ntaps: int = 161):
    cutoff = max(100.0, min(float(cutoff_hz), float(sr) * 0.45))
    if ntaps % 2 == 0:
        ntaps += 1
    n = np.arange(ntaps) - (ntaps - 1) / 2
    h = 2 * cutoff / sr * np.sinc(2 * cutoff / sr * n)
    h *= np.hamming(ntaps)
    h /= np.sum(h)
    return h.astype(np.float32)

def freq_shift(iq, sr: float, offset_hz: float):
    if abs(offset_hz) < 1e-9:
        return iq
    n = np.arange(iq.size, dtype=np.float64)
    return iq * np.exp(-1j * 2 * np.pi * float(offset_hz) * n / float(sr)).astype(np.complex64)

def channelize(iq, sr: float, offset_hz: float, channel_bw_hz: float, audio_mode: bool = False):
    x = freq_shift(iq, sr, offset_hz)
    bw = max(1000.0, float(channel_bw_hz))
    cutoff = min(sr * 0.45, max(bw / 2.0, 1000.0))
    taps = lowpass_taps(sr, cutoff, 161 if sr < 5_000_000 else 241)
    y = np.convolve(x, taps, mode="same")
    target = max(96_000.0 if audio_mode else 250_000.0, bw * 4.0)
    decim = max(1, int(math.floor(sr / target)))
    if decim > 1:
        y = y[::decim]
    return y.astype(np.complex64), float(sr / decim), int(decim), float(cutoff)

def spectrum(iq, sr: float, fft_size: int = 8192, max_points: int = 1600):
    n = min(int(fft_size), iq.size)
    n = max(256, 2 ** int(math.floor(math.log2(n))))
    x = iq[:n]
    sp = np.fft.fftshift(np.fft.fft(x * np.blackman(n)))
    pwr = 20 * np.log10(np.abs(sp) + 1e-12)
    freqs = np.fft.fftshift(np.fft.fftfreq(n, d=1.0 / sr))
    step = max(1, len(freqs) // max_points)
    pts = [{"freq_hz": round(float(freqs[i]), 3), "db": round(float(pwr[i]), 2)} for i in range(0, len(freqs), step)]
    return pts, freqs, pwr

def occupied_bw(freqs, pwr, drop_db: float = 20.0):
    mx = float(np.max(pwr))
    med = float(np.median(pwr))
    th = max(mx - drop_db, med + 6)
    mask = pwr >= th
    if not np.any(mask):
        return 0.0, None, None
    f = freqs[mask]
    return float(f[-1] - f[0]), float(f[0]), float(f[-1])

def spectral_flatness(iq) -> float:
    sp = np.fft.fft(iq[: min(iq.size, 8192)])
    ps = np.abs(sp) ** 2 + 1e-18
    return float(np.exp(np.mean(np.log(ps))) / np.mean(ps))

def iq_metrics(iq, sr: float, fft_size: int = 8192):
    pts, freqs, pwr = spectrum(iq, sr, fft_size=fft_size)
    peak_i = int(np.argmax(pwr))
    bw, low, high = occupied_bw(freqs, pwr)
    mag = np.abs(iq)
    i = np.real(iq)
    q = np.imag(iq)
    clip = np.mean((np.abs(i) > 0.98) | (np.abs(q) > 0.98)) * 100.0
    rms_i = float(np.sqrt(np.mean(i * i)))
    rms_q = float(np.sqrt(np.mean(q * q)))
    phase = np.unwrap(np.angle(iq[: min(iq.size, 200000)]))
    inst = np.diff(phase) * sr / (2 * np.pi)
    if bw < 12000:
        kind = "NARROW_CARRIER_CW_OR_SSB"
    elif bw < 25000:
        kind = "NARROWBAND_VOICE_AM_NFM"
    elif bw < 250000:
        kind = "NFM_OR_WIDEBAND_ANALOG"
    elif bw < 1500000:
        kind = "WIDEBAND_ANALOG_OR_SIMPLE_DIGITAL"
    else:
        kind = "OFDM_WIDEBAND_DIGITAL_OR_NOISE"
    return {
        "samples": int(iq.size),
        "sample_rate": float(sr),
        "duration_s": round(float(iq.size / sr), 6),
        "rms": round(float(np.sqrt(np.mean(np.abs(iq) ** 2))), 6),
        "mean_i": round(float(np.mean(i)), 6),
        "mean_q": round(float(np.mean(q)), 6),
        "dc_offset_mag": round(float(abs(np.mean(iq))), 6),
        "iq_gain_imbalance_db": round(float(20 * np.log10((rms_i + 1e-12) / (rms_q + 1e-12))), 4),
        "clip_percent": round(float(clip), 5),
        "papr_db": round(float(20 * np.log10((float(np.max(mag)) + 1e-12) / (float(np.sqrt(np.mean(mag * mag))) + 1e-12))), 3),
        "noise_floor_db": round(float(np.median(pwr)), 2),
        "peak_offset_hz": round(float(freqs[peak_i]), 3),
        "peak_db": round(float(pwr[peak_i]), 2),
        "occupied_bw_hz": round(float(bw), 3),
        "occupied_low_hz": round(low, 3) if low is not None else None,
        "occupied_high_hz": round(high, 3) if high is not None else None,
        "spectral_flatness": round(spectral_flatness(iq), 6),
        "inst_freq_std_hz": round(float(np.std(inst)) if inst.size else 0.0, 3),
        "classification_hint": kind,
    }

def normalize_audio(a):
    a = a.astype(np.float32)
    a = a - float(np.mean(a))
    mx = float(np.max(np.abs(a))) if a.size else 0.0
    if mx > 0:
        a = 0.88 * a / mx
    return a

def resample_to_audio(a, in_sr: float, out_sr: int = 48000):
    if a.size < 4:
        return a.astype(np.float32), int(in_sr)
    ratio = float(out_sr) / float(in_sr)
    if abs(ratio - 1.0) < 0.02:
        return a.astype(np.float32), int(round(in_sr))
    out_len = max(16, int(a.size * ratio))
    y = np.interp(np.linspace(0, a.size - 1, out_len), np.arange(a.size), a).astype(np.float32)
    return y, out_sr

def deemphasis(y, sr: float, tau: float):
    dt = 1.0 / sr
    alpha = dt / (tau + dt)
    out = np.empty_like(y, dtype=np.float32)
    acc = 0.0
    for idx, v in enumerate(y.astype(np.float32)):
        acc = acc + alpha * (float(v) - acc)
        out[idx] = acc
    return out

def demodulate(iq, sr: float, mode: str, audio_rate: int = 48000, cw_bfo_hz: float = 700.0):
    mode = mode.lower().strip()
    if mode in ("am", "ask", "ook", "ook_env"):
        audio = np.abs(iq)
    elif mode in ("nfm", "fm", "fsk", "fm_baseband"):
        audio = np.angle(iq[1:] * np.conj(iq[:-1]))
    elif mode == "wfm":
        audio = np.angle(iq[1:] * np.conj(iq[:-1]))
        audio = deemphasis(audio.astype(np.float32), sr, 50e-6)
    elif mode in ("usb", "ssb_usb"):
        audio = np.real(iq)
    elif mode in ("lsb", "ssb_lsb"):
        audio = -np.real(iq)
    elif mode == "cw":
        n = np.arange(iq.size, dtype=np.float64)
        audio = np.real(iq * np.exp(1j * 2 * np.pi * cw_bfo_hz * n / sr))
    else:
        raise HTTPException(status_code=400, detail=f"Demodulatore non supportato: {mode}")
    audio = normalize_audio(audio)
    audio, actual = resample_to_audio(audio, sr, audio_rate)
    return normalize_audio(audio), int(actual)

def audio_metrics(audio, sr: int):
    n = min(audio.size, 8192)
    if n < 256:
        return {}
    sp = np.fft.rfft(audio[:n] * np.hanning(n))
    p = 20 * np.log10(np.abs(sp) + 1e-12)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    peak = int(np.argmax(p))
    return {
        "audio_rate": int(sr),
        "audio_samples": int(audio.size),
        "audio_duration_s": round(float(audio.size / sr), 6),
        "audio_rms": round(float(np.sqrt(np.mean(audio * audio))), 6),
        "audio_peak_hz": round(float(f[peak]), 3),
        "audio_peak_db": round(float(p[peak]), 2),
        "audio_noise_floor_db": round(float(np.median(p)), 2),
    }

def write_wav(path: Path, audio, sr: int):
    pcm = (np.clip(audio, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(int(sr))
        w.writeframes(pcm.tobytes())

class AnalyzePlusRequest(BaseModel):
    filename: Optional[str] = None
    sample_rate: float = Field(2_000_000, ge=10_000, le=100_000_000)
    fft_size: int = Field(8192, ge=256, le=65536)
    max_seconds: float = Field(3.0, ge=0.05, le=60.0)

class ChannelDemodRequest(BaseModel):
    filename: Optional[str] = None
    sample_rate: float = Field(2_000_000, ge=10_000, le=100_000_000)
    freq_offset_hz: float = 0.0
    channel_bw_hz: float = Field(25_000, ge=500, le=20_000_000)
    mode: str = "nfm"
    audio_rate: int = Field(48_000, ge=8_000, le=192_000)
    max_seconds: float = Field(5.0, ge=0.05, le=60.0)
    cw_bfo_hz: float = Field(700.0, ge=50, le=3000)

class SyntheticRequest(BaseModel):
    mode: str = "nfm"
    sample_rate: float = Field(2_000_000, ge=100_000, le=20_000_000)
    seconds: float = Field(2.0, ge=0.1, le=20.0)
    tone_hz: float = Field(1000.0, ge=20, le=10_000)
    carrier_offset_hz: float = 0.0

@router.get("/demod/page", response_class=HTMLResponse)
def page():
    p = ROOT / "frontend" / "public" / "signal_demod_v581.html"
    if not p.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {p}")
    return HTMLResponse(p.read_text(encoding="utf-8", errors="ignore"))

@router.get("/demod/modes")
def modes():
    return {
        "ok": True,
        "version": "5.8.1",
        "rx_only": True,
        "demodulators": [
            {"id": "am", "audio": True, "use": "AM envelope"},
            {"id": "nfm", "audio": True, "use": "narrow FM voice"},
            {"id": "wfm", "audio": True, "use": "wide FM preview, de-emphasis 50 us"},
            {"id": "usb", "audio": True, "use": "SSB USB preview"},
            {"id": "lsb", "audio": True, "use": "SSB LSB preview"},
            {"id": "cw", "audio": True, "use": "CW con BFO locale"},
            {"id": "ook", "audio": "diagnostic", "use": "OOK/ASK envelope"},
            {"id": "fsk", "audio": "diagnostic", "use": "FSK/FM discriminator"},
        ],
        "digital_note": "Wi-Fi/DVB/DAB/cellular/OFDM non diventano audio analogico utile; richiedono decoder digitale/protocollo dedicato.",
    }

@router.post("/iq/selftest_signal")
def selftest_signal(req: SyntheticRequest):
    if not HAS_NUMPY:
        raise HTTPException(status_code=500, detail="numpy non disponibile")
    sr = float(req.sample_rate)
    n = int(sr * float(req.seconds))
    t = np.arange(n, dtype=np.float64) / sr
    tone = np.sin(2 * np.pi * float(req.tone_hz) * t)
    mode = req.mode.lower().strip()
    if mode == "am":
        sig = (0.55 + 0.35 * tone) * np.exp(1j * 2 * np.pi * req.carrier_offset_hz * t)
    elif mode in ("nfm", "wfm", "fm"):
        dev = 5_000.0 if mode == "nfm" else 75_000.0
        phase = 2 * np.pi * (req.carrier_offset_hz * t + dev * np.cumsum(tone) / sr)
        sig = 0.75 * np.exp(1j * phase)
    elif mode == "ook":
        sig = ((np.sin(2 * np.pi * 20 * t) > 0).astype(np.float32)) * 0.8 * np.exp(1j * 2 * np.pi * req.carrier_offset_hz * t)
    elif mode == "fsk":
        data = np.sign(np.sin(2 * np.pi * 25 * t))
        phase = 2 * np.pi * np.cumsum(req.carrier_offset_hz + data * 3000.0) / sr
        sig = 0.75 * np.exp(1j * phase)
    else:
        sig = 0.65 * tone.astype(np.float32).astype(np.complex64)
    iq = (sig + 0.03 * (np.random.randn(n) + 1j * np.random.randn(n))).astype(np.complex64)
    out = IQ_DIR / f"selftest_{mode}_{int(sr)}sps_{int(time.time())}.iq8"
    write_iq8(out, iq)
    return {"ok": True, "version": "5.8.1", "file": out.name, "path": str(out), "sha256": sha256_file(out), "sample_rate": sr, "seconds": req.seconds, "mode": mode}

@router.post("/iq/analyze_plus")
def analyze_plus(req: AnalyzePlusRequest):
    p = safe_file(req.filename, IQ_DIR, (".iq8", ".iq", ".c8"))
    iq = load_iq8(p, max_samples=int(req.sample_rate * req.max_seconds))
    pts, freqs, pwr = spectrum(iq, req.sample_rate, req.fft_size)
    metrics = iq_metrics(iq, req.sample_rate, req.fft_size)
    med = float(np.median(pwr))
    peaks = [{"offset_hz": round(float(freqs[int(idx)]), 3), "db": round(float(pwr[int(idx)]), 2), "snr_over_median_db": round(float(pwr[int(idx)] - med), 2)} for idx in np.argsort(pwr)[-12:][::-1]]
    return save_json("iq_analyze_plus", {"ok": True, "version": "5.8.1", "file": p.name, "file_sha256": sha256_file(p), "sample_rate": req.sample_rate, "fft_size": req.fft_size, "metrics": metrics, "peaks": peaks, "spectrum": pts})

@router.post("/iq/channelize_demod")
def channelize_demod(req: ChannelDemodRequest):
    p = safe_file(req.filename, IQ_DIR, (".iq8", ".iq", ".c8"))
    iq = load_iq8(p, max_samples=int(req.sample_rate * req.max_seconds))
    ch, ch_sr, decim, cutoff = channelize(iq, req.sample_rate, req.freq_offset_hz, req.channel_bw_hz, audio_mode=True)
    audio, audio_sr = demodulate(ch, ch_sr, req.mode, req.audio_rate, req.cw_bfo_hz)
    wav = WAV_DIR / f"v581_{req.mode}_{Path(p).stem}_{int(time.time())}.wav"
    write_wav(wav, audio, audio_sr)
    out = {
        "ok": True,
        "version": "5.8.1",
        "rx_only": True,
        "source_iq": p.name,
        "source_sha256": sha256_file(p),
        "mode": req.mode,
        "sample_rate_in": req.sample_rate,
        "freq_offset_hz": req.freq_offset_hz,
        "channel_bw_hz": req.channel_bw_hz,
        "channel_sample_rate": ch_sr,
        "decimation": decim,
        "fir_cutoff_hz": cutoff,
        "wav_file": wav.name,
        "wav_url": f"/api/v581/iq/file/{wav.name}",
        "wav_sha256": sha256_file(wav),
        "audio_metrics": audio_metrics(audio, audio_sr),
        "channel_metrics": iq_metrics(ch, ch_sr, min(8192, max(256, int(ch.size // 2)))),
        "statement": "RX-only offline DSP: frequency shift + FIR low-pass + decimation + audio demod.",
    }
    return save_json("channelize_demod", out)

@router.get("/iq/files")
def files():
    def rows(base: Path, exts: Tuple[str, ...]):
        out = []
        for ext in exts:
            for p in base.glob(f"*{ext}"):
                if p.is_file():
                    out.append({"name": p.name, "size": p.stat().st_size, "mtime": datetime.fromtimestamp(p.stat().st_mtime, timezone.utc).isoformat(), "sha256": sha256_file(p)})
        return sorted(out, key=lambda x: x["mtime"], reverse=True)
    return {"ok": True, "iq": rows(IQ_DIR, (".iq8", ".iq", ".c8")), "wav": rows(WAV_DIR, (".wav",)), "reports": rows(REPORT_DIR, (".json",))}

@router.get("/iq/file/{filename}")
def get_file(filename: str):
    for base, media in ((WAV_DIR, "audio/wav"), (IQ_DIR, "application/octet-stream"), (REPORT_DIR, "application/json")):
        p = (base / Path(filename).name).resolve()
        if str(p).startswith(str(base.resolve())) and p.exists():
            return FileResponse(p, media_type=media, filename=p.name)
    raise HTTPException(status_code=404, detail="file non trovato")

@router.get("/iq/last_report")
def last_report():
    reports = sorted(REPORT_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not reports:
        return {"ok": False, "message": "nessun report disponibile"}
    return json.loads(reports[0].read_text(encoding="utf-8"))

@router.get("/selftest")
def selftest():
    return {"ok": True, "version": "5.8.1", "numpy": HAS_NUMPY, "iq_dir": str(IQ_DIR), "wav_dir": str(WAV_DIR), "report_dir": str(REPORT_DIR)}
