(function(){
  const data={
    antenna:{title:"Antenna Sector",desc:"Pannello antenna settoriale: azimuth, tilt, beamwidth, banda e MIMO layer.",band:"n78",azimuth:"120°",tilt:"4.5°",vswr:"1.18",power:"40 W",alarm:"NONE",interp:"Il settore antenna determina copertura, overlap, interferenza, handover e qualità radio."},
    rru:{title:"Remote Radio Unit",desc:"Unità radio remota: PA, conversione RF, potenza, temperatura, fault e sincronizzazione.",band:"n78/n3",azimuth:"—",tilt:"—",vswr:"1.22",power:"2x40 W",alarm:"TEMP OK",interp:"La RRU impatta potenza irradiata, linearità, ACLR, consumo e disponibilità della cella."},
    ret:{title:"RET / AISG Control",desc:"Remote Electrical Tilt e catena AISG per controllo tilt e ottimizzazione copertura.",band:"AISG",azimuth:"sector",tilt:"4.5°",vswr:"—",power:"DC feed",alarm:"RET OK",interp:"Un RET bloccato può generare overshooting, buchi di copertura o interferenza inter-settore."},
    microwave:{title:"Microwave Backhaul",desc:"Ponte radio per trasporto traffico sito-core/aggregation.",band:"18/23 GHz",azimuth:"link",tilt:"path",vswr:"—",power:"+20 dBm",alarm:"WATCH",interp:"Il backhaul influenza latenza, jitter, availability e throughput massimo del sito."},
    shelter:{title:"Shelter / Cabinet",desc:"Cabinet con apparati, alimentazione, cooling, ODF, batterie e supervisione.",band:"infra",azimuth:"—",tilt:"—",vswr:"—",power:"-48 VDC",alarm:"COOLING OK",interp:"Lo shelter è il cuore infrastrutturale: energia, fibra, controllo termico e continuità operativa."},
    power:{title:"Power Chain",desc:"AC/DC, rettificatori, batterie, generatori, protezioni e messa a terra.",band:"power",azimuth:"—",tilt:"—",vswr:"—",power:"-48 VDC",alarm:"BATTERY OK",interp:"Instabilità di alimentazione causa fault intermittenti, reset apparati e degrado disponibilità."},
    fiber:{title:"Fiber / Fronthaul",desc:"ODF, fibra, SFP, fronthaul/backhaul, attenuazione ottica e sincronizzazione.",band:"optical",azimuth:"—",tilt:"—",vswr:"—",power:"optical",alarm:"LINK OK",interp:"Perdita ottica o SFP degradato impattano trasporto, sincronizzazione e disponibilità cella."}
  };
  function set(id,v){const e=document.getElementById(id); if(e)e.textContent=v;}
  function focus(name){
    const x=data[name]||data.antenna;
    document.body.className=document.body.className.replace(/\bfocus-\w+/g,"").trim()+" focus-"+name;
    document.querySelectorAll("[data-focus]").forEach(b=>b.classList.toggle("active",b.dataset.focus===name));
    set("focus_state",name.toUpperCase()+" SELECTED"); set("detail_title",x.title); set("detail_desc",x.desc);
    set("k_band",x.band); set("k_azimuth",x.azimuth); set("k_tilt",x.tilt); set("k_vswr",x.vswr); set("k_power",x.power); set("k_alarm",x.alarm); set("interpretation",x.interp);
  }
  document.addEventListener("DOMContentLoaded",()=>{
    document.querySelectorAll("[data-focus]").forEach(b=>b.addEventListener("click",()=>focus(b.dataset.focus)));
    focus("antenna");
  });
})();
