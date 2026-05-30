#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
TS="$(date +%Y%m%d_%H%M%S)"

SRC="$PUBLIC/trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html"
DST="$PUBLIC/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html"

OUT="$BASE/runtime/quality/TRFMC_3D_RF_ASSET_RENDERER_WEBGL_V2R2_REALITY_$TS"
BK="$BASE/runtime/backups/3D_RF_ASSET_RENDERER_WEBGL_V2R2_REALITY_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC 3D RF ASSET RENDERER WEBGL V2R2 - REALITY BOOST"
echo "PBR · shadows · radiation pattern lobes · air particles · surface detail"
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
echo "[1/7] Verifico sorgente V2R1"
ls -lh "$SRC" || { echo "ERRORE: V2R1 non trovata"; exit 1; }

cp -av "$SRC" "$BK/"
cp -av "$SRC" "$DST"

echo
echo "[2/7] Patch V2R2: PBR, pattern 3D, atmosfera, superfici, cavi, viti"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "<title>TRFMC 3D RF Asset Renderer WebGL V2R1 Detail Boost</title>",
    "<title>TRFMC 3D RF Asset Renderer WebGL V2R2 Reality</title>"
)

s = s.replace(
    "TRFMC 3D RF ASSET RENDERER WEBGL V2R1 DETAIL BOOST</h1>",
    "TRFMC 3D RF ASSET RENDERER WEBGL V2R2 REALITY</h1>"
)

s = s.replace(
    "True WebGL scene · refined procedural RF meshes · rounded radomes · bolts · ports · heat-sinks · cables · dish/feed/filter detail",
    "PBR scene · real shadows · micro-surface roughness · true 3D radiation lobes · air particles · RF cables · precision hardware"
)

s = s.replace(
    '<div class="overlay" id="sceneOverlay">WebGL V2 · procedural CAD-like RF assets · Box3 auto-fit</div>',
    '<div class="overlay" id="sceneOverlay">WebGL V2R2 · PBR · radiation pattern lobes · atmosphere · real shadows</div>'
)

# Global state: air/pattern references.
s = s.replace(
    "let currentAsset = null;",
    "let currentAsset = null;\nlet airField = null;\nlet radiationPattern = null;"
)

# Aggiungo funzioni texture/micro-superficie subito prima di makeMats.
marker = "function makeMats(){"
insert = r'''
function proceduralNoiseTexture(size=256, base=42, contrast=34){
  const c=document.createElement("canvas");
  c.width=size; c.height=size;
  const ctx=c.getContext("2d");
  const img=ctx.createImageData(size,size);
  for(let y=0;y<size;y++){
    for(let x=0;x<size;x++){
      const i=(y*size+x)*4;
      const grain = base + Math.sin(x*.17)*8 + Math.sin(y*.13)*8 + Math.random()*contrast;
      const v=Math.max(0,Math.min(255,grain));
      img.data[i]=v; img.data[i+1]=v; img.data[i+2]=v; img.data[i+3]=255;
    }
  }
  ctx.putImageData(img,0,0);
  const tex=new THREE.CanvasTexture(c);
  tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
  tex.repeat.set(5,5);
  tex.anisotropy=8;
  return tex;
}

function brushedMetalTexture(size=256){
  const c=document.createElement("canvas");
  c.width=size; c.height=size;
  const ctx=c.getContext("2d");
  ctx.fillStyle="#808c94";
  ctx.fillRect(0,0,size,size);
  for(let y=0;y<size;y++){
    const a=60+Math.random()*70;
    ctx.strokeStyle=`rgba(${a},${a+12},${a+18},0.35)`;
    ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(size,y+Math.sin(y*.12)*2); ctx.stroke();
  }
  const tex=new THREE.CanvasTexture(c);
  tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
  tex.repeat.set(3,3);
  tex.anisotropy=8;
  return tex;
}
'''
if marker not in s:
    raise SystemExit("marker makeMats non trovato")
s = s.replace(marker, insert + "\n" + marker, 1)

# Potenzio i materiali con mappe procedurali.
mat_marker = '''  mat.beamCyan = new THREE.MeshBasicMaterial({color:0x00e5ff, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});
  mat.beamGold = new THREE.MeshBasicMaterial({color:0xffd400, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});
  mat.glowGreen = new THREE.MeshBasicMaterial({color:0x75ff5b, transparent:true, opacity:.25, side:THREE.DoubleSide, depthWrite:false});
}'''

mat_repl = '''  mat.beamCyan = new THREE.MeshBasicMaterial({color:0x00e5ff, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});
  mat.beamGold = new THREE.MeshBasicMaterial({color:0xffd400, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});
  mat.patternHot = new THREE.MeshBasicMaterial({color:0xffd400, transparent:true, opacity:.26, side:THREE.DoubleSide, depthWrite:false});
  mat.patternCool = new THREE.MeshBasicMaterial({color:0x00e5ff, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});
  mat.air = new THREE.PointsMaterial({color:0x8befff, size:.025, transparent:true, opacity:.34, depthWrite:false});
  mat.contact = new THREE.MeshBasicMaterial({color:0x000000, transparent:true, opacity:.24, depthWrite:false});
  mat.glowGreen = new THREE.MeshBasicMaterial({color:0x75ff5b, transparent:true, opacity:.25, side:THREE.DoubleSide, depthWrite:false});

  const noise = proceduralNoiseTexture(256,55,42);
  const brushed = brushedMetalTexture(256);

  mat.radome.roughnessMap = noise;
  mat.radome.bumpMap = noise;
  mat.radome.bumpScale = .012;
  mat.radome.clearcoat = .75;
  mat.radome.clearcoatRoughness = .18;

  mat.metal.map = brushed;
  mat.metal.roughnessMap = brushed;
  mat.metal.roughness = .46;

  mat.darkMetal.map = brushed;
  mat.darkMetal.roughnessMap = noise;
  mat.darkMetal.roughness = .58;

  mat.blue.roughnessMap = noise;
  mat.blue.bumpMap = noise;
  mat.blue.bumpScale = .01;

  mat.copper.roughness = .36;
  mat.gold.roughness = .28;
}'''

if mat_marker not in s:
    raise SystemExit("material marker non trovato")
s = s.replace(mat_marker, mat_repl, 1)

# Inserisco componenti realistici prima di enhanceFinalAsset.
enh_marker = "function enhanceFinalAsset(group,p){"
reality_funcs = r'''
function threadedScrew(length=.44,r=.045){
  const g=new THREE.Group();
  g.name="threaded precision tuning screw";
  const shaft=cyl(r,length,mat.gold,32,"gold plated screw shaft");
  g.add(shaft);

  const pts=[];
  const turns=5;
  for(let i=0;i<=120;i++){
    const t=i/120;
    const a=t*turns*Math.PI*2;
    pts.push(new THREE.Vector3(Math.cos(a)*r*1.16, -length/2+t*length, Math.sin(a)*r*1.16));
  }
  const helix=new THREE.Mesh(
    new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts),120,r*.12,8,false),
    mat.copper
  );
  helix.name="visible screw thread";
  g.add(helix);

  const head=cyl(r*1.55,.045,mat.darkMetal,6,"hex screw head");
  head.position.y=length/2+.035;
  g.add(head);
  return g;
}

function addContactShadow(group){
  const shadow=new THREE.Mesh(
    new THREE.CircleGeometry(2.8,96),
    mat.contact
  );
  shadow.name="soft contact shadow / ground occlusion";
  shadow.rotation.x=-Math.PI/2;
  shadow.position.y=.018;
  group.add(shadow);
}

function addSurfaceInspectionMarks(group,p){
  const mk = new THREE.Group();
  mk.name="surface inspection details";
  for(let i=0;i<10;i++){
    const dot=sphere(.018 + Math.random()*.012, i%3===0?mat.red:mat.gold, 10, "paint mark / torque seal / inspection dot");
    dot.position.set(-1.2+Math.random()*2.4,.25+Math.random()*2.8,-1.0+Math.random()*2.0);
    mk.add(dot);
  }
  group.add(mk);
}

function addAirParticlesTo(group, origin=[0,2,0], radius=2.8, count=420){
  const geo=new THREE.BufferGeometry();
  const arr=new Float32Array(count*3);
  for(let i=0;i<count;i++){
    const r=radius*Math.pow(Math.random(),.55);
    const a=Math.random()*Math.PI*2;
    const b=(Math.random()-.5)*1.8;
    arr[i*3+0]=origin[0]+Math.cos(a)*r*.9;
    arr[i*3+1]=origin[1]+b+r*.05;
    arr[i*3+2]=origin[2]+Math.sin(a)*r*.55;
  }
  geo.setAttribute("position",new THREE.BufferAttribute(arr,3));
  const pts=new THREE.Points(geo,mat.air);
  pts.name="RF air particles / dust / humidity scattering";
  group.add(pts);
  return pts;
}

function radiationColor(v){
  const c=new THREE.Color();
  if(v>.72) c.setRGB(1.0,.78,.05);
  else if(v>.42) c.setRGB(.25,1.0,.22);
  else c.setRGB(.0,.72,1.0);
  return c;
}

function addRadiationPattern3D(group, origin, p, scale=1.0, label="3D radiation pattern"){
  const thetaSeg=52;
  const phiSeg=96;
  const beamRad=THREE.MathUtils.degToRad(Math.max(5,p.beam));
  const verts=[], colors=[], inds=[];

  for(let ti=0;ti<=thetaSeg;ti++){
    const th=ti/thetaSeg*Math.PI;
    for(let pi=0;pi<=phiSeg;pi++){
      const ph=pi/phiSeg*Math.PI*2;

      const main=Math.exp(-Math.pow(th/(beamRad*.62),2));
      const side1=.28*Math.exp(-Math.pow((th-beamRad*1.28)/(beamRad*.30),2))*Math.pow(Math.abs(Math.cos(ph*3)),1.4);
      const side2=.14*Math.exp(-Math.pow((th-beamRad*2.25)/(beamRad*.45),2))*Math.pow(Math.abs(Math.cos(ph*5)),1.1);
      const back=.08*Math.exp(-Math.pow((Math.PI-th)/.62,2));
      const ripple=.035*(1+Math.sin(ph*8+ti*.21))*Math.exp(-th*.85);

      const gain=Math.max(.015,main+side1+side2+back+ripple);
      const rr=(.28+gain*2.35)*scale;

      const x=rr*Math.sin(th)*Math.cos(ph)*.52;
      const y=-rr*Math.cos(th);
      const z=rr*Math.sin(th)*Math.sin(ph)*.52;
      verts.push(x,y,z);

      const col=radiationColor(gain);
      colors.push(col.r,col.g,col.b);
    }
  }

  for(let ti=0;ti<thetaSeg;ti++){
    for(let pi=0;pi<phiSeg;pi++){
      const a=ti*(phiSeg+1)+pi;
      const b=a+1;
      const c=(ti+1)*(phiSeg+1)+pi;
      const d=c+1;
      inds.push(a,c,b,b,c,d);
    }
  }

  const geo=new THREE.BufferGeometry();
  geo.setAttribute("position",new THREE.Float32BufferAttribute(verts,3));
  geo.setAttribute("color",new THREE.Float32BufferAttribute(colors,3));
  geo.setIndex(inds);
  geo.computeVertexNormals();

  const m=new THREE.Mesh(
    geo,
    new THREE.MeshBasicMaterial({
      vertexColors:true,
      transparent:true,
      opacity:.30,
      side:THREE.DoubleSide,
      depthWrite:false,
      blending:THREE.AdditiveBlending
    })
  );
  m.name=label+" primary/secondary lobes";
  m.position.set(...origin);
  m.rotation.x=p.tilt*Math.PI/180;
  group.add(m);

  const wire=new THREE.LineSegments(
    new THREE.WireframeGeometry(geo),
    new THREE.LineBasicMaterial({color:0x9ffcff,transparent:true,opacity:.16})
  );
  wire.name=label+" gain grid";
  wire.position.copy(m.position);
  wire.rotation.copy(m.rotation);
  group.add(wire);

  const mainAxis=tubeBetween(origin,[origin[0],origin[1]-2.5*scale,origin[2]],.018,mat.gold,"radiation boresight axis");
  group.add(mainAxis);

  return m;
}

function addCableConnectors(group){
  const connectorMat = mat.gold;
  for(let i=0;i<4;i++){
    const conn = port(.055,.09,connectorMat,"precision coaxial connector with ring");
    conn.position.set(-.35+i*.23,.22,-1.62);
    conn.rotation.y = Math.PI/2;
    group.add(conn);

    const boot = cyl(.052,.16,mat.rubber,24,"black strain relief boot");
    boot.rotation.z = Math.PI/2;
    boot.position.set(-.35+i*.23,.22,-1.78);
    group.add(boot);
  }
}
'''
if enh_marker not in s:
    raise SystemExit("enhanceFinalAsset marker non trovato")
s = s.replace(enh_marker, reality_funcs + "\n" + enh_marker, 1)

# Sostituisco addBeam con pattern 3D + aria + asse.
pattern = r'function addBeam\(group, origin, yawDeg, tiltDeg, hpbwDeg, color="cyan"\)\{.*?\n\}\n\nfunction buildTowerSite'
replacement = r'''function addBeam(group, origin, yawDeg, tiltDeg, hpbwDeg, color="cyan"){
  const p=val();
  p.beam=hpbwDeg;
  p.tilt=tiltDeg;

  // Il cono resta solo come volume ottico debole; il vero dato visivo è il radiation pattern.
  const length = Math.max(1.8, 4.8 - hpbwDeg/42);
  const radius = Math.tan((hpbwDeg*Math.PI/180)/2)*length*.28;
  const geom = new THREE.ConeGeometry(radius, length, 96, 1, true);
  const material = color === "gold" ? mat.beamGold : mat.beamCyan;
  const m = new THREE.Mesh(geom, material);
  m.name = "soft volumetric RF beam envelope";
  m.rotation.x = Math.PI/2 + tiltDeg*Math.PI/180;
  m.rotation.z = yawDeg*Math.PI/180;
  m.position.set(origin[0], origin[1] - length/2, origin[2]);
  group.add(m);

  addRadiationPattern3D(group, origin, p, color==="gold" ? 1.05 : .88, "true antenna radiation pattern");
  addAirParticlesTo(group, [origin[0], origin[1]-1.25, origin[2]], Math.max(1.25,radius*2.2), 220);

  const axis = tubeBetween(
    origin,
    [origin[0], origin[1]-length, origin[2]-Math.sin(tiltDeg*Math.PI/180)*length],
    .012,
    color==="gold"?mat.gold:mat.green,
    "boresight / maximum radiation axis"
  );
  group.add(axis);
}

function buildTowerSite'''
s2 = re.sub(pattern, replacement, s, flags=re.S)
if s2 == s:
    raise SystemExit("addBeam regex non ha trovato il blocco")
s = s2

# Sostituisco tuning screw cilindrico nel filtro con vite filettata.
old_screw = '''    const screw = cyl(.045,.42,mat.gold,24,"tuning screw");
    screw.position.set(x,1.42,.58);
    g.add(screw);'''
new_screw = '''    const screw = threadedScrew(.42,.045);
    screw.position.set(x,1.42,.58);
    g.add(screw);'''
if old_screw in s:
    s = s.replace(old_screw, new_screw)

# Miglioro enhanceFinalAsset: contact shadow, aria generale, cavi/connettori, ispezione.
old_enh_tail = '''  for(let i=0;i<4;i++){
    const x = i<2 ? -1.55 : 1.55;
    const z = i%2 ? -1.20 : 1.20;
    const st = cyl(.06,.10,mat.ceramic,24,"ceramic/mechanical standoff");
    st.position.set(x,.06,z);
    group.add(st);
  }
}'''
new_enh_tail = '''  for(let i=0;i<4;i++){
    const x = i<2 ? -1.55 : 1.55;
    const z = i%2 ? -1.20 : 1.20;
    const st = cyl(.06,.10,mat.ceramic,24,"ceramic/mechanical standoff");
    st.position.set(x,.06,z);
    group.add(st);
  }

  addContactShadow(group);
  addSurfaceInspectionMarks(group,p);
  addCableConnectors(group);
}'''
if old_enh_tail not in s:
    raise SystemExit("enhance tail non trovato")
s = s.replace(old_enh_tail, new_enh_tail, 1)

# Rendering fisico: output color, tone mapping, exposure, shadow camera.
shadow_marker = '''  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;'''
shadow_repl = '''  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.12;'''
if shadow_marker in s:
    s = s.replace(shadow_marker, shadow_repl, 1)

key_marker = '''  key.shadow.mapSize.set(2048,2048);
  scene.add(key);'''
key_repl = '''  key.shadow.mapSize.set(4096,4096);
  key.shadow.camera.near = 0.5;
  key.shadow.camera.far = 40;
  key.shadow.camera.left = -8;
  key.shadow.camera.right = 8;
  key.shadow.camera.top = 8;
  key.shadow.camera.bottom = -8;
  scene.add(key);'''
if key_marker in s:
    s = s.replace(key_marker, key_repl, 1)

# Aggiungo una luce bassa tipo riflesso ambiente.
light_marker = '''  const rim = new THREE.PointLight(0x00e5ff,2.0,25);
  rim.position.set(-4,4,-4);
  scene.add(rim);'''
light_repl = '''  const rim = new THREE.PointLight(0x00e5ff,2.0,25);
  rim.position.set(-4,4,-4);
  scene.add(rim);

  const lowWarm = new THREE.PointLight(0xffd400,.75,18);
  lowWarm.position.set(3,.8,3);
  scene.add(lowWarm);'''
if light_marker in s:
    s = s.replace(light_marker, light_repl, 1)

# Suolo più realistico: roughness e ricezione ombre già presenti; aggiungo reticolo morbido.
floor_marker = '''  scene.add(grid);'''
floor_repl = '''  scene.add(grid);

  const underGlow = new THREE.Mesh(
    new THREE.CircleGeometry(5.5,128),
    new THREE.MeshBasicMaterial({color:0x003a50, transparent:true, opacity:.10, depthWrite:false})
  );
  underGlow.rotation.x = -Math.PI/2;
  underGlow.position.y = .012;
  scene.add(underGlow);'''
if floor_marker in s:
    s = s.replace(floor_marker, floor_repl, 1)

# Animazione dell'aria e pattern.
anim_marker = '''  if(currentAsset){
    currentAsset.traverse(o => {
      if(o.name && o.name.includes("beam")){
        o.material.opacity = .15 + Math.sin(tick/35)*.045;
      }
    });
  }'''
anim_repl = '''  if(currentAsset){
    currentAsset.traverse(o => {
      if(o.name && o.name.includes("beam")){
        o.material.opacity = .14 + Math.sin(tick/35)*.04;
      }
      if(o.name && o.name.includes("radiation pattern")){
        o.rotation.y += 0.0008;
        o.material.opacity = .24 + Math.sin(tick/45)*.045;
      }
      if(o.name && o.name.includes("RF air particles")){
        o.rotation.y += 0.0015;
        o.rotation.z += 0.0006;
      }
    });
  }'''
if anim_marker in s:
    s = s.replace(anim_marker, anim_repl, 1)

# Report e label.
s = s.replace(
    'page:"TRFMC 3D RF Asset Renderer WebGL V2R1 Detail Boost"',
    'page:"TRFMC 3D RF Asset Renderer WebGL V2R2 Reality"'
)

s = s.replace(
    'renderer:"Three.js WebGL local vendor runtime + RoundedBoxGeometry + CAD edge overlays + RF micro-details"',
    'renderer:"Three.js WebGL local vendor runtime + PBR materials + procedural roughness + real shadows + 3D antenna radiation pattern + air particles"'
)

s = s.replace(
    'addEvent("TRFMC WebGL RF Asset Renderer V2R1 detail boost online");',
    'addEvent("TRFMC WebGL RF Asset Renderer V2R2 reality online");'
)

# Aggiorno box "what changed".
s = s.replace(
    '<tr><td>fake asset</td><td>procedural RF component model</td></tr>',
    '<tr><td>fake asset</td><td>procedural RF component model</td></tr><tr><td>simple cone beam</td><td>3D primary/secondary radiation lobes</td></tr><tr><td>flat surface</td><td>PBR roughness, shadows, atmosphere</td></tr>'
)

p.write_text(s)
print("PATCH_OK: V2R2 reality created")
PY

echo
echo "[3/7] Verifico nuova pagina"
ls -lh "$DST"

echo
echo "[4/7] Quality gate V2R2"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
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
grep -nEi 'ACESFilmicToneMapping|SRGBColorSpace|PCFSoftShadowMap|radiation pattern|primary/secondary|TubeGeometry|TorusGeometry|threaded|RF air particles|proceduralNoiseTexture|brushedMetalTexture|Box3|WebGLRenderer' "$DST" > "$OUT/reality_markers.txt" 2>/dev/null || true

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
markers=(out/"reality_markers.txt").read_text(errors="ignore")
needed=[
    "ACESFilmicToneMapping",
    "SRGBColorSpace",
    "PCFSoftShadowMap",
    "radiation pattern",
    "TubeGeometry",
    "TorusGeometry",
    "threaded",
    "RF air particles",
    "proceduralNoiseTexture",
    "brushedMetalTexture",
    "Box3",
    "WebGLRenderer"
]
has_reality=all(x in markers for x in needed)

data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html",
 "source_v2r1":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html",
 "http_non_200":http_non_200,
 "iframe_refs":iframes,
 "external_refs":external,
 "reality_markers_present":has_reality,
 "result":"PASS" if http_non_200==0 and iframes==0 and external==0 and has_reality else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_3d_rf_asset_renderer_webgl_v2r2_reality"

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
echo "=== REALITY MARKERS ==="
cat "$OUT/reality_markers.txt"

echo
echo "[6/7] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_3D_RF_ASSET_RENDERER_WEBGL_V2R2_REALITY_$TS.tar.gz"

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
echo "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html"
echo "============================================================"
