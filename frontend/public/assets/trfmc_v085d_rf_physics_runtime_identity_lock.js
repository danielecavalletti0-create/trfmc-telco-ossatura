(function(){
  const FINAL_TITLE = "RF Physics Sapienza Runtime Identity Lock";
  const FINAL_KICKER = "TRFMC v0.85D · RF PHYSICS SAPIENZA · RUNTIME IDENTITY LOCK · FORMULA-DRIVEN · EVIDENCE-GOVERNED";

  const OLD_PATTERNS = [
    /RF\s+Instrument\s+Readability\s*\+\s*Vector\s+Governance/i,
    /Instrument\s+Readability/i,
    /Vector\s+Governance/i,
    /TRFMC\s+v0\.83F/i,
    /TRFMC\s+v0\.85B/i,
    /TRFMC\s+v0\.85C/i
  ];

  function ready(fn){
    if(document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  ready(()=>{
    document.body.classList.add("v85d-identity-lock");
    document.title = "TRFMC v0.85D · " + FINAL_TITLE;

    hardPatch();
    installLockStrip();
    installBadge();
    installObserver();
    bindCleanMode();

    // Patch ripetute per battere eventuali script precedenti che riscrivono dopo il load.
    [50,150,300,700,1200,2000].forEach(ms => setTimeout(hardPatch, ms));
    requestAnimationFrame(hardPatch);
  });

  function isOldText(text){
    return OLD_PATTERNS.some(rx => rx.test(text || ""));
  }

  function hardPatch(){
    document.title = "TRFMC v0.85D · " + FINAL_TITLE;

    patchMainTitle();
    patchTextNodes();
    patchModeReadout();
    patchLinks();
  }

  function patchMainTitle(){
    const candidates = [
      ...document.querySelectorAll("h1"),
      ...document.querySelectorAll(".title"),
      ...document.querySelectorAll(".hero-title"),
      ...document.querySelectorAll("[class*='title']"),
      ...document.querySelectorAll("[class*='Title']")
    ];

    let target = null;

    for(const el of candidates){
      const txt = (el.textContent || "").trim();
      if(isOldText(txt) || /RF\s+Physics\s+Sapienza/i.test(txt)){
        target = el;
        break;
      }
    }

    if(!target && candidates.length){
      target = candidates.sort((a,b)=>{
        const af = parseFloat(getComputedStyle(a).fontSize || "0");
        const bf = parseFloat(getComputedStyle(b).fontSize || "0");
        return bf - af;
      })[0];
    }

    if(target){
      target.textContent = FINAL_TITLE;
      target.classList.add("trfmc-runtime-title-lock");
      target.setAttribute("data-trfmc-identity-lock","v85d");
    }
  }

  function patchTextNodes(){
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode(node){
          const t = node.nodeValue || "";
          return isOldText(t) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
        }
      }
    );

    const nodes = [];
    while(walker.nextNode()) nodes.push(walker.currentNode);

    nodes.forEach(node=>{
      node.nodeValue = node.nodeValue
        .replace(/RF\s+Instrument\s+Readability\s*\+\s*Vector\s+Governance/gi, FINAL_TITLE)
        .replace(/RF\s+Instrument\s+Readability/gi, "RF Physics Sapienza")
        .replace(/Vector\s+Governance/gi, "Runtime Formula Governance")
        .replace(/TRFMC\s+v0\.83F/gi, "TRFMC v0.85D")
        .replace(/TRFMC\s+v0\.85B/gi, "TRFMC v0.85D")
        .replace(/TRFMC\s+v0\.85C/gi, "TRFMC v0.85D");
    });

    const smalls = [...document.querySelectorAll("p,small,.eyebrow,.kicker,.subtitle")];
    const slot = smalls.find(el => /TRFMC|formula|evidence|instrument/i.test(el.textContent || ""));
    if(slot) slot.textContent = FINAL_KICKER;
  }

  function patchModeReadout(){
    const title = document.getElementById("v85bModeTitle");
    const text = document.getElementById("v85bModeText");

    if(title) title.textContent = "MEASURE · IDENTITY LOCKED";
    if(text) {
      text.textContent = "Runtime lock attivo: titolo, formula governance, evidence chain e strumenti sono riallineati alla dottrina v85.";
    }
  }

  function patchLinks(){
    document.querySelectorAll("a,button").forEach(el=>{
      const t = el.textContent || "";
      if(t.includes("v85C")) el.textContent = t.replace("v85C","v85D");
      if(t.includes("v85B")) el.textContent = t.replace("v85B","v85D");
    });
  }

  function installLockStrip(){
    if(document.querySelector(".v85d-lock-strip")) return;

    const anchor =
      document.querySelector(".sapienza-v85b-director") ||
      document.querySelector(".sapienza-v85c-identity-strip") ||
      document.querySelector(".hero, .intro, section");

    if(!anchor) return;

    const strip = document.createElement("section");
    strip.className = "v85d-lock-strip";
    strip.innerHTML = `
      <article>
        <b>Runtime Lock</b>
        <span>Il titolo viene bloccato anche se script precedenti lo riscrivono dopo il caricamento.</span>
      </article>
      <article>
        <b>Formula Governance</b>
        <span>FSPL, log-distance, clutter, fading, SINR e budget restano sorgente della scena.</span>
      </article>
      <article>
        <b>Instrument Proof</b>
        <span>IQ/EVM, PDP, H(f), probe UE e best-server confermano la diagnosi.</span>
      </article>
      <article>
        <b>Promotion Gate</b>
        <span>Se questa pagina passa, diventa il primo template physics riutilizzabile.</span>
      </article>
    `;

    anchor.insertAdjacentElement("afterend", strip);
  }

  function installBadge(){
    if(document.querySelector(".v85d-badge")) return;

    const b = document.createElement("div");
    b.className = "v85d-badge";
    b.textContent = "v0.85D · RUNTIME IDENTITY LOCK";
    document.body.appendChild(b);
  }

  function installObserver(){
    if(!("MutationObserver" in window)) return;

    const observer = new MutationObserver(() => {
      clearTimeout(window.__trfmcV85dPatchTimer);
      window.__trfmcV85dPatchTimer = setTimeout(hardPatch, 30);
    });

    observer.observe(document.body, {
      childList:true,
      subtree:true,
      characterData:true
    });
  }

  function bindCleanMode(){
    window.addEventListener("keydown",(ev)=>{
      if(ev.target && ["INPUT","TEXTAREA","SELECT"].includes(ev.target.tagName)) return;

      if(ev.key === "4") document.body.classList.add("v85d-mode-clean");
      if(["1","2","3"].includes(ev.key)) document.body.classList.remove("v85d-mode-clean");
    });

    document.addEventListener("click",(ev)=>{
      const btn = ev.target.closest && ev.target.closest("button[data-mode]");
      if(!btn) return;

      if(btn.dataset.mode === "clean") {
        document.body.classList.add("v85d-mode-clean");
      } else {
        document.body.classList.remove("v85d-mode-clean");
      }
    });
  }
})();
