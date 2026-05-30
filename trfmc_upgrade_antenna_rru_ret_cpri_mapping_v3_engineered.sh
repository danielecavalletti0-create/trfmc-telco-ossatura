#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ANTENNA_RRU_RET_CPRI_V3_$TS"
LATEST="$BASE/runtime/quality/latest_antenna_rru_ret_cpri_v3"

PAGE="$PUBLIC/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html"
HUB="$PUBLIC/trfmc_expansion_hub_v1.html"
MANIFEST="$PUBLIC/trfmc_expansion_modules_v1.json"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC ANTENNA / RRU / RET / CPRI PORT MAPPING V3 ENGINEERED"
echo "Formule vive · RF/RAN engineering · canvas/WebGL-like cockpit"
echo "============================================================"

echo
echo "[1/8] Snapshot e hash protetti"
cp -av "$PAGE" "runtime/backups/trfmc_antenna_rru_ret_cpri_v3_before_$TS.html.bak" 2>/dev/null || true
cp -av "$HUB" "runtime/backups/trfmc_expansion_hub_before_antenna_v3_$TS.html.bak"
cp -av "$MANIFEST" "runtime/backups/trfmc_expansion_modules_before_antenna_v3_$TS.json.bak"
cp -av "$REG" "runtime/backups/trfmc_registry_before_antenna_v3_$TS.json.bak"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo pagina V3 ingegnerizzata"
cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Antenna / RRU / RET / CPRI Port Mapping V3 Engineering</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<style>
.eng-grid{display:grid;grid-template-columns:390px 1fr 450px;gap:7px;min-height:calc(100vh - 76px);padding:7px;position:relative;z-index:1}
.eng-stage{display:grid;grid-template-rows:1fr 305px;gap:7px;min-height:0}
.eng-viewport{position:relative;min-height:450px;overflow:hidden;background:#010409}
.eng-viewport canvas{width:100%;height:100%;display:block;min-height:450px}
.eng-plots{display:grid;grid-template-columns:1fr 1fr;gap:7px}
.plotBox{border:1px solid rgba(0,229,255,.27);background:#010409;position:relative;overflow:hidden}
.plotBox h3{position:absolute;left:10px;top:8px;margin:0;color:#00e5ff;font-size:11px;letter-spacing:1px;z-index:2}
.plotBox canvas{width:100%;height:100%;display:block}
.control label{display:block;color:#8fb8c8;font-size:10px;text-transform:uppercase;margin:8px 0 4px}
.control input,.control select{width:100%;background:#03101a;color:#e9fbff;border:1px solid rgba(0,229,255,.35);border-radius:5px;padding:7px;font-size:12px}
.value{color:#75ff5b;font-weight:800}
.good{color:#75ff5b}.warn{color:#ffd84d}.bad{color:#ff3d7f}
.formulaLive{font-family:ui-monospace,Consolas,monospace;background:#010409;border:1px solid rgba(0,229,255,.22);border-radius:6px;color:#dffaff;padding:8px;font-size:10.5px;line-height:1.48;overflow:auto}
.portBadge{display:inline-block;border:1px solid rgba(0,229,255,.28);background:rgba(0,229,255,.06);border-radius:4px;padding:2px 5px;margin:1px;font-size:9px;color:#00e5ff}
.matrix{display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-top:6px}
.cell{border:1px solid rgba(0,229,255,.22);background:rgba(0,229,255,.05);padding:5px;border-radius:5px;font-size:9px;color:#8fb8c8}
.cell b{display:block;color:#75ff5b;font-size:11px}
@media(max-width:1380px){.eng-grid{grid-template-columns:1fr}.eng-plots{grid-template-columns:1fr}.eng-viewport{min-height:520px}}
</style>
</head>

<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">Antenna / RRU / RET / CPRI Port Mapping V3</div>
    <div class="leaf-sub">Engineering cockpit · RF formulas · EIRP · VSWR/RL/ML · RET · MIMO · CPRI/eCPRI · PIM · coverage</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>EIRP Total</small><b id="kEirp">--</b></div>
    <div class="leaf-kpi"><small>Return Loss</small><b id="kRL">--</b></div>
    <div class="leaf-kpi"><small>RSRP est.</small><b id="kRSRP">--</b></div>
    <div class="leaf-kpi"><small>Status</small><b id="kStatus">V3</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="eng-grid">
  <aside class="leaf-panel">
    <h2>Parametri RF / RAN</h2>
    <div class="leaf-scroll">
      <div class="leaf-card control">
        <h3>Sector, Antenna, RRU</h3>

        <label>Settore</label>
        <select id="sector"><option value="1">Sector 1</option><option value="2">Sector 2</option><option value="3">Sector 3</option></select>

        <label>Banda principale</label>
        <select id="band">
          <option value="700">700 MHz</option><option value="800">800 MHz</option><option value="900">900 MHz</option>
          <option value="1800" selected>1800 MHz</option><option value="2100">2100 MHz</option>
          <option value="2600">2600 MHz</option><option value="3500">3500 MHz</option>
        </select>

        <label>Porte RF / MIMO</label>
        <select id="ports"><option value="2">2T2R</option><option value="4" selected>4T4R</option><option value="8">8T8R</option><option value="16">16T16R</option><option value="32">32T32R</option></select>

        <label>Azimuth [deg]</label>
        <input id="azimuth" type="range" min="0" max="359" step="1" value="40">
        <div class="leaf-note">azimuth = <span class="value" id="azVal"></span>°</div>

        <label>Mechanical tilt [deg]</label>
        <input id="mTilt" type="range" min="-2" max="12" step="0.5" value="2">
        <div class="leaf-note">mechanical = <span class="value" id="mTiltVal"></span>°</div>

        <label>Electrical RET tilt [deg]</label>
        <input id="eTilt" type="range" min="0" max="14" step="0.5" value="4">
        <div class="leaf-note">RET = <span class="value" id="eTiltVal"></span>°</div>

        <label>TX power per port [dBm]</label>
        <input id="pwr" type="range" min="20" max="47" step="1" value="40">
        <div class="leaf-note">Pport = <span class="value" id="pwrVal"></span> dBm</div>

        <label>Antenna gain [dBi]</label>
        <input id="gain" type="range" min="8" max="26" step="0.5" value="18">
        <div class="leaf-note">Gain = <span class="value" id="gainVal"></span> dBi</div>

        <label>Feeder / jumper length [m]</label>
        <input id="feederM" type="range" min="0" max="80" step="1" value="12">
        <div class="leaf-note">length = <span class="value" id="feederVal"></span> m</div>

        <label>VSWR</label>
        <input id="vswrIn" type="range" min="1.02" max="2.5" step="0.01" value="1.18">
        <div class="leaf-note">VSWR = <span class="value" id="vswrInputVal"></span>:1</div>

        <label>Cell radius estimate [km]</label>
        <input id="radius" type="range" min="0.1" max="20" step="0.1" value="3.5">
        <div class="leaf-note">R = <span class="value" id="radiusVal"></span> km</div>
      </div>

      <div class="leaf-card">
        <h3>Formula book live</h3>
        <div class="formulaLive">
          λ = c / f<br>
          Ptotal(dBm)=Pport+10log10(Nports)<br>
          EIRP = Ptotal + Gant - Lfeeder<br>
          Γ=(VSWR-1)/(VSWR+1)<br>
          RL=-20log10|Γ|<br>
          ML=-10log10(1-|Γ|²)<br>
          Pdelivered=(1-|Γ|²)·100<br>
          FSPL=32.44+20log10(fMHz)+20log10(dkm)<br>
          RSRP≈EIRP-FSPL+Grx-10log10(N_RE)<br>
          CPRI/eCPRI≈ports·IQbits·Fs·2·overhead<br>
          C≈B·log2(1+SNR)·rank
        </div>
      </div>
    </div>
  </aside>

  <main class="leaf-panel eng-stage">
    <section class="eng-viewport">
      <canvas id="sectorCanvas"></canvas>
      <div class="leaf-overlay">
        <div class="leaf-stage-head">
          <div class="leaf-stage-title">3D-like Sector / Beam / RF Port Digital Twin</div>
          <div class="leaf-stage-sub">Visualizzazione ingegneristica di settore, tilt, fascio, mapping porte e stato RF.</div>
        </div>
        <div></div>
        <div class="leaf-stage-foot">
          <div>λ: <span class="leaf-ok" id="lambdaVal">--</span></div>
          <div>Tilt total: <span id="tiltVal">--</span></div>
          <div>CPRI/eCPRI: <span id="cpriVal">--</span></div>
          <div>PIM: <span id="pimVal">--</span></div>
          <div>Mode: leaf V3</div>
        </div>
      </div>
    </section>

    <section class="eng-plots">
      <div class="plotBox"><h3>POLAR / ARRAY FACTOR</h3><canvas id="patternPlot"></canvas></div>
      <div class="plotBox"><h3>RF PORT / CPRI MAPPING</h3><canvas id="portPlot"></canvas></div>
    </section>
  </main>

  <aside class="leaf-panel">
    <h2>Risultati ingegneristici</h2>
    <div class="leaf-scroll">
      <div class="leaf-card">
        <h3>RF KPI</h3>
        <table class="leaf-table">
          <tbody>
            <tr><th>Band</th><td id="tBand">--</td></tr>
            <tr><th>Ports</th><td id="tPorts">--</td></tr>
            <tr><th>Total TX power</th><td id="tPtot">--</td></tr>
            <tr><th>Feeder loss</th><td id="tFeeder">--</td></tr>
            <tr><th>EIRP</th><td id="tEirp">--</td></tr>
            <tr><th>Γ</th><td id="tGamma">--</td></tr>
            <tr><th>Return Loss</th><td id="tRL">--</td></tr>
            <tr><th>Mismatch Loss</th><td id="tML">--</td></tr>
            <tr><th>Delivered Power</th><td id="tDelivered">--</td></tr>
            <tr><th>RSRP estimate</th><td id="tRSRP">--</td></tr>
            <tr><th>Capacity estimate</th><td id="tCapacity">--</td></tr>
          </tbody>
        </table>
      </div>

      <div class="leaf-card">
        <h3>Port allocation</h3>
        <div id="portBadges"></div>
        <div class="matrix" id="matrix"></div>
      </div>

      <div class="leaf-card">
        <h3>PIM / Intermodulation</h3>
        <div class="formulaLive" id="pimBox">--</div>
      </div>

      <div class="leaf-card">
        <h3>Allarmi tecnici</h3>
        <ul id="alarms"></ul>
      </div>
    </div>
  </aside>
</div>

<script>
const $=id=>document.getElementById(id);
const C=299792458;

function log10(x){return Math.log(x)/Math.LN10}
function val(id){return +$(id).value}

function calc(){
  const sector=val("sector");
  const band=val("band");
  const ports=val("ports");
  const az=val("azimuth");
  const mt=val("mTilt");
  const et=val("eTilt");
  const pwr=val("pwr");
  const gain=val("gain");
  const feederM=val("feederM");
  const vswr=val("vswrIn");
  const radius=val("radius");

  const lambda=C/(band*1e6);
  const feederLossPer100 = band>=3500 ? 7.5 : band>=2600 ? 5.5 : band>=1800 ? 4.1 : 2.5;
  const feederLoss=feederLossPer100*(feederM/100)+0.35;
  const pTotal=pwr+10*log10(ports);
  const eirp=pTotal+gain-feederLoss;
  const totalTilt=mt+et;

  const gamma=(vswr-1)/(vswr+1);
  const returnLoss=-20*log10(Math.max(gamma,1e-9));
  const mismatchLoss=-10*log10(Math.max(1e-9,1-gamma*gamma));
  const delivered=(1-gamma*gamma)*100;

  const fspl=32.44+20*log10(band)+20*log10(radius);
  const rxGain=0;
  const nRE=1200;
  const rsrp=eirp-fspl+rxGain-10*log10(nRE);

  const iqBits=15;
  const sampleRate = band>=3500 ? 122.88e6 : 30.72e6;
  const overhead=1.25;
  const cpriGbps=ports*iqBits*sampleRate*2*overhead/1e9;

  const rank=Math.min(ports,4);
  const snr=Math.max(0.1, Math.pow(10, (rsrp+95)/10));
  const bwMHz=band>=3500 ? 100 : band>=2600 ? 40 : 20;
  const capacity=bwMHz*1e6*Math.log2(1+snr)*rank/1e6;

  const pimF1=band;
  const pimF2=band+20;
  const pim1=2*pimF1-pimF2;
  const pim2=2*pimF2-pimF1;
  const pimScore=(pwr>43?2:0)+(ports>=16?2:0)+(vswr>1.35?2:0)+(delivered<95?1:0);
  const pimRisk=pimScore>=4?"HIGH":pimScore>=2?"WATCH":"LOW";

  $("kEirp").textContent=eirp.toFixed(1)+" dBm";
  $("kRL").textContent=returnLoss.toFixed(1)+" dB";
  $("kRSRP").textContent=rsrp.toFixed(1)+" dBm";

  $("azVal").textContent=az.toFixed(0);
  $("mTiltVal").textContent=mt.toFixed(1);
  $("eTiltVal").textContent=et.toFixed(1);
  $("pwrVal").textContent=pwr.toFixed(0);
  $("gainVal").textContent=gain.toFixed(1);
  $("feederVal").textContent=feederM.toFixed(0);
  $("vswrInputVal").textContent=vswr.toFixed(2);
  $("radiusVal").textContent=radius.toFixed(1);

  $("lambdaVal").textContent=lambda.toFixed(3)+" m";
  $("tiltVal").textContent=totalTilt.toFixed(1)+"°";
  $("cpriVal").textContent=cpriGbps.toFixed(2)+" Gb/s est.";
  $("pimVal").innerHTML="<span class='"+(pimRisk==="HIGH"?"bad":pimRisk==="WATCH"?"warn":"good")+"'>"+pimRisk+"</span>";

  $("tBand").textContent=band+" MHz";
  $("tPorts").textContent=ports+" branches";
  $("tPtot").textContent=pTotal.toFixed(2)+" dBm";
  $("tFeeder").textContent=feederLoss.toFixed(2)+" dB";
  $("tEirp").textContent=eirp.toFixed(2)+" dBm";
  $("tGamma").textContent=gamma.toFixed(4);
  $("tRL").textContent=returnLoss.toFixed(2)+" dB";
  $("tML").textContent=mismatchLoss.toFixed(3)+" dB";
  $("tDelivered").textContent=delivered.toFixed(2)+" %";
  $("tRSRP").textContent=rsrp.toFixed(2)+" dBm";
  $("tCapacity").textContent=capacity.toFixed(1)+" Mb/s theoretical";

  const portsHtml=[];
  for(let i=1;i<=ports;i++){
    const pol=(i%2)?"V/+45":"H/-45";
    const cpri=Math.ceil(i/4);
    portsHtml.push("<span class='portBadge'>RF"+i+" · "+band+" MHz · "+pol+" · fronthaul "+cpri+"</span>");
  }
  $("portBadges").innerHTML=portsHtml.join("");

  const matrix=[];
  for(let i=1;i<=Math.min(ports,16);i++){
    matrix.push("<div class='cell'><b>RF"+i+"</b>Pol "+(i%2?"+45":"-45")+"<br>Layer "+(((i-1)%rank)+1)+"</div>");
  }
  $("matrix").innerHTML=matrix.join("");

  $("pimBox").innerHTML=
    "f1 = "+pimF1.toFixed(1)+" MHz<br>"+
    "f2 = "+pimF2.toFixed(1)+" MHz<br>"+
    "IM3 low = 2f1-f2 = "+pim1.toFixed(1)+" MHz<br>"+
    "IM3 high = 2f2-f1 = "+pim2.toFixed(1)+" MHz<br>"+
    "PIM risk = <span class='"+(pimRisk==="HIGH"?"bad":pimRisk==="WATCH"?"warn":"good")+"'>"+pimRisk+"</span>";

  const alarms=[];
  if(returnLoss<14) alarms.push("Return Loss basso: verificare adattamento, connettori, feeder e antenna.");
  if(delivered<96) alarms.push("Potenza consegnata ridotta per mismatch RF.");
  if(totalTilt>12) alarms.push("Tilt totale elevato: rischio buchi di copertura o oversuppression.");
  if(pimRisk==="HIGH") alarms.push("PIM risk alto: potenza/porte/VSWR richiedono verifica passiva.");
  if(cpriGbps>25) alarms.push("Fronthaul stimato elevato: verificare eCPRI/compressione/split funzionale.");
  if(rsrp<-115) alarms.push("RSRP stimato debole al bordo cella indicato.");
  if(alarms.length===0) alarms.push("Configurazione coerente nel modello ingegneristico semplificato.");
  $("alarms").innerHTML=alarms.map(a=>"<li>"+a+"</li>").join("");

  return {sector,band,ports,az,mt,et,pwr,gain,feederM,feederLoss,pTotal,eirp,totalTilt,vswr,gamma,returnLoss,mismatchLoss,delivered,radius,fspl,rsrp,cpriGbps,rank,capacity,pimRisk,pimScore};
}

function fit(c){
  const dpr=window.devicePixelRatio||1;
  const w=c.clientWidth*dpr|0,h=c.clientHeight*dpr|0;
  if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
  return {ctx:c.getContext("2d"),w,h,dpr};
}

function drawSector(c,p,ms){
  const {ctx,w,h,dpr}=fit(c);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);

  ctx.strokeStyle="rgba(0,229,255,.08)";
  for(let x=0;x<w;x+=w/16){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=h/10){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

  const cx=w/2, cy=h*.62;
  const az=(p.az-90)*Math.PI/180;
  const bw=(p.ports>=32?25:p.ports>=16?34:p.ports>=8?48:65)*Math.PI/180;
  const len=Math.min(w,h)*.46;
  const tiltFactor=Math.max(.55,1-p.totalTilt/26);

  for(let i=0;i<120;i++){
    const f=i/119;
    const a=az-bw/2+bw*f;
    const g=Math.cos((f-.5)*Math.PI);
    const shimmer=.85+.15*Math.sin(ms*.002+i*.17);
    ctx.strokeStyle=`rgba(0,229,255,${0.025+0.30*g})`;
    ctx.beginPath();
    ctx.moveTo(cx,cy);
    ctx.lineTo(cx+Math.cos(a)*len*g*shimmer, cy+Math.sin(a)*len*g*tiltFactor-p.totalTilt*5*dpr);
    ctx.stroke();
  }

  ctx.fillStyle="#ffd84d";
  ctx.fillRect(cx-9*dpr,cy-58*dpr,18*dpr,116*dpr);
  ctx.fillStyle="#75ff5b";
  ctx.beginPath();ctx.arc(cx,cy,7*dpr,0,Math.PI*2);ctx.fill();

  ctx.fillStyle="#8fb8c8";
  ctx.font=(12*dpr)+"px monospace";
  ctx.fillText("Sector "+p.sector+" · az "+p.az+"° · tilt "+p.totalTilt.toFixed(1)+"° · "+p.ports+"T"+p.ports+"R",16*dpr,28*dpr);
  ctx.fillText("EIRP "+p.eirp.toFixed(1)+" dBm · RL "+p.returnLoss.toFixed(1)+" dB · RSRP "+p.rsrp.toFixed(1)+" dBm",16*dpr,48*dpr);
}

function drawPattern(c,p){
  const {ctx,w,h,dpr}=fit(c);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  const cx=w/2,cy=h/2,r=Math.min(w,h)*.38;
  ctx.strokeStyle="rgba(0,229,255,.14)";
  for(let i=1;i<=4;i++){ctx.beginPath();ctx.arc(cx,cy,r*i/4,0,Math.PI*2);ctx.stroke();}
  ctx.beginPath();ctx.moveTo(cx-r,cy);ctx.lineTo(cx+r,cy);ctx.moveTo(cx,cy-r);ctx.lineTo(cx,cy+r);ctx.stroke();

  const elements=p.ports;
  ctx.strokeStyle="#75ff5b";
  ctx.lineWidth=2*dpr;
  ctx.beginPath();
  for(let i=0;i<=720;i++){
    const th=(i/2)*Math.PI/180;
    const psi=Math.PI*Math.sin(th);
    let af=0;
    for(let n=0;n<elements;n++) af+=Math.cos(n*psi);
    af=Math.abs(af/elements);
    const envelope=Math.pow(Math.max(0,Math.cos(th)), elements>=16?2.8:1.5);
    const rr=r*Math.min(1,af*.45+envelope);
    const x=cx+Math.cos(th)*rr,y=cy+Math.sin(th)*rr;
    if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
  }
  ctx.closePath();ctx.stroke();
}

function drawPorts(c,p){
  const {ctx,w,h,dpr}=fit(c);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,229,255,.12)";
  for(let x=0;x<w;x+=w/10){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  const cols=Math.ceil(Math.sqrt(p.ports));
  const rows=Math.ceil(p.ports/cols);
  const sx=w/(cols+1),sy=h/(rows+1);
  for(let i=0;i<p.ports;i++){
    const col=i%cols,row=Math.floor(i/cols);
    const x=sx*(col+1),y=sy*(row+1);
    ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
    ctx.beginPath();ctx.arc(x,y,12*dpr,0,Math.PI*2);ctx.fill();
    ctx.fillStyle="#e9fbff";ctx.font=(11*dpr)+"px monospace";
    ctx.fillText("RF"+(i+1),x-13*dpr,y+27*dpr);
  }
}

function tick(ms){
  const p=calc();
  drawSector($("sectorCanvas"),p,ms);
  drawPattern($("patternPlot"),p);
  drawPorts($("portPlot"),p);
  requestAnimationFrame(tick);
}

["sector","band","ports","azimuth","mTilt","eTilt","pwr","gain","feederM","vswrIn","radius"].forEach(id=>$(id).addEventListener("input",calc));
requestAnimationFrame(tick);
</script>
</body>
</html>
HTML

echo
echo "[3/8] Aggiorno Expansion manifest: Antenna punta alla V3"
python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

public=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public")
p=public/"trfmc_expansion_modules_v1.json"
m=json.loads(p.read_text())

found=False
for mod in m["modules"]:
    if mod["id"]=="antenna_rru_ret":
        mod["title"]="Antenna / RRU / RET / CPRI Port Mapping V3"
        mod["url"]="/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html"
        mod["version"]="v3"
        mod["description"]="Engineered RF/RAN sector cockpit with EIRP, VSWR, RL, mismatch loss, RSRP, MIMO, CPRI/eCPRI and PIM formulas."
        found=True

if not found:
    m["modules"].append({
        "id":"antenna_rru_ret",
        "area":"05_Antenna_System",
        "title":"Antenna / RRU / RET / CPRI Port Mapping V3",
        "url":"/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html",
        "class":"leaf_operational_candidate",
        "version":"v3",
        "description":"Engineered RF/RAN sector cockpit."
    })

m["last_antenna_rru_ret_cpri_v3_update"]=datetime.now(timezone.utc).isoformat()
p.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n")
PY

echo
echo "[4/8] Aggiorno Hub link Antenna -> V3"
python3 - <<'PY'
from pathlib import Path
p=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_expansion_hub_v1.html")
s=p.read_text()
s=s.replace('/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html','/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html')
s=s.replace('/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html','/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html')
s=s.replace('Antenna / RRU / RET / CPRI Port Mapping Simulator</b>','Antenna / RRU / RET / CPRI Port Mapping V3</b>')
s=s.replace('Antenna / RRU / RET / CPRI Port Mapping V2</b>','Antenna / RRU / RET / CPRI Port Mapping V3</b>')
s=s.replace('Antenna / RRU / RET / CPRI Port Mapping</b>','Antenna / RRU / RET / CPRI Port Mapping V3</b>')
p.write_text(s)
PY

echo
echo "[5/8] Aggiorno registry unico"
python3 - <<'PY'
import json, re
from pathlib import Path
from datetime import datetime, timezone

base=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
public=base/"frontend/public"
reg_path=public/"trfmc_portal_registry_unified.json"
reg=json.loads(reg_path.read_text())
pages=reg.get("pages",[])
by_url={p.get("url"):p for p in pages if p.get("url")}

target=public/"trfmc_antenna_rru_ret_cpri_port_mapping_v3.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_antenna_rru_ret_cpri_port_mapping_v3.html",
  "url":"/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html",
  "size":target.stat().st_size,
  "webgl":False,
  "canvas":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Antenna RRU RET CPRI V3 engineered RF/RAN formula cockpit"
}

reg["pages"]=list(by_url.values())
counts={}
for p in reg["pages"]:
    c=p.get("class","unknown")
    counts[c]=counts.get(c,0)+1
counts["total_html"]=len(reg["pages"])
for k in ["official_shell","service","leaf_operational_candidate","shell_or_legacy_container","orphan_or_legacy_candidate"]:
    counts.setdefault(k,0)
reg["counts"]=counts
reg["last_antenna_rru_ret_cpri_v3_update"]={
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "page":"/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html",
    "policy":"leaf upgrade only; V6R3 and Control Room unchanged"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_antenna_rru_ret_cpri_v3_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[6/8] Quality gate"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_antenna_rru_ret_cpri_port_mapping_v3.html \
    /trfmc_expansion_hub_v1.html \
    /trfmc_expansion_modules_v1.json \
    /trfmc_portal_registry_unified.json \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/fused_forbidden_refs.txt"

for f in "$PAGE" "$HUB" "$MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
  grep -nEi 'MASTER FUSED|trfmc_master_fused|fallback shell' "$f" >> "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true
done

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

echo
echo "[7/8] Summary"
python3 - "$BASE" "$OUT" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

base=Path(sys.argv[1])
out=Path(sys.argv[2])
public=base/"frontend/public"

http=[]
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=3:
        http.append({"url":p[0],"status":p[1],"bytes":p[2]})

non200=sum(1 for x in http if x["status"]!="200")
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fused=sum(1 for x in (out/"fused_forbidden_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.strip().split("=",1)
        sha[k]=v

protected_ok=(sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER") and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER"))
registry_changed=sha.get("REG_SHA_BEFORE")!=sha.get("REG_SHA_AFTER")
reg=json.loads((public/"trfmc_portal_registry_unified.json").read_text())

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "page":"http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html",
  "http_non_200":non200,
  "external_refs_real":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and protected_ok and registry_changed else "WARN",
  "policy":"Antenna RRU RET CPRI V3 is an engineered leaf upgrade. V6R3 and official Control Room unchanged."
}
(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[8/8] Freeze se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_ANTENNA_RRU_RET_CPRI_V3_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_antenna_rru_ret_cpri_v3 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html"
echo "============================================================"
