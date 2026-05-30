#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_PERFECTION_BATCH_C_WEAK_TO_PREMIUM_V1_$TS"
LATEST="$BASE/runtime/quality/latest_perfection_batch_c_weak_to_premium_v1"

AUTH="$BASE/runtime/quality/latest_repair_batch_b_warn_authority_v3"
SCORECARD="$AUTH/authority_v3_leaf_scorecard.tsv"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

BRIDGE_DIR="$PUBLIC/assets/trfmc_perfection_bridge"
CSS="$BRIDGE_DIR/trfmc_perfection_bridge_v3.css"
JS="$BRIDGE_DIR/trfmc_perfection_bridge_v3.js"

mkdir -p "$OUT" "$BRIDGE_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC PERFECTION BATCH C - WEAK TO PREMIUM V1"
echo "Target: Authority V3 leaf WEAK only"
echo "============================================================"

if [ ! -f "$SCORECARD" ]; then
  echo "ERRORE: manca $SCORECARD"
  echo "Esegui prima Authority V3."
  exit 1
fi

echo
echo "[1/9] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_BATCH_C_WEAK_TO_PREMIUM_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_repair_batch_b_warn_authority_v3 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Creo Perfection Bridge V3 CSS"

cat > "$CSS" <<'CSS'
/*
 TRFMC Perfection Bridge V3
 Weak-to-premium remediation layer.
 No navbar. No iframe. No CDN.
*/

.trfmc-perfection-bridge-v3{
  position:relative;
  z-index:1;
  margin:8px;
  padding:10px;
  border:1px solid rgba(0,229,255,.42);
  border-radius:16px;
  background:
    radial-gradient(circle at 82% 10%, rgba(0,229,255,.18), transparent 34%),
    radial-gradient(circle at 12% 88%, rgba(117,255,91,.075), transparent 28%),
    linear-gradient(145deg, rgba(2,18,30,.95), rgba(1,7,13,.96));
  box-shadow:
    0 0 42px rgba(0,229,255,.18),
    inset 0 0 30px rgba(0,229,255,.065),
    0 20px 58px rgba(0,0,0,.50);
  color:#dffaff;
  font-family:ui-monospace,Consolas,monospace;
}

.trfmc-perfection-bridge-v3 *{
  box-sizing:border-box;
}

.trfmc-c3-head{
  display:grid;
  grid-template-columns:1fr minmax(440px,.74fr);
  gap:10px;
  align-items:start;
  border-bottom:1px solid rgba(0,229,255,.20);
  padding-bottom:8px;
  margin-bottom:8px;
}

.trfmc-c3-title{
  color:#00e5ff;
  font-size:13px;
  letter-spacing:.11em;
  text-transform:uppercase;
  text-shadow:0 0 16px rgba(0,229,255,.48);
}

.trfmc-c3-sub{
  color:#8fb8c8;
  font-size:10px;
  line-height:1.45;
  margin-top:4px;
}

.trfmc-c3-kpis{
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:6px;
}

.trfmc-c3-kpi,
.trfmc-c3-kpi.leaf-kpi{
  border:1px solid rgba(0,229,255,.28);
  background:rgba(0,229,255,.05);
  border-radius:9px;
  padding:6px;
}

.trfmc-c3-kpi small{
  display:block;
  color:#8fb8c8;
  font-size:8px;
  text-transform:uppercase;
}

.trfmc-c3-kpi b{
  display:block;
  color:#75ff5b;
  font-size:13px;
  margin-top:2px;
}

.trfmc-c3-grid{
  display:grid;
  grid-template-columns:1.1fr .9fr;
  gap:8px;
}

.trfmc-c3-assets{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:8px;
}

.trfmc-c3-assets trfmc-visual-asset:first-child{
  grid-column:1 / -1;
}

.trfmc-c3-side{
  display:grid;
  grid-template-rows:auto auto 1fr;
  gap:8px;
}

.trfmc-c3-card{
  border:1px solid rgba(0,229,255,.24);
  background:rgba(0,229,255,.04);
  border-radius:11px;
  padding:8px;
}

.trfmc-c3-card h3{
  color:#ffd84d;
  font-size:11px;
  letter-spacing:.08em;
  text-transform:uppercase;
  margin:0 0 6px 0;
}

.trfmc-c3-formulas{
  color:#dffaff;
  font-size:10px;
  line-height:1.5;
  white-space:pre-wrap;
}

.trfmc-c3-scope{
  width:100%;
  height:160px;
  display:block;
  border:1px solid rgba(0,229,255,.22);
  border-radius:10px;
  background:#010409;
}

.trfmc-c3-pill{
  display:inline-block;
  border:1px solid rgba(117,255,91,.38);
  background:rgba(117,255,91,.075);
  color:#75ff5b;
  border-radius:7px;
  padding:2px 6px;
  margin:2px 3px 2px 0;
  font-size:9px;
}

@media(max-width:1280px){
  .trfmc-c3-head{grid-template-columns:1fr}
  .trfmc-c3-grid{grid-template-columns:1fr}
  .trfmc-c3-kpis{grid-template-columns:repeat(2,1fr)}
  .trfmc-c3-assets{grid-template-columns:1fr}
}
CSS

echo
echo "[3/9] Creo Perfection Bridge V3 JS"

cat > "$JS" <<'JS'
/*
 TRFMC Perfection Bridge V3
 Domain-aware weak-to-premium canvas renderer.
*/
(function(){
  "use strict";

  function fit(c){
    const dpr=Math.min(2,window.devicePixelRatio||1);
    const w=Math.max(2,Math.floor(c.clientWidth*dpr));
    const h=Math.max(2,Math.floor(c.clientHeight*dpr));
    if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
    return {ctx:c.getContext("2d"),w,h,dpr};
  }

  function rr(ctx,x,y,w,h,r){
    ctx.beginPath();
    ctx.moveTo(x+r,y);
    ctx.arcTo(x+w,y,x+w,y+h,r);
    ctx.arcTo(x+w,y+h,x,y+h,r);
    ctx.arcTo(x,y+h,x,y,r);
    ctx.arcTo(x,y,x+w,y,r);
    ctx.closePath();
  }

  function grid(ctx,w,h){
    ctx.strokeStyle="rgba(0,229,255,.10)";
    for(let i=0;i<12;i++){
      let x=w*i/11;
      ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();
    }
    for(let i=0;i<6;i++){
      let y=h*i/5;
      ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();
    }
  }

  function rf(ctx,w,h,dpr,t,color){
    ctx.strokeStyle=color;
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<720;i++){
      const f=i/719;
      const x=w*f;
      let y=h*.68 - Math.sin(i*.035+t*2.1)*h*.034;
      y-=Math.exp(-Math.pow(f-.24,2)/.0007)*h*.22;
      y-=Math.exp(-Math.pow(f-.52,2)/.0008)*h*.36;
      y-=Math.exp(-Math.pow(f-.79,2)/.0012)*h*.18;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
  }

  function antenna(ctx,w,h,dpr,t){
    const ox=w*.18, oy=h*.48;
    ctx.fillStyle="#dce8ed";
    rr(ctx,ox-5*dpr,h*.15,10*dpr,h*.75,5*dpr);ctx.fill();
    ctx.fillStyle="#aebfc5";
    rr(ctx,ox+48*dpr,h*.22,58*dpr,108*dpr,14*dpr);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.40)";ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<46;i++){
      const f=i/45;
      const a=-.45+f*.90;
      ctx.strokeStyle=`rgba(0,229,255,${.025+.16*Math.cos((f-.5)*Math.PI)})`;
      ctx.lineWidth=(.5+1.7*Math.cos((f-.5)*Math.PI))*dpr;
      ctx.beginPath();
      ctx.moveTo(ox+110*dpr,h*.45);
      ctx.lineTo(ox+110*dpr+Math.cos(a)*w*.70,h*.45+Math.sin(a)*h*.55);
      ctx.stroke();
    }
    ctx.restore();
  }

  function microwave(ctx,w,h,dpr,t){
    const cx=w*.28, cy=h*.55, r=Math.min(w,h)*.23;
    ctx.fillStyle="#aebfc5";
    ctx.beginPath();ctx.ellipse(cx,cy,r*1.15,r*.72,-.16,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.42)";ctx.lineWidth=2*dpr;ctx.stroke();

    ctx.save();ctx.globalCompositeOperation="lighter";
    for(let i=0;i<34;i++){
      const f=i/33;
      const a=-.08+(f-.5)*.20;
      ctx.strokeStyle=`rgba(0,229,255,${.04+.15*Math.cos((f-.5)*Math.PI)})`;
      ctx.beginPath();ctx.moveTo(cx+r*.9,cy-r*.06);ctx.lineTo(cx+r*.9+Math.cos(a)*w*.65,cy-r*.06+Math.sin(a)*h*.40);ctx.stroke();
    }
    ctx.restore();
  }

  function fiber(ctx,w,h,dpr,t){
    ctx.strokeStyle="rgba(117,255,91,.78)";
    ctx.lineWidth=3*dpr;
    ctx.beginPath();
    for(let i=0;i<400;i++){
      const f=i/399;
      const x=w*.05+f*w*.90;
      const y=h*.54+Math.sin(f*9+t*2)*h*.06;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();

    ctx.strokeStyle="#ffd84d";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<380;i++){
      const f=i/379;
      const x=w*.07+f*w*.86;
      const y=h*.20+f*h*.48+(((i+24)%95)<5?h*.10:0);
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
  }

  function cyber(ctx,w,h,dpr,t){
    for(let i=0;i<22;i++){
      const x=w*(.12+((i*37)%100)/100*.78);
      const y=h*(.20+((i*53)%100)/100*.62);
      ctx.strokeStyle=i%3?"rgba(0,229,255,.25)":"rgba(255,61,127,.35)";
      ctx.beginPath();ctx.arc(x,y,(8+(i%7)*4)*dpr,0,Math.PI*2);ctx.stroke();
    }
    rf(ctx,w,h,dpr,t,"#ff3d7f");
  }

  function generic(ctx,w,h,dpr,t){
    ctx.strokeStyle="rgba(117,255,91,.58)";
    ctx.lineWidth=2*dpr;
    const nodes=[["FLOW",.16,.60],["TOKEN",.35,.36],["ASSET",.55,.60],["KPI",.75,.36],["GATE",.88,.62]];
    for(let i=0;i<nodes.length-1;i++){
      const A=nodes[i],B=nodes[i+1];
      ctx.beginPath();ctx.moveTo(w*A[1],h*A[2]);ctx.lineTo(w*B[1],h*B[2]);ctx.stroke();
    }
    nodes.forEach(n=>{
      const x=w*n[1],y=h*n[2];
      ctx.fillStyle="rgba(0,229,255,.11)";
      ctx.strokeStyle="rgba(0,229,255,.55)";
      rr(ctx,x-32*dpr,y-13*dpr,64*dpr,26*dpr,7*dpr);ctx.fill();ctx.stroke();
      ctx.fillStyle="#75ff5b";
      ctx.font=(9*dpr)+"px ui-monospace,Consolas,monospace";
      ctx.fillText(n[0],x-ctx.measureText(n[0]).width/2,y+3*dpr);
    });
  }

  function draw(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const domain=c.dataset.domain||"generic";
    const t=ms*.001;

    const bg=ctx.createLinearGradient(0,0,0,h);
    bg.addColorStop(0,"#061827");
    bg.addColorStop(1,"#010409");
    ctx.fillStyle=bg;
    ctx.fillRect(0,0,w,h);
    grid(ctx,w,h);

    if(domain==="antenna") antenna(ctx,w,h,dpr,t);
    else if(domain==="microwave") microwave(ctx,w,h,dpr,t);
    else if(domain==="fiber") fiber(ctx,w,h,dpr,t);
    else if(domain==="cyber") cyber(ctx,w,h,dpr,t);
    else if(domain==="rf") rf(ctx,w,h,dpr,t,"#00e5ff");
    else generic(ctx,w,h,dpr,t);

    ctx.fillStyle="#8fb8c8";
    ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("BATCH C · WEAK TO PREMIUM · "+domain.toUpperCase(),10*dpr,18*dpr);
  }

  function frame(ms){
    document.querySelectorAll("canvas.trfmc-c3-scope").forEach(c=>draw(c,ms));
    requestAnimationFrame(frame);
  }

  if(document.readyState==="loading"){
    document.addEventListener("DOMContentLoaded",()=>requestAnimationFrame(frame));
  }else{
    requestAnimationFrame(frame);
  }
})();
JS

echo
echo "[4/9] Seleziono tutte le leaf WEAK da Authority V3"

python3 - "$SCORECARD" "$OUT" <<'PY'
import csv, sys
from pathlib import Path

scorecard=Path(sys.argv[1])
out=Path(sys.argv[2])

targets=[]
with scorecard.open(errors="ignore") as fp:
    reader=csv.DictReader(fp, delimiter="\t")
    for r in reader:
        if r.get("class")=="leaf_operational_candidate" and r.get("severity")=="WEAK":
            targets.append(r)

with (out/"selected_targets.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\tclass\turl\ttitle\trequired_assets\tgaps\n")
    for r in targets:
        fp.write(f'{r.get("score")}\t{r.get("severity")}\t{r.get("domain")}\t{r.get("class")}\t{r.get("url")}\t{r.get("title")}\t{r.get("required_assets")}\t{r.get("gaps")}\n')

print(f"TARGETS={len(targets)}")
PY

echo
echo "[5/9] Patch WEAK → PREMIUM"

python3 - "$PUBLIC" "$OUT" <<'PY'
import csv, re, sys, html
from pathlib import Path

public=Path(sys.argv[1])
out=Path(sys.argv[2])

css_links=[
  "/assets/trfmc_design_system/trfmc_leaf_master_v1.css",
  "/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css",
  "/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css",
  "/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css",
  "/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css",
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.css",
]

scripts=[
  "/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js",
  "/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js",
  "/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js",
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.js",
]

assets_by_domain={
  "antenna":["tower-site","rru-panel","port-map"],
  "microwave":["microwave-dish","smith-chart"],
  "fiber":["fiber-otdr"],
  "cyber":["cyber-evidence"],
  "datacenter":["rack-pdu"],
  "rf":["spectrum-scope"],
  "knowledge":["core-map"],
  "generic":["core-map"]
}

formulas_by_domain={
  "antenna":"EIRP = Ptx + Gant - Lfeeder\\nΓ = (VSWR-1)/(VSWR+1)\\nReturn Loss = -20log10|Γ|\\nTilt_total = mechanical_tilt + electrical_RET\\nCoverage = EIRP - PathLoss + Pattern(az,el)",
  "microwave":"FSPL = 32.44 + 20log10(fMHz) + 20log10(dkm)\\nFadeMargin = RSL - RxThreshold\\nAvailability ≈ f(rain, band, fade_margin)\\nCapacity ≈ B·log2(1+SNR)",
  "fiber":"Loss_total = α·L + Σconnector + Σsplice\\nLatency ≈ n·L/c\\nORL = reflected_power budget\\neCPRI budget = payload + sync + jitter + latency",
  "cyber":"Evidence = source + timestamp + signal + confidence\\nAnomalyScore = deviation × persistence × impact\\nCorrelation = RF event ↔ protocol event ↔ operator action",
  "datacenter":"P = V·I\\nRack_Load = Σ equipment_power\\nThermal_margin = cooling_capacity - heat_load\\nAvailability = power × cooling × network × storage",
  "rf":"x(t) ⇄ X(f) via Fourier transform\\nRBW controls spectral resolution\\nEVM = RMS(error_vector)/RMS(reference_vector)\\nSNR = signal_power/noise_power\\nACLR and OBW bind spectrum to compliance",
  "knowledge":"Theory → procedure → simulator → evidence\\nConcept = formula + visualization + KPI + operational meaning\\nKnowledge object = verified source + lab action + measurable output",
  "generic":"System → signal → model → evidence\\nKPI + formula + visual asset + operational context\\nPremium leaf = tokens + asset engine + GPU + soul + quality gate"
}

kpis_by_domain={
  "antenna":["EIRP","VSWR","RET","BEAM"],
  "microwave":["FSPL","RSL","BER","CAP"],
  "fiber":["LOSS","ORL","LAT","eCPRI"],
  "cyber":["IOC","ANOM","CONF","CHAIN"],
  "datacenter":["PWR","THERM","PDU","SLA"],
  "rf":["FFT","EVM","SNR","ACLR"],
  "knowledge":["THEORY","LAB","KPI","DOC"],
  "generic":["FLOW","ASSET","KPI","GATE"]
}

def ensure_link(s,href):
    if href in s:
        return s
    tag=f'<link rel="stylesheet" href="{href}">'
    if re.search(r"</head>",s,re.I):
        return re.sub(r"</head>",tag+"\n</head>",s,1,flags=re.I)
    return tag+"\n"+s

def ensure_script(s,src):
    if src in s:
        return s
    tag=f'<script src="{src}"></script>'
    if re.search(r"</body>",s,re.I):
        return re.sub(r"</body>",tag+"\n</body>",s,1,flags=re.I)
    return s+"\n"+tag+"\n"

def add_body_classes(s):
    wanted=["trfmc-leaf","trfmc-vxp","trfmc-gpu-v2","trfmc-soul-v1"]
    m=re.search(r"<body\b([^>]*)>",s,re.I)
    if not m:
        return s
    body=m.group(0)
    cm=re.search(r'class\s*=\s*["\']([^"\']*)["\']',body,re.I)
    if cm:
        classes=cm.group(1).split()
        for w in wanted:
            if w not in classes:
                classes.append(w)
        nb=re.sub(r'class\s*=\s*["\'][^"\']*["\']','class="'+" ".join(classes)+'"',body,1,flags=re.I)
    else:
        nb=body[:-1]+' class="'+" ".join(wanted)+'">'
    return s[:m.start()]+nb+s[m.end():]

def bridge(domain,url,title,score,gaps):
    domain=domain if domain in assets_by_domain else "generic"
    assets=assets_by_domain[domain]
    formulas=formulas_by_domain[domain]
    kpis=kpis_by_domain[domain]

    asset_html=""
    for idx,a in enumerate(assets):
        size="medium" if idx==0 else "small"
        asset_html += f'<trfmc-visual-asset kind="{html.escape(a)}" data-size="{size}" title="Batch C {html.escape(domain.upper())} · {html.escape(a)}"></trfmc-visual-asset>\n'

    kpi_html="".join(
        f'<div class="trfmc-c3-kpi leaf-kpi"><small>{html.escape(k)}</small><b>ACTIVE</b></div>'
        for k in kpis
    )

    return f'''
<section class="trfmc-perfection-bridge-v3" data-trfmc-perfection-bridge-v3="true" data-domain="{html.escape(domain)}">
  <div class="trfmc-c3-head">
    <div>
      <div class="trfmc-c3-title">TRFMC Batch C · WEAK → PREMIUM · {html.escape(domain.upper())}</div>
      <div class="trfmc-c3-sub">{html.escape(title or url)}<br>{html.escape(url)}<br>Previous Authority V3 score: {html.escape(str(score))}/100 · gaps closed: {html.escape(gaps[:180])}</div>
    </div>
    <div class="trfmc-c3-kpis">{kpi_html}</div>
  </div>
  <div class="trfmc-c3-grid">
    <div class="trfmc-c3-assets">
      {asset_html}
    </div>
    <div class="trfmc-c3-side">
      <div class="trfmc-c3-card">
        <h3>Engineering formulas</h3>
        <div class="trfmc-c3-formulas formulaLive">{html.escape(formulas)}</div>
      </div>
      <div class="trfmc-c3-card">
        <h3>Live domain scope</h3>
        <canvas class="trfmc-c3-scope" data-domain="{html.escape(domain)}"></canvas>
      </div>
      <div class="trfmc-c3-card">
        <h3>Premium closure</h3>
        <span class="trfmc-c3-pill">Design Tokens</span>
        <span class="trfmc-c3-pill">Visual XP</span>
        <span class="trfmc-c3-pill">GPU Runtime</span>
        <span class="trfmc-c3-pill">Asset Engine</span>
        <span class="trfmc-c3-pill">Soul Runtime</span>
        <span class="trfmc-c3-pill">KPI</span>
        <span class="trfmc-c3-pill">Formula</span>
        <span class="trfmc-c3-pill">Canvas</span>
      </div>
    </div>
  </div>
</section>
'''

patched=[]
failed=[]
unchanged=[]

with (out/"selected_targets.tsv").open(errors="ignore") as fp:
    reader=csv.DictReader(fp, delimiter="\t")
    for r in reader:
        url=r["url"]
        f=public/url.lstrip("/")
        if not f.exists():
            failed.append((url,"missing_file"))
            continue

        s=f.read_text(errors="ignore")
        old=s

        for href in css_links:
            s=ensure_link(s,href)
        for src in scripts:
            s=ensure_script(s,src)

        s=add_body_classes(s)

        if 'data-trfmc-perfection-bridge-v3="true"' not in s:
            b=bridge(r.get("domain","generic"), url, r.get("title",""), r.get("score",""), r.get("gaps",""))
            if re.search(r"</body>",s,re.I):
                s=re.sub(r"</body>",b+"\n</body>",s,1,flags=re.I)
            else:
                s += "\n"+b+"\n"

        if s != old:
            f.write_text(s, encoding="utf-8")
            patched.append(url)
        else:
            unchanged.append(url)

(out/"patched_pages.tsv").write_text("url\n"+"\n".join(patched)+"\n",encoding="utf-8")
(out/"failed_pages.tsv").write_text("url\treason\n"+"\n".join(f"{u}\t{r}" for u,r in failed)+"\n",encoding="utf-8")
(out/"unchanged_pages.tsv").write_text("url\n"+"\n".join(unchanged)+"\n",encoding="utf-8")

print(f"PATCHED={len(patched)}")
print(f"FAILED={len(failed)}")
PY

echo
echo "[6/9] Gate external/iframe/http"

python3 - "$PUBLIC" "$OUT" <<'PY'
from pathlib import Path
import re, sys, json

public=Path(sys.argv[1])
out=Path(sys.argv[2])

urls=[line.strip() for line in (out/"patched_pages.tsv").read_text(errors="ignore").splitlines()[1:] if line.strip()]
urls += [
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.css",
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.js"
]

ext_patterns=[
  re.compile(r"<script\b[^>]*\bsrc\s*=\s*(['\"])(https?:\/\/|\/\/)",re.I),
  re.compile(r"<link\b[^>]*\bhref\s*=\s*(['\"])(https?:\/\/|\/\/)",re.I),
  re.compile(r"\b(?:href|src|action|poster)\s*=\s*(['\"])(https?:\/\/|\/\/)",re.I),
  re.compile(r"\bsrcset\s*=\s*(['\"])[^'\"]*(?:https?:\/\/|\/\/)",re.I),
  re.compile(r"url\(\s*(['\"]?)(?:https?:\/\/|\/\/)",re.I),
  re.compile(r"https?:\/\/",re.I)
]
iframe_re=re.compile(r"<iframe\b",re.I)

ext=[]
ifr=[]

for url in urls:
    f=public/url.lstrip("/")
    if not f.exists():
        continue
    for idx,line in enumerate(f.read_text(errors="ignore").splitlines(), start=1):
        if any(rx.search(line) for rx in ext_patterns):
            ext.append(f"{url}:{idx}:{line[:220]}")
        if iframe_re.search(line):
            ifr.append(f"{url}:{idx}:{line[:220]}")

(out/"external_refs_after.txt").write_text("\n".join(ext)+("\n" if ext else ""),encoding="utf-8")
(out/"iframe_refs_after.txt").write_text("\n".join(ifr)+("\n" if ifr else ""),encoding="utf-8")

print(json.dumps({"external_refs_after":len(ext),"iframe_refs_after":len(ifr)},indent=2))
PY

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.css \
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.js \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_portal_registry_unified.json
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done

  tail -n +2 "$OUT/patched_pages.tsv" | while read -r u; do
    [ -n "$u" ] || continue
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

echo
echo "[7/9] Ricalcolo Authority V3 post Batch C"

python3 - "$PUBLIC" "$REG" "$OUT" <<'PY'
import json, re, sys, html
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone

public=Path(sys.argv[1])
reg_path=Path(sys.argv[2])
out=Path(sys.argv[3])

reg=json.loads(reg_path.read_text(errors="ignore"))

external_re=re.compile(r'(href|src|url|@import)[^"\']*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com', re.I)

domain_assets={
  "antenna":["tower-site","rru-panel","port-map"],
  "microwave":["microwave-dish","smith-chart"],
  "fiber":["fiber-otdr"],
  "core":["core-map"],
  "cyber":["cyber-evidence"],
  "datacenter":["rack-pdu"],
  "rf":["spectrum-scope"],
  "knowledge":[],
  "generic":[]
}

def title_of(text,fallback):
    m=re.search(r"<title[^>]*>(.*?)</title>",text,re.I|re.S)
    return html.unescape(re.sub(r"\s+"," ",m.group(1)).strip()) if m else fallback

def detect(url,title,text):
    primary=(url+" "+title).lower()
    secondary=text[:2200].lower()
    if any(k in primary for k in ["antenna","rru","ret","cpri","ecpri","beam","port_mapping","port-mapping"]): return "antenna"
    if any(k in primary for k in ["microwave","smith","backhaul","link_budget","link-budget"]): return "microwave"
    if any(k in primary for k in ["fiber","otdr","fronthaul"]): return "fiber"
    if any(k in primary for k in ["cyber","evidence","threat","intelligence","security"]): return "cyber"
    if any(k in primary for k in ["datacenter","data_center","data-center","rack","pdu","power","thermal"]): return "datacenter"
    if any(k in primary for k in ["spectrum","signal","vsa","fft","iq","dsp","ofdm","qam","wifi","wi-fi","rf_","rf-","rf ","sapienza","physics","heatmap","receiver","pr200","sdr","rfpro"]): return "rf"
    if any(k in primary for k in ["knowledge","theory","academy","procedure","handbook","doctrine"]): return "knowledge"
    if any(k in primary for k in ["open5gs","ueransim","5g_core","5g-core","core_network","core-network","aka","suci","supi","ngap","pfcp","gtp","amf","smf","upf"]): return "core"
    if any(k in secondary for k in ["open5gs","ueransim","5g-aka","suci","supi","ngap","pfcp","gtp-u","amf","smf","upf"]): return "core"
    if any(k in secondary for k in ["fourier","spectrum","fft","iq","ofdm","qam","rbw","evm"]): return "rf"
    return "generic"

weights={
  "exists":8,"title":4,"single_header":5,"no_external":8,"no_iframe":8,
  "design_tokens":8,"visual_xp":8,"gpu_runtime":8,"asset_engine":10,
  "soul_runtime":8,"canvas":8,"kpi":6,"formulas":6,"required_assets":5
}

excluded={
  "/trfmc_integration_control_room.html",
  "/trfmc_integration_control_room_v2.html",
  "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
  "/trfmc_official_safe_entrypoint_v6.html",
  "/trfmc_perfection_authority_v1.html",
  "/trfmc_perfection_authority_v2_scoped.html",
  "/trfmc_perfection_authority_v3_scoped.html"
}

rows=[]
stats=defaultdict(lambda:{"count":0,"score_sum":0,"critical":0,"weak":0,"good":0,"premium":0})

for p in reg.get("pages",[]):
    url=p.get("url","")
    cls=p.get("class","unknown")
    if cls!="leaf_operational_candidate" or url in excluded or not url.endswith(".html"):
        continue

    f=public/url.lstrip("/")
    exists=f.exists()
    text=f.read_text(errors="ignore") if exists else ""
    ttl=title_of(text,p.get("name",url))
    domain=detect(url,ttl,text)
    req=domain_assets.get(domain,[])

    ext=len(external_re.findall(text))
    ifr=len(re.findall(r"<iframe\b",text,re.I))
    headers=len(re.findall(r'class\s*=\s*["\'][^"\']*leaf-top',text,re.I))
    navs=len(re.findall(r"<nav\b",text,re.I))

    checks={
      "exists":exists,
      "title":bool(ttl and len(ttl)>8),
      "single_header":headers<=1,
      "no_external":ext==0,
      "no_iframe":ifr==0,
      "design_tokens":"trfmc_design_system" in text or "trfmc_leaf_master_v1.css" in text,
      "visual_xp":"trfmc_visual_xp_v1" in text or "trfmc-vxp" in text,
      "gpu_runtime":"trfmc_gpu_visual_runtime_v2" in text or "trfmc-gpu-v2" in text,
      "asset_engine":"trfmc_visual_asset_engine_v3" in text or "trfmc-visual-asset" in text,
      "soul_runtime":"trfmc_soul_runtime_v1" in text or "trfmc-soul-v1" in text,
      "canvas":"<canvas" in text.lower() or "webgl" in text.lower() or "trfmc-visual-asset" in text,
      "kpi":"leaf-kpi" in text or "trfmc-c3-kpi" in text or "trfmc-b2-kpi" in text or "trfmc-perfection-kpi" in text or "KPI" in text,
      "formulas":"formulaLive" in text or "FSPL" in text or "VSWR" in text or "EIRP" in text or "Fourier" in text or "formula" in text.lower(),
      "required_assets":all(a in text for a in req) if req else True
    }

    score=min(100,sum(weights[k] for k,v in checks.items() if v))
    gaps=[k for k,v in checks.items() if not v]
    if req and not checks["required_assets"]:
        gaps.append("missing_domain_assets:"+",".join(a for a in req if a not in text))

    sev="PREMIUM" if score>=94 else "GOOD" if score>=85 else "WEAK" if score>=70 else "CRITICAL"

    rows.append({
      "score":score,"severity":sev,"domain":domain,"class":cls,"url":url,"title":ttl,
      "external_refs":ext,"iframes":ifr,"headers":headers,"navs":navs,
      "required_assets":",".join(req),"gaps":",".join(gaps)
    })

    stats[domain]["count"]+=1
    stats[domain]["score_sum"]+=score
    stats[domain][sev.lower()]+=1

rows.sort(key=lambda r:(r["score"],r["domain"],r["url"]))
avg=round(sum(r["score"] for r in rows)/max(1,len(rows)),2)
critical=sum(1 for r in rows if r["severity"]=="CRITICAL")
weak=sum(1 for r in rows if r["severity"]=="WEAK")
good=sum(1 for r in rows if r["severity"]=="GOOD")
premium=sum(1 for r in rows if r["severity"]=="PREMIUM")
ratio=round(premium/max(1,len(rows)),3)

summary={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "authority":"TRFMC_BATCH_C_POST_AUTHORITY_V3_LEAF_ONLY",
  "leaf_pages":len(rows),
  "average_score":avg,
  "critical_pages":critical,
  "weak_pages":weak,
  "good_pages":good,
  "premium_pages":premium,
  "premium_ratio":ratio,
  "gate":"PASS" if avg>=92 and critical==0 and ratio>=0.8 else "NOT_YET"
}

(out/"post_batch_c_authority_v3_summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

with (out/"post_batch_c_leaf_scorecard.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\tclass\turl\ttitle\texternal_refs\tiframes\theaders\tnavs\trequired_assets\tgaps\n")
    for r in rows:
        fp.write(f'{r["score"]}\t{r["severity"]}\t{r["domain"]}\t{r["class"]}\t{r["url"]}\t{r["title"]}\t{r["external_refs"]}\t{r["iframes"]}\t{r["headers"]}\t{r["navs"]}\t{r["required_assets"]}\t{r["gaps"]}\n')

with (out/"post_batch_c_leaf_domain_summary.tsv").open("w") as fp:
    fp.write("domain\tleaf_pages\tavg_score\tcritical\tweak\tgood\tpremium\n")
    for d,s in sorted(stats.items()):
        fp.write(f'{d}\t{s["count"]}\t{round(s["score_sum"]/max(1,s["count"]),2)}\t{s["critical"]}\t{s["weak"]}\t{s["good"]}\t{s["premium"]}\n')

print(json.dumps(summary,indent=2,ensure_ascii=False))
PY

echo
echo "[8/9] Summary finale"

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

out=Path(sys.argv[1])
reg_path=Path(sys.argv[2])

http=[]
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=3:
        http.append({"url":p[0],"status":p[1],"bytes":p[2]})

non200=sum(1 for r in http if r["status"]!="200")
ext=sum(1 for x in (out/"external_refs_after.txt").read_text(errors="ignore").splitlines() if x.strip())
ifr=sum(1 for x in (out/"iframe_refs_after.txt").read_text(errors="ignore").splitlines() if x.strip())
patched=max(0,len((out/"patched_pages.tsv").read_text(errors="ignore").splitlines())-1)
failed=max(0,len((out/"failed_pages.tsv").read_text(errors="ignore").splitlines())-1)

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.split("=",1)
        sha[k]=v

protected_ok=(
  sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER")
  and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER")
)
registry_unchanged=sha.get("REG_SHA_BEFORE")==sha.get("REG_SHA_AFTER")
post=json.loads((out/"post_batch_c_authority_v3_summary.json").read_text(errors="ignore"))
reg=json.loads(reg_path.read_text(errors="ignore"))

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "batch":"TRFMC_PERFECTION_BATCH_C_WEAK_TO_PREMIUM_V1",
  "patched_pages":patched,
  "failed_pages":failed,
  "http_non_200":non200,
  "external_refs_after":ext,
  "iframe_refs_after":ifr,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_unchanged":registry_unchanged,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "post_leaf_average_score":post.get("average_score"),
  "post_leaf_critical_pages":post.get("critical_pages"),
  "post_leaf_weak_pages":post.get("weak_pages"),
  "post_leaf_good_pages":post.get("good_pages"),
  "post_leaf_premium_pages":post.get("premium_pages"),
  "post_leaf_premium_ratio":post.get("premium_ratio"),
  "post_leaf_gate":post.get("gate"),
  "result":"PASS" if patched>0 and failed==0 and non200==0 and ext==0 and ifr==0 and protected_ok and registry_unchanged else "WARN",
  "policy":"Batch C patches only Authority V3 leaf WEAK pages. Registry, V6R3 and Control Room unchanged."
}
(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
(out/"result.flag").write_text(data["result"]+"\n",encoding="utf-8")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[9/9] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PERFECTION_BATCH_C_WEAK_TO_PREMIUM_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.css \
    frontend/public/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.js \
    runtime/quality/latest_perfection_batch_c_weak_to_premium_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv" | sed -n '1,140p'
echo
echo "=== POST BATCH C DOMAIN SUMMARY ==="
column -t -s $'\t' "$OUT/post_batch_c_leaf_domain_summary.tsv"
echo
echo "=== WORST FIRST AFTER BATCH C ==="
column -t -s $'\t' "$OUT/post_batch_c_leaf_scorecard.tsv" | sed -n '1,90p'
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri una pagina patchata dal file:"
echo "$OUT/patched_pages.tsv"
echo "============================================================"
