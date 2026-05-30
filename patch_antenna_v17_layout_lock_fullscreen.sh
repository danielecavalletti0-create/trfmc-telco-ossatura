#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
SRC="$PUBLIC/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
DST="$PUBLIC/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html"

if [ ! -f "$SRC" ]; then
  echo "ERRORE: manca $SRC"
  exit 1
fi

cp -f "$SRC" "$DST"

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/public/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout",
    "TRFMC Antenna System Explorer V1.7 Layout Lock Fullscreen"
)
s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout</title>",
    "<title>TRFMC Antenna System Explorer V1.7 Layout Lock Fullscreen</title>"
)

css = r'''
/* === V1.7 LAYOUT LOCK / FULLSCREEN INSTRUMENT MODE === */

body.v17-ready::before{
  content:"V1.7 LAYOUT LOCK · INSTRUMENT WORKSTATION";
  position:fixed;
  left:50%;
  top:58px;
  transform:translateX(-50%);
  z-index:999;
  color:#7dff4f;
  font:11px ui-monospace,monospace;
  background:rgba(3,10,18,.72);
  border:1px solid rgba(125,255,79,.35);
  border-radius:4px;
  padding:4px 9px;
  pointer-events:none;
}

.v17Panel{
  position:fixed;
  right:10px;
  top:62px;
  z-index:1000;
  width:390px;
  border:1px solid rgba(0,217,255,.45);
  background:rgba(3,10,18,.92);
  border-radius:7px;
  padding:7px;
  backdrop-filter:blur(12px);
  box-shadow:0 0 28px rgba(0,217,255,.10);
}

.v17Panel h4{
  margin:0 0 6px;
  color:#00d9ff;
  text-transform:uppercase;
  font-size:11px;
  letter-spacing:.05em;
}

.v17Grid{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:5px;
}

.v17Grid button{
  margin:0;
  text-align:center;
  padding:6px 5px;
  font-size:11px;
}

.v17State{
  margin-top:6px;
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:5px;
}

.v17Cell{
  border:1px solid rgba(36,91,125,.9);
  background:#081522;
  border-radius:4px;
  padding:5px;
  font-family:ui-monospace,monospace;
}

.v17Cell span{
  display:block;
  color:#87a8c6;
  font-size:8px;
  text-transform:uppercase;
}

.v17Cell b{
  display:block;
  color:#7dff4f;
  font-size:11px;
}

body.v17-wide main{
  grid-template-columns:220px 1fr 300px !important;
}

body.v17-wide .kpis{
  grid-template-columns:repeat(10,1fr) !important;
}

body.v17-wide .grid{
  grid-template-rows:minmax(400px,1.15fr) minmax(210px,.7fr) minmax(210px,.7fr) !important;
}

body.v17-canvas-focus header{
  height:42px !important;
}

body.v17-canvas-focus main{
  grid-template-columns:0 1fr 0 !important;
  gap:0 !important;
  padding:4px !important;
  height:calc(100vh - 42px) !important;
}

body.v17-canvas-focus main > aside{
  display:none !important;
}

body.v17-canvas-focus .kpis{
  margin-bottom:4px !important;
  padding:4px !important;
  grid-template-columns:repeat(10,1fr) !important;
}

body.v17-canvas-focus .kpi{
  min-height:48px !important;
  padding:5px !important;
}

body.v17-canvas-focus .kpi b{
  font-size:14px !important;
}

body.v17-canvas-focus .grid{
  height:calc(100% - 58px) !important;
  grid-template-columns:1.2fr 1fr !important;
  grid-template-rows:minmax(520px,1.35fr) minmax(180px,.55fr) minmax(180px,.55fr) !important;
}

body.v17-canvas-focus #siteFrame{
  grid-column:1/3 !important;
}

body.v17-measurement-wall main{
  grid-template-columns:0 1fr 420px !important;
  padding:5px !important;
}

body.v17-measurement-wall main > aside:first-child{
  display:none !important;
}

body.v17-measurement-wall .grid{
  grid-template-rows:minmax(390px,1fr) minmax(240px,.8fr) minmax(240px,.8fr) !important;
}

body.v17-hide-left main{
  grid-template-columns:0 1fr 330px !important;
}

body.v17-hide-left main > aside:first-child{
  display:none !important;
}

body.v17-hide-right main{
  grid-template-columns:248px 1fr 0 !important;
}

body.v17-hide-right main > aside:last-child{
  display:none !important;
}

body.v17-hide-dock #v16r2Dock{
  display:none !important;
}

body.v17-hide-markers #siteFrame .opOverlay,
body.v17-hide-markers .opOverlay{
  opacity:0 !important;
}

body.v17-kiosk header{
  display:none !important;
}

body.v17-kiosk main{
  height:100vh !important;
  grid-template-columns:0 1fr 0 !important;
  gap:0 !important;
  padding:4px !important;
}

body.v17-kiosk main > aside{
  display:none !important;
}

body.v17-kiosk .kpis{
  grid-template-columns:repeat(10,1fr) !important;
  margin-bottom:4px !important;
}

body.v17-kiosk .grid{
  height:calc(100vh - 64px) !important;
  grid-template-rows:minmax(620px,1.45fr) minmax(200px,.55fr) minmax(200px,.55fr) !important;
}

body.v17-kiosk #siteFrame{
  grid-column:1/3 !important;
}

body.v17-kiosk .v17Panel{
  top:10px !important;
  right:10px !important;
  opacity:.72 !important;
}

body.v17-compact-kpis .kpi em{
  display:none !important;
}

body.v17-compact-kpis .kpi{
  min-height:42px !important;
}

body.v17-compact-kpis .kpi b{
  font-size:13px !important;
}

body.v17-locked #siteFrame,
body.v17-locked .frame{
  box-shadow:0 0 0 1px rgba(125,255,79,.14), inset 0 0 0 1px rgba(255,255,255,.03);
}

body.v17-locked #siteFrame::after{
  content:"LAYOUT LOCKED · CLEAN CANVAS · FULLSCREEN READY";
  position:absolute;
  top:7px;
  right:12px;
  z-index:30;
  color:#7dff4f;
  font:11px ui-monospace,monospace;
  pointer-events:none;
}

@media(max-width:1500px){
  .v17Panel{
    width:330px;
  }
  .v17Grid{
    grid-template-columns:1fr 1fr;
  }
}
'''

s = s.replace("</style>", css + "\n</style>")

js = r'''
<script>
/* === TRFMC ANTENNA V1.7 LAYOUT LOCK / FULLSCREEN CONTROLLER === */
(function(){
  const KEY = "trfmc_v17_layout_mode";

  const state = {
    mode:"normal",
    dock:true,
    markers:true,
    left:true,
    right:true,
    compactKpis:false,
    fullscreen:false,
    locked:true
  };

  function el(id){ return document.getElementById(id); }

  function log(msg){
    if(typeof addLog === "function") addLog("V17 · " + msg);
    updatePanel();
  }

  function cls(){
    return document.body.classList;
  }

  function clearModes(){
    [
      "v17-wide",
      "v17-canvas-focus",
      "v17-measurement-wall",
      "v17-kiosk",
      "v17-hide-left",
      "v17-hide-right",
      "v17-hide-dock",
      "v17-hide-markers",
      "v17-compact-kpis",
      "v17-locked"
    ].forEach(c=>cls().remove(c));
  }

  function apply(){
    clearModes();
    cls().add("v17-ready");

    if(state.mode === "wide") cls().add("v17-wide");
    if(state.mode === "focus") cls().add("v17-canvas-focus");
    if(state.mode === "wall") cls().add("v17-measurement-wall");
    if(state.mode === "kiosk") cls().add("v17-kiosk");

    if(!state.left) cls().add("v17-hide-left");
    if(!state.right) cls().add("v17-hide-right");
    if(!state.dock) cls().add("v17-hide-dock");
    if(!state.markers) cls().add("v17-hide-markers");
    if(state.compactKpis) cls().add("v17-compact-kpis");
    if(state.locked) cls().add("v17-locked");

    localStorage.setItem(KEY, JSON.stringify(state));
    updatePanel();
  }

  function setMode(mode){
    state.mode = mode;
    if(mode === "focus"){
      state.left = false;
      state.right = false;
      state.dock = false;
      state.markers = false;
      state.compactKpis = true;
    }
    if(mode === "wall"){
      state.left = false;
      state.right = true;
      state.dock = true;
      state.markers = false;
      state.compactKpis = false;
    }
    if(mode === "wide" || mode === "normal"){
      state.left = true;
      state.right = true;
      state.dock = true;
      state.markers = true;
      state.compactKpis = false;
    }
    if(mode === "kiosk"){
      state.left = false;
      state.right = false;
      state.dock = false;
      state.markers = false;
      state.compactKpis = true;
    }
    apply();
    log("layout mode → " + mode.toUpperCase());
  }

  async function fullscreen(){
    try{
      if(!document.fullscreenElement){
        await document.documentElement.requestFullscreen();
        state.fullscreen = true;
        setMode("kiosk");
        log("fullscreen entered");
      } else {
        await document.exitFullscreen();
        state.fullscreen = false;
        setMode("normal");
        log("fullscreen exited");
      }
    }catch(e){
      log("fullscreen request rejected");
    }
  }

  function toggleDock(){
    state.dock = !state.dock;
    apply();
    log(state.dock ? "dock visible" : "dock hidden");
  }

  function toggleMarkers(){
    state.markers = !state.markers;
    apply();
    log(state.markers ? "markers visible" : "markers hidden");
  }

  function toggleLeft(){
    state.left = !state.left;
    apply();
    log(state.left ? "left rail visible" : "left rail hidden");
  }

  function toggleRight(){
    state.right = !state.right;
    apply();
    log(state.right ? "right rail visible" : "right rail hidden");
  }

  function toggleKpis(){
    state.compactKpis = !state.compactKpis;
    apply();
    log(state.compactKpis ? "compact KPI strip" : "full KPI strip");
  }

  function reset(){
    state.mode = "normal";
    state.dock = true;
    state.markers = true;
    state.left = true;
    state.right = true;
    state.compactKpis = false;
    state.locked = true;
    apply();
    log("layout reset to normal locked workstation");
  }

  function cleanCanvas(){
    if(window.TRFMC_R2 && typeof window.TRFMC_R2.cleanMarkers === "function"){
      window.TRFMC_R2.cleanMarkers();
    }
    state.markers = false;
    state.dock = false;
    apply();
    log("clean canvas view enabled");
  }

  function injectPanel(){
    if(el("v17Panel")) return;

    const panel = document.createElement("div");
    panel.id = "v17Panel";
    panel.className = "v17Panel";
    panel.innerHTML = `
      <h4>V1.7 Layout Lock / Instrument Workstation</h4>
      <div class="v17Grid">
        <button onclick="TRFMC_V17.setMode('normal')">Normal</button>
        <button onclick="TRFMC_V17.setMode('wide')">Wide</button>
        <button onclick="TRFMC_V17.setMode('focus')">Canvas Focus</button>
        <button onclick="TRFMC_V17.setMode('wall')">Measurement Wall</button>
        <button onclick="TRFMC_V17.fullscreen()">Kiosk Fullscreen</button>
        <button onclick="TRFMC_V17.cleanCanvas()">Clean Canvas</button>
        <button onclick="TRFMC_V17.toggleDock()">Dock</button>
        <button onclick="TRFMC_V17.toggleMarkers()">Markers</button>
        <button onclick="TRFMC_V17.toggleLeft()">Left Rail</button>
        <button onclick="TRFMC_V17.toggleRight()">Right Rail</button>
        <button onclick="TRFMC_V17.toggleKpis()">KPI Compact</button>
        <button onclick="TRFMC_V17.reset()">Reset</button>
      </div>
      <div class="v17State">
        <div class="v17Cell"><span>Mode</span><b id="v17Mode">NORMAL</b></div>
        <div class="v17Cell"><span>Dock</span><b id="v17Dock">ON</b></div>
        <div class="v17Cell"><span>Markers</span><b id="v17Markers">ON</b></div>
        <div class="v17Cell"><span>Rails</span><b id="v17Rails">L/R</b></div>
      </div>
    `;

    document.body.appendChild(panel);
  }

  function updatePanel(){
    if(!el("v17Mode")) return;
    el("v17Mode").textContent = state.mode.toUpperCase();
    el("v17Dock").textContent = state.dock ? "ON" : "OFF";
    el("v17Markers").textContent = state.markers ? "ON" : "OFF";
    el("v17Rails").textContent = (state.left ? "L" : "-") + "/" + (state.right ? "R" : "-");
  }

  function bindKeys(){
    window.addEventListener("keydown", ev=>{
      if(ev.target && ["INPUT","SELECT","TEXTAREA"].includes(ev.target.tagName)) return;
      const k = ev.key.toLowerCase();
      if(k === "n") setMode("normal");
      if(k === "w") setMode("wide");
      if(k === "f") setMode("focus");
      if(k === "m") setMode("wall");
      if(k === "k") fullscreen();
      if(k === "c") cleanCanvas();
      if(k === "d") toggleDock();
      if(k === "h") toggleMarkers();
      if(k === "r") reset();
    });
  }

  function restore(){
    const raw = localStorage.getItem(KEY);
    if(raw){
      try{
        Object.assign(state, JSON.parse(raw));
      }catch(e){}
    }
  }

  window.TRFMC_V17 = {
    state,
    setMode,
    fullscreen,
    toggleDock,
    toggleMarkers,
    toggleLeft,
    toggleRight,
    toggleKpis,
    cleanCanvas,
    reset
  };

  injectPanel();
  bindKeys();
  restore();
  apply();

  setTimeout(()=>{
    if(window.TRFMC_R2 && typeof window.TRFMC_R2.movePanels === "function"){
      window.TRFMC_R2.movePanels();
    }
    log("layout lock controller online");
  }, 600);
})();
</script>
'''

s = s.replace("</body>", js + "\n</body>")

p.write_text(s)
print("CREATED", p)
PY

python3 - <<'PY'
from pathlib import Path

files=[
"frontend/public/trfmc_master_console_v4.html",
"frontend/public/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html",
"frontend/public/trfmc_antenna_system_explorer_v16r1_visible_antenna.html",
"frontend/public/trfmc_antenna_system_explorer_v16_metrology_premium.html",
"frontend/public/trfmc_enterprise_prime_portal_v1.html",
"frontend/public/api/portal/index"
]

link='<a href="/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html">Antenna V1.7 Layout Lock</a>'

for f in files:
    p=Path(f)
    if not p.exists():
        continue
    s=p.read_text(errors="ignore")
    if "trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html" not in s:
        if "<nav" in s:
            i=s.find("<nav")
            gt=s.find(">",i)
            s=s[:gt+1]+"\n"+link+s[gt+1:]
        elif "<ul>" in s:
            s=s.replace("<ul>","<ul>\n<li>"+link+"</li>",1)
        p.write_text(s)
        print("PATCHED",p)
PY

curl -I --max-time 5 http://127.0.0.1:5173/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html
