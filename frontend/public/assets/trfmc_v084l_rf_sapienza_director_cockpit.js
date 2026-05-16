(function(){
  function ready(fn){ document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",fn) : fn(); }

  ready(()=>{
    document.body.classList.add("v84l-cockpit");

    document.title = "TRFMC v0.84L · RF Sapienza Director Cockpit";

    const h1 = document.querySelector("h1");
    if(h1) h1.textContent = "RF Sapienza Director Cockpit";

    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.84L · COMPACT RF LAYER GOVERNANCE";

    const heroText = document.querySelector(".hero p:last-child");
    if(heroText){
      heroText.textContent =
        "Director Cockpit RF Sapienza: i layer restano governabili, ma la plancia è più compatta, meno invasiva e più vicina a uno strumento T&M professionale.";
    }

    refineDirectorLabels();
    addCockpitStatus();
  });

  function refineDirectorLabels(){
    const map = {
      measure:"01 · Measure",
      "4d":"02 · 4D",
      teach:"03 · Teach",
      clean:"04 · Clean"
    };

    document.querySelectorAll(".director-modes button[data-mode]").forEach(btn=>{
      const mode = btn.dataset.mode;
      if(map[mode]) btn.textContent = map[mode];
    });

    const title = document.getElementById("directorModeTitle");
    if(title && title.textContent.trim()==="Measure Mode"){
      title.textContent = "MEASURE · PRIMARY";
    }

    const text = document.getElementById("directorModeText");
    if(text){
      text.textContent = "Vista primaria: superficie RF, vettori, probe UE e strumenti. Il layer 4D resta richiamabile, non dominante.";
    }
  }

  function addCockpitStatus(){
    if(document.querySelector(".cockpit-status")) return;

    const readout = document.querySelector(".director-readout");
    if(!readout) return;

    const box = document.createElement("div");
    box.className = "cockpit-status";
    box.innerHTML = `
      <span>Layer policy: governed</span>
      <span>Primary truth: IQ/PDP/H(f)/Budget</span>
      <span>Overlay: selectable</span>
    `;

    readout.appendChild(box);

    const style = document.createElement("style");
    style.textContent = `
      .cockpit-status{
        display:grid;
        gap:4px;
        margin-top:8px;
      }
      .cockpit-status span{
        display:block;
        border:1px solid rgba(143,240,255,.18);
        border-radius:10px;
        padding:4px 6px;
        color:rgba(232,250,255,.58);
        font-size:8.5px;
        letter-spacing:.08em;
        background:rgba(143,240,255,.035);
      }
      body.mode-4d .cockpit-status span:nth-child(3){
        color:#42f56f;
        border-color:rgba(66,245,111,.36);
      }
      body.mode-clean .cockpit-status span:nth-child(1){
        color:#8ff0ff;
        border-color:rgba(143,240,255,.34);
      }
    `;
    document.head.appendChild(style);
  }
})();
