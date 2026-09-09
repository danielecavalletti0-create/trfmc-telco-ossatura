(function(){
  const seasonProfiles = {
    spring: {loss: 7.2, factor:"Spring / 0.62", contract:"-8%", risk:"LOW", mode:"Spring · leaf growth", cap:"Spring growth · moderate wet foliage"},
    summer: {loss: 11.5, factor:"Summer / 0.91", contract:"-14%", risk:"MEDIUM", mode:"Summer · full canopy", cap:"Summer canopy · foliage loss · NLOS corridors"},
    autumn: {loss: 8.8, factor:"Autumn / 0.71", contract:"-10%", risk:"MEDIUM", mode:"Autumn · mixed canopy", cap:"Autumn foliage · scattering variability"},
    winter: {loss: 4.1, factor:"Winter / 0.34", contract:"-4%", risk:"LOW", mode:"Winter · low foliage", cap:"Winter profile · lower vegetation absorption"}
  };

  function qs(s){return document.querySelector(s)}
  function qsa(s){return Array.from(document.querySelectorAll(s))}

  function applySeason(name){
    const p = seasonProfiles[name] || seasonProfiles.summer;
    qs("#heroLoss").textContent = p.loss.toFixed(1) + " dB";
    qs("#lossVal").textContent = p.loss.toFixed(1) + " dB";
    qs("#seasonVal").textContent = p.factor;
    qs("#contractVal").textContent = p.contract;
    qs("#riskVal").textContent = p.risk;
    qs("#heroMode").textContent = p.mode;
    qs("#sceneCaption").textContent = p.cap;
    qs("#eventBus").innerHTML = "<b>AI RF Copilot</b><p>" + p.cap + " · attenuation model refreshed.</p>";

    document.body.dataset.season = name;
    qsa("[data-season]").forEach(b => b.classList.toggle("active", b.dataset.season === name));

    const scene = qs("#rfScene");
    if(scene) scene.style.setProperty("--season-loss", p.loss);
  }

  function updateControls(){
    const freq = Number(qs("#freq").value);
    const wet = Number(qs("#wet").value);
    const density = Number(qs("#density").value);
    const shadow = Number(qs("#shadow").value);

    const ghz = freq < 28 ? "700 MHz" : freq < 72 ? "3.5 GHz" : "28 GHz";
    qs("#freqVal").textContent = ghz;
    qs("#wetVal").textContent = wet + "%";
    qs("#densityVal").textContent = (0.45 + density/100).toFixed(2) + "x";
    qs("#shadowVal").textContent = shadow < 35 ? "low" : shadow < 70 ? "medium" : "high";

    const extraLoss = ((wet/100)*3.2 + (density/100)*4.6 + (shadow/100)*2.4);
    const season = document.body.dataset.season || "summer";
    const base = seasonProfiles[season].loss;
    const loss = Math.max(2, base + extraLoss - 5.5);

    qs("#lossVal").textContent = loss.toFixed(1) + " dB";
    qs("#heroLoss").textContent = loss.toFixed(1) + " dB";
    qs("#contractVal").textContent = "-" + Math.round(loss * 1.25) + "%";
    qs("#riskVal").textContent = loss > 13 ? "HIGH" : loss > 8 ? "MEDIUM" : "LOW";
  }

  document.addEventListener("DOMContentLoaded", () => {
    qsa("[data-season]").forEach(btn => btn.addEventListener("click", () => {
      applySeason(btn.dataset.season);
      updateControls();
    }));

    ["#freq","#wet","#density","#shadow"].forEach(id => {
      qs(id).addEventListener("input", updateControls);
    });

    qs("#windBtn").addEventListener("click", () => document.body.classList.toggle("wind"));
    qs("#focusBtn").addEventListener("click", () => document.body.classList.toggle("focus"));

    applySeason("summer");
    updateControls();
  });
})();
