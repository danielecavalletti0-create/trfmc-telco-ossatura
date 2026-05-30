#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets/trfmc_design_system"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RF_PHYSICS_ATLAS_V2_$TS"
LATEST="$BASE/runtime/quality/latest_rf_physics_atlas_v2"

PAGE="$PUBLIC/trfmc_rf_physics_theory_atlas_v2.html"
HUB="$PUBLIC/trfmc_expansion_hub_v1.html"
MANIFEST="$PUBLIC/trfmc_expansion_modules_v1.json"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality" "$ASSETS"

cd "$BASE"

echo "============================================================"
echo "TRFMC RF PHYSICS THEORY ATLAS V2"
echo "Interactive EM/RF/DSP engine · leaf module · safe patch"
echo "============================================================"

echo
echo "[1/8] Snapshot e hash protetti"
cp -av "$PAGE" "runtime/backups/trfmc_rf_physics_theory_atlas_v2_before_$TS.html.bak" 2>/dev/null || true
cp -av "$HUB" "runtime/backups/trfmc_expansion_hub_before_rfphysics_v2_$TS.html.bak"
cp -av "$MANIFEST" "runtime/backups/trfmc_expansion_modules_before_rfphysics_v2_$TS.json.bak"
cp -av "$REG" "runtime/backups/trfmc_registry_before_rfphysics_v2_$TS.json.bak"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo RF Physics Theory Atlas V2"
cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC RF Physics Theory Atlas V2</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<style>
.rf-grid{display:grid;grid-template-columns:360px 1fr 390px;gap:7px;min-height:calc(100vh - 76px);padding:7px;position:relative;z-index:1}
.rf-scope{display:grid;grid-template-rows:1fr 240px;gap:7px;min-height:0}
.rf-canvas-wrap{position:relative;min-height:420px;overflow:hidden}
#emField{width:100%;height:100%;display:block;min-height:420px}
.rf-plots{display:grid;grid-template-columns:1fr 1fr;gap:7px}
.plotBox{border:1px solid rgba(0,229,255,.27);background:#010409;position:relative;overflow:hidden}
.plotBox h3{position:absolute;left:10px;top:8px;margin:0;color:#00e5ff;font-size:11px;letter-spacing:1px;z-index:2}
.plotBox canvas{width:100%;height:100%;display:block}
.control label{display:block;color:#8fb8c8;font-size:10px;text-transform:uppercase;margin:8px 0 4px}
.control input,.control select{width:100%;background:#03101a;color:#e9fbff;border:1px solid rgba(0,229,255,.35);border-radius:5px;padding:7px;font-size:12px}
.formulaLive{font-family:ui-monospace,Consolas,monospace;background:#010409;border:1px solid rgba(0,229,255,.22);border-radius:6px;color:#dffaff;padding:8px;font-size:11px;line-height:1.5}
.value{color:#75ff5b;font-weight:800}
@media(max-width:1300px){.rf-grid{grid-template-columns:1fr}.rf-plots{grid-template-columns:1fr}.rf-canvas-wrap{min-height:480px}}
</style>
</head>
<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">RF Physics Theory Atlas V2</div>
    <div class="leaf-sub">Maxwell · wave equation · Fourier · phase/group delay · thermal noise · RF/DSP correlation</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>Engine</small><b>EM/DSP</b></div>
    <div class="leaf-kpi"><small>Domain</small><b>TIME/FREQ</b></div>
    <div class="leaf-kpi"><small>Render</small><b data-gl-state>init</b></div>
    <div class="leaf-kpi"><small>Shell</small><b>V6R3</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="rf-grid">
  <aside class="leaf-panel">
    <h2>Parametri fisici</h2>
    <div class="leaf-scroll">
      <div class="leaf-card control">
        <h3>Signal / Sampling</h3>
        <label>Carrier frequency f0 [MHz]</label>
        <input id="freq" type="range" min="1" max="6000" value="2400">
        <div class="leaf-note">f0 = <span class="value" id="freqVal"></span> MHz</div>

        <label>Sample rate Fs [MS/s]</label>
        <input id="fs" type="range" min="1" max="200" value="80">
        <div class="leaf-note">Fs = <span class="value" id="fsVal"></span> MS/s</div>

        <label>Noise floor / random perturbation</label>
        <input id="noise" type="range" min="0" max="100" value="15">
        <div class="leaf-note">noise = <span class="value" id="noiseVal"></span>%</div>

        <label>Phase offset [deg]</label>
        <input id="phase" type="range" min="-180" max="180" value="35">
        <div class="leaf-note">φ = <span class="value" id="phaseVal"></span>°</div>

        <label>Scenario</label>
        <select id="scenario">
          <option value="clean">Clean sinusoid</option>
          <option value="multi">Multi-tone / intermodulation</option>
          <option value="ringing">Ringing / resonance</option>
          <option value="ofdm">OFDM-like composite</option>
        </select>
      </div>

      <div class="leaf-card">
        <h3>Concetti collegati</h3>
        <ul>
          <li>Campo EM come soluzione dell’equazione d’onda.</li>
          <li>Segnale tempo e spettro come due viste dello stesso fenomeno.</li>
          <li>Phase/group delay come radice di dispersione e deformazione.</li>
          <li>Noise floor fisico: kTB, NF, dinamica ADC, sensibilità.</li>
        </ul>
      </div>

      <div class="leaf-card">
        <h3>Formule base</h3>
        <div class="formulaLive">
          c = 1 / √(με)<br>
          λ = c / f<br>
          Δf = Fs / N<br>
          Pn = kTB<br>
          τg = - dφ(ω) / dω
        </div>
      </div>
    </div>
  </aside>

  <main class="leaf-panel rf-scope">
    <section class="rf-canvas-wrap">
      <canvas id="emField"></canvas>
      <div class="leaf-overlay">
        <div class="leaf-stage-head">
          <div class="leaf-stage-title">Electromagnetic Field Layer</div>
          <div class="leaf-stage-sub">GPU/WebGL visual layer: propagazione, interferenza, fase e rumore come campo dinamico.</div>
        </div>
        <div></div>
        <div class="leaf-stage-foot">
          <div>λ: <span class="leaf-ok" id="lambdaVal"></span></div>
          <div>Bin Δf: <span id="binVal"></span></div>
          <div>kTB: <span id="ktbVal"></span></div>
          <div>Mode: <span id="modeVal"></span></div>
          <div>Quality: leaf</div>
        </div>
      </div>
    </section>
    <section class="rf-plots">
      <div class="plotBox"><h3>TIME DOMAIN</h3><canvas id="timePlot"></canvas></div>
      <div class="plotBox"><h3>FREQUENCY DOMAIN</h3><canvas id="freqPlot"></canvas></div>
    </section>
  </main>

  <aside class="leaf-panel">
    <h2>Teoria / Roadmap engine</h2>
    <div class="leaf-scroll">
      <div class="leaf-card">
        <h3>1. Maxwell → wave equation</h3>
        <p>Il modulo deve evolvere verso un motore fisico: campi E/H, boundary conditions, polarizzazione, energia e vettore di Poynting.</p>
      </div>
      <div class="leaf-card">
        <h3>2. Fourier → measurement</h3>
        <p>Il time-domain e il frequency-domain devono restare sincronizzati: cursori, FFT, RBW, transitori, rumore e spur.</p>
      </div>
      <div class="leaf-card">
        <h3>3. Noise physics</h3>
        <p>kTB, thermal noise, phase noise e quantization noise devono diventare parametri collegati a SDR, VNA e receiver chain.</p>
      </div>
      <div class="leaf-card">
        <h3>4. Collegamenti successivi</h3>
        <ul>
          <li>RF DSP Runtime</li>
          <li>Receiver Chain Lab</li>
          <li>VNA / S-parameter Console</li>
          <li>Antenna Radiation Engine</li>
          <li>Propagation Digital Twin</li>
        </ul>
      </div>
    </div>
  </aside>
</div>

<script>
const $=id=>document.getElementById(id);
const N=256;
let signal=new Float32Array(N);
let spectrum=new Float32Array(N/2);

function params(){
  return {
    f:+$("freq").value,
    fs:+$("fs").value,
    noise:+$("noise").value/100,
    phase:+$("phase").value*Math.PI/180,
    scenario:$("scenario").value
  };
}

function compute(){
  const p=params();
  const base=7;
  for(let i=0;i<N;i++){
    const t=i/N;
    let x=Math.sin(2*Math.PI*base*t+p.phase);
    if(p.scenario==="multi") x+=0.45*Math.sin(2*Math.PI*17*t+1.7)+0.25*Math.sin(2*Math.PI*29*t);
    if(p.scenario==="ringing") x+=0.75*Math.exp(-9*((t+.1)%1))*Math.sin(2*Math.PI*42*t);
    if(p.scenario==="ofdm"){
      x=0;
      for(let k=3;k<36;k+=4) x+=Math.sin(2*Math.PI*k*t+p.phase*k*.07)/8;
    }
    const n=(Math.random()*2-1)*p.noise;
    signal[i]=x+n;
  }

  for(let k=0;k<N/2;k++){
    let re=0, im=0;
    for(let n=0;n<N;n++){
      const a=-2*Math.PI*k*n/N;
      re+=signal[n]*Math.cos(a);
      im+=signal[n]*Math.sin(a);
    }
    spectrum[k]=Math.sqrt(re*re+im*im)/N;
  }

  $("freqVal").textContent=p.f.toFixed(0);
  $("fsVal").textContent=p.fs.toFixed(0);
  $("noiseVal").textContent=(p.noise*100).toFixed(0);
  $("phaseVal").textContent=(p.phase*180/Math.PI).toFixed(0);
  $("lambdaVal").textContent=(299792458/(p.f*1e6)).toFixed(3)+" m";
  $("binVal").textContent=(p.fs/N).toFixed(3)+" MHz";
  $("ktbVal").textContent=(-174 + 10*Math.log10(p.fs*1e6)).toFixed(1)+" dBm";
  $("modeVal").textContent=p.scenario;
}

function drawPlot(canvas, data, type){
  const ctx=canvas.getContext("2d");
  const dpr=window.devicePixelRatio||1;
  const w=canvas.clientWidth*dpr|0, h=canvas.clientHeight*dpr|0;
  if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
  ctx.clearRect(0,0,w,h);
  ctx.fillStyle="#010409";ctx.fillRect(0,0,w,h);
  ctx.strokeStyle="rgba(0,229,255,.13)";
  ctx.lineWidth=1;
  for(let x=0;x<w;x+=w/12){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=h/6){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
  ctx.strokeStyle= type==="time" ? "#75ff5b" : "#00e5ff";
  ctx.lineWidth=2*dpr;
  ctx.beginPath();
  for(let i=0;i<data.length;i++){
    const x=i/(data.length-1)*w;
    let y;
    if(type==="time") y=h/2-data[i]*h*.28;
    else y=h-(Math.min(1,data[i]*8))*h*.82-12;
    if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
  }
  ctx.stroke();
}

function initWebGL(){
  const canvas=$("emField");
  const gl=canvas.getContext("webgl",{antialias:true,alpha:false});
  if(!gl){document.querySelector("[data-gl-state]").textContent="fallback";return;}
  document.querySelector("[data-gl-state]").textContent="webgl";
  const vs='attribute vec2 p; varying vec2 v; void main(){v=p; gl_Position=vec4(p,0.0,1.0);}';
  const fs='precision mediump float; varying vec2 v; uniform float t; uniform vec2 r; uniform float phase; uniform float noise; float wave(vec2 p, vec2 c, float f){float d=length(p-c); return sin(28.0*d-f*t+phase)/(1.0+8.0*d);} void main(){vec2 uv=(v+1.0)*0.5; vec2 p=uv*2.0-1.0; p.x*=r.x/r.y; float e=0.0; e+=wave(p,vec2(-.55,-.2),7.0); e+=wave(p,vec2(.35,.15),5.8); e+=wave(p,vec2(.0,.55),4.2); float ring=abs(sin(22.0*length(p)-t*2.0))*0.05/(abs(length(p)-0.48)+0.04); float grid=(step(.986,fract(uv.x*34.0))+step(.986,fract(uv.y*20.0)))*.07; vec3 col=vec3(.003,.014,.026); col+=vec3(0.0,.65,1.0)*abs(e)*.34; col+=vec3(.40,.14,1.0)*ring; col+=vec3(.45,1.0,.25)*grid; col+=vec3(noise*.18,noise*.10,noise*.22); gl_FragColor=vec4(col,1.0);}';
  function compile(type,src){const s=gl.createShader(type);gl.shaderSource(s,src);gl.compileShader(s);return s;}
  const pr=gl.createProgram();gl.attachShader(pr,compile(gl.VERTEX_SHADER,vs));gl.attachShader(pr,compile(gl.FRAGMENT_SHADER,fs));gl.linkProgram(pr);gl.useProgram(pr);
  const buf=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buf);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
  const loc=gl.getAttribLocation(pr,"p");gl.enableVertexAttribArray(loc);gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);
  const ut=gl.getUniformLocation(pr,"t"), ur=gl.getUniformLocation(pr,"r"), up=gl.getUniformLocation(pr,"phase"), un=gl.getUniformLocation(pr,"noise");
  function frame(ms){
    const dpr=window.devicePixelRatio||1; const w=canvas.clientWidth*dpr|0,h=canvas.clientHeight*dpr|0;
    if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);}
    const p=params();
    gl.uniform1f(ut,ms*.001);gl.uniform2f(ur,canvas.width,canvas.height);gl.uniform1f(up,p.phase);gl.uniform1f(un,p.noise);
    gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

function tick(){
  compute();
  drawPlot($("timePlot"), signal, "time");
  drawPlot($("freqPlot"), spectrum, "freq");
  requestAnimationFrame(tick);
}

["freq","fs","noise","phase","scenario"].forEach(id=>$(id).addEventListener("input",compute));
initWebGL();
tick();
</script>
</body>
</html>
HTML

echo
echo "[3/8] Aggiorno Expansion manifest: RF Physics punta alla V2"
python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

public=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public")
p=public/"trfmc_expansion_modules_v1.json"
m=json.loads(p.read_text())

for mod in m["modules"]:
    if mod["id"]=="rf_physics_theory":
        mod["title"]="RF Physics Theory Atlas V2"
        mod["url"]="/trfmc_rf_physics_theory_atlas_v2.html"
        mod["version"]="v2"
        mod["description"]="Interactive EM/RF/DSP physics atlas: wave equation, Fourier, phase, thermal noise and time/frequency correlation."

m["last_rf_physics_v2_update"]=datetime.now(timezone.utc).isoformat()
p.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n")
PY

echo
echo "[4/8] Aggiorno Hub link RF Physics V1 -> V2"
python3 - <<'PY'
from pathlib import Path
p=Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_expansion_hub_v1.html")
s=p.read_text()
s=s.replace('/trfmc_rf_physics_theory_atlas_v1.html','/trfmc_rf_physics_theory_atlas_v2.html')
s=s.replace('RF Physics Theory Atlas</b>','RF Physics Theory Atlas V2</b>')
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

target=public/"trfmc_rf_physics_theory_atlas_v2.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_rf_physics_theory_atlas_v2.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_rf_physics_theory_atlas_v2.html",
  "url":"/trfmc_rf_physics_theory_atlas_v2.html",
  "size":target.stat().st_size,
  "webgl":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"RF Physics Atlas V2 interactive engine"
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
reg["last_rf_physics_v2_update"]={
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "page":"/trfmc_rf_physics_theory_atlas_v2.html",
    "policy":"leaf upgrade only; V6R3 and Control Room unchanged"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_rf_physics_v2_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[6/8] Quality gate"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_rf_physics_theory_atlas_v2.html \
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
  "page":"http://127.0.0.1:5173/trfmc_rf_physics_theory_atlas_v2.html",
  "http_non_200":non200,
  "external_refs_real":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and protected_ok and registry_changed else "WARN",
  "policy":"RF Physics Atlas V2 is a leaf upgrade. V6R3 and official Control Room unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_RF_PHYSICS_ATLAS_V2_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_rf_physics_theory_atlas_v2.html \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_rf_physics_atlas_v2 \
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
echo "http://127.0.0.1:5173/trfmc_rf_physics_theory_atlas_v2.html"
echo "============================================================"
