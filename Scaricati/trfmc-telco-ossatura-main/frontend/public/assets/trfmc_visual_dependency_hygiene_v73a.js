(function(){
  const VERSION = "TRFMC_V0_73A_VISUAL_DEPENDENCY_HYGIENE";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function isPreview(){
    try { return new URLSearchParams(location.search).get("preview") === "1"; }
    catch(e){ return false; }
  }

  function addState(){
    if(isPreview()) return;
    if(document.querySelector(".v73a-hygiene-state")) return;

    const el = document.createElement("div");
    el.className = "v73a-hygiene-state";
    el.innerHTML = "<i></i><span>V73A HYGIENE OK</span>";
    document.body.appendChild(el);
  }

  function detectContamination(){
    const links = Array.from(document.querySelectorAll("link[href],script[src]"))
      .map(x => x.getAttribute("href") || x.getAttribute("src") || "");

    const contamination = {
      v72a_css: links.some(x => x.includes("trfmc_surgical_visual_remediation_v72.css")),
      v72a_js: links.some(x => x.includes("trfmc_surgical_visual_remediation_v72.js")),
      v70b: links.some(x => x.includes("trfmc_object_definition_surfaces_v70b")),
      v72b: links.some(x => x.includes("trfmc_visual_chaos_containment_v72b")),
      v73a: links.some(x => x.includes("trfmc_visual_dependency_hygiene_v73a"))
    };

    document.body.dataset.v73aContamination = JSON.stringify(contamination);

    if(contamination.v72a_css || contamination.v72a_js){
      document.body.classList.add("trfmc-v73a-v72a-residual");
    }
  }

  function bindKeys(){
    if(document.body.dataset.v73aBound === "true") return;
    document.body.dataset.v73aBound = "true";

    document.addEventListener("keydown", e => {
      if(e.altKey && e.key.toLowerCase() === "s"){
        document.body.classList.toggle("trfmc-v73a-clean-screenshot");
        localStorage.setItem(
          "trfmc_v73a_clean_screenshot",
          document.body.classList.contains("trfmc-v73a-clean-screenshot") ? "1" : "0"
        );
      }
    });

    if(localStorage.getItem("trfmc_v73a_clean_screenshot") === "1"){
      document.body.classList.add("trfmc-v73a-clean-screenshot");
    }
  }

  ready(() => {
    document.body.classList.add("trfmc-v73a-hygiene");
    detectContamination();
    addState();
    bindKeys();

    if(!document.title.includes("v0.73A")){
      document.title = "TRFMC v0.73A Hygiene · " + document.title;
    }

    document.body.dataset.v73a = VERSION;
  });
})();
