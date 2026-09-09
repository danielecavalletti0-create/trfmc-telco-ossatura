(function(){
  function ready(fn){ document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",fn) : fn(); }

  const modes = {
    measure: {
      title: "Measure Mode",
      text: "Vista strumentale pulita: campo, vettori, probe e strumenti. La priorità è leggere RSRP, SINR, EVM, PDP, H(f) e link budget."
    },
    "4d": {
      title: "4D Mode",
      text: "Attiva profondità, Fresnel/LOS/NLOS, reticolo temporale e theatre overlay. Utile per spiegare il comportamento dinamico del canale."
    },
    teach: {
      title: "Teach Mode",
      text: "Modalità docente: mantiene layer didattici e metodo Observe → Measure → Correlate → Explain. Pensata per aula e briefing tecnico."
    },
    clean: {
      title: "Clean Mode",
      text: "Vista pulita per screenshot, revisione e confronto. Spegne layer non essenziali e lascia respirare la scena."
    }
  };

  ready(()=>{
    document.body.classList.add("v84k-director");
    setMode("measure");

    document.title = "TRFMC v0.84K · RF Sapienza Layer Director";

    const h1 = document.querySelector("h1");
    if(h1) h1.textContent = "RF Sapienza Layer Director";

    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.84K · RF SAPIENZA LAYER GOVERNANCE";

    const heroText = document.querySelector(".hero p:last-child");
    if(heroText){
      heroText.textContent =
        "Direttore dei layer RF Sapienza: misura pura, teatro 4D, modalità docente e vista pulita convivono senza sovrapporsi. La scena diventa governabile, leggibile e pronta per uso didattico avanzato.";
    }

    installDirector();
    bindKeys();
  });

  function installDirector(){
    if(document.querySelector(".sapienza-director")) return;

    const hero = document.querySelector(".hero");
    if(!hero) return;

    const director = document.createElement("section");
    director.className = "sapienza-director";
    director.innerHTML = `
      <article>
        <h2>Layer Director</h2>
        <p>Da questo punto in poi non si aggiunge grafica a caso: ogni layer deve avere una funzione di misura, diagnosi o didattica.</p>
        <div class="sapienza-keys">
          <span>1 Measure</span>
          <span>2 4D</span>
          <span>3 Teach</span>
          <span>4 Clean</span>
        </div>
      </article>

      <div class="director-modes">
        <button data-mode="measure">Measure</button>
        <button data-mode="4d">4D</button>
        <button data-mode="teach">Teach</button>
        <button data-mode="clean">Clean</button>
      </div>

      <article class="director-readout">
        <b id="directorModeTitle">Measure Mode</b>
        <p id="directorModeText">Vista strumentale pulita.</p>
      </article>
    `;

    hero.insertAdjacentElement("afterend", director);

    director.querySelectorAll("button[data-mode]").forEach(btn=>{
      btn.addEventListener("click",()=>setMode(btn.dataset.mode));
    });

    refreshDirectorButtons("measure");
  }

  function bindKeys(){
    window.addEventListener("keydown",(ev)=>{
      if(ev.target && ["INPUT","TEXTAREA","SELECT"].includes(ev.target.tagName)) return;

      if(ev.key === "1") setMode("measure");
      if(ev.key === "2") setMode("4d");
      if(ev.key === "3") setMode("teach");
      if(ev.key === "4") setMode("clean");
    });
  }

  function setMode(mode){
    if(!modes[mode]) mode = "measure";

    document.body.classList.remove("mode-measure","mode-4d","mode-teach","mode-clean");
    document.body.classList.add("mode-" + mode);

    const title = document.getElementById("directorModeTitle");
    const text = document.getElementById("directorModeText");

    if(title) title.textContent = modes[mode].title;
    if(text) text.textContent = modes[mode].text;

    refreshDirectorButtons(mode);
  }

  function refreshDirectorButtons(mode){
    document.querySelectorAll(".director-modes button").forEach(btn=>{
      btn.classList.toggle("active", btn.dataset.mode === mode);
    });
  }
})();
