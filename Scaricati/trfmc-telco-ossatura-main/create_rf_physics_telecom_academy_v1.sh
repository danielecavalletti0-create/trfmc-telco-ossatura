#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
OUT="$BASE/runtime/quality/TRFMC_RF_PHYSICS_TELECOM_ACADEMY_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$PUBLIC" "$OUT"

cat > "$PUBLIC/trfmc_rf_physics_telecom_academy_v1.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC RF Physics Telecom Academy V1</title>
<style>
:root{--bg:#01060d;--p:#061120;--line:#1d6f9f;--cyan:#00d9ff;--green:#7dff4f;--yellow:#ffd500;--text:#eaf3ff;--muted:#86a7c6}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:radial-gradient(circle at 50% 0,rgba(0,217,255,.16),transparent 36%),#01060d;color:var(--text);font:12px Segoe UI,system-ui,sans-serif;overflow:hidden}
header{height:64px;background:#050b13;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;padding:0 14px}
h1{margin:0;font-size:19px;letter-spacing:.08em;text-transform:uppercase;color:var(--cyan)}
.sub{color:var(--muted);font-size:11px}
button{background:#10233a;color:var(--text);border:1px solid #285d82;border-radius:4px;padding:7px 9px;cursor:pointer}
button:hover{border-color:var(--cyan);box-shadow:inset 3px 0 0 var(--yellow)}
main{height:calc(100vh - 64px);display:grid;grid-template-columns:270px 1fr 340px;gap:6px;padding:6px}
.panel{border:1px solid var(--line);background:linear-gradient(180deg,#061321,#02070f);border-radius:8px;overflow:hidden}
.title{background:#0a1b2e;border-bottom:1px solid #1d5e86;color:var(--cyan);font-weight:700;padding:7px;text-transform:uppercase}
.body{padding:8px}
.mod{border:1px solid #214a68;background:#081522;border-radius:6px;margin-bottom:6px;padding:8px;cursor:pointer}
.mod.active,.mod:hover{border-color:var(--yellow);box-shadow:inset 4px 0 0 var(--yellow);background:#10233a}
.mod b{color:var(--green);display:block}
.mod span{color:var(--muted);font-size:10px}
.stage{display:grid;grid-template-rows:1fr 160px;gap:6px}
.canvasBox{position:relative;border:1px solid var(--line);background:#02070f;border-radius:8px;overflow:hidden}
canvas{width:100%;height:100%;display:block}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.card{border:1px solid #214a68;background:#081522;border-radius:7px;padding:9px}
.card h2{margin:0 0 6px;color:var(--green);font-size:13px}
.card code{color:var(--yellow);font-size:12px}
.kv{display:grid;grid-template-columns:1fr auto;border-bottom:1px solid rgba(255,255,255,.07);padding:6px 0;font:11px Consolas,monospace}
.kv b{color:var(--green)}
input,select{width:100%;background:#071524;color:var(--text);border:1px solid #285d82;border-radius:4px;padding:6px}
.log{height:220px;overflow:auto;border:1px solid #183d58;background:#01060d;border-radius:5px;padding:6px;font:11px Consolas,monospace}
.log div{border-bottom:1px solid rgba(255,255,255,.06);padding:3px;color:#cde7ff}
.badge{display:inline-block;border:1px solid rgba(125,255,79,.4);color:var(--green);padding:3px 6px;border-radius:4px;font:10px Consolas,monospace;margin:2px}
</style>
</head>
<body>
<header>
  <div>
    <h1>TRFMC RF Physics / Telecom Academy</h1>
    <div class="sub">Campo elettrico · onde · modi · dBm · MIMO · microwave backhaul · telecom tower</div>
  </div>
  <div>
    <span class="badge">NO STATIC POSTER</span>
    <span class="badge">INTERACTIVE CANVAS</span>
    <span class="badge">RF MATH</span>
  </div>
</header>

<main>
  <aside class="panel">
    <div class="title">Moduli fisica / RF</div>
    <div class="body" id="mods"></div>
  </aside>

  <section class="stage">
    <div class="canvasBox"><canvas id="cv"></canvas></div>
    <div class="cards">
      <div class="card"><h2 id="f1t">Formula 1</h2><code id="f1"></code></div>
      <div class="card"><h2 id="f2t">Formula 2</h2><code id="f2"></code></div>
      <div class="card"><h2 id="f3t">Formula 3</h2><code id="f3"></code></div>
    </div>
  </section>

  <aside class="panel">
    <div class="title">Controlli / calcoli</div>
    <div class="body">
      <div class="kv"><span>Modulo</span><b id="name">-</b></div>
      <div class="kv"><span>Stato</span><b>OPERATIVE</b></div>

      <p>Potenza dBm</p>
      <input id="dbm" type="range" min="-120" max="60" value="30" oninput="calc()">
      <div class="kv"><span>dBm</span><b id="dbmv">30</b></div>
      <div class="kv"><span>Watt</span><b id="watt">1 W</b></div>

      <p>Link budget</p>
      <input id="ptx" type="number" value="30" oninput="calc()">
      <input id="gain" type="number" value="18" oninput="calc()">
      <input id="loss" type="number" value="4" oninput="calc()">
      <div class="kv"><span>EIRP</span><b id="eirp">44 dBm</b></div>

      <div class="title" style="margin:10px -8px 6px">Event Stream</div>
      <div class="log" id="log"></div>
    </div>
  </aside>
</main>

<script>
const M={
 stark:{n:"Stark Effect",d:"Campo elettrico esterno e splitting spettrale",f:["ΔE = -p·E - 1/2 αE²","linear Stark + quadratic Stark","spectral line splitting"]},
 barrier:{n:"Transmission / Reflection",d:"Onde, barriera di potenziale, coefficienti R/T",f:["R = Jref/Jinc","T = Jtrans/Jinc","R + T = 1"]},
 eigen:{n:"Eigenvalues / Eigenfunctions",d:"Operatori, autostati, modi naturali",f:["Âψ = aψ","Ĥψn = Enψn","En = n²π²ℏ² / 2mL²"]},
 dbm:{n:"dBm / Link Budget",d:"Potenza logaritmica, EIRP, gain/loss",f:["dBm = 10log10(P/1mW)","EIRP = Ptx + Gant - Lcable","FSPL = 32.44 + 20log f + 20log d"]},
 backhaul:{n:"Microwave Backhaul",d:"Dish, OMT, ODU/RRU, channel filter",f:["G ≈ η(πD/λ)²","HPBW ≈ 70λ/D","Rx = EIRP - FSPL + Grx"]},
 mimo:{n:"MIMO / AAU / Tower",d:"AAU, channel matrix, spatial streams",f:["H ∈ C^(Nr×Nt)","C = log2 det(I + ρ/Nt HHᴴ)","streams ≤ min(Nt,Nr)"]}
};
let active="dbm",t=0;
function $(x){return document.getElementById(x)}
function log(m){let d=document.createElement("div");d.textContent="["+new Date().toLocaleTimeString()+"] "+m;$("log").prepend(d)}
function renderMods(){ $("mods").innerHTML=Object.entries(M).map(([k,m])=>`<div class="mod ${k===active?'active':''}" onclick="load('${k}')"><b>${m.n}</b><span>${m.d}</span></div>`).join("")}
function load(k){active=k;let m=M[k];$("name").textContent=m.n;$("f1t").textContent=m.n+" / Eq.1";$("f1").textContent=m.f[0];$("f2").textContent=m.f[1];$("f3").textContent=m.f[2];renderMods();log("module loaded → "+m.n)}
function calc(){
 let dbm=+$("dbm").value; $("dbmv").textContent=dbm;
 let mw=Math.pow(10,dbm/10), w=mw/1000;
 $("watt").textContent=w>=1?w.toFixed(3)+" W":(w*1000).toFixed(3)+" mW";
 let e=+$("ptx").value + +$("gain").value - +$("loss").value;
 $("eirp").textContent=e.toFixed(1)+" dBm";
}
function draw(){
 const c=$("cv"),r=c.getBoundingClientRect(),d=devicePixelRatio||1;c.width=r.width*d;c.height=r.height*d;
 const x=c.getContext("2d");x.setTransform(d,0,0,d,0,0);x.clearRect(0,0,r.width,r.height);
 x.strokeStyle="rgba(42,111,154,.35)";for(let i=0;i<r.width;i+=40){x.beginPath();x.moveTo(i,0);x.lineTo(i,r.height);x.stroke()}for(let j=0;j<r.height;j+=40){x.beginPath();x.moveTo(0,j);x.lineTo(r.width,j);x.stroke()}
 x.fillStyle="#00d9ff";x.font="18px Segoe UI";x.fillText(M[active].n,24,34);
 if(active==="stark"){for(let n=0;n<5;n++){x.strokeStyle=n==2?"#ffd500":"#7dff4f";x.beginPath();x.moveTo(180,120+n*55);x.lineTo(460,120+n*55);x.stroke();x.beginPath();x.moveTo(620,120+n*55);x.lineTo(940,105+n*35);x.stroke();x.moveTo(620,120+n*55);x.lineTo(940,135+n*70);x.stroke()}}
 else if(active==="barrier"){x.fillStyle="rgba(255,255,255,.25)";x.fillRect(r.width/2-55,100,110,r.height-200);["#4db8ff","#ff3366","#7dff4f"].forEach((col,idx)=>{x.strokeStyle=col;x.beginPath();for(let i=0;i<360;i++){let xx=80+i*2+idx*180, yy=220+idx*70+Math.sin(i*.08+t)*24;i?x.lineTo(xx,yy):x.moveTo(xx,yy)}x.stroke()})}
 else if(active==="eigen"){["#b76cff","#4db8ff","#7dff4f"].forEach((col,n)=>{x.strokeStyle=col;x.beginPath();for(let i=0;i<500;i++){let xx=120+i*1.6, yy=180+n*90+Math.sin(i*.02*(n+1)+t)*45;i?x.lineTo(xx,yy):x.moveTo(xx,yy)}x.stroke()})}
 else if(active==="dbm"){for(let i=0;i<6;i++){let h=30+i*38;x.fillStyle=["#888","#7dff4f","#c9ff3d","#ffd500","#ff9e3d","#ff3366"][i];x.fillRect(120+i*130,420-h,70,h);x.fillStyle="#eaf3ff";x.fillText((i*10)+" dBm",120+i*130,450)}}
 else if(active==="backhaul"){x.strokeStyle="#7dff4f";for(let i=0;i<7;i++){x.beginPath();x.ellipse(350,300,160+i*22,80+i*12,0,Math.PI*1.7,Math.PI*.3);x.stroke()}x.fillStyle="#eaf3ff";x.fillRect(338,210,24,180);x.fillText("Dish / OMT / ODU",520,300)}
 else if(active==="mimo"){for(let i=0;i<4;i++){x.fillStyle="#7dff4f";x.fillRect(160,150+i*90,18,45);x.fillStyle="#4db8ff";x.fillRect(900,150+i*90,18,45);for(let j=0;j<4;j++){x.strokeStyle="rgba(255,213,0,.5)";x.beginPath();x.moveTo(180,172+i*90);x.lineTo(900,172+j*90);x.stroke()}}}
 t+=.04;requestAnimationFrame(draw)
}
load(active);calc();draw();
</script>
</body>
</html>
HTML

echo "=== HTTP CHECK ==="
for u in /trfmc_rf_physics_telecom_academy_v1.html /api/health; do
  echo -n "$u -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "http://127.0.0.1:5173$u"
done
