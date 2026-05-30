(function(){
  const VERSION = "TRFMC_V0_43A_EXECUTIVE_NAVIGATION_REFINEMENT_MISSION_ENTRY_HUB";
  const API = "/api";

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

  async function refreshHub(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary");
      const docs = await getJson(API + "/docs/index");
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));

      const counts = portal.high_value_counts || {};
      const golden = snap.overall_status || "UNKNOWN";

      set("v43_hub_state", "ENTRY HUB READY");
      set("v43_hub_detail", VERSION + " · " + new Date().toLocaleTimeString());

      set("v43_backend", health.version + " · " + health.operational_mode);
      set("v43_pages", String(portal.pages_active ?? "—"));
      set("v43_events", String(counts.cloud_events ?? "—"));
      set("v43_rf", String(counts.rf_coverage_runs ?? "—") + " / " + String(counts.rf_field_runs ?? "—"));
      set("v43_docs", String(docs.count ?? "—") + " docs");
      set("v43_golden", golden);
    } catch(e) {
      set("v43_hub_state", "ENTRY HUB DEGRADED");
      set("v43_hub_detail", String(e));
    }
  }

  ready(function(){
    refreshHub();
    setInterval(refreshHub, 30000);
  });
})();
