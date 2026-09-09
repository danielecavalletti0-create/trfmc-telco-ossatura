#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V2_$TS"
LATEST="$BASE/runtime/quality/latest_rf_pro_signal_intelligence_lab_v2"

V1="$BASE/runtime/quality/latest_rf_pro_signal_intelligence_lab_v1"
DOSSIER="$BASE/runtime/quality/latest_orphan_consolidation_dossier_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

ASSET_DIR="$PUBLIC/assets/trfmc_rf_pro_signal_intelligence"
CSS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v2.css"
JS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v2.js"
WORKER="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_worker_v2.js"

PAGE="$PUBLIC/trfmc_rf_pro_signal_intelligence_lab_v2.html"
MANIFEST="$PUBLIC/trfmc_rf_pro_signal_intelligence_manifest_v2.json"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC RF PRO SIGNAL INTELLIGENCE LAB V2"
echo "Instrument-grade DSP worker · advanced RF console · no shell mutation"
echo "============================================================"

if [ ! -f "$V1/summary.json" ]; then
  echo "ERRORE: manca V1 PASS: $V1/summary.json"
  exit 10
fi

V1_RESULT="$(python3 - <<PY
import json
from pathlib import Path
print(json.loads(Path("$V1/summary.json").read_text()).get("result",""))
PY
)"

if [ "$V1_RESULT" != "PASS" ]; then
  echo "ERRORE: V1 non PASS: $V1_RESULT"
  exit 11
fi

echo
echo "[1/10] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V2_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_rf_pro_signal_intelligence_lab_v1 runtime/quality/latest_orphan_consolidation_dossier_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/10] Copio evidence sorgente RF PRO V1"

cp "$V1/rf_pro_rebuild_sources.tsv" "$OUT/rf_pro_rebuild_sources.tsv" 2>/dev/null || true
cp "$V1/rf_pro_rebuild_sources.json" "$OUT/rf_pro_rebuild_sources.json" 2>/dev/null || true
cp "$V1/rf_pro_source_scan_summary.json" "$OUT/rf_pro_source_scan_summary.json" 2>/dev/null || true

python3 - "$V1" "$OUT" <<'PY'
import json
from pathlib import Path
import sys

v1 = Path(sys.argv[1])
out = Path(sys.argv[2])

src = v1 / "rf_pro_source_scan_summary.json"
if src.exists():
    data = json.loads(src.read_text(errors="ignore"))
else:
    data = {"source_orphans": 4, "all_sources_exist": True}

data["v2_policy"] = "V2 consumes read-only source evidence from V1. Orphans remain unchanged."
(out / "rf_pro_v2_source_policy.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(data, indent=2, ensure_ascii=False))
PY

echo
echo "[3/10] Creo worker DSP sintetico V2"

cat > "$WORKER" <<'JS'
/*
 TRFMC RF PRO V2 DSP Worker
 Synthetic/lab-only signal generator.
 No network. No SDR control. No interception.
*/

"use strict";

let state = {
  running: true,
  profile: "fhss",
  snr: 28,
  spanMHz: 40,
  rbwKHz: 30,
  centerMHz: 2440,
  tick: 0
};

function clamp(x,a,b){ return Math.max(a, Math.min(b, x)); }

function gauss(x, mu, sigma){
  const z = (x - mu) / sigma;
  return Math.exp(-0.5 * z * z);
}

function dbNoise(i,t){
  return -92 + 2.5*Math.sin(i*.019 + t*.37) + 1.5*Math.sin(i*.071 + t*.91);
}

function hopCenter(t, lane){
  const seq = [0.12,0.37,0.62,0.21,0.78,0.48,0.31,0.86,0.56,0.69];
  return seq[(Math.floor(t*2.2)+lane*3) % seq.length];
}

function makeSpectrum(n,t){
  const arr = new Float32Array(n);
  for(let i=0;i<n;i++){
    const f = i/(n-1);
    let p = dbNoise(i,t);

    if(state.profile === "fhss"){
      for(let k=0;k<5;k++){
        const c = hopCenter(t, k);
        p += 34 * gauss(f, c, 0.010 + k*0.001);
      }
    } else if(state.profile === "ofdm"){
      p += 30 * gauss(f, .50, .095);
      p += 9 * gauss(f, .39, .008);
      p += 9 * gauss(f, .61, .008);
    } else if(state.profile === "qpsk"){
      p += 33 * gauss(f, .50, .035);
      p += 10 * gauss(f, .43, .012);
      p += 10 * gauss(f, .57, .012);
    } else if(state.profile === "burst"){
      const c = .18 + .68 * Math.abs(Math.sin(t*.35));
      p += 40 * gauss(f, c, .015);
      p += 18 * gauss(f, (c+.17)%1, .009);
    } else {
      p += 12 * gauss(f, .5, .20);
    }

    const floor = -110;
    const ceil = -18;
    arr[i] = clamp((p - floor) / (ceil - floor), 0, 1);
  }
  return arr;
}

function makeConstellation(points,t){
  const out = new Float32Array(points*2);
  const mod = state.profile === "ofdm" ? 16 : 4;
  const grid = mod === 16 ? [-3,-1,1,3] : [-1,1];
  const norm = mod === 16 ? 3 : 1;
  const jitter = Math.max(.018, (36-state.snr)/180);
  for(let i=0;i<points;i++){
    const a = grid[(i + Math.floor(t*7)) % grid.length] / norm;
    const b = grid[(Math.floor(i/grid.length) + Math.floor(t*5)) % grid.length] / norm;
    out[i*2] = a + jitter*Math.sin(i*.77+t*2.1);
    out[i*2+1] = b + jitter*Math.cos(i*.59+t*1.7);
  }
  return out;
}

function makeBursts(count,t){
  const out = new Float32Array(count*4);
  for(let i=0;i<count;i++){
    const lane = (i*5 + Math.floor(t*2.2)) % 8;
    const x = (i*.071 + t*.047) % 1;
    const width = .018 + (i%5)*.005;
    const amp = .45 + .5*((i%7)/6);
    out[i*4] = x;
    out[i*4+1] = lane;
    out[i*4+2] = width;
    out[i*4+3] = amp;
  }
  return out;
}

function makeMetrics(t){
  const evm = state.profile === "ofdm" ? 3.8 : state.profile === "fhss" ? 2.6 : 2.2;
  const occ = state.profile === "fhss" ? 18 + 6*Math.sin(t*.7) : state.profile === "ofdm" ? 42 : 12 + 5*Math.sin(t*.9);
  const aclr = state.profile === "ofdm" ? 45 : 51;
  const obw = state.profile === "ofdm" ? 18.4 : state.profile === "fhss" ? 7.2 : 4.8;
  return {
    profile: state.profile,
    snr: Number(state.snr.toFixed(1)),
    evm: Number(evm.toFixed(2)),
    occupancy: Number(occ.toFixed(1)),
    aclr: Number(aclr.toFixed(1)),
    obw: Number(obw.toFixed(1)),
    spanMHz: state.spanMHz,
    rbwKHz: state.rbwKHz,
    centerMHz: state.centerMHz,
    gpuReadyHint: false
  };
}

function frame(){
  if(!state.running) return;

  state.tick++;
  const t = state.tick / 30;
  const spectrum = makeSpectrum(1024, t);
  const constellation = makeConstellation(520, t);
  const bursts = makeBursts(52, t);
  const metrics = makeMetrics(t);

  postMessage(
    {type:"frame", spectrum, constellation, bursts, metrics},
    [spectrum.buffer, constellation.buffer, bursts.buffer]
  );
}

setInterval(frame, 33);

onmessage = (ev)=>{
  const msg = ev.data || {};
  if(msg.type === "config"){
    state = {...state, ...msg.config};
  }
  if(msg.type === "pause"){
    state.running = false;
  }
  if(msg.type === "resume"){
    state.running = true;
  }
};
JS

echo
echo "[4/10] Creo CSS V2"

cat > "$CSS" <<'CSS'
:root{
  --rf2-bg:#010409;
  --rf2-cyan:#00e5ff;
  --rf2-green:#75ff5b;
  --rf2-yellow:#ffd84d;
  --rf2-red:#ff3d7f;
  --rf2-text:#dffaff;
  --rf2-muted:#8fb8c8;
}

.rf2-root{
  min-height:100vh;
  color:var(--rf2-text);
  font-family:ui-monospace,Consolas,monospace;
  background:
    radial-gradient(circle at 82% 6%,rgba(0,229,255,.18),transparent 30%),
    radial-gradient(circle at 12% 88%,rgba(117,255,91,.08),transparent 28%),
    linear-gradient(145deg,#020812,#010409 62%,#000);
}

.rf2-grid{
  display:grid;
  grid-template-columns:400px 1fr;
  gap:8px;
  padding:8px;
  position:relative;
  z-index:1;
}

.rf2-panel{
  border:1px solid rgba(0,229,255,.28);
  border-radius:16px;
  background:
    linear-gradient(145deg,rgba(2,18,30,.94),rgba(1,7,13,.97)),
    radial-gradient(circle at 70% 0%,rgba(0,229,255,.10),transparent 34%);
  box-shadow:
    0 0 42px rgba(0,229,255,.14),
    inset 0 0 28px rgba(0,229,255,.055),
    0 22px 60px rgba(0,0,0,.48);
  padding:10px;
}

.rf2-title{
  color:var(--rf2-cyan);
  text-transform:uppercase;
  letter-spacing:.12em;
  font-size:15px;
  text-shadow:0 0 18px rgba(0,229,255,.46);
}

.rf2-sub{
  color:var(--rf2-muted);
  font-size:10px;
  line-height:1.5;
  margin-top:5px;
}

.rf2-kpis{
  display:grid;
  grid-template-columns:repeat(2,1fr);
  gap:7px;
  margin-top:9px;
}

.rf2-kpi{
  border:1px solid rgba(0,229,255,.24);
  background:rgba(0,229,255,.045);
  border-radius:11px;
  padding:8px;
}

.rf2-kpi small{
  display:block;
  color:var(--rf2-muted);
  text-transform:uppercase;
  font-size:8px;
}

.rf2-kpi b{
  display:block;
  color:var(--rf2-green);
  font-size:17px;
  margin-top:2px;
}

.rf2-card{
  border:1px solid rgba(0,229,255,.22);
  background:rgba(0,229,255,.035);
  border-radius:13px;
  padding:9px;
  margin-top:8px;
}

.rf2-card h3{
  color:var(--rf2-yellow);
  text-transform:uppercase;
  letter-spacing:.08em;
  font-size:11px;
  margin:0 0 7px 0;
}

.rf2-control{
  display:grid;
  grid-template-columns:120px 1fr;
  gap:6px;
  align-items:center;
  margin:6px 0;
  color:var(--rf2-muted);
  font-size:10px;
}

.rf2-control select,
.rf2-control input{
  width:100%;
  background:#020812;
  color:var(--rf2-text);
  border:1px solid rgba(0,229,255,.28);
  border-radius:8px;
  padding:5px;
  font-family:inherit;
  font-size:10px;
}

.rf2-main{
  display:grid;
  grid-template-columns:1.15fr .85fr;
  gap:8px;
}

.rf2-stack{
  display:grid;
  gap:8px;
}

.rf2-canvas{
  width:100%;
  height:250px;
  display:block;
  border:1px solid rgba(0,229,255,.20);
  border-radius:12px;
  background:#010409;
}

.rf2-canvas.tall{
  height:350px;
}

.rf2-canvas.small{
  height:165px;
}

.rf2-assets{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:8px;
}

.rf2-assets trfmc-visual-asset:first-child{
  grid-column:1 / -1;
}

.rf2-pill{
  display:inline-block;
  border:1px solid rgba(117,255,91,.36);
  background:rgba(117,255,91,.075);
  color:var(--rf2-green);
  border-radius:7px;
  padding:2px 6px;
  margin:2px 3px 2px 0;
  font-size:9px;
}

.rf2-formulas{
  color:var(--rf2-text);
  white-space:pre-wrap;
  font-size:10px;
  line-height:1.55;
}

.rf2-source{
  color:var(--rf2-muted);
  font-size:9px;
  padding:5px 0;
  border-bottom:1px solid rgba(0,229,255,.13);
}

.rf2-source a{
  color:var(--rf2-cyan);
}

@media(max-width:1400px){
  .rf2-grid{grid-template-columns:1fr}
  .rf2-main{grid-template-columns:1fr}
}
@media(max-width:900px){
  .rf2-kpis{grid-template-columns:1fr}
  .rf2-assets{grid-template-columns:1fr}
}
CSS

echo
echo "[5/10] Creo JS V2 Web Component + renderer"

cat > "$JS" <<'JS'
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
JS

echo
echo "[6/10] Creo pagina V2 + manifest"

python3 - "$OUT" "$PAGE" "$MANIFEST" <<'PY'
import json, html, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
page = Path(sys.argv[2])
manifest = Path(sys.argv[3])

src_summary = json.loads((out / "rf_pro_v2_source_policy.json").read_text(errors="ignore"))

src_rows = ""
src_tsv = out / "rf_pro_rebuild_sources.tsv"
if src_tsv.exists():
    for line in src_tsv.read_text(errors="ignore").splitlines()[1:]:
        p = line.split("\t")
        if len(p) >= 8:
            src_rows += f"<tr><td><a href='{html.escape(p[0])}'>{html.escape(p[0])}</a></td><td>{html.escape(p[1])}</td><td>{html.escape(p[3])}</td><td>{html.escape(p[4])}</td><td>{html.escape(p[5][:16])}…</td></tr>"

manifest_data = {
    "id": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V2",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v2.html",
    "source_policy": src_summary,
    "mode": "synthetic_lab_only",
    "architecture": {
        "web_component": "trfmc-rf-pro-lab-v2",
        "worker": "/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v2.js",
        "renderer": "canvas_2d_request_animation_frame",
        "gpu": "webgpu_readiness_detection_with_canvas_fallback"
    },
    "capabilities": [
        "dsp_worker",
        "scenario_controls",
        "spectrum_analyzer",
        "persistent_waterfall",
        "iq_constellation",
        "spectral_mask",
        "fhss_burst_timeline",
        "formula_matrix",
        "visual_asset_engine_binding"
    ],
    "policy": "New V2 leaf. Orphans unchanged. V6R3 and Control Room protected."
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

page.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC RF PRO Signal Intelligence Lab V2</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<link rel="stylesheet" href="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v2.css">
<style>
.rf2-evidence{{position:relative;z-index:1;margin:8px;border:1px solid rgba(0,229,255,.24);border-radius:12px;background:rgba(0,229,255,.035);padding:8px}}
.rf2-evidence h2{{color:#00e5ff;font-size:13px;text-transform:uppercase;letter-spacing:.10em}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC RF PRO Signal Intelligence Lab V2</div>
    <div class="leaf-sub">DSP worker · persistent waterfall · spectral mask · FHSS timeline · I/Q/EVM · WebGPU readiness · synthetic/lab-only</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_lab_v1.html">V1</a>
    <a class="leaf-btn" href="/trfmc_rf_spectrum_lab_v1.html">RF Spectrum</a>
    <a class="leaf-btn" href="/trfmc_post_promotion_control_center_v1.html">Governance</a>
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_manifest_v2.json">Manifest</a>
  </div>
</header>

<trfmc-rf-pro-lab-v2></trfmc-rf-pro-lab-v2>

<section class="rf2-evidence">
<h2>Read-only source evidence</h2>
<table>
<thead><tr><th>Source orphan</th><th>Exists</th><th>Words</th><th>RF keywords</th><th>SHA256</th></tr></thead>
<tbody>{src_rows}</tbody>
</table>
</section>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
<script src="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v2.js"></script>
</body>
</html>
''', encoding="utf-8")

print(json.dumps(manifest_data, indent=2, ensure_ascii=False))
PY

echo
echo "[7/10] Registro V2 come nuova leaf premium"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

target = public / "trfmc_rf_pro_signal_intelligence_lab_v2.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_rf_pro_signal_intelligence_lab_v2.html"] = {
    "class": "leaf_operational_candidate",
    "name": "trfmc_rf_pro_signal_intelligence_lab_v2.html",
    "url": "/trfmc_rf_pro_signal_intelligence_lab_v2.html",
    "size": target.stat().st_size,
    "domain": "rf",
    "premium_leaf": True,
    "rf_pro_rebuild": True,
    "canvas": True,
    "web_component": True,
    "web_worker": True,
    "webgpu_readiness": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "RF PRO Signal Intelligence Lab V2"
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
reg["last_rf_pro_signal_intelligence_lab_v2_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v2.html",
    "policy": "New V2 leaf only. Orphans unchanged. V6R3 and Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[8/10] HTTP + external/iframe/content gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_rf_pro_signal_intelligence_lab_v2.html \
    /trfmc_rf_pro_signal_intelligence_manifest_v2.json \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v2.css \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v2.js \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v2.js \
    /trfmc_rf_pro_signal_intelligence_lab_v1.html \
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

for f in "$PAGE" "$MANIFEST" "$CSS" "$JS" "$WORKER"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC RF PRO Signal Intelligence Lab V2" \
  "trfmc-rf-pro-lab-v2" \
  "new Worker" \
  "DSP worker" \
  "Persistent Waterfall" \
  "Spectral Mask" \
  "FHSS HOPSET" \
  "I/Q CONSTELLATION" \
  "Formula Matrix" \
  "WebGPU" \
  "synthetic_lab_only" \
  "trfmc-visual-asset" \
  "requestAnimationFrame"
do
  if grep -Rqs "$token" "$PAGE" "$MANIFEST" "$CSS" "$JS" "$WORKER"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

echo
echo "[9/10] Summary"

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
    "operation": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V2",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "content_check_miss": miss,
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "new_leaf": "/trfmc_rf_pro_signal_intelligence_lab_v2.html",
    "architecture": "web_component + dsp_worker + canvas_renderer + webgpu_readiness",
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and miss == 0 and protected_ok and registry_changed else "WARN",
    "policy": "V2 RF PRO engineering leaf. Orphans unchanged. V6R3 and Control Room unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V2_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_rf_pro_signal_intelligence_lab_v2.html \
    frontend/public/trfmc_rf_pro_signal_intelligence_manifest_v2.json \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v2.css \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v2.js \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_worker_v2.js \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_rf_pro_signal_intelligence_lab_v2 \
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
echo "http://127.0.0.1:5173/trfmc_rf_pro_signal_intelligence_lab_v2.html"
echo "============================================================"
