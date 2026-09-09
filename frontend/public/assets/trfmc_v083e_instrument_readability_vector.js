(function(){
  const $ = (s) => document.querySelector(s);

  function ensureReadabilityDock(){
    document.body.classList.add("v83e-readability");
    document.title = "TRFMC v0.83E · Instrument Readability + Vector Governance";

    const formula = $(".formula-dock");
    if(formula && !$(".v83e-readability-dock")){
      const dock = document.createElement("section");
      dock.className = "v83e-readability-dock";
      dock.innerHTML = `
        <article class="v83e-card">
          <h3>Visual Governance</h3>
          <code>Heatmap opacity < object readability < formula traceability</code>
          <p>La scena non deve coprire gli oggetti: sito, UE, edifici e vettore devono restare leggibili sopra il campo RF.</p>
        </article>
        <article class="v83e-card">
          <h3>Vector Rule</h3>
          <code>Best-server vector = line only · label = independent HUD</code>
          <p>La label non ruota più lungo il vettore e non sporca la zona UE/building. La linea resta un riferimento tecnico.</p>
        </article>
        <article class="v83e-card">
          <h3>Instrument Mode</h3>
          <code>Lower saturation · softer contours · readable physics</code>
          <p>Il canvas viene reso più strumentale: meno saturazione, meno sweep, più distinzione tra campo, oggetti e diagnostica.</p>
        </article>
      `;
      formula.insertAdjacentElement("beforebegin", dock);
    }

    const eyebrow = $(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.83E · INSTRUMENT READABILITY + VECTOR GOVERNANCE";

    const h1 = $("h1");
    if(h1) h1.textContent = "RF Instrument Readability + Vector Governance";
  }

  function ensureVectorLabel(){
    const stage = $(".stage");
    if(!stage) return;

    let label = $(".v83e-vector-label");
    if(!label){
      label = document.createElement("div");
      label.className = "v83e-vector-label";
      label.textContent = "BEST SERVER VECTOR · SITE-B → UE-42";
      stage.appendChild(label);
    }

    const ue = $(".ue2");
    const site = $(".site-b");
    if(!ue || !site) return;

    const sr = stage.getBoundingClientRect();
    const ur = ue.getBoundingClientRect();
    const br = site.getBoundingClientRect();

    const midX = ((ur.left + ur.width/2) + (br.left + br.width/2))/2 - sr.left;
    const midY = ((ur.top + ur.height/2) + (br.top + br.height/2))/2 - sr.top;

    label.style.left = Math.max(18, Math.min(sr.width - 290, midX + 22)) + "px";
    label.style.top = Math.max(18, Math.min(sr.height - 48, midY - 50)) + "px";
  }

  function updateCopilotReadability(){
    const copilot = $("#copilot");
    const rsrp = $("#rsrpVal")?.textContent || "—";
    const sinr = $("#sinrVal")?.textContent || "—";
    const cov = $("#coverageVal")?.textContent || "—";

    if(copilot){
      copilot.innerHTML = `
        <b>AI RF Copilot</b>
        <p>v83E readability mode attivo: RSRP=${rsrp}, SINR=${sinr}, coverage=${cov}.
        Best-server vector governato, heatmap de-saturata, oggetti fisici e link budget prioritari.</p>
      `;
    }
  }

  function bindLiveRefresh(){
    ["freqMHz","eirp","pathN","vegDepth","shadowDb","sectorGain","fading"].forEach(id => {
      const el = document.getElementById(id);
      if(el){
        el.addEventListener("input", () => {
          setTimeout(() => {
            ensureVectorLabel();
            updateCopilotReadability();
          }, 80);
        });
      }
    });

    window.addEventListener("resize", () => {
      setTimeout(ensureVectorLabel, 150);
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    setTimeout(() => {
      ensureReadabilityDock();
      ensureVectorLabel();
      updateCopilotReadability();
      bindLiveRefresh();
    }, 450);

    setTimeout(() => {
      ensureReadabilityDock();
      ensureVectorLabel();
      updateCopilotReadability();
    }, 1000);
  });
})();
