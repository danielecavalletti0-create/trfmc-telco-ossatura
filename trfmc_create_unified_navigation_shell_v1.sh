#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC UNIFIED NAVIGATION SHELL V1 - SOLO 5173"
echo "============================================================"
date
echo "BASE=$BASE"
echo "PUBLIC=$PUBLIC"

mkdir -p "$PUBLIC" "$BASE/runtime/shell"

SHELL="$PUBLIC/trfmc_unified_navigation_shell_v1.html"

if [ -f "$SHELL" ]; then
  cp -a "$SHELL" "$SHELL.bak_$TS"
fi

cat > "$SHELL" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Unified Navigation Shell V1</title>
<style>
:root{
  --bg:#030711;
  --panel:rgba(8,18,36,.88);
  --panel2:rgba(12,28,55,.72);
  --line:rgba(125,190,255,.24);
  --line2:rgba(157,255,199,.22);
  --text:#eaf3ff;
  --muted:#94a9c5;
  --cyan:#86d7ff;
  --green:#9dffc7;
  --amber:#ffd37a;
  --red:#ff8d8d;
  --violet:#bda7ff;
}
*{box-sizing:border-box}
body{
  margin:0;
  background:
    radial-gradient(circle at 12% 0%,rgba(50,130,255,.22),transparent 30%),
    radial-gradient(circle at 88% 8%,rgba(0,255,190,.10),transparent 28%),
    radial-gradient(circle at 50% 100%,rgba(145,95,255,.12),transparent 30%),
    linear-gradient(180deg,#030711,#07111f 50%,#030711);
  color:var(--text);
  font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}
body:before{
  content:"";
  position:fixed;
  inset:0;
  pointer-events:none;
  background:
    linear-gradient(rgba(255,255,255,.025) 1px,transparent 1px),
    linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px);
  background-size:42px 42px;
  mask-image:linear-gradient(to bottom,rgba(0,0,0,.8),rgba(0,0,0,.18));
}
header{
  position:sticky;
  top:0;
  z-index:10;
  background:rgba(3,7,17,.82);
  backdrop-filter:blur(18px);
  border-bottom:1px solid var(--line);
}
.topbar{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:18px;
  padding:18px 24px;
}
.brand h1{
  margin:0;
  font-size:22px;
  text-transform:uppercase;
  letter-spacing:.08em;
}
.brand small{
  color:var(--muted);
}
.quick{
  display:flex;
  gap:8px;
  flex-wrap:wrap;
  justify-content:flex-end;
}
.quick a,.pill{
  color:var(--text);
  text-decoration:none;
  border:1px solid var(--line);
  background:rgba(255,255,255,.045);
  padding:8px 11px;
  border-radius:999px;
  font-size:12px;
}
.pill.ok{
  color:var(--green);
  border-color:rgba(157,255,199,.55);
}
.domainbar{
  display:flex;
  gap:8px;
  overflow:auto;
  padding:0 24px 14px;
}
.domainbar button{
  white-space:nowrap;
  border:1px solid rgba(125,190,255,.20);
  color:var(--text);
  background:rgba(255,255,255,.035);
  border-radius:999px;
  padding:8px 11px;
  cursor:pointer;
}
.domainbar button.active,
.domainbar button:hover{
  border-color:rgba(134,215,255,.75);
  background:linear-gradient(135deg,rgba(50,130,255,.18),rgba(0,255,190,.08));
}
main{
  position:relative;
  padding:24px;
}
.hero{
  display:grid;
  grid-template-columns:1.1fr .9fr;
  gap:18px;
  margin-bottom:18px;
}
.panel{
  border:1px solid var(--line);
  background:linear-gradient(180deg,var(--panel),rgba(5,12,25,.88));
  border-radius:22px;
  box-shadow:0 18px 60px rgba(0,0,0,.30),inset 0 1px 0 rgba(255,255,255,.05);
}
.heroMain{
  padding:24px;
}
.heroMain h2{
  margin:0 0 10px;
  font-size:40px;
  line-height:1.02;
  letter-spacing:-.04em;
}
.heroMain p{
  color:#c8d9ef;
  line-height:1.55;
  max-width:900px;
}
.kpis{
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:12px;
  margin-top:18px;
}
.kpi{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.045);
  border-radius:16px;
  padding:14px;
}
.kpi b{
  display:block;
  font-size:25px;
}
.kpi span{
  color:var(--muted);
  font-size:12px;
}
.status{
  padding:18px;
  display:grid;
  gap:10px;
}
.statusRow{
  display:flex;
  justify-content:space-between;
  gap:12px;
  border:1px solid rgba(255,255,255,.09);
  background:rgba(255,255,255,.04);
  border-radius:14px;
  padding:12px;
}
.statusRow span{
  color:var(--muted);
}
.layout{
  display:grid;
  grid-template-columns:360px 1fr;
  gap:18px;
}
.sidebar{
  padding:14px;
  max-height:78vh;
  overflow:auto;
}
.domainCard{
  border:1px solid rgba(125,190,255,.18);
  background:rgba(255,255,255,.04);
  border-radius:16px;
  padding:12px;
  margin-bottom:9px;
  cursor:pointer;
}
.domainCard.active,
.domainCard:hover{
  border-color:rgba(134,215,255,.72);
  background:linear-gradient(135deg,rgba(50,130,255,.18),rgba(0,255,190,.08));
}
.domainCard b{
  display:block;
}
.domainCard small{
  color:var(--muted);
  display:block;
  margin-top:4px;
  line-height:1.35;
}
.content{
  padding:18px;
}
.domainTitle{
  display:flex;
  align-items:flex-start;
  justify-content:space-between;
  gap:18px;
  margin-bottom:14px;
}
.domainTitle h3{
  margin:0;
  font-size:28px;
}
.domainTitle p{
  margin:6px 0 0;
  color:var(--muted);
  line-height:1.45;
}
.engineBadge{
  border:1px solid rgba(157,255,199,.40);
  color:var(--green);
  border-radius:999px;
  padding:8px 11px;
  font-size:12px;
}
.grid{
  display:grid;
  grid-template-columns:repeat(2,minmax(260px,1fr));
  gap:12px;
}
.page{
  border:1px solid rgba(255,255,255,.09);
  background:rgba(255,255,255,.04);
  border-radius:16px;
  padding:13px;
}
.pageTop{
  display:flex;
  align-items:flex-start;
  justify-content:space-between;
  gap:12px;
}
.page a{
  color:var(--text);
  text-decoration:none;
  font-weight:700;
}
.page a:hover{
  color:var(--cyan);
}
.badge{
  border:1px solid rgba(255,255,255,.18);
  border-radius:999px;
  padding:4px 7px;
  font-size:11px;
}
.PROMOTE{color:var(--green);border-color:rgba(157,255,199,.5)}
.ENGINE{color:var(--cyan);border-color:rgba(134,215,255,.5)}
.FUSE{color:var(--amber);border-color:rgba(255,211,122,.5)}
.REWRITE{color:var(--violet);border-color:rgba(189,167,255,.5)}
.ARCHIVE{color:var(--red);border-color:rgba(255,141,141,.5)}
.page p{
  margin:8px 0 0;
  color:var(--muted);
  font-size:13px;
  line-height:1.42;
}
.empty{
  color:var(--muted);
  border:1px dashed rgba(255,255,255,.18);
  border-radius:16px;
  padding:18px;
}
.footerNote{
  margin-top:18px;
  color:var(--muted);
  font-size:12px;
}
@media(max-width:1100px){
  .hero,.layout{grid-template-columns:1fr}
  .kpis{grid-template-columns:repeat(2,1fr)}
}
@media(max-width:720px){
  .topbar{align-items:flex-start;flex-direction:column}
  .kpis,.grid{grid-template-columns:1fr}
}
</style>
</head>
<body>
<header>
  <div class="topbar">
    <div class="brand">
      <h1>TRFMC Unified Navigation Shell</h1>
      <small>Single-port RF/Telco/Cyber Laboratory · 127.0.0.1:5173</small>
    </div>
    <div class="quick">
      <span class="pill ok" id="healthPill">Health: checking</span>
      <a href="/trfmc_master_digital_twin_console_v1.html">Master Console</a>
      <a href="/trfmc_domain_registry_v1.html">Domain Registry</a>
      <a href="/trfmc_collaudo_report.html">Collaudo</a>
      <a href="/api/health">API Health</a>
    </div>
  </div>
  <div class="domainbar" id="domainbar"></div>
</header>

<main>
  <section class="hero">
    <div class="panel heroMain">
      <h2>Shell unica per il portale RF/Telco/Cyber</h2>
      <p>
        Questa shell è il punto di convergenza operativo: organizza le pagine esistenti
        nei 12 domini ufficiali, collega Master Console, Domain Registry, Collaudo e
        prepara la trasformazione progressiva da pagine statiche a engine interattivi.
      </p>
      <div class="kpis">
        <div class="kpi"><b id="kpiPages">–</b><span>pagine censite</span></div>
        <div class="kpi"><b id="kpiDomains">12</b><span>domini ufficiali</span></div>
        <div class="kpi"><b id="kpiPort">5173</b><span>porta unica</span></div>
        <div class="kpi"><b id="kpiMode">NO CDN</b><span>asset locali</span></div>
      </div>
    </div>

    <div class="panel status">
      <div class="statusRow"><b>Portal Entry</b><span>http://127.0.0.1:5173</span></div>
      <div class="statusRow"><b>Architettura</b><span>single-port portal</span></div>
      <div class="statusRow"><b>Regola UI</b><span>oggetti tecnici interattivi</span></div>
      <div class="statusRow"><b>Prossima fase</b><span>Unified theme + engine promotion</span></div>
    </div>
  </section>

  <section class="layout">
    <aside class="panel sidebar" id="sidebar"></aside>

    <section class="panel content">
      <div class="domainTitle">
        <div>
          <h3 id="domainName">Dominio</h3>
          <p id="domainDesc">Seleziona un dominio.</p>
        </div>
        <span class="engineBadge" id="engineTarget">Engine target</span>
      </div>

      <div class="grid" id="pagesGrid"></div>
      <div class="footerNote">
        Regola operativa: PROMOTE, ENGINE, FUSE e REWRITE non sono estetica. Sono priorità di consolidamento tecnico.
      </div>
    </section>
  </section>
</main>

<script>
const fallbackDomains = [
  ["01_Mission_Control","Mission Control","Mission Control / NOC / Runtime Health Engine"],
  ["02_RF_Physics","RF Physics","RF Physics Field Engine"],
  ["03_Signal_Analyzer","Signal Analyzer","RF Spectrum Lab / VSA / IQ Analyzer"],
  ["04_RF_Microwave_Engineering","RF Microwave Engineering","Smith Chart & Matching Engine"],
  ["05_Antenna_System","Antenna System","Antenna System Explorer / RRU RET CPRI Simulator"],
  ["06_Microwave_Link","Microwave Link","Microwave Link Budget Engine"],
  ["07_Fiber_Optic","Fiber Optic","Fiber / OTDR Trace Engine"],
  ["08_Private_Networks","Private Networks","Private Network Scenario Engine"],
  ["09_Core_Network","Core Network","5G Core / RAN Call-Flow Engine"],
  ["10_Data_Center_Infrastructure","Data Center Infrastructure","Infrastructure Digital Twin"],
  ["11_Cyber_RF_Intelligence","Cyber RF Intelligence","Cyber RF Intelligence Engine"],
  ["12_Knowledge_Base","Knowledge Base","Knowledge & Procedure Engine"]
].map(d=>({id:d[0],title:d[1],engine_target:d[2]}));

let registry = null;
let activeDomain = "01_Mission_Control";

const domainbar = document.getElementById("domainbar");
const sidebar = document.getElementById("sidebar");
const pagesGrid = document.getElementById("pagesGrid");
const domainName = document.getElementById("domainName");
const domainDesc = document.getElementById("domainDesc");
const engineTarget = document.getElementById("engineTarget");

async function loadHealth(){
  try{
    const res = await fetch("/api/health", {cache:"no-store"});
    const data = await res.json();
    document.getElementById("healthPill").textContent = data.ok ? "Health: online" : "Health: degraded";
    document.getElementById("healthPill").classList.toggle("ok", !!data.ok);
  }catch(e){
    document.getElementById("healthPill").textContent = "Health: unavailable";
    document.getElementById("healthPill").classList.remove("ok");
  }
}

async function loadRegistry(){
  try{
    const res = await fetch("/trfmc_domain_registry_v1.json", {cache:"no-store"});
    registry = await res.json();
  }catch(e){
    registry = {
      domains: fallbackDomains,
      pages: [],
      summary: {total_pages:0}
    };
  }

  document.getElementById("kpiPages").textContent = registry.summary?.total_pages ?? registry.pages?.length ?? 0;
  renderDomains();
  selectDomain(activeDomain);
}

function domainPages(id){
  return (registry.pages || []).filter(p=>p.domain_id === id);
}

function renderDomains(){
  const domains = registry.domains || fallbackDomains;

  domainbar.innerHTML = "";
  sidebar.innerHTML = "";

  domains.forEach(d=>{
    const count = domainPages(d.id).length;

    const btn = document.createElement("button");
    btn.textContent = d.id.replace("_"," · ");
    btn.onclick = () => selectDomain(d.id);
    btn.dataset.id = d.id;
    domainbar.appendChild(btn);

    const card = document.createElement("div");
    card.className = "domainCard";
    card.dataset.id = d.id;
    card.innerHTML = `<b>${d.id} — ${d.title}</b><small>${d.engine_target || "Engine target"} · ${count} pagine</small>`;
    card.onclick = () => selectDomain(d.id);
    sidebar.appendChild(card);
  });
}

function selectDomain(id){
  activeDomain = id;
  const domains = registry.domains || fallbackDomains;
  const d = domains.find(x=>x.id===id) || domains[0];

  document.querySelectorAll(".domainbar button").forEach(b=>b.classList.toggle("active", b.dataset.id===id));
  document.querySelectorAll(".domainCard").forEach(c=>c.classList.toggle("active", c.dataset.id===id));

  domainName.textContent = `${d.id} — ${d.title}`;
  domainDesc.textContent = domainDescription(d.id);
  engineTarget.textContent = d.engine_target || "Engine target";

  const pages = domainPages(id);
  if(!pages.length){
    pagesGrid.innerHTML = `<div class="empty">Nessuna pagina ancora classificata in questo dominio. Verrà popolato durante la promozione/fusione dei moduli.</div>`;
    return;
  }

  pagesGrid.innerHTML = pages.map(p=>{
    const action = p.recommended_action || "FUSE";
    const title = p.title || p.h1 || p.route;
    const reason = p.reason || "";
    return `
      <article class="page">
        <div class="pageTop">
          <a href="${p.route}">${title}</a>
          <span class="badge ${action}">${action}</span>
        </div>
        <p><b>Route:</b> ${p.route}</p>
        <p>${reason}</p>
      </article>
    `;
  }).join("");
}

function domainDescription(id){
  const map = {
    "01_Mission_Control":"Stato laboratorio, Open5GS/UERANSIM, HackRF/SDR, allarmi, KPI live e runtime readiness.",
    "02_RF_Physics":"Onde elettromagnetiche, propagazione, Fourier/FFT, fase, group delay, rumore di fase, coerenza e dispersione.",
    "03_Signal_Analyzer":"Spettro, waterfall, IQ, costellazioni, modulazioni AM/FM/PM/QPSK/QAM/OFDM e analisi HackRF fino a 6 GHz.",
    "04_RF_Microwave_Engineering":"Smith Chart, impedenza, VSWR, S11, return loss, coassiali, microstrip, stripline e patch antenna.",
    "05_Antenna_System":"Antenne panel, RRU/BBU, CPRI/eCPRI, RET/AISG, 8T8R/MIMO, tilt, azimuth e port mapping.",
    "06_Microwave_Link":"LOS, Fresnel, fade margin, rain fading, RSL, BER, XPIC e adaptive modulation.",
    "07_Fiber_Optic":"Connettori SC/LC/ST/MPO, ODF, attenuazione, riflessione, OTDR e trasporto fronthaul/backhaul.",
    "08_Private_Networks":"5G SA private, WiFi 7, MLO, industrial mesh, mining/campus/tactical network, slicing, QoS e MEC.",
    "09_Core_Network":"AMF/SMF/UPF, NGAP, PFCP, GTP-U, PDU session e call-flow 3GPP.",
    "10_Data_Center_Infrastructure":"Rack, PDU, UPS, alimentazione -48V, grounding, temperatura e monitoring SNMP.",
    "11_Cyber_RF_Intelligence":"Spectrum anomaly, jamming, rogue RF, intrusion detection, protocol anomaly ed evidence/report.",
    "12_Knowledge_Base":"Glossario, formule, procedure, troubleshooting, checklist e lesson plan."
  };
  return map[id] || "Dominio tecnico TRFMC.";
}

loadHealth();
loadRegistry();
</script>
</body>
</html>
HTML

echo
echo "=== PATCH LINK SU MASTER, INDEX E REGISTRY ==="

MASTER="$PUBLIC/trfmc_master_digital_twin_console_v1.html"
INDEX="$PUBLIC/api/portal/index"
REGISTRY="$PUBLIC/trfmc_domain_registry_v1.html"

if [ -f "$MASTER" ]; then
  cp -a "$MASTER" "$MASTER.bak_shell_v1_$TS"
  if ! grep -q "trfmc_unified_navigation_shell_v1.html" "$MASTER"; then
    sed -i '/<a href="\/trfmc_domain_registry_v1.html">Domain Registry<\/a>/a \      <a href="/trfmc_unified_navigation_shell_v1.html">Unified Shell</a>' "$MASTER" || true
  fi
fi

if [ -f "$INDEX" ]; then
  cp -a "$INDEX" "$INDEX.bak_shell_v1_$TS"
  if ! grep -q "trfmc_unified_navigation_shell_v1.html" "$INDEX"; then
    sed -i '/<ul>/a <li><a href="/trfmc_unified_navigation_shell_v1.html">TRFMC Unified Navigation Shell V1</a></li>' "$INDEX" || true
  fi
fi

if [ -f "$REGISTRY" ]; then
  cp -a "$REGISTRY" "$REGISTRY.bak_shell_v1_$TS"
  if ! grep -q "trfmc_unified_navigation_shell_v1.html" "$REGISTRY"; then
    sed -i '/<a href="\/trfmc_master_digital_twin_console_v1.html">Master Digital Twin Console<\/a>/a \    <a href="/trfmc_unified_navigation_shell_v1.html">Unified Shell</a>' "$REGISTRY" || true
  fi
fi

echo
echo "=== TEST FILE ==="
ls -lh "$SHELL"

echo
echo "UNIFIED SHELL URL:"
echo "http://127.0.0.1:5173/trfmc_unified_navigation_shell_v1.html"
