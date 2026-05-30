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
