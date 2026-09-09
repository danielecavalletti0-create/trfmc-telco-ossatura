(function(){
  "use strict";

  const root = document.getElementById("rf86-root");
  if(!root) return;

  const state = {
    freq: 3500,
    eirp: 46,
    n: 3.2,
    veg: 28,
    shadow: 11,
    delay: 130,
    mode: "measure",
    t: 0,
    paused: false
  };

  const el = {
    canvas: document.getElementById("rf86Canvas"),
    iq: document.getElementById("rf86Iq"),
    pdp: document.getElementById("rf86Pdp"),
    hf: document.getElementById("rf86Hf"),
    integrity: document.getElementById("rf86Integrity"),
    best: document.getElementById("rf86Best"),
    rsrp: document.getElementById("rf86Rsrp"),
    sinr: document.getElementById("rf86Sinr"),
    loss: document.getElementById("rf86Loss"),
    coverage: document.getElementById("rf86Coverage"),
    cell: document.getElementById("rf86Cell"),
    copilot: document.getElementById("rf86Copilot"),
    modeText: document.getElementById("rf86ModeText"),
    probe: document.getElementById("rf86Probe"),
    fsplText: document.getElementById("rf86FsplText"),
    vegText: document.getElementById("rf86VegText"),
    prxText: document.getElementById("rf86PrxText")
  };

  const controls = [
    ["rf86Freq","freq","rf86FreqOut", v => `${v} MHz`, v => +v],
    ["rf86Eirp","eirp","rf86EirpOut", v => `${v} dBm`, v => +v],
    ["rf86N","n","rf86NOut", v => `${(v/10).toFixed(1)}`, v => +v/10],
    ["rf86Veg","veg","rf86VegOut", v => `${v} m`, v => +v],
    ["rf86Shadow","shadow","rf86ShadowOut", v => `${v} dB`, v => +v],
    ["rf86Delay","delay","rf86DelayOut", v => `${v} ns`, v => +v]
  ];

  controls.forEach(([id,key,outId,fmt,cast])=>{
    const input = document.getElementById(id);
    const out = document.getElementById(outId);
    if(!input || !out) return;

    const sync = () => {
      state[key] = cast(input.value);
      out.textContent = fmt(input.value);
      renderAll();
    };

    input.addEventListener("input", sync);
    sync();
  });

  root.querySelectorAll("[data-rf86-mode]").forEach(btn=>{
    btn.addEventListener("click", ()=>{
      setMode(btn.dataset.rf86Mode || "measure");
    });
  });

  document.getElementById("rf86ScenarioBalanced")?.addEventListener("click", ()=>{
    setScenario({freq:3500,eirp:46,n:32,veg:28,shadow:11,delay:130});
  });

  document.getElementById("rf86ScenarioNlos")?.addEventListener("click", ()=>{
    setScenario({freq:3500,eirp:44,n:39,veg:48,shadow:24,delay:420});
  });

  document.getElementById("rf86ScenarioRecover")?.addEventListener("click", ()=>{
    setScenario({freq:3500,eirp:50,n:30,veg:18,shadow:8,delay:90});
  });

  window.addEventListener("keydown", ev=>{
    if(ev.target && ["INPUT","TEXTAREA","SELECT"].includes(ev.target.tagName)) return;
    if(ev.key === "1") setMode("measure");
    if(ev.key === "2") setMode("channel");
    if(ev.key === "3") setMode("signal");
    if(ev.key === "4") setMode("teach");
    if(ev.key === "5") setMode("clean");
  });

  function setScenario(values){
    const map = {
      freq:"rf86Freq",
      eirp:"rf86Eirp",
      n:"rf86N",
      veg:"rf86Veg",
      shadow:"rf86Shadow",
      delay:"rf86Delay"
    };

    for(const [key,val] of Object.entries(values)){
      const input = document.getElementById(map[key]);
      if(!input) continue;
      input.value = key === "n" ? Math.round(val) : val;
      input.dispatchEvent(new Event("input", {bubbles:true}));
    }
  }

  function setMode(mode){
    state.mode = mode;
    root.dataset.mode = mode;

    root.querySelectorAll("[data-rf86-mode]").forEach(btn=>{
      const active = btn.dataset.rf86Mode === mode;
      btn.classList.toggle("is-active", active);
      btn.setAttribute("aria-pressed", active ? "true" : "false");
    });

    const map = {
      measure: "Measure: osserva geometria, campo, soglie e strumenti prima di decidere.",
      channel: "Channel: path loss, shadowing, clutter e delay spiegano la forma della copertura.",
      signal: "Signal: IQ, EVM, PDP e H(f) confermano qualità, distorsione e selettività.",
      teach: "Teach: la console deve insegnare metodo: osserva, misura, correla, spiega.",
      clean: "Clean: vista pulita per screenshot e revisione, senza ribbon didattiche invasive."
    };

    if(el.modeText) el.modeText.textContent = map[mode] || map.measure;
    renderAll();
  }

  function resizeCanvas(c){
    const rect = c.getBoundingClientRect();
    const dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
    const w = Math.max(320, Math.round(rect.width * dpr));
    const h = Math.max(180, Math.round(rect.height * dpr));
    if(c.width !== w || c.height !== h){
      c.width = w;
      c.height = h;
    }
    return {w,h,dpr};
  }

  function colorForScore(score){
    // score 0..1, operativo: nero/blu -> ciano -> verde -> giallo -> rosso
    if(score < 0.18) return [2,6,17];
    if(score < 0.35) return [8,62,138];
    if(score < 0.52) return [10,160,208];
    if(score < 0.72) return [58,220,116];
    if(score < 0.86) return [225,201,69];
    return [214,75,69];
  }

  function fspl(dMeters){
    const dKm = Math.max(0.001, dMeters/1000);
    return 32.44 + 20*Math.log10(state.freq) + 20*Math.log10(dKm);
  }

  function logDistance(dMeters){
    const d0 = 10;
    const pl0 = fspl(d0);
    return pl0 + 10*state.n*Math.log10(Math.max(1,dMeters/d0));
  }

  function vegetationLoss(){
    const fGHz = state.freq / 1000;
    return 0.22 * Math.pow(fGHz,0.3) * Math.pow(Math.max(1,state.veg),0.6) * 1.15;
  }

  function estimate(){
    const d = 185;
    const pl = logDistance(d);
    const veg = vegetationLoss();
    const shadow = state.shadow * 0.58;
    const fade = Math.max(0, state.delay / 170);
    const sector = 6.4;
    const prx = state.eirp + sector - pl - veg - shadow - fade;
    const interference = Math.max(3, state.shadow*0.36 + state.veg*0.035 + state.delay*0.008);
    const sinr = Math.max(-8, Math.min(24, prx + 88 - interference));
    const score = Math.max(0, Math.min(100, Math.round((prx + 112) * 2.15 + sinr * 2.2)));
    const integrity = Math.max(12, Math.min(96, score));
    const cell = state.shadow > 20 ? "SITE-C" : state.veg > 50 ? "SITE-A" : "SITE-B";
    return {d,pl,veg,shadow,fade,sector,prx,sinr,score,integrity,cell,totalLoss:pl+veg+shadow+fade};
  }

  function drawMain(){
    const c = el.canvas;
    if(!c) return;
    const {w,h} = resizeCanvas(c);
    const ctx = c.getContext("2d", {alpha:false});
    if(!ctx) return;

    const est = estimate();
    const img = ctx.createImageData(w,h);
    const data = img.data;

    const sites = [
      {x:0.18,y:0.72,p:1.00,name:"SITE-A"},
      {x:0.54,y:0.23,p:1.14,name:"SITE-B"},
      {x:0.84,y:0.60,p:0.96,name:"SITE-C"}
    ];

    const blocks = [
      {x:.31,y:.38,w:.055,h:.26,loss:.42},
      {x:.58,y:.31,w:.060,h:.21,loss:.36},
      {x:.75,y:.40,w:.060,h:.24,loss:.46},
      {x:.50,y:.68,w:.065,h:.18,loss:.32}
    ];

    for(let y=0; y<h; y++){
      for(let x=0; x<w; x++){
        const nx = x/w;
        const ny = y/h;
        let field = 0;

        for(const s of sites){
          const dx = nx-s.x;
          const dy = ny-s.y;
          const dist = Math.sqrt(dx*dx+dy*dy) + 0.015;
          field += s.p / Math.pow(dist, 0.92 + state.n*0.04);
        }

        let clutter = 0;
        for(const b of blocks){
          const inside = nx>b.x && nx<b.x+b.w && ny>b.y && ny<b.y+b.h;
          const edge = Math.max(Math.abs(nx-(b.x+b.w/2))/(b.w/2), Math.abs(ny-(b.y+b.h/2))/(b.h/2));
          if(inside) clutter += b.loss;
          else if(edge < 1.9) clutter += b.loss * (1.9-edge) * .18;
        }

        const vegWave =
          Math.sin(nx*18 + state.t*0.018) * Math.cos(ny*10 - state.t*0.012) * 0.06 +
          Math.sin((nx+ny)*25) * 0.025;

        const shadowBand = Math.max(0, Math.sin((nx*2.2 - ny*3.4 + .45) * Math.PI)) * state.shadow * .003;
        const noise = Math.sin((x*12.9898 + y*78.233) * 0.017) * 0.015;
        const atten = state.veg * 0.0025 + state.delay * 0.00032 + clutter + shadowBand;

        let score = field * 0.022 + vegWave + noise - atten;
        score = Math.max(0, Math.min(1, score));

        if(state.mode === "channel") score *= 0.92;
        if(state.mode === "signal") score = Math.max(0, Math.min(1, score*0.86 + 0.10));
        if(state.mode === "teach") score = Math.round(score*8)/8;

        const [r,g,b] = colorForScore(score);
        const i = (y*w+x)*4;
        data[i] = r;
        data[i+1] = g;
        data[i+2] = b;
        data[i+3] = 255;
      }
    }

    ctx.putImageData(img,0,0);

    // griglia strumentale
    ctx.save();
    ctx.globalAlpha = 0.20;
    ctx.strokeStyle = "#8ff0ff";
    ctx.lineWidth = 1;
    const gx = w/18, gy = h/10;
    for(let x=gx; x<w; x+=gx){ ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke(); }
    for(let y=gy; y<h; y+=gy){ ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke(); }
    ctx.restore();

    // beam sectors
    ctx.save();
    sites.forEach((s,idx)=>{
      const sx=s.x*w, sy=s.y*h;
      ctx.beginPath();
      ctx.moveTo(sx,sy);
      ctx.lineTo(w*(idx===0?.52:idx===1?.66:.58), h*(idx===0?.55:idx===1?.48:.66));
      ctx.lineWidth=2;
      ctx.strokeStyle=idx===1?"rgba(143,240,255,.75)":"rgba(66,245,111,.55)";
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(sx,sy,Math.min(w,h)*.045,0,Math.PI*2);
      ctx.fillStyle="rgba(143,240,255,.24)";
      ctx.fill();
      ctx.strokeStyle="rgba(232,250,255,.70)";
      ctx.stroke();

      ctx.fillStyle="#e8faff";
      ctx.beginPath();
      ctx.arc(sx,sy,6,0,Math.PI*2);
      ctx.fill();

      ctx.font="12px ui-monospace,monospace";
      ctx.fillStyle="#e8faff";
      ctx.textAlign="center";
      ctx.fillText(s.name,sx,sy+42);
    });

    // edifici
    const blocksPx = [
      {x:.31,y:.38,w:.055,h:.26},
      {x:.58,y:.31,w:.060,h:.21},
      {x:.75,y:.40,w:.060,h:.24},
      {x:.50,y:.68,w:.065,h:.18}
    ];

    blocksPx.forEach(b=>{
      const x=b.x*w, y=b.y*h, bw=b.w*w, bh=b.h*h;
      ctx.fillStyle="rgba(5,22,38,.58)";
      ctx.fillRect(x,y,bw,bh);
      ctx.strokeStyle="rgba(143,240,255,.45)";
      ctx.strokeRect(x,y,bw,bh);
      ctx.fillStyle="rgba(0,0,0,.45)";
      ctx.beginPath();
      ctx.moveTo(x+bw,y);
      ctx.lineTo(x+bw+20,y+18);
      ctx.lineTo(x+bw+20,y+bh+18);
      ctx.lineTo(x+bw,y+bh);
      ctx.closePath();
      ctx.fill();
    });

    // UE/probe
    const px = w*.66, py = h*.60;
    ctx.strokeStyle="rgba(251,191,36,.85)";
    ctx.setLineDash([5,6]);
    ctx.beginPath();
    ctx.moveTo(w*.18,h*.72);
    ctx.lineTo(px,py);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.strokeStyle="rgba(232,250,255,.75)";
    ctx.beginPath();
    ctx.arc(px,py,18,0,Math.PI*2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(px-26,py); ctx.lineTo(px+26,py);
    ctx.moveTo(px,py-26); ctx.lineTo(px,py+26);
    ctx.stroke();

    ctx.fillStyle="#e8faff";
    ctx.font="11px ui-monospace,monospace";
    ctx.fillText("UE-42",px+8,py-10);

    updateReadouts(est);
  }

  function drawGrid(ctx,w,h){
    ctx.clearRect(0,0,w,h);
    ctx.fillStyle="#020813";
    ctx.fillRect(0,0,w,h);
    ctx.strokeStyle="rgba(143,240,255,.12)";
    ctx.lineWidth=1;
    for(let x=0;x<w;x+=32){ ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke(); }
    for(let y=0;y<h;y+=28){ ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke(); }
  }

  function drawIq(){
    const c = el.iq; if(!c) return;
    const ctx = c.getContext("2d");
    const w=c.width,h=c.height;
    drawGrid(ctx,w,h);
    const est=estimate();
    const spread = Math.max(3, 14 - est.sinr*.35 + state.shadow*.12);
    const levels=[-3,-1,1,3];
    ctx.fillStyle="rgba(66,245,111,.70)";
    for(let i=0;i<720;i++){
      const ix=levels[i%4], iy=levels[Math.floor(i/4)%4];
      const n1=Math.sin(i*12.989+state.t*.03)*spread;
      const n2=Math.cos(i*7.13+state.t*.02)*spread;
      const x=w/2+ix*38+n1;
      const y=h/2+iy*28+n2;
      ctx.fillRect(x,y,2,2);
    }
    ctx.strokeStyle="rgba(255,59,92,.75)";
    ctx.beginPath(); ctx.moveTo(0,h-22); ctx.lineTo(w,h-22); ctx.stroke();
  }

  function drawPdp(){
    const c = el.pdp; if(!c) return;
    const ctx = c.getContext("2d");
    const w=c.width,h=c.height;
    drawGrid(ctx,w,h);
    ctx.strokeStyle="rgba(251,191,36,.86)";
    ctx.lineWidth=3;
    const taps=[.08,.13,.17,.24,.38,.56,.78,.93];
    taps.forEach((t,i)=>{
      const amp = (i<3 ? .75-i*.16 : .22/(i*.45)) * (1 + state.delay/600);
      ctx.beginPath();
      ctx.moveTo(w*t,h-22);
      ctx.lineTo(w*t,Math.max(18,h-22-amp*120));
      ctx.stroke();
    });
    ctx.fillStyle="rgba(232,250,255,.60)";
    ctx.font="11px ui-monospace,monospace";
    ctx.fillText(`RMS delay ${state.delay} ns`,14,18);
  }

  function drawHf(){
    const c = el.hf; if(!c) return;
    const ctx = c.getContext("2d");
    const w=c.width,h=c.height;
    drawGrid(ctx,w,h);
    ctx.strokeStyle="rgba(143,240,255,.88)";
    ctx.lineWidth=2;
    ctx.beginPath();
    for(let x=0;x<w;x++){
      const nx=x/w;
      const notch = Math.exp(-Math.pow((nx-.28)*25,2))*40 + Math.exp(-Math.pow((nx-.68)*38,2))*26;
      const ripple = Math.sin(nx*70 + state.t*.015)*7 + Math.sin(nx*17)*12;
      const y=h*.48 + ripple + notch + state.shadow*.8;
      if(x===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();
  }

  function updateReadouts(est){
    if(el.integrity) el.integrity.textContent = `${est.integrity}%`;
    if(el.best) el.best.textContent = est.cell;
    if(el.rsrp) el.rsrp.textContent = `${est.prx.toFixed(1)} dBm`;
    if(el.sinr) el.sinr.textContent = `${est.sinr.toFixed(1)} dB`;
    if(el.loss) el.loss.textContent = `${est.totalLoss.toFixed(1)} dB`;
    if(el.coverage) el.coverage.textContent = `${est.integrity}%`;
    if(el.cell) el.cell.textContent = est.cell;

    if(el.copilot){
      const msg = est.integrity > 80
        ? "Campo coerente: best-server stabile, SINR sufficiente, link budget leggibile."
        : est.integrity > 58
          ? "Margine medio: verificare clutter, fading selettivo e vicinanza NLOS."
          : "Criticità operativa: degrado RF, shadowing/fading elevato, serve recovery o cambio serving cell.";
      el.copilot.textContent = msg;
    }

    if(el.fsplText) el.fsplText.textContent = `d=${est.d} m, f=${state.freq} MHz → FSPL≈${fspl(est.d).toFixed(1)} dB.`;
    if(el.vegText) el.vegText.textContent = `Lveg≈${est.veg.toFixed(1)} dB, depth=${state.veg} m, clutter controllato.`;
    if(el.prxText) el.prxText.textContent = `Prx≈${est.prx.toFixed(1)} dBm, SINR≈${est.sinr.toFixed(1)} dB, best-server=${est.cell}.`;
  }

  function renderAll(){
    drawMain();
    drawIq();
    drawPdp();
    drawHf();
  }

  function tick(){
    state.t += 1;
    if(!state.paused) renderAll();
    requestAnimationFrame(tick);
  }

  window.addEventListener("resize", renderAll);
  setMode("measure");
  renderAll();
  tick();
})();
