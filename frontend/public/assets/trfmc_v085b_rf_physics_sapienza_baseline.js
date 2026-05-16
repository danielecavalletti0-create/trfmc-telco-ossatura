(function(){
  function ready(fn){ document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",fn) : fn(); }

  const modes = {
    measure: {
      title:"MEASURE · PHYSICS",
      text:"Vista primaria: RSRP, SINR, path loss, clutter, serving decision e strumenti restano la verità operativa."
    },
    "4d": {
      title:"4D · CHANNEL",
      text:"Lettura dinamica: fading, delay spread, spatial consistency e variazione locale del campo."
    },
    teach: {
      title:"TEACH · METHOD",
      text:"Modalità docente: ogni conclusione deve passare da geometria, canale, segnale, decisione e spiegazione."
    },
    clean: {
      title:"CLEAN · REVIEW",
      text:"Vista pulita per screenshot e revisione. Nessuna catena didattica visibile, solo scena e strumenti."
    }
  };

  ready(()=>{
    document.body.classList.add("v85b-physics");
    setMode("measure");
    document.title = "TRFMC v0.85B · RF Physics Sapienza Baseline";

    patchHeader();
    installDirector();
    installEvidenceChain();
    installBadge();
    bindKeys();
  });

  function patchHeader(){
    const h1 = document.querySelector("h1");
    if(h1) h1.textContent = "RF Physics Sapienza Baseline";

    const candidates = [...document.querySelectorAll("p, small, .eyebrow")];
    const e = candidates.find(x => /TRFMC|v0\.83|v85/i.test(x.textContent || ""));
    if(e) e.textContent = "TRFMC v0.85B · RF PHYSICS SAPIENZA BASELINE · formula-driven · evidence-governed";
  }

  function installDirector(){
    if(document.querySelector(".sapienza-v85b-director")) return;

    const anchor = document.querySelector(".hero, .intro, section");
    if(!anchor) return;

    const d = document.createElement("section");
    d.className = "sapienza-v85b-director";
    d.innerHTML = `
      <article>
        <h2>Physics Director</h2>
        <p>Applicazione dottrina v85: nessun colore senza misura, nessuna decisione senza catena RF.</p>
      </article>
      <div class="sapienza-v85b-modes">
        <button data-mode="measure">01 · Measure</button>
        <button data-mode="4d">02 · 4D</button>
        <button data-mode="teach">03 · Teach</button>
        <button data-mode="clean">04 · Clean</button>
      </div>
      <article class="sapienza-v85b-readout">
        <b id="v85bModeTitle">MEASURE · PHYSICS</b>
        <p id="v85bModeText">Vista primaria.</p>
      </article>
    `;

    anchor.insertAdjacentElement("afterend", d);

    d.querySelectorAll("button[data-mode]").forEach(btn=>{
      btn.addEventListener("click",()=>setMode(btn.dataset.mode));
    });

    refreshButtons("measure");
  }

  function installEvidenceChain(){
    if(document.querySelector(".sapienza-v85b-chain")) return;

    const director = document.querySelector(".sapienza-v85b-director");
    if(!director) return;

    const chain = document.createElement("section");
    chain.className = "sapienza-v85b-chain";
    chain.innerHTML = `
      <article>
        <b>01 · Geometry</b>
        <span>Settori, UE, ostacoli e vettori devono restare distinguibili prima della formula.</span>
      </article>
      <article>
        <b>02 · Channel</b>
        <span>Path loss, shadowing, fading e delay spread spiegano perché il campo cambia.</span>
      </article>
      <article>
        <b>03 · Signal</b>
        <span>IQ, EVM, PDP e H(f) validano qualità e degradazione: mai solo colore.</span>
      </article>
      <article>
        <b>04 · Decision</b>
        <span>Best server, edge, outage e SINR stress devono derivare da budget e misura.</span>
      </article>
      <article>
        <b>05 · Teaching</b>
        <span>Lo studente deve vedere il metodo: osservare, misurare, correlare, spiegare.</span>
      </article>
    `;

    director.insertAdjacentElement("afterend", chain);
  }

  function installBadge(){
    if(document.querySelector(".sapienza-v85b-badge")) return;
    const b = document.createElement("div");
    b.className = "sapienza-v85b-badge";
    b.textContent = "v0.85B · PHYSICS BASELINE CANDIDATE";
    document.body.appendChild(b);
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

    document.body.classList.remove("v85b-mode-measure","v85b-mode-4d","v85b-mode-teach","v85b-mode-clean");
    document.body.classList.add("v85b-mode-" + mode);

    const title = document.getElementById("v85bModeTitle");
    const text = document.getElementById("v85bModeText");

    if(title) title.textContent = modes[mode].title;
    if(text) text.textContent = modes[mode].text;

    refreshButtons(mode);
  }

  function refreshButtons(mode){
    document.querySelectorAll(".sapienza-v85b-modes button").forEach(btn=>{
      btn.classList.toggle("active", btn.dataset.mode === mode);
    });
  }
})();
