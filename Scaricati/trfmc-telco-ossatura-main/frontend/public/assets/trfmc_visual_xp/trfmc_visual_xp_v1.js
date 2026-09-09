/*
 TRFMC Visual Experience Layer V1
 Adds only ambience layers and interaction variables.
 No navbar, no iframe, no CDN.
*/
(function(){
  "use strict";

  if (window.localStorage && localStorage.getItem("TRFMC_VXP") === "off") return;

  document.addEventListener("DOMContentLoaded", function(){
    document.body.classList.add("trfmc-vxp");

    if (!document.querySelector(".trfmc-vxp-aurora")) {
      const aurora = document.createElement("div");
      aurora.className = "trfmc-vxp-aurora";
      document.body.prepend(aurora);
    }

    if (!document.querySelector(".trfmc-vxp-depth")) {
      const depth = document.createElement("div");
      depth.className = "trfmc-vxp-depth";
      document.body.prepend(depth);
    }

    const reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!reduce) {
      let tx = 50, ty = 35, cx = 50, cy = 35;

      window.addEventListener("pointermove", function(ev){
        tx = (ev.clientX / Math.max(1, window.innerWidth)) * 100;
        ty = (ev.clientY / Math.max(1, window.innerHeight)) * 100;
      }, {passive:true});

      function frame(){
        cx += (tx - cx) * 0.045;
        cy += (ty - cy) * 0.045;
        document.documentElement.style.setProperty("--trfmc-vxp-x", cx.toFixed(2) + "%");
        document.documentElement.style.setProperty("--trfmc-vxp-y", cy.toFixed(2) + "%");
        requestAnimationFrame(frame);
      }
      requestAnimationFrame(frame);
    }

    document.querySelectorAll(".leaf-panel,.leaf-card,.plotBox,.leaf-kpi").forEach(function(el){
      el.setAttribute("data-trfmc-vxp", "active");
    });
  });
})();
