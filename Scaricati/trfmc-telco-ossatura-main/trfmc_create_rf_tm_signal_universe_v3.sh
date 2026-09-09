#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC RF/TM SIGNAL UNIVERSE V3"
echo "3D/4D/5D GRAPHIC · GAMING · STRUMENTALE · RF INTELLIGENCE"
echo "============================================================"
date
echo "BASE=$BASE"
echo "PUBLIC=$PUBLIC"

mkdir -p "$PUBLIC" "$BASE/runtime/engines"

PAGE="$PUBLIC/trfmc_rf_tm_signal_universe_v3.html"

if [ -f "$PAGE" ]; then
  cp -a "$PAGE" "$PAGE.bak_$TS"
fi

cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC RF/TM Signal Universe V3</title>
<style>
:root{
  --bg:#01040d;
  --panel:rgba(5,13,29,.90);
  --panel2:rgba(10,25,52,.76);
  --line:rgba(110,190,255,.28);
  --line2:rgba(120,255,210,.24);
  --text:#eaf3ff;
  --muted:#8da6c4;
  --cyan:#78d9ff;
  --green:#9dffc7;
  --amber:#ffd37a;
  --red:#ff8a8a;
  --violet:#bda7ff;
  --blue:#6aa8ff;
}
*{box-sizing:border-box}
html,body{margin:0;min-height:100%;background:var(--bg);color:var(--text);font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
body{
  background:
    radial-gradient(circle at 13% 0%,rgba(45,130,255,.30),transparent 32%),
    radial-gradient(circle at 88% 4%,rgba(0,255,190,.14),transparent 31%),
    radial-gradient(circle at 50% 105%,rgba(170,90,255,.18),transparent 34%),
    linear-gradient(180deg,#01040d,#061225 52%,#01040d);
  overflow-x:hidden;
}
body:before{
  content:"";
  position:fixed;
  inset:0;
  pointer-events:none;
  background:
    linear-gradient(rgba(255,255,255,.028) 1px,transparent 1px),
    linear-gradient(90deg,rgba(255,255,255,.028) 1px,transparent 1px);
  background-size:40px 40px;
  mask-image:linear-gradient(to bottom,rgba(0,0,0,.92),rgba(0,0,0,.10));
}
header{
  position:sticky;
  top:0;
  z-index:20;
  border-bottom:1px solid var(--line);
  background:rgba(1,4,13,.86);
  backdrop-filter:blur(20px);
}
.topbar{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:18px;
  padding:15px 20px;
}
.brand h1{
  margin:0;
  font-size:22px;
  text-transform:uppercase;
  letter-spacing:.09em;
}
.brand small{display:block;color:var(--muted);margin-top:3px}
.nav{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end}
.nav a,.pill{
  color:var(--text);
  text-decoration:none;
  border:1px solid var(--line);
  background:rgba(255,255,255,.045);
  border-radius:999px;
  padding:8px 11px;
  font-size:12px;
}
.pill.ok{color:var(--green);border-color:rgba(157,255,199,.55)}
main{position:relative;padding:18px}
.hero{
  display:grid;
  grid-template-columns:1.05fr .95fr;
  gap:16px;
  margin-bottom:16px;
}
.panel{
  border:1px solid var(--line);
  background:linear-gradient(180deg,var(--panel),rgba(2,8,20,.92));
  border-radius:22px;
  box-shadow:0 20px 70px rgba(0,0,0,.38), inset 0 1px 0 rgba(255,255,255,.055);
}
.heroMain{padding:22px}
.heroMain h2{
  margin:0 0 10px;
  font-size:44px;
  line-height:1.0;
  letter-spacing:-.05em;
}
.heroMain p{color:#c8daf1;line-height:1.55;max-width:1040px}
.kpiGrid{display:grid;grid-template-columns:repeat(5,1fr);gap:10px;margin-top:16px}
.kpi{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.045);
  border-radius:16px;
  padding:12px;
}
.kpi b{display:block;font-size:22px}
.kpi span{display:block;color:var(--muted);font-size:11px;margin-top:3px}
.statusPanel{padding:15px;display:grid;gap:9px}
.statusRow{
  display:flex;
  justify-content:space-between;
  gap:12px;
  border:1px solid rgba(255,255,255,.09);
  background:rgba(255,255,255,.04);
  border-radius:14px;
  padding:10px;
}
.statusRow span{color:var(--muted);text-align:right}
.deck{
  display:grid;
  grid-template-columns:330px minmax(700px,1fr) 370px;
  gap:16px;
}
.controls,.rightRail,.center{padding:14px}
.controls{display:grid;gap:11px;align-content:start}
.controls h3,.rightRail h3{margin:0;color:var(--cyan)}
.instrumentBlock{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.04);
  border-radius:16px;
  padding:12px;
}
.instrumentBlock h4{
  margin:0 0 9px;
  color:var(--green);
  letter-spacing:.03em;
}
.control{margin-top:9px}
.control label{
  display:flex;
  justify-content:space-between;
  gap:8px;
  color:var(--muted);
  font-size:12px;
}
input[type=range],select{width:100%;margin-top:6px}
select{
  background:#071326;
  border:1px solid var(--line);
  color:var(--text);
  padding:9px;
  border-radius:10px;
}
.modeButtons{display:grid;grid-template-columns:1fr 1fr;gap:7px}
.modeButtons button{
  border:1px solid rgba(110,190,255,.20);
  background:rgba(255,255,255,.04);
  color:var(--text);
  border-radius:12px;
  padding:8px;
  cursor:pointer;
}
.modeButtons button.active,
.modeButtons button:hover{
  border-color:rgba(120,217,255,.8);
  background:linear-gradient(135deg,rgba(45,130,255,.20),rgba(0,255,200,.09));
}
.centerHead{
  display:flex;
  justify-content:space-between;
  gap:16px;
  align-items:flex-start;
  margin-bottom:12px;
}
.centerHead h3{margin:0;font-size:28px}
.centerHead p{margin:5px 0 0;color:var(--muted)}
.badge{
  border:1px solid var(--line);
  border-radius:999px;
  color:var(--cyan);
  padding:6px 9px;
  font-size:11px;
  white-space:nowrap;
}
.canvasBox{
  border:1px solid rgba(110,190,255,.24);
  background:rgba(255,255,255,.024);
  border-radius:18px;
  overflow:hidden;
}
.canvasTitle{
  display:flex;
  justify-content:space-between;
  gap:10px;
  padding:9px 11px;
  color:var(--muted);
  font-size:12px;
  border-bottom:1px solid rgba(255,255,255,.08);
}
canvas{
  width:100%;
  display:block;
  background:
    radial-gradient(circle at 50% 50%,rgba(24,82,150,.16),transparent 42%),
    linear-gradient(180deg,rgba(255,255,255,.034),rgba(255,255,255,.010));
}
#universeCanvas{height:570px}
.matrix{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:12px;
  margin-top:12px;
}
#scopeCanvas,#spectrumCanvas,#phaseCanvas,#spaceCanvas,#waterfallCanvas,#constellationCanvas{height:245px}
.rightRail{display:grid;gap:12px;align-content:start}
.card{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.04);
  border-radius:16px;
  padding:12px;
}
.card b{display:block}
.card span,.card p{color:var(--muted);font-size:13px;line-height:1.42}
.meter{
  height:10px;
  border-radius:999px;
  background:rgba(255,255,255,.08);
  overflow:hidden;
  margin-top:8px;
}
.meter i{display:block;height:100%;width:50%;background:linear-gradient(90deg,var(--cyan),var(--green))}
.eventLog{
  max-height:270px;
  overflow:auto;
  font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;
  font-size:12px;
  color:#bfd4ec;
}
.eventLog div{padding:6px 0;border-bottom:1px solid rgba(255,255,255,.06)}
.legend{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.legend div{
  border:1px solid rgba(255,255,255,.09);
  background:rgba(255,255,255,.035);
  border-radius:12px;
  padding:9px;
  color:var(--muted);
  font-size:12px;
}
.dot{display:inline-block;width:9px;height:9px;border-radius:99px;margin-right:6px;background:var(--cyan);box-shadow:0 0 12px var(--cyan)}
.dot.g{background:var(--green);box-shadow:0 0 12px var(--green)}
.dot.a{background:var(--amber);box-shadow:0 0 12px var(--amber)}
.dot.r{background:var(--red);box-shadow:0 0 12px var(--red)}
@media(max-width:1480px){
  .deck{grid-template-columns:320px 1fr}
  .rightRail{grid-column:1/-1}
}
@media(max-width:1000px){
  .hero,.deck,.matrix{grid-template-columns:1fr}
  .kpiGrid{grid-template-columns:repeat(2,1fr)}
}
@media(max-width:720px){
  .topbar{align-items:flex-start;flex-direction:column}
  .kpiGrid{grid-template-columns:1fr}
}
</style>
</head>
<body>
<header>
  <div class="topbar">
    <div class="brand">
      <h1>TRFMC RF/TM Signal Universe V3</h1>
      <small>Receiver · Generator · Function Generator · Oscilloscope · Spectrum · Time/Frequency/Phase/Space</small>
    </div>
    <nav class="nav">
      <span class="pill ok" id="healthPill">Health: checking</span>
      <a href="/trfmc_unified_navigation_shell_v1.html">Unified Shell</a>
      <a href="/trfmc_master_digital_twin_console_v1.html">Master Console</a>
      <a href="/trfmc_signal_world_engine_v2.html">Signal World V2</a>
      <a href="/trfmc_collaudo_report.html">Collaudo</a>
      <a href="/api/health">Health</a>
    </nav>
  </div>
</header>

<main>
  <section class="hero">
    <div class="panel heroMain">
      <h2>Signal Universe 3D/4D/5D</h2>
      <p>
        Plancia RF/T&M: ricevitore, generatore di segnali, generatore di funzioni,
        oscilloscopio, analizzatore di spettro, waterfall, fase, IQ, spazio e modulazioni.
        La rappresentazione è pseudo-3D/4D/5D: spazio, frequenza, tempo, fase e ampiezza/anomalia.
      </p>
      <div class="kpiGrid">
        <div class="kpi"><b id="kRx">3.50 GHz</b><span>receiver center</span></div>
        <div class="kpi"><b id="kGen">100 kHz</b><span>function generator</span></div>
        <div class="kpi"><b id="kMod">OFDM</b><span>modulation</span></div>
        <div class="kpi"><b id="kMode">5D</b><span>view mode</span></div>
        <div class="kpi"><b id="kRisk">12%</b><span>RF anomaly</span></div>
      </div>
    </div>

    <div class="panel statusPanel">
      <div class="statusRow"><b>Receiver chain</b><span>LNA · mixer · IF · ADC · DSP</span></div>
      <div class="statusRow"><b>Generator chain</b><span>carrier · waveform · modulation · sweep</span></div>
      <div class="statusRow"><b>Domains</b><span>time · frequency · phase · space · amplitude</span></div>
      <div class="statusRow"><b>Portal</b><span>single-port 5173 · no external refs</span></div>
    </div>
  </section>

  <section class="deck">
    <aside class="panel controls">
      <h3>Instrument Control Rack</h3>

      <div class="instrumentBlock">
        <h4>RF Receiver</h4>
        <div class="control">
          <label>Center <b id="rxCenterLabel">3.50 GHz</b></label>
          <select id="rxBand">
            <option value="27">27 MHz · HF/CB</option>
            <option value="144">144 MHz · VHF</option>
            <option value="244">244 MHz · Utility</option>
            <option value="433">433 MHz · ISM Remote</option>
            <option value="868">868 MHz · IoT/ISM</option>
            <option value="1800">1.8 GHz · LTE-like</option>
            <option value="2400">2.4 GHz · WiFi</option>
            <option value="3500" selected>3.5 GHz · 5G NR</option>
            <option value="5800">5.8 GHz · WiFi/ISM</option>
          </select>
        </div>
        <div class="control">
          <label>Span <b id="spanLabel">80 MHz</b></label>
          <input id="span" type="range" min="1" max="100" value="70">
        </div>
        <div class="control">
          <label>RX Gain <b id="rxGainLabel">28 dB</b></label>
          <input id="rxGain" type="range" min="1" max="100" value="62">
        </div>
        <div class="control">
          <label>Noise Floor <b id="noiseLabel">-84 dBm</b></label>
          <input id="noise" type="range" min="1" max="100" value="35">
        </div>
      </div>

      <div class="instrumentBlock">
        <h4>Signal / Function Generator</h4>
        <div class="control">
          <label>Waveform <b id="waveLabel">Chirp</b></label>
          <select id="waveform">
            <option>Sine</option>
            <option>Square</option>
            <option>Saw</option>
            <option>Pulse</option>
            <option selected>Chirp</option>
            <option>Burst</option>
            <option>Noise</option>
          </select>
        </div>
        <div class="control">
          <label>Function Freq <b id="funcFreqLabel">100 kHz</b></label>
          <input id="funcFreq" type="range" min="1" max="100" value="44">
        </div>
        <div class="control">
          <label>Amplitude <b id="ampLabel">72%</b></label>
          <input id="amp" type="range" min="1" max="100" value="72">
        </div>
        <div class="control">
          <label>Sweep Depth <b id="sweepLabel">56%</b></label>
          <input id="sweep" type="range" min="1" max="100" value="56">
        </div>
      </div>

      <div class="instrumentBlock">
        <h4>Modulation / View</h4>
        <div class="control">
          <label>Modulation <b id="modLabel">OFDM</b></label>
          <select id="modulation">
            <option>AM</option>
            <option>FM</option>
            <option>PM</option>
            <option>ASK</option>
            <option>FSK</option>
            <option>BPSK</option>
            <option>QPSK</option>
            <option>16QAM</option>
            <option selected>OFDM</option>
            <option>WiFi-like</option>
            <option>5GNR-like</option>
          </select>
        </div>
        <div class="control">
          <label>Universe Mode</label>
          <div class="modeButtons">
            <button data-mode="3D">3D Space</button>
            <button data-mode="4D">4D Sweep</button>
            <button data-mode="5D" class="active">5D RF</button>
            <button data-mode="ATTACK">RF Watch</button>
          </div>
        </div>
      </div>
    </aside>

    <section class="panel center">
      <div class="centerHead">
        <div>
          <h3>Holographic Signal Universe</h3>
          <p>Visualizzazione strumentale: spazio RF, traiettorie, fase, ampiezza, spettro e domini incrociati.</p>
        </div>
        <span class="badge" id="viewBadge">5D RF UNIVERSE</span>
      </div>

      <div class="canvasBox">
        <div class="canvasTitle"><b>3D/4D/5D Signal Universe</b><span id="universeReadout">emitters: --</span></div>
        <canvas id="universeCanvas" width="1500" height="680"></canvas>
      </div>

      <div class="matrix">
        <div class="canvasBox">
          <div class="canvasTitle"><b>Oscilloscope / Time Domain</b><span id="scopeReadout">time: --</span></div>
          <canvas id="scopeCanvas" width="900" height="320"></canvas>
        </div>
        <div class="canvasBox">
          <div class="canvasTitle"><b>Spectrum Analyzer / Frequency Domain</b><span id="peakReadout">peak: -- dBm</span></div>
          <canvas id="spectrumCanvas" width="900" height="320"></canvas>
        </div>
        <div class="canvasBox">
          <div class="canvasTitle"><b>Phase Domain / Lissajous</b><span id="phaseReadout">phase: --°</span></div>
          <canvas id="phaseCanvas" width="900" height="320"></canvas>
        </div>
        <div class="canvasBox">
          <div class="canvasTitle"><b>Spatial RF Field</b><span id="spaceReadout">field: --</span></div>
          <canvas id="spaceCanvas" width="900" height="320"></canvas>
        </div>
        <div class="canvasBox">
          <div class="canvasTitle"><b>Waterfall</b><span>time-frequency persistence</span></div>
          <canvas id="waterfallCanvas" width="900" height="320"></canvas>
        </div>
        <div class="canvasBox">
          <div class="canvasTitle"><b>IQ / Constellation</b><span id="evmReadout">EVM: --%</span></div>
          <canvas id="constellationCanvas" width="900" height="320"></canvas>
        </div>
      </div>
    </section>

    <aside class="panel rightRail">
      <h3>RF Intelligence / Instrument Readout</h3>

      <div class="card">
        <b>Receiver Pipeline</b>
        <span>LNA → Mixer → IF → ADC → FFT → Classifier</span>
        <div class="meter"><i id="rxMeter"></i></div>
      </div>

      <div class="card">
        <b>Classification</b>
        <span id="classText">--</span>
        <div class="meter"><i id="classMeter"></i></div>
      </div>

      <div class="card">
        <b>Phase Stability</b>
        <span id="phaseText">--</span>
        <div class="meter"><i id="phaseMeter"></i></div>
      </div>

      <div class="card">
        <b>Anomaly / RF Watch</b>
        <span id="riskText">--%</span>
        <div class="meter"><i id="riskMeter"></i></div>
      </div>

      <div class="card">
        <b>Legend</b>
        <div class="legend">
          <div><span class="dot"></span>Carrier / source</div>
          <div><span class="dot g"></span>Valid modulation</div>
          <div><span class="dot a"></span>Sweep / probe</div>
          <div><span class="dot r"></span>Anomaly / jammer</div>
        </div>
      </div>

      <div class="card">
        <b>Event Stream</b>
        <div class="eventLog" id="eventLog"></div>
      </div>
    </aside>
  </section>
</main>

<script>
const $ = id => document.getElementById(id);

const canvases = {
  universe: $("universeCanvas"),
  scope: $("scopeCanvas"),
  spectrum: $("spectrumCanvas"),
  phase: $("phaseCanvas"),
  space: $("spaceCanvas"),
  waterfall: $("waterfallCanvas"),
  constellation: $("constellationCanvas")
};
const ctx = {};
Object.entries(canvases).forEach(([k,c]) => ctx[k] = c.getContext("2d"));

let t = 0;
let mode = "5D";
let emitters = [];
let lastBand = "3500";
let lastLog = 0;

const bands = {
  27: "HF/CB AM",
  144: "VHF FM",
  244: "VHF/UHF utility",
  433: "ISM FSK remote",
  868: "ISM IoT",
  1800: "LTE-like OFDM",
  2400: "WiFi OFDM",
  3500: "5G NR n78",
  5800: "WiFi/ISM"
};

function p(){
  const rx = Number($("rxBand").value);
  const span = 5 + Number($("span").value)/100 * 115;
  const gain = 2 + Number($("rxGain").value)/100 * 48;
  const noise = -110 + Number($("noise").value)/100 * 50;
  const func = 1 + Number($("funcFreq").value)/100 * 999;
  const amp = Number($("amp").value);
  const sweep = Number($("sweep").value);
  const mod = $("modulation").value;
  const wave = $("waveform").value;
  return {rx, span, gain, noise, func, amp, sweep, mod, wave, mode};
}

function updateLabels(){
  const x = p();
  $("rxCenterLabel").textContent = x.rx >= 1000 ? (x.rx/1000).toFixed(2)+" GHz" : x.rx+" MHz";
  $("spanLabel").textContent = Math.round(x.span)+" MHz";
  $("rxGainLabel").textContent = Math.round(x.gain)+" dB";
  $("noiseLabel").textContent = Math.round(x.noise)+" dBm";
  $("waveLabel").textContent = x.wave;
  $("funcFreqLabel").textContent = Math.round(x.func)+" kHz";
  $("ampLabel").textContent = Math.round(x.amp)+"%";
  $("sweepLabel").textContent = Math.round(x.sweep)+"%";
  $("modLabel").textContent = x.mod;

  $("kRx").textContent = x.rx >= 1000 ? (x.rx/1000).toFixed(2)+" GHz" : x.rx+" MHz";
  $("kGen").textContent = Math.round(x.func)+" kHz";
  $("kMod").textContent = x.mod;
  $("kMode").textContent = mode;
  $("viewBadge").textContent = mode + " RF UNIVERSE";
}

function regenerateEmitters(){
  const x = p();
  emitters = [];
  const n = x.rx >= 2400 ? 18 : x.rx >= 433 ? 13 : 9;
  for(let i=0;i<n;i++){
    emitters.push({
      x:(Math.random()-.5)*2.0,
      y:(Math.random()-.5)*1.3,
      z:Math.random()*2.2-0.3,
      amp:.25+Math.random()*.8,
      phase:Math.random()*Math.PI*2,
      drift:(Math.random()-.5)*.003,
      type: Math.random() < (mode==="ATTACK" ? .22 : .10) ? "anomaly" : "valid",
      offset:(Math.random()-.5)*0.9
    });
  }
  lastBand = String(x.rx);
}

function grid(c,w,h){
  c.strokeStyle="rgba(110,190,255,.075)";
  c.lineWidth=1;
  for(let x=0;x<w;x+=50){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke();}
  for(let y=0;y<h;y+=40){c.beginPath();c.moveTo(0,y);c.lineTo(w,y);c.stroke();}
}

function label(c,text,x,y,color="rgba(234,243,255,.82)",size=13){
  c.fillStyle=color;
  c.font=size+"px system-ui";
  c.fillText(text,x,y);
}

function project(pt,w,h){
  const z = pt.z + 2.8;
  const scale = 420 / z;
  return {
    x: w/2 + pt.x * scale,
    y: h/2 + pt.y * scale - pt.z*48,
    s: scale/260,
    z
  };
}

function drawUniverse(){
  const c=ctx.universe, w=canvases.universe.width, h=canvases.universe.height;
  const x=p();
  c.clearRect(0,0,w,h);

  const g=c.createRadialGradient(w/2,h/2,40,w/2,h/2,w*.72);
  g.addColorStop(0,"rgba(28,110,210,.18)");
  g.addColorStop(1,"rgba(255,255,255,.01)");
  c.fillStyle=g;
  c.fillRect(0,0,w,h);
  grid(c,w,h);

  // 3D perspective grid
  c.strokeStyle="rgba(120,255,210,.12)";
  for(let i=-8;i<=8;i++){
    const a=project({x:i*.18,y:-.8,z:0},w,h);
    const b=project({x:i*.18,y:.9,z:2.2},w,h);
    c.beginPath();c.moveTo(a.x,a.y);c.lineTo(b.x,b.y);c.stroke();
  }
  for(let j=0;j<=10;j++){
    c.beginPath();
    for(let i=-10;i<=10;i++){
      const q=project({x:i*.18,y:-.8+j*.17,z:j*.22},w,h);
      if(i===-10)c.moveTo(q.x,q.y);else c.lineTo(q.x,q.y);
    }
    c.stroke();
  }

  // receiver/generator nodes
  const rx = project({x:-1.25,y:.52,z:.35},w,h);
  const gen = project({x:1.25,y:.52,z:.35},w,h);

  function drawNode(q,name,color){
    c.fillStyle=color;
    c.shadowColor=color;
    c.shadowBlur=18;
    c.beginPath();c.arc(q.x,q.y,12,0,Math.PI*2);c.fill();
    c.shadowBlur=0;
    label(c,name,q.x-42,q.y+32,"rgba(234,243,255,.82)",13);
  }
  drawNode(rx,"RX CHAIN","rgba(120,217,255,.95)");
  drawNode(gen,"GENERATOR","rgba(157,255,199,.95)");

  // links generator to receiver
  c.strokeStyle="rgba(255,211,122,.24)";
  c.lineWidth=2;
  c.beginPath();
  c.moveTo(gen.x,gen.y);
  c.bezierCurveTo(w*.68,h*.22,w*.32,h*.22,rx.x,rx.y);
  c.stroke();

  // scan rings
  const sweep = (Math.sin(t*.018)*.5+.5);
  const sweepX = w*(.14 + sweep*.72);
  const beam=c.createLinearGradient(sweepX-120,0,sweepX+120,0);
  beam.addColorStop(0,"rgba(255,211,122,0)");
  beam.addColorStop(.5,"rgba(255,211,122,.20)");
  beam.addColorStop(1,"rgba(255,211,122,0)");
  c.fillStyle=beam;
  c.fillRect(sweepX-130,0,260,h);

  // emitters in 3D
  emitters.forEach((e,i)=>{
    e.phase += .025 + e.amp*.015;
    e.x += e.drift;
    if(e.x > 1.25) e.x = -1.25;
    if(e.x < -1.25) e.x = 1.25;

    const q=project({
      x:e.x + Math.sin(t*.004+i)*.04,
      y:e.y + Math.cos(t*.003+i)*.04,
      z:e.z + Math.sin(t*.006+e.phase)*.08
    },w,h);

    const col = e.type==="anomaly" ? "255,138,138" : "120,217,255";
    const col2 = e.type==="anomaly" ? "255,88,88" : "157,255,199";
    const r = 5 + e.amp*9*q.s;

    for(let rr=22; rr<100+e.amp*80; rr+=22){
      c.strokeStyle=`rgba(${col},${Math.max(.035,.16-rr/650)})`;
      c.beginPath();
      c.ellipse(q.x,q.y,rr*q.s*1.8,rr*q.s*.65,0,0,Math.PI*2);
      c.stroke();
    }

    c.shadowColor=`rgba(${col2},.9)`;
    c.shadowBlur=16;
    c.fillStyle=`rgba(${col2},.92)`;
    c.beginPath();c.arc(q.x,q.y,r,0,Math.PI*2);c.fill();
    c.shadowBlur=0;

    c.strokeStyle=e.type==="anomaly"?"rgba(255,138,138,.26)":"rgba(120,217,255,.18)";
    c.beginPath();
    c.moveTo(q.x,q.y);
    c.lineTo(rx.x,rx.y);
    c.stroke();

    if(mode==="5D" || mode==="ATTACK"){
      const phaseArc = 18 + Math.sin(e.phase)*12;
      c.strokeStyle=`rgba(189,167,255,.34)`;
      c.beginPath();c.arc(q.x,q.y,Math.abs(phaseArc)+18,0,e.phase%(Math.PI*2));c.stroke();
    }
  });

  label(c,`RX ${x.rx>=1000?(x.rx/1000).toFixed(2)+"GHz":x.rx+"MHz"} · ${bands[x.rx]} · ${x.mod} · ${x.wave}`,22,32);
  label(c,"Dimensions: space(X/Y/Z) · time · frequency · phase · amplitude/anomaly",22,55,"rgba(141,166,196,.88)",13);
  $("universeReadout").textContent = "emitters: "+emitters.length+" · mode: "+mode;
}

function sampleWave(i,phase=0){
  const x=p();
  const tt = i*.035 + t*.055 + phase;
  let y = 0;
  if(x.wave==="Sine") y = Math.sin(tt);
  else if(x.wave==="Square") y = Math.sin(tt)>0?1:-1;
  else if(x.wave==="Saw") y = ((tt/Math.PI)%2)-1;
  else if(x.wave==="Pulse") y = Math.sin(tt)>0.7?1:0;
  else if(x.wave==="Chirp") y = Math.sin(tt + Math.sin(t*.01)*i*.006);
  else if(x.wave==="Burst") y = Math.sin(tt) * (Math.sin(t*.025)>0?.95:.18);
  else y = (Math.random()-.5)*2;
  return y * x.amp/100;
}

function drawScope(){
  const c=ctx.scope,w=canvases.scope.width,h=canvases.scope.height;
  c.clearRect(0,0,w,h);grid(c,w,h);
  const mid=h/2;
  c.strokeStyle="rgba(157,255,199,.90)";
  c.lineWidth=2;
  c.beginPath();
  for(let i=0;i<w;i++){
    const y = mid - sampleWave(i)*110 + Math.sin(i*.012+t*.03)*8;
    if(i===0)c.moveTo(i,y);else c.lineTo(i,y);
  }
  c.stroke();

  c.strokeStyle="rgba(120,217,255,.68)";
  c.beginPath();
  for(let i=0;i<w;i++){
    const y = mid - sampleWave(i,Math.PI/2)*70;
    if(i===0)c.moveTo(i,y);else c.lineTo(i,y);
  }
  c.stroke();

  $("scopeReadout").textContent = "waveform: "+p().wave;
  label(c,"Oscilloscope CH1/CH2",16,24);
}

function generateSpectrum(){
  const x=p(), w=canvases.spectrum.width;
  const arr=new Float32Array(w);
  let peak=-140;
  for(let i=0;i<w;i++){
    let db=x.noise+(Math.random()-.5)*4+Math.sin(i*.018+t*.022)*2;

    emitters.forEach((e,k)=>{
      const center = w*(.5 + e.offset*.42 + Math.sin(t*.004+k)*.015);
      let width = 11+x.span*.16+e.amp*24;
      let amp = (14+x.gain*.45)*e.amp;
      if(e.type==="anomaly"){width*=3.1;amp*=1.35;}
      db += Math.exp(-Math.pow(i-center,2)/(width*width))*amp;
    });

    if(x.mod==="OFDM" || x.mod==="WiFi-like" || x.mod==="5GNR-like"){
      for(let k=-14;k<=14;k++){
        const c=w*.5+k*(5+x.span*.045);
        db+=Math.exp(-Math.pow(i-c,2)/(8+x.span*.04))*5.2;
      }
    }
    if(x.mod==="FSK"){
      db+=Math.exp(-Math.pow(i-w*.45,2)/(13*13))*13;
      db+=Math.exp(-Math.pow(i-w*.55,2)/(13*13))*13;
    }
    if(x.mod==="AM"){
      db+=Math.exp(-Math.pow(i-w*.5,2)/(10*10))*14;
      db+=Math.exp(-Math.pow(i-w*.42,2)/(16*16))*8;
      db+=Math.exp(-Math.pow(i-w*.58,2)/(16*16))*8;
    }
    arr[i]=db; peak=Math.max(peak,db);
  }
  return {arr,peak};
}

function drawSpectrum(data){
  const c=ctx.spectrum,w=canvases.spectrum.width,h=canvases.spectrum.height;
  c.clearRect(0,0,w,h);grid(c,w,h);
  c.beginPath();
  for(let i=0;i<w;i++){
    const n=Math.max(0,Math.min(1,(data.arr[i]+120)/85));
    const y=h-30-n*(h-60);
    if(i===0)c.moveTo(i,y);else c.lineTo(i,y);
  }
  c.strokeStyle="rgba(120,217,255,.96)";
  c.lineWidth=2;
  c.stroke();
  c.lineTo(w,h-30);c.lineTo(0,h-30);c.closePath();
  c.fillStyle="rgba(120,217,255,.10)";
  c.fill();
  $("peakReadout").textContent="peak: "+data.peak.toFixed(1)+" dBm";
  label(c,"Spectrum Analyzer · RBW/VBW synthetic",16,24);
}

function drawWaterfall(data){
  const c=ctx.waterfall,w=canvases.waterfall.width,h=canvases.waterfall.height;
  const img=c.getImageData(0,0,w,h-1);
  c.putImageData(img,0,1);
  for(let i=0;i<w;i++){
    const n=Math.max(0,Math.min(1,(data.arr[i]+115)/80));
    const r=Math.round(12+n*115);
    const g=Math.round(42+n*185);
    const b=Math.round(85+n*160);
    c.fillStyle=`rgb(${r},${g},${b})`;
    c.fillRect(i,0,1,1);
  }
}

function drawPhase(){
  const c=ctx.phase,w=canvases.phase.width,h=canvases.phase.height;
  c.clearRect(0,0,w,h);grid(c,w,h);
  const cx=w/2,cy=h/2;
  c.strokeStyle="rgba(157,255,199,.18)";
  c.beginPath();c.moveTo(cx,25);c.lineTo(cx,h-25);c.stroke();
  c.beginPath();c.moveTo(25,cy);c.lineTo(w-25,cy);c.stroke();

  c.beginPath();
  for(let i=0;i<900;i++){
    const a=i*.025+t*.02;
    const ph=Number($("sweep").value)/100*Math.PI;
    const x=Math.sin(a)*Math.cos(ph)-Math.sin(a*0.72+t*.01)*Math.sin(ph);
    const y=Math.sin(a*0.72+t*.01);
    const px=cx+x*w*.32, py=cy-y*h*.32;
    if(i===0)c.moveTo(px,py);else c.lineTo(px,py);
  }
  c.strokeStyle="rgba(189,167,255,.90)";
  c.lineWidth=1.8;
  c.stroke();

  const deg=Math.round((Number($("sweep").value)/100)*180);
  $("phaseReadout").textContent="phase: "+deg+"°";
  label(c,"Phase / Lissajous Domain",16,24);
}

function drawSpace(){
  const c=ctx.space,w=canvases.space.width,h=canvases.space.height;
  c.clearRect(0,0,w,h);
  const cell=20;
  const xpar=p();
  for(let y=0;y<h;y+=cell){
    for(let x=0;x<w;x+=cell){
      let v=0;
      emitters.forEach(e=>{
        const ex=w/2+e.x*w*.32, ey=h/2+e.y*h*.34;
        const d=Math.hypot(x-ex,y-ey)+1;
        v+=e.amp*1200/(d*d+220);
      });
      const n=Math.max(0,Math.min(1,v*(xpar.gain/28)));
      const r=Math.round(12+n*80);
      const g=Math.round(35+n*170);
      const b=Math.round(70+n*170);
      c.fillStyle=`rgba(${r},${g},${b},.72)`;
      c.fillRect(x,y,cell,cell);
    }
  }
  grid(c,w,h);
  label(c,"Spatial RF Field / Power Density",16,24);
  $("spaceReadout").textContent="field: "+emitters.length+" sources";
}

function constellationPoints(){
  const x=p(), pts=[];
  const n=450;
  const noise=Math.max(.015,(100-Number($("rxGain").value))/620+Number($("noise").value)/3200);
  const add=(a,b)=>pts.push([a+(Math.random()-.5)*noise*2,b+(Math.random()-.5)*noise*2]);

  for(let i=0;i<n;i++){
    if(x.mod==="BPSK") add(Math.random()>.5?.75:-.75,0);
    else if(x.mod==="QPSK") add(Math.random()>.5?.62:-.62,Math.random()>.5?.62:-.62);
    else if(x.mod==="16QAM"){
      const v=[-.75,-.25,.25,.75];add(v[Math.floor(Math.random()*4)],v[Math.floor(Math.random()*4)]);
    }else if(x.mod==="OFDM" || x.mod==="WiFi-like" || x.mod==="5GNR-like"){
      const a=Math.random()*Math.PI*2,r=.15+Math.random()*.78;add(Math.cos(a)*r,Math.sin(a)*r);
    }else if(x.mod==="FSK"){
      add(Math.random()>.5?.55:-.55,Math.sin(i*.4+t*.04)*.18);
    }else{
      const a=i*.19+t*.025,r=x.mod==="AM"?.35+Math.sin(i*.08+t*.02)*.22:.62;add(Math.cos(a)*r,Math.sin(a)*r);
    }
  }
  return pts;
}

function drawConstellation(){
  const c=ctx.constellation,w=canvases.constellation.width,h=canvases.constellation.height;
  c.clearRect(0,0,w,h);grid(c,w,h);
  const cx=w/2,cy=h/2,s=Math.min(w,h)*.36;
  c.strokeStyle="rgba(157,255,199,.18)";
  c.beginPath();c.moveTo(cx,25);c.lineTo(cx,h-25);c.stroke();
  c.beginPath();c.moveTo(25,cy);c.lineTo(w-25,cy);c.stroke();

  c.fillStyle="rgba(157,255,199,.78)";
  constellationPoints().forEach(([x,y])=>{
    c.beginPath();c.arc(cx+x*s,cy-y*s,2.3,0,Math.PI*2);c.fill();
  });

  const evm=Math.max(1.1,Math.min(38,27-Number($("rxGain").value)*.12+Number($("noise").value)*.12+(mode==="ATTACK"?6:0)));
  $("evmReadout").textContent="EVM: "+evm.toFixed(1)+"%";
  label(c,"IQ / Constellation",16,24);
}

function updateKpis(data){
  const x=p();
  const risk=Math.max(2,Math.min(99,Math.round(emitters.filter(e=>e.type==="anomaly").length*9+Number($("noise").value)*.2+(mode==="ATTACK"?22:0))));
  const confidence=Math.max(5,Math.min(99,Math.round(Number($("rxGain").value)*.75+(100-Number($("noise").value))*.25)));
  const phase=Math.max(6,Math.min(98,Math.round(100-Number($("sweep").value)*.55-Number($("noise").value)*.08)));
  const rxLoad=Math.max(10,Math.min(99,Math.round(x.span*.42+x.gain*.65)));

  $("kRisk").textContent=risk+"%";
  $("riskText").textContent=risk+"%";
  $("riskMeter").style.width=risk+"%";
  $("classText").textContent=(bands[x.rx]||"RF signal")+" · "+x.mod+" · confidence "+confidence+"%";
  $("classMeter").style.width=confidence+"%";
  $("phaseText").textContent=phase+"% coherent";
  $("phaseMeter").style.width=phase+"%";
  $("rxMeter").style.width=rxLoad+"%";
}

function logEvent(){
  const now=Date.now();
  if(now-lastLog<1600)return;
  lastLog=now;
  const x=p();
  const row=document.createElement("div");
  row.textContent=`[${new Date().toLocaleTimeString()}] ${mode} RX=${x.rx}MHz MOD=${x.mod} WAVE=${x.wave} emitters=${emitters.length}`;
  $("eventLog").prepend(row);
  while($("eventLog").children.length>20)$("eventLog").removeChild($("eventLog").lastChild);
}

function loop(){
  t++;
  if(lastBand!==$("rxBand").value) regenerateEmitters();
  updateLabels();
  drawUniverse();
  drawScope();
  const data=generateSpectrum();
  drawSpectrum(data);
  drawWaterfall(data);
  drawPhase();
  drawSpace();
  drawConstellation();
  updateKpis(data);
  logEvent();
  requestAnimationFrame(loop);
}

async function health(){
  try{
    const r=await fetch("/api/health",{cache:"no-store"});
    const j=await r.json();
    $("healthPill").textContent=j.ok?"Health: online":"Health: degraded";
  }catch(e){
    $("healthPill").textContent="Health: unavailable";
    $("healthPill").classList.remove("ok");
  }
}

document.querySelectorAll(".modeButtons button").forEach(b=>{
  b.onclick=()=>{
    mode=b.dataset.mode;
    document.querySelectorAll(".modeButtons button").forEach(x=>x.classList.toggle("active",x===b));
    if(mode==="ATTACK") emitters.forEach((e,i)=>{ if(i%4===0)e.type="anomaly"; });
    updateLabels();
  };
});

["rxBand","span","rxGain","noise","waveform","funcFreq","amp","sweep","modulation"].forEach(id=>{
  $(id).addEventListener("input",()=>{
    if(id==="rxBand") regenerateEmitters();
    updateLabels();
  });
});

regenerateEmitters();
health();
updateLabels();
loop();
</script>
</body>
</html>
HTML

echo
echo "=== PATCH NAVIGATION LINKS ==="

python3 - <<'PY'
from pathlib import Path

files = [
    Path("frontend/public/trfmc_unified_navigation_shell_v1.html"),
    Path("frontend/public/trfmc_master_digital_twin_console_v1.html"),
    Path("frontend/public/trfmc_engine_promotion_board_v1.html"),
    Path("frontend/public/trfmc_domain_registry_v1.html"),
    Path("frontend/public/trfmc_signal_world_engine_v2.html"),
    Path("frontend/public/api/portal/index"),
]

for p in files:
    if not p.exists():
        print("SKIP:", p)
        continue

    s = p.read_text(errors="ignore")
    old = s

    if "trfmc_rf_tm_signal_universe_v3.html" not in s:
        if '<a href="/trfmc_signal_world_engine_v2.html">Signal World Engine</a>' in s:
            s = s.replace(
                '<a href="/trfmc_signal_world_engine_v2.html">Signal World Engine</a>',
                '<a href="/trfmc_rf_tm_signal_universe_v3.html">RF/TM Signal Universe V3</a>\n      <a href="/trfmc_signal_world_engine_v2.html">Signal World Engine</a>',
                1
            )
        elif "<ul>" in s:
            s = s.replace(
                "<ul>",
                '<ul>\n<li><a href="/trfmc_rf_tm_signal_universe_v3.html">RF/TM Signal Universe V3</a></li>',
                1
            )
        elif '<a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>' in s:
            s = s.replace(
                '<a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>',
                '<a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>\n      <a href="/trfmc_rf_tm_signal_universe_v3.html">RF/TM Signal Universe V3</a>',
                1
            )

    if s != old:
        p.write_text(s)
        print("PATCHED:", p)
    else:
        print("UNCHANGED:", p)
PY

echo
echo "=== TEST HTTP ==="
curl -I --max-time 5 http://127.0.0.1:5173/trfmc_rf_tm_signal_universe_v3.html

echo
echo "RF/TM SIGNAL UNIVERSE V3:"
echo "http://127.0.0.1:5173/trfmc_rf_tm_signal_universe_v3.html"
