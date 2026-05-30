#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets"

mkdir -p "$ASSETS"

cat > "$ASSETS/trfmc_global_top_telemetry_v2.css" <<'CSS'
/* ============================================================
   TRFMC GLOBAL TOP TELEMETRY STRIP V2
   Unified instrument top strip for Antenna / DSP / Wi-Fi / 5G / NOC
   ============================================================ */

:root{
  --gtt-bg:#02070f;
  --gtt-panel:#061120;
  --gtt-line:#1d6f9f;
  --gtt-text:#eaf3ff;
  --gtt-muted:#86a7c6;
  --gtt-cyan:#00d9ff;
  --gtt-green:#7dff4f;
  --gtt-yellow:#ffd500;
  --gtt-red:#ff3366;
  --gtt-blue:#268cff;
}

body.trfmc-gtt-ready{
  --gtt-header-h:54px;
  --gtt-strip-h:70px;
}

body.trfmc-gtt-ready .trfmc-gtt-strip{
  height:var(--gtt-strip-h);
  border-bottom:1px solid rgba(0,217,255,.45);
  border-top:1px solid rgba(0,217,255,.20);
  background:
    linear-gradient(90deg,rgba(0,16,28,.98),rgba(6,26,44,.99),rgba(0,16,28,.98)),
    radial-gradient(circle at 20% 0%,rgba(0,217,255,.12),transparent 38%),
    radial-gradient(circle at 80% 0%,rgba(125,255,79,.09),transparent 38%);
  display:grid;
  grid-template-columns:220px repeat(12,1fr) 280px;
  gap:5px;
  padding:6px;
  box-shadow:0 0 26px rgba(0,217,255,.08), inset 0 1px 0 rgba(255,255,255,.05);
  color:var(--gtt-text);
  font:12px Inter,Segoe UI,system-ui,sans-serif;
  z-index:9000;
}

body.trfmc-gtt-ready main{
  height:calc(100vh - var(--gtt-header-h) - var(--gtt-strip-h)) !important;
}

.trfmc-gtt-id{
  border:1px solid rgba(36,91,125,.95);
  background:linear-gradient(180deg,#09223a,#06111f);
  border-radius:5px;
  padding:6px 8px;
  overflow:hidden;
}

.trfmc-gtt-id span{
  color:var(--gtt-muted);
  display:block;
  font-size:9px;
  text-transform:uppercase;
}

.trfmc-gtt-id b{
  color:var(--gtt-cyan);
  display:block;
  font-size:14px;
  letter-spacing:.04em;
  white-space:nowrap;
}

.trfmc-gtt-id em{
  color:var(--gtt-green);
  display:block;
  font-style:normal;
  font-size:9px;
  white-space:nowrap;
}

.trfmc-gtt-cell{
  border:1px solid rgba(36,91,125,.95);
  background:linear-gradient(180deg,#091b2e,#07111f);
  border-radius:5px;
  padding:5px 6px;
  min-width:0;
  box-shadow:inset 0 1px 0 rgba(255,255,255,.04);
}

.trfmc-gtt-cell span{
  display:block;
  color:var(--gtt-muted);
  font-size:8px;
  letter-spacing:.04em;
  text-transform:uppercase;
}

.trfmc-gtt-cell b{
  color:var(--gtt-text);
  display:block;
  font-size:15px;
  line-height:1.15;
  overflow:hidden;
  text-overflow:ellipsis;
  white-space:nowrap;
}

.trfmc-gtt-cell em{
  color:var(--gtt-green);
  display:block;
  font-style:normal;
  font-size:9px;
  overflow:hidden;
  text-overflow:ellipsis;
  white-space:nowrap;
}

.trfmc-gtt-cell.warn em,
.trfmc-gtt-cell.warn b{
  color:var(--gtt-yellow);
}

.trfmc-gtt-cell.fail em,
.trfmc-gtt-cell.fail b{
  color:var(--gtt-red);
}

.trfmc-gtt-actions{
  border:1px solid rgba(36,91,125,.95);
  background:linear-gradient(180deg,#091b2e,#07111f);
  border-radius:5px;
  padding:5px;
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:4px;
}

.trfmc-gtt-actions button{
  background:#10233a;
  border:1px solid #285d82;
  color:var(--gtt-text);
  border-radius:4px;
  padding:4px 5px;
  font-size:10px;
  cursor:pointer;
}

.trfmc-gtt-actions button:hover{
  background:#145078;
  border-color:var(--gtt-cyan);
  box-shadow:inset 3px 0 0 var(--gtt-yellow);
}

.trfmc-gtt-miniwave{
  position:absolute;
  left:8px;
  right:8px;
  bottom:3px;
  height:14px;
  opacity:.55;
  pointer-events:none;
}

.trfmc-gtt-strip-wrap{
  position:relative;
}

body.trfmc-gtt-dense .trfmc-gtt-strip{
  height:54px;
  --gtt-strip-h:54px;
}

body.trfmc-gtt-dense .trfmc-gtt-cell em,
body.trfmc-gtt-dense .trfmc-gtt-id em{
  display:none;
}

body.trfmc-gtt-hidden .trfmc-gtt-strip{
  display:none !important;
}

body.trfmc-gtt-hidden main{
  height:calc(100vh - var(--gtt-header-h)) !important;
}

@media(max-width:1500px){
  body.trfmc-gtt-ready .trfmc-gtt-strip{
    grid-template-columns:180px repeat(6,1fr) 210px;
    height:auto;
  }
  .trfmc-gtt-cell:nth-of-type(n+8){
    display:none;
  }
}

@media(max-width:1100px){
  body.trfmc-gtt-ready .trfmc-gtt-strip{
    grid-template-columns:1fr 1fr;
  }
  .trfmc-gtt-actions{
    grid-column:1/-1;
  }
}
CSS

cat > "$ASSETS/trfmc_global_top_telemetry_v2.js" <<'JS'
/* ============================================================
   TRFMC GLOBAL TOP TELEMETRY STRIP V2
   ============================================================ */
(function(){
  const KEY = "trfmc_global_top_telemetry_v2";

  const state = {
    dense:false,
    hidden:false,
    quality:"PASS",
    tick:0,
    lastAction:"BOOT"
  };

  function el(id){ return document.getElementById(id); }

  function classify(){
    const p = location.pathname.toLowerCase();
    if(p.includes("antenna")) return {domain:"ANTENNA", sub:"RRU/BBU · RET/AISG · MIMO"};
    if(p.includes("wifi") || p.includes("qam")) return {domain:"WIFI/QAM", sub:"802.11ax/be/bn · OFDMA · 4096-QAM"};
    if(p.includes("dsp") || p.includes("measurement_chain")) return {domain:"DSP", sub:"Receiver Chain · RBW/VBW · FFT"};
    if(p.includes("core") || p.includes("aka") || p.includes("ran")) return {domain:"5G CORE", sub:"Open5GS · UERANSIM · SUPI/SUCI · AKA"};
    if(p.includes("noc")) return {domain:"NOC", sub:"RF/5G Operational Center"};
    if(p.includes("war_room")) return {domain:"RF/TM", sub:"War Room · Evidence · Signals"};
    if(p.includes("master")) return {domain:"MASTER", sub:"TRFMC Mission Control"};
    return {domain:"TRFMC", sub:"RF/Telco/Cyber Instrument OS"};
  }

  function valueOf(id, fallback){
    const x = el(id);
    if(!x) return fallback;
    if(x.tagName === "SELECT"){
      return x.options[x.selectedIndex]?.text || x.value || fallback;
    }
    if(x.type === "range" || x.type === "number" || x.type === "text"){
      return x.value || fallback;
    }
    return x.textContent || fallback;
  }

  function numeric(id, fallback){
    const v = parseFloat(valueOf(id, fallback));
    return Number.isFinite(v) ? v : fallback;
  }

  function inferTelemetry(){
    const c = classify();

    let center = numeric("freq", null);
    let bw = numeric("bw", null);
    let rbw = numeric("rbw", null);
    let vbw = numeric("vbw", null);
    let gain = numeric("gain", null);
    let vswr = numeric("vswr", null);
    if(vswr && vswr > 20) vswr = vswr/100;

    const snr = numeric("snr", null);
    const evmText = el("kevm")?.textContent || "";
    const evm = parseFloat(evmText) || null;

    if(center === null){
      if(c.domain === "WIFI/QAM") center = numeric("cf", 5975);
      else if(c.domain === "5G CORE") center = 3500;
      else if(c.domain === "DSP") center = 1000;
      else center = 3500;
    }

    if(bw === null){
      if(c.domain === "WIFI/QAM") bw = numeric("bw", 320);
      else if(c.domain === "5G CORE") bw = 100;
      else if(c.domain === "DSP") bw = 20;
      else bw = 100;
    }

    if(rbw === null) rbw = c.domain === "DSP" ? 100 : c.domain === "WIFI/QAM" ? 1000 : 100;
    if(vbw === null) vbw = rbw/3;

    let mod = "OFDM";
    if(c.domain === "WIFI/QAM") mod = valueOf("mod", "4096-QAM");
    if(c.domain === "5G CORE") mod = "5G NR / NAS";
    if(c.domain === "ANTENNA") mod = valueOf("service", "n78 / TDD");
    if(c.domain === "DSP") mod = valueOf("detector", "Peak");

    let quality = "PASS";
    let qClass = "";
    if(vswr !== null && vswr > 2.1) { quality = "FAIL"; qClass = "fail"; }
    else if(vswr !== null && vswr > 1.7) { quality = "WARN"; qClass = "warn"; }

    if(evm !== null && evm > 4) { quality = "WARN"; qClass = "warn"; }
    if(snr !== null && snr < 18) { quality = "WARN"; qClass = "warn"; }

    state.quality = quality;

    const jitter = Math.sin(state.tick/28);
    const ref = c.domain === "DSP" ? "-60 dBm" : c.domain === "WIFI/QAM" ? "-30 dBm" : "-10 dBm";
    const att = c.domain === "DSP" ? valueOf("att","10") + " dB" : "10 dB";

    return {
      domain:c.domain,
      sub:c.sub,
      center:center >= 1000 ? (center/1000).toFixed(3)+" GHz" : center.toFixed(0)+" MHz",
      span:bw+" MHz",
      rbw:rbw+" kHz",
      vbw:Math.max(1,Math.round(vbw))+" kHz",
      ref,
      att,
      gain:gain !== null ? gain.toFixed(1)+" dB" : (18 + jitter).toFixed(1)+" dB",
      snr:snr !== null ? snr.toFixed(1)+" dB" : (42 + jitter*2).toFixed(1)+" dB",
      evm:evm !== null ? evm.toFixed(1)+"%" : (1.2 + Math.abs(jitter)*.4).toFixed(1)+"%",
      mod,
      trigger: "AUTO",
      sync: "LOCKED",
      runtime: "5173",
      qClass
    };
  }

  function createCell(label, id){
    return `
      <div class="trfmc-gtt-cell" id="gttCell_${id}">
        <span>${label}</span>
        <b id="gtt_${id}">--</b>
        <em id="gtt_${id}_sub">--</em>
      </div>
    `;
  }

  function inject(){
    if(el("trfmcGttStrip")) return;

    const header = document.querySelector("header");
    const main = document.querySelector("main");

    const wrap = document.createElement("div");
    wrap.id = "trfmcGttStrip";
    wrap.className = "trfmc-gtt-strip trfmc-gtt-strip-wrap";
    wrap.innerHTML = `
      <div class="trfmc-gtt-id">
        <span>Instrument Domain</span>
        <b id="gtt_domain">TRFMC</b>
        <em id="gtt_domain_sub">RF/Telco/Cyber</em>
      </div>
      ${createCell("Center", "center")}
      ${createCell("Span/BW", "span")}
      ${createCell("RBW", "rbw")}
      ${createCell("VBW", "vbw")}
      ${createCell("Ref Level", "ref")}
      ${createCell("Att", "att")}
      ${createCell("Gain", "gain")}
      ${createCell("SNR", "snr")}
      ${createCell("EVM", "evm")}
      ${createCell("Modulation", "mod")}
      ${createCell("Sync", "sync")}
      ${createCell("Quality", "quality")}
      <div class="trfmc-gtt-actions">
        <button onclick="TRFMC_GTT.presetLab()">Lab Preset</button>
        <button onclick="TRFMC_GTT.toggleDense()">Dense</button>
        <button onclick="TRFMC_GTT.toggleStrip()">Hide</button>
        <button onclick="TRFMC_GTT.nativeAction()">Native</button>
        <button onclick="TRFMC_GTT.focus()">Focus</button>
        <button onclick="TRFMC_GTT.reset()">Reset</button>
      </div>
      <canvas id="gttMiniWave" class="trfmc-gtt-miniwave" width="900" height="22"></canvas>
    `;

    if(header && header.parentNode){
      header.insertAdjacentElement("afterend", wrap);
    }else if(main && main.parentNode){
      main.parentNode.insertBefore(wrap, main);
    }else{
      document.body.insertBefore(wrap, document.body.firstChild);
    }

    document.body.classList.add("trfmc-gtt-ready");
  }

  function setText(id, main, sub, cls){
    const a = el("gtt_"+id);
    const b = el("gtt_"+id+"_sub");
    const cell = el("gttCell_"+id);
    if(a) a.textContent = main;
    if(b) b.textContent = sub || "";
    if(cell){
      cell.classList.remove("warn","fail");
      if(cls) cell.classList.add(cls);
    }
  }

  function update(){
    state.tick++;
    const t = inferTelemetry();

    if(el("gtt_domain")) el("gtt_domain").textContent = t.domain;
    if(el("gtt_domain_sub")) el("gtt_domain_sub").textContent = t.sub;

    setText("center", t.center, "carrier / RF center");
    setText("span", t.span, "analysis bandwidth");
    setText("rbw", t.rbw, "resolution BW");
    setText("vbw", t.vbw, "video / smoothing");
    setText("ref", t.ref, "display ref");
    setText("att", t.att, "input attenuation");
    setText("gain", t.gain, "front-end gain");
    setText("snr", t.snr, "signal/noise", t.snr.includes("-") ? "warn" : "");
    setText("evm", t.evm, "vector error");
    setText("mod", t.mod, "test/model");
    setText("sync", t.sync, "ref / timing");
    setText("quality", state.quality, "gate", t.qClass);

    drawMiniWave(t);
    requestAnimationFrame(update);
  }

  function drawMiniWave(t){
    const c = el("gttMiniWave");
    if(!c) return;
    const x = c.getContext("2d");
    const w = c.width;
    const h = c.height;
    x.clearRect(0,0,w,h);

    x.strokeStyle = "rgba(120,190,240,.18)";
    x.beginPath();
    x.moveTo(0,h/2);
    x.lineTo(w,h/2);
    x.stroke();

    const colors = {
      "ANTENNA":"#7dff4f",
      "DSP":"#00d9ff",
      "WIFI/QAM":"#ffd500",
      "5G CORE":"#c66bff",
      "NOC":"#ff9e3d",
      "MASTER":"#00d9ff"
    };

    x.beginPath();
    for(let i=0;i<w;i++){
      const y = h/2
        + Math.sin((i + state.tick*3)*0.035)*5
        + Math.sin((i + state.tick)*0.011)*3;
      i ? x.lineTo(i,y) : x.moveTo(i,y);
    }
    x.strokeStyle = colors[t.domain] || "#00d9ff";
    x.lineWidth = 1.5;
    x.stroke();
  }

  function presetLab(){
    const d = classify().domain;

    function set(id,val){
      const e = el(id);
      if(!e) return;
      e.value = val;
      e.dispatchEvent(new Event("input",{bubbles:true}));
    }

    if(d === "ANTENNA"){
      set("freq",3500); set("gain",18); set("az",0); set("tilt",4);
      set("vswr",130); set("rl",20); set("iso",32); set("ptx",24);
    }

    if(d === "WIFI/QAM"){
      set("cf",5975); set("bw",320); set("snr",42); set("iqi",1);
      const mod = el("mod"); if(mod){mod.value="4096-QAM";mod.dispatchEvent(new Event("input",{bubbles:true}));}
    }

    if(d === "DSP"){
      set("snr",45);
      set("att",10);
    }

    if(window.TRFMC_V16 && typeof window.TRFMC_V16.restoreGold === "function"){
      window.TRFMC_V16.restoreGold();
    }

    log("lab preset applied for " + d);
  }

  function log(msg){
    state.lastAction = msg;
    try{
      if(typeof addLog === "function") addLog("GTT · " + msg);
    }catch(e){}
  }

  function toggleDense(){
    state.dense = !state.dense;
    document.body.classList.toggle("trfmc-gtt-dense", state.dense);
    localStorage.setItem(KEY, JSON.stringify(state));
    log(state.dense ? "dense strip enabled" : "dense strip disabled");
  }

  function toggleStrip(){
    state.hidden = !state.hidden;
    document.body.classList.toggle("trfmc-gtt-hidden", state.hidden);
    localStorage.setItem(KEY, JSON.stringify(state));
    log(state.hidden ? "top strip hidden" : "top strip visible");
  }

  function nativeAction(){
    if(window.TRFMC_GIS && typeof window.TRFMC_GIS.runPageAction === "function"){
      window.TRFMC_GIS.runPageAction();
      return;
    }
    if(window.TRFMC_IC && typeof window.TRFMC_IC.runSequence === "function"){
      window.TRFMC_IC.runSequence();
      return;
    }
    log("no native action available");
  }

  function focus(){
    if(window.TRFMC_GIS && typeof window.TRFMC_GIS.setMode === "function"){
      window.TRFMC_GIS.setMode("focus");
      return;
    }
    document.body.classList.toggle("trfmc-gtt-dense", true);
    log("local focus fallback");
  }

  function reset(){
    state.dense = false;
    state.hidden = false;
    document.body.classList.remove("trfmc-gtt-dense","trfmc-gtt-hidden");
    if(window.TRFMC_GIS && typeof window.TRFMC_GIS.reset === "function"){
      window.TRFMC_GIS.reset();
    }
    localStorage.setItem(KEY, JSON.stringify(state));
    log("top telemetry reset");
  }

  function restore(){
    const raw = localStorage.getItem(KEY);
    if(raw){
      try{ Object.assign(state, JSON.parse(raw)); }catch(e){}
    }
    document.body.classList.toggle("trfmc-gtt-dense", state.dense);
    document.body.classList.toggle("trfmc-gtt-hidden", state.hidden);
  }

  window.TRFMC_GTT = {
    state,
    presetLab,
    toggleDense,
    toggleStrip,
    nativeAction,
    focus,
    reset
  };

  inject();
  restore();
  requestAnimationFrame(update);
})();
JS

python3 - <<'PY'
from pathlib import Path

public = Path("frontend/public")

targets = [
    "trfmc_master_console_v4.html",
    "trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html",
    "trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html",
    "trfmc_measurement_chain_dsp_engine_v3.html",
    "trfmc_wifi_5_6_7_8_qam_engine_v1.html",
    "trfmc_5g_core_ran_identity_aka_engine_v1.html",
    "trfmc_converged_rf_5g_noc_v1.html",
    "trfmc_rf_tm_war_room_v4.html",
    "trfmc_instrument_os_alignment_v1.html",
    "trfmc_enterprise_prime_portal_v1.html",
]

css_tag = '<link rel="stylesheet" href="/assets/trfmc_global_top_telemetry_v2.css">'
js_tag = '<script src="/assets/trfmc_global_top_telemetry_v2.js"></script>'

for name in targets:
    p = public / name
    if not p.exists():
        print("SKIP missing", p)
        continue

    s = p.read_text(errors="ignore")

    if "trfmc_global_top_telemetry_v2.css" not in s:
        if "</head>" in s:
            s = s.replace("</head>", css_tag + "\n</head>", 1)
        else:
            s = css_tag + "\n" + s

    if "trfmc_global_top_telemetry_v2.js" not in s:
        if "</body>" in s:
            s = s.replace("</body>", js_tag + "\n</body>", 1)
        else:
            s = s + "\n" + js_tag

    p.write_text(s)
    print("INJECTED GTT", p)
PY

echo
echo "=== HTTP CHECK GLOBAL TOP TELEMETRY V2 ==="
for url in \
  http://127.0.0.1:5173/assets/trfmc_global_top_telemetry_v2.css \
  http://127.0.0.1:5173/assets/trfmc_global_top_telemetry_v2.js \
  http://127.0.0.1:5173/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html \
  http://127.0.0.1:5173/trfmc_measurement_chain_dsp_engine_v3.html \
  http://127.0.0.1:5173/trfmc_wifi_5_6_7_8_qam_engine_v1.html \
  http://127.0.0.1:5173/trfmc_5g_core_ran_identity_aka_engine_v1.html \
  http://127.0.0.1:5173/trfmc_converged_rf_5g_noc_v1.html \
  http://127.0.0.1:5173/trfmc_master_console_v4.html \
  http://127.0.0.1:5173/api/health
do
  echo -n "$url -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "$url"
done

echo
echo "=== DISK ==="
df -h /
df -h /data/LABDATA
