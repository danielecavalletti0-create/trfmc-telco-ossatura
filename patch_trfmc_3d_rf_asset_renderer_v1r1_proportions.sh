#!/usr/bin/env bash
set -u
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

SRC="$PUBLIC/trfmc_3d_rf_asset_renderer_lab_v1.html"
DST="$PUBLIC/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html"

OUT="$BASE/runtime/quality/TRFMC_3D_RF_ASSET_RENDERER_V1R1_PROPORTIONS_$TS"
BK="$BASE/runtime/backups/3D_RF_ASSET_RENDERER_V1R1_PROPORTIONS_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC 3D RF ASSET RENDERER V1R1 - PROPORTIONS FIX"
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
echo "[1/6] Verifico V1 sorgente"
ls -lh "$SRC" || {
  echo "ERRORE: sorgente V1 non trovata."
  exit 1
}

cp -av "$SRC" "$BK/"
cp -av "$SRC" "$DST"

echo
echo "[2/6] Patch proporzioni: camera, scala, griglia, asset"
python3 - <<'PY'
from pathlib import Path

p = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "<title>TRFMC 3D RF Asset Renderer Lab</title>",
    "<title>TRFMC 3D RF Asset Renderer Lab V1R1 Proportions</title>"
)

s = s.replace(
    "TRFMC 3D RF ASSET RENDERER LAB</h1>",
    "TRFMC 3D RF ASSET RENDERER LAB V1R1 PROPORTIONS</h1>"
)

s = s.replace(
    "Technical asset renderer · antennas · AAU/RRU · eNB/gNB · filters · arrays · beam cones · 4D/5D engineering layers",
    "Corrected proportions · asset-specific camera · realistic tower/AAU/filter/array/dish scaling · 4D/5D engineering layers"
)

# Default più corretto: isometrico, non exploded.
s = s.replace(
    '<option>ISOMETRIC</option>\n            <option>FRONT_TECH</option>\n            <option>TOP_RF</option>\n            <option>EXPLODED</option>',
    '<option selected>ISOMETRIC</option>\n            <option>FRONT_TECH</option>\n            <option>TOP_RF</option>\n            <option>EXPLODED</option>'
)

# Scala default più grande.
s = s.replace(
    'id="scale" class="range" type="range" min="0.6" max="1.8" value="1.05"',
    'id="scale" class="range" type="range" min="0.6" max="1.8" value="1.35"'
)

# Sostituisco la funzione iso con una camera asset-specifica.
old_iso = '''function iso(x,y,z,c){
  const p=calc();
  const az=p.az*Math.PI/180;
  const ca=Math.cos(az), sa=Math.sin(az);
  const xr=x*ca-y*sa, yr=x*sa+y*ca;
  const s=46*p.scale;
  return [c.cx+(xr-yr)*s*0.72, c.cy+(xr+yr)*s*0.38-z*s];
}'''

new_iso = '''function assetScale(p){
  if(p.asset==="TOWER_SITE") return 82;
  if(p.asset==="GNB_STACK") return 82;
  if(p.asset==="MIMO_ARRAY") return 118;
  if(p.asset==="RF_FILTER") return 118;
  if(p.asset==="MICROWAVE_DISH") return 112;
  return 90;
}
function cameraFor(w,h,p){
  let cx=w*0.50, cy=h*0.78;
  if(p.asset==="MIMO_ARRAY"){ cx=w*0.50; cy=h*0.68; }
  if(p.asset==="RF_FILTER"){ cx=w*0.50; cy=h*0.70; }
  if(p.asset==="MICROWAVE_DISH"){ cx=w*0.50; cy=h*0.70; }
  if(p.asset==="GNB_STACK"){ cx=w*0.50; cy=h*0.78; }
  return {cx,cy};
}
function iso(x,y,z,c){
  const p=calc();
  const az=p.az*Math.PI/180;
  const ca=Math.cos(az), sa=Math.sin(az);
  const xr=x*ca-y*sa, yr=x*sa+y*ca;
  const s=assetScale(p)*p.scale;
  return [c.cx+(xr-yr)*s*0.70, c.cy+(xr+yr)*s*0.34-z*s];
}'''

if old_iso not in s:
    raise SystemExit("ERRORE: funzione iso originale non trovata")
s = s.replace(old_iso, new_iso)

# Proporzioni torre/AAU più leggibili: antenne più larghe e realistiche.
s = s.replace(
'''  box(ctx,c,-.7,-.28,2.9,.18,.12,2.1,"#d6edf5");
  box(ctx,c,-.45,-.32,2.6,.2,.18,1.4,"#0b72a8");
  box(ctx,c,.35,-.28,3.2,.18,.12,1.9,"#d6edf5");
  box(ctx,c,.58,-.32,2.8,.2,.18,1.2,"#0b72a8");''',
'''  box(ctx,c,-.92,-.34,2.65,.30,.18,2.45,"#d6edf5");
  box(ctx,c,-.58,-.40,2.35,.32,.24,1.55,"#0b72a8");
  box(ctx,c,.50,-.34,2.92,.30,.18,2.25,"#d6edf5");
  box(ctx,c,.86,-.40,2.50,.32,.24,1.38,"#0b72a8");'''
)

# GNB proporzioni migliorate.
s = s.replace(
'''  box(ctx,c,-1.25,-.7,1.7,.5,.25,2.4,"#d6edf5");
  box(ctx,c,-.45,-.72,1.55,.5,.25,2.6,"#d6edf5");
  box(ctx,c,.35,-.7,1.8,.5,.25,2.1,"#d6edf5");
  box(ctx,c,1.0,-.55,1.0,.55,.45,1,"#0b72a8");''',
'''  box(ctx,c,-1.35,-.76,1.42,.62,.34,2.75,"#d6edf5");
  box(ctx,c,-.48,-.78,1.32,.62,.34,2.95,"#d6edf5");
  box(ctx,c,.40,-.76,1.55,.62,.34,2.55,"#d6edf5");
  box(ctx,c,1.14,-.60,.88,.68,.50,1.20,"#0b72a8");'''
)

# Grid enorme ridotta: da -20..40 a -8..9.
s = s.replace(
'''  for(let i=-20;i<40;i++){
    const A=iso(i,-12,0,c),B=iso(i,12,0,c);
    ctx.beginPath();ctx.moveTo(A[0],A[1]);ctx.lineTo(B[0],B[1]);ctx.stroke();
    const C=iso(-12,i,0,c),D=iso(12,i,0,c);
    ctx.beginPath();ctx.moveTo(C[0],C[1]);ctx.lineTo(D[0],D[1]);ctx.stroke();
  }''',
'''  for(let i=-8;i<=9;i++){
    const A=iso(i,-8,0,c),B=iso(i,8,0,c);
    ctx.beginPath();ctx.moveTo(A[0],A[1]);ctx.lineTo(B[0],B[1]);ctx.stroke();
    const C=iso(-8,i,0,c),D=iso(8,i,0,c);
    ctx.beginPath();ctx.moveTo(C[0],C[1]);ctx.lineTo(D[0],D[1]);ctx.stroke();
  }'''
)

# Camera nel drawScene: sostituisco centro fisso con camera asset-specifica.
s = s.replace(
'''  const w=r.width,h=r.height,p=calc(), c={cx:w/2,cy:h*.62};''',
'''  const w=r.width,h=r.height,p=calc(), c=cameraFor(w,h,p);'''
)

# Linee di griglia più discrete.
s = s.replace(
'''  ctx.strokeStyle="rgba(0,210,255,.14)";''',
'''  ctx.strokeStyle="rgba(0,210,255,.105)";'''
)

# Beam leggermente più presente ma meno sproporzionato.
s = s.replace(
'''  const len=1.8+Math.max(0,60-beam)/22;
  const spread=Math.tan((beam*Math.PI/180)/2)*len*.55;''',
'''  const len=1.35+Math.max(0,70-beam)/32;
  const spread=Math.tan((beam*Math.PI/180)/2)*len*.42;'''
)

# Etichetta V1R1 e stato.
s = s.replace(
''' "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1.html",''',
''' "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html",'''
)

s = s.replace(
'''const data={page:"TRFMC 3D RF Asset Renderer Lab V1",timestamp:new Date().toISOString(),renderer:"pure-canvas-2.5D-first-stage",future_renderer:"local WebGL/Three.js/WebGPU",parameters:p,gate:{standalone_leaf:true,iframe:false,external_refs:false}};''',
'''const data={page:"TRFMC 3D RF Asset Renderer Lab V1R1 Proportions",timestamp:new Date().toISOString(),renderer:"pure-canvas-2.5D-proportion-corrected",future_renderer:"local WebGL/Three.js/WebGPU",parameters:p,gate:{standalone_leaf:true,iframe:false,external_refs:false}};'''
)

s = s.replace(
'''loadState();update();addEvent("3D RF Asset Renderer Lab online");loop();''',
'''loadState();update();addEvent("3D RF Asset Renderer Lab V1R1 proportions online");loop();'''
)

p.write_text(s)
print("PATCH_OK: V1R1 proportions created")
PY

echo
echo "[3/6] Verifico nuovo file"
ls -lh "$DST"

echo
echo "[4/6] Quality gate V1R1 proportions"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
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
 "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html",
 "source_v1":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1.html",
 "http_non_200":http_non_200,
 "iframe_refs":iframes,
 "external_refs":external,
 "result":"PASS" if http_non_200==0 and iframes==0 and external==0 else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_3d_rf_asset_renderer_v1r1_proportions"

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
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_3D_RF_ASSET_RENDERER_V1R1_PROPORTIONS_$TS.tar.gz"

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
echo "APRI LA VERSIONE CORRETTA:"
echo "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html"
echo "============================================================"
