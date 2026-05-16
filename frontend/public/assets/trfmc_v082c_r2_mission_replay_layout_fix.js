(function(){
  function qs(s){ return document.querySelector(s); }

  function moveTimelineToDock(){
    document.body.classList.add("v82c-r2-layout");
    document.title = "TRFMC v0.82C-R2 · Native WebGL Mission Replay Layout Fix";

    const oldTimeline = qs(".v82c-timeline");
    const labGrid = qs(".lab-grid");

    if(!oldTimeline || !labGrid) return;
    if(qs(".v82c-r2-replay-dock")) return;

    const dock = document.createElement("section");
    dock.className = "v82c-r2-replay-dock";

    const left = document.createElement("article");
    left.className = "v82c-r2-dock-card";
    left.innerHTML = `
      <h3>Replay Dock</h3>
      <strong>Timeline separata</strong>
      <p>La barra RF Mission Replay non è più dentro il canvas WebGL: nessuna sovrapposizione con mappa, celle, edifici o caption.</p>
    `;

    const center = document.createElement("article");
    center.className = "v82c-r2-dock-main";

    const right = document.createElement("article");
    right.className = "v82c-r2-dock-status";
    right.innerHTML = `
      <h3>Layout Status</h3>
      <div class="v82c-r2-status-grid">
        <div><span>Canvas</span><b>Clean</b></div>
        <div><span>Timeline</span><b>Docked</b></div>
        <div><span>Overlay</span><b>Reduced</b></div>
        <div><span>Mode</span><b>R2 Fix</b></div>
      </div>
    `;

    const title = oldTimeline.querySelector(".v82c-timeline-title");
    if(title) title.textContent = "RF Mission Replay Timeline";

    center.appendChild(oldTimeline);
    dock.appendChild(left);
    dock.appendChild(center);
    dock.appendChild(right);

    labGrid.insertAdjacentElement("afterend", dock);

    const eyebrow = qs(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.82C-R2 · CLEAN MISSION REPLAY LAYOUT";

    const h1 = qs("h1");
    if(h1) h1.textContent = "Native WebGL RF Mission Replay · Clean Layout";

    const eventBus = qs("#eventBus");
    if(eventBus){
      eventBus.innerHTML = `
        <b>AI RF Copilot</b>
        <p>Layout R2 attivo: timeline mission replay spostata in dock dedicato. Canvas WebGL libero da sovrapposizioni operative.</p>
      `;
    }
  }

  document.addEventListener("DOMContentLoaded", () => {
    /*
      v82C creates the replay timeline on DOMContentLoaded too.
      Run after a short delay to ensure the original timeline exists,
      then move it out of the canvas into a clean dock.
    */
    setTimeout(moveTimelineToDock, 180);
    setTimeout(moveTimelineToDock, 650);
  });
})();
