#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V4_INSTRUMENT_$TS"
LATEST="$BASE/runtime/quality/latest_rf_pro_signal_intelligence_lab_v4_instrument"

V3="$BASE/runtime/quality/latest_rf_pro_signal_intelligence_lab_v3_reality"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

ASSET_DIR="$PUBLIC/assets/trfmc_rf_pro_signal_intelligence"
CSS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v4_instrument.css"
JS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v4_instrument.js"
WORKER_V3="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_worker_v3.js"

PAGE="$PUBLIC/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html"
MANIFEST="$PUBLIC/trfmc_rf_pro_signal_intelligence_manifest_v4_instrument.json"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC RF PRO SIGNAL INTELLIGENCE LAB V4 INSTRUMENT"
echo "True WebGL scene · instrument skin · no shell mutation"
echo "============================================================"

if [ ! -f "$V3/summary.json" ]; then
  echo "ERRORE: manca V3 PASS: $V3/summary.json"
  exit 10
fi

V3_RESULT="$(python3 - <<PY
import json
from pathlib import Path
print(json.loads(Path("$V3/summary.json").read_text()).get("result",""))
PY
)"

if [ "$V3_RESULT" != "PASS" ]; then
  echo "ERRORE: V3 non PASS: $V3_RESULT"
  exit 11
fi

echo
echo "[1/9] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V4_INSTRUMENT_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_rf_pro_signal_intelligence_lab_v3_reality 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

cp "$V3/rf_pro_rebuild_sources.tsv" "$OUT/rf_pro_rebuild_sources.tsv" 2>/dev/null || true
cp "$V3/source_v2_summary.json" "$OUT/source_v2_summary.json" 2>/dev/null || true

echo
echo "[2/9] Creo CSS V4 instrument-grade"

cat > "$CSS" <<'CSS'
:root{
  --i4-bg:#000307;
  --i4-panel:rgba(3,17,27,.78);
  --i4-panel2:rgba(2,9,16,.94);
  --i4-cyan:#00e5ff;
  --i4-green:#75ff5b;
  --i4-yellow:#ffd84d;
  --i4-red:#ff3d7f;
  --i4-text:#e8fbff;
  --i4-muted:#8fb8c8;
}

.i4-root{
  min-height:100vh;
  color:var(--i4-text);
  font-family:ui-monospace,Consolas,monospace;
  background:
    radial-gradient(circle at 72% 8%,rgba(0,229,255,.16),transparent 30%),
    radial-gradient(circle at 16% 85%,rgba(117,255,91,.06),transparent 26%),
    linear-gradient(150deg,#020812,#000307 62%,#000);
  overflow:hidden;
}

.i4-shell{
  display:grid;
  grid-template-columns:320px minmax(780px,1fr) 430px;
  gap:8px;
  padding:8px;
  min-height:calc(100vh - 76px);
  position:relative;
  z-index:1;
}

.i4-panel{
  position:relative;
  border:1px solid rgba(0,229,255,.24);
  border-radius:22px;
  background:
    linear-gradient(145deg,rgba(3,18,30,.82),rgba(1,5,10,.96)),
    radial-gradient(circle at 60% 0%,rgba(0,229,255,.12),transparent 34%);
  box-shadow:
    0 0 55px rgba(0,229,255,.12),
    inset 0 0 34px rgba(0,229,255,.055),
    0 28px 80px rgba(0,0,0,.62);
  backdrop-filter:blur(12px);
  padding:10px;
  overflow:hidden;
}

.i4-panel::before{
  content:"";
  position:absolute;
  inset:0;
  pointer-events:none;
  background:
    linear-gradient(90deg,rgba(255,255,255,.035),transparent 16%,transparent 84%,rgba(255,255,255,.025)),
    repeating-linear-gradient(0deg,rgba(255,255,255,.018) 0,rgba(255,255,255,.018) 1px,transparent 1px,transparent 5px);
  mix-blend-mode:screen;
  opacity:.45;
}

.i4-title{
  color:var(--i4-cyan);
  text-transform:uppercase;
  letter-spacing:.15em;
  font-size:15px;
  text-shadow:0 0 18px rgba(0,229,255,.55);
}

.i4-sub{
  color:var(--i4-muted);
  font-size:9.5px;
  line-height:1.45;
  margin-top:5px;
}

.i4-kpis{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:6px;
  margin-top:9px;
}

.i4-kpi{
  border:1px solid rgba(0,229,255,.22);
  background:rgba(0,229,255,.04);
  border-radius:13px;
  padding:7px;
  min-height:46px;
}

.i4-kpi small{
  display:block;
  color:var(--i4-muted);
  text-transform:uppercase;
  font-size:8px;
}

.i4-kpi b{
  display:block;
  color:var(--i4-green);
  font-size:16px;
  margin-top:2px;
}

.i4-card{
  position:relative;
  border:1px solid rgba(0,229,255,.18);
  border-radius:16px;
  background:rgba(0,229,255,.028);
  padding:8px;
  margin-top:8px;
  overflow:hidden;
}

.i4-card h3{
  color:var(--i4-yellow);
  font-size:10.5px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin:0 0 6px 0;
}

.i4-control{
  display:grid;
  grid-template-columns:88px 1fr;
  gap:6px;
  align-items:center;
  margin:6px 0;
  color:var(--i4-muted);
  font-size:9px;
}

.i4-control select,
.i4-control input{
  width:100%;
  background:#01060b;
  color:var(--i4-text);
  border:1px solid rgba(0,229,255,.28);
  border-radius:8px;
  padding:5px;
  font-family:inherit;
  font-size:9px;
}

.i4-main{
  display:grid;
  grid-template-rows:480px 300px 1fr;
  gap:8px;
}

.i4-canvas{
  display:block;
  width:100%;
  height:100%;
  background:#000307;
  border:1px solid rgba(0,229,255,.18);
  border-radius:16px;
}

.i4-row{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:8px;
}

.i4-side-grid{
  display:grid;
  grid-template-rows:230px 230px 230px auto;
  gap:8px;
}

.i4-meter{
  height:10px;
  border:1px solid rgba(0,229,255,.20);
  border-radius:999px;
  background:#020812;
  overflow:hidden;
  margin:5px 0;
}

.i4-meter span{
  display:block;
  height:100%;
  width:50%;
  background:linear-gradient(90deg,var(--i4-cyan),var(--i4-green));
  box-shadow:0 0 14px rgba(0,229,255,.55);
}

.i4-table{
  width:100%;
  border-collapse:collapse;
  font-size:9px;
}

.i4-table th,
.i4-table td{
  border-bottom:1px solid rgba(0,229,255,.14);
  padding:4px;
  text-align:left;
}

.i4-table th{
  color:var(--i4-cyan);
  background:rgba(0,229,255,.045);
}

.i4-pill{
  display:inline-block;
  color:var(--i4-green);
  border:1px solid rgba(117,255,91,.35);
  background:rgba(117,255,91,.07);
  border-radius:8px;
  padding:2px 6px;
  margin:2px 3px 2px 0;
  font-size:8.5px;
}

.i4-formula{
  white-space:pre-wrap;
  font-size:9px;
  line-height:1.5;
  color:var(--i4-text);
}

.i4-footer{
  margin:8px;
  position:relative;
  z-index:1;
  border:1px solid rgba(0,229,255,.22);
  border-radius:16px;
  background:rgba(0,229,255,.025);
  padding:8px;
}

@media(max-width:1650px){
  .i4-shell{grid-template-columns:310px 1fr}
  .i4-right{grid-column:1 / -1}
  .i4-side-grid{grid-template-columns:repeat(2,1fr);grid-template-rows:auto}
}
@media(max-width:1100px){
  .i4-shell{grid-template-columns:1fr}
  .i4-row,.i4-side-grid{grid-template-columns:1fr}
}
CSS

echo
echo "[3/9] Creo JS V4 con vera scena WebGL"

cat > "$JS" <<'JS'
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
JS

echo
echo "[4/9] Creo pagina V4 + manifest"

python3 - "$OUT" "$PAGE" "$MANIFEST" <<'PY'
import json, html, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
page = Path(sys.argv[2])
manifest = Path(sys.argv[3])

src_rows = ""
src_tsv = out / "rf_pro_rebuild_sources.tsv"
if src_tsv.exists():
    for line in src_tsv.read_text(errors="ignore").splitlines()[1:]:
        p = line.split("\t")
        if len(p) >= 8:
            src_rows += f"<tr><td><a href='{html.escape(p[0])}'>{html.escape(p[0])}</a></td><td>{html.escape(p[1])}</td><td>{html.escape(p[3])}</td><td>{html.escape(p[4])}</td><td>{html.escape(p[5][:16])}…</td></tr>"

manifest_data = {
    "id": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V4_INSTRUMENT",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html",
    "mode": "synthetic_lab_only_true_webgl_instrument_cockpit",
    "architecture": {
        "web_component": "trfmc-rf-pro-instrument-v4",
        "worker": "/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v3.js",
        "renderer": "true_webgl_scene_plus_canvas_2d_measurement_surfaces",
        "mutation_policy": "new leaf only; V3, V2, orphan files, V6R3 and Control Room unchanged"
    },
    "capabilities": [
        "true_webgl_rf_scene",
        "instrument_skin",
        "vsa_marker_table",
        "dense_waterfall",
        "iq_error_vectors",
        "fhss_hop_map",
        "formula_spine",
        "visual_evidence_binding"
    ],
    "policy": "V4 is an instrument-grade leaf. No shell mutation."
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

page.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC RF PRO Signal Intelligence Lab V4 Instrument</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<link rel="stylesheet" href="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v4_instrument.css">
<style>
.i4-source-table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:9px}}
.i4-source-table th,.i4-source-table td{{border-bottom:1px solid rgba(0,229,255,.16);padding:5px;text-align:left}}
.i4-source-table th{{color:#00e5ff;background:rgba(0,229,255,.05)}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC RF PRO Signal Intelligence Lab V4 Instrument</div>
    <div class="leaf-sub">True WebGL RF scene · instrument skin · VSA · dense waterfall · I/Q · FHSS · synthetic/lab-only</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html">V3 Reality</a>
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_lab_v2.html">V2 Engine</a>
    <a class="leaf-btn" href="/trfmc_post_promotion_control_center_v1.html">Governance</a>
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_manifest_v4_instrument.json">Manifest</a>
  </div>
</header>

<trfmc-rf-pro-instrument-v4></trfmc-rf-pro-instrument-v4>

<section class="i4-footer">
<h2 style="color:#00e5ff;font-size:12px;text-transform:uppercase;letter-spacing:.10em">Read-only source evidence</h2>
<table class="i4-source-table">
<thead><tr><th>Source orphan</th><th>Exists</th><th>Words</th><th>RF keywords</th><th>SHA256</th></tr></thead>
<tbody>{src_rows}</tbody>
</table>
</section>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
<script src="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v4_instrument.js"></script>
</body>
</html>
''', encoding="utf-8")

print(json.dumps(manifest_data, indent=2, ensure_ascii=False))
PY

echo
echo "[5/9] Registro V4 nel registry"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

target = public / "trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html"] = {
    "class": "leaf_operational_candidate",
    "name": "trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html",
    "url": "/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html",
    "size": target.stat().st_size,
    "domain": "rf",
    "premium_leaf": True,
    "instrument_grade": True,
    "true_webgl_scene": True,
    "rf_pro_rebuild": True,
    "canvas": True,
    "web_component": True,
    "web_worker": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "RF PRO Signal Intelligence Lab V4 Instrument"
}

reg["pages"] = list(by_url.values())

counts = {}
for p in reg["pages"]:
    c = p.get("class", "unknown")
    counts[c] = counts.get(c, 0) + 1

counts["total_html"] = len([p for p in reg["pages"] if str(p.get("url","")).endswith(".html")])
for k in ["official_shell", "service", "leaf_operational_candidate", "shell_or_legacy_container", "orphan_or_legacy_candidate"]:
    counts.setdefault(k, 0)

reg["counts"] = counts
reg["last_rf_pro_signal_intelligence_lab_v4_instrument_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html",
    "policy": "New V4 leaf only. V3/V2/orphans/V6R3/Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[6/9] HTTP + external/iframe/content gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html \
    /trfmc_rf_pro_signal_intelligence_manifest_v4_instrument.json \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v4_instrument.css \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v4_instrument.js \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v3.js \
    /trfmc_rf_pro_signal_intelligence_lab_v3_reality.html \
    /trfmc_portal_registry_unified.json \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/content_checks.txt"

for f in "$PAGE" "$MANIFEST" "$CSS" "$JS"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC RF PRO Signal Intelligence Lab V4 Instrument" \
  "trfmc-rf-pro-instrument-v4" \
  "True WebGL RF scene" \
  "getContext(\"webgl\"" \
  "DSP worker" \
  "Reality Vector Spectrum Analyzer" \
  "Dense Persistent Waterfall" \
  "FHSS Hop Intelligence" \
  "I/Q Cloud" \
  "Formula Spine" \
  "requestAnimationFrame" \
  "synthetic_lab_only_true_webgl_instrument_cockpit" \
  "trfmc-visual-asset"
do
  if grep -Rqs "$token" "$PAGE" "$MANIFEST" "$CSS" "$JS"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

echo
echo "[7/9] Summary"

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

python3 - "$OUT" "$REG" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

http = []
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 3:
        http.append({"url": p[0], "status": p[1], "bytes": p[2]})

non200 = sum(1 for r in http if r["status"] != "200")
ext = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
ifr = sum(1 for x in (out / "iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
miss = sum(1 for x in (out / "content_checks.txt").read_text(errors="ignore").splitlines() if x.startswith("MISS:"))

sha = {}
for line in (out / "sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        sha[k] = v

protected_ok = (
    sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
)
registry_changed = sha.get("REG_SHA_BEFORE") != sha.get("REG_SHA_AFTER")
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V4_INSTRUMENT",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "content_check_miss": miss,
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "new_leaf": "/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html",
    "architecture": "web_component + v3_dsp_worker + true_webgl_scene + canvas_measurement_surfaces",
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and miss == 0 and protected_ok and registry_changed else "WARN",
    "policy": "V4 instrument-grade RF PRO leaf. V3, V2, orphan files, V6R3 and Control Room unchanged."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[8/9] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V4_INSTRUMENT_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html \
    frontend/public/trfmc_rf_pro_signal_intelligence_manifest_v4_instrument.json \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v4_instrument.css \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v4_instrument.js \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_rf_pro_signal_intelligence_lab_v4_instrument \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "[9/9] Output"

echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== CONTENT CHECKS ==="
cat "$OUT/content_checks.txt"
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html"
echo "============================================================"
