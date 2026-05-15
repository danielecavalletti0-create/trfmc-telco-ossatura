(function(){
  const VERSION = "TRFMC_V0_77A_COMPONENT_OBJECT_INTEGRATION_PACK";

  const OBJECTS = {
    tower: {
      name: "Tower",
      desc: "Supporto fisico per settori, RRU, microwave, cablaggi e vincoli meccanici.",
      layer: "Physical Site",
      cls: "v77-visual-tower",
      html: '<div class="truss"></div><div class="mast"></div><div class="v77-pulse"></div>'
    },
    antenna: {
      name: "Antenna Panel",
      desc: "Settore RF con azimuth, tilt, beamwidth, gain e footprint di copertura.",
      layer: "RF/RAN",
      cls: "v77-visual-antenna",
      html: '<div class="panel p1"></div><div class="panel p2"></div><div class="v77-pulse"></div>'
    },
    rru: {
      name: "RRU",
      desc: "RF front-end remoto: PA, filtri, temperatura, fault, potenza e KPI radio.",
      layer: "RF Front-End",
      cls: "v77-visual-rru",
      html: '<div class="box"></div><div class="v77-pulse"></div>'
    },
    ret: {
      name: "RET/AISG",
      desc: "Tilt remoto, calibrazione antenna, allineamento e ottimizzazione settore.",
      layer: "Antenna Control",
      cls: "v77-visual-ret",
      html: '<div class="box"></div><div class="v77-pulse"></div>'
    },
    microwave: {
      name: "Microwave",
      desc: "Backhaul punto-punto con allineamento, fade margin e availability.",
      layer: "Transport",
      cls: "v77-visual-mw",
      html: '<div class="dish"></div><div class="v77-pulse"></div>'
    },
    fiber: {
      name: "Fiber Link",
      desc: "Trasporto ottico per fronthaul/backhaul, ODF, path continuity e loss budget.",
      layer: "Transport",
      cls: "v77-visual-fiber",
      html: '<div class="line"></div><div class="v77-pulse"></div>'
    },
    shelter: {
      name: "Shelter",
      desc: "Cabinet/shelter con BBU, edge compute, cooling e apparati di sito.",
      layer: "Physical / Edge",
      cls: "v77-visual-shelter",
      html: '<div class="box"></div><div class="v77-pulse"></div>'
    },
    power: {
      name: "-48 VDC",
      desc: "Rettificatori, batterie, breaker, autonomia e continuità di servizio.",
      layer: "Power",
      cls: "v77-visual-power",
      html: '<div class="box"></div><div class="v77-pulse"></div>'
    },
    ue: {
      name: "UE/V2X",
      desc: "Terminale mobile: serving cell, candidate cell, RSRP/SINR e rischio drop.",
      layer: "Access / Mobility",
      cls: "v77-visual-ue",
      html: '<div class="phone"></div><div class="v77-pulse"></div>'
    },
    gnb: {
      name: "gNB",
      desc: "Nodo RAN logico con cell identity, scheduling, NGAP/N2 e GTP-U/N3.",
      layer: "5G RAN",
      cls: "v77-visual-gnb",
      html: '<div class="node"></div><div class="v77-pulse"></div>'
    },
    core: {
      name: "5GC",
      desc: "AMF/SMF/UPF/NRF/AUSF: sessione, registrazione, policy e user plane.",
      layer: "5G Core",
      cls: "v77-visual-core",
      html: '<div class="node"></div><div class="v77-pulse"></div>'
    },
    cloud: {
      name: "Cloud/Edge",
      desc: "Runtime cloud-native, workload, osservabilità, container e servizi edge.",
      layer: "Cloud Native",
      cls: "v77-visual-cloud",
      html: '<div class="node"></div><div class="v77-pulse"></div>'
    },
    evidence: {
      name: "Evidence",
      desc: "Snapshot, log, metriche, QA, report e tracciabilità del laboratorio.",
      layer: "Governance",
      cls: "v77-visual-evidence",
      html: '<div class="node"></div><div class="v77-pulse"></div>'
    }
  };

  const PAGE_CONFIG = {
    "webgl_rf_heatmap_engine_v69.html": {
      title: "UE Mobility Object Stack",
      text: "Oggetti di dominio integrati nella pagina handover: UE, gNB, settore antenna, trasporto e core. Servono a rendere visibile il percorso decisionale mobility/RF senza introdurre overlay o rumore grafico.",
      objects: ["ue","gnb","antenna","fiber","core","evidence"],
      flow: ["UE", "RSRP/SINR", "Candidate Cell", "Handover", "5GC Session", "Evidence"],
      anchor: ".v74-ue-mission-strip"
    },
    "infrastructure_digital_twin_v63.html": {
      title: "Telecom Site Object Stack",
      text: "Oggetti fisici e logici del sito radio: torre, antenna, RRU, RET/AISG, microwave, fibra, shelter e catena -48 VDC. La pagina diventa un digital twin leggibile e non una composizione casuale.",
      objects: ["tower","antenna","rru","ret","microwave","fiber","shelter","power"],
      flow: ["Power", "Shelter", "BBU/Edge", "RRU", "Antenna", "RF Coverage", "Backhaul"],
      anchor: ".v74-site-operational-ribbon"
    },
    "executive_mission_dashboard_v_next.html": {
      title: "Executive Mission Object Stack",
      text: "Sintesi oggetti per la plancia executive: accesso radio, core, cloud/edge, trasporto ed evidence. Riduce la frammentazione visiva e collega le KPI a oggetti reali.",
      objects: ["gnb","ue","core","cloud","fiber","evidence"],
      flow: ["RAN", "Mobility", "5GC", "Cloud/Edge", "Transport", "Evidence"],
      anchor: "main"
    },
    "rf_telco_knowledge_os_v60.html": {
      title: "Knowledge Object Stack",
      text: "Oggetti didattici agganciati ai moduli teorici: antenna, propagazione, RRU, gNB, UE, core e trasporto. Ogni concetto deve avere un riferimento visivo-operativo.",
      objects: ["antenna","rru","gnb","ue","core","fiber"],
      flow: ["Physics", "Antenna", "RF Chain", "RAN", "Mobility", "Core"],
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

  function card(key){
    const o = OBJECTS[key];
    return `
      <article class="v77-object-card" data-v77-object="${key}" data-critical="${["power","rru","core","evidence"].includes(key)}">
        <div class="v77-object-visual ${o.cls}">
          ${o.html}
        </div>
        <h3>${o.name}</h3>
        <p>${o.desc}</p>
        <small>${o.layer}</small>
      </article>
    `;
  }

  function buildStack(cfg){
    const section = document.createElement("section");
    section.className = "v77-object-stack";
    section.dataset.v77 = VERSION;
    section.innerHTML = `
      <div class="v77-stack-head">
        <div>
          <h2>${cfg.title}</h2>
          <p>${cfg.text}</p>
        </div>
        <a href="/rf_telco_component_library_v76.html">Open Component Library</a>
      </div>
      <div class="v77-object-row">
        ${cfg.objects.map(card).join("")}
      </div>
    `;
    return section;
  }

  function buildMap(cfg){
    const map = document.createElement("section");
    map.className = "v77-system-map";
    map.innerHTML = `
      <div class="v77-map-title">Operational Object Flow</div>
      <div class="v77-map-flow">
        ${cfg.flow.map(x => `<div class="v77-map-node">${x}</div>`).join("")}
      </div>
    `;
    return map;
  }

  function insertForPage(){
    if(isPreview()) return;

    const cfg = PAGE_CONFIG[page()];
    if(!cfg) return;
    if(document.querySelector(".v77-object-stack")) return;

    const stack = buildStack(cfg);
    const map = buildMap(cfg);

    const anchor = document.querySelector(cfg.anchor);
    if(anchor && anchor !== document.body){
      anchor.insertAdjacentElement("afterend", map);
      anchor.insertAdjacentElement("afterend", stack);
    } else {
      const main = document.querySelector("main") || document.body;
      main.prepend(map);
      main.prepend(stack);
    }

    document.body.classList.add("v77-object-integrated");
    document.body.dataset.v77Objects = cfg.objects.join(",");
  }

  ready(() => {
    document.body.classList.add("v77-object-integrated");
    insertForPage();

    if(!document.title.includes("v0.77A")){
      document.title = "TRFMC v0.77A Objects · " + document.title;
    }

    document.body.dataset.v77 = VERSION;
  });
})();
