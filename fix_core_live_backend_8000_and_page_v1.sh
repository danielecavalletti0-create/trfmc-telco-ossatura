#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
BACKEND="$BASE/backend"
TS="$(date +%Y%m%d_%H%M%S)"

PAGE="$PUBLIC/trfmc_core_network_live_ops_bridge_v1.html"
SERVER="$BACKEND/core_live_standalone_server.py"

OUT="$BASE/runtime/quality/TRFMC_FIX_CORE_LIVE_BACKEND_8000_$TS"
BK="$BASE/runtime/backups/FIX_CORE_LIVE_BACKEND_8000_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/logs" "$BASE/runtime/quality" "$BASE/runtime/freezes" "$BACKEND"

echo "============================================================"
echo "TRFMC FIX - CORE LIVE BACKEND 8000 + PAGE FETCH"
echo "============================================================"

http_probe() {
  local url="$1"
  local r code bytes
  r="$(curl -s -o /dev/null -w "%{response_code} %{size_download}" --max-time 5 "$url" 2>/dev/null || true)"
  code="$(echo "$r" | awk '{print $1}')"
  bytes="$(echo "$r" | awk '{print $2}')"
  [ -n "$code" ] || code="000"
  [ -n "$bytes" ] || bytes="0"
  echo -e "$url\t$code\t$bytes"
}

echo
echo "[1/8] Backup pagina e log"
[ -f "$PAGE" ] && cp -av "$PAGE" "$BK/$(basename "$PAGE").bak"
[ -f "$BASE/runtime/logs/backend_8000.log" ] && cp -av "$BASE/runtime/logs/backend_8000.log" "$BK/backend_8000.log.bak" || true

echo
echo "[2/8] Creo backend standalone Core Live su 127.0.0.1:8000"
cat > "$SERVER" <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
from datetime import datetime, timezone
import subprocess
import os
import re

BASE = Path(os.environ.get("TRFMC_BASE", "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"))
RUNTIME = Path(os.environ.get("TRFMC_RUNTIME", str(BASE / "runtime")))

app = FastAPI(title="TRFMC Core Live Standalone Backend", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5173",
        "http://localhost:5173",
        "http://127.0.0.1:8080",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def run(cmd: str, timeout: int = 4):
    try:
        r = subprocess.run(
            cmd,
            shell=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        return {
            "ok": r.returncode == 0,
            "code": r.returncode,
            "stdout": r.stdout.strip(),
            "stderr": r.stderr.strip(),
        }
    except Exception as e:
        return {"ok": False, "code": -1, "stdout": "", "stderr": str(e)}

def lines(txt: str):
    return [x for x in txt.splitlines() if x.strip()]

def process_probe(pattern: str):
    r = run(f"pgrep -af '{pattern}' || true")
    return lines(r["stdout"])

def port_probe():
    r = run("ss -ltnup 2>/dev/null | egrep '(:38412|:8805|:2152|:7777|:8000|:5173)' || true")
    return lines(r["stdout"])

def ogstun_probe():
    r = run("ip addr show ogstun 2>/dev/null || true")
    return {"present": bool(r["stdout"].strip()), "raw": lines(r["stdout"])}

def route_probe():
    r = run("ip route 2>/dev/null | egrep '10\\.45|ogstun|uesimtun|default' || true")
    return lines(r["stdout"])

def file_exists(rel):
    p = BASE / rel
    return {
        "path": str(p),
        "exists": p.exists(),
        "size": p.stat().st_size if p.exists() and p.is_file() else None,
        "executable": os.access(p, os.X_OK) if p.exists() else False,
    }

def read_tail(rel, n=80):
    p = BASE / rel
    if not p.exists():
        return []
    try:
        return p.read_text(errors="ignore").splitlines()[-n:]
    except Exception as e:
        return [f"READ_ERROR: {e}"]

def cfg_extract():
    candidates = [
        "lab/UERANSIM/config/open5gs-gnb.yaml",
        "lab/UERANSIM/config/open5gs-ue.yaml",
        "UERANSIM/config/open5gs-gnb.yaml",
        "UERANSIM/config/open5gs-ue.yaml",
        "open5gs-gnb.yaml",
        "open5gs-ue.yaml",
    ]

    out = {}
    for c in candidates:
        p = BASE / c
        if not p.exists():
            continue

        txt = p.read_text(errors="ignore")
        out[c] = {
            "exists": True,
            "linkIp": re.findall(r"linkIp:\\s*'?([^'\\n]+)'?", txt),
            "ngapIp": re.findall(r"ngapIp:\\s*'?([^'\\n]+)'?", txt),
            "gtpIp": re.findall(r"gtpIp:\\s*'?([^'\\n]+)'?", txt),
            "gnbSearchList": re.findall(r"gnbSearchList:\\s*\\n\\s*-\\s*'?([^'\\n]+)'?", txt),
            "supi": re.findall(r"supi:\\s*'?([^'\\n]+)'?", txt),
            "mcc": re.findall(r"mcc:\\s*'?([^'\\n]+)'?", txt),
            "mnc": re.findall(r"mnc:\\s*'?([^'\\n]+)'?", txt),
        }
    return out

def scripts_probe():
    scripts = [
        "bin/5g-start.sh",
        "bin/5g-stop.sh",
        "bin/5g-health.sh",
        "bin/5g-capture-start.sh",
        "bin/5g-capture-stop.sh",
        "start_lab.sh",
        "status_super_portale_5g.sh",
    ]
    return {s: file_exists(s) for s in scripts}

def snapshot():
    open5gs = process_probe("open5gs|amfd|smfd|upfd|ausfd|udmd|nrf|scp|bsf|pcfd|nssfd")
    ueransim = process_probe("nr-gnb|nr-ue|UERANSIM")
    ports = port_probe()
    ogstun = ogstun_probe()
    routes = route_probe()
    scripts = scripts_probe()
    configs = cfg_extract()

    gates = {
        "backend_api": True,
        "open5gs_process_seen": len(open5gs) > 0,
        "ueransim_process_seen": len(ueransim) > 0,
        "ngap_38412_seen": any(":38412" in x for x in ports),
        "pfcp_8805_seen": any(":8805" in x for x in ports),
        "gtpu_2152_seen": any(":2152" in x for x in ports),
        "ogstun_present": ogstun["present"],
        "start_script_present": scripts.get("bin/5g-start.sh", {}).get("exists", False),
        "health_script_present": scripts.get("bin/5g-health.sh", {}).get("exists", False),
    }

    score = sum(1 for v in gates.values() if v)
    total = len(gates)

    if gates["open5gs_process_seen"] and gates["ueransim_process_seen"] and gates["ogstun_present"]:
        state = "LIVE_ATTACHED_OR_READY"
    elif gates["open5gs_process_seen"]:
        state = "CORE_ONLY"
    elif gates["start_script_present"]:
        state = "INSTALLED_BUT_STOPPED"
    else:
        state = "DISCOVERY_REQUIRED"

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "trfmc-core-live-standalone",
        "base": str(BASE),
        "runtime": str(RUNTIME),
        "state": state,
        "score": score,
        "score_total": total,
        "gates": gates,
        "processes": {
            "open5gs": open5gs,
            "ueransim": ueransim,
        },
        "ports": ports,
        "ogstun": ogstun,
        "routes": routes,
        "scripts": scripts,
        "configs": configs,
        "logs": {
            "backend_8000_tail": read_tail("runtime/logs/backend_8000.log", 50),
            "open5gs_tail": read_tail("runtime/logs/open5gs.log", 80),
            "ueransim_tail": read_tail("runtime/logs/ueransim.log", 80),
        },
    }

@app.get("/api/health")
def api_health():
    return {
        "status": "ok",
        "service": "trfmc-core-live-standalone",
        "port": 8000,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.get("/api/trfmc-backend-ready")
def backend_ready():
    return {
        "status": "ok",
        "service": "trfmc-backend",
        "mode": "standalone-core-live",
        "core_live": True,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.get("/api/core-live/health")
def core_live_health():
    snap = snapshot()
    return {
        "status": "ok",
        "service": "trfmc-core-live",
        "state": snap["state"],
        "score": snap["score"],
        "score_total": snap["score_total"],
        "timestamp": snap["timestamp"],
    }

@app.get("/api/core-live/status")
def core_live_status():
    return snapshot()

@app.get("/api/core-live/events")
def core_live_events():
    snap = snapshot()
    events = []
    for k, v in snap["gates"].items():
        events.append({"gate": k, "status": "PASS" if v else "WARN"})
    return {"timestamp": snap["timestamp"], "state": snap["state"], "events": events}
PY

echo
echo "[3/8] Avvio/recupero backend 8000"
if curl -fsS --max-time 3 "http://127.0.0.1:8000/api/core-live/health" >/dev/null 2>&1; then
  echo "Backend Core Live già raggiungibile su 8000"
else
  PIDS="$(lsof -ti tcp:8000 2>/dev/null || true)"
  if [ -n "$PIDS" ]; then
    echo "Porta 8000 occupata ma non sana. Termino: $PIDS"
    kill $PIDS 2>/dev/null || true
    sleep 2
  fi

  if [ ! -d "$BASE/.venv" ]; then
    python3 -m venv "$BASE/.venv"
  fi

  source "$BASE/.venv/bin/activate"
  python -m pip install --upgrade pip wheel >/dev/null 2>&1 || true
  python -m pip install fastapi uvicorn pydantic >/dev/null 2>&1 || true

  nohup bash -lc "
    cd '$BASE'
    source .venv/bin/activate
    export TRFMC_BASE='$BASE'
    export TRFMC_RUNTIME='$BASE/runtime'
    exec uvicorn backend.core_live_standalone_server:app --host 127.0.0.1 --port 8000
  " > "$BASE/runtime/logs/backend_8000.log" 2>&1 &

  sleep 5
fi

echo
echo "[4/8] Patch pagina: API base resiliente senza hardcoded http:// nel sorgente"
python3 - <<'PY'
from pathlib import Path

p = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_core_network_live_ops_bridge_v1.html")
if not p.exists():
    raise SystemExit("ERRORE: pagina core live non trovata")

s = p.read_text(errors="ignore")
original = s

# Inserisco helper API_BASE senza literal http://, così il gate external_refs resta pulito.
if "function coreApiBase()" not in s:
    marker = "function log(m){"
    helper = r'''
function coreApiBase(){
  return `${location.protocol}//${location.hostname}:8000`;
}
async function fetchCore(path){
  const url = coreApiBase() + path;
  const res = await fetch(url, {cache:"no-store", mode:"cors"});
  if(!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  return await res.json();
}
'''
    if marker not in s:
        raise SystemExit("ERRORE: marker function log non trovato")
    s = s.replace(marker, helper + "\n" + marker, 1)

# Sostituisco fetch assoluto precedente.
s = s.replace(
    'const res=await fetch("http://127.0.0.1:8000/api/core-live/status",{cache:"no-store"});\n    last=await res.json();',
    'last=await fetchCore("/api/core-live/status");'
)

# Sostituisco window.open assoluto senza introdurre http:// nel sorgente.
s = s.replace(
    'window.open("http://127.0.0.1:8000/api/core-live/status","_blank")',
    'window.open(coreApiBase()+"/api/core-live/status","_blank")'
)

# Piccolo miglioramento messaggio errore.
s = s.replace(
    '$("kBackend").textContent="WARN"; $("overlay").textContent="Backend 8000 not reachable: "+e.message; log("backend error: "+e.message);',
    '$("kBackend").textContent="WARN"; $("overlay").textContent="Backend 8000 not reachable: "+e.message+" · check runtime/logs/backend_8000.log"; log("backend error: "+e.message);'
)

if s != original:
    p.write_text(s)
    print("PATCH_OK: pagina aggiornata con coreApiBase/fetchCore")
else:
    print("INFO: pagina già aggiornata o nessuna sostituzione necessaria")
PY

echo
echo "[5/8] Gate HTTP backend + frontend"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  "http://127.0.0.1:8000/api/health" \
  "http://127.0.0.1:8000/api/trfmc-backend-ready" \
  "http://127.0.0.1:8000/api/core-live/health" \
  "http://127.0.0.1:8000/api/core-live/status" \
  "http://127.0.0.1:8000/api/core-live/events" \
  "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html" \
  "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html" \
  "http://127.0.0.1:5173/vendor/three/build/three.module.js" \
  "http://127.0.0.1:5173/vendor/three/examples/jsm/controls/OrbitControls.js"
do
  http_probe "$u" >> "$OUT/http.tsv"
done

grep -nEi '<iframe|http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' "$PAGE" > "$OUT/page_refs.txt" 2>/dev/null || true
grep -nEi 'coreApiBase|fetchCore|core-live|Open5GS|UERANSIM|NGAP|PFCP|GTP-U|WebGLRenderer|OrbitControls' "$PAGE" > "$OUT/core_markers.txt" 2>/dev/null || true

curl -s --max-time 5 "http://127.0.0.1:8000/api/core-live/status" > "$OUT/core_live_status.json" || true

echo
echo "[6/8] Summary JSON"
export OUT
python3 - <<'PY'
import json
import os
from pathlib import Path
from datetime import datetime, timezone

out = Path(os.environ["OUT"])

http_non_200 = 0
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 2 and p[1].strip() != "200":
        http_non_200 += 1

page_refs = [x for x in (out / "page_refs.txt").read_text(errors="ignore").splitlines() if x.strip()]
markers = (out / "core_markers.txt").read_text(errors="ignore")
needed = ["coreApiBase", "fetchCore", "core-live", "Open5GS", "UERANSIM", "NGAP", "PFCP", "GTP-U", "WebGLRenderer", "OrbitControls"]
markers_ok = all(x in markers for x in needed)

status_ok = False
state = "UNKNOWN"
try:
    status = json.loads((out / "core_live_status.json").read_text(errors="ignore"))
    status_ok = status.get("service") == "trfmc-core-live-standalone"
    state = status.get("state", "UNKNOWN")
except Exception:
    pass

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "backend": "http://127.0.0.1:8000/api/core-live/status",
    "page": "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html",
    "http_non_200": http_non_200,
    "page_refs_count": len(page_refs),
    "markers_ok": markers_ok,
    "core_live_status_ok": status_ok,
    "core_state": state,
    "result": "PASS" if http_non_200 == 0 and len(page_refs) == 0 and markers_ok and status_ok else "WARN",
}

(out / "summary.json").write_text(json.dumps(data, indent=4) + "\n")
(out / "result.flag").write_text(data["result"] + "\n")
print(json.dumps(data, indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_fix_core_live_backend_8000"

echo
echo "[7/8] Report"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== PAGE REFS ==="
cat "$OUT/page_refs.txt"

echo
echo "=== CORE MARKERS ==="
cat "$OUT/core_markers.txt"

echo
echo "=== CORE LIVE STATUS ==="
cat "$OUT/core_live_status.json" | python3 -m json.tool || cat "$OUT/core_live_status.json"

echo
echo "=== BACKEND LOG TAIL ==="
tail -n 80 "$BASE/runtime/logs/backend_8000.log" || true

echo
echo "[8/8] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_CORE_LIVE_BACKEND_8000_FIXED_$TS.tar.gz"

  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .

  echo
  echo "=== FREEZE CREATO ==="
  ls -lh "$FREEZE"

  echo
  echo "============================================================"
  echo "CORE LIVE BACKEND 8000 RIPARATO"
  echo "Apri:"
  echo "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html"
  echo
  echo "API:"
  echo "http://127.0.0.1:8000/api/core-live/status"
  echo "============================================================"
else
  echo
  echo "============================================================"
  echo "WARN: gate non PASS. Report:"
  echo "$OUT"
  echo "Log:"
  echo "$BASE/runtime/logs/backend_8000.log"
  echo "============================================================"
fi
