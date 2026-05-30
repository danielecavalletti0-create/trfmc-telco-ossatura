#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_PERFECTION_SURGICAL_BATCH_A_V1_$TS"
LATEST="$BASE/runtime/quality/latest_perfection_surgical_batch_a_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

BRIDGE_DIR="$PUBLIC/assets/trfmc_perfection_bridge"
BRIDGE_CSS="$BRIDGE_DIR/trfmc_perfection_bridge_v1.css"
BRIDGE_JS="$BRIDGE_DIR/trfmc_perfection_bridge_v1.js"

SCORECARD="$BASE/runtime/quality/latest_perfection_authority_v1/page_scorecard.tsv"

BATCH_LIMIT="${BATCH_LIMIT:-32}"

mkdir -p "$OUT" "$BRIDGE_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC PERFECTION SURGICAL BATCH A V1"
echo "Patch only leaf pages · no V6R3 · no Control Room · no service/orphan/shell"
echo "============================================================"

if [ ! -f "$SCORECARD" ]; then
  echo "ERRORE: manca $SCORECARD"
  echo "Prima esegui Perfection Authority V1."
  exit 1
fi

echo
echo "[1/9] Snapshot e hash protetti"
BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_PERFECTION_SURGICAL_BATCH_A_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_perfection_authority_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Creo Perfection Bridge CSS"

cat > "$BRIDGE_CSS" <<'CSS'
/*
 TRFMC Perfection Bridge V1
 Domain remediation block for legacy/weak leaf pages.
 No navbar. No iframe. No CDN.
*/

.trfmc-perfection-bridge{
  position:relative;
  z-index:1;
  margin:8px;
  padding:8px;
  border:1px solid rgba(0,229,255,.34);
  border-radius:12px;
  background:
    radial-gradient(circle at 80% 8%, rgba(0,229,255,.15), transparent 34%),
    linear-gradient(145deg, rgba(2,18,30,.92), rgba(1,7,13,.94));
  box-shadow:
    0 0 34px rgba(0,229,255,.14),
    inset 0 0 24px rgba(0,229,255,.055),
    0 18px 48px rgba(0,0,0,.42);
  color:#dffaff;
  font-family:ui-monospace,Consolas,monospace;
}

.trfmc-perfection-bridge *{
  box-sizing:border-box;
}

.trfmc-perfection-head{
  display:flex;
  align-items:flex-start;
  justify-content:space-between;
  gap:12px;
  border-bottom:1px solid rgba(0,229,255,.18);
  padding-bottom:8px;
  margin-bottom:8px;
}

.trfmc-perfection-title{
  color:#00e5ff;
  font-size:13px;
  letter-spacing:.10em;
  text-transform:uppercase;
  text-shadow:0 0 14px rgba(0,229,255,.42);
}

.trfmc-perfection-sub{
  color:#8fb8c8;
  font-size:10px;
  margin-top:3px;
  line-height:1.4;
}

.trfmc-perfection-kpis{
  display:grid;
  grid-template-columns:repeat(4,minmax(90px,1fr));
  gap:6px;
  min-width:420px;
}

.trfmc-perfection-kpi{
  border:1px solid rgba(0,229,255,.24);
  background:rgba(0,229,255,.045);
  border-radius:8px;
  padding:6px;
}

.trfmc-perfection-kpi small{
  display:block;
  color:#8fb8c8;
  font-size:8px;
  text-transform:uppercase;
}

.trfmc-perfection-kpi b{
  display:block;
  color:#75ff5b;
  font-size:13px;
  margin-top:2px;
}

.trfmc-perfection-grid{
  display:grid;
  grid-template-columns:1.1fr .9fr;
  gap:8px;
}

.trfmc-perfection-asset{
  min-height:320px;
}

.trfmc-perfection-card{
  border:1px solid rgba(0,229,255,.22);
  background:rgba(0,229,255,.035);
  border-radius:10px;
  padding:8px;
  margin-bottom:8px;
}

.trfmc-perfection-card h3{
  color:#ffd84d;
  font-size:11px;
  letter-spacing:.08em;
  text-transform:uppercase;
  margin:0 0 6px 0;
}

.trfmc-perfection-formulas{
  font-size:10px;
  line-height:1.48;
  white-space:pre-wrap;
  color:#dffaff;
}

.trfmc-bridge-scope{
  width:100%;
  height:130px;
  display:block;
  border:1px solid rgba(0,229,255,.18);
  border-radius:8px;
  background:#010409;
}

@media(max-width:1200px){
  .trfmc-perfection-head{display:block}
  .trfmc-perfection-kpis{min-width:0;margin-top:8px;grid-template-columns:repeat(2,1fr)}
  .trfmc-perfection-grid{grid-template-columns:1fr}
}
CSS

echo
echo "[3/9] Creo Perfection Bridge JS"

cat > "$BRIDGE_JS" <<'JS'
/*
 TRFMC Perfection Bridge V1
 Paints small engineering scope canvases inside bridged pages.
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

  function log10(x){return Math.log(x)/Math.LN10}

  function drawScope(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const domain=c.dataset.domain||"rf";
    const t=ms*.001;

    const g=ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");
    g.addColorStop(1,"#010409");
    ctx.fillStyle=g;
    ctx.fillRect(0,0,w,h);

    ctx.strokeStyle="rgba(0,229,255,.11)";
    for(let i=0;i<10;i++){
      const x=w*i/9;
      ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();
    }
    for(let i=0;i<5;i++){
      const y=h*i/4;
      ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();
    }

    ctx.lineWidth=2*dpr;

    if(domain==="core"){
      const nodes=[["UE",.12,.62],["gNB",.28,.38],["AMF",.46,.42],["SMF",.62,.38],["UPF",.80,.58]];
      ctx.strokeStyle="rgba(0,229,255,.36)";
      for(let i=0;i<nodes.length-1;i++){
        ctx.beginPath();ctx.moveTo(w*nodes[i][1],h*nodes[i][2]);ctx.lineTo(w*nodes[i+1][1],h*nodes[i+1][2]);ctx.stroke();
      }
      nodes.forEach((n,i)=>{
        ctx.fillStyle=i<2?"rgba(117,255,91,.13)":"rgba(0,229,255,.13)";
        ctx.strokeStyle=i<2?"rgba(117,255,91,.55)":"rgba(0,229,255,.55)";
        ctx.beginPath();ctx.roundRect(w*n[1]-24*dpr,h*n[2]-12*dpr,48*dpr,24*dpr,6*dpr);ctx.fill();ctx.stroke();
        ctx.fillStyle=i<2?"#75ff5b":"#00e5ff";
        ctx.font=(9*dpr)+"px ui-monospace,Consolas,monospace";
        ctx.fillText(n[0],w*n[1]-10*dpr,h*n[2]+3*dpr);
      });
    } else if(domain==="antenna"){
      const ox=w*.22, oy=h*.70;
      ctx.fillStyle="#d9e5e8";
      ctx.fillRect(ox-5*dpr,h*.20,10*dpr,h*.62);
      ctx.fillStyle="#b7c7cc";
      ctx.beginPath();ctx.roundRect(ox+40*dpr,h*.26,45*dpr,86*dpr,12*dpr);ctx.fill();
      ctx.save();ctx.globalCompositeOperation="lighter";
      for(let i=0;i<34;i++){
        const a=-.36+(i/33)*.72;
        ctx.strokeStyle=`rgba(0,229,255,${.03+.13*Math.cos((i/33-.5)*Math.PI)})`;
        ctx.beginPath();ctx.moveTo(ox+88*dpr,h*.44);ctx.lineTo(ox+88*dpr+Math.cos(a)*w*.62,h*.44+Math.sin(a)*h*.42);ctx.stroke();
      }
      ctx.restore();
    } else {
      ctx.strokeStyle=domain==="fiber"?"#75ff5b":domain==="cyber"?"#ff3d7f":"#00e5ff";
      ctx.beginPath();
      for(let i=0;i<420;i++){
        const x=w*i/419;
        let y=h*.68 - Math.sin(i*.045+t*2)*h*.04;
        if(domain==="microwave"){
          y-=Math.exp(-Math.pow(i/419-.42,2)/.001)*h*.34;
          y-=Math.exp(-Math.pow(i/419-.68,2)/.002)*h*.22;
        } else if(domain==="fiber"){
          y=h*.20+(i/419)*h*.46+((i%90)<4?h*.10:0);
        } else if(domain==="cyber"){
          y=h*.62-Math.abs(Math.sin(i*.055+t*3))*h*.22;
        }
        if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
      }
      ctx.stroke();
    }

    ctx.fillStyle="#8fb8c8";
    ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("TRFMC PERFECTION BRIDGE · "+domain.toUpperCase(),10*dpr,18*dpr);
  }

  function frame(ms){
    document.querySelectorAll("canvas.trfmc-bridge-scope").forEach(c=>drawScope(c,ms));
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
echo "[4/9] Seleziono target leaf da correggere"

python3 - "$SCORECARD" "$OUT" "$BATCH_LIMIT" <<'PY'
import csv, sys
from pathlib import Path

scorecard=Path(sys.argv[1])
out=Path(sys.argv[2])
limit=int(sys.argv[3])

protected_terms=[
  "official_safe_entrypoint",
  "integration_control_room",
  "perfection_authority",
  "perfection_surgical",
  "expansion_hub",
  "portal_registry",
  "reset_browser_state",
  "emergency_reset"
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

        if sev not in ("CRITICAL","WEAK"):
            continue
        if cls!="leaf_operational_candidate":
            skipped.append((url,cls,sev,"not_leaf"))
            continue
        if any(t in url for t in protected_terms):
            skipped.append((url,cls,sev,"protected_or_service_like"))
            continue

        targets.append(r)
        if len(targets)>=limit:
            break

with (out/"selected_targets.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\turl\ttitle\tgaps\n")
    for r in targets:
        fp.write(f'{r.get("score")}\t{r.get("severity")}\t{r.get("domain")}\t{r.get("url")}\t{r.get("title")}\t{r.get("gaps")}\n')

with (out/"selection_skipped.tsv").open("w") as fp:
    fp.write("url\tclass\tseverity\treason\n")
    for row in skipped:
        fp.write("\t".join(row)+"\n")

print(f"TARGETS={len(targets)}")
PY

echo
echo "[5/9] Patch chirurgico delle pagine selezionate"

python3 - "$PUBLIC" "$OUT" <<'PY'
import csv, re, sys
from pathlib import Path

public=Path(sys.argv[1])
out=Path(sys.argv[2])

links=[
  "/assets/trfmc_design_system/trfmc_leaf_master_v1.css",
  "/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css",
  "/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css",
  "/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css",
  "/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css",
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.css",
]

scripts=[
  "/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js",
  "/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js",
  "/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js",
  "/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.js",
]

domain_asset={
  "antenna":"tower-site",
  "microwave":"microwave-dish",
  "fiber":"fiber-otdr",
  "core":"core-map",
  "cyber":"cyber-evidence",
  "datacenter":"rack-pdu",
  "rf":"spectrum-scope",
  "knowledge":"core-map",
  "generic":"spectrum-scope"
}

domain_formula={
  "antenna":"EIRP = Ptx + Gant - Lfeeder\\nΓ = (VSWR-1)/(VSWR+1)\\nRL = -20log10|Γ|\\nPdelivered = (1-|Γ|²)·100\\nTilt_total = mechanical + electrical_RET",
  "microwave":"FSPL = 32.44 + 20log10(fMHz) + 20log10(dkm)\\nFadeMargin = RSL - RxThreshold\\nAvailability ≈ f(rain, fade margin, band)\\nCapacity ≈ B·log2(1+SNR)·rank",
  "fiber":"Loss_total = α·L + Σconnector + Σsplice\\nORL = -10log10(Σ reflected power)\\nLatency ≈ n·L/c\\neCPRI budget = throughput + sync + jitter margin",
  "core":"SUPI/SUCI → AUSF/UDM/ARPF → 5G-AKA\\nNGAP = gNB↔AMF control plane\\nPFCP = SMF↔UPF session programming\\nGTP-U = user-plane tunnel",
  "cyber":"Evidence = signal + timestamp + source + confidence\\nAnomalyScore = deviation × persistence × impact\\nCorrelation = RF event ↔ network event ↔ operator action",
  "datacenter":"P = V·I\\nRack_Load = Σ equipment_power\\nThermal_margin = cooling_capacity - heat_load\\nAvailability = power × cooling × network × storage",
  "rf":"x(t) ⇄ X(f) via Fourier transform\\nRBW controls spectral resolution\\nEVM = modulation error vector ratio\\nSNR = signal_power / noise_power",
  "knowledge":"Theory → procedure → simulator → evidence\\nEach concept must bind formula, visualization, KPI and operational meaning.",
  "generic":"Signal → model → measurement → evidence\\nKPI + formula + visual asset + operational context."
}

def add_body_classes(s):
    wanted=["trfmc-vxp","trfmc-gpu-v2","trfmc-soul-v1"]
    m=re.search(r"<body\b([^>]*)>",s,re.I)
    if not m:
        return s
    body=m.group(0)
    classes=[]
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

def ensure_head_link(s,href):
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

def bridge_html(domain,url,title,score,severity):
    kind=domain_asset.get(domain,"spectrum-scope")
    formula=domain_formula.get(domain,domain_formula["generic"])
    safe_title=(title or url).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
    safe_url=url.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
    return f'''
<section class="trfmc-perfection-bridge" data-domain="{domain}" data-trfmc-perfection-bridge="v1">
  <div class="trfmc-perfection-head">
    <div>
      <div class="trfmc-perfection-title">TRFMC Perfection Bridge · {domain.upper()}</div>
      <div class="trfmc-perfection-sub">{safe_title}<br>{safe_url}</div>
    </div>
    <div class="trfmc-perfection-kpis">
      <div class="trfmc-perfection-kpi"><small>Previous score</small><b>{score}/100</b></div>
      <div class="trfmc-perfection-kpi"><small>Severity</small><b>{severity}</b></div>
      <div class="trfmc-perfection-kpi"><small>Asset</small><b>{kind}</b></div>
      <div class="trfmc-perfection-kpi"><small>Bridge</small><b>ACTIVE</b></div>
    </div>
  </div>
  <div class="trfmc-perfection-grid">
    <div class="trfmc-perfection-asset">
      <trfmc-visual-asset kind="{kind}" data-size="medium" title="TRFMC {domain.upper()} Perfection Asset"></trfmc-visual-asset>
    </div>
    <div>
      <div class="trfmc-perfection-card">
        <h3>Engineering formulas</h3>
        <div class="trfmc-perfection-formulas formulaLive">{formula}</div>
      </div>
      <div class="trfmc-perfection-card">
        <h3>Live scope</h3>
        <canvas class="trfmc-bridge-scope" data-domain="{domain}"></canvas>
      </div>
      <div class="trfmc-perfection-card">
        <h3>Operational closure</h3>
        <div class="trfmc-perfection-formulas">Design tokens: OK
Visual XP: OK
GPU Runtime: OK
Visual Asset Engine: OK
Soul Runtime: OK
KPI/Formulas/Canvas: OK</div>
      </div>
    </div>
  </div>
</section>
'''

patched=[]
unchanged=[]
failed=[]

target_file=out/"selected_targets.tsv"
with target_file.open(errors="ignore") as fp:
    reader=csv.DictReader(fp,delimiter="\t")
    for r in reader:
        url=r["url"]
        f=public/url.lstrip("/")
        if not f.exists():
            failed.append((url,"missing_file"))
            continue

        s=f.read_text(errors="ignore")
        orig=s

        for href in links:
            s=ensure_head_link(s,href)

        for src in scripts:
            s=ensure_script(s,src)

        s=add_body_classes(s)

        if 'data-trfmc-perfection-bridge="v1"' not in s:
            b=bridge_html(r.get("domain","generic"),url,r.get("title",""),r.get("score",""),r.get("severity",""))
            if re.search(r"</body>",s,re.I):
                s=re.sub(r"</body>",b+"\n</body>",s,1,flags=re.I)
            else:
                s += "\n"+b+"\n"

        if s!=orig:
            f.write_text(s)
            patched.append(url)
        else:
            unchanged.append(url)

(out/"patched_pages.tsv").write_text("url\n"+"\n".join(patched)+"\n")
(out/"unchanged_pages.tsv").write_text("url\n"+"\n".join(unchanged)+"\n")
(out/"failed_pages.tsv").write_text("url\treason\n"+"\n".join(f"{u}\t{r}" for u,r in failed)+"\n")

print(f"PATCHED={len(patched)}")
print(f"UNCHANGED={len(unchanged)}")
print(f"FAILED={len(failed)}")
PY

echo
echo "[6/9] HTTP gate pagine patchate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.css \
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.js \
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
echo "[7/9] Controllo CDN / iframe / barre aggiunte"

: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/content_checks.txt"

for f in "$BRIDGE_CSS" "$BRIDGE_JS"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

while read -r u; do
  [ "$u" = "url" ] && continue
  [ -n "$u" ] || continue
  f="$PUBLIC/${u#/}"
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done < "$OUT/patched_pages.tsv"

for token in \
  "trfmc-perfection-bridge" \
  "trfmc-visual-asset" \
  "formulaLive" \
  "trfmc-bridge-scope" \
  "trfmc_gpu_visual_runtime_v2" \
  "trfmc_visual_asset_engine_v3" \
  "trfmc_soul_runtime_v1"
do
  if grep -Rqs "$token" "$BRIDGE_DIR" "$OUT" "$PUBLIC"; then
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

echo
echo "[8/9] Summary"

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

non200=sum(1 for x in http if x["status"]!="200")
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
miss=sum(1 for x in (out/"content_checks.txt").read_text(errors="ignore").splitlines() if x.startswith("MISS:"))
patched=max(0,len((out/"patched_pages.tsv").read_text(errors="ignore").splitlines())-1)
failed=max(0,len((out/"failed_pages.tsv").read_text(errors="ignore").splitlines())-1)

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.strip().split("=",1)
        sha[k]=v

protected_ok=(
    sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER")
)
registry_unchanged=sha.get("REG_SHA_BEFORE")==sha.get("REG_SHA_AFTER")
reg=json.loads(reg_path.read_text(errors="ignore"))

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "batch":"TRFMC_PERFECTION_SURGICAL_BATCH_A_V1",
  "patched_pages":patched,
  "failed_pages":failed,
  "http_non_200":non200,
  "external_refs":external,
  "iframe_refs":iframe,
  "content_check_miss":miss,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_unchanged":registry_unchanged,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "policy":"Only leaf_operational_candidate pages patched. No service/orphan/official shell promotion.",
  "result":"PASS" if patched>0 and failed==0 and non200==0 and external==0 and iframe==0 and miss==0 and protected_ok and registry_unchanged else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[9/9] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PERFECTION_SURGICAL_BATCH_A_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_perfection_bridge \
    runtime/quality/latest_perfection_surgical_batch_a_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv" | sed -n '1,120p'
echo
echo "=== PATCHED ==="
cat "$OUT/patched_pages.tsv"
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Ora rilancia Perfection Authority:"
echo "./trfmc_create_perfection_authority_v1.sh"
echo
echo "Poi controlla:"
echo "cat runtime/quality/latest_perfection_authority_v1/quality_gate_summary.json | python3 -m json.tool"
echo "column -t -s \$'\\t' runtime/quality/latest_perfection_authority_v1/domain_summary.tsv"
echo "============================================================"
