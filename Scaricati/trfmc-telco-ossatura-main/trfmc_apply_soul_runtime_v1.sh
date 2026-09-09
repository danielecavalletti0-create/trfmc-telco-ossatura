#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSET_DIR="$PUBLIC/assets/trfmc_soul_runtime"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_SOUL_RUNTIME_V1_$TS"
LATEST="$BASE/runtime/quality/latest_soul_runtime_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

CSS="$ASSET_DIR/trfmc_soul_runtime_v1.css"
JS="$ASSET_DIR/trfmc_soul_runtime_v1.js"
TOKENS="$PUBLIC/trfmc_soul_tokens_v1.json"
MANIFEST="$PUBLIC/trfmc_soul_runtime_manifest_v1.json"
LAB="$PUBLIC/trfmc_soul_runtime_lab_v1.html"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC SOUL RUNTIME V1"
echo "Mission cortex · living context · sensory optional · safe leaf patch"
echo "============================================================"

echo
echo "[1/9] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_SOUL_RUNTIME_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_visual_asset_engine_v3 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Creo Soul Tokens"

cat > "$TOKENS" <<'JSON'
{
  "id": "TRFMC_SOUL_TOKENS_V1",
  "mission": {
    "name": "TRFMC / RF Telco Cyber Digital Twin",
    "motto": "Dal campo elettromagnetico al core 5G, dal segnale alla decisione.",
    "stance": "engineering-grade, instrument-like, evidence-driven, cinematic"
  },
  "domains": {
    "rf": {
      "name": "RF Physics",
      "soul": "Il campo è il linguaggio primario: ampiezza, fase, spettro, energia e propagazione."
    },
    "antenna": {
      "name": "Antenna / RRU / RET",
      "soul": "Il segnale diventa infrastruttura fisica: porte, polarizzazione, beam, tilt, EIRP e copertura."
    },
    "microwave": {
      "name": "Microwave Link",
      "soul": "Il collegamento vive fra linea di vista, fade margin, modulazione, RSL, BER e disponibilità."
    },
    "fiber": {
      "name": "Fiber / Fronthaul",
      "soul": "La fibra porta tempo, perdita, riflessione, latenza, CPRI/eCPRI e continuità di servizio."
    },
    "core": {
      "name": "5G Core / RAN",
      "soul": "Identità, autenticazione, sessioni, policy, tunnel e sicurezza diventano flusso operativo."
    },
    "cyber": {
      "name": "Cyber RF Intelligence",
      "soul": "Ogni anomalia diventa evidenza: spettro, evento, correlazione, decisione."
    },
    "datacenter": {
      "name": "Data Center / Power",
      "soul": "Senza energia, raffreddamento, rack, PDU e telemetria non esiste continuità digitale."
    },
    "knowledge": {
      "name": "Knowledge Base",
      "soul": "La teoria non è documento: è motore operativo che spiega ciò che il portale mostra."
    }
  }
}
JSON

echo
echo "[3/9] Creo CSS Soul Runtime"

cat > "$CSS" <<'CSS'
/*
 TRFMC Soul Runtime V1
 Mission cortex layer. No navbar. No iframe. No CDN.
*/

body.trfmc-soul-v1{
  --soul-cyan:#00e5ff;
  --soul-green:#75ff5b;
  --soul-gold:#ffd84d;
  --soul-red:#ff3d7f;
  --soul-bg:rgba(1,9,16,.76);
}

.trfmc-soul-orb{
  position:fixed;
  left:18px;
  bottom:18px;
  z-index:30;
  width:54px;
  height:54px;
  border-radius:50%;
  border:1px solid rgba(0,229,255,.48);
  background:
    radial-gradient(circle at 35% 30%, rgba(255,255,255,.72), rgba(0,229,255,.22) 18%, rgba(0,20,34,.88) 58%, rgba(0,0,0,.94));
  box-shadow:
    0 0 28px rgba(0,229,255,.28),
    inset 0 0 18px rgba(0,229,255,.18);
  cursor:pointer;
  transform:translateZ(0);
  transition:transform .18s ease, box-shadow .18s ease, opacity .18s ease;
  font-family:ui-monospace,Consolas,monospace;
  color:#75ff5b;
  font-size:9px;
  display:flex;
  align-items:center;
  justify-content:center;
  letter-spacing:.08em;
  user-select:none;
}

.trfmc-soul-orb:hover{
  transform:scale(1.06);
  box-shadow:
    0 0 36px rgba(117,255,91,.30),
    inset 0 0 20px rgba(0,229,255,.20);
}

.trfmc-soul-orb::before{
  content:"";
  position:absolute;
  inset:-8px;
  border-radius:50%;
  border:1px solid rgba(0,229,255,.20);
  animation:trfmcSoulPulse 2.8s ease-in-out infinite;
}

.trfmc-soul-orb::after{
  content:"";
  position:absolute;
  inset:8px;
  border-radius:50%;
  border:1px solid rgba(117,255,91,.34);
  opacity:.65;
}

.trfmc-soul-panel{
  position:fixed;
  left:18px;
  bottom:84px;
  z-index:30;
  width:min(430px, calc(100vw - 36px));
  max-height:min(560px, calc(100vh - 120px));
  overflow:auto;
  border:1px solid rgba(0,229,255,.38);
  border-radius:12px;
  background:
    radial-gradient(circle at 80% 8%, rgba(0,229,255,.16), transparent 30%),
    linear-gradient(145deg, rgba(2,18,30,.94), rgba(1,7,13,.94));
  box-shadow:
    0 0 36px rgba(0,229,255,.18),
    inset 0 0 24px rgba(0,229,255,.055),
    0 18px 58px rgba(0,0,0,.55);
  backdrop-filter:blur(16px) saturate(130%);
  color:#dffaff;
  font-family:ui-monospace,Consolas,monospace;
  padding:12px;
  opacity:0;
  transform:translateY(8px) scale(.98);
  pointer-events:none;
  transition:opacity .18s ease, transform .18s ease;
}

.trfmc-soul-panel[data-open="true"]{
  opacity:1;
  transform:translateY(0) scale(1);
  pointer-events:auto;
}

.trfmc-soul-title{
  color:#00e5ff;
  font-size:13px;
  letter-spacing:.09em;
  text-transform:uppercase;
  margin-bottom:3px;
  text-shadow:0 0 14px rgba(0,229,255,.42);
}

.trfmc-soul-sub{
  color:#8fb8c8;
  font-size:10px;
  line-height:1.45;
  margin-bottom:10px;
}

.trfmc-soul-section{
  border:1px solid rgba(0,229,255,.18);
  border-radius:8px;
  background:rgba(0,229,255,.035);
  padding:8px;
  margin-top:8px;
}

.trfmc-soul-section b{
  color:#75ff5b;
}

.trfmc-soul-line{
  font-size:10.5px;
  color:#dffaff;
  line-height:1.45;
}

.trfmc-soul-path{
  display:grid;
  grid-template-columns:repeat(6,1fr);
  gap:4px;
  margin-top:8px;
}

.trfmc-soul-node{
  min-height:28px;
  border:1px solid rgba(0,229,255,.22);
  background:rgba(0,229,255,.05);
  border-radius:6px;
  color:#8fb8c8;
  font-size:8px;
  display:flex;
  align-items:center;
  justify-content:center;
  text-align:center;
  padding:3px;
}

.trfmc-soul-node[data-active="true"]{
  color:#75ff5b;
  border-color:rgba(117,255,91,.50);
  box-shadow:0 0 14px rgba(117,255,91,.18);
}

.trfmc-soul-actions{
  display:flex;
  gap:6px;
  flex-wrap:wrap;
  margin-top:10px;
}

.trfmc-soul-button{
  border:1px solid rgba(0,229,255,.30);
  background:rgba(0,229,255,.08);
  color:#dffaff;
  border-radius:6px;
  padding:6px 8px;
  font-size:10px;
  font-family:ui-monospace,Consolas,monospace;
  cursor:pointer;
}

.trfmc-soul-button:hover{
  border-color:rgba(117,255,91,.50);
  color:#75ff5b;
}

.trfmc-soul-ribbon{
  position:fixed;
  right:18px;
  bottom:18px;
  z-index:28;
  pointer-events:none;
  font-family:ui-monospace,Consolas,monospace;
  color:#8fb8c8;
  font-size:9px;
  padding:6px 8px;
  border:1px solid rgba(0,229,255,.22);
  border-radius:8px;
  background:rgba(1,9,16,.55);
  backdrop-filter:blur(10px);
  max-width:300px;
  opacity:.82;
}

@keyframes trfmcSoulPulse{
  0%,100%{transform:scale(.92);opacity:.25;}
  50%{transform:scale(1.20);opacity:.70;}
}

@media(max-width:900px){
  .trfmc-soul-ribbon{display:none;}
}

@media (prefers-reduced-motion: reduce){
  .trfmc-soul-orb::before{animation:none;}
}
CSS

echo
echo "[4/9] Creo JS Soul Runtime"

cat > "$JS" <<'JS'
/*
 TRFMC Soul Runtime V1
 Mission context, living narrative, optional local audio feedback.
 Safe: no CDN, no iframe, no network except local tokens/registry fetch.
*/
(function(){
  "use strict";

  const ID = "TRFMC_SOUL_RUNTIME_V1";
  const OFF = "TRFMC_SOUL_RUNTIME";
  const AUDIO = "TRFMC_SOUL_AUDIO";

  if (localStorage.getItem(OFF) === "off") return;

  const defaultTokens = {
    mission:{
      name:"TRFMC / RF Telco Cyber Digital Twin",
      motto:"Dal campo elettromagnetico al core 5G, dal segnale alla decisione."
    },
    domains:{
      rf:{name:"RF Physics",soul:"Il campo è il linguaggio primario: ampiezza, fase, spettro, energia e propagazione."},
      antenna:{name:"Antenna / RRU / RET",soul:"Il segnale diventa infrastruttura fisica: porte, polarizzazione, beam, tilt, EIRP e copertura."},
      microwave:{name:"Microwave Link",soul:"Il collegamento vive fra linea di vista, fade margin, modulazione, RSL, BER e disponibilità."},
      fiber:{name:"Fiber / Fronthaul",soul:"La fibra porta tempo, perdita, riflessione, latenza, CPRI/eCPRI e continuità di servizio."},
      core:{name:"5G Core / RAN",soul:"Identità, autenticazione, sessioni, policy, tunnel e sicurezza diventano flusso operativo."},
      cyber:{name:"Cyber RF Intelligence",soul:"Ogni anomalia diventa evidenza: spettro, evento, correlazione, decisione."},
      datacenter:{name:"Data Center / Power",soul:"Senza energia, raffreddamento, rack, PDU e telemetria non esiste continuità digitale."},
      knowledge:{name:"Knowledge Base",soul:"La teoria non è documento: è motore operativo che spiega ciò che il portale mostra."}
    }
  };

  const path = [
    ["rf","CAMPO"],
    ["antenna","ANTENNA"],
    ["microwave","LINK"],
    ["fiber","FIBER"],
    ["core","CORE"],
    ["cyber","EVIDENCE"]
  ];

  function detectDomain(){
    const u = location.pathname.toLowerCase();
    const t = (document.title || "").toLowerCase();

    if (u.includes("antenna") || u.includes("rru") || u.includes("ret") || t.includes("antenna")) return "antenna";
    if (u.includes("microwave") || u.includes("smith") || u.includes("mw_") || t.includes("microwave")) return "microwave";
    if (u.includes("fiber") || u.includes("otdr") || u.includes("fronthaul")) return "fiber";
    if (u.includes("core") || u.includes("ran") || u.includes("identity") || u.includes("aka") || u.includes("open5gs")) return "core";
    if (u.includes("cyber") || u.includes("intelligence") || u.includes("evidence") || u.includes("war_room")) return "cyber";
    if (u.includes("data") || u.includes("pdu") || u.includes("rack") || u.includes("power")) return "datacenter";
    if (u.includes("knowledge") || u.includes("theory") || u.includes("sapienza")) return "knowledge";
    return "rf";
  }

  function moduleName(){
    const h1 = document.querySelector(".leaf-title,h1,h2");
    if (h1 && h1.textContent.trim()) return h1.textContent.trim();
    const file = location.pathname.split("/").pop() || "TRFMC module";
    return file.replace(/\.html$/,"").replace(/_/g," ");
  }

  function qualitySignals(){
    const labels = [];
    if (document.querySelector("canvas")) labels.push("canvas");
    if (document.body.classList.contains("trfmc-gpu-v2")) labels.push("gpu-runtime");
    if (window.TRFMC_VISUAL_ASSET_ENGINE_V3) labels.push("asset-engine");
    if (document.querySelector("trfmc-visual-asset")) labels.push("visual-assets");
    if (document.querySelector(".formulaLive")) labels.push("live-formulas");
    if (document.querySelector(".leaf-kpi")) labels.push("kpi");
    return labels.length ? labels : ["leaf-module"];
  }

  function createEl(tag, cls, text){
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text !== undefined) el.textContent = text;
    return el;
  }

  function localBeep(kind){
    if (localStorage.getItem(AUDIO) !== "on") return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;

    const ctx = window.__TRFMC_SOUL_AUDIO_CTX || new AC();
    window.__TRFMC_SOUL_AUDIO_CTX = ctx;

    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    const base = kind === "open" ? 196 : kind === "domain" ? 261.63 : 146.83;
    osc.type = "sine";
    osc.frequency.setValueAtTime(base, now);
    osc.frequency.exponentialRampToValueAtTime(base * 1.5, now + 0.10);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.035, now + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.18);

    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.20);
  }

  async function loadTokens(){
    try {
      const r = await fetch("/trfmc_soul_tokens_v1.json", {cache:"no-cache"});
      if (r.ok) return await r.json();
    } catch(e){}
    return defaultTokens;
  }

  async function loadRegistryCounts(){
    try {
      const r = await fetch("/trfmc_portal_registry_unified.json", {cache:"no-cache"});
      if (!r.ok) return null;
      const j = await r.json();
      return j.counts || null;
    } catch(e){
      return null;
    }
  }

  function buildPanel(tokens, counts){
    const domain = detectDomain();
    const d = tokens.domains[domain] || tokens.domains.rf;
    const signals = qualitySignals();

    const panel = createEl("div","trfmc-soul-panel");
    panel.dataset.open = "false";

    panel.appendChild(createEl("div","trfmc-soul-title","MISSION CORTEX · " + d.name));
    panel.appendChild(createEl("div","trfmc-soul-sub",tokens.mission.motto));

    const s1 = createEl("div","trfmc-soul-section");
    s1.innerHTML =
      '<div class="trfmc-soul-line"><b>Modulo:</b> ' + escapeHtml(moduleName()) + '</div>' +
      '<div class="trfmc-soul-line"><b>Anima tecnica:</b> ' + escapeHtml(d.soul) + '</div>' +
      '<div class="trfmc-soul-line"><b>Segnali vivi:</b> ' + signals.map(escapeHtml).join(" · ") + '</div>';
    panel.appendChild(s1);

    const s2 = createEl("div","trfmc-soul-section");
    s2.innerHTML =
      '<div class="trfmc-soul-line"><b>Stato portale:</b> ' +
      (counts ? counts.total_html + ' HTML · ' + counts.leaf_operational_candidate + ' leaf operative' : 'registry local not loaded') +
      '</div>' +
      '<div class="trfmc-soul-line"><b>Runtime:</b> GPU · Visual Asset Engine · Soul Layer</div>';
    panel.appendChild(s2);

    const p = createEl("div","trfmc-soul-path");
    path.forEach(([key,label])=>{
      const n = createEl("div","trfmc-soul-node",label);
      n.dataset.active = String(key === domain);
      p.appendChild(n);
    });
    panel.appendChild(p);

    const actions = createEl("div","trfmc-soul-actions");

    const audio = createEl("button","trfmc-soul-button",localStorage.getItem(AUDIO)==="on" ? "SOUND ON" : "ARM SOUND");
    audio.addEventListener("click",()=>{
      const on = localStorage.getItem(AUDIO)==="on";
      localStorage.setItem(AUDIO, on ? "off" : "on");
      audio.textContent = on ? "ARM SOUND" : "SOUND ON";
      localBeep("domain");
    });

    const mute = createEl("button","trfmc-soul-button","HIDE SOUL");
    mute.addEventListener("click",()=>{
      localStorage.setItem(OFF,"off");
      location.reload();
    });

    const pulse = createEl("button","trfmc-soul-button","PULSE");
    pulse.addEventListener("click",()=>localBeep("open"));

    actions.appendChild(audio);
    actions.appendChild(pulse);
    actions.appendChild(mute);
    panel.appendChild(actions);

    return panel;
  }

  function escapeHtml(s){
    return String(s).replace(/[&<>"']/g, m => ({
      "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
    }[m]));
  }

  async function boot(){
    document.body.classList.add("trfmc-soul-v1");

    const [tokens, counts] = await Promise.all([loadTokens(), loadRegistryCounts()]);
    const domain = detectDomain();
    const d = tokens.domains[domain] || tokens.domains.rf;

    const orb = createEl("div","trfmc-soul-orb","SOUL");
    const panel = buildPanel(tokens, counts);
    const ribbon = createEl("div","trfmc-soul-ribbon",d.name + " · " + d.soul);

    orb.addEventListener("click",()=>{
      const open = panel.dataset.open === "true";
      panel.dataset.open = String(!open);
      localBeep(open ? "close" : "open");
    });

    document.body.appendChild(orb);
    document.body.appendChild(panel);
    document.body.appendChild(ribbon);

    window.TRFMC_SOUL_RUNTIME_V1 = {
      id: ID,
      domain,
      module: moduleName(),
      signals: qualitySignals(),
      counts,
      audio: localStorage.getItem(AUDIO)==="on",
      createdAt: new Date().toISOString()
    };
  }

  if (document.readyState === "loading"){
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
JS

echo
echo "[5/9] Creo manifest Soul Runtime"

cat > "$MANIFEST" <<'JSON'
{
  "id": "TRFMC_SOUL_RUNTIME_V1",
  "version": "1.0.0",
  "policy": "Mission cortex layer. No CDN. No iframe. No new navigation bar. V6R3 and Control Room protected.",
  "assets": {
    "css": "/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css",
    "js": "/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js",
    "tokens": "/trfmc_soul_tokens_v1.json"
  },
  "features": [
    "mission_context",
    "domain_detection",
    "living_status_panel",
    "quality_signal_detection",
    "registry_count_bridge",
    "optional_local_web_audio_feedback",
    "disable_switch",
    "technical_micro_narrative"
  ],
  "disable": {
    "runtime": "localStorage.TRFMC_SOUL_RUNTIME='off'",
    "audio": "localStorage.TRFMC_SOUL_AUDIO='off'"
  }
}
JSON

echo
echo "[6/9] Creo Soul Runtime Lab"

cat > "$LAB" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Soul Runtime Lab V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.soul-lab{display:grid;grid-template-columns:390px 1fr 430px;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}
.soul-stage{display:grid;grid-template-rows:1fr 260px;gap:8px}
.soul-map{border:1px solid rgba(0,229,255,.34);border-radius:10px;background:rgba(1,9,16,.72);position:relative;overflow:hidden;min-height:520px}
.soul-map canvas{width:100%;height:100%;display:block}
.mono{font-family:ui-monospace,Consolas,monospace;color:#dffaff;font-size:11px}
@media(max-width:1400px){.soul-lab{grid-template-columns:1fr}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Soul Runtime Lab V1</div>
    <div class="leaf-sub">Mission cortex · identità viva · domini tecnici · feedback sensoriale opzionale · portale come organismo</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>Runtime</small><b>Soul</b></div>
    <div class="leaf-kpi"><small>Audio</small><b>opt-in</b></div>
    <div class="leaf-kpi"><small>Registry</small><b>local</b></div>
    <div class="leaf-kpi"><small>Mode</small><b>V1</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_visual_asset_engine_lab_v3.html">Asset Engine</a>
    <a class="leaf-btn" href="/trfmc_gpu_visual_runtime_lab_v2.html">GPU Lab</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
  </div>
</header>

<div class="soul-lab">
  <aside class="leaf-panel">
    <h2>Che cosa aggiunge</h2>
    <div class="leaf-card">
      <h3>Anima del portale</h3>
      <p>Non è solo estetica. È una regia che dice: dove sei, cosa stai guardando, perché è importante, quali segnali sono vivi e come quel modulo si collega agli altri.</p>
    </div>
    <div class="leaf-card">
      <h3>Runtime object</h3>
      <pre class="mono" id="runtimeBox">loading...</pre>
    </div>
  </aside>

  <main class="leaf-panel soul-stage">
    <section class="soul-map">
      <canvas id="soulCanvas"></canvas>
    </section>
    <trfmc-visual-asset kind="core-map" data-size="small" title="Core / RF / Cyber continuity"></trfmc-visual-asset>
  </main>

  <aside class="leaf-panel">
    <h2>Mission domains</h2>
    <div class="leaf-card"><h3>RF</h3><p>Campo, fase, spettro, energia.</p></div>
    <div class="leaf-card"><h3>Antenna</h3><p>Beam, porte, tilt, EIRP, copertura.</p></div>
    <div class="leaf-card"><h3>Microwave / Fiber</h3><p>Link, attenuazione, riflessione, latenza.</p></div>
    <div class="leaf-card"><h3>5G Core / Cyber</h3><p>Identità, sessioni, evidenza, decisione.</p></div>
  </aside>
</div>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
<script>
(function(){
  const canvas=document.getElementById("soulCanvas");
  const nodes=[
    ["RF",.18,.35],["ANTENNA",.36,.25],["MW",.55,.35],["FIBER",.72,.25],
    ["CORE",.54,.62],["CYBER",.78,.65],["KNOWLEDGE",.28,.68]
  ];
  function fit(){
    const dpr=Math.min(2,devicePixelRatio||1);
    const w=canvas.clientWidth*dpr,h=canvas.clientHeight*dpr;
    if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
    return {ctx:canvas.getContext("2d"),w,h,dpr};
  }
  function rr(ctx,x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}
  function frame(ms){
    const {ctx,w,h,dpr}=fit();
    const t=ms*.001;
    const g=ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");g.addColorStop(1,"#010409");
    ctx.fillStyle=g;ctx.fillRect(0,0,w,h);

    ctx.strokeStyle="rgba(0,229,255,.08)";
    for(let i=0;i<18;i++){ctx.beginPath();ctx.moveTo(w*i/17,0);ctx.lineTo(w*.50,h*.50);ctx.stroke();}

    ctx.lineWidth=2*dpr;
    for(let i=0;i<nodes.length;i++){
      for(let j=i+1;j<nodes.length;j++){
        const a=nodes[i],b=nodes[j];
        const pulse=(Math.sin(t*1.7+i+j)+1)/2;
        ctx.strokeStyle=`rgba(0,229,255,${.08+.16*pulse})`;
        ctx.beginPath();ctx.moveTo(w*a[1],h*a[2]);ctx.lineTo(w*b[1],h*b[2]);ctx.stroke();
      }
    }

    nodes.forEach((n,i)=>{
      const x=w*n[1],y=h*n[2],pulse=(Math.sin(t*2+i)+1)/2;
      ctx.fillStyle=`rgba(${i===5?255:0},${i===5?61:229},${i===5?127:255},${.10+.10*pulse})`;
      rr(ctx,x-58*dpr,y-22*dpr,116*dpr,44*dpr,10*dpr);ctx.fill();
      ctx.strokeStyle=i===5?"rgba(255,61,127,.58)":"rgba(0,229,255,.55)";
      ctx.stroke();
      ctx.fillStyle=i===5?"#ff3d7f":"#75ff5b";
      ctx.font=(13*dpr)+"px ui-monospace,Consolas,monospace";
      ctx.fillText(n[0],x-ctx.measureText(n[0]).width/2,y+4*dpr);
    });

    ctx.fillStyle="#00e5ff";
    ctx.font=(15*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("TRFMC MISSION CORTEX · DAL SEGNALE ALLA DECISIONE",24*dpr,34*dpr);

    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  setTimeout(()=>{document.getElementById("runtimeBox").textContent=JSON.stringify(window.TRFMC_SOUL_RUNTIME_V1||{},null,2)},600);
})();
</script>
</body>
</html>
HTML

echo
echo "[7/9] Patch leaf operative con Soul Runtime"

python3 - "$PUBLIC" "$REG" "$OUT" <<'PY'
import json, re, sys
from pathlib import Path

public=Path(sys.argv[1])
reg_path=Path(sys.argv[2])
out=Path(sys.argv[3])

css_href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css"
js_src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"

protected={
    "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "/trfmc_integration_control_room.html",
    "/trfmc_portal_registry_unified.json",
    "/trfmc_soul_runtime_lab_v1.html"
}

reg=json.loads(reg_path.read_text(errors="ignore"))
patched=[]
skipped=[]
missing=[]

def body_class(s):
    m=re.search(r"<body\b([^>]*)>", s, flags=re.I)
    if not m:
        return s
    body=m.group(0)
    attrs=m.group(1)
    if "trfmc-soul-v1" in body:
        return s
    if re.search(r'\bclass\s*=', body, flags=re.I):
        new=re.sub(
            r'class\s*=\s*["\']([^"\']*)["\']',
            lambda mm: 'class="' + mm.group(1).strip() + ' trfmc-soul-v1"',
            body, count=1, flags=re.I
        )
    else:
        new='<body class="trfmc-soul-v1"' + attrs + ">"
    return s[:m.start()] + new + s[m.end():]

for p in reg.get("pages",[]):
    url=p.get("url","")
    cls=p.get("class","")
    if cls!="leaf_operational_candidate":
        skipped.append((url,"not_leaf"))
        continue
    if url in protected:
        skipped.append((url,"protected"))
        continue
    if not url.endswith(".html"):
        skipped.append((url,"not_html"))
        continue

    f=public/url.lstrip("/")
    if not f.exists():
        missing.append(url)
        continue

    s=f.read_text(errors="ignore")
    original=s

    if css_href not in s:
        if re.search(r"</head>", s, flags=re.I):
            s=re.sub(r"</head>", f'<link rel="stylesheet" href="{css_href}">\n</head>', s, count=1, flags=re.I)
        else:
            skipped.append((url,"no_head"))
            continue

    if js_src not in s:
        if re.search(r"</body>", s, flags=re.I):
            s=re.sub(r"</body>", f'<script src="{js_src}"></script>\n</body>', s, count=1, flags=re.I)
        else:
            s += f'\n<script src="{js_src}"></script>\n'

    s=body_class(s)

    if s != original:
        f.write_text(s)
        patched.append(url)

(out/"patched_pages.tsv").write_text("url\n" + "\n".join(patched) + "\n")
(out/"skipped_pages.tsv").write_text("url\treason\n" + "\n".join(f"{u}\t{r}" for u,r in skipped) + "\n")
(out/"missing_pages.txt").write_text("\n".join(missing) + "\n")

print(json.dumps({"patched":len(patched),"skipped":len(skipped),"missing":len(missing)},indent=2))
PY

echo
echo "[8/9] Registro Soul Lab nel registry"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public=Path(sys.argv[1])
reg_path=Path(sys.argv[2])
reg=json.loads(reg_path.read_text(errors="ignore"))
pages=reg.get("pages",[])
by_url={p.get("url"):p for p in pages if p.get("url")}

target=public/"trfmc_soul_runtime_lab_v1.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_soul_runtime_lab_v1.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_soul_runtime_lab_v1.html",
  "url":"/trfmc_soul_runtime_lab_v1.html",
  "size":target.stat().st_size,
  "canvas":True,
  "audio_opt_in":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Soul Runtime V1 mission cortex"
}

reg["pages"]=list(by_url.values())
counts={}
for p in reg["pages"]:
    c=p.get("class","unknown")
    counts[c]=counts.get(c,0)+1
counts["total_html"]=len(reg["pages"])
for k in ["official_shell","service","leaf_operational_candidate","shell_or_legacy_container","orphan_or_legacy_candidate"]:
    counts.setdefault(k,0)

reg["counts"]=counts
reg["last_soul_runtime_v1_update"]={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "page":"/trfmc_soul_runtime_lab_v1.html",
  "policy":"Soul Runtime applied to leaf pages; V6R3 and Control Room protected"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_soul_runtime_v1_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[9/9] Quality gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css \
    /assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js \
    /trfmc_soul_tokens_v1.json \
    /trfmc_soul_runtime_manifest_v1.json \
    /trfmc_soul_runtime_lab_v1.html \
    /trfmc_visual_asset_engine_lab_v3.html \
    /trfmc_gpu_visual_runtime_lab_v2.html \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_portal_registry_unified.json
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/fused_forbidden_refs.txt"
: > "$OUT/content_checks.txt"

for f in "$CSS" "$JS" "$TOKENS" "$MANIFEST" "$LAB"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
  grep -nEi 'MASTER FUSED|trfmc_master_fused|fallback shell' "$f" >> "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC_SOUL_RUNTIME_V1" \
  "MISSION CORTEX" \
  "trfmc-soul-orb" \
  "trfmc-soul-panel" \
  "AudioContext" \
  "Oscillator" \
  "domain_detection" \
  "registry_count_bridge" \
  "Dal campo elettromagnetico al core 5G"
do
  if grep -Rqs "$token" "$ASSET_DIR" "$TOKENS" "$MANIFEST" "$LAB"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

python3 - "$OUT" "$REG" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

out=Path(sys.argv[1])
reg_path=Path(sys.argv[2])

http=[]
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=3:
        http.append({"url":p[0],"status":p[1],"bytes":p[2]})

non200=sum(1 for x in http if x["status"]!="200")
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fused=sum(1 for x in (out/"fused_forbidden_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
content_miss=sum(1 for x in (out/"content_checks.txt").read_text(errors="ignore").splitlines() if x.startswith("MISS:"))
missing=sum(1 for x in (out/"missing_pages.txt").read_text(errors="ignore").splitlines() if x.strip())
patched=max(0, len((out/"patched_pages.tsv").read_text(errors="ignore").splitlines())-1)

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.strip().split("=",1)
        sha[k]=v

protected_ok=(
    sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER")
)
registry_changed=sha.get("REG_SHA_BEFORE")!=sha.get("REG_SHA_AFTER")
reg=json.loads(reg_path.read_text(errors="ignore"))

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "runtime":"TRFMC_SOUL_RUNTIME_V1",
  "lab":"/trfmc_soul_runtime_lab_v1.html",
  "patched_leaf_pages":patched,
  "http_non_200":non200,
  "external_refs":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "content_check_miss":content_miss,
  "missing_pages":missing,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "disable_switch":"localStorage.TRFMC_SOUL_RUNTIME='off'",
  "audio_switch":"localStorage.TRFMC_SOUL_AUDIO='on'",
  "result":"PASS" if patched>=1 and non200==0 and external==0 and iframe==0 and fused==0 and content_miss==0 and missing==0 and protected_ok and registry_changed else "WARN",
  "policy":"Soul Runtime V1 applied to leaf pages only. V6R3 and official Control Room unchanged."
}
(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_SOUL_RUNTIME_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_soul_runtime \
    frontend/public/trfmc_soul_tokens_v1.json \
    frontend/public/trfmc_soul_runtime_manifest_v1.json \
    frontend/public/trfmc_soul_runtime_lab_v1.html \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_soul_runtime_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "Content checks:"
cat "$OUT/content_checks.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_soul_runtime_lab_v1.html"
echo "http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"
echo "============================================================"
