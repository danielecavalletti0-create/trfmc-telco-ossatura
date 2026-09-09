#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
SRC="$PUBLIC/trfmc_antenna_system_explorer_v14_instrument_grade.html"
DST="$PUBLIC/trfmc_antenna_system_explorer_v15_instrument_center.html"

if [ ! -f "$SRC" ]; then
  echo "ERRORE: manca $SRC"
  exit 1
fi

cp -f "$SRC" "$DST"

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/public/trfmc_antenna_system_explorer_v15_instrument_center.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "TRFMC Antenna System Explorer V1.4 Instrument Grade",
    "TRFMC Antenna System Explorer V1.5 Instrument Center"
)
s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.4 Instrument Grade</title>",
    "<title>TRFMC Antenna System Explorer V1.5 Instrument Center</title>"
)

css = r'''
/* === V1.5 INSTRUMENT CENTER / PREMIUM LAB LAYER === */
.icTopStrip{
  grid-column:1 / -1;
  display:grid;
  grid-template-columns:repeat(12,1fr);
  gap:5px;
  margin-bottom:6px;
  border:1px solid rgba(0,217,255,.48);
  background:linear-gradient(90deg,rgba(0,20,34,.95),rgba(5,31,52,.98),rgba(0,20,34,.95));
  border-radius:6px;
  padding:5px;
  box-shadow:0 0 24px rgba(0,217,255,.08), inset 0 1px 0 rgba(255,255,255,.05);
}
.icCell{
  border:1px solid rgba(36,91,125,.9);
  background:linear-gradient(180deg,#09223a,#06111f);
  border-radius:4px;
  padding:5px 6px;
  min-height:48px;
}
.icCell span{
  display:block;
  color:#87a8c6;
  font-size:8px;
  text-transform:uppercase;
  letter-spacing:.05em;
}
.icCell b{
  display:block;
  color:#eaf3ff;
  font-size:15px;
  line-height:1.15;
}
.icCell em{
  display:block;
  color:#7dff4f;
  font-style:normal;
  font-size:9px;
}
.icCell.warn em{color:#ffd500}
.icCell.bad em{color:#ff3366}
.icRightDeck{
  border:1px solid #183d58;
  background:#081522;
  border-radius:5px;
  margin-bottom:7px;
  overflow:hidden;
}
.icRightDeck h4{
  margin:0;
  padding:6px 8px;
  border-bottom:1px solid #183d58;
  color:#00d9ff;
  background:#0a1b2e;
  text-transform:uppercase;
  font-size:11px;
}
.icRightDeck .inner{padding:7px}
.icRows{
  font-family:ui-monospace,monospace;
  font-size:11px;
}
.icRow{
  display:grid;
  grid-template-columns:1fr auto;
  gap:8px;
  border-bottom:1px solid rgba(255,255,255,.06);
  padding:4px 0;
  color:#cde7ff;
}
.icRow strong{color:#ffd500;font-weight:600}
.icRow b{color:#7dff4f}
.icRow.bad b{color:#ff3366}
.icRow.warn b{color:#ffd500}
.icCommand{
  display:grid;
  grid-template-columns:1fr auto;
  gap:5px;
  margin-top:5px;
}
.icCommand input{
  margin:0;
  background:#02070f;
  border:1px solid #285d82;
  color:#eaf3ff;
  border-radius:4px;
  padding:6px;
  font-family:ui-monospace,monospace;
}
.icCommand button{
  width:auto;
  margin:0;
  padding:6px 10px;
}
.icMiniButtons{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:5px;
  margin-top:5px;
}
.icMiniButtons button{
  margin:0;
  text-align:center;
}
.icMatrix{
  position:absolute;
  right:8px;
  top:70px;
  z-index:6;
  width:310px;
  border:1px solid rgba(0,217,255,.42);
  background:rgba(3,10,18,.86);
  border-radius:6px;
  padding:7px;
  backdrop-filter:blur(10px);
}
.icMatrix h4{
  margin:0 0 6px;
  color:#00d9ff;
  font-size:11px;
  text-transform:uppercase;
}
.icMatrix table{
  width:100%;
  border-collapse:collapse;
  font-family:ui-monospace,monospace;
  font-size:10px;
}
.icMatrix th,.icMatrix td{
  border-bottom:1px solid rgba(255,255,255,.08);
  padding:3px 4px;
  text-align:left;
}
.icMatrix th{color:#87a8c6}
.icMatrix td:last-child{color:#7dff4f;text-align:right}
.icCenterDock{
  position:absolute;
  left:50%;
  transform:translateX(-50%);
  bottom:8px;
  z-index:7;
  display:flex;
  gap:5px;
  padding:5px;
  border:1px solid rgba(255,213,0,.45);
  background:rgba(3,10,18,.86);
  border-radius:6px;
  backdrop-filter:blur(10px);
}
.icCenterDock button{
  width:auto;
  margin:0;
  padding:5px 8px;
  text-align:center;
}
.icMeasureOverlay{
  position:absolute;
  left:8px;
  top:70px;
  z-index:6;
  width:330px;
  border:1px solid rgba(125,255,79,.40);
  background:rgba(3,10,18,.86);
  border-radius:6px;
  padding:7px;
  backdrop-filter:blur(10px);
}
.icMeasureOverlay h4{
  margin:0 0 6px;
  color:#7dff4f;
  text-transform:uppercase;
  font-size:11px;
}
.icMeasureGrid{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:5px;
}
.icMeasure{
  border:1px solid rgba(36,91,125,.9);
  background:#081522;
  border-radius:4px;
  padding:5px;
}
.icMeasure span{
  color:#87a8c6;
  font-size:8px;
  display:block;
}
.icMeasure b{
  color:#eaf3ff;
  font-size:14px;
  display:block;
}
.icStatusLine{
  position:absolute;
  left:8px;
  right:8px;
  bottom:44px;
  z-index:5;
  height:18px;
  border:1px solid rgba(36,91,125,.75);
  background:rgba(3,10,18,.78);
  border-radius:4px;
  display:flex;
  align-items:center;
  gap:12px;
  padding:0 8px;
  color:#87a8c6;
  font-family:ui-monospace,monospace;
  font-size:10px;
}
.icStatusLine b{color:#7dff4f}
'''

s = s.replace("</style>", css + "\n</style>")

js = r'''
<script>
/* === TRFMC ANTENNA V1.5 INSTRUMENT CENTER LAYER === */
(function(){
  const IC_KEY = "trfmc_antenna_v15_instrument_center";
  const STATION = {
    lab:"TRFMC-RF-LAB",
    bench:"ANT-MIMO-01",
    cal:"CAL-2026-05",
    profile:"PRE-COMPLIANCE / TELCO",
    operator:"sentinel",
    mode:"LOCAL-INSTRUMENT-SIM"
  };

  const ic = {
    running:false,
    sequenceStep:0,
    sequenceName:"IDLE",
    snapshots:[],
    markerTable:[],
    meas:{},
    scpiHistory:[],
    mask:"TELCO-SECTOR",
    quality:"PASS",
    last:"BOOT"
  };

  function el(id){return document.getElementById(id)}
  function qs(x){return document.querySelector(x)}
  function qsa(x){return Array.from(document.querySelectorAll(x))}
  function log(m){ if(typeof addLog==="function") addLog("IC · "+m); ic.last=m; updateIC(); }
  function param(id){ const x=el(id); if(!x) return null; return x.type==="checkbox"?x.checked:x.value; }
  function setParam(id,v){ const x=el(id); if(!x) return; if(x.type==="checkbox") x.checked=!!v; else x.value=v; x.dispatchEvent(new Event("input",{bubbles:true})); }

  function getP(){
    return {
      type:param("type"), service:param("service"),
      freq:+param("freq"), gain:+param("gain"), az:+param("az"), tilt:+param("tilt"),
      vswr:+param("vswr")/100, rl:+param("rl"), iso:+param("iso"),
      bal:+param("bal")/10, ptx:+param("ptx"), sectors:+param("sectors")
    };
  }

  function calc(){
    const p=getP();
    const lambda = 299792458/(p.freq*1e6);
    const gamma = (p.vswr-1)/(p.vswr+1);
    const mismatchLoss = -10*Math.log10(1-gamma*gamma);
    const eirp = p.ptx + p.gain - 0.5;
    const horizonKm = 3.57*(Math.sqrt(30)+Math.sqrt(1.5));
    const fspl1 = 32.44 + 20*Math.log10(p.freq) + 20*Math.log10(1);
    const nearField = 2*Math.pow(1.2,2)/lambda;
    const snrProxy = Math.max(5, 55 - (p.vswr-1)*12 - Math.max(0,20-p.rl)*1.5 - Math.max(0,25-p.iso)*1.2 + (p.gain-15)*0.8);
    const cap = (p.type||"").includes("32")?32:(p.type||"").includes("8")?8:(p.type||"").includes("4")?4:1;
    const capacityIndex = cap*Math.log2(1+Math.pow(10,snrProxy/10))/10;
    const pass = p.vswr < 1.8 && p.rl >= 14 && p.iso >= 24 && p.bal <= 1.8;
    const warn = !pass && p.vswr < 2.3 && p.rl >= 9 && p.iso >= 17;
    ic.quality = pass ? "PASS" : warn ? "WARN" : "FAIL";
    ic.meas = {
      lambda, gamma, mismatchLoss, eirp, horizonKm, fspl1, nearField,
      snrProxy, capacityIndex, cap,
      frontBack: Math.max(10, p.iso-4),
      beamWidth: Math.max(4, 70-p.gain*1.55),
      sideLobe: Math.max(-32, -12 - p.gain*.7),
      returnPower: p.ptx - p.rl,
      acceptedPower: p.ptx - mismatchLoss,
      efficiency: Math.max(45, 92 - mismatchLoss*8 - Math.max(0,p.vswr-1.5)*12)
    };
    return ic.meas;
  }

  function injectTopStrip(){
    if(el("icTopStrip")) return;
    const section = qs("main > section");
    if(!section) return;
    const strip = document.createElement("div");
    strip.id="icTopStrip";
    strip.className="icTopStrip";
    strip.innerHTML = `
      <div class="icCell"><span>Station</span><b>${STATION.bench}</b><em>${STATION.lab}</em></div>
      <div class="icCell"><span>Cal State</span><b id="icCal">VALID</b><em>${STATION.cal}</em></div>
      <div class="icCell"><span>GPSDO / Ref</span><b id="icRef">LOCKED</b><em>10 MHz REF</em></div>
      <div class="icCell"><span>Mask</span><b id="icMask">TELCO</b><em>sector limit</em></div>
      <div class="icCell"><span>λ</span><b id="icLambda">--</b><em>wavelength</em></div>
      <div class="icCell"><span>Γ</span><b id="icGamma">--</b><em>reflection</em></div>
      <div class="icCell"><span>Mismatch</span><b id="icMismatch">--</b><em>loss dB</em></div>
      <div class="icCell"><span>Accepted Pwr</span><b id="icAccepted">--</b><em>dBm</em></div>
      <div class="icCell"><span>Beam Width</span><b id="icBeam">--</b><em>HPBW est.</em></div>
      <div class="icCell"><span>Front/Back</span><b id="icFB">--</b><em>dB</em></div>
      <div class="icCell"><span>Capacity IDX</span><b id="icCap">--</b><em>MIMO proxy</em></div>
      <div class="icCell"><span>Gate</span><b id="icGate">PASS</b><em>quality</em></div>
    `;
    section.insertBefore(strip, section.firstChild);
  }

  function injectRightDeck(){
    const asideBody = document.querySelector("main > aside:last-child .body");
    if(!asideBody || el("icRightDeck")) return;

    const deck = document.createElement("div");
    deck.id="icRightDeck";
    deck.className="icRightDeck";
    deck.innerHTML = `
      <h4>Instrument Center</h4>
      <div class="inner">
        <div class="icRows">
          <div class="icRow"><strong>Profile</strong><b>${STATION.profile}</b></div>
          <div class="icRow"><strong>Bench</strong><b>${STATION.bench}</b></div>
          <div class="icRow"><strong>Sequence</strong><b id="icSeq">IDLE</b></div>
          <div class="icRow"><strong>Step</strong><b id="icStep">0</b></div>
          <div class="icRow"><strong>Quality</strong><b id="icQuality">PASS</b></div>
          <div class="icRow"><strong>Last</strong><b id="icLast">BOOT</b></div>
        </div>

        <div class="icCommand">
          <input id="icScpi" value="ANT:MEAS:VSWR?">
          <button onclick="TRFMC_IC.execScpi()">RUN</button>
        </div>

        <div class="icMiniButtons">
          <button onclick="TRFMC_IC.runSequence()">Run Sequence</button>
          <button onclick="TRFMC_IC.stopSequence()">Stop</button>
          <button onclick="TRFMC_IC.presetUrban()">Urban Macro</button>
          <button onclick="TRFMC_IC.presetRural()">Rural High Gain</button>
          <button onclick="TRFMC_IC.presetIndoor()">Indoor Wi-Fi 7</button>
          <button onclick="TRFMC_IC.presetFault()">Fault Case</button>
          <button onclick="TRFMC_IC.exportReport()">Export Report</button>
          <button onclick="TRFMC_IC.clearEvidence()">Clear Evidence</button>
        </div>
      </div>
    `;
    asideBody.insertBefore(deck, asideBody.firstChild);
  }

  function injectSiteOverlays(){
    const frame = el("site")?.closest(".frame");
    if(!frame) return;

    if(!el("icMeasureOverlay")){
      const m = document.createElement("div");
      m.id="icMeasureOverlay";
      m.className="icMeasureOverlay";
      m.innerHTML = `
        <h4>Live Measurement Readout</h4>
        <div class="icMeasureGrid">
          <div class="icMeasure"><span>FSPL @ 1 km</span><b id="icMfspl">--</b></div>
          <div class="icMeasure"><span>Radio Horizon</span><b id="icMhorizon">--</b></div>
          <div class="icMeasure"><span>Near Field</span><b id="icMnf">--</b></div>
          <div class="icMeasure"><span>SNR Proxy</span><b id="icMsnr">--</b></div>
          <div class="icMeasure"><span>Side Lobe</span><b id="icMside">--</b></div>
          <div class="icMeasure"><span>Efficiency</span><b id="icMeff">--</b></div>
        </div>
      `;
      frame.appendChild(m);
    }

    if(!el("icMatrix")){
      const mt = document.createElement("div");
      mt.id="icMatrix";
      mt.className="icMatrix";
      mt.innerHTML = `
        <h4>Marker / Port / Sector Matrix</h4>
        <table>
          <thead><tr><th>ID</th><th>Widget</th><th>Value</th><th>State</th></tr></thead>
          <tbody id="icMarkerTable"></tbody>
        </table>
      `;
      frame.appendChild(mt);
    }

    if(!el("icCenterDock")){
      const dock = document.createElement("div");
      dock.id="icCenterDock";
      dock.className="icCenterDock";
      dock.innerHTML = `
        <button onclick="TRFMC_IC.maskTelco()">Mask TELCO</button>
        <button onclick="TRFMC_IC.maskWifi()">Mask Wi-Fi</button>
        <button onclick="TRFMC_IC.markCurrent()">Mark</button>
        <button onclick="TRFMC_IC.refLock()">Ref Lock</button>
        <button onclick="TRFMC_IC.calCheck()">Cal Check</button>
        <button onclick="TRFMC_IC.evidence()">Evidence</button>
      `;
      frame.appendChild(dock);
    }

    if(!el("icStatusLine")){
      const sl = document.createElement("div");
      sl.id="icStatusLine";
      sl.className="icStatusLine";
      sl.innerHTML = `
        <span>SCPI <b id="icScpiState">READY</b></span>
        <span>CAL <b id="icCalState">VALID</b></span>
        <span>REF <b id="icRefState">LOCKED</b></span>
        <span>MASK <b id="icMaskState">TELCO-SECTOR</b></span>
        <span>SEQ <b id="icSeqState">IDLE</b></span>
        <span>QUALITY <b id="icQState">PASS</b></span>
      `;
      frame.appendChild(sl);
    }
  }

  function updateTop(){
    const m=calc();
    const p=getP();
    const mm = m.lambda*1000;
    if(el("icLambda")) el("icLambda").textContent = mm>=10 ? mm.toFixed(1)+" mm" : (m.lambda*100).toFixed(2)+" cm";
    if(el("icGamma")) el("icGamma").textContent = m.gamma.toFixed(3);
    if(el("icMismatch")) el("icMismatch").textContent = m.mismatchLoss.toFixed(2)+" dB";
    if(el("icAccepted")) el("icAccepted").textContent = m.acceptedPower.toFixed(1);
    if(el("icBeam")) el("icBeam").textContent = m.beamWidth.toFixed(1)+"°";
    if(el("icFB")) el("icFB").textContent = m.frontBack.toFixed(1)+" dB";
    if(el("icCap")) el("icCap").textContent = m.capacityIndex.toFixed(1);
    if(el("icGate")) el("icGate").textContent = ic.quality;
    if(el("icGate")) el("icGate").parentElement.className = "icCell " + (ic.quality==="FAIL"?"bad":ic.quality==="WARN"?"warn":"");
    if(el("icMfspl")) el("icMfspl").textContent = m.fspl1.toFixed(1)+" dB";
    if(el("icMhorizon")) el("icMhorizon").textContent = m.horizonKm.toFixed(1)+" km";
    if(el("icMnf")) el("icMnf").textContent = m.nearField.toFixed(1)+" m";
    if(el("icMsnr")) el("icMsnr").textContent = m.snrProxy.toFixed(1)+" dB";
    if(el("icMside")) el("icMside").textContent = m.sideLobe.toFixed(1)+" dBc";
    if(el("icMeff")) el("icMeff").textContent = m.efficiency.toFixed(1)+"%";

    if(el("icSeq")) el("icSeq").textContent = ic.sequenceName;
    if(el("icStep")) el("icStep").textContent = ic.sequenceStep;
    if(el("icQuality")) {
      el("icQuality").textContent = ic.quality;
      el("icQuality").parentElement.className = "icRow " + (ic.quality==="FAIL"?"bad":ic.quality==="WARN"?"warn":"");
    }
    if(el("icLast")) el("icLast").textContent = ic.last.slice(0,28);
    if(el("icMask")) el("icMask").textContent = ic.mask.replace("-SECTOR","");
    if(el("icMaskState")) el("icMaskState").textContent = ic.mask;
    if(el("icSeqState")) el("icSeqState").textContent = ic.sequenceName;
    if(el("icQState")) el("icQState").textContent = ic.quality;
  }

  function updateMarkerTable(){
    const tb = el("icMarkerTable");
    if(!tb) return;
    const rows = ic.markerTable.slice(0,8).map((r,i)=>`
      <tr><td>${i+1}</td><td>${r.widget}</td><td>${r.value}</td><td>${r.state}</td></tr>
    `).join("");
    tb.innerHTML = rows || `<tr><td>--</td><td>--</td><td>no markers</td><td>READY</td></tr>`;
  }

  function updateIC(){
    updateTop();
    updateMarkerTable();
  }

  function pushMarker(widget,value,state="OK"){
    ic.markerTable.unshift({ts:new Date().toISOString(), widget, value, state});
    if(ic.markerTable.length>30) ic.markerTable.pop();
    updateIC();
  }

  function execScpi(cmd){
    cmd = cmd || el("icScpi")?.value || "";
    const p=getP();
    let answer="OK";
    const c=cmd.trim().toUpperCase();

    if(c.includes("VSWR?")) answer = "VSWR "+p.vswr.toFixed(2);
    else if(c.includes("RL?") || c.includes("RETURN")) answer = "RETURN_LOSS "+p.rl.toFixed(1)+" DB";
    else if(c.includes("EIRP?")) answer = "EIRP "+ic.meas.eirp.toFixed(1)+" DBM";
    else if(c.includes("GAIN?")) answer = "GAIN "+p.gain.toFixed(1)+" DBI";
    else if(c.includes("TILT?")) answer = "TILT "+p.tilt.toFixed(1)+" DEG";
    else if(c.includes("AZ?")) answer = "AZIMUTH "+p.az.toFixed(1)+" DEG";
    else if(c.includes("MASK:WIFI")) { maskWifi(); answer="MASK WIFI7"; }
    else if(c.includes("MASK:TELCO")) { maskTelco(); answer="MASK TELCO"; }
    else if(c.includes("PRESET:URBAN")) { presetUrban(); answer="PRESET URBAN"; }
    else if(c.includes("PRESET:RURAL")) { presetRural(); answer="PRESET RURAL"; }
    else if(c.includes("CAL:CHECK")) { calCheck(); answer="CAL CHECK PASS"; }
    else if(c.includes("EVID")) { evidence(); answer="EVIDENCE MARKED"; }
    else answer = "EXECUTED "+cmd;

    ic.scpiHistory.unshift({ts:new Date().toISOString(),cmd,answer});
    if(ic.scpiHistory.length>50) ic.scpiHistory.pop();
    if(el("icScpiState")) el("icScpiState").textContent="LAST OK";
    log("SCPI → "+answer);
    return answer;
  }

  function runSequence(){
    if(ic.running) return;
    ic.running=true;
    ic.sequenceName="ANTENNA_ACCEPTANCE";
    ic.sequenceStep=0;
    const steps=[
      ()=>{ic.sequenceStep=1; setParam("vswr",135); pushMarker("RF","VSWR nominal","PASS"); log("sequence step 1 · VSWR measured")},
      ()=>{ic.sequenceStep=2; setParam("rl",18); pushMarker("RF","Return loss 18 dB","PASS"); log("sequence step 2 · return loss measured")},
      ()=>{ic.sequenceStep=3; setParam("iso",30); pushMarker("PORT","Isolation 30 dB","PASS"); log("sequence step 3 · cross-pol isolation measured")},
      ()=>{ic.sequenceStep=4; setParam("tilt",4); pushMarker("RET","Tilt +4°","PASS"); log("sequence step 4 · RET/AISG verified")},
      ()=>{ic.sequenceStep=5; setParam("gain",18); pushMarker("PATTERN","Gain 18 dBi","PASS"); log("sequence step 5 · pattern verified")},
      ()=>{ic.sequenceStep=6; ic.running=false; ic.sequenceName="COMPLETE"; snapshot(); log("sequence complete · acceptance snapshot stored")}
    ];
    steps.forEach((fn,i)=>setTimeout(fn, i*850));
  }

  function stopSequence(){
    ic.running=false;
    ic.sequenceName="STOPPED";
    log("sequence stopped by operator");
  }

  function snapshot(){
    const snap={ts:new Date().toISOString(), station:STATION, params:getP(), meas:calc(), quality:ic.quality, markers:ic.markerTable};
    ic.snapshots.unshift(snap);
    if(ic.snapshots.length>20) ic.snapshots.pop();
    localStorage.setItem(IC_KEY, JSON.stringify(ic));
    log("instrument-center snapshot stored");
  }

  function exportReport(){
    snapshot();
    const report = {
      title:"TRFMC Antenna Instrument Center Report",
      exportedAt:new Date().toISOString(),
      station:STATION,
      params:getP(),
      measurements:calc(),
      quality:ic.quality,
      sequence:{name:ic.sequenceName, step:ic.sequenceStep},
      markerTable:ic.markerTable,
      scpiHistory:ic.scpiHistory.slice(0,20),
      snapshots:ic.snapshots.slice(0,5)
    };
    const blob = new Blob([JSON.stringify(report,null,2)],{type:"application/json"});
    const a=document.createElement("a");
    a.href=URL.createObjectURL(blob);
    a.download="trfmc_antenna_v15_instrument_report_"+new Date().toISOString().replace(/[:.]/g,"-")+".json";
    a.click();
    URL.revokeObjectURL(a.href);
    log("instrument report exported");
  }

  function evidence(){
    pushMarker("EVIDENCE","operator bookmark","REC");
    snapshot();
    log("evidence bookmark added");
  }

  function clearEvidence(){
    ic.markerTable=[];
    ic.scpiHistory=[];
    ic.snapshots=[];
    localStorage.removeItem(IC_KEY);
    log("instrument evidence cleared");
    updateIC();
  }

  function maskTelco(){
    ic.mask="TELCO-SECTOR";
    setParam("sectors","3");
    setParam("showMain",true);
    setParam("showSide",true);
    pushMarker("MASK","TELCO-SECTOR","PASS");
    log("mask profile → TELCO-SECTOR");
  }

  function maskWifi(){
    ic.mask="WIFI7-INDOOR";
    setParam("service","wifi7");
    setParam("freq",5975);
    setParam("gain",12);
    setParam("sectors","1");
    pushMarker("MASK","WIFI7-INDOOR","PASS");
    log("mask profile → WIFI7-INDOOR");
  }

  function refLock(){
    if(el("icRef")) el("icRef").textContent="LOCKED";
    if(el("icRefState")) el("icRefState").textContent="LOCKED";
    pushMarker("REF","10 MHz locked","PASS");
    log("reference locked");
  }

  function calCheck(){
    if(el("icCal")) el("icCal").textContent="VALID";
    if(el("icCalState")) el("icCalState").textContent="VALID";
    pushMarker("CAL",STATION.cal,"PASS");
    log("calibration check valid");
  }

  function presetUrban(){
    setParam("type","Massive MIMO 8T8R"); setParam("service","n78"); setParam("freq",3500);
    setParam("gain",18); setParam("az",0); setParam("tilt",6); setParam("ptx",24);
    setParam("vswr",132); setParam("rl",18); setParam("iso",31); setParam("bal",6);
    pushMarker("PRESET","URBAN MACRO","PASS");
    log("preset loaded → urban macro");
  }

  function presetRural(){
    setParam("type","Triple-band panel"); setParam("service","b8"); setParam("freq",900);
    setParam("gain",22); setParam("az",0); setParam("tilt",2); setParam("ptx",30);
    setParam("vswr",128); setParam("rl",20); setParam("iso",34); setParam("bal",4);
    pushMarker("PRESET","RURAL HIGH GAIN","PASS");
    log("preset loaded → rural high gain");
  }

  function presetIndoor(){
    setParam("type","Patch array"); setParam("service","wifi7"); setParam("freq",5975);
    setParam("gain",11); setParam("az",0); setParam("tilt",0); setParam("ptx",17);
    setParam("vswr",140); setParam("rl",16); setParam("iso",24); setParam("bal",9);
    pushMarker("PRESET","INDOOR WIFI 7","PASS");
    log("preset loaded → indoor Wi-Fi 7");
  }

  function presetFault(){
    setParam("vswr",238); setParam("rl",8); setParam("iso",15); setParam("bal",32);
    pushMarker("FAULT","VSWR/RL/ISO degraded","FAIL");
    log("fault case loaded");
  }

  function markCurrent(){
    const p=getP();
    pushMarker("USER",`${p.freq} MHz / az ${p.az} / tilt ${p.tilt}`,"MARK");
    log("current condition marked");
  }

  function boot(){
    injectTopStrip();
    injectRightDeck();
    injectSiteOverlays();
    updateIC();

    const old=localStorage.getItem(IC_KEY);
    if(old){
      try{
        const o=JSON.parse(old);
        Object.assign(ic,o);
        log("previous instrument-center state recalled");
      }catch(e){}
    } else {
      log("instrument-center layer online");
    }

    setInterval(updateIC,500);
  }

  window.TRFMC_IC = {
    execScpi, runSequence, stopSequence, snapshot, exportReport, evidence, clearEvidence,
    maskTelco, maskWifi, refLock, calCheck, presetUrban, presetRural, presetIndoor, presetFault,
    markCurrent, updateIC
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
"frontend/public/trfmc_antenna_system_explorer_v14_instrument_grade.html",
"frontend/public/trfmc_antenna_system_explorer_v13_premium.html",
"frontend/public/trfmc_enterprise_prime_portal_v1.html",
"frontend/public/trfmc_instrument_os_alignment_v1.html",
"frontend/public/api/portal/index"
]
link='<a href="/trfmc_antenna_system_explorer_v15_instrument_center.html">Antenna V1.5 Instrument Center</a>'
for f in files:
    p=Path(f)
    if not p.exists():
        continue
    s=p.read_text(errors="ignore")
    if "trfmc_antenna_system_explorer_v15_instrument_center.html" not in s:
        if "<nav" in s:
            i=s.find("<nav"); gt=s.find(">",i)
            s=s[:gt+1]+"\n"+link+s[gt+1:]
        elif "<ul>" in s:
            s=s.replace("<ul>","<ul>\n<li>"+link+"</li>",1)
        p.write_text(s)
        print("PATCHED",p)
PY

curl -I --max-time 5 http://127.0.0.1:5173/trfmc_antenna_system_explorer_v15_instrument_center.html
