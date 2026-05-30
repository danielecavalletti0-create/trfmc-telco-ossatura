#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_READONLY_BACKEND_BRIDGE_V28_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_READONLY_BACKEND_BRIDGE_V28_$TS"
BACKEND_DIR="$ROOT/backend/readonly_bridge_v28"
APP="$BACKEND_DIR/app.py"
FREEZE="$ROOT/runtime/freezes/TRFMC_READONLY_BACKEND_BRIDGE_V28_$TS.tar.gz"

echo "============================================================"
echo "TRFMC READ-ONLY BACKEND BRIDGE V28"
echo "FastAPI · read-only status APIs · no systemd/nginx/vite mutation"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$BACKEND_DIR" "$ROOT/runtime/bin" "$ROOT/runtime/logs" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -d "$ROOT/frontend" || { echo "ERRORE: frontend mancante"; exit 1; }
test -f "$ROOT/frontend/src/app/main.tsx" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$ROOT/runtime/quality/latest_portal_contract_audit_v27/summary.json" || { echo "ERRORE: V27 summary mancante"; exit 1; }

grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" || {
  echo "ERRORE: RFOperationalDeckV16ChunkObservatory non montato"
  exit 1
}

python3 - <<'PY'
import importlib.util, sys
missing = [m for m in ("fastapi", "uvicorn") if importlib.util.find_spec(m) is None]
if missing:
    print("MISSING_PYTHON_MODULES=" + ",".join(missing))
    sys.exit(10)
print("OK: fastapi + uvicorn disponibili")
PY
PY_RC=$?

if [ "$PY_RC" -ne 0 ]; then
  cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_READONLY_BACKEND_BRIDGE_V28",
  "result": "NEEDS_PYTHON_MODULES",
  "missing_hint": "Installa/attiva ambiente con fastapi e uvicorn, poi rilancia V28.",
  "source_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false
}
JSON
  ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_readonly_backend_bridge_v28"
  cat "$QUALITY_DIR/summary.json" | python3 -m json.tool
  exit 0
fi

echo "OK: V27 presente, runtime foundation preservata, FastAPI disponibile"

echo
echo "=== CREA BACKEND READ-ONLY APP ==="

cat > "$APP" <<'PY'
from __future__ import annotations

import json
import os
import platform
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
    out = run_cmd(["pgrep", "-af", pattern])
    lines = [x for x in out["stdout"].splitlines() if x.strip()]
    return {
        "pattern": pattern,
        "count": len(lines),
        "lines": lines[:20],
        "running": len(lines) > 0,
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
PY

echo
echo "=== CREA CONTROL SCRIPT V28 ==="

cat > "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"
APP_MODULE="backend.readonly_bridge_v28.app:app"
LOG="\$ROOT/runtime/logs/trfmc_readonly_backend_v28_8000_\$(date +%Y%m%d_%H%M%S).log"
PIDFILE="\$ROOT/runtime/trfmc_readonly_backend_v28_8000.pid"

cd "\$ROOT"

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:8000/api/health >/dev/null 2>&1; then
  echo "OK: V28 backend già raggiungibile su http://127.0.0.1:8000/"
  ss -ltnp | grep ':8000' || true
  exit 0
fi

nohup python3 -m uvicorn "\$APP_MODULE" --host 127.0.0.1 --port 8000 > "\$LOG" 2>&1 &
PID=\$!
echo "\$PID" > "\$PIDFILE"

sleep 2

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:8000/api/health >/dev/null 2>&1; then
  echo "OK: V28 read-only backend avviato"
  echo "URL: http://127.0.0.1:8000/"
  echo "PID: \$PID"
  echo "LOG: \$LOG"
else
  echo "ERRORE: backend V28 non raggiungibile"
  echo "PID: \$PID"
  echo "LOG: \$LOG"
  tail -n 120 "\$LOG" || true
  exit 1
fi
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_readonly_backend_v28_stop_8000.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"
PIDFILE="\$ROOT/runtime/trfmc_readonly_backend_v28_8000.pid"

if [ -f "\$PIDFILE" ]; then
  PID="\$(cat "\$PIDFILE")"
  if ps -p "\$PID" >/dev/null 2>&1; then
    kill "\$PID" || true
    sleep 1
  fi
fi

pkill -f "backend.readonly_bridge_v28.app:app" 2>/dev/null || true

echo "OK: stop backend V28 richiesto"
ss -ltnp | grep ':8000' || true
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_readonly_backend_v28_status_8000.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== PORT 8000 ==="
ss -ltnp | grep ':8000' || true

echo
echo "=== DIRECT HEALTH ==="
curl -sS --connect-timeout 2 --max-time 6 http://127.0.0.1:8000/api/health | python3 -m json.tool || true

echo
echo "=== PROXY THROUGH 4181 ==="
curl -sS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/api/mission/status | python3 -m json.tool || true
SCRIPT

chmod +x \
  "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh" \
  "$ROOT/runtime/bin/trfmc_readonly_backend_v28_stop_8000.sh" \
  "$ROOT/runtime/bin/trfmc_readonly_backend_v28_status_8000.sh"

echo
echo "=== START BACKEND V28 ==="

"$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh"

echo
echo "=== HTTP GATE DIRECT + PROXY ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

for base in http://127.0.0.1:8000 http://127.0.0.1:4181
do
  probe "$base/api/health"
  probe "$base/api/mission/status"
  probe "$base/api/runtime/services"
  probe "$base/api/core/open5gs/status"
  probe "$base/api/ran/ueransim/status"
  probe "$base/api/network-fabric/overview"
  probe "$base/api/rf-coverage/demo"
  probe "$base/api/rf-field/demo"
  probe "$base/api/telco-mns/status"
  probe "$base/api/evidence/index"
  probe "$base/api/restricted/status"
done

column -t -s $'\t' "$HTTP_TSV"

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$APP" && echo "OK: app.py created" || echo "MISS: app.py created"
  test -x "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh" && echo "OK: start script" || echo "MISS: start script"
  test -x "$ROOT/runtime/bin/trfmc_readonly_backend_v28_stop_8000.sh" && echo "OK: stop script" || echo "MISS: stop script"
  test -x "$ROOT/runtime/bin/trfmc_readonly_backend_v28_status_8000.sh" && echo "OK: status script" || echo "MISS: status script"

  grep -q "read-only" "$APP" && echo "OK: read-only marker" || echo "MISS: read-only marker"
  grep -q "no_start_stop" "$APP" && echo "OK: no start/stop safety marker" || echo "MISS: no start/stop safety marker"

  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:8000/api/health >/dev/null && echo "OK: direct 8000 health" || echo "MISS: direct 8000 health"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/api/mission/status >/dev/null && echo "OK: proxy 4181 mission status" || echo "MISS: proxy 4181 mission status"

  grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" && echo "OK: V16 mount preserved" || echo "MISS: V16 mount preserved"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== SAMPLE PAYLOADS ==="

mkdir -p "$RELEASE_DIR/samples"

for ep in \
  /api/health \
  /api/mission/status \
  /api/core/open5gs/status \
  /api/ran/ueransim/status \
  /api/rf-coverage/demo \
  /api/evidence/index
do
  safe="$(echo "$ep" | sed 's#/#_#g' | sed 's/^_//')"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:8000$ep" | python3 -m json.tool > "$RELEASE_DIR/samples/${safe}.json" || true
done

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/readonly_backend_bridge_manifest_v28.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_READONLY_BACKEND_BRIDGE_V28",
  "backend_url": "http://127.0.0.1:8000/",
  "proxy_url": "http://127.0.0.1:4181/",
  "app": "$APP",
  "control_scripts": {
    "start": "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh",
    "stop": "$ROOT/runtime/bin/trfmc_readonly_backend_v28_stop_8000.sh",
    "status": "$ROOT/runtime/bin/trfmc_readonly_backend_v28_status_8000.sh"
  },
  "implemented_minimum_contract": [
    "/api/health",
    "/api/mission/status",
    "/api/runtime/services",
    "/api/core/open5gs/status",
    "/api/ran/ueransim/status",
    "/api/network-fabric/overview",
    "/api/rf-coverage/demo",
    "/api/rf-field/demo",
    "/api/telco-mns/status",
    "/api/evidence/index",
    "/api/restricted/status"
  ],
  "safety": {
    "read_only": true,
    "no_open5gs_start_stop": true,
    "no_ueransim_start_stop": true,
    "no_sdr_tx_control": true,
    "no_nginx_mutation": true,
    "no_systemd_mutation": true,
    "no_vite_mutation": true,
    "no_dist_mutation": true
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  backend/readonly_bridge_v28 \
  runtime/bin/trfmc_readonly_backend_v28_start_8000.sh \
  runtime/bin/trfmc_readonly_backend_v28_stop_8000.sh \
  runtime/bin/trfmc_readonly_backend_v28_status_8000.sh \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_READONLY_BACKEND_BRIDGE_V28",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_readonly_backend_bridge_v28"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_readonly_backend_bridge_v28"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V28 READ-ONLY BACKEND BRIDGE COMPLETATO"
echo "Backend: http://127.0.0.1:8000/"
echo "Proxy  : http://127.0.0.1:4181/"
echo "Status : runtime/bin/trfmc_readonly_backend_v28_status_8000.sh"
echo "============================================================"
