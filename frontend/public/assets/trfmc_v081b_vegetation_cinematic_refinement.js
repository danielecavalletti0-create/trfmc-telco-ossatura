(function(){
  function ready(fn){
    document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", fn) : fn();
  }

  ready(() => {
    document.body.classList.add("v81b-cinematic");

    if(!document.querySelector(".v81b-sandbox-mark")){
      const mark = document.createElement("div");
      mark.className = "v81b-sandbox-mark";
      mark.textContent = "v0.81B cinematic sandbox";
      document.body.appendChild(mark);
    }

    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) {
      eyebrow.textContent = "TRFMC v0.81B · CINEMATIC OBJECT DEFINITION REFINEMENT";
    }

    document.title = "TRFMC v0.81B · Vegetation Cinematic Surgical Sandbox";
    document.body.dataset.v81b = "cinematic-refinement";
  });
})();
