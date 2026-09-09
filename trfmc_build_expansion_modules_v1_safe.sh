#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets/trfmc_design_system"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_EXPANSION_MODULES_V1_$TS"
LATEST="$BASE/runtime/quality/latest_expansion_modules_v1"

mkdir -p "$ASSETS" "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/rejected_scripts"

cd "$BASE"

echo "============================================================"
echo "TRFMC EXPANSION MODULES V1 SAFE"
echo "Nuove strutture · pagine leaf · teoria · no iframe · no CDN"
echo "============================================================"

echo
echo "[1/9] Blocco script fused non ammesso, se presente"
if [ -f trfmc_create_master_fused_portal_v1.sh ]; then
  cp -av trfmc_create_master_fused_portal_v1.sh \
    "runtime/rejected_scripts/trfmc_create_master_fused_portal_v1_REJECTED_$TS.sh" || true
  chmod -x trfmc_create_master_fused_portal_v1.sh || true
fi

cat > runtime/rejected_scripts/README_REJECTED_MASTER_FUSED_PORTAL.txt <<EOF2
Script non ammesso: trfmc_create_master_fused_portal_v1.sh

Motivi:
- crea nuova shell parallela;
- usa iframe come viewer strutturale;
- può creare portale dentro portale;
- può introdurre doppie/triple barre;
- può spostare V6R3 da shell ufficiale a fallback.

Regola valida:
V6R3 resta ufficiale. Le nuove integrazioni sono leaf modules + registry + quality gate.

Data: $(date)
EOF2

echo
echo "[2/9] Snapshot dei file protetti e del registry"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"
REG="$PUBLIC/trfmc_portal_registry_unified.json"

V6R3_SHA_BEFORE="$(sha256sum "$V6R3" | awk '{print $1}')"
CONTROL_SHA_BEFORE="$(sha256sum "$CONTROL" | awk '{print $1}')"
REG_SHA_BEFORE="$(sha256sum "$REG" | awk '{print $1}')"

cp -av "$REG" "runtime/backups/trfmc_portal_registry_unified_before_expansion_$TS.json.bak"
cp -av "$V6R3" "runtime/backups/trfmc_v6r3_before_expansion_$TS.html.bak"
cp -av "$CONTROL" "runtime/backups/trfmc_control_room_before_expansion_$TS.html.bak"

{
  echo "V6R3_SHA_BEFORE=$V6R3_SHA_BEFORE"
  echo "CONTROL_SHA_BEFORE=$CONTROL_SHA_BEFORE"
  echo "REG_SHA_BEFORE=$REG_SHA_BEFORE"
} > "$OUT/pre_sha.txt"

echo
echo "[3/9] Creo CSS leaf premium locale"
cat > "$ASSETS/trfmc_leaf_master_v1.css" <<'CSS'
:root{
  --leaf-bg:#02060d;
  --leaf-bg2:#061827;
  --leaf-panel:rgba(5,18,31,.90);
  --leaf-panel2:rgba(8,32,52,.94);
  --leaf-line:#0c7fb8;
  --leaf-cyan:#00e5ff;
  --leaf-green:#75ff5b;
  --leaf-yellow:#ffd84d;
  --leaf-red:#ff3d7f;
  --leaf-blue:#1e9cff;
  --leaf-violet:#9b7cff;
  --leaf-text:#e9fbff;
  --leaf-muted:#8fb8c8;
  --leaf-font:Inter,Segoe UI,Arial,sans-serif;
}
*{box-sizing:border-box}
body.trfmc-leaf{
  margin:0;
  min-height:100vh;
  background:
    radial-gradient(circle at 15% 0%,rgba(0,229,255,.13),transparent 28%),
    radial-gradient(circle at 85% 10%,rgba(117,255,91,.07),transparent 24%),
    linear-gradient(180deg,#02060d,#010409 72%);
  color:var(--leaf-text);
  font-family:var(--leaf-font);
}
body.trfmc-leaf:before{
  content:"";
  position:fixed;
  inset:0;
  pointer-events:none;
  background-image:
    linear-gradient(rgba(0,229,255,.045) 1px,transparent 1px),
    linear-gradient(90deg,rgba(0,229,255,.045) 1px,transparent 1px);
  background-size:44px 44px;
  mask-image:linear-gradient(to bottom,rgba(0,0,0,.70),transparent);
}
.leaf-top{
  min-height:76px;
  display:grid;
  grid-template-columns:1.2fr 1.6fr auto;
  align-items:center;
  gap:14px;
  padding:12px 16px;
  border-bottom:1px solid rgba(0,229,255,.34);
  background:linear-gradient(90deg,rgba(4,16,27,.96),rgba(6,36,58,.92),rgba(4,16,27,.96));
  box-shadow:0 0 34px rgba(0,229,255,.16);
  position:sticky;
  top:0;
  z-index:10;
}
.leaf-title{
  color:var(--leaf-cyan);
  font-size:18px;
  font-weight:900;
  letter-spacing:2px;
  text-transform:uppercase;
}
.leaf-sub{color:var(--leaf-muted);font-size:11px;margin-top:3px}
.leaf-kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:7px}
.leaf-kpi{border:1px solid rgba(0,229,255,.25);background:rgba(7,24,39,.72);padding:7px}
.leaf-kpi small{display:block;color:var(--leaf-muted);font-size:9px;text-transform:uppercase}
.leaf-kpi b{display:block;color:var(--leaf-green);font-size:16px;margin-top:2px}
.leaf-actions{display:flex;flex-wrap:wrap;gap:6px;justify-content:flex-end}
.leaf-btn{
  display:inline-block;
  border:1px solid rgba(0,229,255,.36);
  background:rgba(6,36,58,.76);
  color:var(--leaf-cyan);
  padding:7px 9px;
  border-radius:5px;
  text-decoration:none;
  font-size:11px;
}
.leaf-layout{
  display:grid;
  grid-template-columns:340px 1fr 360px;
  min-height:calc(100vh - 76px);
  gap:7px;
  padding:7px;
  position:relative;
  z-index:1;
}
.leaf-panel{
  border:1px solid rgba(0,229,255,.27);
  background:linear-gradient(180deg,var(--leaf-panel2),rgba(2,8,14,.95));
  min-height:0;
  overflow:hidden;
}
.leaf-panel h2{
  margin:0;
  padding:9px 11px;
  border-bottom:1px solid rgba(12,127,184,.55);
  color:var(--leaf-cyan);
  font-size:12px;
  letter-spacing:1px;
  text-transform:uppercase;
}
.leaf-scroll{height:calc(100% - 34px);overflow:auto;padding:9px}
.leaf-card{
  border:1px solid rgba(12,127,184,.55);
  background:rgba(3,16,26,.78);
  border-radius:8px;
  padding:10px;
  margin-bottom:9px;
  position:relative;
  overflow:hidden;
}
.leaf-card:after{
  content:"";
  position:absolute;
  right:-42px;
  top:-42px;
  width:120px;
  height:120px;
  background:radial-gradient(circle,rgba(0,229,255,.10),transparent 70%);
}
.leaf-card h3{margin:0 0 7px;color:var(--leaf-yellow);font-size:12px;position:relative;z-index:1}
.leaf-card p,.leaf-card li,.leaf-note{color:var(--leaf-muted);font-size:11px;line-height:1.45;position:relative;z-index:1}
.leaf-card ul{margin:8px 0 0 18px;padding:0}
.leaf-badge{
  display:inline-block;
  border:1px solid rgba(0,229,255,.35);
  color:var(--leaf-cyan);
  background:rgba(0,229,255,.06);
  border-radius:5px;
  padding:2px 6px;
  font-size:9px;
  margin:2px 3px 0 0;
}
.leaf-ok{color:var(--leaf-green);border-color:rgba(117,255,91,.4)}
.leaf-warn{color:var(--leaf-yellow);border-color:rgba(255,216,77,.4)}
.leaf-bad{color:var(--leaf-red);border-color:rgba(255,61,127,.4)}
.leaf-stage{
  min-height:620px;
  position:relative;
  overflow:hidden;
}
.leaf-canvas{width:100%;height:100%;display:block;min-height:620px}
.leaf-overlay{
  position:absolute;
  inset:0;
  pointer-events:none;
  display:grid;
  grid-template-rows:auto 1fr auto;
}
.leaf-stage-head{
  margin:14px;
  padding:12px;
  border:1px solid rgba(0,229,255,.28);
  background:rgba(2,8,14,.50);
  backdrop-filter:blur(8px);
}
.leaf-stage-title{color:var(--leaf-cyan);font-weight:900;letter-spacing:1px}
.leaf-stage-sub{color:var(--leaf-muted);font-size:12px;margin-top:4px}
.leaf-stage-foot{
  margin:14px;
  padding:9px;
  border:1px solid rgba(0,229,255,.24);
  background:rgba(2,8,14,.48);
  color:var(--leaf-muted);
  font-size:11px;
  display:grid;
  grid-template-columns:repeat(5,1fr);
  gap:8px;
}
.leaf-table{width:100%;border-collapse:collapse;font-size:11px}
.leaf-table th,.leaf-table td{border-bottom:1px solid rgba(0,229,255,.16);padding:6px;text-align:left;color:var(--leaf-muted)}
.leaf-table th{color:var(--leaf-cyan);text-transform:uppercase;font-size:9px}
.leaf-formula{
  background:#010409;
  border:1px solid rgba(0,229,255,.22);
  color:#dffaff;
  padding:8px;
  border-radius:6px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:11px;
  overflow:auto;
}
@media(max-width:1200px){
  .leaf-top{grid-template-columns:1fr}
  .leaf-kpis{grid-template-columns:repeat(2,1fr)}
  .leaf-layout{grid-template-columns:1fr}
  .leaf-stage,.leaf-canvas{min-height:520px}
}
CSS

echo
echo "[4/9] Creo JS WebGL locale condiviso"
cat > "$ASSETS/trfmc_leaf_webgl_v1.js" <<'JS'
(function(){
  function boot(){
    const canvases=document.querySelectorAll('[data-trfmc-webgl]');
    canvases.forEach((canvas,idx)=>init(canvas,idx));
  }
  function init(canvas,idx){
    const gl=canvas.getContext('webgl',{antialias:true,alpha:false});
    const state=document.querySelector('[data-gl-state]');
    if(!gl){ if(state) state.textContent='fallback'; return; }
    if(state) state.textContent='webgl';

    const vs='attribute vec2 p; varying vec2 v; void main(){v=p; gl_Position=vec4(p,0.0,1.0);}';
    const fs='precision mediump float; varying vec2 v; uniform float t; uniform vec2 r; uniform float mode; float line(vec2 p, vec2 a, vec2 b){vec2 pa=p-a, ba=b-a; float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0); return length(pa-ba*h);} void main(){vec2 uv=(v+1.0)*0.5; vec2 p=uv*2.0-1.0; p.x*=r.x/r.y; float g=0.0; for(int i=0;i<8;i++){float fi=float(i); vec2 a=vec2(sin(t*.20+fi+mode)*.72,cos(t*.17+fi*1.71)*.48); vec2 b=vec2(cos(t*.19+fi*1.3)*.82,sin(t*.23+fi*.9+mode)*.52); float d=line(p,a,b); g+=0.006/(d+0.006);} float rings=abs(sin(18.0*length(p)-t*1.8))*0.035/(abs(length(p)-0.44)+0.035); float grid=(step(.986,fract(uv.x*32.0))+step(.986,fract(uv.y*18.0)))*.08; vec3 col=vec3(0.004,0.017,0.028); col+=vec3(0.0,0.70,1.0)*g*.30; col+=vec3(0.45,1.0,0.25)*grid; col+=vec3(0.35,0.15,1.0)*rings; col+=vec3(0.0,0.16,0.22)*(1.0-length(p)*.45); gl_FragColor=vec4(col,1.0);}';

    function compile(type,src){
      const s=gl.createShader(type);
      gl.shaderSource(s,src);
      gl.compileShader(s);
      return s;
    }

    const pr=gl.createProgram();
    gl.attachShader(pr,compile(gl.VERTEX_SHADER,vs));
    gl.attachShader(pr,compile(gl.FRAGMENT_SHADER,fs));
    gl.linkProgram(pr);
    gl.useProgram(pr);

    const buf=gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER,buf);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
    const loc=gl.getAttribLocation(pr,'p');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);

    const ut=gl.getUniformLocation(pr,'t');
    const ur=gl.getUniformLocation(pr,'r');
    const um=gl.getUniformLocation(pr,'mode');

    function frame(ms){
      const dpr=window.devicePixelRatio||1;
      const w=canvas.clientWidth*dpr|0;
      const h=canvas.clientHeight*dpr|0;
      if(canvas.width!==w||canvas.height!==h){
        canvas.width=w; canvas.height=h; gl.viewport(0,0,w,h);
      }
      gl.uniform1f(ut,ms*.001);
      gl.uniform2f(ur,canvas.width,canvas.height);
      gl.uniform1f(um,idx+1.0);
      gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot);
  else boot();
})();
JS

echo
echo "[5/9] Genero nuove pagine leaf e hub"
python3 - <<'PY'
import json, html
from pathlib import Path
from datetime import datetime, timezone

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
public = base / "frontend/public"

modules = [
  {
    "file":"trfmc_rf_physics_theory_atlas_v1.html",
    "id":"rf_physics_theory",
    "area":"02_RF_Physics",
    "title":"RF Physics Theory Atlas",
    "subtitle":"Maxwell · Fourier · propagazione · fase · rumore · coerenza",
    "kpis":["Maxwell","Fourier","Phase","Noise"],
    "theory":[
      ["Equazioni di Maxwell","Base fisica di propagazione, induzione, onde elettromagnetiche, continuità del campo e accoppiamento E/H."],
      ["Fourier / FFT","Ogni segnale viene letto come somma di componenti spettrali. La FFT diventa ponte tra dominio tempo e frequenza."],
      ["Fase e ritardo di gruppo","La fase governa interferenza, beamforming, dispersione e fedeltà del segnale nei filtri e nelle linee."],
      ["Rumore e dinamica","Noise floor, SNR, NF, phase noise e jitter determinano capacità di misura e decodifica."]
    ],
    "formulas":["c = 1 / sqrt(μ ε)","τg = - dφ(ω) / dω","SNR(dB) = Ps(dBm) - Pn(dBm)","Δf = Fs / N"],
    "checklist":["Visualizzare onda tempo/frequenza","Collegare FFT a RBW/VBW","Mostrare phase noise e skirt spettrale","Creare simulatore coerenza/interferenza"]
  },
  {
    "file":"trfmc_microwave_link_operations_center_v1.html",
    "id":"microwave_link",
    "area":"06_Microwave_Link",
    "title":"Microwave Link Operations Center",
    "subtitle":"LOS · Fresnel · rain fade · RSL · BER · XPIC · adaptive modulation",
    "kpis":["LOS","Fresnel","RSL","BER"],
    "theory":[
      ["Line of Sight","Il collegamento MW richiede visibilità ottica e clearance della zona di Fresnel, non solo allineamento geometrico."],
      ["Fade margin","Margine tra RSL ricevuto e soglia minima di modulazione/capacità. Governa disponibilità e robustezza."],
      ["Rain fading","Alle frequenze alte la pioggia introduce attenuazione selettiva; E-band e mmWave richiedono calcolo probabilistico."],
      ["XPIC","Cross Polar Interference Cancellation permette riuso di frequenza su polarizzazioni ortogonali."]
    ],
    "formulas":["FSPL(dB)=32.44+20log10(f_MHz)+20log10(d_km)","r1 = sqrt(λ d1 d2 / (d1+d2))","RSL = EIRP + Gr - FSPL - losses","Availability = 1 - outage_probability"],
    "checklist":["Calcolatore link budget","Profilo terreno e Fresnel","Rain zone ITU-R","Adaptive modulation table","Allineamento antenna e polarizzazione"]
  },
  {
    "file":"trfmc_fiber_fronthaul_otdr_workbench_v1.html",
    "id":"fiber_fronthaul",
    "area":"07_Fiber_Optic",
    "title":"Fiber / Fronthaul / OTDR Workbench",
    "subtitle":"ODF · LC/SC/MPO · CPRI/eCPRI · attenuazione · riflessione · OTDR",
    "kpis":["ODF","OTDR","CPRI","eCPRI"],
    "theory":[
      ["Budget ottico","Il collegamento deve rispettare potenza TX/RX, attenuazioni, connettori, giunzioni, margine e dispersione."],
      ["OTDR","Misura riflessioni, eventi, attenuazione distribuita, giunti, connettori e fault lungo la fibra."],
      ["Fronthaul","CPRI/eCPRI trasporta segnali radio digitalizzati tra BBU/DU e RRU/RU con vincoli di latenza/jitter."],
      ["Pulizia connettori","Ispezione e cleaning sono obbligatori: contaminazione causa riflessione e perdita."]
    ],
    "formulas":["Loss_total = fiber_km·α + connector_loss + splice_loss + margin","ORL = -10log10(Preflected/Pincident)","Latency ≈ 5 μs/km in fibra","Throughput_eCPRI = function(IQ_rate, compression, MIMO_layers)"],
    "checklist":["Tabella connettori LC/SC/MPO","ODF map","OTDR event table","CPRI/eCPRI latency budget","Procedure cleaning/ispezione"]
  },
  {
    "file":"trfmc_private_networks_wifi7_5g_mesh_v1.html",
    "id":"private_networks",
    "area":"08_Private_Networks",
    "title":"Private Networks / Wi-Fi 7 / 5G Mesh Lab",
    "subtitle":"5G SA private · Wi-Fi 7 · MLO · TSN · MEC · industrial mesh",
    "kpis":["5G SA","Wi-Fi 7","MLO","MEC"],
    "theory":[
      ["5G Private","Core locale, RAN dedicata, SIM/eSIM, slicing, QoS e policy per industria, campus, mining, tactical."],
      ["Wi-Fi 7 MLO","Multi-Link Operation usa più bande/link per throughput, resilienza e latenza ridotta."],
      ["MEC","Edge compute avvicina applicazioni critiche a UE/sensori, riducendo latenza e traffico verso cloud."],
      ["TSN/QoS","Determinismo temporale e priorità traffico sono essenziali per robotica, AGV, droni e OT."]
    ],
    "formulas":["Latency_total = RAN + transport + core + app","Throughput_eff = PHY_rate · efficiency · airtime","QoS = 5QI / DSCP / scheduling_policy","Availability = path_diversity + redundancy"],
    "checklist":["Scenario mining/campus","Wi-Fi 7 MLO map","5G slice/QoS table","MEC workload","Roaming/handover view"]
  },
  {
    "file":"trfmc_antenna_rru_ret_cpri_port_mapping_v1.html",
    "id":"antenna_rru_ret",
    "area":"05_Antenna_System",
    "title":"Antenna / RRU / RET / CPRI Port Mapping Simulator",
    "subtitle":"sector · azimuth · tilt · AISG/RET · CPRI/eCPRI · MIMO layers",
    "kpis":["RRU","RET","CPRI","MIMO"],
    "theory":[
      ["Antenna sector","Ogni settore ha azimuth, mechanical/electrical tilt, beamwidth, gain, polarization e downtilt strategy."],
      ["RRU/RU mapping","Le porte RF e fronthaul devono essere coerenti con banda, MIMO, polarizzazione e carrier configuration."],
      ["RET/AISG","Remote Electrical Tilt abilita ottimizzazione copertura/interferenza senza intervento fisico in quota."],
      ["MIMO/Beamforming","Fase e ampiezza sui rami antenna determinano pattern, null steering e spatial multiplexing."]
    ],
    "formulas":["EIRP = Ptx + Gant - losses","ArrayFactor(θ)=Σ wn·e^(j n k d sinθ)","Tilt_total = mechanical + electrical","CPRI_rate ∝ IQ_width · sample_rate · antenna_ports"],
    "checklist":["Port mapping RRU/antenna","AISG/RET chain","Azimuth/tilt planner","MIMO layer view","PIM/VSWR alarm integration"]
  },
  {
    "file":"trfmc_datacenter_power_pdu_infrastructure_v1.html",
    "id":"datacenter_power",
    "area":"10_Data_Center_Infrastructure",
    "title":"Data Center / Power / PDU Infrastructure Lab",
    "subtitle":"rack · PDU · UPS · -48V · grounding · thermal · SNMP monitoring",
    "kpis":["PDU","UPS","-48V","SNMP"],
    "theory":[
      ["Power chain","AC mains, UPS, rectifier, DC plant, PDU e load balancing determinano resilienza del sito."],
      ["Grounding","Messa a terra, bonding e equipotenzialità sono critici per sicurezza, EMC e affidabilità RF."],
      ["Thermal","Densità rack, airflow, hot/cold aisle, sensori e derating influenzano disponibilità apparati."],
      ["SNMP/Telemetry","PDU, UPS e sensori ambientali devono alimentare NOC e correlazione eventi."]
    ],
    "formulas":["P = V · I · PF","Runtime_UPS ≈ Energy_available / Load","ΔT ∝ Power_dissipated / airflow","Redundancy = N+1 / 2N policy"],
    "checklist":["Rack topology","PDU load map","UPS runtime","-48V DC plant","Grounding/EMC checklist","SNMP polling dashboard"]
  },
  {
    "file":"trfmc_cyber_rf_intelligence_evidence_v1.html",
    "id":"cyber_rf_intelligence",
    "area":"11_Cyber_RF_Intelligence",
    "title":"Cyber RF Intelligence / Evidence Lab",
    "subtitle":"spectrum anomaly · rogue RF · jamming simulation · evidence · correlation",
    "kpis":["Anomaly","Rogue RF","Evidence","Correlation"],
    "theory":[
      ["Spectrum anomaly","Deviazioni rispetto al baseline: occupazione anomala, emissioni spurie, potenze inattese, pattern temporali."],
      ["Rogue RF","Trasmettitori non autorizzati o configurazioni errate rilevate tramite spettro, fingerprint e localizzazione."],
      ["Jamming simulation","Solo scenari controllati/lab: analisi impatto su SNR, BER, BLER, throughput e disponibilità."],
      ["Evidence chain","PCAP, IQ capture, screenshot strumenti, log e timestamp devono essere correlati e preservati."]
    ],
    "formulas":["AnomalyScore = distance(current_features, baseline_features)","J/S = Pjammer - Psignal","Evidence = IQ + PCAP + logs + clock + operator_note","Confidence = sensors_agreement · quality_score"],
    "checklist":["Baseline spettro","Anomaly detector","Evidence pack","Timeline eventi","Correlazione RF/protocollo/log","Report tecnico"]
  },
  {
    "file":"trfmc_knowledge_base_theory_procedures_v1.html",
    "id":"knowledge_base",
    "area":"12_Knowledge_Base",
    "title":"Knowledge Base / Theory / Procedures Atlas",
    "subtitle":"glossario · formule · procedure · troubleshooting · lesson plan",
    "kpis":["Glossary","Formulas","Procedures","Lessons"],
    "theory":[
      ["Glossario tecnico","RF, DSP, 5G Core, RAN, fronthaul, cybersecurity, metrologia e infrastruttura."],
      ["Formula book","Link budget, FFT, EVM, BER, VSWR, return loss, Fresnel, OTDR, QoS e power budget."],
      ["Procedure operative","Start/stop portale, health check, backup, quality gate, registry, promozione moduli."],
      ["Lesson plan","Moduli didattici progressivi: teoria, simulazione, misura, evidenza, report."]
    ],
    "formulas":["VSWR=(1+|Γ|)/(1-|Γ|)","EVM(%) = RMS(error)/RMS(reference)·100","FSPL=32.44+20logf+20logd","FFT_bin = Fs/N"],
    "checklist":["Glossario versionato","Procedure passo-passo","Troubleshooting tree","Template report","Checklist docente/studente"]
  }
]

def esc(x):
    return html.escape(str(x), quote=True)

def page_html(m):
    theory_cards = "\n".join([
        f"<div class='leaf-card'><h3>{esc(t)}</h3><p>{esc(d)}</p></div>"
        for t,d in m["theory"]
    ])
    formula_rows = "\n".join([
        f"<tr><td>F{i+1}</td><td><div class='leaf-formula'>{esc(f)}</div></td></tr>"
        for i,f in enumerate(m["formulas"])
    ])
    checklist = "\n".join([f"<li>{esc(x)}</li>" for x in m["checklist"]])
    kpis = "".join([f"<div class='leaf-kpi'><small>KPI</small><b>{esc(k)}</b></div>" for k in m["kpis"]])

    return f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(m['title'])}</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<script defer src="/assets/trfmc_design_system/trfmc_leaf_webgl_v1.js"></script>
</head>
<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">{esc(m['title'])}</div>
    <div class="leaf-sub">{esc(m['subtitle'])}</div>
  </div>
  <div class="leaf-kpis">{kpis}</div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="leaf-layout">
  <aside class="leaf-panel">
    <h2>Teoria / Modello</h2>
    <div class="leaf-scroll">
      {theory_cards}
    </div>
  </aside>

  <main class="leaf-panel leaf-stage">
    <canvas class="leaf-canvas" data-trfmc-webgl></canvas>
    <div class="leaf-overlay">
      <div class="leaf-stage-head">
        <div class="leaf-stage-title">{esc(m['area'])}</div>
        <div class="leaf-stage-sub">Leaf module operativo. Nessun iframe. Nessuna CDN. Nessuna shell parallela.</div>
      </div>
      <div></div>
      <div class="leaf-stage-foot">
        <div>Render: <span class="leaf-ok" data-gl-state>init</span></div>
        <div>Mode: leaf</div>
        <div>Shell: V6R3 locked</div>
        <div>Registry: active</div>
        <div>Quality: required</div>
      </div>
    </div>
  </main>

  <aside class="leaf-panel">
    <h2>Formule / Checklist</h2>
    <div class="leaf-scroll">
      <div class="leaf-card">
        <h3>Formula Book</h3>
        <table class="leaf-table">
          <thead><tr><th>ID</th><th>Formula</th></tr></thead>
          <tbody>{formula_rows}</tbody>
        </table>
      </div>

      <div class="leaf-card">
        <h3>Da implementare / collegare</h3>
        <ul>{checklist}</ul>
      </div>

      <div class="leaf-card">
        <h3>Regola di integrazione</h3>
        <p>Questo modulo entra nel portale solo come leaf page registrata. Non introduce navbar globali, iframe, CDN o shell alternative.</p>
        <span class="leaf-badge leaf-ok">NO IFRAME</span>
        <span class="leaf-badge leaf-ok">NO CDN</span>
        <span class="leaf-badge leaf-ok">REGISTRY</span>
      </div>
    </div>
  </aside>
</div>
</body>
</html>
"""

for m in modules:
    (public / m["file"]).write_text(page_html(m), encoding="utf-8")

hub_cards = "\n".join([
    f"""<div class="leaf-card">
<h3>{esc(m['area'])}</h3>
<p><b>{esc(m['title'])}</b></p>
<p>{esc(m['subtitle'])}</p>
<a class="leaf-btn" href="/{esc(m['file'])}">Apri modulo</a>
<span class="leaf-badge leaf-ok">LEAF</span>
</div>"""
    for m in modules
])

hub = f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Expansion Hub V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<script defer src="/assets/trfmc_design_system/trfmc_leaf_webgl_v1.js"></script>
</head>
<body class="trfmc-leaf">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Expansion Hub V1</div>
    <div class="leaf-sub">Nuove strutture leaf: teoria, RF, Microwave, Fiber, Private Networks, Data Center, Cyber RF, Knowledge Base</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>Modules</small><b>{len(modules)}</b></div>
    <div class="leaf-kpi"><small>Iframe</small><b>0</b></div>
    <div class="leaf-kpi"><small>CDN</small><b>0</b></div>
    <div class="leaf-kpi"><small>Shell</small><b>V6R3</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="leaf-layout">
  <aside class="leaf-panel">
    <h2>Policy</h2>
    <div class="leaf-scroll">
      <div class="leaf-card">
        <h3>Metodo</h3>
        <p>Questo hub non è una nuova shell. È un indice tecnico delle nuove pagine leaf create per completare il portale.</p>
        <span class="leaf-badge leaf-ok">NO IFRAME</span>
        <span class="leaf-badge leaf-ok">NO CDN</span>
        <span class="leaf-badge leaf-ok">NO DOPPIA BAR</span>
      </div>
      <div class="leaf-card">
        <h3>Catena di qualità</h3>
        <p>Snapshot, registry, HTTP test, content test, controllo iframe/CDN, freeze se PASS.</p>
      </div>
    </div>
  </aside>

  <main class="leaf-panel leaf-stage">
    <canvas class="leaf-canvas" data-trfmc-webgl></canvas>
    <div class="leaf-overlay">
      <div class="leaf-stage-head">
        <div class="leaf-stage-title">Expansion Layer</div>
        <div class="leaf-stage-sub">Struttura controllata per completare il portale senza sporcare V6R3.</div>
      </div>
      <div></div>
      <div class="leaf-stage-foot">
        <div>Render: <span class="leaf-ok" data-gl-state>init</span></div>
        <div>Modules: {len(modules)}</div>
        <div>Mode: leaf</div>
        <div>Registry: patched</div>
        <div>V6R3: locked</div>
      </div>
    </div>
  </main>

  <aside class="leaf-panel">
    <h2>Nuovi moduli</h2>
    <div class="leaf-scroll">{hub_cards}</div>
  </aside>
</div>
</body>
</html>
"""
(public / "trfmc_expansion_hub_v1.html").write_text(hub, encoding="utf-8")

manifest = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "policy": "Expansion modules are leaf pages. V6R3 remains official shell. No iframe. No CDN.",
    "hub": "/trfmc_expansion_hub_v1.html",
    "modules": [
        {
            "id": m["id"],
            "area": m["area"],
            "title": m["title"],
            "url": "/" + m["file"],
            "class": "leaf_operational_candidate",
            "webgl": True,
            "core_api": False
        } for m in modules
    ]
}
(public / "trfmc_expansion_modules_v1.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps({"created_pages": len(modules)+1, "hub": manifest["hub"]}, indent=2))
PY

echo
echo "[6/9] Aggiorno registry unico in modo controllato"
python3 - <<'PY'
import json, re
from pathlib import Path
from datetime import datetime, timezone

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
public = base / "frontend/public"
reg_path = public / "trfmc_portal_registry_unified.json"
exp_path = public / "trfmc_expansion_modules_v1.json"

reg = json.loads(reg_path.read_text(encoding="utf-8"))
exp = json.loads(exp_path.read_text(encoding="utf-8"))

pages = reg.get("pages", [])
by_url = {p.get("url"): p for p in pages if p.get("url")}

def refs_count(txt):
    return len(re.findall(r'href=|src=', txt, re.I))

new_entries = []

hub_file = public / "trfmc_expansion_hub_v1.html"
hub_txt = hub_file.read_text(encoding="utf-8", errors="ignore")
new_entries.append({
    "class": "service",
    "name": "trfmc_expansion_hub_v1.html",
    "url": "/trfmc_expansion_hub_v1.html",
    "size": hub_file.stat().st_size,
    "webgl": True,
    "core_api": False,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": refs_count(hub_txt)
})

for m in exp["modules"]:
    p = public / m["url"].lstrip("/")
    txt = p.read_text(encoding="utf-8", errors="ignore")
    new_entries.append({
        "class": m["class"],
        "name": p.name,
        "url": m["url"],
        "size": p.stat().st_size,
        "webgl": True,
        "core_api": False,
        "has_iframe": False,
        "external_refs": 0,
        "refs_count": refs_count(txt)
    })

for entry in new_entries:
    by_url[entry["url"]] = entry

reg["pages"] = list(by_url.values())

counts = {}
for p in reg["pages"]:
    c = p.get("class", "unknown")
    counts[c] = counts.get(c, 0) + 1
counts["total_html"] = len(reg["pages"])

# garantisco le chiavi storiche
for k in ["official_shell","service","leaf_operational_candidate","shell_or_legacy_container","orphan_or_legacy_candidate"]:
    counts.setdefault(k, 0)

reg["counts"] = counts
reg["last_expansion_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "source": "/trfmc_expansion_modules_v1.json",
    "added_or_updated": len(new_entries),
    "policy": "leaf modules only; no iframe; no CDN; V6R3 unchanged"
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(reg["last_expansion_update"], indent=2, ensure_ascii=False))
print(json.dumps(reg["counts"], indent=2, ensure_ascii=False))
PY

echo
echo "[7/9] Quality gate robusto"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_expansion_hub_v1.html \
    /trfmc_expansion_modules_v1.json \
    /assets/trfmc_design_system/trfmc_leaf_master_v1.css \
    /assets/trfmc_design_system/trfmc_leaf_webgl_v1.js \
    /trfmc_rf_physics_theory_atlas_v1.html \
    /trfmc_microwave_link_operations_center_v1.html \
    /trfmc_fiber_fronthaul_otdr_workbench_v1.html \
    /trfmc_private_networks_wifi7_5g_mesh_v1.html \
    /trfmc_antenna_rru_ret_cpri_port_mapping_v1.html \
    /trfmc_datacenter_power_pdu_infrastructure_v1.html \
    /trfmc_cyber_rf_intelligence_evidence_v1.html \
    /trfmc_knowledge_base_theory_procedures_v1.html \
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

grep -RInEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$PUBLIC/trfmc_expansion_hub_v1.html" \
  "$PUBLIC"/trfmc_*_v1.html \
  "$ASSETS/trfmc_leaf_master_v1.css" \
  "$ASSETS/trfmc_leaf_webgl_v1.js" \
  > "$OUT/external_refs.txt" 2>/dev/null || true

grep -RInEi '<iframe' \
  "$PUBLIC/trfmc_expansion_hub_v1.html" \
  "$PUBLIC"/trfmc_*_v1.html \
  > "$OUT/iframe_refs.txt" 2>/dev/null || true

grep -RInEi 'MASTER FUSED|trfmc_master_fused|fallback shell' \
  "$PUBLIC/trfmc_expansion_hub_v1.html" \
  "$PUBLIC"/trfmc_*_v1.html \
  "$PUBLIC/trfmc_expansion_modules_v1.json" \
  > "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true

V6R3_SHA_AFTER="$(sha256sum "$V6R3" | awk '{print $1}')"
CONTROL_SHA_AFTER="$(sha256sum "$CONTROL" | awk '{print $1}')"
REG_SHA_AFTER="$(sha256sum "$REG" | awk '{print $1}')"

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$V6R3_SHA_AFTER"
  echo "CONTROL_SHA_AFTER=$CONTROL_SHA_AFTER"
  echo "REG_SHA_AFTER=$REG_SHA_AFTER"
} > "$OUT/sha_compare.txt"

echo
echo "[8/9] Summary"
python3 - "$BASE" "$OUT" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

base = Path(sys.argv[1])
out = Path(sys.argv[2])
public = base / "frontend/public"

http = []
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 3:
        http.append({"url": p[0], "status": p[1], "bytes": p[2]})

non200 = sum(1 for x in http if x["status"] != "200")
external = sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe = sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fused = sum(1 for x in (out/"fused_forbidden_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

sha = {}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v = line.strip().split("=",1)
        sha[k]=v

protected_ok = (
    sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER") and
    sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
)

registry_changed = sha.get("REG_SHA_BEFORE") != sha.get("REG_SHA_AFTER")

exp = json.loads((public/"trfmc_expansion_modules_v1.json").read_text())
reg = json.loads((public/"trfmc_portal_registry_unified.json").read_text())

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "hub": "http://127.0.0.1:5173/trfmc_expansion_hub_v1.html",
    "manifest": "http://127.0.0.1:5173/trfmc_expansion_modules_v1.json",
    "created_modules": len(exp["modules"]),
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_leaf_operational_candidate": reg.get("counts",{}).get("leaf_operational_candidate"),
    "http_non_200": non200,
    "external_refs": external,
    "iframe_refs": iframe,
    "fused_forbidden_refs": fused,
    "protected_v6r3_and_control_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "result": "PASS" if non200 == 0 and external == 0 and iframe == 0 and fused == 0 and protected_ok and registry_changed else "WARN",
    "policy": "Expansion modules are leaf pages. V6R3 and official Control Room unchanged. Registry updated intentionally."
}
(out/"summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
(out/"result.flag").write_text(data["result"] + "\n")
print(json.dumps(data, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[9/9] Freeze se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_EXPANSION_MODULES_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_rf_physics_theory_atlas_v1.html \
    frontend/public/trfmc_microwave_link_operations_center_v1.html \
    frontend/public/trfmc_fiber_fronthaul_otdr_workbench_v1.html \
    frontend/public/trfmc_private_networks_wifi7_5g_mesh_v1.html \
    frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html \
    frontend/public/trfmc_datacenter_power_pdu_infrastructure_v1.html \
    frontend/public/trfmc_cyber_rf_intelligence_evidence_v1.html \
    frontend/public/trfmc_knowledge_base_theory_procedures_v1.html \
    frontend/public/assets/trfmc_design_system/trfmc_leaf_master_v1.css \
    frontend/public/assets/trfmc_design_system/trfmc_leaf_webgl_v1.js \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_expansion_modules_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
echo "RISULTATO"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_expansion_hub_v1.html"
echo "============================================================"
