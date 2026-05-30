/*
 TRFMC RF PRO Signal Intelligence Lab V1
 Synthetic/lab-only RF visual engine.
 No network fetch. No external dependency.
*/

(function(){
  "use strict";

  const TAU = Math.PI * 2;

  function fit(c){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(2, Math.floor(c.clientWidth * dpr));
    const h = Math.max(2, Math.floor(c.clientHeight * dpr));
    if(c.width !== w || c.height !== h){ c.width = w; c.height = h; }
    const ctx = c.getContext("2d");
    return {ctx,w,h,dpr};
  }

  function grid(ctx,w,h,dpr){
    ctx.strokeStyle = "rgba(0,229,255,.095)";
    ctx.lineWidth = 1*dpr;
    for(let i=0;i<12;i++){
      const x = w*i/11;
      ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke();
    }
    for(let i=0;i<7;i++){
      const y = h*i/6;
      ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke();
    }
  }

  function bg(ctx,w,h){
    const g = ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");
    g.addColorStop(1,"#010409");
    ctx.fillStyle = g;
    ctx.fillRect(0,0,w,h);
  }

  function text(ctx,dpr,label,x,y,color){
    ctx.fillStyle = color || "#8fb8c8";
    ctx.font = `${10*dpr}px ui-monospace,Consolas,monospace`;
    ctx.fillText(label,x,y);
  }

  function spectrum(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    ctx.lineWidth = 2*dpr;
    ctx.strokeStyle = "#00e5ff";
    ctx.beginPath();
    for(let i=0;i<900;i++){
      const f=i/899;
      const x=w*f;
      let y=h*.74 + Math.sin(i*.03+t*1.2)*h*.012;
      y -= Math.exp(-Math.pow(f-.19,2)/.00055)*h*.25;
      y -= Math.exp(-Math.pow(f-.33,2)/.00075)*h*.17;
      y -= Math.exp(-Math.pow(f-.51,2)/.00065)*h*.38;
      y -= Math.exp(-Math.pow(f-.68,2)/.00090)*h*.23;
      y -= Math.exp(-Math.pow(f-.84,2)/.00050)*h*.14;
      if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<5;i++){
      const cx=[.19,.33,.51,.68,.84][i]*w;
      const a=.08+.05*Math.sin(t+i);
      const rg=ctx.createRadialGradient(cx,h*.54,2*dpr,cx,h*.54,h*.18);
      rg.addColorStop(0,`rgba(117,255,91,${a})`);
      rg.addColorStop(1,"rgba(117,255,91,0)");
      ctx.fillStyle=rg;
      ctx.fillRect(cx-w*.08,h*.25,w*.16,h*.50);
    }
    ctx.restore();

    text(ctx,dpr,"SPECTRUM · SYNTHETIC RF SCENE · FFT/RBW/OBW/ACLR",10*dpr,18*dpr,"#8fb8c8");
    text(ctx,dpr,"RBW 30 kHz · Span 40 MHz · Noise floor -92 dBm",10*dpr,h-12*dpr,"#75ff5b");
  }

  function waterfall(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h);

    const rows=80, cols=180;
    const cw=w/cols, rh=h/rows;
    for(let y=0;y<rows;y++){
      for(let x=0;x<cols;x++){
        const f=x/cols;
        const age=y/rows;
        const hop = Math.floor((t*2 + y*.05))%8;
        const center = (.10 + ((hop*23)%80)/100);
        const burst1 = Math.exp(-Math.pow(f-center,2)/.0008);
        const burst2 = Math.exp(-Math.pow(f-(.25+.55*Math.abs(Math.sin(t*.2+y*.01))),2)/.0012);
        const noise = .08*Math.sin(x*.31+y*.21+t);
        const v = Math.max(0, Math.min(1, burst1*.95 + burst2*.35 + noise + .05));
        const r = Math.floor(20 + 40*v);
        const g = Math.floor(55 + 200*v);
        const b = Math.floor(80 + 175*v);
        ctx.fillStyle = `rgba(${r},${g},${b},${.35+.55*v})`;
        ctx.fillRect(x*cw,y*rh,cw+1,rh+1);
      }
    }

    grid(ctx,w,h,dpr);
    text(ctx,dpr,"WATERFALL · HOP/BURST OCCUPANCY MAP",10*dpr,18*dpr,"#dffaff");
  }

  function constellation(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    const cx=w*.5, cy=h*.52, scale=Math.min(w,h)*.25;
    ctx.strokeStyle="rgba(0,229,255,.22)";
    ctx.beginPath(); ctx.moveTo(cx, h*.12); ctx.lineTo(cx,h*.90); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w*.12, cy); ctx.lineTo(w*.88,cy); ctx.stroke();

    const pts=[[-1,-1],[-1,1],[1,-1],[1,1]];
    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<720;i++){
      const p=pts[i%4];
      const jitter=.10*Math.sin(t*2+i*.61);
      const jitter2=.10*Math.cos(t*1.7+i*.47);
      const x=cx+(p[0]+jitter)*scale;
      const y=cy+(p[1]+jitter2)*scale;
      ctx.fillStyle=i%5?"rgba(0,229,255,.16)":"rgba(117,255,91,.20)";
      ctx.beginPath(); ctx.arc(x,y,2.1*dpr,0,TAU); ctx.fill();
    }
    ctx.restore();

    text(ctx,dpr,"I/Q CONSTELLATION · QPSK SYNTHETIC · EVM TRACE",10*dpr,18*dpr,"#8fb8c8");
    text(ctx,dpr,"EVM 2.8% · CFO compensated · phase noise synthetic",10*dpr,h-12*dpr,"#75ff5b");
  }

  function timeline(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    const lanes=8;
    for(let l=0;l<lanes;l++){
      const y=h*(.18 + l*.085);
      ctx.strokeStyle="rgba(0,229,255,.12)";
      ctx.beginPath(); ctx.moveTo(w*.06,y); ctx.lineTo(w*.94,y); ctx.stroke();
      text(ctx,dpr,`CH${l+1}`,10*dpr,y+3*dpr,"#8fb8c8");
    }

    for(let i=0;i<42;i++){
      const lane=(i*5+Math.floor(t*2))%lanes;
      const x=w*((i*.067 + t*.055)%1);
      const y=h*(.18 + lane*.085)-8*dpr;
      const bw=w*(.018 + ((i%4)*.006));
      ctx.fillStyle=i%3===0?"rgba(255,216,77,.55)":i%3===1?"rgba(0,229,255,.55)":"rgba(117,255,91,.50)";
      ctx.fillRect(x,y,bw,16*dpr);
      ctx.strokeStyle="rgba(255,255,255,.22)";
      ctx.strokeRect(x,y,bw,16*dpr);
    }

    text(ctx,dpr,"FHSS / BURST TIMELINE · LAB-SYNTHETIC HOP SEQUENCE",10*dpr,18*dpr,"#dffaff");
  }

  function formula(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    ctx.fillStyle="#00e5ff";
    ctx.font=`${12*dpr}px ui-monospace,Consolas,monospace`;
    const lines=[
      "FFT: X[k] = Σ x[n]·e^(-j2πkn/N)",
      "RBW ≈ Fs/N · window_ENBW",
      "SNR = Psignal / Pnoise",
      "EVM = RMS(error_vector) / RMS(reference_vector)",
      "OBW: occupied bandwidth containing selected integrated power",
      "ACLR = Pchannel / Padjacent",
      "FHSS dwell = burst_time / hop_period"
    ];
    lines.forEach((line,i)=>{
      ctx.fillStyle=i%2?"#75ff5b":"#dffaff";
      ctx.fillText(line,18*dpr,(28+i*20)*dpr);
    });
  }

  class TrfmcRfProLab extends HTMLElement{
    connectedCallback(){
      this.innerHTML = `
        <section class="rfpro-root">
          <div class="rfpro-topology">
            <aside class="rfpro-panel">
              <div class="rfpro-title">RF PRO Signal Intelligence Lab</div>
              <div class="rfpro-sub">
                Controlled synthetic/lab-only signal laboratory. Built from RF PRO orphan dossier without mutating legacy pages.
              </div>
              <div class="rfpro-kpis">
                <div class="rfpro-kpi"><small>Mode</small><b>LAB</b></div>
                <div class="rfpro-kpi"><small>Input</small><b>IQ/SYN</b></div>
                <div class="rfpro-kpi"><small>FFT</small><b>LIVE</b></div>
                <div class="rfpro-kpi"><small>FHSS</small><b>TRACE</b></div>
                <div class="rfpro-kpi"><small>EVM</small><b>2.8%</b></div>
                <div class="rfpro-kpi"><small>Gate</small><b>PASS</b></div>
              </div>

              <div class="rfpro-card" style="margin-top:8px">
                <h3>Operational doctrine</h3>
                <p>
                  This leaf does not intercept, decode or operate on third-party RF traffic. It visualizes synthetic or lab-owned IQ concepts:
                  spectrum occupancy, burst timing, FHSS patterning, modulation quality and evidence-grade RF measurements.
                </p>
              </div>

              <div class="rfpro-card">
                <h3>RF PRO closure</h3>
                <span class="rfpro-pill">FFT</span>
                <span class="rfpro-pill">Waterfall</span>
                <span class="rfpro-pill">I/Q</span>
                <span class="rfpro-pill">FHSS</span>
                <span class="rfpro-pill">Burst</span>
                <span class="rfpro-pill">EVM</span>
                <span class="rfpro-pill">ACLR</span>
                <span class="rfpro-pill">OBW</span>
              </div>

              <div class="rfpro-card">
                <h3>Rebuild sources</h3>
                <div class="rfpro-source"><a href="/signal_demod_v581.html">/signal_demod_v581.html</a></div>
                <div class="rfpro-source"><a href="/signal_workbench_v580.html">/signal_workbench_v580.html</a></div>
                <div class="rfpro-source"><a href="/signal_workbench_v582.html">/signal_workbench_v582.html</a></div>
                <div class="rfpro-source"><a href="/uav_fhss_v584.html">/uav_fhss_v584.html</a></div>
              </div>
            </aside>

            <main class="rfpro-panel">
              <div class="rfpro-grid">
                <div class="rfpro-stack">
                  <div class="rfpro-card">
                    <h3>Vector Spectrum Analyzer</h3>
                    <canvas class="rfpro-canvas tall" data-rfpro="spectrum"></canvas>
                  </div>
                  <div class="rfpro-card">
                    <h3>Waterfall / Occupancy</h3>
                    <canvas class="rfpro-canvas" data-rfpro="waterfall"></canvas>
                  </div>
                  <div class="rfpro-card">
                    <h3>FHSS / Burst Timeline</h3>
                    <canvas class="rfpro-canvas small" data-rfpro="timeline"></canvas>
                  </div>
                </div>

                <div class="rfpro-stack">
                  <div class="rfpro-card">
                    <h3>Visual asset engine</h3>
                    <div class="rfpro-assets">
                      <trfmc-visual-asset kind="spectrum-scope" data-size="medium" title="RF Spectrum Scope"></trfmc-visual-asset>
                      <trfmc-visual-asset kind="cyber-evidence" data-size="small" title="Evidence Chain"></trfmc-visual-asset>
                      <trfmc-visual-asset kind="core-map" data-size="small" title="Signal-to-NOC Correlation"></trfmc-visual-asset>
                    </div>
                  </div>

                  <div class="rfpro-card">
                    <h3>I/Q constellation</h3>
                    <canvas class="rfpro-canvas" data-rfpro="constellation"></canvas>
                  </div>

                  <div class="rfpro-card">
                    <h3>Formula cockpit</h3>
                    <canvas class="rfpro-canvas small" data-rfpro="formula"></canvas>
                  </div>

                  <div class="rfpro-card">
                    <h3>Engineering formulas</h3>
                    <div class="rfpro-formulas formulaLive">FFT: X[k] = Σ x[n]·e^(-j2πkn/N)
RBW ≈ Fs/N · ENBW(window)
SNR = Psignal / Pnoise
EVM = RMS(error_vector) / RMS(reference_vector)
ACLR = Pchannel / Padjacent
OBW = bandwidth containing integrated occupied power
FHSS dwell ratio = burst_time / hop_period</div>
                  </div>
                </div>
              </div>
            </main>
          </div>
        </section>
      `;
      this.start();
    }

    start(){
      const canvases = Array.from(this.querySelectorAll("canvas[data-rfpro]"));
      const draw = (ms)=>{
        for(const c of canvases){
          const mode = c.dataset.rfpro;
          if(mode === "spectrum") spectrum(c,ms);
          else if(mode === "waterfall") waterfall(c,ms);
          else if(mode === "constellation") constellation(c,ms);
          else if(mode === "timeline") timeline(c,ms);
          else if(mode === "formula") formula(c,ms);
        }
        this._raf = requestAnimationFrame(draw);
      };
      this._raf = requestAnimationFrame(draw);
    }

    disconnectedCallback(){
      if(this._raf) cancelAnimationFrame(this._raf);
    }
  }

  if(!customElements.get("trfmc-rf-pro-lab")){
    customElements.define("trfmc-rf-pro-lab", TrfmcRfProLab);
  }
})();
