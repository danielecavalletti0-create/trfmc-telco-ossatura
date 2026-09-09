(function(){
  const VERSION = "v0.81C-R2 physics visual discipline";

  const seasonProfiles = {
    spring: { leafDensity: 0.72, label:"Spring / 0.72", mode:"Spring · leaf growth", cap:"Spring growth · moderate foliage attenuation" },
    summer: { leafDensity: 1.00, label:"Summer / 1.00", mode:"Summer · full canopy", cap:"Summer canopy · maximum foliage attenuation" },
    autumn: { leafDensity: 0.64, label:"Autumn / 0.64", mode:"Autumn · mixed canopy", cap:"Autumn profile · variable wet foliage and scattering" },
    winter: { leafDensity: 0.16, label:"Winter / 0.16", mode:"Winter · low foliage", cap:"Winter profile · lower vegetation absorption" }
  };

  function qs(sel){ return document.querySelector(sel); }
  function qsa(sel){ return Array.from(document.querySelectorAll(sel)); }

  function clamp(v, min, max){ return Math.max(min, Math.min(max, v)); }

  function sliderToFreqGHz(raw){
    const v = Number(raw);
    if(v <= 30) return { ghz: 0.7, label: "700 MHz · macro layer" };
    if(v <= 70) return { ghz: 3.5, label: "3.5 GHz · C-band" };
    return { ghz: 28.0, label: "28 GHz · mmWave" };
  }

  function weissbergerLoss(freqGHz, depthM){
    if(depthM <= 0) return 0;
    if(depthM <= 14) return 0.45 * Math.pow(freqGHz, 0.284) * depthM;
    return 1.33 * Math.pow(freqGHz, 0.284) * Math.pow(depthM, 0.588);
  }

  function currentSeason(){
    return document.body.dataset.season || "summer";
  }

  function classifyRisk(totalLoss, freqGHz){
    if(totalLoss >= 26 || (freqGHz >= 24 && totalLoss >= 18)) return "CRITICAL";
    if(totalLoss >= 16) return "HIGH";
    if(totalLoss >= 8) return "MEDIUM";
    return "LOW";
  }

  function riskClass(risk){
    return "risk-" + risk.toLowerCase();
  }

  function updatePhysics(){
    const freqEl = qs("#freq");
    const wetEl = qs("#wet");
    const depthEl = qs("#density");
    const shadowEl = qs("#shadow");

    if(!freqEl || !wetEl || !depthEl || !shadowEl) return;

    const freq = sliderToFreqGHz(freqEl.value);
    const wetPct = Number(wetEl.value);
    const depthM = 5 + (Number(depthEl.value) / 100) * 45;
    const shadowPct = Number(shadowEl.value);

    const seasonKey = currentSeason();
    const season = seasonProfiles[seasonKey] || seasonProfiles.summer;

    const dryVegLoss = weissbergerLoss(freq.ghz, depthM);
    const wetMultiplier = 1 + ((wetPct / 100) * 0.38);
    const vegLoss = dryVegLoss * season.leafDensity * wetMultiplier;

    const urbanShadowLoss = (shadowPct / 100) * Math.sqrt(freq.ghz) * 3.2;
    const totalLoss = vegLoss + urbanShadowLoss;

    const contraction = clamp(Math.round(totalLoss * 1.75), 0, 99);
    const risk = classifyRisk(totalLoss, freq.ghz);

    const freqVal = qs("#freqVal");
    const wetVal = qs("#wetVal");
    const densityVal = qs("#densityVal");
    const shadowVal = qs("#shadowVal");
    const heroLoss = qs("#heroLoss");
    const heroMode = qs("#heroMode");
    const lossVal = qs("#lossVal");
    const seasonVal = qs("#seasonVal");
    const contractVal = qs("#contractVal");
    const riskVal = qs("#riskVal");
    const sceneCaption = qs("#sceneCaption");
    const eventBus = qs("#eventBus");

    if(freqVal) freqVal.textContent = freq.label;
    if(wetVal) wetVal.textContent = wetPct + "%";
    if(densityVal) densityVal.textContent = depthM.toFixed(1) + " m";
    if(shadowVal) shadowVal.textContent = shadowPct < 35 ? "low" : shadowPct < 70 ? "medium" : "severe";

    if(heroLoss) heroLoss.textContent = totalLoss.toFixed(1) + " dB";
    if(heroMode) heroMode.textContent = season.mode;
    if(lossVal) lossVal.textContent = vegLoss.toFixed(2) + " dB";
    if(seasonVal) seasonVal.textContent = season.label;
    if(contractVal) contractVal.textContent = "-" + contraction + "%";

    if(riskVal){
      riskVal.textContent = risk;
      riskVal.classList.remove("risk-low","risk-medium","risk-high","risk-critical");
      riskVal.classList.add(riskClass(risk));
    }

    if(sceneCaption) {
      sceneCaption.textContent = season.cap + " · f=" + freq.ghz + " GHz · d=" + depthM.toFixed(1) + " m";
    }

    if(eventBus){
      eventBus.innerHTML =
        "<b>AI RF Copilot</b>" +
        "<p>Weissberger engine active. Lveg=" + vegLoss.toFixed(2) +
        " dB, Lshadow=" + urbanShadowLoss.toFixed(2) +
        " dB, total=" + totalLoss.toFixed(2) + " dB.</p>";
    }

    document.body.dataset.v81cR2TotalLoss = totalLoss.toFixed(2);
    document.body.dataset.v81cR2VegLoss = vegLoss.toFixed(2);
    document.body.dataset.v81cR2Risk = risk;
  }

  function installSeasonBridge(){
    qsa("[data-season]").forEach(btn => {
      btn.addEventListener("click", () => {
        setTimeout(updatePhysics, 0);
      });
    });
  }

  function installFormulaBox(){
    const telemetry = qs(".telemetry");
    if(!telemetry || telemetry.querySelector(".v81c-r2-formula")) return;

    const box = document.createElement("div");
    box.className = "v81c-r2-formula";
    box.innerHTML =
      "<b>Physics model</b><br>" +
      "Weissberger MED: L=0.45 f^0.284 d for d<=14 m; " +
      "L=1.33 f^0.284 d^0.588 for d>14 m. " +
      "Wetness and seasonal foliage are applied as controlled multipliers.";
    telemetry.appendChild(box);
  }

  function installBadge(){
    if(document.querySelector(".v81c-r2-badge")) return;
    const b = document.createElement("div");
    b.className = "v81c-r2-badge";
    b.textContent = VERSION;
    document.body.appendChild(b);
  }

  document.addEventListener("DOMContentLoaded", () => {
    document.body.classList.add("v81c-r2-physics");
    document.title = "TRFMC v0.81C-R2 · Vegetation Physics Visual Sandbox";

    const eyebrow = qs(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.81C-R2 · RF PHYSICS + VISUAL DISCIPLINE";

    const densityLabel = qs("label:nth-of-type(3) span");
    if(densityLabel) densityLabel.textContent = "Vegetation depth along path";

    const small = qs(".telemetry .metric:nth-of-type(1) small");
    if(small) small.textContent = "Weissberger modified exponential decay estimate";

    ["#freq","#wet","#density","#shadow"].forEach(sel => {
      const el = qs(sel);
      if(el) el.addEventListener("input", updatePhysics);
    });

    installSeasonBridge();
    installFormulaBox();
    installBadge();

    setTimeout(updatePhysics, 0);
  });
})();
