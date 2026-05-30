#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets/trfmc_design_system"
PREVIEW="$PUBLIC/trfmc_visual_master_preview_v1.html"
ROADMAP="$PUBLIC/trfmc_visual_master_roadmap_v1.json"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_VISUAL_MASTER_PREVIEW_V1_$TS"
LATEST="$BASE/runtime/quality/latest_visual_master_preview"

mkdir -p "$ASSETS" "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/rejected_scripts"

echo "============================================================"
echo "TRFMC VISUAL MASTER PREVIEW V1 SAFE"
echo "Preview separata · no iframe · no CDN · V6R3 intoccata"
echo "============================================================"

cd "$BASE"

echo
echo "[1/8] Quarantena eventuale script fused NON ammesso"
if [ -f trfmc_create_master_fused_portal_v1.sh ]; then
  cp -av trfmc_create_master_fused_portal_v1.sh \
    "runtime/rejected_scripts/trfmc_create_master_fused_portal_v1_REJECTED_$TS.sh" || true
  chmod -x trfmc_create_master_fused_portal_v1.sh || true
fi

cat > runtime/rejected_scripts/README_REJECTED_MASTER_FUSED_PORTAL.txt <<EOF2
Script non ammesso: trfmc_create_master_fused_portal_v1.sh

Motivo:
- crea una nuova shell candidata;
- usa iframe come viewer strutturale;
- rischia portale dentro portale;
- può creare doppie/triple barre;
- non rispetta la decisione V6R3 ufficiale + preview separata.

Data: $(date)
EOF2

echo
echo "[2/8] Snapshot pre-modifica dei soli file che tocchiamo"
cp -av "$ASSETS/trfmc_visual_master_v1.css" \
  "$BASE/runtime/backups/trfmc_visual_master_v1_before_$TS.css.bak" 2>/dev/null || true

cp -av "$PREVIEW" \
  "$BASE/runtime/backups/trfmc_visual_master_preview_v1_before_$TS.html.bak" 2>/dev/null || true

cp -av "$ROADMAP" \
  "$BASE/runtime/backups/trfmc_visual_master_roadmap_v1_before_$TS.json.bak" 2>/dev/null || true

V6R3_SHA_BEFORE="$(sha256sum "$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html" | awk '{print $1}')"
CONTROL_SHA_BEFORE="$(sha256sum "$PUBLIC/trfmc_integration_control_room.html" | awk '{print $1}')"
REG_SHA_BEFORE="$(sha256sum "$PUBLIC/trfmc_portal_registry_unified.json" | awk '{print $1}')"

echo "V6R3_SHA_BEFORE=$V6R3_SHA_BEFORE" > "$OUT/pre_sha.txt"
echo "CONTROL_SHA_BEFORE=$CONTROL_SHA_BEFORE" >> "$OUT/pre_sha.txt"
echo "REG_SHA_BEFORE=$REG_SHA_BEFORE" >> "$OUT/pre_sha.txt"

echo
echo "[3/8] Creo Visual Master CSS V1"
cat > "$ASSETS/trfmc_visual_master_v1.css" <<'CSS'
:root{
  --vm-bg:#02060d;
  --vm-bg2:#061827;
  --vm-panel:rgba(5,18,31,.88);
  --vm-panel2:rgba(8,32,52,.92);
  --vm-line:#0c7fb8;
  --vm-line2:#00e5ff;
  --vm-text:#e9fbff;
  --vm-muted:#8fb8c8;
  --vm-green:#75ff5b;
  --vm-yellow:#ffd84d;
  --vm-red:#ff3d7f;
  --vm-blue:#1e9cff;
  --vm-violet:#9b7cff;
  --vm-shadow:0 0 34px rgba(0,229,255,.16);
  --vm-font:Inter,Segoe UI,Arial,sans-serif;
}
*{box-sizing:border-box}
body.trfmc-vm{
  margin:0;
  min-height:100vh;
  overflow:hidden;
  background:
    radial-gradient(circle at 18% 0%,rgba(0,229,255,.12),transparent 27%),
    radial-gradient(circle at 84% 12%,rgba(117,255,91,.08),transparent 22%),
    linear-gradient(180deg,#02060d,#010409 70%);
  color:var(--vm-text);
  font-family:var(--vm-font);
}
.trfmc-vm::before{
  content:"";
  position:fixed;
  inset:0;
  pointer-events:none;
  background-image:
    linear-gradient(rgba(0,229,255,.05) 1px,transparent 1px),
    linear-gradient(90deg,rgba(0,229,255,.05) 1px,transparent 1px);
  background-size:44px 44px;
  mask-image:linear-gradient(to bottom,rgba(0,0,0,.72),transparent);
}
.vm-top{
  height:78px;
  display:grid;
  grid-template-columns:1.1fr 2fr .9fr;
  align-items:center;
  gap:12px;
  padding:12px 16px;
  border-bottom:1px solid rgba(0,229,255,.34);
  background:linear-gradient(90deg,rgba(4,16,27,.95),rgba(6,36,58,.9),rgba(4,16,27,.95));
  box-shadow:var(--vm-shadow);
  position:relative;
  z-index:5;
}
.vm-title{
  color:var(--vm-line2);
  font-size:18px;
  font-weight:900;
  letter-spacing:2px;
  text-transform:uppercase;
}
.vm-sub{
  color:var(--vm-muted);
  font-size:11px;
  margin-top:3px;
}
.vm-kpis{
  display:grid;
  grid-template-columns:repeat(5,1fr);
  gap:7px;
}
.vm-kpi{
  border:1px solid rgba(0,229,255,.28);
  background:rgba(7,24,39,.72);
  padding:7px;
  min-height:48px;
}
.vm-kpi small{
  display:block;
  color:var(--vm-muted);
  font-size:9px;
  text-transform:uppercase;
}
.vm-kpi b{
  display:block;
  color:var(--vm-green);
  font-size:17px;
  margin-top:2px;
}
.vm-actions{
  display:flex;
  flex-wrap:wrap;
  justify-content:flex-end;
  gap:6px;
}
.vm-btn{
  display:inline-block;
  border:1px solid rgba(0,229,255,.36);
  background:rgba(6,36,58,.76);
  color:var(--vm-line2);
  padding:7px 9px;
  border-radius:5px;
  text-decoration:none;
  font-size:11px;
  cursor:pointer;
}
.vm-btn:hover{box-shadow:0 0 18px rgba(0,229,255,.22)}
.vm-layout{
  height:calc(100vh - 78px);
  display:grid;
  grid-template-columns:330px 1fr 360px;
  gap:7px;
  padding:7px;
  position:relative;
  z-index:2;
}
.vm-panel{
  border:1px solid rgba(0,229,255,.28);
  background:linear-gradient(180deg,var(--vm-panel2),rgba(2,8,14,.94));
  box-shadow:inset 0 0 0 1px rgba(0,229,255,.04);
  min-height:0;
  overflow:hidden;
}
.vm-panel h2{
  margin:0;
  padding:9px 11px;
  border-bottom:1px solid rgba(12,127,184,.55);
  color:var(--vm-line2);
  font-size:12px;
  letter-spacing:1.1px;
  text-transform:uppercase;
}
.vm-scroll{
  height:calc(100% - 34px);
  overflow:auto;
  padding:9px;
}
.vm-tools{
  padding:9px;
  border-bottom:1px solid rgba(12,127,184,.45);
}
.vm-input,.vm-select{
  width:100%;
  margin-bottom:7px;
  background:#03101a;
  color:var(--vm-text);
  border:1px solid rgba(0,229,255,.35);
  border-radius:5px;
  padding:8px;
  font-size:12px;
}
.vm-card{
  border:1px solid rgba(12,127,184,.55);
  background:rgba(3,16,26,.78);
  border-radius:8px;
  padding:9px;
  margin-bottom:8px;
  position:relative;
  overflow:hidden;
}
.vm-card::after{
  content:"";
  position:absolute;
  right:-42px;
  top:-42px;
  width:120px;
  height:120px;
  background:radial-gradient(circle,rgba(0,229,255,.11),transparent 70%);
}
.vm-card h3{
  margin:0 0 7px;
  color:var(--vm-yellow);
  font-size:12px;
  position:relative;
  z-index:1;
}
.vm-meta,.vm-note,.vm-card li{
  color:var(--vm-muted);
  font-size:11px;
  line-height:1.42;
  position:relative;
  z-index:1;
}
.vm-badge{
  display:inline-block;
  border:1px solid rgba(0,229,255,.35);
  color:var(--vm-line2);
  background:rgba(0,229,255,.06);
  border-radius:5px;
  padding:2px 6px;
  font-size:9px;
  margin:2px 3px 0 0;
  position:relative;
  z-index:1;
}
.vm-ok{color:var(--vm-green);border-color:rgba(117,255,91,.4)}
.vm-warn{color:var(--vm-yellow);border-color:rgba(255,216,77,.4)}
.vm-bad{color:var(--vm-red);border-color:rgba(255,61,127,.4)}
.vm-stage{
  position:relative;
  min-height:0;
  overflow:hidden;
}
#vmWebgl{
  width:100%;
  height:100%;
  display:block;
}
.vm-overlay{
  position:absolute;
  inset:0;
  pointer-events:none;
  display:grid;
  grid-template-rows:auto 1fr auto;
}
.vm-stage-head{
  margin:14px;
  padding:12px;
  border:1px solid rgba(0,229,255,.28);
  background:rgba(2,8,14,.52);
  backdrop-filter:blur(8px);
}
.vm-stage-title{
  color:var(--vm-line2);
  font-weight:900;
  letter-spacing:1px;
}
.vm-stage-sub{
  color:var(--vm-muted);
  font-size:12px;
  margin-top:4px;
}
.vm-stage-foot{
  margin:14px;
  padding:9px;
  border:1px solid rgba(0,229,255,.24);
  background:rgba(2,8,14,.48);
  color:var(--vm-muted);
  font-size:11px;
  display:grid;
  grid-template-columns:repeat(5,1fr);
  gap:8px;
}
.vm-log{
  height:150px;
  overflow:auto;
  background:#010409;
  border:1px solid rgba(12,127,184,.55);
  color:var(--vm-green);
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
  padding:8px;
}
@media(max-width:1200px){
  body.trfmc-vm{overflow:auto}
  .vm-layout{height:auto;grid-template-columns:1fr}
  .vm-stage{height:520px}
  .vm-top{height:auto;grid-template-columns:1fr}
  .vm-kpis{grid-template-columns:repeat(2,1fr)}
}
CSS

echo
echo "[4/8] Creo roadmap / matrice moduli mancanti"
python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
public = base / "frontend/public"

registry_path = public / "trfmc_portal_registry_unified.json"
registry = json.loads(registry_path.read_text()) if registry_path.exists() else {"pages":[]}
pages = registry.get("pages", [])
names = {p.get("name",""): p for p in pages}
urls = {p.get("url",""): p for p in pages}

target_modules = [
  {"id":"official_v6r3","area":"00 Governance","title":"V6R3 Official Command Center","url":"/trfmc_official_safe_entrypoint_v6r3_command_center.html","status":"LOCKED_BASELINE","priority":100},
  {"id":"control_room","area":"00 Governance","title":"Integration Control Room","url":"/trfmc_integration_control_room.html","status":"ACTIVE","priority":98},
  {"id":"control_room_v2","area":"00 Governance","title":"Integration Control Room V2 Preview","url":"/trfmc_integration_control_room_v2.html","status":"ACTIVE_PREVIEW","priority":97},
  {"id":"visual_donor","area":"01 Visual Twin","title":"3D RF Asset Renderer WebGL V2R2 Reality","url":"/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html","status":"VISUAL_DONOR","priority":96},
  {"id":"rf_physics","area":"02 RF Physics","title":"WebGL RF Physics Engine V85E","url":"/webgl_rf_physics_engine_v85e_viewport_discipline.html","status":"ACTIVE_LEAF","priority":94},
  {"id":"signal_intelligence","area":"03 Signal Analyzer","title":"Signal Intelligence Center","url":"/trfmc_signal_intelligence_center_v1.html","status":"ACTIVE_LEAF_OR_CHECK","priority":92},
  {"id":"rf_metrology","area":"04 RF Microwave Engineering","title":"RF Metrology Calibration Lab","url":"/trfmc_rf_metrology_calibration_lab_v1.html","status":"ACTIVE_LEAF_OR_CHECK","priority":90},
  {"id":"smith_microwave","area":"04 RF Microwave Engineering","title":"RF Microwave / Smith Chart Lab","url":"/trfmc_rf_microwave_engineering_v1.html","status":"ACTIVE_LEAF_OR_CHECK","priority":88},
  {"id":"antenna_system","area":"05 Antenna System","title":"Antenna System Explorer","url":"/trfmc_antenna_system_explorer_STABLE_CLEAN_RECOVERY.html","status":"ACTIVE_LEAF_OR_CHECK","priority":86},
  {"id":"microwave_link","area":"06 Microwave Link","title":"Microwave Link Operations Center","url":"","status":"MISSING_TO_BUILD","priority":84},
  {"id":"fiber_optic","area":"07 Fiber Optic","title":"Fiber / CPRI / ODF / OTDR Workbench","url":"","status":"MISSING_TO_BUILD","priority":82},
  {"id":"private_networks","area":"08 Private Networks","title":"5G Private / Wi-Fi 7 / MLO / Industrial Mesh","url":"","status":"MISSING_TO_BUILD","priority":80},
  {"id":"core_identity","area":"09 Core Network","title":"5G Core / RAN Identity AKA Engine","url":"/trfmc_5g_core_ran_identity_aka_engine_v1.html","status":"ACTIVE_LEAF_OR_CHECK","priority":78},
  {"id":"core_live","area":"09 Core Network","title":"Core Network Live Ops Bridge","url":"/trfmc_core_network_live_ops_bridge_v1.html","status":"ACTIVE_LEAF_OR_CHECK","priority":76},
  {"id":"datacenter","area":"10 Data Center Infrastructure","title":"Rack / PDU / UPS / Grounding / SNMP","url":"","status":"MISSING_TO_BUILD","priority":74},
  {"id":"cyber_rf","area":"11 Cyber RF Intelligence","title":"Cyber RF Intelligence / Jamming / Rogue RF / Evidence","url":"","status":"MISSING_TO_BUILD","priority":72},
  {"id":"knowledge","area":"12 Knowledge Base","title":"Glossary / Formulas / Procedures / Lesson Plan","url":"","status":"MISSING_TO_BUILD","priority":70}
]

for m in target_modules:
    if m["url"]:
        p = public / m["url"].lstrip("/")
        m["exists"] = p.exists()
        m["size"] = p.stat().st_size if p.exists() else 0
        m["registry_present"] = m["url"] in urls
    else:
        m["exists"] = False
        m["size"] = 0
        m["registry_present"] = False

roadmap = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "policy": "Visual Master Preview only. V6R3 remains official. No iframe. No CDN. No shell promotion.",
    "official_shell": "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "preview": "/trfmc_visual_master_preview_v1.html",
    "counts": {
        "total_targets": len(target_modules),
        "existing": sum(1 for x in target_modules if x["exists"]),
        "missing_to_build": sum(1 for x in target_modules if not x["exists"]),
        "registry_present": sum(1 for x in target_modules if x["registry_present"])
    },
    "modules": target_modules
}
(public / "trfmc_visual_master_roadmap_v1.json").write_text(json.dumps(roadmap, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(roadmap["counts"], indent=2))
PY

echo
echo "[5/8] Creo preview HTML senza iframe"
cat > "$PREVIEW" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Visual Master Preview V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_visual_master_v1.css">
</head>
<body class="trfmc-vm">
<header class="vm-top">
  <div>
    <div class="vm-title">TRFMC Visual Master Preview V1</div>
    <div class="vm-sub">preview separata · no iframe · no CDN · V6R3 ufficiale intoccata · WebGL GPU visual discipline</div>
  </div>
  <div class="vm-kpis">
    <div class="vm-kpi"><small>Roadmap</small><b id="kRoadmap">--</b></div>
    <div class="vm-kpi"><small>Existing</small><b id="kExisting">--</b></div>
    <div class="vm-kpi"><small>Missing</small><b id="kMissing">--</b></div>
    <div class="vm-kpi"><small>Registry</small><b id="kRegistry">--</b></div>
    <div class="vm-kpi"><small>Policy</small><b>SAFE</b></div>
  </div>
  <div class="vm-actions">
    <a class="vm-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html" target="_blank">V6R3</a>
    <a class="vm-btn" href="/trfmc_integration_control_room.html" target="_blank">Control Room</a>
    <a class="vm-btn" href="/trfmc_portal_registry_unified.json" target="_blank">Registry</a>
    <a class="vm-btn" href="/trfmc_visual_master_roadmap_v1.json" target="_blank">Roadmap</a>
  </div>
</header>

<div class="vm-layout">
  <aside class="vm-panel">
    <h2>Moduli / Roadmap</h2>
    <div class="vm-tools">
      <input id="q" class="vm-input" placeholder="cerca area, modulo, stato...">
      <select id="area" class="vm-select"><option value="">tutte le aree</option></select>
    </div>
    <div id="modules" class="vm-scroll"></div>
  </aside>

  <main class="vm-panel vm-stage">
    <canvas id="vmWebgl"></canvas>
    <div class="vm-overlay">
      <div class="vm-stage-head">
        <div class="vm-stage-title" id="activeTitle">TRFMC Unified RF/Telco/Cyber Visual Layer</div>
        <div class="vm-stage-sub" id="activeSub">Questa non è una nuova shell: è una preview grafica controllata per estrarre lo stile master.</div>
      </div>
      <div></div>
      <div class="vm-stage-foot">
        <div>Render: <span class="vm-ok" id="glState">init</span></div>
        <div>Shell: V6R3 locked</div>
        <div>Iframe: denied</div>
        <div>CDN: denied</div>
        <div>Promotion: quality gate</div>
      </div>
    </div>
  </main>

  <aside class="vm-panel">
    <h2>Decisione / Mancanti</h2>
    <div class="vm-scroll">
      <div class="vm-card">
        <h3>Regola operativa</h3>
        <div class="vm-note">
          Questo livello serve a creare lo stile 3D/GPU comune e la matrice dei moduli mancanti.
          Non sostituisce V6R3 e non ingloba pagine tramite iframe.
        </div>
        <div>
          <span class="vm-badge vm-ok">NO IFRAME</span>
          <span class="vm-badge vm-ok">NO CDN</span>
          <span class="vm-badge vm-ok">V6R3 LOCKED</span>
        </div>
      </div>

      <div class="vm-card">
        <h3>Modulo attivo</h3>
        <div id="activeDesc" class="vm-note">--</div>
        <div id="activeBadges"></div>
        <div style="margin-top:8px">
          <a id="openActive" class="vm-btn" href="#" target="_blank">Apri se esiste</a>
        </div>
      </div>

      <div class="vm-card">
        <h3>Cosa manca da costruire</h3>
        <ul id="missingList"></ul>
      </div>

      <div class="vm-card">
        <h3>Event stream</h3>
        <div id="log" class="vm-log"></div>
      </div>
    </div>
  </aside>
</div>

<script>
let ROADMAP=null;
let ACTIVE=null;

function $(id){return document.getElementById(id)}
function log(m){
  const t=new Date().toLocaleTimeString();
  $("log").textContent = `[${t}] ${m}\n` + $("log").textContent;
}
function badge(t,cls=""){return `<span class="vm-badge ${cls}">${t}</span>`}

function renderModules(){
  const q=$("q").value.toLowerCase();
  const area=$("area").value;
  const list=ROADMAP.modules.filter(m=>{
    const blob=(m.area+" "+m.title+" "+m.status+" "+m.url).toLowerCase();
    if(q && !blob.includes(q)) return false;
    if(area && m.area!==area) return false;
    return true;
  });

  $("modules").innerHTML=list.map(m=>`
    <article class="vm-card" onclick="activate('${m.id}')">
      <h3>${m.title}</h3>
      <div class="vm-meta">${m.area}</div>
      <div>
        ${badge(m.status, m.exists?'vm-ok':'vm-warn')}
        ${m.registry_present?badge('REGISTRY','vm-ok'):badge('NO REG','vm-warn')}
        ${m.exists?badge((m.size/1024).toFixed(1)+' KiB'):badge('BUILD','vm-warn')}
      </div>
    </article>
  `).join('');
}

function activate(id){
  const m=ROADMAP.modules.find(x=>x.id===id);
  if(!m) return;
  ACTIVE=m;
  $("activeTitle").textContent=m.title;
  $("activeSub").textContent=m.area+" · "+m.status;
  $("activeDesc").textContent=m.exists
    ? `Modulo esistente: ${m.url}. Deve restare leaf o riferimento controllato.`
    : `Modulo mancante: va progettato come leaf module, con registry e quality gate.`;
  $("activeBadges").innerHTML =
    badge(m.area)+badge(m.status,m.exists?'vm-ok':'vm-warn')+
    (m.registry_present?badge('registry present','vm-ok'):badge('registry missing','vm-warn'));
  $("openActive").href=m.url || "/trfmc_integration_control_room.html";
  $("openActive").textContent=m.exists ? "Apri modulo" : "Apri Control Room";
  log("selected: "+m.title);
}

function renderMissing(){
  const missing=ROADMAP.modules.filter(x=>!x.exists);
  $("missingList").innerHTML=missing.map(m=>`<li>${m.area}: ${m.title}</li>`).join('');
}

async function boot(){
  const r=await fetch('/trfmc_visual_master_roadmap_v1.json',{cache:'no-store'});
  ROADMAP=await r.json();

  $("kRoadmap").textContent=ROADMAP.counts.total_targets;
  $("kExisting").textContent=ROADMAP.counts.existing;
  $("kMissing").textContent=ROADMAP.counts.missing_to_build;
  $("kRegistry").textContent=ROADMAP.counts.registry_present;

  const areas=[...new Set(ROADMAP.modules.map(x=>x.area))].sort();
  $("area").innerHTML='<option value="">tutte le aree</option>'+areas.map(a=>`<option value="${a}">${a}</option>`).join('');

  $("q").addEventListener("input",renderModules);
  $("area").addEventListener("input",renderModules);

  renderModules();
  renderMissing();
  activate("visual_donor");
  log("Visual Master Preview loaded");
}

function initWebGL(){
  const canvas=$("vmWebgl");
  const gl=canvas.getContext("webgl",{antialias:true,alpha:false});
  if(!gl){$("glState").textContent="fallback"; return;}

  $("glState").textContent="webgl";

  const vs=`attribute vec2 p; varying vec2 v; void main(){v=p; gl_Position=vec4(p,0.0,1.0);}`;
  const fs=`precision mediump float;
  varying vec2 v; uniform float t; uniform vec2 r;
  float line(vec2 p, vec2 a, vec2 b){
    vec2 pa=p-a, ba=b-a;
    float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
    return length(pa-ba*h);
  }
  void main(){
    vec2 uv=(v+1.0)*0.5;
    vec2 p=uv*2.0-1.0;
    p.x*=r.x/r.y;
    float g=0.0;
    for(int i=0;i<7;i++){
      float fi=float(i);
      vec2 a=vec2(sin(t*.21+fi)*.72, cos(t*.17+fi*1.7)*.45);
      vec2 b=vec2(cos(t*.19+fi*1.3)*.80, sin(t*.23+fi*.9)*.48);
      float d=line(p,a,b);
      g+=0.006/(d+0.006);
    }
    float grid=(step(.985,fract(uv.x*32.0))+step(.985,fract(uv.y*18.0)))*.10;
    vec3 col=vec3(0.005,0.018,0.030);
    col+=vec3(0.0,0.70,1.0)*g*.34;
    col+=vec3(0.2,1.0,0.35)*grid;
    col+=vec3(0.0,0.18,0.25)*(1.0-length(p)*.55);
    gl_FragColor=vec4(col,1.0);
  }`;

  function compile(type,src){
    const s=gl.createShader(type); gl.shaderSource(s,src); gl.compileShader(s); return s;
  }
  const pr=gl.createProgram();
  gl.attachShader(pr,compile(gl.VERTEX_SHADER,vs));
  gl.attachShader(pr,compile(gl.FRAGMENT_SHADER,fs));
  gl.linkProgram(pr); gl.useProgram(pr);

  const buf=gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER,buf);
  gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
  const loc=gl.getAttribLocation(pr,"p");
  gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);

  const ut=gl.getUniformLocation(pr,"t");
  const ur=gl.getUniformLocation(pr,"r");

  function frame(ms){
    const dpr=window.devicePixelRatio||1;
    const w=canvas.clientWidth*dpr|0, h=canvas.clientHeight*dpr|0;
    if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);}
    gl.uniform1f(ut,ms*.001);
    gl.uniform2f(ur,canvas.width,canvas.height);
    gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

initWebGL();
boot().catch(e=>{log("boot error: "+e.message);});
</script>
</body>
</html>
HTML

echo
echo "[6/8] Quality gate robusto"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_visual_master_preview_v1.html \
    /trfmc_visual_master_roadmap_v1.json \
    /assets/trfmc_design_system/trfmc_visual_master_v1.css \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_portal_registry_unified.json
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' "$PREVIEW" "$ASSETS/trfmc_visual_master_v1.css" > "$OUT/external_refs.txt" 2>/dev/null || true
grep -nEi '<iframe' "$PREVIEW" > "$OUT/iframe_refs.txt" 2>/dev/null || true
grep -nEi 'trfmc_master_fused|fallback shell|MASTER FUSED' "$PREVIEW" "$ROADMAP" > "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true

V6R3_SHA_AFTER="$(sha256sum "$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html" | awk '{print $1}')"
CONTROL_SHA_AFTER="$(sha256sum "$PUBLIC/trfmc_integration_control_room.html" | awk '{print $1}')"
REG_SHA_AFTER="$(sha256sum "$PUBLIC/trfmc_portal_registry_unified.json" | awk '{print $1}')"

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$V6R3_SHA_AFTER"
  echo "CONTROL_SHA_AFTER=$CONTROL_SHA_AFTER"
  echo "REG_SHA_AFTER=$REG_SHA_AFTER"
} > "$OUT/sha_compare.txt"

echo
echo "[7/8] Summary"
python3 - "$BASE" "$OUT" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

base=Path(sys.argv[1])
out=Path(sys.argv[2])

http=[]
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=3:
        http.append({"url":p[0],"status":p[1],"bytes":p[2]})

non200=sum(1 for x in http if x["status"]!="200")
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fused=sum(1 for x in (out/"fused_forbidden_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.strip().split("=",1)
        sha[k]=v

sha_ok = (
    sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER") and
    sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER") and
    sha.get("REG_SHA_BEFORE")==sha.get("REG_SHA_AFTER")
)

roadmap=json.loads((base/"frontend/public/trfmc_visual_master_roadmap_v1.json").read_text())

data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "preview":"http://127.0.0.1:5173/trfmc_visual_master_preview_v1.html",
 "roadmap":"http://127.0.0.1:5173/trfmc_visual_master_roadmap_v1.json",
 "css":"http://127.0.0.1:5173/assets/trfmc_design_system/trfmc_visual_master_v1.css",
 "http_non_200":non200,
 "external_refs":external,
 "iframe_refs":iframe,
 "fused_forbidden_refs":fused,
 "protected_sha_unchanged":sha_ok,
 "roadmap_counts":roadmap["counts"],
 "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and sha_ok else "WARN",
 "policy":"Preview only. V6R3, official Control Room and registry were not modified."
}
(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[8/8] Freeze se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_VISUAL_MASTER_PREVIEW_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_visual_master_preview_v1.html \
    frontend/public/trfmc_visual_master_roadmap_v1.json \
    frontend/public/assets/trfmc_design_system/trfmc_visual_master_v1.css \
    runtime/quality/latest_visual_master_preview \
    runtime/rejected_scripts \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
echo "RISULTATO"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "Apri preview:"
echo "http://127.0.0.1:5173/trfmc_visual_master_preview_v1.html"
echo "============================================================"
