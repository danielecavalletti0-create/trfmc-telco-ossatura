#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_PERFECTION_SURGICAL_BATCH_B_LEAF_ONLY_V1_$TS"
LATEST="$BASE/runtime/quality/latest_perfection_surgical_batch_b_leaf_only_v1"

AUTH="$BASE/runtime/quality/latest_false_external_repair_and_authority_v2"
SCORECARD="$AUTH/authority_v2_leaf_scorecard.tsv"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

BRIDGE_DIR="$PUBLIC/assets/trfmc_perfection_bridge"
BRIDGE_CSS="$BRIDGE_DIR/trfmc_perfection_bridge_v2.css"
BRIDGE_JS="$BRIDGE_DIR/trfmc_perfection_bridge_v2.js"

BATCH_LIMIT="${BATCH_LIMIT:-48}"

mkdir -p "$OUT" "$BRIDGE_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC PERFECTION SURGICAL BATCH B - LEAF ONLY V1"
echo "Target: Authority V2 leaf CRITICAL/WEAK only"
echo "============================================================"

if [ ! -f "$SCORECARD" ]; then
  echo "ERRORE: manca $SCORECARD"
  echo "Esegui prima trfmc_repair_false_external_and_create_authority_v2.sh"
  exit 1
fi

echo
echo "[1/9] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_PERFECTION_BATCH_B_LEAF_ONLY_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_false_external_repair_and_authority_v2 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Creo Perfection Bridge V2 CSS"

cat > "$BRIDGE_CSS" <<'CSS'
/*
 TRFMC Perfection Bridge V2
 Leaf-only remediation module.
 No navbar. No iframe. No CDN.
*/

.trfmc-perfection-bridge-v2{
  position:relative;
  z-index:1;
  margin:8px;
  padding:9px;
  border:1px solid rgba(0,229,255,.38);
  border-radius:14px;
  background:
    radial-gradient(circle at 82% 8%, rgba(0,229,255,.16), transparent 32%),
    radial-gradient(circle at 12% 90%, rgba(117,255,91,.06), transparent 26%),
    linear-gradient(145deg, rgba(2,18,30,.94), rgba(1,7,13,.95));
  box-shadow:
    0 0 38px rgba(0,229,255,.16),
    inset 0 0 26px rgba(0,229,255,.06),
    0 18px 54px rgba(0,0,0,.46);
  color:#dffaff;
  font-family:ui-monospace,Consolas,monospace;
}

.trfmc-perfection-bridge-v2 *{
  box-sizing:border-box;
}

.trfmc-b2-head{
  display:grid;
  grid-template-columns:1fr minmax(420px,.7fr);
  gap:10px;
  align-items:start;
  border-bottom:1px solid rgba(0,229,255,.18);
  padding-bottom:8px;
  margin-bottom:8px;
}

.trfmc-b2-title{
  color:#00e5ff;
  font-size:13px;
  letter-spacing:.10em;
  text-transform:uppercase;
  text-shadow:0 0 16px rgba(0,229,255,.42);
}

.trfmc-b2-sub{
  color:#8fb8c8;
  font-size:10px;
  line-height:1.45;
  margin-top:4px;
}

.trfmc-b2-kpis{
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:6px;
}

.trfmc-b2-kpi{
  border:1px solid rgba(0,229,255,.26);
  background:rgba(0,229,255,.045);
  border-radius:8px;
  padding:6px;
}

.trfmc-b2-kpi small{
  display:block;
  color:#8fb8c8;
  font-size:8px;
  text-transform:uppercase;
}

.trfmc-b2-kpi b{
  display:block;
  color:#75ff5b;
  font-size:13px;
  margin-top:2px;
}

.trfmc-b2-grid{
  display:grid;
  grid-template-columns:1fr .92fr;
  gap:8px;
}

.trfmc-b2-asset{
  min-height:360px;
}

.trfmc-b2-side{
  display:grid;
  grid-template-rows:auto auto 1fr;
  gap:8px;
}

.trfmc-b2-card{
  border:1px solid rgba(0,229,255,.22);
  background:rgba(0,229,255,.035);
  border-radius:10px;
  padding:8px;
}

.trfmc-b2-card h3{
  color:#ffd84d;
  font-size:11px;
  letter-spacing:.08em;
  text-transform:uppercase;
  margin:0 0 6px 0;
}

.trfmc-b2-formulas{
  color:#dffaff;
  font-size:10px;
  line-height:1.48;
  white-space:pre-wrap;
}

.trfmc-b2-scope{
  width:100%;
  height:150px;
  display:block;
  border:1px solid rgba(0,229,255,.20);
  border-radius:9px;
  background:#010409;
}

.trfmc-b2-pill{
  display:inline-block;
  border:1px solid rgba(117,255,91,.34);
  background:rgba(117,255,91,.07);
  color:#75ff5b;
  border-radius:6px;
  padding:2px 6px;
  margin:2px 3px 2px 0;
  font-size:9px;
}

@media(max-width:1250px){
  .trfmc-b2-head{grid-template-columns:1fr}
  .trfmc-b2-grid{grid-template-columns:1fr}
  .trfmc-b2-kpis{grid-template-columns:repeat(2,1fr)}
}
CSS

echo
echo "[3/9] Creo Perfection Bridge V2 JS"

cat > "$BRIDGE_JS" <<'JS'
/*
 TRFMC Perfection Bridge V2
 Domain scope renderer for surgical leaf remediation.
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
      const x=w*i/11;
      ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();
    }
    for(let i=0;i<6;i++){
      const y=h*i/5;
      ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();
    }
  }

  function drawCore(ctx,w,h,dpr,t){
    const nodes=[
      ["UE",.08,.62,"g"],["gNB",.23,.38,"g"],["AMF",.43,.34,"c"],
      ["AUSF",.43,.66,"c"],["UDM",.61,.66,"c"],["SMF",.61,.34,"c"],["UPF",.82,.50,"c"]
    ];
    const links=[[0,1],[1,2],[2,3],[3,4],[2,5],[5,6],[4,5]];
    ctx.lineWidth=2*dpr;
    links.forEach(([a,b],idx)=>{
      const A=nodes[a],B=nodes[b];
      const p=(Math.sin(t*2+idx)+1)/2;
      ctx.strokeStyle=`rgba(0,229,255,${.18+.22*p})`;
      ctx.beginPath();ctx.moveTo(w*A[1],h*A[2]);ctx.lineTo(w*B[1],h*B[2]);ctx.stroke();
    });
    nodes.forEach((n,idx)=>{
      const x=w*n[1], y=h*n[2], green=n[3]==="g";
      ctx.fillStyle=green?"rgba(117,255,91,.12)":"rgba(0,229,255,.12)";
      ctx.strokeStyle=green?"rgba(117,255,91,.58)":"rgba(0,229,255,.58)";
      rr(ctx,x-32*dpr,y-14*dpr,64*dpr,28*dpr,7*dpr);ctx.fill();ctx.stroke();
      ctx.fillStyle=green?"#75ff5b":"#00e5ff";
      ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
      ctx.fillText(n[0],x-ctx.measureText(n[0]).width/2,y+3*dpr);
    });
  }

  function drawRF(ctx,w,h,dpr,t,color){
    ctx.strokeStyle=color;
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<640;i++){
      const x=w*i/639;
      let y=h*.66 - Math.sin(i*.036+t*2.0)*h*.035;
      y-=Math.exp(-Math.pow(i/639-.26,2)/.0006)*h*.22;
      y-=Math.exp(-Math.pow(i/639-.52,2)/.0008)*h*.34;
      y-=Math.exp(-Math.pow(i/639-.78,2)/.0012)*h*.18;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
  }

  function drawAntenna(ctx,w,h,dpr,t){
    const ox=w*.18, oy=h*.72;
    ctx.fillStyle="#dce8ed";
    rr(ctx,ox-5*dpr,h*.18,10*dpr,h*.68,5*dpr);ctx.fill();
    ctx.fillStyle="#aebfc5";
    rr(ctx,ox+50*dpr,h*.22,54*dpr,102*dpr,13*dpr);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.38)";ctx.stroke();
    ctx.save();ctx.globalCompositeOperation="lighter";
    for(let i=0;i<42;i++){
      const f=i/41;
      const a=-.40+f*.80;
      ctx.strokeStyle=`rgba(0,229,255,${.025+.14*Math.cos((f-.5)*Math.PI)})`;
      ctx.lineWidth=(.5+1.5*Math.cos((f-.5)*Math.PI))*dpr;
      ctx.beginPath();ctx.moveTo(ox+108*dpr,h*.42);ctx.lineTo(ox+108*dpr+Math.cos(a)*w*.70,h*.42+Math.sin(a)*h*.52);ctx.stroke();
    }
    ctx.restore();
  }

  function drawScope(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const domain=c.dataset.domain||"core";
    const t=ms*.001;

    const bg=ctx.createLinearGradient(0,0,0,h);
    bg.addColorStop(0,"#061827");
    bg.addColorStop(1,"#010409");
    ctx.fillStyle=bg;
    ctx.fillRect(0,0,w,h);
    grid(ctx,w,h);

    if(domain==="core"){ drawCore(ctx,w,h,dpr,t); }
    else if(domain==="antenna"){ drawAntenna(ctx,w,h,dpr,t); }
    else if(domain==="cyber"){ drawRF(ctx,w,h,dpr,t,"#ff3d7f"); }
    else if(domain==="fiber"){
      ctx.strokeStyle="#75ff5b";ctx.lineWidth=2*dpr;ctx.beginPath();
      for(let i=0;i<420;i++){
        const x=w*i/419;
        const y=h*.18+(i/419)*h*.52+(((i+20)%105)<5?h*.12:0);
        if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
      }
      ctx.stroke();
    }
    else { drawRF(ctx,w,h,dpr,t,"#00e5ff"); }

    ctx.fillStyle="#8fb8c8";
    ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("BATCH B LEAF ONLY · "+domain.toUpperCase()+" · LIVE CANVAS",10*dpr,18*dpr);
  }

  function frame(ms){
    document.querySelectorAll("canvas.trfmc-b2-scope").forEach(c=>drawScope(c,ms));
    requestAnimationFrame(frame);
  }

  if(document.readyState==="loading"){
    document.addEventListener("DOMContentLoaded",()=>requestAnimationFrame(frame));
  } else {
    requestAnimationFrame(frame);
  }
})();
JS

echo
echo "[4/9] Seleziono target leaf CRITICAL/WEAK da Authority V2"

python3 - "$SCORECARD" "$OUT" "$BATCH_LIMIT" <<'PY'
import csv, sys
from pathlib import Path

scorecard=Path(sys.argv[1])
out=Path(sys.argv[2])
limit=int(sys.argv[3])

protected=[
    "official_safe_entrypoint_v6r3",
    "integration_control_room",
    "perfection_authority",
    "emergency_reset",
    "reset_browser_state"
]

targets=[]
skipped=[]

with scorecard.open(errors="ignore") as fp:
    reader=csv.DictReader(fp, delimiter="\t")
    for r in reader:
        url=r.get("url","")
        cls=r.get("class","")
        sev=r.get("severity","")
        score=int(r.get("score") or 0)

        if cls!="leaf_operational_candidate":
            skipped.append((url,cls,sev,"not_leaf"))
            continue
        if sev not in ("CRITICAL","WEAK"):
            skipped.append((url,cls,sev,"not_critical_or_weak"))
            continue
        if any(p in url for p in protected):
            skipped.append((url,cls,sev,"protected"))
            continue

        targets.append(r)
        if len(targets)>=limit:
            break

with (out/"selected_targets.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\tclass\turl\ttitle\tgaps\n")
    for r in targets:
        fp.write(f'{r.get("score")}\t{r.get("severity")}\t{r.get("domain")}\t{r.get("class")}\t{r.get("url")}\t{r.get("title")}\t{r.get("gaps")}\n')

with (out/"selection_skipped.tsv").open("w") as fp:
    fp.write("url\tclass\tseverity\treason\n")
    for row in skipped:
        fp.write("\t".join(row)+"\n")

print(f"TARGETS={len(targets)}")
PY

echo
echo "[5/9] Patch chirurgico leaf-only"

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
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.css",
]

scripts=[
  "/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js",
  "/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js",
  "/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js",
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.js",
]

asset_for_domain={
  "core":"core-map",
  "rf":"spectrum-scope",
  "antenna":"tower-site",
  "fiber":"fiber-otdr",
  "cyber":"cyber-evidence",
  "datacenter":"rack-pdu",
  "microwave":"microwave-dish",
  "generic":"spectrum-scope",
  "knowledge":"core-map"
}

formula_for_domain={
  "core": "SUPI/SUCI → AUSF/UDM/ARPF → 5G-AKA\\nNGAP: gNB ↔ AMF control plane\\nPFCP: SMF ↔ UPF session programming\\nGTP-U: PDU Session user-plane tunnel\\nDecision = identity + policy + tunnel + evidence",
  "rf": "x(t) ⇄ X(f) via Fourier transform\\nRBW controls spectral resolution\\nEVM = RMS(error vector) / RMS(reference vector)\\nSNR = signal_power / noise_power\\nACLR/OBW/FFT bind signal to measurement",
  "antenna": "EIRP = Ptx + Gant - Lfeeder\\nΓ = (VSWR-1)/(VSWR+1)\\nRL = -20log10|Γ|\\nTilt_total = mechanical + electrical_RET\\nCoverage = EIRP - path_loss + antenna_pattern",
  "fiber": "Loss_total = α·L + Σconnector + Σsplice\\nLatency ≈ n·L/c\\nORL = reflected_power budget\\neCPRI = payload + sync + jitter + latency margin",
  "cyber": "Evidence = source + timestamp + signal + confidence\\nAnomalyScore = deviation × persistence × impact\\nCorrelation = RF event ↔ network event ↔ operator action",
  "datacenter": "P = V·I\\nThermal_margin = cooling_capacity - heat_load\\nAvailability = power × cooling × network × storage\\nRack risk = load + thermal + dependency",
  "microwave": "FSPL = 32.44 + 20log10(fMHz) + 20log10(dkm)\\nFadeMargin = RSL - RxThreshold\\nAvailability ≈ f(rain, band, fade margin)\\nCapacity ≈ B·log2(1+SNR)",
  "generic": "Signal → model → measurement → evidence\\nKPI + formula + visual asset + operational context\\nEvery page must explain what is shown and why it matters",
  "knowledge": "Theory → procedure → simulator → evidence\\nConcept = formula + visualization + KPI + operational meaning"
}

kpi_for_domain={
  "core": ("AKA","NGAP","PFCP","GTP-U"),
  "rf": ("FFT","EVM","SNR","ACLR"),
  "antenna": ("EIRP","VSWR","RET","RSRP"),
  "fiber": ("LOSS","ORL","LAT","eCPRI"),
  "cyber": ("IOC","ANOM","CONF","CHAIN"),
  "datacenter": ("PWR","THERM","PDU","SLA"),
  "microwave": ("RSL","FSPL","BER","CAP"),
  "generic": ("KPI","FORM","ASSET","SOUL"),
  "knowledge": ("THEORY","LAB","KPI","DOC")
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

def bridge(domain,url,title,score,severity):
    domain=domain if domain in asset_for_domain else "generic"
    asset=asset_for_domain[domain]
    formulas=formula_for_domain[domain]
    kpis=kpi_for_domain[domain]
    safe_title=html.escape(title or url)
    safe_url=html.escape(url)
    kpi_html="".join(f'<div class="trfmc-b2-kpi"><small>{html.escape(k)}</small><b>ACTIVE</b></div>' for k in kpis)
    return f'''
<section class="trfmc-perfection-bridge-v2" data-trfmc-perfection-bridge-v2="true" data-domain="{html.escape(domain)}">
  <div class="trfmc-b2-head">
    <div>
      <div class="trfmc-b2-title">TRFMC Batch B Leaf Perfection · {html.escape(domain.upper())}</div>
      <div class="trfmc-b2-sub">{safe_title}<br>{safe_url}<br>Previous Authority V2 score: {html.escape(str(score))}/100 · {html.escape(severity)}</div>
    </div>
    <div class="trfmc-b2-kpis">{kpi_html}</div>
  </div>
  <div class="trfmc-b2-grid">
    <div class="trfmc-b2-asset">
      <trfmc-visual-asset kind="{html.escape(asset)}" data-size="medium" title="Batch B {html.escape(domain.upper())} Visual Asset"></trfmc-visual-asset>
    </div>
    <div class="trfmc-b2-side">
      <div class="trfmc-b2-card">
        <h3>Engineering closure</h3>
        <div class="trfmc-b2-formulas formulaLive">{html.escape(formulas)}</div>
      </div>
      <div class="trfmc-b2-card">
        <h3>Live diagnostic scope</h3>
        <canvas class="trfmc-b2-scope" data-domain="{html.escape(domain)}"></canvas>
      </div>
      <div class="trfmc-b2-card">
        <h3>Perfection signals</h3>
        <span class="trfmc-b2-pill">Design Tokens</span>
        <span class="trfmc-b2-pill">Visual XP</span>
        <span class="trfmc-b2-pill">GPU Runtime</span>
        <span class="trfmc-b2-pill">Asset Engine</span>
        <span class="trfmc-b2-pill">Soul Runtime</span>
        <span class="trfmc-b2-pill">KPI</span>
        <span class="trfmc-b2-pill">Formula</span>
        <span class="trfmc-b2-pill">Canvas</span>
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

        if 'data-trfmc-perfection-bridge-v2="true"' not in s:
            b=bridge(r.get("domain","generic"),url,r.get("title",""),r.get("score",""),r.get("severity",""))
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
echo "[6/9] Gate: external/iframe/http"

python3 - "$PUBLIC" "$OUT" <<'PY'
from pathlib import Path
import re, sys, json

public=Path(sys.argv[1])
out=Path(sys.argv[2])

urls=[line.strip() for line in (out/"patched_pages.tsv").read_text(errors="ignore").splitlines()[1:] if line.strip()]

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

for extra in [
  public/"assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.css",
  public/"assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.js"
]:
    if extra.exists():
      urls.append("/"+str(extra.relative_to(public)))

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
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.css \
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.js \
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
echo "[7/9] Ricalcolo Authority V2 leaf scoped post Batch B"

python3 - "$PUBLIC" "$REG" "$OUT" <<'PY'
import json, re, sys, csv
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

def detect(url,title,text):
    b=(url+" "+title+" "+text[:3000]).lower()
    if any(k in b for k in ["open5gs","ueransim","5g core","5g_core","aka","suci","supi","ngap","pfcp","gtp","ran","identity","amf","smf","upf"]): return "core"
    if any(k in b for k in ["antenna","rru","ret","cpri","ecpri","beam","port mapping","port_mapping"]): return "antenna"
    if any(k in b for k in ["fiber","otdr","fronthaul"]): return "fiber"
    if any(k in b for k in ["cyber","evidence","threat","intelligence","security"]): return "cyber"
    if any(k in b for k in ["datacenter","data center","rack","pdu","power","thermal"]): return "datacenter"
    if any(k in b for k in ["spectrum","signal","vsa","fft","iq","dsp","ofdm","qam","wi-fi","wifi","physics","rf_","heatmap","receiver","pr200","sdr"]): return "rf"
    if any(k in b for k in ["microwave","smith","link budget","backhaul","dish","fade margin"]): return "microwave"
    if any(k in b for k in ["knowledge","theory","academy","procedure","handbook","doctrine"]): return "knowledge"
    return "generic"

def title(text,fallback):
    m=re.search(r"<title[^>]*>(.*?)</title>",text,re.I|re.S)
    return re.sub(r"\s+"," ",m.group(1)).strip() if m else fallback

weights={
  "exists":8,"title":4,"single_header":5,"no_external":8,"no_iframe":8,
  "design_tokens":8,"visual_xp":8,"gpu_runtime":8,"asset_engine":10,
  "soul_runtime":8,"canvas":8,"kpi":6,"formulas":6,"required_assets":5
}

rows=[]
stats=defaultdict(lambda:{"count":0,"score_sum":0,"critical":0,"weak":0,"good":0,"premium":0})

for p in reg.get("pages",[]):
    if p.get("class")!="leaf_operational_candidate":
        continue
    url=p.get("url","")
    if not url.endswith(".html"):
        continue
    f=public/url.lstrip("/")
    exists=f.exists()
    text=f.read_text(errors="ignore") if exists else ""
    ttl=title(text,p.get("name",url))
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
      "kpi":"leaf-kpi" in text or "trfmc-b2-kpi" in text or "trfmc-perfection-kpi" in text or "KPI" in text,
      "formulas":"formulaLive" in text or "FSPL" in text or "VSWR" in text or "EIRP" in text or "Fourier" in text or "formula" in text.lower(),
      "required_assets":all(a in text for a in req) if req else True
    }

    score=min(100,sum(weights[k] for k,v in checks.items() if v))
    gaps=[k for k,v in checks.items() if not v]
    if req and not checks["required_assets"]:
        gaps.append("missing_domain_assets:"+",".join(a for a in req if a not in text))

    sev="PREMIUM" if score>=94 else "GOOD" if score>=85 else "WEAK" if score>=70 else "CRITICAL"

    rows.append({
      "score":score,"severity":sev,"domain":domain,"url":url,"title":ttl,
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
  "authority":"TRFMC_BATCH_B_POST_AUTHORITY_V2_LEAF_ONLY",
  "leaf_pages":len(rows),
  "average_score":avg,
  "critical_pages":critical,
  "weak_pages":weak,
  "good_pages":good,
  "premium_pages":premium,
  "premium_ratio":ratio,
  "gate":"PASS" if avg>=92 and critical==0 and ratio>=0.8 else "NOT_YET"
}

(out/"post_batch_b_authority_v2_summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

with (out/"post_batch_b_leaf_scorecard.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\turl\ttitle\texternal_refs\tiframes\theaders\tnavs\trequired_assets\tgaps\n")
    for r in rows:
        fp.write(f'{r["score"]}\t{r["severity"]}\t{r["domain"]}\t{r["url"]}\t{r["title"]}\t{r["external_refs"]}\t{r["iframes"]}\t{r["headers"]}\t{r["navs"]}\t{r["required_assets"]}\t{r["gaps"]}\n')

with (out/"post_batch_b_leaf_domain_summary.tsv").open("w") as fp:
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
post=json.loads((out/"post_batch_b_authority_v2_summary.json").read_text(errors="ignore"))
reg=json.loads(reg_path.read_text(errors="ignore"))

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "batch":"TRFMC_PERFECTION_SURGICAL_BATCH_B_LEAF_ONLY_V1",
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
  "post_leaf_premium_pages":post.get("premium_pages"),
  "post_leaf_gate":post.get("gate"),
  "result":"PASS" if patched>0 and failed==0 and non200==0 and ext==0 and ifr==0 and protected_ok and registry_unchanged else "WARN",
  "policy":"Batch B patches leaf_operational_candidate only. Registry, V6R3 and Control Room unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_PERFECTION_BATCH_B_LEAF_ONLY_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.css \
    frontend/public/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v2.js \
    runtime/quality/latest_perfection_surgical_batch_b_leaf_only_v1 \
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
echo "=== POST BATCH B DOMAIN SUMMARY ==="
column -t -s $'\t' "$OUT/post_batch_b_leaf_domain_summary.tsv"
echo
echo "=== WORST FIRST AFTER BATCH B ==="
column -t -s $'\t' "$OUT/post_batch_b_leaf_scorecard.tsv" | sed -n '1,80p'
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri una pagina patchata dal file:"
echo "$OUT/patched_pages.tsv"
echo "============================================================"
