(function(){
  const VERSION = "TRFMC_V0_57A_EXECUTIVE_DASHBOARD_NEXT_HOLOGRAPHIC_MISSION_GLOBE";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function ensureGlobe(){
    const hero = document.querySelector(".hero-next");
    if(!hero || document.querySelector(".v57-holo-globe")) return;

    const globe = document.createElement("div");
    globe.className = "v57-holo-globe";
    globe.innerHTML = `
      <div class="v57-holo-sphere"></div>
      <div class="v57-holo-ring r1"></div>
      <div class="v57-holo-ring r2"></div>
      <div class="v57-holo-link l1"></div>
      <div class="v57-holo-link l2"></div>
      <div class="v57-holo-link l3"></div>
      <div class="v57-holo-node n1"></div>
      <div class="v57-holo-node n2"></div>
      <div class="v57-holo-node n3"></div>
      <div class="v57-holo-node n4"></div>
      <div class="v57-holo-label"><span>Global Mission Mesh</span><b id="v57_globe_state">SYNCHRONIZED</b></div>
    `;
    hero.appendChild(globe);
  }

  function ensureSpectrumTarget(){
    const spectrum = document.querySelector(".spectrum-window");
    if(!spectrum || document.querySelector(".v57-spectrum-target")) return;
    const target = document.createElement("div");
    target.className = "v57-spectrum-target";
    spectrum.appendChild(target);
  }

  function updateText(){
    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.57A · HOLOGRAPHIC MISSION GLOBE";

    const p = document.querySelector(".hero-copy p");
    if(p){
      p.textContent =
        "Plancia executive spaziale con mission globe olografico, RF/Telco intelligence, scenario command, KPI live, evidence posture e runtime readiness. Layout pulito preservato, impatto visivo elevato verso una vera console mission-control.";
    }

    const footer = document.querySelector(".next-footer");
    if(footer){
      footer.textContent = "TRFMC v0.57A · Executive Dashboard Next / Holographic Mission Globe · frontend-only · localhost-only · backend simulation-only";
    }

    document.title = "TRFMC v0.57A · Executive Dashboard Next Holographic Mission Globe";
  }

  function bindGlobeState(){
    const set = () => {
      const state = document.getElementById("v57_globe_state");
      const mission = document.getElementById("mission_state");
      if(state && mission){
        const t = mission.textContent || "";
        state.textContent = t.includes("READY") ? "SYNCHRONIZED" : "TRACKING";
      }
    };

    set();
    setInterval(set, 3000);
  }

  ready(function(){
    document.body.classList.add("v57-holographic-globe");
    ensureGlobe();
    ensureSpectrumTarget();
    updateText();
    bindGlobeState();
  });
})();
