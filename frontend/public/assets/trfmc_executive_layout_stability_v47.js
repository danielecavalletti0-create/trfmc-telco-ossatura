(function(){
  const VERSION = "TRFMC_V0_47A_EXECUTIVE_PAGE_PERFORMANCE_LAYOUT_STABILITY";

  const sections = [
    ["v47_kpi", "KPI Wall", ".v46-instrument-cluster"],
    ["v47_glass", "Glass Command", ".v45-glass-command-band"],
    ["v47_priority", "Priority Rail", ".v44-priority-rail"],
    ["v47_hub", "Entry Hub", ".v43-entry-hub"],
    ["v47_evidence", "Evidence", ".v42-evidence-overlay"],
    ["v47_cinematic", "Cinematic", ".v41-command-strip"],
    ["v47_legacy", "Runtime Panels", ".command-layout"]
  ];

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function ensureAnchors(){
    sections.forEach(([id, label, selector]) => {
      const el = document.querySelector(selector);
      if(!el) return;
      el.id = id;
      el.classList.add("v47-section-anchor");
      if(!el.previousElementSibling || !el.previousElementSibling.classList.contains("v47-section-label")){
        const tag = document.createElement("div");
        tag.className = "v47-section-label";
        tag.textContent = label;
        el.insertAdjacentElement("beforebegin", tag);
      }
    });
  }

  function ensureNav(){
    if(document.querySelector(".v47-section-nav")) return;

    const nav = document.createElement("nav");
    nav.className = "v47-section-nav";
    nav.innerHTML = `
      <div class="v47-section-nav-head">
        <b>Executive Section Navigator</b>
        <span>${VERSION}</span>
      </div>
      <div class="v47-section-links">
        ${sections.map(([id,label]) => `<a href="#${id}" data-v47-target="${id}">${label}</a>`).join("")}
        <button type="button" id="v47_motion_toggle">Reduce Motion</button>
        <button type="button" id="v47_density_toggle">Compact Density</button>
      </div>
    `;

    const hero = document.querySelector(".hero");
    if(hero) hero.insertAdjacentElement("afterend", nav);
    else document.body.insertBefore(nav, document.body.firstChild);
  }

  function bindToggles(){
    const motion = document.getElementById("v47_motion_toggle");
    const density = document.getElementById("v47_density_toggle");

    if(motion){
      motion.addEventListener("click", () => {
        document.body.classList.toggle("v47-reduced-motion");
        motion.textContent = document.body.classList.contains("v47-reduced-motion") ? "Motion Reduced" : "Reduce Motion";
      });
    }

    if(density){
      density.addEventListener("click", () => {
        document.body.classList.toggle("v47-density-compact");
        density.textContent = document.body.classList.contains("v47-density-compact") ? "Standard Density" : "Compact Density";
      });
    }
  }

  function activeSectionObserver(){
    const links = Array.from(document.querySelectorAll("[data-v47-target]"));
    if(!links.length || !("IntersectionObserver" in window)) return;

    const byId = Object.fromEntries(links.map(a => [a.dataset.v47Target, a]));
    const obs = new IntersectionObserver((entries) => {
      const visible = entries.filter(e => e.isIntersecting).sort((a,b) => b.intersectionRatio - a.intersectionRatio)[0];
      if(!visible) return;
      links.forEach(a => a.classList.remove("active"));
      const link = byId[visible.target.id];
      if(link) link.classList.add("active");
    }, { threshold: [0.20, 0.35], rootMargin: "-10% 0px -70% 0px" });

    sections.forEach(([id]) => {
      const el = document.getElementById(id);
      if(el) obs.observe(el);
    });
  }

  ready(function(){
    document.body.classList.add("v47-layout-stable");
    ensureAnchors();
    ensureNav();
    bindToggles();
    activeSectionObserver();
  });
})();
