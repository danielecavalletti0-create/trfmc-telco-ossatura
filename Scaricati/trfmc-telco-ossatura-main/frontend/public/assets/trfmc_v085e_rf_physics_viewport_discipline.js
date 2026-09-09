(function(){
  const FINAL_TITLE = "RF Physics Sapienza Lock";
  const FINAL_KICKER = "TRFMC v0.85E · RF PHYSICS SAPIENZA · VIEWPORT DISCIPLINE · FORMULA-DRIVEN · EVIDENCE-GOVERNED";

  function ready(fn){
    document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", fn) : fn();
  }

  ready(()=>{
    document.body.classList.add("v85e-polish");
    hardPatch();
    installSingleRibbon();
    installBadge();
    bindCleanMode();
    installObserver();

    [50,150,350,800,1400].forEach(ms => setTimeout(hardPatch, ms));
  });

  function hardPatch(){
    document.title = "TRFMC v0.85E · " + FINAL_TITLE;

    const title = findPrimaryTitle();
    if(title){
      title.textContent = FINAL_TITLE;
      title.classList.add("trfmc-runtime-title-lock");
      title.setAttribute("data-trfmc-v85e-title","locked");
    }

    const textSlots = [...document.querySelectorAll("p, small, .eyebrow, .kicker, .subtitle")];
    const slot = textSlots.find(el => /TRFMC|formula|evidence|runtime|viewport|sapienza/i.test(el.textContent || ""));
    if(slot) slot.textContent = FINAL_KICKER;

    const readoutTitle = document.getElementById("v85bModeTitle");
    const readoutText = document.getElementById("v85bModeText");

    if(readoutTitle) readoutTitle.textContent = "MEASURE · VIEWPORT DISCIPLINE";
    if(readoutText) {
      readoutText.textContent = "Titolo compatto, una sola ribbon dottrinale, canvas più alto e lettura RF più pulita.";
    }

    document.querySelectorAll("a,button").forEach(el=>{
      const t = el.textContent || "";
      if(t.includes("v85D")) el.textContent = t.replace("v85D","v85E");
      if(t.includes("v85C")) el.textContent = t.replace("v85C","v85E");
    });
  }

  function findPrimaryTitle(){
    const candidates = [
      ...document.querySelectorAll("h1"),
      ...document.querySelectorAll(".title"),
      ...document.querySelectorAll(".hero-title"),
      ...document.querySelectorAll("[class*='title']"),
      ...document.querySelectorAll("[class*='Title']")
    ];

    if(!candidates.length) return null;

    return candidates.sort((a,b)=>{
      const af = parseFloat(getComputedStyle(a).fontSize || "0");
      const bf = parseFloat(getComputedStyle(b).fontSize || "0");
      return bf - af;
    })[0];
  }

  function installSingleRibbon(){
    if(document.querySelector(".v85e-proof-ribbon")) return;

    const anchor =
      document.querySelector(".sapienza-v85b-director") ||
      document.querySelector(".hero, .intro, section");

    if(!anchor) return;

    const ribbon = document.createElement("section");
    ribbon.className = "v85e-proof-ribbon";
    ribbon.innerHTML = `
      <article>
        <b>01 · Geometry</b>
        <span>Siti, UE, ostacoli e vettori restano leggibili.</span>
      </article>
      <article>
        <b>02 · Channel</b>
        <span>Path loss, shadowing, fading e delay spiegano il campo.</span>
      </article>
      <article>
        <b>03 · Signal</b>
        <span>IQ/EVM, PDP e H(f) confermano la qualità.</span>
      </article>
      <article>
        <b>04 · Decision</b>
        <span>Best-server e SINR derivano da budget e misura.</span>
      </article>
      <article>
        <b>05 · Teach</b>
        <span>Osserva, misura, correla, spiega.</span>
      </article>
    `;

    anchor.insertAdjacentElement("afterend", ribbon);
  }

  function installBadge(){
    if(document.querySelector(".v85e-badge")) return;

    const b = document.createElement("div");
    b.className = "v85e-badge";
    b.textContent = "v0.85E · VIEWPORT DISCIPLINE";
    document.body.appendChild(b);
  }

  function installObserver(){
    if(!("MutationObserver" in window)) return;

    const obs = new MutationObserver(()=>{
      clearTimeout(window.__trfmcV85eTimer);
      window.__trfmcV85eTimer = setTimeout(hardPatch, 40);
    });

    obs.observe(document.body, {
      childList:true,
      subtree:true,
      characterData:true
    });
  }

  function bindCleanMode(){
    window.addEventListener("keydown",(ev)=>{
      if(ev.target && ["INPUT","TEXTAREA","SELECT"].includes(ev.target.tagName)) return;

      if(ev.key === "4") document.body.classList.add("v85e-mode-clean");
      if(["1","2","3"].includes(ev.key)) document.body.classList.remove("v85e-mode-clean");
    });

    document.addEventListener("click",(ev)=>{
      const btn = ev.target.closest && ev.target.closest("button[data-mode]");
      if(!btn) return;

      if(btn.dataset.mode === "clean") {
        document.body.classList.add("v85e-mode-clean");
      } else {
        document.body.classList.remove("v85e-mode-clean");
      }
    });
  }
})();
