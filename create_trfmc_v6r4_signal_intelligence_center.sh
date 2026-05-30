#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V6R4_SIGNAL_INTELLIGENCE_CENTER_$TS"
BACKUP="$BASE/runtime/backups/V6R4_SIGNAL_INTELLIGENCE_$TS"

mkdir -p "$PUBLIC" "$OUT" "$BACKUP" "$BASE/runtime/quality" "$BASE/runtime/freezes"

PAGE="$PUBLIC/trfmc_signal_intelligence_center_v1.html"
PAGE_URL="/trfmc_signal_intelligence_center_v1.html"
LINK_GRAPH="$PUBLIC/trfmc_portal_link_graph_v1.html"

echo "============================================================"
echo "TRFMC V6R4 SIGNAL INTELLIGENCE CENTER - SAFE CREATE"
echo "============================================================"
echo "BASE=$BASE"
echo "OUT=$OUT"
echo

if [ -f "$PAGE" ]; then
  cp -a "$PAGE" "$BACKUP/$(basename "$PAGE").bak"
fi

cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC V6R4 Signal Intelligence Center</title>
<style>
:root{
  --bg:#02070d;--panel:#071827;--panel2:#0a2135;--line:#0b75a8;--line2:#0ff0ff;
  --ok:#75ff5b;--warn:#ffd84d;--bad:#ff3d7f;--txt:#dff8ff;--muted:#7fa3b7;
  --blue:#1aa8ff;--gold:#ffd400;--violet:#b772ff;
}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:radial-gradient(circle at 50% 0,#06213a 0,#02070d 42%,#00050a 100%);color:var(--txt);font-family:Inter,Segoe UI,Arial,sans-serif;overflow:hidden}
body:before{content:"";position:fixed;inset:0;background:
linear-gradient(rgba(0,255,255,.045) 1px,transparent 1px),
linear-gradient(90deg,rgba(0,255,255,.035) 1px,transparent 1px);
background-size:44px 44px;opacity:.45;pointer-events:none}
.app{height:100vh;display:grid;grid-template-rows:62px 84px 1fr;gap:6px;padding:8px}
.top{display:grid;grid-template-columns:1.3fr auto;align-items:center;border:1px solid #0b5f8a;background:linear-gradient(180deg,#071827,#020811);box-shadow:0 0 28px rgba(0,180,255,.18);padding:9px 12px}
.brand h1{margin:0;font-size:21px;letter-spacing:2px}
.brand small{color:var(--muted);letter-spacing:.8px}
.actions{display:flex;gap:6px;align-items:center}
button,select,input{background:#0b2238;border:1px solid #1175a5;color:var(--txt);border-radius:4px;padding:7px 10px;font-size:12px}
button:hover{border-color:var(--line2);box-shadow:0 0 12px rgba(0,240,255,.35);cursor:pointer}
.led{width:10px;height:10px;border-radius:50%;background:var(--ok);box-shadow:0 0 12px var(--ok)}
.kpis{display:grid;grid-template-columns:repeat(12,1fr);gap:6px}
.kpi{border:1px solid #0b5f8a;background:linear-gradient(180deg,#092037,#04101b);padding:7px 9px;min-height:78px;box-shadow:inset 0 0 18px rgba(0,160,255,.06)}
.kpi .l{font-size:9px;color:#80bad0;text-transform:uppercase;letter-spacing:.8px}
.kpi .v{font-size:18px;font-weight:800;margin-top:3px}
.kpi .s{font-size:10px;color:var(--ok)}
.main{display:grid;grid-template-columns:245px 1.5fr 1fr 285px;gap:6px;min-height:0}
.panel{border:1px solid #0b5f8a;background:rgba(3,14,24,.92);box-shadow:inset 0 0 22px rgba(0,150,255,.06),0 0 16px rgba(0,130,255,.08);min-height:0;overflow:hidden;position:relative}
.panel h2{margin:0;padding:8px 10px;border-bottom:1px solid #0b5f8a;color:#00e5ff;font-size:13px;text-transform:uppercase;letter-spacing:.8px;background:#061625}
.panel .body{padding:9px;height:calc(100% - 34px);overflow:auto}
.label{font-size:10px;color:#8fc0d2;text-transform:uppercase;margin:10px 0 4px}
.range{width:100%}
fieldset{border:1px solid #123f5d;border-radius:6px;margin:0 0 8px;padding:8px;background:#061523}
legend{font-size:10px;color:var(--gold);padding:0 5px}
.val{float:right;color:var(--ok);font-family:monospace}
.pipe{display:grid;grid-template-columns:repeat(8,1fr);gap:5px;margin-bottom:7px}
.stage{border:1px solid #135c82;background:#061827;padding:8px 5px;text-align:center;min-height:58px;position:relative}
.stage b{display:block;font-size:11px;color:#fff}
.stage span{font-size:9px;color:var(--ok)}
.stage.active{border-color:var(--gold);box-shadow:0 0 18px rgba(255,212,0,.25)}
.canvasBox{height:330px;border:1px solid #0d6f9e;background:#020b12;position:relative;margin-bottom:6px}
canvas{width:100%;height:100%;display:block}
.overlay{position:absolute;left:8px;top:8px;font-family:monospace;font-size:11px;color:var(--ok);background:rgba(0,0,0,.35);border:1px solid #154e34;padding:5px 7px}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:6px}
.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.card{border:1px solid #104e73;background:#061625;padding:8px;border-radius:4px}
.card h3{margin:0 0 7px;font-size:12px;color:#00e5ff}
.mini{font-family:monospace;font-size:11px;color:#b9eaff;line-height:1.45}
.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}.gold{color:var(--gold)}
.table{width:100%;border-collapse:collapse;font-size:11px}
.table th,.table td{border-bottom:1px solid #12344c;padding:5px;text-align:left}
.table th{color:#83cfff;font-weight:600}
.bar{height:8px;background:#082035;border:1px solid #11496a;margin-top:4px}
.bar i{display:block;height:100%;background:linear-gradient(90deg,#12e1ff,#75ff5b)}
.log{height:190px;background:#02070d;border:1px solid #123f5d;padding:7px;overflow:auto;font-family:monospace;font-size:10px;color:#bcecff}
.formula{font-family:Cambria,serif;font-size:17px;color:#fff;background:#061523;border:1px solid #174e73;padding:8px;margin:6px 0;border-radius:4px}
.badge{display:inline-block;border:1px solid #1c7ba8;background:#092238;padding:3px 6px;border-radius:4px;margin:2px;font-size:10px}
.radar{height:210px;border:1px solid #0d6f9e;background:radial-gradient(circle at 50% 50%,rgba(0,255,120,.12),rgba(0,0,0,.2) 32%,transparent 33%),#020b12}
.footerStatus{position:absolute;right:8px;bottom:6px;color:var(--ok);font-family:monospace;font-size:10px;border:1px solid #1d7c33;padding:3px 6px;background:#04110a}
@media(max-width:1400px){.main{grid-template-columns:220px 1.3fr 1fr 260px}.kpis{grid-template-columns:repeat(6,1fr)}}
</style>
</head>
<body>
<div class="app">
  <header class="top">
    <div class="brand">
      <h1>TRFMC V6R4 SIGNAL INTELLIGENCE CENTER</h1>
      <small>Wideband receiver · FFT/RBW/DNL · DDC matrix · classifier · IQ evidence · DF/geolocation · RF metrology</small>
    </div>
    <div class="actions">
      <button onclick="preset('monitor')">Monitor</button>
      <button onclick="preset('dense')">Dense HF</button>
      <button onclick="preset('hopper')">Hopper</button>
      <button onclick="preset('metrology')">Metrology</button>
      <button onclick="exportReport()">Export JSON</button>
      <button onclick="resetState()">Reset</button>
      <span class="led"></span><span id="clock" class="mini">--:--:--</span>
    </div>
  </header>

  <section class="kpis">
    <div class="kpi"><div class="l">Receiver Mode</div><div class="v" id="kMode">WFFM</div><div class="s">gapless sim</div></div>
    <div class="kpi"><div class="l">Center</div><div class="v" id="kCenter">145.500</div><div class="s">MHz</div></div>
    <div class="kpi"><div class="l">IF BW</div><div class="v" id="kIfbw">20.0</div><div class="s">MHz</div></div>
    <div class="kpi"><div class="l">FFT</div><div class="v" id="kFft">4096</div><div class="s">points</div></div>
    <div class="kpi"><div class="l">Bin / RBW</div><div class="v" id="kBin">6.25</div><div class="s">kHz</div></div>
    <div class="kpi"><div class="l">DNL</div><div class="v" id="kDnl">-126</div><div class="s">dBm</div></div>
    <div class="kpi"><div class="l">DDC</div><div class="v" id="kDdc">8</div><div class="s">channels</div></div>
    <div class="kpi"><div class="l">Classifier</div><div class="v" id="kCls">READY</div><div class="s">AM/FSK/OFDM</div></div>
    <div class="kpi"><div class="l">IQ Evidence</div><div class="v" id="kIq">ARMED</div><div class="s">ring buffer</div></div>
    <div class="kpi"><div class="l">DF σ RMS</div><div class="v" id="kDf">1.0°</div><div class="s">baseline model</div></div>
    <div class="kpi"><div class="l">Metrology</div><div class="v" id="kMet">PASS</div><div class="s">TRFL model</div></div>
    <div class="kpi"><div class="l">Gate</div><div class="v" id="kGate">PASS</div><div class="s">no iframe</div></div>
  </section>

  <main class="main">
    <aside class="panel">
      <h2>Receiver / Scenario Controls</h2>
      <div class="body">
        <fieldset>
          <legend>RF FRONTEND</legend>
          <div class="label">Mode <span class="val" id="vMode">WFFM</span></div>
          <select id="mode" onchange="update()">
            <option>WFFM</option><option>SCAN</option><option>REPLAY</option><option>METROLOGY</option>
          </select>
          <div class="label">Center MHz <span class="val" id="vCenter"></span></div>
          <input id="center" class="range" type="range" min="1" max="6000" value="145.5" step="0.5" oninput="update()">
          <div class="label">IF Bandwidth MHz <span class="val" id="vIfbw"></span></div>
          <input id="ifbw" class="range" type="range" min="1" max="80" value="20" step="1" oninput="update()">
          <div class="label">Noise Figure dB <span class="val" id="vNf"></span></div>
          <input id="nf" class="range" type="range" min="1" max="20" value="7" step="0.5" oninput="update()">
        </fieldset>

        <fieldset>
          <legend>DSP / FFT</legend>
          <div class="label">FFT points</div>
          <select id="fft" onchange="update()">
            <option>1024</option><option>2048</option><option selected>4096</option><option>8192</option><option>16384</option>
          </select>
          <div class="label">Overlap % <span class="val" id="vOverlap"></span></div>
          <input id="overlap" class="range" type="range" min="0" max="75" value="50" step="5" oninput="update()">
          <div class="label">Detector Threshold dB <span class="val" id="vThr"></span></div>
          <input id="thr" class="range" type="range" min="3" max="30" value="12" step="1" oninput="update()">
        </fieldset>

        <fieldset>
          <legend>DF / GEOLOCATION</legend>
          <div class="label">DF σ RMS degrees <span class="val" id="vSigma"></span></div>
          <input id="sigma" class="range" type="range" min="0.5" max="5" value="1" step="0.1" oninput="update()">
          <div class="label">Baseline km <span class="val" id="vBase"></span></div>
          <input id="baseline" class="range" type="range" min="1" max="40" value="10" step="1" oninput="update()">
        </fieldset>

        <fieldset>
          <legend>ACTIONS</legend>
          <button style="width:100%" onclick="addEvent('IQ_RECORD: 30 s pre/post trigger snapshot')">Arm IQ Snapshot</button>
          <button style="width:100%;margin-top:5px" onclick="addEvent('CLASSIFIER: spectral shape trainer refreshed')">Train Shape</button>
          <button style="width:100%;margin-top:5px" onclick="addEvent('DF_FIX: two-station bearing solution computed')">DF Fix</button>
          <button style="width:100%;margin-top:5px" onclick="addEvent('METROLOGY: TRFL adjacent range recalibration simulated')">TRFL Recal</button>
        </fieldset>
      </div>
    </aside>

    <section class="panel">
      <h2>Wideband Spectrum / Signal Workflow</h2>
      <div class="body">
        <div class="pipe">
          <div class="stage active"><b>INGEST</b><span>IQ stream</span></div>
          <div class="stage"><b>FFT</b><span>RBW/DNL</span></div>
          <div class="stage"><b>DETECT</b><span>energy/shape</span></div>
          <div class="stage"><b>DDC</b><span>channels</span></div>
          <div class="stage"><b>CLASSIFY</b><span>mod/sys</span></div>
          <div class="stage"><b>DEMOD</b><span>symbol</span></div>
          <div class="stage"><b>DECODE</b><span>content</span></div>
          <div class="stage"><b>EVIDENCE</b><span>record/replay</span></div>
        </div>
        <div class="canvasBox">
          <canvas id="spectrum"></canvas>
          <div class="overlay" id="specOverlay">RBW -- kHz · DNL -- dBm · POI --</div>
          <div class="footerStatus">SEAMLESS FFT ENGINE · ACTIVE</div>
        </div>
        <div class="grid3">
          <div class="card">
            <h3>FFT / Receiver Math</h3>
            <div class="formula">BW<sub>bin</sub> = f<sub>s</sub> / N</div>
            <div class="formula">DNL = -174 dBm + NF + 10log<sub>10</sub>(BW<sub>bin</sub>)</div>
            <div class="mini" id="mathOut"></div>
          </div>
          <div class="card">
            <h3>Event → Action Engine</h3>
            <div class="mini">
              IF signal = unknown<br>
              AND SNR &gt; threshold<br>
              THEN record IQ + classify + report
            </div>
            <div class="bar"><i id="actionBar" style="width:76%"></i></div>
          </div>
          <div class="card">
            <h3>Signal Shape Library</h3>
            <span class="badge">CW</span><span class="badge">AM-DSB</span><span class="badge">SSB</span>
            <span class="badge">FSK2</span><span class="badge">OFDM</span><span class="badge">LTE-like</span>
            <span class="badge">Wi-Fi</span><span class="badge">Hopper</span><span class="badge">Unknown</span>
          </div>
        </div>
      </div>
    </section>

    <section class="panel">
      <h2>DDC / Classifier / Evidence</h2>
      <div class="body">
        <div class="card">
          <h3>Digital Downconversion Matrix</h3>
          <table class="table" id="ddcTable">
            <thead><tr><th>CH</th><th>Offset</th><th>BW</th><th>Signal</th><th>Conf.</th></tr></thead>
            <tbody></tbody>
          </table>
        </div>
        <div class="grid2" style="margin-top:6px">
          <div class="card">
            <h3>Constellation / Symbol View</h3>
            <canvas id="constel" style="height:180px;border:1px solid #0d6f9e;background:#020b12"></canvas>
          </div>
          <div class="card">
            <h3>IQ Evidence Recorder</h3>
            <div class="mini">
              Ring buffer: <span class="ok">180 s</span><br>
              Pre-trigger: <span class="ok">30 s</span><br>
              Replay: <span class="ok">enabled</span><br>
              Export: IQ + JSON + HTML report
            </div>
            <div class="bar"><i id="iqBar" style="width:48%"></i></div>
          </div>
        </div>
        <div class="card" style="margin-top:6px">
          <h3>Operator Event Stream</h3>
          <div class="log" id="log"></div>
        </div>
      </div>
    </section>

    <aside class="panel">
      <h2>DF / Metrology / Correlation</h2>
      <div class="body">
        <div class="card">
          <h3>DF Geolocation Model</h3>
          <div class="formula">R<sub>RMS</sub> = 0.035 × σ × B</div>
          <div class="mini" id="dfOut"></div>
          <canvas id="dfCanvas" class="radar"></canvas>
        </div>

        <div class="card" style="margin-top:6px">
          <h3>RF Metrology Gate</h3>
          <table class="table">
            <tr><th>Test</th><th>Result</th><th>Gate</th></tr>
            <tr><td>TRFL range</td><td class="ok">±0.014 dB model</td><td class="ok">PASS</td></tr>
            <tr><td>Power sensor</td><td class="ok">VSWR corr.</td><td class="ok">PASS</td></tr>
            <tr><td>AM/FM/PM</td><td class="ok">&lt;0.5% model</td><td class="ok">PASS</td></tr>
            <tr><td>Phase noise</td><td class="warn">x-corr sim</td><td class="ok">PASS</td></tr>
          </table>
        </div>

        <div class="card" style="margin-top:6px">
          <h3>5G/RF Correlation</h3>
          <div class="mini">
            RF event → protocol event<br>
            NGAP/NAS/PFCP timeline<br>
            PDU session KPI alignment<br>
            anomaly → evidence bundle
          </div>
        </div>
      </div>
    </aside>
  </main>
</div>

<script>
"use strict";

const $ = id => document.getElementById(id);
const signals = ["CW","AM-DSB","SSB","FSK2","QPSK","OFDM","Wi-Fi","Hopper","Unknown"];
let tick=0, logLines=[];

function n(v,d=1){return Number(v).toFixed(d)}
function addEvent(msg){
  const t=new Date().toLocaleTimeString();
  logLines.unshift(`[${t}] ${msg}`);
  logLines=logLines.slice(0,80);
  $("log").textContent=logLines.join("\n");
}
function preset(p){
  if(p==="monitor"){ $("mode").value="WFFM"; $("center").value=145.5; $("ifbw").value=20; $("fft").value=4096; $("sigma").value=1; }
  if(p==="dense"){ $("mode").value="WFFM"; $("center").value=7100; $("ifbw").value=10; $("fft").value=8192; $("thr").value=9; }
  if(p==="hopper"){ $("mode").value="SCAN"; $("center").value=430; $("ifbw").value=40; $("fft").value=4096; $("overlap").value=75; }
  if(p==="metrology"){ $("mode").value="METROLOGY"; $("center").value=1000; $("ifbw").value=5; $("fft").value=4096; $("nf").value=4; }
  addEvent(`PRESET: ${p.toUpperCase()} loaded`);
  update();
}
function resetState(){
  localStorage.removeItem("trfmc_v6r4_signal_intel_state");
  location.reload();
}
function saveState(){
  const data={mode:$("mode").value,center:$("center").value,ifbw:$("ifbw").value,fft:$("fft").value,nf:$("nf").value,overlap:$("overlap").value,thr:$("thr").value,sigma:$("sigma").value,baseline:$("baseline").value};
  localStorage.setItem("trfmc_v6r4_signal_intel_state",JSON.stringify(data));
}
function loadState(){
  try{
    const d=JSON.parse(localStorage.getItem("trfmc_v6r4_signal_intel_state")||"{}");
    for(const k of Object.keys(d)){ if($(k)) $(k).value=d[k]; }
  }catch(e){}
}
function update(){
  const mode=$("mode").value, center=+$("center").value, ifbw=+$("ifbw").value, fft=+$("fft").value;
  const nf=+$("nf").value, overlap=+$("overlap").value, thr=+$("thr").value, sigma=+$("sigma").value, base=+$("baseline").value;
  const fs=ifbw*1.28e6;
  const bin=fs/fft;
  const dnl=-174+nf+10*Math.log10(bin);
  const frameUs=fft/fs*1e6;
  const fps=1e6/frameUs*(1/(1-overlap/100 || 1));
  const rrms=0.035*sigma*(base*1000);
  const area=Math.PI*rrms*rrms/1e6;

  $("vMode").textContent=mode; $("vCenter").textContent=n(center,1); $("vIfbw").textContent=n(ifbw,1);
  $("vNf").textContent=n(nf,1); $("vOverlap").textContent=overlap+"%"; $("vThr").textContent=thr;
  $("vSigma").textContent=n(sigma,1)+"°"; $("vBase").textContent=base+" km";

  $("kMode").textContent=mode; $("kCenter").textContent=n(center,3); $("kIfbw").textContent=n(ifbw,1);
  $("kFft").textContent=fft; $("kBin").textContent=n(bin/1000,2); $("kDnl").textContent=n(dnl,1);
  $("kDf").textContent=n(sigma,1)+"°";
  $("specOverlay").textContent=`RBW ${n(bin/1000,2)} kHz · DNL ${n(dnl,1)} dBm · frame ${n(frameUs,1)} µs · overlap ${overlap}%`;
  $("mathOut").innerHTML=`fs = ${n(fs/1e6,2)} Msample/s<br>FFT frame = ${n(frameUs,2)} µs<br>virtual spectra/s = ${Math.round(fps).toLocaleString()}<br>threshold = ${thr} dB`;
  $("dfOut").innerHTML=`σ = ${n(sigma,1)}° RMS<br>baseline = ${base} km<br>RMS uncertainty radius = ${n(rrms,1)} m<br>simplified area = ${n(area,3)} km²`;
  saveState();
  drawSpectrum(); drawConstellation(); drawDF(rrms,base); fillDdc();
}
function drawSpectrum(){
  const c=$("spectrum"), r=c.getBoundingClientRect(), dpr=window.devicePixelRatio||1;
  c.width=r.width*dpr; c.height=r.height*dpr;
  const ctx=c.getContext("2d"); ctx.scale(dpr,dpr);
  const w=r.width,h=r.height;
  ctx.clearRect(0,0,w,h);
  ctx.fillStyle="#020b12"; ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,210,255,.16)"; ctx.lineWidth=1;
  for(let x=0;x<w;x+=44){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=34){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
  ctx.strokeStyle="#ffe100"; ctx.lineWidth=1.5; ctx.beginPath();
  for(let x=0;x<w;x++){
    let y=h-55 + Math.sin((x+tick)/17)*3 + Math.sin((x+tick)/5)*1.4;
    const peaks=[.18,.36,.52,.69,.82];
    for(const p of peaks){
      const dx=x-w*p;
      y-=Math.exp(-(dx*dx)/(2*(10+25*p)*(10+25*p)))*(70+38*Math.sin(tick/40+p*4));
    }
    if(x===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
  }
  ctx.stroke();
  ctx.strokeStyle="#00e5ff"; ctx.lineWidth=1; ctx.beginPath();
  for(let x=0;x<w;x++){
    let y=h-60 + Math.sin((x+tick)/21)*5 + (Math.random()*8);
    for(const p of [.22,.47,.73]){const dx=x-w*p;y-=Math.exp(-(dx*dx)/(2*90))*(55+25*Math.sin(tick/30+p));}
    if(x===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
  }
  ctx.stroke();
  ctx.fillStyle="rgba(0,255,120,.10)";
  ctx.fillRect(w*.43,0,w*.12,h);
  ctx.strokeStyle="rgba(255,0,100,.75)";
  ctx.strokeRect(w*.43,0,w*.12,h);
  ctx.fillStyle="#7fa3b7"; ctx.font="10px monospace";
  for(let i=0;i<6;i++)ctx.fillText((-20-i*20)+" dBm",w-55,20+i*45);
}
function drawConstellation(){
  const c=$("constel"), r=c.getBoundingClientRect(), dpr=window.devicePixelRatio||1;
  c.width=r.width*dpr; c.height=r.height*dpr;
  const ctx=c.getContext("2d"); ctx.scale(dpr,dpr);
  const w=r.width,h=r.height; ctx.clearRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,210,255,.18)";
  ctx.beginPath();ctx.moveTo(w/2,0);ctx.lineTo(w/2,h);ctx.moveTo(0,h/2);ctx.lineTo(w,h/2);ctx.stroke();
  const pts=[-1,-.33,.33,1];
  for(const x of pts)for(const y of pts){
    ctx.fillStyle="#75ff5b";
    ctx.beginPath();
    ctx.arc(w/2+x*w*.28+Math.random()*5-2.5,h/2+y*h*.32+Math.random()*5-2.5,2.1,0,Math.PI*2);
    ctx.fill();
  }
}
function drawDF(rrms,base){
  const c=$("dfCanvas"), r=c.getBoundingClientRect(), dpr=window.devicePixelRatio||1;
  c.width=r.width*dpr; c.height=r.height*dpr;
  const ctx=c.getContext("2d"); ctx.scale(dpr,dpr);
  const w=r.width,h=r.height; ctx.clearRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,210,255,.18)";
  for(let i=1;i<5;i++){ctx.beginPath();ctx.arc(w/2,h/2,i*24,0,Math.PI*2);ctx.stroke();}
  const scale=Math.min(90,20+rrms/20);
  ctx.strokeStyle="#ffd400";ctx.lineWidth=2;
  ctx.beginPath();ctx.ellipse(w/2,h/2,scale,scale*.45,0.4,0,Math.PI*2);ctx.stroke();
  ctx.strokeStyle="#75ff5b";
  ctx.beginPath();ctx.moveTo(35,h-28);ctx.lineTo(w/2,h/2);ctx.lineTo(w-35,h-35);ctx.stroke();
  ctx.fillStyle="#75ff5b";ctx.font="10px monospace";
  ctx.fillText("DF1",25,h-18);ctx.fillText("DF2",w-55,h-20);ctx.fillText("TX estimate",w/2-35,h/2-10);
}
function fillDdc(){
  const tb=$("ddcTable").querySelector("tbody");
  tb.innerHTML="";
  for(let i=1;i<=8;i++){
    const sig=signals[(i+tick/60|0)%signals.length];
    const conf=Math.max(58,Math.min(99,78+Math.sin((tick+i*9)/31)*18));
    const tr=document.createElement("tr");
    tr.innerHTML=`<td>DDC-${i}</td><td>${((i-4.5)*0.625).toFixed(3)} MHz</td><td>${[12.5,25,50,100,250][i%5]} kHz</td><td>${sig}</td><td><span class="${conf>85?'ok':conf>70?'warn':'bad'}">${conf.toFixed(1)}%</span><div class="bar"><i style="width:${conf}%"></i></div></td>`;
    tb.appendChild(tr);
  }
}
function exportReport(){
  const data={
    page:"TRFMC V6R4 Signal Intelligence Center",
    timestamp:new Date().toISOString(),
    receiver:{mode:$("mode").value,center_mhz:+$("center").value,if_bw_mhz:+$("ifbw").value,fft:+$("fft").value,nf_db:+$("nf").value},
    df:{sigma_deg:+$("sigma").value,baseline_km:+$("baseline").value},
    gate:{nested_iframe:false,external_refs:false,standalone:true}
  };
  const blob=new Blob([JSON.stringify(data,null,2)],{type:"application/json"});
  const a=document.createElement("a");
  a.href=URL.createObjectURL(blob);
  a.download="trfmc_v6r4_signal_intelligence_report.json";
  a.click();
  URL.revokeObjectURL(a.href);
  addEvent("REPORT: JSON exported");
}
function loop(){
  tick++;
  $("clock").textContent=new Date().toLocaleTimeString();
  if(tick%8===0)drawSpectrum();
  if(tick%25===0)drawConstellation();
  if(tick%90===0){fillDdc(); addEvent(["DETECT: new burst above threshold","CLASSIFY: OFDM-like confidence updated","IQ: ring buffer healthy","DF: bearing variance nominal"][Math.floor(Math.random()*4)]);}
  requestAnimationFrame(loop);
}
loadState();
update();
addEvent("V6R4 Signal Intelligence Center online");
loop();
</script>
</body>
</html>
HTML

echo "[1/5] Pagina creata:"
ls -lh "$PAGE"

echo
echo "[2/5] Patch non distruttiva del Portal Link Graph"
if [ -f "$LINK_GRAPH" ]; then
  cp -a "$LINK_GRAPH" "$BACKUP/$(basename "$LINK_GRAPH").bak"
  export LINK_GRAPH PAGE_URL
  python3 - <<'PY'
import os
from pathlib import Path

p = Path(os.environ["LINK_GRAPH"])
page_url = os.environ["PAGE_URL"]
s = p.read_text(errors="ignore")

if page_url not in s:
    badge = f'''
<!-- TRFMC V6R4 SIGNAL INTELLIGENCE SAFE LINK - injected non destructive -->
<style id="trfmc-v6r4-link-style">
.trfmc-v6r4-signal-link {{
  position:fixed; right:18px; bottom:18px; z-index:9999;
  display:block; padding:11px 14px; border:1px solid #00e5ff;
  background:linear-gradient(180deg,#092238,#020811); color:#dff8ff;
  font:700 12px Inter,Segoe UI,Arial,sans-serif; letter-spacing:.7px;
  text-decoration:none; border-radius:6px; box-shadow:0 0 22px rgba(0,229,255,.28);
}}
.trfmc-v6r4-signal-link small {{display:block;color:#75ff5b;font-weight:500;margin-top:2px}}
</style>
<a class="trfmc-v6r4-signal-link" href="{page_url}">
  V6R4 SIGNAL INTELLIGENCE CENTER
  <small>FFT · DDC · CLASSIFIER · IQ · DF · METROLOGY</small>
</a>
'''
    if "</body>" in s.lower():
        idx = s.lower().rfind("</body>")
        s = s[:idx] + badge + "\n" + s[idx:]
    else:
        s += "\n" + badge + "\n"
    p.write_text(s)
    print("PATCH: link V6R4 aggiunto al Portal Link Graph")
else:
    print("OK: link V6R4 già presente")
PY
else
  echo "WARN: trfmc_portal_link_graph_v1.html non trovato; pagina V6R4 comunque creata."
fi

echo
echo "[3/5] Quality gate V6R4"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_signal_intelligence_center_v1.html \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_official_safe_entrypoint_v6r2_premium_console.html \
    /trfmc_portal_link_graph_v1.html \
    /trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html \
    /trfmc_measurement_chain_dsp_engine_v3.html \
    /trfmc_wifi_5_6_7_8_qam_engine_v1.html \
    /trfmc_5g_core_ran_identity_aka_engine_v1.html \
    /api/health
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" || echo "000 0")
    echo -e "$u\t$code\t$bytes"
  done
} > "$OUT/http.tsv"

grep -nEi '<iframe|src="/trfmc_(supervisor|unified|official_safe_entrypoint)' "$PAGE" > "$OUT/nested_iframe_refs.txt" 2>/dev/null || true
grep -nEi 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' "$PAGE" > "$OUT/external_refs.txt" 2>/dev/null || true

export OUT PAGE_URL
python3 - <<'PY'
import os, json
from pathlib import Path
from datetime import datetime, timezone

out = Path(os.environ["OUT"])
http = out / "http.tsv"

non200 = 0
for line in http.read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 2 and p[1].strip() != "200":
        non200 += 1

nested = sum(1 for x in (out/"nested_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
external = sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "v6r4_signal_intelligence": "http://127.0.0.1:5173" + os.environ["PAGE_URL"],
    "http_non_200": non200,
    "nested_iframe_refs": nested,
    "external_refs": external,
    "result": "PASS" if non200 == 0 and nested == 0 and external == 0 else "WARN"
}
(out/"summary.json").write_text(json.dumps(data, indent=4) + "\n")
print(json.dumps(data, indent=4))
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v6r4_signal_intelligence_center"

echo
echo "[4/5] Freeze sicuro V6R4"
FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_V6R4_SIGNAL_INTELLIGENCE_CENTER_$TS.tar.gz"
tar -czf "$FREEZE" \
  --exclude='frontend/node_modules' \
  --exclude='frontend/dist' \
  --exclude='.venv' \
  --exclude='runtime/freezes' \
  --exclude='runtime/collaudo' \
  -C "$BASE" .

ls -lh "$FREEZE"

echo
echo "[5/5] Report finale"
echo "=== SUMMARY ==="
cat "$OUT/summary.json" | python3 -m json.tool
echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== NESTED ==="
cat "$OUT/nested_iframe_refs.txt"
echo
echo "=== EXTERNAL ==="
cat "$OUT/external_refs.txt"

echo
echo "============================================================"
echo "V6R4 COMPLETATA"
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_signal_intelligence_center_v1.html"
echo
echo "Oppure dal grafo:"
echo "http://127.0.0.1:5173/trfmc_portal_link_graph_v1.html"
echo "============================================================"
