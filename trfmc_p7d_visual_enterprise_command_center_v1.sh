#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P7D_VISUAL_ENTERPRISE_COMMAND_CENTER_V1_$TS"

mkdir -p "$OUT"
cd "$BASE" || exit 1

DATA_SRC=""
if [ -f runtime/quality/latest_p7c_single_enterprise_telco_dashboard_v1/enterprise_telco_dashboard_data.json ]; then
  DATA_SRC="runtime/quality/latest_p7c_single_enterprise_telco_dashboard_v1/enterprise_telco_dashboard_data.json"
else
  DATA_SRC="$(find runtime/quality -path '*TRFMC_P7C_SINGLE_ENTERPRISE_TELCO_DASHBOARD_V1_*/*enterprise_telco_dashboard_data.json' | sort | tail -n 1)"
fi

if [ -z "$DATA_SRC" ] || [ ! -f "$DATA_SRC" ]; then
  if [ -f runtime/quality/latest_p7a_thematic_command_center_v1/thematic_command_center_data.json ]; then
    DATA_SRC="runtime/quality/latest_p7a_thematic_command_center_v1/thematic_command_center_data.json"
  else
    DATA_SRC="$(find runtime/quality -path '*TRFMC_P7A_THEMATIC_COMMAND_CENTER_V1_*/*thematic_command_center_data.json' | sort | tail -n 1)"
  fi
fi

DASH="frontend/public/trfmc_visual_enterprise_command_center_v1.html"
SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_visual_enterprise_command_center.txt"
SCREEN="$OUT/visual_enterprise_command_center_1920x1080.png"
NORMALIZED="$OUT/visual_enterprise_dashboard_data.json"

echo "============================================================"
echo "TRFMC_P7D_VISUAL_ENTERPRISE_COMMAND_CENTER_V1"
echo "Dashboard unica visuale enterprise · no React mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$DATA_SRC" ] || [ ! -f "$DATA_SRC" ]; then
  echo "ERRORE: data source P7C/P7A non trovato."
  exit 1
fi

echo "DATA_SRC=$DATA_SRC"

python3 - "$DATA_SRC" "$DASH" "$NORMALIZED" <<'PY'
import json, re, sys
from pathlib import Path
from collections import defaultdict

src = Path(sys.argv[1])
dash = Path(sys.argv[2])
normalized_out = Path(sys.argv[3])

raw = json.loads(src.read_text(encoding="utf-8", errors="replace"))

if "areas" in raw:
    areas_in = raw["areas"]
else:
    areas_in = raw.get("themes", {})

pages_in = raw.get("pages", [])

ENTERPRISE_AREAS = {
    "mission": {
        "title": "Mission Control",
        "subtitle": "Command, registry, readiness, route governance.",
        "icon": "◈",
        "color": "#67e8f9",
        "keywords": ["mission", "portal", "command", "overview", "dashboard", "registry", "control", "nexus"]
    },
    "assurance": {
        "title": "Assurance / NOC",
        "subtitle": "Alarms, evidence, health, correlation, flight recorder.",
        "icon": "◎",
        "color": "#86efac",
        "keywords": ["assurance", "alarm", "evidence", "health", "flight", "recorder", "noc", "war", "ops", "readiness"]
    },
    "orchestration": {
        "title": "Orchestration",
        "subtitle": "Activation, workflow, API bridge, lifecycle, automation.",
        "icon": "⟲",
        "color": "#c084fc",
        "keywords": ["orchestr", "automation", "activation", "workflow", "scenario", "runner", "api", "bridge", "proxy"]
    },
    "core_ran": {
        "title": "5G Core / RAN",
        "subtitle": "Open5GS, UERANSIM, NGAP, PFCP, GTP-U, identity.",
        "icon": "5G",
        "color": "#fbbf24",
        "keywords": ["open5gs", "ueransim", "ngap", "pfcp", "gtp", "core", "ran", "supi", "suci", "aka", "gnb"]
    },
    "signal_dsp": {
        "title": "Signal / DSP",
        "subtitle": "FFT, IQ, waterfall, spectrum, VSA, measurement chain.",
        "icon": "∿",
        "color": "#38bdf8",
        "keywords": ["dsp", "fft", "iq", "waterfall", "signal", "spectrum", "measurement", "vsa", "trace", "analyzer"]
    },
    "rf_microwave": {
        "title": "RF / Microwave",
        "subtitle": "Propagation, link budget, Smith chart, microwave physics.",
        "icon": "λ",
        "color": "#22c55e",
        "keywords": ["microwave", "fresnel", "smith", "propagation", "link budget", "rf_physics", "maxwell", "wave", "em_"]
    },
    "antenna": {
        "title": "Antenna System",
        "subtitle": "RRU, RET, CPRI, AISG, MIMO, beam and pattern mapping.",
        "icon": "⌁",
        "color": "#fb7185",
        "keywords": ["antenna", "rru", "ret", "cpri", "aisg", "mimo", "beam", "array", "pattern", "downtilt"]
    },
    "infrastructure": {
        "title": "Infrastructure",
        "subtitle": "Fiber, fronthaul, data center, ODF, power, rack, UPS.",
        "icon": "▦",
        "color": "#a3e635",
        "keywords": ["fiber", "otdr", "fronthaul", "odf", "datacenter", "data_center", "power", "pdu", "ups", "rack"]
    },
    "knowledge": {
        "title": "Knowledge Base",
        "subtitle": "Theory, glossary, academy, procedures and training material.",
        "icon": "Σ",
        "color": "#f472b6",
        "keywords": ["knowledge", "theory", "academy", "glossary", "lesson", "procedure", "training", "reference"]
    }
}

def classify(page):
    text = " ".join([
        page.get("area", ""),
        page.get("theme", ""),
        page.get("category", ""),
        page.get("title", ""),
        page.get("url", ""),
        page.get("file", ""),
    ]).lower()

    scores = {}
    for key, area in ENTERPRISE_AREAS.items():
        score = 0
        for kw in area["keywords"]:
            if kw in text:
                score += 12 if len(kw) > 3 else 3
        scores[key] = score

    best = max(scores, key=scores.get)
    if scores[best] <= 0:
        return "knowledge"
    return best

pages = []
for p in pages_in:
    url = p.get("url", "")
    if not isinstance(url, str) or not url.startswith("/"):
        continue

    area = classify(p)
    pages.append({
        "area": area,
        "title": p.get("title") or p.get("file") or url,
        "url": url,
        "file": p.get("file", ""),
        "category": p.get("category", "reference"),
        "bytes": int(p.get("bytes", 0) or 0),
        "canvas": int(p.get("canvas", 0) or 0),
        "scripts": int(p.get("scripts", 0) or 0)
    })

pages.sort(key=lambda x: (x["area"], -x["canvas"], -x["scripts"], x["title"].lower()))

by_area = defaultdict(list)
for p in pages:
    by_area[p["area"]].append(p)

for key, area in ENTERPRISE_AREAS.items():
    group = by_area.get(key, [])
    area["count"] = len(group)
    area["canvas"] = sum(p["canvas"] for p in group)
    area["scripts"] = sum(p["scripts"] for p in group)
    area["bytes"] = sum(p["bytes"] for p in group)

data = {
    "areas": ENTERPRISE_AREAS,
    "pages": pages,
    "generatedAt": "__TS__"
}
normalized_out.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")

data_json = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")

html = r'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>TRFMC Visual Enterprise Command Center</title>
<style>
:root {
  --bg:#020812;
  --panel:rgba(3,14,28,.78);
  --panel2:rgba(0,10,22,.88);
  --line:rgba(103,232,249,.18);
  --line2:rgba(134,239,172,.20);
  --text:#e8f7ff;
  --muted:#9fb8ca;
  --cyan:#67e8f9;
  --green:#86efac;
  --amber:#fbbf24;
  --red:#fb7185;
  --violet:#c084fc;
}
* { box-sizing:border-box; }
body {
  margin:0;
  overflow-x:hidden;
  color:var(--text);
  font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
  background:
    radial-gradient(circle at 12% 6%, rgba(14,165,233,.22), transparent 30%),
    radial-gradient(circle at 88% 0%, rgba(16,185,129,.16), transparent 30%),
    radial-gradient(circle at 48% 50%, rgba(192,132,252,.08), transparent 34%),
    linear-gradient(180deg,#020812,#020617 56%,#00040b);
}
#networkCanvas {
  position:fixed;
  inset:0;
  z-index:-2;
  opacity:.52;
}
body::before {
  content:"";
  position:fixed;
  inset:0;
  z-index:-1;
  background:
    linear-gradient(rgba(103,232,249,.035) 1px, transparent 1px),
    linear-gradient(90deg, rgba(103,232,249,.035) 1px, transparent 1px);
  background-size:42px 42px;
  mask-image:radial-gradient(circle at 50% 20%, black, transparent 78%);
}
.top-nav {
  position:sticky;
  top:0;
  z-index:80;
  display:flex;
  gap:8px;
  flex-wrap:wrap;
  align-items:center;
  padding:10px 22px;
  border-bottom:1px solid var(--line);
  background:rgba(2,8,18,.94);
  backdrop-filter:blur(18px);
}
.top-nav a,.top-nav button {
  border:1px solid rgba(103,232,249,.24);
  border-radius:999px;
  padding:8px 12px;
  color:var(--text);
  background:rgba(0,12,24,.72);
  text-decoration:none;
  font-size:12px;
  font-weight:950;
  cursor:pointer;
}
.top-nav a:hover,.top-nav button:hover {
  color:var(--green);
  border-color:rgba(134,239,172,.58);
  box-shadow:0 0 20px rgba(16,185,129,.12);
}
.shell {
  max-width:1920px;
  margin:0 auto;
  padding:20px 22px 44px;
}
.hero {
  min-height:330px;
  display:grid;
  grid-template-columns:1.05fr .95fr;
  gap:16px;
  border:1px solid var(--line);
  border-radius:34px;
  padding:22px;
  background:
    radial-gradient(circle at 85% 10%, rgba(103,232,249,.17), transparent 32%),
    linear-gradient(135deg, rgba(0,19,34,.90), rgba(0,7,16,.76));
  box-shadow:0 38px 140px rgba(0,0,0,.42);
}
.eyebrow {
  color:var(--cyan);
  font-size:11px;
  font-weight:950;
  letter-spacing:.15em;
  text-transform:uppercase;
}
h1 {
  margin:10px 0 0;
  font-size:52px;
  letter-spacing:-.065em;
  line-height:.95;
}
.hero-copy p {
  max-width:980px;
  margin:16px 0 0;
  color:var(--muted);
  font-size:15px;
  line-height:1.55;
}
.kpi-row {
  display:grid;
  grid-template-columns:repeat(5,minmax(0,1fr));
  gap:10px;
  margin-top:20px;
}
.kpi {
  position:relative;
  overflow:hidden;
  border:1px solid rgba(103,232,249,.14);
  border-radius:19px;
  padding:13px;
  background:rgba(0,9,20,.65);
}
.kpi::after {
  content:"";
  position:absolute;
  inset:auto -30% -50% -30%;
  height:80px;
  background:radial-gradient(circle, rgba(103,232,249,.13), transparent 70%);
}
.kpi span {
  display:block;
  color:var(--muted);
  font-size:10px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.11em;
}
.kpi strong {
  display:block;
  margin-top:6px;
  color:var(--green);
  font-size:28px;
}
.visual-stage {
  min-height:286px;
  border:1px solid rgba(103,232,249,.14);
  border-radius:28px;
  background:
    radial-gradient(circle at 50% 48%, rgba(103,232,249,.08), transparent 42%),
    rgba(0,8,18,.55);
  position:relative;
  overflow:hidden;
}
.ring-svg {
  position:absolute;
  inset:0;
  width:100%;
  height:100%;
}
.ring-label {
  position:absolute;
  left:18px;
  bottom:18px;
  color:var(--muted);
  font-size:12px;
  line-height:1.45;
  max-width:360px;
}
.command-grid {
  display:grid;
  grid-template-columns:360px 1fr 430px;
  gap:14px;
  margin-top:14px;
  align-items:start;
}
.area-rail,.main-panel,.right-panel {
  border:1px solid var(--line);
  border-radius:28px;
  background:var(--panel);
  box-shadow:0 22px 90px rgba(0,0,0,.30);
}
.area-rail {
  position:sticky;
  top:64px;
  padding:12px;
}
.area-button {
  width:100%;
  display:grid;
  grid-template-columns:42px 1fr auto;
  align-items:center;
  gap:10px;
  margin-bottom:8px;
  border:1px solid rgba(103,232,249,.13);
  border-radius:18px;
  padding:10px;
  color:inherit;
  background:rgba(0,9,20,.70);
  cursor:pointer;
  text-align:left;
}
.area-button.active {
  border-color:rgba(134,239,172,.70);
  background:linear-gradient(135deg, rgba(8,47,38,.34), rgba(0,12,24,.72));
  box-shadow:0 0 28px rgba(16,185,129,.12);
}
.area-icon {
  display:flex;
  width:40px;
  height:40px;
  align-items:center;
  justify-content:center;
  border-radius:15px;
  background:rgba(103,232,249,.12);
  color:var(--cyan);
  font-weight:950;
}
.area-button strong {
  display:block;
  font-size:13px;
}
.area-button span:last-child {
  color:var(--muted);
  font-size:11px;
}
.area-count {
  color:var(--green);
  font-size:18px;
  font-weight:950;
}
.main-panel {
  min-height:650px;
  padding:16px;
}
.panel-head {
  display:flex;
  justify-content:space-between;
  gap:12px;
  align-items:flex-start;
  border-bottom:1px solid rgba(103,232,249,.10);
  padding-bottom:12px;
}
.panel-head h2 {
  margin:4px 0;
  font-size:32px;
  letter-spacing:-.045em;
}
.panel-head p {
  margin:0;
  color:var(--muted);
  line-height:1.45;
}
.status-pill {
  border:1px solid rgba(134,239,172,.25);
  border-radius:999px;
  padding:8px 11px;
  color:var(--green);
  background:rgba(8,47,38,.18);
  font-weight:950;
  font-size:12px;
  white-space:nowrap;
}
.lanes {
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:10px;
  margin:14px 0;
}
.lane {
  border:1px solid rgba(103,232,249,.12);
  border-radius:18px;
  padding:12px;
  background:rgba(0,9,20,.62);
}
.lane b {
  display:block;
  color:var(--cyan);
}
.lane span {
  display:block;
  margin-top:5px;
  color:var(--muted);
  font-size:12px;
  line-height:1.35;
}
.toolbar {
  display:flex;
  gap:8px;
  margin:12px 0;
}
.toolbar input {
  flex:1;
  border:1px solid rgba(103,232,249,.20);
  border-radius:14px;
  padding:11px;
  outline:none;
  color:var(--text);
  background:rgba(0,7,16,.72);
}
.page-grid {
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:10px;
  max-height:430px;
  overflow:auto;
  padding-right:4px;
}
.page-card {
  min-height:138px;
  display:flex;
  flex-direction:column;
  gap:7px;
  border:1px solid rgba(103,232,249,.14);
  border-radius:18px;
  padding:12px;
  color:inherit;
  background:
    radial-gradient(circle at 90% 0%, rgba(103,232,249,.10), transparent 30%),
    rgba(0,8,18,.72);
  text-decoration:none;
}
.page-card:hover {
  border-color:rgba(134,239,172,.56);
  box-shadow:0 0 34px rgba(16,185,129,.11);
}
.page-card span {
  color:var(--cyan);
  font-size:9px;
  font-weight:950;
  letter-spacing:.10em;
  text-transform:uppercase;
}
.page-card strong {
  font-size:13px;
  line-height:1.16;
}
.page-card em {
  color:var(--muted);
  font-size:10px;
  font-style:normal;
  word-break:break-word;
}
.page-card small {
  margin-top:auto;
  color:var(--amber);
  font-size:10px;
  font-weight:900;
}
.right-panel {
  padding:16px;
}
.right-panel h3 {
  margin:0 0 10px;
  font-size:19px;
}
.topology {
  position:relative;
  min-height:270px;
  border:1px solid rgba(103,232,249,.12);
  border-radius:22px;
  background:
    radial-gradient(circle at 50% 48%, rgba(134,239,172,.10), transparent 32%),
    rgba(0,8,18,.62);
  overflow:hidden;
}
.node {
  position:absolute;
  transform:translate(-50%,-50%);
  min-width:74px;
  text-align:center;
  border:1px solid rgba(103,232,249,.18);
  border-radius:15px;
  padding:8px;
  color:var(--text);
  background:rgba(0,12,24,.80);
  font-size:10px;
  font-weight:900;
}
.node.core {
  left:50%;
  top:50%;
  border-color:rgba(134,239,172,.62);
  color:var(--green);
}
.action-stack {
  display:grid;
  gap:8px;
  margin-top:12px;
}
.action {
  border:1px solid rgba(103,232,249,.12);
  border-radius:16px;
  padding:10px;
  background:rgba(0,9,20,.60);
}
.action b {
  display:block;
  color:var(--green);
  font-size:12px;
}
.action span {
  display:block;
  color:var(--muted);
  font-size:11px;
  margin-top:4px;
  line-height:1.32;
}
.empty {
  color:var(--muted);
  padding:14px;
}
@media(max-width:1600px) {
  .command-grid { grid-template-columns:320px 1fr; }
  .right-panel { grid-column:1 / -1; }
}
@media(max-width:1150px) {
  .hero { grid-template-columns:1fr; }
  .command-grid { grid-template-columns:1fr; }
  .area-rail { position:relative; top:auto; }
  .page-grid,.lanes,.kpi-row { grid-template-columns:repeat(2,minmax(0,1fr)); }
}
@media(max-width:720px) {
  h1 { font-size:34px; }
  .page-grid,.lanes,.kpi-row { grid-template-columns:1fr; }
}
</style>
</head>
<body data-trfmc-visual-enterprise-command-center="mounted">
<canvas id="networkCanvas"></canvas>

<nav class="top-nav">
  <button onclick="history.back()">← Indietro</button>
  <a href="/#portal-os-preview">Portal OS</a>
  <a href="/trfmc_enterprise_telco_command_center_v1.html">Enterprise V1</a>
  <a href="/trfmc_page_review_cockpit_v1.html">Review Cockpit</a>
  <a href="/trfmc_working_pages_control_room_v1.html">Working Pages</a>
</nav>

<div class="shell">
  <section class="hero">
    <div class="hero-copy">
      <div class="eyebrow">TRFMC · visual enterprise telco command center</div>
      <h1>Operational Digital Twin Shell</h1>
      <p>
        Una sola dashboard madre, con aree operative interne: assurance, orchestration, inventory,
        core/RAN, RF, DSP, antenna e infrastructure. Le pagine legacy diventano sorgenti/evidence,
        non un labirinto di link.
      </p>
      <div class="kpi-row">
        <div class="kpi"><span>Active sources</span><strong id="kpiPages">0</strong></div>
        <div class="kpi"><span>Areas</span><strong id="kpiAreas">0</strong></div>
        <div class="kpi"><span>Canvas</span><strong id="kpiCanvas">0</strong></div>
        <div class="kpi"><span>Scripts</span><strong id="kpiScripts">0</strong></div>
        <div class="kpi"><span>Mode</span><strong>QA</strong></div>
      </div>
    </div>
    <div class="visual-stage">
      <svg class="ring-svg" viewBox="0 0 800 420" aria-hidden="true">
        <defs>
          <filter id="glow"><feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
          <linearGradient id="g1" x1="0" x2="1"><stop stop-color="#67e8f9"/><stop offset="1" stop-color="#86efac"/></linearGradient>
        </defs>
        <circle cx="400" cy="210" r="145" fill="none" stroke="rgba(103,232,249,.16)" stroke-width="1"/>
        <circle cx="400" cy="210" r="102" fill="none" stroke="rgba(134,239,172,.18)" stroke-width="1"/>
        <circle cx="400" cy="210" r="58" fill="rgba(103,232,249,.05)" stroke="url(#g1)" stroke-width="2" filter="url(#glow)"/>
        <path d="M255,210 C255,120 545,120 545,210 C545,300 255,300 255,210Z" fill="none" stroke="rgba(192,132,252,.20)" stroke-width="2"/>
        <path d="M400,65 L545,210 L400,355 L255,210 Z" fill="none" stroke="rgba(251,191,36,.20)" stroke-width="2"/>
        <text x="400" y="205" text-anchor="middle" fill="#e8f7ff" font-size="20" font-weight="900">TRFMC</text>
        <text x="400" y="230" text-anchor="middle" fill="#9fb8ca" font-size="12">Digital Twin · RF/Telco/Cyber</text>
        <text x="400" y="42" text-anchor="middle" fill="#67e8f9" font-size="12" font-weight="900">ASSURANCE</text>
        <text x="400" y="392" text-anchor="middle" fill="#86efac" font-size="12" font-weight="900">ORCHESTRATION</text>
        <text x="98" y="216" text-anchor="middle" fill="#fbbf24" font-size="12" font-weight="900">CORE/RAN</text>
        <text x="702" y="216" text-anchor="middle" fill="#fb7185" font-size="12" font-weight="900">RF/DSP</text>
      </svg>
      <div class="ring-label">Model: DOC / OSS-style shell · area selector · live contracts · QA evidence · no page sprawl.</div>
    </div>
  </section>

  <section class="command-grid">
    <aside class="area-rail" id="areaRail"></aside>

    <main class="main-panel">
      <div class="panel-head">
        <div>
          <div class="eyebrow" id="activeEyebrow">AREA</div>
          <h2 id="activeTitle">—</h2>
          <p id="activeSubtitle">—</p>
        </div>
        <div class="status-pill" id="activeStatus">QA MODE</div>
      </div>

      <div class="lanes">
        <article class="lane"><b>Assurance</b><span>Verifica DOM, visuale, link, ritorno home, screenshot e qualità contenuto.</span></article>
        <article class="lane"><b>Integration</b><span>Solo le pagine mature entrano nel Portal OS; le altre restano evidence.</span></article>
        <article class="lane"><b>React Candidate</b><span>Conversione nativa solo dopo QA: War Room, DSP, Antenna, Core/RAN.</span></article>
      </div>

      <div class="toolbar">
        <input id="search" placeholder="Cerca nelle sorgenti di questa area..." />
      </div>

      <div class="page-grid" id="pageGrid"></div>
    </main>

    <aside class="right-panel">
      <h3>Service Topology</h3>
      <div class="topology" id="topology"></div>

      <div class="action-stack">
        <div class="action"><b>1 · Consolidare</b><span>Una dashboard madre, zero proliferazione di pagine area.</span></div>
        <div class="action"><b>2 · Qualificare</b><span>Ogni sorgente va marcata: OK, improve, integrate, React-ready, broken.</span></div>
        <div class="action"><b>3 · Promuovere</b><span>Portal OS riceve solo moduli maturi, non link grezzi.</span></div>
      </div>
    </aside>
  </section>
</div>

<script>
const DATA = __DATA_JSON__;
const areas = DATA.areas || {};
const pages = DATA.pages || [];
let activeArea = Object.keys(areas)[0] || 'mission';
const areaRail = document.getElementById('areaRail');
const pageGrid = document.getElementById('pageGrid');
const search = document.getElementById('search');

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, ch => ({
    '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#039;'
  }[ch]));
}

function pageStats(areaKey) {
  const group = pages.filter(p => p.area === areaKey);
  return {
    count: group.length,
    canvas: group.reduce((a,p)=>a+(Number(p.canvas)||0),0),
    scripts: group.reduce((a,p)=>a+(Number(p.scripts)||0),0)
  };
}

function renderRail() {
  areaRail.innerHTML = Object.entries(areas).map(([key, area]) => {
    const st = pageStats(key);
    return `
      <button class="area-button ${key === activeArea ? 'active' : ''}" data-area="${esc(key)}">
        <span class="area-icon" style="color:${esc(area.color)}">${esc(area.icon)}</span>
        <span><strong>${esc(area.title)}</strong><span>${st.canvas} canvas · ${st.scripts} script</span></span>
        <b class="area-count">${st.count}</b>
      </button>
    `;
  }).join('');

  areaRail.querySelectorAll('[data-area]').forEach(btn => {
    btn.addEventListener('click', () => {
      activeArea = btn.dataset.area;
      search.value = '';
      renderAll();
    });
  });
}

function renderPanel() {
  const area = areas[activeArea] || {};
  const st = pageStats(activeArea);
  document.getElementById('activeEyebrow').textContent = `AREA · ${activeArea}`;
  document.getElementById('activeTitle').textContent = area.title || activeArea;
  document.getElementById('activeSubtitle').textContent = area.subtitle || '';
  document.getElementById('activeStatus').textContent = `${st.count} SOURCES · ${st.canvas} CANVAS`;

  const q = search.value.trim().toLowerCase();
  const group = pages
    .filter(p => p.area === activeArea)
    .filter(p => !q || `${p.title} ${p.url} ${p.category}`.toLowerCase().includes(q))
    .slice(0, 36);

  pageGrid.innerHTML = group.length ? group.map(p => `
    <a class="page-card" data-page-card="mounted" href="${esc(p.url)}" target="_blank" rel="noreferrer">
      <span>${esc(p.category)}</span>
      <strong>${esc(p.title)}</strong>
      <em>${esc(p.url)}</em>
      <small>canvas ${Number(p.canvas)||0} · script ${Number(p.scripts)||0} · ${Number(p.bytes)||0} B</small>
    </a>
  `).join('') : `<div class="empty">Nessuna sorgente visibile in questa area. Serve triage/classificazione manuale.</div>`;
}

function renderTopology() {
  const topology = document.getElementById('topology');
  const keys = Object.keys(areas);
  const positions = [
    [50,50], [50,16], [82,31], [82,69], [50,84], [18,69], [18,31], [34,18], [66,82]
  ];
  topology.innerHTML = `<div class="node core">TRFMC<br/>CORE</div>` + keys.map((key, i) => {
    const area = areas[key];
    const pos = positions[(i+1) % positions.length];
    const st = pageStats(key);
    return `<div class="node" style="left:${pos[0]}%;top:${pos[1]}%;border-color:${esc(area.color)}55;color:${esc(area.color)}">${esc(area.icon)}<br/>${st.count}</div>`;
  }).join('');
}

function renderKpis() {
  document.getElementById('kpiPages').textContent = pages.length;
  document.getElementById('kpiAreas').textContent = Object.keys(areas).length;
  document.getElementById('kpiCanvas').textContent = pages.reduce((a,p)=>a+(Number(p.canvas)||0),0);
  document.getElementById('kpiScripts').textContent = pages.reduce((a,p)=>a+(Number(p.scripts)||0),0);
}

function renderAll() {
  renderKpis();
  renderRail();
  renderPanel();
  renderTopology();
}

search.addEventListener('input', renderPanel);
renderAll();

const canvas = document.getElementById('networkCanvas');
const ctx = canvas.getContext('2d');
let particles = [];

function resize() {
  canvas.width = innerWidth * devicePixelRatio;
  canvas.height = innerHeight * devicePixelRatio;
  canvas.style.width = innerWidth + 'px';
  canvas.style.height = innerHeight + 'px';
  ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0);
  particles = Array.from({length: Math.min(120, Math.floor(innerWidth / 12))}, () => ({
    x: Math.random() * innerWidth,
    y: Math.random() * innerHeight,
    vx: (Math.random()-.5) * .35,
    vy: (Math.random()-.5) * .35,
    r: Math.random() * 1.8 + .5
  }));
}
function tick() {
  ctx.clearRect(0,0,innerWidth,innerHeight);
  ctx.fillStyle = 'rgba(103,232,249,.55)';
  particles.forEach(p => {
    p.x += p.vx; p.y += p.vy;
    if (p.x < 0 || p.x > innerWidth) p.vx *= -1;
    if (p.y < 0 || p.y > innerHeight) p.vy *= -1;
    ctx.beginPath();
    ctx.arc(p.x,p.y,p.r,0,Math.PI*2);
    ctx.fill();
  });
  ctx.strokeStyle = 'rgba(103,232,249,.075)';
  for (let i=0;i<particles.length;i++) {
    for (let j=i+1;j<particles.length;j++) {
      const a=particles[i], b=particles[j];
      const dx=a.x-b.x, dy=a.y-b.y, d=Math.sqrt(dx*dx+dy*dy);
      if (d < 145) {
        ctx.globalAlpha = 1 - d/145;
        ctx.beginPath();
        ctx.moveTo(a.x,a.y);
        ctx.lineTo(b.x,b.y);
        ctx.stroke();
      }
    }
  }
  ctx.globalAlpha = 1;
  requestAnimationFrame(tick);
}
addEventListener('resize', resize);
resize();
tick();
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
code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" http://127.0.0.1:5173/trfmc_visual_enterprise_command_center_v1.html 2>/dev/null || echo 000)"
bytes="$(wc -c < "$tmp" | tr -d ' ')"
hint="TEXT"
grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
result="OK"
[ "$code" != "200" ] && result="NON_200"
[ "$bytes" = "0" ] && result="ZERO_BYTES"
printf "%s\t%s\t%s\t%s\t%s\n" "http://127.0.0.1:5173/trfmc_visual_enterprise_command_center_v1.html" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
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
    --dump-dom http://127.0.0.1:5173/trfmc_visual_enterprise_command_center_v1.html > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --screenshot="$SCREEN" http://127.0.0.1:5173/trfmc_visual_enterprise_command_center_v1.html >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

MOUNT_COUNT="$(grep -o 'data-trfmc-visual-enterprise-command-center="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
AREA_BUTTON_COUNT="$(grep -o 'class="area-button' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
PAGE_CARD_COUNT="$(grep -o 'data-page-card="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
CANVAS_COUNT="$(grep -o '<canvas' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$MOUNT_COUNT" = "0" ] && RESULT="FAIL_MARKER"
[ "$AREA_BUTTON_COUNT" -lt 6 ] && RESULT="FAIL_AREAS"
[ "$PAGE_CARD_COUNT" = "0" ] && RESULT="FAIL_NO_PAGE_CARDS"
[ "$CANVAS_COUNT" = "0" ] && RESULT="FAIL_NO_CANVAS"
[ "$SCREENSHOT_RESULT" != "PASS" ] && RESULT="FAIL_SCREENSHOT"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P7D_VISUAL_ENTERPRISE_COMMAND_CENTER_V1",
  "mutation": "public_static_visual_enterprise_dashboard",
  "react_mutation": false,
  "backend_mutation": false,
  "data_source": "$DATA_SRC",
  "dashboard": "$DASH",
  "url": "http://127.0.0.1:5173/trfmc_visual_enterprise_command_center_v1.html",
  "normalized_data": "$NORMALIZED",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "mount_count": $MOUNT_COUNT,
  "area_button_count": $AREA_BUTTON_COUNT,
  "page_card_count": $PAGE_CARD_COUNT,
  "canvas_count": $CANVAS_COUNT,
  "http_failures": $HTTP_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p7d_visual_enterprise_command_center_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P7D_VISUAL_ENTERPRISE_COMMAND_CENTER_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
