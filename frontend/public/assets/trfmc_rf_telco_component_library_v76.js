(function(){
  const VERSION = "TRFMC_V0_76A_RF_TELCO_COMPONENT_OBJECT_LIBRARY";

  const objects = [
    {
      id: "tower",
      name: "Telecom Lattice Tower",
      domain: "physical",
      layer: "Site Infrastructure",
      status: "Reusable",
      reuse: "Digital Twin / Field",
      desc: "Struttura portante per settori antenna, apparati RRU, microwave e cablaggi AISG/fibra.",
      tags: ["tower","mast","site"],
      targets: ["Infrastructure Digital Twin", "Field Engineering", "Executive Dashboard"],
      cls: "obj-tower",
      html: '<div class="truss"></div><div class="mast"></div><div class="pulse"></div>'
    },
    {
      id: "antenna",
      name: "Sector Antenna Panel",
      domain: "radio",
      layer: "RAN / RF",
      status: "Reusable",
      reuse: "Handover / Propagation",
      desc: "Pannello antenna settoriale con azimuth, tilt, beamwidth e relazione diretta con copertura e handover.",
      tags: ["antenna","sector","beam"],
      targets: ["UE Handover", "RF Propagation", "Digital Twin"],
      cls: "obj-antenna",
      html: '<div class="panel p1"></div><div class="panel p2"></div><div class="pulse"></div>'
    },
    {
      id: "rru",
      name: "Remote Radio Unit",
      domain: "radio",
      layer: "RF Front-End",
      status: "Reusable",
      reuse: "Digital Twin / Alarm",
      desc: "Unità radio remota: PA, duplexer/filter chain, temperatura, fault, power state e KPI RF.",
      tags: ["RRU","PA","fault"],
      targets: ["Infrastructure Digital Twin", "Field Engineering", "Alarm Console"],
      cls: "obj-rru",
      html: '<div class="box"></div><div class="pulse"></div>'
    },
    {
      id: "ret",
      name: "RET / AISG Controller",
      domain: "radio",
      layer: "Antenna Control",
      status: "Reusable",
      reuse: "Field / Optimization",
      desc: "Controllo tilt remoto e calibrazione AISG: oggetto operativo per ottimizzazione e fault isolation.",
      tags: ["RET","AISG","tilt"],
      targets: ["Digital Twin", "Field Engineering", "RF Optimization"],
      cls: "obj-ret",
      html: '<div class="box"></div><div class="pulse"></div>'
    },
    {
      id: "microwave",
      name: "Microwave Backhaul Dish",
      domain: "transport",
      layer: "Backhaul",
      status: "Reusable",
      reuse: "Transport / Field",
      desc: "Link microwave punto-punto per backhaul: allineamento, fade margin, availability e degradazione meteo.",
      tags: ["MW","backhaul","link"],
      targets: ["Digital Twin", "Transport Dashboard", "Evidence"],
      cls: "obj-mw",
      html: '<div class="dish"></div><div class="pulse"></div>'
    },
    {
      id: "fiber",
      name: "Fiber Transport Link",
      domain: "transport",
      layer: "Fronthaul/Backhaul",
      status: "Reusable",
      reuse: "Transport / Core",
      desc: "Collegamento ottico per fronthaul/backhaul: loss budget, ODF, uplink e path continuity.",
      tags: ["fiber","ODF","transport"],
      targets: ["Digital Twin", "Core View", "Field Engineering"],
      cls: "obj-fiber",
      html: '<div class="line"></div><div class="pulse"></div>'
    },
    {
      id: "shelter",
      name: "Shelter / Edge Cabinet",
      domain: "physical",
      layer: "Site / Edge",
      status: "Reusable",
      reuse: "Digital Twin",
      desc: "Shelter o cabinet contenente BBU/edge, cooling, power distribution e sistemi di controllo.",
      tags: ["shelter","edge","cooling"],
      targets: ["Digital Twin", "Field Engineering", "Executive Dashboard"],
      cls: "obj-shelter",
      html: '<div class="box"></div><div class="pulse"></div>'
    },
    {
      id: "power",
      name: "-48 VDC Power Chain",
      domain: "physical",
      layer: "Power",
      status: "Reusable",
      reuse: "Field / Alarm",
      desc: "Catena energetica di sito: rettificatore, batterie, autonomia, breaker, allarmi e continuità servizio.",
      tags: ["power","battery","-48V"],
      targets: ["Field Engineering", "Digital Twin", "Alarm Console"],
      cls: "obj-power",
      html: '<div class="box"></div><div class="pulse"></div>'
    },
    {
      id: "ue",
      name: "UE / V2X Device",
      domain: "radio",
      layer: "Access / Mobility",
      status: "Reusable",
      reuse: "Handover / Mobility",
      desc: "Terminale utente o V2X: traiettoria, serving cell, candidate cell, RSRP/SINR e rischio drop.",
      tags: ["UE","V2X","mobility"],
      targets: ["UE Handover", "RF Heatmap", "Knowledge OS"],
      cls: "obj-ue",
      html: '<div class="phone"></div><div class="pulse"></div>'
    },
    {
      id: "gnb",
      name: "gNB Logical Node",
      domain: "radio",
      layer: "5G RAN",
      status: "Reusable",
      reuse: "RAN / Protocol",
      desc: "Nodo gNB logico: NGAP/N2, GTP-U/N3, cell identity, scheduling e RAN state.",
      tags: ["gNB","RAN","NGAP"],
      targets: ["Protocol Console", "UE Handover", "Executive Dashboard"],
      cls: "obj-gnb",
      html: '<div class="node"></div><div class="pulse"></div>'
    },
    {
      id: "core",
      name: "5GC Service Core",
      domain: "core",
      layer: "AMF/SMF/UPF",
      status: "Reusable",
      reuse: "Core / Protocol",
      desc: "Oggetto logico 5GC per AMF, SMF, UPF, NRF, AUSF e correlazione eventi protocollo.",
      tags: ["5GC","AMF","UPF"],
      targets: ["Core Console", "Protocol Console", "Executive Dashboard"],
      cls: "obj-core",
      html: '<div class="node"></div><div class="pulse"></div>'
    },
    {
      id: "cloud",
      name: "Cloud / Edge Compute",
      domain: "core",
      layer: "Cloud Native",
      status: "Reusable",
      reuse: "Core / Observability",
      desc: "Cloud/edge domain per servizi containerizzati, observability, workload e runtime posture.",
      tags: ["cloud","edge","k8s"],
      targets: ["Executive Dashboard", "Core Console", "Knowledge OS"],
      cls: "obj-cloud",
      html: '<div class="node"></div><div class="pulse"></div>'
    },
    {
      id: "evidence",
      name: "Evidence Recorder",
      domain: "operations",
      layer: "Evidence / QA",
      status: "Reusable",
      reuse: "Audit / Report",
      desc: "Oggetto di raccolta evidenze: snapshot, log, metriche, report, QA e tracciabilità laboratorio.",
      tags: ["evidence","QA","report"],
      targets: ["Visual QA", "Golden Check", "Executive Dashboard"],
      cls: "obj-evidence",
      html: '<div class="node"></div><div class="pulse"></div>'
    }
  ];

  const $ = id => document.getElementById(id);

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function renderCard(obj){
    return `
      <article class="v76-object-card" data-id="${obj.id}" data-domain="${obj.domain}">
        <div class="v76-object-visual ${obj.cls}">
          ${obj.html}
        </div>
        <h3>${obj.name}</h3>
        <p>${obj.desc}</p>
        <div class="v76-tags">
          ${obj.tags.map(t => `<span>${t}</span>`).join("")}
        </div>
      </article>
    `;
  }

  function render(filter="all"){
    const filtered = filter === "all" ? objects : objects.filter(o => o.domain === filter);
    $("v76_object_grid").innerHTML = filtered.map(renderCard).join("");
    $("v76_gallery_count").textContent = filtered.length + " objects";

    document.querySelectorAll(".v76-object-card").forEach(card => {
      card.addEventListener("click", () => selectObject(card.dataset.id));
    });

    if(filtered[0]) selectObject(filtered[0].id);
  }

  function selectObject(id){
    const obj = objects.find(o => o.id === id);
    if(!obj) return;

    document.querySelectorAll(".v76-object-card").forEach(c => c.classList.toggle("active", c.dataset.id === id));

    $("v76_selected_label").textContent = obj.name;
    $("v76_preview_stage").className = "v76-preview-stage " + obj.cls;
    $("v76_preview_stage").innerHTML = obj.html;

    $("v76_sheet_title").textContent = obj.name;
    $("v76_sheet_desc").textContent = obj.desc;
    $("v76_kpi_domain").textContent = obj.domain;
    $("v76_kpi_layer").textContent = obj.layer;
    $("v76_kpi_status").textContent = obj.status;
    $("v76_kpi_reuse").textContent = obj.reuse;

    $("v76_targets").innerHTML = obj.targets.map(t => `<li>${t}</li>`).join("");
  }

  function bindFilters(){
    document.querySelectorAll("[data-filter]").forEach(btn => {
      btn.addEventListener("click", () => {
        document.querySelectorAll("[data-filter]").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        render(btn.dataset.filter);
      });
    });
  }

  function score(){
    const readiness = Math.round(82 + Math.min(14, objects.length));
    $("v76_score").textContent = readiness + "%";
    $("v76_score_label").textContent = objects.length + " reusable RF/Telco objects";
  }

  ready(() => {
    bindFilters();
    render("all");
    score();
    document.body.dataset.v76 = VERSION;
  });
})();
