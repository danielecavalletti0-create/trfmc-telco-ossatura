from __future__ import annotations

import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
import textwrap
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/rfpro", tags=["RF PRO External SDR Bridges"])

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
IQ_DIR = RUNTIME / "iq"
REPORT_DIR = RUNTIME / "reports"
INT_DIR = RUNTIME / "integrations"
GR_DIR = INT_DIR / "gnuradio"
SDRPP_DIR = INT_DIR / "sdrpp"
BRIDGE_DIR = INT_DIR / "bridges"
for d in (IQ_DIR, REPORT_DIR, INT_DIR, GR_DIR, SDRPP_DIR, BRIDGE_DIR):
    d.mkdir(parents=True, exist_ok=True)

PRESETS = [
    ("HF utility 1-4 MHz", 2500000, 3000000, "AM/USB/LSB"),
    ("Shortwave Broadcast 4.75-5.06 MHz", 4900000, 310000, "AM"),
    ("Shortwave Broadcast 5.9-6.2 MHz", 6050000, 300000, "AM"),
    ("27 MHz CB/ISM witness", 27200000, 600000, "AM/FM"),
    ("VHF 144 MHz witness", 145000000, 2000000, "NFM"),
    ("433 MHz SRD telemetry", 434000000, 2000000, "OOK/FSK/NFM"),
    ("868 MHz EU SRD", 866500000, 7000000, "FSK/OOK"),
    ("GNSS L1 witness", 1575420000, 51000000, "Interference witness"),
    ("2.4 GHz ISM/WiFi/UAV", 2442000000, 83500000, "WiFi/UAV"),
    ("5.8 GHz ISM/video/UAV", 5800000000, 150000000, "Video/UAV"),
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()


def run(cmd: List[str], timeout: int = 20) -> Dict[str, Any]:
    t0 = time.time()
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout, check=False)
        return {"cmd": cmd, "returncode": p.returncode, "stdout": p.stdout[-200000:], "stderr": p.stderr[-20000:], "elapsed_s": round(time.time() - t0, 3)}
    except subprocess.TimeoutExpired:
        return {"cmd": cmd, "returncode": 124, "stdout": "", "stderr": "timeout", "elapsed_s": round(time.time() - t0, 3)}
    except Exception as exc:
        return {"cmd": cmd, "returncode": -1, "stdout": "", "stderr": repr(exc), "elapsed_s": round(time.time() - t0, 3)}


def py_import_probe(module: str) -> Dict[str, Any]:
    code = f"import {module}; print(getattr({module}, '__version__', 'import-ok'))"
    return run([sys.executable, "-c", code], timeout=10)


def http_json(url: str, timeout: int = 5) -> Dict[str, Any]:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            raw = r.read(600000)
            text = raw.decode("utf-8", errors="replace")
            try:
                data = json.loads(text)
            except Exception:
                data = {"raw": text[:4000]}
            return {"ok": True, "status": getattr(r, "status", None), "url": url, "data": data}
    except Exception as exc:
        return {"ok": False, "url": url, "error": repr(exc)}


def latest_iq() -> str:
    files = sorted(list(IQ_DIR.glob("*.iq8")) + list(IQ_DIR.glob("*.iq")) + list(IQ_DIR.glob("*.c8")), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0].name if files else ""


@router.get("/bridges/state")
def bridges_state():
    tools = {
        "gnuradio_companion": shutil.which("gnuradio-companion"),
        "python": sys.executable,
        "SoapySDRUtil": shutil.which("SoapySDRUtil"),
        "sdrpp": shutil.which("sdrpp") or shutil.which("sdrpp-gtk"),
        "hackrf_info": shutil.which("hackrf_info"),
        "hackrf_sweep": shutil.which("hackrf_sweep"),
        "hackrf_transfer": shutil.which("hackrf_transfer"),
    }
    probes = {
        "gnuradio_python": py_import_probe("gnuradio"),
    }
    if shutil.which("SoapySDRUtil"):
        probes["soapysdr_info"] = run(["SoapySDRUtil", "--info"], timeout=15)
    mark_url = os.environ.get("MARKVII_URL", "")
    blue_url = os.environ.get("BLUEWAY_STATUS_URL", "")
    blue_json = os.environ.get("BLUEWAY_STATUS_JSON", "")
    return {
        "ok": True,
        "version": "BRIDGES_1",
        "time": now_iso(),
        "tools": tools,
        "probes": probes,
        "env": {
            "MARKVII_URL_set": bool(mark_url),
            "MARKVII_USERNAME_set": bool(os.environ.get("MARKVII_USERNAME")),
            "MARKVII_PASSWORD_set": bool(os.environ.get("MARKVII_PASSWORD")),
            "BLUEWAY_STATUS_URL_set": bool(blue_url),
            "BLUEWAY_STATUS_JSON_set": bool(blue_json),
        },
        "latest_iq": latest_iq(),
        "note": "Bridge passivo/RX-only: probe, export, lettura stato; nessuna azione TX/offensiva.",
    }


@router.get("/bridges/soapy/probe")
def soapy_probe():
    if not shutil.which("SoapySDRUtil"):
        return {"ok": False, "error": "SoapySDRUtil non trovato"}
    out = {
        "ok": True,
        "info": run(["SoapySDRUtil", "--info"], timeout=15),
        "find": run(["SoapySDRUtil", "--find"], timeout=20),
        "probe_hackrf": run(["SoapySDRUtil", "--probe=driver=hackrf"], timeout=20),
    }
    p = BRIDGE_DIR / f"soapy_probe_{int(time.time())}.json"
    p.write_text(json.dumps(out, indent=2), encoding="utf-8")
    out["report_file"] = p.name
    out["report_sha256"] = sha256_file(p)
    return out


class GnURadioExportReq(BaseModel):
    iq_file: str = ""
    sample_rate: int = Field(2_000_000, ge=10_000, le=50_000_000)
    freq_offset_hz: float = 0.0
    channel_bw_hz: float = Field(25_000, ge=100, le=10_000_000)
    decimation: int = Field(20, ge=1, le=10000)


@router.post("/bridges/gnuradio/export")
def gnuradio_export(req: GnURadioExportReq):
    iq_name = Path(req.iq_file or latest_iq()).name
    script = GR_DIR / "rfpro_gr_offline_channelizer.py"
    blueprint = GR_DIR / "rfpro_gnuradio_blueprint.json"
    content = f'''#!/usr/bin/env python3
# RF PRO GNU Radio offline channelizer blueprint
# RX-only / offline file processing. Generated: {now_iso()}
#
# Input IQ: {iq_name}
# Sample rate: {req.sample_rate}
# Frequency offset: {req.freq_offset_hz}
# Channel BW: {req.channel_bw_hz}
# Decimation: {req.decimation}
#
# Requires GNU Radio Python modules. This file is intentionally safe/offline:
# it reads IQ from file, frequency-translates + filters + decimates to extract
# a narrowband channel. Extend it with analog.wfm_rcv, analog.nbfm_rx,
# digital symbol blocks, or file sinks according to the lab scenario.

from gnuradio import gr, blocks, filter
from gnuradio.filter import firdes
import os

BASE = os.path.expanduser("~/Scaricati/trfmc_full_telco_ossatura_v0_2")
IQ_PATH = os.path.join(BASE, "runtime/workbench_v580/iq", "{iq_name}")
OUT_PATH = os.path.join(BASE, "runtime/workbench_v580/iq", "gnuradio_channelized_{int(time.time())}.c64")

SAMP_RATE = float({req.sample_rate})
FREQ_OFFSET = float({req.freq_offset_hz})
CHAN_BW = float({req.channel_bw_hz})
DECIM = int({req.decimation})

class rfpro_offline_channelizer(gr.top_block):
    def __init__(self):
        gr.top_block.__init__(self, "RF PRO offline channelizer")
        taps = firdes.low_pass(1.0, SAMP_RATE, CHAN_BW/2.0, CHAN_BW/4.0, firdes.WIN_HAMMING, 6.76)
        self.src = blocks.file_source(gr.sizeof_char, IQ_PATH, False)
        self.unpack = blocks.interleaved_char_to_complex(False, False)
        self.scale = blocks.multiply_const_cc(1.0/128.0)
        self.xlate = filter.freq_xlating_fir_filter_ccc(DECIM, taps, FREQ_OFFSET, SAMP_RATE)
        self.sink = blocks.file_sink(gr.sizeof_gr_complex, OUT_PATH, False)
        self.connect(self.src, self.unpack, self.scale, self.xlate, self.sink)

if __name__ == "__main__":
    tb = rfpro_offline_channelizer()
    tb.run()
    print("Wrote:", OUT_PATH)
'''
    script.write_text(content, encoding="utf-8")
    script.chmod(0o755)
    bp = {
        "ok": True,
        "version": "BRIDGES_1",
        "kind": "gnuradio_offline_channelizer",
        "script": script.name,
        "path": str(script),
        "iq_file": iq_name,
        "sample_rate": req.sample_rate,
        "freq_offset_hz": req.freq_offset_hz,
        "channel_bw_hz": req.channel_bw_hz,
        "decimation": req.decimation,
        "blocks": ["file_source", "interleaved_char_to_complex", "multiply_const_cc", "freq_xlating_fir_filter_ccc", "file_sink"],
        "safe": "offline RX/IQ only",
        "time": now_iso(),
    }
    blueprint.write_text(json.dumps(bp, indent=2), encoding="utf-8")
    bp["blueprint_file"] = blueprint.name
    bp["script_sha256"] = sha256_file(script)
    bp["blueprint_sha256"] = sha256_file(blueprint)
    return bp


@router.get("/bridges/sdrpp/export")
def sdrpp_export():
    csv_path = SDRPP_DIR / "rfpro_sdrpp_frequency_presets.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Name", "Frequency_Hz", "Span_Hz", "Mode", "Notes"])
        for name, center, span, mode in PRESETS:
            w.writerow([name, center, span, mode, "Generated by RF PRO unified console"])
    manifest = {
        "ok": True,
        "kind": "sdrpp_frequency_presets",
        "file": csv_path.name,
        "path": str(csv_path),
        "sha256": sha256_file(csv_path),
        "count": len(PRESETS),
        "time": now_iso(),
    }
    (SDRPP_DIR / "rfpro_sdrpp_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


@router.get("/bridges/markvii/preflight")
def markvii_preflight():
    base = os.environ.get("MARKVII_URL", "").rstrip("/")
    if not base:
        return {"ok": False, "error": "MARKVII_URL non impostata", "hint": "export MARKVII_URL='http://172.16.42.1:1471'"}
    endpoints = [
        "/api/recon/status",
        "/api/recon/scans",
        "/api/pineap/clients",
        "/api/pineap/previousclients",
        "/api/pineap/ssids",
        "/api/pineap/filters/client/mode",
        "/api/pineap/filters/ssid/mode",
    ]
    res = {ep: http_json(base + ep, timeout=6) for ep in endpoints}
    out = {
        "ok": True,
        "mode": "READ_ONLY_PREFLIGHT",
        "base": base,
        "auth_env": {
            "username_set": bool(os.environ.get("MARKVII_USERNAME")),
            "password_set": bool(os.environ.get("MARKVII_PASSWORD")),
        },
        "endpoints": res,
        "time": now_iso(),
    }
    p = BRIDGE_DIR / f"markvii_preflight_{int(time.time())}.json"
    p.write_text(json.dumps(out, indent=2), encoding="utf-8")
    out["report_file"] = p.name
    out["report_sha256"] = sha256_file(p)
    return out


@router.get("/bridges/blueway/state")
def blueway_state():
    url = os.environ.get("BLUEWAY_STATUS_URL", "")
    js = os.environ.get("BLUEWAY_STATUS_JSON", "")
    if url:
        return {"ok": True, "source": "BLUEWAY_STATUS_URL", "result": http_json(url, timeout=6)}
    if js:
        p = Path(js).expanduser()
        if p.exists():
            try:
                return {"ok": True, "source": "BLUEWAY_STATUS_JSON", "path": str(p), "data": json.loads(p.read_text(encoding="utf-8"))}
            except Exception as exc:
                return {"ok": False, "source": "BLUEWAY_STATUS_JSON", "path": str(p), "error": repr(exc)}
    return {"ok": False, "error": "Nessuna sorgente BlueWay configurata", "hint": "export BLUEWAY_STATUS_URL=... oppure BLUEWAY_STATUS_JSON=..."}


@router.get("/bridges/files")
def bridge_files():
    rows = []
    for base, bucket in [(GR_DIR, "gnuradio"), (SDRPP_DIR, "sdrpp"), (BRIDGE_DIR, "bridges")]:
        for p in base.glob("*"):
            if p.is_file():
                rows.append({"bucket": bucket, "name": p.name, "size": p.stat().st_size, "mtime": datetime.fromtimestamp(p.stat().st_mtime, timezone.utc).isoformat(), "sha256": sha256_file(p)})
    return {"ok": True, "files": sorted(rows, key=lambda x: x["mtime"], reverse=True)}


@router.get("/bridges/file/{bucket}/{filename}")
def get_bridge_file(bucket: str, filename: str):
    buckets = {"gnuradio": GR_DIR, "sdrpp": SDRPP_DIR, "bridges": BRIDGE_DIR}
    if bucket not in buckets:
        raise HTTPException(404, "bucket non valido")
    base = buckets[bucket]
    p = (base / Path(filename).name).resolve()
    if str(p).startswith(str(base.resolve())) and p.exists():
        return FileResponse(p, filename=p.name)
    raise HTTPException(404, "file non trovato")
