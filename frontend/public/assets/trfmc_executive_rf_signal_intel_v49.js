(function(){
  const VERSION = "TRFMC_V0_49A_EXECUTIVE_RF_TELCO_SIGNAL_INTELLIGENCE";
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

  function klass(id, state){
    const el = document.getElementById(id);
    if(!el) return;
    el.classList.remove("good", "warn", "bad");
    el.classList.add(state || "good");
  }

  function num(v, digits=1){
    if(v === null || v === undefined || Number.isNaN(Number(v))) return "—";
    return Number(v).toFixed(digits);
  }

  function setConfidence(percent){
    const p = Math.max(0, Math.min(100, Number(percent || 0)));
    const deg = Math.round((p / 100) * 280);
    const gauge = document.querySelector(".v49-confidence-wrap");
    if(gauge) gauge.style.setProperty("--v49-confidence-deg", deg + "deg");
    set("v49_rf_confidence", Math.round(p) + "%");
  }

  async function refreshRfIntel(){
    try {
      const portal = await getJson(API + "/portal/health-summary");
      const coverage = await getJson(API + "/rf-coverage/demo").catch(() => ({}));
      const field = await getJson(API + "/rf-field/demo").catch(() => ({}));

      const counts = portal.high_value_counts || {};
      const link = coverage.target_link || {};
      const wave = field.wave || {};
      const regions = field.regions || {};
      const antenna = field.antenna || {};
      const fieldResult = field.field || field.target_field || {};
      const frequencyHz = coverage.frequency_hz || field.frequency_hz || 0;
      const freqGhz = frequencyHz ? frequencyHz / 1e9 : 0;

      const rxPower = Number(link.rx_power_dbm);
      const snr = Number(link.snr_db);
      const loss = Number(link.total_path_loss_db);
      const losState = link.los_state || link.target_los_state || (link.obstacle_hits && link.obstacle_hits.length ? "NLOS" : "LOS/NLOS");
      const region = fieldResult.field_region || field.field_region || "RF FIELD";

      let confidence = 50;
      if(!Number.isNaN(rxPower)) confidence += Math.max(-20, Math.min(20, (rxPower + 80) / 2));
      if(!Number.isNaN(snr)) confidence += Math.max(-15, Math.min(20, snr / 2));
      if(losState === "LOS") confidence += 10;
      if(String(losState).includes("NLOS")) confidence -= 8;
      if((counts.rf_coverage_runs || 0) > 0) confidence += 8;
      if((counts.rf_field_runs || 0) > 0) confidence += 8;

      const status = confidence >= 78 ? "RF PATH READY" : confidence >= 55 ? "RF PATH WATCH" : "RF PATH DEGRADED";

      set("v49_rf_state", status);
      set("v49_rf_detail", VERSION + " · " + new Date().toLocaleTimeString());
      setConfidence(confidence);

      set("v49_rf_status", status);
      set("v49_rf_status_detail", "frequency " + (freqGhz ? num(freqGhz,3) + " GHz" : "—") + " · " + losState + " · " + region);

      set("v49_frequency", freqGhz ? num(freqGhz,3) + " GHz" : "—");
      set("v49_wavelength", wave.wavelength_m ? num(wave.wavelength_m,4) + " m" : "—");
      set("v49_path_loss", !Number.isNaN(loss) ? num(loss,1) + " dB" : "—");
      set("v49_rx_power", !Number.isNaN(rxPower) ? num(rxPower,1) + " dBm" : "—");
      set("v49_snr", !Number.isNaN(snr) ? num(snr,1) + " dB" : "—");
      set("v49_los_state", losState);
      set("v49_field_region", region);
      set("v49_obstacles", link.obstacle_hits ? String(link.obstacle_hits.length) : "—");
      set("v49_coverage_runs", String(counts.rf_coverage_runs ?? "—"));
      set("v49_field_runs", String(counts.rf_field_runs ?? "—"));
      set("v49_antenna", antenna.gain_to_target_dbi !== undefined ? num(antenna.gain_to_target_dbi,1) + " dBi" : "—");
      set("v49_bearing", antenna.bearing_to_target_deg !== undefined ? num(antenna.bearing_to_target_deg,1) + "°" : "—");

      klass("v49_tile_rx", !Number.isNaN(rxPower) && rxPower > -70 ? "good" : "warn");
      klass("v49_tile_snr", !Number.isNaN(snr) && snr > 12 ? "good" : "warn");
      klass("v49_tile_loss", !Number.isNaN(loss) && loss < 120 ? "good" : "warn");
      klass("v49_tile_los", String(losState).includes("NLOS") ? "warn" : "good");
      klass("v49_tile_region", "good");
      klass("v49_tile_runs", (counts.rf_coverage_runs && counts.rf_field_runs) ? "good" : "warn");

      const carrier = document.querySelector(".v49-spectrum-carrier");
      if(carrier){
        const left = Math.max(22, Math.min(78, confidence));
        carrier.style.setProperty("--v49-carrier-left", left + "%");
      }
    } catch(e) {
      set("v49_rf_state", "RF INTEL DEGRADED");
      set("v49_rf_detail", String(e));
      set("v49_rf_status", "RF INTEL ERROR");
      set("v49_rf_status_detail", String(e));
      setConfidence(0);
      klass("v49_tile_rx", "bad");
    }
  }

  function addToV47Navigator(){
    const links = document.querySelector(".v47-section-links");
    if(!links || document.querySelector('[data-v47-target="v49_rf_intel"]')) return;

    const a = document.createElement("a");
    a.href = "#v49_rf_intel";
    a.dataset.v47Target = "v49_rf_intel";
    a.textContent = "RF Intel";
    links.insertBefore(a, links.firstChild);
  }

  ready(function(){
    const section = document.querySelector(".v49-rf-intel-strip");
    if(section && !section.id) section.id = "v49_rf_intel";

    addToV47Navigator();
    refreshRfIntel();
    setInterval(refreshRfIntel, 30000);
  });
})();
