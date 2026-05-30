#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
SRC="$PUBLIC/trfmc_antenna_system_explorer_v15_instrument_center.html"
DST="$PUBLIC/trfmc_antenna_system_explorer_v16_metrology_premium.html"

if [ ! -f "$SRC" ]; then
  echo "ERRORE: manca $SRC"
  exit 1
fi

cp -f "$SRC" "$DST"

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/public/trfmc_antenna_system_explorer_v16_metrology_premium.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "TRFMC Antenna System Explorer V1.5 Instrument Center",
    "TRFMC Antenna System Explorer V1.6 Metrology Premium"
)
s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.5 Instrument Center</title>",
    "<title>TRFMC Antenna System Explorer V1.6 Metrology Premium</title>"
)

css = r'''
/* === V1.6 METROLOGY PREMIUM LAYER === */
.v16Scope{
  position:absolute;
  left:8px;
  right:8px;
  top:98px;
  z-index:6;
  display:grid;
  grid-template-columns:280px 1fr 310px;
  gap:6px;
  pointer-events:none;
}
.v16Glass{
  border:1px solid rgba(0,217,255,.40);
  background:rgba(2,8,15,.78);
  border-radius:6px;
  padding:7px;
  backdrop-filter:blur(12px);
  box-shadow:0 0 22px rgba(0,217,255,.08);
}
.v16Glass h4{
  margin:0 0 6px;
  color:#00d9ff;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.04em;
}
.v16MiniGrid{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:5px;
}
.v16Metric{
  border:1px solid rgba(36,91,125,.85);
  background:linear-gradient(180deg,#071626,#02070f);
  border-radius:4px;
  padding:5px;
}
.v16Metric span{
  display:block;
  color:#87a8c6;
  font-size:8px;
  text-transform:uppercase;
}
.v16Metric b{
  display:block;
  color:#eaf3ff;
  font-size:13px;
}
.v16Metric.pass b{color:#7dff4f}
.v16Metric.warn b{color:#ffd500}
.v16Metric.fail b{color:#ff3366}
.v16Acceptance{
  border-collapse:collapse;
  width:100%;
  font-family:ui-monospace,monospace;
  font-size:10px;
}
.v16Acceptance th,.v16Acceptance td{
  border-bottom:1px solid rgba(255,255,255,.08);
  padding:3px 4px;
  text-align:left;
}
.v16Acceptance th{color:#87a8c6}
.v16Acceptance td:last-child{text-align:right;color:#7dff4f}
.v16Acceptance tr.fail td:last-child{color:#ff3366}
.v16Acceptance tr.warn td:last-child{color:#ffd500}
.v16BottomBar{
  position:absolute;
  left:8px;
  right:8px;
  bottom:70px;
  z-index:7;
  border:1px solid rgba(255,213,0,.40);
  background:rgba(3,10,18,.84);
  border-radius:6px;
  padding:6px;
  display:grid;
  grid-template-columns:repeat(8,1fr);
  gap:5px;
  backdrop-filter:blur(10px);
}
.v16BottomCell{
  border:1px solid rgba(36,91,125,.85);
  background:#081522;
  border-radius:4px;
  padding:5px;
  font-family:ui-monospace,monospace;
}
.v16BottomCell span{display:block;color:#87a8c6;font-size:8px;text-transform:uppercase}
.v16BottomCell b{display:block;color:#7dff4f;font-size:12px}
.v16ControlDeck{
  border:1px solid #183d58;
  background:#081522;
  border-radius:5px;
  padding:7px;
  margin-bottom:7px;
}
.v16ControlDeck b{
  display:block;
  color:#ffd500;
  margin-bottom:5px;
}
.v16ControlDeck button{
  text-align:center;
}
.v16ControlGrid{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:5px;
}
.v16ReportBtn{
  border-color:#ffd500!important;
  box-shadow:inset 3px 0 0 #ffd500;
}
.v16Trace{
  height:42px;
  width:100%;
  border:1px solid rgba(36,91,125,.85);
  background:#02070f;
  border-radius:4px;
  margin-top:5px;
}
@media(max-width:1300px){
  .v16Scope{position:relative;top:auto;left:auto;right:auto;grid-template-columns:1fr}
  .v16BottomBar{position:relative;bottom:auto;left:auto;right:auto;grid-template-columns:1fr 1fr}
}
'''

s = s.replace("</style>", css + "\n</style>")

js = r'''
<script>
/* === TRFMC ANTENNA V1.6 METROLOGY PREMIUM === */
(function(){
  const V16_KEY = "trfmc_antenna_v16_metrology_premium";
  const v16 = {
    bench:"TRFMC-ANT-RF-CENTER-01",
    procedure:"ANT-RRU-MIMO-PRECOMPLIANCE-001",
    uncertaintyClass:"LAB-GRADE",
    sequence:"IDLE",
    step:0,
    last:"BOOT",
    samples:[],
    sweep:[],
    acceptance:[],
    reportSeq:1
  };

  function el(id){return document.getElementById(id)}
  function qs(x){return document.querySelector(x)}
  function log(m){ if(typeof addLog==="function") addLog("V16 · "+m); v16.last=m; updateV16(); }
  function param(id){const x=el(id); if(!x) return null; return x.type==="checkbox"?x.checked:x.value}
  function setParam(id,v){const x=el(id); if(!x) return; if(x.type==="checkbox")x.checked=!!v; else x.value=v; x.dispatchEvent(new Event("input",{bubbles:true}))}

  function P(){
    return {
      type:param("type"), service:param("service"),
      freq:+param("freq"), gain:+param("gain"), az:+param("az"), tilt:+param("tilt"),
      vswr:+param("vswr")/100, rl:+param("rl"), iso:+param("iso"),
      bal:+param("bal")/10, ptx:+param("ptx"), sectors:+param("sectors"),
      cableLoss:+(el("v16CableLoss")?.value||0.7),
      antHeight:+(el("v16AntHeight")?.value||30),
      distance:+(el("v16Distance")?.value||1),
      calUnc:+(el("v16CalUnc")?.value||0.45),
      temp:+(el("v16AmbientTemp")?.value||24)
    }
  }

  function calc(){
    const p=P();
    const lambda = 299792458/(p.freq*1e6);
    const gamma = (p.vswr-1)/(p.vswr+1);
    const mismatchLoss = -10*Math.log10(Math.max(0.0001,1-gamma*gamma));
    const acceptedPower = p.ptx - mismatchLoss;
    const eirp = p.ptx + p.gain - p.cableLoss - mismatchLoss;
    const fspl = 32.44 + 20*Math.log10(p.freq) + 20*Math.log10(Math.max(.001,p.distance));
    const prx = eirp - fspl;
    const noise = -174 + 10*Math.log10(100e3) + 7;
    const snr = prx - noise;
    const hpbw = Math.max(3, 72 - p.gain*1.65);
    const nearField = 2*Math.pow(1.2,2)/lambda;
    const horizon = 3.57*(Math.sqrt(p.antHeight)+Math.sqrt(1.5));
    const returnPower = p.ptx - p.rl;
    const rfMargin = Math.min(20, Math.max(-10, (p.rl-14)*0.8 + (p.iso-24)*0.5 - (p.vswr-1.5)*5));
    const uncertainty = Math.sqrt(p.calUnc*p.calUnc + 0.18*0.18 + (p.vswr-1)*0.22 + (p.bal*0.08)**2);
    const qVswr = p.vswr <= 1.5 ? "PASS" : p.vswr <= 1.9 ? "WARN" : "FAIL";
    const qRl = p.rl >= 16 ? "PASS" : p.rl >= 10 ? "WARN" : "FAIL";
    const qIso = p.iso >= 28 ? "PASS" : p.iso >= 20 ? "WARN" : "FAIL";
    const qBal = p.bal <= 1.0 ? "PASS" : p.bal <= 2.0 ? "WARN" : "FAIL";
    const qEirp = eirp >= 25 ? "PASS" : eirp >= 18 ? "WARN" : "FAIL";
    const overall = [qVswr,qRl,qIso,qBal,qEirp].includes("FAIL") ? "FAIL" : [qVswr,qRl,qIso,qBal,qEirp].includes("WARN") ? "WARN" : "PASS";
    return {lambda,gamma,mismatchLoss,acceptedPower,eirp,fspl,prx,noise,snr,hpbw,nearField,horizon,returnPower,rfMargin,uncertainty,qVswr,qRl,qIso,qBal,qEirp,overall};
  }

  function injectLeftControls(){
    const left = qs("main > aside:first-child .body");
    if(!left || el("v16Controls")) return;

    const deck = document.createElement("div");
    deck.id = "v16Controls";
    deck.className = "v16ControlDeck";
    deck.innerHTML = `
      <b>Metrology / Site Inputs</b>
      <label>Cable Loss <span id="v16CableLossV">0.7 dB</span></label><input id="v16CableLoss" type="range" min="0" max="5" step="0.1" value="0.7">
      <label>Antenna Height <span id="v16AntHeightV">30 m</span></label><input id="v16AntHeight" type="range" min="2" max="120" step="1" value="30">
      <label>Distance <span id="v16DistanceV">1.0 km</span></label><input id="v16Distance" type="range" min="0.1" max="30" step="0.1" value="1">
      <label>Cal Uncertainty <span id="v16CalUncV">0.45 dB</span></label><input id="v16CalUnc" type="range" min="0.05" max="2.5" step="0.05" value="0.45">
      <label>Ambient Temp <span id="v16AmbientTempV">24 °C</span></label><input id="v16AmbientTemp" type="range" min="-10" max="55" step="1" value="24">
      <div class="v16ControlGrid">
        <button onclick="TRFMC_V16.acceptanceSweep()">Acceptance Sweep</button>
        <button onclick="TRFMC_V16.maskStress()">Mask Stress</button>
        <button onclick="TRFMC_V16.portBalance()">Port Balance</button>
        <button onclick="TRFMC_V16.uncertaintyRun()">Uncertainty</button>
        <button onclick="TRFMC_V16.connectorFault()">Connector Fault</button>
        <button onclick="TRFMC_V16.restoreGold()">Gold Baseline</button>
      </div>
    `;
    left.appendChild(deck);

    ["v16CableLoss","v16AntHeight","v16Distance","v16CalUnc","v16AmbientTemp"].forEach(id=>{
      el(id).addEventListener("input", updateV16);
    });
  }

  function injectScope(){
    const frame = el("site")?.closest(".frame");
    if(!frame || el("v16Scope")) return;

    const scope = document.createElement("div");
    scope.id = "v16Scope";
    scope.className = "v16Scope";
    scope.innerHTML = `
      <div class="v16Glass">
        <h4>Metrology Readout</h4>
        <div class="v16MiniGrid">
          <div class="v16Metric"><span>EIRP</span><b id="v16Eirp">--</b></div>
          <div class="v16Metric"><span>Prx @ dist</span><b id="v16Prx">--</b></div>
          <div class="v16Metric"><span>FSPL</span><b id="v16Fspl">--</b></div>
          <div class="v16Metric"><span>SNR Proxy</span><b id="v16Snr">--</b></div>
          <div class="v16Metric"><span>RF Margin</span><b id="v16Margin">--</b></div>
          <div class="v16Metric"><span>Uncertainty</span><b id="v16Unc">--</b></div>
        </div>
        <canvas id="v16Trace" class="v16Trace" width="260" height="42"></canvas>
      </div>
      <div class="v16Glass">
        <h4>Acceptance Gate</h4>
        <table class="v16Acceptance">
          <thead><tr><th>Test</th><th>Limit</th><th>Measured</th><th>Gate</th></tr></thead>
          <tbody id="v16AcceptanceRows"></tbody>
        </table>
      </div>
      <div class="v16Glass">
        <h4>Procedure / Traceability</h4>
        <table class="v16Acceptance">
          <tbody>
            <tr><th>Bench</th><td id="v16Bench">TRFMC-ANT-RF-CENTER-01</td></tr>
            <tr><th>Procedure</th><td id="v16Proc">ANT-RRU-MIMO-PRECOMPLIANCE-001</td></tr>
            <tr><th>Sequence</th><td id="v16Seq">IDLE</td></tr>
            <tr><th>Step</th><td id="v16Step">0</td></tr>
            <tr><th>Overall</th><td id="v16Overall">PASS</td></tr>
          </tbody>
        </table>
      </div>
    `;
    frame.appendChild(scope);

    const bar = document.createElement("div");
    bar.id = "v16BottomBar";
    bar.className = "v16BottomBar";
    bar.innerHTML = `
      <div class="v16BottomCell"><span>λ</span><b id="v16B_lambda">--</b></div>
      <div class="v16BottomCell"><span>Γ</span><b id="v16B_gamma">--</b></div>
      <div class="v16BottomCell"><span>Mismatch</span><b id="v16B_mismatch">--</b></div>
      <div class="v16BottomCell"><span>Accepted</span><b id="v16B_accepted">--</b></div>
      <div class="v16BottomCell"><span>Return Power</span><b id="v16B_return">--</b></div>
      <div class="v16BottomCell"><span>HPBW</span><b id="v16B_hpbw">--</b></div>
      <div class="v16BottomCell"><span>Near Field</span><b id="v16B_nf">--</b></div>
      <div class="v16BottomCell"><span>Horizon</span><b id="v16B_horizon">--</b></div>
    `;
    frame.appendChild(bar);
  }

  function injectRightDeck(){
    const right = qs("main > aside:last-child .body");
    if(!right || el("v16RightDeck")) return;

    const deck = document.createElement("div");
    deck.id = "v16RightDeck";
    deck.className = "icRightDeck";
    deck.innerHTML = `
      <h4>Premium Center Actions</h4>
      <div class="inner">
        <div class="icMiniButtons">
          <button onclick="TRFMC_V16.acceptanceSweep()">Run Full Acceptance</button>
          <button onclick="TRFMC_V16.quickCheck()">Quick Check</button>
          <button onclick="TRFMC_V16.exportHtmlReport()" class="v16ReportBtn">Export HTML Report</button>
          <button onclick="TRFMC_V16.exportJsonReport()" class="v16ReportBtn">Export JSON Report</button>
          <button onclick="TRFMC_V16.scpiPreset()">SCPI Preset</button>
          <button onclick="TRFMC_V16.clearV16()">Clear V1.6</button>
        </div>
      </div>
    `;
    right.insertBefore(deck, right.firstChild);
  }

  function fmtDb(x){return (Number.isFinite(x)?x.toFixed(1):"--")+" dB"}
  function fmtDbm(x){return (Number.isFinite(x)?x.toFixed(1):"--")+" dBm"}

  function updateLabels(){
    const p=P();
    if(el("v16CableLossV")) el("v16CableLossV").textContent = p.cableLoss.toFixed(1)+" dB";
    if(el("v16AntHeightV")) el("v16AntHeightV").textContent = p.antHeight.toFixed(0)+" m";
    if(el("v16DistanceV")) el("v16DistanceV").textContent = p.distance.toFixed(1)+" km";
    if(el("v16CalUncV")) el("v16CalUncV").textContent = p.calUnc.toFixed(2)+" dB";
    if(el("v16AmbientTempV")) el("v16AmbientTempV").textContent = p.temp.toFixed(0)+" °C";
  }

  function updateV16(){
    updateLabels();
    const p=P(), m=calc();

    const map = {
      v16Eirp:fmtDbm(m.eirp),
      v16Prx:fmtDbm(m.prx),
      v16Fspl:fmtDb(m.fspl),
      v16Snr:fmtDb(m.snr),
      v16Margin:fmtDb(m.rfMargin),
      v16Unc:"±"+m.uncertainty.toFixed(2)+" dB",
      v16B_lambda:(m.lambda*1000).toFixed(1)+" mm",
      v16B_gamma:m.gamma.toFixed(3),
      v16B_mismatch:m.mismatchLoss.toFixed(2)+" dB",
      v16B_accepted:fmtDbm(m.acceptedPower),
      v16B_return:fmtDbm(m.returnPower),
      v16B_hpbw:m.hpbw.toFixed(1)+"°",
      v16B_nf:m.nearField.toFixed(1)+" m",
      v16B_horizon:m.horizon.toFixed(1)+" km",
      v16Seq:v16.sequence,
      v16Step:String(v16.step),
      v16Overall:m.overall
    };
    Object.entries(map).forEach(([id,val])=>{if(el(id)) el(id).textContent=val});

    const rows = [
      ["VSWR","≤ 1.50",p.vswr.toFixed(2),m.qVswr],
      ["Return Loss","≥ 16 dB",p.rl.toFixed(1)+" dB",m.qRl],
      ["Isolation","≥ 28 dB",p.iso.toFixed(1)+" dB",m.qIso],
      ["Port Balance","≤ 1.0 dB",p.bal.toFixed(1)+" dB",m.qBal],
      ["EIRP","≥ 25 dBm",m.eirp.toFixed(1)+" dBm",m.qEirp],
      ["Uncertainty","≤ ±1.0 dB","±"+m.uncertainty.toFixed(2)+" dB",m.uncertainty<=1?"PASS":m.uncertainty<=1.6?"WARN":"FAIL"]
    ];
    if(el("v16AcceptanceRows")){
      el("v16AcceptanceRows").innerHTML = rows.map(r=>`<tr class="${r[3].toLowerCase()}"><td>${r[0]}</td><td>${r[1]}</td><td>${r[2]}</td><td>${r[3]}</td></tr>`).join("");
    }

    document.querySelectorAll(".v16Metric").forEach(x=>x.classList.remove("pass","warn","fail"));
    if(el("v16Overall")){
      el("v16Overall").style.color = m.overall==="PASS" ? "#7dff4f" : m.overall==="WARN" ? "#ffd500" : "#ff3366";
    }

    v16.samples.unshift({ts:Date.now(), eirp:m.eirp, snr:m.snr, margin:m.rfMargin, q:m.overall});
    if(v16.samples.length>80) v16.samples.pop();
    drawTrace();
  }

  function drawTrace(){
    const c=el("v16Trace");
    if(!c) return;
    const x=c.getContext("2d"), w=c.width, h=c.height;
    x.clearRect(0,0,w,h);
    x.strokeStyle="rgba(120,190,240,.20)";
    for(let i=0;i<w;i+=32){x.beginPath();x.moveTo(i,0);x.lineTo(i,h);x.stroke()}
    const data=v16.samples.slice().reverse();
    if(data.length<2) return;
    [["snr","#7dff4f",70],["margin","#ffd500",20]].forEach(([key,col,scale])=>{
      x.beginPath();
      data.forEach((d,i)=>{
        const px=i/(80-1)*w;
        const py=h-4-Math.max(0,Math.min(1,d[key]/scale))*(h-8);
        i?x.lineTo(px,py):x.moveTo(px,py);
      });
      x.strokeStyle=col;x.lineWidth=1.5;x.stroke();
    });
  }

  function snapshot(){
    const snap={ts:new Date().toISOString(), params:P(), calc:calc(), sequence:v16.sequence, step:v16.step};
    v16.sweep.unshift(snap);
    if(v16.sweep.length>100) v16.sweep.pop();
    localStorage.setItem(V16_KEY, JSON.stringify(v16));
  }

  function acceptanceSweep(){
    v16.sequence="ACCEPTANCE";
    v16.step=0;
    const steps = [
      ["RF input calibration",()=>{setParam("vswr",135);setParam("rl",18)}],
      ["Port isolation",()=>{setParam("iso",31);setParam("bal",6)}],
      ["Pattern reference",()=>{setParam("gain",18);setParam("az",0)}],
      ["RET reference",()=>{setParam("tilt",4)}],
      ["EIRP verification",()=>{setParam("ptx",24);}],
      ["Uncertainty budget",()=>{el("v16CalUnc").value=0.45;updateV16()}],
      ["Evidence snapshot",()=>{snapshot()}]
    ];
    steps.forEach(([name,fn],i)=>setTimeout(()=>{
      v16.step=i+1;
      fn();
      snapshot();
      log("acceptance step "+(i+1)+" · "+name);
      if(i===steps.length-1){v16.sequence="COMPLETE";log("acceptance sweep complete")}
      updateV16();
    },i*750));
  }

  function quickCheck(){
    snapshot();
    log("quick check · overall "+calc().overall);
  }

  function maskStress(){
    setParam("vswr",190);
    setParam("rl",12);
    setParam("iso",22);
    setParam("bal",18);
    log("mask stress applied");
    updateV16();
  }

  function portBalance(){
    setParam("bal", Math.min(50, Number(param("bal"))+8));
    log("port balance stress +0.8 dB");
    updateV16();
  }

  function uncertaintyRun(){
    el("v16CalUnc").value = Math.min(2.5, Number(el("v16CalUnc").value)+0.25);
    log("uncertainty budget recalculated");
    updateV16();
  }

  function connectorFault(){
    setParam("vswr",245);
    setParam("rl",8);
    log("connector fault injected");
    updateV16();
  }

  function restoreGold(){
    setParam("type","Massive MIMO 8T8R");
    setParam("service","n78");
    setParam("freq",3500);
    setParam("gain",18);
    setParam("az",0);
    setParam("tilt",4);
    setParam("vswr",128);
    setParam("rl",20);
    setParam("iso",34);
    setParam("bal",4);
    setParam("ptx",24);
    el("v16CableLoss").value=0.7;
    el("v16CalUnc").value=0.35;
    log("gold baseline restored");
    updateV16();
  }

  function scpiPreset(){
    const cmd = el("icScpi");
    if(cmd) cmd.value="ANT:MEAS:EIRP?";
    if(window.TRFMC_IC && window.TRFMC_IC.execScpi) window.TRFMC_IC.execScpi("ANT:MEAS:EIRP?");
    log("SCPI preset executed");
  }

  function buildReport(){
    return {
      title:"TRFMC Antenna V1.6 Metrology Premium Report",
      exportedAt:new Date().toISOString(),
      bench:v16.bench,
      procedure:v16.procedure,
      params:P(),
      measurements:calc(),
      acceptance:v16.acceptance,
      sweep:v16.sweep.slice(0,30),
      last:v16.last
    };
  }

  function exportJsonReport(){
    snapshot();
    const blob = new Blob([JSON.stringify(buildReport(),null,2)],{type:"application/json"});
    const a=document.createElement("a");
    a.href=URL.createObjectURL(blob);
    a.download="trfmc_antenna_v16_metrology_report_"+new Date().toISOString().replace(/[:.]/g,"-")+".json";
    a.click();
    URL.revokeObjectURL(a.href);
    log("JSON metrology report exported");
  }

  function exportHtmlReport(){
    snapshot();
    const r=buildReport(), m=r.measurements, p=r.params;
    const html = `<!doctype html><html><head><meta charset="utf-8"><title>${r.title}</title>
    <style>body{font-family:Segoe UI,Arial;background:#07111f;color:#eaf3ff;padding:24px}table{border-collapse:collapse;width:100%;margin:16px 0}td,th{border:1px solid #245b7d;padding:8px;text-align:left}th{background:#0a1b2e;color:#00d9ff}.pass{color:#7dff4f}.warn{color:#ffd500}.fail{color:#ff3366}</style></head>
    <body><h1>${r.title}</h1><p>Exported: ${r.exportedAt}</p><h2>Bench</h2><table><tr><th>Bench</th><td>${r.bench}</td></tr><tr><th>Procedure</th><td>${r.procedure}</td></tr></table>
    <h2>Configuration</h2><table>${Object.entries(p).map(([k,v])=>`<tr><th>${k}</th><td>${v}</td></tr>`).join("")}</table>
    <h2>Measurements</h2><table>
    <tr><th>EIRP</th><td>${m.eirp.toFixed(2)} dBm</td></tr><tr><th>FSPL</th><td>${m.fspl.toFixed(2)} dB</td></tr><tr><th>SNR Proxy</th><td>${m.snr.toFixed(2)} dB</td></tr><tr><th>Mismatch Loss</th><td>${m.mismatchLoss.toFixed(3)} dB</td></tr><tr><th>Uncertainty</th><td>±${m.uncertainty.toFixed(2)} dB</td></tr><tr><th>Overall</th><td class="${m.overall.toLowerCase()}">${m.overall}</td></tr>
    </table></body></html>`;
    const blob = new Blob([html],{type:"text/html"});
    const a=document.createElement("a");
    a.href=URL.createObjectURL(blob);
    a.download="trfmc_antenna_v16_metrology_report_"+new Date().toISOString().replace(/[:.]/g,"-")+".html";
    a.click();
    URL.revokeObjectURL(a.href);
    log("HTML metrology report exported");
  }

  function clearV16(){
    v16.samples=[];
    v16.sweep=[];
    v16.acceptance=[];
    localStorage.removeItem(V16_KEY);
    log("V1.6 metrology data cleared");
    updateV16();
  }

  function boot(){
    injectLeftControls();
    injectScope();
    injectRightDeck();
    const saved=localStorage.getItem(V16_KEY);
    if(saved){
      try{Object.assign(v16, JSON.parse(saved));}catch(e){}
    }
    updateV16();
    setInterval(updateV16, 900);
    log("metrology premium layer online");
  }

  window.TRFMC_V16 = {
    acceptanceSweep, quickCheck, maskStress, portBalance, uncertaintyRun, connectorFault, restoreGold,
    scpiPreset, exportJsonReport, exportHtmlReport, clearV16, updateV16
  };

  boot();
})();
</script>
'''

s = s.replace("</body>", js + "\n</body>")

p.write_text(s)
print("CREATED", p)
PY

python3 - <<'PY'
from pathlib import Path
files=[
"frontend/public/trfmc_master_console_v4.html",
"frontend/public/trfmc_antenna_system_explorer_v15_instrument_center.html",
"frontend/public/trfmc_antenna_system_explorer_v14_instrument_grade.html",
"frontend/public/trfmc_enterprise_prime_portal_v1.html",
"frontend/public/trfmc_instrument_os_alignment_v1.html",
"frontend/public/api/portal/index"
]
link='<a href="/trfmc_antenna_system_explorer_v16_metrology_premium.html">Antenna V1.6 Metrology Premium</a>'
for f in files:
    p=Path(f)
    if not p.exists():
        continue
    s=p.read_text(errors="ignore")
    if "trfmc_antenna_system_explorer_v16_metrology_premium.html" not in s:
        if "<nav" in s:
            i=s.find("<nav"); gt=s.find(">",i)
            s=s[:gt+1]+"\n"+link+s[gt+1:]
        elif "<ul>" in s:
            s=s.replace("<ul>","<ul>\n<li>"+link+"</li>",1)
        p.write_text(s)
        print("PATCHED",p)
PY

curl -I --max-time 5 http://127.0.0.1:5173/trfmc_antenna_system_explorer_v16_metrology_premium.html
