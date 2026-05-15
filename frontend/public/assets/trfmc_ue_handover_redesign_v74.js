(function(){
  const VERSION = "TRFMC_V0_74A_UE_HANDOVER_PAGE_SPECIFIC_REDESIGN";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function isPreview(){
    try { return new URLSearchParams(location.search).get("preview") === "1"; }
    catch(e){ return false; }
  }

  function insertMissionStrip(){
    if(document.querySelector(".v74-ue-mission-strip")) return;

    const strip = document.createElement("section");
    strip.className = "v74-ue-mission-strip";
    strip.innerHTML = `
      <div>
        <h2>UE Mobility / Handover Operating View</h2>
        <p>
          Vista pagina-specifica: UE in movimento, celle candidate, serving cell, clutter urbano/vegetazione,
          RSRP/RSRQ/SINR, trigger A3/A5, handover preparation, execution e KPI di continuità servizio.
        </p>
      </div>
      <div class="v74-ue-flow">
        <div class="v74-ue-step"><b>UE</b><span>trajectory, speed, serving cell</span></div>
        <div class="v74-ue-step"><b>Measure</b><span>RSRP / RSRQ / SINR window</span></div>
        <div class="v74-ue-step"><b>Event</b><span>A3/A5 threshold, hysteresis, TTT</span></div>
        <div class="v74-ue-step"><b>HO</b><span>prepare, execute, complete</span></div>
        <div class="v74-ue-step"><b>KPI</b><span>drop risk, ping-pong, outage</span></div>
      </div>
    `;

    const anchor = document.querySelector("main, .v69-app, .dashboard, body");
    if(anchor && anchor !== document.body) anchor.prepend(strip);
    else document.body.insertBefore(strip, document.body.firstChild);
  }

  function insertLegend(){
    if(document.querySelector(".v74-handover-legend")) return;

    const legend = document.createElement("section");
    legend.className = "v74-handover-legend";
    legend.innerHTML = `
      <div class="ok"><b>Serving Cell</b><span>Primary radio link and control-plane anchor.</span></div>
      <div><b>Candidate Cell</b><span>Neighbor selected by measurement report window.</span></div>
      <div class="warn"><b>Risk Zone</b><span>Shadowing, clutter or vegetation may trigger degradation.</span></div>
      <div class="crit"><b>Failure Mode</b><span>Radio link failure, late HO, ping-pong or outage.</span></div>
    `;

    const strip = document.querySelector(".v74-ue-mission-strip");
    if(strip) strip.insertAdjacentElement("afterend", legend);
  }

  function markPageObjects(){
    document.querySelectorAll("canvas, .panel, section, article, aside").forEach((el, idx) => {
      el.dataset.v74Object = el.dataset.v74Object || `ue-object-${idx}`;
    });
  }

  ready(() => {
    document.body.classList.add("v74-ue-redesign");

    if(!isPreview()){
      insertMissionStrip();
      insertLegend();
    }

    markPageObjects();

    if(!document.title.includes("v0.74A")){
      document.title = "TRFMC v0.74A UE Handover · " + document.title;
    }

    document.body.dataset.v74Ue = VERSION;
  });
})();
