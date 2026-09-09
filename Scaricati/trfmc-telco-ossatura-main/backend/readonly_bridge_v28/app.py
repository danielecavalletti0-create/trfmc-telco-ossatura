from __future__ import annotations

import json
import os
import platform
import re
import socket
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime"

APP_VERSION = "TRFMC_READONLY_BACKEND_BRIDGE_V28"

app = FastAPI(
    title="TRFMC Read-only Backend Bridge V28",
    version="28.0",
    description="Read-only operational bridge for TRFMC portal. No start/stop/mutation endpoints.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5173",
        "http://127.0.0.1:4173",
        "http://127.0.0.1:4180",
        "http://127.0.0.1:4181",
        "http://127.0.0.1:4182",
    ],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def run_cmd(cmd: list[str], timeout: float = 2.0) -> dict[str, Any]:
    try:
        p = subprocess.run(
            cmd,
            cwd=str(ROOT),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
        return {
            "cmd": cmd,
            "returncode": p.returncode,
            "stdout": p.stdout.strip(),
            "stderr": p.stderr.strip(),
            "ok": p.returncode == 0,
        }
    except Exception as exc:
        return {
            "cmd": cmd,
            "returncode": -1,
            "stdout": "",
            "stderr": repr(exc),
            "ok": False,
        }


def path_exists(path: str | Path) -> bool:
    return Path(path).expanduser().exists()


def latest_json(link: Path) -> dict[str, Any] | None:
    try:
        p = link.resolve()
        if p.is_dir():
            p = p / "summary.json"
        if p.exists():
            return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return None
    return None


def service_state_user(name: str) -> dict[str, Any]:
    active = run_cmd(["systemctl", "--user", "is-active", name])
    enabled = run_cmd(["systemctl", "--user", "is-enabled", name])
    return {
        "service": name,
        "active": active["stdout"] or "unknown",
        "enabled": enabled["stdout"] or "unknown",
        "active_ok": active["returncode"] == 0,
        "enabled_ok": enabled["returncode"] == 0,
    }


def process_probe(pattern: str) -> dict[str, Any]:
    """
    Robust read-only process probe.

    V30 hygiene:
    - avoid pgrep self/curl false positives;
    - inspect process table directly;
    - for open5gs, match real open5gs daemon names only;
    - for UERANSIM, match real nr-gnb/nr-ue processes only.
    """
    out = run_cmd(["ps", "-eo", "pid=,comm=,args="], timeout=2)
    lines: list[str] = []

    excluded_comms = {
        "curl", "grep", "pgrep", "awk", "sed", "head", "tail",
        "python3", "python", "uvicorn", "nginx", "bash", "sh",
    }

    raw_pattern = pattern
    lower_pattern = pattern.lower()

    for raw in out["stdout"].splitlines():
        raw = raw.strip()
        if not raw:
            continue

        parts = raw.split(None, 2)
        if len(parts) < 2:
            continue

        pid = parts[0]
        comm = parts[1]
        args = parts[2] if len(parts) > 2 else ""

        comm_l = comm.lower()
        args_l = args.lower()

        if comm_l in excluded_comms:
            continue

        # Specific Open5GS daemon hygiene.
        if lower_pattern == "open5gs":
            if comm_l.startswith("open5gs-") or re.search(r'(^|/|\\s)open5gs-[a-z0-9_-]+d?(\\s|$)', args_l):
                lines.append(raw)
            continue

        # Specific UERANSIM hygiene.
        if "nr-gnb" in lower_pattern or "nr-ue" in lower_pattern or "ueransim" in lower_pattern:
            if comm_l in {"nr-gnb", "nr-ue"} or re.search(r'(^|/|\\s)(nr-gnb|nr-ue)(\\s|$)', args_l) or "ueransim/build/nr-" in args_l:
                lines.append(raw)
            continue

        # Generic safe regex mode, excluding pure probe commands.
        try:
            if re.search(raw_pattern, comm, re.I) or re.search(raw_pattern, args, re.I):
                lines.append(raw)
        except re.error:
            if raw_pattern.lower() in comm_l or raw_pattern.lower() in args_l:
                lines.append(raw)

    return {
        "pattern": pattern,
        "count": len(lines),
        "lines": lines[:20],
        "running": len(lines) > 0,
        "probe_hygiene": "v30_no_curl_no_pgrep_no_self_match",
    }



def ss_probe() -> list[dict[str, Any]]:
    out = run_cmd(["ss", "-ltnp"], timeout=2)
    rows = []
    for line in out["stdout"].splitlines():
        if any(f":{p}" in line for p in ("8000", "8090", "4180", "4181", "4182", "5173", "4173")):
            rows.append({"line": line})
    return rows


def find_first(paths: list[str]) -> str | None:
    for p in paths:
        pp = Path(p).expanduser()
        if pp.exists():
            return str(pp)
    return None


def list_recent_dirs(base: Path, limit: int = 20) -> list[dict[str, Any]]:
    if not base.exists():
        return []
    items = []
    for p in base.iterdir():
        try:
            st = p.stat()
        except OSError:
            continue
        items.append({
            "name": p.name,
            "path": str(p),
            "is_dir": p.is_dir(),
            "mtime": st.st_mtime,
            "mtime_iso": datetime.fromtimestamp(st.st_mtime, timezone.utc).isoformat(),
        })
    return sorted(items, key=lambda x: x["mtime"], reverse=True)[:limit]


def common_status() -> dict[str, Any]:
    return {
        "status": "ok",
        "source": APP_VERSION,
        "mode": "read-only",
        "timestamp": now_iso(),
        "host": socket.gethostname(),
        "project_root": str(ROOT),
    }


@app.get("/api/health")
def api_health() -> dict[str, Any]:
    data = common_status()
    data.update({
        "python": platform.python_version(),
        "platform": platform.platform(),
        "runtime_foundation": {
            "v25": latest_json(RUNTIME / "quality" / "latest_boot_persistence_verification_pack_v25"),
            "v26": latest_json(RUNTIME / "quality" / "latest_systemd_unit_hygiene_pack_v26"),
            "v27": latest_json(RUNTIME / "quality" / "latest_portal_contract_audit_v27"),
        },
    })
    return data


@app.get("/api/mission/status")
@app.get("/api/mission")
def api_mission_status() -> dict[str, Any]:
    data = common_status()
    data.update({
        "mission": "TRFMC RF/Telco/Cyber Digital Twin Lab",
        "runtime_modes": {
            "static_4180": service_state_user("trfmc-static-4180.service"),
            "api_proxy_4181": service_state_user("trfmc-api-proxy-4181.service"),
            "clean_offline_4182": service_state_user("trfmc-clean-offline-4182.service"),
        },
        "ports": ss_probe(),
        "decision": "runtime foundation complete; backend bridge read-only active",
    })
    return data


@app.get("/api/runtime/services")
def api_runtime_services() -> dict[str, Any]:
    data = common_status()
    data.update({
        "systemd_user": [
            service_state_user("trfmc-static-4180.service"),
            service_state_user("trfmc-api-proxy-4181.service"),
            service_state_user("trfmc-clean-offline-4182.service"),
        ],
        "processes": {
            "nginx": process_probe("nginx"),
            "uvicorn": process_probe("uvicorn"),
            "open5gs": process_probe("open5gs"),
            "ueransim": process_probe("nr-gnb|nr-ue|UERANSIM"),
            "vite": process_probe("vite"),
        },
        "listening": ss_probe(),
    })
    return data


@app.get("/api/core/open5gs/status")
@app.get("/api/core-live/status")
@app.get("/api/core-live/health")
@app.get("/api/core-live")
@app.get("/api/telco-mns/status")
@app.get("/api/telco-mns")
def api_open5gs_status() -> dict[str, Any]:
    binaries = {
        "amf": find_first([
            "/home/sentinel/lab/open5gs-d12-curl77/install/bin/open5gs-amfd",
            "/home/debian/lab/open5gs-d12-curl77/install/bin/open5gs-amfd",
            "/usr/bin/open5gs-amfd",
        ]),
        "smf": find_first([
            "/home/sentinel/lab/open5gs-d12-curl77/install/bin/open5gs-smfd",
            "/home/debian/lab/open5gs-d12-curl77/install/bin/open5gs-smfd",
            "/usr/bin/open5gs-smfd",
        ]),
        "upf": find_first([
            "/home/sentinel/lab/open5gs-d12-curl77/install/bin/open5gs-upfd",
            "/home/debian/lab/open5gs-d12-curl77/install/bin/open5gs-upfd",
            "/usr/bin/open5gs-upfd",
        ]),
    }

    proc = process_probe("open5gs")
    data = common_status()
    data.update({
        "domain": "5g-core",
        "open5gs": {
            "detected_binaries": binaries,
            "process_probe": proc,
            "interfaces": {
                "ogstun": run_cmd(["ip", "addr", "show", "ogstun"], timeout=1.5),
            },
            "ports": [x for x in ss_probe() if any(p in x["line"] for p in [":7777", ":38412", ":8805", ":2152"])],
            "readiness": "running" if proc["running"] else "not_running_or_not_detected",
        },
        "safety": {
            "read_only": True,
            "no_start_stop": True,
            "no_config_mutation": True,
        },
    })
    return data


@app.get("/api/ran/ueransim/status")
def api_ueransim_status() -> dict[str, Any]:
    paths = {
        "sentinel_default": "/home/sentinel/lab/UERANSIM",
        "debian_default": "/home/debian/lab/UERANSIM",
        "project_local": str(ROOT / "UERANSIM"),
    }
    proc = process_probe("nr-gnb|nr-ue|UERANSIM")
    data = common_status()
    data.update({
        "domain": "5g-ran-simulator",
        "ueransim": {
            "paths": {k: {"path": v, "exists": path_exists(v)} for k, v in paths.items()},
            "process_probe": proc,
            "interfaces": {
                "uesimtun0": run_cmd(["ip", "addr", "show", "uesimtun0"], timeout=1.5),
            },
            "readiness": "running" if proc["running"] else "not_running_or_not_detected",
        },
        "safety": {
            "read_only": True,
            "no_start_stop": True,
            "no_config_mutation": True,
        },
    })
    return data


@app.get("/api/network-fabric/overview")
@app.get("/api/network-fabric")
def api_network_fabric_overview() -> dict[str, Any]:
    data = common_status()
    data.update({
        "network": {
            "ip_brief": run_cmd(["ip", "-brief", "addr"], timeout=2),
            "routes": run_cmd(["ip", "route"], timeout=2),
            "listening": ss_probe(),
        },
        "classification": "read-only local host network fabric overview",
    })
    return data


@app.get("/api/rf-coverage/demo")
@app.get("/api/rf-coverage")
def api_rf_coverage_demo() -> dict[str, Any]:
    data = common_status()
    data.update({
        "rf_coverage": {
            "mode": "demo_readonly_contract",
            "cells": [
                {"id": "CELL-A", "band": "n78", "center_mhz": 3640, "pci": 101, "status": "synthetic"},
                {"id": "CELL-B", "band": "n78", "center_mhz": 3660, "pci": 102, "status": "synthetic"},
            ],
            "note": "V28 exposes the contract; V30 will bind real RF/simulation sources.",
        }
    })
    return data


@app.get("/api/rf-field/demo")
@app.get("/api/rf-field")
def api_rf_field_demo(target_asset_id: str | None = Query(default=None)) -> dict[str, Any]:
    data = common_status()
    data.update({
        "rf_field": {
            "mode": "demo_readonly_contract",
            "target_asset_id": target_asset_id or "UE-REMOTE-001",
            "measurements": {
                "rsrp_dbm": -84.2,
                "rsrq_db": -10.4,
                "sinr_db": 18.1,
                "evm_percent": 2.9,
            },
            "note": "Synthetic baseline until RF source adapter is promoted.",
        }
    })
    return data


@app.get("/api/rfpro/state")
@app.get("/api/rfpro")
@app.get("/api/rfpro/console")
@app.get("/api/rfpro/device/info")
@app.get("/api/rfpro/bridges/state")
def api_rfpro_state() -> dict[str, Any]:
    data = common_status()
    data.update({
        "rfpro": {
            "state": "readonly_bridge_online",
            "source_modes": ["synthetic", "file", "future_live_sdr"],
            "tx_enabled": False,
            "safety": "RX/read-only only in V28",
            "workers": list_recent_dirs(ROOT / "frontend" / "src" / "rf_instruments", limit=12),
        }
    })
    return data


@app.get("/api/evidence/index")
@app.get("/api/persistence/status")
@app.get("/api/evidence")
def api_evidence_index() -> dict[str, Any]:
    data = common_status()
    data.update({
        "evidence": {
            "quality_latest": list_recent_dirs(RUNTIME / "quality", limit=20),
            "releases_latest": list_recent_dirs(RUNTIME / "releases", limit=20),
            "freezes_latest": list_recent_dirs(RUNTIME / "freezes", limit=20),
        },
        "persistence": {
            "runtime_dir_exists": RUNTIME.exists(),
            "quality_dir_exists": (RUNTIME / "quality").exists(),
            "releases_dir_exists": (RUNTIME / "releases").exists(),
            "freezes_dir_exists": (RUNTIME / "freezes").exists(),
        },
    })
    return data


@app.get("/api/restricted/status")
@app.get("/api/restricted")
def api_restricted_status() -> dict[str, Any]:
    data = common_status()
    data.update({
        "restricted": {
            "mode": "safe_readonly",
            "write_actions": False,
            "tx_actions": False,
            "system_mutation": False,
            "operator_note": "V28 intentionally exposes only status contracts.",
        }
    })
    return data


@app.get("/api/access-trust")
@app.get("/api/soc-noc")
def api_correlation_stub() -> dict[str, Any]:
    data = common_status()
    data.update({
        "correlation": {
            "mode": "readonly_contract",
            "events": [],
            "note": "V28 contract placeholder; V31 can bind SOC/NOC correlation sources.",
        }
    })
    return data


@app.get("/api/core-live/events")
def api_core_live_events() -> dict[str, Any]:
    data = common_status()
    data.update({
        "events": [
            {"ts": now_iso(), "severity": "info", "source": APP_VERSION, "message": "read-only bridge online"}
        ]
    })
    return data



# === TRFMC_V31_CONTRACT_COVERAGE_EXPANSION ===
V31_CONTRACT_VERSION = "TRFMC_CONTRACT_COVERAGE_V31"


def v31_contract(endpoint: str, domain: str, capability: str, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    data = common_status()
    data.update({
        "contract_version": V31_CONTRACT_VERSION,
        "endpoint": endpoint,
        "domain": domain,
        "capability": capability,
        "contract_mode": "read-only",
        "action_executed": False,
        "tx_enabled": False,
        "mutation_enabled": False,
        "safety": {
            "read_only": True,
            "no_sdr_tx_control": True,
            "no_rf_transmission": True,
            "no_open5gs_start_stop": True,
            "no_ueransim_start_stop": True,
            "no_file_write": True,
            "no_system_mutation": True,
        },
    })
    if extra:
        data.update(extra)
    return data


@app.get("/api/rfpro/bandplan")
def api_v31_rfpro_bandplan() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bandplan",
        "rfpro",
        "bandplan_inventory",
        {
            "bands": [
                {"name": "FR1 n78", "range_mhz": [3300, 3800], "usage": "5G NR TDD lab reference", "status": "reference"},
                {"name": "ISM 2.4 GHz", "range_mhz": [2400, 2483.5], "usage": "Wi-Fi/Bluetooth/ISM reference", "status": "reference"},
                {"name": "ISM 5 GHz", "range_mhz": [5150, 5850], "usage": "Wi-Fi/ISM reference", "status": "reference"},
                {"name": "GNSS L1", "center_mhz": 1575.42, "usage": "GNSS reference", "status": "reference"},
            ],
            "note": "Reference-only bandplan for UI contract coverage; not a regulatory authorization table.",
        },
    )


@app.get("/api/rfpro/bridges/blueway/state")
def api_v31_rfpro_blueway_state() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/blueway/state",
        "rfpro.bridge.blueway",
        "bridge_state",
        {
            "bridge": "blueway",
            "state": "not_connected",
            "driver_loaded": False,
            "readiness": "contract_available_device_not_bound",
        },
    )


@app.get("/api/rfpro/bridges/markvii/preflight")
def api_v31_rfpro_markvii_preflight() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/markvii/preflight",
        "rfpro.bridge.markvii",
        "preflight",
        {
            "bridge": "markvii",
            "checks": [
                {"name": "device_present", "ok": False, "detail": "No live device adapter bound in V31"},
                {"name": "read_only_policy", "ok": True, "detail": "No transmit or mutation action allowed"},
            ],
            "readiness": "safe_contract_only",
        },
    )


@app.get("/api/rfpro/bridges/soapy/probe")
def api_v31_rfpro_soapy_probe() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/soapy/probe",
        "rfpro.bridge.soapy",
        "device_probe",
        {
            "bridge": "soapy",
            "devices": [],
            "readiness": "not_bound",
            "note": "V31 does not enumerate hardware through SoapySDR; contract only.",
        },
    )


@app.api_route("/api/rfpro/bridges/gnuradio/export", methods=["GET", "POST"])
def api_v31_rfpro_gnuradio_export() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/gnuradio/export",
        "rfpro.bridge.gnuradio",
        "export_contract",
        {
            "export_supported": False,
            "export_executed": False,
            "reason": "V31 is read-only; no GNU Radio file generation.",
        },
    )


@app.api_route("/api/rfpro/bridges/sdrpp/export", methods=["GET", "POST"])
def api_v31_rfpro_sdrpp_export() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/sdrpp/export",
        "rfpro.bridge.sdrpp",
        "export_contract",
        {
            "export_supported": False,
            "export_executed": False,
            "reason": "V31 is read-only; no SDR++ profile generation.",
        },
    )


@app.get("/api/rfpro/evidence/manifest")
def api_v31_rfpro_evidence_manifest() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/evidence/manifest",
        "rfpro.evidence",
        "evidence_manifest",
        {
            "evidence": {
                "quality_latest": list_recent_dirs(RUNTIME / "quality", limit=12),
                "releases_latest": list_recent_dirs(RUNTIME / "releases", limit=12),
                "freezes_latest": list_recent_dirs(RUNTIME / "freezes", limit=12),
            },
        },
    )


@app.get("/api/rfpro/file/wav/{filename:path}")
def api_v31_rfpro_wav_file(filename: str) -> dict[str, Any]:
    return v31_contract(
        f"/api/rfpro/file/wav/{filename}",
        "rfpro.file.wav",
        "file_lookup_contract",
        {
            "filename": filename,
            "available": False,
            "streaming": False,
            "reason": "No WAV artifact serving enabled in V31 contract mode.",
        },
    )


@app.api_route("/api/rfpro/iq/capture", methods=["GET", "POST"])
def api_v31_rfpro_iq_capture() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/iq/capture",
        "rfpro.iq",
        "iq_capture_contract",
        {
            "capture_supported": False,
            "capture_executed": False,
            "source_modes": ["synthetic", "file", "future_live_rx"],
            "reason": "V31 exposes contract only; no SDR capture is executed.",
        },
    )


@app.api_route("/api/rfpro/spectrum/sweep", methods=["GET", "POST"])
def api_v31_rfpro_spectrum_sweep() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/spectrum/sweep",
        "rfpro.spectrum",
        "sweep_contract",
        {
            "sweep_supported": False,
            "sweep_executed": False,
            "spectrum": {
                "center_mhz": 3640.0,
                "span_mhz": 100.0,
                "rbw_khz": 100.0,
                "data_source": "synthetic_contract",
            },
            "reason": "V31 does not command SDR/instrument sweep.",
        },
    )


@app.get("/api/rfpro/uav/fhss")
def api_v31_rfpro_uav_fhss() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/uav/fhss",
        "rfpro.uav",
        "fhss_analysis_contract",
        {
            "analysis_supported": True,
            "live_capture": False,
            "profile": {
                "type": "FHSS reference model",
                "hopping_detected": False,
                "data_source": "contract_only",
            },
        },
    )


@app.get("/api/rfpro/uav/profiles")
def api_v31_rfpro_uav_profiles() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/uav/profiles",
        "rfpro.uav",
        "profile_catalog",
        {
            "profiles": [
                {"id": "uav-ism-24", "band": "2.4GHz ISM", "modulation": "FHSS/OFDM reference", "status": "template"},
                {"id": "uav-ism-58", "band": "5.8GHz ISM", "modulation": "OFDM/analog video reference", "status": "template"},
                {"id": "uav-lte-5g", "band": "LTE/5G modem", "modulation": "cellular reference", "status": "template"},
            ],
        },
    )


@app.get("/api/v585/ws/spectrum")
def api_v31_v585_ws_spectrum_contract() -> dict[str, Any]:
    return v31_contract(
        "/api/v585/ws/spectrum",
        "rfpro.websocket",
        "spectrum_stream_contract",
        {
            "websocket_enabled": False,
            "http_contract_available": True,
            "future_ws_path": "/ws/v585/spectrum",
            "reason": "V31 exposes HTTP contract only; live WebSocket can be promoted later.",
        },
    )


@app.get("/api/access-trust/rat/demo")
def api_v31_access_trust_rat_demo() -> dict[str, Any]:
    return v31_contract(
        "/api/access-trust/rat/demo",
        "access-trust",
        "rat_demo",
        {
            "rat": [
                {"name": "NR", "trust": "unknown", "data_source": "contract"},
                {"name": "LTE", "trust": "unknown", "data_source": "contract"},
                {"name": "Wi-Fi", "trust": "unknown", "data_source": "contract"},
            ],
        },
    )


@app.get("/api/access-trust/wifi/demo")
def api_v31_access_trust_wifi_demo() -> dict[str, Any]:
    return v31_contract(
        "/api/access-trust/wifi/demo",
        "access-trust",
        "wifi_demo",
        {
            "wifi": {
                "aps": [],
                "risk_score": None,
                "data_source": "contract_only",
            },
        },
    )


@app.get("/api/soc-noc/correlation/demo")
def api_v31_soc_noc_correlation_demo() -> dict[str, Any]:
    return v31_contract(
        "/api/soc-noc/correlation/demo",
        "soc-noc",
        "correlation_demo",
        {
            "events": [],
            "correlations": [],
            "data_source": "contract_only",
        },
    )
# === END TRFMC_V31_CONTRACT_COVERAGE_EXPANSION ===

# === TRFMC_V31R1_CONTRACT_SEMANTICS_HYGIENE ===
# Global response source must remain TRFMC_READONLY_BACKEND_BRIDGE_V28.
# Contract-local provenance fields use data_source / analysis_source / catalog_source.

# === TRFMC BATCH2G RF NORMALIZED TRACE ROUTER START ===
try:
    from backend.routers import rf_normalized_trace_v1
except Exception:
    try:
        from routers import rf_normalized_trace_v1
    except Exception:
        rf_normalized_trace_v1 = None

try:
    if rf_normalized_trace_v1 is not None:
        app.include_router(rf_normalized_trace_v1.router)
except Exception as exc:
    print("TRFMC Batch2G normalized RF trace router include failed:", repr(exc))
# === TRFMC BATCH2G RF NORMALIZED TRACE ROUTER END ===
