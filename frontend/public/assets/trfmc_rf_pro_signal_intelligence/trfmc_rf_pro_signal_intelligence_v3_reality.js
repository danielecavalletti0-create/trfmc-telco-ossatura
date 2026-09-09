(function(){
  "use strict";

  const WORKER_URL = "/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v3.js";
  const TAU = Math.PI * 2;

  function fit(c){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(2, Math.floor(c.clientWidth * dpr));
    const h = Math.max(2, Math.floor(c.clientHeight * dpr));
    if(c.width !== w || c.height !== h){ c.width=w; c.height=h; }
    return {ctx:c.getContext("2d"),w,h,dpr};
  }

  function bg(ctx,w,h){
    const g=ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");
    g.addColorStop(.55,"#020812");
    g.addColorStop(1,"#010409");
    ctx.fillStyle=g;
    ctx.fillRect(0,0,w,h);
  }

  function grid(ctx,w,h,dpr,strong){
    ctx.lineWidth=1*dpr;
    ctx.strokeStyle=strong?"rgba(0,229,255,.16)":"rgba(0,229,255,.085)";
    for(let i=0;i<13;i++){ const x=w*i/12; ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke(); }
    for(let i=0;i<9;i++){ const y=h*i/8; ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke(); }
  }

  function label(ctx,dpr,s,x,y,color,size){
    ctx.fillStyle=color || "#8fb8c8";
    ctx.font = `${size||10*dpr}px ui-monospace,Consolas,monospace`;
    ctx.fillText(s,x,y);
  }

  function roundRect(ctx,x,y,w,h,r){
    ctx.beginPath();
    ctx.moveTo(x+r,y);
    ctx.arcTo(x+w,y,x+w,y+h,r);
    ctx.arcTo(x+w,y+h,x,y+h,r);
    ctx.arcTo(x,y+h,x,y,r);
    ctx.arcTo(x,y,x+w,y,r);
    ctx.closePath();
  }

  function drawRealityScene(c,data,metrics,time){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);

    ctx.save();
    ctx.strokeStyle="rgba(0,229,255,.08)";
    for(let i=0;i<18;i++){
      const y=h*(.68+i*.025);
      ctx.beginPath();
      ctx.moveTo(w*.05,y);
      ctx.lineTo(w*.95,y-h*.20);
      ctx.stroke();
    }
    for(let i=0;i<24;i++){
      const x=w*(.05+i*.04);
      ctx.beginPath();
      ctx.moveTo(x,h*.98);
      ctx.lineTo(w*.52+(x-w*.52)*.18,h*.58);
      ctx.stroke();
    }

    const mastX=w*.20, baseY=h*.82;
    const dishX=w*.31, dishY=h*.48;
    const uavX=w*(.76 + .035*Math.sin(time*.001)), uavY=h*(.26 + .035*Math.cos(time*.0012));

    ctx.lineWidth=5*dpr;
    ctx.strokeStyle="rgba(215,240,245,.80)";
    ctx.beginPath(); ctx.moveTo(mastX,baseY); ctx.lineTo(mastX,h*.23); ctx.stroke();

    ctx.fillStyle="rgba(120,150,160,.85)";
    roundRect(ctx,mastX-28*dpr,h*.50,56*dpr,95*dpr,8*dpr); ctx.fill();
    ctx.strokeStyle="rgba(255,255,255,.18)"; ctx.stroke();

    for(let i=0;i<12;i++){
      ctx.strokeStyle=`rgba(210,235,240,${.10+i*.025})`;
      ctx.lineWidth=1*dpr;
      ctx.beginPath();
      ctx.ellipse(dishX,dishY,58*dpr+i*2*dpr,112*dpr+i*2*dpr,-0.08,0,TAU);
      ctx.stroke();
    }
    ctx.fillStyle="rgba(230,248,255,.88)";
    ctx.beginPath(); ctx.ellipse(dishX,dishY,58*dpr,112*dpr,-0.08,0,TAU); ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.32)"; ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<28;i++){
      const a = i/28;
      ctx.strokeStyle=`rgba(0,229,255,${.018 + .055*(1-a)})`;
      ctx.lineWidth=(1+i*.035)*dpr;
      ctx.beginPath();
      ctx.moveTo(dishX+52*dpr,dishY);
      ctx.quadraticCurveTo(w*(.50+a*.05),h*(.38+a*.18),uavX,uavY);
      ctx.stroke();
    }

    const rg=ctx.createRadialGradient(uavX,uavY,4*dpr,uavX,uavY,80*dpr);
    rg.addColorStop(0,"rgba(255,216,77,.42)");
    rg.addColorStop(1,"rgba(255,216,77,0)");
    ctx.fillStyle=rg; ctx.fillRect(uavX-90*dpr,uavY-90*dpr,180*dpr,180*dpr);
    ctx.restore();

    ctx.strokeStyle="rgba(255,216,77,.95)";
    ctx.lineWidth=3*dpr;
    ctx.beginPath(); ctx.moveTo(uavX-30*dpr,uavY); ctx.lineTo(uavX+30*dpr,uavY); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(uavX,uavY-22*dpr); ctx.lineTo(uavX,uavY+22*dpr); ctx.stroke();
    ctx.fillStyle="rgba(255,216,77,.9)";
    ctx.beginPath(); ctx.arc(uavX,uavY,8*dpr,0,TAU); ctx.fill();

    label(ctx,dpr,"RF REALITY SCENE · emitter → antenna → DSP → evidence",18*dpr,24*dpr,"#dffaff",11*dpr);
    label(ctx,dpr,`${String(metrics.profile||"").toUpperCase()} · SNR ${metrics.snr} dB · anomaly ${metrics.anomaly}`,18*dpr,h-18*dpr,"#75ff5b",10*dpr);
    ctx.restore();
  }

  function drawVsa(c,spec,hold,metrics){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,true);
    if(!spec) return;

    ctx.strokeStyle="rgba(255,216,77,.52)";
    ctx.lineWidth=1*dpr;
    if(hold && hold.length){
      ctx.beginPath();
      for(let i=0;i<hold.length;i++){
        const x=w*i/(hold.length-1);
        const y=h*(.88-hold[i]*.72);
        if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
      }
      ctx.stroke();
    }

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    ctx.strokeStyle="#00e5ff";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<spec.length;i++){
      const x=w*i/(spec.length-1);
      const y=h*(.88-spec[i]*.72);
      if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();
    ctx.restore();

    ctx.strokeStyle="rgba(255,61,127,.40)";
    ctx.fillStyle="rgba(255,61,127,.07)";
    ctx.fillRect(w*.06,h*.16,w*.16,h*.65);
    ctx.fillRect(w*.78,h*.16,w*.16,h*.65);

    const markers = metrics.markers || [];
    markers.slice(0,5).forEach((m,idx)=>{
      const x=w*m.bin/(spec.length-1);
      const y=h*(.88-spec[m.bin]*.72);
      ctx.strokeStyle=idx===0?"#ffd84d":"#75ff5b";
      ctx.fillStyle=ctx.strokeStyle;
      ctx.beginPath(); ctx.moveTo(x,y-18*dpr); ctx.lineTo(x,y+18*dpr); ctx.stroke();
      label(ctx,dpr,m.id,x+5*dpr,y-7*dpr,ctx.fillStyle,10*dpr);
    });

    label(ctx,dpr,`REALITY VSA · ${String(metrics.profile||"").toUpperCase()} · CENTER ${metrics.centerMHz} MHz · SPAN ${metrics.spanMHz} MHz · RBW ${metrics.rbwKHz} kHz`,12*dpr,18*dpr,"#dffaff",10*dpr);
    label(ctx,dpr,`detector ${metrics.detector} · max hold ${metrics.maxHold ? "ON":"OFF"} · ACLR ${metrics.aclr} dB · OBW ${metrics.obw} MHz`,12*dpr,h-12*dpr,"#75ff5b",10*dpr);
  }

  function drawWaterfall(c,rows){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);
    const count=Math.min(rows.length,140);
    if(!count){ grid(ctx,w,h,dpr,false); return; }
    const cols=rows[0].length, rh=h/count, cw=w/cols;
    for(let y=0;y<count;y++){
      const row=rows[rows.length-1-y];
      for(let x=0;x<cols;x+=2){
        const v=row[x];
        const r=Math.floor(8+70*v);
        const g=Math.floor(30+220*v);
        const b=Math.floor(50+205*v);
        ctx.fillStyle=`rgba(${r},${g},${b},${.22+.75*v})`;
        ctx.fillRect(x*cw,y*rh,cw*2+1,rh+1);
      }
    }
    grid(ctx,w,h,dpr,false);
    label(ctx,dpr,"DENSE PERSISTENT WATERFALL · spectral memory",12*dpr,18*dpr,"#dffaff",10*dpr);
  }

  function drawConstellation(c,pts,metrics){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,false);
    if(!pts) return;
    const cx=w*.5, cy=h*.52, scale=Math.min(w,h)*.30;
    ctx.strokeStyle="rgba(0,229,255,.22)";
    ctx.beginPath();ctx.moveTo(cx,h*.10);ctx.lineTo(cx,h*.90);ctx.stroke();
    ctx.beginPath();ctx.moveTo(w*.10,cy);ctx.lineTo(w*.90,cy);ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<pts.length;i+=4){
      const x=cx+pts[i]*scale, y=cy+pts[i+1]*scale;
      const x0=cx+pts[i+2]*scale, y0=cy+pts[i+3]*scale;
      if(i%20===0){
        ctx.strokeStyle="rgba(255,61,127,.18)";
        ctx.beginPath();ctx.moveTo(x0,y0);ctx.lineTo(x,y);ctx.stroke();
      }
      ctx.fillStyle=i%16?"rgba(0,229,255,.11)":"rgba(117,255,91,.28)";
      ctx.beginPath();ctx.arc(x,y,1.8*dpr,0,TAU);ctx.fill();
    }
    ctx.restore();
    label(ctx,dpr,`I/Q CLOUD · EVM ${metrics.evm}% · phase/CFO synthetic`,12*dpr,18*dpr,"#dffaff",10*dpr);
  }

  function drawHop(c,bursts,metrics){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,false);
    const lanes=12;
    for(let l=0;l<lanes;l++){
      const y=h*(.14+l*.066);
      ctx.strokeStyle="rgba(0,229,255,.12)";
      ctx.beginPath();ctx.moveTo(w*.07,y);ctx.lineTo(w*.96,y);ctx.stroke();
      label(ctx,dpr,`H${String(l+1).padStart(2,"0")}`,8*dpr,y+3*dpr,"#8fb8c8",8*dpr);
    }
    if(bursts){
      for(let i=0;i<bursts.length;i+=5){
        const x=w*(.07+bursts[i]*.86);
        const lane=bursts[i+1], bw=w*bursts[i+2];
        const y=h*(.14+lane*.066)-6*dpr;
        const anomaly=bursts[i+4] > .5;
        ctx.fillStyle=anomaly?"rgba(255,61,127,.70)":bursts[i+3]>.72?"rgba(255,216,77,.55)":"rgba(0,229,255,.52)";
        ctx.fillRect(x,y,bw,12*dpr);
      }
    }
    label(ctx,dpr,`HOP INTELLIGENCE · occupancy ${metrics.occupancy}% · anomaly ${metrics.anomaly}`,12*dpr,18*dpr,"#dffaff",10*dpr);
  }

  class TrfmcRfProRealityV3 extends HTMLElement{
    connectedCallback(){
      this.rows=[];
      this.latest={spectrum:null,maxHold:null,constellation:null,bursts:null,metrics:{profile:"fhss",snr:31,evm:2.3,aclr:52.4,obw:12.6,occupancy:28,anomaly:.18,centerMHz:2440,spanMHz:80,rbwKHz:10,detector:"RMS",maxHold:true,markers:[]}};
      this.t0=performance.now();
      this.config={profile:"fhss",snr:31,spanMHz:80,rbwKHz:10,centerMHz:2440,detector:"RMS",maxHold:true};

      this.innerHTML=`
        <section class="r3-root">
          <div class="r3-cockpit">
            <aside class="r3-panel r3-left">
              <div class="r3-title">RF PRO V3 Reality Cockpit</div>
              <div class="r3-sub">Emitter scene, VSA, dense waterfall, I/Q cloud, hop intelligence, marker table and evidence chain. Synthetic/lab-only RF.</div>

              <div class="r3-kpis">
                <div class="r3-kpi"><small>Profile</small><b data-r3-kpi="profile">FHSS</b></div>
                <div class="r3-kpi"><small>SNR</small><b data-r3-kpi="snr">31 dB</b></div>
                <div class="r3-kpi"><small>EVM</small><b data-r3-kpi="evm">2.3%</b></div>
                <div class="r3-kpi"><small>OBW</small><b data-r3-kpi="obw">12.6 MHz</b></div>
                <div class="r3-kpi"><small>ACLR</small><b data-r3-kpi="aclr">52.4 dB</b></div>
                <div class="r3-kpi"><small>GPU</small><b data-r3-kpi="gpu">CHECK</b></div>
              </div>

              <div class="r3-card">
                <h3>Scenario controls</h3>
                <label class="r3-control"><span>Profile</span><select data-r3-control="profile">
                  <option value="fhss">FHSS emitter / hopset</option>
                  <option value="ofdm">OFDM occupied channel</option>
                  <option value="qpsk">QPSK narrowband</option>
                  <option value="burst">Agile burst emitter</option>
                  <option value="noise">Noise baseline</option>
                </select></label>
                <label class="r3-control"><span>SNR dB</span><input data-r3-control="snr" type="range" min="5" max="44" value="31"></label>
                <label class="r3-control"><span>Span MHz</span><input data-r3-control="spanMHz" type="range" min="10" max="160" value="80"></label>
                <label class="r3-control"><span>RBW kHz</span><input data-r3-control="rbwKHz" type="range" min="1" max="300" value="10"></label>
                <label class="r3-control"><span>Detector</span><select data-r3-control="detector"><option>RMS</option><option>PEAK</option><option>AVG</option></select></label>
              </div>

              <div class="r3-card">
                <h3>Instrument doctrine</h3>
                <p class="r3-sub">No SDR control, no third-party interception, no protected traffic decoding. V3 is an RF engineering, measurement and evidence-visualization cockpit for synthetic or lab-owned IQ.</p>
              </div>

              <div class="r3-card">
                <h3>Reality layers</h3>
                <span class="r3-pill">Emitter Scene</span><span class="r3-pill">VSA Markers</span><span class="r3-pill">Max Hold</span><span class="r3-pill">Dense Waterfall</span><span class="r3-pill">Error Vectors</span><span class="r3-pill">Hop Classifier</span><span class="r3-pill">Evidence Chain</span>
              </div>
            </aside>

            <main class="r3-panel r3-center">
              <div class="r3-card"><h3>RF Reality Scene</h3><canvas class="r3-canvas hero" data-r3-scope="scene"></canvas></div>
              <div class="r3-card"><h3>Reality Vector Spectrum Analyzer</h3><canvas class="r3-canvas vsa" data-r3-scope="vsa"></canvas></div>
              <div class="r3-card"><h3>Dense Persistent Waterfall</h3><canvas class="r3-canvas waterfall" data-r3-scope="waterfall"></canvas></div>
            </main>

            <aside class="r3-panel r3-right">
              <div class="r3-split">
                <div class="r3-card"><h3>I/Q Cloud + Error Vectors</h3><canvas class="r3-canvas" data-r3-scope="iq"></canvas></div>
                <div class="r3-card"><h3>FHSS Hop Intelligence</h3><canvas class="r3-canvas" data-r3-scope="hop"></canvas></div>
              </div>

              <div class="r3-card">
                <h3>Marker / Peak Table</h3>
                <table class="r3-table"><thead><tr><th>M</th><th>MHz</th><th>dBm</th><th>Δ</th></tr></thead><tbody data-r3-markers></tbody></table>
              </div>

              <div class="r3-card">
                <h3>Formula spine</h3>
                <div class="r3-formula formulaLive">FFT: X[k] = Σ x[n] · exp(-j2πkn/N)
RBW ≈ Fs/N · ENBW(window)
SNR = Psignal / Pnoise
EVM = RMS(error_vector) / RMS(reference_vector)
ACLR = Pchannel / Padjacent
OBW = ∫P(f) df inside occupied mask
Processing gain ≈ 10log10(Bspread/Bdata)
POI ≈ 1 - exp(-Tobs/Tdwell)</div>
              </div>

              <div class="r3-card">
                <h3>Visual evidence binding</h3>
                <trfmc-visual-asset kind="spectrum-scope" data-size="medium" title="Reality Spectrum"></trfmc-visual-asset>
              </div>
            </aside>
          </div>
        </section>
      `;

      this.bind();
      this.workerStart();
      this.renderStart();
      this.gpuCheck();
    }

    bind(){
      this.querySelectorAll("[data-r3-control]").forEach(el=>{
        el.addEventListener("input",()=>{
          const k=el.dataset.r3Control;
          let v=el.type==="range"?Number(el.value):el.value;
          this.config[k]=v;
          if(this.worker) this.worker.postMessage({type:"config",config:this.config});
        });
      });
    }

    workerStart(){
      try{
        this.worker=new Worker(WORKER_URL);
        this.worker.onmessage=(ev)=>{
          const m=ev.data||{};
          if(m.type==="frame"){
            this.latest=m;
            if(m.spectrum){
              this.rows.push(m.spectrum);
              if(this.rows.length>160) this.rows.shift();
            }
            this.kpis(m.metrics);
            this.markers(m.metrics);
          }
        };
        this.worker.postMessage({type:"config",config:this.config});
      }catch(e){ console.warn("RF PRO V3 worker unavailable",e); }
    }

    kpis(m){
      if(!m) return;
      const set=(k,v)=>{const el=this.querySelector(`[data-r3-kpi="${k}"]`); if(el) el.textContent=v;};
      set("profile",String(m.profile||"").toUpperCase());
      set("snr",`${m.snr} dB`);
      set("evm",`${m.evm}%`);
      set("obw",`${m.obw} MHz`);
      set("aclr",`${m.aclr} dB`);
    }

    markers(m){
      const body=this.querySelector("[data-r3-markers]");
      if(!body || !m || !m.markers) return;
      body.innerHTML=m.markers.slice(0,8).map((x,i)=>{
        const d=i===0?"REF":`${(x.dbm-(m.markers[0]?.dbm||x.dbm)).toFixed(1)} dB`;
        return `<tr><td>${x.id}</td><td>${x.mhz}</td><td>${x.dbm}</td><td>${d}</td></tr>`;
      }).join("");
    }

    gpuCheck(){
      const el=this.querySelector('[data-r3-kpi="gpu"]');
      if(el) el.textContent = navigator.gpu ? "WEBGPU" : "WEBGL2";
    }

    renderStart(){
      const loop=(now)=>{
        const m=this.latest.metrics||{};
        this.querySelectorAll("canvas[data-r3-scope]").forEach(c=>{
          const s=c.dataset.r3Scope;
          if(s==="scene") drawRealityScene(c,this.latest,m,now);
          else if(s==="vsa") drawVsa(c,this.latest.spectrum,this.latest.maxHold,m);
          else if(s==="waterfall") drawWaterfall(c,this.rows);
          else if(s==="iq") drawConstellation(c,this.latest.constellation,m);
          else if(s==="hop") drawHop(c,this.latest.bursts,m);
        });
        this.raf=requestAnimationFrame(loop);
      };
      this.raf=requestAnimationFrame(loop);
    }

    disconnectedCallback(){
      if(this.raf) cancelAnimationFrame(this.raf);
      if(this.worker) this.worker.terminate();
    }
  }

  if(!customElements.get("trfmc-rf-pro-reality-v3")){
    customElements.define("trfmc-rf-pro-reality-v3",TrfmcRfProRealityV3);
  }
})();
