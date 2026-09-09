(function(){
  const VERSION = "TRFMC_V0_53A_FINAL_VISUAL_ALIGNMENT_PASS";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function setHero(){
    const h1 = document.querySelector(".hero h1");
    if(h1) h1.textContent = "TRFMC EXECUTIVE MISSION DASHBOARD";

    const p = document.querySelector(".hero p");
    if(p){
      p.textContent =
        "v0.53A · final visual alignment pass: plancia executive consolidata per revisione finale. Focus operativo su RF/Telco intelligence, Scenario Command, KPI Wall, Evidence posture, Master Index e Golden readiness.";
    }
  }

  function updateReviewText(){
    const p = document.querySelector(".v51-review-band p");
    if(p){
      p.textContent =
        VERSION + " · final alignment: gerarchia consolidata, sezioni compattate, RF/Scenario/KPI prioritari, dettagli engineering disponibili solo quando richiesti.";
    }
  }

  function normalizeFooter(){
    document.querySelectorAll("footer").forEach(f => {
      if((f.textContent || "").includes("TRFMC")){
        f.textContent = "TRFMC v0.53A · Final Visual Alignment Pass · frontend-only · localhost-only";
      }
    });
  }

  function ensureExecutiveDefault(){
    document.body.classList.add("v53-final-aligned");

    const mode = localStorage.getItem("trfmc_v51_view_mode");
    if(!mode){
      localStorage.setItem("trfmc_v51_view_mode", "exec");
      document.body.classList.add("v51-exec-view");
      document.body.classList.remove("v51-engineering-view");
    }
  }

  function labelOperationalCore(){
    const rf = document.querySelector(".v49-rf-intel-strip");
    const scn = document.querySelector(".v48-scenario-command");

    if(rf && !rf.dataset.v53Core){
      rf.dataset.v53Core = "true";
      rf.setAttribute("aria-label", "Primary RF Telco Signal Intelligence");
    }

    if(scn && !scn.dataset.v53Core){
      scn.dataset.v53Core = "true";
      scn.setAttribute("aria-label", "Primary Scenario Mission Command");
    }
  }

  function addToNavigator(){
    const links = document.querySelector(".v47-section-links");
    if(!links || document.querySelector('[data-v47-target="v53_final"]')) return;

    const a = document.createElement("a");
    a.href = "#v51_review";
    a.dataset.v47Target = "v53_final";
    a.textContent = "Final";
    links.insertBefore(a, links.firstChild);
  }

  function markCurrentRelease(){
    const band = document.querySelector(".v51-review-band h2");
    if(band && !band.textContent.includes("Final")) {
      band.textContent = "Executive Final Visual Review Mode";
    }
  }

  ready(function(){
    ensureExecutiveDefault();
    setHero();
    updateReviewText();
    normalizeFooter();
    labelOperationalCore();
    addToNavigator();
    markCurrentRelease();
  });
})();
