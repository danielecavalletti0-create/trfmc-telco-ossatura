(function(){
  const VERSION = "TRFMC_V0_55A_EXECUTIVE_DASHBOARD_NEXT_SPATIAL_COMMAND_LAYER";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function ensureOrbitalStack(){
    const hero = document.querySelector(".hero-next");
    if(!hero || document.querySelector(".v55-orbital-stack")) return;

    const stack = document.createElement("div");
    stack.className = "v55-orbital-stack";
    stack.innerHTML = `
      <div class="v55-orbit o1"></div>
      <div class="v55-orbit o2"></div>
      <div class="v55-orbit o3"></div>
      <div class="v55-satellite s1"></div>
      <div class="v55-satellite s2"></div>
      <div class="v55-satellite s3"></div>
    `;
    hero.appendChild(stack);
  }

  function ensureCommandRibbon(){
    const strip = document.querySelector(".control-strip");
    if(!strip || document.querySelector(".v55-command-ribbon")) return;

    const ribbon = document.createElement("div");
    ribbon.className = "v55-command-ribbon";
    ribbon.innerHTML = `
      <div><span>Spatial Layer</span><b>ORBITAL UI</b></div>
      <div><span>RF Core</span><b id="v55_rf_core">SYNC</b></div>
      <div><span>Scenario</span><b id="v55_scenario_core">ARMED</b></div>
      <div><span>Review</span><b>V0.55A</b></div>
    `;
    strip.insertAdjacentElement("afterend", ribbon);
  }

  function updateHero(){
    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.55A · SPATIAL COMMAND LAYER";

    const h1 = document.querySelector(".hero-copy h1");
    if(h1) h1.textContent = "Executive Mission Dashboard Next";

    const p = document.querySelector(".hero-copy p");
    if(p){
      p.textContent =
        "Plancia executive spaziale per RF/Telco, scenario command, KPI live, evidence posture e runtime readiness. Layout pulito v0.54A preservato, ora con profondità visiva, orbite operative, spectrum intelligence e mission-control impact.";
    }

    const footer = document.querySelector(".next-footer");
    if(footer){
      footer.textContent = "TRFMC v0.55A · Executive Dashboard Next / Spatial Command Layer · frontend-only · localhost-only · backend simulation-only";
    }
  }

  function bindSpatialKeyboard(){
    document.addEventListener("keydown", (ev) => {
      if(ev.key.toLowerCase() === "s" && ev.altKey){
        document.body.classList.toggle("v55-spatial-muted");
      }
    });
  }

  function observeRuntimeText(){
    const rfState = document.getElementById("rf_state");
    const scenarioState = document.getElementById("scenario_state");

    const tick = () => {
      const rf = document.getElementById("v55_rf_core");
      const sc = document.getElementById("v55_scenario_core");
      if(rf && rfState) rf.textContent = (rfState.textContent || "SYNC").replace("RF PATH ", "");
      if(sc && scenarioState) sc.textContent = scenarioState.textContent || "ARMED";
    };

    tick();
    setInterval(tick, 2500);
  }

  ready(function(){
    document.body.classList.add("v55-spatial-command");
    ensureOrbitalStack();
    ensureCommandRibbon();
    updateHero();
    bindSpatialKeyboard();
    observeRuntimeText();
  });
})();
