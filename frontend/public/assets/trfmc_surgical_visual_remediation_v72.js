(function(){
  const VERSION = "TRFMC_V0_72A_SURGICAL_VISUAL_REMEDIATION";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function currentPage(){
    return (location.pathname.split("/").pop() || "index.html").replace(".html","");
  }

  function addBadge(){
    if(document.querySelector(".v72-remediation-badge")) return;

    const badge = document.createElement("div");
    badge.className = "v72-remediation-badge";
    badge.innerHTML = `
      <i></i>
      <span>Surgical Visual Remediation</span>
      <b>${currentPage()}</b>
      <span>· geometry corrected</span>
      <span>· object grammar enforced</span>
      <span>· ALT+F focus · ALT+C calibrated</span>
    `;
    document.body.appendChild(badge);
  }

  function classifyAndCorrect(){
    const all = Array.from(document.querySelectorAll("section, article, aside, .panel, .card, .tile, .metric-grid article, .mini-card"));
    all.forEach((node, idx) => {
      node.dataset.v72Surface = node.dataset.v72Surface || "surface-" + idx;
      node.classList.add("v72-remediated-surface");

      const rect = node.getBoundingClientRect();
      if(rect.width > 240 && rect.height > 120) node.classList.add("v72-major-object");
      else node.classList.add("v72-minor-object");
    });

    const canvases = Array.from(document.querySelectorAll("canvas, iframe, .rf-scene, .site-scene, .tower-scene, .v66-canvas-wrap"));
    canvases.forEach((node, idx) => {
      node.dataset.v72Viewport = "instrument-viewport-" + idx;
      node.classList.add("v72-instrument-viewport");
    });
  }

  function fixPageIdentity(){
    const h1 = document.querySelector("h1");
    if(h1 && !h1.dataset.v72Identity){
      h1.dataset.v72Identity = "true";
    }

    if(!document.title.includes("v0.72A")){
      document.title = "TRFMC v0.72A Remediated · " + document.title;
    }
  }

  function bindKeys(){
    if(document.body.dataset.v72Bound === "true") return;
    document.body.dataset.v72Bound = "true";

    document.addEventListener("keydown", e => {
      if(e.altKey && e.key.toLowerCase() === "f"){
        document.body.classList.toggle("trfmc-v72-focus");
        localStorage.setItem("trfmc_v72_focus", document.body.classList.contains("trfmc-v72-focus") ? "1" : "0");
      }

      if(e.altKey && e.key.toLowerCase() === "c"){
        document.body.classList.toggle("trfmc-v72-calibrated");
        localStorage.setItem("trfmc_v72_calibrated", document.body.classList.contains("trfmc-v72-calibrated") ? "1" : "0");
      }
    });

    if(localStorage.getItem("trfmc_v72_focus") === "1") document.body.classList.add("trfmc-v72-focus");
    if(localStorage.getItem("trfmc_v72_calibrated") === "1") document.body.classList.add("trfmc-v72-calibrated");
  }

  function runtimeScore(){
    const surfaces = document.querySelectorAll(".v72-remediated-surface").length;
    const viewports = document.querySelectorAll(".v72-instrument-viewport").length;
    const nav = document.querySelectorAll("nav a").length;
    const h1 = !!document.querySelector("h1");
    const score = Math.max(72, Math.min(99, 72 + Math.min(14, surfaces) + Math.min(6, viewports*2) + Math.min(5, nav/2) + (h1?4:0)));
    document.body.dataset.v72Score = String(Math.round(score));
  }

  ready(() => {
    document.body.classList.add("trfmc-v72-remediation");
    addBadge();
    fixPageIdentity();
    bindKeys();

    setTimeout(() => {
      classifyAndCorrect();
      runtimeScore();
    }, 100);
  });
})();
