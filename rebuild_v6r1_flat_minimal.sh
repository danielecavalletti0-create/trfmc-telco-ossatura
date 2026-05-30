#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"

mkdir -p "$PUBLIC" "$BASE/runtime/quality" "$BASE/runtime/backups"

cat > "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC V6R1 Flat</title>
<style>
:root{--bg:#01060d;--panel:#061120;--line:#1d6f9f;--text:#eaf3ff;--muted:#86a7c6;--cyan:#00d9ff;--green:#7dff4f;--yellow:#ffd500;--red:#ff3366}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:var(--bg);color:var(--text);font:12px Segoe UI,system-ui,sans-serif;overflow:hidden}
header{height:54px;background:#050b13;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;padding:0 12px}
h1{margin:0;font-size:17px;letter-spacing:.08em;text-transform:uppercase}
.sub{color:var(--muted);font-size:11px}
button{color:var(--text);background:#10233a;border:1px solid #285d82;border-radius:4px;padding:6px 9px;cursor:pointer;font-size:11px}
button:hover{border-color:var(--cyan);background:#145078;box-shadow:inset 3px 0 0 var(--yellow)}
.top{height:60px;display:grid;grid-template-columns:220px repeat(5,1fr);gap:5px;padding:6px;background:#061120;border-bottom:1px solid rgba(0,217,255,.45)}
.cell{border:1px solid #285d82;background:#081522;border-radius:5px;padding:6px;overflow:hidden}
.cell span{display:block;color:var(--muted);font-size:8px;text-transform:uppercase}
.cell b{display:block;color:var(--green);font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
main{height:calc(100vh - 114px);display:grid;grid-template-columns:280px 1fr 350px;gap:6px;padding:6px}
aside,.stage,.dock{border:1px solid #1d5e86;background:#02070f;border-radius:6px;overflow:hidden}
.title{background:#0a1b2e;border-bottom:1px solid #1d5e86;color:var(--cyan);font-weight:700;padding:7px 8px;text-transform:uppercase}
.body{padding:7px}
.card{border:1px solid #183d58;background:#081522;border-radius:5px;margin-bottom:6px;padding:8px;cursor:pointer}
.card:hover,.card.active{border-color:var(--yellow);box-shadow:inset 3px 0 0 var(--yellow);background:#10233a}
.card b{display:block;color:var(--green)}
.card span{display:block;color:var(--muted);font-size:10px;margin-top:2px}
.stage{display:grid;grid-template-rows:34px 1fr;position:relative}
.stagebar{height:34px;background:#071524;border-bottom:1px solid #1d5e86;display:flex;align-items:center;justify-content:space-between;padding:0 8px}
.stagebar b{color:var(--cyan)}
.stagebar span{color:var(--muted);font-family:monospace;font-size:11px}
iframe{width:100%;height:100%;border:0;background:#02070f}
.log{height:260px;overflow:auto;border:1px solid #183d58;background:#01060d;border-radius:5px;padding:6px;font-family:monospace;font-size:11px}
.log div{border-bottom:1px solid rgba(255,255,255,.06);padding:3px 0;color:#cde7ff}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:5px}
body.focus header,body.focus aside,body.focus .dock,body.focus .top{display:none}
body.focus main{height:100vh;display:block;padding:4px}
body.focus .stage{height:100%}
</style>
</head>
<body>
<header>
  <div>
    <h1>TRFMC Official Safe Entrypoint V6R1 Flat</h1>
    <div class="sub">Iframe solo verso moduli foglia. Le shell V2/V3/V4/V5 si aprono solo in nuova scheda.</div>
  </div>
  <nav>
    <button onclick="layout('normal')">Normal</button>
    <button onclick="layout('focus')">Focus</button>
    <button onclick="health()">Health</button>
    <button onclick="reloadFrame()">Reload</button>
    <button onclick="resetBrokenStorage()">Reset State</button>
  </nav>
</header>

<section class="top">
  <div class="cell"><span>Policy</span><b>LEAF ONLY</b></div>
  <div class="cell"><span>Active</span><b id="activeName">Antenna</b></div>
  <div class="cell"><span>Frame</span><b id="frameState">LOADING</b></div>
  <div class="cell"><span>Health</span><b id="healthState">PENDING</b></div>
  <div class="cell"><span>Nested</span><b>BLOCKED</b></div>
  <div class="cell"><span>Port</span><b>5173</b></div>
</section>

<main>
  <aside>
    <div class="title">Moduli foglia</div>
    <div class="body" id="leafCards"></div>
    <div class="title">Shell precedenti - solo nuova scheda</div>
    <div class="body" id="wrapperCards"></div>
  </aside>

  <section class="stage">
    <div class="stagebar">
      <b id="stageTitle">Antenna Stable Clean V1.6R2</b>
      <span id="stageUrl">/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html</span>
    </div>
    <iframe id="frame" src="/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"></iframe>
  </section>

  <section class="dock">
    <div class="title">Controllo</div>
    <div class="body">
      <div class="grid2">
        <button onclick="load('antenna')">Antenna</button>
        <button onclick="load('dsp')">DSP</button>
        <button onclick="load('wifi')">Wi-Fi/QAM</button>
        <button onclick="load('core')">5G Core</button>
        <button onclick="load('noc')">NOC</button>
        <button onclick="load('war')">War Room</button>
        <button onclick="load('master')">Master</button>
        <button onclick="openActive()">Open</button>
      </div>
      <div class="title" style="margin:8px -7px 6px">Eventi</div>
      <div class="log" id="log"></div>
    </div>
  </section>
</main>

<script>
const LEAF={
 antenna:{name:"Antenna Stable Clean V1.6R2",url:"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"},
 dsp:{name:"DSP Measurement Chain",url:"/trfmc_measurement_chain_dsp_engine_v3.html"},
 wifi:{name:"Wi-Fi/QAM Engine",url:"/trfmc_wifi_5_6_7_8_qam_engine_v1.html"},
 core:{name:"5G Core/RAN Identity",url:"/trfmc_5g_core_ran_identity_aka_engine_v1.html"},
 noc:{name:"Converged RF/5G NOC",url:"/trfmc_converged_rf_5g_noc_v1.html"},
 war:{name:"RF/TM War Room",url:"/trfmc_rf_tm_war_room_v4.html"},
 master:{name:"Master Console",url:"/trfmc_master_console_v4.html"}
};
const WRAP={
 v5:"/trfmc_supervisor_mission_control_v5.html",
 v4:"/trfmc_unified_evidence_supervisor_v4.html",
 v3:"/trfmc_unified_matrix_room_v3.html",
 v2:"/trfmc_unified_instrument_shell_lab_v2.html"
};
let active="antenna";
function $(id){return document.getElementById(id)}
function log(m){const d=document.createElement("div");d.textContent="["+new Date().toLocaleTimeString()+"] "+m;$("log").prepend(d)}
function render(){
 const l=$("leafCards");l.innerHTML="";
 Object.entries(LEAF).forEach(([k,r])=>{const d=document.createElement("div");d.className="card"+(k===active?" active":"");d.onclick=()=>load(k);d.innerHTML="<b>"+r.name+"</b><span>"+r.url+"</span>";l.appendChild(d)});
 const w=$("wrapperCards");w.innerHTML="";
 Object.entries(WRAP).forEach(([k,u])=>{const d=document.createElement("div");d.className="card";d.onclick=()=>window.open(u,"_blank");d.innerHTML="<b>"+k.toUpperCase()+"</b><span>Solo nuova scheda, mai dentro iframe.</span><span>"+u+"</span>";w.appendChild(d)});
}
function load(k){
 if(!LEAF[k])return log("BLOCKED: "+k);
 active=k;const r=LEAF[k];
 $("frame").src=r.url;$("stageTitle").textContent=r.name;$("stageUrl").textContent=r.url;$("activeName").textContent=r.name;$("frameState").textContent="LOADING";
 render();log("loaded leaf module: "+r.name);
}
$("frame").addEventListener("load",()=>{$("frameState").textContent="LOADED";log("iframe loaded: "+LEAF[active].name)});
function layout(m){document.body.classList.toggle("focus",m==="focus");log("layout "+m)}
function reloadFrame(){$("frame").contentWindow.location.reload();log("reload")}
function openActive(){window.open(LEAF[active].url,"_blank")}
function resetBrokenStorage(){["trfmc_global_instrument_shell_v1","trfmc_global_top_telemetry_v2","trfmc_v17_layout_mode","trfmc_antenna_v17_layout_mode"].forEach(k=>localStorage.removeItem(k));log("broken keys removed")}
async function health(){
 let ok=true;
 for(const [k,r] of Object.entries(LEAF)){
  try{const res=await fetch(r.url,{method:"HEAD",cache:"no-store"});log("health "+k+" HTTP "+res.status);if(res.status!==200)ok=false}
  catch(e){log("health "+k+" ERR");ok=false}
 }
 $("healthState").textContent=ok?"PASS":"WARN";
}
render();log("V6R1 flat ready: only leaf modules in iframe");setTimeout(health,500);
</script>
</body>
</html>
HTML

cat > "$PUBLIC/trfmc_official_safe_entrypoint_v6.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0;url=/trfmc_official_safe_entrypoint_v6r1_flat.html">
<title>TRFMC V6 Redirect</title>
<a href="/trfmc_official_safe_entrypoint_v6r1_flat.html">Apri TRFMC V6R1 Flat</a>
HTML

cat > "$PUBLIC/trfmc_reset_browser_state_v6r1.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>TRFMC Reset State</title>
<body style="background:#02070f;color:#eaf3ff;font-family:Segoe UI;padding:30px">
<h1>TRFMC Reset Browser State V6R1</h1>
<pre id="out"></pre>
<a style="color:#ffd500" href="/trfmc_official_safe_entrypoint_v6r1_flat.html">Apri V6R1 Flat</a>
<script>
const keys=["trfmc_global_instrument_shell_v1","trfmc_global_top_telemetry_v2","trfmc_v17_layout_mode","trfmc_antenna_v17_layout_mode"];
document.getElementById("out").textContent=keys.map(k=>{localStorage.removeItem(k);return "REMOVED: "+k}).join("\n");
setTimeout(()=>location.href="/trfmc_official_safe_entrypoint_v6r1_flat.html",1200);
</script>
</body>
HTML

cat > trfmc_guard_no_nested_iframe_v6r1.sh <<'GUARD'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_NO_NESTED_IFRAME_V6R1_$TS"
mkdir -p "$OUT"

URLS=(
"/trfmc_official_safe_entrypoint_v6r1_flat.html"
"/trfmc_official_safe_entrypoint_v6.html"
"/trfmc_reset_browser_state_v6r1.html"
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

grep -nE '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" > "$OUT/nested_iframe_refs.txt" 2>/dev/null || true

grep -nE 'trfmc_global_instrument_shell_v1|trfmc_global_top_telemetry_v2' \
 "$PUBLIC/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html" \
 "$PUBLIC/trfmc_measurement_chain_dsp_engine_v3.html" \
 "$PUBLIC/trfmc_wifi_5_6_7_8_qam_engine_v1.html" \
 "$PUBLIC/trfmc_5g_core_ran_identity_aka_engine_v1.html" \
 "$PUBLIC/trfmc_converged_rf_5g_noc_v1.html" \
 "$PUBLIC/trfmc_master_console_v4.html" > "$OUT/forbidden_stable_refs.txt" 2>/dev/null || true

NON200="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$OUT/http.tsv")"
NESTED="$(wc -l < "$OUT/nested_iframe_refs.txt" | tr -d ' ')"
FORBIDDEN="$(wc -l < "$OUT/forbidden_stable_refs.txt" | tr -d ' ')"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "official_entrypoint": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r1_flat.html",
  "http_non_200": $NON200,
  "nested_supervisor_iframes": $NESTED,
  "forbidden_stable_refs": $FORBIDDEN,
  "result": "$([ "$NON200" = "0" ] && [ "$NESTED" = "0" ] && [ "$FORBIDDEN" = "0" ] && echo PASS || echo WARN)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_no_nested_v6r1"
cat "$OUT/summary.json" | python3 -m json.tool
GUARD

chmod +x trfmc_guard_no_nested_iframe_v6r1.sh
./trfmc_guard_no_nested_iframe_v6r1.sh
