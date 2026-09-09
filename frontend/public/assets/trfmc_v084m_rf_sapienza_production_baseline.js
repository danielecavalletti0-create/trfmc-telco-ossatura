(function(){
  function ready(fn){ document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",fn) : fn(); }

  ready(()=>{
    document.body.classList.add("v84m-baseline");

    document.title = "TRFMC v0.84M · RF Sapienza Production Baseline";

    const h1 = document.querySelector("h1");
    if(h1) h1.textContent = "RF Sapienza Production Baseline";

    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.84M · PRODUCTION BASELINE CANDIDATE";

    const heroText = document.querySelector(".hero p:last-child");
    if(heroText){
      heroText.textContent =
        "Baseline RF Sapienza: plancia governata, gerarchia pulita, evidence chain esplicita e strumenti leggibili. Candidata a base stabile per didattica, misura e mission replay.";
    }

    installEvidenceChain();
    refineBaselineModeText();
    addBaselineHotkeys();
  });

  function installEvidenceChain(){
    if(document.querySelector(".sapienza-evidence-chain")) return;

    const director = document.querySelector(".sapienza-director");
    if(!director) return;

    const chain = document.createElement("section");
    chain.className = "sapienza-evidence-chain";
    chain.innerHTML = `
      <article class="ok">
        <b>01 · Geometry</b>
        <span>Siti, UE, ostacoli, corridoi NLOS e vettore serving devono essere leggibili prima della diagnosi.</span>
      </article>
      <article class="ok">
        <b>02 · Channel</b>
        <span>Path loss, shadowing, delay spread, fading e coerenza spaziale spiegano la forma del campo.</span>
      </article>
      <article class="warn">
        <b>03 · Signal</b>
        <span>IQ, EVM, PDP e H(f) validano la qualità reale: nessuna conclusione nasce dal solo colore.</span>
      </article>
      <article class="ok">
        <b>04 · Decision</b>
        <span>Best server, margine, edge, SINR stress e outage devono derivare dalla catena di misura.</span>
      </article>
      <article class="critical">
        <b>05 · Teaching</b>
        <span>L’allievo deve imparare il metodo: osservare, misurare, correlare, spiegare.</span>
      </article>
    `;

    director.insertAdjacentElement("afterend", chain);
  }

  function refineBaselineModeText(){
    const title = document.getElementById("directorModeTitle");
    const text = document.getElementById("directorModeText");

    if(title) title.textContent = "MEASURE · BASELINE";
    if(text){
      text.textContent =
        "Baseline primaria: scena RF governata, evidence chain attiva, strumenti leggibili e overlay selezionabili.";
    }

    document.querySelectorAll(".director-modes button[data-mode]").forEach(btn=>{
      const m = btn.dataset.mode;
      if(m === "measure") btn.textContent = "01 · Measure";
      if(m === "4d") btn.textContent = "02 · 4D";
      if(m === "teach") btn.textContent = "03 · Teach";
      if(m === "clean") btn.textContent = "04 · Clean";
    });
  }

  function addBaselineHotkeys(){
    const style = document.createElement("style");
    style.textContent = `
      body.v84m-baseline .stage:after{
        content:"BASELINE · GEOMETRY → CHANNEL → SIGNAL → DECISION → TEACHING";
      }
      body.v84m-baseline.mode-measure .stage:after{
        content:"MEASURE BASELINE · FIELD + VECTOR + INSTRUMENT PROOF";
      }
      body.v84m-baseline.mode-4d .stage:after{
        content:"4D BASELINE · FRESNEL / LOS-NLOS / TEMPORAL PROBE";
      }
      body.v84m-baseline.mode-teach .stage:after{
        content:"TEACH BASELINE · OBSERVE → MEASURE → CORRELATE → EXPLAIN";
      }
      body.v84m-baseline.mode-clean .stage:after{
        content:"CLEAN BASELINE · SCREENSHOT / REVIEW READY";
      }
    `;
    document.head.appendChild(style);
  }
})();
