(function(){
  const VERSION = "TRFMC_V0_75A_MASTER_VISUAL_RESET_SINGLE_SHELL";

  const NAV = [
    ["Executive", "/executive_mission_dashboard_v_next.html"],
    ["Components", "/rf_telco_component_library_v76.html"],
    ["UE Handover", "/webgl_rf_heatmap_engine_v69.html"],
    ["Digital Twin", "/infrastructure_digital_twin_v63.html"],
    ["Vegetation", "/webgl_rf_heatmap_engine_v68.html"],
    ["Urban", "/webgl_rf_heatmap_engine_v67.html"],
    ["Heatmap", "/webgl_rf_heatmap_engine_v66.html"],
    ["Field", "/field_engineering_mode_v64.html"],
    ["Propagation", "/rf_propagation_sandbox_v62.html"],
    ["Knowledge", "/rf_telco_knowledge_os_v60.html"],
    ["QA", "/trfmc_visual_qa_matrix_v71.html"],
    ["Golden", "/runtime_golden_check_console_v29.html"]
  ];

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function isPreview(){
    try { return new URLSearchParams(location.search).get("preview") === "1"; }
    catch(e){ return false; }
  }

  function currentFile(){
    return location.pathname.split("/").pop() || "index.html";
  }

  function createShell(){
    if(isPreview()){
      document.body.classList.add("trfmc-preview-embedded");
      return;
    }

    if(document.querySelector(".trfmc-v75-masterbar")) return;

    const activeFile = currentFile();

    const bar = document.createElement("header");
    bar.className = "trfmc-v75-masterbar";
    bar.innerHTML = `
      <div class="v75-brand">
        <div class="v75-orb"></div>
        <div>
          <b>TRFMC MISSION CONTROL</b>
          <span id="v75_identity">${activeFile} · single clean shell</span>
        </div>
      </div>

      <nav class="v75-nav">
        ${NAV.map(([label, href]) => {
          const file = href.split("/").pop();
          const active = file === activeFile ? "active" : "";
          return `<a class="${active}" href="${href}">${label}</a>`;
        }).join("")}
      </nav>

      <div class="v75-status">
        <span id="v75_backend">Backend —</span>
        <span id="v75_runtime">Runtime —</span>
        <span id="v75_visual">Visual OK</span>
      </div>
    `;

    document.body.prepend(bar);
  }

  async function health(){
    const backend = document.getElementById("v75_backend");
    const runtime = document.getElementById("v75_runtime");
    const visual = document.getElementById("v75_visual");

    if(!backend || !runtime || !visual) return;

    try{
      const r = await fetch("/api/health", {cache:"no-store"});
      if(!r.ok) throw new Error("HTTP " + r.status);
      const j = await r.json();
      backend.textContent = "Backend OK";
      backend.className = "";
      runtime.textContent = (j.operational_mode || "SIMULATION").replace("_"," ");
      runtime.className = "";
      visual.textContent = "Shell v75";
      visual.className = "";
    }catch(e){
      backend.textContent = "Backend OFF";
      backend.className = "crit";
      runtime.textContent = "Runtime WARN";
      runtime.className = "warn";
      visual.textContent = "Local UI";
      visual.className = "warn";
    }
  }

  function bindKeys(){
    if(document.body.dataset.v75Bound === "true") return;
    document.body.dataset.v75Bound = "true";

    document.addEventListener("keydown", e => {
      if(e.altKey && e.key.toLowerCase() === "s"){
        document.body.classList.toggle("trfmc-v75-clean-shot");
        localStorage.setItem(
          "trfmc_v75_clean_shot",
          document.body.classList.contains("trfmc-v75-clean-shot") ? "1" : "0"
        );
      }

      if(e.altKey && e.key.toLowerCase() === "c"){
        document.body.classList.toggle("trfmc-v75-calibrated");
        localStorage.setItem(
          "trfmc_v75_calibrated",
          document.body.classList.contains("trfmc-v75-calibrated") ? "1" : "0"
        );
      }
    });

    if(localStorage.getItem("trfmc_v75_clean_shot") === "1"){
      document.body.classList.add("trfmc-v75-clean-shot");
    }

    if(localStorage.getItem("trfmc_v75_calibrated") === "1"){
      document.body.classList.add("trfmc-v75-calibrated");
    }
  }

  ready(() => {
    document.body.classList.add("trfmc-v75-active");
    createShell();
    bindKeys();

    if(!isPreview()){
      health();
      setInterval(health, 12000);
    }

    document.body.dataset.v75 = VERSION;

    if(!document.title.includes("v0.75A")){
      document.title = "TRFMC v0.75A Shell · " + document.title;
    }
  });
})();
