(function(){
  function ready(fn){ document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",fn) : fn(); }

  ready(()=>{
    document.body.classList.add("v84j-theater");

    document.title = "TRFMC v0.84J · RF 4D Measurement Theater";

    const h1 = document.querySelector("h1");
    if(h1) h1.textContent = "RF 4D Measurement Theater";

    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.84J · 4D RF MEASUREMENT THEATER";

    const heroText = document.querySelector(".hero p:last-child");
    if(heroText){
      heroText.textContent =
        "Teatro di misura RF 4D: campo, vettori, profondità, timeline, probe e strumenti concorrono alla diagnosi. Non è una heatmap: è una plancia didattica per leggere propagazione, qualità e canale.";
    }

    install4DOverlay();
    install4DDock();
    installTimeline();

    window.addEventListener("resize",()=>setTimeout(layoutOverlay,80));
    setTimeout(layoutOverlay,120);
    requestAnimationFrame(drawLoop);
  });

  let overlay;
  let base;
  let t0 = performance.now();

  function install4DOverlay(){
    base = document.getElementById("fieldCanvas");
    if(!base || document.getElementById("rf4dOverlayCanvas")) return;

    const stage = base.closest(".stage");
    if(!stage) return;

    stage.style.position = "relative";

    overlay = document.createElement("canvas");
    overlay.id = "rf4dOverlayCanvas";
    stage.appendChild(overlay);
  }

  function installTimeline(){
    const stage = document.querySelector(".stage");
    if(!stage || stage.querySelector(".rf4d-timeline")) return;

    const d = document.createElement("div");
    d.className = "rf4d-timeline";
    d.innerHTML = `
      <strong>4D REPLAY</strong>
      <div class="rf4d-track"></div>
      <span>geometry → channel → IQ → teaching</span>
    `;
    stage.appendChild(d);
  }

  function install4DDock(){
    const instruments = document.querySelector(".instruments");
    if(!instruments || document.querySelector(".rf4d-dock")) return;

    const dock = document.createElement("section");
    dock.className = "rf4d-dock";
    dock.innerHTML = `
      <article>
        <h2>Observe</h2>
        <p>Prima si osserva la geometria: siti, UE, ostacoli, corridoi NLOS, Fresnel e vettore serving.</p>
        <code>geometry → LOS/NLOS → obstruction</code>
      </article>
      <article>
        <h2>Measure</h2>
        <p>La misura non è il colore: RSRP, SINR, EVM, PDP e H(f) devono confermare la scena.</p>
        <code>RSRP + SINR + EVM + TDL</code>
      </article>
      <article>
        <h2>Correlate</h2>
        <p>La qualità nasce dalla correlazione: potenza ricevuta, interferenza, delay spread e risposta selettiva.</p>
        <code>field ⇄ IQ ⇄ PDP ⇄ H(f)</code>
      </article>
      <article>
        <h2>Teach</h2>
        <p>L’allievo deve imparare il metodo: non fidarsi della mappa, ma costruire una diagnosi radio verificabile.</p>
        <code>observe → measure → explain</code>
      </article>
    `;
    instruments.parentNode.insertBefore(dock, instruments);
  }

  function layoutOverlay(){
    if(!overlay || !base) return;

    const stage = base.closest(".stage");
    const b = base.getBoundingClientRect();
    const s = stage.getBoundingClientRect();
    const dpr = Math.min(devicePixelRatio || 1, 2);

    overlay.style.left = (b.left - s.left) + "px";
    overlay.style.top = (b.top - s.top) + "px";
    overlay.style.width = b.width + "px";
    overlay.style.height = b.height + "px";

    overlay.width = Math.max(320, Math.floor(b.width * dpr));
    overlay.height = Math.max(180, Math.floor(b.height * dpr));

    const ctx = overlay.getContext("2d");
    ctx.setTransform(dpr,0,0,dpr,0,0);
  }

  function drawLoop(now){
    drawOverlay((now - t0) / 1000);
    requestAnimationFrame(drawLoop);
  }

  function drawOverlay(t){
    if(!overlay || !base) return;

    const ctx = overlay.getContext("2d");
    const rect = overlay.getBoundingClientRect();
    const w = rect.width;
    const h = rect.height;

    ctx.clearRect(0,0,w,h);

    drawDepthReticle(ctx,w,h,t);
    drawFresnelAndCorridors(ctx,w,h,t);
    drawProbeTheater(ctx,w,h,t);
    drawTimeVector(ctx,w,h,t);
    drawMeasurementLabels(ctx,w,h,t);
  }

  function drawDepthReticle(ctx,w,h,t){
    ctx.save();

    const cx = w * .64;
    const cy = h * .50;

    ctx.strokeStyle = "rgba(143,240,255,.10)";
    ctx.lineWidth = 1;

    for(let r=80; r<Math.max(w,h); r+=120){
      ctx.beginPath();
      ctx.ellipse(cx,cy,r,r*.55,0,0,Math.PI*2);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(66,245,111,.080)";
    for(let a=-70; a<=70; a+=20){
      const rad = (a + Math.sin(t*.3)*2) * Math.PI/180;
      ctx.beginPath();
      ctx.moveTo(cx,cy);
      ctx.lineTo(cx + Math.cos(rad)*w*.52, cy + Math.sin(rad)*h*.42);
      ctx.stroke();
    }

    ctx.restore();
  }

  function drawFresnelAndCorridors(ctx,w,h,t){
    const siteA = {x:w*.20, y:h*.63};
    const siteB = {x:w*.54, y:h*.22};
    const siteC = {x:w*.82, y:h*.54};
    const ue = {x:w*.64, y:h*.50};

    ctx.save();
    ctx.lineWidth = 1.4;

    // Fresnel-like ellipses, non fisicamente assolute ma didattiche/diagnostiche
    drawEllipseBetween(ctx, siteB, ue, "rgba(143,240,255,.34)", 42, "FRESNEL / SERVING");
    drawEllipseBetween(ctx, siteA, ue, "rgba(251,191,36,.22)", 34, "NEIGHBOR PATH");
    drawEllipseBetween(ctx, siteC, ue, "rgba(251,191,36,.22)", 30, "LOAD PATH");

    // NLOS corridor shaded vector
    ctx.strokeStyle = "rgba(46,167,255,.34)";
    ctx.setLineDash([10,8]);
    ctx.beginPath();
    ctx.moveTo(w*.10,h*.30);
    ctx.bezierCurveTo(w*.28,h*.46,w*.46,h*.55,w*.76,h*.45);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.restore();
  }

  function drawEllipseBetween(ctx,a,b,color,thick,label){
    const mx = (a.x+b.x)/2;
    const my = (a.y+b.y)/2;
    const dx = b.x-a.x;
    const dy = b.y-a.y;
    const len = Math.sqrt(dx*dx+dy*dy);
    const angle = Math.atan2(dy,dx);

    ctx.save();
    ctx.translate(mx,my);
    ctx.rotate(angle);
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.ellipse(0,0,len/2,thick,0,0,Math.PI*2);
    ctx.stroke();

    ctx.fillStyle = "rgba(1,6,14,.76)";
    ctx.strokeStyle = "rgba(143,240,255,.22)";
    round(ctx,-58,-thick-24,116,20,9,true,true);
    ctx.fillStyle = color.replace(/rgba\(([^,]+),([^,]+),([^,]+),[^)]+\)/,"rgb($1,$2,$3)");
    ctx.font = "bold 9px monospace";
    ctx.textAlign = "center";
    ctx.fillText(label,0,-thick-10);
    ctx.restore();
  }

  function drawProbeTheater(ctx,w,h,t){
    const ux = w*.64;
    const uy = h*.50;

    ctx.save();

    for(let i=0;i<3;i++){
      const r = 24 + i*18 + Math.sin(t*1.6+i)*2;
      ctx.strokeStyle = i===0 ? "rgba(66,245,111,.70)" : "rgba(143,240,255,.28)";
      ctx.lineWidth = i===0 ? 2 : 1;
      ctx.beginPath();
      ctx.arc(ux,uy,r,0,Math.PI*2);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(255,255,255,.54)";
    ctx.beginPath();
    ctx.moveTo(ux-42,uy); ctx.lineTo(ux+42,uy);
    ctx.moveTo(ux,uy-42); ctx.lineTo(ux,uy+42);
    ctx.stroke();

    ctx.fillStyle = "rgba(1,6,14,.86)";
    ctx.strokeStyle = "rgba(66,245,111,.34)";
    round(ctx,ux+26,uy+26,152,64,14,true,true);
    ctx.fillStyle = "#42f56f";
    ctx.font = "bold 10px monospace";
    ctx.fillText("UE-42 PROBE LOCK",ux+42,uy+48);
    ctx.fillStyle = "rgba(232,250,255,.70)";
    ctx.font = "9px monospace";
    ctx.fillText("RSRP/SINR/EVM correlated",ux+42,uy+64);

    ctx.restore();
  }

  function drawTimeVector(ctx,w,h,t){
    ctx.save();

    const y = h*.86;
    const x1 = w*.18;
    const x2 = w*.82;
    const p = (Math.sin(t*.45)+1)/2;
    const x = x1 + (x2-x1)*p;

    ctx.strokeStyle = "rgba(143,240,255,.22)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x1,y);
    ctx.bezierCurveTo(w*.34,y-40,w*.55,y+34,x2,y-18);
    ctx.stroke();

    ctx.fillStyle = "#8ff0ff";
    ctx.shadowColor = "rgba(143,240,255,.80)";
    ctx.shadowBlur = 16;
    ctx.beginPath();
    ctx.arc(x,y-10*Math.sin(t*.9),5,0,Math.PI*2);
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.fillStyle = "rgba(1,6,14,.78)";
    ctx.strokeStyle = "rgba(143,240,255,.24)";
    round(ctx,x-54,y-46,108,24,10,true,true);
    ctx.fillStyle = "#8ff0ff";
    ctx.font = "bold 9px monospace";
    ctx.textAlign = "center";
    ctx.fillText("TIME SAMPLE",x,y-30);
    ctx.textAlign = "left";

    ctx.restore();
  }

  function drawMeasurementLabels(ctx,w,h,t){
    const labels = [
      {x:.13,y:.17,t:"NLOS corridor",c:"#2ea7ff"},
      {x:.43,y:.28,t:"obstruction cluster",c:"#fbbf24"},
      {x:.57,y:.42,t:"serving vector",c:"#8ff0ff"},
      {x:.78,y:.31,t:"SINR stress check",c:"#ff3b5c"},
      {x:.68,y:.70,t:"TDL/EVM proof",c:"#42f56f"}
    ];

    ctx.save();
    labels.forEach((l,i)=>{
      const pulse = .55 + .45*Math.sin(t*1.4+i);
      const x = w*l.x;
      const y = h*l.y;

      ctx.fillStyle = "rgba(1,6,14,.80)";
      ctx.strokeStyle = l.c + "88";
      round(ctx,x-8,y-14,l.t.length*7.2+18,23,10,true,true);

      ctx.fillStyle = l.c;
      ctx.globalAlpha = .68 + .20*pulse;
      ctx.font = "bold 9px monospace";
      ctx.fillText(l.t,x,y+2);
      ctx.globalAlpha = 1;
    });
    ctx.restore();
  }

  function round(ctx,x,y,w,h,r,fill,stroke){
    ctx.beginPath();
    if(ctx.roundRect){
      ctx.roundRect(x,y,w,h,r);
    }else{
      ctx.moveTo(x+r,y);
      ctx.lineTo(x+w-r,y);
      ctx.quadraticCurveTo(x+w,y,x+w,y+r);
      ctx.lineTo(x+w,y+h-r);
      ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
      ctx.lineTo(x+r,y+h);
      ctx.quadraticCurveTo(x,y+h,x,y+h-r);
      ctx.lineTo(x,y+r);
      ctx.quadraticCurveTo(x,y,x+r,y);
    }
    if(fill) ctx.fill();
    if(stroke) ctx.stroke();
  }
})();
