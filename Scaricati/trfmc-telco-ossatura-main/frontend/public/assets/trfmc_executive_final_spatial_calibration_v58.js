(function(){
  const VERSION = "TRFMC_V0_58A_EXECUTIVE_DASHBOARD_NEXT_FINAL_SPATIAL_CALIBRATION";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function updateIdentity(){
    document.body.classList.add("v58-final-calibrated");

    const brandSpan = document.querySelector(".brand span");
    if(brandSpan){
      brandSpan.textContent = "Executive Dashboard Next · Final Spatial Calibration · v0.58A";
    }

    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow){
      eyebrow.textContent = "TRFMC v0.58A · FINAL SPATIAL CALIBRATION";
    }

    const p = document.querySelector(".hero-copy p");
    if(p){
      p.textContent =
        "Plancia executive spaziale finale per RF/Telco, scenario command, KPI live, evidence posture e runtime readiness. Layout pulito, gerarchia compatta, mission globe olografico calibrato e impatto cockpit professionale.";
    }

    const footer = document.querySelector(".next-footer");
    if(footer){
      footer.textContent = "TRFMC v0.58A · Executive Dashboard Next / Final Spatial Calibration · frontend-only · localhost-only · backend simulation-only";
    }

    document.title = "TRFMC v0.58A · Executive Dashboard Next Final Spatial Calibration";
  }

  function updateRibbon(){
    const review = document.querySelector(".v55-command-ribbon div:last-child b");
    if(review) review.textContent = "V0.58A";

    const ticker = document.querySelector(".v56-command-ticker");
    if(ticker){
      ticker.textContent = VERSION + " · final spatial calibration active · clean dashboard baseline";
    }
  }

  function forceEngineeringHidden(){
    if(!document.body.classList.contains("show-engineering")){
      const detail = document.getElementById("engineering_detail");
      if(detail) detail.style.display = "";
    }
  }

  ready(function(){
    updateIdentity();
    updateRibbon();
    forceEngineeringHidden();
  });
})();
