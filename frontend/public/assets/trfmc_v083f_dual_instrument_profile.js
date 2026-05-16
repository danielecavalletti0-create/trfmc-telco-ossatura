(function(){
  const $ = (s) => document.querySelector(s);

  function valueText(id){
    return ($(id)?.textContent || "").trim();
  }

  function parseNum(text){
    const m = String(text).match(/-?\d+(\.\d+)?/);
    return m ? Number(m[0]) : 0;
  }

  function classifyCoverage(v){
    if(v >= 75) return "good";
    if(v >= 50) return "warn";
    return "bad";
  }

  function classifySinr(v){
    if(v >= 12) return "good";
    if(v >= 6) return "warn";
    return "bad";
  }

  function ensureDualDock(){
    document.body.classList.add("v83f-dual");
    document.title = "TRFMC v0.83F · Dual Instrument View + RSRP/SINR Profile";

    const formula = $(".formula-dock");
    if(!formula || $(".v83f-dual-dock")) return;

    const dock = document.createElement("section");
    dock.className = "v83f-dual-dock";
    dock.innerHTML = `
      <article class="v83f-panel">
        <h3>Instrument Profile · RSRP / SINR / Margin</h3>
        <div class="v83f-profile-wrap">
          <canvas id="v83fProfileCanvas"></canvas>
          <div class="v83f-axis-note">X = route/profile sample · Y = RSRP/SINR normalized · threshold-aware</div>
        </div>
        <div class="v83f-chip-row">
          <span class="ok">RSRP trace</span>
          <span class="ok">SINR margin</span>
          <span>handover edge</span>
          <span class="warn">quality gate</span>
        </div>
      </article>

      <article class="v83f-panel">
        <h3>Quality Gate</h3>
        <div class="v83f-quality-grid">
          <div><span>Serving Cell</span><b id="v83fServing">—</b></div>
          <div><span>RSRP</span><b id="v83fRsrp">—</b></div>
          <div><span>SINR</span><b id="v83fSinr">—</b></div>
          <div><span>Coverage</span><b id="v83fCoverage">—</b></div>
        </div>
        <div class="v83f-spectrum">
          <canvas id="v83fSpectrumCanvas"></canvas>
        </div>
        <p class="v83f-status-text" id="v83fStatus">
          Dual instrument mode inizializzato.
        </p>
      </article>
    `;

    formula.insertAdjacentElement("beforebegin", dock);
  }

  function setupCanvas(canvas, cssHeight){
    if(!canvas) return null;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const rect = canvas.getBoundingClientRect();
    const w = Math.max(300, Math.floor(rect.width * dpr));
    const h = Math.floor(cssHeight * dpr);
    if(canvas.width !== w || canvas.height !== h){
      canvas.width = w;
      canvas.height = h;
    }
    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr,0,0,dpr,0,0);
    return {ctx,w:rect.width,h:cssHeight};
  }

  function drawProfile(){
    const canvas = $("#v83fProfileCanvas");
    const pack = setupCanvas(canvas, 260);
    if(!pack) return;

    const {ctx,w,h} = pack;
    const rsrp = parseNum(valueText("#rsrpVal"));
    const sinr = parseNum(valueText("#sinrVal"));
    const coverage = parseNum(valueText("#coverageVal"));
    const shadow = Number($("#shadowDb")?.value || 0);
    const fading = Number($("#fading")?.value || 0) / 10;
    const veg = Number($("#vegDepth")?.value || 0);

    ctx.clearRect(0,0,w,h);

    const grad = ctx.createLinearGradient(0,0,w,h);
    grad.addColorStop(0,"rgba(143,240,255,0.08)");
    grad.addColorStop(1,"rgba(2,8,18,0.96)");
    ctx.fillStyle = grad;
    ctx.fillRect(0,0,w,h);

    // Threshold bands
    const bands = [
      {y:0.18,c:"rgba(66,245,111,0.08)",label:"GOOD"},
      {y:0.38,c:"rgba(251,191,36,0.08)",label:"EDGE"},
      {y:0.62,c:"rgba(46,167,255,0.08)",label:"WEAK"},
      {y:0.82,c:"rgba(255,59,92,0.06)",label:"OUTAGE"}
    ];
    bands.forEach(b=>{
      ctx.fillStyle=b.c;
      ctx.fillRect(0,b.y*h,w,34);
      ctx.fillStyle="rgba(232,250,255,0.38)";
      ctx.font="10px monospace";
      ctx.fillText(b.label,10,b.y*h+22);
    });

    // Grid
    ctx.strokeStyle="rgba(143,240,255,0.10)";
    ctx.lineWidth=1;
    for(let x=0;x<w;x+=w/12){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let y=0;y<h;y+=h/6){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

    function yFromRsrp(v){
      const t = Math.max(0,Math.min(1,(v + 115)/45));
      return h - t*h;
    }

    function yFromSinr(v){
      const t = Math.max(0,Math.min(1,(v + 5)/30));
      return h - t*h;
    }

    const samples = 96;
    const rsrpPts = [];
    const sinrPts = [];

    for(let i=0;i<samples;i++){
      const x = i/(samples-1);
      const localShadow = Math.sin(x*10.2 + shadow*.11)*2.5 + Math.sin(x*23.0)*1.4;
      const localVeg = Math.sin(x*7.0 + veg*.05)*1.8;
      const localFade = Math.sin(x*18.0 + performance.now()/900)*fading;
      const cellPeak = 9*Math.exp(-Math.pow((x-.55)/.16,2));
      const edgeDrop = -7*Math.exp(-Math.pow((x-.78)/.10,2));
      const r = rsrp + cellPeak + edgeDrop - localShadow - localVeg - localFade;
      const s = sinr + 3*Math.sin(x*6.0) - Math.max(0,shadow-12)*0.08 - Math.max(0,veg-40)*0.05 - Math.abs(edgeDrop)*0.12;
      rsrpPts.push([x*w,yFromRsrp(r)]);
      sinrPts.push([x*w,yFromSinr(s)]);
    }

    function drawLine(pts, color, width){
      ctx.beginPath();
      pts.forEach(([x,y],idx)=> idx?ctx.lineTo(x,y):ctx.moveTo(x,y));
      ctx.strokeStyle=color;
      ctx.lineWidth=width;
      ctx.shadowColor=color;
      ctx.shadowBlur=10;
      ctx.stroke();
      ctx.shadowBlur=0;
    }

    drawLine(rsrpPts,"rgba(143,240,255,0.92)",2.4);
    drawLine(sinrPts,"rgba(66,245,111,0.88)",2.2);

    // Current probe vertical marker
    const probeX = w*.63;
    ctx.strokeStyle="rgba(251,191,36,0.76)";
    ctx.lineWidth=1.5;
    ctx.beginPath();
    ctx.moveTo(probeX,0);
    ctx.lineTo(probeX,h);
    ctx.stroke();

    ctx.fillStyle="rgba(2,8,18,0.82)";
    ctx.strokeStyle="rgba(251,191,36,0.40)";
    ctx.lineWidth=1;
    ctx.beginPath();
    ctx.roundRect(probeX+8,18,190,54,12);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle="rgba(251,191,36,0.95)";
    ctx.font="bold 11px monospace";
    ctx.fillText("UE-42 PROFILE PROBE",probeX+20,39);
    ctx.fillStyle="rgba(232,250,255,0.70)";
    ctx.font="10px monospace";
    ctx.fillText("RSRP "+rsrp.toFixed(1)+" dBm · SINR "+sinr.toFixed(1)+" dB",probeX+20,57);

    // Labels
    ctx.fillStyle="rgba(143,240,255,0.90)";
    ctx.font="bold 11px monospace";
    ctx.fillText("RSRP",w-70,24);
    ctx.fillStyle="rgba(66,245,111,0.90)";
    ctx.fillText("SINR",w-70,42);
  }

  function drawSpectrum(){
    const canvas = $("#v83fSpectrumCanvas");
    const pack = setupCanvas(canvas, 120);
    if(!pack) return;

    const {ctx,w,h} = pack;
    const sinr = parseNum(valueText("#sinrVal"));
    const coverage = parseNum(valueText("#coverageVal"));
    const fading = Number($("#fading")?.value || 0)/10;

    ctx.clearRect(0,0,w,h);
    ctx.fillStyle="rgba(2,8,18,0.76)";
    ctx.fillRect(0,0,w,h);

    ctx.strokeStyle="rgba(143,240,255,0.10)";
    for(let x=0;x<w;x+=w/16){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let y=0;y<h;y+=h/4){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

    const bins=80;
    for(let i=0;i<bins;i++){
      const x=i/(bins-1);
      const shape =
        0.18 +
        0.55*Math.exp(-Math.pow((x-.50)/.15,2)) +
        0.18*Math.exp(-Math.pow((x-.25)/.06,2)) +
        0.14*Math.exp(-Math.pow((x-.73)/.08,2));
      const noise = 0.04*Math.sin(i*1.9 + performance.now()/500);
      const quality = Math.max(.35, Math.min(1, coverage/100));
      const v = Math.max(0.05, Math.min(0.95, (shape+noise)*quality + fading*.015));
      const bh = v*h*.82;
      const bx = x*w;
      const bw = Math.max(2,w/bins*.72);

      let color="rgba(143,240,255,0.65)";
      if(sinr < 6) color="rgba(255,59,92,0.58)";
      else if(sinr < 12) color="rgba(251,191,36,0.62)";
      else color="rgba(66,245,111,0.62)";

      ctx.fillStyle=color;
      ctx.fillRect(bx,h-bh,bw,bh);
    }

    ctx.fillStyle="rgba(232,250,255,0.72)";
    ctx.font="10px monospace";
    ctx.fillText("Synthetic channel margin / interference profile",12,18);

    ctx.fillStyle = sinr >= 12 ? "rgba(66,245,111,0.95)" : sinr >= 6 ? "rgba(251,191,36,0.95)" : "rgba(255,59,92,0.95)";
    ctx.font="bold 14px monospace";
    ctx.fillText("SINR " + sinr.toFixed(1) + " dB",12,42);
  }

  function updateQualityGate(){
    const serving = valueText("#cellVal") || "—";
    const rsrp = valueText("#rsrpVal") || "—";
    const sinr = valueText("#sinrVal") || "—";
    const coverage = valueText("#coverageVal") || "—";

    const sinrN = parseNum(sinr);
    const covN = parseNum(coverage);

    const s = $("#v83fServing");
    const r = $("#v83fRsrp");
    const si = $("#v83fSinr");
    const c = $("#v83fCoverage");
    const status = $("#v83fStatus");

    if(s) s.textContent = serving;
    if(r) r.textContent = rsrp;
    if(si){
      si.textContent = sinr;
      si.className = classifySinr(sinrN);
    }
    if(c){
      c.textContent = coverage;
      c.className = classifyCoverage(covN);
    }

    if(status){
      let verdict = "RF quality nominale.";
      if(covN < 50 || sinrN < 6) verdict = "Margine critico: verificare interferenza, NLOS, shadowing e clutter.";
      else if(covN < 75 || sinrN < 12) verdict = "Margine intermedio: cell-edge o interferenza moderata.";
      else verdict = "Margine operativo buono: copertura e qualità coerenti.";

      status.textContent = verdict + " Il profilo strumentale separa finalmente campo RF, qualità SINR e decisione best-server.";
    }

    const copilot = $("#copilot");
    if(copilot){
      copilot.innerHTML = `
        <b>AI RF Copilot</b>
        <p>v83F dual instrument: serving=${serving}, RSRP=${rsrp}, SINR=${sinr}, coverage=${coverage}.
        La mappa mostra il campo; il profilo sotto verifica qualità, margine e soglie.</p>
      `;
    }
  }

  function refresh(){
    ensureDualDock();
    updateQualityGate();
    drawProfile();
    drawSpectrum();
  }

  function bind(){
    ["freqMHz","eirp","pathN","vegDepth","shadowDb","sectorGain","fading"].forEach(id=>{
      const el=document.getElementById(id);
      if(el) el.addEventListener("input",()=>setTimeout(refresh,80));
    });
    window.addEventListener("resize",()=>setTimeout(refresh,160));
  }

  function loop(){
    drawProfile();
    drawSpectrum();
    requestAnimationFrame(loop);
  }

  document.addEventListener("DOMContentLoaded",()=>{
    setTimeout(()=>{
      ensureDualDock();
      updateQualityGate();
      refresh();
      bind();

      const eyebrow=$(".eyebrow");
      if(eyebrow) eyebrow.textContent="TRFMC v0.83F · DUAL INSTRUMENT VIEW + RSRP/SINR PROFILE";

      const h1=$("h1");
      if(h1) h1.textContent="RF Dual Instrument View + RSRP/SINR Profile";

      loop();
    },650);

    setTimeout(refresh,1300);
  });
})();
