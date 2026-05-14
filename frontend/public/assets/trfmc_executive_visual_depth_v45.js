(function(){
  const VERSION = "TRFMC_V0_45A_EXECUTIVE_VISUAL_DEPTH_GLASS_COMMAND_CENTER";
  const API = "http://127.0.0.1:8000/api";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  async function getJson(url){
    const r = await fetch(url, {cache:"no-store"});
    if(!r.ok) throw new Error(url + " HTTP " + r.status);
    return await r.json();
  }

  function set(id, value){
    const el = document.getElementById(id);
    if(el) el.textContent = value ?? "—";
  }

  function enableDepthLayer(){
    document.body.classList.add("v45-depth-enabled");

    if(!document.querySelector(".v45-depth-microgrid")){
      const g = document.createElement("div");
      g.className = "v45-depth-microgrid";
      document.body.appendChild(g);
    }
  }

  async function refreshVisualDepth(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary");
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));

      const counts = portal.high_value_counts || {};
      const golden = snap.overall_status || "UNKNOWN";
      const ready = health.status === "ok" && portal.overall_status === "OK" && golden === "OK";

      set("v45_depth_state", ready ? "GLASS COMMAND READY" : "VISUAL ATTENTION");
      set("v45_depth_detail", VERSION + " · " + new Date().toLocaleTimeString());

      set("v45_depth_runtime", health.version + " · " + health.operational_mode);
      set("v45_depth_runtime_detail", "localhost-only · backend health " + health.status);

      set("v45_depth_mission", golden);
      set("v45_depth_mission_detail", "Golden Check state · release confidence");

      set("v45_depth_rf", (counts.rf_coverage_runs ?? "—") + " / " + (counts.rf_field_runs ?? "—"));
      set("v45_depth_rf_detail", "coverage / field measurement runs");

      set("v45_depth_events", (counts.cloud_events ?? "—") + " events");
      set("v45_depth_events_detail", "CloudEvents and mission telemetry");
    } catch(e) {
      set("v45_depth_state", "GLASS LAYER DEGRADED");
      set("v45_depth_detail", String(e));
    }
  }

  function bindSubtleParallax(){
    const hero = document.querySelector(".hero");
    if(!hero) return;

    let last = 0;
    window.addEventListener("mousemove", (ev) => {
      const now = Date.now();
      if(now - last < 60) return;
      last = now;

      const x = (ev.clientX / window.innerWidth - .5) * 4;
      const y = (ev.clientY / window.innerHeight - .5) * 4;
      hero.style.transform = `perspective(1200px) rotateX(${(-y).toFixed(2)}deg) rotateY(${x.toFixed(2)}deg)`;
    });

    window.addEventListener("mouseleave", () => {
      hero.style.transform = "perspective(1200px) rotateX(0deg) rotateY(0deg)";
    });
  }

  ready(function(){
    enableDepthLayer();
    bindSubtleParallax();
    refreshVisualDepth();
    setInterval(refreshVisualDepth, 30000);
  });
})();
