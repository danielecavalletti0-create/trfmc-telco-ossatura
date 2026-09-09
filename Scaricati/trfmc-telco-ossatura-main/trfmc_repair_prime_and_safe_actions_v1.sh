#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$PUBLIC" "$BASE/runtime/logs"

echo "============================================================"
echo "TRFMC REPAIR PRIME + SAFE ACTIONS V1"
echo "NO FREEZE · NO HEAVY REPORT · 5173 ONLY"
echo "============================================================"

PRIME="$PUBLIC/trfmc_enterprise_prime_portal_v1.html"
SAFE="$PUBLIC/trfmc_safe_runtime_action_console_v1.html"

[ -f "$PRIME" ] && cp -a "$PRIME" "$PRIME.bak_repair_$TS" || true
[ -f "$SAFE" ] && cp -a "$SAFE" "$SAFE.bak_repair_$TS" || true

cat > "$PRIME" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Enterprise Prime Portal V1</title>
<style>
:root{--bg:#01040c;--panel:rgba(5,13,30,.94);--line:rgba(105,190,255,.30);--text:#eaf3ff;--muted:#90a9c7;--cyan:#74dcff;--green:#9dffc7;--amber:#ffd37a;--red:#ff8585;--violet:#bda7ff}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;color:var(--text);font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:radial-gradient(circle at 12% 0%,rgba(48,132,255,.34),transparent 31%),radial-gradient(circle at 88% 4%,rgba(0,255,205,.16),transparent 31%),linear-gradient(180deg,#01040c,#061327 52%,#01040c)}
body:before{content:"";position:fixed;inset:0;pointer-events:none;background:linear-gradient(rgba(255,255,255,.026) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.026) 1px,transparent 1px);background-size:38px 38px;mask-image:linear-gradient(to bottom,rgba(0,0,0,.95),rgba(0,0,0,.10))}
header{position:sticky;top:0;z-index:20;background:rgba(1,4,12,.88);border-bottom:1px solid var(--line);backdrop-filter:blur(22px)}
.topbar{display:flex;justify-content:space-between;align-items:center;gap:18px;padding:15px 20px}
.brand h1{margin:0;font-size:22px;letter-spacing:.10em;text-transform:uppercase}.brand small{display:block;color:var(--muted);margin-top:4px}
.nav{display:flex;gap:7px;flex-wrap:wrap;justify-content:flex-end}.nav a,.pill{color:var(--text);text-decoration:none;border:1px solid var(--line);background:rgba(255,255,255,.045);border-radius:999px;padding:7px 10px;font-size:11px}.pill.ok{color:var(--green);border-color:rgba(157,255,199,.55)}
main{padding:16px}.hero{display:grid;grid-template-columns:1.15fr .85fr;gap:14px;margin-bottom:14px}.panel{border:1px solid var(--line);background:linear-gradient(180deg,var(--panel),rgba(2,8,20,.94));border-radius:22px;box-shadow:0 22px 78px rgba(0,0,0,.40),inset 0 1px 0 rgba(255,255,255,.055)}
.heroMain{padding:22px}.heroMain h2{margin:0 0 12px;font-size:46px;line-height:1;letter-spacing:-.05em}.heroMain p{color:#c8daf1;line-height:1.55;max-width:1120px}
.kpis{display:grid;grid-template-columns:repeat(6,1fr);gap:9px;margin-top:16px}.kpi{border:1px solid rgba(255,255,255,.10);background:rgba(255,255,255,.04);border-radius:15px;padding:10px}.kpi b{display:block;font-size:20px}.kpi span{color:var(--muted);font-size:10px}
.status{padding:14px;display:grid;gap:9px}.statusRow{display:flex;justify-content:space-between;gap:12px;border:1px solid rgba(255,255,255,.09);background:rgba(255,255,255,.035);border-radius:13px;padding:10px}.statusRow span{color:var(--muted);text-align:right}
.layout{display:grid;grid-template-columns:350px minmax(780px,1fr) 400px;gap:14px}.left,.center,.right{padding:14px}.left,.right{display:grid;gap:11px;align-content:start}h3{margin:0;color:var(--cyan)}
.block,.card{border:1px solid rgba(255,255,255,.10);background:rgba(255,255,255,.04);border-radius:16px;padding:12px}.block h4{margin:0 0 8px;color:var(--green);font-size:13px;text-transform:uppercase;letter-spacing:.04em}.block p,.card p,.card span{color:var(--muted);font-size:12px;line-height:1.4}
.linkGrid{display:grid;gap:7px}.linkGrid a{color:var(--text);text-decoration:none;border:1px solid rgba(105,190,255,.20);background:rgba(255,255,255,.035);border-radius:12px;padding:9px;font-size:12px}.linkGrid a:hover{border-color:rgba(116,220,255,.80);background:linear-gradient(135deg,rgba(45,132,255,.22),rgba(0,255,205,.09))}
.canvasFrame{border:1px solid rgba(105,190,255,.26);background:rgba(255,255,255,.022);border-radius:20px;overflow:hidden}.canvasTitle{display:flex;justify-content:space-between;gap:10px;padding:8px 10px;color:var(--muted);font-size:11px;border-bottom:1px solid rgba(255,255,255,.08)}
canvas{width:100%;height:610px;display:block;background:radial-gradient(circle at 50% 50%,rgba(24,82,150,.16),transparent 42%),linear-gradient(180deg,rgba(255,255,255,.032),rgba(255,255,255,.010))}
.matrix{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:10px}
.meter{height:9px;border-radius:999px;background:rgba(255,255,255,.08);overflow:hidden;margin-top:7px}.meter i{display:block;height:100%;width:50%;background:linear-gradient(90deg,var(--cyan),var(--green))}
.eventLog{max-height:330px;overflow:auto;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;font-size:11px;color:#c0d5ee}.eventLog div{padding:5px 0;border-bottom:1px solid rgba(255,255,255,.06)}
@media(max-width:1550px){.layout{grid-template-columns:340px 1fr}.right{grid-column:1/-1;grid-template-columns:repeat(3,1fr)}}@media(max-width:1100px){.hero,.layout,.right,.matrix,.kpis{grid-template-columns:1fr}}
</style>
</head>
<body>
<header>
<div class="topbar">
<div class="brand"><h1>TRFMC Enterprise Prime Portal</h1><small>RF/TM · HackRF · Open5GS · UERANSIM · SUPI/SUCI · AKA · NAS · Evidence · 5173</small></div>
<nav class="nav">
<span class="pill ok" id="healthPill">Health: checking</span>
<a href="/trfmc_runtime_hook_layer_v1.html">Runtime Hook</a>
<a href="/trfmc_safe_runtime_action_console_v1.html">Safe Actions</a>
<a href="/trfmc_converged_rf_5g_noc_v1.html">Converged NOC</a>
<a href="/trfmc_rf_tm_war_room_v4.html">RF/TM War Room</a>
<a href="/trfmc_5g_core_ran_identity_aka_engine_v1.html">5G Identity/AKA</a>
<a href="/trfmc_collaudo_report.html">Collaudo</a>
</nav>
</div>
</header>
<main>
<section class="hero">
<div class="panel heroMain">
<h2>Expert Enterprise RF/Telco/Cyber Portal</h2>
<p>Cabina principale del laboratorio: RF/TM, HackRF, Open5GS, UERANSIM, identità 5G, AKA, NAS security, NGAP/PFCP/GTP-U, evidenze e readiness operativa in un unico quadro.</p>
<div class="kpis">
<div class="kpi"><b>5173</b><span>single entrypoint</span></div><div class="kpi"><b>RF/TM</b><span>instrumentation</span></div><div class="kpi"><b>HackRF</b><span>SDR readiness</span></div><div class="kpi"><b>Open5GS</b><span>5G core</span></div><div class="kpi"><b>UERANSIM</b><span>UE/gNB</span></div><div class="kpi"><b>AKA/NAS</b><span>security</span></div>
</div>
</div>
<aside class="panel status">
<div class="statusRow"><b>Portal status</b><span id="portalStatus">checking</span></div>
<div class="statusRow"><b>Quality policy</b><span>light check by default</span></div>
<div class="statusRow"><b>Disk guard</b><span>no giant local freeze</span></div>
<div class="statusRow"><b>Mission</b><span>enterprise RF/Telco/Cyber digital twin</span></div>
</aside>
</section>
<section class="layout">
<aside class="panel left">
<h3>Prime Navigation</h3>
<div class="block"><h4>Enterprise Consoles</h4><div class="linkGrid">
<a href="/trfmc_converged_rf_5g_noc_v1.html">Converged RF + 5G NOC</a>
<a href="/trfmc_runtime_hook_layer_v1.html">Runtime Hook Layer</a>
<a href="/trfmc_safe_runtime_action_console_v1.html">Safe Runtime Action Console</a>
<a href="/trfmc_rf_tm_war_room_v4.html">RF/TM War Room V4</a>
<a href="/trfmc_5g_core_ran_identity_aka_engine_v1.html">5G Core/RAN Identity & AKA</a>
</div></div>
<div class="block"><h4>Governance</h4><div class="linkGrid">
<a href="/trfmc_unified_navigation_shell_v1.html">Unified Navigation Shell</a>
<a href="/trfmc_domain_registry_v1.html">Domain Registry</a>
<a href="/trfmc_engine_promotion_board_v1.html">Engine Promotion Board</a>
<a href="/trfmc_collaudo_report.html">Quality Gate Report</a>
<a href="/api/health">Portal Health JSON</a>
</div></div>
</aside>
<section class="panel center">
<div class="canvasFrame"><div class="canvasTitle"><b>Enterprise Converged Digital Twin</b><span>RF + 5G + Identity + Evidence</span></div><canvas id="primeCanvas" width="1600" height="720"></canvas></div>
<div class="matrix">
<div class="card"><b>5G Identity/Security Plane</b><p>SUPI/SUCI, IMSI, HNPKI, AUSF, UDM/ARPF, 5G-AKA, EAP-AKA', NAS Security Mode, GUTI lifecycle.</p></div>
<div class="card"><b>RF/TM Instrument Plane</b><p>Receiver chain, generator, oscilloscope, spectrum analyzer, VSA/IQ, phase, spatial field, HackRF readiness.</p></div>
<div class="card"><b>Core/RAN Protocol Plane</b><p>UERANSIM UE/gNB, AMF, SMF, UPF, NGAP, PFCP, GTP-U, PDU session, evidence correlation.</p></div>
<div class="card"><b>Evidence Plane</b><p>PCAP, IQ capture, Open5GS logs, UERANSIM logs, event timeline, report builder, lab-only evidence trail.</p></div>
</div>
</section>
<aside class="panel right">
<h3>Enterprise Readout</h3>
<div class="card"><b>RF/TM Completeness</b><span>receiver/generator/spectrum/phase/space</span><div class="meter"><i style="width:82%"></i></div></div>
<div class="card"><b>5G Core/RAN Completeness</b><span>Open5GS + UERANSIM + AKA/NAS/PDU</span><div class="meter"><i style="width:78%"></i></div></div>
<div class="card"><b>Runtime Readiness</b><span>hook scripts/logs/pcap/iq without changing 5173</span><div class="meter"><i style="width:58%"></i></div></div>
<div class="card"><b>Event Stream</b><div class="eventLog" id="events"></div></div>
</aside>
</section>
</main>
<script>
const $=id=>document.getElementById(id);const c=$("primeCanvas"),x=c.getContext("2d");let t=0,last=0;
const nodes=[["RF World",.08,.56,"#74dcff"],["HackRF",.19,.34,"#9dffc7"],["Receiver",.19,.70,"#74dcff"],["UE/SUPI",.33,.56,"#74dcff"],["gNB",.45,.45,"#9dffc7"],["AMF",.58,.35,"#74dcff"],["AUSF",.70,.20,"#bda7ff"],["UDM/ARPF",.84,.20,"#ffd37a"],["SMF",.70,.58,"#74dcff"],["UPF",.84,.58,"#9dffc7"],["DN",.94,.58,"#9dffc7"],["Evidence",.58,.78,"#ffd37a"]];
function label(s,a,b,col="rgba(234,243,255,.82)",sz=12){x.fillStyle=col;x.font=sz+"px system-ui";x.fillText(s,a,b)}
function node(n){let w=c.width,h=c.height,px=n[1]*w,py=n[2]*h;x.shadowColor=n[3];x.shadowBlur=18;x.fillStyle=n[3];x.beginPath();x.arc(px,py,12,0,Math.PI*2);x.fill();x.shadowBlur=0;x.strokeStyle="rgba(255,255,255,.20)";x.beginPath();x.arc(px,py,25+Math.sin(t*.05+n[1]*9)*4,0,Math.PI*2);x.stroke();label(n[0],px-38,py+42)}
function get(id){return nodes.find(n=>n[0]===id)}
function edge(a,b,name,warn=false){let W=c.width,H=c.height,A=get(a),B=get(b),ax=A[1]*W,ay=A[2]*H,bx=B[1]*W,by=B[2]*H;x.strokeStyle=warn?"rgba(255,133,133,.44)":"rgba(157,255,199,.48)";x.lineWidth=2;x.beginPath();x.moveTo(ax,ay);x.lineTo(bx,by);x.stroke();let q=(Math.sin(t*.055+ax*.001)*.5+.5),px=ax+(bx-ax)*q,py=ay+(by-ay)*q;x.fillStyle=warn?"rgba(255,133,133,.95)":"rgba(255,211,122,.92)";x.beginPath();x.arc(px,py,4.5,0,Math.PI*2);x.fill();label(name,(ax+bx)/2,(ay+by)/2-8,"rgba(144,169,199,.86)",10)}
function draw(){let W=c.width,H=c.height;x.clearRect(0,0,W,H);let g=x.createRadialGradient(W/2,H/2,20,W/2,H/2,W*.72);g.addColorStop(0,"rgba(30,115,220,.20)");g.addColorStop(1,"rgba(255,255,255,.006)");x.fillStyle=g;x.fillRect(0,0,W,H);x.strokeStyle="rgba(105,190,255,.075)";for(let i=0;i<W;i+=50){x.beginPath();x.moveTo(i,0);x.lineTo(i,H);x.stroke()}for(let j=0;j<H;j+=40){x.beginPath();x.moveTo(0,j);x.lineTo(W,j);x.stroke()}for(let i=0;i<18;i++){let a=i/18*Math.PI*2+t*.01,r=50+(i%6)*22+Math.sin(t*.04+i)*7,px=.08*W+Math.cos(a)*r,py=.56*H+Math.sin(a)*r*.62,warn=i%7===0;x.strokeStyle=warn?"rgba(255,133,133,.20)":"rgba(116,220,255,.16)";x.beginPath();x.arc(px,py,25+(i%3)*9,0,Math.PI*2);x.stroke();x.fillStyle=warn?"rgba(255,133,133,.90)":"rgba(116,220,255,.78)";x.beginPath();x.arc(px,py,warn?5:3.5,0,Math.PI*2);x.fill()}edge("RF World","HackRF","IQ/FFT");edge("HackRF","Receiver","RX chain");edge("RF World","UE/SUPI","radio env",true);edge("UE/SUPI","gNB","Uu/RRC/NAS");edge("gNB","AMF","N2/NGAP");edge("AMF","AUSF","N12/AKA");edge("AUSF","UDM/ARPF","N13/vector");edge("AMF","SMF","N11");edge("SMF","UPF","N4/PFCP");edge("gNB","UPF","N3/GTP-U");edge("UPF","DN","N6");edge("AMF","Evidence","NAS/NGAP log");edge("UPF","Evidence","GTP-U/PCAP");edge("HackRF","Evidence","IQ evidence");nodes.forEach(node);label("TRFMC Enterprise Digital Twin · RF/TM + HackRF + Open5GS + UERANSIM + Identity/Security + Evidence",52,H-45,"rgba(255,211,122,.94)",15)}
function log(){let now=Date.now();if(now-last<1600)return;last=now;let ev=["RF sweep correlated with UE/gNB attach window","SUPI/SUCI privacy plane active","AUSF/UDM authentication vector visualized","NAS security mode negotiated","PFCP N4 programming mapped to UPF","GTP-U tunnel evidence target ready","HackRF IQ evidence hook staged"];let r=document.createElement("div");r.textContent="["+new Date().toLocaleTimeString()+"] "+ev[Math.floor(Math.random()*ev.length)];$("events").prepend(r);while($("events").children.length>24)$("events").removeChild($("events").lastChild)}
async function health(){try{let r=await fetch("/api/health",{cache:"no-store"}),j=await r.json();$("healthPill").textContent=j.ok?"Health: online":"Health: degraded";$("portalStatus").textContent=j.ok?"online / 5173":"degraded"}catch(e){$("healthPill").textContent="Health: unavailable";$("portalStatus").textContent="unavailable"}}
health();(function loop(){t++;draw();log();requestAnimationFrame(loop)})()
</script>
</body>
</html>
HTML

cat > "$SAFE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Safe Runtime Action Console V1</title>
<style>
:root{--bg:#01040c;--panel:rgba(5,13,30,.94);--line:rgba(105,190,255,.30);--text:#eaf3ff;--muted:#90a9c7;--cyan:#74dcff;--green:#9dffc7;--amber:#ffd37a;--red:#ff8585}
*{box-sizing:border-box}body{margin:0;min-height:100vh;color:var(--text);background:radial-gradient(circle at 12% 0%,rgba(48,132,255,.34),transparent 31%),radial-gradient(circle at 88% 4%,rgba(0,255,205,.16),transparent 31%),linear-gradient(180deg,#01040c,#061327 52%,#01040c);font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
header{position:sticky;top:0;z-index:20;background:rgba(1,4,12,.88);border-bottom:1px solid var(--line);backdrop-filter:blur(22px)}.topbar{display:flex;justify-content:space-between;align-items:center;gap:18px;padding:15px 20px}.brand h1{margin:0;font-size:21px;letter-spacing:.10em;text-transform:uppercase}.brand small{display:block;color:var(--muted);margin-top:4px}.nav{display:flex;gap:7px;flex-wrap:wrap;justify-content:flex-end}.nav a,.pill{color:var(--text);text-decoration:none;border:1px solid var(--line);background:rgba(255,255,255,.045);border-radius:999px;padding:7px 10px;font-size:11px}.pill.ok{color:var(--green);border-color:rgba(157,255,199,.55)}
main{padding:16px}.hero{display:grid;grid-template-columns:1.1fr .9fr;gap:14px;margin-bottom:14px}.panel{border:1px solid var(--line);background:linear-gradient(180deg,var(--panel),rgba(2,8,20,.94));border-radius:22px;box-shadow:0 22px 78px rgba(0,0,0,.40),inset 0 1px 0 rgba(255,255,255,.055)}.heroMain{padding:22px}.heroMain h2{margin:0 0 12px;font-size:42px;line-height:1;letter-spacing:-.05em}.heroMain p{color:#c8daf1;line-height:1.55}.status{padding:14px;display:grid;gap:9px}.statusRow{display:flex;justify-content:space-between;gap:12px;border:1px solid rgba(255,255,255,.09);background:rgba(255,255,255,.035);border-radius:13px;padding:10px}.statusRow span{color:var(--muted);text-align:right}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.section{padding:14px}.section h3{margin:0 0 12px;color:var(--cyan)}.cmd{border:1px solid rgba(255,255,255,.10);background:rgba(255,255,255,.04);border-radius:15px;padding:12px;margin-bottom:10px}.cmd b{display:block;color:var(--green);margin-bottom:6px}.cmd p{color:var(--muted);font-size:12px;line-height:1.4}pre{white-space:pre-wrap;overflow:auto;border:1px solid rgba(255,255,255,.10);background:rgba(0,0,0,.28);border-radius:12px;padding:10px;color:#c0d5ee;font-size:11px}button{border:1px solid rgba(105,190,255,.30);background:rgba(255,255,255,.045);color:var(--text);border-radius:999px;padding:8px 12px;cursor:pointer;margin-top:6px}.warn{color:var(--amber)}
@media(max-width:1200px){.hero,.grid{grid-template-columns:1fr}}
</style>
</head>
<body>
<header><div class="topbar"><div class="brand"><h1>TRFMC Safe Runtime Action Console V1</h1><small>Dry-run only · Copy commands · Open5GS · UERANSIM · HackRF · Evidence · 5173</small></div><nav class="nav"><span class="pill ok" id="healthPill">Health: checking</span><a href="/trfmc_enterprise_prime_portal_v1.html">Enterprise Prime</a><a href="/trfmc_runtime_hook_layer_v1.html">Runtime Hook</a><a href="/trfmc_converged_rf_5g_noc_v1.html">Converged NOC</a><a href="/trfmc_5g_core_ran_identity_aka_engine_v1.html">5G Identity/AKA</a><a href="/trfmc_rf_tm_war_room_v4.html">RF/TM</a></nav></div></header>
<main>
<section class="hero"><div class="panel heroMain"><h2>Console azioni sicure</h2><p>Questa pagina non esegue comandi. Presenta comandi controllati, copiabili e leggibili per verificare portale 5173, readiness runtime, Open5GS, UERANSIM, HackRF, PCAP/IQ evidence e disco.</p></div><aside class="panel status"><div class="statusRow"><b>Execution policy</b><span class="warn">nessuna esecuzione automatica</span></div><div class="statusRow"><b>Default mode</b><span>dry-run / read-only</span></div><div class="statusRow"><b>Portal rule</b><span>127.0.0.1:5173</span></div><div class="statusRow"><b>Snapshot</b><span>/trfmc_runtime_readiness_latest.json</span></div></aside></section>
<section class="grid">
<div class="panel section"><h3>Portal / Quality</h3>
<div class="cmd"><b>Health portale 5173</b><p>Verifica middleware locale.</p><pre>curl -s --max-time 5 http://127.0.0.1:5173/api/health | python3 -m json.tool</pre><button onclick="copyCmd(this)">Copy</button></div>
<div class="cmd"><b>Light HTTP check</b><p>Controllo leggero senza report pesanti.</p><pre>cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2
for url in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:5173/trfmc_enterprise_prime_portal_v1.html \
  http://127.0.0.1:5173/trfmc_runtime_hook_layer_v1.html \
  http://127.0.0.1:5173/trfmc_safe_runtime_action_console_v1.html \
  http://127.0.0.1:5173/trfmc_converged_rf_5g_noc_v1.html \
  http://127.0.0.1:5173/trfmc_5g_core_ran_identity_aka_engine_v1.html \
  http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html \
  http://127.0.0.1:5173/api/health
do
  echo -n "$url -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "$url"
done</pre><button onclick="copyCmd(this)">Copy</button></div>
<div class="cmd"><b>Disk guard</b><p>Prima di generare altro.</p><pre>df -h .
du -h --max-depth=2 runtime 2>/dev/null | sort -h | tail -n 80</pre><button onclick="copyCmd(this)">Copy</button></div>
</div>
<div class="panel section"><h3>5G Core / RAN</h3>
<div class="cmd"><b>Readiness snapshot</b><p>Rigenera snapshot read-only.</p><pre>cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2
./trfmc_runtime_readiness_check_v1.sh
cat runtime/readiness/latest_runtime_readiness.json | python3 -m json.tool | sed -n '1,220p'</pre><button onclick="copyCmd(this)">Copy</button></div>
<div class="cmd"><b>Open5GS inspection</b><p>Solo ispezione.</p><pre>command -v open5gs-amfd open5gs-smfd open5gs-upfd open5gs-ausfd open5gs-udmd || true
ps aux | grep -E 'open5gs-(amf|smf|upf|ausf|udm|nrf|scp)' | grep -v grep || true
ls -lah /var/log/open5gs 2>/dev/null || true</pre><button onclick="copyCmd(this)">Copy</button></div>
<div class="cmd"><b>UERANSIM inspection</b><p>Solo verifica UE/gNB.</p><pre>command -v nr-gnb nr-ue nr-cli || true
ls -lah "$HOME/lab/UERANSIM" 2>/dev/null || true
ps aux | grep -E 'nr-(gnb|ue)' | grep -v grep || true</pre><button onclick="copyCmd(this)">Copy</button></div>
</div>
<div class="panel section"><h3>RF / HackRF / Evidence</h3>
<div class="cmd"><b>HackRF probe</b><p>Verifica device, non trasmette.</p><pre>command -v hackrf_info hackrf_transfer hackrf_sweep SoapySDRUtil || true
hackrf_info || true</pre><button onclick="copyCmd(this)">Copy</button></div>
<div class="cmd"><b>Evidence folders</b><p>Cartelle leggere PCAP/IQ/log/report.</p><pre>cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2
mkdir -p runtime/evidence/pcap runtime/evidence/iq runtime/evidence/logs runtime/evidence/reports
find runtime/evidence -maxdepth 2 -type d -print</pre><button onclick="copyCmd(this)">Copy</button></div>
</div>
</section>
</main>
<script>
async function health(){try{let r=await fetch("/api/health",{cache:"no-store"}),j=await r.json();document.getElementById("healthPill").textContent=j.ok?"Health: online":"Health: degraded"}catch(e){document.getElementById("healthPill").textContent="Health: unavailable"}}
function copyCmd(btn){let pre=btn.parentElement.querySelector("pre");navigator.clipboard.writeText(pre.textContent).then(()=>{let old=btn.textContent;btn.textContent="Copied";setTimeout(()=>btn.textContent=old,900)})}
health()
</script>
</body>
</html>
HTML

# Root verso Enterprise Prime, se non già fatto
cat > "$BASE/frontend/index.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Enterprise Prime Entrypoint</title>
<meta http-equiv="refresh" content="0; url=/trfmc_enterprise_prime_portal_v1.html">
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:linear-gradient(180deg,#01040c,#061327,#01040c);color:#eaf3ff;font-family:system-ui}.card{max-width:820px;border:1px solid rgba(105,190,255,.30);border-radius:22px;background:rgba(5,13,30,.93);padding:32px}a{color:#eaf3ff}</style>
</head>
<body><div class="card"><h1>TRFMC Enterprise Prime Portal</h1><p>Redirect al portale enterprise RF/Telco/Cyber su 127.0.0.1:5173.</p><a href="/trfmc_enterprise_prime_portal_v1.html">Apri Enterprise Prime Portal</a></div></body>
</html>
HTML

echo
echo "=== FILE SIZE CHECK ==="
ls -lh "$PRIME" "$SAFE" "$BASE/frontend/index.html"

echo
echo "=== HTTP CHECK ==="
for url in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:5173/trfmc_enterprise_prime_portal_v1.html \
  http://127.0.0.1:5173/trfmc_safe_runtime_action_console_v1.html
do
  echo -n "$url -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "$url"
done
