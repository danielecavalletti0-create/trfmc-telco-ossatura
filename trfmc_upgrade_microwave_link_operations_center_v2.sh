#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_MICROWAVE_LINK_V2_$TS"
LATEST="$BASE/runtime/quality/latest_microwave_link_v2"

PAGE="$PUBLIC/trfmc_microwave_link_operations_center_v2.html"
HUB="$PUBLIC/trfmc_expansion_hub_v1.html"
MANIFEST="$PUBLIC/trfmc_expansion_modules_v1.json"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC MICROWAVE LINK OPERATIONS CENTER V2"
echo "Link budget · Fresnel · rain fade · adaptive modulation"
echo "============================================================"

echo
echo "[1/8] Snapshot e hash protetti"
cp -av "$PAGE" "runtime/backups/trfmc_microwave_link_v2_before_$TS.html.bak" 2>/dev/null || true
cp -av "$HUB" "runtime/backups/trfmc_expansion_hub_before_mwlink_v2_$TS.html.bak"
cp -av "$MANIFEST" "runtime/backups/trfmc_expansion_modules_before_mwlink_v2_$TS.json.bak"
cp -av "$REG" "runtime/backups/trfmc_registry_before_mwlink_v2_$TS.json.bak"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo Microwave Link Operations Center V2"
cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Microwave Link Operations Center V2</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<style>
.mw-grid{display:grid;grid-template-columns:360px 1fr 400px;gap:7px;min-height:calc(100vh - 76px);padding:7px;position:relative;z-index:1}
.mw-stage{display:grid;grid-template-rows:1fr 270px;gap:7px;min-height:0}
.mw-webgl-wrap{position:relative;min-height:420px;overflow:hidden}
#mwField{width:100%;height:100%;display:block;min-height:420px}
.mw-plots{display:grid;grid-template-columns:1.1fr .9fr;gap:7px}
.plotBox{border:1px solid rgba(0,229,255,.27);background:#010409;position:relative;overflow:hidden}
.plotBox h3{position:absolute;left:10px;top:8px;margin:0;color:#00e5ff;font-size:11px;letter-spacing:1px;z-index:2}
.plotBox canvas{width:100%;height:100%;display:block}
.control label{display:block;color:#8fb8c8;font-size:10px;text-transform:uppercase;margin:8px 0 4px}
.control input,.control select{width:100%;background:#03101a;color:#e9fbff;border:1px solid rgba(0,229,255,.35);border-radius:5px;padding:7px;font-size:12px}
.value{color:#75ff5b;font-weight:800}
.formulaLive{font-family:ui-monospace,Consolas,monospace;background:#010409;border:1px solid rgba(0,229,255,.22);border-radius:6px;color:#dffaff;padding:8px;font-size:11px;line-height:1.5}
.modGood{color:#75ff5b}
.modWarn{color:#ffd84d}
.modBad{color:#ff3d7f}
@media(max-width:1300px){.mw-grid{grid-template-columns:1fr}.mw-plots{grid-template-columns:1fr}.mw-webgl-wrap{min-height:480px}}
</style>
</head>
<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">Microwave Link Operations Center V2</div>
    <div class="leaf-sub">FSPL · Fresnel · RSL · rain fade · adaptive modulation · availability engineering</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>RSL</small><b id="kRsl">--</b></div>
    <div class="leaf-kpi"><small>Fade Margin</small><b id="kMargin">--</b></div>
    <div class="leaf-kpi"><small>Modulation</small><b id="kMod">--</b></div>
    <div class="leaf-kpi"><small>Render</small><b data-gl-state>init</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="mw-grid">
  <aside class="leaf-panel">
    <h2>Parametri collegamento</h2>
    <div class="leaf-scroll">
      <div class="leaf-card control">
        <h3>Radio Link Budget</h3>

        <label>Frequenza [GHz]</label>
        <input id="freq" type="range" min="1" max="90" step="0.1" value="18">
        <div class="leaf-note">f = <span class="value" id="freqVal"></span> GHz</div>

        <label>Distanza [km]</label>
        <input id="dist" type="range" min="0.1" max="80" step="0.1" value="12">
        <div class="leaf-note">d = <span class="value" id="distVal"></span> km</div>

        <label>Potenza TX [dBm]</label>
        <input id="ptx" type="range" min="-10" max="40" step="1" value="20">
        <div class="leaf-note">Ptx = <span class="value" id="ptxVal"></span> dBm</div>

        <label>Guadagno antenna TX/RX [dBi]</label>
        <input id="gain" type="range" min="10" max="55" step="0.5" value="34">
        <div class="leaf-note">Gtx = Grx = <span class="value" id="gainVal"></span> dBi</div>

        <label>Perdite totali [dB]</label>
        <input id="loss" type="range" min="0" max="20" step="0.5" value="4">
        <div class="leaf-note">losses = <span class="value" id="lossVal"></span> dB</div>

        <label>Intensità pioggia [mm/h]</label>
        <input id="rain" type="range" min="0" max="80" step="1" value="10">
        <div class="leaf-note">rain = <span class="value" id="rainVal"></span> mm/h</div>
      </div>

      <div class="leaf-card">
        <h3>Formule operative</h3>
        <div class="formulaLive">
          FSPL = 92.45 + 20log10(f_GHz) + 20log10(d_km)<br>
          RSL = Ptx + Gtx + Grx - FSPL - losses - rainFade<br>
          r1 = √(λ d1 d2 / (d1+d2))<br>
          FadeMargin = RSL - RxThreshold
        </div>
      </div>

      <div class="leaf-card">
        <h3>Concetti</h3>
        <ul>
          <li>LOS geometrico non basta: serve clearance Fresnel.</li>
          <li>Rain fade cresce con frequenza e distanza effettiva.</li>
          <li>Adaptive modulation riduce capacità per mantenere disponibilità.</li>
          <li>RSL e BER devono essere correlati a soglie reali apparato.</li>
        </ul>
      </div>
    </div>
  </aside>

  <main class="leaf-panel mw-stage">
    <section class="mw-webgl-wrap">
      <canvas id="mwField"></canvas>
      <div class="leaf-overlay">
        <div class="leaf-stage-head">
          <div class="leaf-stage-title">Microwave Propagation Layer</div>
          <div class="leaf-stage-sub">LOS, Fresnel, attenuazione e degradazione meteo come digital twin operativo del link.</div>
        </div>
        <div></div>
        <div class="leaf-stage-foot">
          <div>FSPL: <span class="leaf-ok" id="fsplVal"></span></div>
          <div>Rain fade: <span id="rainFadeVal"></span></div>
          <div>Fresnel r1: <span id="fresnelVal"></span></div>
          <div>Availability: <span id="availabilityVal"></span></div>
          <div>Quality: leaf</div>
        </div>
      </div>
    </section>

    <section class="mw-plots">
      <div class="plotBox"><h3>PATH PROFILE / FRESNEL</h3><canvas id="pathPlot"></canvas></div>
      <div class="plotBox"><h3>CAPACITY / MODULATION</h3><canvas id="modPlot"></canvas></div>
    </section>
  </main>

  <aside class="leaf-panel">
    <h2>Risultati / Design decision</h2>
    <div class="leaf-scroll">
      <div class="leaf-card">
        <h3>Link budget live</h3>
        <table class="leaf-table">
          <tbody>
            <tr><th>FSPL</th><td id="tFspl">--</td></tr>
            <tr><th>Rain fade</th><td id="tRain">--</td></tr>
            <tr><th>RSL</th><td id="tRsl">--</td></tr>
            <tr><th>Fade margin</th><td id="tMargin">--</td></tr>
            <tr><th>Modulation</th><td id="tMod">--</td></tr>
            <tr><th>Capacity class</th><td id="tCap">--</td></tr>
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
          <li>Profilo terreno reale e curvatura terrestre.</li>
          <li>ITU-R rain zone e availability target.</li>
          <li>XPIC / dual polarization.</li>
          <li>Adaptive modulation table vendor-like.</li>
          <li>Correlazione con BER, ES, SES, UAS.</li>
        </ul>
      </div>
    </div>
  </aside>
</div>

<script>
const $=id=>document.getElementById(id);

function db(x){return 20*Math.log10(x);}
function val(id){return +$(id).value;}
function calc(){
  const f=val("freq");
  const d=val("dist");
  const ptx=val("ptx");
  const gain=val("gain");
  const loss=val("loss");
  const rain=val("rain");

  const fspl=92.45+20*Math.log10(f)+20*Math.log10(d);
  const lambda=299792458/(f*1e9);
  const fresnel=Math.sqrt(lambda*(d*1000/2)*(d*1000/2)/(d*1000));
  const rainFade=(rain/25)*Math.pow(f/18,1.18)*Math.pow(d/10,0.82)*2.1;
  const rsl=ptx+gain+gain-fspl-loss-rainFade;

  const thresholds=[
    {m:"4096QAM",thr:-48,cap:"Very High"},
    {m:"1024QAM",thr:-54,cap:"High"},
    {m:"256QAM",thr:-60,cap:"Medium/High"},
    {m:"64QAM",thr:-66,cap:"Medium"},
    {m:"16QAM",thr:-72,cap:"Robust"},
    {m:"QPSK",thr:-78,cap:"Fallback"},
    {m:"LINK DOWN",thr:-999,cap:"Outage"}
  ];
  const selected=thresholds.find(x=>rsl>=x.thr) || thresholds[thresholds.length-1];
  const margin=rsl-selected.thr;
  const availability= margin>25 ? "99.999%" : margin>18 ? "99.99%" : margin>10 ? "99.9%" : margin>3 ? "degraded" : "risk";

  $("freqVal").textContent=f.toFixed(1);
  $("distVal").textContent=d.toFixed(1);
  $("ptxVal").textContent=ptx.toFixed(0);
  $("gainVal").textContent=gain.toFixed(1);
  $("lossVal").textContent=loss.toFixed(1);
  $("rainVal").textContent=rain.toFixed(0);

  $("fsplVal").textContent=fspl.toFixed(1)+" dB";
  $("rainFadeVal").textContent=rainFade.toFixed(1)+" dB";
  $("fresnelVal").textContent=fresnel.toFixed(1)+" m";
  $("availabilityVal").textContent=availability;

  $("kRsl").textContent=rsl.toFixed(1)+" dBm";
  $("kMargin").textContent=margin.toFixed(1)+" dB";
  $("kMod").textContent=selected.m;

  $("tFspl").textContent=fspl.toFixed(2)+" dB";
  $("tRain").textContent=rainFade.toFixed(2)+" dB";
  $("tRsl").textContent=rsl.toFixed(2)+" dBm";
  $("tMargin").textContent=margin.toFixed(2)+" dB";
  $("tMod").innerHTML="<span class='"+(selected.m==="LINK DOWN"?"modBad":margin<8?"modWarn":"modGood")+"'>"+selected.m+"</span>";
  $("tCap").textContent=selected.cap;

  const alarms=[];
  if(margin<3) alarms.push("CRITICO: fade margin insufficiente, rischio outage.");
  if(rainFade>12) alarms.push("Rain fade elevato: valutare frequenza inferiore, antenne maggiori o diversity.");
  if(fresnel>12) alarms.push("Prima zona di Fresnel ampia: verificare clearance reale.");
  if(d>35 && f>23) alarms.push("Link lungo ad alta frequenza: availability meteo da verificare.");
  if(alarms.length===0) alarms.push("Nessun allarme critico nel modello semplificato.");
  $("alarms").innerHTML=alarms.map(a=>"<li>"+a+"</li>").join("");

  return {f,d,ptx,gain,loss,rain,fspl,fresnel,rainFade,rsl,margin,selected,availability};
}

function drawPath(c, p){
  const ctx=c.getContext("2d");
  const dpr=window.devicePixelRatio||1;
  const w=c.clientWidth*dpr|0,h=c.clientHeight*dpr|0;
  if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
  ctx.clearRect(0,0,w,h);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,229,255,.14)";
  for(let x=0;x<w;x+=w/12){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=h/5){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

  const yLos=h*.35;
  ctx.strokeStyle="#00e5ff";ctx.lineWidth=2*dpr;
  ctx.beginPath();ctx.moveTo(30*dpr,yLos);ctx.lineTo(w-30*dpr,yLos);ctx.stroke();

  ctx.strokeStyle="rgba(117,255,91,.78)";
  ctx.lineWidth=1.5*dpr;
  ctx.beginPath();
  for(let i=0;i<=100;i++){
    const x=30*dpr+i/100*(w-60*dpr);
    const fres=Math.sin(Math.PI*i/100)*Math.min(h*.28,p.fresnel*7*dpr);
    const y=yLos+fres;
    if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
  }
  ctx.stroke();
  ctx.beginPath();
  for(let i=0;i<=100;i++){
    const x=30*dpr+i/100*(w-60*dpr);
    const fres=Math.sin(Math.PI*i/100)*Math.min(h*.28,p.fresnel*7*dpr);
    const y=yLos-fres;
    if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
  }
  ctx.stroke();

  ctx.fillStyle="#ffd84d";
  ctx.fillRect(20*dpr,yLos-34*dpr,14*dpr,70*dpr);
  ctx.fillRect(w-34*dpr,yLos-34*dpr,14*dpr,70*dpr);

  ctx.fillStyle="#8fb8c8";
  ctx.font=(11*dpr)+"px monospace";
  ctx.fillText("LOS + Fresnel clearance model", 14*dpr, h-18*dpr);
}

function drawMod(c,p){
  const ctx=c.getContext("2d");
  const dpr=window.devicePixelRatio||1;
  const w=c.clientWidth*dpr|0,h=c.clientHeight*dpr|0;
  if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
  ctx.clearRect(0,0,w,h);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  const mods=[
    ["QPSK",-78],["16QAM",-72],["64QAM",-66],["256QAM",-60],["1024QAM",-54],["4096QAM",-48]
  ];
  const min=-85,max=-40;
  mods.forEach((m,i)=>{
    const x=(m[1]-min)/(max-min)*w;
    ctx.strokeStyle="rgba(0,229,255,.20)";
    ctx.beginPath();ctx.moveTo(x,35*dpr);ctx.lineTo(x,h-25*dpr);ctx.stroke();
    ctx.fillStyle="#8fb8c8";
    ctx.font=(10*dpr)+"px monospace";
    ctx.fillText(m[0],x+4*dpr,50*dpr+i%2*14*dpr);
  });
  const xr=(p.rsl-min)/(max-min)*w;
  ctx.strokeStyle=p.margin<3?"#ff3d7f":p.margin<10?"#ffd84d":"#75ff5b";
  ctx.lineWidth=4*dpr;
  ctx.beginPath();ctx.moveTo(xr,25*dpr);ctx.lineTo(xr,h-20*dpr);ctx.stroke();
  ctx.fillStyle=ctx.strokeStyle;
  ctx.font=(13*dpr)+"px monospace";
  ctx.fillText("RSL "+p.rsl.toFixed(1)+" dBm", 18*dpr, h-38*dpr);
}

function initWebGL(){
  const canvas=$("mwField");
  const gl=canvas.getContext("webgl",{antialias:true,alpha:false});
  if(!gl){document.querySelector("[data-gl-state]").textContent="fallback";return;}
  document.querySelector("[data-gl-state]").textContent="webgl";
  const vs='attribute vec2 p; varying vec2 v; void main(){v=p; gl_Position=vec4(p,0.0,1.0);}';
  const fs='precision mediump float; varying vec2 v; uniform float t; uniform vec2 r; uniform float margin; uniform float rain; float beam(vec2 p, vec2 a, vec2 b){vec2 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);return length(pa-ba*h);} void main(){vec2 uv=(v+1.0)*0.5; vec2 p=uv*2.0-1.0; p.x*=r.x/r.y; vec2 a=vec2(-.85,.0), b=vec2(.85,.0); float d=beam(p,a,b); float core=0.012/(d+0.012); float fres=0.020/(abs(d-.18)+0.035); float rainfog=rain*(sin((uv.x+uv.y)*80.0+t*7.0)*.5+.5); vec3 col=vec3(.003,.014,.026); col+=vec3(0.0,.75,1.0)*core*.42; col+=vec3(.20,.22,1.0)*fres*.22; col+=vec3(.25,.35,.55)*rainfog*.22; col+=vec3(.45,1.0,.25)*smoothstep(.0,28.0,margin)*.05; gl_FragColor=vec4(col,1.0);}';
  function compile(type,src){const s=gl.createShader(type);gl.shaderSource(s,src);gl.compileShader(s);return s;}
  const pr=gl.createProgram();gl.attachShader(pr,compile(gl.VERTEX_SHADER,vs));gl.attachShader(pr,compile(gl.FRAGMENT_SHADER,fs));gl.linkProgram(pr);gl.useProgram(pr);
  const buf=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buf);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
  const loc=gl.getAttribLocation(pr,"p");gl.enableVertexAttribArray(loc);gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);
  const ut=gl.getUniformLocation(pr,"t"),ur=gl.getUniformLocation(pr,"r"),um=gl.getUniformLocation(pr,"margin"),ui=gl.getUniformLocation(pr,"rain");
  function frame(ms){
    const dpr=window.devicePixelRatio||1; const w=canvas.clientWidth*dpr|0,h=canvas.clientHeight*dpr|0;
    if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);}
    const p=calc();
    gl.uniform1f(ut,ms*.001);gl.uniform2f(ur,canvas.width,canvas.height);gl.uniform1f(um,Math.max(0,p.margin));gl.uniform1f(ui,p.rain/80);
    gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

function tick(){
  const p=calc();
  drawPath($("pathPlot"),p);
  drawMod($("modPlot"),p);
  requestAnimationFrame(tick);
}

["freq","dist","ptx","gain","loss","rain"].forEach(id=>$(id).addEventListener("input",calc));
initWebGL();
tick();
</script>
</body>
</html>
HTML

echo
echo "[3/8] Aggiorno Expansion manifest: Microwave Link punta alla V2"
python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

public=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public")
p=public/"trfmc_expansion_modules_v1.json"
m=json.loads(p.read_text())

for mod in m["modules"]:
    if mod["id"]=="microwave_link":
        mod["title"]="Microwave Link Operations Center V2"
        mod["url"]="/trfmc_microwave_link_operations_center_v2.html"
        mod["version"]="v2"
        mod["description"]="Interactive microwave link budget engine: FSPL, Fresnel, rain fade, RSL, margin and adaptive modulation."

m["last_microwave_link_v2_update"]=datetime.now(timezone.utc).isoformat()
p.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n")
PY

echo
echo "[4/8] Aggiorno Hub link Microwave V1 -> V2"
python3 - <<'PY'
from pathlib import Path
p=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_expansion_hub_v1.html")
s=p.read_text()
s=s.replace('/trfmc_microwave_link_operations_center_v1.html','/trfmc_microwave_link_operations_center_v2.html')
s=s.replace('Microwave Link Operations Center</b>','Microwave Link Operations Center V2</b>')
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

target=public/"trfmc_microwave_link_operations_center_v2.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_microwave_link_operations_center_v2.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_microwave_link_operations_center_v2.html",
  "url":"/trfmc_microwave_link_operations_center_v2.html",
  "size":target.stat().st_size,
  "webgl":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Microwave Link V2 interactive link budget engine"
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
reg["last_microwave_link_v2_update"]={
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "page":"/trfmc_microwave_link_operations_center_v2.html",
    "policy":"leaf upgrade only; V6R3 and Control Room unchanged"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_microwave_link_v2_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[6/8] Quality gate"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_microwave_link_operations_center_v2.html \
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
  "page":"http://127.0.0.1:5173/trfmc_microwave_link_operations_center_v2.html",
  "http_non_200":non200,
  "external_refs_real":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and protected_ok and registry_changed else "WARN",
  "policy":"Microwave Link V2 is a leaf upgrade. V6R3 and official Control Room unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_MICROWAVE_LINK_V2_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_microwave_link_operations_center_v2.html \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_microwave_link_v2 \
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
echo "http://127.0.0.1:5173/trfmc_microwave_link_operations_center_v2.html"
echo "============================================================"
