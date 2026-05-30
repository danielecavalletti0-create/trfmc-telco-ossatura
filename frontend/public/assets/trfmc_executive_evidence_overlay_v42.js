(function(){
  const VERSION = "TRFMC_V0_42A_EXECUTIVE_EVIDENCE_MISSION_STATUS_OVERLAY";
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

  function setTile(id, state){
    const el = document.getElementById(id);
    if(!el) return;
    el.classList.remove("good","warn","critical");
    el.classList.add(state || "good");
  }

  async function refreshOverlay(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary");
      const persistence = await getJson(API + "/persistence/status").catch(() => ({}));
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));

      const counts = portal.high_value_counts || {};
      const pcounts = persistence.counts || portal.persistence?.counts || {};
      const golden = snap.overall_status || "UNKNOWN";
      const checks = Array.isArray(snap.checks) ? snap.checks.length : "—";

      const missionReady =
        health.status === "ok" &&
        portal.overall_status === "OK" &&
        golden === "OK";

      set("v42_readiness", missionReady ? "MISSION READY" : "ATTENTION REQUIRED");
      set("v42_readiness_detail", VERSION + " · " + new Date().toLocaleTimeString());

      set("v42_mission_state", missionReady ? "READY" : "DEGRADED");
      set("v42_mission_detail", "backend " + (health.version || "—") + " · " + (health.operational_mode || "—"));
      setTile("v42_tile_mission", missionReady ? "good" : "warn");

      set("v42_evidence_state", (pcounts.evidence ?? "—") + " evidence");
      set("v42_evidence_detail", (counts.incidents ?? pcounts.incidents ?? "—") + " incidents · " + (counts.cloud_events ?? pcounts.cloud_events ?? "—") + " events");
      setTile("v42_tile_evidence", "good");

      set("v42_backup_state", "READY");
      set("v42_backup_detail", "backup / restore consoles linked");
      setTile("v42_tile_backup", "good");

      set("v42_security_state", health.restricted_enabled ? "RESTRICTED" : "SIMULATION");
      set("v42_security_detail", "localhost · restricted=" + String(health.restricted_enabled));
      setTile("v42_tile_security", health.restricted_enabled ? "good" : "warn");

      set("v42_rf_state", (counts.rf_coverage_runs ?? pcounts.rf_coverage_runs ?? "—") + " / " + (counts.rf_field_runs ?? pcounts.rf_field_runs ?? "—"));
      set("v42_rf_detail", "coverage / field runs");
      setTile("v42_tile_rf", "good");

      set("v42_golden_state", golden);
      set("v42_golden_detail", checks + " checks · git dirty " + (snap.release_context?.git_dirty_files ?? "—"));
      setTile("v42_tile_golden", golden === "OK" ? "good" : "warn");

      document.querySelectorAll(".v42-flow-step").forEach((el, idx) => {
        setTimeout(() => el.classList.add("active"), idx * 120);
      });
    } catch(e) {
      set("v42_readiness", "OVERLAY ERROR");
      set("v42_readiness_detail", String(e));
      set("v42_mission_state", "ERROR");
      set("v42_mission_detail", String(e));
      setTile("v42_tile_mission", "critical");
    }
  }

  ready(function(){
    refreshOverlay();
    setInterval(refreshOverlay, 30000);
  });
})();
