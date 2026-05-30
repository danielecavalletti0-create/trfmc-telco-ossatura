(function(){
  const VERSION = "TRFMC_V0_46A_EXECUTIVE_INSTRUMENT_CLUSTER_LIVE_KPI_WALL";
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

  function tile(id, state){
    const el = document.getElementById(id);
    if(!el) return;
    el.classList.remove("good", "warn", "bad");
    el.classList.add(state || "good");
  }

  function setGauge(percent){
    const p = Math.max(0, Math.min(100, Number(percent || 0)));
    const deg = Math.round((p / 100) * 280);
    const gauge = document.querySelector(".v46-gauge-wrap");
    if(gauge) gauge.style.setProperty("--v46-gauge-deg", deg + "deg");
    set("v46_readiness_percent", Math.round(p) + "%");
  }

  async function refreshInstrumentCluster(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary");
      const docs = await getJson(API + "/docs/index").catch(() => ({}));
      const persistence = await getJson(API + "/persistence/status").catch(() => ({}));
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));

      const counts = portal.high_value_counts || {};
      const pcounts = persistence.counts || portal.persistence?.counts || {};
      const golden = snap.overall_status || "UNKNOWN";
      const checks = Array.isArray(snap.checks) ? snap.checks.length : 0;
      const dirty = snap.release_context?.git_dirty_files ?? "—";

      let score = 0;
      if(health.status === "ok") score += 20;
      if(portal.overall_status === "OK") score += 20;
      if(golden === "OK") score += 20;
      if((counts.cloud_events ?? pcounts.cloud_events ?? 0) > 0) score += 15;
      if((counts.rf_coverage_runs ?? pcounts.rf_coverage_runs ?? 0) > 0) score += 10;
      if((counts.rf_field_runs ?? pcounts.rf_field_runs ?? 0) > 0) score += 10;
      if((docs.count ?? 0) >= 6) score += 5;

      const ready = score >= 85;

      set("v46_cluster_state", ready ? "KPI WALL READY" : "KPI WALL ATTENTION");
      set("v46_cluster_detail", VERSION + " · " + new Date().toLocaleTimeString());

      setGauge(score);
      set("v46_readiness_label", ready ? "MISSION READY" : "CHECK REQUIRED");
      set("v46_readiness_detail", "score " + score + "/100 · golden " + golden + " · checks " + checks);

      set("v46_backend", health.version || "—");
      set("v46_mode", health.operational_mode || "—");
      set("v46_golden", golden);
      set("v46_checks", String(checks));
      set("v46_events", String(counts.cloud_events ?? pcounts.cloud_events ?? "—"));
      set("v46_rf_cov", String(counts.rf_coverage_runs ?? pcounts.rf_coverage_runs ?? "—"));
      set("v46_rf_field", String(counts.rf_field_runs ?? pcounts.rf_field_runs ?? "—"));
      set("v46_assets", String(counts.assets ?? pcounts.assets ?? "—"));
      set("v46_evidence", String(pcounts.evidence ?? "—"));
      set("v46_incidents", String(counts.incidents ?? pcounts.incidents ?? "—"));
      set("v46_docs", String(docs.count ?? "—"));
      set("v46_pages", String(portal.pages_active ?? "—"));

      set("v46_dirty", String(dirty));
      set("v46_runtime", health.status || "—");
      set("v46_portal", portal.overall_status || "—");
      set("v46_refresh", new Date().toLocaleTimeString());

      tile("v46_tile_backend", health.status === "ok" ? "good" : "bad");
      tile("v46_tile_golden", golden === "OK" ? "good" : "warn");
      tile("v46_tile_events", (counts.cloud_events ?? pcounts.cloud_events ?? 0) > 0 ? "good" : "warn");
      tile("v46_tile_rf_cov", (counts.rf_coverage_runs ?? pcounts.rf_coverage_runs ?? 0) > 0 ? "good" : "warn");
      tile("v46_tile_rf_field", (counts.rf_field_runs ?? pcounts.rf_field_runs ?? 0) > 0 ? "good" : "warn");
      tile("v46_tile_evidence", (pcounts.evidence ?? 0) > 0 ? "good" : "warn");
      tile("v46_tile_incidents", (counts.incidents ?? pcounts.incidents ?? 0) > 0 ? "warn" : "good");
      tile("v46_tile_docs", (docs.count ?? 0) >= 6 ? "good" : "warn");
    } catch(e) {
      set("v46_cluster_state", "KPI WALL DEGRADED");
      set("v46_cluster_detail", String(e));
      set("v46_readiness_label", "ERROR");
      set("v46_readiness_detail", String(e));
      setGauge(0);
      tile("v46_tile_backend", "bad");
    }
  }

  ready(function(){
    refreshInstrumentCluster();
    setInterval(refreshInstrumentCluster, 30000);
  });
})();
