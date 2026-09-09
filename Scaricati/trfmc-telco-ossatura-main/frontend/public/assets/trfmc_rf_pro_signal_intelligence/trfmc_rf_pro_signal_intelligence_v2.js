/*
 TRFMC RF PRO Signal Intelligence Lab V2
 Web Component + DSP worker + RF rendering console.
 Synthetic/lab-only.
*/

(function(){
  "use strict";

  const WORKER_URL = "/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v2.js";
  const TAU = Math.PI * 2;

  function fit(c){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(2, Math.floor(c.clientWidth * dpr));
    const h = Math.max(2, Math.floor(c.clientHeight * dpr));
    if(c.width !== w || c.height !== h){ c.width = w; c.height = h; }
    return {ctx:c.getContext("2d"),w,h,dpr};
  }

  function bg(ctx,w,h){
    const g = ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");
    g.addColorStop(1,"#010409");
    ctx.fillStyle = g;
    ctx.fillRect(0,0,w,h);
  }

  function grid(ctx,w,h,dpr){
    ctx.strokeStyle = "rgba(0,229,255,.095)";
    ctx.lineWidth = 1*dpr;
    for(let i=0;i<12;i++){
      const x=w*i/11; ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke();
    }
    for(let i=0;i<7;i++){
      const y=h*i/6; ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke();
    }
  }

  function label(ctx,dpr,s,x,y,color){
    ctx.fillStyle = color || "#8fb8c8";
    ctx.font = `${10*dpr}px ui-monospace,Consolas,monospace`;
    ctx.fillText(s,x,y);
  }

  function drawSpectrum(c, data, metrics){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr);
    if(!data) return;

    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.strokeStyle = "#00e5ff";
    ctx.lineWidth = 2*dpr;
    ctx.beginPath();
    for(let i=0;i<data.length;i++){
      const x = w*i/(data.length-1);
      const y = h*(.88 - data[i]*.72);
      if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    for(let i=0;i<data.length;i+=8){
      if(data[i] > .45){
        const x = w*i/(data.length-1);
        const grd = ctx.createRadialGradient(x,h*.52,2*dpr,x,h*.52,h*.20);
        grd.addColorStop(0,`rgba(117,255,91,${Math.min(.18,data[i]*.15)})`);
        grd.addColorStop(1,"rgba(117,255,91,0)");
        ctx.fillStyle = grd;
        ctx.fillRect(x-w*.04,h*.20,w*.08,h*.55);
      }
    }
    ctx.restore();

    label(ctx,dpr,`VSA · ${metrics.profile.toUpperCase()} · CENTER ${metrics.centerMHz} MHz · SPAN ${metrics.spanMHz} MHz`,10*dpr,18*dpr,"#dffaff");
    label(ctx,dpr,`SNR ${metrics.snr} dB · EVM ${metrics.evm}% · ACLR ${metrics.aclr} dB · OBW ${metrics.obw} MHz`,10*dpr,h-12*dpr,"#75ff5b");
  }

  function drawWaterfall(c, rows){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);
    if(!rows.length) return;

    const rowCount = Math.min(rows.length, 90);
    const colCount = rows[0].length;
    const cw = w/colCount;
    const rh = h/rowCount;

    for(let y=0;y<rowCount;y++){
      const row = rows[rows.length-1-y];
      for(let x=0;x<colCount;x+=2){
        const v = row[x];
        const r = Math.floor(15 + 60*v);
        const g = Math.floor(45 + 210*v);
        const b = Math.floor(65 + 190*v);
        ctx.fillStyle = `rgba(${r},${g},${b},${.30+.65*v})`;
        ctx.fillRect(x*cw,y*rh,cw*2+1,rh+1);
      }
    }
    grid(ctx,w,h,dpr);
    label(ctx,dpr,"PERSISTENT WATERFALL · OCCUPANCY MEMORY",10*dpr,18*dpr,"#dffaff");
  }

  function drawConstellation(c, pts, metrics){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr);
    if(!pts) return;

    const cx=w*.5, cy=h*.52, scale=Math.min(w,h)*.28;
    ctx.strokeStyle="rgba(0,229,255,.22)";
    ctx.beginPath(); ctx.moveTo(cx,h*.12); ctx.lineTo(cx,h*.90); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w*.10,cy); ctx.lineTo(w*.90,cy); ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<pts.length;i+=2){
      const x=cx+pts[i]*scale;
      const y=cy+pts[i+1]*scale;
      ctx.fillStyle=i%12 ? "rgba(0,229,255,.17)" : "rgba(117,255,91,.25)";
      ctx.beginPath(); ctx.arc(x,y,2.2*dpr,0,TAU); ctx.fill();
    }
    ctx.restore();

    label(ctx,dpr,`I/Q CONSTELLATION · ${metrics.profile.toUpperCase()} · EVM ${metrics.evm}%`,10*dpr,18*dpr,"#8fb8c8");
  }

  function drawTimeline(c, bursts){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr);
    const lanes = 8;

    for(let l=0;l<lanes;l++){
      const y=h*(.18+l*.085);
      ctx.strokeStyle="rgba(0,229,255,.13)";
      ctx.beginPath(); ctx.moveTo(w*.06,y); ctx.lineTo(w*.94,y); ctx.stroke();
      label(ctx,dpr,`CH${l+1}`,10*dpr,y+3*dpr,"#8fb8c8");
    }

    if(bursts){
      for(let i=0;i<bursts.length;i+=4){
        const x = bursts[i]*w*.88 + w*.06;
        const lane = bursts[i+1];
        const width = bursts[i+2]*w;
        const amp = bursts[i+3];
        const y = h*(.18+lane*.085)-8*dpr;
        ctx.fillStyle = amp>.75 ? "rgba(255,216,77,.58)" : i%8 ? "rgba(0,229,255,.52)" : "rgba(117,255,91,.50)";
        ctx.fillRect(x,y,width,16*dpr);
        ctx.strokeStyle="rgba(255,255,255,.20)";
        ctx.strokeRect(x,y,width,16*dpr);
      }
    }

    label(ctx,dpr,"FHSS HOPSET / BURST INTELLIGENCE TIMELINE",10*dpr,18*dpr,"#dffaff");
  }

  function drawMask(c, data){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr);
    if(!data) return;

    ctx.fillStyle="rgba(255,61,127,.10)";
    ctx.fillRect(w*.08,h*.16,w*.18,h*.68);
    ctx.fillRect(w*.74,h*.16,w*.18,h*.68);

    ctx.strokeStyle="#ffd84d";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<data.length;i++){
      const x=w*i/(data.length-1);
      const y=h*(.86-data[i]*.68);
      if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    label(ctx,dpr,"SPECTRAL MASK · ADJACENT CHANNEL WATCH",10*dpr,18*dpr,"#dffaff");
    label(ctx,dpr,"red zones = adjacent risk bands",10*dpr,h-12*dpr,"#ff3d7f");
  }

  function drawFormula(c, metrics){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr);
    const lines = [
      "FFT: X[k] = Σ x[n] · exp(-j2πkn/N)",
      "RBW ≈ Fs/N · ENBW(window)",
      "SNR = Psignal / Pnoise",
      "EVM = RMS(error_vector) / RMS(reference_vector)",
      "ACLR = Pchannel / Padjacent",
      "OBW = ∫P(f) df inside occupied mask",
      "FHSS dwell = burst_time / hop_period",
      `LIVE: SNR ${metrics.snr} dB · EVM ${metrics.evm}% · OBW ${metrics.obw} MHz`
    ];
    ctx.font=`${11*dpr}px ui-monospace,Consolas,monospace`;
    lines.forEach((line,i)=>{
      ctx.fillStyle = i%2 ? "#75ff5b" : "#dffaff";
      ctx.fillText(line,16*dpr,(24+i*18)*dpr);
    });
  }

  class TrfmcRfProLabV2 extends HTMLElement{
    connectedCallback(){
      this.rows = [];
      this.latest = {spectrum:null, constellation:null, bursts:null, metrics:{profile:"fhss",snr:28,evm:2.6,aclr:51,obw:7.2,spanMHz:40,rbwKHz:30,centerMHz:2440}};
      this.innerHTML = `
        <section class="rf2-root">
          <div class="rf2-grid">
            <aside class="rf2-panel">
              <div class="rf2-title">RF PRO V2 Signal Intelligence</div>
              <div class="rf2-sub">Instrument-grade synthetic RF console: DSP worker, persistent waterfall, spectrum mask, I/Q, FHSS timeline and GPU readiness.</div>

              <div class="rf2-kpis">
                <div class="rf2-kpi"><small>Profile</small><b data-kpi="profile">FHSS</b></div>
                <div class="rf2-kpi"><small>SNR</small><b data-kpi="snr">28 dB</b></div>
                <div class="rf2-kpi"><small>EVM</small><b data-kpi="evm">2.6%</b></div>
                <div class="rf2-kpi"><small>OBW</small><b data-kpi="obw">7.2 MHz</b></div>
                <div class="rf2-kpi"><small>ACLR</small><b data-kpi="aclr">51 dB</b></div>
                <div class="rf2-kpi"><small>WebGPU</small><b data-kpi="gpu">CHECK</b></div>
              </div>

              <div class="rf2-card">
                <h3>Scenario controls</h3>
                <label class="rf2-control"><span>Profile</span><select data-control="profile">
                  <option value="fhss">FHSS / hopping burst</option>
                  <option value="ofdm">OFDM occupied channel</option>
                  <option value="qpsk">QPSK narrowband</option>
                  <option value="burst">Agile burst emitter</option>
                  <option value="noise">Noise / baseline</option>
                </select></label>
                <label class="rf2-control"><span>SNR dB</span><input data-control="snr" type="range" min="4" max="42" value="28"></label>
                <label class="rf2-control"><span>Span MHz</span><input data-control="spanMHz" type="range" min="5" max="120" value="40"></label>
                <label class="rf2-control"><span>RBW kHz</span><input data-control="rbwKHz" type="range" min="1" max="300" value="30"></label>
              </div>

              <div class="rf2-card">
                <h3>Lab-only doctrine</h3>
                <p class="rf2-sub">Synthetic or lab-owned IQ only. No third-party interception, no SDR device control, no decoding of protected traffic. This is an RF engineering and evidence-visualization instrument panel.</p>
              </div>

              <div class="rf2-card">
                <h3>Capabilities</h3>
                <span class="rf2-pill">DSP Worker</span>
                <span class="rf2-pill">Waterfall Memory</span>
                <span class="rf2-pill">FHSS Hopset</span>
                <span class="rf2-pill">Spectral Mask</span>
                <span class="rf2-pill">I/Q Cloud</span>
                <span class="rf2-pill">Formula Matrix</span>
                <span class="rf2-pill">WebGPU Readiness</span>
              </div>
            </aside>

            <main class="rf2-panel">
              <div class="rf2-main">
                <div class="rf2-stack">
                  <div class="rf2-card"><h3>Vector Spectrum Analyzer</h3><canvas class="rf2-canvas tall" data-scope="spectrum"></canvas></div>
                  <div class="rf2-card"><h3>Persistent Waterfall</h3><canvas class="rf2-canvas" data-scope="waterfall"></canvas></div>
                  <div class="rf2-card"><h3>FHSS / Burst Intelligence Timeline</h3><canvas class="rf2-canvas small" data-scope="timeline"></canvas></div>
                </div>

                <div class="rf2-stack">
                  <div class="rf2-card">
                    <h3>Visual Asset Binding</h3>
                    <div class="rf2-assets">
                      <trfmc-visual-asset kind="spectrum-scope" data-size="medium" title="RF PRO V2 Spectrum"></trfmc-visual-asset>
                      <trfmc-visual-asset kind="cyber-evidence" data-size="small" title="RF Evidence Chain"></trfmc-visual-asset>
                      <trfmc-visual-asset kind="core-map" data-size="small" title="NOC Correlation"></trfmc-visual-asset>
                    </div>
                  </div>
                  <div class="rf2-card"><h3>I/Q Constellation and EVM</h3><canvas class="rf2-canvas" data-scope="constellation"></canvas></div>
                  <div class="rf2-card"><h3>Spectral Mask / ACLR Watch</h3><canvas class="rf2-canvas small" data-scope="mask"></canvas></div>
                  <div class="rf2-card"><h3>Formula Matrix</h3><canvas class="rf2-canvas small" data-scope="formula"></canvas></div>
                </div>
              </div>
            </main>
          </div>
        </section>
      `;
      this.bindControls();
      this.startWorker();
      this.startRenderer();
      this.detectGpu();
    }

    bindControls(){
      this.config = {profile:"fhss", snr:28, spanMHz:40, rbwKHz:30, centerMHz:2440};
      this.querySelectorAll("[data-control]").forEach(el=>{
        el.addEventListener("input", ()=>{
          const key = el.dataset.control;
          const val = el.type === "range" ? Number(el.value) : el.value;
          this.config[key] = val;
          if(this.worker) this.worker.postMessage({type:"config", config:this.config});
        });
      });
    }

    startWorker(){
      try{
        this.worker = new Worker(WORKER_URL);
        this.worker.onmessage = (ev)=>{
          const m = ev.data || {};
          if(m.type === "frame"){
            this.latest = m;
            if(m.spectrum){
              this.rows.push(m.spectrum);
              if(this.rows.length > 120) this.rows.shift();
            }
            this.updateKpis(m.metrics);
          }
        };
        this.worker.postMessage({type:"config", config:this.config});
      }catch(e){
        console.warn("RF PRO V2 worker unavailable", e);
      }
    }

    updateKpis(metrics){
      if(!metrics) return;
      const set = (k,v)=>{ const el=this.querySelector(`[data-kpi="${k}"]`); if(el) el.textContent=v; };
      set("profile", String(metrics.profile || "").toUpperCase());
      set("snr", `${metrics.snr} dB`);
      set("evm", `${metrics.evm}%`);
      set("obw", `${metrics.obw} MHz`);
      set("aclr", `${metrics.aclr} dB`);
    }

    detectGpu(){
      const el = this.querySelector('[data-kpi="gpu"]');
      if(el) el.textContent = navigator.gpu ? "READY" : "FALLBACK";
    }

    startRenderer(){
      const draw = ()=>{
        const m = this.latest.metrics || {};
        this.querySelectorAll("canvas[data-scope]").forEach(c=>{
          const s = c.dataset.scope;
          if(s==="spectrum") drawSpectrum(c,this.latest.spectrum,m);
          else if(s==="waterfall") drawWaterfall(c,this.rows);
          else if(s==="constellation") drawConstellation(c,this.latest.constellation,m);
          else if(s==="timeline") drawTimeline(c,this.latest.bursts);
          else if(s==="mask") drawMask(c,this.latest.spectrum);
          else if(s==="formula") drawFormula(c,m);
        });
        this.raf = requestAnimationFrame(draw);
      };
      this.raf = requestAnimationFrame(draw);
    }

    disconnectedCallback(){
      if(this.raf) cancelAnimationFrame(this.raf);
      if(this.worker) this.worker.terminate();
    }
  }

  if(!customElements.get("trfmc-rf-pro-lab-v2")){
    customElements.define("trfmc-rf-pro-lab-v2", TrfmcRfProLabV2);
  }
})();
