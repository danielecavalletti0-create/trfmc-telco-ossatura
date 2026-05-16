(function(){
  function ready(fn){ document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",fn) : fn(); }

  ready(()=>{
    document.body.classList.add("v85c-identity");
    document.title = "TRFMC v0.85C · RF Physics Sapienza Identity Baseline";

    forceIdentity();
    installIdentityStrip();
    installIdentityBadge();
    bridgeCleanMode();
  });

  function forceIdentity(){
    const h1s = [...document.querySelectorAll("h1")];

    if(h1s.length){
      const largest = h1s.sort((a,b)=>{
        const af = parseFloat(getComputedStyle(a).fontSize || "0");
        const bf = parseFloat(getComputedStyle(b).fontSize || "0");
        return bf - af;
      })[0];

      largest.textContent = "RF Physics Sapienza Identity Baseline";
    }

    const all = [...document.querySelectorAll("p, small, .eyebrow, .subtitle, .kicker")];

    for(const el of all){
      const txt = (el.textContent || "").trim();

      if(/TRFMC v0\.85|TRFMC v0\.83|RF PHYSICS|instrument readability/i.test(txt)){
        el.textContent = "TRFMC v0.85C · RF PHYSICS SAPIENZA IDENTITY · formula-driven · evidence-governed · no overwrite";
        break;
      }
    }

    // Corregge eventuali bottoni/nav ancora ambigui
    document.querySelectorAll("a, button").forEach(el=>{
      if((el.textContent || "").includes("v85B")) {
        el.textContent = el.textContent.replace("v85B","v85C");
      }
    });

    const readoutTitle = document.getElementById("v85bModeTitle");
    const readoutText = document.getElementById("v85bModeText");

    if(readoutTitle) readoutTitle.textContent = "MEASURE · PHYSICS IDENTITY";
    if(readoutText) {
      readoutText.textContent = "Identità corretta: la pagina è ora una baseline RF Physics Sapienza, con formula, misura e catena di evidenza allineate.";
    }
  }

  function installIdentityStrip(){
    if(document.querySelector(".sapienza-v85c-identity-strip")) return;

    const director = document.querySelector(".sapienza-v85b-director");
    const anchor = director || document.querySelector(".hero, .intro, section");

    if(!anchor) return;

    const strip = document.createElement("section");
    strip.className = "sapienza-v85c-identity-strip";
    strip.innerHTML = `
      <article>
        <b>Identity Fix</b>
        <span>Titolo, badge e readout sono riallineati: questa pagina non è più una variante v83F, ma baseline physics v85C.</span>
      </article>
      <article>
        <b>Formula First</b>
        <span>FSPL, log-distance, clutter, fading, SINR e link budget guidano la scena; il colore resta conseguenza.</span>
      </article>
      <article>
        <b>Instrument Proof</b>
        <span>IQ/EVM, PDP, H(f), probe UE e best-server sono la prova della diagnosi.</span>
      </article>
      <article>
        <b>Promotion Gate</b>
        <span>Se passa il controllo visivo, può diventare il primo template physics riutilizzabile.</span>
      </article>
    `;

    anchor.insertAdjacentElement("afterend", strip);
  }

  function installIdentityBadge(){
    if(document.querySelector(".sapienza-v85c-badge")) return;

    const b = document.createElement("div");
    b.className = "sapienza-v85c-badge";
    b.textContent = "v0.85C · RF PHYSICS IDENTITY BASELINE";
    document.body.appendChild(b);
  }

  function bridgeCleanMode(){
    window.addEventListener("keydown",(ev)=>{
      if(ev.target && ["INPUT","TEXTAREA","SELECT"].includes(ev.target.tagName)) return;

      if(ev.key === "4"){
        document.body.classList.add("v85c-mode-clean");
      }

      if(["1","2","3"].includes(ev.key)){
        document.body.classList.remove("v85c-mode-clean");
      }
    });

    document.querySelectorAll("button[data-mode]").forEach(btn=>{
      btn.addEventListener("click",()=>{
        if(btn.dataset.mode === "clean") {
          document.body.classList.add("v85c-mode-clean");
        } else {
          document.body.classList.remove("v85c-mode-clean");
        }
      });
    });
  }
})();
