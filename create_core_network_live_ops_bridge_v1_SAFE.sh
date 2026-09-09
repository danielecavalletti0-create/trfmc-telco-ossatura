#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
BACKEND="$BASE/backend"
TS="$(date +%Y%m%d_%H%M%S)"

OUT="$BASE/runtime/quality/TRFMC_CORE_NETWORK_LIVE_OPS_BRIDGE_V1_$TS"
BK="$BASE/runtime/backups/CORE_NETWORK_LIVE_OPS_BRIDGE_V1_$TS"
PAGE="$PUBLIC/trfmc_core_network_live_ops_bridge_v1.html"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"

mkdir -p "$OUT" "$BK" "$BASE/runtime/logs" "$BASE/runtime/quality" "$BASE/runtime/freezes"
mkdir -p "$BACKEND/app/domains/core_live"
mkdir -p "$PUBLIC/vendor/three/build" "$PUBLIC/vendor/three/examples/jsm/controls"

echo "============================================================"
echo "TRFMC CORE NETWORK LIVE OPS BRIDGE V1"
echo "backend recovery · Open5GS/UERANSIM diagnostics · WebGL core topology"
echo "============================================================"

http_full() {
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
echo "[1/10] Backup file critici"
[ -f "$BACKEND/app/main.py" ] && cp -av "$BACKEND/app/main.py" "$BK/main.py.bak"
[ -f "$BACKEND/app/domains/ops_backup/services.py" ] && cp -av "$BACKEND/app/domains/ops_backup/services.py" "$BK/ops_backup_services.py.bak"
[ -f "$V6R3" ] && cp -av "$V6R3" "$BK/v6r3_command_center.html.bak"
[ -f "$PAGE" ] && cp -av "$PAGE" "$BK/$(basename "$PAGE").bak"

echo
echo "[2/10] Fix backend runtime path: niente più /runtime assoluto"
python3 - <<'PY'
from pathlib import Path
import re

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
svc = base / "backend/app/domains/ops_backup/services.py"

if svc.exists():
    s = svc.read_text(errors="ignore")
    original = s

    if "import os" not in s:
        s = "import os\n" + s

    if "from pathlib import Path" not in s and "import pathlib" not in s:
        s = "from pathlib import Path\n" + s

    safe_expr = 'Path(os.environ.get("TRFMC_RUNTIME", str(Path.cwd() / "runtime"))) / "backups"'

    s = re.sub(r'Path\(["\']/runtime/backups["\']\)', safe_expr, s)
    s = re.sub(r'Path\(["\']/runtime["\']\)\s*/\s*["\']backups["\']', safe_expr, s)
    s = s.replace('"/runtime/backups"', 'os.environ.get("TRFMC_RUNTIME", str(Path.cwd() / "runtime")) + "/backups"')
    s = s.replace("'/runtime/backups'", 'os.environ.get("TRFMC_RUNTIME", str(Path.cwd() / "runtime")) + "/backups"')

    if s != original:
        svc.write_text(s)
        print("PATCH_OK: ops_backup/services.py corretto per runtime locale")
    else:
        print("INFO: nessun pattern /runtime/backups trovato in ops_backup/services.py")
else:
    print("INFO: ops_backup/services.py non presente")
PY

echo
echo "[3/10] Creo Core Live API router"
cat > "$BACKEND/app/domains/core_live/api.py" <<'PY'
from fastapi import APIRouter
from pathlib import Path
from datetime import datetime, timezone
import os
import subprocess
import json
import re

router = APIRouter(prefix="/api/core-live", tags=["TRFMC Core Live"])

BASE = Path(os.environ.get("TRFMC_BASE", "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"))
RUNTIME = Path(os.environ.get("TRFMC_RUNTIME", str(BASE / "runtime")))

def run(cmd, timeout=4):
    try:
        r = subprocess.run(cmd, shell=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        return {"ok": r.returncode == 0, "code": r.returncode, "stdout": r.stdout.strip(), "stderr": r.stderr.strip()}
    except Exception as e:
        return {"ok": False, "code": -1, "stdout": "", "stderr": str(e)}

def lines(txt):
    return [x for x in txt.splitlines() if x.strip()]

def process_probe(pattern):
    r = run(f"pgrep -af '{pattern}' || true")
    return lines(r["stdout"])

def port_probe():
    r = run("ss -ltnup 2>/dev/null | egrep '(:38412|:8805|:2152|:7777|:8000|:5173)' || true")
    return lines(r["stdout"])

def file_exists(path):
    p = BASE / path
    return {"path": str(p), "exists": p.exists(), "size": p.stat().st_size if p.exists() and p.is_file() else None}

def read_tail(path, n=80):
    p = BASE / path
    if not p.exists():
        return []
    try:
        return p.read_text(errors="ignore").splitlines()[-n:]
    except Exception:
        return []

def cfg_extract():
    candidates = [
        "lab/UERANSIM/config/open5gs-gnb.yaml",
        "lab/UERANSIM/config/open5gs-ue.yaml",
        "UERANSIM/config/open5gs-gnb.yaml",
        "UERANSIM/config/open5gs-ue.yaml",
    ]
    out = {}
    for c in candidates:
        p = BASE / c
        if p.exists():
            txt = p.read_text(errors="ignore")
            out[c] = {
                "exists": True,
                "linkIp": re.findall(r"linkIp:\s*'?([^'\\n]+)'?", txt),
                "ngapIp": re.findall(r"ngapIp:\s*'?([^'\\n]+)'?", txt),
                "gtpIp": re.findall(r"gtpIp:\s*'?([^'\\n]+)'?", txt),
                "gnbSearchList": re.findall(r"gnbSearchList:\s*\\n\\s*-\\s*'?([^'\\n]+)'?", txt),
                "supi": re.findall(r"supi:\s*'?([^'\\n]+)'?", txt),
                "mcc": re.findall(r"mcc:\s*'?([^'\\n]+)'?", txt),
                "mnc": re.findall(r"mnc:\s*'?([^'\\n]+)'?", txt),
            }
    return out

def ogstun_probe():
    r = run("ip addr show ogstun 2>/dev/null || true")
    return {"present": bool(r["stdout"].strip()), "raw": lines(r["stdout"])}

def route_probe():
    r = run("ip route 2>/dev/null | egrep '10\\.45|ogstun|uesimtun|default' || true")
    return lines(r["stdout"])

def scripts_probe():
    scripts = [
        "bin/5g-start.sh",
        "bin/5g-stop.sh",
        "bin/5g-health.sh",
        "bin/5g-capture-start.sh",
        "bin/5g-capture-stop.sh",
        "start_lab.sh",
    ]
    return {s: file_exists(s) for s in scripts}

def core_snapshot():
    open5gs = process_probe("open5gs|amfd|smfd|upfd|ausfd|udmd|nrf|scp|bsf|pcfd|nssfd")
    ueransim = process_probe("nr-gnb|nr-ue|UERANSIM")
    ports = port_probe()
    ogstun = ogstun_probe()
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
        "routes": route_probe(),
        "scripts": scripts,
        "configs": configs,
        "logs": {
            "backend_8000_tail": read_tail("runtime/logs/backend_8000.log", 60),
            "open5gs_tail": read_tail("runtime/logs/open5gs.log", 80),
            "ueransim_tail": read_tail("runtime/logs/ueransim.log", 80),
        }
    }

@router.get("/health")
def health():
    snap = core_snapshot()
    return {
        "status": "ok",
        "service": "trfmc-core-live",
        "state": snap["state"],
        "score": snap["score"],
        "score_total": snap["score_total"],
        "timestamp": snap["timestamp"],
    }

@router.get("/status")
def status():
    return core_snapshot()

@router.get("/events")
def events():
    snap = core_snapshot()
    ev = []
    for k, v in snap["gates"].items():
        ev.append({"gate": k, "status": "PASS" if v else "WARN"})
    return {"timestamp": snap["timestamp"], "events": ev, "state": snap["state"]}
PY

touch "$BACKEND/app/domains/core_live/__init__.py"

echo
echo "[4/10] Includo router e CORS in backend/app/main.py"
python3 - <<'PY'
from pathlib import Path

main = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/backend/app/main.py")
if not main.exists():
    raise SystemExit("ERRORE: backend/app/main.py non esiste")

s = main.read_text(errors="ignore")
original = s

if "CORSMiddleware" not in s:
    insert = """
from fastapi.middleware.cors import CORSMiddleware
"""
    s = insert + s

if "TRFMC CORE LIVE ROUTER" not in s:
    s += r'''

# ============================================================
# TRFMC CORE LIVE ROUTER
# ============================================================
try:
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
except Exception:
    pass

try:
    from app.domains.core_live.api import router as trfmc_core_live_router
    app.include_router(trfmc_core_live_router)
except Exception as e:
    print("TRFMC_CORE_LIVE_ROUTER_DISABLED", e)

@app.get("/api/trfmc-backend-ready")
def trfmc_backend_ready():
    return {"status": "ok", "service": "trfmc-backend", "core_live": True}
'''

if s != original:
    main.write_text(s)
    print("PATCH_OK: main.py aggiornato con Core Live router/CORS")
else:
    print("INFO: main.py già aggiornato")
PY

echo
echo "[5/10] Avvio backend FastAPI su 127.0.0.1:8000"
PIDS="$(lsof -ti tcp:8000 2>/dev/null || true)"
if [ -n "$PIDS" ]; then
  echo "Kill processi su porta 8000: $PIDS"
  kill $PIDS 2>/dev/null || true
  sleep 2
fi

if [ -d "$BASE/.venv" ]; then
  source "$BASE/.venv/bin/activate"
else
  python3 -m venv "$BASE/.venv"
  source "$BASE/.venv/bin/activate"
fi

python -m pip install --upgrade pip wheel >/dev/null 2>&1 || true
python -m pip install fastapi uvicorn pydantic python-multipart >/dev/null 2>&1 || true

nohup bash -lc "
cd '$BASE'
source .venv/bin/activate
export PYTHONPATH=\"\$PWD/backend\"
export TRFMC_BASE=\"\$PWD\"
export TRFMC_RUNTIME=\"\$PWD/runtime\"
exec uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000 --reload
" > "$BASE/runtime/logs/backend_8000.log" 2>&1 &

sleep 6

echo
echo "[6/10] Creo pagina WebGL Core Network Live Ops Bridge"
if [ ! -f "$PUBLIC/vendor/three/build/three.module.js" ]; then
  if [ ! -d "$FRONT/node_modules/three" ]; then
    npm --prefix "$FRONT" install three@0.164.1
  fi
  cp -av "$FRONT/node_modules/three/build/three.module.js" "$PUBLIC/vendor/three/build/three.module.js"
  cp -av "$FRONT/node_modules/three/examples/jsm/controls/OrbitControls.js" "$PUBLIC/vendor/three/examples/jsm/controls/OrbitControls.js"
fi

cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC 5G Core Network Live Ops Bridge</title>
<style>
:root{--bg:#01060d;--p:#061827;--line:#0b75a8;--cyan:#00e5ff;--ok:#75ff5b;--warn:#ffd84d;--bad:#ff3d7f;--txt:#e8f9ff;--muted:#84a8ba}
*{box-sizing:border-box}
html,body{margin:0;height:100%;overflow:hidden;background:radial-gradient(circle at 50% -10%,#07365a,#02070d 42%,#00050a);color:var(--txt);font-family:Inter,Segoe UI,Arial,sans-serif}
.app{height:100vh;display:grid;grid-template-rows:62px 82px 1fr;gap:6px;padding:8px}
.top,.kpi,.panel{border:1px solid #0b5f8a;background:rgba(3,14,24,.95);box-shadow:0 0 18px rgba(0,160,255,.10)}
.top{display:grid;grid-template-columns:1fr auto;align-items:center;padding:9px 12px}
h1{font-size:20px;letter-spacing:2px;margin:0}.sub{color:var(--muted);font-size:12px}
.actions{display:flex;gap:6px;align-items:center}button,select{background:#0b2238;border:1px solid #1175a5;color:var(--txt);border-radius:4px;padding:7px 10px;font-size:12px}
.led{width:10px;height:10px;border-radius:50%;background:var(--ok);box-shadow:0 0 12px var(--ok)}
.kpis{display:grid;grid-template-columns:repeat(12,1fr);gap:6px}
.kpi{padding:7px 8px}.kpi .l{font-size:9px;color:#80bad0;text-transform:uppercase}.kpi .v{font-size:17px;font-weight:800}.kpi .s{font-size:10px;color:var(--ok)}
.main{display:grid;grid-template-columns:300px 1fr 380px;gap:6px;min-height:0}
.panel{overflow:hidden}.panel h2{margin:0;padding:8px 10px;border-bottom:1px solid #0b5f8a;color:var(--cyan);font-size:13px;text-transform:uppercase}.body{padding:9px;height:calc(100% - 35px);overflow:auto}
.viewport{position:relative;border:1px solid #0d6f9e;background:#020b12;min-height:0}#threeRoot{position:absolute;inset:0}
.overlay{position:absolute;left:10px;top:10px;font-family:monospace;font-size:11px;color:var(--ok);background:rgba(0,0,0,.50);border:1px solid #154e34;padding:6px 8px;z-index:5}
.card{border:1px solid #104e73;background:#061625;padding:8px;border-radius:4px;margin-bottom:6px}.card h3{margin:0 0 7px;font-size:12px;color:var(--cyan)}
.table{width:100%;border-collapse:collapse;font-size:11px}.table th,.table td{border-bottom:1px solid #12344c;padding:5px;text-align:left}.table th{color:#83cfff}
.log{height:310px;background:#02070d;border:1px solid #123f5d;padding:7px;overflow:auto;font-family:monospace;font-size:10px;color:#bcecff}
.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}.mini{font-family:monospace;font-size:11px;color:#b9eaff;line-height:1.45}
</style>
<script type="importmap">
{"imports":{"three":"/vendor/three/build/three.module.js","three/addons/":"/vendor/three/examples/jsm/"}}
</script>
</head>
<body>
<div class="app">
<header class="top">
  <div><h1>TRFMC 5G CORE NETWORK LIVE OPS BRIDGE</h1><div class="sub">Open5GS · UERANSIM · NGAP · PFCP · GTP-U · ogstun · SUPI/SUCI/AKA evidence path · live operational bridge</div></div>
  <div class="actions">
    <button onclick="refresh()">Refresh</button>
    <button onclick="openApi()">API</button>
    <button onclick="exportJson()">Export JSON</button>
    <span class="led"></span><span id="clock" class="mini">--:--:--</span>
  </div>
</header>

<section class="kpis">
  <div class="kpi"><div class="l">Backend</div><div class="v" id="kBackend">--</div><div class="s">8000</div></div>
  <div class="kpi"><div class="l">State</div><div class="v" id="kState">--</div><div class="s">core live</div></div>
  <div class="kpi"><div class="l">Score</div><div class="v" id="kScore">--</div><div class="s">gates</div></div>
  <div class="kpi"><div class="l">Open5GS</div><div class="v" id="kOpen5gs">--</div><div class="s">process</div></div>
  <div class="kpi"><div class="l">UERANSIM</div><div class="v" id="kUeransim">--</div><div class="s">gNB/UE</div></div>
  <div class="kpi"><div class="l">NGAP</div><div class="v" id="kNgap">--</div><div class="s">38412</div></div>
  <div class="kpi"><div class="l">PFCP</div><div class="v" id="kPfcp">--</div><div class="s">8805</div></div>
  <div class="kpi"><div class="l">GTP-U</div><div class="v" id="kGtpu">--</div><div class="s">2152</div></div>
  <div class="kpi"><div class="l">ogstun</div><div class="v" id="kOgstun">--</div><div class="s">TUN</div></div>
  <div class="kpi"><div class="l">SUPI</div><div class="v" id="kSupi">--</div><div class="s">cfg</div></div>
  <div class="kpi"><div class="l">Script</div><div class="v" id="kScript">--</div><div class="s">5g-start</div></div>
  <div class="kpi"><div class="l">Gate</div><div class="v" id="kGate">--</div><div class="s">live</div></div>
</section>

<main class="main">
<aside class="panel"><h2>Core Controls</h2><div class="body">
  <div class="card"><h3>Operational Philosophy</h3><div class="mini">
    Questa pagina non forza start/stop. Prima legge stato, processi, porte, config e tunnel. Le azioni operative verranno aggiunte solo dopo gate stabile.
  </div></div>
  <div class="card"><h3>5G Chain</h3>
    <table class="table">
      <tr><th>Layer</th><th>Check</th></tr>
      <tr><td>RAN</td><td>nr-gnb / nr-ue</td></tr>
      <tr><td>Control</td><td>NGAP 38412</td></tr>
      <tr><td>Session</td><td>PFCP 8805</td></tr>
      <tr><td>User Plane</td><td>GTP-U 2152 / ogstun</td></tr>
      <tr><td>Identity</td><td>SUPI/SUCI/AKA path</td></tr>
    </table>
  </div>
  <div class="card"><h3>API</h3><div class="mini">
    /api/core-live/health<br>
    /api/core-live/status<br>
    /api/core-live/events
  </div></div>
</div></aside>

<section class="viewport">
  <div id="threeRoot"></div>
  <div class="overlay" id="overlay">Core Network WebGL topology · waiting for API...</div>
</section>

<aside class="panel"><h2>Live Evidence</h2><div class="body">
  <div class="card"><h3>Gates</h3><table class="table" id="gateTable"><tbody></tbody></table></div>
  <div class="card"><h3>Ports / Processes</h3><div class="mini" id="procOut">--</div></div>
  <div class="card"><h3>Event Stream</h3><div class="log" id="log"></div></div>
</div></aside>
</main>
</div>

<script type="module">
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const $=id=>document.getElementById(id);
let scene,camera,renderer,controls,root,links=[],nodes={},last=null,tick=0;

function log(m){$("log").textContent = `[${new Date().toLocaleTimeString()}] ${m}\n` + $("log").textContent.split("\n").slice(0,90).join("\n");}
function ok(v){return v ? "PASS" : "WARN"}
function color(v){return v ? "ok" : "warn"}

function init3d(){
  const el=$("threeRoot"), r=el.getBoundingClientRect();
  scene=new THREE.Scene(); scene.background=new THREE.Color(0x02070d); scene.fog=new THREE.Fog(0x02070d,12,42);
  camera=new THREE.PerspectiveCamera(45,r.width/r.height,.1,100);
  renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:"high-performance"});
  renderer.setPixelRatio(Math.min(devicePixelRatio||1,2)); renderer.setSize(r.width,r.height);
  renderer.shadowMap.enabled=true; renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  el.appendChild(renderer.domElement);
  controls=new OrbitControls(camera,renderer.domElement); controls.enableDamping=true;

  scene.add(new THREE.HemisphereLight(0xb6f3ff,0x061018,1.3));
  const key=new THREE.DirectionalLight(0xffffff,2.2); key.position.set(5,8,6); key.castShadow=true; scene.add(key);
  const grid=new THREE.GridHelper(12,24,0x0b75a8,0x063448); grid.material.opacity=.3; grid.material.transparent=true; scene.add(grid);

  const matCore=new THREE.MeshStandardMaterial({color:0x00a7c9,metalness:.45,roughness:.34,emissive:0x001b24});
  const matWarn=new THREE.MeshStandardMaterial({color:0xffd84d,metalness:.3,roughness:.32,emissive:0x221800});
  const matOk=new THREE.MeshStandardMaterial({color:0x75ff5b,metalness:.2,roughness:.28,emissive:0x0b2408});
  const matLink=new THREE.MeshBasicMaterial({color:0x00e5ff,transparent:true,opacity:.55});

  function node(name,x,y,z,mat){
    const g=new THREE.Group(); g.name=name;
    const body=new THREE.Mesh(new THREE.BoxGeometry(.8,.42,.55),mat); body.castShadow=true; body.receiveShadow=true; g.add(body);
    const top=new THREE.Mesh(new THREE.SphereGeometry(.16,24,16),matOk); top.position.y=.34; g.add(top);
    g.position.set(x,y,z); scene.add(g); nodes[name]=g; return g;
  }
  ["gNB","AMF","SMF","UPF","AUSF","UDM","UE","DN"].forEach((n,i)=>{});
  node("UE",-4,.5,1.8,matWarn); node("gNB",-2,.8,1.1,matCore); node("AMF",0,1,1.1,matCore);
  node("SMF",1.8,1,.4,matCore); node("UPF",3.6,.9,.4,matCore); node("DN",5,.6,.4,matOk);
  node("AUSF",0,.8,-1.2,matCore); node("UDM",1.8,.8,-1.2,matCore);

  function tube(a,b,name){
    const A=nodes[a].position, B=nodes[b].position;
    const curve=new THREE.CatmullRomCurve3([A.clone(),A.clone().lerp(B,.5).add(new THREE.Vector3(0,.25,0)),B.clone()]);
    const m=new THREE.Mesh(new THREE.TubeGeometry(curve,32,.025,8,false),matLink); m.name=name; scene.add(m); links.push(m);
  }
  tube("UE","gNB","RRC/NAS"); tube("gNB","AMF","NGAP"); tube("AMF","SMF","N11"); tube("SMF","UPF","PFCP"); tube("UPF","DN","GTP-U/DN");
  tube("AMF","AUSF","N12"); tube("AUSF","UDM","N13"); tube("UDM","SMF","subscription");

  camera.position.set(6,5,6); controls.target.set(.7,.6,0); controls.update();
}
function updateScene(data){
  const gates=data.gates||{};
  const live=gates.open5gs_process_seen && gates.ueransim_process_seen;
  for(const [name,obj] of Object.entries(nodes)){
    obj.scale.setScalar(live?1.05:1.0);
  }
  links.forEach((l,i)=>{l.material.opacity = .38 + Math.sin((tick+i*15)/25)*.18;});
  $("overlay").textContent=`Core state ${data.state} · score ${data.score}/${data.score_total} · Open5GS ${ok(gates.open5gs_process_seen)} · UERANSIM ${ok(gates.ueransim_process_seen)}`;
}
async function refresh(){
  try{
    const res=await fetch("http://127.0.0.1:8000/api/core-live/status",{cache:"no-store"});
    last=await res.json();
    const g=last.gates||{};
    $("kBackend").textContent="OK"; $("kState").textContent=last.state||"--"; $("kScore").textContent=`${last.score}/${last.score_total}`;
    $("kOpen5gs").textContent=ok(g.open5gs_process_seen); $("kUeransim").textContent=ok(g.ueransim_process_seen);
    $("kNgap").textContent=ok(g.ngap_38412_seen); $("kPfcp").textContent=ok(g.pfcp_8805_seen); $("kGtpu").textContent=ok(g.gtpu_2152_seen);
    $("kOgstun").textContent=ok(g.ogstun_present); $("kScript").textContent=ok(g.start_script_present);
    $("kGate").textContent=(last.score>=6)?"PASS":"WARN";
    const cfg=last.configs||{}; let supi="--";
    for(const v of Object.values(cfg)){ if(v.supi && v.supi.length) supi=v.supi[0].slice(0,6)+"…"; }
    $("kSupi").textContent=supi;

    $("gateTable").innerHTML=Object.entries(g).map(([k,v])=>`<tr><td>${k}</td><td class="${color(v)}">${ok(v)}</td></tr>`).join("");
    $("procOut").innerHTML=
      `Open5GS processes: ${(last.processes.open5gs||[]).length}<br>`+
      `UERANSIM processes: ${(last.processes.ueransim||[]).length}<br>`+
      `Ports observed: ${(last.ports||[]).length}<br>`+
      `Routes: ${(last.routes||[]).length}<br>`;
    updateScene(last); log("core-live status refreshed");
  }catch(e){
    $("kBackend").textContent="WARN"; $("overlay").textContent="Backend 8000 not reachable: "+e.message; log("backend error: "+e.message);
  }
}
function animate(){requestAnimationFrame(animate); tick++; $("clock").textContent=new Date().toLocaleTimeString(); links.forEach((l,i)=>l.material.opacity=.35+Math.sin((tick+i*20)/30)*.20); controls.update(); renderer.render(scene,camera);}
window.refresh=refresh; window.openApi=()=>window.open("http://127.0.0.1:8000/api/core-live/status","_blank");
window.exportJson=()=>{const b=new Blob([JSON.stringify(last||{},null,2)],{type:"application/json"});const a=document.createElement("a");a.href=URL.createObjectURL(b);a.download="trfmc_core_live_status.json";a.click();};
addEventListener("resize",()=>{const r=$("threeRoot").getBoundingClientRect();camera.aspect=r.width/r.height;camera.updateProjectionMatrix();renderer.setSize(r.width,r.height);});
init3d(); refresh(); setInterval(refresh,5000); animate(); log("Core Network Live Ops Bridge online");
</script>
</body>
</html>
HTML

echo
echo "[7/10] Gate pagina + backend"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html" \
  "http://127.0.0.1:5173/vendor/three/build/three.module.js" \
  "http://127.0.0.1:5173/vendor/three/examples/jsm/controls/OrbitControls.js" \
  "http://127.0.0.1:8000/api/trfmc-backend-ready" \
  "http://127.0.0.1:8000/api/core-live/health" \
  "http://127.0.0.1:8000/api/core-live/status" \
  "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html" \
  "http://127.0.0.1:5173/api/health"
do
  http_full "$u" >> "$OUT/http.tsv"
done

grep -nEi '<iframe|http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' "$PAGE" > "$OUT/page_refs.txt" 2>/dev/null || true
grep -nEi 'WebGLRenderer|OrbitControls|core-live|NGAP|PFCP|GTP-U|Open5GS|UERANSIM' "$PAGE" > "$OUT/core_markers.txt" 2>/dev/null || true

echo
echo "[8/10] Promuovo in V6R3 solo se backend e pagina sono raggiungibili"
export OUT V6R3
python3 - <<'PY'
import os, json, re
from pathlib import Path
from datetime import datetime, timezone

out=Path(os.environ["OUT"])
v6r3=Path(os.environ["V6R3"])

non200=0
http_lines=(out/"http.tsv").read_text(errors="ignore").splitlines()[1:]
for line in http_lines:
    p=line.split("\t")
    if len(p)>=2 and p[1].strip()!="200":
        non200 += 1

markers=(out/"core_markers.txt").read_text(errors="ignore")
marker_ok=all(x in markers for x in ["WebGLRenderer","OrbitControls","core-live","NGAP","PFCP","GTP-U","Open5GS","UERANSIM"])

promoted=False
if non200 == 0 and marker_ok and v6r3.exists():
    s=v6r3.read_text(errors="ignore")
    module=''' corelive:{icon:"5GC",name:"5G Core Live Ops Bridge",desc:"Open5GS · UERANSIM · NGAP/PFCP/GTP-U · ogstun · live backend diagnostics",url:"/trfmc_core_network_live_ops_bridge_v1.html"},
'''
    button='''        <button onclick="load('corelive')">Core Live</button>
'''
    changed=False
    if "/trfmc_core_network_live_ops_bridge_v1.html" not in s:
        if "const M={\n" in s:
            s=s.replace("const M={\n","const M={\n"+module,1)
            changed=True
        elif "const M={" in s:
            s=s.replace("const M={","const M={\n"+module,1)
            changed=True
    if "load('corelive')" not in s:
        for mk in [
            '''        <button onclick="load('webgl3d')">3D WebGL</button>''',
            '''        <button onclick="load('metrology')">RF Metrology</button>''',
            '''        <button onclick="load('sigintel')">Signal Intel</button>''',
        ]:
            if mk in s:
                s=s.replace(mk,mk+"\n"+button.rstrip(),1)
                changed=True
                break
    if changed:
        v6r3.write_text(s)
    promoted=True

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "core_live_page":"http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html",
  "backend_ready":"http://127.0.0.1:8000/api/trfmc-backend-ready",
  "core_live_status":"http://127.0.0.1:8000/api/core-live/status",
  "http_non_200":non200,
  "markers_ok":marker_ok,
  "promoted_into_v6r3":promoted,
  "result":"PASS" if non200==0 and marker_ok and promoted else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_core_network_live_ops_bridge_v1"

echo
echo "[9/10] Report"
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
echo "[10/10] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_CORE_NETWORK_LIVE_OPS_BRIDGE_V1_$TS.tar.gz"
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
  echo "CORE NETWORK LIVE OPS BRIDGE VALIDATO E AGGANCIATO IN V6R3"
  echo "V6R3:"
  echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
  echo
  echo "Modulo diretto:"
  echo "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html"
  echo
  echo "API:"
  echo "http://127.0.0.1:8000/api/core-live/status"
  echo "============================================================"
else
  echo
  echo "============================================================"
  echo "WARN: non ho promosso/congelato perché il gate non è PASS."
  echo "Guarda report:"
  echo "$OUT"
  echo "Log backend:"
  echo "$BASE/runtime/logs/backend_8000.log"
  echo "============================================================"
fi
