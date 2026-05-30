#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ANTENNA_RRU_RET_CPRI_V4_REALITY_$TS"
LATEST="$BASE/runtime/quality/latest_antenna_rru_ret_cpri_v4"

PAGE="$PUBLIC/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html"
HUB="$PUBLIC/trfmc_expansion_hub_v1.html"
MANIFEST="$PUBLIC/trfmc_expansion_modules_v1.json"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC ANTENNA / RRU / RET / CPRI V4 REALITY ENGINEERING"
echo "Reality canvas · real-site visual · formulas · safe leaf upgrade"
echo "============================================================"

echo
echo "[1/8] Snapshot e hash protetti"
cp -av "$PAGE" "runtime/backups/trfmc_antenna_rru_ret_cpri_v4_before_$TS.html.bak" 2>/dev/null || true
cp -av "$HUB" "runtime/backups/trfmc_expansion_hub_before_antenna_v4_$TS.html.bak"
cp -av "$MANIFEST" "runtime/backups/trfmc_expansion_modules_before_antenna_v4_$TS.json.bak"
cp -av "$REG" "runtime/backups/trfmc_registry_before_antenna_v4_$TS.json.bak"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo pagina V4 Reality"
cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Antenna / RRU / RET / CPRI Port Mapping V4 Reality</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<style>
.reality-grid{display:grid;grid-template-columns:390px 1fr 455px;gap:7px;min-height:calc(100vh - 76px);padding:7px;position:relative;z-index:1}
.reality-stage{display:grid;grid-template-rows:1fr 318px;gap:7px;min-height:0}
.reality-viewport{position:relative;min-height:510px;overflow:hidden;background:#010409}
#realityCanvas{width:100%;height:100%;display:block;min-height:510px}
.reality-plots{display:grid;grid-template-columns:1fr 1fr;gap:7px}
.plotBox{border:1px solid rgba(0,229,255,.27);background:#010409;position:relative;overflow:hidden}
.plotBox h3{position:absolute;left:10px;top:8px;margin:0;color:#00e5ff;font-size:11px;letter-spacing:1px;z-index:2}
.plotBox canvas{width:100%;height:100%;display:block}
.control label{display:block;color:#8fb8c8;font-size:10px;text-transform:uppercase;margin:8px 0 4px}
.control input,.control select{width:100%;background:#03101a;color:#e9fbff;border:1px solid rgba(0,229,255,.35);border-radius:5px;padding:7px;font-size:12px}
.value{color:#75ff5b;font-weight:800}
.good{color:#75ff5b}.warn{color:#ffd84d}.bad{color:#ff3d7f}
.formulaLive{font-family:ui-monospace,Consolas,monospace;background:#010409;border:1px solid rgba(0,229,255,.22);border-radius:6px;color:#dffaff;padding:8px;font-size:10.4px;line-height:1.48;overflow:auto}
.portBadge{display:inline-block;border:1px solid rgba(0,229,255,.28);background:rgba(0,229,255,.06);border-radius:4px;padding:2px 5px;margin:1px;font-size:9px;color:#00e5ff}
.micro{font-size:10px;color:#8fb8c8;line-height:1.45}
@media(max-width:1380px){.reality-grid{grid-template-columns:1fr}.reality-plots{grid-template-columns:1fr}.reality-viewport{min-height:560px}}
</style>
</head>

<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">Antenna / RRU / RET / CPRI V4 Reality Engineering</div>
    <div class="leaf-sub">Real-site visual twin · mast · antenna · RRU · jumper · beam · RET · VSWR/RL/ML · EIRP · RSRP · PIM</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>EIRP Total</small><b id="kEirp">--</b></div>
    <div class="leaf-kpi"><small>Return Loss</small><b id="kRL">--</b></div>
    <div class="leaf-kpi"><small>RSRP Edge</small><b id="kRSRP">--</b></div>
    <div class="leaf-kpi"><small>Reality</small><b>V4</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="reality-grid">
  <aside class="leaf-panel">
    <h2>Reality controls</h2>
    <div class="leaf-scroll">
      <div class="leaf-card control">
        <h3>Site / RF / RAN parameters</h3>

        <label>Scenario visuale</label>
        <select id="scene">
          <option value="tower">Rooftop / Tower Sector</option>
          <option value="pole">Monopole / Small Cell</option>
          <option value="mountain">Remote hill / microwave site</option>
        </select>

        <label>Settore</label>
        <select id="sector"><option value="1">Sector 1</option><option value="2">Sector 2</option><option value="3">Sector 3</option></select>

        <label>Banda principale</label>
        <select id="band">
          <option value="700">700 MHz</option><option value="800">800 MHz</option><option value="900">900 MHz</option>
          <option value="1800">1800 MHz</option><option value="2100">2100 MHz</option>
          <option value="2600">2600 MHz</option><option value="3500" selected>3500 MHz</option>
        </select>

        <label>Porte RF / MIMO</label>
        <select id="ports"><option value="2">2T2R</option><option value="4">4T4R</option><option value="8">8T8R</option><option value="16">16T16R</option><option value="32" selected>32T32R</option></select>

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
        <input id="gain" type="range" min="8" max="27" step="0.5" value="18">
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
          C≈B·log2(1+SNR)·rank<br>
          IM3: 2f1-f2, 2f2-f1
        </div>
      </div>
    </div>
  </aside>

  <main class="leaf-panel reality-stage">
    <section class="reality-viewport">
      <canvas id="realityCanvas"></canvas>
      <div class="leaf-overlay">
        <div class="leaf-stage-head">
          <div class="leaf-stage-title">Real-site RF Visual Twin</div>
          <div class="leaf-stage-sub">Rendering pseudo-realistico locale: antenna panel, RRU, dissipatore, jumper, porte, ground, ombre, beam volumetrico.</div>
        </div>
        <div></div>
        <div class="leaf-stage-foot">
          <div>λ: <span class="leaf-ok" id="lambdaVal">--</span></div>
          <div>Tilt: <span id="tiltVal">--</span></div>
          <div>CPRI/eCPRI: <span id="cpriVal">--</span></div>
          <div>PIM: <span id="pimVal">--</span></div>
          <div>Render: Canvas Reality</div>
        </div>
      </div>
    </section>

    <section class="reality-plots">
      <div class="plotBox"><h3>3GPP-LIKE POLAR PATTERN</h3><canvas id="patternPlot"></canvas></div>
      <div class="plotBox"><h3>RF PORT BLOCK / CPRI MAP</h3><canvas id="portPlot"></canvas></div>
    </section>
  </main>

  <aside class="leaf-panel">
    <h2>Engineering evidence</h2>
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
      </div>

      <div class="leaf-card">
        <h3>PIM / Intermodulation</h3>
        <div class="formulaLive" id="pimBox">--</div>
      </div>

      <div class="leaf-card">
        <h3>Reality roadmap</h3>
        <div class="micro">
          V4 usa canvas realistico locale. V5 dovrà importare asset GLB/GLTF locali, materiali PBR, normal map, misure reali, altezze, coordinate sito, vendor port map e telemetria SNMP/NETCONF/O-RAN.
        </div>
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
  const scene=$("scene").value, sector=val("sector"), band=val("band"), ports=val("ports");
  const az=val("azimuth"), mt=val("mTilt"), et=val("eTilt"), pwr=val("pwr"), gain=val("gain"), feederM=val("feederM"), vswr=val("vswrIn"), radius=val("radius");
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
  const nRE=1200;
  const rsrp=eirp-fspl-10*log10(nRE);
  const rank=Math.min(ports,4);
  const snr=Math.max(0.1, Math.pow(10,(rsrp+95)/10));
  const bwMHz=band>=3500 ? 100 : band>=2600 ? 40 : 20;
  const capacity=bwMHz*1e6*Math.log2(1+snr)*rank/1e6;
  const sampleRate=band>=3500?122.88e6:30.72e6;
  const cpriGbps=ports*15*sampleRate*2*1.25/1e9;
  const pimF1=band, pimF2=band+20, pim1=2*pimF1-pimF2, pim2=2*pimF2-pimF1;
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
    const fr=Math.ceil(i/4);
    portsHtml.push("<span class='portBadge'>RF"+i+" · "+band+" MHz · "+pol+" · fronthaul "+fr+"</span>");
  }
  $("portBadges").innerHTML=portsHtml.join("");

  $("pimBox").innerHTML=
    "f1 = "+pimF1.toFixed(1)+" MHz<br>"+
    "f2 = "+pimF2.toFixed(1)+" MHz<br>"+
    "IM3 low = 2f1-f2 = "+pim1.toFixed(1)+" MHz<br>"+
    "IM3 high = 2f2-f1 = "+pim2.toFixed(1)+" MHz<br>"+
    "Risk = <span class='"+(pimRisk==="HIGH"?"bad":pimRisk==="WATCH"?"warn":"good")+"'>"+pimRisk+"</span>";

  const alarms=[];
  if(returnLoss<14) alarms.push("Return Loss basso: verificare adattamento, jumper, porta antenna e connettori.");
  if(delivered<96) alarms.push("Mismatch RF: potenza consegnata ridotta.");
  if(totalTilt>12) alarms.push("Tilt totale elevato: rischio cell breathing / coverage hole.");
  if(pimRisk==="HIGH") alarms.push("PIM risk alto: verificare serraggi, jumper, ossidazioni, connettori e multi-carrier.");
  if(cpriGbps>25) alarms.push("Fronthaul stimato elevato: considerare eCPRI/compressione/split funzionale.");
  if(rsrp<-115) alarms.push("RSRP al bordo cella debole.");
  if(alarms.length===0) alarms.push("Configurazione coerente nel modello V4 semplificato.");
  $("alarms").innerHTML=alarms.map(a=>"<li>"+a+"</li>").join("");

  return {scene,sector,band,ports,az,mt,et,pwr,gain,feederM,vswr,radius,lambda,feederLoss,pTotal,eirp,totalTilt,gamma,returnLoss,mismatchLoss,delivered,fspl,rsrp,rank,capacity,cpriGbps,pimRisk};
}

function fit(c){
  const dpr=window.devicePixelRatio||1, w=c.clientWidth*dpr|0, h=c.clientHeight*dpr|0;
  if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
  return {ctx:c.getContext("2d"),w,h,dpr};
}
function roundRect(ctx,x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}
function grad(ctx,x1,y1,x2,y2,a,b){const g=ctx.createLinearGradient(x1,y1,x2,y2);g.addColorStop(0,a);g.addColorStop(1,b);return g;}

function drawReality(c,p,ms){
  const {ctx,w,h,dpr}=fit(c);
  const time=ms*.001;
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);

  // atmospheric grid / sky
  const sky=ctx.createLinearGradient(0,0,0,h);
  sky.addColorStop(0,"#061827"); sky.addColorStop(.55,"#03101a"); sky.addColorStop(1,"#010409");
  ctx.fillStyle=sky;ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,229,255,.055)";
  for(let x=0;x<w;x+=w/18){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=h/12){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

  const baseX=w*.38, baseY=h*.78;
  const mastH=h*.58, mastW=18*dpr;

  // ground / shadow
  ctx.fillStyle="rgba(0,0,0,.28)";
  ctx.beginPath();ctx.ellipse(baseX+70*dpr,baseY+50*dpr,210*dpr,42*dpr,0,0,Math.PI*2);ctx.fill();

  // mast
  ctx.fillStyle=grad(ctx,baseX-mastW/2,0,baseX+mastW/2,0,"#6d7f88","#dce8ed");
  roundRect(ctx,baseX-mastW/2,baseY-mastH,mastW,mastH,7*dpr);ctx.fill();
  ctx.strokeStyle="rgba(255,255,255,.25)";ctx.stroke();

  // brackets
  ctx.strokeStyle="#8fb8c8";ctx.lineWidth=4*dpr;
  ctx.beginPath();ctx.moveTo(baseX,baseY-mastH*.58);ctx.lineTo(baseX+115*dpr,baseY-mastH*.62);ctx.stroke();
  ctx.beginPath();ctx.moveTo(baseX,baseY-mastH*.35);ctx.lineTo(baseX+100*dpr,baseY-mastH*.40);ctx.stroke();

  // antenna panel
  const antX=baseX+110*dpr, antY=baseY-mastH*.78, antW=78*dpr, antH=245*dpr;
  ctx.save();
  ctx.translate(antX,antY);
  ctx.rotate((-p.totalTilt*.7)*Math.PI/180);
  ctx.fillStyle=grad(ctx,-antW/2,-antH/2,antW/2,antH/2,"#eef7f8","#9aa9ad");
  roundRect(ctx,-antW/2,-antH/2,antW,antH,18*dpr);ctx.fill();
  ctx.strokeStyle="rgba(0,229,255,.35)";ctx.stroke();
  ctx.fillStyle="rgba(255,255,255,.22)";
  for(let i=0;i<7;i++){roundRect(ctx,-antW*.32,-antH*.36+i*antH*.12,antW*.64,5*dpr,2*dpr);ctx.fill();}
  ctx.restore();

  // RRU box with heat sink
  const rruX=baseX+55*dpr, rruY=baseY-mastH*.38, rruW=112*dpr, rruH=118*dpr;
  ctx.fillStyle=grad(ctx,rruX,rruY,rruX+rruW,rruY+rruH,"#dce5e7","#7f9095");
  roundRect(ctx,rruX,rruY,rruW,rruH,10*dpr);ctx.fill();
  ctx.strokeStyle="rgba(0,229,255,.25)";ctx.stroke();
  ctx.fillStyle="rgba(30,50,55,.35)";
  for(let i=0;i<9;i++){ctx.fillRect(rruX+14*dpr+i*10*dpr,rruY+12*dpr,5*dpr,rruH-24*dpr);}

  // ports and cables
  const portY=rruY+rruH+6*dpr;
  for(let i=0;i<Math.min(p.ports,8);i++){
    const px=rruX+12*dpr+i*12*dpr;
    ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
    ctx.beginPath();ctx.arc(px,portY,4*dpr,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle=i%2?"rgba(0,229,255,.75)":"rgba(255,216,77,.75)";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    ctx.moveTo(px,portY);
    ctx.bezierCurveTo(px+20*dpr,portY+40*dpr,antX-40*dpr+i*5*dpr,antY+95*dpr,antX-28*dpr+i*3*dpr,antY+115*dpr);
    ctx.stroke();
  }

  // volumetric beam
  const originX=antX+54*dpr, originY=antY-20*dpr;
  const az=(p.az-35)*Math.PI/180;
  const beamLen=Math.min(w,h)*(.48 + Math.min(0.2,p.eirp/400));
  const bw=(p.ports>=32?23:p.ports>=16?30:p.ports>=8?42:58)*Math.PI/180;
  for(let layer=0;layer<5;layer++){
    ctx.globalAlpha=.13-layer*.015;
    ctx.fillStyle=layer%2?"#00e5ff":"#1e9cff";
    ctx.beginPath();
    ctx.moveTo(originX,originY);
    ctx.arc(originX,originY,beamLen*(1+layer*.08),az-bw/2,az+bw/2);
    ctx.closePath();
    ctx.fill();
  }
  ctx.globalAlpha=1;
  for(let i=0;i<38;i++){
    const f=i/37, a=az-bw/2+bw*f, l=beamLen*(.82+.12*Math.sin(time*2+i));
    ctx.strokeStyle=`rgba(0,229,255,${.08+.25*Math.cos((f-.5)*Math.PI)})`;
    ctx.lineWidth=(1.1+2*Math.cos((f-.5)*Math.PI))*dpr;
    ctx.beginPath();ctx.moveTo(originX,originY);ctx.lineTo(originX+Math.cos(a)*l,originY+Math.sin(a)*l-p.totalTilt*4*dpr);ctx.stroke();
  }

  // labels
  ctx.fillStyle="#00e5ff";ctx.font=(12*dpr)+"px monospace";
  ctx.fillText("SECTOR "+p.sector+" · "+p.band+" MHz · "+p.ports+"T"+p.ports+"R",20*dpr,28*dpr);
  ctx.fillText("EIRP "+p.eirp.toFixed(1)+" dBm · RL "+p.returnLoss.toFixed(1)+" dB · RSRP "+p.rsrp.toFixed(1)+" dBm",20*dpr,48*dpr);
  ctx.fillStyle="#75ff5b";ctx.fillText("RRU/RU + ANTENNA PANEL + RF JUMPER + BEAM MODEL",20*dpr,h-24*dpr);
}

function drawPattern(c,p){
  const {ctx,w,h,dpr}=fit(c);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  const cx=w/2,cy=h/2,r=Math.min(w,h)*.38;
  ctx.strokeStyle="rgba(0,229,255,.14)";
  for(let i=1;i<=4;i++){ctx.beginPath();ctx.arc(cx,cy,r*i/4,0,Math.PI*2);ctx.stroke();}
  ctx.beginPath();ctx.moveTo(cx-r,cy);ctx.lineTo(cx+r,cy);ctx.moveTo(cx,cy-r);ctx.lineTo(cx,cy+r);ctx.stroke();

  const elements=p.ports;
  ctx.strokeStyle="#75ff5b";ctx.lineWidth=2*dpr;ctx.beginPath();
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
  const cols=Math.ceil(Math.sqrt(p.ports)), rows=Math.ceil(p.ports/cols);
  const sx=w/(cols+1),sy=h/(rows+1);
  for(let i=0;i<p.ports;i++){
    const col=i%cols,row=Math.floor(i/cols),x=sx*(col+1),y=sy*(row+1);
    ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
    ctx.beginPath();ctx.arc(x,y,11*dpr,0,Math.PI*2);ctx.fill();
    ctx.fillStyle="#e9fbff";ctx.font=(10*dpr)+"px monospace";
    ctx.fillText("RF"+(i+1),x-12*dpr,y+24*dpr);
  }
}

function tick(ms){
  const p=calc();
  drawReality($("realityCanvas"),p,ms);
  drawPattern($("patternPlot"),p);
  drawPorts($("portPlot"),p);
  requestAnimationFrame(tick);
}
["scene","sector","band","ports","azimuth","mTilt","eTilt","pwr","gain","feederM","vswrIn","radius"].forEach(id=>$(id).addEventListener("input",calc));
requestAnimationFrame(tick);
</script>
</body>
</html>
HTML

echo
echo "[3/8] Aggiorno manifest: Antenna punta alla V4 Reality"
python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

public=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public")
p=public/"trfmc_expansion_modules_v1.json"
m=json.loads(p.read_text())

for mod in m["modules"]:
    if mod["id"]=="antenna_rru_ret":
        mod["title"]="Antenna / RRU / RET / CPRI Port Mapping V4 Reality"
        mod["url"]="/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html"
        mod["version"]="v4-reality"
        mod["description"]="Reality-engineered RF/RAN visual twin with mast, panel antenna, RRU, jumper, beam, EIRP, VSWR, RL, RSRP, MIMO, CPRI/eCPRI and PIM formulas."

m["last_antenna_rru_ret_cpri_v4_reality_update"]=datetime.now(timezone.utc).isoformat()
p.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n")
PY

echo
echo "[4/8] Aggiorno Hub link Antenna -> V4 Reality"
python3 - <<'PY'
from pathlib import Path
p=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_expansion_hub_v1.html")
s=p.read_text()
for old in [
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html",
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html"
]:
    s=s.replace(old,"/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html")
for old in [
  "Antenna / RRU / RET / CPRI Port Mapping Simulator</b>",
  "Antenna / RRU / RET / CPRI Port Mapping V2</b>",
  "Antenna / RRU / RET / CPRI Port Mapping V3</b>",
  "Antenna / RRU / RET / CPRI Port Mapping</b>"
]:
    s=s.replace(old,"Antenna / RRU / RET / CPRI Port Mapping V4 Reality</b>")
p.write_text(s)
PY

echo
echo "[5/8] Aggiorno registry"
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

target=public/"trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html",
  "url":"/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html",
  "size":target.stat().st_size,
  "canvas":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Antenna RRU RET CPRI V4 Reality visual RF/RAN twin"
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
reg["last_antenna_rru_ret_cpri_v4_reality_update"]={
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "page":"/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html",
    "policy":"leaf upgrade only; V6R3 and Control Room unchanged"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_antenna_rru_ret_cpri_v4_reality_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[6/8] Quality gate"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html \
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
  "page":"http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html",
  "http_non_200":non200,
  "external_refs_real":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and protected_ok and registry_changed else "WARN",
  "policy":"Antenna RRU RET CPRI V4 Reality is a visual-engineered leaf upgrade. V6R3 and official Control Room unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_ANTENNA_RRU_RET_CPRI_V4_REALITY_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_antenna_rru_ret_cpri_v4 \
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
echo "http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html"
echo "============================================================"
