(function(){
  const API = "http://127.0.0.1:8000/api";

  const scenarios = {
    rural:  { label: "Rural UE", region: "Rural / remote", risk: "MEDIUM" },
    japan:  { label: "Japan", region: "APAC / Japan", risk: "MEDIUM" },
    usa:    { label: "USA", region: "Transatlantic / USA", risk: "HIGH" },
    africa: { label: "Africa", region: "Long-haul / degraded", risk: "HIGH" },
    india:  { label: "India", region: "Regional APAC", risk: "MEDIUM" },
    ntn:    { label: "NTN", region: "Satellite / NTN", risk: "HIGH" }
  };

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  async function getJson(url){
    const r = await fetch(url, {cache: "no-store"});
    if(!r.ok) throw new Error(url + " HTTP " + r.status);
    return await r.json();
  }

  function set(id, value){
    const el = document.getElementById(id);
    if(el) el.textContent = value ?? "—";
  }

  function num(value, digits=1){
    const n = Number(value);
    if(Number.isNaN(n)) return "—";
    return n.toFixed(digits);
  }

  function setScore(p){
    const pct = Math.max(0, Math.min(100, Number(p || 0)));
    const deg = Math.round((pct / 100) * 360);
    const ring = document.getElementById("readiness_ring");
    if(ring) ring.style.setProperty("--score-deg", deg + "deg");
    set("readiness_score", Math.round(pct) + "%");
  }

  function setRfConfidence(p){
    const pct = Math.max(0, Math.min(100, Number(p || 0)));
    const deg = Math.round((pct / 100) * 280);
    const ring = document.getElementById("rf_confidence_ring");
    if(ring) ring.style.setProperty("--rf-deg", deg + "deg");
    set("rf_confidence", Math.round(pct) + "%");
    const carrier = document.getElementById("carrier_line");
    if(carrier) carrier.style.setProperty("--carrier-left", Math.max(22, Math.min(78, pct)) + "%");
  }

  function readinessScore(health, portal, snapshot, counts){
    let score = 0;
    if(health.status === "ok") score += 20;
    if(portal.overall_status === "OK") score += 18;
    if(snapshot.overall_status === "OK") score += 18;
    if((counts.cloud_events || 0) > 0) score += 10;
    if((counts.assets || 0) > 0) score += 8;
    if((counts.evidence || 0) > 0) score += 6;
    if((counts.rf_coverage_runs || 0) > 0) score += 10;
    if((counts.rf_field_runs || 0) > 0) score += 10;
    return Math.min(100, score);
  }

  function rfScore(link, counts){
    const rx = Number(link.rx_power_dbm);
    const snr = Number(link.snr_db);
    const los = String(link.los_state || link.target_los_state || "");
    let score = 50;

    if(!Number.isNaN(rx)) score += Math.max(-20, Math.min(22, (rx + 80) / 2));
    if(!Number.isNaN(snr)) score += Math.max(-12, Math.min(22, snr / 2));
    if(los.includes("NLOS")) score -= 8;
    if(los === "LOS") score += 9;
    if((counts.rf_coverage_runs || 0) > 0) score += 8;
    if((counts.rf_field_runs || 0) > 0) score += 8;

    return Math.max(0, Math.min(100, score));
  }

  async function refresh(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary").catch(() => ({}));
      const docs = await getJson(API + "/docs/index").catch(() => ({}));
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));
      const cov = await getJson(API + "/rf-coverage/demo").catch(() => ({}));
      const field = await getJson(API + "/rf-field/demo").catch(() => ({}));

      const counts = portal.high_value_counts || {};
      const score = readinessScore(health, portal, snap, counts);

      setScore(score);
      const state = score >= 90 ? "MISSION READY" : score >= 75 ? "MISSION REVIEW" : "MISSION ATTENTION";
      set("mission_state", state);
      set("mission_state_detail", "backend " + (health.version || "—") + " · golden " + (snap.overall_status || "—") + " · RF " + (counts.rf_coverage_runs || "—") + "/" + (counts.rf_field_runs || "—"));

      set("top_backend", "Backend " + (health.version || "—"));
      set("top_golden", "Golden " + (snap.overall_status || "—"));
      set("top_mode", "Mode " + (health.operational_mode || "—"));

      set("kpi_backend", health.version || "—");
      set("kpi_backend_detail", health.environment || "runtime");
      set("kpi_golden", snap.overall_status || "—");
      set("kpi_golden_detail", ((snap.checks || []).length || "—") + " checks");
      set("kpi_events", counts.cloud_events ?? "—");
      set("kpi_rf_runs", String(counts.rf_coverage_runs ?? "—") + " / " + String(counts.rf_field_runs ?? "—"));
      set("kpi_evidence", counts.evidence ?? "—");
      set("kpi_assets", counts.assets ?? "—");

      set("wall_runtime", health.status || "—");
      set("wall_golden", snap.overall_status || "—");
      set("wall_docs", docs.count ?? "—");
      set("wall_pages", portal.pages_active ?? "13");
      set("wall_rf_cov", counts.rf_coverage_runs ?? "—");
      set("wall_rf_field", counts.rf_field_runs ?? "—");
      set("wall_incidents", counts.incidents ?? "—");
      set("wall_refresh", new Date().toLocaleTimeString());

      set("support_evidence", String(counts.incidents ?? "—") + " incidents / " + String(counts.evidence ?? "—") + " evidence");
      set("support_rf", String(counts.rf_coverage_runs ?? "—") + " coverage / " + String(counts.rf_field_runs ?? "—") + " field");
      set("support_release", (snap.overall_status || "—") + " · " + (docs.count ?? "—") + " docs");

      const link = cov.target_link || {};
      const wave = field.wave || {};
      const antenna = field.antenna || {};
      const fieldResult = field.field || field.target_field || {};
      const freq = cov.frequency_hz || field.frequency_hz || 0;
      const freqGhz = freq ? freq / 1e9 : 0;
      const los = link.los_state || link.target_los_state || (link.obstacle_hits?.length ? "NLOS" : "LOS/NLOS");
      const region = fieldResult.field_region || field.field_region || "RF FIELD";
      const confidence = rfScore(link, counts);

      setRfConfidence(confidence);
      set("rf_state", confidence >= 78 ? "RF PATH READY" : confidence >= 58 ? "RF PATH WATCH" : "RF DEGRADED");
      set("rf_path_status", confidence >= 78 ? "RF PATH READY" : "RF PATH WATCH");
      set("rf_path_detail", (freqGhz ? num(freqGhz,3) + " GHz" : "—") + " · " + los + " · " + region);

      set("rf_rx_power", link.rx_power_dbm !== undefined ? num(link.rx_power_dbm,1) + " dBm" : "—");
      set("rf_snr", link.snr_db !== undefined ? num(link.snr_db,1) + " dB" : "—");
      set("rf_loss", link.total_path_loss_db !== undefined ? num(link.total_path_loss_db,1) + " dB" : "—");
      set("rf_los", los);
      set("rf_frequency", freqGhz ? num(freqGhz,3) + " GHz" : "—");
      set("rf_wavelength", wave.wavelength_m ? num(wave.wavelength_m,4) + " m" : "—");
      set("rf_field", region);
      set("rf_obstacles", link.obstacle_hits ? String(link.obstacle_hits.length) : "—");

      const runtime = {
        health,
        portal,
        docs,
        snapshot: snap,
        rf_coverage: cov,
        rf_field: field
      };
      const pre = document.getElementById("runtime_json");
      if(pre) pre.textContent = JSON.stringify(runtime, null, 2);
    } catch(e) {
      setScore(0);
      setRfConfidence(0);
      set("mission_state", "DASHBOARD DEGRADED");
      set("mission_state_detail", String(e));
      set("rf_state", "RF UNKNOWN");
      const pre = document.getElementById("runtime_json");
      if(pre) pre.textContent = String(e);
    }
  }

  function bindScenario(){
    document.querySelectorAll("[data-scenario]").forEach(btn => {
      btn.addEventListener("click", () => {
        document.querySelectorAll("[data-scenario]").forEach(b => b.classList.remove("selected"));
        btn.classList.add("selected");
        const id = btn.dataset.scenario;
        const s = scenarios[id] || scenarios.rural;
        set("scenario_region", s.region);
        set("scenario_risk", s.risk);
        set("scenario_last", s.label);
        set("scenario_state", "READY");
        localStorage.setItem("trfmc_v54_scenario", id);
      });
    });

    const saved = localStorage.getItem("trfmc_v54_scenario") || "rural";
    const target = document.querySelector('[data-scenario="' + saved + '"]');
    if(target) target.click();
  }

  function bindButtons(){
    const refreshBtn = document.getElementById("btn_refresh");
    const compactBtn = document.getElementById("btn_compact");
    const engBtn = document.getElementById("btn_engineering");

    if(refreshBtn) refreshBtn.addEventListener("click", refresh);

    if(compactBtn){
      compactBtn.addEventListener("click", () => {
        document.body.classList.toggle("compact");
        compactBtn.classList.toggle("active");
      });
    }

    if(engBtn){
      engBtn.addEventListener("click", () => {
        document.body.classList.toggle("show-engineering");
        engBtn.classList.toggle("active");
      });
    }
  }

  ready(function(){
    bindScenario();
    bindButtons();
    refresh();
    setInterval(refresh, 30000);
  });
})();
