(function(){
  const VERSION = "TRFMC_V0_52A_EXECUTIVE_VISUAL_CORRECTION_PASS";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function setText(selector, value){
    const el = document.querySelector(selector);
    if(el) el.textContent = value;
  }

  function normalizeHero(){
    setText(".hero h1", "TRFMC EXECUTIVE MISSION DASHBOARD");

    const p = document.querySelector(".hero p");
    if(p){
      p.textContent =
        "v0.52A · visual correction pass: dashboard executive consolidata e rifinita per revisione finale. Master Index compatto, RF/Telco intelligence dominante, Scenario Command operativo, KPI leggibili, Runtime JSON nascosto in Executive View.";
    }
  }

  function updateReviewBand(){
    const band = document.querySelector(".v51-review-band p");
    if(band){
      band.textContent =
        VERSION + " · correzione visiva: riduzione altezza sezioni, gerarchia più chiara, Master Index compatto, runtime avanzato nascosto e priorità a RF/Telco, Scenario Command e KPI Wall.";
    }
  }

  function normalizeFooter(){
    const footers = Array.from(document.querySelectorAll("footer"));
    footers.forEach(f => {
      if((f.textContent || "").includes("TRFMC v0.51A") || (f.textContent || "").includes("TRFMC v0.50A")){
        f.textContent = "TRFMC v0.52A · Executive Visual Correction Pass · frontend-only · localhost-only";
      }
    });
  }

  function markLegacyGhosts(){
    const nodes = Array.from(document.querySelectorAll("body *"));
    nodes.forEach(el => {
      const t = (el.textContent || "").trim();
      if(!t || t.length > 140) return;
      if(/TRFMC_V0_41A|TRFMC v0\.41A|TRFMC_V0_45A|TRFMC_V0_46A/.test(t)){
        el.dataset.v52LegacyWatermark = "true";
      }
    });
  }

  function addToNavigator(){
    const links = document.querySelector(".v47-section-links");
    if(!links || document.querySelector('[data-v47-target="v52_correction"]')) return;

    const a = document.createElement("a");
    a.href = "#v51_review";
    a.dataset.v47Target = "v52_correction";
    a.textContent = "Corrected";
    links.insertBefore(a, links.firstChild);
  }

  function ensureExecutiveDefault(){
    document.body.classList.add("v52-corrected");

    const mode = localStorage.getItem("trfmc_v51_view_mode");
    if(!mode){
      document.body.classList.add("v51-exec-view");
      document.body.classList.remove("v51-engineering-view");
      localStorage.setItem("trfmc_v51_view_mode", "exec");
    }
  }

  function compactRuntimePlaceholder(){
    const ph = document.querySelector(".v51-runtime-placeholder");
    if(ph){
      ph.innerHTML =
        "<b>Engineering runtime details hidden.</b><br/>Executive View mostra solo readiness, RF/Telco, scenario, KPI ed evidence. Usa Engineering View per JSON completo.";
    }
  }

  ready(function(){
    ensureExecutiveDefault();
    normalizeHero();
    updateReviewBand();
    normalizeFooter();
    markLegacyGhosts();
    compactRuntimePlaceholder();
    addToNavigator();
  });
})();
