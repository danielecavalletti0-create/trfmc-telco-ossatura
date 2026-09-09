#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V6R3_COMMAND_CENTER_$TS"

mkdir -p "$PUBLIC" "$OUT" "$BASE/runtime/backups"

echo "============================================================"
echo "TRFMC V6R3 COMMAND CENTER - SAFE CREATE"
echo "============================================================"

cp -av "$PUBLIC/trfmc_official_safe_entrypoint_v6r2_premium_console.html" \
  "$BASE/runtime/backups/v6r2_before_v6r3_$TS.html" 2>/dev/null || true

cat > "$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC V6R3 Command Center</title>
<style>
:root{
  --bg:#01060d;--p:#061120;--p2:#081522;--p3:#0a1b2e;
  --line:#1d6f9f;--cyan:#00d9ff;--green:#7dff4f;--yellow:#ffd500;
  --text:#eaf3ff;--muted:#86a7c6;--red:#ff3366;--orange:#ff9e3d;
}
*{box-sizing:border-box}
html,body{margin:0;height:100%;overflow:hidden;background:
radial-gradient(circle at 48% -8%,rgba(0,217,255,.18),transparent 36%),
radial-gradient(circle at 85% 80%,rgba(125,255,79,.08),transparent 30%),
linear-gradient(180deg,#01060d,#020711);color:var(--text);font:12px Segoe UI,system-ui,sans-serif}
header{height:66px;background:#050b13;border-bottom:1px solid var(--line);display:grid;grid-template-columns:350px 1fr 500px;gap:8px;align-items:center;padding:0 10px}
h1{margin:0;font-size:19px;letter-spacing:.09em;text-transform:uppercase}
.sub{color:var(--muted);font-size:11px}
.brand b{color:var(--cyan)}
.tiles{display:grid;grid-template-columns:repeat(8,1fr);gap:5px}
.tile{border:1px solid #245b7d;background:linear-gradient(180deg,#09223a,#06111f);border-radius:5px;padding:5px;min-width:0}
.tile span{display:block;color:var(--muted);font-size:8px;text-transform:uppercase}
.tile b{display:block;color:var(--green);font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
button,a.btn{background:#10233a;color:var(--text);border:1px solid #285d82;border-radius:4px;padding:6px 8px;text-decoration:none;cursor:pointer;font-size:10px;text-transform:uppercase}
button:hover,a.btn:hover{border-color:var(--cyan);background:#145078;box-shadow:inset 3px 0 0 var(--yellow)}
.actions{display:flex;gap:5px;justify-content:flex-end;flex-wrap:wrap}
main{height:calc(100vh - 66px);display:grid;grid-template-columns:330px 1fr 360px;gap:6px;padding:6px}
aside,.stage,.dock{border:1px solid var(--line);background:linear-gradient(180deg,#061321,#02070f);border-radius:8px;overflow:hidden;box-shadow:0 0 30px rgba(0,217,255,.07)}
.title{background:#0a1b2e;border-bottom:1px solid #1d5e86;color:var(--cyan);font-weight:700;padding:7px 8px;text-transform:uppercase;font-size:11px}
.body{padding:7px}
.module{border:1px solid #214a68;background:#081522;border-radius:7px;margin-bottom:6px;padding:8px;cursor:pointer;display:grid;grid-template-columns:45px 1fr;gap:8px;align-items:center}
.module:hover,.module.active{border-color:var(--yellow);background:#10233a;box-shadow:inset 4px 0 0 var(--yellow)}
.ico{height:40px;border:1px solid #285d82;border-radius:6px;display:grid;place-items:center;color:var(--cyan);font-size:20px;background:#04111e;font-weight:800}
.module b{display:block;color:var(--green);font-size:12px;text-transform:uppercase}
.module span{display:block;color:var(--muted);font-size:10px;line-height:1.25}
.stage{display:grid;grid-template-rows:46px 1fr 42px}
.stagebar{height:46px;background:#071524;border-bottom:1px solid #1d5e86;display:grid;grid-template-columns:1fr auto;align-items:center;padding:0 8px;gap:8px}
.stagebar b{color:var(--cyan);font-size:13px;text-transform:uppercase}
.stagebar code{color:var(--muted);font-size:10px}
iframe{width:100%;height:100%;border:0;background:#02070f;display:block}
.statusbar{border-top:1px solid #1d5e86;background:#061120;display:grid;grid-template-columns:repeat(8,1fr);gap:4px;padding:4px}
.s{border-left:1px solid #224e6a;padding-left:7px;color:var(--muted);font:10px Consolas,monospace}
.s b{color:var(--green)}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:5px}
.kv{display:grid;grid-template-columns:1fr auto;gap:8px;border-bottom:1px solid rgba(255,255,255,.06);padding:5px 0;font:11px Consolas,monospace}
.kv b{color:var(--green)}
.log{height:245px;overflow:auto;border:1px solid #183d58;background:#01060d;border-radius:5px;padding:6px;font:11px Consolas,monospace}
.log div{border-bottom:1px solid rgba(255,255,255,.06);padding:3px 0;color:#cde7ff}
canvas{width:100%;height:95px;border:1px solid #183d58;background:#01060d;border-radius:5px;margin-top:6px}
.badge{display:inline-block;border:1px solid rgba(125,255,79,.42);color:var(--green);padding:3px 6px;border-radius:4px;font:10px Consolas,monospace;margin:2px}
body.focus header,body.focus aside,body.focus .dock{display:none}
body.focus main{height:100vh;grid-template-columns:1fr;padding:0}
body.focus .stage{border-radius:0;border:0;grid-template-rows:42px 1fr 34px}
@media(max-width:1500px){header{grid-template-columns:320px 1fr 410px}.tiles{grid-template-columns:repeat(4,1fr)}}
</style>
</head>
<body>
<header>
  <div class="brand">
    <h1><b>TRFMC</b> V6R3 Command Center</h1>
    <div class="sub">RF/Telco/Cyber command console · leaf modules only · no shell nesting</div>
  </div>
  <div class="tiles">
    <div class="tile"><span>Port</span><b>5173</b></div>
    <div class="tile"><span>Gate</span><b>PASS</b></div>
    <div class="tile"><span>Nested</span><b>ZERO</b></div>
    <div class="tile"><span>External</span><b>ZERO</b></div>
    <div class="tile"><span>RF</span><b>ACTIVE</b></div>
    <div class="tile"><span>Core</span><b>5G SA</b></div>
    <div class="tile"><span>Mode</span><b id="modeTile">OPS</b></div>
    <div class="tile"><span>Clock</span><b id="clk">--:--:--</b></div>
  </div>
  <div class="actions">
    <button onclick="layout('normal')">Normal</button>
    <button onclick="layout('focus')">Focus</button>
    <button onclick="health()">Health</button>
    <button onclick="reloadFrame()">Reload</button>
    <button onclick="openActive()">Open</button>
    <a class="btn" href="/trfmc_portal_link_graph_v1.html">Graph</a>
    <a class="btn" href="/trfmc_official_safe_entrypoint_v6r2_premium_console.html">V6R2</a>
  </div>
</header>

<main>
  <aside>
    <div class="title">Operational Modules</div>
    <div class="body" id="mods"></div>
  </aside>

  <section class="stage">
    <div class="stagebar">
      <div>
        <b id="activeTitle">RF/Antenna Academy Wall</b><br>
        <code id="activeUrl">/trfmc_rf_antenna_academy_wall_v2_premium.html</code>
      </div>
      <div>
        <span class="badge">LEAF IFRAME</span>
        <span class="badge">NO MATRIOSKA</span>
      </div>
    </div>
    <iframe id="frame" src="/trfmc_rf_antenna_academy_wall_v2_premium.html"></iframe>
    <div class="statusbar">
      <div class="s">Frame <b id="frameState2">LOAD</b></div>
      <div class="s">Ref <b>50Ω</b></div>
      <div class="s">RBW <b>100k</b></div>
      <div class="s">Avg <b>16</b></div>
      <div class="s">Trace <b>LIVE</b></div>
      <div class="s">API <b>OK</b></div>
      <div class="s">Core <b>READY</b></div>
      <div class="s">User <b>OPS</b></div>
    </div>
  </section>

  <aside class="dock">
    <div class="title">Command / Evidence</div>
    <div class="body">
      <div class="kv"><span>Active</span><b id="activeName">RF/Antenna</b></div>
      <div class="kv"><span>Frame</span><b id="frameState">LOADING</b></div>
      <div class="kv"><span>Policy</span><b>LEAF ONLY</b></div>
      <div class="kv"><span>V6R2</span><b>Fallback</b></div>

      <div class="title" style="margin:8px -7px 6px">Quick Load</div>
      <div class="grid2">
        <button onclick="load('rfwall')">RF/Antenna</button>
        <button onclick="load('antenna')">Antenna</button>
        <button onclick="load('dsp')">DSP</button>
        <button onclick="load('wifi')">Wi-Fi/QAM</button>
        <button onclick="load('core')">5G Core</button>
        <button onclick="load('noc')">NOC</button>
        <button onclick="load('war')">War Room</button>
        <button onclick="load('master')">Master</button>
      </div>

      <canvas id="mini"></canvas>

      <div class="title" style="margin:8px -7px 6px">Event Stream</div>
      <div class="log" id="log"></div>
    </div>
  </aside>
</main>

<script>
const M={
 rfwall:{icon:"▧",name:"RF/Antenna Academy Wall",desc:"thermal noise · gain · RFID · Vivaldi · metasurface · Wi-Fi · site twin",url:"/trfmc_rf_antenna_academy_wall_v2_premium.html"},
 antenna:{icon:"⌁",name:"Antenna System Explorer",desc:"RRU/BBU · RET/AISG · MIMO · VSWR · EIRP · coverage",url:"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"},
 dsp:{icon:"∿",name:"DSP Measurement Chain",desc:"receiver · LNA · mixer · IF · RBW/VBW · detector · FFT",url:"/trfmc_measurement_chain_dsp_engine_v3.html"},
 wifi:{icon:"≋",name:"Wi-Fi/QAM Engine",desc:"Wi-Fi 5/6/6E/7/8 · OFDMA · MLO · 4096-QAM",url:"/trfmc_wifi_5_6_7_8_qam_engine_v1.html"},
 core:{icon:"5G",name:"5G Core/RAN Identity",desc:"Open5GS · UERANSIM · SUPI/SUCI · IMSI · AKA · NGAP/PFCP/GTP-U",url:"/trfmc_5g_core_ran_identity_aka_engine_v1.html"},
 noc:{icon:"N",name:"Converged RF/5G NOC",desc:"RF · SDR · Core · evidence · alarms · operations",url:"/trfmc_converged_rf_5g_noc_v1.html"},
 war:{icon:"⚡",name:"RF/TM War Room",desc:"signal universe · RF/TM · cyber RF intelligence · evidence",url:"/trfmc_rf_tm_war_room_v4.html"},
 master:{icon:"M",name:"Master Console",desc:"portal master and legacy navigation",url:"/trfmc_master_console_v4.html"}
};
let active="rfwall", tick=0;
function $(x){return document.getElementById(x)}
function log(m){const d=document.createElement("div");d.textContent="["+new Date().toLocaleTimeString()+"] "+m;$("log").prepend(d);while($("log").children.length>90)$("log").removeChild($("log").lastChild)}
function render(){
  $("mods").innerHTML=Object.entries(M).map(([k,m])=>`
    <div class="module ${k===active?'active':''}" onclick="load('${k}')">
      <div class="ico">${m.icon}</div>
      <div><b>${m.name}</b><span>${m.desc}</span></div>
    </div>`).join("");
}
function load(k){
  if(!M[k])return;
  active=k;const m=M[k];
  $("frame").src=m.url;
  $("activeTitle").textContent=m.name;
  $("activeUrl").textContent=m.url;
  $("activeName").textContent=m.name;
  $("frameState").textContent="LOADING";
  $("frameState2").textContent="LOAD";
  render();log("loaded leaf module → "+m.name);
}
$("frame").addEventListener("load",()=>{$("frameState").textContent="LOADED";$("frameState2").textContent="OK";log("iframe loaded → "+M[active].name)});
function reloadFrame(){$("frame").contentWindow.location.reload();log("reload active frame")}
function openActive(){window.open(M[active].url,"_blank");log("open standalone → "+M[active].name)}
function layout(m){document.body.classList.toggle("focus",m==="focus");log("layout → "+m)}
async function health(){
  log("health started");
  for(const [k,m] of Object.entries(M)){
    try{const r=await fetch(m.url,{method:"HEAD",cache:"no-store"});log(k+" → HTTP "+r.status)}
    catch(e){log(k+" → ERR")}
  }
  try{const r=await fetch("/api/health",{cache:"no-store"});log("/api/health → HTTP "+r.status)}
  catch(e){log("/api/health → ERR")}
}
function drawMini(){
  const c=$("mini"),r=c.getBoundingClientRect(),d=window.devicePixelRatio||1;
  c.width=Math.max(200,r.width*d);c.height=Math.max(80,r.height*d);
  const x=c.getContext("2d");x.setTransform(d,0,0,d,0,0);x.clearRect(0,0,r.width,r.height);
  x.strokeStyle="rgba(42,111,154,.35)";
  for(let i=0;i<r.width;i+=30){x.beginPath();x.moveTo(i,0);x.lineTo(i,r.height);x.stroke()}
  for(let j=0;j<r.height;j+=20){x.beginPath();x.moveTo(0,j);x.lineTo(r.width,j);x.stroke()}
  x.strokeStyle="#7dff4f";x.beginPath();
  for(let i=0;i<r.width;i++){let y=r.height/2+Math.sin(i*.05+tick)*18+Math.sin(i*.017+tick*2)*7;i?x.lineTo(i,y):x.moveTo(i,y)}
  x.stroke();
}
setInterval(()=>$("clk").textContent=new Date().toLocaleTimeString(),1000);
function loop(){tick+=.04;drawMini();requestAnimationFrame(loop)}
render();log("V6R3 Command Center online");setTimeout(health,500);loop();
</script>
</body>
</html>
HTML

echo "=== QUALITY GATE V6R3 ==="
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_official_safe_entrypoint_v6r2_premium_console.html \
    /trfmc_portal_link_graph_v1.html \
    /trfmc_rf_antenna_academy_wall_v2_premium.html \
    /trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html \
    /trfmc_measurement_chain_dsp_engine_v3.html \
    /trfmc_wifi_5_6_7_8_qam_engine_v1.html \
    /trfmc_5g_core_ran_identity_aka_engine_v1.html \
    /trfmc_converged_rf_5g_noc_v1.html \
    /trfmc_rf_tm_war_room_v4.html \
    /trfmc_master_console_v4.html \
    /api/health
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u")
    echo -e "$u\t$code\t$bytes"
  done
} > "$OUT/http.tsv"

grep -nE '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  "$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html" \
  > "$OUT/nested_iframe_refs.txt" 2>/dev/null || true

grep -nE 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html" \
  > "$OUT/external_refs.txt" 2>/dev/null || true

export OUT
python3 - <<'PY'
import json, os
from pathlib import Path
from datetime import datetime, timezone
out=Path(os.environ["OUT"])
non200=0
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=2 and p[1].strip()!="200":
        non200+=1
nested=sum(1 for x in (out/"nested_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "v6r3":"http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html",
 "http_non_200":non200,
 "nested_supervisor_iframes":nested,
 "external_refs":external,
 "result":"PASS" if non200==0 and nested==0 and external==0 else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v6r3_command_center"

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== NESTED ==="
cat "$OUT/nested_iframe_refs.txt"
echo
echo "=== EXTERNAL ==="
cat "$OUT/external_refs.txt"
