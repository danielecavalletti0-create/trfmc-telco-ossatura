#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
SRC="$PUBLIC/trfmc_antenna_system_explorer_v13_premium.html"
DST="$PUBLIC/trfmc_antenna_system_explorer_v14_instrument_grade.html"

if [ ! -f "$SRC" ]; then
  echo "ERRORE: manca $SRC"
  exit 1
fi

cp -f "$SRC" "$DST"

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/public/trfmc_antenna_system_explorer_v14_instrument_grade.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.3 Premium</title>",
    "<title>TRFMC Antenna System Explorer V1.4 Instrument Grade</title>"
)
s = s.replace(
    "TRFMC Antenna System Explorer V1.3 Premium",
    "TRFMC Antenna System Explorer V1.4 Instrument Grade"
)

css = r'''
/* === TRFMC V1.4 OPERATIONAL WIDGET LAYER === */
.opOverlay{
  position:absolute;
  left:0;
  top:26px;
  width:100%;
  height:calc(100% - 26px);
  z-index:4;
  pointer-events:auto;
  cursor:crosshair;
}
.opOverlay[data-locked="1"]{cursor:not-allowed}
.opDock{
  position:absolute;
  left:8px;
  bottom:8px;
  z-index:5;
  display:flex;
  gap:5px;
  flex-wrap:wrap;
  align-items:center;
  background:rgba(3,10,18,.82);
  border:1px solid rgba(0,217,255,.45);
  border-radius:5px;
  padding:5px;
  backdrop-filter:blur(10px);
}
.opDock button{
  width:auto;
  margin:0;
  padding:5px 8px;
  font-size:11px;
}
.opBadge{
  position:absolute;
  right:8px;
  bottom:8px;
  z-index:5;
  background:rgba(3,10,18,.86);
  border:1px solid rgba(125,255,79,.45);
  border-radius:5px;
  padding:5px 8px;
  color:#7dff4f;
  font:11px ui-monospace,monospace;
}
.opPanel{
  border:1px solid #183d58;
  background:#081522;
  border-radius:5px;
  padding:7px;
  margin-bottom:6px;
}
.opPanel b{
  display:block;
  color:#ffd500;
  margin-bottom:5px;
}
.opPanel .opRow{
  display:flex;
  justify-content:space-between;
  gap:8px;
  border-bottom:1px solid rgba(255,255,255,.06);
  padding:3px 0;
  color:#cde7ff;
  font-family:ui-monospace,monospace;
  font-size:11px;
}
.opPanel .opRow span:last-child{color:#7dff4f}
.kpi.opSelected{
  border-color:#ffd500;
  box-shadow:inset 0 -3px 0 #ffd500, 0 0 18px rgba(255,213,0,.18);
}
.frame.opSelected{
  border-color:#ffd500;
  box-shadow:0 0 20px rgba(255,213,0,.16);
}
'''

s = s.replace("</style>", css + "\n</style>")

ops = r'''
<script>
/* === TRFMC ANTENNA V1.4 INSTRUMENT-GRADE OPERATIONS === */
(function(){
  const OP_KEY = "trfmc_antenna_v14_operational_state";

  const WIDGETS = ["site","polar","ports","ret","mimo"];
  const state = {
    armed: "site",
    selectedKpi: "kfreq",
    lock: false,
    markerSeq: 1,
    markers: {site:[], polar:[], ports:[], ret:[], mimo:[]},
    snapshots: [],
    lastAction: "BOOT",
    apiMode: "LOCAL_SIM",
    evidence: []
  };

  function el(id){ return document.getElementById(id); }
  function now(){ return new Date().toLocaleTimeString(); }

  function safeLog(msg){
    if (typeof addLog === "function") addLog("OP · " + msg);
    state.lastAction = msg;
    state.evidence.unshift({ts:new Date().toISOString(), action:msg, armed:state.armed});
    if(state.evidence.length > 100) state.evidence.pop();
    updateOpsPanel();
  }

  function currentParams(){
    const ids = ["type","service","freq","gain","az","tilt","vswr","rl","iso","bal","ptx","sectors","showMain","showSide","showTerrain"];
    const out = {};
    ids.forEach(id=>{
      const x = el(id);
      if(!x) return;
      out[id] = x.type === "checkbox" ? x.checked : x.value;
    });
    return out;
  }

  function applyParam(id,value){
    const x = el(id);
    if(!x) return;
    x.value = value;
    x.dispatchEvent(new Event("input",{bubbles:true}));
  }

  function setChecked(id,value){
    const x = el(id);
    if(!x) return;
    x.checked = !!value;
    x.dispatchEvent(new Event("input",{bubbles:true}));
  }

  function setArmed(id){
    state.armed = id;
    document.querySelectorAll(".frame").forEach(f=>f.classList.remove("opSelected"));
    const cv = el(id);
    if(cv && cv.closest(".frame")) cv.closest(".frame").classList.add("opSelected");
    document.querySelectorAll(".opOverlay").forEach(o=>o.dataset.locked = state.lock ? "1" : "0");
    safeLog("armed widget → " + id.toUpperCase());
  }

  function resizeOverlay(overlay, host){
    const r = host.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    overlay.style.width = r.width + "px";
    overlay.style.height = Math.max(1,r.height-26) + "px";
    overlay.width = Math.floor(r.width * dpr);
    overlay.height = Math.floor(Math.max(1,r.height-26) * dpr);
    overlay.getContext("2d").setTransform(dpr,0,0,dpr,0,0);
  }

  function drawOverlay(id){
    const overlay = el("op_" + id);
    if(!overlay) return;
    const host = overlay.closest(".frame");
    resizeOverlay(overlay, host);
    const ctx = overlay.getContext("2d");
    const w = overlay.clientWidth;
    const h = overlay.clientHeight;
    ctx.clearRect(0,0,w,h);

    ctx.font = "11px ui-monospace,monospace";
    ctx.fillStyle = id === state.armed ? "rgba(255,213,0,.95)" : "rgba(0,217,255,.75)";
    ctx.fillText(id.toUpperCase()+" · "+(id===state.armed?"ARMED":"READY"), 10, 18);

    const marks = state.markers[id] || [];
    marks.forEach(m=>{
      ctx.strokeStyle = m.color;
      ctx.fillStyle = m.color;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(m.x*w, m.y*h, 7, 0, Math.PI*2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(m.x*w-12,m.y*h);
      ctx.lineTo(m.x*w+12,m.y*h);
      ctx.moveTo(m.x*w,m.y*h-12);
      ctx.lineTo(m.x*w,m.y*h+12);
      ctx.stroke();
      ctx.fillText(m.label, m.x*w+10, m.y*h-10);
    });
  }

  function drawAllOverlays(){
    WIDGETS.forEach(drawOverlay);
    requestAnimationFrame(drawAllOverlays);
  }

  function markerColor(id){
    return {site:"#ffd500",polar:"#7dff4f",ports:"#00d9ff",ret:"#ff9e3d",mimo:"#c66bff"}[id] || "#00d9ff";
  }

  function addMarker(id,x,y,label){
    state.markers[id].push({
      id:state.markerSeq++,
      x,y,
      label:label || ("M"+state.markerSeq),
      color:markerColor(id),
      ts:new Date().toISOString()
    });
    if(state.markers[id].length > 12) state.markers[id].shift();
  }

  function canvasPoint(ev, overlay){
    const r = overlay.getBoundingClientRect();
    return {
      x: Math.max(0,Math.min(1,(ev.clientX-r.left)/r.width)),
      y: Math.max(0,Math.min(1,(ev.clientY-r.top)/r.height))
    };
  }

  function operateWidget(id,pt){
    if(state.lock){
      safeLog("locked · ignored pointer on " + id);
      return;
    }

    setArmed(id);

    if(id === "site"){
      const az = Math.round((pt.x - 0.5) * 240);
      const tilt = Math.max(-10, Math.min(20, Math.round((0.55-pt.y)*30)));
      applyParam("az", az);
      applyParam("tilt", tilt);
      addMarker(id,pt.x,pt.y,"AZ "+az+"° / TILT "+tilt+"°");
      safeLog("site pointer → azimuth "+az+"°, tilt "+tilt+"°");
    }

    if(id === "polar"){
      const gain = Math.round(8 + (1-pt.y)*22);
      const az = Math.round((pt.x - 0.5) * 360);
      applyParam("gain", gain);
      applyParam("az", az);
      addMarker(id,pt.x,pt.y,"GAIN "+gain+" / AZ "+az);
      safeLog("polar pointer → gain "+gain+" dBi, azimuth "+az+"°");
    }

    if(id === "ports"){
      const row = Math.max(0,Math.min(5,Math.floor(pt.y*6)));
      const services = ["b8","b3","b1","n78","n77","wifi7"];
      const freqs = [900,1800,2100,3500,3700,5975];
      el("service").value = services[row];
      el("service").dispatchEvent(new Event("input",{bubbles:true}));
      applyParam("freq", freqs[row]);
      addMarker(id,pt.x,pt.y,"PORT P"+(row+1));
      safeLog("port map selected → P"+(row+1)+" / "+services[row]+" / "+freqs[row]+" MHz");
    }

    if(id === "ret"){
      const tilt = Math.round(((0.75-pt.y)*30)*2)/2;
      applyParam("tilt", Math.max(-10,Math.min(20,tilt)));
      addMarker(id,pt.x,pt.y,"RET "+tilt+"°");
      safeLog("RET setpoint → electrical tilt "+tilt+"°");
    }

    if(id === "mimo"){
      const types = ["Panel antenna 4T4R","Massive MIMO 8T8R","Massive MIMO 32T32R"];
      const idx = Math.max(0,Math.min(2,Math.floor(pt.x*3)));
      el("type").value = types[idx];
      el("type").dispatchEvent(new Event("input",{bubbles:true}));
      const az = Math.round((pt.x-.5)*120);
      applyParam("az", az);
      addMarker(id,pt.x,pt.y,types[idx].replace("Massive MIMO ",""));
      safeLog("MIMO selected → "+types[idx]+", beam az "+az+"°");
    }
  }

  function injectOverlays(){
    WIDGETS.forEach(id=>{
      const c = el(id);
      if(!c) return;
      const frame = c.closest(".frame");
      if(!frame || el("op_"+id)) return;

      const overlay = document.createElement("canvas");
      overlay.id = "op_" + id;
      overlay.className = "opOverlay";
      overlay.addEventListener("pointerdown", ev=>{
        const pt = canvasPoint(ev, overlay);
        operateWidget(id,pt);
      });
      frame.appendChild(overlay);

      const badge = document.createElement("div");
      badge.className = "opBadge";
      badge.id = "badge_" + id;
      badge.textContent = "OPERATIVE";
      frame.appendChild(badge);
    });
  }

  function injectDocks(){
    const siteFrame = el("site")?.closest(".frame");
    if(siteFrame && !el("opDockSite")){
      const dock = document.createElement("div");
      dock.id = "opDockSite";
      dock.className = "opDock";
      dock.innerHTML = `
        <button onclick="TRFMC_OP.autoAlign()">Auto Align</button>
        <button onclick="TRFMC_OP.sectorSweep()">Sector Sweep</button>
        <button onclick="TRFMC_OP.heatmapRun()">Run Heatmap</button>
        <button onclick="TRFMC_OP.peakBeam()">Peak Beam</button>
        <button onclick="TRFMC_OP.exportSnapshot()">Export JSON</button>
      `;
      siteFrame.appendChild(dock);
    }

    const rightBody = document.querySelector("aside.panel .body");
    if(rightBody && !el("opLivePanel")){
      const panel = document.createElement("div");
      panel.id = "opLivePanel";
      panel.className = "opPanel";
      panel.innerHTML = `
        <b>Operational Widget State</b>
        <div class="opRow"><span>Armed</span><span id="opArmed">site</span></div>
        <div class="opRow"><span>Mode</span><span id="opMode">LOCAL_SIM</span></div>
        <div class="opRow"><span>Markers</span><span id="opMarkers">0</span></div>
        <div class="opRow"><span>Snapshots</span><span id="opSnaps">0</span></div>
        <div class="opRow"><span>Last Action</span><span id="opLast">BOOT</span></div>
      `;
      rightBody.insertBefore(panel, rightBody.firstChild);
    }

    const ctrl = document.querySelector(".body .ctrl:last-child");
    if(ctrl && !el("opButtons")){
      const box = document.createElement("div");
      box.id = "opButtons";
      box.className = "ctrl";
      box.innerHTML = `
        <b>Operational Actions</b>
        <button onclick="TRFMC_OP.toggleLock()">Lock / Unlock Widgets</button>
        <button onclick="TRFMC_OP.snapshot()">Add Snapshot</button>
        <button onclick="TRFMC_OP.clearMarkers()">Clear All Markers</button>
        <button onclick="TRFMC_OP.randomFault()">Inject RF Fault</button>
        <button onclick="TRFMC_OP.nominal()">Nominal Baseline</button>
      `;
      ctrl.parentElement.appendChild(box);
    }
  }

  function countMarkers(){
    return WIDGETS.reduce((n,id)=>n+(state.markers[id]?.length||0),0);
  }

  function updateOpsPanel(){
    if(el("opArmed")) el("opArmed").textContent = state.armed.toUpperCase();
    if(el("opMode")) el("opMode").textContent = state.apiMode + (state.lock ? " / LOCKED" : "");
    if(el("opMarkers")) el("opMarkers").textContent = countMarkers();
    if(el("opSnaps")) el("opSnaps").textContent = state.snapshots.length;
    if(el("opLast")) el("opLast").textContent = state.lastAction.slice(0,34);
    WIDGETS.forEach(id=>{
      const b=el("badge_"+id);
      if(b) b.textContent = id===state.armed ? "ARMED · CLICK ACTIVE" : "OPERATIVE";
    });
  }

  function autoAlign(){
    applyParam("az",0);
    applyParam("tilt",4);
    applyParam("gain",18);
    applyParam("vswr",135);
    applyParam("rl",18);
    safeLog("auto-align completed → az 0°, tilt 4°, gain 18 dBi");
  }

  function sectorSweep(){
    const az = Number(el("az").value || 0);
    const next = az >= 120 ? -120 : az + 30;
    applyParam("az",next);
    addMarker("site",0.5+next/240,0.48,"SWEEP "+next+"°");
    safeLog("sector sweep step → az "+next+"°");
  }

  function heatmapRun(){
    document.querySelectorAll("button[data-view]").forEach(b=>{
      b.classList.toggle("active",b.dataset.view==="HEAT");
    });
    if(typeof view !== "undefined") view = "HEAT";
    setChecked("showTerrain",true);
    safeLog("heatmap acquisition simulated → coverage energy map refreshed");
  }

  function peakBeam(){
    applyParam("gain", Math.min(30, Number(el("gain").value||18)+1));
    applyParam("iso", Math.min(50, Number(el("iso").value||28)+2));
    addMarker("mimo",0.72,0.50,"PEAK BEAM");
    safeLog("peak beam optimization → gain +1 dB, isolation improved");
  }

  function snapshot(){
    const snap = {
      ts:new Date().toISOString(),
      params:currentParams(),
      markers:JSON.parse(JSON.stringify(state.markers)),
      armed:state.armed
    };
    state.snapshots.unshift(snap);
    if(state.snapshots.length > 20) state.snapshots.pop();
    localStorage.setItem(OP_KEY, JSON.stringify(state));
    safeLog("snapshot added");
  }

  function exportSnapshot(){
    snapshot();
    const data = {
      exportedAt:new Date().toISOString(),
      page:"TRFMC Antenna System Explorer V1.4 Instrument Grade",
      state,
      params:currentParams()
    };
    const blob = new Blob([JSON.stringify(data,null,2)], {type:"application/json"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "trfmc_antenna_v14_snapshot_"+new Date().toISOString().replace(/[:.]/g,"-")+".json";
    a.click();
    URL.revokeObjectURL(a.href);
    safeLog("snapshot exported as JSON");
  }

  function clearMarkers(){
    WIDGETS.forEach(id=>state.markers[id]=[]);
    safeLog("all operational markers cleared");
  }

  function toggleLock(){
    state.lock = !state.lock;
    safeLog(state.lock ? "widgets locked" : "widgets unlocked");
  }

  function randomFault(){
    const faults = [
      ()=>{applyParam("vswr",245);applyParam("rl",8);safeLog("RF fault injected → high VSWR / poor return loss")},
      ()=>{applyParam("iso",14);safeLog("RF fault injected → low cross-pol isolation")},
      ()=>{applyParam("bal",32);safeLog("RF fault injected → port imbalance")},
      ()=>{applyParam("tilt",14);safeLog("RET fault injected → excessive electrical tilt")}
    ];
    faults[Math.floor(Math.random()*faults.length)]();
  }

  function nominal(){
    applyParam("vswr",135);
    applyParam("rl",18);
    applyParam("iso",30);
    applyParam("bal",6);
    applyParam("ptx",24);
    applyParam("tilt",4);
    safeLog("nominal RF baseline restored");
  }

  function saveAll(){
    localStorage.setItem(OP_KEY, JSON.stringify(state));
    if(typeof saveState === "function") saveState();
    safeLog("full operational state saved");
  }

  function recallAll(){
    const raw = localStorage.getItem(OP_KEY);
    if(raw){
      const old = JSON.parse(raw);
      Object.assign(state, old);
      safeLog("operational layer recalled");
    }
    if(typeof loadState === "function") loadState();
  }

  function bindKpis(){
    document.querySelectorAll(".kpi").forEach(k=>{
      k.addEventListener("click", ()=>{
        document.querySelectorAll(".kpi").forEach(x=>x.classList.remove("opSelected"));
        k.classList.add("opSelected");
        const txt = k.innerText.toLowerCase();
        if(txt.includes("frequency")) {el("freq")?.focus(); setArmed("site");}
        else if(txt.includes("gain")) {el("gain")?.focus(); setArmed("polar");}
        else if(txt.includes("tilt")) {el("tilt")?.focus(); setArmed("ret");}
        else if(txt.includes("vswr")) {el("vswr")?.focus(); setArmed("ports");}
        else if(txt.includes("mimo")) {el("type")?.focus(); setArmed("mimo");}
        else setArmed("site");
        safeLog("KPI selected → "+k.querySelector("span")?.textContent);
      });
    });
  }

  function bindKeyboard(){
    window.addEventListener("keydown", ev=>{
      if(ev.target && ["INPUT","SELECT","TEXTAREA"].includes(ev.target.tagName)) return;
      if(ev.key==="1") setArmed("site");
      if(ev.key==="2") setArmed("polar");
      if(ev.key==="3") setArmed("ports");
      if(ev.key==="4") setArmed("ret");
      if(ev.key==="5") setArmed("mimo");
      if(ev.key.toLowerCase()==="s") saveAll();
      if(ev.key.toLowerCase()==="r") recallAll();
      if(ev.key.toLowerCase()==="e") exportSnapshot();
      if(ev.key.toLowerCase()==="l") toggleLock();
    });
  }

  window.TRFMC_OP = {
    state,
    setArmed,
    autoAlign,
    sectorSweep,
    heatmapRun,
    peakBeam,
    snapshot,
    exportSnapshot,
    clearMarkers,
    toggleLock,
    randomFault,
    nominal,
    saveAll,
    recallAll
  };

  injectOverlays();
  injectDocks();
  bindKpis();
  bindKeyboard();
  setArmed("site");
  drawAllOverlays();
  safeLog("instrument-grade operational layer online");
})();
</script>
'''

s = s.replace("</body>", ops + "\n</body>")

p.write_text(s)
print("CREATED", p)
PY

python3 - <<'PY'
from pathlib import Path
files=[
"frontend/public/trfmc_master_console_v4.html",
"frontend/public/trfmc_antenna_system_explorer_v13_premium.html",
"frontend/public/trfmc_antenna_system_explorer_v12_operativo.html",
"frontend/public/trfmc_enterprise_prime_portal_v1.html",
"frontend/public/trfmc_instrument_os_alignment_v1.html",
"frontend/public/api/portal/index"
]
link='<a href="/trfmc_antenna_system_explorer_v14_instrument_grade.html">Antenna V1.4 Instrument Grade</a>'
for f in files:
    p=Path(f)
    if not p.exists():
        continue
    s=p.read_text(errors="ignore")
    if "trfmc_antenna_system_explorer_v14_instrument_grade.html" not in s:
        if "<nav" in s:
            i=s.find("<nav"); gt=s.find(">",i)
            s=s[:gt+1]+"\n"+link+s[gt+1:]
        elif "<ul>" in s:
            s=s.replace("<ul>","<ul>\n<li>"+link+"</li>",1)
        p.write_text(s)
        print("PATCHED",p)
PY

curl -I --max-time 5 http://127.0.0.1:5173/trfmc_antenna_system_explorer_v14_instrument_grade.html
