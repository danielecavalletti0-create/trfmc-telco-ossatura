(function(){
  function ready(fn){document.readyState==="loading"?document.addEventListener("DOMContentLoaded",fn):fn();}

  ready(()=>{
    document.body.classList.add("v63b-cinematic-site");

    const scene=document.getElementById("site_scene");
    if(scene && !scene.querySelector(".v63b-truss")){
      const truss=document.createElement("div");
      truss.className="v63b-truss";
      const tower=scene.querySelector(".tower");
      if(tower) tower.prepend(truss);

      ["v63b-skyline","v63b-target-tower","v63b-packet","v63b-packet p2"].forEach(cls=>{
        const d=document.createElement("div");
        d.className=cls;
        scene.appendChild(d);
      });
    }

    const heroEyebrow=document.querySelector(".eyebrow");
    if(heroEyebrow) heroEyebrow.textContent="TRFMC v0.63B · Cinematic Telecom Site Digital Twin";

    const heroP=document.querySelector(".hero p");
    if(heroP){
      heroP.textContent="Telecom site digital twin con torre reticolare, pannelli antenna, RRU, RET/AISG, microwave link, fibra, shelter, power chain, beam RF e telemetria operativa in stile enterprise mission-control.";
    }

    const detail=document.querySelector(".detail-panel");
    if(detail && !detail.querySelector(".v63b-mode-strip")){
      const strip=document.createElement("div");
      strip.className="v63b-mode-strip";
      strip.innerHTML=`
        <div><span>Digital Twin</span><b>Live Site</b></div>
        <div><span>RF Layer</span><b>Sectorized</b></div>
        <div><span>Backhaul</span><b>MW + Fiber</b></div>
        <div><span>Power</span><b>-48 VDC</b></div>
      `;
      detail.appendChild(strip);
    }

    document.title="TRFMC v0.63B · Infrastructure Digital Twin Visual Upgrade";
  });
})();
