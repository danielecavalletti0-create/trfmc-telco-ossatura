#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets"

mkdir -p "$ASSETS"

cat > "$ASSETS/trfmc_global_instrument_shell_v1.css" <<'CSS'
/* ============================================================
   TRFMC GLOBAL INSTRUMENT SHELL V1
   Layout Lock · Canvas Focus · Measurement Wall · Kiosk
   ============================================================ */

:root{
  --gis-bg:#02070f;
  --gis-panel:#061120;
  --gis-line:#1d6f9f;
  --gis-text:#eaf3ff;
  --gis-muted:#86a7c6;
  --gis-cyan:#00d9ff;
  --gis-green:#7dff4f;
  --gis-yellow:#ffd500;
  --gis-red:#ff3366;
}

body.trfmc-gis-ready::before{
  content:"TRFMC GLOBAL INSTRUMENT SHELL · V1";
  position:fixed;
  left:50%;
  top:58px;
  transform:translateX(-50%);
  z-index:9998;
  color:var(--gis-green);
  background:rgba(3,10,18,.72);
  border:1px solid rgba(125,255,79,.35);
  border-radius:4px;
  padding:4px 9px;
  font:11px ui-monospace,monospace;
  pointer-events:none;
}

.trfmc-gis-panel{
  position:fixed;
  right:10px;
  top:62px;
  z-index:9999;
  width:405px;
  border:1px solid rgba(0,217,255,.45);
  background:rgba(3,10,18,.94);
  border-radius:7px;
  padding:7px;
  backdrop-filter:blur(12px);
  box-shadow:0 0 28px rgba(0,217,255,.10);
  color:var(--gis-text);
  font:12px Inter,Segoe UI,system-ui,sans-serif;
}

.trfmc-gis-panel h4{
  margin:0 0 6px;
  color:var(--gis-cyan);
  text-transform:uppercase;
  font-size:11px;
  letter-spacing:.05em;
}

.trfmc-gis-grid{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:5px;
}

.trfmc-gis-panel button{
  margin:0;
  padding:6px 5px;
  color:var(--gis-text);
  background:#10233a;
  border:1px solid #285d82;
  border-radius:4px;
  font-size:11px;
  cursor:pointer;
}

.trfmc-gis-panel button:hover{
  background:#145078;
  border-color:var(--gis-cyan);
  box-shadow:inset 3px 0 0 var(--gis-yellow);
}

.trfmc-gis-state{
  margin-top:6px;
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:5px;
}

.trfmc-gis-cell{
  border:1px solid rgba(36,91,125,.9);
  background:#081522;
  border-radius:4px;
  padding:5px;
  font-family:ui-monospace,monospace;
}

.trfmc-gis-cell span{
  display:block;
  color:var(--gis-muted);
  font-size:8px;
  text-transform:uppercase;
}

.trfmc-gis-cell b{
  display:block;
  color:var(--gis-green);
  font-size:11px;
}

.trfmc-gis-command{
  display:grid;
  grid-template-columns:1fr auto;
  gap:5px;
  margin-top:6px;
}

.trfmc-gis-command input{
  background:#02070f;
  border:1px solid #285d82;
  color:var(--gis-text);
  border-radius:4px;
  padding:6px;
  font:11px ui-monospace,monospace;
}

.trfmc-gis-log{
  margin-top:6px;
  height:82px;
  overflow:auto;
  border:1px solid rgba(36,91,125,.9);
  background:#02070f;
  border-radius:4px;
  padding:5px;
  font:10px ui-monospace,monospace;
  color:#cde7ff;
}

.trfmc-gis-log div{
  border-bottom:1px solid rgba(255,255,255,.06);
  padding:2px 0;
}

/* generic page normalization */
body.trfmc-gis-ready header{
  border-bottom-color:var(--gis-line) !important;
}

body.trfmc-gis-ready .frame,
body.trfmc-gis-ready .panel,
body.trfmc-gis-ready canvas{
  box-shadow:0 0 0 1px rgba(0,217,255,.04);
}

body.trfmc-gis-wide main{
  grid-template-columns:220px 1fr 300px !important;
}

body.trfmc-gis-wide .grid{
  grid-template-rows:minmax(400px,1.15fr) minmax(210px,.7fr) minmax(210px,.7fr) !important;
}

body.trfmc-gis-focus header{
  height:42px !important;
}

body.trfmc-gis-focus main{
  grid-template-columns:0 1fr 0 !important;
  gap:0 !important;
  padding:4px !important;
  height:calc(100vh - 42px) !important;
}

body.trfmc-gis-focus main > aside{
  display:none !important;
}

body.trfmc-gis-focus .kpis{
  margin-bottom:4px !important;
  padding:4px !important;
}

body.trfmc-gis-focus .kpi{
  min-height:46px !important;
  padding:5px !important;
}

body.trfmc-gis-focus .kpi b{
  font-size:14px !important;
}

body.trfmc-gis-focus .grid{
  height:calc(100% - 58px) !important;
}

body.trfmc-gis-focus #siteFrame,
body.trfmc-gis-focus #specFrame,
body.trfmc-gis-focus .grid > .frame:first-child{
  grid-column:1/3 !important;
}

body.trfmc-gis-wall main{
  grid-template-columns:0 1fr 420px !important;
  padding:5px !important;
}

body.trfmc-gis-wall main > aside:first-child{
  display:none !important;
}

body.trfmc-gis-hide-left main{
  grid-template-columns:0 1fr 330px !important;
}

body.trfmc-gis-hide-left main > aside:first-child{
  display:none !important;
}

body.trfmc-gis-hide-right main{
  grid-template-columns:248px 1fr 0 !important;
}

body.trfmc-gis-hide-right main > aside:last-child{
  display:none !important;
}

body.trfmc-gis-clean .opOverlay,
body.trfmc-gis-clean .opBadge,
body.trfmc-gis-clean .icMatrix,
body.trfmc-gis-clean .icMeasureOverlay,
body.trfmc-gis-clean .v16Scope,
body.trfmc-gis-clean .v16BottomBar,
body.trfmc-gis-clean .icCenterDock,
body.trfmc-gis-clean .icStatusLine{
  opacity:0 !important;
  pointer-events:none !important;
}

body.trfmc-gis-compact .kpi em{
  display:none !important;
}

body.trfmc-gis-compact .kpi{
  min-height:42px !important;
}

body.trfmc-gis-compact .kpi b{
  font-size:13px !important;
}

body.trfmc-gis-kiosk header{
  display:none !important;
}

body.trfmc-gis-kiosk main{
  height:100vh !important;
  grid-template-columns:0 1fr 0 !important;
  gap:0 !important;
  padding:4px !important;
}

body.trfmc-gis-kiosk main > aside{
  display:none !important;
}

body.trfmc-gis-kiosk .kpis{
  grid-template-columns:repeat(10,1fr) !important;
  margin-bottom:4px !important;
}

body.trfmc-gis-kiosk .grid{
  height:calc(100vh - 64px) !important;
}

body.trfmc-gis-kiosk #siteFrame,
body.trfmc-gis-kiosk #specFrame,
body.trfmc-gis-kiosk .grid > .frame:first-child{
  grid-column:1/3 !important;
}

body.trfmc-gis-kiosk .trfmc-gis-panel{
  top:10px !important;
  right:10px !important;
  opacity:.74 !important;
}

body.trfmc-gis-locked .frame,
body.trfmc-gis-locked canvas{
  box-shadow:0 0 0 1px rgba(125,255,79,.12), inset 0 0 0 1px rgba(255,255,255,.03);
}

@media(max-width:1500px){
  .trfmc-gis-panel{
    width:340px;
  }
  .trfmc-gis-grid{
    grid-template-columns:1fr 1fr;
  }
}
CSS

cat > "$ASSETS/trfmc_global_instrument_shell_v1.js" <<'JS'
/* ============================================================
   TRFMC GLOBAL INSTRUMENT SHELL V1
   ============================================================ */
(function(){
  const KEY = "trfmc_global_instrument_shell_v1";

  const state = {
    mode:"normal",
    left:true,
    right:true,
    clean:false,
    compact:false,
    fullscreen:false,
    locked:true,
    last:"BOOT"
  };

  function now(){ return new Date().toLocaleTimeString(); }
  function el(id){ return document.getElementById(id); }

  function classifyPage(){
    const path = location.pathname.toLowerCase();
    if(path.includes("antenna")) return "ANTENNA";
    if(path.includes("wifi") || path.includes("qam")) return "WIFI/QAM";
    if(path.includes("dsp") || path.includes("measurement_chain")) return "DSP";
    if(path.includes("core") || path.includes("aka") || path.includes("ran")) return "5G CORE";
    if(path.includes("noc")) return "NOC";
    if(path.includes("master")) return "MASTER";
    return "TRFMC";
  }

  function pageLog(msg){
    state.last = msg;
    const box = el("trfmcGisLog");
    if(box){
      const d = document.createElement("div");
      d.textContent = "[" + now() + "] " + msg;
      box.prepend(d);
      while(box.children.length > 20) box.removeChild(box.lastChild);
    }
    try{
      if(typeof addLog === "function") addLog("GIS · " + msg);
    }catch(e){}
    updatePanel();
  }

  function clearClasses(){
    [
      "trfmc-gis-wide",
      "trfmc-gis-focus",
      "trfmc-gis-wall",
      "trfmc-gis-kiosk",
      "trfmc-gis-hide-left",
      "trfmc-gis-hide-right",
      "trfmc-gis-clean",
      "trfmc-gis-compact",
      "trfmc-gis-locked"
    ].forEach(c=>document.body.classList.remove(c));
  }

  function apply(){
    clearClasses();
    document.body.classList.add("trfmc-gis-ready");

    if(state.mode === "wide") document.body.classList.add("trfmc-gis-wide");
    if(state.mode === "focus") document.body.classList.add("trfmc-gis-focus");
    if(state.mode === "wall") document.body.classList.add("trfmc-gis-wall");
    if(state.mode === "kiosk") document.body.classList.add("trfmc-gis-kiosk");

    if(!state.left) document.body.classList.add("trfmc-gis-hide-left");
    if(!state.right) document.body.classList.add("trfmc-gis-hide-right");
    if(state.clean) document.body.classList.add("trfmc-gis-clean");
    if(state.compact) document.body.classList.add("trfmc-gis-compact");
    if(state.locked) document.body.classList.add("trfmc-gis-locked");

    localStorage.setItem(KEY, JSON.stringify(state));
    updatePanel();
  }

  function setMode(mode){
    state.mode = mode;

    if(mode === "normal"){
      state.left = true;
      state.right = true;
      state.clean = false;
      state.compact = false;
    }

    if(mode === "wide"){
      state.left = true;
      state.right = true;
      state.clean = false;
      state.compact = false;
    }

    if(mode === "focus"){
      state.left = false;
      state.right = false;
      state.clean = true;
      state.compact = true;
    }

    if(mode === "wall"){
      state.left = false;
      state.right = true;
      state.clean = false;
      state.compact = false;
    }

    if(mode === "kiosk"){
      state.left = false;
      state.right = false;
      state.clean = true;
      state.compact = true;
    }

    apply();
    pageLog("mode → " + mode.toUpperCase());
  }

  async function fullscreen(){
    try{
      if(!document.fullscreenElement){
        await document.documentElement.requestFullscreen();
        state.fullscreen = true;
        setMode("kiosk");
        pageLog("fullscreen entered");
      }else{
        await document.exitFullscreen();
        state.fullscreen = false;
        setMode("normal");
        pageLog("fullscreen exited");
      }
    }catch(e){
      pageLog("fullscreen rejected");
    }
  }

  function toggleLeft(){
    state.left = !state.left;
    apply();
    pageLog(state.left ? "left rail visible" : "left rail hidden");
  }

  function toggleRight(){
    state.right = !state.right;
    apply();
    pageLog(state.right ? "right rail visible" : "right rail hidden");
  }

  function toggleClean(){
    state.clean = !state.clean;
    apply();
    pageLog(state.clean ? "clean canvas ON" : "clean canvas OFF");
  }

  function toggleCompact(){
    state.compact = !state.compact;
    apply();
    pageLog(state.compact ? "compact KPI ON" : "compact KPI OFF");
  }

  function reset(){
    state.mode = "normal";
    state.left = true;
    state.right = true;
    state.clean = false;
    state.compact = false;
    state.locked = true;
    apply();
    pageLog("global layout reset");
  }

  function runPageAction(){
    const p = classifyPage();

    if(window.TRFMC_R2 && typeof window.TRFMC_R2.canvasFocus === "function"){
      window.TRFMC_R2.canvasFocus();
      pageLog("native antenna canvas focus executed");
      return;
    }

    if(window.TRFMC_V16 && typeof window.TRFMC_V16.quickCheck === "function"){
      window.TRFMC_V16.quickCheck();
      pageLog("native antenna quick check executed");
      return;
    }

    const buttons = Array.from(document.querySelectorAll("button"));
    const action = buttons.find(b => /run|quick|acceptance|heatmap|align|sweep|peak|sequence|check/i.test(b.textContent || ""));
    if(action){
      action.click();
      pageLog("native page action executed on " + p);
      return;
    }

    pageLog("no native action found for " + p);
  }

  function injectPanel(){
    if(el("trfmcGisPanel")) return;

    const panel = document.createElement("div");
    panel.id = "trfmcGisPanel";
    panel.className = "trfmc-gis-panel";
    panel.innerHTML = `
      <h4>Global Instrument Shell · ${classifyPage()}</h4>
      <div class="trfmc-gis-grid">
        <button onclick="TRFMC_GIS.setMode('normal')">Normal</button>
        <button onclick="TRFMC_GIS.setMode('wide')">Wide</button>
        <button onclick="TRFMC_GIS.setMode('focus')">Canvas Focus</button>
        <button onclick="TRFMC_GIS.setMode('wall')">Measurement Wall</button>
        <button onclick="TRFMC_GIS.fullscreen()">Kiosk</button>
        <button onclick="TRFMC_GIS.toggleClean()">Clean</button>
        <button onclick="TRFMC_GIS.toggleLeft()">Left Rail</button>
        <button onclick="TRFMC_GIS.toggleRight()">Right Rail</button>
        <button onclick="TRFMC_GIS.toggleCompact()">KPI Compact</button>
        <button onclick="TRFMC_GIS.runPageAction()">Native Action</button>
        <button onclick="TRFMC_GIS.reset()">Reset</button>
        <button onclick="TRFMC_GIS.hidePanel()">Hide Panel</button>
      </div>
      <div class="trfmc-gis-state">
        <div class="trfmc-gis-cell"><span>Mode</span><b id="trfmcGisMode">NORMAL</b></div>
        <div class="trfmc-gis-cell"><span>Rails</span><b id="trfmcGisRails">L/R</b></div>
        <div class="trfmc-gis-cell"><span>Clean</span><b id="trfmcGisClean">OFF</b></div>
        <div class="trfmc-gis-cell"><span>Page</span><b id="trfmcGisPage">${classifyPage()}</b></div>
      </div>
      <div class="trfmc-gis-command">
        <input id="trfmcGisCmd" value="MODE:FOCUS">
        <button onclick="TRFMC_GIS.exec()">EXEC</button>
      </div>
      <div class="trfmc-gis-log" id="trfmcGisLog"></div>
    `;

    document.body.appendChild(panel);
  }

  function updatePanel(){
    if(el("trfmcGisMode")) el("trfmcGisMode").textContent = state.mode.toUpperCase();
    if(el("trfmcGisRails")) el("trfmcGisRails").textContent = (state.left ? "L" : "-") + "/" + (state.right ? "R" : "-");
    if(el("trfmcGisClean")) el("trfmcGisClean").textContent = state.clean ? "ON" : "OFF";
    if(el("trfmcGisPage")) el("trfmcGisPage").textContent = classifyPage();
  }

  function exec(cmd){
    cmd = (cmd || el("trfmcGisCmd")?.value || "").trim().toUpperCase();

    if(cmd.includes("NORMAL")) setMode("normal");
    else if(cmd.includes("WIDE")) setMode("wide");
    else if(cmd.includes("FOCUS")) setMode("focus");
    else if(cmd.includes("WALL")) setMode("wall");
    else if(cmd.includes("KIOSK")) fullscreen();
    else if(cmd.includes("CLEAN")) toggleClean();
    else if(cmd.includes("LEFT")) toggleLeft();
    else if(cmd.includes("RIGHT")) toggleRight();
    else if(cmd.includes("COMPACT")) toggleCompact();
    else if(cmd.includes("ACTION")) runPageAction();
    else if(cmd.includes("RESET")) reset();
    else pageLog("unknown GIS command → " + cmd);
  }

  function hidePanel(){
    const p = el("trfmcGisPanel");
    if(p) p.style.display = "none";
    pageLog("panel hidden; press G to restore");
  }

  function showPanel(){
    const p = el("trfmcGisPanel");
    if(p) p.style.display = "block";
  }

  function bindKeys(){
    window.addEventListener("keydown", ev=>{
      if(ev.target && ["INPUT","SELECT","TEXTAREA"].includes(ev.target.tagName)) return;

      const k = ev.key.toLowerCase();
      if(k === "g") showPanel();
      if(k === "n") setMode("normal");
      if(k === "w") setMode("wide");
      if(k === "f") setMode("focus");
      if(k === "m") setMode("wall");
      if(k === "k") fullscreen();
      if(k === "c") toggleClean();
      if(k === "d") toggleRight();
      if(k === "l") toggleLeft();
      if(k === "r") reset();
      if(k === "x") runPageAction();
    });
  }

  function restore(){
    const raw = localStorage.getItem(KEY);
    if(raw){
      try{ Object.assign(state, JSON.parse(raw)); }catch(e){}
    }
  }

  window.TRFMC_GIS = {
    state,
    setMode,
    fullscreen,
    toggleLeft,
    toggleRight,
    toggleClean,
    toggleCompact,
    runPageAction,
    reset,
    exec,
    hidePanel,
    showPanel
  };

  injectPanel();
  bindKeys();
  restore();
  apply();
  pageLog("global instrument shell online");
})();
JS

python3 - <<'PY'
from pathlib import Path

public = Path("frontend/public")

targets = [
    "trfmc_master_console_v4.html",
    "trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html",
    "trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html",
    "trfmc_measurement_chain_dsp_engine_v3.html",
    "trfmc_wifi_5_6_7_8_qam_engine_v1.html",
    "trfmc_5g_core_ran_identity_aka_engine_v1.html",
    "trfmc_converged_rf_5g_noc_v1.html",
    "trfmc_rf_tm_war_room_v4.html",
    "trfmc_instrument_os_alignment_v1.html",
    "trfmc_enterprise_prime_portal_v1.html",
]

css_tag = '<link rel="stylesheet" href="/assets/trfmc_global_instrument_shell_v1.css">'
js_tag = '<script src="/assets/trfmc_global_instrument_shell_v1.js"></script>'

for name in targets:
    p = public / name
    if not p.exists():
        print("SKIP missing", p)
        continue

    s = p.read_text(errors="ignore")

    if "trfmc_global_instrument_shell_v1.css" not in s:
        if "</head>" in s:
            s = s.replace("</head>", css_tag + "\n</head>", 1)
        else:
            s = css_tag + "\n" + s

    if "trfmc_global_instrument_shell_v1.js" not in s:
        if "</body>" in s:
            s = s.replace("</body>", js_tag + "\n</body>", 1)
        else:
            s = s + "\n" + js_tag

    p.write_text(s)
    print("INJECTED", p)
PY

python3 - <<'PY'
from pathlib import Path

files=[
"frontend/public/trfmc_master_console_v4.html",
"frontend/public/api/portal/index",
"frontend/public/trfmc_enterprise_prime_portal_v1.html"
]

links=[
'<a href="/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html">Antenna V1.7 Layout Lock</a>',
'<a href="/trfmc_measurement_chain_dsp_engine_v3.html">DSP Engine</a>',
'<a href="/trfmc_wifi_5_6_7_8_qam_engine_v1.html">Wi-Fi/QAM Engine</a>',
'<a href="/trfmc_5g_core_ran_identity_aka_engine_v1.html">5G Core/RAN Identity</a>',
'<a href="/trfmc_converged_rf_5g_noc_v1.html">Converged RF/5G NOC</a>'
]

for f in files:
    p=Path(f)
    if not p.exists():
        continue
    s=p.read_text(errors="ignore")
    for link in links:
        href=link.split('href="')[1].split('"')[0]
        if href not in s:
            if "<nav" in s:
                i=s.find("<nav")
                gt=s.find(">",i)
                s=s[:gt+1]+"\n"+link+s[gt+1:]
            elif "<ul>" in s:
                s=s.replace("<ul>","<ul>\n<li>"+link+"</li>",1)
            else:
                s=s.replace("</body>",f'<div style="position:fixed;left:10px;bottom:10px;z-index:9999">{link}</div></body>')
    p.write_text(s)
    print("LINKED",p)
PY

echo
echo "=== HTTP CHECK GLOBAL SHELL ==="
for url in \
  http://127.0.0.1:5173/assets/trfmc_global_instrument_shell_v1.css \
  http://127.0.0.1:5173/assets/trfmc_global_instrument_shell_v1.js \
  http://127.0.0.1:5173/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html \
  http://127.0.0.1:5173/trfmc_measurement_chain_dsp_engine_v3.html \
  http://127.0.0.1:5173/trfmc_wifi_5_6_7_8_qam_engine_v1.html \
  http://127.0.0.1:5173/trfmc_5g_core_ran_identity_aka_engine_v1.html \
  http://127.0.0.1:5173/trfmc_converged_rf_5g_noc_v1.html \
  http://127.0.0.1:5173/trfmc_master_console_v4.html \
  http://127.0.0.1:5173/api/health
do
  echo -n "$url -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "$url"
done

echo
echo "=== DISK ==="
df -h /
df -h /data/LABDATA
