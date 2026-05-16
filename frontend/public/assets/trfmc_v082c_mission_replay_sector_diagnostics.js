(function(){
  const qs = (s) => document.querySelector(s);
  const qsa = (s) => Array.from(document.querySelectorAll(s));

  let step = 0;
  let autoTimer = null;

  const scenarios = [
    {
      id:"baseline",
      name:"01 · Baseline RF",
      desc:"Copertura bilanciata C-band, clutter moderato, margine servizio stabile.",
      sliders:{freq:58, veg:34, shadow:24, noise:18, beam:58},
      sectors:[
        ["SITE-A","SERVING","RSRP -82 dBm · SINR 22 dB · low risk",86],
        ["SITE-B","ANCHOR","RSRP -79 dBm · SINR 24 dB · best server",91],
        ["SITE-C","LOAD","RSRP -88 dBm · SINR 18 dB · stable",76]
      ]
    },
    {
      id:"shadow",
      name:"02 · Urban Shadow",
      desc:"Edifici e canyon urbano generano ombra RF e contrazione di copertura.",
      sliders:{freq:64, veg:42, shadow:76, noise:30, beam:50},
      sectors:[
        ["SITE-A","DEGRADED","RSRP -96 dBm · SINR 11 dB · NLOS belt",54],
        ["SITE-B","EDGE","RSRP -91 dBm · SINR 14 dB · handover candidate",62],
        ["SITE-C","RECOVERY","RSRP -86 dBm · SINR 17 dB · secondary server",74]
      ]
    },
    {
      id:"foliage",
      name:"03 · Vegetation Loss",
      desc:"Fogliame e umidità aumentano attenuazione, fading lento e rischio cell-edge.",
      sliders:{freq:55, veg:82, shadow:46, noise:42, beam:56},
      sectors:[
        ["SITE-A","MARGIN","RSRP -92 dBm · SINR 13 dB · foliage loss",66],
        ["SITE-B","SERVING","RSRP -87 dBm · SINR 16 dB · sector hold",72],
        ["SITE-C","EDGE","RSRP -98 dBm · SINR 9 dB · weak margin",48]
      ]
    },
    {
      id:"handover",
      name:"04 · Handover Event",
      desc:"Il terminale entra in cintura di handover: dominanza tra SITE-B e SITE-C instabile.",
      sliders:{freq:62, veg:54, shadow:58, noise:62, beam:48},
      sectors:[
        ["SITE-A","OFFLOAD","RSRP -101 dBm · SINR 8 dB · low candidate",42],
        ["SITE-B","PING-PONG","RSRP -91 dBm · SINR 12 dB · unstable",58],
        ["SITE-C","PING-PONG","RSRP -90 dBm · SINR 13 dB · unstable",60]
      ]
    },
    {
      id:"recovery",
      name:"05 · Beam Recovery",
      desc:"Ricalibrazione beam/settore: aumenta dominanza, migliora SINR e riduce outage risk.",
      sliders:{freq:58, veg:42, shadow:38, noise:24, beam:86},
      sectors:[
        ["SITE-A","STABLE","RSRP -84 dBm · SINR 21 dB · clean sector",84],
        ["SITE-B","SERVING","RSRP -77 dBm · SINR 26 dB · dominant",96],
        ["SITE-C","ASSIST","RSRP -86 dBm · SINR 19 dB · load support",79]
      ]
    }
  ];

  function setSlider(id, value){
    const el = qs("#" + id);
    if(!el) return;
    el.value = value;
    el.dispatchEvent(new Event("input", {bubbles:true}));
  }

  function createPanel(){
    const control = qs(".control-panel");
    if(control && !qs(".v82c-mission-panel")){
      const panel = document.createElement("div");
      panel.className = "v82c-mission-panel";
      panel.innerHTML = `
        <h3>Mission Replay</h3>
        <span class="v82c-step-name" id="v82cStepName">—</span>
        <span class="v82c-step-desc" id="v82cStepDesc">—</span>
        <div class="v82c-step-bar"><i id="v82cStepBar"></i></div>
        <button class="v82c-auto" id="v82cAuto">Auto Replay: OFF</button>
      `;
      const legend = control.querySelector(".legend");
      control.insertBefore(panel, legend || null);
    }
  }

  function createStageOverlays(){
    const stage = qs(".webgl-stage");
    if(!stage) return;

    if(!qs(".v82c-sector-diag")){
      const diag = document.createElement("div");
      diag.className = "v82c-sector-diag";
      diag.innerHTML = `
        <div class="v82c-sector-card" data-sector="0">
          <header><b>SITE-A</b><span>—</span></header>
          <small>—</small><div class="meter"><i></i></div>
        </div>
        <div class="v82c-sector-card" data-sector="1">
          <header><b>SITE-B</b><span>—</span></header>
          <small>—</small><div class="meter"><i></i></div>
        </div>
        <div class="v82c-sector-card" data-sector="2">
          <header><b>SITE-C</b><span>—</span></header>
          <small>—</small><div class="meter"><i></i></div>
        </div>
      `;
      stage.appendChild(diag);
    }

    if(!qs(".v82c-timeline")){
      const timeline = document.createElement("div");
      timeline.className = "v82c-timeline";
      timeline.innerHTML = `
        <div class="v82c-timeline-title">RF Mission Replay Timeline</div>
        <div class="v82c-timeline-track">
          <div class="v82c-timeline-step">Baseline</div>
          <div class="v82c-timeline-step">Shadow</div>
          <div class="v82c-timeline-step">Foliage</div>
          <div class="v82c-timeline-step">Handover</div>
          <div class="v82c-timeline-step">Recovery</div>
        </div>
      `;
      stage.appendChild(timeline);
    }

    ["pa","pb","pc"].forEach(cls => {
      if(!qs(".v82c-pulse." + cls)){
        const p = document.createElement("div");
        p.className = "v82c-pulse " + cls;
        stage.appendChild(p);
      }
    });
  }

  function updateSectorCards(scenario){
    qsa(".v82c-sector-card").forEach((card, idx) => {
      const data = scenario.sectors[idx];
      if(!data) return;
      const b = card.querySelector("b");
      const span = card.querySelector("span");
      const small = card.querySelector("small");
      const meter = card.querySelector(".meter i");
      b.textContent = data[0];
      span.textContent = data[1];
      small.textContent = data[2];
      meter.style.width = data[3] + "%";
    });
  }

  function updateTimeline(){
    qsa(".v82c-timeline-step").forEach((el, idx) => {
      el.classList.toggle("active", idx === step);
    });
  }

  function applyScenario(idx){
    step = ((idx % scenarios.length) + scenarios.length) % scenarios.length;
    const s = scenarios[step];

    document.body.classList.add("v82c-replay");
    document.body.dataset.v82cStep = s.id;

    Object.entries(s.sliders).forEach(([id,value]) => setSlider(id,value));

    const name = qs("#v82cStepName");
    const desc = qs("#v82cStepDesc");
    const bar = qs("#v82cStepBar");

    if(name) name.textContent = s.name;
    if(desc) desc.textContent = s.desc;
    if(bar) bar.style.width = ((step + 1) / scenarios.length * 100).toFixed(0) + "%";

    updateSectorCards(s);
    updateTimeline();

    const eventBus = qs("#eventBus");
    if(eventBus){
      eventBus.innerHTML =
        "<b>AI RF Copilot</b><p>" +
        s.name + ": " + s.desc +
        " Sector diagnostics refreshed. Next gate: verify dominance, edge stability and recovery margin.</p>";
    }

    const caption = qs("#captionText");
    if(caption){
      caption.textContent = s.name + " · " + s.desc;
    }
  }

  function bindControls(){
    const scenarioBtn = qs("#scenarioBtn");
    if(scenarioBtn){
      scenarioBtn.textContent = "Mission Replay Step";
      scenarioBtn.addEventListener("click", () => {
        setTimeout(() => applyScenario(step + 1), 0);
      });
    }

    const auto = qs("#v82cAuto");
    if(auto){
      auto.addEventListener("click", () => {
        if(autoTimer){
          clearInterval(autoTimer);
          autoTimer = null;
          auto.textContent = "Auto Replay: OFF";
        } else {
          autoTimer = setInterval(() => applyScenario(step + 1), 3200);
          auto.textContent = "Auto Replay: ON";
        }
      });
    }
  }

  document.addEventListener("DOMContentLoaded", () => {
    document.body.classList.add("v82c-replay");
    document.title = "TRFMC v0.82C · Native WebGL Mission Replay";

    const eyebrow = qs(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.82C · MISSION REPLAY + SECTOR DIAGNOSTICS";

    createPanel();
    createStageOverlays();
    bindControls();

    setTimeout(() => applyScenario(0), 120);
  });
})();
