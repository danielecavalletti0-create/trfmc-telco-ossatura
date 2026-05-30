#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ANTENNA_RRU_RET_CPRI_V5_REALITY_ASSET_$TS"
LATEST="$BASE/runtime/quality/latest_antenna_rru_ret_cpri_v5"

PAGE="$PUBLIC/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"
HUB="$PUBLIC/trfmc_expansion_hub_v1.html"
MANIFEST="$PUBLIC/trfmc_expansion_modules_v1.json"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC ANTENNA / RRU / RET / CPRI V5 REALITY ASSET PAINTER"
echo "No ugly rectangles · pseudo-real asset · formulas · safe leaf upgrade"
echo "============================================================"

echo
echo "[1/8] Snapshot e hash protetti"
cp -av "$PAGE" "runtime/backups/trfmc_antenna_rru_ret_cpri_v5_before_$TS.html.bak" 2>/dev/null || true
cp -av "$HUB" "runtime/backups/trfmc_expansion_hub_before_antenna_v5_$TS.html.bak"
cp -av "$MANIFEST" "runtime/backups/trfmc_expansion_modules_before_antenna_v5_$TS.json.bak"
cp -av "$REG" "runtime/backups/trfmc_registry_before_antenna_v5_$TS.json.bak"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo pagina V5 Reality Asset Painter"
cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Antenna / RRU / RET / CPRI V5 Reality Asset Painter</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<style>
.v5-grid{display:grid;grid-template-columns:390px 1fr 455px;gap:7px;min-height:calc(100vh - 76px);padding:7px;position:relative;z-index:1}
.v5-stage{display:grid;grid-template-rows:1fr 318px;gap:7px;min-height:0}
.v5-viewport{position:relative;min-height:535px;overflow:hidden;background:#010409}
#realityCanvas{width:100%;height:100%;display:block;min-height:535px}
.v5-plots{display:grid;grid-template-columns:1fr 1fr;gap:7px}
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
@media(max-width:1380px){.v5-grid{grid-template-columns:1fr}.v5-plots{grid-template-columns:1fr}.v5-viewport{min-height:590px}}
</style>
</head>

<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">Antenna / RRU / RET / CPRI V5 Reality Asset Painter</div>
    <div class="leaf-sub">Pseudo-real RF site · mast · panel · RRU · heat sink · jumper · connectors · volumetric beam · live RF formulas</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>EIRP Total</small><b id="kEirp">--</b></div>
    <div class="leaf-kpi"><small>Return Loss</small><b id="kRL">--</b></div>
    <div class="leaf-kpi"><small>RSRP Edge</small><b id="kRSRP">--</b></div>
    <div class="leaf-kpi"><small>Reality</small><b>V5</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="v5-grid">
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

  <main class="leaf-panel v5-stage">
    <section class="v5-viewport">
      <canvas id="realityCanvas"></canvas>
      <div class="leaf-overlay">
        <div class="leaf-stage-head">
          <div class="leaf-stage-title">RF Site Reality Asset Painter</div>
          <div class="leaf-stage-sub">Non più rettangoli: asset canvas con pseudo-prospettiva, ombre, materiali, cavi curvi e beam volumetrico.</div>
        </div>
        <div></div>
        <div class="leaf-stage-foot">
          <div>λ: <span class="leaf-ok" id="lambdaVal">--</span></div>
          <div>Tilt: <span id="tiltVal">--</span></div>
          <div>CPRI/eCPRI: <span id="cpriVal">--</span></div>
          <div>PIM: <span id="pimVal">--</span></div>
          <div>Render: Canvas V5</div>
        </div>
      </div>
    </section>

    <section class="v5-plots">
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
        <h3>V6 necessario</h3>
        <div class="micro">
          Per arrivare al “quasi reale” vero: asset GLB/GLTF locali, materiali PBR, mesh antenna/RRU realistiche, normal map, luci, camera orbitale, import vendor sheet, port map reale, dati SNMP/NETCONF/O-RAN.
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
  if(alarms.length===0) alarms.push("Configurazione coerente nel modello V5 semplificato.");
  $("alarms").innerHTML=alarms.map(a=>"<li>"+a+"</li>").join("");

  return {scene,sector,band,ports,az,mt,et,pwr,gain,feederM,vswr,radius,lambda,feederLoss,pTotal,eirp,totalTilt,gamma,returnLoss,mismatchLoss,delivered,fspl,rsrp,rank,capacity,cpriGbps,pimRisk};
}

function fit(c){
  const dpr=window.devicePixelRatio||1, w=c.clientWidth*dpr|0, h=c.clientHeight*dpr|0;
  if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
  return {ctx:c.getContext("2d"),w,h,dpr};
}
function roundRect(ctx,x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}
function metalGrad(ctx,x1,y1,x2,y2){const g=ctx.createLinearGradient(x1,y1,x2,y2);g.addColorStop(0,"#4d5960");g.addColorStop(.18,"#dce8ed");g.addColorStop(.44,"#7c8b92");g.addColorStop(.68,"#f2fbff");g.addColorStop(1,"#56636a");return g}
function softShadow(ctx,x,y,w,h,alpha){ctx.save();ctx.globalAlpha=alpha;ctx.fillStyle="#000";ctx.beginPath();ctx.ellipse(x,y,w,h,0,0,Math.PI*2);ctx.fill();ctx.restore();}
function cable(ctx,x1,y1,x2,y2,c1x,c1y,c2x,c2y,color,w){ctx.strokeStyle=color;ctx.lineWidth=w;ctx.lineCap="round";ctx.beginPath();ctx.moveTo(x1,y1);ctx.bezierCurveTo(c1x,c1y,c2x,c2y,x2,y2);ctx.stroke();ctx.strokeStyle="rgba(255,255,255,.18)";ctx.lineWidth=Math.max(1,w*.22);ctx.beginPath();ctx.moveTo(x1,y1);ctx.bezierCurveTo(c1x,c1y,c2x,c2y,x2,y2);ctx.stroke();}

function antennaPanelPath(ctx,x,y,w,h,r){
  ctx.beginPath();
  ctx.moveTo(x+r,y);
  ctx.bezierCurveTo(x+w*.86,y-10,x+w+8,y+h*.16,x+w,y+r);
  ctx.lineTo(x+w,y+h-r);
  ctx.bezierCurveTo(x+w+7,y+h*.86,x+w*.82,y+h+9,x+w-r,y+h);
  ctx.lineTo(x+r,y+h);
  ctx.bezierCurveTo(x-8,y+h*.82,x-5,y+h*.18,x,y+r);
  ctx.bezierCurveTo(x+4,y+8,x+8,y+2,x+r,y);
  ctx.closePath();
}

function drawReality(c,p,ms){
  const {ctx,w,h,dpr}=fit(c);
  const time=ms*.001;
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);

  const sky=ctx.createLinearGradient(0,0,0,h);
  sky.addColorStop(0,"#071a2a"); sky.addColorStop(.52,"#04121f"); sky.addColorStop(1,"#010409");
  ctx.fillStyle=sky;ctx.fillRect(0,0,w,h);

  // distant site silhouettes
  ctx.save();
  ctx.globalAlpha=.22;
  ctx.fillStyle="#0c3040";
  ctx.beginPath();
  ctx.moveTo(0,h*.67);
  for(let i=0;i<9;i++){ctx.lineTo(w*i/8,h*(.60+.05*Math.sin(i*1.7))); }
  ctx.lineTo(w,h);ctx.lineTo(0,h);ctx.closePath();ctx.fill();
  ctx.restore();

  // perspective floor grid
  ctx.strokeStyle="rgba(0,229,255,.055)";
  for(let i=0;i<18;i++){
    const y=h*.64+i*h*.027;
    ctx.beginPath();ctx.moveTo(w*.08,y);ctx.lineTo(w*.92,y+i*i*.18*dpr);ctx.stroke();
  }
  for(let i=-12;i<=12;i++){
    ctx.beginPath();ctx.moveTo(w*.50,h*.62);ctx.lineTo(w*.50+i*w*.045,h*.98);ctx.stroke();
  }

  const cx=w*.42, base=h*.82;
  const mastTop=h*.18, mastBot=h*.92;
  softShadow(ctx,cx+95*dpr,base+38*dpr,230*dpr,46*dpr,.30);

  // mast: real cylinder
  const mastW=24*dpr;
  ctx.fillStyle=metalGrad(ctx,cx-mastW/2,0,cx+mastW/2,0);
  roundRect(ctx,cx-mastW/2,mastTop,mastW,mastBot-mastTop,12*dpr);ctx.fill();
  ctx.strokeStyle="rgba(255,255,255,.28)";ctx.lineWidth=1*dpr;ctx.stroke();

  // clamps
  const clampYs=[h*.42,h*.54,h*.66];
  clampYs.forEach((y,idx)=>{
    ctx.fillStyle=metalGrad(ctx,cx-44*dpr,y-8*dpr,cx+82*dpr,y+8*dpr);
    roundRect(ctx,cx-38*dpr,y-7*dpr,118*dpr,14*dpr,6*dpr);ctx.fill();ctx.strokeStyle="rgba(0,0,0,.45)";ctx.stroke();
    ctx.fillStyle="#1b252a";
    ctx.beginPath();ctx.arc(cx-23*dpr,y,4*dpr,0,Math.PI*2);ctx.fill();
    ctx.beginPath();ctx.arc(cx+58*dpr,y,4*dpr,0,Math.PI*2);ctx.fill();
  });

  // antenna panel pseudo-3D
  const panelX=cx+86*dpr, panelY=h*.27, panelW=100*dpr, panelH=300*dpr;
  ctx.save();
  ctx.translate(panelX+panelW/2,panelY+panelH/2);
  ctx.rotate((-p.totalTilt*.55)*Math.PI/180);
  ctx.translate(-(panelX+panelW/2),-(panelY+panelH/2));

  // side depth
  ctx.fillStyle="#5d6b70";
  antennaPanelPath(ctx,panelX+12*dpr,panelY+10*dpr,panelW,panelH,20*dpr);ctx.fill();

  const pg=ctx.createLinearGradient(panelX,panelY,panelX+panelW,panelY+panelH);
  pg.addColorStop(0,"#f5fbfc");pg.addColorStop(.28,"#bdc8cc");pg.addColorStop(.55,"#eef7f8");pg.addColorStop(1,"#8fa0a6");
  ctx.fillStyle=pg;
  antennaPanelPath(ctx,panelX,panelY,panelW,panelH,24*dpr);ctx.fill();
  ctx.strokeStyle="rgba(0,229,255,.35)";ctx.lineWidth=1*dpr;ctx.stroke();

  // radome vertical subtle grooves
  ctx.strokeStyle="rgba(40,70,80,.22)";
  for(let i=1;i<7;i++){
    const xx=panelX+i*panelW/7;
    ctx.beginPath();ctx.moveTo(xx,panelY+25*dpr);ctx.bezierCurveTo(xx+5*dpr,panelY+panelH*.35,xx-5*dpr,panelY+panelH*.67,xx,panelY+panelH-25*dpr);ctx.stroke();
  }

  // lower RF connector block
  const cbx=panelX+18*dpr, cby=panelY+panelH-30*dpr;
  ctx.fillStyle="#2e3b40";roundRect(ctx,cbx,cby,panelW-36*dpr,34*dpr,8*dpr);ctx.fill();
  for(let i=0;i<Math.min(8,p.ports);i++){
    const px=cbx+10*dpr+i*(panelW-56*dpr)/7;
    ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
    ctx.beginPath();ctx.arc(px,cby+18*dpr,4*dpr,0,Math.PI*2);ctx.fill();
  }
  ctx.restore();

  // RRU body: not rectangle, rounded cast metal with fins
  const rruX=cx-78*dpr, rruY=h*.50, rruW=132*dpr, rruH=145*dpr;
  const rg=ctx.createLinearGradient(rruX,rruY,rruX+rruW,rruY+rruH);
  rg.addColorStop(0,"#e7eef0");rg.addColorStop(.25,"#96a6ab");rg.addColorStop(.58,"#d8e2e5");rg.addColorStop(1,"#65737a");
  ctx.fillStyle=rg;
  roundRect(ctx,rruX,rruY,rruW,rruH,18*dpr);ctx.fill();
  ctx.strokeStyle="rgba(255,255,255,.28)";ctx.stroke();

  // heat sink fins with depth
  for(let i=0;i<12;i++){
    const fx=rruX+18*dpr+i*8*dpr;
    const fg=ctx.createLinearGradient(fx,rruY,fx+5*dpr,rruY);
    fg.addColorStop(0,"#55646a");fg.addColorStop(.5,"#f0f6f7");fg.addColorStop(1,"#46545a");
    ctx.fillStyle=fg;
    roundRect(ctx,fx,rruY+14*dpr,5*dpr,rruH-28*dpr,3*dpr);ctx.fill();
  }

  // RRU side label and LEDs
  ctx.fillStyle="rgba(0,0,0,.28)";roundRect(ctx,rruX+rruW-22*dpr,rruY+36*dpr,10*dpr,48*dpr,5*dpr);ctx.fill();
  for(let i=0;i<4;i++){ctx.fillStyle=i<3?"#75ff5b":"#ffd84d";ctx.beginPath();ctx.arc(rruX+rruW-17*dpr,rruY+44*dpr+i*10*dpr,2.5*dpr,0,Math.PI*2);ctx.fill();}

  // power/fiber/RF connectors on bottom
  const bottom=rruY+rruH+6*dpr;
  const conns=Math.min(8,p.ports);
  for(let i=0;i<conns;i++){
    const px=rruX+16*dpr+i*(rruW-34*dpr)/(conns-1 || 1);
    ctx.fillStyle="#1b252a";roundRect(ctx,px-5*dpr,bottom-5*dpr,10*dpr,14*dpr,3*dpr);ctx.fill();
    ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
    ctx.beginPath();ctx.arc(px,bottom+11*dpr,4*dpr,0,Math.PI*2);ctx.fill();
  }

  // curved RF jumpers
  for(let i=0;i<conns;i++){
    const sx=rruX+16*dpr+i*(rruW-34*dpr)/(conns-1 || 1);
    const sy=bottom+12*dpr;
    const tx=panelX+20*dpr+i*(panelW-40*dpr)/(conns-1 || 1);
    const ty=panelY+panelH+5*dpr;
    const color=i%2?"rgba(0,229,255,.78)":"rgba(255,216,77,.85)";
    cable(ctx,sx,sy,tx,ty,sx+22*dpr,sy+78*dpr,tx-45*dpr,ty+42*dpr,color,5*dpr);
  }

  // DC/fiber cables down
  cable(ctx,rruX+20*dpr,bottom+20*dpr,rruX-20*dpr,h*.92,rruX+5*dpr,bottom+80*dpr,rruX-35*dpr,h*.78,"rgba(255,118,55,.85)",5*dpr);
  cable(ctx,rruX+45*dpr,bottom+20*dpr,rruX+20*dpr,h*.93,rruX+65*dpr,bottom+80*dpr,rruX+0*dpr,h*.80,"rgba(0,229,255,.72)",4*dpr);

  // bracket to antenna
  ctx.strokeStyle="rgba(180,200,205,.8)";ctx.lineWidth=7*dpr;
  ctx.beginPath();ctx.moveTo(cx+12*dpr,h*.54);ctx.lineTo(panelX+16*dpr,panelY+panelH*.42);ctx.stroke();
  ctx.strokeStyle="rgba(40,55,60,.9)";ctx.lineWidth=2*dpr;ctx.stroke();

  // volumetric realistic beam: soft plume not straight MATLAB lobe
  const originX=panelX+panelW+6*dpr, originY=panelY+panelH*.34;
  const az=(p.az-45)*Math.PI/180;
  const beamLen=Math.min(w,h)*(.52 + Math.min(.14,p.eirp/600));
  const bw=(p.ports>=32?24:p.ports>=16?32:p.ports>=8?44:58)*Math.PI/180;
  ctx.save();
  for(let layer=0;layer<9;layer++){
    const a0=az-bw/2-layer*.008, a1=az+bw/2+layer*.008;
    const len=beamLen*(.80+layer*.055);
    const grad=ctx.createRadialGradient(originX,originY,5*dpr,originX+Math.cos(az)*len*.65,originY+Math.sin(az)*len*.65, len);
    grad.addColorStop(0,`rgba(0,229,255,${.18-layer*.012})`);
    grad.addColorStop(.38,`rgba(30,156,255,${.10-layer*.008})`);
    grad.addColorStop(1,"rgba(0,229,255,0)");
    ctx.fillStyle=grad;
    ctx.beginPath();
    ctx.moveTo(originX,originY);
    ctx.arc(originX,originY,len,a0,a1);
    ctx.closePath();
    ctx.fill();
  }
  ctx.globalCompositeOperation="lighter";
  for(let i=0;i<55;i++){
    const f=i/54, a=az-bw/2+bw*f;
    const l=beamLen*(.68+.25*Math.sin(time*1.6+i*.29)*.08+.20*Math.cos((f-.5)*Math.PI));
    ctx.strokeStyle=`rgba(0,229,255,${.025+.17*Math.cos((f-.5)*Math.PI)})`;
    ctx.lineWidth=(.5+1.8*Math.cos((f-.5)*Math.PI))*dpr;
    ctx.beginPath();
    ctx.moveTo(originX,originY);
    ctx.bezierCurveTo(
      originX+Math.cos(a)*l*.32,originY+Math.sin(a)*l*.25-p.totalTilt*3*dpr,
      originX+Math.cos(a)*l*.68,originY+Math.sin(a)*l*.70-p.totalTilt*6*dpr,
      originX+Math.cos(a)*l,originY+Math.sin(a)*l-p.totalTilt*8*dpr
    );
    ctx.stroke();
  }
  ctx.restore();

  // annotation pins
  ctx.fillStyle="rgba(0,8,14,.78)";
  ctx.strokeStyle="rgba(0,229,255,.45)";
  roundRect(ctx,20*dpr,22*dpr,310*dpr,56*dpr,8*dpr);ctx.fill();ctx.stroke();
  ctx.fillStyle="#00e5ff";ctx.font=(13*dpr)+"px monospace";
  ctx.fillText("REALITY SITE ASSET · "+p.scene.toUpperCase()+" · SECTOR "+p.sector,34*dpr,46*dpr);
  ctx.fillStyle="#8fb8c8";ctx.font=(11*dpr)+"px monospace";
  ctx.fillText(p.band+" MHz · "+p.ports+"T"+p.ports+"R · EIRP "+p.eirp.toFixed(1)+" dBm · RL "+p.returnLoss.toFixed(1)+" dB",34*dpr,64*dpr);

  ctx.fillStyle="rgba(0,8,14,.72)";
  ctx.strokeStyle="rgba(117,255,91,.35)";
  roundRect(ctx,w-285*dpr,h-74*dpr,262*dpr,46*dpr,8*dpr);ctx.fill();ctx.stroke();
  ctx.fillStyle="#75ff5b";ctx.font=(11*dpr)+"px monospace";
  ctx.fillText("RRU / PANEL / JUMPER / CONNECTOR BLOCK",w-270*dpr,h-50*dpr);
  ctx.fillText("CANVAS V5 REALITY PAINTER · ACTIVE",w-270*dpr,h-34*dpr);
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
echo "[3/8] Aggiorno manifest: Antenna punta alla V5 Reality Asset"
python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

public=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public")
p=public/"trfmc_expansion_modules_v1.json"
m=json.loads(p.read_text())

for mod in m["modules"]:
    if mod["id"]=="antenna_rru_ret":
        mod["title"]="Antenna / RRU / RET / CPRI Port Mapping V5 Reality Asset"
        mod["url"]="/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"
        mod["version"]="v5-reality-asset"
        mod["description"]="Canvas-based pseudo-real RF/RAN asset painter with mast, antenna panel, RRU, heatsink, jumper cables, connector block, volumetric beam and live formulas."

m["last_antenna_rru_ret_cpri_v5_reality_asset_update"]=datetime.now(timezone.utc).isoformat()
p.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n")
PY

echo
echo "[4/8] Aggiorno Hub link Antenna -> V5 Reality Asset"
python3 - <<'PY'
from pathlib import Path
p=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_expansion_hub_v1.html")
s=p.read_text()
for old in [
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html",
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html",
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html"
]:
    s=s.replace(old,"/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html")
for old in [
  "Antenna / RRU / RET / CPRI Port Mapping Simulator</b>",
  "Antenna / RRU / RET / CPRI Port Mapping V2</b>",
  "Antenna / RRU / RET / CPRI Port Mapping V3</b>",
  "Antenna / RRU / RET / CPRI Port Mapping V4 Reality</b>",
  "Antenna / RRU / RET / CPRI Port Mapping</b>"
]:
    s=s.replace(old,"Antenna / RRU / RET / CPRI Port Mapping V5 Reality Asset</b>")
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

target=public/"trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html",
  "url":"/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html",
  "size":target.stat().st_size,
  "canvas":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Antenna RRU RET CPRI V5 Reality Asset Painter"
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
reg["last_antenna_rru_ret_cpri_v5_reality_asset_update"]={
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "page":"/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html",
    "policy":"leaf upgrade only; V6R3 and Control Room unchanged"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_antenna_rru_ret_cpri_v5_reality_asset_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[6/8] Quality gate"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html \
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
  "page":"http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html",
  "http_non_200":non200,
  "external_refs_real":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and protected_ok and registry_changed else "WARN",
  "policy":"Antenna RRU RET CPRI V5 Reality Asset is a visual-engineered leaf upgrade. V6R3 and official Control Room unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_ANTENNA_RRU_RET_CPRI_V5_REALITY_ASSET_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_antenna_rru_ret_cpri_v5 \
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
echo "http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"
echo "============================================================"
