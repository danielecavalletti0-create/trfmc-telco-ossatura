(function(){
  const VERSION = "TRFMC_V0_79A_OBJECT_STACK_GOVERNANCE_COMPACT_EXPERT_MODE";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function isPreview(){
    try { return new URLSearchParams(location.search).get("preview") === "1"; }
    catch(e){ return false; }
  }

  function hasObjectStack(){
    return !!document.querySelector(".v77-object-stack,.v78-object-stack");
  }

  function addControls(){
    if(isPreview()) return;
    if(document.querySelector(".v79-object-controls")) return;

    const heads = document.querySelectorAll(".v77-stack-head,.v78-stack-head");
    heads.forEach(head => {
      const controls = document.createElement("div");
      controls.className = "v79-object-controls";
      controls.innerHTML = `
        <button type="button" data-v79-action="expand">Expand Objects</button>
        <button type="button" data-v79-action="hide">Hide Objects</button>
        <button type="button" data-v79-action="calibrate">Low Motion</button>
      `;
      head.appendChild(controls);
    });
  }

  function applySaved(){
    if(localStorage.getItem("trfmc_v79_expanded") === "1") document.body.classList.add("v79-object-expanded");
    if(localStorage.getItem("trfmc_v79_hidden") === "1") document.body.classList.add("v79-object-hidden");
    if(localStorage.getItem("trfmc_v79_calibrated") === "1") document.body.classList.add("trfmc-v75-calibrated");
  }

  function syncButtons(){
    document.querySelectorAll('[data-v79-action="expand"]').forEach(b => {
      b.classList.toggle("active", document.body.classList.contains("v79-object-expanded"));
      b.textContent = document.body.classList.contains("v79-object-expanded") ? "Compact Objects" : "Expand Objects";
    });

    document.querySelectorAll('[data-v79-action="hide"]').forEach(b => {
      b.classList.toggle("active", document.body.classList.contains("v79-object-hidden"));
      b.textContent = document.body.classList.contains("v79-object-hidden") ? "Show Objects" : "Hide Objects";
    });

    document.querySelectorAll('[data-v79-action="calibrate"]').forEach(b => {
      b.classList.toggle("active", document.body.classList.contains("trfmc-v75-calibrated"));
    });
  }

  function bind(){
    document.addEventListener("click", e => {
      const btn = e.target.closest("[data-v79-action]");
      if(!btn) return;

      const action = btn.dataset.v79Action;

      if(action === "expand"){
        document.body.classList.toggle("v79-object-expanded");
        localStorage.setItem("trfmc_v79_expanded", document.body.classList.contains("v79-object-expanded") ? "1" : "0");
      }

      if(action === "hide"){
        document.body.classList.toggle("v79-object-hidden");
        localStorage.setItem("trfmc_v79_hidden", document.body.classList.contains("v79-object-hidden") ? "1" : "0");
      }

      if(action === "calibrate"){
        document.body.classList.toggle("trfmc-v75-calibrated");
        localStorage.setItem("trfmc_v79_calibrated", document.body.classList.contains("trfmc-v75-calibrated") ? "1" : "0");
      }

      syncButtons();
    });

    document.addEventListener("keydown", e => {
      if(!e.altKey) return;

      if(e.key.toLowerCase() === "o"){
        document.body.classList.toggle("v79-object-expanded");
        localStorage.setItem("trfmc_v79_expanded", document.body.classList.contains("v79-object-expanded") ? "1" : "0");
        syncButtons();
      }

      if(e.key.toLowerCase() === "h"){
        document.body.classList.toggle("v79-object-hidden");
        localStorage.setItem("trfmc_v79_hidden", document.body.classList.contains("v79-object-hidden") ? "1" : "0");
        syncButtons();
      }
    });
  }

  function audit(){
    const stacks = document.querySelectorAll(".v77-object-stack,.v78-object-stack").length;
    const maps = document.querySelectorAll(".v77-system-map,.v78-domain-flow").length;
    const cards = document.querySelectorAll(".v77-object-card,.v78-object-card").length;
    document.body.dataset.v79Stacks = String(stacks);
    document.body.dataset.v79Maps = String(maps);
    document.body.dataset.v79Cards = String(cards);
  }

  ready(() => {
    document.body.classList.add("v79-object-governance");

    if(hasObjectStack()){
      applySaved();
      addControls();
      bind();
      syncButtons();
      audit();
    }

    if(!document.title.includes("v0.79A")){
      document.title = "TRFMC v0.79A Governed · " + document.title;
    }

    document.body.dataset.v79 = VERSION;
  });
})();
