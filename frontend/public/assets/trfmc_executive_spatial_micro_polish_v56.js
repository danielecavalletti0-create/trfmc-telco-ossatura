(function(){
  const VERSION = "TRFMC_V0_56A_EXECUTIVE_DASHBOARD_NEXT_SPATIAL_MICRO_POLISH";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function ensureHeroBadges(){
    const copy = document.querySelector(".hero-copy");
    if(!copy || document.querySelector(".v56-hero-badge-row")) return;

    const row = document.createElement("div");
    row.className = "v56-hero-badge-row";
    row.innerHTML = `
      <span class="good">Mission Console</span>
      <span>RF/Telco Intelligence</span>
      <span>Scenario Command</span>
      <span>KPI Wall</span>
      <span>Evidence Ready</span>
    `;

    const p = copy.querySelector("p");
    if(p) p.insertAdjacentElement("afterend", row);
    else copy.appendChild(row);
  }

  function ensureMissionHorizon(){
    const hero = document.querySelector(".hero-next");
    if(!hero || document.querySelector(".v56-mission-horizon")) return;
    const h = document.createElement("div");
    h.className = "v56-mission-horizon";
    hero.appendChild(h);
  }

  function ensureTicker(){
    const strip = document.querySelector(".control-strip > div:first-child");
    if(!strip || document.querySelector(".v56-command-ticker")) return;

    const ticker = document.createElement("div");
    ticker.className = "v56-command-ticker";
    ticker.textContent = VERSION + " · spatial polish active · clean dashboard baseline";
    strip.appendChild(ticker);
  }

  function updateCopy(){
    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.56A · SPATIAL MICRO-POLISH";

    const p = document.querySelector(".hero-copy p");
    if(p){
      p.textContent =
        "Plancia executive spaziale per RF/Telco, scenario command, KPI live, evidence posture e runtime readiness. La base v0.54A rimane pulita; v0.56A aggiunge profondità, micro-glow, rifinitura cockpit e maggiore impatto mission-control.";
    }

    const footer = document.querySelector(".next-footer");
    if(footer){
      footer.textContent = "TRFMC v0.56A · Executive Dashboard Next / Spatial Micro-Polish · frontend-only · localhost-only · backend simulation-only";
    }

    document.title = "TRFMC v0.56A · Executive Dashboard Next Spatial Micro-Polish";
  }

  function tuneButtons(){
    document.querySelectorAll(".strip-actions button, .hero-actions a, .launch-actions a").forEach(el => {
      el.dataset.v56Polished = "true";
    });
  }

  function bindDoubleClickFocus(){
    const rf = document.querySelector(".rf-panel");
    const scn = document.querySelector(".scenario-panel");

    [rf, scn].forEach(panel => {
      if(!panel) return;
      panel.addEventListener("dblclick", () => {
        panel.scrollIntoView({behavior: "smooth", block: "center"});
      });
    });
  }

  ready(function(){
    document.body.classList.add("v56-micro-polish");
    ensureHeroBadges();
    ensureMissionHorizon();
    ensureTicker();
    updateCopy();
    tuneButtons();
    bindDoubleClickFocus();
  });
})();
