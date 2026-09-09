(function(){
  "use strict";

  const WORKER_URL="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v3.js";
  const TAU=Math.PI*2;

  function fit(c){
    const dpr=Math.min(2,window.devicePixelRatio||1);
    const w=Math.max(2,Math.floor(c.clientWidth*dpr));
    const h=Math.max(2,Math.floor(c.clientHeight*dpr));
    if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
    return {ctx:c.getContext("2d"),w,h,dpr};
  }

  function bg(ctx,w,h){
    const g=ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");g.addColorStop(.55,"#020812");g.addColorStop(1,"#000307");
    ctx.fillStyle=g;ctx.fillRect(0,0,w,h);
  }

  function grid(ctx,w,h,dpr,a){
    ctx.lineWidth=1*dpr;
    ctx.strokeStyle=`rgba(0,229,255,${a||.09})`;
    for(let i=0;i<13;i++){let x=w*i/12;ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let i=0;i<9;i++){let y=h*i/8;ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
  }

  function label(ctx,dpr,s,x,y,color,size){
    ctx.fillStyle=color||"#8fb8c8";
    ctx.font=`${size||10*dpr}px ui-monospace,Consolas,monospace`;
    ctx.fillText(s,x,y);
  }

  function drawVsa(c,spec,hold,m){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);grid(ctx,w,h,dpr,.13);
    if(!spec)return;

    ctx.fillStyle="rgba(255,61,127,.07)";
    ctx.fillRect(w*.07,h*.16,w*.15,h*.66);
    ctx.fillRect(w*.78,h*.16,w*.15,h*.66);

    if(hold&&hold.length){
      ctx.strokeStyle="rgba(255,216,77,.50)";
      ctx.lineWidth=1*dpr;
      ctx.beginPath();
      for(let i=0;i<hold.length;i++){
        const x=w*i/(hold.length-1), y=h*(.88-hold[i]*.72);
        if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
      }
      ctx.stroke();
    }

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    ctx.strokeStyle="#00e5ff";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<spec.length;i++){
      const x=w*i/(spec.length-1), y=h*(.88-spec[i]*.72);
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
    ctx.restore();

    (m.markers||[]).slice(0,6).forEach((mk,i)=>{
      const x=w*mk.bin/(spec.length-1), y=h*(.88-spec[mk.bin]*.72);
      ctx.strokeStyle=i===0?"#ffd84d":"#75ff5b";
      ctx.fillStyle=ctx.strokeStyle;
      ctx.beginPath();ctx.moveTo(x,y-18*dpr);ctx.lineTo(x,y+18*dpr);ctx.stroke();
      label(ctx,dpr,mk.id,x+5*dpr,y-7*dpr,ctx.fillStyle,9*dpr);
    });

    label(ctx,dpr,`VSA REALITY · ${String(m.profile||"").toUpperCase()} · CF ${m.centerMHz} MHz · SPAN ${m.spanMHz} MHz · RBW ${m.rbwKHz} kHz`,12*dpr,18*dpr,"#e8fbff",10*dpr);
    label(ctx,dpr,`det ${m.detector} · max hold ${m.maxHold?"ON":"OFF"} · ACLR ${m.aclr} dB · OBW ${m.obw} MHz`,12*dpr,h-12*dpr,"#75ff5b",9*dpr);
  }

  function drawWaterfall(c,rows){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);
    const count=Math.min(rows.length,160);
    if(count){
      const cols=rows[0].length,rh=h/count,cw=w/cols;
      for(let y=0;y<count;y++){
        const row=rows[rows.length-1-y];
        for(let x=0;x<cols;x+=2){
          const v=row[x];
          const r=Math.floor(5+80*v),g=Math.floor(25+230*v),b=Math.floor(45+210*v);
          ctx.fillStyle=`rgba(${r},${g},${b},${.20+.78*v})`;
          ctx.fillRect(x*cw,y*rh,cw*2+1,rh+1);
        }
      }
    }
    grid(ctx,w,h,dpr,.07);
    label(ctx,dpr,"DENSE RF WATERFALL · persistence texture · burst memory",10*dpr,18*dpr,"#e8fbff",9*dpr);
  }

  function drawIQ(c,pts,m){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);grid(ctx,w,h,dpr,.08);
    if(!pts)return;
    const cx=w*.5,cy=h*.53,scale=Math.min(w,h)*.30;
    ctx.strokeStyle="rgba(0,229,255,.23)";
    ctx.beginPath();ctx.moveTo(cx,h*.10);ctx.lineTo(cx,h*.90);ctx.stroke();
    ctx.beginPath();ctx.moveTo(w*.10,cy);ctx.lineTo(w*.90,cy);ctx.stroke();

    ctx.save();ctx.globalCompositeOperation="lighter";
    for(let i=0;i<pts.length;i+=4){
      const x=cx+pts[i]*scale,y=cy+pts[i+1]*scale,x0=cx+pts[i+2]*scale,y0=cy+pts[i+3]*scale;
      if(i%24===0){ctx.strokeStyle="rgba(255,61,127,.16)";ctx.beginPath();ctx.moveTo(x0,y0);ctx.lineTo(x,y);ctx.stroke();}
      ctx.fillStyle=i%20?"rgba(0,229,255,.12)":"rgba(117,255,91,.25)";
      ctx.beginPath();ctx.arc(x,y,1.55*dpr,0,TAU);ctx.fill();
    }
    ctx.restore();
    label(ctx,dpr,`I/Q CLOUD · EVM ${m.evm}%`,10*dpr,18*dpr,"#e8fbff",9*dpr);
  }

  function drawHop(c,bursts,m){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);grid(ctx,w,h,dpr,.07);
    const lanes=12;
    for(let l=0;l<lanes;l++){
      const y=h*(.14+l*.064);
      ctx.strokeStyle="rgba(0,229,255,.12)";
      ctx.beginPath();ctx.moveTo(w*.08,y);ctx.lineTo(w*.96,y);ctx.stroke();
      label(ctx,dpr,`H${String(l+1).padStart(2,"0")}`,8*dpr,y+2*dpr,"#8fb8c8",8*dpr);
    }
    if(bursts){
      for(let i=0;i<bursts.length;i+=5){
        const x=w*(.08+bursts[i]*.86),lane=bursts[i+1],bw=w*bursts[i+2];
        const y=h*(.14+lane*.064)-5*dpr,anom=bursts[i+4]>.5;
        ctx.fillStyle=anom?"rgba(255,61,127,.72)":bursts[i+3]>.72?"rgba(255,216,77,.55)":"rgba(0,229,255,.50)";
        ctx.fillRect(x,y,bw,10*dpr);
      }
    }
    label(ctx,dpr,`HOP INTELLIGENCE · anomaly ${m.anomaly}`,10*dpr,18*dpr,"#e8fbff",9*dpr);
  }

  function initWebGLScene(canvas){
    const gl=canvas.getContext("webgl",{alpha:true,antialias:true});
    if(!gl)return null;

    const vs=`attribute vec2 p;varying vec2 uv;void main(){uv=p*.5+.5;gl_Position=vec4(p,0.,1.);}`;
    const fs=`precision mediump float;varying vec2 uv;uniform float t;uniform float snr;uniform float anomaly;
    float beam(vec2 p,float y,float w){return exp(-abs(p.y-y)*w)*smoothstep(.08,.72,p.x)*(1.0-smoothstep(.82,1.0,p.x));}
    void main(){
      vec2 p=uv;
      vec3 bg=mix(vec3(.005,.018,.03),vec3(.0,.055,.075),p.y);
      float grid=(step(.985,fract(p.x*18.))+step(.985,fract(p.y*10.)))*.08;
      float b=beam(p,.52+.035*sin(p.x*9.+t*.001),30.)*.75;
      float b2=beam(p,.47+.025*sin(p.x*13.-t*.0013),45.)*.35;
      float glow=exp(-distance(p,vec2(.78,.48))*8.)*.55;
      float dish=1.-smoothstep(.09,.095,abs(distance(p,vec2(.25,.54))-.11));
      float mast=smoothstep(.018,.0,abs(p.x-.16))*smoothstep(.18,.22,p.y)*smoothstep(.88,.82,p.y);
      vec3 col=bg+grid*vec3(0.,.7,1.)+(b+b2)*vec3(0.,.85,1.)+glow*vec3(1.,.8,.15)+dish*vec3(.7,.95,1.)+mast*vec3(.55,.75,.78);
      col += anomaly*.10*vec3(1.,0.,.35);
      gl_FragColor=vec4(col,1.);
    }`;

    function shader(type,src){
      const s=gl.createShader(type);gl.shaderSource(s,src);gl.compileShader(s);
      return s;
    }
    const pr=gl.createProgram();
    gl.attachShader(pr,shader(gl.VERTEX_SHADER,vs));
    gl.attachShader(pr,shader(gl.FRAGMENT_SHADER,fs));
    gl.linkProgram(pr);

    const buf=gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER,buf);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);

    const loc=gl.getAttribLocation(pr,"p");
    const tLoc=gl.getUniformLocation(pr,"t");
    const snrLoc=gl.getUniformLocation(pr,"snr");
    const anLoc=gl.getUniformLocation(pr,"anomaly");

    return {
      render(now,m){
        const dpr=Math.min(2,window.devicePixelRatio||1);
        const w=Math.max(2,Math.floor(canvas.clientWidth*dpr)),h=Math.max(2,Math.floor(canvas.clientHeight*dpr));
        if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
        gl.viewport(0,0,canvas.width,canvas.height);
        gl.useProgram(pr);
        gl.bindBuffer(gl.ARRAY_BUFFER,buf);
        gl.enableVertexAttribArray(loc);
        gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);
        gl.uniform1f(tLoc,now);
        gl.uniform1f(snrLoc,m.snr||30);
        gl.uniform1f(anLoc,m.anomaly||0);
        gl.drawArrays(gl.TRIANGLES,0,6);
      }
    };
  }

  class TrfmcRfProInstrumentV4 extends HTMLElement{
    connectedCallback(){
      this.rows=[];
      this.latest={spectrum:null,maxHold:null,constellation:null,bursts:null,metrics:{profile:"fhss",snr:31,evm:2.3,obw:12.6,aclr:52.4,anomaly:.18,occupancy:32,centerMHz:2440,spanMHz:80,rbwKHz:10,detector:"RMS",maxHold:true,markers:[]}};
      this.config={profile:"fhss",snr:31,spanMHz:80,rbwKHz:10,centerMHz:2440,detector:"RMS",maxHold:true};

      this.innerHTML=`
      <section class="i4-root">
        <div class="i4-shell">
          <aside class="i4-panel">
            <div class="i4-title">RF PRO V4 Instrument</div>
            <div class="i4-sub">True WebGL RF scene + DSP worker + dense measurement cockpit. Synthetic/lab-only.</div>
            <div class="i4-kpis">
              <div class="i4-kpi"><small>Profile</small><b data-i4-kpi="profile">FHSS</b></div>
              <div class="i4-kpi"><small>SNR</small><b data-i4-kpi="snr">31 dB</b></div>
              <div class="i4-kpi"><small>EVM</small><b data-i4-kpi="evm">2.3%</b></div>
              <div class="i4-kpi"><small>OBW</small><b data-i4-kpi="obw">12.6 MHz</b></div>
              <div class="i4-kpi"><small>ACLR</small><b data-i4-kpi="aclr">52.4 dB</b></div>
              <div class="i4-kpi"><small>Renderer</small><b data-i4-kpi="renderer">WEBGL</b></div>
            </div>
            <div class="i4-card">
              <h3>Instrument controls</h3>
              <label class="i4-control"><span>Profile</span><select data-i4-control="profile"><option value="fhss">FHSS emitter</option><option value="ofdm">OFDM channel</option><option value="qpsk">QPSK narrow</option><option value="burst">Agile burst</option><option value="noise">Noise floor</option></select></label>
              <label class="i4-control"><span>SNR</span><input data-i4-control="snr" type="range" min="5" max="44" value="31"></label>
              <label class="i4-control"><span>Span</span><input data-i4-control="spanMHz" type="range" min="10" max="160" value="80"></label>
              <label class="i4-control"><span>RBW</span><input data-i4-control="rbwKHz" type="range" min="1" max="300" value="10"></label>
              <label class="i4-control"><span>Detector</span><select data-i4-control="detector"><option>RMS</option><option>PEAK</option><option>AVG</option></select></label>
            </div>
            <div class="i4-card">
              <h3>Reality judgement</h3>
              <div class="i4-meter"><span data-meter="occ"></span></div>
              <div class="i4-sub">Occupancy / anomaly / evidence indicators are synthetic but rendered as instrument telemetry.</div>
            </div>
            <div class="i4-card">
              <h3>Lab-only policy</h3>
              <div class="i4-sub">No SDR control. No interception. No third-party traffic. Measurement cockpit for synthetic/lab-owned IQ only.</div>
            </div>
            <div class="i4-card">
              <h3>Layers</h3>
              <span class="i4-pill">WebGL Scene</span><span class="i4-pill">DSP Worker</span><span class="i4-pill">VSA</span><span class="i4-pill">Waterfall</span><span class="i4-pill">I/Q</span><span class="i4-pill">Hop Map</span>
            </div>
          </aside>

          <main class="i4-panel i4-main">
            <div class="i4-card" style="height:100%;margin-top:0"><h3>WebGL RF Reality Chamber</h3><canvas class="i4-canvas" data-i4-scope="gl"></canvas></div>
            <div class="i4-card" style="height:100%"><h3>Reality Vector Spectrum Analyzer</h3><canvas class="i4-canvas" data-i4-scope="vsa"></canvas></div>
            <div class="i4-row">
              <div class="i4-card"><h3>Dense Persistent Waterfall</h3><canvas class="i4-canvas" data-i4-scope="waterfall"></canvas></div>
              <div class="i4-card"><h3>FHSS Hop Intelligence</h3><canvas class="i4-canvas" data-i4-scope="hop"></canvas></div>
            </div>
          </main>

          <aside class="i4-panel i4-right">
            <div class="i4-side-grid">
              <div class="i4-card"><h3>I/Q Cloud + Error Vectors</h3><canvas class="i4-canvas" data-i4-scope="iq"></canvas></div>
              <div class="i4-card"><h3>Peak / Marker Table</h3><table class="i4-table"><thead><tr><th>M</th><th>MHz</th><th>dBm</th><th>Δ</th></tr></thead><tbody data-i4-markers></tbody></table></div>
              <div class="i4-card"><h3>Formula Spine</h3><div class="i4-formula formulaLive">FFT: X[k] = Σ x[n]·e^(-j2πkn/N)
RBW ≈ Fs/N · ENBW
SNR = Psignal / Pnoise
EVM = RMS(error) / RMS(ref)
ACLR = Pch / Padj
OBW = ∫P(f)df
Processing gain ≈ 10log10(Bspread/Bdata)
POI ≈ 1-exp(-Tobs/Tdwell)</div></div>
              <div class="i4-card"><h3>Visual Evidence Binding</h3><trfmc-visual-asset kind="spectrum-scope" data-size="medium" title="V4 Instrument Spectrum"></trfmc-visual-asset></div>
            </div>
          </aside>
        </div>
      </section>`;

      this.bind();
      this.startWorker();
      this.startRender();
    }

    bind(){
      this.querySelectorAll("[data-i4-control]").forEach(el=>{
        el.addEventListener("input",()=>{
          const k=el.dataset.i4Control;
          const v=el.type==="range"?Number(el.value):el.value;
          this.config[k]=v;
          if(this.worker)this.worker.postMessage({type:"config",config:this.config});
        });
      });
    }

    startWorker(){
      this.worker=new Worker(WORKER_URL);
      this.worker.onmessage=(ev)=>{
        const m=ev.data||{};
        if(m.type==="frame"){
          this.latest=m;
          if(m.spectrum){this.rows.push(m.spectrum);if(this.rows.length>180)this.rows.shift();}
          this.updateKpi(m.metrics);
          this.updateMarkers(m.metrics);
        }
      };
      this.worker.postMessage({type:"config",config:this.config});
    }

    updateKpi(m){
      if(!m)return;
      const set=(k,v)=>{const e=this.querySelector(`[data-i4-kpi="${k}"]`);if(e)e.textContent=v;};
      set("profile",String(m.profile||"").toUpperCase());
      set("snr",`${m.snr} dB`);
      set("evm",`${m.evm}%`);
      set("obw",`${m.obw} MHz`);
      set("aclr",`${m.aclr} dB`);
      const occ=this.querySelector('[data-meter="occ"]'); if(occ) occ.style.width=`${Math.max(8,Math.min(100,m.occupancy||30))}%`;
    }

    updateMarkers(m){
      const b=this.querySelector("[data-i4-markers]");
      if(!b||!m||!m.markers)return;
      b.innerHTML=m.markers.slice(0,8).map((x,i)=>{
        const d=i===0?"REF":`${(x.dbm-(m.markers[0]?.dbm||x.dbm)).toFixed(1)} dB`;
        return `<tr><td>${x.id}</td><td>${x.mhz}</td><td>${x.dbm}</td><td>${d}</td></tr>`;
      }).join("");
    }

    startRender(){
      const glCanvas=this.querySelector('[data-i4-scope="gl"]');
      const glScene=initWebGLScene(glCanvas);
      const r=this.querySelector('[data-i4-kpi="renderer"]');
      if(r) r.textContent=glScene?"WEBGL":"2D";

      const loop=(now)=>{
        const m=this.latest.metrics||{};
        if(glScene) glScene.render(now,m);
        this.querySelectorAll("canvas[data-i4-scope]").forEach(c=>{
          const s=c.dataset.i4Scope;
          if(s==="vsa")drawVsa(c,this.latest.spectrum,this.latest.maxHold,m);
          else if(s==="waterfall")drawWaterfall(c,this.rows);
          else if(s==="iq")drawIQ(c,this.latest.constellation,m);
          else if(s==="hop")drawHop(c,this.latest.bursts,m);
        });
        this.raf=requestAnimationFrame(loop);
      };
      this.raf=requestAnimationFrame(loop);
    }

    disconnectedCallback(){
      if(this.raf)cancelAnimationFrame(this.raf);
      if(this.worker)this.worker.terminate();
    }
  }

  if(!customElements.get("trfmc-rf-pro-instrument-v4")){
    customElements.define("trfmc-rf-pro-instrument-v4",TrfmcRfProInstrumentV4);
  }
})();
