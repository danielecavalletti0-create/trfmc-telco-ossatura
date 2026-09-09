#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_INSTRUMENT_SUPERB_SYSTEM_V1_$TS"
LATEST="$BASE/runtime/quality/latest_instrument_superb_system_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

DIR="$PUBLIC/assets/trfmc_instrument_superb"
CSS="$DIR/trfmc_instrument_superb_v1.css"
JS="$DIR/trfmc_instrument_superb_v1.js"
MODELS="$DIR/trfmc_instrument_models_v1.json"

PAGE="$PUBLIC/trfmc_instrument_superb_gallery_v1.html"
DECK="$PUBLIC/trfmc_instrument_superb_command_deck_v1.html"
MANIFEST="$PUBLIC/trfmc_instrument_superb_manifest_v1.json"

mkdir -p "$OUT" "$DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC INSTRUMENT SUPERB SYSTEM V1"
echo "Real instrument taxonomy · technical canvases · formulas · donor-aware"
echo "============================================================"

echo
echo "[1/10] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_INSTRUMENT_SUPERB_SYSTEM_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_instrument_design_system_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/10] Scansione donor reali e sorgenti strumenti"

python3 - "$PUBLIC" "$OUT" <<'PY'
from pathlib import Path
import re, json, sys, hashlib

public = Path(sys.argv[1])
out = Path(sys.argv[2])

candidates = [
    "trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html",
    "rfpro_unified_console.html",
    "rfpro_master_v583.html",
    "signal_workbench_v582.html",
    "signal_workbench_v580.html",
    "signal_demod_v581.html",
    "uav_fhss_v584.html",
    "trfmc_signal_intelligence_center_v1.html",
    "trfmc_rf_metrology_calibration_lab_v1.html",
    "trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html",
    "trfmc_rf_microwave_engineering_v1.html",
    "trfmc_microwave_link_operations_center_v2.html",
    "trfmc_fiber_fronthaul_otdr_workbench_v2.html",
    "trfmc_datacenter_power_pdu_infrastructure_v1.html",
    "webgl_rf_physics_engine_v85e_viewport_discipline.html",
]

rows = []
for name in candidates:
    p = public / name
    exists = p.exists()
    txt = p.read_text(errors="ignore") if exists else ""
    title = re.search(r"<title[^>]*>(.*?)</title>", txt, re.I|re.S)
    title = re.sub(r"\s+"," ", title.group(1)).strip() if title else ""
    rows.append({
        "url": "/" + name,
        "exists": exists,
        "size": p.stat().st_size if exists else 0,
        "sha256": hashlib.sha256(txt.encode()).hexdigest() if exists else "",
        "title": title,
        "has_canvas": bool(re.search(r"<canvas|canvas", txt, re.I)),
        "has_webgl": bool(re.search(r"webgl|getContext\\(['\"]webgl", txt, re.I)),
        "has_formula": bool(re.search(r"formula|FFT|EVM|VSWR|Smith|OTDR|Fresnel|link budget|S11", txt, re.I)),
        "instrument_keywords": sorted(set(re.findall(r"(?i)\b(VSA|FFT|IQ|EVM|ACLR|OBW|Smith|S11|VSWR|OTDR|CPRI|eCPRI|RET|RRU|PDU|Fresnel|RSL|phase noise|coax|stripline|microstrip)\b", txt)))
    })

(out / "donor_sources.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n")
with (out / "donor_sources.tsv").open("w") as f:
    f.write("url\texists\tsize\thas_canvas\thas_webgl\thas_formula\tkeywords\ttitle\tsha256\n")
    for r in rows:
        f.write(f'{r["url"]}\t{r["exists"]}\t{r["size"]}\t{r["has_canvas"]}\t{r["has_webgl"]}\t{r["has_formula"]}\t{",".join(r["instrument_keywords"])}\t{r["title"]}\t{r["sha256"]}\n')

print(json.dumps({"sources": rows, "existing": sum(1 for r in rows if r["exists"])}, indent=2, ensure_ascii=False))
PY

echo
echo "[3/10] Creo modello dati strumenti basato sul materiale fornito"

cat > "$MODELS" <<'JSON'
{
  "id": "TRFMC_INSTRUMENT_MODELS_V1",
  "purpose": "Real instrument taxonomy for TRFMC RF/Telco/Cyber portal",
  "instruments": [
    {
      "id": "vsa_spectrum",
      "title": "Vector Spectrum Analyzer / Signal Intelligence",
      "domain": "RF / SDR / Spectrum",
      "visual_reference": "Spectrum analyzer, waterfall, IQ constellation, FHSS/burst intelligence",
      "kpi": ["center_frequency", "span", "RBW", "VBW", "noise_floor", "SNR", "EVM", "ACLR", "OBW", "marker_peak_table"],
      "formulas": [
        "FFT: X[k] = Σ x[n]e^{-j2πkn/N}",
        "RBW ≈ Fs/N · ENBW(window)",
        "EVM = RMS(error_vector)/RMS(reference_vector)",
        "ACLR = P_channel/P_adjacent",
        "OBW = occupied bandwidth over integrated spectral power"
      ]
    },
    {
      "id": "vna_smith",
      "title": "Vector Network Analyzer / Smith Chart",
      "domain": "Microwave / Matching / Transmission Lines",
      "visual_reference": "Smith chart, S11, VSWR, return loss, shunt stub matching",
      "kpi": ["Z0", "ZL", "Γ", "VSWR", "return_loss", "mismatch_loss", "stub_length"],
      "formulas": [
        "Γ = (ZL - Z0)/(ZL + Z0)",
        "VSWR = (1 + |Γ|)/(1 - |Γ|)",
        "ReturnLoss = -20log10(|Γ|)",
        "ML = -10log10(1-|Γ|²)"
      ]
    },
    {
      "id": "otdr_fiber",
      "title": "OTDR / Fiber Fronthaul Workbench",
      "domain": "Fiber / CPRI / eCPRI / Fronthaul",
      "visual_reference": "OTDR trace, reflection events, splice loss, connector loss, attenuation slope",
      "kpi": ["fiber_length", "attenuation_db_km", "splice_loss", "reflectance", "ORL", "event_table"],
      "formulas": [
        "Loss_total = α·L + ΣLoss_events",
        "Reflectance = 10log10(P_reflected/P_incident)",
        "ORL = -10log10(ΣP_reflected/P_incident)"
      ]
    },
    {
      "id": "microwave_link",
      "title": "Microwave Link / Backhaul Planner",
      "domain": "LOS / Fresnel / RSL / Fade Margin",
      "visual_reference": "Parabolic dish, LOS path, Fresnel zone, alignment, RSL, BER",
      "kpi": ["frequency", "distance", "antenna_gain", "EIRP", "FSPL", "RSL", "fade_margin", "modulation"],
      "formulas": [
        "FSPL(dB)=32.44+20log10(f_MHz)+20log10(d_km)",
        "RSL = Pt + Gt + Gr - FSPL - losses",
        "FadeMargin = RSL - RxSensitivity"
      ]
    },
    {
      "id": "rru_field",
      "title": "Antenna / RRU / RET / CPRI Field Instrument",
      "domain": "RAN / Sector / Beam / Port Mapping",
      "visual_reference": "Panel antenna, RRU, RET, CPRI/eCPRI, RF jumpers, port map, beam, PIM",
      "kpi": ["band", "ports", "sector", "azimuth", "mechanical_tilt", "electrical_tilt", "RET", "EIRP", "RSRP_edge", "PIM"],
      "formulas": [
        "EIRP = Ptx + Gantenna - feeder_loss",
        "RSRP_edge ≈ EIRP - path_loss - penetration_margin",
        "PIM: f_IM3 = 2f1 - f2 / 2f2 - f1"
      ]
    },
    {
      "id": "rack_pdu",
      "title": "Data Center Rack / PDU Power Instrument",
      "domain": "Data Center / Power / Infrastructure",
      "visual_reference": "Rack, PDU, UPS, load monitoring, environmental sensor, grounding",
      "kpi": ["voltage", "current", "power", "load_percent", "temperature", "humidity", "breaker_state", "outlet_status"],
      "formulas": [
        "P = V · I · PF",
        "Energy = P · t",
        "Load% = P_used/P_rated · 100"
      ]
    },
    {
      "id": "scope_ringing",
      "title": "Oscilloscope / Time Domain Integrity",
      "domain": "Signal Integrity / Time Domain",
      "visual_reference": "Square wave, overshoot, undershoot, ringing, impedance discontinuity",
      "kpi": ["rise_time", "overshoot", "undershoot", "ring_frequency", "settling_time", "impedance_spike"],
      "formulas": [
        "f_ring ≈ 1/T_ring",
        "Overshoot% = (Vpeak - Vfinal)/Vfinal · 100",
        "Z0 ≈ sqrt(L/C)"
      ]
    },
    {
      "id": "phase_noise",
      "title": "Phase Noise / mmWave Radar Instrument",
      "domain": "PLL / Radar / mmWave",
      "visual_reference": "Spectral spreading, phase jitter, beat frequency, multi-target separation",
      "kpi": ["phase_noise_dBc_Hz", "jitter", "beat_frequency_spread", "velocity_error", "target_separation"],
      "formulas": [
        "L(f) = phase_noise density in dBc/Hz",
        "σt ≈ jitter RMS",
        "ΔR = c/(2B) for FMCW range resolution"
      ]
    }
  ]
}
JSON

echo
echo "[4/10] Creo CSS Superb Instruments"

cat > "$CSS" <<'CSS'
:root{
  --sp-bg:#000205;
  --sp-panel:rgba(2,18,30,.86);
  --sp-deep:rgba(1,6,12,.96);
  --sp-cyan:#00e5ff;
  --sp-green:#78ff63;
  --sp-yellow:#ffd84d;
  --sp-red:#ff3d7f;
  --sp-blue:#4aa3ff;
  --sp-text:#eafbff;
  --sp-muted:#8fb8c8;
  --sp-border:rgba(0,229,255,.25);
  --sp-soft:rgba(0,229,255,.12);
  --sp-font:ui-monospace,Consolas,monospace;
}

.trfmc-superb-body{
  margin:0;
  min-height:100vh;
  color:var(--sp-text);
  font-family:var(--sp-font);
  background:
    radial-gradient(circle at 78% 8%,rgba(0,229,255,.18),transparent 30%),
    radial-gradient(circle at 10% 88%,rgba(120,255,99,.07),transparent 28%),
    linear-gradient(145deg,#020912,#000205 64%,#000);
}

.sp-top{
  height:62px;
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  padding:8px 12px;
  border-bottom:1px solid rgba(0,229,255,.28);
  background:linear-gradient(180deg,rgba(2,20,34,.98),rgba(1,7,13,.98));
  box-sizing:border-box;
}

.sp-title{
  margin:0;
  color:var(--sp-cyan);
  font-size:18px;
  text-transform:uppercase;
  letter-spacing:.13em;
  text-shadow:0 0 18px rgba(0,229,255,.55);
}

.sp-sub{
  margin:2px 0 0 0;
  color:var(--sp-muted);
  font-size:10px;
}

.sp-actions{
  display:flex;
  gap:8px;
  flex-wrap:wrap;
}

.sp-btn{
  color:var(--sp-cyan);
  text-decoration:none;
  border:1px solid rgba(0,229,255,.35);
  background:rgba(0,229,255,.06);
  border-radius:10px;
  padding:7px 10px;
  font-size:10px;
}

.sp-shell{
  display:grid;
  grid-template-columns:340px 1fr 420px;
  gap:8px;
  padding:8px;
  box-sizing:border-box;
  min-height:calc(100vh - 62px);
}

.sp-panel{
  position:relative;
  border:1px solid var(--sp-border);
  border-radius:22px;
  background:
    linear-gradient(145deg,var(--sp-panel),var(--sp-deep)),
    radial-gradient(circle at 65% 0%,rgba(0,229,255,.11),transparent 36%);
  box-shadow:
    0 0 55px rgba(0,229,255,.12),
    inset 0 0 32px rgba(0,229,255,.05),
    0 26px 78px rgba(0,0,0,.62);
  overflow:hidden;
  padding:10px;
}

.sp-panel::before{
  content:"";
  position:absolute;
  inset:0;
  pointer-events:none;
  background:
    linear-gradient(90deg,rgba(255,255,255,.035),transparent 18%,transparent 82%,rgba(255,255,255,.025)),
    repeating-linear-gradient(0deg,rgba(255,255,255,.012) 0,rgba(255,255,255,.012) 1px,transparent 1px,transparent 5px);
  opacity:.48;
  mix-blend-mode:screen;
}

.sp-panel > *{position:relative;z-index:1}

.sp-label{
  color:var(--sp-yellow);
  text-transform:uppercase;
  letter-spacing:.10em;
  font-size:11px;
  margin:0 0 7px 0;
}

.sp-muted{
  color:var(--sp-muted);
  font-size:10px;
  line-height:1.45;
}

.sp-kpis{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:7px;
  margin-top:10px;
}

.sp-kpi{
  border:1px solid rgba(0,229,255,.22);
  background:rgba(0,229,255,.045);
  border-radius:13px;
  padding:8px;
}

.sp-kpi small{
  display:block;
  color:var(--sp-muted);
  text-transform:uppercase;
  font-size:8px;
}

.sp-kpi b{
  display:block;
  color:var(--sp-green);
  font-size:16px;
  margin-top:2px;
}

.sp-instrument-list{
  display:grid;
  gap:7px;
  margin-top:10px;
}

.sp-instrument-item{
  border:1px solid rgba(0,229,255,.18);
  border-radius:14px;
  background:rgba(0,229,255,.035);
  padding:8px;
  cursor:pointer;
}

.sp-instrument-item strong{
  display:block;
  color:var(--sp-cyan);
  font-size:10px;
  text-transform:uppercase;
  letter-spacing:.08em;
}

.sp-instrument-item span{
  display:block;
  color:var(--sp-muted);
  font-size:8.5px;
  margin-top:4px;
  line-height:1.35;
}

.sp-main{
  display:grid;
  grid-template-rows:470px 285px 1fr;
  gap:8px;
}

.sp-stage{
  position:relative;
  height:100%;
  min-height:420px;
  border:1px solid rgba(0,229,255,.20);
  border-radius:18px;
  overflow:hidden;
  background:#000205;
}

.sp-canvas{
  width:100%;
  height:100%;
  display:block;
  background:#000205;
  border-radius:14px;
}

.sp-grid2{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:8px;
}

.sp-mini{
  border:1px solid rgba(0,229,255,.18);
  border-radius:16px;
  background:rgba(0,229,255,.03);
  padding:8px;
  overflow:hidden;
}

.sp-mini h3{
  color:var(--sp-yellow);
  font-size:10px;
  text-transform:uppercase;
  letter-spacing:.08em;
  margin:0 0 6px 0;
}

.sp-right{
  display:grid;
  grid-template-rows:auto 1fr auto;
  gap:8px;
}

.sp-table{
  width:100%;
  border-collapse:collapse;
  font-size:9px;
}

.sp-table th,
.sp-table td{
  border-bottom:1px solid rgba(0,229,255,.14);
  padding:5px;
  text-align:left;
  vertical-align:top;
}

.sp-table th{
  color:var(--sp-cyan);
  background:rgba(0,229,255,.05);
}

.sp-formulas{
  white-space:pre-wrap;
  color:var(--sp-text);
  font-size:9.5px;
  line-height:1.55;
}

.sp-badge{
  display:inline-block;
  border:1px solid rgba(120,255,99,.35);
  background:rgba(120,255,99,.07);
  color:var(--sp-green);
  border-radius:8px;
  padding:2px 6px;
  margin:2px 3px 2px 0;
  font-size:8.5px;
}

.sp-footer{
  margin:8px;
  border:1px solid rgba(0,229,255,.22);
  border-radius:16px;
  background:rgba(0,229,255,.03);
  padding:8px;
}

@media(max-width:1600px){
  .sp-shell{grid-template-columns:320px 1fr}
  .sp-right{grid-column:1 / -1;grid-template-columns:1fr 1fr 1fr;grid-template-rows:auto}
}

@media(max-width:1100px){
  .sp-shell{grid-template-columns:1fr}
  .sp-right,.sp-grid2{grid-template-columns:1fr}
}
CSS

echo
echo "[5/10] Creo JS Superb Instruments"

cat > "$JS" <<'JS'
(function(){
  "use strict";

  const TAU = Math.PI * 2;
  const MODEL_URL = "/assets/trfmc_instrument_superb/trfmc_instrument_models_v1.json";

  function fit(c){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(2, Math.floor(c.clientWidth * dpr));
    const h = Math.max(2, Math.floor(c.clientHeight * dpr));
    if(c.width !== w || c.height !== h){ c.width=w; c.height=h; }
    return {ctx:c.getContext("2d"),w,h,dpr};
  }

  function bg(ctx,w,h){
    const g = ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");
    g.addColorStop(.55,"#020812");
    g.addColorStop(1,"#000205");
    ctx.fillStyle = g;
    ctx.fillRect(0,0,w,h);
  }

  function grid(ctx,w,h,dpr,a=.09){
    ctx.lineWidth = 1*dpr;
    ctx.strokeStyle = `rgba(0,229,255,${a})`;
    for(let i=0;i<13;i++){ const x=w*i/12; ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke(); }
    for(let i=0;i<9;i++){ const y=h*i/8; ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke(); }
  }

  function label(ctx,dpr,s,x,y,color="#8fb8c8",size=10){
    ctx.fillStyle = color;
    ctx.font = `${size*dpr}px ui-monospace,Consolas,monospace`;
    ctx.fillText(s,x,y);
  }

  function rr(ctx,x,y,w,h,r=12){
    ctx.beginPath();
    ctx.moveTo(x+r,y);
    ctx.arcTo(x+w,y,x+w,y+h,r);
    ctx.arcTo(x+w,y+h,x,y+h,r);
    ctx.arcTo(x,y+h,x,y,r);
    ctx.arcTo(x,y,x+w,y,r);
    ctx.closePath();
  }

  function drawSuperScene(c, t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);
    grid(ctx,w,h,dpr,.055);

    ctx.save();
    ctx.strokeStyle="rgba(0,229,255,.10)";
    for(let i=0;i<26;i++){
      const x=w*(.04+i*.038);
      ctx.beginPath();
      ctx.moveTo(x,h*.97);
      ctx.lineTo(w*.50+(x-w*.5)*.18,h*.58);
      ctx.stroke();
    }
    for(let i=0;i<20;i++){
      const y=h*(.62+i*.025);
      ctx.beginPath();
      ctx.moveTo(w*.04,y);
      ctx.lineTo(w*.95,y-h*.16);
      ctx.stroke();
    }

    const mastX=w*.18;
    ctx.lineWidth=5*dpr;
    ctx.strokeStyle="rgba(220,245,250,.88)";
    ctx.beginPath(); ctx.moveTo(mastX,h*.84); ctx.lineTo(mastX,h*.22); ctx.stroke();

    ctx.fillStyle="rgba(160,200,210,.82)";
    rr(ctx,mastX-46*dpr,h*.48,92*dpr,105*dpr,9*dpr); ctx.fill();
    ctx.strokeStyle="rgba(255,255,255,.20)"; ctx.stroke();

    for(let i=0;i<13;i++){
      ctx.strokeStyle=`rgba(20,50,60,${.20+i*.015})`;
      ctx.beginPath();
      ctx.moveTo(mastX-36*dpr+i*6*dpr,h*.50);
      ctx.lineTo(mastX-36*dpr+i*6*dpr,h*.70);
      ctx.stroke();
    }

    const panelX=w*.33, panelY=h*.43;
    const g=ctx.createLinearGradient(panelX-60*dpr,panelY-140*dpr,panelX+70*dpr,panelY+140*dpr);
    g.addColorStop(0,"rgba(255,255,255,.97)");
    g.addColorStop(1,"rgba(150,230,245,.82)");
    ctx.fillStyle=g;
    rr(ctx,panelX-55*dpr,panelY-138*dpr,110*dpr,276*dpr,28*dpr); ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.26)"; ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    const emitterX=w*(.78+.015*Math.sin(t*.0012)), emitterY=h*(.30+.02*Math.cos(t*.001));
    for(let i=0;i<44;i++){
      const k=i/44;
      ctx.strokeStyle=`rgba(0,229,255,${.028*(1-k)})`;
      ctx.lineWidth=(1+k*7)*dpr;
      ctx.beginPath();
      ctx.moveTo(panelX+55*dpr,panelY);
      ctx.quadraticCurveTo(w*(.53+k*.05),h*(.35+k*.12),emitterX,emitterY);
      ctx.stroke();
    }
    const rg=ctx.createRadialGradient(emitterX,emitterY,2*dpr,emitterX,emitterY,105*dpr);
    rg.addColorStop(0,"rgba(255,216,77,.50)");
    rg.addColorStop(1,"rgba(255,216,77,0)");
    ctx.fillStyle=rg; ctx.fillRect(emitterX-120*dpr,emitterY-120*dpr,240*dpr,240*dpr);
    ctx.restore();

    ctx.fillStyle="rgba(255,216,77,.92)";
    ctx.beginPath(); ctx.arc(w*.78,h*.30,9*dpr,0,TAU); ctx.fill();
    ctx.strokeStyle="rgba(255,216,77,.90)";
    ctx.beginPath(); ctx.moveTo(w*.78-38*dpr,h*.30); ctx.lineTo(w*.78+38*dpr,h*.30); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w*.78,h*.30-28*dpr); ctx.lineTo(w*.78,h*.30+28*dpr); ctx.stroke();

    label(ctx,dpr,"TRFMC SUPERB INSTRUMENT SCENE · RRU + PANEL + RF FIELD + EVIDENCE",18*dpr,26*dpr,"#eafbff",11);
    label(ctx,dpr,"visual donor driven · no shell mutation · instrument taxonomy active",18*dpr,h-18*dpr,"#78ff63",10);
    ctx.restore();
  }

  function drawSpectrum(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,.12);
    ctx.fillStyle="rgba(255,61,127,.07)";
    ctx.fillRect(w*.07,h*.16,w*.15,h*.66);
    ctx.fillRect(w*.78,h*.16,w*.15,h*.66);

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    ctx.strokeStyle="#00e5ff";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<950;i++){
      const x=w*i/949;
      const f=i/949;
      let v=.18+.03*Math.sin(i*.05+t*.002)+.02*Math.sin(i*.017);
      const peaks=[.18,.31,.50,.59,.73,.84];
      for(const p of peaks){ v += .33*Math.exp(-Math.pow((f-p)/.010,2)); }
      const y=h*(.84-v*.65);
      if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();
    ctx.restore();

    const marks=[.18,.31,.50,.59,.73,.84];
    marks.forEach((p,i)=>{
      const x=w*p;
      ctx.strokeStyle=i===2?"#ffd84d":"#78ff63";
      ctx.fillStyle=ctx.strokeStyle;
      ctx.beginPath(); ctx.moveTo(x,h*.25); ctx.lineTo(x,h*.78); ctx.stroke();
      label(ctx,dpr,"M"+(i+1),x+5*dpr,h*.30,ctx.fillStyle,9);
    });

    label(ctx,dpr,"VSA · FFT · RBW/VBW · MAX HOLD · ACLR/OBW · PEAK TABLE",10*dpr,18*dpr,"#eafbff",9);
  }

  function drawSmith(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);
    const cx=w*.5, cy=h*.52, r=Math.min(w,h)*.36;
    ctx.strokeStyle="rgba(232,251,255,.65)";
    ctx.lineWidth=1.5*dpr;
    ctx.beginPath(); ctx.arc(cx,cy,r,0,TAU); ctx.stroke();

    ctx.strokeStyle="rgba(0,229,255,.14)";
    for(let i=1;i<8;i++){
      ctx.beginPath(); ctx.arc(cx+r*(i/8),cy,r*(1-i/8),0,TAU); ctx.stroke();
      ctx.beginPath(); ctx.arc(cx-r*(i/8),cy,r*(1-i/8),0,TAU); ctx.stroke();
    }
    ctx.beginPath(); ctx.moveTo(cx-r,cy); ctx.lineTo(cx+r,cy); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx,cy-r); ctx.lineTo(cx,cy+r); ctx.stroke();

    ctx.strokeStyle="#00e5ff";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<180;i++){
      const a= -1.8 + i/179*2.5 + .15*Math.sin(t*.001);
      const rr=.50 + .10*Math.sin(i*.06);
      const x=cx+Math.cos(a)*r*rr;
      const y=cy+Math.sin(a)*r*rr;
      if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    ctx.fillStyle="#ffd84d";
    ctx.beginPath(); ctx.arc(cx,cy,5*dpr,0,TAU); ctx.fill();
    label(ctx,dpr,"VNA / SMITH · S11 · Γ · VSWR · RETURN LOSS",10*dpr,18*dpr,"#eafbff",9);
  }

  function drawOTDR(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,.10);
    ctx.strokeStyle="#00e5ff";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<850;i++){
      const x=w*i/849;
      const km=i/849;
      let y=h*(.18+.55*km);
      const events=[.18,.37,.62,.81];
      for(const e of events){
        y -= h*.16*Math.exp(-Math.pow((km-e)/.006,2));
        if(km>e)y += h*.025;
      }
      y += Math.sin(i*.04+t*.002)*2*dpr;
      if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    [.18,.37,.62,.81].forEach((e,i)=>{
      const x=w*e;
      ctx.strokeStyle=i===3?"#ff3d7f":"#ffd84d";
      ctx.beginPath(); ctx.moveTo(x,h*.12); ctx.lineTo(x,h*.84); ctx.stroke();
      label(ctx,dpr,"E"+(i+1),x+4*dpr,h*.20,ctx.strokeStyle,9);
    });

    label(ctx,dpr,"OTDR · SPLICE LOSS · REFLECTANCE · ORL · CPRI/eCPRI FIBER",10*dpr,18*dpr,"#eafbff",9);
  }

  function drawMicrowave(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h);
    grid(ctx,w,h,dpr,.07);

    ctx.strokeStyle="rgba(200,245,255,.75)";
    ctx.lineWidth=3*dpr;
    ctx.beginPath(); ctx.moveTo(w*.18,h*.80); ctx.lineTo(w*.18,h*.25); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w*.82,h*.80); ctx.lineTo(w*.82,h*.25); ctx.stroke();

    ctx.fillStyle="rgba(230,250,255,.90)";
    ctx.beginPath(); ctx.ellipse(w*.22,h*.40,32*dpr,58*dpr,-.2,0,TAU); ctx.fill();
    ctx.beginPath(); ctx.ellipse(w*.78,h*.40,32*dpr,58*dpr,.2,0,TAU); ctx.fill();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<28;i++){
      const k=i/28;
      ctx.strokeStyle=`rgba(0,229,255,${.030*(1-k)})`;
      ctx.lineWidth=(1+k*5)*dpr;
      ctx.beginPath();
      ctx.moveTo(w*.25,h*.40);
      ctx.quadraticCurveTo(w*.50,h*(.30+.05*Math.sin(t*.001+k)),w*.75,h*.40);
      ctx.stroke();
    }
    ctx.restore();

    ctx.strokeStyle="rgba(255,216,77,.55)";
    ctx.setLineDash([8*dpr,7*dpr]);
    ctx.beginPath(); ctx.ellipse(w*.50,h*.40,w*.24,h*.10,0,0,TAU); ctx.stroke();
    ctx.setLineDash([]);

    label(ctx,dpr,"MICROWAVE LINK · LOS · FRESNEL · RSL · FADE MARGIN · BER",10*dpr,18*dpr,"#eafbff",9);
  }

  function drawRRUPorts(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,.06);

    ctx.fillStyle="rgba(210,245,255,.88)";
    rr(ctx,w*.48,h*.14,w*.16,h*.58,18*dpr); ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.25)"; ctx.stroke();

    ctx.fillStyle="rgba(160,200,210,.80)";
    rr(ctx,w*.28,h*.34,w*.18,h*.26,9*dpr); ctx.fill();

    const colors=["#ffd84d","#00e5ff","#ffd84d","#00e5ff","#78ff63","#ff7a3d","#00e5ff","#ffd84d"];
    for(let i=0;i<8;i++){
      const sx=w*(.50+i*.017), sy=h*.73;
      const ex=w*(.18+i*.07), ey=h*.86;
      ctx.strokeStyle=colors[i%colors.length];
      ctx.lineWidth=3*dpr;
      ctx.beginPath();
      ctx.moveTo(sx,sy);
      ctx.bezierCurveTo(sx,sy+h*.10,ex,ey-h*.12,ex,ey);
      ctx.stroke();
      ctx.fillStyle=colors[i%colors.length];
      ctx.beginPath(); ctx.arc(sx,sy,4*dpr,0,TAU); ctx.fill();
    }

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<24;i++){
      const k=i/24;
      ctx.strokeStyle=`rgba(0,229,255,${.035*(1-k)})`;
      ctx.lineWidth=(1+k*4)*dpr;
      ctx.beginPath();
      ctx.moveTo(w*.64,h*.42);
      ctx.lineTo(w*(.90+k*.04),h*(.30+k*.22));
      ctx.stroke();
    }
    ctx.restore();

    label(ctx,dpr,"ANTENNA/RRU/RET/CPRI · PORT MAP · PIM · EIRP · RSRP EDGE",10*dpr,18*dpr,"#eafbff",9);
  }

  function drawPDU(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,.05);

    ctx.strokeStyle="rgba(220,245,255,.45)";
    ctx.lineWidth=3*dpr;
    ctx.strokeRect(w*.22,h*.14,w*.50,h*.72);

    for(let r=0;r<6;r++){
      ctx.fillStyle="rgba(30,55,68,.78)";
      rr(ctx,w*.30,h*(.18+r*.10),w*.34,h*.065,7*dpr); ctx.fill();
      for(let i=0;i<6;i++){
        ctx.fillStyle=i%2?"#00e5ff":"#78ff63";
        ctx.fillRect(w*(.34+i*.045),h*(.20+r*.10),8*dpr,8*dpr);
      }
    }

    ctx.fillStyle="rgba(20,30,38,.92)";
    rr(ctx,w*.07,h*.13,w*.10,h*.74,12*dpr); ctx.fill();
    for(let i=0;i<8;i++){
      ctx.strokeStyle="rgba(0,229,255,.35)";
      ctx.strokeRect(w*.095,h*(.20+i*.075),w*.05,h*.045);
    }

    const load=.55+.22*Math.sin(t*.001);
    ctx.fillStyle="#78ff63";
    ctx.fillRect(w*.09,h*.76,w*.06,-h*.50*load);

    label(ctx,dpr,"DATA CENTER PDU · UPS · LOAD · POWER · ENVIRONMENT · GROUND",10*dpr,18*dpr,"#eafbff",9);
  }

  function drawScope(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,.11);

    ctx.strokeStyle="#ffd84d";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<900;i++){
      const x=w*i/899;
      const phase=(i/899*4)%1;
      let base=phase<.5?.30:.72;
      const edge=Math.min(Math.abs(phase-.5),Math.abs(phase-0),Math.abs(phase-1));
      const ring=Math.exp(-edge*28)*Math.sin(edge*90+t*.004)*.12;
      const y=h*(base-ring);
      if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    label(ctx,dpr,"OSCILLOSCOPE · OVERSHOOT · UNDERSHOOT · RINGING · IMPEDANCE SPIKE",10*dpr,18*dpr,"#eafbff",9);
  }

  function drawPhaseNoise(c,t){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr,.09);

    ctx.strokeStyle="#00e5ff";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<850;i++){
      const f=i/849;
      const clean=.12*Math.exp(-Math.pow((f-.30)/.015,2));
      const noisy=.45*Math.exp(-Math.pow((f-.68)/.075,2))*(.7+.2*Math.sin(i*.22+t*.002));
      const v=.16+clean+noisy;
      const x=w*f,y=h*(.85-v);
      if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    label(ctx,dpr,"PHASE NOISE · PLL · mmWAVE RADAR · BEAT FREQUENCY SPREADING",10*dpr,18*dpr,"#eafbff",9);
  }

  class SuperbInstrumentSuite extends HTMLElement{
    async connectedCallback(){
      this.models = await fetch(MODEL_URL).then(r=>r.json()).catch(()=>({instruments:[]}));
      this.innerHTML = `
        <div class="sp-shell">
          <aside class="sp-panel">
            <h2 class="sp-title" style="font-size:15px">Instrument Taxonomy</h2>
            <p class="sp-muted">Strumenti reali, non rettangoli: VSA, VNA/Smith, OTDR, MW Link, RRU field, rack PDU, oscilloscope, phase-noise.</p>
            <div class="sp-kpis">
              <div class="sp-kpi"><small>Models</small><b>${this.models.instruments.length}</b></div>
              <div class="sp-kpi"><small>Mode</small><b>SUPERB</b></div>
              <div class="sp-kpi"><small>Shell</small><b>LOCKED</b></div>
              <div class="sp-kpi"><small>Refs</small><b>LOCAL</b></div>
            </div>
            <div class="sp-instrument-list">
              ${this.models.instruments.map(x=>`
                <div class="sp-instrument-item" data-instrument="${x.id}">
                  <strong>${x.title}</strong>
                  <span>${x.domain}</span>
                </div>
              `).join("")}
            </div>
          </aside>

          <main class="sp-panel sp-main">
            <div class="sp-stage"><canvas class="sp-canvas" data-sp-scope="scene"></canvas></div>
            <div class="sp-grid2">
              <div class="sp-mini"><h3>VSA / Spectrum</h3><canvas class="sp-canvas" data-sp-scope="spectrum"></canvas></div>
              <div class="sp-mini"><h3>VNA / Smith Chart</h3><canvas class="sp-canvas" data-sp-scope="smith"></canvas></div>
            </div>
            <div class="sp-grid2">
              <div class="sp-mini"><h3>OTDR Fiber Trace</h3><canvas class="sp-canvas" data-sp-scope="otdr"></canvas></div>
              <div class="sp-mini"><h3>Microwave Link</h3><canvas class="sp-canvas" data-sp-scope="mw"></canvas></div>
            </div>
          </main>

          <aside class="sp-panel sp-right">
            <div>
              <h2 class="sp-title" style="font-size:15px">Field Instruments</h2>
              <p class="sp-muted">La parte strumenti ora deve essere autonoma, densa, tecnica, con formule e KPI veri.</p>
            </div>
            <div class="sp-grid2">
              <div class="sp-mini"><h3>RRU / RET / CPRI</h3><canvas class="sp-canvas" data-sp-scope="rru"></canvas></div>
              <div class="sp-mini"><h3>Rack / PDU</h3><canvas class="sp-canvas" data-sp-scope="pdu"></canvas></div>
              <div class="sp-mini"><h3>Scope Ringing</h3><canvas class="sp-canvas" data-sp-scope="scope"></canvas></div>
              <div class="sp-mini"><h3>Phase Noise</h3><canvas class="sp-canvas" data-sp-scope="phase"></canvas></div>
            </div>
            <div class="sp-mini">
              <h3>Formula Spine</h3>
              <div class="sp-formulas">Maxwell: ∇×E = -∂B/∂t | ∇×H = J + ∂D/∂t
Link budget: RSL = Pt + Gt + Gr - FSPL - Loss
FSPL = 32.44 + 20log10(fMHz) + 20log10(dkm)
Γ = (ZL-Z0)/(ZL+Z0) | VSWR = (1+|Γ|)/(1-|Γ|)
Zcoax = 60/sqrt(εr) · ln(b/a)
Patch W = c/(2f0) · sqrt(2/(εr+1))
OTDR Loss = αL + ΣEvents
EVM = RMS(error)/RMS(reference)
PIM IM3 = 2f1-f2 / 2f2-f1</div>
            </div>
          </aside>
        </div>
      `;

      this.querySelectorAll(".sp-instrument-item").forEach(el=>{
        el.addEventListener("click",()=>{
          const id=el.dataset.instrument;
          this.dispatchEvent(new CustomEvent("trfmc-instrument-select",{detail:{id},bubbles:true}));
        });
      });

      const loop = (t)=>{
        this.querySelectorAll("canvas[data-sp-scope]").forEach(c=>{
          const s=c.dataset.spScope;
          if(s==="scene")drawSuperScene(c,t);
          else if(s==="spectrum")drawSpectrum(c,t);
          else if(s==="smith")drawSmith(c,t);
          else if(s==="otdr")drawOTDR(c,t);
          else if(s==="mw")drawMicrowave(c,t);
          else if(s==="rru")drawRRUPorts(c,t);
          else if(s==="pdu")drawPDU(c,t);
          else if(s==="scope")drawScope(c,t);
          else if(s==="phase")drawPhaseNoise(c,t);
        });
        this.raf=requestAnimationFrame(loop);
      };
      this.raf=requestAnimationFrame(loop);
    }

    disconnectedCallback(){
      if(this.raf)cancelAnimationFrame(this.raf);
    }
  }

  if(!customElements.get("trfmc-superb-instrument-suite")){
    customElements.define("trfmc-superb-instrument-suite", SuperbInstrumentSuite);
  }
})();
JS

echo
echo "[6/10] Creo pagine Superb Gallery e Command Deck"

cat > "$MANIFEST" <<JSON
{
  "id": "TRFMC_INSTRUMENT_SUPERB_SYSTEM_V1",
  "timestamp": "$(date -Iseconds)",
  "purpose": "Replace incomplete instrument preview with a real instrument taxonomy and superb visual/engineering gallery",
  "assets": [
    "/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.css",
    "/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.js",
    "/assets/trfmc_instrument_superb/trfmc_instrument_models_v1.json"
  ],
  "pages": [
    "/trfmc_instrument_superb_gallery_v1.html",
    "/trfmc_instrument_superb_command_deck_v1.html"
  ],
  "instrument_domains": [
    "VSA Spectrum",
    "VNA Smith",
    "OTDR Fiber",
    "Microwave Link",
    "Antenna RRU RET CPRI",
    "Data Center PDU",
    "Oscilloscope Ringing",
    "Phase Noise mmWave"
  ],
  "policy": "New service/design layer only. V6R3, Control Room, orphans and previous RF pages remain unchanged."
}
JSON

cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Instrument Superb Gallery V1</title>
<link rel="stylesheet" href="/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.css">
</head>
<body class="trfmc-superb-body">
<header class="sp-top">
  <div>
    <h1 class="sp-title">TRFMC Instrument Superb Gallery V1</h1>
    <p class="sp-sub">VSA · VNA/Smith · OTDR · Microwave Link · Antenna/RRU/RET/CPRI · Rack/PDU · Scope · Phase Noise</p>
  </div>
  <nav class="sp-actions">
    <a class="sp-btn" href="/trfmc_instrument_superb_command_deck_v1.html">Superb Deck</a>
    <a class="sp-btn" href="/trfmc_true_portal_command_deck_v1.html">Old Deck</a>
    <a class="sp-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="sp-btn" href="/trfmc_instrument_superb_manifest_v1.json">Manifest</a>
  </nav>
</header>

<trfmc-superb-instrument-suite></trfmc-superb-instrument-suite>

<section class="sp-footer">
  <h2 class="sp-title" style="font-size:14px">Nota tecnica</h2>
  <p class="sp-muted">Questa non è una shell alternativa. È una libreria strumenti visuale e ingegneristica, locale, senza iframe e senza CDN, costruita per sostituire le preview povere con strumenti riconoscibili e riusabili.</p>
</section>

<script src="/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.js"></script>
</body>
</html>
HTML

cat > "$DECK" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Instrument Superb Command Deck V1</title>
<link rel="stylesheet" href="/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.css">
</head>
<body class="trfmc-superb-body">
<header class="sp-top">
  <div>
    <h1 class="sp-title">TRFMC Instrument Superb Command Deck V1</h1>
    <p class="sp-sub">Regia strumenti: dalla documentazione visuale al cockpit tecnico del portale</p>
  </div>
  <nav class="sp-actions">
    <a class="sp-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="sp-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="sp-btn" href="/trfmc_instrument_superb_gallery_v1.html">Gallery</a>
    <a class="sp-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </nav>
</header>

<main class="sp-shell">
  <aside class="sp-panel">
    <h2 class="sp-title" style="font-size:15px">Correzione rotta</h2>
    <p class="sp-muted">Il precedente IDS era una preview incompleta. Questa versione introduce strumenti reali e tassonomia tecnica da applicare alle pagine leaf.</p>
    <div class="sp-kpis">
      <div class="sp-kpi"><small>V6R3</small><b>LOCKED</b></div>
      <div class="sp-kpi"><small>IFRAME</small><b>ZERO</b></div>
      <div class="sp-kpi"><small>CDN</small><b>ZERO</b></div>
      <div class="sp-kpi"><small>Scope</small><b>SERVICE</b></div>
    </div>
    <div class="sp-instrument-list">
      <a class="sp-instrument-item" href="/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html"><strong>RF PRO V4</strong><span>Baseline precedente: tecnicamente PASS, visivamente insufficiente.</span></a>
      <a class="sp-instrument-item" href="/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"><strong>Antenna/RRU V5</strong><span>Primo candidato per refit con strumenti superb.</span></a>
      <a class="sp-instrument-item" href="/trfmc_microwave_link_operations_center_v2.html"><strong>Microwave V2</strong><span>Da trasformare con LOS/Fresnel/RSL real instrument panel.</span></a>
      <a class="sp-instrument-item" href="/trfmc_fiber_fronthaul_otdr_workbench_v2.html"><strong>Fiber OTDR V2</strong><span>Da portare a OTDR workbench reale.</span></a>
    </div>
  </aside>

  <section class="sp-panel sp-main">
    <div class="sp-stage"><canvas class="sp-canvas" data-sp-scope="scene"></canvas></div>
    <div class="sp-grid2">
      <div class="sp-mini"><h3>VSA Standard</h3><canvas class="sp-canvas" data-sp-scope="spectrum"></canvas></div>
      <div class="sp-mini"><h3>VNA/Smith Standard</h3><canvas class="sp-canvas" data-sp-scope="smith"></canvas></div>
    </div>
    <div class="sp-grid2">
      <div class="sp-mini"><h3>OTDR Standard</h3><canvas class="sp-canvas" data-sp-scope="otdr"></canvas></div>
      <div class="sp-mini"><h3>RRU Port Standard</h3><canvas class="sp-canvas" data-sp-scope="rru"></canvas></div>
    </div>
  </section>

  <aside class="sp-panel">
    <h2 class="sp-title" style="font-size:15px">Requisiti nuovi</h2>
    <table class="sp-table">
      <tr><th>Gate</th><th>Richiesta</th></tr>
      <tr><td>Visuale</td><td>Oggetto tecnico riconoscibile, non rettangolo generico</td></tr>
      <tr><td>Formula</td><td>Ogni strumento deve avere spine matematica</td></tr>
      <tr><td>KPI</td><td>Misure vive o sintetiche credibili</td></tr>
      <tr><td>Layout</td><td>Cockpit, non pagina web dispersiva</td></tr>
      <tr><td>Governance</td><td>Snapshot, registry, HTTP, no CDN, no iframe</td></tr>
    </table>
    <div class="sp-mini" style="margin-top:8px">
      <h3>Prossima azione</h3>
      <p class="sp-muted">Applicare questa libreria a una pagina reale: Antenna/RRU/RET/CPRI, perché il materiale visuale e tecnico lì può produrre il salto maggiore.</p>
    </div>
  </aside>
</main>

<script src="/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.js"></script>
</body>
</html>
HTML

echo
echo "[7/10] Registro nel registry come service layer"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

for name, upgrade in [
    ("trfmc_instrument_superb_gallery_v1.html", "Instrument Superb Gallery V1"),
    ("trfmc_instrument_superb_command_deck_v1.html", "Instrument Superb Command Deck V1")
]:
    path = public / name
    txt = path.read_text(errors="ignore")
    by_url["/" + name] = {
        "class": "service",
        "name": name,
        "url": "/" + name,
        "size": path.stat().st_size,
        "domain": "instrumentation",
        "instrument_superb": True,
        "visual_refit": True,
        "canvas": True,
        "web_component": True,
        "has_iframe": False,
        "external_refs": 0,
        "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
        "upgrade": upgrade
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
reg["last_instrument_superb_system_v1_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "pages": [
        "/trfmc_instrument_superb_gallery_v1.html",
        "/trfmc_instrument_superb_command_deck_v1.html"
    ],
    "policy": "Service layer only. V6R3 and Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[8/10] Gate HTTP + sicurezza + contenuto"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.css \
    /assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.js \
    /assets/trfmc_instrument_superb/trfmc_instrument_models_v1.json \
    /trfmc_instrument_superb_manifest_v1.json \
    /trfmc_instrument_superb_gallery_v1.html \
    /trfmc_instrument_superb_command_deck_v1.html \
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

for f in "$CSS" "$JS" "$MODELS" "$PAGE" "$DECK" "$MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC_INSTRUMENT_MODELS_V1" \
  "trfmc-superb-instrument-suite" \
  "Vector Spectrum Analyzer" \
  "Vector Network Analyzer" \
  "OTDR" \
  "Microwave Link" \
  "Antenna / RRU / RET / CPRI" \
  "Data Center Rack / PDU" \
  "Oscilloscope" \
  "Phase Noise" \
  "Formula Spine" \
  "requestAnimationFrame" \
  "TRFMC Instrument Superb Gallery V1" \
  "TRFMC Instrument Superb Command Deck V1"
do
  if grep -Rqs "$token" "$CSS" "$JS" "$MODELS" "$PAGE" "$DECK" "$MANIFEST"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

cat > "$OUT/visual_assessment.json" <<JSON
{
  "status": "SUPERB_SYSTEM_V1_CREATED",
  "previous_problem": "IDS V1 was too small and visually incomplete; instruments were not real enough.",
  "fix": {
    "instrument_taxonomy": true,
    "domain_specific_canvases": 8,
    "formula_spine": true,
    "visual_donor_scan": true,
    "service_deck": true,
    "gallery": true
  },
  "next_required_step": "Apply this system to a real operational page, preferably Antenna/RRU/RET/CPRI V6 Superb, not another generic preview."
}
JSON

echo
echo "[9/10] Summary + freeze"

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
        k,v = line.split("=",1)
        sha[k] = v

protected_ok = sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER") and sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
registry_changed = sha.get("REG_SHA_BEFORE") != sha.get("REG_SHA_AFTER")
reg = json.loads(reg_path.read_text(errors="ignore"))
visual = json.loads((out / "visual_assessment.json").read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_INSTRUMENT_SUPERB_SYSTEM_V1",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "content_check_miss": miss,
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "created_pages": [
        "/trfmc_instrument_superb_gallery_v1.html",
        "/trfmc_instrument_superb_command_deck_v1.html"
    ],
    "created_assets": [
        "/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.css",
        "/assets/trfmc_instrument_superb/trfmc_instrument_superb_v1.js",
        "/assets/trfmc_instrument_superb/trfmc_instrument_models_v1.json"
    ],
    "visual_assessment": visual,
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and miss == 0 and protected_ok and registry_changed else "WARN",
    "policy": "Instrument Superb System service layer. No mutation of V6R3, Control Room, orphan files or previous operational pages."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
(out / "result.flag").write_text(summary["result"] + "\n")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_INSTRUMENT_SUPERB_SYSTEM_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_instrument_superb \
    frontend/public/trfmc_instrument_superb_gallery_v1.html \
    frontend/public/trfmc_instrument_superb_command_deck_v1.html \
    frontend/public/trfmc_instrument_superb_manifest_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_instrument_superb_system_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "[10/10] Output finale"
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== DONOR SOURCES ==="
column -t -s $'\t' "$OUT/donor_sources.tsv" | sed -n '1,40p'
echo
echo "=== VISUAL ASSESSMENT ==="
cat "$OUT/visual_assessment.json" | python3 -m json.tool
echo
echo "=== CONTENT CHECKS ==="
cat "$OUT/content_checks.txt"
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_instrument_superb_gallery_v1.html"
echo "http://127.0.0.1:5173/trfmc_instrument_superb_command_deck_v1.html"
echo "============================================================"
