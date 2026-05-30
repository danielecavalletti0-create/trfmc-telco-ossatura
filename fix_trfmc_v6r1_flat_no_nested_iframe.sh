#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
BK="$BASE/runtime/backups/V6_NESTED_ROLLBACK_$TS"

mkdir -p "$BK"

echo "============================================================"
echo "TRFMC V6R1 FLAT - NO NESTED IFRAMES"
echo "============================================================"

echo "[1/5] Backup V6 attuale"
cp -av "$PUBLIC/trfmc_official_safe_entrypoint_v6.html" "$BK/" 2>/dev/null || true

echo
echo "[2/5] Creo V6R1 flat: iframe solo verso moduli foglia"
cat > "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Official Safe Entrypoint V6R1 Flat</title>
<style>
:root{
  --bg:#01060d;--p:#061120;--p2:#0a1828;--line:#1d6f9f;
  --text:#eaf3ff;--muted:#86a7c6;--cyan:#00d9ff;--green:#7dff4f;
  --yellow:#ffd500;--red:#ff3366;--violet:#c66bff;
}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:var(--bg);color:var(--text);font:12px Inter,Segoe UI,system-ui,sans-serif;overflow:hidden}
header{
  height:54px;background:#050b13;border-bottom:1px solid var(--line);
  display:flex;align-items:center;justify-content:space-between;padding:0 12px;
}
h1{margin:0;font-size:17px;letter-spacing:.08em;text-transform:uppercase}
.sub{font-size:11px;color:var(--muted)}
nav{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
button,a{
  color:var(--text);background:#10233a;border:1px solid #285d82;border-radius:4px;
  padding:6px 9px;text-decoration:none;cursor:pointer;font-size:11px;
}
button:hover,a:hover{border-color:var(--cyan);background:#145078;box-shadow:inset 3px 0 0 var(--yellow)}
button.danger:hover{border-color:var(--red);box-shadow:inset 3px 0 0 var(--red)}
.led{width:8px;height:8px;border-radius:50%;background:var(--green);box-shadow:0 0 12px var(--green)}
.top{
  height:74px;display:grid;grid-template-columns:230px repeat(8,1fr) 310px;gap:5px;padding:6px;
  background:linear-gradient(90deg,#061120,#0a1828,#061120);
  border-bottom:1px solid rgba(0,217,255,.45);
}
.id,.cell,.actions{
  border:1px solid rgba(36,91,125,.95);background:linear-gradient(180deg,#09223a,#06111f);
  border-radius:5px;padding:6px;min-width:0;overflow:hidden;
}
.id span,.cell span{display:block;color:var(--muted);font-size:8px;text-transform:uppercase;letter-spacing:.04em}
.id b,.cell b{display:block;color:var(--text);font-size:15px;line-height:1.12;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.id b{color:var(--cyan)}
.id em,.cell em{display:block;color:var(--green);font-style:normal;font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.actions{display:grid;grid-template-columns:repeat(4,1fr);gap:4px;padding:5px}
.actions button{padding:4px 5px;text-align:center}
main{
  height:calc(100vh - 128px);
  display:grid;grid-template-columns:300px 1fr 380px;gap:6px;padding:6px;
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
.stage{display:grid;grid-template-rows:34px 1fr;background:#02070f;position:relative}
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
.log{height:245px;overflow:auto;border:1px solid #183d58;background:#02070f;border-radius:5px;padding:6px;font-family:ui-monospace,monospace;font-size:11px}
.log div{border-bottom:1px solid rgba(255,255,255,.06);padding:3px 0;color:#cde7ff}
.badge{
  position:absolute;right:10px;bottom:10px;z-index:5;border:1px solid rgba(125,255,79,.45);
  color:var(--green);background:rgba(3,10,18,.8);border-radius:5px;padding:5px 8px;font:11px ui-monospace,monospace;
}
body.focus header,body.focus aside,body.focus .dock,body.focus .top{display:none}
body.focus main{height:100vh;display:block;padding:4px}
body.focus .stage{height:100%}
body.wall main{grid-template-columns:0 1fr 410px}
body.wall aside{display:none}
body.clean .top{display:none}
body.clean main{height:calc(100vh - 54px)}
body.kiosk header,body.kiosk aside,body.kiosk .dock,body.kiosk .top{display:none}
body.kiosk main{height:100vh;display:block;padding:0}
body.kiosk .stage{height:100%;border-radius:0;border:0}
@media(max-width:1400px){
  .top{grid-template-columns:220px repeat(4,1fr) 260px}
  .cell:nth-of-type(n+6){display:none}
}
</style>
</head>
<body>
<header>
  <div>
    <h1>TRFMC Official Safe Entrypoint V6R1 Flat</h1>
    <div class="sub">Correzione ufficiale: nessuna shell dentro iframe · solo moduli foglia/stabili</div>
  </div>
  <nav>
    <button onclick="layout('normal')">Normal</button>
    <button onclick="layout('focus')">Focus</button>
    <button onclick="layout('wall')">Wall</button>
    <button onclick="layout('kiosk')">Kiosk</button>
    <button onclick="toggleClean()">Clean</button>
    <button onclick="health()">Health</button>
    <button onclick="reloadFrame()">Reload</button>
    <button onclick="resetBrokenStorage()" class="danger">Reset State</button>
    <span class="led"></span><span id="clock">--:--:--</span>
  </nav>
</header>

<section class="top">
  <div class="id"><span>Official Flat Entry</span><b>V6R1 FLAT</b><em>no nested iframe chain</em></div>
  <div class="cell"><span>Active Module</span><b id="activeName">Antenna Stable</b><em id="activeType">leaf module</em></div>
  <div class="cell"><span>Health</span><b id="healthState">PENDING</b><em>HTTP gate</em></div>
  <div class="cell"><span>Evidence</span><b id="evCount">0</b><em>events</em></div>
  <div class="cell"><span>Layout</span><b id="layoutState">NORMAL</b><em>operator view</em></div>
  <div class="cell"><span>Iframe Policy</span><b>LEAF ONLY</b><em>wrappers open new tab</em></div>
  <div class="cell"><span>Mutation</span><b>ZERO</b><em>stable pages untouched</em></div>
  <div class="cell"><span>Port</span><b>5173</b><em>official</em></div>
  <div class="cell"><span>Gate</span><b id="gate">PASS</b><em>flat supervisor</em></div>
  <div class="actions">
    <button onclick="load('antenna')">Antenna</button>
    <button onclick="load('dsp')">DSP</button>
    <button onclick="load('wifi')">Wi-Fi</button>
    <button onclick="load('core')">Core</button>
    <button onclick="load('noc')">NOC</button>
    <button onclick="load('war')">War</button>
    <button onclick="load('master')">Master</button>
    <button onclick="openActive()">Open</button>
  </div>
</section>

<main>
  <aside>
    <div class="title">Leaf Modules - iframe allowed</div>
    <div class="body" id="cards"></div>

    <div class="title">Supervisor Pages - open only</div>
    <div class="body" id="wrappers"></div>
  </aside>

  <section class="stage">
    <div class="stagebar">
      <b id="stageTitle">Antenna Stable Clean V1.6R2</b>
      <span id="stageUrl">/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html</span>
    </div>
    <iframe id="frame" src="/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html" title="TRFMC leaf module workspace"></iframe>
    <div class="badge">V6R1 FLAT · LEAF MODULE ONLY</div>
  </section>

  <section class="dock">
    <div class="title">Flat Entrypoint / Evidence</div>
    <div class="body">
      <div class="kv"><span>Active</span><b id="dockActive">ANTENNA</b></div>
      <div class="kv"><span>Frame</span><b id="frameState">LOADING</b></div>
      <div class="kv"><span>Health Gate</span><b id="healthGate">NOT RUN</b></div>
      <div class="kv"><span>Nested Shells</span><b>BLOCKED</b></div>
      <div class="kv"><span>Stable Mutation</span><b>ZERO</b></div>

      <div class="cmd">
        <input id="cmd" value="LOAD:ANTENNA">
        <button onclick="execCmd()">EXEC</button>
      </div>

      <div class="grid2">
        <button onclick="load('antenna')">Antenna</button>
        <button onclick="load('dsp')">DSP</button>
        <button onclick="load('wifi')">Wi-Fi/QAM</button>
        <button onclick="load('core')">5G Core</button>
        <button onclick="load('noc')">NOC</button>
        <button onclick="load('war')">War Room</button>
        <button onclick="health()">Health Check</button>
        <button onclick="reloadFrame()">Reload</button>
        <button onclick="openActive()">Open Standalone</button>
        <button onclick="resetBrokenStorage()">Reset Broken Keys</button>
      </div>

      <div class="title" style="margin:8px -7px 6px">Event Stream</div>
      <div class="log" id="log"></div>
    </div>
  </section>
</main>

<script>
const LEAF = {
  antenna:{name:"Antenna Stable Clean V1.6R2",type:"leaf module",url:"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html",desc:"antenna/metrology clean dock"},
  dsp:{name:"DSP Measurement Chain",type:"leaf module",url:"/trfmc_measurement_chain_dsp_engine_v3.html",desc:"receiver chain · DSP · FFT"},
  wifi:{name:"Wi-Fi/QAM Engine",type:"leaf module",url:"/trfmc_wifi_5_6_7_8_qam_engine_v1.html",desc:"Wi-Fi 5/6/7/8 · 4096-QAM"},
  core:{name:"5G Core/RAN Identity",type:"leaf module",url:"/trfmc_5g_core_ran_identity_aka_engine_v1.html",desc:"Open5GS · UERANSIM · SUPI/SUCI · AKA"},
  noc:{name:"Converged RF/5G NOC",type:"leaf module",url:"/trfmc_converged_rf_5g_noc_v1.html",desc:"RF/5G operational center"},
  war:{name:"RF/TM War Room",type:"leaf module",url:"/trfmc_rf_tm_war_room_v4.html",desc:"war room · signals · evidence"},
  master:{name:"Master Console",type:"leaf module",url:"/trfmc_master_console_v4.html",desc:"portal master"}
};
const WRAPPERS = {
  v6:"/trfmc_official_safe_entrypoint_v6.html",
  v5:"/trfmc_supervisor_mission_control_v5.html",
  v4:"/trfmc_unified_evidence_supervisor_v4.html",
  v3:"/trfmc_unified_matrix_room_v3.html",
  v2:"/trfmc_unified_instrument_shell_lab_v2.html"
};
let active="antenna", evidence=[], healthMap={};

function $(id){return document.getElementById(id)}
function log(msg){
  evidence.unshift({ts:new Date().toISOString(),msg,active,layout:$("layoutState").textContent});
  if(evidence.length>200)evidence.pop();
  const d=document.createElement("div");
  d.textContent="["+new Date().toLocaleTimeString()+"] "+msg;
  $("log").prepend(d);
  while($("log").children.length>80)$("log").removeChild($("log").lastChild);
  update();
}
function renderCards(){
  const box=$("cards"); box.innerHTML="";
  Object.entries(LEAF).forEach(([k,r])=>{
    const h=healthMap[k], cls=h===200?"ok":h?"bad":"unk", label=h===200?"HTTP 200":h?"HTTP "+h:"not checked";
    const div=document.createElement("div");
    div.className="card"+(k===active?" active":"");
    div.onclick=()=>load(k);
    div.innerHTML="<b>"+r.name+"</b><span>"+r.desc+"</span><span>"+r.url+"</span><small class='"+cls+"'>"+label+"</small>";
    box.appendChild(div);
  });

  const w=$("wrappers"); w.innerHTML="";
  Object.entries(WRAPPERS).forEach(([k,u])=>{
    const div=document.createElement("div");
    div.className="card";
    div.onclick=()=>{window.open(u,"_blank");log("wrapper opened in new tab only → "+k)};
    div.innerHTML="<b>"+k.toUpperCase()+" supervisor page</b><span>Non viene più caricato dentro iframe.</span><span>"+u+"</span><small class='unk'>open only</small>";
    w.appendChild(div);
  });
}
function load(k){
  if(!LEAF[k]) return log("BLOCKED nested/wrapper iframe request → "+k);
  active=k; const r=LEAF[k];
  $("frame").src=r.url;
  $("stageTitle").textContent=r.name;
  $("stageUrl").textContent=r.url;
  $("activeName").textContent=r.name;
  $("activeType").textContent=r.type;
  $("dockActive").textContent=k.toUpperCase();
  $("frameState").textContent="LOADING";
  log("leaf module loaded → "+r.name);
  renderCards();
}
$("frame").addEventListener("load",()=>{$("frameState").textContent="LOADED";log("iframe loaded → "+LEAF[active].name)});
function update(){
  $("evCount").textContent=String(evidence.length);
  $("clock").textContent=new Date().toLocaleTimeString();
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
  log("health started");
  for(const [k,r] of Object.entries(LEAF)){
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
function reloadFrame(){$("frame").contentWindow.location.reload();log("active leaf iframe reload requested")}
function openActive(){window.open(LEAF[active].url,"_blank");log("opened standalone → "+LEAF[active].url)}
function resetBrokenStorage(){
  ["trfmc_global_instrument_shell_v1","trfmc_global_top_telemetry_v2","trfmc_v17_layout_mode","trfmc_antenna_v17_layout_mode"].forEach(k=>localStorage.removeItem(k));
  log("removed experimental broken layout keys");
}
function execCmd(){
  const c=$("cmd").value.trim().toUpperCase();
  if(c.includes("ANTENNA"))load("antenna");
  else if(c.includes("DSP"))load("dsp");
  else if(c.includes("WIFI")||c.includes("QAM"))load("wifi");
  else if(c.includes("CORE"))load("core");
  else if(c.includes("NOC"))load("noc");
  else if(c.includes("WAR"))load("war");
  else if(c.includes("MASTER"))load("master");
  else if(c.includes("HEALTH"))health();
  else if(c.includes("RESET"))resetBrokenStorage();
  else if(c.includes("FOCUS"))layout("focus");
  else if(c.includes("WALL"))layout("wall");
  else if(c.includes("KIOSK"))layout("kiosk");
  else if(c.includes("NORMAL"))layout("normal");
  else log("unknown/blocked command → "+c);
}
window.addEventListener("keydown",ev=>{
  if(["INPUT","TEXTAREA","SELECT"].includes(ev.target.tagName))return;
  const k=ev.key.toLowerCase();
  if(k==="1")load("antenna"); if(k==="2")load("dsp"); if(k==="3")load("wifi"); if(k==="4")load("core");
  if(k==="5")load("noc"); if(k==="6")load("war"); if(k==="7")load("master"); if(k==="h")health();
  if(k==="f")layout("focus"); if(k==="w")layout("wall"); if(k==="k")layout("kiosk"); if(k==="n")layout("normal"); if(k==="r")reloadFrame();
});
renderCards(); log("V6R1 FLAT online · only leaf modules in iframe · wrappers open in new tab"); update(); setTimeout(health,500);
</script>
</body>
</html>
HTML

echo
echo "[3/5] Sostituisco V6 ufficiale con redirect alla V6R1 flat"
cat > "$PUBLIC/trfmc_official_safe_entrypoint_v6.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0;url=/trfmc_official_safe_entrypoint_v6r1_flat.html">
<title>TRFMC V6 redirected to V6R1 Flat</title>
<style>
body{background:#02070f;color:#eaf3ff;font-family:Segoe UI,system-ui,sans-serif;display:grid;place-items:center;height:100vh}
a{color:#ffd500}
</style>
</head>
<body>
<div>
<h1>TRFMC V6 → V6R1 FLAT</h1>
<p>Redirect alla versione corretta senza iframe annidati.</p>
<p><a href="/trfmc_official_safe_entrypoint_v6r1_flat.html">Apri V6R1 Flat</a></p>
</div>
</body>
</html>
HTML

echo
echo "[4/5] Quality check flat"
cat > "$BASE/trfmc_quality_gate_v6r1_flat.sh" <<'QG'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V6R1_FLAT_$TS"
mkdir -p "$OUT"

URLS=(
"/trfmc_official_safe_entrypoint_v6r1_flat.html"
"/trfmc_official_safe_entrypoint_v6.html"
"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
"/trfmc_measurement_chain_dsp_engine_v3.html"
"/trfmc_wifi_5_6_7_8_qam_engine_v1.html"
"/trfmc_5g_core_ran_identity_aka_engine_v1.html"
"/trfmc_converged_rf_5g_noc_v1.html"
"/trfmc_rf_tm_war_room_v4.html"
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

# Dentro V6R1 non devono esserci wrapper supervisor come iframe/route caricabile.
grep -nE 'trfmc_supervisor_mission_control_v5.html|trfmc_unified_evidence_supervisor_v4.html|trfmc_unified_matrix_room_v3.html|trfmc_unified_instrument_shell_lab_v2.html' \
  "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" > "$OUT/wrapper_refs.txt" || true

# Sono ammessi solo in WRAPPERS/open-only. Segnalo comunque per revisione, ma non blocco.
NON200="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$OUT/http.tsv")"
IFRAME_NESTED="$(grep -nE '<iframe[^>]+src="/trfmc_(supervisor|unified)' "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" 2>/dev/null | wc -l | tr -d ' ')"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "official_flat": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r1_flat.html",
  "http_non_200": $NON200,
  "nested_supervisor_iframes": $IFRAME_NESTED,
  "result": "$([ "$NON200" = "0" ] && [ "$IFRAME_NESTED" = "0" ] && echo PASS || echo WARN)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v6r1_flat"
cat "$OUT/summary.json" | python3 -m json.tool
QG

chmod +x "$BASE/trfmc_quality_gate_v6r1_flat.sh"

echo
echo "[5/5] HTTP e gate"
"$BASE/trfmc_quality_gate_v6r1_flat.sh"

echo
echo "============================================================"
echo "V6R1 FLAT PRONTA"
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r1_flat.html"
echo
echo "La vecchia V6 ora redirige alla V6R1:"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6.html"
echo "============================================================"
