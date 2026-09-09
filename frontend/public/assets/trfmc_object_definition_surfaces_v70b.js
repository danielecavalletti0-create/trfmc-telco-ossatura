(function(){
  const VERSION = "TRFMC_V0_70B_OBJECT_DEFINITION_ORGANIC_SURFACES";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function currentPage(){
    return (location.pathname.split("/").pop() || "index.html").replace(".html","");
  }

  function addDefinitionStrip(){
    if(document.querySelector(".v70b-definition-strip")) return;

    const strip = document.createElement("div");
    strip.className = "v70b-definition-strip";
    strip.innerHTML = `
      <i></i><span>Object System</span>
      <b id="v70b_page">${currentPage()}</b>
      <span>· surfaces: defined</span>
      <span>· geometry: organic</span>
      <span>· random edges: reduced</span>
    `;
    document.body.appendChild(strip);
  }

  function classifyObjects(){
    const selectors = [
      ".panel",
      "article",
      ".metric-grid article",
      ".mini-card",
      ".v65-kpis div",
      ".diag-grid div",
      ".v66-status div",
      ".v66-kpi-grid div",
      ".hero-kpi div"
    ];

    let count = 0;

    selectors.forEach(sel => {
      document.querySelectorAll(sel).forEach((el, idx) => {
        el.classList.add("v70b-object-surface");
        el.dataset.v70bObject = el.dataset.v70bObject || `${sel.replace(/[^a-z0-9]/gi,"")}_${idx}`;
        count++;
      });
    });

    document.body.dataset.v70bObjects = String(count);
  }

  function normalizeLabels(){
    document.querySelectorAll("h2,h3").forEach(h => {
      if(!h.dataset.v70bNormalized){
        h.dataset.v70bNormalized = "true";
      }
    });
  }

  function bindModes(){
    if(document.body.dataset.v70bBound === "true") return;
    document.body.dataset.v70bBound = "true";

    document.addEventListener("keydown", e => {
      if(e.altKey && e.key.toLowerCase() === "d"){
        document.body.classList.toggle("trfmc-v70b-dense");
        localStorage.setItem("trfmc_v70b_dense", document.body.classList.contains("trfmc-v70b-dense") ? "1" : "0");
      }
      if(e.altKey && e.key.toLowerCase() === "c"){
        document.body.classList.toggle("trfmc-v70b-calibrated");
        localStorage.setItem("trfmc_v70b_calibrated", document.body.classList.contains("trfmc-v70b-calibrated") ? "1" : "0");
      }
    });

    if(localStorage.getItem("trfmc_v70b_dense") === "1") document.body.classList.add("trfmc-v70b-dense");
    if(localStorage.getItem("trfmc_v70b_calibrated") === "1") document.body.classList.add("trfmc-v70b-calibrated");
  }

  function visualAudit(){
    const sharpCandidates = Array.from(document.querySelectorAll("*")).filter(el => {
      const cs = getComputedStyle(el);
      const w = el.getBoundingClientRect().width;
      const h = el.getBoundingClientRect().height;
      const br = parseFloat(cs.borderRadius || "0");
      return w > 140 && h > 60 && br < 12 && cs.display !== "inline";
    }).length;

    const strip = document.querySelector(".v70b-definition-strip");
    if(strip){
      const s = document.createElement("span");
      s.textContent = "· sharp candidates: " + Math.min(sharpCandidates, 99);
      strip.appendChild(s);
    }
  }

  ready(() => {
    document.body.classList.add("trfmc-v70b-object-system");
    addDefinitionStrip();
    classifyObjects();
    normalizeLabels();
    bindModes();
    setTimeout(visualAudit, 400);

    document.title = document.title.includes("v0.70B")
      ? document.title
      : "TRFMC v0.70B Object System · " + document.title;
  });
})();
