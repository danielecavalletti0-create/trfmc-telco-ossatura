(function(){
  const VERSION = "TRFMC_V0_70A_UNIFIED_ULTIMATE_ENTERPRISE_SHELL";

  const nav = [
    ["Executive", "/executive_mission_dashboard_v_next.html"],
    ["UE Handover", "/webgl_rf_heatmap_engine_v69.html"],
    ["Vegetation", "/webgl_rf_heatmap_engine_v68.html"],
    ["Urban", "/webgl_rf_heatmap_engine_v67.html"],
    ["Heatmap", "/webgl_rf_heatmap_engine_v66.html"],
    ["Field", "/field_engineering_mode_v64.html"],
    ["Digital Twin", "/infrastructure_digital_twin_v63.html"],
    ["Propagation", "/rf_propagation_sandbox_v62.html"],
    ["Knowledge", "/rf_telco_knowledge_os_v60.html"],
    ["Modules", "/rf_telco_knowledge_modules_v61.html"],
    ["Golden", "/runtime_golden_check_console_v29.html"]
  ];

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function el(tag, cls){
    const n = document.createElement(tag);
    if(cls) n.className = cls;
    return n;
  }

  function currentPath(){
    return location.pathname.split("/").pop() || "index.html";
  }

  function shellAlready(){
    return document.querySelector(".trfmc-v70-shell");
  }

  function buildShell(){
    if(shellAlready()) return;

    document.body.classList.add("trfmc-v70-unified");

    const shell = el("header", "trfmc-v70-shell");
    shell.innerHTML = `
      <div class="trfmc-v70-brand">
        <div class="trfmc-v70-orb"></div>
        <div>
          <b>TRFMC ULTIMATE ENTERPRISE SHELL</b>
          <span id="v70_page_identity">${VERSION}</span>
        </div>
      </div>
      <nav class="trfmc-v70-nav">
        ${nav.map(([label, href]) => `<a href="${href}" data-v70-href="${href}">${label}</a>`).join("")}
      </nav>
      <div class="trfmc-v70-status">
        <span id="v70_backend">Backend —</span>
        <span id="v70_runtime">Runtime —</span>
        <span id="v70_visual">Visual —</span>
      </div>
    `;

    document.body.prepend(shell);

    const path = currentPath();
    document.querySelectorAll("[data-v70-href]").forEach(a => {
      const href = a.getAttribute("data-v70-href").split("/").pop();
      if(href === path) a.classList.add("active");
    });

    const blade = el("aside", "trfmc-v70-blade");
    blade.innerHTML = `
      <h3>Mission Control Context</h3>
      <div class="trfmc-v70-blade-grid">
        <div><span>Page</span><b id="v70_page">—</b></div>
        <div><span>Branch</span><b>v0.70A</b></div>
        <div><span>Mode</span><b id="v70_mode">Ultimate</b></div>
        <div><span>Focus</span><b>RF/Telco</b></div>
      </div>
      <div class="trfmc-v70-actions">
        <button id="v70_ultimate_btn" type="button">Ultimate</button>
        <button id="v70_perf_btn" type="button">Performance</button>
      </div>
    `;
    document.body.appendChild(blade);

    const rail = el("aside", "trfmc-v70-rail");
    rail.innerHTML = `
      <h3>Visual Governance</h3>
      <p>
        Unified navigation, runtime state, visual density and cockpit alignment.
        This layer prevents page drift and keeps the portal credible as an engineering platform.
      </p>
      <div class="score">
        <b id="v70_score">92%</b>
        <div class="bar"><i id="v70_score_bar"></i></div>
      </div>
    `;
    document.body.appendChild(rail);

    const badge = el("div", "trfmc-v70-mode-badge");
    badge.id = "v70_badge";
    badge.textContent = "V70 · ENTERPRISE SHELL ACTIVE";
    document.body.appendChild(badge);

    document.getElementById("v70_page").textContent = path.replace(".html","");
    document.getElementById("v70_page_identity").textContent = path + " · unified cockpit layer";

    bindModes();
    refreshHealth();
    setInterval(refreshHealth, 15000);
    visualAudit();
  }

  function bindModes(){
    const ultimate = document.getElementById("v70_ultimate_btn");
    const perf = document.getElementById("v70_perf_btn");

    function apply(){
      const mode = localStorage.getItem("trfmc_v70_mode") || "ultimate";
      document.body.classList.toggle("trfmc-v70-ultimate", mode === "ultimate");
      document.body.classList.toggle("trfmc-v70-performance", mode === "performance");
      if(ultimate) ultimate.classList.toggle("active", mode === "ultimate");
      if(perf) perf.classList.toggle("active", mode === "performance");
      const m = document.getElementById("v70_mode");
      if(m) m.textContent = mode === "ultimate" ? "Ultimate" : "Performance";
      const badge = document.getElementById("v70_badge");
      if(badge) badge.textContent = mode === "ultimate" ? "V70 · 4.5D ULTIMATE ACTIVE" : "V70 · PERFORMANCE MODE";
    }

    if(ultimate) ultimate.addEventListener("click", () => {
      localStorage.setItem("trfmc_v70_mode","ultimate");
      apply();
    });

    if(perf) perf.addEventListener("click", () => {
      localStorage.setItem("trfmc_v70_mode","performance");
      apply();
    });

    document.addEventListener("keydown", e => {
      if(e.altKey && e.key.toLowerCase() === "u"){
        const current = localStorage.getItem("trfmc_v70_mode") || "ultimate";
        localStorage.setItem("trfmc_v70_mode", current === "ultimate" ? "performance" : "ultimate");
        apply();
      }
    });

    apply();
  }

  async function refreshHealth(){
    const backend = document.getElementById("v70_backend");
    const runtime = document.getElementById("v70_runtime");
    const visual = document.getElementById("v70_visual");

    try{
      const r = await fetch("/api/health", {cache:"no-store"});
      if(!r.ok) throw new Error("backend " + r.status);
      const j = await r.json();

      backend.textContent = "Backend OK";
      backend.className = "";
      runtime.textContent = (j.operational_mode || "SIM").replace("_"," ");
      runtime.className = "";
      visual.textContent = "Visual READY";
      visual.className = "";

      try{
        const m = await fetch("/api/observability/health-matrix", {cache:"no-store"});
        if(m.ok){
          const mj = await m.json();
          runtime.textContent = mj.overall_status ? "Matrix " + mj.overall_status : runtime.textContent;
          if(mj.overall_status && mj.overall_status !== "OK") runtime.className = "warn";
        }
      }catch(e){}
    }catch(e){
      backend.textContent = "Backend OFF";
      backend.className = "crit";
      runtime.textContent = "Runtime WARN";
      runtime.className = "warn";
      visual.textContent = "Visual LOCAL";
      visual.className = "warn";
    }
  }

  function visualAudit(){
    let score = 100;
    const path = currentPath();

    if(!document.querySelector("canvas")) score -= 4;
    if(!document.querySelector("nav, .trfmc-v70-nav")) score -= 10;
    if(!document.querySelector("h1")) score -= 8;
    if(!document.querySelector("[id*='state'], [class*='status'], .trfmc-v70-status")) score -= 8;
    if(path.includes("v69") || path.includes("v68") || path.includes("v67")) score += 3;

    score = Math.max(72, Math.min(98, score));
    const s = document.getElementById("v70_score");
    const b = document.getElementById("v70_score_bar");
    if(s) s.textContent = score + "%";
    if(b) b.style.width = score + "%";
  }

  ready(buildShell);
})();
