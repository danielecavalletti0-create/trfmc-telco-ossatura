#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P7F_VISUAL_LAB_GRADE_TELCO_DASHBOARD_V1_$TS"

mkdir -p "$OUT"
cd "$BASE" || exit 1

DATA_SRC=""
if [ -f runtime/quality/latest_p7d_visual_enterprise_command_center_v1/visual_enterprise_dashboard_data.json ]; then
  DATA_SRC="runtime/quality/latest_p7d_visual_enterprise_command_center_v1/visual_enterprise_dashboard_data.json"
elif [ -f runtime/quality/latest_p7c_single_enterprise_telco_dashboard_v1/enterprise_telco_dashboard_data.json ]; then
  DATA_SRC="runtime/quality/latest_p7c_single_enterprise_telco_dashboard_v1/enterprise_telco_dashboard_data.json"
else
  DATA_SRC="$(find runtime/quality -path '*TRFMC_P7D_VISUAL_ENTERPRISE_COMMAND_CENTER_V1_*/*visual_enterprise_dashboard_data.json' -o -path '*TRFMC_P7C_SINGLE_ENTERPRISE_TELCO_DASHBOARD_V1_*/*enterprise_telco_dashboard_data.json' | sort | tail -n 1)"
fi

DASH="frontend/public/trfmc_visual_lab_grade_telco_dashboard_v1.html"
SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_visual_lab_grade.txt"
SCREEN="$OUT/visual_lab_grade_telco_dashboard_1920x1080.png"
NORMALIZED="$OUT/visual_lab_grade_data.json"

echo "============================================================"
echo "TRFMC_P7F_VISUAL_LAB_GRADE_TELCO_DASHBOARD_V1"
echo "Dashboard visuale RF/Telco lab-grade: una sola pagina, no React mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$DATA_SRC" ] || [ ! -f "$DATA_SRC" ]; then
  echo "ERRORE: data source P7D/P7C non trovato."
  exit 1
fi

python3 - "$DATA_SRC" "$DASH" "$NORMALIZED" <<'PY'
import json, sys
from pathlib import Path
from collections import defaultdict

src = Path(sys.argv[1])
dash = Path(sys.argv[2])
normalized = Path(sys.argv[3])

raw = json.loads(src.read_text(encoding="utf-8", errors="replace"))
pages = raw.get("pages", [])
areas = raw.get("areas", {})

def clean_page(p):
    return {
        "title": p.get("title") or p.get("file") or p.get("url") or "Untitled",
        "url": p.get("url") or "#",
        "category": p.get("category") or p.get("area") or p.get("theme") or "source",
        "canvas": int(p.get("canvas", 0) or 0),
        "scripts": int(p.get("scripts", 0) or 0),
        "bytes": int(p.get("bytes", 0) or 0),
    }

clean = [clean_page(p) for p in pages if isinstance(p.get("url",""), str) and p.get("url","").startswith("/")]

def contains(p, words):
    t = " ".join([p["title"], p["url"], p["category"]]).lower()
    return any(w in t for w in words)

buckets = {
    "rf": [p for p in clean if contains(p, ["rf", "microwave", "propagation", "smith", "fresnel", "link"])],
    "antenna": [p for p in clean if contains(p, ["antenna", "rru", "ret", "cpri", "aisg", "mimo", "beam", "pattern"])],
    "dsp": [p for p in clean if contains(p, ["dsp", "fft", "iq", "waterfall", "signal", "spectrum", "vsa"])],
    "core": [p for p in clean if contains(p, ["open5gs", "ueransim", "ngap", "pfcp", "gtp", "core", "ran", "supi", "suci"])],
    "ops": [p for p in clean if contains(p, ["mission", "dashboard", "war", "evidence", "alarm", "health", "control", "registry"])],
}
for key in buckets:
    buckets[key] = sorted(buckets[key], key=lambda x: (-x["canvas"], -x["scripts"], x["title"]))[:18]

data = {
    "pages": clean,
    "buckets": buckets,
    "kpi": {
        "sources": len(clean),
        "canvas": sum(p["canvas"] for p in clean),
        "scripts": sum(p["scripts"] for p in clean),
        "bytes": sum(p["bytes"] for p in clean),
    }
}
normalized.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
data_json = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")

html = r'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>TRFMC Visual Lab Grade Telco Dashboard</title>
<style>
:root{
  --bg:#020812;
  --panel:rgba(3,14,28,.86);
  --panel2:rgba(0,10,22,.92);
  --line:rgba(103,232,249,.22);
  --line2:rgba(134,239,172,.22);
  --text:#e8f7ff;
  --muted:#9fb8ca;
  --cyan:#67e8f9;
  --blue:#38bdf8;
  --green:#86efac;
  --amber:#fbbf24;
  --red:#fb7185;
  --violet:#c084fc;
}
*{box-sizing:border-box}
body{
  margin:0;
  color:var(--text);
  font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
  background:
    radial-gradient(circle at 12% 8%,rgba(14,165,233,.24),transparent 31%),
    radial-gradient(circle at 88% 4%,rgba(16,185,129,.17),transparent 30%),
    radial-gradient(circle at 50% 50%,rgba(192,132,252,.09),transparent 36%),
    linear-gradient(180deg,#020812,#020617 56%,#00040b);
  overflow-x:hidden;
}
#bgCanvas{
  position:fixed;
  inset:0;
  z-index:-4;
  opacity:.65;
}
body::before{
  content:"";
  position:fixed;
  inset:0;
  z-index:-3;
  background:
    linear-gradient(rgba(103,232,249,.045) 1px,transparent 1px),
    linear-gradient(90deg,rgba(103,232,249,.045) 1px,transparent 1px);
  background-size:42px 42px;
  mask-image:radial-gradient(circle at 50% 28%,black,transparent 80%);
}
.top-nav{
  position:sticky;
  top:0;
  z-index:100;
  display:flex;
  gap:8px;
  flex-wrap:wrap;
  align-items:center;
  padding:10px 22px;
  border-bottom:1px solid var(--line);
  background:rgba(2,8,18,.94);
  backdrop-filter:blur(18px);
}
.top-nav a,.top-nav button{
  border:1px solid rgba(103,232,249,.28);
  border-radius:999px;
  padding:8px 12px;
  color:var(--text);
  background:rgba(0,12,24,.72);
  text-decoration:none;
  font-size:12px;
  font-weight:950;
  cursor:pointer;
}
.top-nav a:hover,.top-nav button:hover{
  color:var(--green);
  border-color:rgba(134,239,172,.64);
  box-shadow:0 0 22px rgba(16,185,129,.15);
}
.shell{
  max-width:1920px;
  margin:0 auto;
  padding:18px 22px 42px;
}
.mission-header{
  display:grid;
  grid-template-columns:1fr auto;
  gap:18px;
  align-items:end;
  border:1px solid var(--line);
  border-radius:32px;
  padding:20px 22px;
  background:
    radial-gradient(circle at 86% 10%,rgba(103,232,249,.18),transparent 34%),
    linear-gradient(135deg,rgba(0,22,38,.92),rgba(0,7,16,.80));
  box-shadow:0 34px 130px rgba(0,0,0,.42);
}
.eyebrow{
  color:var(--cyan);
  font-size:11px;
  font-weight:950;
  letter-spacing:.16em;
  text-transform:uppercase;
}
h1{
  margin:8px 0 0;
  font-size:48px;
  line-height:.95;
  letter-spacing:-.06em;
}
.mission-header p{
  max-width:1120px;
  color:var(--muted);
  line-height:1.55;
  margin:14px 0 0;
}
.header-badges{
  display:grid;
  grid-template-columns:repeat(2,150px);
  gap:10px;
}
.badge{
  border:1px solid rgba(103,232,249,.18);
  border-radius:18px;
  padding:13px;
  background:rgba(0,9,20,.70);
}
.badge span{
  display:block;
  color:var(--muted);
  font-size:10px;
  font-weight:950;
  letter-spacing:.1em;
  text-transform:uppercase;
}
.badge strong{
  display:block;
  color:var(--green);
  font-size:26px;
  margin-top:5px;
}
.dashboard{
  display:grid;
  grid-template-columns:330px 1fr 410px;
  gap:14px;
  margin-top:14px;
  align-items:start;
}
.panel{
  border:1px solid var(--line);
  border-radius:28px;
  background:var(--panel);
  box-shadow:0 24px 95px rgba(0,0,0,.32);
}
.left-rail{
  padding:12px;
  position:sticky;
  top:64px;
}
.area-btn{
  width:100%;
  display:grid;
  grid-template-columns:42px 1fr auto;
  gap:10px;
  align-items:center;
  margin-bottom:8px;
  border:1px solid rgba(103,232,249,.15);
  border-radius:18px;
  padding:10px;
  color:inherit;
  background:rgba(0,9,20,.72);
  cursor:pointer;
  text-align:left;
}
.area-btn.active{
  border-color:rgba(134,239,172,.72);
  background:linear-gradient(135deg,rgba(8,47,38,.36),rgba(0,12,24,.76));
  box-shadow:0 0 30px rgba(16,185,129,.14);
}
.area-icon{
  width:40px;
  height:40px;
  display:flex;
  align-items:center;
  justify-content:center;
  border-radius:15px;
  background:rgba(103,232,249,.13);
  color:var(--cyan);
  font-weight:950;
}
.area-btn strong{
  display:block;
  font-size:13px;
}
.area-btn small{
  color:var(--muted);
  font-size:10px;
}
.area-count{
  color:var(--green);
  font-size:18px;
  font-weight:950;
}
.stage{
  padding:14px;
  min-height:760px;
}
.visual-grid{
  display:grid;
  grid-template-columns:1.15fr .85fr;
  gap:12px;
}
.visual-card{
  border:1px solid rgba(103,232,249,.15);
  border-radius:24px;
  background:rgba(0,8,18,.66);
  overflow:hidden;
  position:relative;
}
.visual-card .titlebar{
  display:flex;
  justify-content:space-between;
  gap:10px;
  align-items:center;
  padding:12px 14px;
  border-bottom:1px solid rgba(103,232,249,.10);
}
.visual-card h2,.visual-card h3{
  margin:0;
  letter-spacing:-.03em;
}
.status{
  color:var(--green);
  border:1px solid rgba(134,239,172,.28);
  border-radius:999px;
  padding:6px 9px;
  font-size:11px;
  font-weight:950;
  background:rgba(8,47,38,.18);
}
.rf-scene{
  height:420px;
  background:
    radial-gradient(circle at 52% 40%,rgba(103,232,249,.14),transparent 35%),
    linear-gradient(180deg,rgba(2,12,24,.55),rgba(0,4,10,.95));
  position:relative;
  overflow:hidden;
}
.skyline{
  position:absolute;
  left:0;
  right:0;
  bottom:0;
  height:122px;
  background:linear-gradient(180deg,transparent,rgba(0,0,0,.35));
}
.building{
  position:absolute;
  bottom:0;
  width:34px;
  background:linear-gradient(180deg,rgba(103,232,249,.12),rgba(103,232,249,.03));
  border:1px solid rgba(103,232,249,.08);
}
.tower{
  position:absolute;
  left:48%;
  bottom:66px;
  width:126px;
  height:270px;
  transform:translateX(-50%);
}
.tower::before,.tower::after{
  content:"";
  position:absolute;
  bottom:0;
  width:3px;
  height:240px;
  background:linear-gradient(var(--cyan),rgba(103,232,249,.15));
  transform-origin:bottom;
}
.tower::before{left:45px;transform:skewX(-12deg)}
.tower::after{right:45px;transform:skewX(12deg)}
.mast{
  position:absolute;
  left:61px;
  bottom:0;
  width:4px;
  height:270px;
  background:linear-gradient(#d8f8ff,rgba(103,232,249,.12));
  box-shadow:0 0 18px rgba(103,232,249,.28);
}
.cross{
  position:absolute;
  left:40px;
  width:46px;
  height:2px;
  background:rgba(103,232,249,.42);
}
.c1{bottom:70px}.c2{bottom:120px}.c3{bottom:170px}.c4{bottom:220px}
.panel-ant{
  position:absolute;
  width:16px;
  height:54px;
  border-radius:8px;
  background:linear-gradient(180deg,#e8f7ff,#6b879b);
  border:1px solid rgba(255,255,255,.55);
  box-shadow:0 0 24px rgba(103,232,249,.28);
}
.a1{left:72px;top:58px}.a2{left:40px;top:90px}.a3{left:78px;top:126px}
.beam{
  position:absolute;
  transform-origin:left center;
  width:440px;
  height:160px;
  left:53%;
  top:118px;
  background:linear-gradient(90deg,rgba(134,239,172,.50),rgba(134,239,172,.10),transparent);
  clip-path:polygon(0 45%,100% 0,100% 100%,0 55%);
  filter:blur(.2px);
  animation:pulse 2.8s ease-in-out infinite;
}
.beam.blue{
  top:182px;
  height:44px;
  background:linear-gradient(90deg,rgba(56,189,248,.70),rgba(56,189,248,.13),transparent);
  clip-path:polygon(0 40%,100% 35%,100% 65%,0 60%);
  animation-delay:.8s;
}
@keyframes pulse{50%{opacity:.58;transform:scaleX(.97)}}
.globe-widget{
  height:420px;
  position:relative;
  display:grid;
  place-items:center;
}
.globe{
  width:310px;
  height:310px;
  border-radius:50%;
  border:1px solid rgba(103,232,249,.24);
  background:
    radial-gradient(circle at 35% 30%,rgba(134,239,172,.20),transparent 28%),
    radial-gradient(circle at 55% 58%,rgba(103,232,249,.16),transparent 34%),
    rgba(0,8,18,.72);
  box-shadow:inset 0 0 50px rgba(103,232,249,.08),0 0 40px rgba(103,232,249,.08);
  position:relative;
  overflow:hidden;
}
.globe::before{
  content:"";
  position:absolute;
  inset:30px;
  border-radius:50%;
  border:1px dashed rgba(103,232,249,.20);
}
.globe::after{
  content:"";
  position:absolute;
  left:50%;
  top:-20%;
  width:1px;
  height:140%;
  background:rgba(103,232,249,.20);
  box-shadow:-70px 0 rgba(103,232,249,.12),70px 0 rgba(103,232,249,.12);
}
.geo-node{
  position:absolute;
  width:12px;
  height:12px;
  border-radius:50%;
  background:var(--green);
  box-shadow:0 0 18px var(--green);
}
.n1{left:43%;top:36%}.n2{left:62%;top:43%}.n3{left:51%;top:55%}.n4{left:36%;top:61%}.n5{left:70%;top:28%}
.lower-grid{
  display:grid;
  grid-template-columns:1fr 1fr 1fr;
  gap:12px;
  margin-top:12px;
}
.microstrip{
  height:260px;
  padding:14px;
}
.patch3d{
  position:relative;
  height:198px;
  border:1px solid rgba(103,232,249,.12);
  border-radius:18px;
  background:radial-gradient(circle at 55% 40%,rgba(103,232,249,.12),transparent 44%),rgba(0,8,18,.64);
  overflow:hidden;
}
.substrate,.ground,.patch{
  position:absolute;
  left:50%;
  transform:translateX(-50%) skewX(-16deg);
  border-radius:8px;
}
.ground{
  top:115px;
  width:220px;
  height:58px;
  background:linear-gradient(135deg,#5b341c,#c06b2c);
  box-shadow:0 18px 28px rgba(0,0,0,.35);
}
.substrate{
  top:82px;
  width:250px;
  height:70px;
  background:linear-gradient(135deg,#82907a,#d7e4d0);
}
.patch{
  top:52px;
  width:190px;
  height:58px;
  background:linear-gradient(135deg,#c06b2c,#ffb174);
  box-shadow:0 0 20px rgba(251,191,36,.15);
}
.feed{
  position:absolute;
  left:54%;
  top:115px;
  width:120px;
  height:10px;
  background:#d98235;
  transform:skewX(-16deg);
}
.sma{
  position:absolute;
  left:70%;
  top:108px;
  width:26px;
  height:26px;
  border-radius:50%;
  border:5px solid #fbbf24;
  background:#3b2411;
}
.spectrum{
  height:260px;
  padding:14px;
}
#spectrumCanvas,#radarCanvas{
  width:100%;
  height:198px;
  border:1px solid rgba(103,232,249,.12);
  border-radius:18px;
  background:rgba(0,8,18,.68);
}
.source-list{
  padding:14px;
  max-height:536px;
  overflow:auto;
}
.source-card{
  display:block;
  color:inherit;
  text-decoration:none;
  border:1px solid rgba(103,232,249,.13);
  border-radius:16px;
  padding:10px;
  margin-bottom:8px;
  background:rgba(0,8,18,.66);
}
.source-card:hover{
  border-color:rgba(134,239,172,.55);
  box-shadow:0 0 24px rgba(16,185,129,.10);
}
.source-card span{
  color:var(--cyan);
  font-size:9px;
  font-weight:950;
  letter-spacing:.1em;
  text-transform:uppercase;
}
.source-card strong{
  display:block;
  margin-top:4px;
  font-size:12px;
}
.source-card em{
  display:block;
  color:var(--muted);
  font-size:10px;
  margin-top:4px;
  font-style:normal;
  word-break:break-word;
}
.side{
  display:grid;
  gap:14px;
}
.side .panel{
  padding:14px;
}
.side h3{
  margin:0 0 10px;
  font-size:19px;
}
.health-row{
  display:grid;
  grid-template-columns:1fr auto;
  gap:8px;
  align-items:center;
  border:1px solid rgba(103,232,249,.12);
  border-radius:16px;
  padding:10px;
  background:rgba(0,8,18,.64);
  margin-bottom:8px;
}
.health-row b{
  font-size:12px;
}
.health-row span{
  color:var(--muted);
  font-size:11px;
}
.health-row strong{
  color:var(--green);
}
.formula{
  border:1px solid rgba(103,232,249,.12);
  border-radius:15px;
  padding:10px;
  background:rgba(0,8,18,.64);
  margin-bottom:8px;
}
.formula b{
  color:var(--amber);
}
.formula code{
  display:block;
  margin-top:5px;
  color:#d7fbe8;
  font-size:12px;
}
.event-stream{
  max-height:210px;
  overflow:auto;
  font-family:ui-monospace,SFMono-Regular,Menlo,monospace;
  font-size:11px;
  color:#b8f7d0;
  line-height:1.45;
}
.event{
  border-bottom:1px solid rgba(103,232,249,.08);
  padding:6px 0;
}
@media(max-width:1600px){
  .dashboard{grid-template-columns:300px 1fr}
  .side{grid-column:1/-1;grid-template-columns:repeat(3,1fr)}
}
@media(max-width:1150px){
  .dashboard,.visual-grid,.lower-grid{grid-template-columns:1fr}
  .left-rail{position:relative;top:auto}
  .header-badges{grid-template-columns:1fr 1fr}
}
@media(max-width:720px){
  h1{font-size:34px}
  .mission-header{grid-template-columns:1fr}
  .header-badges,.side{grid-template-columns:1fr}
}
</style>
</head>
<body data-trfmc-visual-lab-grade-dashboard="mounted">
<canvas id="bgCanvas"></canvas>

<nav class="top-nav">
  <button onclick="history.back()">← Indietro</button>
  <a href="/#portal-os-preview">Portal OS</a>
  <a href="/trfmc_visual_enterprise_command_center_v1.html">Visual Enterprise</a>
  <a href="/trfmc_page_review_cockpit_v1.html">Review Cockpit</a>
  <a href="/trfmc_working_pages_control_room_v1.html">Working Pages</a>
</nav>

<div class="shell">
  <header class="mission-header">
    <div>
      <div class="eyebrow">TRFMC · RF/Telco/Cyber Lab Grade Operational Dashboard</div>
      <h1>Visual Mission Control</h1>
      <p>
        Dashboard unica ad alto impatto: sito radio, beam coverage, antenna/microstrip, spettro,
        core/RAN, assurance e sorgenti legacy governate. Non è più un indice: è la control room visuale del portale.
      </p>
    </div>
    <div class="header-badges">
      <div class="badge"><span>Sources</span><strong id="kSources">0</strong></div>
      <div class="badge"><span>Canvas</span><strong id="kCanvas">0</strong></div>
      <div class="badge"><span>Proxy</span><strong id="kProxy">CHK</strong></div>
      <div class="badge"><span>Mode</span><strong>QA</strong></div>
    </div>
  </header>

  <section class="dashboard">
    <aside class="panel left-rail" id="areaRail"></aside>

    <main class="panel stage">
      <section class="visual-grid">
        <article class="visual-card">
          <div class="titlebar">
            <div>
              <div class="eyebrow" id="areaEyebrow">AREA</div>
              <h2 id="areaTitle">RF/Telco Operational Site</h2>
            </div>
            <div class="status" id="areaStatus">LIVE VISUAL</div>
          </div>
          <div class="rf-scene">
            <div class="beam"></div>
            <div class="beam blue"></div>
            <div class="tower">
              <div class="mast"></div>
              <div class="cross c1"></div><div class="cross c2"></div><div class="cross c3"></div><div class="cross c4"></div>
              <div class="panel-ant a1"></div><div class="panel-ant a2"></div><div class="panel-ant a3"></div>
            </div>
            <div class="skyline" id="skyline"></div>
          </div>
        </article>

        <article class="visual-card">
          <div class="titlebar">
            <h3>Geographic / Service Twin</h3>
            <div class="status">MULTI REGION</div>
          </div>
          <div class="globe-widget">
            <div class="globe">
              <div class="geo-node n1"></div><div class="geo-node n2"></div><div class="geo-node n3"></div><div class="geo-node n4"></div><div class="geo-node n5"></div>
            </div>
          </div>
        </article>
      </section>

      <section class="lower-grid">
        <article class="visual-card microstrip">
          <div class="titlebar"><h3>Microstrip / Antenna Stack</h3><div class="status">5 GHz</div></div>
          <div class="patch3d">
            <div class="ground"></div>
            <div class="substrate"></div>
            <div class="patch"></div>
            <div class="feed"></div>
            <div class="sma"></div>
          </div>
        </article>

        <article class="visual-card spectrum">
          <div class="titlebar"><h3>Spectrum / Field Intelligence</h3><div class="status">FFT</div></div>
          <canvas id="spectrumCanvas"></canvas>
        </article>

        <article class="visual-card spectrum">
          <div class="titlebar"><h3>Radar / Coverage Pattern</h3><div class="status">BEAM</div></div>
          <canvas id="radarCanvas"></canvas>
        </article>
      </section>

      <section class="visual-card source-list">
        <div class="titlebar"><h3>Governed Source Evidence</h3><div class="status" id="sourceCount">0 SOURCES</div></div>
        <div id="sourceCards"></div>
      </section>
    </main>

    <aside class="side">
      <section class="panel">
        <h3>Live Contracts</h3>
        <div class="health-row"><div><b>Backend 8000</b><br><span id="backendStatus">checking...</span></div><strong id="backendCode">—</strong></div>
        <div class="health-row"><div><b>Bridge 4181</b><br><span id="bridgeStatus">checking...</span></div><strong id="bridgeCode">—</strong></div>
        <div class="health-row"><div><b>Same-Origin Proxy</b><br><span id="proxyStatus">checking...</span></div><strong id="proxyCode">—</strong></div>
      </section>

      <section class="panel">
        <h3>RF / Telco Formula Wall</h3>
        <div class="formula"><b>Wavelength</b><code>λ = c / f</code></div>
        <div class="formula"><b>FSPL</b><code>FSPL = 32.44 + 20log₁₀(fMHz) + 20log₁₀(dkm)</code></div>
        <div class="formula"><b>EIRP</b><code>EIRP = Ptx + Gant − Loss</code></div>
        <div class="formula"><b>VSWR</b><code>VSWR = (1 + |Γ|) / (1 − |Γ|)</code></div>
      </section>

      <section class="panel">
        <h3>Event Stream</h3>
        <div class="event-stream" id="events"></div>
      </section>
    </aside>
  </section>
</div>

<script>
const DATA = __DATA_JSON__;

const AREAS = [
  {key:"ops", label:"Mission / Assurance", icon:"◎", bucket:"ops", subtitle:"Readiness, evidence, mission control, operational posture."},
  {key:"rf", label:"RF / Microwave", icon:"λ", bucket:"rf", subtitle:"Propagation, link budget, Smith/Fresnel, RF physics."},
  {key:"antenna", label:"Antenna / RRU", icon:"⌁", bucket:"antenna", subtitle:"Antenna, RRU, RET, CPRI, AISG, MIMO and beam."},
  {key:"dsp", label:"DSP / Spectrum", icon:"∿", bucket:"dsp", subtitle:"FFT, IQ, waterfall, analyzer, measurement chain."},
  {key:"core", label:"5G Core / RAN", icon:"5G", bucket:"core", subtitle:"Open5GS, UERANSIM, NGAP, PFCP, GTP-U and identity."}
];

let active = "ops";

function esc(s){
  return String(s ?? "").replace(/[&<>"']/g, ch => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
  }[ch]));
}

function logEvent(msg){
  const t = new Date().toLocaleTimeString();
  const el = document.getElementById("events");
  el.innerHTML = `<div class="event">[${t}] ${esc(msg)}</div>` + el.innerHTML;
}

function bucketPages(key){
  return (DATA.buckets && DATA.buckets[key]) ? DATA.buckets[key] : [];
}

function renderRail(){
  const root = document.getElementById("areaRail");
  root.innerHTML = AREAS.map(area => {
    const list = bucketPages(area.bucket);
    const canvas = list.reduce((a,p)=>a+(Number(p.canvas)||0),0);
    return `
      <button class="area-btn ${area.key===active ? "active" : ""}" data-area="${esc(area.key)}">
        <span class="area-icon">${esc(area.icon)}</span>
        <span><strong>${esc(area.label)}</strong><small>${canvas} canvas · ${list.length} sources</small></span>
        <b class="area-count">${list.length}</b>
      </button>
    `;
  }).join("");
  root.querySelectorAll("[data-area]").forEach(btn => {
    btn.addEventListener("click", () => {
      active = btn.dataset.area;
      renderAll();
      logEvent(`active area → ${AREAS.find(a=>a.key===active).label}`);
    });
  });
}

function renderStage(){
  const area = AREAS.find(a => a.key === active) || AREAS[0];
  const list = bucketPages(area.bucket);
  document.getElementById("areaEyebrow").textContent = `ACTIVE AREA · ${area.key}`;
  document.getElementById("areaTitle").textContent = area.label;
  document.getElementById("areaStatus").textContent = `${list.length} SOURCES`;
  document.getElementById("sourceCount").textContent = `${list.length} SOURCES`;

  document.getElementById("sourceCards").innerHTML = list.length ? list.slice(0,16).map(p => `
    <a class="source-card" href="${esc(p.url)}" target="_blank" rel="noreferrer">
      <span>${esc(p.category)}</span>
      <strong>${esc(p.title)}</strong>
      <em>${esc(p.url)}</em>
    </a>
  `).join("") : `<div style="color:var(--muted);padding:12px">Nessuna sorgente classificata qui: serve triage manuale, non altra pagina.</div>`;
}

function renderKpi(){
  document.getElementById("kSources").textContent = DATA.kpi.sources || 0;
  document.getElementById("kCanvas").textContent = DATA.kpi.canvas || 0;
}

async function checkEndpoint(label,url,statusId,codeId){
  try{
    const res = await fetch(url,{cache:"no-store"});
    const text = await res.text();
    let json = false;
    try{ JSON.parse(text); json = true; } catch(e){}
    document.getElementById(statusId).textContent = json ? "JSON OK" : (text.includes("<html") ? "HTML fallback" : "non-json");
    document.getElementById(codeId).textContent = String(res.status);
    logEvent(`${label} ${res.status} ${json ? "JSON" : "NOJSON"}`);
    return res.ok && json;
  }catch(e){
    document.getElementById(statusId).textContent = "offline";
    document.getElementById(codeId).textContent = "ERR";
    logEvent(`${label} offline`);
    return false;
  }
}

async function liveContracts(){
  const b = await checkEndpoint("backend","/trfmc-api/backend/api/health","backendStatus","backendCode");
  const br = await checkEndpoint("bridge","/trfmc-api/bridge/api/health","bridgeStatus","bridgeCode");
  const ok = b && br;
  document.getElementById("proxyStatus").textContent = ok ? "proxy contract OK" : "proxy degraded";
  document.getElementById("proxyCode").textContent = ok ? "OK" : "WARN";
  document.getElementById("kProxy").textContent = ok ? "OK" : "WARN";
}

function drawBuildings(){
  const root = document.getElementById("skyline");
  let html = "";
  for(let i=0;i<26;i++){
    const h = 28 + Math.random()*86;
    const l = i*4;
    html += `<div class="building" style="left:${l}%;height:${h}px"></div>`;
  }
  root.innerHTML = html;
}

function renderAll(){
  renderKpi();
  renderRail();
  renderStage();
}

function drawSpectrum(){
  const c = document.getElementById("spectrumCanvas");
  const ctx = c.getContext("2d");
  const r = c.getBoundingClientRect();
  c.width = r.width * devicePixelRatio;
  c.height = r.height * devicePixelRatio;
  ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0);
  ctx.clearRect(0,0,r.width,r.height);

  ctx.strokeStyle = "rgba(103,232,249,.12)";
  ctx.lineWidth = 1;
  for(let x=0;x<r.width;x+=34){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,r.height);ctx.stroke();}
  for(let y=0;y<r.height;y+=28){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(r.width,y);ctx.stroke();}

  const grad = ctx.createLinearGradient(0,0,r.width,0);
  grad.addColorStop(0,"#38bdf8");
  grad.addColorStop(.55,"#86efac");
  grad.addColorStop(1,"#fbbf24");
  ctx.strokeStyle = grad;
  ctx.lineWidth = 2;

  ctx.beginPath();
  for(let x=0;x<r.width;x++){
    const n = Math.sin(x*.035)*18 + Math.sin(x*.091)*8 + Math.random()*8;
    const peak = 90*Math.exp(-Math.pow((x-r.width*.58)/34,2));
    const y = r.height - 42 - n - peak;
    if(x===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
  }
  ctx.stroke();
}

function drawRadar(){
  const c = document.getElementById("radarCanvas");
  const ctx = c.getContext("2d");
  const r = c.getBoundingClientRect();
  c.width = r.width * devicePixelRatio;
  c.height = r.height * devicePixelRatio;
  ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0);
  ctx.clearRect(0,0,r.width,r.height);

  const cx = r.width/2, cy = r.height/2 + 16;
  const max = Math.min(r.width,r.height)*.40;
  ctx.strokeStyle = "rgba(103,232,249,.18)";
  for(let rr=max/4;rr<=max;rr+=max/4){ctx.beginPath();ctx.arc(cx,cy,rr,Math.PI,Math.PI*2);ctx.stroke();}
  for(let a=180;a<=360;a+=20){
    const rad=a*Math.PI/180;
    ctx.beginPath();ctx.moveTo(cx,cy);ctx.lineTo(cx+Math.cos(rad)*max,cy+Math.sin(rad)*max);ctx.stroke();
  }

  ctx.fillStyle = "rgba(134,239,172,.34)";
  ctx.strokeStyle = "#86efac";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(cx,cy);
  for(let a=205;a<=335;a++){
    const rad=a*Math.PI/180;
    const gain=max*(.35+.62*Math.pow(Math.cos((a-270)*Math.PI/180),8));
    ctx.lineTo(cx+Math.cos(rad)*gain,cy+Math.sin(rad)*gain);
  }
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
}

const bg = document.getElementById("bgCanvas");
const bctx = bg.getContext("2d");
let pts = [];
function resizeBg(){
  bg.width = innerWidth*devicePixelRatio;
  bg.height = innerHeight*devicePixelRatio;
  bg.style.width = innerWidth+"px";
  bg.style.height = innerHeight+"px";
  bctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0);
  pts = Array.from({length:Math.min(150,Math.floor(innerWidth/10))},()=>({
    x:Math.random()*innerWidth,y:Math.random()*innerHeight,
    vx:(Math.random()-.5)*.28,vy:(Math.random()-.5)*.28,r:Math.random()*1.6+.4
  }));
  drawSpectrum();
  drawRadar();
}
function animateBg(){
  bctx.clearRect(0,0,innerWidth,innerHeight);
  for(const p of pts){
    p.x+=p.vx;p.y+=p.vy;
    if(p.x<0||p.x>innerWidth)p.vx*=-1;
    if(p.y<0||p.y>innerHeight)p.vy*=-1;
  }
  bctx.strokeStyle="rgba(103,232,249,.07)";
  for(let i=0;i<pts.length;i++)for(let j=i+1;j<pts.length;j++){
    const a=pts[i],b=pts[j],dx=a.x-b.x,dy=a.y-b.y,d=Math.sqrt(dx*dx+dy*dy);
    if(d<130){
      bctx.globalAlpha=1-d/130;
      bctx.beginPath();bctx.moveTo(a.x,a.y);bctx.lineTo(b.x,b.y);bctx.stroke();
    }
  }
  bctx.globalAlpha=1;
  bctx.fillStyle="rgba(103,232,249,.56)";
  for(const p of pts){bctx.beginPath();bctx.arc(p.x,p.y,p.r,0,Math.PI*2);bctx.fill();}
  requestAnimationFrame(animateBg);
}

drawBuildings();
renderAll();
liveContracts();
resizeBg();
animateBg();
addEventListener("resize",resizeBg);
setInterval(drawSpectrum,1200);
setInterval(drawRadar,1600);
logEvent("Visual Lab Grade dashboard mounted");
</script>
</body>
</html>
'''
html = html.replace("__DATA_JSON__", data_json)
dash.write_text(html, encoding="utf-8")
PY

cat > "$HTTP" <<HDR
url	status	bytes	hint	result
HDR

tmp="$(mktemp)"
code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" http://127.0.0.1:5173/trfmc_visual_lab_grade_telco_dashboard_v1.html 2>/dev/null || echo 000)"
bytes="$(wc -c < "$tmp" | tr -d ' ')"
hint="TEXT"
grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
result="OK"
[ "$code" != "200" ] && result="NON_200"
[ "$bytes" = "0" ] && result="ZERO_BYTES"
printf "%s\t%s\t%s\t%s\t%s\n" "http://127.0.0.1:5173/trfmc_visual_lab_grade_telco_dashboard_v1.html" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
rm -f "$tmp"

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

if [ -n "$CHROME_BIN" ]; then
  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --dump-dom http://127.0.0.1:5173/trfmc_visual_lab_grade_telco_dashboard_v1.html > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --screenshot="$SCREEN" http://127.0.0.1:5173/trfmc_visual_lab_grade_telco_dashboard_v1.html >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

MOUNT_COUNT="$(grep -o 'data-trfmc-visual-lab-grade-dashboard="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
CANVAS_COUNT="$(grep -o '<canvas' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
AREA_COUNT="$(grep -o 'class="area-btn' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
SOURCE_COUNT="$(grep -o 'class="source-card"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$MOUNT_COUNT" = "0" ] && RESULT="FAIL_MARKER"
[ "$CANVAS_COUNT" -lt 3 ] && RESULT="FAIL_CANVAS"
[ "$AREA_COUNT" -lt 5 ] && RESULT="FAIL_AREAS"
[ "$SOURCE_COUNT" = "0" ] && RESULT="FAIL_SOURCES"
[ "$SCREENSHOT_RESULT" != "PASS" ] && RESULT="FAIL_SCREENSHOT"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P7F_VISUAL_LAB_GRADE_TELCO_DASHBOARD_V1",
  "mutation": "public_static_visual_lab_grade_dashboard",
  "react_mutation": false,
  "backend_mutation": false,
  "data_source": "$DATA_SRC",
  "dashboard": "$DASH",
  "url": "http://127.0.0.1:5173/trfmc_visual_lab_grade_telco_dashboard_v1.html",
  "normalized_data": "$NORMALIZED",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "mount_count": $MOUNT_COUNT,
  "canvas_count": $CANVAS_COUNT,
  "area_count": $AREA_COUNT,
  "source_count": $SOURCE_COUNT,
  "http_failures": $HTTP_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p7f_visual_lab_grade_telco_dashboard_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P7F_VISUAL_LAB_GRADE_TELCO_DASHBOARD_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
