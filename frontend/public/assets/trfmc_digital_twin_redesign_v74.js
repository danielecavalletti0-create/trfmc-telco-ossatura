(function(){
  const VERSION = "TRFMC_V0_74A_DIGITAL_TWIN_PAGE_SPECIFIC_REDESIGN";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function isPreview(){
    try { return new URLSearchParams(location.search).get("preview") === "1"; }
    catch(e){ return false; }
  }

  function insertRibbon(){
    if(document.querySelector(".v74-site-operational-ribbon")) return;

    const ribbon = document.createElement("section");
    ribbon.className = "v74-site-operational-ribbon";
    ribbon.innerHTML = `
      <div>
        <h2>Telecom Site Digital Twin Operating View</h2>
        <p>
          Vista pagina-specifica del sito radio: struttura fisica, settori antenna, RRU, RET/AISG,
          backhaul microwave/fiber, shelter, alimentazione -48 VDC, thermal posture e catena allarmi.
        </p>
      </div>
      <div class="v74-site-stack">
        <div><b>Antenna</b><span>sector, azimuth, tilt, beamwidth</span></div>
        <div><b>RRU</b><span>RF front-end, PA, thermal state</span></div>
        <div><b>RET/AISG</b><span>tilt control and calibration</span></div>
        <div><b>Backhaul</b><span>MW path and fiber transport</span></div>
        <div><b>Shelter</b><span>BBU, edge, cooling, cabinet</span></div>
        <div><b>Power</b><span>-48 VDC, rectifier, battery</span></div>
      </div>
    `;

    const anchor = document.querySelector("main, .dashboard, body");
    if(anchor && anchor !== document.body) anchor.prepend(ribbon);
    else document.body.insertBefore(ribbon, document.body.firstChild);
  }

  function insertCallouts(){
    if(document.querySelector(".v74-site-callouts")) return;

    const callouts = document.createElement("section");
    callouts.className = "v74-site-callouts";
    callouts.innerHTML = `
      <div class="ok"><b>Physical Layer</b><span>Site geometry drives coverage, overlap, isolation and service continuity.</span></div>
      <div><b>Protocol Mapping</b><span>RF/site state maps to cell identity, handover, QoS and alarm posture.</span></div>
      <div class="warn"><b>Failure Chain</b><span>Power, RET, RRU thermal and backhaul faults propagate to user experience.</span></div>
      <div><b>Field Action</b><span>Inspect object, correlate metric, confirm fault, execute controlled remediation.</span></div>
    `;

    const ribbon = document.querySelector(".v74-site-operational-ribbon");
    if(ribbon) ribbon.insertAdjacentElement("afterend", callouts);
  }

  function markObjects(){
    const names = [".antenna",".rru",".ret",".microwave",".shelter",".power",".site-scene",".detail-panel"];
    names.forEach(sel => {
      document.querySelectorAll(sel).forEach((el, idx) => {
        el.dataset.v74TwinObject = `${sel.replace(".","")}-${idx}`;
      });
    });
  }

  ready(() => {
    document.body.classList.add("v74-twin-redesign");

    if(!isPreview()){
      insertRibbon();
      insertCallouts();
    }

    markObjects();

    if(!document.title.includes("v0.74A")){
      document.title = "TRFMC v0.74A Digital Twin · " + document.title;
    }

    document.body.dataset.v74Twin = VERSION;
  });
})();
