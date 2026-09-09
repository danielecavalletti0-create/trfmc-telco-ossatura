#!/usr/bin/env bash
set -u
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
PAGE="$PUBLIC/trfmc_3d_rf_asset_renderer_lab_v1.html"
OUT="$BASE/runtime/quality/TRFMC_3D_RF_ASSET_RENDERER_LAB_$TS"
BK="$BASE/runtime/backups/3D_RF_ASSET_RENDERER_LAB_$TS"

mkdir -p "$PUBLIC" "$OUT" "$BK" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC 3D RF ASSET RENDERER LAB V1 - SAFE CREATE"
echo "============================================================"

if [ -f "$PAGE" ]; then
  cp -av "$PAGE" "$BK/$(basename "$PAGE").bak"
fi

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

cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC 3D RF Asset Renderer Lab</title>
<style>
:root{
  --bg:#01060d;--panel:#071827;--panel2:#0a2135;--line:#0b75a8;--cyan:#00e5ff;
  --ok:#75ff5b;--warn:#ffd84d;--bad:#ff3d7f;--txt:#e8f9ff;--muted:#84a8ba;
  --gold:#ffd400;--violet:#b772ff;--blue:#1aa8ff;
}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:radial-gradient(circle at 50% -10%,#07365a 0,#02070d 42%,#00050a 100%);color:var(--txt);font-family:Inter,Segoe UI,Arial,sans-serif;overflow:hidden}
body:before{content:"";position:fixed;inset:0;background:
linear-gradient(rgba(0,255,255,.04) 1px,transparent 1px),
linear-gradient(90deg,rgba(0,255,255,.03) 1px,transparent 1px);
background-size:44px 44px;opacity:.36;pointer-events:none}
.app{height:100vh;display:grid;grid-template-rows:64px 88px 1fr;gap:6px;padding:8px}
.top{display:grid;grid-template-columns:1fr auto;gap:12px;align-items:center;border:1px solid #0b5f8a;background:linear-gradient(180deg,#071827,#020811);padding:9px 12px;box-shadow:0 0 28px rgba(0,180,255,.18)}
h1{margin:0;font-size:21px;letter-spacing:2px}
small{color:var(--muted)}
.actions{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
button,select,input{background:#0b2238;border:1px solid #1175a5;color:var(--txt);border-radius:4px;padding:7px 10px;font-size:12px}
button:hover{border-color:var(--cyan);box-shadow:0 0 12px rgba(0,240,255,.35);cursor:pointer}
.led{width:10px;height:10px;border-radius:50%;background:var(--ok);box-shadow:0 0 12px var(--ok)}
.kpis{display:grid;grid-template-columns:repeat(12,1fr);gap:6px}
.kpi{border:1px solid #0b5f8a;background:linear-gradient(180deg,#092037,#04101b);padding:7px 8px;min-height:82px}
.kpi .l{font-size:9px;color:#80bad0;text-transform:uppercase;letter-spacing:.8px}
.kpi .v{font-size:18px;font-weight:800;margin-top:3px}
.kpi .s{font-size:10px;color:var(--ok)}
.main{display:grid;grid-template-columns:300px 1.5fr 360px;gap:6px;min-height:0}
.panel{border:1px solid #0b5f8a;background:rgba(3,14,24,.94);box-shadow:inset 0 0 22px rgba(0,150,255,.06),0 0 16px rgba(0,130,255,.08);overflow:hidden;position:relative}
.panel h2{margin:0;padding:8px 10px;border-bottom:1px solid #0b5f8a;color:#00e5ff;font-size:13px;text-transform:uppercase;letter-spacing:.8px;background:#061625}
.body{padding:9px;height:calc(100% - 35px);overflow:auto}
fieldset{border:1px solid #123f5d;border-radius:6px;margin:0 0 8px;padding:8px;background:#061523}
legend{font-size:10px;color:var(--gold);padding:0 5px}
.label{font-size:10px;color:#8fc0d2;text-transform:uppercase;margin:10px 0 4px}
.val{float:right;color:var(--ok);font-family:monospace}
.range{width:100%}
.viewport{height:100%;display:grid;grid-template-rows:1fr 170px;gap:6px}
.canvasBox{position:relative;border:1px solid #0d6f9e;background:#020b12;overflow:hidden}
canvas{width:100%;height:100%;display:block}
.overlay{position:absolute;left:8px;top:8px;font-family:monospace;font-size:11px;color:var(--ok);background:rgba(0,0,0,.38);border:1px solid #154e34;padding:5px 7px}
.footerStatus{position:absolute;right:8px;bottom:6px;color:var(--ok);font-family:monospace;font-size:10px;border:1px solid #1d7c33;padding:3px 6px;background:#04110a}
.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.card{border:1px solid #104e73;background:#061625;padding:8px;border-radius:4px;margin-bottom:6px}
.card h3{margin:0 0 7px;font-size:12px;color:#00e5ff}
.mini{font-family:monospace;font-size:11px;color:#b9eaff;line-height:1.45}
.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}.gold{color:var(--gold)}
.table{width:100%;border-collapse:collapse;font-size:11px}
.table th,.table td{border-bottom:1px solid #12344c;padding:5px;text-align:left}
.table th{color:#83cfff}
.badge{display:inline-block;border:1px solid #1c7ba8;background:#092238;padding:3px 6px;border-radius:4px;margin:2px;font-size:10px}
.log{height:230px;background:#02070d;border:1px solid #123f5d;padding:7px;overflow:auto;font-family:monospace;font-size:10px;color:#bcecff}
.modeCard{display:grid;grid-template-columns:1fr auto;align-items:center;gap:6px;border:1px solid #104e73;background:#061625;padding:8px;margin-bottom:6px;border-radius:4px}
.modeCard b{color:#00e5ff}
@media(max-width:1450px){.main{grid-template-columns:270px 1.35fr 320px}.kpis{grid-template-columns:repeat(6,1fr)}}
</style>
</head>
<body>
<div class="app">
  <header class="top">
    <div>
      <h1>TRFMC 3D RF ASSET RENDERER LAB</h1>
      <small>Technical asset renderer · antennas · AAU/RRU · eNB/gNB · filters · arrays · beam cones · 4D/5D engineering layers</small>
    </div>
    <div class="actions">
      <button onclick="preset('tower')">Tower</button>
      <button onclick="preset('array')">MIMO Array</button>
      <button onclick="preset('filter')">RF Filter</button>
      <button onclick="preset('microwave')">Microwave Link</button>
      <button onclick="exportReport()">Export JSON</button>
      <button onclick="resetState()">Reset</button>
      <span class="led"></span><span id="clock" class="mini">--:--:--</span>
    </div>
  </header>

  <section class="kpis">
    <div class="kpi"><div class="l">Renderer</div><div class="v">2.5D</div><div class="s">pure canvas</div></div>
    <div class="kpi"><div class="l">Asset</div><div class="v" id="kAsset">Tower</div><div class="s">technical object</div></div>
    <div class="kpi"><div class="l">View</div><div class="v" id="kView">ISO</div><div class="s">projection</div></div>
    <div class="kpi"><div class="l">Azimuth</div><div class="v" id="kAz">35°</div><div class="s">rotation</div></div>
    <div class="kpi"><div class="l">Tilt</div><div class="v" id="kTilt">12°</div><div class="s">antenna</div></div>
    <div class="kpi"><div class="l">Beam</div><div class="v" id="kBeam">65°</div><div class="s">HPBW</div></div>
    <div class="kpi"><div class="l">Array</div><div class="v" id="kArray">8x8</div><div class="s">MIMO</div></div>
    <div class="kpi"><div class="l">Freq</div><div class="v" id="kFreq">3.5</div><div class="s">GHz</div></div>
    <div class="kpi"><div class="l">Power</div><div class="v" id="kPow">40</div><div class="s">dBm</div></div>
    <div class="kpi"><div class="l">Layer 4D</div><div class="v">TIME</div><div class="s">animation</div></div>
    <div class="kpi"><div class="l">Layer 5D</div><div class="v">STATE</div><div class="s">protocol/KPI</div></div>
    <div class="kpi"><div class="l">Gate</div><div class="v">LEAF</div><div class="s">zero iframe</div></div>
  </section>

  <main class="main">
    <aside class="panel">
      <h2>Renderer Controls</h2>
      <div class="body">
        <fieldset>
          <legend>OBJECT SELECTION</legend>
          <div class="label">Asset <span class="val" id="vAsset"></span></div>
          <select id="asset" onchange="update()">
            <option>TOWER_SITE</option>
            <option>MIMO_ARRAY</option>
            <option>RF_FILTER</option>
            <option>MICROWAVE_DISH</option>
            <option>GNB_STACK</option>
          </select>

          <div class="label">Projection</div>
          <select id="view" onchange="update()">
            <option>ISOMETRIC</option>
            <option>FRONT_TECH</option>
            <option>TOP_RF</option>
            <option>EXPLODED</option>
          </select>

          <div class="label">Azimuth deg <span class="val" id="vAz"></span></div>
          <input id="az" class="range" type="range" min="-90" max="90" value="35" step="1" oninput="update()">

          <div class="label">Scale <span class="val" id="vScale"></span></div>
          <input id="scale" class="range" type="range" min="0.6" max="1.8" value="1.05" step="0.01" oninput="update()">
        </fieldset>

        <fieldset>
          <legend>RF PARAMETERS</legend>
          <div class="label">Frequency GHz <span class="val" id="vFreq"></span></div>
          <input id="freq" class="range" type="range" min="0.4" max="40" value="3.5" step="0.1" oninput="update()">

          <div class="label">Power dBm <span class="val" id="vPow"></span></div>
          <input id="pow" class="range" type="range" min="0" max="60" value="40" step="1" oninput="update()">

          <div class="label">Beam HPBW deg <span class="val" id="vBeam"></span></div>
          <input id="beam" class="range" type="range" min="5" max="120" value="65" step="1" oninput="update()">

          <div class="label">Electrical tilt deg <span class="val" id="vTilt"></span></div>
          <input id="tilt" class="range" type="range" min="-15" max="20" value="12" step="1" oninput="update()">
        </fieldset>

        <fieldset>
          <legend>ARRAY / EQUIPMENT</legend>
          <div class="label">Array Rows <span class="val" id="vRows"></span></div>
          <input id="rows" class="range" type="range" min="2" max="16" value="8" step="1" oninput="update()">

          <div class="label">Array Columns <span class="val" id="vCols"></span></div>
          <input id="cols" class="range" type="range" min="2" max="16" value="8" step="1" oninput="update()">

          <div class="label">Detail Level <span class="val" id="vDetail"></span></div>
          <input id="detail" class="range" type="range" min="1" max="5" value="4" step="1" oninput="update()">

          <button style="width:100%;margin-top:8px" onclick="addEvent('RENDER: engineering object re-projected')">Reproject</button>
          <button style="width:100%;margin-top:5px" onclick="addEvent('ANNOTATION: RF ports and signal path highlighted')">Annotate Ports</button>
        </fieldset>
      </div>
    </aside>

    <section class="panel viewport">
      <div class="canvasBox">
        <canvas id="scene"></canvas>
        <div class="overlay" id="sceneOverlay">3D/4D/5D technical renderer · no CDN · no iframe</div>
        <div class="footerStatus">TRFMC ASSET RENDERER · ACTIVE</div>
      </div>

      <div class="grid3">
        <div class="card">
          <h3>3D Geometry Layer</h3>
          <div class="mini" id="geoOut"></div>
        </div>
        <div class="card">
          <h3>4D RF/Time Layer</h3>
          <div class="mini" id="timeOut"></div>
        </div>
        <div class="card">
          <h3>5D State/Protocol Layer</h3>
          <div class="mini" id="stateOut"></div>
        </div>
      </div>
    </section>

    <aside class="panel">
      <h2>Object Library / Evidence</h2>
      <div class="body">
        <div class="modeCard"><b>Antenna sector</b><span class="ok">ACTIVE</span></div>
        <div class="modeCard"><b>AAU/RRU block</b><span class="ok">ACTIVE</span></div>
        <div class="modeCard"><b>Filter cavity</b><span class="ok">ACTIVE</span></div>
        <div class="modeCard"><b>Array elements</b><span class="ok">ACTIVE</span></div>
        <div class="modeCard"><b>Beam cone</b><span class="ok">ACTIVE</span></div>

        <div class="card">
          <h3>Engineering Object Rules</h3>
          <table class="table">
            <tr><th>Object</th><th>Visual accuracy target</th></tr>
            <tr><td>Panel antenna</td><td>radome, brackets, ports, downtilt</td></tr>
            <tr><td>AAU/RRU</td><td>heat fins, optical/DC ports, grounding</td></tr>
            <tr><td>Filter</td><td>cavities, tuning screws, SMA/N ports</td></tr>
            <tr><td>MIMO array</td><td>element grid, phase gradient, beam</td></tr>
            <tr><td>Microwave dish</td><td>dish, feed, ODU, waveguide</td></tr>
          </table>
        </div>

        <div class="card">
          <h3>Export Bundle</h3>
          <div class="mini">
            Object parameters: <span class="ok">enabled</span><br>
            View/projection: <span class="ok">enabled</span><br>
            RF layer: <span class="ok">enabled</span><br>
            State layer: <span class="ok">enabled</span><br>
            Future WebGL port: <span class="warn">planned</span>
          </div>
          <button style="width:100%;margin-top:8px" onclick="exportReport()">Export Renderer JSON</button>
        </div>

        <div class="card">
          <h3>Event Stream</h3>
          <div class="log" id="log"></div>
        </div>
      </div>
    </aside>
  </main>
</div>

<script>
"use strict";
const $ = id => document.getElementById(id);
let tick = 0, logLines=[];

function addEvent(msg){
  const t=new Date().toLocaleTimeString();
  logLines.unshift(`[${t}] ${msg}`);
  logLines=logLines.slice(0,90);
  $("log").textContent=logLines.join("\n");
}
function n(v,d=2){return Number(v).toFixed(d)}

function loadState(){
  try{
    const s=JSON.parse(localStorage.getItem("trfmc_3d_asset_renderer_v1")||"{}");
    for(const k of Object.keys(s)){ if($(k)) $(k).value=s[k]; }
  }catch(e){}
}
function saveState(){
  const ids=["asset","view","az","scale","freq","pow","beam","tilt","rows","cols","detail"];
  const s={}; ids.forEach(id=>s[id]=$(id).value);
  localStorage.setItem("trfmc_3d_asset_renderer_v1",JSON.stringify(s));
}
function resetState(){localStorage.removeItem("trfmc_3d_asset_renderer_v1");location.reload()}

function preset(p){
  if(p==="tower"){ $("asset").value="TOWER_SITE"; $("view").value="ISOMETRIC"; $("az").value=35; $("beam").value=65; $("tilt").value=12; $("freq").value=3.5; }
  if(p==="array"){ $("asset").value="MIMO_ARRAY"; $("view").value="FRONT_TECH"; $("rows").value=8; $("cols").value=8; $("beam").value=28; $("freq").value=3.7; }
  if(p==="filter"){ $("asset").value="RF_FILTER"; $("view").value="EXPLODED"; $("freq").value=2.6; $("pow").value=30; $("detail").value=5; }
  if(p==="microwave"){ $("asset").value="MICROWAVE_DISH"; $("view").value="ISOMETRIC"; $("freq").value=18; $("beam").value=6; $("pow").value=23; }
  addEvent("PRESET: "+p.toUpperCase()+" loaded");
  update();
}

function calc(){
  return {
    asset:$("asset").value, view:$("view").value,
    az:+$("az").value, scale:+$("scale").value, freq:+$("freq").value,
    pow:+$("pow").value, beam:+$("beam").value, tilt:+$("tilt").value,
    rows:+$("rows").value, cols:+$("cols").value, detail:+$("detail").value
  };
}

function iso(x,y,z,c){
  const p=calc();
  const az=p.az*Math.PI/180;
  const ca=Math.cos(az), sa=Math.sin(az);
  const xr=x*ca-y*sa, yr=x*sa+y*ca;
  const s=46*p.scale;
  return [c.cx+(xr-yr)*s*0.72, c.cy+(xr+yr)*s*0.38-z*s];
}
function poly(ctx,pts,fill,stroke="#1aa8ff",alpha=1){
  ctx.save();ctx.globalAlpha=alpha;ctx.fillStyle=fill;ctx.strokeStyle=stroke;ctx.lineWidth=1.2;
  ctx.beginPath();pts.forEach((p,i)=>i?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]));ctx.closePath();ctx.fill();ctx.stroke();ctx.restore();
}
function box(ctx,c,x,y,z,w,d,h,color="#0b72a8"){
  const A=iso(x,y,z,c),B=iso(x+w,y,z,c),C=iso(x+w,y+d,z,c),D=iso(x,y+d,z,c);
  const E=iso(x,y,z+h,c),F=iso(x+w,y,z+h,c),G=iso(x+w,y+d,z+h,c),H=iso(x,y+d,z+h,c);
  poly(ctx,[E,F,G,H],shade(color,1.2));
  poly(ctx,[A,B,F,E],shade(color,.95));
  poly(ctx,[B,C,G,F],shade(color,.75));
  poly(ctx,[C,D,H,G],shade(color,.62));
  return {A,B,C,D,E,F,G,H};
}
function shade(hex,k){
  const h=hex.replace("#","");let r=parseInt(h.slice(0,2),16),g=parseInt(h.slice(2,4),16),b=parseInt(h.slice(4,6),16);
  r=Math.max(0,Math.min(255,Math.round(r*k)));g=Math.max(0,Math.min(255,Math.round(g*k)));b=Math.max(0,Math.min(255,Math.round(b*k)));
  return `rgb(${r},${g},${b})`;
}
function line3(ctx,c,a,b,col="#75ff5b",lw=1.5){
  const A=iso(a[0],a[1],a[2],c),B=iso(b[0],b[1],b[2],c);
  ctx.strokeStyle=col;ctx.lineWidth=lw;ctx.beginPath();ctx.moveTo(A[0],A[1]);ctx.lineTo(B[0],B[1]);ctx.stroke();
}
function label(ctx,text,x,y,col="#dff8ff"){
  ctx.fillStyle=col;ctx.font="10px monospace";ctx.fillText(text,x,y);
}

function drawTower(ctx,c,p){
  line3(ctx,c,[0,0,0],[0,0,6.8],"#8fc0d2",4);
  for(let z=0;z<6.5;z+=.7){
    line3(ctx,c,[-.45,0,z],[.45,0,z+.35],"rgba(143,192,210,.5)",1);
    line3(ctx,c,[.45,0,z],[-.45,0,z+.35],"rgba(143,192,210,.5)",1);
  }
  box(ctx,c,-.7,-.28,2.9,.18,.12,2.1,"#d6edf5");
  box(ctx,c,-.45,-.32,2.6,.2,.18,1.4,"#0b72a8");
  box(ctx,c,.35,-.28,3.2,.18,.12,1.9,"#d6edf5");
  box(ctx,c,.58,-.32,2.8,.2,.18,1.2,"#0b72a8");
  box(ctx,c,-.25,-.7,.1,.55,.45,.55,"#4f6b7c");
  line3(ctx,c,[-.15,-.5,.65],[-.52,-.24,2.7],"#ffd400",1.2);
  line3(ctx,c,[.1,-.48,.65],[.42,-.24,2.9],"#00e5ff",1.2);
  drawBeam(ctx,c,[.7,-.22,3.8],p.beam,p.tilt,"#75ff5b");
  drawBeam(ctx,c,[-.6,-.22,3.8],p.beam,p.tilt,"#00e5ff");
}

function drawArray(ctx,c,p){
  const rows=p.rows, cols=p.cols, spacing=.16;
  const ox=-cols*spacing/2, oz=2.7;
  box(ctx,c,-1.4,-.12,1.9,2.8,.14,2.2,"#1b4f72");
  for(let r=0;r<rows;r++){
    for(let cc=0;cc<cols;cc++){
      const x=ox+cc*spacing, z=oz+(r-rows/2)*spacing;
      box(ctx,c,x,-.22,z,.07,.08,.07,(r+cc)%2?"#75ff5b":"#00e5ff");
    }
  }
  for(let cc=0;cc<cols;cc+=2){
    line3(ctx,c,[ox+cc*spacing,-.34,1.9],[ox+cc*spacing,-.34,4.15],"rgba(255,212,0,.65)",.8);
  }
  drawBeam(ctx,c,[0,-.32,3.05],p.beam,p.tilt,"#ffd400");
}

function drawFilter(ctx,c,p){
  box(ctx,c,-1.7,-.5,1,3.4,1,1,"#55738a");
  for(let i=0;i<6;i++){
    box(ctx,c,-1.35+i*.54,-.62,2.05,.26,.18,.16,"#d8edf5");
    line3(ctx,c,[-1.22+i*.54,-.7,2.21],[-1.22+i*.54,-.96,2.45],"#ffd400",1);
  }
  box(ctx,c,-2.1,-.1,1.35,.38,.28,.34,"#00a7c9");
  box(ctx,c,1.72,-.1,1.35,.38,.28,.34,"#00a7c9");
  for(let i=0;i<5;i++) line3(ctx,c,[-1.1+i*.55,-.48,2.05],[-.84+i*.55,-.48,2.05],"#75ff5b",1);
}

function drawDish(ctx,c,p){
  const center=iso(0,0,2.6,c);
  ctx.save();
  ctx.strokeStyle="#dff8ff";ctx.lineWidth=2;
  for(let r=20;r<95;r+=14){ctx.beginPath();ctx.ellipse(center[0],center[1],r,r*.55,-.25,0,Math.PI*2);ctx.stroke();}
  ctx.strokeStyle="#75ff5b";
  for(let i=0;i<8;i++){ctx.beginPath();ctx.moveTo(center[0],center[1]);ctx.lineTo(center[0]+Math.cos(i*Math.PI/4-.25)*90,center[1]+Math.sin(i*Math.PI/4-.25)*50);ctx.stroke();}
  ctx.restore();
  box(ctx,c,-.18,-.12,1.1,.36,.28,1.1,"#4f6b7c");
  box(ctx,c,.45,-.18,2.35,.35,.25,.28,"#00a7c9");
  line3(ctx,c,[.55,-.1,2.5],[0,0,2.6],"#ffd400",2);
  drawBeam(ctx,c,[.9,-.2,2.7],p.beam,p.tilt,"#75ff5b");
}

function drawGnb(ctx,c,p){
  box(ctx,c,-1.5,-.5,.2,3,1,1.3,"#344b5c");
  box(ctx,c,-1.25,-.7,1.7,.5,.25,2.4,"#d6edf5");
  box(ctx,c,-.45,-.72,1.55,.5,.25,2.6,"#d6edf5");
  box(ctx,c,.35,-.7,1.8,.5,.25,2.1,"#d6edf5");
  box(ctx,c,1.0,-.55,1.0,.55,.45,1,"#0b72a8");
  for(let i=0;i<4;i++) line3(ctx,c,[-.9+i*.45,-.52,1.45],[-.9+i*.45,-.72,1.75+i*.15],"#ffd400",1);
  drawBeam(ctx,c,[-.95,-.85,3.0],p.beam,p.tilt,"#00e5ff");
  drawBeam(ctx,c,[-.15,-.85,3.1],p.beam,p.tilt,"#75ff5b");
  drawBeam(ctx,c,[.65,-.85,2.9],p.beam,p.tilt,"#ffd400");
}

function drawBeam(ctx,c,origin,beam,tilt,col){
  const o=iso(origin[0],origin[1],origin[2],c);
  const len=1.8+Math.max(0,60-beam)/22;
  const spread=Math.tan((beam*Math.PI/180)/2)*len*.55;
  const zdrop=Math.sin(tilt*Math.PI/180)*1.2;
  const a=iso(origin[0]-spread,origin[1]-len,origin[2]-zdrop,c);
  const b=iso(origin[0]+spread,origin[1]-len,origin[2]-zdrop,c);
  ctx.save();
  ctx.globalAlpha=.22;ctx.fillStyle=col;ctx.strokeStyle=col;ctx.lineWidth=1.2;
  ctx.beginPath();ctx.moveTo(o[0],o[1]);ctx.lineTo(a[0],a[1]);ctx.lineTo(b[0],b[1]);ctx.closePath();ctx.fill();ctx.stroke();
  ctx.globalAlpha=.7;ctx.beginPath();ctx.moveTo(o[0],o[1]);ctx.lineTo((a[0]+b[0])/2,(a[1]+b[1])/2);ctx.stroke();
  ctx.restore();
}

function drawScene(){
  const canvas=$("scene"), r=canvas.getBoundingClientRect(), dpr=devicePixelRatio||1;
  canvas.width=r.width*dpr; canvas.height=r.height*dpr;
  const ctx=canvas.getContext("2d"); ctx.setTransform(dpr,0,0,dpr,0,0);
  const w=r.width,h=r.height,p=calc(), c={cx:w/2,cy:h*.62};
  ctx.fillStyle="#020b12";ctx.fillRect(0,0,w,h);

  ctx.strokeStyle="rgba(0,210,255,.14)";
  for(let i=-20;i<40;i++){
    const A=iso(i,-12,0,c),B=iso(i,12,0,c);
    ctx.beginPath();ctx.moveTo(A[0],A[1]);ctx.lineTo(B[0],B[1]);ctx.stroke();
    const C=iso(-12,i,0,c),D=iso(12,i,0,c);
    ctx.beginPath();ctx.moveTo(C[0],C[1]);ctx.lineTo(D[0],D[1]);ctx.stroke();
  }

  if(p.asset==="TOWER_SITE") drawTower(ctx,c,p);
  if(p.asset==="MIMO_ARRAY") drawArray(ctx,c,p);
  if(p.asset==="RF_FILTER") drawFilter(ctx,c,p);
  if(p.asset==="MICROWAVE_DISH") drawDish(ctx,c,p);
  if(p.asset==="GNB_STACK") drawGnb(ctx,c,p);

  ctx.fillStyle="#83cfff";ctx.font="11px monospace";
  label(ctx,"3D geometry: "+p.asset,14,22);
  label(ctx,"4D layer: t="+(tick/60).toFixed(1)+"s / freq="+p.freq.toFixed(1)+"GHz",14,40,"#75ff5b");
  label(ctx,"5D state: RF POWER "+p.pow+" dBm · protocol KPI overlay simulated",14,58,"#ffd400");
}

function update(){
  const p=calc();
  $("vAsset").textContent=p.asset;$("vAz").textContent=p.az+"°";$("vScale").textContent=n(p.scale,2);
  $("vFreq").textContent=n(p.freq,1);$("vPow").textContent=p.pow; $("vBeam").textContent=p.beam+"°"; $("vTilt").textContent=p.tilt+"°";
  $("vRows").textContent=p.rows;$("vCols").textContent=p.cols;$("vDetail").textContent=p.detail;
  $("kAsset").textContent=p.asset.replace("_"," ");$("kView").textContent=p.view.replace("_"," ");$("kAz").textContent=p.az+"°";
  $("kTilt").textContent=p.tilt+"°";$("kBeam").textContent=p.beam+"°";$("kArray").textContent=p.rows+"x"+p.cols;
  $("kFreq").textContent=n(p.freq,1);$("kPow").textContent=p.pow;

  $("sceneOverlay").textContent=`${p.asset} · ${p.view} · az ${p.az}° · ${p.freq} GHz · beam ${p.beam}° · ${p.rows}x${p.cols}`;
  $("geoOut").innerHTML=`projection = ${p.view}<br>asset = ${p.asset}<br>azimuth = ${p.az}°<br>detail = ${p.detail}/5`;
  $("timeOut").innerHTML=`animated RF beam<br>carrier = ${n(p.freq,1)} GHz<br>power = ${p.pow} dBm<br>time-indexed overlay active`;
  $("stateOut").innerHTML=`protocol/KPI layer<br>RET tilt = ${p.tilt}°<br>MIMO = ${p.rows}x${p.cols}<br>beam HPBW = ${p.beam}°`;
  saveState(); drawScene();
}

function exportReport(){
  const p=calc();
  const data={page:"TRFMC 3D RF Asset Renderer Lab V1",timestamp:new Date().toISOString(),renderer:"pure-canvas-2.5D-first-stage",future_renderer:"local WebGL/Three.js/WebGPU",parameters:p,gate:{standalone_leaf:true,iframe:false,external_refs:false}};
  const blob=new Blob([JSON.stringify(data,null,2)],{type:"application/json"});
  const a=document.createElement("a");a.href=URL.createObjectURL(blob);a.download="trfmc_3d_rf_asset_renderer_report.json";a.click();URL.revokeObjectURL(a.href);
  addEvent("REPORT: renderer JSON exported");
}

function loop(){
  tick++;
  $("clock").textContent=new Date().toLocaleTimeString();
  if(tick%2===0) drawScene();
  if(tick%180===0) addEvent(["RENDER: beam layer animated","OBJECT: ports and radome geometry refreshed","4D: time/frequency overlay updated","5D: state/protocol layer synchronized"][Math.floor(Math.random()*4)]);
  requestAnimationFrame(loop);
}
loadState();update();addEvent("3D RF Asset Renderer Lab online");loop();
</script>
</body>
</html>
HTML

echo
echo "[1/5] Pagina creata"
ls -lh "$PAGE"

echo
echo "[2/5] Quality gate 3D RF Asset Renderer"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_3d_rf_asset_renderer_lab_v1.html \
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
 "page":"http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1.html",
 "http_non_200":http_non_200,
 "iframe_refs":iframes,
 "external_refs":external,
 "result":"PASS" if http_non_200==0 and iframes==0 and external==0 else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_3d_rf_asset_renderer_lab"

echo
echo "[3/5] Report"
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
echo "[4/5] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_3D_RF_ASSET_RENDERER_LAB_$TS.tar.gz"
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
echo "[5/5] Apertura"
echo "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_lab_v1.html"
echo "============================================================"
