(function(){
  const bands={
    "700":{label:"700 MHz",desc:"Low band · migliore copertura e penetrazione",lambda:"0.428 m",loss:"92 dB",rsrp:"-78 dBm",sinr:"21 dB",bler:"1%",los:"LOS/NLOS"},
    "3500":{label:"3.5 GHz",desc:"Mid-band · capacity / coverage balance",lambda:"0.086 m",loss:"108 dB",rsrp:"-91 dBm",sinr:"14 dB",bler:"3%",los:"NLOS"},
    "28000":{label:"28 GHz",desc:"mmWave · beamforming e blocchi critici",lambda:"0.0107 m",loss:"132 dB",rsrp:"-108 dBm",sinr:"7 dB",bler:"12%",los:"NLOS CRITICAL"}
  };
  function set(id,v){const e=document.getElementById(id); if(e)e.textContent=v;}
  function applyBand(b){
    const x=bands[b]||bands["3500"];
    document.querySelectorAll("[data-band]").forEach(btn=>btn.classList.toggle("active",btn.dataset.band===b));
    set("band-label",x.label); set("band-desc",x.desc); set("m_freq",x.label); set("m_lambda",x.lambda); set("m_loss",x.loss); set("m_rsrp",x.rsrp); set("m_sinr",x.sinr); set("m_bler",x.bler); set("m_los",x.los);
    set("los-state",x.los.includes("CRITICAL")?"NLOS CRITICAL":x.los.includes("NLOS")?"NLOS WATCH":"LOS/NLOS READY");
    document.body.dataset.band=b;
  }
  document.addEventListener("DOMContentLoaded",()=>{
    document.querySelectorAll("[data-band]").forEach(btn=>btn.addEventListener("click",()=>applyBand(btn.dataset.band)));
    document.getElementById("toggle-rays")?.addEventListener("click",()=>document.body.classList.toggle("hide-rays"));
    document.getElementById("toggle-heat")?.addEventListener("click",()=>document.body.classList.toggle("hide-heat"));
    applyBand("3500");
  });
})();
