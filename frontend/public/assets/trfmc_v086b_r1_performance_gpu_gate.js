(function(){
  "use strict";

  const root = document.getElementById("pg86-root");
  const canvas = document.getElementById("pg86Canvas");

  let probeCanvas = document.getElementById("pg86ProbeCanvas");
  if(!probeCanvas){
    probeCanvas = document.createElement("canvas");
    probeCanvas.id = "pg86ProbeCanvas";
    probeCanvas.width = 16;
    probeCanvas.height = 16;
    probeCanvas.style.cssText = "position:absolute;left:-99999px;top:-99999px;width:16px;height:16px;opacity:0;pointer-events:none;";
    document.body.appendChild(probeCanvas);
  }

  if(!root || !canvas) return;

  const state = {
    quality: "balanced",
    paused: false,
    frames: 0,
    dropped: 0,
    last: performance.now(),
    lastWindow: performance.now(),
    frameTimes: [],
    t: 0,
    webglRenderer: "—",
    webglVendor: "—",
    webgpuAdapter: "—",
    webgpuStatus: "detecting"
  };

  const $ = id => document.getElementById(id);

  const out = {
    backend: $("pg86Backend"),
    vendor: $("pg86WebglVendor"),
    renderer: $("pg86WebglRenderer"),
    unmaskedVendor: $("pg86UnmaskedVendor"),
    unmaskedRenderer: $("pg86UnmaskedRenderer"),
    webgpuStatus: $("pg86WebgpuStatus"),
    webgpuAdapter: $("pg86WebgpuAdapter"),
    fps: $("pg86Fps"),
    avg: $("pg86FrameAvg"),
    max: $("pg86FrameMax"),
    min: $("pg86FrameMin"),
    dropped: $("pg86Dropped"),
    dpr: $("pg86Dpr"),
    css: $("pg86CssSize"),
    backing: $("pg86BackingSize"),
    quality: $("pg86QualityReadout"),
    verdict: $("pg86Verdict"),
    verdictDetail: $("pg86VerdictDetail"),
    overlayRenderer: $("pg86OverlayRenderer"),
    overlayBudget: $("pg86OverlayBudget")
  };

  document.querySelectorAll("[data-quality]").forEach(btn=>{
    btn.addEventListener("click",()=>{
      setQuality(btn.dataset.quality || "balanced");
    });
  });

  $("pg86Pause")?.addEventListener("click",()=>{
    state.paused = !state.paused;
    $("pg86Pause").textContent = state.paused ? "Resume" : "Pause";
  });

  $("pg86Reset")?.addEventListener("click",resetStats);
  $("pg86RefreshGpu")?.addEventListener("click",probeGpu);
  $("pg86Export")?.addEventListener("click",exportJson);

  async function checkBackend(){
    try{
      const r = await fetch("/api/health", {cache:"no-store"});
      if(out.backend) out.backend.textContent = r.ok ? "Backend OK" : "Backend ERR";
    } catch {
      if(out.backend) out.backend.textContent = "Backend OFF";
    }
  }

  function resize(){
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.max(1, Math.min(devicePixelRatio || 1, qualityDpr()));
    const w = Math.max(640, Math.round(rect.width * dpr));
    const h = Math.max(280, Math.round(rect.height * dpr));
    if(canvas.width !== w || canvas.height !== h){
      canvas.width = w;
      canvas.height = h;
    }
    if(out.dpr) out.dpr.textContent = `${(devicePixelRatio || 1).toFixed(2)} / cap ${dpr.toFixed(2)}`;
    if(out.css) out.css.textContent = `${Math.round(rect.width)} × ${Math.round(rect.height)}`;
    if(out.backing) out.backing.textContent = `${canvas.width} × ${canvas.height}`;
    if(out.overlayBudget) out.overlayBudget.textContent = `canvas ${canvas.width}×${canvas.height} · ${state.quality}`;
  }

  function qualityDpr(){
    if(state.quality === "safe") return 1.0;
    if(state.quality === "supreme") return 2.0;
    return 1.35;
  }

  function qualityCells(){
    if(state.quality === "safe") return 42;
    if(state.quality === "supreme") return 96;
    return 64;
  }

  function setQuality(q){
    state.quality = ["safe","balanced","supreme"].includes(q) ? q : "balanced";
    document.querySelectorAll("[data-quality]").forEach(btn=>{
      btn.classList.toggle("is-active", btn.dataset.quality === state.quality);
    });
    if(out.quality) out.quality.textContent = state.quality.toUpperCase();
    resize();
    resetStats();
  }

  function resetStats(){
    state.frames = 0;
    state.dropped = 0;
    state.frameTimes = [];
    state.last = performance.now();
    state.lastWindow = performance.now();
  }

  function getWebglContext(){
    // R1 FIX:
    // Il canvas visibile resta dedicato al benchmark 2D.
    // Il probe WebGL usa un canvas separato, altrimenti il canvas principale resta bloccato in modalità WebGL
    // e canvas.getContext("2d") restituisce null.
    return probeCanvas.getContext("webgl2", {alpha:false, antialias:false, powerPreference:"high-performance"}) ||
           probeCanvas.getContext("webgl", {alpha:false, antialias:false, powerPreference:"high-performance"}) ||
           probeCanvas.getContext("experimental-webgl", {alpha:false, antialias:false});
  }

  async function probeGpu(){
    const gl = getWebglContext();

    if(gl){
      state.webglVendor = gl.getParameter(gl.VENDOR) || "—";
      state.webglRenderer = gl.getParameter(gl.RENDERER) || "—";

      let uv = "not exposed";
      let ur = "not exposed";
      const dbg = gl.getExtension("WEBGL_debug_renderer_info");
      if(dbg){
        uv = gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) || "—";
        ur = gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) || "—";
      }

      if(out.vendor) out.vendor.textContent = state.webglVendor;
      if(out.renderer) out.renderer.textContent = state.webglRenderer;
      if(out.unmaskedVendor) out.unmaskedVendor.textContent = uv;
      if(out.unmaskedRenderer) out.unmaskedRenderer.textContent = ur;
      if(out.overlayRenderer) out.overlayRenderer.textContent = `WebGL: ${ur !== "not exposed" ? ur : state.webglRenderer}`;
    } else {
      if(out.renderer) out.renderer.textContent = "WebGL unavailable";
      if(out.overlayRenderer) out.overlayRenderer.textContent = "WebGL unavailable";
    }

    if("gpu" in navigator){
      try{
        const adapter = await navigator.gpu.requestAdapter({powerPreference:"high-performance"});
        if(adapter){
          let info = {};
          if(adapter.info) {
            info = adapter.info;
          } else if(adapter.requestAdapterInfo) {
            info = await adapter.requestAdapterInfo();
          }

          state.webgpuStatus = "available";
          state.webgpuAdapter = [
            info.vendor,
            info.architecture,
            info.device,
            info.description
          ].filter(Boolean).join(" · ") || "available / info hidden";

          if(out.webgpuStatus) out.webgpuStatus.textContent = "Available";
          if(out.webgpuAdapter) out.webgpuAdapter.textContent = state.webgpuAdapter;
        } else {
          state.webgpuStatus = "no adapter";
          if(out.webgpuStatus) out.webgpuStatus.textContent = "No adapter";
          if(out.webgpuAdapter) out.webgpuAdapter.textContent = "—";
        }
      } catch(e){
        state.webgpuStatus = "error";
        if(out.webgpuStatus) out.webgpuStatus.textContent = "Error";
        if(out.webgpuAdapter) out.webgpuAdapter.textContent = String(e.message || e);
      }
    } else {
      state.webgpuStatus = "not supported";
      if(out.webgpuStatus) out.webgpuStatus.textContent = "Not supported";
      if(out.webgpuAdapter) out.webgpuAdapter.textContent = "—";
    }
  }

  function draw(now){
    resize();

    const ctx = canvas.getContext("2d", {alpha:false});

    if(!ctx){
      if(out.verdict) out.verdict.textContent = "FAIL";
      if(out.verdictDetail) out.verdictDetail.textContent = "2D canvas context non disponibile";
      if(out.overlayBudget) out.overlayBudget.textContent = "ERROR: 2D context unavailable";
      return;
    }

    const w = canvas.width;
    const h = canvas.height;
    const cells = qualityCells();
    const cw = w / cells;
    const ch = h / Math.round(cells * h / w);

    ctx.fillStyle = "#020813";
    ctx.fillRect(0,0,w,h);

    const rows = Math.ceil(h / ch);
    state.t += 0.012;

    for(let y=0;y<rows;y++){
      for(let x=0;x<cells;x++){
        const nx = x/cells;
        const ny = y/rows;

        const s1 = Math.hypot(nx-.22, ny-.70);
        const s2 = Math.hypot(nx-.58, ny-.24);
        const s3 = Math.hypot(nx-.84, ny-.58);

        let f = 0.38/(s1+.045) + 0.52/(s2+.045) + 0.34/(s3+.045);
        f *= 0.18;

        f += Math.sin(nx*18 + now*.0012) * Math.cos(ny*10 - now*.0009) * .055;
        f -= Math.max(0, Math.sin((nx*2.2 - ny*3.4 + .45) * Math.PI)) * .12;

        if(state.quality === "safe") f = Math.round(f*7)/7;
        if(state.quality === "supreme") f += Math.sin((nx+ny)*70 + now*.001) * .018;

        f = Math.max(0, Math.min(1, f));
        const c = color(f);
        ctx.fillStyle = `rgb(${c[0]},${c[1]},${c[2]})`;
        ctx.fillRect(Math.floor(x*cw), Math.floor(y*ch), Math.ceil(cw)+1, Math.ceil(ch)+1);
      }
    }

    ctx.save();
    ctx.globalAlpha = .22;
    ctx.strokeStyle = "#8ff0ff";
    ctx.lineWidth = 1;
    for(let x=0; x<w; x+=w/18){ ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke(); }
    for(let y=0; y<h; y+=h/10){ ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke(); }
    ctx.restore();

    drawSite(ctx,w,h,.22,.70,"SITE-A");
    drawSite(ctx,w,h,.58,.24,"SITE-B");
    drawSite(ctx,w,h,.84,.58,"SITE-C");
  }

  function drawSite(ctx,w,h,x,y,label){
    const px=x*w, py=y*h;
    ctx.beginPath();
    ctx.arc(px,py,18,0,Math.PI*2);
    ctx.fillStyle="rgba(143,240,255,.25)";
    ctx.fill();
    ctx.strokeStyle="rgba(232,250,255,.75)";
    ctx.stroke();
    ctx.fillStyle="#e8faff";
    ctx.font="12px ui-monospace,monospace";
    ctx.textAlign="center";
    ctx.fillText(label,px,py+40);
  }

  function color(v){
    if(v < .18) return [2,6,17];
    if(v < .35) return [8,62,138];
    if(v < .52) return [10,160,208];
    if(v < .72) return [58,220,116];
    if(v < .86) return [225,201,69];
    return [214,75,69];
  }

  function loop(now){
    const dt = now - state.last;
    state.last = now;

    if(!state.paused){
      draw(now);
      state.frames++;
      state.frameTimes.push(dt);
      if(dt > 33.4) state.dropped++;
      if(state.frameTimes.length > 180) state.frameTimes.shift();
    }

    if(now - state.lastWindow >= 1000){
      const samples = state.frameTimes.slice();
      const avg = samples.reduce((a,b)=>a+b,0) / Math.max(1,samples.length);
      const min = Math.min(...samples);
      const max = Math.max(...samples);
      const fps = Math.round(1000 / avg);

      if(out.fps) out.fps.textContent = Number.isFinite(fps) ? String(fps) : "—";
      if(out.avg) out.avg.textContent = Number.isFinite(avg) ? `${avg.toFixed(1)} ms` : "—";
      if(out.max) out.max.textContent = Number.isFinite(max) ? `${max.toFixed(1)} ms` : "—";
      if(out.min) out.min.textContent = Number.isFinite(min) ? `${min.toFixed(1)} ms` : "—";
      if(out.dropped) out.dropped.textContent = String(state.dropped);

      updateVerdict(fps, avg, max);
      state.lastWindow = now;
    }

    requestAnimationFrame(loop);
  }

  function updateVerdict(fps, avg, max){
    let verdict = "PASS";
    let detail = "frame budget stabile";

    if(!Number.isFinite(fps) || fps < 35 || max > 80){
      verdict = "FAIL";
      detail = "jank elevato: ridurre qualità o canvas";
    } else if(fps < 50 || max > 45){
      verdict = "WATCH";
      detail = "accettabile ma non ancora production supreme";
    }

    if(out.verdict) out.verdict.textContent = verdict;
    if(out.verdictDetail) out.verdictDetail.textContent = detail;
  }

  function exportJson(){
    const report = {
      version: "TRFMC v0.86B-R1",
      timestamp: new Date().toISOString(),
      quality: state.quality,
      webglVendor: out.vendor?.textContent || null,
      webglRenderer: out.renderer?.textContent || null,
      unmaskedVendor: out.unmaskedVendor?.textContent || null,
      unmaskedRenderer: out.unmaskedRenderer?.textContent || null,
      webgpuStatus: out.webgpuStatus?.textContent || null,
      webgpuAdapter: out.webgpuAdapter?.textContent || null,
      fps: out.fps?.textContent || null,
      frameAvg: out.avg?.textContent || null,
      frameMax: out.max?.textContent || null,
      frameMin: out.min?.textContent || null,
      droppedFrames: out.dropped?.textContent || null,
      dpr: out.dpr?.textContent || null,
      cssSize: out.css?.textContent || null,
      backingSize: out.backing?.textContent || null,
      verdict: out.verdict?.textContent || null
    };

    const blob = new Blob([JSON.stringify(report,null,2)], {type:"application/json"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "trfmc_v86b_r1_runtime_report.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  window.addEventListener("resize", resize);

  checkBackend();
  probeGpu();
  setQuality("balanced");
  resetStats();
  requestAnimationFrame(loop);
})();
