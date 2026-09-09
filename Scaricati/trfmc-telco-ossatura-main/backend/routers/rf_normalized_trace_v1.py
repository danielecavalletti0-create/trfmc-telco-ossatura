from __future__ import annotations

import math
import time
from typing import Any, Dict, List

from fastapi import APIRouter, Query

router = APIRouter(
    prefix="/api/rfpro/normalized",
    tags=["RF PRO Normalized Readonly Trace"],
)

try:
    from routers.rfpro_final import synthetic_spectrum as _rfpro_synthetic_spectrum
    from routers.rfpro_final import spectrum_metrics as _rfpro_spectrum_metrics
except Exception:  # pragma: no cover - import style varies by launcher
    try:
        from backend.routers.rfpro_final import synthetic_spectrum as _rfpro_synthetic_spectrum
        from backend.routers.rfpro_final import spectrum_metrics as _rfpro_spectrum_metrics
    except Exception:
        _rfpro_synthetic_spectrum = None
        _rfpro_spectrum_metrics = None


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _local_synthetic_trace(start_hz: float, stop_hz: float, points: int, seq: int) -> List[Dict[str, float]]:
    points = int(_clamp(points, 256, 4096))
    span = max(1.0, stop_hz - start_hz)
    carriers = [
        (0.17, 18.0, 0.006),
        (0.34, 33.0, 0.0045),
        (0.54, 24.0, 0.0065),
        (0.69, 41.0, 0.0038),
        (0.82, 28.0, 0.007),
    ]

    trace: List[Dict[str, float]] = []

    for i in range(points):
        x = i / max(1, points - 1)
        freq_hz = start_hz + span * x

        floor = -96.0
        ripple = 1.8 * math.sin(2.0 * math.pi * (x * 7.0 + seq * 0.013))
        noise_shape = 1.1 * math.sin(2.0 * math.pi * (x * 19.0 + 0.31))

        peak = 0.0
        for center, gain, width in carriers:
            drift = 0.002 * math.sin(seq * 0.021 + center * 11.0)
            peak += gain * math.exp(-((x - center - drift) ** 2) / (2.0 * width * width))

        dbm = floor + ripple + noise_shape + peak

        trace.append({
            "freq_hz": round(freq_hz, 3),
            "mhz": round(freq_hz / 1_000_000.0, 6),
            "dbm": round(dbm, 3),
        })

    return trace


def _normalize_points(data: Any, start_hz: float, stop_hz: float, points: int) -> List[Dict[str, float]]:
    if not isinstance(data, list):
        return []

    normalized: List[Dict[str, float]] = []
    span = max(1.0, stop_hz - start_hz)

    for idx, item in enumerate(data):
        if isinstance(item, dict):
            freq_hz = (
                item.get("freq_hz")
                or item.get("frequency_hz")
                or item.get("freq")
                or item.get("frequency")
            )
            mhz = item.get("mhz") or item.get("freq_mhz") or item.get("frequency_mhz")
            dbm = item.get("dbm") or item.get("power_dbm") or item.get("power") or item.get("y")

            if freq_hz is None and mhz is not None:
                freq_hz = float(mhz) * 1_000_000.0

            if freq_hz is None:
                freq_hz = start_hz + span * (idx / max(1, len(data) - 1))

            if dbm is None:
                continue

            normalized.append({
                "freq_hz": round(float(freq_hz), 3),
                "mhz": round(float(freq_hz) / 1_000_000.0, 6),
                "dbm": round(float(dbm), 3),
            })

        elif isinstance(item, (int, float)):
            freq_hz = start_hz + span * (idx / max(1, len(data) - 1))
            normalized.append({
                "freq_hz": round(freq_hz, 3),
                "mhz": round(freq_hz / 1_000_000.0, 6),
                "dbm": round(float(item), 3),
            })

    return normalized[:points]


def _percentile(values: List[float], q: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    idx = int(round((len(s) - 1) * q))
    idx = max(0, min(len(s) - 1, idx))
    return s[idx]


def _metrics(trace: List[Dict[str, float]], start_hz: float, stop_hz: float) -> Dict[str, Any]:
    powers = [float(p["dbm"]) for p in trace]
    if not powers:
        return {
            "snr_db": None,
            "evm_pct": None,
            "mer_db": None,
            "obw_mhz": None,
            "aclr_low_dbc": None,
            "aclr_high_dbc": None,
            "channel_power_dbm": None,
            "noise_floor_dbm": None,
            "crest_factor_db": None,
            "peak_dbm": None,
            "mean_dbm": None,
        }

    peak = max(powers)
    mean = sum(powers) / len(powers)
    noise = _percentile(powers, 0.20)
    snr = peak - noise

    threshold = noise + 6.0
    occupied = [trace[i]["freq_hz"] for i, p in enumerate(powers) if p >= threshold]
    if occupied:
        obw_mhz = (max(occupied) - min(occupied)) / 1_000_000.0
    else:
        obw_mhz = (stop_hz - start_hz) / 1_000_000.0 * 0.15

    linear = [10.0 ** (p / 20.0) for p in powers]
    rms = math.sqrt(sum(v * v for v in linear) / len(linear))
    crest = 20.0 * math.log10(max(linear) / rms) if rms > 0 else None

    # Synthetic but deterministic quality estimate from measured/derived SNR.
    evm_pct = max(1.0, min(18.0, 100.0 / max(8.0, snr)))
    mer_db = 20.0 * math.log10(100.0 / evm_pct)

    return {
        "snr_db": round(snr, 3),
        "evm_pct": round(evm_pct, 3),
        "mer_db": round(mer_db, 3),
        "obw_mhz": round(obw_mhz, 3),
        "aclr_low_dbc": round(noise - peak, 3),
        "aclr_high_dbc": round(noise - peak + 0.7, 3),
        "channel_power_dbm": round(peak, 3),
        "noise_floor_dbm": round(noise, 3),
        "crest_factor_db": None if crest is None else round(crest, 3),
        "peak_dbm": round(peak, 3),
        "mean_dbm": round(mean, 3),
    }


@router.get("/spectrum/trace")
def normalized_spectrum_trace(
    start_hz: float = Query(2_400_000_000.0, ge=1_000_000.0, le=6_000_000_000.0),
    stop_hz: float = Query(2_480_000_000.0, ge=1_000_001.0, le=6_000_000_000.0),
    points: int = Query(1200, ge=256, le=4096),
    seq: int = Query(0, ge=0, le=1_000_000),
) -> Dict[str, Any]:
    """
    Read-only normalized RF spectrum trace.

    Safety:
    - no TX;
    - no SDR control;
    - no hackrf_sweep execution;
    - deterministic synthetic/read-only trace when no capture is available.
    """
    if stop_hz <= start_hz:
        stop_hz = start_hz + 80_000_000.0

    points = int(_clamp(points, 256, 4096))

    source = "NORMALIZED_SYNTHETIC_READONLY"
    raw_trace: List[Dict[str, float]]

    if _rfpro_synthetic_spectrum is not None:
        try:
            raw = _rfpro_synthetic_spectrum(start_hz, stop_hz, points, seq=seq)
            raw_trace = _normalize_points(raw, start_hz, stop_hz, points)
            source = "RFPRO_FINAL_SYNTHETIC_REUSED_READONLY"
        except Exception:
            raw_trace = _local_synthetic_trace(start_hz, stop_hz, points, seq)
            source = "NORMALIZED_SYNTHETIC_READONLY_FALLBACK"
    else:
        raw_trace = _local_synthetic_trace(start_hz, stop_hz, points, seq)

    metrics = _metrics(raw_trace, start_hz, stop_hz)

    return {
        "ok": True,
        "version": "batch2f.normalized.trace.v1",
        "source": source,
        "mode": "read-only",
        "rx_only": True,
        "tx_enabled": False,
        "hackrf_control": False,
        "timestamp": time.time(),
        "center_mhz": round(((start_hz + stop_hz) / 2.0) / 1_000_000.0, 6),
        "span_mhz": round((stop_hz - start_hz) / 1_000_000.0, 6),
        "start_hz": round(start_hz, 3),
        "stop_hz": round(stop_hz, 3),
        "points": len(raw_trace),
        "trace": raw_trace,
        "metrics": metrics,
        "contract": {
            "trace_shape": [{"freq_hz": "number", "mhz": "number", "dbm": "number"}],
            "metrics_shape": {
                "snr_db": "number",
                "evm_pct": "number",
                "mer_db": "number",
                "obw_mhz": "number",
                "aclr_low_dbc": "number",
                "aclr_high_dbc": "number",
                "channel_power_dbm": "number",
                "noise_floor_dbm": "number",
            },
        },
    }
