(function(){
  const VERSION = "TRFMC_V0_51A_EXECUTIVE_VISUAL_AUDIT_REFINEMENT";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function findRuntimeSection(){
    const headers = Array.from(document.querySelectorAll("h1,h2,h3"));
    const h = headers.find(x => /EXECUTIVE RUNTIME SNAPSHOT/i.test(x.textContent || ""));
    if(!h) return null;
    return h.closest("section") || h.closest(".panel") || h.parentElement;
  }

  function markRuntimeAsAdvanced(){
    const runtime = findRuntimeSection();
    if(!runtime) return;

    runtime.classList.add("v51-advanced-runtime");

    if(!document.querySelector(".v51-runtime-placeholder")){
      const ph = document.createElement("div");
      ph.className = "v51-runtime-placeholder";
      ph.innerHTML = "<b>Advanced Runtime Snapshot hidden in Executive View.</b><br/>Use Engineering View to inspect raw JSON and low-level runtime details.";
      runtime.insertAdjacentElement("beforebegin", ph);
    }
  }

  function normalizeHero(){
    const h1 = document.querySelector(".hero h1");
    if(h1) h1.textContent = "TRFMC EXECUTIVE MISSION DASHBOARD";

    const heroP = document.querySelector(".hero p");
    if(heroP){
      heroP.textContent =
        "v0.51A · visual audit refinement milestone: plancia executive consolidata con master index, RF/Telco intelligence, scenario command, KPI wall, evidence posture e runtime readiness. Default Executive View, Engineering Detail disponibile.";
    }
  }

  function insertReviewBand(){
    if(document.querySelector(".v51-review-band")) return;

    const band = document.createElement("section");
    band.className = "v51-review-band";
    band.id = "v51_review";
    band.innerHTML = `
      <div>
        <h2>Executive Visual Review Mode</h2>
        <p>
          ${VERSION} · questa modalità serve a valutare la dashboard completa: impatto iniziale,
          gerarchia, leggibilità RF/Telco, comandi missione, KPI live e sezioni da comprimere o rifinire.
        </p>
      </div>
      <div class="v51-review-actions">
        <button type="button" id="v51_exec_view" class="active">Executive View</button>
        <button type="button" id="v51_eng_view">Engineering View</button>
        <a href="#v50_master">Master</a>
        <a href="#v49_rf_intel">RF Intel</a>
        <a href="#v48_scenario">Scenario</a>
        <a href="#v47_kpi">KPI</a>
      </div>
    `;

    const hero = document.querySelector(".hero");
    if(hero) hero.insertAdjacentElement("afterend", band);
    else document.body.insertBefore(band, document.body.firstChild);
  }

  function bindViewToggles(){
    const exec = document.getElementById("v51_exec_view");
    const eng = document.getElementById("v51_eng_view");

    function setMode(mode){
      document.body.classList.toggle("v51-exec-view", mode === "exec");
      document.body.classList.toggle("v51-engineering-view", mode === "eng");
      if(exec) exec.classList.toggle("active", mode === "exec");
      if(eng) eng.classList.toggle("active", mode === "eng");
      localStorage.setItem("trfmc_v51_view_mode", mode);
    }

    if(exec) exec.addEventListener("click", () => setMode("exec"));
    if(eng) eng.addEventListener("click", () => setMode("eng"));

    const saved = localStorage.getItem("trfmc_v51_view_mode") || "exec";
    setMode(saved === "eng" ? "eng" : "exec");
  }

  function normalizeLegacyWatermarks(){
    const nodes = Array.from(document.querySelectorAll("body *"));
    nodes.forEach(el => {
      const t = (el.textContent || "").trim();
      if(!t) return;
      if(t.includes("TRFMC_V0_41A") || t.includes("TRFMC v0.41A")) {
        if(t.length < 120){
          el.dataset.v51LegacyWatermark = "true";
          el.textContent = "TRFMC v0.51A · Executive Review Mode";
        }
      }
    });
  }

  function addToNavigator(){
    const links = document.querySelector(".v47-section-links");
    if(!links || document.querySelector('[data-v47-target="v51_review"]')) return;

    const a = document.createElement("a");
    a.href = "#v51_review";
    a.dataset.v47Target = "v51_review";
    a.textContent = "Review";
    links.insertBefore(a, links.firstChild);
  }

  function compactReleaseChain(){
    const chain = document.querySelector(".v50-release-chain");
    if(chain && !chain.querySelector(".v51-chain-note")){
      const note = document.createElement("div");
      note.className = "v51-chain-note";
      note.style.cssText = "margin-top:8px;color:rgba(237,248,255,.48);font-size:10px;line-height:1.4";
      note.textContent = "Release chain compatta: usare questa sezione come checkpoint, non come area operativa primaria.";
      chain.appendChild(note);
    }
  }

  ready(function(){
    document.body.classList.add("v51-refined");
    normalizeHero();
    insertReviewBand();
    markRuntimeAsAdvanced();
    normalizeLegacyWatermarks();
    bindViewToggles();
    addToNavigator();
    compactReleaseChain();
  });
})();
