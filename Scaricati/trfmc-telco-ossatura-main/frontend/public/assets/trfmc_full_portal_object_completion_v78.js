(function(){
  const VERSION = "TRFMC_V0_78A_FULL_PORTAL_OBJECT_INTEGRATION_COMPLETION";

  const OBJECTS = {
    tower: ["Tower", "Struttura fisica del sito radio e supporto ai settori.", "Physical", "v78-tower", '<div class="truss"></div><div class="mast"></div><div class="v78-pulse"></div>'],
    antenna: ["Antenna", "Settore RF, beam, azimuth, tilt e footprint radio.", "RF/RAN", "v78-antenna", '<div class="panel p1"></div><div class="panel p2"></div><div class="v78-pulse"></div>'],
    rru: ["RRU", "Front-end RF remoto, PA, filtri, fault e temperatura.", "RF Front-End", "v78-rru", '<div class="box"></div><div class="v78-pulse"></div>'],
    ret: ["RET/AISG", "Tilt remoto, calibrazione e controllo settore.", "Antenna Control", "v78-ret", '<div class="box"></div><div class="v78-pulse"></div>'],
    microwave: ["Microwave", "Backhaul MW, fade margin, availability e allineamento.", "Transport", "v78-microwave", '<div class="dish"></div><div class="v78-pulse"></div>'],
    fiber: ["Fiber", "Trasporto ottico, ODF, loss budget e continuità.", "Transport", "v78-fiber", '<div class="line"></div><div class="v78-pulse"></div>'],
    shelter: ["Shelter", "Cabinet, BBU/edge, cooling e apparati sito.", "Site/Edge", "v78-shelter", '<div class="box"></div><div class="v78-pulse"></div>'],
    power: ["-48 VDC", "Rettificatori, batterie, breaker e continuità servizio.", "Power", "v78-power", '<div class="box"></div><div class="v78-pulse"></div>'],
    ue: ["UE/V2X", "Terminale mobile, traiettoria, serving cell e SINR.", "Mobility", "v78-ue", '<div class="phone"></div><div class="v78-pulse"></div>'],
    gnb: ["gNB", "Nodo RAN logico, cell identity, NGAP/N2 e GTP-U/N3.", "5G RAN", "v78-gnb", '<div class="node"></div><div class="v78-pulse"></div>'],
    core: ["5GC", "AMF/SMF/UPF/NRF, sessione, policy e user plane.", "Core", "v78-core", '<div class="node"></div><div class="v78-pulse"></div>'],
    cloud: ["Cloud/Edge", "Runtime cloud-native, workload e observability.", "Cloud", "v78-cloud", '<div class="node"></div><div class="v78-pulse"></div>'],
    evidence: ["Evidence", "Snapshot, log, metriche, QA e reportistica.", "Governance", "v78-evidence", '<div class="node"></div><div class="v78-pulse"></div>'],
    propagation: ["Propagation", "Onde, path loss, multipath, fading e clutter.", "RF Physics", "v78-propagation", '<div class="wave"></div><div class="v78-pulse"></div>'],
    vegetation: ["Vegetation", "Foliage loss, stagionalità, umidità e attenuazione.", "Clutter", "v78-vegetation", '<div class="tree"></div><div class="v78-pulse"></div>'],
    urban: ["Urban Canyon", "Edifici, shadowing, diffraction e NLOS.", "Clutter", "v78-urban", '<div class="building b1"></div><div class="building b2"></div><div class="building b3"></div><div class="v78-pulse"></div>'],
    golden: ["Golden Check", "Baseline, health, manifest, verify e regressione.", "QA", "v78-golden", '<div class="node"></div><div class="v78-pulse"></div>']
  };

  const CONFIG = {
    "webgl_rf_heatmap_engine_v68.html": {
      title: "Seasonal Vegetation Object Stack",
      text: "Oggetti di dominio per clutter vegetazionale: foliage loss, stagionalità, UE, gNB, antenna e correlazione con propagazione.",
      objects: ["vegetation","propagation","ue","gnb","antenna","evidence"],
      flow: ["Season", "Foliage Loss", "RSRP/SINR", "Coverage", "Mobility", "Evidence"],
      anchor: "main"
    },
    "webgl_rf_heatmap_engine_v67.html": {
      title: "Urban Shadowing Object Stack",
      text: "Oggetti per ambiente urbano: canyon edilizio, NLOS, multipath, gNB, UE, antenna e rischio handover.",
      objects: ["urban","propagation","ue","gnb","antenna","core"],
      flow: ["Urban Canyon", "NLOS", "Multipath", "SINR", "Handover", "5GC"],
      anchor: "main"
    },
    "webgl_rf_heatmap_engine_v66.html": {
      title: "RF Heatmap Engine Object Stack",
      text: "Oggetti per il motore heatmap: antenna, propagazione, UE, gNB, clutter e osservabilità.",
      objects: ["antenna","propagation","ue","gnb","urban","vegetation"],
      flow: ["Antenna", "Propagation", "Clutter", "Heatmap", "UE Mobility", "KPI"],
      anchor: "main"
    },
    "field_engineering_mode_v64.html": {
      title: "Field Engineering Object Stack",
      text: "Oggetti per troubleshooting sul campo: tower, RRU, RET/AISG, power, fiber, microwave ed evidence.",
      objects: ["tower","rru","ret","power","fiber","microwave","evidence"],
      flow: ["Inspect", "Measure", "Correlate", "Isolate Fault", "Remediate", "Evidence"],
      anchor: "main"
    },
    "rf_propagation_sandbox_v62.html": {
      title: "RF Propagation Object Stack",
      text: "Oggetti teorici e operativi per propagazione: antenna, onda, clutter urbano/vegetazione, UE e gNB.",
      objects: ["antenna","propagation","urban","vegetation","ue","gnb"],
      flow: ["Antenna", "Wave", "Path Loss", "Multipath", "Clutter", "Coverage"],
      anchor: "main"
    },
    "rf_telco_knowledge_modules_v61.html": {
      title: "Knowledge Modules Object Stack",
      text: "Oggetti visuali associati ai contenuti didattici: fisica RF, RAN, core, trasporto e site operations.",
      objects: ["propagation","antenna","rru","gnb","core","fiber","evidence"],
      flow: ["Theory", "Object", "Measurement", "Scenario", "Evidence", "Lesson"],
      anchor: "main"
    },
    "portal_index_v19.html": {
      title: "Portal Index Object Stack",
      text: "Oggetti di orientamento per l'intero portale: RAN, core, transport, field, knowledge e governance.",
      objects: ["gnb","core","fiber","cloud","evidence","golden"],
      flow: ["Portal", "RAN", "Core", "Transport", "Knowledge", "Governance"],
      anchor: "main"
    },
    "runtime_golden_check_console_v29.html": {
      title: "Golden Runtime Object Stack",
      text: "Oggetti di controllo qualità: backend, frontend, manifest, evidence, runtime health e regressione.",
      objects: ["golden","evidence","cloud","core","fiber"],
      flow: ["Health", "Manifest", "HTTP", "Runtime", "Evidence", "Baseline"],
      anchor: "main"
    },
    "trfmc_visual_qa_matrix_v71.html": {
      title: "Visual QA Object Stack",
      text: "Oggetti di governance visuale: shell, component library, evidence, golden baseline e quality matrix.",
      objects: ["evidence","golden","cloud","gnb","core"],
      flow: ["Page", "Object", "Shell", "QA", "Evidence", "Decision"],
      anchor: "main"
    }
  };

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function isPreview(){
    try { return new URLSearchParams(location.search).get("preview") === "1"; }
    catch(e){ return false; }
  }

  function page(){
    return location.pathname.split("/").pop() || "index.html";
  }

  function objectCard(key){
    const o = OBJECTS[key];
    if(!o) return "";
    const [name, desc, layer, cls, html] = o;
    const critical = ["power","rru","core","evidence","golden"].includes(key);
    return `
      <article class="v78-object-card" data-v78-object="${key}" data-critical="${critical ? "true" : "false"}">
        <div class="v78-object-visual ${cls}">${html}</div>
        <h3>${name}</h3>
        <p>${desc}</p>
        <small>${layer}</small>
      </article>
    `;
  }

  function buildStack(cfg){
    const s = document.createElement("section");
    s.className = "v78-object-stack";
    s.dataset.v78 = VERSION;
    s.innerHTML = `
      <div class="v78-stack-head">
        <div>
          <h2>${cfg.title}</h2>
          <p>${cfg.text}</p>
        </div>
        <a href="/rf_telco_component_library_v76.html">Component Library</a>
      </div>
      <div class="v78-object-row">
        ${cfg.objects.map(objectCard).join("")}
      </div>
    `;
    return s;
  }

  function buildFlow(cfg){
    const f = document.createElement("section");
    f.className = "v78-domain-flow";
    f.innerHTML = `
      <div class="v78-flow-title">Domain Flow</div>
      <div class="v78-flow-row">
        ${cfg.flow.map(x => `<div class="v78-flow-node">${x}</div>`).join("")}
      </div>
    `;
    return f;
  }

  function insert(){
    if(isPreview()) return;

    const cfg = CONFIG[page()];
    if(!cfg) return;
    if(document.querySelector(".v78-object-stack")) return;

    const stack = buildStack(cfg);
    const flow = buildFlow(cfg);

    const anchor = document.querySelector(cfg.anchor);
    if(anchor && anchor !== document.body){
      anchor.prepend(flow);
      anchor.prepend(stack);
    } else {
      document.body.prepend(flow);
      document.body.prepend(stack);
    }

    document.body.dataset.v78Objects = cfg.objects.join(",");
  }

  ready(() => {
    document.body.classList.add("v78-full-object-completion");
    insert();

    if(!document.title.includes("v0.78A")){
      document.title = "TRFMC v0.78A Objects · " + document.title;
    }

    document.body.dataset.v78 = VERSION;
  });
})();
