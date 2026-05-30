#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
TS="$(date +%Y%m%d_%H%M%S)"

PAGE="$PUBLIC/trfmc_3d_rf_asset_renderer_webgl_v2.html"
OUT="$BASE/runtime/quality/TRFMC_3D_RF_ASSET_RENDERER_WEBGL_V2_$TS"
BK="$BASE/runtime/backups/3D_RF_ASSET_RENDERER_WEBGL_V2_$TS"

mkdir -p "$PUBLIC" "$OUT" "$BK" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC 3D RF ASSET RENDERER WEBGL V2 - TRUE 3D SAFE CREATE"
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
echo "[1/7] Preparo Three.js locale, senza CDN runtime"

if [ ! -d "$FRONT/node_modules/three" ]; then
  echo "Three.js non trovato in frontend/node_modules: installo localmente nel progetto frontend..."
  npm --prefix "$FRONT" install three@0.164.1
else
  echo "Three.js già presente in frontend/node_modules"
fi

mkdir -p "$PUBLIC/vendor/three/build"
mkdir -p "$PUBLIC/vendor/three/examples/jsm/controls"
mkdir -p "$PUBLIC/vendor/three/examples/jsm/loaders"

cp -av "$FRONT/node_modules/three/build/three.module.js" \
  "$PUBLIC/vendor/three/build/three.module.js"

cp -av "$FRONT/node_modules/three/examples/jsm/controls/OrbitControls.js" \
  "$PUBLIC/vendor/three/examples/jsm/controls/OrbitControls.js"

cp -av "$FRONT/node_modules/three/examples/jsm/loaders/GLTFLoader.js" \
  "$PUBLIC/vendor/three/examples/jsm/loaders/GLTFLoader.js"

if [ -f "$PAGE" ]; then
  cp -av "$PAGE" "$BK/$(basename "$PAGE").bak"
fi

echo
echo "[2/7] Creo pagina WebGL V2"

cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC 3D RF Asset Renderer WebGL V2</title>
<style>
:root{
  --bg:#01060d;--panel:#071827;--panel2:#0a2135;--line:#0b75a8;--cyan:#00e5ff;
  --ok:#75ff5b;--warn:#ffd84d;--bad:#ff3d7f;--txt:#e8f9ff;--muted:#84a8ba;
  --gold:#ffd400;--violet:#b772ff;--blue:#1aa8ff;
}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:#01060d;color:var(--txt);font-family:Inter,Segoe UI,Arial,sans-serif;overflow:hidden}
body:before{content:"";position:fixed;inset:0;background:
radial-gradient(circle at 50% -20%,rgba(0,150,255,.22),transparent 42%),
linear-gradient(rgba(0,255,255,.035) 1px,transparent 1px),
linear-gradient(90deg,rgba(0,255,255,.025) 1px,transparent 1px);
background-size:auto,42px 42px,42px 42px;pointer-events:none}
.app{height:100vh;display:grid;grid-template-rows:64px 82px 1fr;gap:6px;padding:8px}
.top{display:grid;grid-template-columns:1fr auto;gap:12px;align-items:center;border:1px solid #0b5f8a;background:linear-gradient(180deg,#071827,#020811);padding:9px 12px;box-shadow:0 0 28px rgba(0,180,255,.18)}
h1{margin:0;font-size:21px;letter-spacing:2px}
small{color:var(--muted)}
.actions{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
button,select,input{background:#0b2238;border:1px solid #1175a5;color:var(--txt);border-radius:4px;padding:7px 10px;font-size:12px}
button:hover{border-color:var(--cyan);box-shadow:0 0 12px rgba(0,240,255,.35);cursor:pointer}
.led{width:10px;height:10px;border-radius:50%;background:var(--ok);box-shadow:0 0 12px var(--ok)}
.kpis{display:grid;grid-template-columns:repeat(12,1fr);gap:6px}
.kpi{border:1px solid #0b5f8a;background:linear-gradient(180deg,#092037,#04101b);padding:7px 8px;min-height:76px}
.kpi .l{font-size:9px;color:#80bad0;text-transform:uppercase;letter-spacing:.8px}
.kpi .v{font-size:17px;font-weight:800;margin-top:3px}
.kpi .s{font-size:10px;color:var(--ok)}
.main{display:grid;grid-template-columns:310px 1fr 360px;gap:6px;min-height:0}
.panel{border:1px solid #0b5f8a;background:rgba(3,14,24,.94);box-shadow:inset 0 0 22px rgba(0,150,255,.06),0 0 16px rgba(0,130,255,.08);overflow:hidden;position:relative}
.panel h2{margin:0;padding:8px 10px;border-bottom:1px solid #0b5f8a;color:#00e5ff;font-size:13px;text-transform:uppercase;letter-spacing:.8px;background:#061625}
.body{padding:9px;height:calc(100% - 35px);overflow:auto}
fieldset{border:1px solid #123f5d;border-radius:6px;margin:0 0 8px;padding:8px;background:#061523}
legend{font-size:10px;color:var(--gold);padding:0 5px}
.label{font-size:10px;color:#8fc0d2;text-transform:uppercase;margin:10px 0 4px}
.val{float:right;color:var(--ok);font-family:monospace}
.range{width:100%}
.viewport{position:relative;border:1px solid #0d6f9e;background:#020b12;min-height:0}
#threeRoot{position:absolute;inset:0}
.overlay{position:absolute;left:10px;top:10px;font-family:monospace;font-size:11px;color:var(--ok);background:rgba(0,0,0,.46);border:1px solid #154e34;padding:6px 8px;z-index:5}
.footerStatus{position:absolute;right:10px;bottom:8px;color:var(--ok);font-family:monospace;font-size:10px;border:1px solid #1d7c33;padding:3px 6px;background:#04110a;z-index:5}
.card{border:1px solid #104e73;background:#061625;padding:8px;border-radius:4px;margin-bottom:6px}
.card h3{margin:0 0 7px;font-size:12px;color:#00e5ff}
.mini{font-family:monospace;font-size:11px;color:#b9eaff;line-height:1.45}
.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}.gold{color:var(--gold)}
.table{width:100%;border-collapse:collapse;font-size:11px}
.table th,.table td{border-bottom:1px solid #12344c;padding:5px;text-align:left}
.table th{color:#83cfff}
.modeCard{display:grid;grid-template-columns:1fr auto;align-items:center;gap:6px;border:1px solid #104e73;background:#061625;padding:8px;margin-bottom:6px;border-radius:4px}
.modeCard b{color:#00e5ff}
.log{height:230px;background:#02070d;border:1px solid #123f5d;padding:7px;overflow:auto;font-family:monospace;font-size:10px;color:#bcecff}
@media(max-width:1450px){.main{grid-template-columns:270px 1fr 310px}.kpis{grid-template-columns:repeat(6,1fr)}}
</style>

<script type="importmap">
{
  "imports": {
    "three": "/vendor/three/build/three.module.js",
    "three/addons/": "/vendor/three/examples/jsm/"
  }
}
</script>
</head>

<body>
<div class="app">
  <header class="top">
    <div>
      <h1>TRFMC 3D RF ASSET RENDERER WEBGL V2</h1>
      <small>True WebGL scene · procedural CAD-like RF assets · antennas · AAU/RRU · eNB/gNB · filters · MIMO arrays · microwave dish</small>
    </div>
    <div class="actions">
      <button onclick="window.trfmcPreset('tower')">Tower Site</button>
      <button onclick="window.trfmcPreset('gnb')">gNB Stack</button>
      <button onclick="window.trfmcPreset('array')">MIMO Array</button>
      <button onclick="window.trfmcPreset('filter')">RF Filter</button>
      <button onclick="window.trfmcPreset('dish')">Microwave Dish</button>
      <button onclick="window.trfmcExport()">Export JSON</button>
      <button onclick="window.trfmcReset()">Reset</button>
      <span class="led"></span><span id="clock" class="mini">--:--:--</span>
    </div>
  </header>

  <section class="kpis">
    <div class="kpi"><div class="l">Renderer</div><div class="v">WEBGL</div><div class="s">Three.js local</div></div>
    <div class="kpi"><div class="l">Asset</div><div class="v" id="kAsset">Tower</div><div class="s">3D mesh</div></div>
    <div class="kpi"><div class="l">Meshes</div><div class="v" id="kMeshes">--</div><div class="s">scene count</div></div>
    <div class="kpi"><div class="l">Camera</div><div class="v" id="kCamera">FIT</div><div class="s">Box3 auto</div></div>
    <div class="kpi"><div class="l">Azimuth</div><div class="v" id="kAz">35°</div><div class="s">asset yaw</div></div>
    <div class="kpi"><div class="l">Tilt</div><div class="v" id="kTilt">8°</div><div class="s">electrical</div></div>
    <div class="kpi"><div class="l">Beam</div><div class="v" id="kBeam">65°</div><div class="s">HPBW</div></div>
    <div class="kpi"><div class="l">Array</div><div class="v" id="kArray">8x8</div><div class="s">elements</div></div>
    <div class="kpi"><div class="l">Freq</div><div class="v" id="kFreq">3.5</div><div class="s">GHz</div></div>
    <div class="kpi"><div class="l">Power</div><div class="v" id="kPow">40</div><div class="s">dBm</div></div>
    <div class="kpi"><div class="l">Layer</div><div class="v">4D/5D</div><div class="s">time/state</div></div>
    <div class="kpi"><div class="l">Gate</div><div class="v">LEAF</div><div class="s">zero iframe</div></div>
  </section>

  <main class="main">
    <aside class="panel">
      <h2>3D Object Controls</h2>
      <div class="body">
        <fieldset>
          <legend>OBJECT</legend>
          <div class="label">Asset <span class="val" id="vAsset"></span></div>
          <select id="asset">
            <option>TOWER_SITE</option>
            <option>GNB_STACK</option>
            <option>MIMO_ARRAY</option>
            <option>RF_FILTER</option>
            <option>MICROWAVE_DISH</option>
          </select>

          <div class="label">Material Mode</div>
          <select id="matMode">
            <option>INSTRUMENT</option>
            <option>FIELD_SITE</option>
            <option>XRAY_TECH</option>
            <option>ACADEMY</option>
          </select>

          <div class="label">Yaw deg <span class="val" id="vYaw"></span></div>
          <input id="yaw" class="range" type="range" min="-180" max="180" value="35" step="1">

          <div class="label">Zoom Bias <span class="val" id="vZoom"></span></div>
          <input id="zoom" class="range" type="range" min="0.65" max="1.55" value="1.00" step="0.01">
        </fieldset>

        <fieldset>
          <legend>RF</legend>
          <div class="label">Frequency GHz <span class="val" id="vFreq"></span></div>
          <input id="freq" class="range" type="range" min="0.4" max="40" value="3.5" step="0.1">

          <div class="label">Power dBm <span class="val" id="vPow"></span></div>
          <input id="pow" class="range" type="range" min="0" max="60" value="40" step="1">

          <div class="label">Beam HPBW deg <span class="val" id="vBeam"></span></div>
          <input id="beam" class="range" type="range" min="4" max="120" value="65" step="1">

          <div class="label">Electrical Tilt deg <span class="val" id="vTilt"></span></div>
          <input id="tilt" class="range" type="range" min="-15" max="25" value="8" step="1">
        </fieldset>

        <fieldset>
          <legend>ARRAY / DETAIL</legend>
          <div class="label">Rows <span class="val" id="vRows"></span></div>
          <input id="rows" class="range" type="range" min="2" max="16" value="8" step="1">

          <div class="label">Columns <span class="val" id="vCols"></span></div>
          <input id="cols" class="range" type="range" min="2" max="16" value="8" step="1">

          <div class="label">Detail <span class="val" id="vDetail"></span></div>
          <input id="detail" class="range" type="range" min="1" max="5" value="5" step="1">

          <button style="width:100%;margin-top:8px" onclick="window.trfmcRebuild()">Rebuild Mesh</button>
          <button style="width:100%;margin-top:5px" onclick="window.trfmcFit()">Fit Camera</button>
        </fieldset>
      </div>
    </aside>

    <section class="viewport">
      <div id="threeRoot"></div>
      <div class="overlay" id="sceneOverlay">WebGL V2 · procedural CAD-like RF assets · Box3 auto-fit</div>
      <div class="footerStatus">TRFMC WEBGL ASSET RENDERER · ACTIVE</div>
    </section>

    <aside class="panel">
      <h2>Asset Engineering / Evidence</h2>
      <div class="body">
        <div class="modeCard"><b>True 3D Renderer</b><span class="ok">WEBGL</span></div>
        <div class="modeCard"><b>Local Runtime</b><span class="ok">NO CDN</span></div>
        <div class="modeCard"><b>Camera</b><span class="ok">AUTO FIT</span></div>
        <div class="modeCard"><b>Future CAD Import</b><span class="warn">GLB/GLTF</span></div>

        <div class="card">
          <h3>What changed vs Canvas V1</h3>
          <table class="table">
            <tr><th>Before</th><th>Now</th></tr>
            <tr><td>2D polygons</td><td>real 3D meshes</td></tr>
            <tr><td>rectangles/triangles</td><td>boxes, cylinders, tubes, paraboloids, cones</td></tr>
            <tr><td>manual centering</td><td>Box3 camera fit</td></tr>
            <tr><td>flat beam</td><td>transparent volumetric beam cone</td></tr>
            <tr><td>fake asset</td><td>procedural RF component model</td></tr>
          </table>
        </div>

        <div class="card">
          <h3>Rendered Detail</h3>
          <div class="mini" id="detailOut">--</div>
        </div>

        <div class="card">
          <h3>Event Stream</h3>
          <div class="log" id="log"></div>
        </div>
      </div>
    </aside>
  </main>
</div>

<script type="module">
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const $ = id => document.getElementById(id);
let scene, camera, renderer, controls, root, grid, tick = 0;
let currentAsset = null;
let logLines = [];

const mat = {};
const stateIds = ["asset","matMode","yaw","zoom","freq","pow","beam","tilt","rows","cols","detail"];

function addEvent(msg){
  const t = new Date().toLocaleTimeString();
  logLines.unshift(`[${t}] ${msg}`);
  logLines = logLines.slice(0,80);
  $("log").textContent = logLines.join("\\n");
}

function saveState(){
  const s = {};
  for(const id of stateIds) s[id] = $(id).value;
  localStorage.setItem("trfmc_webgl_asset_renderer_v2", JSON.stringify(s));
}

function loadState(){
  try{
    const s = JSON.parse(localStorage.getItem("trfmc_webgl_asset_renderer_v2") || "{}");
    for(const k of Object.keys(s)) if($(k)) $(k).value = s[k];
  }catch(e){}
}

function val(){
  return {
    asset: $("asset").value,
    matMode: $("matMode").value,
    yaw: +$("yaw").value,
    zoom: +$("zoom").value,
    freq: +$("freq").value,
    pow: +$("pow").value,
    beam: +$("beam").value,
    tilt: +$("tilt").value,
    rows: +$("rows").value,
    cols: +$("cols").value,
    detail: +$("detail").value
  };
}

function makeMats(){
  mat.metal = new THREE.MeshStandardMaterial({color:0x93a9b8, metalness:.72, roughness:.34});
  mat.darkMetal = new THREE.MeshStandardMaterial({color:0x253744, metalness:.75, roughness:.42});
  mat.radome = new THREE.MeshPhysicalMaterial({color:0xe8f5f7, metalness:.08, roughness:.28, clearcoat:.55, clearcoatRoughness:.18});
  mat.blue = new THREE.MeshStandardMaterial({color:0x0077aa, metalness:.45, roughness:.35});
  mat.green = new THREE.MeshStandardMaterial({color:0x52e651, metalness:.15, roughness:.3, emissive:0x0b300b});
  mat.gold = new THREE.MeshStandardMaterial({color:0xffd400, metalness:.5, roughness:.25, emissive:0x332200});
  mat.black = new THREE.MeshStandardMaterial({color:0x03080c, metalness:.5, roughness:.45});
  mat.copper = new THREE.MeshStandardMaterial({color:0xb87333, metalness:.65, roughness:.32});
  mat.red = new THREE.MeshStandardMaterial({color:0xff315e, metalness:.2, roughness:.4});
  mat.beamCyan = new THREE.MeshBasicMaterial({color:0x00e5ff, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});
  mat.beamGold = new THREE.MeshBasicMaterial({color:0xffd400, transparent:true, opacity:.18, side:THREE.DoubleSide, depthWrite:false});
  mat.glowGreen = new THREE.MeshBasicMaterial({color:0x75ff5b, transparent:true, opacity:.25, side:THREE.DoubleSide, depthWrite:false});
}

function mesh(geometry, material, name){
  const m = new THREE.Mesh(geometry, material);
  m.castShadow = true;
  m.receiveShadow = true;
  if(name) m.name = name;
  return m;
}

function box(w,h,d,material,name){
  return mesh(new THREE.BoxGeometry(w,h,d), material, name);
}

function cyl(radius, height, material, segments=32, name){
  return mesh(new THREE.CylinderGeometry(radius, radius, height, segments), material, name);
}

function cone(r1,r2,h,material,segments=48,name){
  return mesh(new THREE.CylinderGeometry(r1,r2,h,segments), material, name);
}

function sphere(r, material, seg=24, name){
  return mesh(new THREE.SphereGeometry(r,seg,seg), material, name);
}

function tubeBetween(a,b,r,material,name){
  const start = new THREE.Vector3(...a);
  const end = new THREE.Vector3(...b);
  const mid = start.clone().add(end).multiplyScalar(.5);
  const dir = end.clone().sub(start);
  const len = dir.length();
  const m = cyl(r,len,material,16,name);
  m.position.copy(mid);
  m.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0), dir.normalize());
  return m;
}

function cableCurve(points, r=.025){
  const curve = new THREE.CatmullRomCurve3(points.map(p => new THREE.Vector3(...p)));
  return mesh(new THREE.TubeGeometry(curve, 48, r, 10, false), mat.black, "cable/hybrid feeder");
}

function addLabelPlane(group, text, pos, color=0x00e5ff){
  const c = document.createElement("canvas");
  c.width = 512; c.height = 128;
  const ctx = c.getContext("2d");
  ctx.fillStyle = "rgba(0,0,0,.55)";
  ctx.fillRect(0,0,c.width,c.height);
  ctx.strokeStyle = "#" + color.toString(16).padStart(6,"0");
  ctx.strokeRect(4,4,c.width-8,c.height-8);
  ctx.fillStyle = "#e8f9ff";
  ctx.font = "32px monospace";
  ctx.fillText(text,24,78);
  const tex = new THREE.CanvasTexture(c);
  const m = new THREE.Sprite(new THREE.SpriteMaterial({map:tex, transparent:true}));
  m.position.set(...pos);
  m.scale.set(1.8,.45,1);
  group.add(m);
}

function buildSectorAntenna(name="Sector Antenna"){
  const g = new THREE.Group();
  g.name = name;

  const radome = box(.42,2.65,.18,mat.radome,"white fiberglass radome");
  radome.position.set(0,0,0);
  g.add(radome);

  const rear = box(.50,2.72,.10,mat.darkMetal,"rear RF chassis");
  rear.position.set(0,0,-.15);
  g.add(rear);

  for(let i=-4;i<=4;i++){
    const line = tubeBetween([-.24,i*.28,.105],[.24,i*.28,.105],.007,mat.metal,"radome reinforcement seam");
    g.add(line);
  }

  for(let side of [-1,1]){
    const cap = cyl(.075,.55,mat.metal,24,"side bracket clamp");
    cap.rotation.z = Math.PI/2;
    cap.position.set(side*.34,.75,-.20);
    g.add(cap);
    const cap2 = cap.clone();
    cap2.position.y = -.75;
    g.add(cap2);
  }

  const ret = box(.30,.18,.12,mat.blue,"RET/AISG actuator");
  ret.position.set(.42,-1.12,-.20);
  g.add(ret);

  for(let i=0;i<4;i++){
    const port = cyl(.035,.10,mat.gold,20,"RF/AISG port");
    port.rotation.x = Math.PI/2;
    port.position.set(-.18+i*.12,-1.46,-.22);
    g.add(port);
  }

  return g;
}

function buildAAU(name="AAU/RRU"){
  const g = new THREE.Group();
  g.name = name;

  const body = box(.72,1.10,.36,mat.blue,"AAU/RRU radio body");
  g.add(body);

  for(let i=-5;i<=5;i++){
    const fin = box(.035,1.03,.22,mat.metal,"heat sink fin");
    fin.position.set(i*.055,0,.30);
    g.add(fin);
  }

  const door = box(.55,.70,.025,mat.darkMetal,"service door");
  door.position.set(0,.08,-.205);
  g.add(door);

  for(let i=0;i<4;i++){
    const p = cyl(.045,.08,mat.gold,20,"RF/optical/DC connector");
    p.rotation.x = Math.PI/2;
    p.position.set(-.24+i*.16,-.48,-.25);
    g.add(p);
  }

  const ground = tubeBetween([.38,-.30,-.23],[.65,-.52,-.45],.018,mat.green,"grounding strap");
  g.add(ground);

  return g;
}

function addBeam(group, origin, yawDeg, tiltDeg, hpbwDeg, color="cyan"){
  const length = Math.max(2.2, 5.5 - hpbwDeg/35);
  const radius = Math.tan((hpbwDeg*Math.PI/180)/2)*length*.45;
  const geom = new THREE.ConeGeometry(radius, length, 64, 1, true);
  const material = color === "gold" ? mat.beamGold : mat.beamCyan;
  const m = new THREE.Mesh(geom, material);
  m.name = "transparent volumetric RF beam cone";
  m.rotation.x = Math.PI/2 + tiltDeg*Math.PI/180;
  m.rotation.z = yawDeg*Math.PI/180;
  m.position.set(origin[0], origin[1] - length/2, origin[2]);
  group.add(m);

  const axis = tubeBetween(origin, [origin[0], origin[1]-length, origin[2]-Math.sin(tiltDeg*Math.PI/180)*length], .015, color==="gold"?mat.gold:mat.green, "beam center line");
  group.add(axis);
}

function buildTowerSite(p){
  const g = new THREE.Group();
  g.name = "Telecom tower site with sector antenna, AAU/RRU and feeder cables";

  const base = box(2.6,.18,2.6,mat.darkMetal,"concrete base pad");
  base.position.y = -.05;
  g.add(base);

  const legs = [[-.75,-.75], [.75,-.75], [.75,.75], [-.75,.75]];
  for(const [x,z] of legs){
    g.add(tubeBetween([x,0,z],[x,5.8,z],.035,mat.metal,"tower vertical leg"));
  }
  for(let y=.55;y<5.8;y+=.55){
    for(let i=0;i<4;i++){
      const a = legs[i], b = legs[(i+1)%4];
      g.add(tubeBetween([a[0],y,a[1]],[b[0],y+.27,b[1]],.018,mat.metal,"tower diagonal truss"));
      g.add(tubeBetween([b[0],y,a[1]],[a[0],y+.27,b[1]],.018,mat.metal,"tower cross brace"));
    }
  }

  const panelA = buildSectorAntenna("sector antenna A");
  panelA.position.set(-1.12,3.65,.15);
  panelA.rotation.y = Math.PI/2;
  panelA.rotation.z = p.tilt*Math.PI/180;
  g.add(panelA);

  const panelB = buildSectorAntenna("sector antenna B");
  panelB.position.set(1.12,3.45,.05);
  panelB.rotation.y = -Math.PI/2;
  panelB.rotation.z = -p.tilt*Math.PI/180;
  g.add(panelB);

  const aau = buildAAU("AAU/RRU mounted behind sector");
  aau.position.set(-1.42,2.55,-.32);
  aau.rotation.y = Math.PI/2;
  g.add(aau);

  g.add(cableCurve([[-1.43,2.0,-.35],[-1.15,1.5,-.55],[-.55,.8,-.72],[-.15,.18,-.80]],.018));
  g.add(cableCurve([[-1.35,2.25,-.30],[-.95,1.85,-.52],[-.40,1.05,-.70],[.15,.22,-.75]],.018));

  const cabinet = box(.95,1.05,.55,mat.darkMetal,"outdoor cabinet ODU/BBU");
  cabinet.position.set(.25,.62,-1.25);
  g.add(cabinet);

  addBeam(g,[-1.12,3.65,.10],0,p.tilt,p.beam,"cyan");
  addLabelPlane(g,"SECTOR + AAU/RRU",[-1.0,5.9,.2]);
  return g;
}

function buildGnbStack(p){
  const g = new THREE.Group();
  g.name = "gNodeB/eNodeB integrated stack";

  const rack = box(1.25,2.0,.72,mat.darkMetal,"gNB baseband / outdoor enclosure");
  rack.position.set(0,1.0,0);
  g.add(rack);

  for(let i=0;i<5;i++){
    const slot = box(1.05,.10,.77, i%2 ? mat.blue : mat.metal, "PSU/BBU/NIU module slot");
    slot.position.set(0,.35+i*.28,.02);
    g.add(slot);
  }

  const mast = tubeBetween([-.9,0,-.15],[-.9,4.8,-.15],.045,mat.metal,"site support mast");
  g.add(mast);

  for(let i=0;i<3;i++){
    const ant = buildSectorAntenna("integrated active sector antenna");
    ant.position.set(-.95,2.1+i*.85,.45);
    ant.rotation.y = Math.PI/2;
    ant.rotation.z = (p.tilt-4+i*2)*Math.PI/180;
    g.add(ant);

    const aau = buildAAU("AAU/RRU module");
    aau.position.set(-1.34,1.95+i*.85,-.02);
    aau.rotation.y = Math.PI/2;
    aau.scale.set(.75,.75,.75);
    g.add(aau);

    addBeam(g,[-.95,2.1+i*.85,.55],0,p.tilt+i*2,p.beam*.78,i===1?"gold":"cyan");
  }

  for(let i=0;i<3;i++){
    g.add(cableCurve([[-1.25,1.7+i*.65,-.1],[-.55,1.25+i*.25,-.45],[-.1,.95,-.35],[.2,.55,.1]],.016));
  }

  addLabelPlane(g,"gNB STACK / ACTIVE ANTENNA",[-.2,4.95,.55]);
  return g;
}

function buildMimoArray(p){
  const g = new THREE.Group();
  g.name = "Massive MIMO array with physical patch elements and phase gradient";

  const back = box(3.2,2.7,.22,mat.darkMetal,"AAU array backplane");
  back.position.set(0,1.45,0);
  g.add(back);

  const rows = p.rows, cols = p.cols;
  const pitchX = 2.65 / Math.max(1,cols-1);
  const pitchY = 2.15 / Math.max(1,rows-1);

  for(let r=0;r<rows;r++){
    for(let c=0;c<cols;c++){
      const phase = (r+c)/(rows+cols);
      const color = phase > .65 ? mat.gold : phase > .35 ? mat.green : mat.blue;
      const elem = box(.105,.105,.045,color,"individual radiating patch element");
      elem.position.set(-1.325+c*pitchX,.40+r*pitchY,.16);
      g.add(elem);

      const via = cyl(.018,.08,mat.copper,12,"feed via / RF element contact");
      via.rotation.x = Math.PI/2;
      via.position.set(elem.position.x,elem.position.y,.23);
      g.add(via);
    }
  }

  for(let c=0;c<cols;c+=Math.max(1,Math.floor(cols/6))){
    const line = tubeBetween([-1.325+c*pitchX,.33,.25],[-1.325+c*pitchX,2.58,.25],.006,mat.gold,"RF feed distribution trace");
    g.add(line);
  }

  addBeam(g,[0,1.45,.32],0,p.tilt,p.beam,"gold");
  addLabelPlane(g,`${rows}x${cols} MIMO ARRAY`,[0,3.25,.38],0xffd400);
  return g;
}

function buildRfFilter(p){
  const g = new THREE.Group();
  g.name = "RF cavity filter / duplexer with tuning screws and connectors";

  const body = box(4.0,.78,1.15,mat.metal,"milled aluminium cavity filter body");
  body.position.set(0,.65,0);
  g.add(body);

  for(let i=0;i<6;i++){
    const x = -1.55+i*.62;
    const cavity = cyl(.22,.12,mat.darkMetal,48,"round resonant cavity cover");
    cavity.rotation.x = Math.PI/2;
    cavity.position.set(x,1.05,.58);
    g.add(cavity);

    const screw = cyl(.045,.42,mat.gold,24,"tuning screw");
    screw.position.set(x,1.42,.58);
    g.add(screw);

    const lock = cyl(.08,.035,mat.copper,24,"lock nut");
    lock.position.set(x,1.22,.58);
    g.add(lock);
  }

  const inConn = cone(.17,.10,.42,mat.gold,36,"N/SMA input connector");
  inConn.rotation.z = Math.PI/2;
  inConn.position.set(-2.28,.65,0);
  g.add(inConn);

  const outConn = cone(.17,.10,.42,mat.gold,36,"N/SMA output connector");
  outConn.rotation.z = -Math.PI/2;
  outConn.position.set(2.28,.65,0);
  g.add(outConn);

  const path = cableCurve([[-1.8,1.04,.60],[-1.15,1.18,.70],[-.45,.98,.62],[.25,1.16,.66],[1.05,1.02,.62],[1.72,1.16,.70]],.025);
  path.material = mat.green;
  path.name = "internal RF coupling path";
  g.add(path);

  addLabelPlane(g,"RF CAVITY FILTER / DUPLEXER",[0,1.85,.05]);
  return g;
}

function paraboloidGeometry(radius=1.35, depth=.42, segR=28, segT=96){
  const verts=[], inds=[];
  for(let r=0;r<=segR;r++){
    const rr = radius * r / segR;
    const z = -depth * (rr/radius)**2;
    for(let t=0;t<=segT;t++){
      const th = 2*Math.PI*t/segT;
      verts.push(rr*Math.cos(th), rr*Math.sin(th), z);
    }
  }
  for(let r=0;r<segR;r++){
    for(let t=0;t<segT;t++){
      const a=r*(segT+1)+t, b=a+1, c=(r+1)*(segT+1)+t, d=c+1;
      inds.push(a,c,b,b,c,d);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(verts,3));
  g.setIndex(inds);
  g.computeVertexNormals();
  return g;
}

function buildMicrowaveDish(p){
  const g = new THREE.Group();
  g.name = "Microwave backhaul dish with ODU, feed horn and bracket";

  const dish = mesh(paraboloidGeometry(1.38,.55,32,128), mat.radome, "parabolic microwave reflector");
  dish.rotation.x = Math.PI/2;
  dish.position.set(0,1.8,0);
  g.add(dish);

  const rim = cyl(1.40,.035,mat.metal,96,"dish rim/shroud");
  rim.rotation.x = Math.PI/2;
  rim.position.set(0,1.8,.02);
  g.add(rim);

  const feedArm = tubeBetween([0,1.75,.05],[0,1.05,.72],.035,mat.metal,"feed support arm");
  g.add(feedArm);

  const horn = cone(.20,.06,.38,mat.gold,48,"feed horn");
  horn.rotation.x = Math.PI/2;
  horn.position.set(0,1.05,.72);
  g.add(horn);

  const odu = buildAAU("microwave ODU");
  odu.position.set(0,.40,.62);
  odu.scale.set(.72,.72,.72);
  g.add(odu);

  const bracket = tubeBetween([-1.6,.7,-.4],[1.6,.7,-.4],.045,mat.metal,"azimuth/elevation mounting bracket");
  g.add(bracket);
  g.add(tubeBetween([-.9,.7,-.4],[0,1.8,0],.035,mat.metal,"dish support strut"));
  g.add(tubeBetween([.9,.7,-.4],[0,1.8,0],.035,mat.metal,"dish support strut"));

  addBeam(g,[0,1.80,.05],0,p.tilt,Math.max(4,p.beam),"cyan");
  addLabelPlane(g,"MICROWAVE BACKHAUL ODU + DISH",[0,3.45,.2]);
  return g;
}

function clearAsset(){
  if(currentAsset){
    scene.remove(currentAsset);
    currentAsset.traverse(o => {
      if(o.geometry) o.geometry.dispose();
      if(o.material && o.material.dispose) o.material.dispose();
    });
  }
  currentAsset = null;
}

function buildAsset(){
  clearAsset();
  const p = val();

  if(p.asset==="TOWER_SITE") currentAsset = buildTowerSite(p);
  if(p.asset==="GNB_STACK") currentAsset = buildGnbStack(p);
  if(p.asset==="MIMO_ARRAY") currentAsset = buildMimoArray(p);
  if(p.asset==="RF_FILTER") currentAsset = buildRfFilter(p);
  if(p.asset==="MICROWAVE_DISH") currentAsset = buildMicrowaveDish(p);

  currentAsset.rotation.y = p.yaw * Math.PI/180;
  scene.add(currentAsset);

  fitCamera();
  updateKpi();
  addEvent(`MESH: ${p.asset} rebuilt with WebGL geometry`);
}

function fitCamera(){
  if(!currentAsset) return;

  currentAsset.updateWorldMatrix(true,true);
  const box = new THREE.Box3().setFromObject(currentAsset);
  const size = new THREE.Vector3();
  const center = new THREE.Vector3();
  box.getSize(size);
  box.getCenter(center);

  const p = val();
  const maxDim = Math.max(size.x,size.y,size.z);
  const fov = camera.fov * Math.PI/180;
  let dist = (maxDim / (2*Math.tan(fov/2))) * 1.45 / p.zoom;

  const dir = new THREE.Vector3(1.35,.92,1.15).normalize();
  camera.position.copy(center).add(dir.multiplyScalar(dist));
  camera.near = dist/100;
  camera.far = dist*100;
  camera.updateProjectionMatrix();
  controls.target.copy(center);
  controls.update();

  $("sceneOverlay").textContent = `WEBGL V2 · ${p.asset} · Box3 ${size.x.toFixed(2)}×${size.y.toFixed(2)}×${size.z.toFixed(2)} · camera fit`;
}

function init(){
  makeMats();

  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x02070d);
  scene.fog = new THREE.Fog(0x02070d, 12, 60);

  const rootEl = $("threeRoot");
  const r = rootEl.getBoundingClientRect();

  camera = new THREE.PerspectiveCamera(45, Math.max(1,r.width)/Math.max(1,r.height), .01, 500);

  renderer = new THREE.WebGLRenderer({antialias:true, alpha:false, powerPreference:"high-performance"});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setSize(r.width,r.height);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  rootEl.appendChild(renderer.domElement);

  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = .08;
  controls.enablePan = true;
  controls.autoRotate = false;

  const hemi = new THREE.HemisphereLight(0xb6f3ff,0x061018,1.4);
  scene.add(hemi);

  const key = new THREE.DirectionalLight(0xffffff,2.4);
  key.position.set(5,8,5);
  key.castShadow = true;
  key.shadow.mapSize.set(2048,2048);
  scene.add(key);

  const rim = new THREE.PointLight(0x00e5ff,2.0,25);
  rim.position.set(-4,4,-4);
  scene.add(rim);

  const floor = new THREE.Mesh(
    new THREE.PlaneGeometry(28,28,40,40),
    new THREE.MeshStandardMaterial({color:0x03131d, metalness:.2, roughness:.65, transparent:true, opacity:.85})
  );
  floor.rotation.x = -Math.PI/2;
  floor.receiveShadow = true;
  scene.add(floor);

  grid = new THREE.GridHelper(28,28,0x0b75a8,0x063448);
  grid.material.transparent = true;
  grid.material.opacity = .32;
  scene.add(grid);

  for(const id of stateIds) $(id).addEventListener("input", () => { saveState(); buildAsset(); });

  window.addEventListener("resize", resize);
  buildAsset();
  animate();
}

function resize(){
  const r = $("threeRoot").getBoundingClientRect();
  camera.aspect = Math.max(1,r.width)/Math.max(1,r.height);
  camera.updateProjectionMatrix();
  renderer.setSize(r.width,r.height);
  fitCamera();
}

function updateKpi(){
  const p = val();
  $("vAsset").textContent = p.asset;
  $("vYaw").textContent = p.yaw + "°";
  $("vZoom").textContent = p.zoom.toFixed(2);
  $("vFreq").textContent = p.freq.toFixed(1);
  $("vPow").textContent = p.pow;
  $("vBeam").textContent = p.beam + "°";
  $("vTilt").textContent = p.tilt + "°";
  $("vRows").textContent = p.rows;
  $("vCols").textContent = p.cols;
  $("vDetail").textContent = p.detail;

  $("kAsset").textContent = p.asset.replace("_"," ");
  $("kAz").textContent = p.yaw + "°";
  $("kTilt").textContent = p.tilt + "°";
  $("kBeam").textContent = p.beam + "°";
  $("kArray").textContent = p.rows + "x" + p.cols;
  $("kFreq").textContent = p.freq.toFixed(1);
  $("kPow").textContent = p.pow;

  let count = 0;
  if(currentAsset) currentAsset.traverse(o => { if(o.isMesh || o.isSprite) count++; });
  $("kMeshes").textContent = count;

  $("detailOut").innerHTML =
    `asset = ${p.asset}<br>` +
    `yaw = ${p.yaw}°<br>` +
    `freq = ${p.freq.toFixed(1)} GHz<br>` +
    `power = ${p.pow} dBm<br>` +
    `beam = ${p.beam}° HPBW<br>` +
    `tilt = ${p.tilt}°<br>` +
    `mesh objects = ${count}<br>` +
    `runtime = local Three.js / WebGL`;
}

function animate(){
  requestAnimationFrame(animate);
  tick++;
  $("clock").textContent = new Date().toLocaleTimeString();

  if(currentAsset){
    currentAsset.traverse(o => {
      if(o.name && o.name.includes("beam")){
        o.material.opacity = .15 + Math.sin(tick/35)*.045;
      }
    });
  }

  controls.update();
  renderer.render(scene,camera);

  if(tick % 240 === 0){
    addEvent("RENDER: WebGL mesh scene refreshed, camera stable");
  }
}

window.trfmcPreset = function(p){
  if(p==="tower"){ $("asset").value="TOWER_SITE"; $("yaw").value=35; $("zoom").value=1.0; $("freq").value=3.5; $("beam").value=65; $("tilt").value=8; }
  if(p==="gnb"){ $("asset").value="GNB_STACK"; $("yaw").value=-28; $("zoom").value=1.05; $("freq").value=3.7; $("beam").value=55; $("tilt").value=10; }
  if(p==="array"){ $("asset").value="MIMO_ARRAY"; $("yaw").value=18; $("zoom").value=1.08; $("rows").value=12; $("cols").value=12; $("beam").value=30; $("freq").value=3.6; }
  if(p==="filter"){ $("asset").value="RF_FILTER"; $("yaw").value=-36; $("zoom").value=1.1; $("freq").value=2.6; $("beam").value=80; $("tilt").value=0; }
  if(p==="dish"){ $("asset").value="MICROWAVE_DISH"; $("yaw").value=25; $("zoom").value=1.05; $("freq").value=18; $("beam").value=7; $("tilt").value=2; }
  saveState();
  buildAsset();
  addEvent(`PRESET: ${p.toUpperCase()} loaded`);
};

window.trfmcRebuild = function(){ buildAsset(); };
window.trfmcFit = function(){ fitCamera(); addEvent("CAMERA: Box3 fit applied"); };
window.trfmcReset = function(){ localStorage.removeItem("trfmc_webgl_asset_renderer_v2"); location.reload(); };

window.trfmcExport = function(){
  const p = val();
  const data = {
    page:"TRFMC 3D RF Asset Renderer WebGL V2",
    timestamp:new Date().toISOString(),
    renderer:"Three.js WebGL local vendor runtime",
    asset_parameters:p,
    gates:{standalone_leaf:true,iframe:false,external_refs:false,cdn_runtime:false},
    future:"replace procedural assets with GLB/GLTF CAD-grade meshes when available"
  };
  const blob = new Blob([JSON.stringify(data,null,2)],{type:"application/json"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "trfmc_3d_rf_asset_renderer_webgl_v2_report.json";
  a.click();
  URL.revokeObjectURL(a.href);
  addEvent("REPORT: WebGL renderer JSON exported");
};

loadState();
init();
addEvent("TRFMC WebGL RF Asset Renderer V2 online");
</script>
</body>
</html>
HTML

echo
echo "[3/7] Verifico pagina e vendor locale"
ls -lh "$PAGE"
ls -lh "$PUBLIC/vendor/three/build/three.module.js"
ls -lh "$PUBLIC/vendor/three/examples/jsm/controls/OrbitControls.js"
ls -lh "$PUBLIC/vendor/three/examples/jsm/loaders/GLTFLoader.js"

echo
echo "[4/7] Quality gate WebGL V2"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_3d_rf_asset_renderer_webgl_v2.html \
  /vendor/three/build/three.module.js \
  /vendor/three/examples/jsm/controls/OrbitControls.js \
  /vendor/three/examples/jsm/loaders/GLTFLoader.js \
  /trfmc_3d_rf_asset_renderer_lab_v1r2_auto_fit.html \
  /trfmc_official_safe_entrypoint_v6r3_command_center.html \
  /trfmc_signal_intelligence_center_v1.html \
  /trfmc_realtime_fft_gapless_receiver_lab_v1.html \
  /trfmc_rf_metrology_calibration_lab_v1.html \
  /api/health
do
  http_probe "$u" >> "$OUT/http.tsv"
done

grep -nEi '<iframe|src="/trfmc_(supervisor|unified|official_safe_entrypoint)' "$PAGE" > "$OUT/iframe_refs.txt" 2>/dev/null || true
grep -nEi 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' "$PAGE" > "$OUT/external_refs.txt" 2>/dev/null || true
grep -nEi 'three.module.js|OrbitControls|GLTFLoader|importmap|WebGLRenderer|Box3' "$PAGE" > "$OUT/webgl_markers.txt" 2>/dev/null || true

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
markers=(out/"webgl_markers.txt").read_text(errors="ignore")
has_webgl = "WebGLRenderer" in markers and "Box3" in markers and "OrbitControls" in markers

data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2.html",
 "http_non_200":http_non_200,
 "iframe_refs":iframes,
 "external_refs":external,
 "webgl_markers_present":has_webgl,
 "result":"PASS" if http_non_200==0 and iframes==0 and external==0 and has_webgl else "WARN"
}

(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_3d_rf_asset_renderer_webgl_v2"

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
echo "=== WEBGL MARKERS ==="
cat "$OUT/webgl_markers.txt"

echo
echo "[6/7] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_3D_RF_ASSET_RENDERER_WEBGL_V2_$TS.tar.gz"

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
echo "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2.html"
echo "============================================================"
