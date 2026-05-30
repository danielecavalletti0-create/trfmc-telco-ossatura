#!/usr/bin/env bash
set -u
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

SRC="$PUBLIC/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html"
DST="$PUBLIC/trfmc_3d_rf_asset_renderer_lab_v1r2_auto_fit.html"

OUT="$BASE/runtime/quality/TRFMC_3D_RF_ASSET_RENDERER_V1R2_AUTO_FIT_$TS"
BK="$BASE/runtime/backups/3D_RF_ASSET_RENDERER_V1R2_AUTO_FIT_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC 3D RF ASSET RENDERER V1R2 - AUTO FIT / AUTO CENTER"
echo "============================================================"

http_probe() {
  local u="$1"
  local r code bytes
  r="$(curl -s -o /dev/null -w "%{response_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
  code="$(echo "$r" | awk '{print $1}')"
  bytes="$(echo "$r" | awk '{print $2}')"
  [ -n "$code" ] || code="000"
  [ -n "$bytes" ] || bytes="0"
  echo -e "$u\t$code\t$bytes"
}

echo
echo "[1/6] Verifico V1R1 sorgente"
ls -lh "$SRC" || {
  echo "ERRORE: sorgente V1R1 non trovata."
  exit 1
}

cp -av "$SRC" "$BK/"
cp -av "$SRC" "$DST"

echo
echo "[2/6] Patch auto-camera: bounding box, fit scale, centro ottico"
python3 - <<'PY'
from pathlib import Path

p = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_3d_rf_asset_renderer_lab_v1r2_auto_fit.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "<title>TRFMC 3D RF Asset Renderer Lab V1R1 Proportions</title>",
    "<title>TRFMC 3D RF Asset Renderer Lab V1R2 Auto Fit</title>"
)

s = s.replace(
    "TRFMC 3D RF ASSET RENDERER LAB V1R1 PROPORTIONS</h1>",
    "TRFMC 3D RF ASSET RENDERER LAB V1R2 AUTO FIT</h1>"
)

s = s.replace(
    "Corrected proportions · asset-specific camera · realistic tower/AAU/filter/array/dish scaling · 4D/5D engineering layers",
    "Auto-centering · projected bounding box · viewport-fit zoom · realistic RF asset proportions · 4D/5D engineering layers"
)

# Il range scale diventa un "fill bias", non una scala cieca che manda fuori scena l'oggetto.
s = s.replace(
    '<div class="label">Scale <span class="val" id="vScale"></span></div>',
    '<div class="label">Viewport Fill Bias <span class="val" id="vScale"></span></div>'
)

# Inserisco funzioni auto-fit subito dopo cameraFor.
marker = '''function cameraFor(w,h,p){
  let cx=w*0.50, cy=h*0.78;
  if(p.asset==="MIMO_ARRAY"){ cx=w*0.50; cy=h*0.68; }
  if(p.asset==="RF_FILTER"){ cx=w*0.50; cy=h*0.70; }
  if(p.asset==="MICROWAVE_DISH"){ cx=w*0.50; cy=h*0.70; }
  if(p.asset==="GNB_STACK"){ cx=w*0.50; cy=h*0.78; }
  return {cx,cy};
}
'''

insert = r'''function beamPoints(origin,beam,tilt){
  const len=1.35+Math.max(0,70-beam)/32;
  const spread=Math.tan((beam*Math.PI/180)/2)*len*.42;
  const zdrop=Math.sin(tilt*Math.PI/180)*1.2;
  return [
    origin,
    [origin[0]-spread,origin[1]-len,origin[2]-zdrop],
    [origin[0]+spread,origin[1]-len,origin[2]-zdrop],
    [origin[0],origin[1]-len,origin[2]-zdrop]
  ];
}

function bboxCube(x0,y0,z0,x1,y1,z1){
  return [
    [x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0],
    [x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]
  ];
}

function assetBBoxPoints(p){
  let pts=[];
  if(p.asset==="TOWER_SITE"){
    pts = pts.concat(
      bboxCube(-1.25,-1.25,0.0,1.35,0.55,7.05),
      bboxCube(-1.05,-.50,2.25,-.42,-.16,5.25),
      bboxCube(.42,-.50,2.35,1.22,-.16,5.25),
      bboxCube(-.45,-.85,.05,.45,-.20,.90),
      beamPoints([.7,-.22,3.8],p.beam,p.tilt),
      beamPoints([-.6,-.22,3.8],p.beam,p.tilt)
    );
  } else if(p.asset==="MIMO_ARRAY"){
    const rows=p.rows, cols=p.cols, spacing=.16;
    const ox=-cols*spacing/2;
    pts = pts.concat(
      bboxCube(-1.65,-.55,1.65,1.65,.18,4.45),
      bboxCube(ox-.15,-.42,2.0,ox+cols*spacing+.15,-.10,3.95),
      beamPoints([0,-.32,3.05],p.beam,p.tilt)
    );
  } else if(p.asset==="RF_FILTER"){
    pts = pts.concat(
      bboxCube(-2.25,-1.05,.80,2.35,.70,2.65),
      bboxCube(-2.35,-.45,1.20,2.35,.05,1.95)
    );
  } else if(p.asset==="MICROWAVE_DISH"){
    pts = pts.concat(
      bboxCube(-1.80,-1.15,.65,2.10,.75,4.20),
      beamPoints([.9,-.2,2.7],p.beam,p.tilt)
    );
  } else if(p.asset==="GNB_STACK"){
    pts = pts.concat(
      bboxCube(-1.90,-1.05,.10,2.05,.35,4.65),
      beamPoints([-.95,-.85,3.0],p.beam,p.tilt),
      beamPoints([-.15,-.85,3.1],p.beam,p.tilt),
      beamPoints([.65,-.85,2.9],p.beam,p.tilt)
    );
  } else {
    pts = bboxCube(-2,-1,0,2,1,4);
  }
  return pts;
}

function projectRaw(pt,p,fit=1){
  const az=p.az*Math.PI/180;
  const ca=Math.cos(az), sa=Math.sin(az);
  const x=pt[0], y=pt[1], z=pt[2];
  const xr=x*ca-y*sa, yr=x*sa+y*ca;
  const s=assetScale(p)*p.scale*fit;
  return [(xr-yr)*s*0.70,(xr+yr)*s*0.34-z*s];
}

function projectedBounds(points,p,fit=1){
  let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
  for(const pt of points){
    const q=projectRaw(pt,p,fit);
    minX=Math.min(minX,q[0]); maxX=Math.max(maxX,q[0]);
    minY=Math.min(minY,q[1]); maxY=Math.max(maxY,q[1]);
  }
  return {minX,minY,maxX,maxY,w:maxX-minX,h:maxY-minY,cx:(minX+maxX)/2,cy:(minY+maxY)/2};
}

function autoCamera(w,h,p){
  const pts=assetBBoxPoints(p);
  const b=projectedBounds(pts,p,1);

  // Fill bias derivato dallo slider: 0.60 -> più margine, 1.80 -> più pieno.
  const bias=(p.scale-0.6)/(1.8-0.6);
  const targetW=w*(0.50 + 0.22*Math.max(0,Math.min(1,bias)));
  const targetH=h*(0.54 + 0.18*Math.max(0,Math.min(1,bias)));

  let fit=Math.min(targetW/Math.max(1,b.w), targetH/Math.max(1,b.h));
  fit=Math.max(0.35,Math.min(3.80,fit));

  // Centro ottico: leggermente sopra il centro geometrico per lasciare spazio ai pannelli KPI inferiori.
  const opticalX=w*0.50;
  const opticalY=h*0.50;

  return {
    cx: opticalX - b.cx*fit,
    cy: opticalY - b.cy*fit,
    fit: fit,
    bbox: b,
    targetW: targetW,
    targetH: targetH
  };
}
'''

if marker not in s:
    raise SystemExit("ERRORE: cameraFor marker non trovato")
s = s.replace(marker, marker + "\n" + insert + "\n", 1)

# Modifico iso per usare c.fit.
old = '''  const s=assetScale(p)*p.scale;
  return [c.cx+(xr-yr)*s*0.70, c.cy+(xr+yr)*s*0.34-z*s];'''
new = '''  const s=assetScale(p)*p.scale*(c.fit||1);
  return [c.cx+(xr-yr)*s*0.70, c.cy+(xr+yr)*s*0.34-z*s];'''
if old not in s:
    raise SystemExit("ERRORE: scala iso originale non trovata")
s = s.replace(old,new,1)

# DrawScene usa autoCamera, non camera fissa.
old = '''  const w=r.width,h=r.height,p=calc(), c=cameraFor(w,h,p);'''
new = '''  const w=r.width,h=r.height,p=calc(), c=autoCamera(w,h,p);'''
if old not in s:
    raise SystemExit("ERRORE: drawScene camera line non trovata")
s = s.replace(old,new,1)

# Griglia parametrica centrata sulla camera auto-fit, più contenuta e meno invasiva.
old_grid = '''  for(let i=-8;i<=9;i++){
    const A=iso(i,-8,0,c),B=iso(i,8,0,c);
    ctx.beginPath();ctx.moveTo(A[0],A[1]);ctx.lineTo(B[0],B[1]);ctx.stroke();
    const C=iso(-8,i,0,c),D=iso(8,i,0,c);
    ctx.beginPath();ctx.moveTo(C[0],C[1]);ctx.lineTo(D[0],D[1]);ctx.stroke();
  }'''
new_grid = '''  const gridExtent = p.asset==="MIMO_ARRAY" ? 4.5 : p.asset==="RF_FILTER" ? 4.0 : 5.5;
  const gridStep = p.asset==="MIMO_ARRAY" ? .75 : 1.0;
  for(let i=-gridExtent;i<=gridExtent+0.001;i+=gridStep){
    const A=iso(i,-gridExtent,0,c),B=iso(i,gridExtent,0,c);
    ctx.beginPath();ctx.moveTo(A[0],A[1]);ctx.lineTo(B[0],B[1]);ctx.stroke();
    const C=iso(-gridExtent,i,0,c),D=iso(gridExtent,i,0,c);
    ctx.beginPath();ctx.moveTo(C[0],C[1]);ctx.lineTo(D[0],D[1]);ctx.stroke();
  }'''
if old_grid not in s:
    raise SystemExit("ERRORE: grid block non trovato")
s = s.replace(old_grid,new_grid,1)

# Aggiungo overlay con fit reale e bounding box.
old_overlay = '''  label(ctx,"3D geometry: "+p.asset,14,22);
  label(ctx,"4D layer: t="+(tick/60).toFixed(1)+"s / freq="+p.freq.toFixed(1)+"GHz",14,40,"#75ff5b");
  label(ctx,"5D state: RF POWER "+p.pow+" dBm · protocol KPI overlay simulated",14,58,"#ffd400");'''
new_overlay = '''  label(ctx,"3D geometry: "+p.asset+" · auto-fit x"+(c.fit||1).toFixed(2),14,22);
  label(ctx,"bbox: "+Math.round(c.bbox.w)+"x"+Math.round(c.bbox.h)+" px · target "+Math.round(c.targetW)+"x"+Math.round(c.targetH)+" px",14,40,"#00e5ff");
  label(ctx,"4D layer: t="+(tick/60).toFixed(1)+"s / freq="+p.freq.toFixed(1)+"GHz",14,58,"#75ff5b");
  label(ctx,"5D state: RF POWER "+p.pow+" dBm · protocol KPI overlay simulated",14,76,"#ffd400");'''
if old_overlay not in s:
    raise SystemExit("ERRORE: overlay labels non trovate")
s = s.replace(old_overlay,new_overlay,1)

# Aggiorno pannelli informativi.
s = s.replace(
    'projection = ${p.view}<br>asset = ${p.asset}<br>azimuth = ${p.az}°<br>detail = ${p.detail}/5',
    'projection = ${p.view}<br>asset = ${p.asset}<br>azimuth = ${p.az}°<br>auto-fit camera = active<br>detail = ${p.detail}/5'
)

# Export report.
s = s.replace(
    'const data={page:"TRFMC 3D RF Asset Renderer Lab V1R1 Proportions",timestamp:new Date().toISOString(),renderer:"pure-canvas-2.5D-proportion-corrected",future_renderer:"local WebGL/Three.js/WebGPU",parameters:p,gate:{standalone_leaf:true,iframe:false,external_refs:false}};',
    'const cam=autoCamera(1200,720,p); const data={page:"TRFMC 3D RF Asset Renderer Lab V1R2 Auto Fit",timestamp:new Date().toISOString(),renderer:"pure-canvas-2.5D-auto-fit-bbox",future_renderer:"local WebGL/Three.js/WebGPU",parameters:p,auto_camera:{fit:cam.fit,bbox:cam.bbox,targetW:cam.targetW,targetH:cam.targetH},gate:{standalone_leaf:true,iframe:false,external_refs:false}};'
)

s = s.replace(
    'loadState();update();addEvent("3D RF Asset Renderer Lab V1R1 proportions online");loop();',
    'loadState();update();addEvent("3D RF Asset Renderer Lab V1R2 auto-fit online");loop();'
)

p.write_text(s)
print("PATCH_OK: V1R2 auto-fit created")
PY

echo
echo "[3/6] Verifico nuovo file"
ls -lh "$DST"

echo
echo "[4/6] Quality gate V1R2 auto-fit"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_3d_rf_asset_renderer_lab_v1r2_auto_fit.html \
  /trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html \
  /trfmc_3d_rf_asset_renderer_lab_v1.html \
  /trfmc_official_safe_entrypoint_v6r3_command_center.html \
  /trfmc_signal_intelligence_center_v1.html \
  /trfmc_realtime_fft_gapless_receiver_lab_v1.html \
  /trfmc_rf_metrology_calibration_lab_v1.html \
  /api/health
do
  http_probe "$u" >> "$OUT/http.tsv"
done

grep -nEi '<iframe|src="/trfmc_(supervisor|unified|official_safe_entrypoint)' "$DST" > "$OUT/iframe_refs.txt" 2>/dev/null || true
grep -nEi 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' "$DST" > "$OUT/external_refs.txt" 2>/dev/null || true

export OUT
python3 - <<'PY'
import os,json
from pathlib import Path
from datetime import datetime, timezone

out=Path(os.environ["OUT"])
http_non_200=0
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=2 and p[1].strip()!="200":
        http_non_200+=1

iframes=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1r2_auto_fit.html",
 "source_v1r1":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html",
 "http_non_200":http_non_200,
 "iframe_refs":iframes,
 "external_refs":external,
 "result":"PASS" if http_non_200==0 and iframes==0 and external==0 else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_3d_rf_asset_renderer_v1r2_auto_fit"

echo
echo "[5/6] Report"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== IFRAME ==="
cat "$OUT/iframe_refs.txt"

echo
echo "=== EXTERNAL ==="
cat "$OUT/external_refs.txt"

echo
echo "[6/6] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_3D_RF_ASSET_RENDERER_V1R2_AUTO_FIT_$TS.tar.gz"

  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .

  echo
  echo "=== FREEZE CREATO ==="
  ls -lh "$FREEZE"
else
  echo "WARN: freeze non creato perché il gate non è PASS"
fi

echo
echo "============================================================"
echo "APRI LA VERSIONE AUTO-FIT:"
echo "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1r2_auto_fit.html"
echo "============================================================"
