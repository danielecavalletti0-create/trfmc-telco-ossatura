#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
mkdir -p "$PUBLIC" "$BASE/runtime/quality"

cat > "$PUBLIC/trfmc_official_safe_entrypoint_v6.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Official Safe Entrypoint V6</title>
<style>
:root{
  --bg:#01060d;--p:#061120;--p2:#0a1828;--line:#1d6f9f;
  --text:#eaf3ff;--muted:#86a7c6;--cyan:#00d9ff;--green:#7dff4f;
  --yellow:#ffd500;--red:#ff3366;--violet:#c66bff;--orange:#ff9e3d;
}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:var(--bg);color:var(--text);font:12px Inter,Segoe UI,system-ui,sans-serif;overflow:hidden}
header{
  height:56px;background:#050b13;border-bottom:1px solid var(--line);
  display:flex;align-items:center;justify-content:space-between;padding:0 12px;
}
h1{margin:0;font-size:17px;letter-spacing:.08em;text-transform:uppercase}
.sub{color:var(--muted);font-size:11px}
nav{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
button,a{
  color:var(--text);background:#10233a;border:1px solid #285d82;
  border-radius:4px;padding:6px 9px;text-decoration:none;cursor:pointer;font-size:11px;
}
button:hover,a:hover{border-color:var(--cyan);background:#145078;box-shadow:inset 3px 0 0 var(--yellow)}
button.danger:hover{border-color:var(--red);box-shadow:inset 3px 0 0 var(--red)}
.led{width:8px;height:8px;border-radius:50%;background:var(--green);box-shadow:0 0 12px var(--green)}
.top{
  height:84px;display:grid;grid-template-columns:240px repeat(10,1fr) 340px;gap:5px;padding:6px;
  background:linear-gradient(90deg,#061120,#0a1828,#061120);
  border-bottom:1px solid rgba(0,217,255,.45);
}
.id,.cell,.actions{
  border:1px solid rgba(36,91,125,.95);background:linear-gradient(180deg,#09223a,#06111f);
  border-radius:5px;padding:6px;min-width:0;overflow:hidden;position:relative;
}
.id span,.cell span{display:block;color:var(--muted);font-size:8px;text-transform:uppercase;letter-spacing:.04em}
.id b,.cell b{display:block;color:var(--text);font-size:15px;line-height:1.12;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.id b{color:var(--cyan)}
.id em,.cell em{display:block;color:var(--green);font-style:normal;font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.actions{display:grid;grid-template-columns:repeat(4,1fr);gap:4px;padding:5px}
.actions button{padding:4px 5px;text-align:center}
main{
  height:calc(100vh - 140px);
  display:grid;grid-template-columns:310px 1fr 410px;gap:6px;padding:6px;
}
aside,.dock,.stage{
  background:linear-gradient(180deg,#071524,#02070f);
  border:1px solid #1d5e86;border-radius:6px;overflow:hidden;
}
.title{
  background:#0a1b2e;border-bottom:1px solid #1d5e86;color:var(--cyan);
  font-weight:700;padding:7px 8px;text-transform:uppercase;
}
.body{padding:7px}
.card{
  border:1px solid #183d58;background:#081522;border-radius:5px;margin-bottom:6px;padding:8px;cursor:pointer;
}
.card:hover,.card.active{border-color:var(--yellow);box-shadow:inset 3px 0 0 var(--yellow);background:#10233a}
.card b{display:block;color:var(--green);font-size:12px}
.card span{display:block;color:var(--muted);font-size:10px;margin-top:2px;line-height:1.25}
.card small{display:inline-block;margin-top:4px;font-family:ui-monospace,monospace}
.ok{color:var(--green)}.bad{color:var(--red)}.unk{color:var(--yellow)}
.stage{display:grid;grid-template-rows:34px 1fr;position:relative;background:#02070f}
.stagebar{
  height:34px;background:#071524;border-bottom:1px solid #1d5e86;
  display:flex;align-items:center;justify-content:space-between;padding:0 8px;
}
.stagebar b{color:var(--cyan)}
.stagebar span{color:var(--muted);font-family:ui-monospace,monospace;font-size:11px}
iframe{width:100%;height:100%;border:0;background:#02070f;display:block}
.kv{display:grid;grid-template-columns:1fr auto;gap:8px;border-bottom:1px solid rgba(255,255,255,.06);padding:5px 0;font-family:ui-monospace,monospace;font-size:11px}
.kv span{color:#cde7ff}.kv b{color:var(--green)}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:5px}
.grid2 button{margin:0;text-align:center}
.cmd{display:grid;grid-template-columns:1fr auto;gap:5px;margin:7px 0}
.cmd input{
  background:#02070f;border:1px solid #285d82;color:var(--text);
  border-radius:4px;padding:7px;font-family:ui-monospace,monospace;width:100%;
}
.log{height:285px;overflow:auto;border:1px solid #183d58;background:#02070f;border-radius:5px;padding:6px;font-family:ui-monospace,monospace;font-size:11px}
.log div{border-bottom:1px solid rgba(255,255,255,.06);padding:3px 0;color:#cde7ff}
.badge{
  position:absolute;right:10px;bottom:10px;z-index:5;border:1px solid rgba(125,255,79,.45);
  color:var(--green);background:rgba(3,10,18,.8);border-radius:5px;padding:5px 8px;font:11px ui-monospace,monospace;
}
.mini{position:absolute;left:10px;right:10px;bottom:3px;height:15px;opacity:.6;pointer-events:none}
body.focus header,body.focus aside,body.focus .dock,body.focus .top{display:none}
body.focus main{height:100vh;display:block;padding:4px}
body.focus .stage{height:100%}
body.wall main{grid-template-columns:0 1fr 430px}
body.wall aside{display:none}
body.clean .top{display:none}
body.clean main{height:calc(100vh - 56px)}
body.kiosk header,body.kiosk aside,body.kiosk .dock,body.kiosk .top{display:none}
body.kiosk main{height:100vh;display:block;padding:0}
body.kiosk .stage{height:100%;border-radius:0;border:0}
@media(max-width:1500px){
  .top{grid-template-columns:220px repeat(5,1fr) 290px}
  .cell:nth-of-type(n+7){display:none}
}
</style>
</head>
<body>
<header>
  <div>
    <h1>TRFMC Official Safe Entrypoint V6</h1>
    <div class="sub">Entrypoint ufficiale sicuro · wrapper autonomo · nessuna reiniezione · health · evidence · freeze-ready</div>
  </div>
  <nav>
    <button onclick="layout('normal')">Normal</button>
    <button onclick="layout('focus')">Focus</button>
    <button onclick="layout('wall')">Wall</button>
    <button onclick="layout('kiosk')">Kiosk</button>
    <button onclick="toggleClean()">Clean</button>
    <button onclick="health()">Health</button>
    <button onclick="runbook()">Runbook</button>
    <button onclick="exportHtml()">HTML</button>
    <button onclick="exportJson()">JSON</button>
    <button onclick="resetBrokenStorage()" class="danger">Reset State</button>
    <span class="led"></span><span id="clock">--:--:--</span>
  </nav>
</header>

<section class="top">
  <div class="id"><span>Official Entry</span><b>SAFE ENTRYPOINT V6</b><em>single port 5173 · isolated iframe</em></div>
  <div class="cell"><span>Active</span><b id="activeName">Mission Control V5</b><em id="activeType">supervisor</em></div>
  <div class="cell"><span>Health</span><b id="healthState">PENDING</b><em>HTTP gate</em></div>
  <div class="cell"><span>Evidence</span><b id="evCount">0</b><em>events</em></div>
  <div class="cell"><span>Layout</span><b id="layoutState">NORMAL</b><em>operator view</em></div>
  <div class="cell"><span>Isolation</span><b>IFRAME</b><em>no mutation</em></div>
  <div class="cell"><span>Mutation</span><b>ZERO</b><em>stable pages untouched</em></div>
  <div class="cell"><span>Port</span><b>5173</b><em>official</em></div>
  <div class="cell"><span>Gate</span><b id="gate">PASS</b><em>supervisor</em></div>
  <div class="cell"><span>Clock</span><b id="topClock">--:--</b><em>local</em></div>
  <div class="cell"><span>Build</span><b>V6</b><em>official safe entry</em></div>
  <div class="actions">
    <button onclick="load('v5')">V5</button>
    <button onclick="load('v4')">V4</button>
    <button onclick="load('v3')">V3</button>
    <button onclick="load('antenna')">Antenna</button>
    <button onclick="load('dsp')">DSP</button>
    <button onclick="load('wifi')">Wi-Fi</button>
    <button onclick="load('core')">Core</button>
    <button onclick="openActive()">Open</button>
  </div>
  <canvas id="mini" class="mini" width="900" height="20"></canvas>
</section>

<main>
  <aside>
    <div class="title">Official Safe Registry</div>
    <div class="body" id="cards"></div>
  </aside>

  <section class="stage">
    <div class="stagebar">
      <b id="stageTitle">TRFMC Supervisor Mission Control V5</b>
      <span id="stageUrl">/trfmc_supervisor_mission_control_v5.html</span>
    </div>
    <iframe id="frame" src="/trfmc_supervisor_mission_control_v5.html" title="TRFMC official safe workspace"></iframe>
    <div class="badge">V6 OFFICIAL SAFE ENTRYPOINT</div>
  </section>

  <section class="dock">
    <div class="title">Safe Entrypoint / Evidence</div>
    <div class="body">
      <div class="kv"><span>Active Page</span><b id="dockActive">V5</b></div>
      <div class="kv"><span>Frame</span><b id="frameState">LOADING</b></div>
      <div class="kv"><span>Health Gate</span><b id="healthGate">NOT RUN</b></div>
      <div class="kv"><span>Injection</span><b>DISABLED</b></div>
      <div class="kv"><span>Stable Mutation</span><b>ZERO</b></div>

      <div class="cmd">
        <input id="cmd" value="LOAD:V5">
        <button onclick="execCmd()">EXEC</button>
      </div>

      <div class="grid2">
        <button onclick="load('v5')">Mission V5</button>
        <button onclick="load('v4')">Evidence V4</button>
        <button onclick="load('v3')">Matrix V3</button>
        <button onclick="load('antenna')">Antenna Stable</button>
        <button onclick="health()">Health Check</button>
        <button onclick="runbook()">Runbook</button>
        <button onclick="reloadFrame()">Reload Frame</button>
        <button onclick="postPing()">postMessage Ping</button>
        <button onclick="exportJson()">Export JSON</button>
        <button onclick="exportHtml()">Export HTML</button>
        <button onclick="openActive()">Open Standalone</button>
        <button onclick="resetBrokenStorage()">Reset Broken Keys</button>
      </div>

      <div class="title" style="margin:8px -7px 6px">Event Stream</div>
      <div class="log" id="log"></div>
    </div>
  </section>
</main>

<script>
const REG = {
  v6:{name:"Official Safe Entrypoint V6",type:"entrypoint",url:"/trfmc_official_safe_entrypoint_v6.html",desc:"pagina madre ufficiale sicura"},
  v5:{name:"Supervisor Mission Control V5",type:"supervisor",url:"/trfmc_supervisor_mission_control_v5.html",desc:"mission control autonoma"},
  v4:{name:"Unified Evidence Supervisor V4",type:"evidence",url:"/trfmc_unified_evidence_supervisor_v4.html",desc:"runbook · evidence · reports · health"},
  v3:{name:"Unified Matrix Room V3",type:"matrix",url:"/trfmc_unified_matrix_room_v3.html",desc:"single/dual/triple/quad workspace"},
  v2:{name:"Unified Instrument Shell Lab V2",type:"shell",url:"/trfmc_unified_instrument_shell_lab_v2.html",desc:"dual workspace · safe wrapper"},
  antenna:{name:"Antenna Stable Clean V1.6R2",type:"stable module",url:"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html",desc:"antenna/metrology clean dock"},
  dsp:{name:"DSP Measurement Chain",type:"stable module",url:"/trfmc_measurement_chain_dsp_engine_v3.html",desc:"receiver chain · DSP · FFT"},
  wifi:{name:"Wi-Fi/QAM Engine",type:"stable module",url:"/trfmc_wifi_5_6_7_8_qam_engine_v1.html",desc:"Wi-Fi 5/6/7/8 · 4096-QAM"},
  core:{name:"5G Core/RAN Identity",type:"stable module",url:"/trfmc_5g_core_ran_identity_aka_engine_v1.html",desc:"Open5GS · UERANSIM · SUPI/SUCI · AKA"},
  noc:{name:"Converged RF/5G NOC",type:"stable module",url:"/trfmc_converged_rf_5g_noc_v1.html",desc:"RF/5G operational center"},
  master:{name:"Master Console",type:"stable module",url:"/trfmc_master_console_v4.html",desc:"portale master"}
};
let active="v5", evidence=[], healthMap={};
function $(id){return document.getElementById(id)}
function log(msg){
  evidence.unshift({ts:new Date().toISOString(),msg,active,layout:$("layoutState").textContent});
  if(evidence.length>300)evidence.pop();
  const d=document.createElement("div");
  d.textContent="["+new Date().toLocaleTimeString()+"] "+msg;
  $("log").prepend(d);
  while($("log").children.length>90)$("log").removeChild($("log").lastChild);
  update();
}
function renderCards(){
  const box=$("cards"); box.innerHTML="";
  Object.entries(REG).forEach(([k,r])=>{
    if(k==="v6") return;
    const h=healthMap[k], cls=h===200?"ok":h?"bad":"unk", label=h===200?"HTTP 200":h?"HTTP "+h:"not checked";
    const div=document.createElement("div");
    div.className="card"+(k===active?" active":"");
    div.onclick=()=>load(k);
    div.innerHTML="<b>"+r.name+"</b><span>"+r.desc+"</span><span>"+r.url+"</span><small class='"+cls+"'>"+label+"</small>";
    box.appendChild(div);
  });
}
function load(k){
  if(!REG[k] || k==="v6") return log("blocked self/nondestructive route → "+k);
  active=k; const r=REG[k];
  $("frame").src=r.url;
  $("stageTitle").textContent=r.name;
  $("stageUrl").textContent=r.url;
  $("activeName").textContent=r.name;
  $("activeType").textContent=r.type;
  $("dockActive").textContent=k.toUpperCase();
  $("frameState").textContent="LOADING";
  log("loaded → "+r.name+" · "+r.url);
  renderCards();
}
$("frame").addEventListener("load",()=>{$("frameState").textContent="LOADED";log("iframe loaded → "+REG[active].name)});
function update(){
  $("evCount").textContent=String(evidence.length);
  $("clock").textContent=new Date().toLocaleTimeString();
  $("topClock").textContent=new Date().toLocaleTimeString();
  const bad=Object.values(healthMap).some(v=>v!==200);
  $("gate").textContent=bad?"WARN":"PASS";
  $("healthState").textContent=Object.keys(healthMap).length?"CHECKED":"PENDING";
  $("healthGate").textContent=Object.keys(healthMap).length?(bad?"WARN":"PASS"):"NOT RUN";
}
function layout(m){
  document.body.classList.remove("focus","wall","kiosk");
  if(m!=="normal")document.body.classList.add(m);
  $("layoutState").textContent=m.toUpperCase();
  log("layout → "+m.toUpperCase());
}
function toggleClean(){document.body.classList.toggle("clean");log(document.body.classList.contains("clean")?"top strip hidden":"top strip visible")}
async function health(){
  log("health gate started");
  for(const [k,r] of Object.entries(REG)){
    try{
      const res=await fetch(r.url,{method:"HEAD",cache:"no-store"});
      healthMap[k]=res.status; log("health "+k+" → HTTP "+res.status);
    }catch(e){healthMap[k]="ERR";log("health "+k+" → ERR")}
  }
  try{
    const res=await fetch("/api/health",{cache:"no-store"});
    healthMap.api=res.status; log("/api/health → HTTP "+res.status);
  }catch(e){healthMap.api="ERR";log("/api/health → ERR")}
  renderCards(); update();
}
async function runbook(){
  log("runbook started");
  resetBrokenStorage();
  await health();
  load("v5");
  setTimeout(()=>postPing(),600);
  log("runbook complete · V6 safe entry ready");
}
function reloadFrame(){$("frame").contentWindow.location.reload();log("active frame reload requested")}
function postPing(){$("frame").contentWindow.postMessage({type:"TRFMC_SAFE_ENTRY_V6_PING",active,ts:new Date().toISOString()},location.origin);log("postMessage ping sent")}
window.addEventListener("message",ev=>{if(ev.origin!==location.origin)return;log("postMessage received ← "+JSON.stringify(ev.data).slice(0,120))});
function openActive(){window.open(REG[active].url,"_blank");log("opened standalone → "+REG[active].url)}
function resetBrokenStorage(){
  ["trfmc_global_instrument_shell_v1","trfmc_global_top_telemetry_v2","trfmc_v17_layout_mode","trfmc_antenna_v17_layout_mode"].forEach(k=>localStorage.removeItem(k));
  log("removed experimental broken layout keys");
}
function report(){
  return {title:"TRFMC Official Safe Entrypoint V6 Report",exportedAt:new Date().toISOString(),active,activePage:REG[active],health:healthMap,evidence:evidence.slice(0,250)};
}
function exportJson(){
  const blob=new Blob([JSON.stringify(report(),null,2)],{type:"application/json"});
  const a=document.createElement("a"); a.href=URL.createObjectURL(blob);
  a.download="trfmc_official_safe_entrypoint_v6_"+new Date().toISOString().replace(/[:.]/g,"-")+".json";
  a.click(); URL.revokeObjectURL(a.href); log("JSON report exported");
}
function exportHtml(){
  const r=report();
  const hRows=Object.entries(r.health).map(([k,v])=>"<tr><td>"+k+"</td><td>"+v+"</td></tr>").join("");
  const eRows=r.evidence.map(e=>"<tr><td>"+e.ts+"</td><td>"+e.msg+"</td><td>"+e.active+"</td><td>"+e.layout+"</td></tr>").join("");
  const html=`<!doctype html><html><head><meta charset="utf-8"><title>${r.title}</title><style>body{background:#07111f;color:#eaf3ff;font-family:Segoe UI,Arial;padding:24px}h1{color:#00d9ff}table{border-collapse:collapse;width:100%;margin:14px 0}td,th{border:1px solid #245b7d;padding:7px;text-align:left}th{background:#0a1b2e;color:#00d9ff}</style></head><body><h1>${r.title}</h1><p>${r.exportedAt}</p><h2>Active</h2><table><tr><th>Key</th><td>${r.active}</td></tr><tr><th>Name</th><td>${r.activePage.name}</td></tr><tr><th>URL</th><td>${r.activePage.url}</td></tr></table><h2>Health</h2><table><tr><th>Target</th><th>Status</th></tr>${hRows}</table><h2>Evidence</h2><table><tr><th>Timestamp</th><th>Event</th><th>Active</th><th>Layout</th></tr>${eRows}</table></body></html>`;
  const blob=new Blob([html],{type:"text/html"});
  const a=document.createElement("a"); a.href=URL.createObjectURL(blob);
  a.download="trfmc_official_safe_entrypoint_v6_"+new Date().toISOString().replace(/[:.]/g,"-")+".html";
  a.click(); URL.revokeObjectURL(a.href); log("HTML report exported");
}
function execCmd(){
  const c=$("cmd").value.trim().toUpperCase();
  if(c.includes("V5"))load("v5"); else if(c.includes("V4"))load("v4"); else if(c.includes("V3"))load("v3"); else if(c.includes("V2"))load("v2");
  else if(c.includes("ANTENNA"))load("antenna"); else if(c.includes("DSP"))load("dsp"); else if(c.includes("WIFI"))load("wifi"); else if(c.includes("CORE"))load("core");
  else if(c.includes("HEALTH"))health(); else if(c.includes("RUNBOOK"))runbook(); else if(c.includes("RESET"))resetBrokenStorage();
  else if(c.includes("JSON"))exportJson(); else if(c.includes("HTML"))exportHtml(); else log("unknown command → "+c);
}
function draw(){
  const c=$("mini"),x=c.getContext("2d"),w=c.width,h=c.height,t=Date.now()/45;
  x.clearRect(0,0,w,h); x.strokeStyle="rgba(125,255,79,.65)"; x.beginPath();
  for(let i=0;i<w;i++){const y=h/2+Math.sin((i+t)*.035)*5+Math.sin((i+t*.4)*.012)*3;i?x.lineTo(i,y):x.moveTo(i,y)}
  x.stroke();
}
window.addEventListener("keydown",ev=>{
  if(["INPUT","TEXTAREA","SELECT"].includes(ev.target.tagName))return;
  const k=ev.key.toLowerCase();
  if(k==="1")load("v5"); if(k==="2")load("v4"); if(k==="3")load("v3"); if(k==="4")load("antenna");
  if(k==="5")load("dsp"); if(k==="6")load("wifi"); if(k==="7")load("core"); if(k==="h")health();
  if(k==="b")runbook(); if(k==="f")layout("focus"); if(k==="w")layout("wall"); if(k==="k")layout("kiosk");
  if(k==="n")layout("normal"); if(k==="r")reloadFrame(); if(k==="j")exportJson();
});
function loop(){update();draw();requestAnimationFrame(loop)}
renderCards(); log("Official Safe Entrypoint V6 online · standalone / no injection"); loop(); setTimeout(health,700);
</script>
</body>
</html>
HTML

cat > trfmc_quality_gate_light_v6.sh <<'QG'
#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_QUALITY_GATE_V6_$TS"
mkdir -p "$OUT"

URLS=(
"/trfmc_official_safe_entrypoint_v6.html"
"/trfmc_supervisor_mission_control_v5.html"
"/trfmc_unified_evidence_supervisor_v4.html"
"/trfmc_unified_matrix_room_v3.html"
"/trfmc_unified_instrument_shell_lab_v2.html"
"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
"/trfmc_measurement_chain_dsp_engine_v3.html"
"/trfmc_wifi_5_6_7_8_qam_engine_v1.html"
"/trfmc_5g_core_ran_identity_aka_engine_v1.html"
"/trfmc_converged_rf_5g_noc_v1.html"
"/trfmc_master_console_v4.html"
"/api/health"
)

{
  echo -e "url\tstatus\tbytes"
  for u in "${URLS[@]}"; do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u")
    echo -e "$u\t$code\t$bytes"
  done
} > "$OUT/http.tsv"

STABLE_FILES=(
"$PUBLIC/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
"$PUBLIC/trfmc_measurement_chain_dsp_engine_v3.html"
"$PUBLIC/trfmc_wifi_5_6_7_8_qam_engine_v1.html"
"$PUBLIC/trfmc_5g_core_ran_identity_aka_engine_v1.html"
"$PUBLIC/trfmc_converged_rf_5g_noc_v1.html"
"$PUBLIC/trfmc_master_console_v4.html"
)

{
  echo -e "file\tline\tcontent"
  grep -Hn "trfmc_global_instrument_shell_v1\|trfmc_global_top_telemetry_v2" "${STABLE_FILES[@]}" 2>/dev/null || true
} > "$OUT/forbidden_stable_refs.tsv"

NON200="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$OUT/http.tsv")"
FORBIDDEN="$(awk 'NR>1{c++} END{print c+0}' "$OUT/forbidden_stable_refs.tsv")"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "official_entrypoint": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6.html",
  "http_non_200": $NON200,
  "forbidden_stable_refs": $FORBIDDEN,
  "result": "$([ "$NON200" = "0" ] && [ "$FORBIDDEN" = "0" ] && echo PASS || echo WARN)"
}
JSON

cat > "$OUT/report.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><title>TRFMC Quality Gate V6</title>
<style>body{background:#07111f;color:#eaf3ff;font-family:Segoe UI,Arial;padding:24px}h1{color:#00d9ff}pre,table{background:#02070f;border:1px solid #245b7d;padding:12px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #245b7d;padding:7px;text-align:left}th{background:#0a1b2e;color:#00d9ff}</style>
</head><body>
<h1>TRFMC Quality Gate V6</h1>
<pre>$(python3 -m json.tool "$OUT/summary.json")</pre>
<h2>HTTP</h2><table>
$(awk -F'\t' 'NR==1{print "<tr><th>"$1"</th><th>"$2"</th><th>"$3"</th></tr>";next}{print "<tr><td>"$1"</td><td>"$2"</td><td>"$3"</td></tr>"}' "$OUT/http.tsv")
</table>
<h2>Forbidden stable refs</h2><pre>$(cat "$OUT/forbidden_stable_refs.tsv")</pre>
</body></html>
HTML

cp -f "$OUT/report.html" "$PUBLIC/trfmc_quality_gate_v6_report.html"
ln -sfn "$OUT" "$BASE/runtime/quality/latest_v6"

echo "REPORT_DIR=$OUT"
cat "$OUT/summary.json" | python3 -m json.tool
echo "REPORT_URL=http://127.0.0.1:5173/trfmc_quality_gate_v6_report.html"
QG

cat > freeze_trfmc_v6_safe.sh <<'FRZ'
#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
DEST="/data/LABDATA/TRFMC_FREEZES"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$DEST/TRFMC_SAFE_ENTRYPOINT_V6_$TS.tar.gz"

mkdir -p "$DEST"

cd "$BASE"

tar -czf "$OUT" \
  --exclude='./frontend/node_modules' \
  --exclude='./frontend/dist' \
  --exclude='./.venv' \
  --exclude='./runtime/collaudo' \
  --exclude='./runtime/freezes' \
  --exclude='./runtime/tmp' \
  --exclude='./runtime/logs/*.log' \
  --exclude='./runtime/quality/TRFMC_QUALITY_GATE_V6_*' \
  .

echo "FREEZE=$OUT"
ls -lh "$OUT"
df -h /data/LABDATA
FRZ

chmod +x trfmc_quality_gate_light_v6.sh freeze_trfmc_v6_safe.sh

echo "=== HTTP CHECK V6 ENTRYPOINT ==="
for url in \
  http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6.html \
  http://127.0.0.1:5173/trfmc_supervisor_mission_control_v5.html \
  http://127.0.0.1:5173/trfmc_unified_evidence_supervisor_v4.html \
  http://127.0.0.1:5173/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html \
  http://127.0.0.1:5173/api/health
do
  echo -n "$url -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "$url"
done

echo
echo "=== QUALITY GATE V6 ==="
./trfmc_quality_gate_light_v6.sh

echo
echo "APRI:"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6.html"
