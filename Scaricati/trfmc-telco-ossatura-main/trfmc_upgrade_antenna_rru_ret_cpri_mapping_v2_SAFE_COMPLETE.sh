#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ANTENNA_RRU_RET_CPRI_V2_$TS"
LATEST="$BASE/runtime/quality/latest_antenna_rru_ret_cpri_v2"

PAGE="$PUBLIC/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html"
HUB="$PUBLIC/trfmc_expansion_hub_v1.html"
MANIFEST="$PUBLIC/trfmc_expansion_modules_v1.json"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC ANTENNA / RRU / RET / CPRI PORT MAPPING V2"
echo "SAFE COMPLETE · leaf module · no iframe · no CDN · V6R3 untouched"
echo "============================================================"

echo
echo "[1/8] Snapshot e hash protetti"
cp -av "$PAGE" "runtime/backups/trfmc_antenna_rru_ret_cpri_v2_before_$TS.html.bak" 2>/dev/null || true
cp -av "$HUB" "runtime/backups/trfmc_expansion_hub_before_antenna_v2_$TS.html.bak"
cp -av "$MANIFEST" "runtime/backups/trfmc_expansion_modules_before_antenna_v2_$TS.json.bak"
cp -av "$REG" "runtime/backups/trfmc_registry_before_antenna_v2_$TS.json.bak"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo pagina Antenna/RRU/RET/CPRI V2 completa"
cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Antenna / RRU / RET / CPRI Port Mapping V2</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<style>
.ant-grid{display:grid;grid-template-columns:370px 1fr 420px;gap:7px;min-height:calc(100vh - 76px);padding:7px;position:relative;z-index:1}
.ant-stage{display:grid;grid-template-rows:1fr 285px;gap:7px;min-height:0}
.ant-webgl-wrap{position:relative;min-height:430px;overflow:hidden;background:#010409}
#sectorCanvas{width:100%;height:100%;display:block;min-height:430px}
.ant-plots{display:grid;grid-template-columns:1fr 1fr;gap:7px}
.plotBox{border:1px solid rgba(0,229,255,.27);background:#010409;position:relative;overflow:hidden}
.plotBox h3{position:absolute;left:10px;top:8px;margin:0;color:#00e5ff;font-size:11px;letter-spacing:1px;z-index:2}
.plotBox canvas{width:100%;height:100%;display:block}
.control label{display:block;color:#8fb8c8;font-size:10px;text-transform:uppercase;margin:8px 0 4px}
.control input,.control select{width:100%;background:#03101a;color:#e9fbff;border:1px solid rgba(0,229,255,.35);border-radius:5px;padding:7px;font-size:12px}
.value{color:#75ff5b;font-weight:800}
.good{color:#75ff5b}.warn{color:#ffd84d}.bad{color:#ff3d7f}
.formulaLive{font-family:ui-monospace,Consolas,monospace;background:#010409;border:1px solid rgba(0,229,255,.22);border-radius:6px;color:#dffaff;padding:8px;font-size:11px;line-height:1.5}
.portBadge{display:inline-block;border:1px solid rgba(0,229,255,.28);background:rgba(0,229,255,.06);border-radius:4px;padding:2px 5px;margin:1px;font-size:9px;color:#00e5ff}
@media(max-width:1300px){.ant-grid{grid-template-columns:1fr}.ant-plots{grid-template-columns:1fr}.ant-webgl-wrap{min-height:500px}}
</style>
</head>
<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">Antenna / RRU / RET / CPRI Port Mapping V2</div>
    <div class="leaf-sub">Sector engineering · RF port map · MIMO layers · AISG/RET · CPRI/eCPRI fronthaul · VSWR/PIM</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>Sector</small><b id="kSector">--</b></div>
    <div class="leaf-kpi"><small>Ports</small><b id="kPorts">--</b></div>
    <div class="leaf-kpi"><small>EIRP</small><b id="kEirp">--</b></div>
    <div class="leaf-kpi"><small>Status</small><b id="kStatus">leaf</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="ant-grid">
  <aside class="leaf-panel">
    <h2>Parametri sito / antenna</h2>
    <div class="leaf-scroll">
      <div class="leaf-card control">
        <h3>Sector & RF Chain</h3>

        <label>Settore</label>
        <select id="sector">
          <option value="1">Sector 1</option>
          <option value="2">Sector 2</option>
          <option value="3">Sector 3</option>
        </select>

        <label>Banda principale</label>
        <select id="band">
          <option value="700">700 MHz</option>
          <option value="800">800 MHz</option>
          <option value="900">900 MHz</option>
          <option value="1800" selected>1800 MHz</option>
          <option value="2100">2100 MHz</option>
          <option value="2600">2600 MHz</option>
          <option value="3500">3500 MHz</option>
        </select>

        <label>Configurazione porte RF</label>
        <select id="ports">
          <option value="2">2T2R</option>
          <option value="4" selected>4T4R</option>
          <option value="8">8T8R</option>
          <option value="16">16T16R</option>
          <option value="32">32T32R massive MIMO</option>
        </select>

        <label>Azimuth [deg]</label>
        <input id="azimuth" type="range" min="0" max="359" step="1" value="40">
        <div class="leaf-note">azimuth = <span class="value" id="azVal"></span>°</div>

        <label>Mechanical tilt [deg]</label>
        <input id="mTilt" type="range" min="-2" max="12" step="0.5" value="2">
        <div class="leaf-note">mech tilt = <span class="value" id="mTiltVal"></span>°</div>

        <label>Electrical RET tilt [deg]</label>
        <input id="eTilt" type="range" min="0" max="14" step="0.5" value="4">
        <div class="leaf-note">RET = <span class="value" id="eTiltVal"></span>°</div>

        <label>TX power per port [dBm]</label>
        <input id="pwr" type="range" min="20" max="47" step="1" value="40">
        <div class="leaf-note">Pport = <span class="value" id="pwrVal"></span> dBm</div>

        <label>Antenna gain [dBi]</label>
        <input id="gain" type="range" min="8" max="26" step="0.5" value="18">
        <div class="leaf-note">Gain = <span class="value" id="gainVal"></span> dBi</div>
      </div>

      <div class="leaf-card">
        <h3>Formule operative</h3>
        <div class="formulaLive">
          EIRP = Ptx + Gant - feeder_loss<br>
          Tilt_total = mechanical + electrical_RET<br>
          ArrayFactor(θ)=Σ wn·e^(j n k d sinθ)<br>
          CPRI_rate ∝ ports · IQ_width · Fs
        </div>
      </div>
    </div>
  </aside>

  <main class="leaf-panel ant-stage">
    <section class="ant-webgl-wrap">
      <canvas id="sectorCanvas"></canvas>
      <div class="leaf-overlay">
        <div class="leaf-stage-head">
          <div class="leaf-stage-title">Sector Radiation / Port Mapping Layer</div>
          <div class="leaf-stage-sub">Settore, beam, porte RF, RET e fronthaul visualizzati come digital twin operativo.</div>
        </div>
        <div></div>
        <div class="leaf-stage-foot">
          <div>Tilt: <span class="leaf-ok" id="tiltVal">--</span></div>
          <div>CPRI: <span id="cpriVal">--</span></div>
          <div>VSWR: <span id="vswrVal">--</span></div>
          <div>PIM: <span id="pimVal">--</span></div>
          <div>Mode: leaf</div>
        </div>
      </div>
    </section>

    <section class="ant-plots">
      <div class="plotBox"><h3>AZIMUTH PATTERN</h3><canvas id="patternPlot"></canvas></div>
      <div class="plotBox"><h3>RF / CPRI PORT MAP</h3><canvas id="portPlot"></canvas></div>
    </section>
  </main>

  <aside class="leaf-panel">
    <h2>Mapping / Allarmi</h2>
    <div class="leaf-scroll">
      <div class="leaf-card">
        <h3>RF Port Allocation</h3>
        <div id="portBadges"></div>
      </div>

      <div class="leaf-card">
        <h3>Risultati live</h3>
        <table class="leaf-table">
          <tbody>
            <tr><th>Band</th><td id="tBand">--</td></tr>
            <tr><th>Ports</th><td id="tPorts">--</td></tr>
            <tr><th>Total tilt</th><td id="tTilt">--</td></tr>
            <tr><th>EIRP</th><td id="tEirp">--</td></tr>
            <tr><th>CPRI/eCPRI class</th><td id="tCpri">--</td></tr>
            <tr><th>VSWR simulated</th><td id="tVswr">--</td></tr>
            <tr><th>PIM risk</th><td id="tPim">--</td></tr>
          </tbody>
        </table>
      </div>

      <div class="leaf-card">
        <h3>Allarmi tecnici</h3>
        <ul id="alarms"></ul>
      </div>

      <div class="leaf-card">
        <h3>Da evolvere in V3</h3>
        <ul>
          <li>Import/export port map reale da vendor sheet.</li>
          <li>Modello RET/AISG con address chain.</li>
          <li>Beamforming matrix e array factor 3D.</li>
          <li>VSWR/PIM alarm simulator collegato a RF metrology.</li>
          <li>CPRI/eCPRI fronthaul capacity calculator.</li>
        </ul>
      </div>
    </div>
  </aside>
</div>

<script>
const $=id=>document.getElementById(id);

function val(id){return +$(id).value;}
function calc(){
  const sector=val("sector");
  const band=val("band");
  const ports=val("ports");
  const az=val("azimuth");
  const mt=val("mTilt");
  const et=val("eTilt");
  const pwr=val("pwr");
  const gain=val("gain");

  const feederLoss = band >= 2600 ? 2.2 : band >= 1800 ? 1.6 : 1.1;
  const eirp = pwr + gain - feederLoss;
  const totalTilt = mt + et;
  const cpriRate = ports * (band >= 3500 ? 2.45 : 1.23);
  const vswr = 1.08 + totalTilt/80 + ports/180;
  const pimRisk = (pwr > 43 ? 2 : 0) + (ports >= 16 ? 2 : 0) + (vswr > 1.25 ? 1 : 0);
  const pim = pimRisk >= 4 ? "HIGH" : pimRisk >= 2 ? "WATCH" : "LOW";

  $("kSector").textContent="S"+sector;
  $("kPorts").textContent=ports+"T"+ports+"R";
  $("kEirp").textContent=eirp.toFixed(1)+" dBm";

  $("azVal").textContent=az.toFixed(0);
  $("mTiltVal").textContent=mt.toFixed(1);
  $("eTiltVal").textContent=et.toFixed(1);
  $("pwrVal").textContent=pwr.toFixed(0);
  $("gainVal").textContent=gain.toFixed(1);

  $("tiltVal").textContent=totalTilt.toFixed(1)+"°";
  $("cpriVal").textContent=cpriRate.toFixed(1)+"G class";
  $("vswrVal").textContent=vswr.toFixed(2)+":1";
  $("pimVal").innerHTML="<span class='"+(pim==="HIGH"?"bad":pim==="WATCH"?"warn":"good")+"'>"+pim+"</span>";

  $("tBand").textContent=band+" MHz";
  $("tPorts").textContent=ports+" RF branches";
  $("tTilt").textContent=totalTilt.toFixed(1)+"°";
  $("tEirp").textContent=eirp.toFixed(2)+" dBm";
  $("tCpri").textContent=cpriRate.toFixed(2)+" nominal units";
  $("tVswr").textContent=vswr.toFixed(2)+":1";
  $("tPim").innerHTML="<span class='"+(pim==="HIGH"?"bad":pim==="WATCH"?"warn":"good")+"'>"+pim+"</span>";

  const portsHtml=[];
  for(let i=1;i<=ports;i++){
    const pol=(i%2)?"V/+45":"H/-45";
    portsHtml.push("<span class='portBadge'>RF"+i+" · "+band+" · "+pol+"</span>");
  }
  $("portBadges").innerHTML=portsHtml.join("");

  const alarms=[];
  if(totalTilt>12) alarms.push("Tilt totale elevato: verificare copertura e overshooting.");
  if(vswr>1.25) alarms.push("VSWR simulato in crescita: controllare jumper, connettori e porta antenna.");
  if(pim==="HIGH") alarms.push("Rischio PIM elevato: potenza alta e molte porte attive.");
  if(ports>=16) alarms.push("Configurazione massive/MIMO: verificare fronthaul e mappatura IQ.");
  if(alarms.length===0) alarms.push("Configurazione coerente nel modello semplificato.");
  $("alarms").innerHTML=alarms.map(a=>"<li>"+a+"</li>").join("");

  return {sector,band,ports,az,mt,et,pwr,gain,feederLoss,eirp,totalTilt,cpriRate,vswr,pim};
}

function fit(c){
  const dpr=window.devicePixelRatio||1;
  const w=c.clientWidth*dpr|0,h=c.clientHeight*dpr|0;
  if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
  return {ctx:c.getContext("2d"),w,h,dpr};
}

function drawSector(c,p,t){
  const {ctx,w,h,dpr}=fit(c);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,229,255,.10)";
  for(let x=0;x<w;x+=w/14){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=h/8){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

  const cx=w/2, cy=h*.58;
  const az=(p.az-90)*Math.PI/180;
  const beamWidth=(p.ports>=16?34:p.ports>=8?48:65)*Math.PI/180;
  const len=Math.min(w,h)*.42;

  for(let i=0;i<90;i++){
    const a=az-beamWidth/2+beamWidth*i/89;
    const gain=Math.cos((i/89-.5)*Math.PI);
    ctx.strokeStyle=`rgba(0,229,255,${0.04+0.22*gain})`;
    ctx.beginPath();
    ctx.moveTo(cx,cy);
    ctx.lineTo(cx+Math.cos(a)*len*(.65+.35*gain),cy+Math.sin(a)*len*(.65+.35*gain)-p.totalTilt*5*dpr);
    ctx.stroke();
  }

  ctx.fillStyle="#ffd84d";
  ctx.fillRect(cx-8*dpr,cy-55*dpr,16*dpr,110*dpr);
  ctx.fillStyle="#75ff5b";
  ctx.beginPath();ctx.arc(cx,cy,6*dpr,0,Math.PI*2);ctx.fill();

  ctx.fillStyle="#8fb8c8";ctx.font=(12*dpr)+"px monospace";
  ctx.fillText("Sector "+p.sector+" · azimuth "+p.az+"° · tilt "+p.totalTilt.toFixed(1)+"°",16*dpr,26*dpr);
  ctx.fillText("Band "+p.band+" MHz · "+p.ports+"T"+p.ports+"R · EIRP "+p.eirp.toFixed(1)+" dBm",16*dpr,44*dpr);
}

function drawPattern(c,p){
  const {ctx,w,h,dpr}=fit(c);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  const cx=w/2, cy=h/2, r=Math.min(w,h)*.38;
  ctx.strokeStyle="rgba(0,229,255,.14)";
  for(let i=1;i<=4;i++){ctx.beginPath();ctx.arc(cx,cy,r*i/4,0,Math.PI*2);ctx.stroke();}
  ctx.beginPath();ctx.moveTo(cx-r,cy);ctx.lineTo(cx+r,cy);ctx.moveTo(cx,cy-r);ctx.lineTo(cx,cy+r);ctx.stroke();

  const bw=p.ports>=16?.45:p.ports>=8?.62:.82;
  ctx.strokeStyle="#75ff5b";ctx.lineWidth=2*dpr;ctx.beginPath();
  for(let i=0;i<=360;i++){
    const th=i*Math.PI/180;
    const main=Math.pow(Math.max(0,Math.cos(th)),2/bw);
    const side=0.12*Math.abs(Math.sin(p.ports*th/2));
    const rr=r*Math.min(1,main+side);
    const x=cx+Math.cos(th)*rr, y=cy+Math.sin(th)*rr;
    if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
  }
  ctx.closePath();ctx.stroke();
}

function drawPorts(c,p){
  const {ctx,w,h,dpr}=fit(c);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,229,255,.14)";
  for(let x=0;x<w;x+=w/10){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  const cols=Math.ceil(Math.sqrt(p.ports));
  const rows=Math.ceil(p.ports/cols);
  const sx=w/(cols+1), sy=h/(rows+1);
  for(let i=0;i<p.ports;i++){
    const col=i%cols,row=Math.floor(i/cols);
    const x=sx*(col+1),y=sy*(row+1);
    ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
    ctx.beginPath();ctx.arc(x,y,12*dpr,0,Math.PI*2);ctx.fill();
    ctx.fillStyle="#e9fbff";ctx.font=(11*dpr)+"px monospace";
    ctx.fillText("RF"+(i+1),x-13*dpr,y+26*dpr);
  }
}

function tick(ms){
  const p=calc();
  drawSector($("sectorCanvas"),p,ms);
  drawPattern($("patternPlot"),p);
  drawPorts($("portPlot"),p);
  requestAnimationFrame(tick);
}

["sector","band","ports","azimuth","mTilt","eTilt","pwr","gain"].forEach(id=>$(id).addEventListener("input",calc));
requestAnimationFrame(tick);
</script>
</body>
</html>
HTML

echo
echo "[3/8] Aggiorno Expansion manifest: Antenna punta alla V2"
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
        mod["title"]="Antenna / RRU / RET / CPRI Port Mapping V2"
        mod["url"]="/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html"
        mod["version"]="v2"
        mod["description"]="Interactive sector, RF port, RET/AISG, CPRI/eCPRI, VSWR/PIM mapping engine."
        found=True

if not found:
    m["modules"].append({
        "id":"antenna_rru_ret",
        "area":"05_Antenna_System",
        "title":"Antenna / RRU / RET / CPRI Port Mapping V2",
        "url":"/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
        "class":"leaf_operational_candidate",
        "webgl":False,
        "core_api":False,
        "version":"v2",
        "description":"Interactive sector, RF port, RET/AISG, CPRI/eCPRI, VSWR/PIM mapping engine."
    })

m["last_antenna_rru_ret_cpri_v2_update"]=datetime.now(timezone.utc).isoformat()
p.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n")
PY

echo
echo "[4/8] Aggiorno Hub link Antenna V1 -> V2"
python3 - <<'PY'
from pathlib import Path
p=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_expansion_hub_v1.html")
s=p.read_text()
s=s.replace('/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html','/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html')
s=s.replace('Antenna / RRU / RET / CPRI Port Mapping Simulator</b>','Antenna / RRU / RET / CPRI Port Mapping V2</b>')
s=s.replace('Antenna / RRU / RET / CPRI Port Mapping</b>','Antenna / RRU / RET / CPRI Port Mapping V2</b>')
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

target=public/"trfmc_antenna_rru_ret_cpri_port_mapping_v2.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
  "url":"/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
  "size":target.stat().st_size,
  "webgl":False,
  "canvas":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Antenna RRU RET CPRI V2 interactive port mapping engine"
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
reg["last_antenna_rru_ret_cpri_v2_update"]={
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "page":"/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
    "policy":"leaf upgrade only; V6R3 and Control Room unchanged"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_antenna_rru_ret_cpri_v2_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[6/8] Quality gate"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_antenna_rru_ret_cpri_port_mapping_v2.html \
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

protected_ok=(
    sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER")
)
registry_changed=sha.get("REG_SHA_BEFORE")!=sha.get("REG_SHA_AFTER")

reg=json.loads((public/"trfmc_portal_registry_unified.json").read_text())

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "page":"http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
  "http_non_200":non200,
  "external_refs_real":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and protected_ok and registry_changed else "WARN",
  "policy":"Antenna RRU RET CPRI V2 is a leaf upgrade. V6R3 and official Control Room unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_ANTENNA_RRU_RET_CPRI_V2_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_antenna_rru_ret_cpri_v2 \
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
echo "http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html"
echo "============================================================"
