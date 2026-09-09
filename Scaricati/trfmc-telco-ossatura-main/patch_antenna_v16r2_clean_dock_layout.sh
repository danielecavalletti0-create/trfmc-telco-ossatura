#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"

SRC="$PUBLIC/trfmc_antenna_system_explorer_v16r1_visible_antenna.html"
if [ ! -f "$SRC" ]; then
  SRC="$PUBLIC/trfmc_antenna_system_explorer_v16_metrology_premium.html"
fi

DST="$PUBLIC/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"

if [ ! -f "$SRC" ]; then
  echo "ERRORE: manca sorgente V1.6/V1.6R1"
  exit 1
fi

cp -f "$SRC" "$DST"

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/public/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "TRFMC Antenna System Explorer V1.6R1 Metrology Premium Visible Antenna",
    "TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout"
)
s = s.replace(
    "TRFMC Antenna System Explorer V1.6 Metrology Premium",
    "TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout"
)
s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.6R1 Visible Antenna</title>",
    "<title>TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout</title>"
)
s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.6 Metrology Premium</title>",
    "<title>TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout</title>"
)

css = r'''
/* === V1.6R2 CLEAN DOCK LAYOUT: NO MORE CANVAS OVERLAP === */

body.v16r2-clean #siteFrame{
  overflow:hidden !important;
}

body.v16r2-clean #siteFrame::after{
  content:"CLEAN CANVAS MODE · METROLOGY DOCKED · V1.6R2";
  position:absolute;
  top:7px;
  right:12px;
  z-index:20;
  color:#7dff4f;
  font:11px ui-monospace,monospace;
  pointer-events:none;
}

body.v16r2-clean #siteFrame .toolbar{
  z-index:20 !important;
}

body.v16r2-clean #siteFrame .overlayControls{
  z-index:20 !important;
  opacity:.92 !important;
}

body.v16r2-clean #siteFrame .opOverlay{
  opacity:.42 !important;
}

body.v16r2-clean #siteFrame .opBadge{
  opacity:.82 !important;
  right:10px !important;
  bottom:10px !important;
}

.v16r2Dock{
  border:1px solid #183d58;
  background:#081522;
  border-radius:6px;
  margin-bottom:8px;
  overflow:hidden;
}

.v16r2Dock h4{
  margin:0;
  padding:7px 8px;
  background:#0a1b2e;
  border-bottom:1px solid #183d58;
  color:#00d9ff;
  text-transform:uppercase;
  font-size:11px;
  letter-spacing:.04em;
}

.v16r2Dock .v16r2Inner{
  padding:7px;
  max-height:520px;
  overflow:auto;
}

.v16r2DockControls{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:5px;
  margin-bottom:7px;
}

.v16r2DockControls button{
  margin:0;
  text-align:center;
  padding:6px;
}

body.v16r2-clean #v16r2Dock #v16Scope,
body.v16r2-clean #v16r2Dock #icMeasureOverlay,
body.v16r2-clean #v16r2Dock #icMatrix,
body.v16r2-clean #v16r2Dock #v16BottomBar,
body.v16r2-clean #v16r2Dock #icCenterDock,
body.v16r2-clean #v16r2Dock #icStatusLine{
  position:static !important;
  left:auto !important;
  right:auto !important;
  top:auto !important;
  bottom:auto !important;
  transform:none !important;
  width:100% !important;
  max-width:100% !important;
  opacity:1 !important;
  z-index:auto !important;
  pointer-events:auto !important;
  margin:0 0 7px 0 !important;
}

body.v16r2-clean #v16r2Dock #v16Scope{
  display:grid !important;
  grid-template-columns:1fr !important;
  gap:6px !important;
}

body.v16r2-clean #v16r2Dock #v16Scope .v16Glass{
  display:block !important;
  margin-bottom:0 !important;
}

body.v16r2-clean #v16r2Dock #icMeasureOverlay{
  display:block !important;
}

body.v16r2-clean #v16r2Dock #icMatrix{
  display:block !important;
  max-height:210px !important;
  overflow:auto !important;
}

body.v16r2-clean #v16r2Dock #icCenterDock{
  display:grid !important;
  grid-template-columns:1fr 1fr 1fr !important;
  gap:5px !important;
  padding:5px !important;
  border:1px solid rgba(255,213,0,.45) !important;
  background:#061120 !important;
}

body.v16r2-clean #v16r2Dock #icCenterDock button{
  width:100% !important;
  margin:0 !important;
  text-align:center !important;
}

body.v16r2-clean #v16r2Dock #icStatusLine{
  height:auto !important;
  display:grid !important;
  grid-template-columns:1fr 1fr !important;
  gap:4px !important;
  padding:6px !important;
}

body.v16r2-clean #v16r2Dock #v16BottomBar{
  display:grid !important;
  grid-template-columns:1fr 1fr !important;
  gap:5px !important;
  padding:5px !important;
  border:1px solid rgba(255,213,0,.40) !important;
  background:#061120 !important;
}

body.v16r2-clean #v16r2Dock .v16BottomCell{
  min-height:42px !important;
}

body.v16r2-minimal #v16r2Dock #v16Scope,
body.v16r2-minimal #v16r2Dock #icMeasureOverlay,
body.v16r2-minimal #v16r2Dock #icMatrix{
  display:none !important;
}

body.v16r2-hide-markers #siteFrame .opOverlay,
body.v16r2-hide-markers .opOverlay{
  opacity:0 !important;
  pointer-events:auto !important;
}
'''
s = s.replace("</style>", css + "\n</style>")

js = r'''
<script>
/* === V1.6R2 CLEAN DOCK LAYOUT CONTROLLER === */
(function(){
  const idsToDock = [
    "v16Scope",
    "icMeasureOverlay",
    "icMatrix",
    "v16BottomBar",
    "icCenterDock",
    "icStatusLine"
  ];

  function el(id){ return document.getElementById(id); }

  function addLogSafe(msg){
    if(typeof addLog === "function") addLog("R2 · " + msg);
  }

  function ensureDock(){
    const rightBody = document.querySelector("main > aside:last-child .body");
    if(!rightBody) return null;

    let dock = el("v16r2Dock");
    if(!dock){
      dock = document.createElement("div");
      dock.id = "v16r2Dock";
      dock.className = "v16r2Dock";
      dock.innerHTML = `
        <h4>Clean Dock · Metrology / Markers / Commands</h4>
        <div class="v16r2Inner">
          <div class="v16r2DockControls">
            <button onclick="TRFMC_R2.cleanMarkers()">Pulisci Marker</button>
            <button onclick="TRFMC_R2.toggleMarkers()">Marker ON/OFF</button>
            <button onclick="TRFMC_R2.toggleMinimal()">Dock Compact</button>
            <button onclick="TRFMC_R2.canvasFocus()">Canvas Focus</button>
          </div>
          <div id="v16r2DockMount"></div>
        </div>
      `;
      rightBody.insertBefore(dock, rightBody.firstChild);
    }
    return el("v16r2DockMount");
  }

  function movePanels(){
    const mount = ensureDock();
    if(!mount) return;

    idsToDock.forEach(id=>{
      const n = el(id);
      if(n && n.parentElement !== mount){
        mount.appendChild(n);
      }
    });

    document.body.classList.add("v16r2-clean");
  }

  function limitMarkerDensity(){
    if(!window.TRFMC_OP || !window.TRFMC_OP.state || !window.TRFMC_OP.state.markers) return;

    Object.keys(window.TRFMC_OP.state.markers).forEach(k=>{
      const arr = window.TRFMC_OP.state.markers[k];
      if(Array.isArray(arr) && arr.length > 3){
        window.TRFMC_OP.state.markers[k] = arr.slice(-3);
      }
    });
  }

  function cleanMarkers(){
    if(window.TRFMC_OP && typeof window.TRFMC_OP.clearMarkers === "function"){
      window.TRFMC_OP.clearMarkers();
    }
    const tb = el("icMarkerTable");
    if(tb){
      tb.innerHTML = `<tr><td>--</td><td>--</td><td>clean</td><td>READY</td></tr>`;
    }
    addLogSafe("markers cleared / canvas decluttered");
  }

  function toggleMarkers(){
    document.body.classList.toggle("v16r2-hide-markers");
    addLogSafe(document.body.classList.contains("v16r2-hide-markers") ? "marker overlay hidden" : "marker overlay visible");
  }

  function toggleMinimal(){
    document.body.classList.toggle("v16r2-minimal");
    addLogSafe(document.body.classList.contains("v16r2-minimal") ? "dock compact mode" : "dock full mode");
  }

  function canvasFocus(){
    cleanMarkers();
    document.body.classList.add("v16r2-hide-markers");
    if(typeof view !== "undefined") view = "2D";
    document.querySelectorAll("button[data-view]").forEach(b=>{
      b.classList.toggle("active", b.dataset.view === "2D");
    });
    addLogSafe("canvas focus mode enabled");
  }

  window.TRFMC_R2 = {
    movePanels,
    cleanMarkers,
    toggleMarkers,
    toggleMinimal,
    canvasFocus
  };

  let count = 0;
  const timer = setInterval(()=>{
    movePanels();
    limitMarkerDensity();
    count++;
    if(count > 12){
      clearInterval(timer);
      addLogSafe("clean dock layout stabilized");
    }
  }, 350);

  setTimeout(()=>{
    cleanMarkers();
    movePanels();
  }, 1400);
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
"frontend/public/trfmc_antenna_system_explorer_v16r1_visible_antenna.html",
"frontend/public/trfmc_antenna_system_explorer_v16_metrology_premium.html",
"frontend/public/trfmc_antenna_system_explorer_v15_instrument_center.html",
"frontend/public/trfmc_enterprise_prime_portal_v1.html",
"frontend/public/api/portal/index"
]

link='<a href="/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html">Antenna V1.6R2 Clean Dock</a>'

for f in files:
    p=Path(f)
    if not p.exists():
        continue
    s=p.read_text(errors="ignore")
    if "trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html" not in s:
        if "<nav" in s:
            i=s.find("<nav")
            gt=s.find(">",i)
            s=s[:gt+1]+"\n"+link+s[gt+1:]
        elif "<ul>" in s:
            s=s.replace("<ul>","<ul>\n<li>"+link+"</li>",1)
        p.write_text(s)
        print("PATCHED",p)
PY

curl -I --max-time 5 http://127.0.0.1:5173/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html
