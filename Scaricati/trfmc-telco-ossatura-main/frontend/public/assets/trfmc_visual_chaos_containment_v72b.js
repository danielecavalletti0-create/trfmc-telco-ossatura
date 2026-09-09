(function(){
  const VERSION = "TRFMC_V0_72B_VISUAL_CHAOS_CONTAINMENT";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function isPreview(){
    try {
      return new URLSearchParams(location.search).get("preview") === "1";
    } catch(e) {
      return false;
    }
  }

  function addBadge(){
    if(isPreview()) return;
    if(document.querySelector(".v72b-clean-badge")) return;

    const badge = document.createElement("div");
    badge.className = "v72b-clean-badge";
    badge.innerHTML = "<i></i><span>V72B CLEAN GOVERNANCE</span>";
    document.body.appendChild(badge);
  }

  function bindKeys(){
    if(document.body.dataset.v72bBound === "true") return;
    document.body.dataset.v72bBound = "true";

    document.addEventListener("keydown", e => {
      if(e.altKey && e.key.toLowerCase() === "a"){
        document.body.classList.toggle("trfmc-v72b-audit");
        localStorage.setItem("trfmc_v72b_audit", document.body.classList.contains("trfmc-v72b-audit") ? "1" : "0");
      }

      if(e.altKey && e.key.toLowerCase() === "c"){
        document.body.classList.toggle("trfmc-v72b-calibrated");
        localStorage.setItem("trfmc_v72b_calibrated", document.body.classList.contains("trfmc-v72b-calibrated") ? "1" : "0");
      }
    });

    if(localStorage.getItem("trfmc_v72b_audit") === "1") document.body.classList.add("trfmc-v72b-audit");
    if(localStorage.getItem("trfmc_v72b_calibrated") === "1") document.body.classList.add("trfmc-v72b-calibrated");
  }

  function patchIframeLinks(){
    document.querySelectorAll("iframe").forEach(frame => {
      try {
        const src = frame.getAttribute("src");
        if(src && !src.includes("preview=1")){
          frame.setAttribute("src", src + (src.includes("?") ? "&" : "?") + "preview=1");
        }
      } catch(e) {}
    });
  }

  ready(() => {
    document.body.classList.add("trfmc-v72b-clean-governance");

    if(isPreview()){
      document.body.classList.add("trfmc-preview-embedded");
    } else {
      addBadge();
      bindKeys();
      patchIframeLinks();
    }

    if(!document.title.includes("v0.72B")){
      document.title = "TRFMC v0.72B Clean · " + document.title;
    }

    document.body.dataset.v72b = VERSION;
  });
})();
