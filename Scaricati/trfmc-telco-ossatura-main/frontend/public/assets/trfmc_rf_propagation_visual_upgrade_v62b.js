(function(){
  function ready(fn){document.readyState==="loading"?document.addEventListener("DOMContentLoaded",fn):fn();}
  ready(()=>{
    document.body.classList.add("v62b-visual-upgrade");

    const scene=document.getElementById("rf-scene");
    if(scene && !scene.querySelector(".v62b-ground")){
      const ground=document.createElement("div");
      ground.className="v62b-ground";
      scene.prepend(ground);

      const labels=[
        ["v62b-floating-label l-sector","Sector A · n78<br><b>Beam active</b>"],
        ["v62b-floating-label l-multipath","Multipath cluster<br><b>reflection / diffraction</b>"],
        ["v62b-floating-label l-shadow","Shadow zone<br><b>NLOS degraded</b>"]
      ];
      labels.forEach(([cls,html])=>{
        const d=document.createElement("div");
        d.className=cls;
        d.innerHTML=html;
        scene.appendChild(d);
      });
    }

    const eyebrow=document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent="TRFMC v0.62B · RF Propagation Visual Upgrade";

    document.title="TRFMC v0.62B · RF Propagation Sandbox Visual Upgrade";
  });
})();
