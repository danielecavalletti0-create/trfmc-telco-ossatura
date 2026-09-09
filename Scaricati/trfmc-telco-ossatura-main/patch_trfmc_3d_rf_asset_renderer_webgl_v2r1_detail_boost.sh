#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
TS="$(date +%Y%m%d_%H%M%S)"

SRC="$PUBLIC/trfmc_3d_rf_asset_renderer_webgl_v2.html"
DST="$PUBLIC/trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html"

OUT="$BASE/runtime/quality/TRFMC_3D_RF_ASSET_RENDERER_WEBGL_V2R1_DETAIL_BOOST_$TS"
BK="$BASE/runtime/backups/3D_RF_ASSET_RENDERER_WEBGL_V2R1_DETAIL_BOOST_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/quality" "$BASE/runtime/freezes"
mkdir -p "$PUBLIC/vendor/three/examples/jsm/geometries"

echo "============================================================"
echo "TRFMC 3D RF ASSET RENDERER WEBGL V2R1 - DETAIL BOOST"
echo "rounded geometry · edges · bolts · ports · heat-sinks · cables"
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
echo "[1/7] Verifico sorgente V2 e vendor Three.js"
ls -lh "$SRC" || { echo "ERRORE: V2 WebGL non trovata"; exit 1; }

if [ ! -d "$FRONT/node_modules/three" ]; then
  echo "Three.js non trovato: installo localmente..."
  npm --prefix "$FRONT" install three@0.164.1
fi

cp -av "$FRONT/node_modules/three/examples/jsm/geometries/RoundedBoxGeometry.js" \
  "$PUBLIC/vendor/three/examples/jsm/geometries/RoundedBoxGeometry.js"

cp -av "$SRC" "$BK/"
cp -av "$SRC" "$DST"

echo
echo "[2/7] Patch V2 -> V2R1: rounded boxes, edge lines, micro-detail RF"
python3 - <<'PY'
from pathlib import Path

p = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "<title>TRFMC 3D RF Asset Renderer WebGL V2</title>",
    "<title>TRFMC 3D RF Asset Renderer WebGL V2R1 Detail Boost</title>"
)

s = s.replace(
    "TRFMC 3D RF ASSET RENDERER WEBGL V2</h1>",
    "TRFMC 3D RF ASSET RENDERER WEBGL V2R1 DETAIL BOOST</h1>"
)

s = s.replace(
    "True WebGL scene · procedural CAD-like RF assets · antennas · AAU/RRU · eNB/gNB · filters · MIMO arrays · microwave dish",
    "True WebGL scene · refined procedural RF meshes · rounded radomes · bolts · ports · heat-sinks · cables · dish/feed/filter detail"
)

s = s.replace(
    'import { OrbitControls } from \'three/addons/controls/OrbitControls.js\';',
    'import { OrbitControls } from \'three/addons/controls/OrbitControls.js\';\nimport { RoundedBoxGeometry } from \'three/addons/geometries/RoundedBoxGeometry.js\';'
)

# Materiali aggiuntivi più realistici.
s = s.replace(
'''  mat.red = new THREE.MeshStandardMaterial({color:0xff315e, metalness:.2, roughness:.4});
  mat.beamCyan = new THREE.MeshBasicMaterial({color:0x00e5ff, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});''',
'''  mat.red = new THREE.MeshStandardMaterial({color:0xff315e, metalness:.2, roughness:.4});
  mat.rubber = new THREE.MeshStandardMaterial({color:0x050708, metalness:.15, roughness:.82});
  mat.ceramic = new THREE.MeshPhysicalMaterial({color:0xf3fbff, metalness:.02, roughness:.18, clearcoat:.75, clearcoatRoughness:.12});
  mat.glass = new THREE.MeshPhysicalMaterial({color:0x80eaff, transparent:true, opacity:.22, roughness:.05, metalness:0, transmission:.35, clearcoat:1});
  mat.edge = new THREE.LineBasicMaterial({color:0x062c3f, transparent:true, opacity:.62});
  mat.beamCyan = new THREE.MeshBasicMaterial({color:0x00e5ff, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});'''
)

# Box smussati invece di scatole secche.
s = s.replace(
'''function box(w,h,d,material,name){
  return mesh(new THREE.BoxGeometry(w,h,d), material, name);
}''',
'''function box(w,h,d,material,name,radius=.035,segments=4){
  const minDim = Math.min(w,h,d);
  const rr = Math.min(radius, minDim * 0.28);
  return mesh(new RoundedBoxGeometry(w,h,d,segments,rr), material, name);
}

function sharpBox(w,h,d,material,name){
  return mesh(new THREE.BoxGeometry(w,h,d), material, name);
}

function addEdges(target, color=0x0b75a8, opacity=.58){
  const meshes = [];
  target.traverse(o => {
    if(o.isMesh && o.geometry && !(o.material && o.material.transparent && o.name.includes("beam"))){
      meshes.push(o);
    }
  });
  for(const m of meshes){
    const e = new THREE.EdgesGeometry(m.geometry, 24);
    const lm = new THREE.LineBasicMaterial({color, transparent:true, opacity});
    const line = new THREE.LineSegments(e,lm);
    line.name = "technical edge overlay";
    line.position.copy(m.position);
    line.rotation.copy(m.rotation);
    line.scale.copy(m.scale);
    m.parent.add(line);
  }
}

function bolt(radius=.035, height=.025, material=mat.darkMetal, name="hex bolt"){
  const b = mesh(new THREE.CylinderGeometry(radius,radius,height,6), material, name);
  b.rotation.x = Math.PI/2;
  return b;
}

function port(radius=.055, depth=.075, material=mat.gold, name="RF port"){
  const g = new THREE.Group();
  const ring = mesh(new THREE.TorusGeometry(radius, radius*.16, 12, 32), material, name+" ring");
  ring.rotation.x = Math.PI/2;
  g.add(ring);
  const pin = cyl(radius*.36, depth, material, 20, name+" center pin");
  pin.rotation.x = Math.PI/2;
  g.add(pin);
  return g;
}

function microVent(width=.42,count=7){
  const g = new THREE.Group();
  for(let i=0;i<count;i++){
    const v = sharpBox(width,.018,.018,mat.black,"ventilation slit");
    v.position.y = (i-(count-1)/2)*.045;
    g.add(v);
  }
  return g;
}

function screwGrid(w,h,cols,rows,z=.02){
  const g = new THREE.Group();
  for(let r=0;r<rows;r++){
    for(let c=0;c<cols;c++){
      const b = bolt(.018,.014,mat.darkMetal,"panel screw");
      b.position.set((c/(cols-1)-.5)*w,(r/(rows-1)-.5)*h,z);
      g.add(b);
    }
  }
  return g;
}

function smallNameplate(text){
  const c=document.createElement("canvas");
  c.width=512;c.height=128;
  const ctx=c.getContext("2d");
  ctx.fillStyle="rgba(2,10,16,.92)";
  ctx.fillRect(0,0,512,128);
  ctx.strokeStyle="#00e5ff";ctx.strokeRect(8,8,496,112);
  ctx.fillStyle="#e8f9ff";ctx.font="30px monospace";
  ctx.fillText(text,24,75);
  const tex=new THREE.CanvasTexture(c);
  const m=new THREE.MeshBasicMaterial({map:tex, transparent:true});
  const plane=new THREE.Mesh(new THREE.PlaneGeometry(.62,.155),m);
  plane.name="equipment nameplate";
  return plane;
}'''
)

# Miglioro settore antenna: screw grid, nameplate, vent, connettori più credibili.
s = s.replace(
'''  for(let i=0;i<4;i++){
    const port = cyl(.035,.10,mat.gold,20,"RF/AISG port");
    port.rotation.x = Math.PI/2;
    port.position.set(-.18+i*.12,-1.46,-.22);
    g.add(port);
  }

  return g;''',
'''  const screws = screwGrid(.34,2.28,2,8,.115);
  screws.position.set(0,0,.02);
  g.add(screws);

  const plate = smallNameplate("RRU/ANT");
  plate.position.set(0,-1.16,.115);
  g.add(plate);

  const vent = microVent(.32,6);
  vent.position.set(0,.95,.12);
  g.add(vent);

  for(let i=0;i<4;i++){
    const p3 = port(.043,.095,mat.gold,"RF/AISG port");
    p3.position.set(-.18+i*.12,-1.46,-.235);
    g.add(p3);
  }

  return g;'''
)

# Miglioro AAU/RRU: più fins, viti, nameplate, port cluster.
s = s.replace(
'''  for(let i=-5;i<=5;i++){
    const fin = box(.035,1.03,.22,mat.metal,"heat sink fin");
    fin.position.set(i*.055,0,.30);
    g.add(fin);
  }''',
'''  for(let i=-8;i<=8;i++){
    const fin = sharpBox(.022,1.05,.32,mat.metal,"dense heat sink fin");
    fin.position.set(i*.036,0,.33);
    g.add(fin);
  }'''
)

s = s.replace(
'''  for(let i=0;i<4;i++){
    const p = cyl(.045,.08,mat.gold,20,"RF/optical/DC connector");
    p.rotation.x = Math.PI/2;
    p.position.set(-.24+i*.16,-.48,-.25);
    g.add(p);
  }

  const ground = tubeBetween([.38,-.30,-.23],[.65,-.52,-.45],.018,mat.green,"grounding strap");
  g.add(ground);

  return g;''',
'''  const screwFace = screwGrid(.55,.82,3,5,-.22);
  screwFace.position.set(0,.04,0);
  g.add(screwFace);

  const np = smallNameplate("AAU");
  np.position.set(0,.28,-.235);
  g.add(np);

  for(let i=0;i<5;i++){
    const p3 = port(.047,.09,i===4?mat.green:mat.gold,i===4?"optical/ground port":"RF/DC connector");
    p3.position.set(-.30+i*.15,-.48,-.265);
    g.add(p3);
  }

  const ground = tubeBetween([.38,-.30,-.23],[.65,-.52,-.45],.018,mat.green,"grounding strap");
  g.add(ground);

  return g;'''
)

# Dettaglio tower: aggiungo clamp, junction box, marker balls.
s = s.replace(
'''  const cabinet = box(.95,1.05,.55,mat.darkMetal,"outdoor cabinet ODU/BBU");
  cabinet.position.set(.25,.62,-1.25);
  g.add(cabinet);

  addBeam(g,[-1.12,3.65,.10],0,p.tilt,p.beam,"cyan");''',
'''  const cabinet = box(.95,1.05,.55,mat.darkMetal,"outdoor cabinet ODU/BBU");
  cabinet.position.set(.25,.62,-1.25);
  g.add(cabinet);

  const cabPlate = smallNameplate("ODU / NIU");
  cabPlate.position.set(.25,.82,-1.535);
  g.add(cabPlate);

  for(let i=0;i<6;i++){
    const clamp = sharpBox(.34,.035,.055,mat.metal,"feeder cable clamp");
    clamp.position.set(-.35,.75+i*.42,-.76);
    g.add(clamp);
  }

  for(const y of [2.2,3.0,3.8]){
    const marker = sphere(.045,mat.red,16,"RF safety / inspection marker");
    marker.position.set(.82,y,.82);
    g.add(marker);
  }

  addBeam(g,[-1.12,3.65,.10],0,p.tilt,p.beam,"cyan");'''
)

# MIMO: aggiungo subarray frames, radome shell trasparente, RF feed manifold.
s = s.replace(
'''  const back = box(3.2,2.7,.22,mat.darkMetal,"AAU array backplane");
  back.position.set(0,1.45,0);
  g.add(back);''',
'''  const back = box(3.2,2.7,.22,mat.darkMetal,"AAU array backplane");
  back.position.set(0,1.45,0);
  g.add(back);

  const radome = box(3.32,2.82,.055,mat.glass,"transparent front radome cover",.06,6);
  radome.position.set(0,1.45,.31);
  g.add(radome);

  for(let sx=-1;sx<=1;sx+=2){
    for(let sy=-1;sy<=1;sy+=2){
      const frame = sharpBox(1.48,1.20,.035,mat.metal,"sub-array mechanical frame");
      frame.position.set(sx*.80,1.45+sy*.62,.34);
      g.add(frame);
    }
  }'''
)

s = s.replace(
'''  for(let c=0;c<cols;c+=Math.max(1,Math.floor(cols/6))){
    const line = tubeBetween([-1.325+c*pitchX,.33,.25],[-1.325+c*pitchX,2.58,.25],.006,mat.gold,"RF feed distribution trace");
    g.add(line);
  }

  addBeam(g,[0,1.45,.32],0,p.tilt,p.beam,"gold");''',
'''  const manifold = box(2.85,.12,.11,mat.copper,"RF corporate feed manifold");
  manifold.position.set(0,.18,.23);
  g.add(manifold);

  for(let c=0;c<cols;c+=Math.max(1,Math.floor(cols/6))){
    const line = tubeBetween([-1.325+c*pitchX,.33,.25],[-1.325+c*pitchX,2.58,.25],.008,mat.gold,"RF feed distribution trace");
    g.add(line);
  }

  for(let i=0;i<8;i++){
    const phaseDot = sphere(.028,i%2?mat.green:mat.gold,12,"phase shifter node");
    phaseDot.position.set(-1.15+i*.33,.20,.34);
    g.add(phaseDot);
  }

  addBeam(g,[0,1.45,.32],0,p.tilt,p.beam,"gold");'''
)

# RF filter: aggiungo flange, viti su flange, frecce input/output.
s = s.replace(
'''  const inConn = cone(.17,.10,.42,mat.gold,36,"N/SMA input connector");
  inConn.rotation.z = Math.PI/2;
  inConn.position.set(-2.28,.65,0);
  g.add(inConn);

  const outConn = cone(.17,.10,.42,mat.gold,36,"N/SMA output connector");
  outConn.rotation.z = -Math.PI/2;
  outConn.position.set(2.28,.65,0);
  g.add(outConn);''',
'''  const inFlange = box(.18,.48,.48,mat.darkMetal,"input connector square flange");
  inFlange.position.set(-2.12,.65,0);
  g.add(inFlange);
  const outFlange = box(.18,.48,.48,mat.darkMetal,"output connector square flange");
  outFlange.position.set(2.12,.65,0);
  g.add(outFlange);

  for(const x of [-2.23,2.23]){
    for(const yy of [.48,.82]){
      for(const zz of [-.18,.18]){
        const b = bolt(.022,.018,mat.metal,"flange bolt");
        b.position.set(x,yy,zz);
        b.rotation.y = Math.PI/2;
        g.add(b);
      }
    }
  }

  const inConn = cone(.17,.10,.42,mat.gold,36,"N/SMA input connector");
  inConn.rotation.z = Math.PI/2;
  inConn.position.set(-2.36,.65,0);
  g.add(inConn);

  const outConn = cone(.17,.10,.42,mat.gold,36,"N/SMA output connector");
  outConn.rotation.z = -Math.PI/2;
  outConn.position.set(2.36,.65,0);
  g.add(outConn);'''
)

# Dish: aggiungo shroud, waveguide, inclinometri/indicatori e bulloni.
s = s.replace(
'''  const rim = cyl(1.40,.035,mat.metal,96,"dish rim/shroud");
  rim.rotation.x = Math.PI/2;
  rim.position.set(0,1.8,.02);
  g.add(rim);''',
'''  const rim = cyl(1.40,.035,mat.metal,96,"dish rim/shroud");
  rim.rotation.x = Math.PI/2;
  rim.position.set(0,1.8,.02);
  g.add(rim);

  const shroud = mesh(new THREE.TorusGeometry(1.40,.055,16,128), mat.darkMetal, "deep microwave antenna shroud");
  shroud.rotation.x = Math.PI/2;
  shroud.position.set(0,1.8,.08);
  g.add(shroud);

  for(let i=0;i<16;i++){
    const a = i*Math.PI*2/16;
    const b = bolt(.022,.016,mat.metal,"dish rim bolt");
    b.position.set(Math.cos(a)*1.37,1.8+Math.sin(a)*1.37,.105);
    g.add(b);
  }'''
)

s = s.replace(
'''  const odu = buildAAU("microwave ODU");
  odu.position.set(0,.40,.62);
  odu.scale.set(.72,.72,.72);
  g.add(odu);''',
'''  const waveguide = box(.14,.65,.10,mat.gold,"rectangular waveguide from ODU to feed",.025,4);
  waveguide.position.set(0,.72,.68);
  g.add(waveguide);

  const odu = buildAAU("microwave ODU");
  odu.position.set(0,.40,.62);
  odu.scale.set(.72,.72,.72);
  g.add(odu);

  const inclinometer = box(.34,.08,.20,mat.green,"mechanical elevation scale / inclinometer");
  inclinometer.position.set(.92,.75,-.34);
  g.add(inclinometer);'''
)

# Inserisco funzione enhancer e la chiamo in buildAsset.
insert_before = '''function clearAsset(){'''
enhancer = r'''
function enhanceFinalAsset(group,p){
  if(!group) return;

  // Bordo tecnico su tutti i componenti: dà lettura CAD senza appiattire la mesh.
  addEdges(group,0x0b75a8,.46);

  // Piastra base metadati / scala tecnica.
  const plate = smallNameplate(`TRFMC ${p.asset}`);
  plate.position.set(0,-.08,-1.85);
  plate.rotation.x = -Math.PI/2;
  group.add(plate);

  // Coordinate axes miniaturizzate.
  const axes = new THREE.Group();
  axes.name = "local RF coordinate triad";
  axes.add(tubeBetween([0,0,0],[.55,0,0],.012,mat.red,"X azimuth axis"));
  axes.add(tubeBetween([0,0,0],[0,.55,0],.012,mat.green,"Y height axis"));
  axes.add(tubeBetween([0,0,0],[0,0,.55],.012,mat.gold,"Z boresight axis"));
  axes.position.set(-1.85,.15,-1.55);
  group.add(axes);

  // Piccoli isolatori/standoff su base: effetto meccanico reale.
  for(let i=0;i<4;i++){
    const x = i<2 ? -1.55 : 1.55;
    const z = i%2 ? -1.20 : 1.20;
    const st = cyl(.06,.10,mat.ceramic,24,"ceramic/mechanical standoff");
    st.position.set(x,.06,z);
    group.add(st);
  }
}
'''
if insert_before not in s:
    raise SystemExit("ERRORE: marker clearAsset non trovato")
s = s.replace(insert_before, enhancer + "\n" + insert_before, 1)

s = s.replace(
'''  currentAsset.rotation.y = p.yaw * Math.PI/180;
  scene.add(currentAsset);''',
'''  enhanceFinalAsset(currentAsset,p);
  currentAsset.rotation.y = p.yaw * Math.PI/180;
  scene.add(currentAsset);'''
)

# Report e label V2R1.
s = s.replace(
    'page:"TRFMC 3D RF Asset Renderer WebGL V2"',
    'page:"TRFMC 3D RF Asset Renderer WebGL V2R1 Detail Boost"'
)

s = s.replace(
    'renderer:"Three.js WebGL local vendor runtime"',
    'renderer:"Three.js WebGL local vendor runtime + RoundedBoxGeometry + CAD edge overlays + RF micro-details"'
)

s = s.replace(
    'addEvent("TRFMC WebGL RF Asset Renderer V2 online");',
    'addEvent("TRFMC WebGL RF Asset Renderer V2R1 detail boost online");'
)

s = s.replace(
    'WEBGL V2 · ${p.asset} · Box3 ${size.x.toFixed(2)}×${size.y.toFixed(2)}×${size.z.toFixed(2)} · camera fit',
    'WEBGL V2R1 · ${p.asset} · rounded CAD mesh · Box3 ${size.x.toFixed(2)}×${size.y.toFixed(2)}×${size.z.toFixed(2)} · camera fit'
)

p.write_text(s)
print("PATCH_OK: V2R1 detail boost created")
PY

echo
echo "[3/7] Verifico pagina e vendor"
ls -lh "$DST"
ls -lh "$PUBLIC/vendor/three/examples/jsm/geometries/RoundedBoxGeometry.js"

echo
echo "[4/7] Quality gate V2R1"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html \
  /trfmc_3d_rf_asset_renderer_webgl_v2.html \
  /vendor/three/build/three.module.js \
  /vendor/three/examples/jsm/controls/OrbitControls.js \
  /vendor/three/examples/jsm/loaders/GLTFLoader.js \
  /vendor/three/examples/jsm/geometries/RoundedBoxGeometry.js \
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
grep -nEi 'RoundedBoxGeometry|EdgesGeometry|TorusGeometry|TubeGeometry|Box3|WebGLRenderer|OrbitControls' "$DST" > "$OUT/webgl_detail_markers.txt" 2>/dev/null || true

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
markers=(out/"webgl_detail_markers.txt").read_text(errors="ignore")
needed=["RoundedBoxGeometry","EdgesGeometry","TorusGeometry","TubeGeometry","Box3","WebGLRenderer","OrbitControls"]
has_details=all(x in markers for x in needed)

data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html",
 "source_v2":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2.html",
 "http_non_200":http_non_200,
 "iframe_refs":iframes,
 "external_refs":external,
 "webgl_detail_markers_present":has_details,
 "result":"PASS" if http_non_200==0 and iframes==0 and external==0 and has_details else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_3d_rf_asset_renderer_webgl_v2r1_detail_boost"

echo
echo "[5/7] Report"
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
echo "=== WEBGL DETAIL MARKERS ==="
cat "$OUT/webgl_detail_markers.txt"

echo
echo "[6/7] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_3D_RF_ASSET_RENDERER_WEBGL_V2R1_DETAIL_BOOST_$TS.tar.gz"

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
echo "[7/7] Apertura"
echo "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html"
echo "============================================================"
