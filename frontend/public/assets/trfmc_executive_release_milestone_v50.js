(function(){
  const VERSION = "TRFMC_V0_50A_EXECUTIVE_RELEASE_MILESTONE_MASTER_INDEX";
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

  function setScore(percent){
    const p = Math.max(0, Math.min(100, Number(percent || 0)));
    const deg = Math.round((p / 100) * 360);
    const orb = document.querySelector(".v50-score-orb");
    if(orb) orb.style.setProperty("--v50-score-deg", deg + "deg");
    set("v50_master_score", Math.round(p) + "%");
  }

  async function refreshMilestone(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary").catch(() => ({}));
      const docs = await getJson(API + "/docs/index").catch(() => ({}));
      const persistence = await getJson(API + "/persistence/status").catch(() => ({}));
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));

      const counts = portal.high_value_counts || persistence.counts || {};
      const golden = snap.overall_status || "UNKNOWN";
      const gitDirty = snap.release_context?.git_dirty_files ?? "—";

      let score = 0;
      if(health.status === "ok") score += 18;
      if(portal.overall_status === "OK") score += 18;
      if(golden === "OK") score += 18;
      if((docs.count ?? 0) >= 6) score += 10;
      if((counts.cloud_events ?? 0) > 0) score += 10;
      if((counts.rf_coverage_runs ?? 0) > 0) score += 8;
      if((counts.rf_field_runs ?? 0) > 0) score += 8;
      if((counts.evidence ?? 0) > 0) score += 5;
      if(gitDirty === 0 || gitDirty === "0") score += 5;

      const state = score >= 90 ? "MILESTONE READY" : score >= 75 ? "MILESTONE REVIEW" : "MILESTONE ATTENTION";

      setScore(score);
      set("v50_master_state", state);
      set("v50_master_detail", VERSION + " · " + new Date().toLocaleTimeString());
      set("v50_status_title", state);
      set("v50_status_detail", "Executive chain v0.40A → v0.50A · backend " + (health.version || "—") + " · golden " + golden);

      set("v50_backend", health.version || "—");
      set("v50_mode", health.operational_mode || "—");
      set("v50_golden", golden);
      set("v50_git_dirty", String(gitDirty));
      set("v50_pages", String(portal.pages_active ?? "—"));
      set("v50_docs", String(docs.count ?? "—"));
      set("v50_events", String(counts.cloud_events ?? "—"));
      set("v50_rf_runs", String(counts.rf_coverage_runs ?? "—") + " / " + String(counts.rf_field_runs ?? "—"));
      set("v50_evidence", String(counts.evidence ?? "—"));
      set("v50_assets", String(counts.assets ?? "—"));
      set("v50_refresh", new Date().toLocaleTimeString());
    } catch(e) {
      setScore(0);
      set("v50_master_state", "MILESTONE DEGRADED");
      set("v50_master_detail", String(e));
      set("v50_status_title", "MILESTONE DEGRADED");
      set("v50_status_detail", String(e));
    }
  }

  function addToV47Navigator(){
    const links = document.querySelector(".v47-section-links");
    if(!links || document.querySelector('[data-v47-target="v50_master"]')) return;

    const a = document.createElement("a");
    a.href = "#v50_master";
    a.dataset.v47Target = "v50_master";
    a.textContent = "Master";
    links.insertBefore(a, links.firstChild);
  }

  ready(function(){
    const section = document.querySelector(".v50-release-milestone");
    if(section && !section.id) section.id = "v50_master";

    addToV47Navigator();
    refreshMilestone();
    setInterval(refreshMilestone, 30000);
  });
})();
