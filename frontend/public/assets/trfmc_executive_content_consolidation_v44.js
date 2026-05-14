(function(){
  const VERSION = "TRFMC_V0_44A_EXECUTIVE_DASHBOARD_CONTENT_CONSOLIDATION";
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

  async function refreshPriorityRail(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary");
      const docs = await getJson(API + "/docs/index").catch(() => ({}));
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));

      const counts = portal.high_value_counts || {};
      const golden = snap.overall_status || "UNKNOWN";
      const missionReady = health.status === "ok" && portal.overall_status === "OK" && golden === "OK";

      set("v44_priority_state", missionReady ? "EXECUTIVE READY" : "EXECUTIVE ATTENTION");
      set("v44_priority_detail", VERSION + " · " + new Date().toLocaleTimeString());

      set("v44_main_decision", missionReady ? "Mission Control Ready" : "Check Runtime State");
      set("v44_main_decision_detail", health.version + " · " + health.operational_mode + " · Golden " + golden);

      set("v44_rf_summary", (counts.rf_coverage_runs ?? "—") + " / " + (counts.rf_field_runs ?? "—"));
      set("v44_rf_detail", "coverage / field runs");

      set("v44_evidence_summary", (counts.cloud_events ?? "—") + " events");
      set("v44_evidence_detail", (counts.incidents ?? "—") + " incidents · evidence chain active");

      set("v44_docs_summary", (docs.count ?? "—") + " docs");
      set("v44_docs_detail", "handbook / command reference / release chain");
    } catch(e) {
      set("v44_priority_state", "EXECUTIVE DEGRADED");
      set("v44_priority_detail", String(e));
    }
  }

  function markHierarchy(){
    document.body.classList.add("v44-compact-mode");
    const hub = document.querySelector(".v43-entry-hub");
    if(hub) hub.classList.add("v44-focus-outline");
  }

  ready(function(){
    markHierarchy();
    refreshPriorityRail();
    setInterval(refreshPriorityRail, 30000);
  });
})();
