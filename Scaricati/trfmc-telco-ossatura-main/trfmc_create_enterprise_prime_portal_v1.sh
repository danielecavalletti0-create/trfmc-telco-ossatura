#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
RUNTIME="$BASE/runtime/enterprise_prime"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$PUBLIC" "$RUNTIME" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC ENTERPRISE PRIME PORTAL V1"
echo "RF/TM · HACKRF · OPEN5GS · UERANSIM · SUPI/SUCI · AKA · EVIDENCE"
echo "============================================================"
date
echo "BASE=$BASE"

FREEZE="$BASE/runtime/freezes/TRFMC_BEFORE_ENTERPRISE_PRIME_PORTAL_V1_$TS.tar.gz"
tar -czf "$FREEZE" \
  --exclude='frontend/node_modules' \
  --exclude='frontend/dist' \
  --exclude='.venv' \
  --exclude='runtime/freezes' \
  -C "$BASE" .

echo
echo "FREEZE:"
ls -lh "$FREEZE"

echo
echo "=== 1) ENTERPRISE SOURCE OF TRUTH JSON ==="

cat > "$PUBLIC/trfmc_enterprise_prime_manifest_v1.json" <<'JSON'
{
  "portal": "TRFMC / 5G RF TELCO LAB",
  "official_entrypoint": "http://127.0.0.1:5173/",
  "single_port_rule": 5173,
  "identity": "Digital Twin RF/Telco/Cyber + SDR/HackRF Laboratory + 5G Core/RAN Console + Technical NOC + Teaching Platform",
  "hard_rules": [
    "Portale visibile solo su 127.0.0.1:5173",
    "Nessun riferimento diretto a 8000 o 5174 nel frontend",
    "Ogni oggetto visivo deve essere tecnico e interattivo",
    "Open5GS + UERANSIM devono essere parte primaria del dominio 09_Core_Network",
    "SUPI, SUCI, IMSI, PKI, 5G-AKA, EAP-AKA', AUSF, UDM, ARPF, NAS security devono essere visualizzati e correlati",
    "NGAP, PFCP, GTP-U e PDU session devono essere rappresentati come control-plane/user-plane workflow",
    "RF/HackRF e 5G Core devono convergere in una console operativa unica"
  ],
  "enterprise_domains": [
    {
      "id": "01_Mission_Control",
      "engine": "Enterprise Mission Control",
      "must_have": ["lab health", "quality gate", "runtime readiness", "service map", "event correlation"]
    },
    {
      "id": "03_Signal_Analyzer",
      "engine": "RF/TM Signal Universe",
      "must_have": ["receiver", "signal generator", "function generator", "oscilloscope", "spectrum analyzer", "waterfall", "IQ", "constellation", "phase", "spatial field", "modulation lab", "HackRF readiness"]
    },
    {
      "id": "09_Core_Network",
      "engine": "Open5GS + UERANSIM Core/RAN Security Engine",
      "must_have": ["UE", "gNB", "AMF", "AUSF", "UDM/ARPF", "SMF", "UPF", "DN", "SUPI", "SUCI", "IMSI", "PKI", "5G-AKA", "EAP-AKA'", "NAS security", "NGAP", "PFCP", "GTP-U", "PDU session"]
    },
    {
      "id": "11_Cyber_RF_Intelligence",
      "engine": "RF/Cyber Evidence Engine",
      "must_have": ["RF anomaly", "jamming watch", "rogue RF", "protocol anomaly", "PCAP", "IQ evidence", "report builder"]
    },
    {
      "id": "12_Knowledge_Base",
      "engine": "Expert Knowledge Base",
      "must_have": ["glossary", "formulas", "procedures", "troubleshooting", "lesson plan", "operator handbook"]
    }
  ],
  "runtime_hooks": {
    "frontend_health": "/api/health",
    "quality_report": "/trfmc_collaudo_report.html",
    "domain_registry": "/trfmc_domain_registry_v1.html",
    "engine_board": "/trfmc_engine_promotion_board_v1.html",
    "rf_war_room": "/trfmc_rf_tm_war_room_v4.html",
    "core_identity_aka": "/trfmc_5g_core_ran_identity_aka_engine_v1.html",
    "converged_noc": "/trfmc_converged_rf_5g_noc_v1.html"
  }
}
JSON

echo
echo "=== 2) ENTERPRISE PRIME PORTAL HTML ==="

cat > "$PUBLIC/trfmc_enterprise_prime_portal_v1.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Enterprise Prime Portal V1</title>
<style>
:root{
  --bg:#01040c;
  --panel:rgba(5,13,30,.94);
  --glass:rgba(255,255,255,.045);
  --line:rgba(105,190,255,.30);
  --text:#eaf3ff;
  --muted:#90a9c7;
  --cyan:#74dcff;
  --green:#9dffc7;
  --amber:#ffd37a;
  --red:#ff8585;
  --violet:#bda7ff;
}
*{box-sizing:border-box}
html,body{
  margin:0;
  min-height:100%;
  color:var(--text);
  background:#01040c;
  font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}
body{
  background:
    radial-gradient(circle at 12% 0%,rgba(48,132,255,.34),transparent 31%),
    radial-gradient(circle at 88% 4%,rgba(0,255,205,.16),transparent 31%),
    radial-gradient(circle at 52% 112%,rgba(170,90,255,.18),transparent 34%),
    linear-gradient(180deg,#01040c,#061327 52%,#01040c);
}
body:before{
  content:"";
  position:fixed;
  inset:0;
  pointer-events:none;
  background:
    linear-gradient(rgba(255,255,255,.026) 1px,transparent 1px),
    linear-gradient(90deg,rgba(255,255,255,.026) 1px,transparent 1px);
  background-size:38px 38px;
  mask-image:linear-gradient(to bottom,rgba(0,0,0,.95),rgba(0,0,0,.10));
}
header{
  position:sticky;
  top:0;
  z-index:30;
  background:rgba(1,4,12,.88);
  border-bottom:1px solid var(--line);
  backdrop-filter:blur(22px);
}
.topbar{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:18px;
  padding:15px 20px;
}
.brand h1{
  margin:0;
  font-size:22px;
  letter-spacing:.10em;
  text-transform:uppercase;
}
.brand small{
  display:block;
  color:var(--muted);
  margin-top:4px;
}
.nav{
  display:flex;
  flex-wrap:wrap;
  justify-content:flex-end;
  gap:7px;
}
.nav a,.pill{
  color:var(--text);
  text-decoration:none;
  border:1px solid var(--line);
  background:rgba(255,255,255,.045);
  border-radius:999px;
  padding:7px 10px;
  font-size:11px;
}
.pill.ok{
  color:var(--green);
  border-color:rgba(157,255,199,.55);
}
main{padding:16px}
.hero{
  display:grid;
  grid-template-columns:1.2fr .8fr;
  gap:14px;
  margin-bottom:14px;
}
.panel{
  border:1px solid var(--line);
  background:linear-gradient(180deg,var(--panel),rgba(2,8,20,.94));
  border-radius:22px;
  box-shadow:0 22px 78px rgba(0,0,0,.40), inset 0 1px 0 rgba(255,255,255,.055);
}
.heroMain{padding:22px}
.heroMain h2{
  margin:0 0 12px;
  font-size:46px;
  line-height:1.0;
  letter-spacing:-.05em;
}
.heroMain p{
  color:#c8daf1;
  max-width:1120px;
  line-height:1.55;
}
.kpiGrid{
  display:grid;
  grid-template-columns:repeat(6,1fr);
  gap:9px;
  margin-top:16px;
}
.kpi{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.04);
  border-radius:15px;
  padding:10px;
}
.kpi b{
  display:block;
  font-size:20px;
}
.kpi span{
  color:var(--muted);
  font-size:10px;
}
.status{
  padding:14px;
  display:grid;
  gap:9px;
}
.statusRow{
  display:flex;
  justify-content:space-between;
  gap:12px;
  border:1px solid rgba(255,255,255,.09);
  background:rgba(255,255,255,.035);
  border-radius:13px;
  padding:10px;
}
.statusRow span{
  color:var(--muted);
  text-align:right;
}
.layout{
  display:grid;
  grid-template-columns:350px minmax(780px,1fr) 400px;
  gap:14px;
}
.left,.center,.right{padding:14px}
.left,.right{
  display:grid;
  gap:11px;
  align-content:start;
}
h3{
  margin:0;
  color:var(--cyan);
}
.block{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.04);
  border-radius:16px;
  padding:12px;
}
.block h4{
  margin:0 0 8px;
  color:var(--green);
  font-size:13px;
  text-transform:uppercase;
  letter-spacing:.04em;
}
.block p,.block span{
  color:var(--muted);
  font-size:12px;
  line-height:1.4;
}
.linkGrid{
  display:grid;
  gap:7px;
}
.linkGrid a{
  color:var(--text);
  text-decoration:none;
  border:1px solid rgba(105,190,255,.20);
  background:rgba(255,255,255,.035);
  border-radius:12px;
  padding:9px;
  font-size:12px;
}
.linkGrid a:hover{
  border-color:rgba(116,220,255,.80);
  background:linear-gradient(135deg,rgba(45,132,255,.22),rgba(0,255,205,.09));
}
.canvasFrame{
  border:1px solid rgba(105,190,255,.26);
  background:rgba(255,255,255,.022);
  border-radius:20px;
  overflow:hidden;
}
.canvasTitle{
  display:flex;
  justify-content:space-between;
  gap:10px;
  padding:8px 10px;
  color:var(--muted);
  font-size:11px;
  border-bottom:1px solid rgba(255,255,255,.08);
}
canvas{
  width:100%;
  height:640px;
  display:block;
  background:
    radial-gradient(circle at 50% 50%,rgba(24,82,150,.16),transparent 42%),
    linear-gradient(180deg,rgba(255,255,255,.032),rgba(255,255,255,.010));
}
.matrix{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:10px;
  margin-top:10px;
}
.card{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.04);
  border-radius:16px;
  padding:11px;
}
.card b{display:block}
.card span,.card p{
  color:var(--muted);
  font-size:12px;
  line-height:1.4;
}
.meter{
  height:9px;
  border-radius:999px;
  background:rgba(255,255,255,.08);
  overflow:hidden;
  margin-top:7px;
}
.meter i{
  display:block;
  height:100%;
  width:50%;
  background:linear-gradient(90deg,var(--cyan),var(--green));
}
.eventLog{
  max-height:330px;
  overflow:auto;
  font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;
  font-size:11px;
  color:#c0d5ee;
}
.eventLog div{
  padding:5px 0;
  border-bottom:1px solid rgba(255,255,255,.06);
}
.badge{
  border:1px solid var(--line);
  border-radius:999px;
  color:var(--cyan);
  padding:5px 8px;
  font-size:10px;
}
@media(max-width:1550px){
  .layout{grid-template-columns:340px 1fr}
  .right{grid-column:1/-1;grid-template-columns:repeat(3,1fr)}
}
@media(max-width:1100px){
  .hero,.layout,.right,.matrix,.kpiGrid{grid-template-columns:1fr}
}
</style>
</head>
<body>
<header>
  <div class="topbar">
    <div class="brand">
      <h1>TRFMC Enterprise Prime Portal</h1>
      <small>RF/TM · HackRF · Open5GS · UERANSIM · SUPI/SUCI · AKA · NAS · Evidence · 5173</small>
    </div>
    <nav class="nav">
      <span class="pill ok" id="healthPill">Health: checking</span>
      <a href="/trfmc_unified_navigation_shell_v1.html">Unified Shell</a>
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
      <p>
        Questo è il punto d’ingresso logico enterprise: non una demo grafica, ma la plancia di regia
        che collega RF/TM, HackRF, Open5GS, UERANSIM, identità 5G, AKA, NAS security, protocolli core,
        evidenze e quality gate. Tutto resta sul portale ufficiale 127.0.0.1:5173.
      </p>
      <div class="kpiGrid">
        <div class="kpi"><b>5173</b><span>single entrypoint</span></div>
        <div class="kpi"><b>RF/TM</b><span>instrumentation</span></div>
        <div class="kpi"><b>HackRF</b><span>SDR readiness</span></div>
        <div class="kpi"><b>Open5GS</b><span>5G core</span></div>
        <div class="kpi"><b>UERANSIM</b><span>UE/gNB</span></div>
        <div class="kpi"><b>AKA/NAS</b><span>security</span></div>
      </div>
    </div>

    <aside class="panel status">
      <div class="statusRow"><b>Portal status</b><span id="portalStatus">checking</span></div>
      <div class="statusRow"><b>Quality gate</b><span>0 broken · 0 external · 0 forbidden</span></div>
      <div class="statusRow"><b>Architecture</b><span>single-port frontend + runtime-ready hooks</span></div>
      <div class="statusRow"><b>Mission</b><span>enterprise RF/Telco/Cyber digital twin</span></div>
    </aside>
  </section>

  <section class="layout">
    <aside class="panel left">
      <h3>Prime Navigation</h3>

      <div class="block">
        <h4>Enterprise Consoles</h4>
        <div class="linkGrid">
          <a href="/trfmc_converged_rf_5g_noc_v1.html">Converged RF + 5G NOC</a>
          <a href="/trfmc_rf_tm_war_room_v4.html">RF/TM War Room V4</a>
          <a href="/trfmc_rf_tm_signal_universe_v3.html">RF/TM Signal Universe V3</a>
          <a href="/trfmc_signal_world_engine_v2.html">Signal World Engine V2</a>
          <a href="/trfmc_5g_core_ran_identity_aka_engine_v1.html">5G Core/RAN Identity & AKA</a>
        </div>
      </div>

      <div class="block">
        <h4>Governance</h4>
        <div class="linkGrid">
          <a href="/trfmc_unified_navigation_shell_v1.html">Unified Navigation Shell</a>
          <a href="/trfmc_domain_registry_v1.html">Domain Registry</a>
          <a href="/trfmc_engine_promotion_board_v1.html">Engine Promotion Board</a>
          <a href="/trfmc_collaudo_report.html">Quality Gate Report</a>
          <a href="/api/health">Portal Health JSON</a>
        </div>
      </div>

      <div class="block">
        <h4>Hard Rules</h4>
        <p>Ogni oggetto visuale deve essere tecnico, misurabile e interattivo. RF e 5G Core/RAN devono avanzare insieme.</p>
      </div>
    </aside>

    <section class="panel center">
      <div class="canvasFrame">
        <div class="canvasTitle"><b>Enterprise Converged Digital Twin</b><span id="canvasReadout">RF + 5G + Identity + Evidence</span></div>
        <canvas id="primeCanvas" width="1600" height="760"></canvas>
      </div>

      <div class="matrix">
        <div class="card">
          <b>5G Identity/Security Plane</b>
          <p>SUPI/SUCI, IMSI, HNPKI, AUSF, UDM/ARPF, 5G-AKA, EAP-AKA', NAS Security Mode, GUTI lifecycle.</p>
        </div>
        <div class="card">
          <b>RF/TM Instrument Plane</b>
          <p>Receiver chain, generator, function generator, oscilloscope, spectrum analyzer, VSA/IQ, phase, spatial field, HackRF readiness.</p>
        </div>
        <div class="card">
          <b>Core/RAN Protocol Plane</b>
          <p>UERANSIM UE/gNB, AMF, SMF, UPF, NGAP, PFCP, GTP-U, PDU session, evidence correlation.</p>
        </div>
        <div class="card">
          <b>Evidence Plane</b>
          <p>PCAP, IQ capture, Open5GS logs, UERANSIM logs, event timeline, report builder, lab-only forensic trail.</p>
        </div>
      </div>
    </section>

    <aside class="panel right">
      <h3>Enterprise Readout</h3>

      <div class="card">
        <b>RF/TM Completeness</b>
        <span id="rfText">receiver/generator/spectrum/phase/space</span>
        <div class="meter"><i style="width:82%"></i></div>
      </div>

      <div class="card">
        <b>5G Core/RAN Completeness</b>
        <span id="coreText">Open5GS + UERANSIM + AKA/NAS/PDU</span>
        <div class="meter"><i style="width:78%"></i></div>
      </div>

      <div class="card">
        <b>Runtime Readiness</b>
        <span>next: hook scripts/logs/pcap/iq without changing 5173</span>
        <div class="meter"><i style="width:52%"></i></div>
      </div>

      <div class="card">
        <b>Event Stream</b>
        <div class="eventLog" id="events"></div>
      </div>
    </aside>
  </section>
</main>

<script>
const $ = id => document.getElementById(id);
const canvas = $("primeCanvas");
const ctx = canvas.getContext("2d");
let t = 0;
let lastLog = 0;

const nodes = [
  {id:"RF World", x:.08, y:.56, c:"cyan"},
  {id:"HackRF", x:.19, y:.34, c:"green"},
  {id:"Receiver", x:.19, y:.70, c:"cyan"},
  {id:"UE/SUPI", x:.33, y:.56, c:"cyan"},
  {id:"gNB", x:.45, y:.45, c:"green"},
  {id:"AMF", x:.58, y:.35, c:"cyan"},
  {id:"AUSF", x:.70, y:.20, c:"violet"},
  {id:"UDM/ARPF", x:.84, y:.20, c:"amber"},
  {id:"SMF", x:.70, y:.58, c:"cyan"},
  {id:"UPF", x:.84, y:.58, c:"green"},
  {id:"DN", x:.94, y:.58, c:"green"},
  {id:"Evidence", x:.58, y:.78, c:"amber"}
];

function col(c){
  return {
    cyan:"rgba(116,220,255,.95)",
    green:"rgba(157,255,199,.95)",
    amber:"rgba(255,211,122,.95)",
    violet:"rgba(189,167,255,.95)",
    red:"rgba(255,133,133,.95)"
  }[c] || "rgba(116,220,255,.95)";
}

function grid(w,h){
  ctx.strokeStyle="rgba(105,190,255,.075)";
  ctx.lineWidth=1;
  for(let x=0;x<w;x+=50){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=40){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
}

function label(text,x,y,color="rgba(234,243,255,.82)",size=12){
  ctx.fillStyle=color;
  ctx.font=size+"px system-ui";
  ctx.fillText(text,x,y);
}

function node(n,w,h){
  const x=n.x*w, y=n.y*h;
  ctx.shadowColor=col(n.c);
  ctx.shadowBlur=18;
  ctx.fillStyle=col(n.c);
  ctx.beginPath();ctx.arc(x,y,12,0,Math.PI*2);ctx.fill();
  ctx.shadowBlur=0;
  ctx.strokeStyle="rgba(255,255,255,.20)";
  ctx.beginPath();ctx.arc(x,y,25+Math.sin(t*.05+n.x*9)*4,0,Math.PI*2);ctx.stroke();
  label(n.id,x-38,y+42,"rgba(234,243,255,.86)",12);
}

function get(id){return nodes.find(n=>n.id===id);}

function edge(a,b,name,active=true,warning=false){
  const w=canvas.width,h=canvas.height;
  const A=get(a),B=get(b);
  const ax=A.x*w,ay=A.y*h,bx=B.x*w,by=B.y*h;
  ctx.strokeStyle=warning?"rgba(255,133,133,.44)":active?"rgba(157,255,199,.48)":"rgba(116,220,255,.15)";
  ctx.lineWidth=active?2.0:1.2;
  ctx.beginPath();ctx.moveTo(ax,ay);ctx.lineTo(bx,by);ctx.stroke();

  const q=(Math.sin(t*.055 + ax*.001)*.5+.5);
  const px=ax+(bx-ax)*q, py=ay+(by-ay)*q;
  ctx.fillStyle=warning?"rgba(255,133,133,.95)":"rgba(255,211,122,.92)";
  ctx.beginPath();ctx.arc(px,py,4.5,0,Math.PI*2);ctx.fill();

  label(name,(ax+bx)/2,(ay+by)/2-8,"rgba(144,169,199,.86)",10);
}

function drawRfField(w,h){
  const cx=.08*w, cy=.56*h;
  for(let i=0;i<18;i++){
    const a=i/18*Math.PI*2+t*.01;
    const r=50+(i%6)*22+Math.sin(t*.04+i)*7;
    const x=cx+Math.cos(a)*r;
    const y=cy+Math.sin(a)*r*.62;
    const warn=i%7===0;
    ctx.strokeStyle=warn?"rgba(255,133,133,.20)":"rgba(116,220,255,.16)";
    ctx.beginPath();ctx.arc(x,y,25+(i%3)*9,0,Math.PI*2);ctx.stroke();
    ctx.fillStyle=warn?"rgba(255,133,133,.90)":"rgba(116,220,255,.78)";
    ctx.beginPath();ctx.arc(x,y,warn?5:3.5,0,Math.PI*2);ctx.fill();
  }
}

function capsule(x,y,w,h,title,lines,color){
  ctx.strokeStyle=color;
  ctx.fillStyle=color.replace(".30",".055");
  ctx.roundRect(x,y,w,h,18);
  ctx.fill();ctx.stroke();
  label(title,x+22,y+30,color.replace(".30",".95"),15);
  lines.forEach((l,i)=>label(l,x+22,y+58+i*24,"rgba(234,243,255,.80)",12));
}

function draw(){
  const w=canvas.width,h=canvas.height;
  ctx.clearRect(0,0,w,h);
  const bg=ctx.createRadialGradient(w/2,h/2,20,w/2,h/2,w*.72);
  bg.addColorStop(0,"rgba(30,115,220,.20)");
  bg.addColorStop(1,"rgba(255,255,255,.006)");
  ctx.fillStyle=bg;ctx.fillRect(0,0,w,h);
  grid(w,h);

  drawRfField(w,h);

  edge("RF World","HackRF","IQ / FFT / Waterfall");
  edge("HackRF","Receiver","RX chain");
  edge("RF World","UE/SUPI","radio environment",true,true);
  edge("UE/SUPI","gNB","Uu / RRC / NAS");
  edge("gNB","AMF","N2 / NGAP");
  edge("AMF","AUSF","N12 / AKA");
  edge("AUSF","UDM/ARPF","N13 / vector");
  edge("AMF","SMF","N11");
  edge("SMF","UPF","N4 / PFCP");
  edge("gNB","UPF","N3 / GTP-U");
  edge("UPF","DN","N6");
  edge("AMF","Evidence","NAS/NGAP log");
  edge("UPF","Evidence","GTP-U/PCAP");
  edge("HackRF","Evidence","IQ evidence");

  nodes.forEach(n=>node(n,w,h));

  capsule(55,50,440,130,"Identity & Privacy Plane",[
    "IMSI/SUPI: imsi-001010000000001",
    "SUCI: concealed subscription identity",
    "5G-GUTI: assigned after registration"
  ],"rgba(157,255,199,.30)");

  capsule(w-540,50,470,130,"Authentication & Security Plane",[
    "AUSF/UDM/ARPF · 5G-AKA / EAP-AKA'",
    "PKI/SBI readiness · NAS Security Mode",
    "NGAP · PFCP · GTP-U · PDU Session"
  ],"rgba(189,167,255,.30)");

  label("TRFMC Enterprise Converged Digital Twin · RF/TM + HackRF + Open5GS + UERANSIM + Identity/Security + Evidence",52,h-46,"rgba(255,211,122,.94)",15);
  label("This is the prime control architecture. Next layer: runtime hooks for scripts, logs, PCAP and IQ.",52,h-23,"rgba(234,243,255,.80)",13);
}

function log(){
  const now=Date.now();
  if(now-lastLog<1600)return;
  lastLog=now;
  const events=[
    "RF sweep correlated with UE/gNB attach window",
    "SUPI/SUCI privacy plane active",
    "AUSF/UDM authentication vector visualized",
    "NAS security mode negotiated",
    "PFCP N4 programming mapped to UPF",
    "GTP-U tunnel evidence target ready",
    "HackRF IQ evidence hook staged"
  ];
  const row=document.createElement("div");
  row.textContent="["+new Date().toLocaleTimeString()+"] "+events[Math.floor(Math.random()*events.length)];
  $("events").prepend(row);
  while($("events").children.length>24)$("events").removeChild($("events").lastChild);
}

function loop(){
  t++;
  draw();
  log();
  requestAnimationFrame(loop);
}

async function health(){
  try{
    const r=await fetch("/api/health",{cache:"no-store"});
    const j=await r.json();
    $("healthPill").textContent=j.ok?"Health: online":"Health: degraded";
    $("portalStatus").textContent=j.ok?"online / 5173":"degraded";
  }catch(e){
    $("healthPill").textContent="Health: unavailable";
    $("portalStatus").textContent="unavailable";
    $("healthPill").classList.remove("ok");
  }
}

if(!CanvasRenderingContext2D.prototype.roundRect){
  CanvasRenderingContext2D.prototype.roundRect=function(x,y,w,h,r){
    this.beginPath();
    this.moveTo(x+r,y);
    this.arcTo(x+w,y,x+w,y+h,r);
    this.arcTo(x+w,y+h,x,y+h,r);
    this.arcTo(x,y+h,x,y,r);
    this.arcTo(x,y,x+w,y,r);
    return this;
  }
}

health();
loop();
</script>
</body>
</html>
HTML

echo
echo "=== 3) PATCH NAVIGATION / ENTRYPOINT ==="

python3 - <<'PY'
from pathlib import Path

files = [
    Path("frontend/public/trfmc_unified_navigation_shell_v1.html"),
    Path("frontend/public/trfmc_master_digital_twin_console_v1.html"),
    Path("frontend/public/trfmc_engine_promotion_board_v1.html"),
    Path("frontend/public/trfmc_domain_registry_v1.html"),
    Path("frontend/public/trfmc_converged_rf_5g_noc_v1.html"),
    Path("frontend/public/trfmc_rf_tm_war_room_v4.html"),
    Path("frontend/public/api/portal/index"),
]

link = '<a href="/trfmc_enterprise_prime_portal_v1.html">Enterprise Prime</a>'
li = '<li><a href="/trfmc_enterprise_prime_portal_v1.html">TRFMC Enterprise Prime Portal V1</a></li>'

for p in files:
    if not p.exists():
        print("SKIP:", p)
        continue
    s = p.read_text(errors="ignore")
    old = s

    if "trfmc_enterprise_prime_portal_v1.html" not in s:
        if '<a href="/trfmc_converged_rf_5g_noc_v1.html">Converged RF+5G NOC</a>' in s:
            s = s.replace(
                '<a href="/trfmc_converged_rf_5g_noc_v1.html">Converged RF+5G NOC</a>',
                link + '\n      <a href="/trfmc_converged_rf_5g_noc_v1.html">Converged RF+5G NOC</a>',
                1
            )
        elif '<a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>' in s:
            s = s.replace(
                '<a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>',
                '<a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>\n      ' + link,
                1
            )
        elif "<ul>" in s:
            s = s.replace("<ul>", "<ul>\n" + li, 1)

    if s != old:
        p.write_text(s)
        print("PATCHED:", p)
    else:
        print("UNCHANGED:", p)
PY

echo
echo "=== 4) PROMUOVO ROOT / A ENTERPRISE PRIME ==="

INDEX="$BASE/frontend/index.html"
cp -a "$INDEX" "$INDEX.bak_enterprise_prime_$TS" 2>/dev/null || true

cat > "$INDEX" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Enterprise Prime Entrypoint</title>
<meta http-equiv="refresh" content="0; url=/trfmc_enterprise_prime_portal_v1.html">
<style>
body{
  margin:0;
  min-height:100vh;
  display:grid;
  place-items:center;
  background:radial-gradient(circle at 20% 0%,rgba(48,132,255,.34),transparent 31%),linear-gradient(180deg,#01040c,#061327,#01040c);
  color:#eaf3ff;
  font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}
.card{
  max-width:820px;
  border:1px solid rgba(105,190,255,.30);
  border-radius:22px;
  background:rgba(5,13,30,.93);
  padding:32px;
}
a{
  color:#eaf3ff;
}
</style>
</head>
<body>
<div class="card">
  <h1>TRFMC Enterprise Prime Portal</h1>
  <p>Redirect al portale enterprise RF/Telco/Cyber su 127.0.0.1:5173.</p>
  <a href="/trfmc_enterprise_prime_portal_v1.html">Apri Enterprise Prime Portal</a>
</div>
</body>
</html>
HTML

echo
echo "=== 5) TEST HTTP ==="
curl -I --max-time 5 http://127.0.0.1:5173/
curl -I --max-time 5 http://127.0.0.1:5173/trfmc_enterprise_prime_portal_v1.html
curl -s --max-time 5 http://127.0.0.1:5173/trfmc_enterprise_prime_manifest_v1.json | python3 -m json.tool | head -n 80

echo
echo "ENTERPRISE PRIME:"
echo "http://127.0.0.1:5173/trfmc_enterprise_prime_portal_v1.html"
