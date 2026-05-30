#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V3_REALITY_$TS"
LATEST="$BASE/runtime/quality/latest_rf_pro_signal_intelligence_lab_v3_reality"

V2="$BASE/runtime/quality/latest_rf_pro_signal_intelligence_lab_v2"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

ASSET_DIR="$PUBLIC/assets/trfmc_rf_pro_signal_intelligence"
CSS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v3_reality.css"
JS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v3_reality.js"
WORKER="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_worker_v3.js"
SHADERS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_shaders_v3.js"

PAGE="$PUBLIC/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html"
MANIFEST="$PUBLIC/trfmc_rf_pro_signal_intelligence_manifest_v3_reality.json"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC RF PRO SIGNAL INTELLIGENCE LAB V3 REALITY"
echo "Reality cockpit · instrument-grade visual language · no shell mutation"
echo "============================================================"

if [ ! -f "$V2/summary.json" ]; then
  echo "ERRORE: manca V2 PASS: $V2/summary.json"
  exit 10
fi

V2_RESULT="$(python3 - <<PY
import json
from pathlib import Path
print(json.loads(Path("$V2/summary.json").read_text()).get("result",""))
PY
)"

if [ "$V2_RESULT" != "PASS" ]; then
  echo "ERRORE: V2 non PASS: $V2_RESULT"
  exit 11
fi

echo
echo "[1/10] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V3_REALITY_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_rf_pro_signal_intelligence_lab_v2 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/10] Copio evidence V2"

cp "$V2/rf_pro_rebuild_sources.tsv" "$OUT/rf_pro_rebuild_sources.tsv" 2>/dev/null || true
cp "$V2/rf_pro_rebuild_sources.json" "$OUT/rf_pro_rebuild_sources.json" 2>/dev/null || true
cp "$V2/summary.json" "$OUT/source_v2_summary.json" 2>/dev/null || true

python3 - "$V2" "$OUT" <<'PY'
import json
from pathlib import Path
import sys

v2 = Path(sys.argv[1])
out = Path(sys.argv[2])
s = json.loads((v2 / "summary.json").read_text(errors="ignore"))

policy = {
    "source": "RF PRO V2 PASS",
    "v2_result": s.get("result"),
    "v3_mode": "reality_instrument_cockpit",
    "mutation_policy": "V3 creates new leaf and local assets only. V2, V6R3, Control Room and orphan files remain unchanged.",
    "expected": {
        "visual_language": "real RF/Telco instrument cockpit",
        "instrument_blocks": ["VSA", "waterfall", "constellation", "FHSS intelligence", "RF scene", "evidence chain"],
        "no_cdn": True,
        "no_iframe": True
    }
}
(out / "rf_pro_v3_reality_policy.json").write_text(json.dumps(policy, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(policy, indent=2, ensure_ascii=False))
PY

echo
echo "[3/10] Creo worker V3: RF scenario telemetry"

cat > "$WORKER" <<'JS'
"use strict";

/*
 TRFMC RF PRO V3 Reality Worker
 Synthetic/lab-only RF telemetry.
 No network. No SDR control. No interception.
*/

let state = {
  running: true,
  profile: "fhss",
  snr: 31,
  spanMHz: 80,
  rbwKHz: 10,
  centerMHz: 2440,
  detector: "RMS",
  maxHold: true,
  tick: 0
};

const hopSeq = [0.08,0.19,0.32,0.47,0.61,0.76,0.88,0.54,0.27,0.69,0.41,0.13];

function clamp(x,a,b){ return Math.max(a, Math.min(b, x)); }
function gauss(x,mu,s){ const z=(x-mu)/s; return Math.exp(-0.5*z*z); }

function makeSpectrum(n,t){
  const arr = new Float32Array(n);
  const floor = -112, ceil = -18;

  for(let i=0;i<n;i++){
    const f=i/(n-1);
    let p = -96 + 1.4*Math.sin(i*.011+t*.4) + 1.2*Math.sin(i*.047+t*.9);

    if(state.profile === "fhss"){
      for(let k=0;k<6;k++){
        const c = hopSeq[(Math.floor(t*2.4)+k*2)%hopSeq.length];
        p += 33*gauss(f,c,0.0065+k*.0007);
      }
      p += 10*gauss(f,.50,.14);
    } else if(state.profile === "ofdm"){
      p += 35*gauss(f,.50,.105);
      p += 9*gauss(f,.37,.010);
      p += 9*gauss(f,.63,.010);
      p -= 7*(gauss(f,.28,.018)+gauss(f,.72,.018));
    } else if(state.profile === "qpsk"){
      p += 35*gauss(f,.50,.032);
      p += 8*gauss(f,.43,.009);
      p += 8*gauss(f,.57,.009);
    } else if(state.profile === "burst"){
      const c=.12+.76*Math.abs(Math.sin(t*.27));
      p += 42*gauss(f,c,.010);
      p += 19*gauss(f,(c+.21)%1,.006);
    } else {
      p += 8*gauss(f,.5,.25);
    }

    arr[i]=clamp((p-floor)/(ceil-floor),0,1);
  }
  return arr;
}

function makeMaxHold(spec, prev){
  if(!prev || prev.length !== spec.length) return spec.slice();
  const out = new Float32Array(spec.length);
  for(let i=0;i<spec.length;i++) out[i] = Math.max(prev[i]*0.992, spec[i]);
  return out;
}

let maxHoldBuf = null;

function makeConstellation(points,t){
  const out = new Float32Array(points*4);
  const isQam = state.profile === "ofdm";
  const grid = isQam ? [-3,-1,1,3] : [-1,1];
  const norm = isQam ? 3 : 1;
  const jitter = Math.max(.012,(42-state.snr)/220);
  const rot = 0.20*Math.sin(t*.3);

  for(let i=0;i<points;i++){
    const sx = grid[(i + Math.floor(t*5)) % grid.length] / norm;
    const sy = grid[(Math.floor(i/grid.length)+Math.floor(t*4)) % grid.length] / norm;
    const ex = jitter*Math.sin(i*.71+t*2.0);
    const ey = jitter*Math.cos(i*.53+t*1.6);

    const x0 = sx, y0 = sy;
    const x = (sx+ex)*Math.cos(rot) - (sy+ey)*Math.sin(rot);
    const y = (sx+ex)*Math.sin(rot) + (sy+ey)*Math.cos(rot);

    out[i*4] = x;
    out[i*4+1] = y;
    out[i*4+2] = x0;
    out[i*4+3] = y0;
  }
  return out;
}

function makeBursts(count,t){
  const out = new Float32Array(count*5);
  for(let i=0;i<count;i++){
    const lane = (i*5 + Math.floor(t*2.1)) % 12;
    const x = (i*.053 + t*.044) % 1;
    const width = .012 + (i%6)*.006;
    const amp = .38 + .58*((i%9)/8);
    const anomaly = ((i + Math.floor(t*1.3)) % 17) === 0 ? 1 : 0;
    out[i*5] = x;
    out[i*5+1] = lane;
    out[i*5+2] = width;
    out[i*5+3] = amp;
    out[i*5+4] = anomaly;
  }
  return out;
}

function peaks(spec){
  const candidates=[];
  for(let i=2;i<spec.length-2;i++){
    if(spec[i] > spec[i-1] && spec[i] > spec[i+1] && spec[i] > .43){
      candidates.push({bin:i, amp:spec[i]});
    }
  }
  candidates.sort((a,b)=>b.amp-a.amp);
  return candidates.slice(0,8).map((p,idx)=>({
    id:"M"+(idx+1),
    bin:p.bin,
    mhz:Number((state.centerMHz - state.spanMHz/2 + state.spanMHz*(p.bin/(spec.length-1))).toFixed(3)),
    dbm:Number((-112 + p.amp*94).toFixed(1))
  }));
}

function metrics(t, spec){
  const evm = state.profile === "ofdm" ? 3.5 : state.profile === "fhss" ? 2.3 : 2.0;
  const aclr = state.profile === "ofdm" ? 46.2 : 52.4;
  const obw = state.profile === "ofdm" ? 18.8 : state.profile === "fhss" ? 12.6 : 5.2;
  const occupancy = state.profile === "fhss" ? 28 + 8*Math.sin(t*.5) : state.profile === "ofdm" ? 49 : 18;
  const anomaly = state.profile === "burst" ? 0.42 : state.profile === "fhss" ? 0.18 : 0.08;
  return {
    profile: state.profile,
    snr: Number(state.snr.toFixed(1)),
    evm: Number(evm.toFixed(2)),
    aclr: Number(aclr.toFixed(1)),
    obw: Number(obw.toFixed(1)),
    occupancy: Number(occupancy.toFixed(1)),
    anomaly: Number(anomaly.toFixed(2)),
    spanMHz: state.spanMHz,
    rbwKHz: state.rbwKHz,
    centerMHz: state.centerMHz,
    detector: state.detector,
    maxHold: state.maxHold,
    markers: peaks(spec)
  };
}

function frame(){
  if(!state.running) return;
  state.tick++;
  const t = state.tick / 30;

  const spectrum = makeSpectrum(1536,t);
  maxHoldBuf = makeMaxHold(spectrum,maxHoldBuf);
  const constellation = makeConstellation(1400,t);
  const bursts = makeBursts(96,t);
  const m = metrics(t,spectrum);
  const hold = state.maxHold ? maxHoldBuf : new Float32Array(0);

  postMessage(
    {type:"frame", spectrum, maxHold:hold, constellation, bursts, metrics:m},
    [spectrum.buffer, hold.buffer, constellation.buffer, bursts.buffer]
  );
}

setInterval(frame,33);

onmessage = (ev)=>{
  const msg = ev.data || {};
  if(msg.type === "config"){
    state = {...state, ...msg.config};
    if(msg.config && Object.prototype.hasOwnProperty.call(msg.config,"profile")) maxHoldBuf = null;
  }
  if(msg.type === "pause") state.running=false;
  if(msg.type === "resume") state.running=true;
};
JS

echo
echo "[4/10] Creo shader registry V3"

cat > "$SHADERS" <<'JS'
/*
 TRFMC RF PRO V3 Reality Shaders
 Local shader registry / future WebGL-WebGPU migration layer.
 No external refs.
*/

window.TRFMC_RF_PRO_V3_SHADERS = Object.freeze({
  identity_vertex_glsl: `
    attribute vec2 a_position;
    varying vec2 v_uv;
    void main(){
      v_uv = a_position * 0.5 + 0.5;
      gl_Position = vec4(a_position, 0.0, 1.0);
    }
  `,
  rf_beam_fragment_glsl: `
    precision mediump float;
    varying vec2 v_uv;
    uniform float u_time;
    void main(){
      vec2 p = v_uv - vec2(0.22,0.55);
      float beam = exp(-abs(p.y - 0.22*sin(p.x*10.0+u_time))*28.0) * smoothstep(0.0,0.8,p.x);
      vec3 col = vec3(0.0,0.85,1.0) * beam;
      gl_FragColor = vec4(col, beam);
    }
  `,
  waterfall_palette_wgsl: `
    fn rf_palette(v: f32) -> vec3<f32> {
      return vec3<f32>(0.05 + v*0.20, 0.18 + v*0.82, 0.28 + v*0.72);
    }
  `
});
JS

echo
echo "[5/10] Creo CSS V3 Reality"

cat > "$CSS" <<'CSS'
:root{
  --r3-bg:#010409;
  --r3-glass:rgba(2,18,30,.86);
  --r3-cyan:#00e5ff;
  --r3-green:#75ff5b;
  --r3-yellow:#ffd84d;
  --r3-red:#ff3d7f;
  --r3-text:#e8fbff;
  --r3-muted:#8fb8c8;
}

.r3-root{
  min-height:100vh;
  color:var(--r3-text);
  font-family:ui-monospace,Consolas,monospace;
  background:
    radial-gradient(circle at 76% 8%,rgba(0,229,255,.19),transparent 31%),
    radial-gradient(circle at 18% 88%,rgba(117,255,91,.075),transparent 30%),
    linear-gradient(145deg,#020812,#010409 58%,#000);
  overflow:hidden;
}

.r3-cockpit{
  display:grid;
  grid-template-columns:360px 1.24fr 520px;
  grid-template-rows:auto 1fr;
  gap:8px;
  padding:8px;
  min-height:calc(100vh - 78px);
  position:relative;
  z-index:1;
}

.r3-panel{
  border:1px solid rgba(0,229,255,.27);
  border-radius:18px;
  background:
    linear-gradient(145deg,rgba(4,21,34,.90),rgba(1,7,13,.97)),
    radial-gradient(circle at 70% 0%,rgba(0,229,255,.10),transparent 35%);
  box-shadow:
    0 0 45px rgba(0,229,255,.13),
    inset 0 0 28px rgba(0,229,255,.055),
    0 25px 68px rgba(0,0,0,.55);
  padding:10px;
  backdrop-filter: blur(10px);
}

.r3-title{
  color:var(--r3-cyan);
  font-size:15px;
  letter-spacing:.14em;
  text-transform:uppercase;
  text-shadow:0 0 18px rgba(0,229,255,.50);
}

.r3-sub{
  color:var(--r3-muted);
  font-size:10px;
  line-height:1.48;
  margin-top:5px;
}

.r3-left{grid-row:1 / span 2}
.r3-center{grid-row:1 / span 2}
.r3-right{grid-row:1 / span 2}

.r3-kpis{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:7px;
  margin-top:9px;
}

.r3-kpi{
  border:1px solid rgba(0,229,255,.23);
  border-radius:12px;
  background:rgba(0,229,255,.045);
  padding:8px;
}

.r3-kpi small{
  display:block;
  color:var(--r3-muted);
  text-transform:uppercase;
  font-size:8px;
}

.r3-kpi b{
  display:block;
  color:var(--r3-green);
  font-size:17px;
  margin-top:2px;
}

.r3-card{
  border:1px solid rgba(0,229,255,.20);
  border-radius:14px;
  background:rgba(0,229,255,.034);
  padding:9px;
  margin-top:8px;
}

.r3-card h3{
  color:var(--r3-yellow);
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.09em;
  margin:0 0 7px 0;
}

.r3-control{
  display:grid;
  grid-template-columns:108px 1fr;
  gap:6px;
  align-items:center;
  margin:7px 0;
  color:var(--r3-muted);
  font-size:10px;
}

.r3-control select,
.r3-control input{
  width:100%;
  background:#020812;
  color:var(--r3-text);
  border:1px solid rgba(0,229,255,.28);
  border-radius:8px;
  padding:5px;
  font-family:inherit;
  font-size:10px;
}

.r3-canvas{
  display:block;
  width:100%;
  height:240px;
  background:#010409;
  border:1px solid rgba(0,229,255,.18);
  border-radius:14px;
}

.r3-canvas.hero{height:430px}
.r3-canvas.vsa{height:360px}
.r3-canvas.waterfall{height:280px}
.r3-canvas.small{height:180px}

.r3-split{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:8px;
}

.r3-table{
  width:100%;
  border-collapse:collapse;
  font-size:10px;
}

.r3-table th,
.r3-table td{
  border-bottom:1px solid rgba(0,229,255,.15);
  padding:5px;
  text-align:left;
}

.r3-table th{
  color:var(--r3-cyan);
  background:rgba(0,229,255,.05);
}

.r3-pill{
  display:inline-block;
  color:var(--r3-green);
  border:1px solid rgba(117,255,91,.35);
  background:rgba(117,255,91,.07);
  border-radius:8px;
  padding:2px 6px;
  margin:2px 3px 2px 0;
  font-size:9px;
}

.r3-formula{
  white-space:pre-wrap;
  font-size:10px;
  line-height:1.55;
  color:var(--r3-text);
}

.r3-footer-evidence{
  position:relative;
  z-index:1;
  margin:8px;
  border:1px solid rgba(0,229,255,.24);
  border-radius:14px;
  background:rgba(0,229,255,.032);
  padding:8px;
}

@media(max-width:1550px){
  .r3-cockpit{grid-template-columns:360px 1fr}
  .r3-right{grid-column:1 / -1;grid-row:auto}
}
@media(max-width:1100px){
  .r3-cockpit{grid-template-columns:1fr}
  .r3-left,.r3-center,.r3-right{grid-row:auto}
  .r3-split{grid-template-columns:1fr}
}
CSS

echo
echo "[6/10] Creo JS V3 Reality Web Component"

cat > "$JS" <<'JS'
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
JS

echo
echo "[7/10] Creo pagina V3 Reality + manifest"

python3 - "$OUT" "$PAGE" "$MANIFEST" <<'PY'
import json, html, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
page = Path(sys.argv[2])
manifest = Path(sys.argv[3])

policy = json.loads((out / "rf_pro_v3_reality_policy.json").read_text(errors="ignore"))

src_rows = ""
src_tsv = out / "rf_pro_rebuild_sources.tsv"
if src_tsv.exists():
    for line in src_tsv.read_text(errors="ignore").splitlines()[1:]:
        p = line.split("\t")
        if len(p) >= 8:
            src_rows += f"<tr><td><a href='{html.escape(p[0])}'>{html.escape(p[0])}</a></td><td>{html.escape(p[1])}</td><td>{html.escape(p[3])}</td><td>{html.escape(p[4])}</td><td>{html.escape(p[5][:16])}…</td></tr>"

manifest_data = {
    "id": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V3_REALITY",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html",
    "source_policy": policy,
    "mode": "synthetic_lab_only_reality_cockpit",
    "architecture": {
        "web_component": "trfmc-rf-pro-reality-v3",
        "worker": "/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v3.js",
        "shader_registry": "/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_shaders_v3.js",
        "renderer": "canvas_2d_reality_instrument_renderer",
        "gpu": "webgpu_readiness_with_webgl2_label_fallback"
    },
    "capabilities": [
        "rf_reality_scene",
        "vsa_markers",
        "max_hold_trace",
        "dense_persistent_waterfall",
        "iq_cloud_error_vectors",
        "fhss_hop_intelligence",
        "peak_marker_table",
        "formula_spine",
        "visual_evidence_binding"
    ],
    "policy": "New V3 reality leaf. V2 unchanged. Orphans unchanged. V6R3 and Control Room protected."
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

page.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC RF PRO Signal Intelligence Lab V3 Reality</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<link rel="stylesheet" href="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v3_reality.css">
<style>
.r3-source-table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
.r3-source-table th,.r3-source-table td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left}}
.r3-source-table th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC RF PRO Signal Intelligence Lab V3 Reality</div>
    <div class="leaf-sub">Reality instrument cockpit · RF scene · VSA markers · dense waterfall · I/Q error vectors · FHSS intelligence · synthetic/lab-only</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_lab_v2.html">V2 Engine</a>
    <a class="leaf-btn" href="/trfmc_rf_spectrum_lab_v1.html">RF Spectrum</a>
    <a class="leaf-btn" href="/trfmc_post_promotion_control_center_v1.html">Governance</a>
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_manifest_v3_reality.json">Manifest</a>
  </div>
</header>

<trfmc-rf-pro-reality-v3></trfmc-rf-pro-reality-v3>

<section class="r3-footer-evidence">
<h2 style="color:#00e5ff;font-size:13px;text-transform:uppercase;letter-spacing:.10em">Read-only RF PRO source evidence</h2>
<table class="r3-source-table">
<thead><tr><th>Source orphan</th><th>Exists</th><th>Words</th><th>RF keywords</th><th>SHA256</th></tr></thead>
<tbody>{src_rows}</tbody>
</table>
</section>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
<script src="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_shaders_v3.js"></script>
<script src="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v3_reality.js"></script>
</body>
</html>
''', encoding="utf-8")

print(json.dumps(manifest_data, indent=2, ensure_ascii=False))
PY

echo
echo "[8/10] Registro V3 Reality nel registry"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

target = public / "trfmc_rf_pro_signal_intelligence_lab_v3_reality.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html"] = {
    "class": "leaf_operational_candidate",
    "name": "trfmc_rf_pro_signal_intelligence_lab_v3_reality.html",
    "url": "/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html",
    "size": target.stat().st_size,
    "domain": "rf",
    "premium_leaf": True,
    "reality_cockpit": True,
    "rf_pro_rebuild": True,
    "canvas": True,
    "web_component": True,
    "web_worker": True,
    "shader_registry": True,
    "webgpu_readiness": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "RF PRO Signal Intelligence Lab V3 Reality"
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
reg["last_rf_pro_signal_intelligence_lab_v3_reality_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html",
    "policy": "New V3 reality leaf only. V2, orphans, V6R3 and Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[9/10] HTTP + external/iframe/content gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_rf_pro_signal_intelligence_lab_v3_reality.html \
    /trfmc_rf_pro_signal_intelligence_manifest_v3_reality.json \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v3_reality.css \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v3_reality.js \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v3.js \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_shaders_v3.js \
    /trfmc_rf_pro_signal_intelligence_lab_v2.html \
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

for f in "$PAGE" "$MANIFEST" "$CSS" "$JS" "$WORKER" "$SHADERS"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC RF PRO Signal Intelligence Lab V3 Reality" \
  "trfmc-rf-pro-reality-v3" \
  "RF Reality Scene" \
  "Reality Vector Spectrum Analyzer" \
  "Dense Persistent Waterfall" \
  "I/Q Cloud + Error Vectors" \
  "FHSS Hop Intelligence" \
  "Marker / Peak Table" \
  "Formula spine" \
  "shader_registry" \
  "TRFMC_RF_PRO_V3_SHADERS" \
  "new Worker" \
  "requestAnimationFrame" \
  "synthetic_lab_only_reality_cockpit" \
  "trfmc-visual-asset"
do
  if grep -Rqs "$token" "$PAGE" "$MANIFEST" "$CSS" "$JS" "$WORKER" "$SHADERS"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

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
    "operation": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V3_REALITY",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "content_check_miss": miss,
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "new_leaf": "/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html",
    "architecture": "web_component + dsp_worker + canvas_reality_renderer + shader_registry + webgpu_readiness",
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and miss == 0 and protected_ok and registry_changed else "WARN",
    "policy": "V3 reality RF PRO cockpit. V2, orphan files, V6R3 and Control Room unchanged."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[10/10] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V3_REALITY_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html \
    frontend/public/trfmc_rf_pro_signal_intelligence_manifest_v3_reality.json \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v3_reality.css \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v3_reality.js \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v3.js \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_shaders_v3.js \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_rf_pro_signal_intelligence_lab_v3_reality \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
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
echo "http://127.0.0.1:5173/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html"
echo "============================================================"
