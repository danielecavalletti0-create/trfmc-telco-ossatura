#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P7E_5D_GEO_MULTITECH_COMMAND_CENTER_V1_$TS"

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

DASH="frontend/public/trfmc_5d_geo_multitech_command_center_v1.html"
SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_5d_geo_multitech.txt"
SCREEN="$OUT/geo_multitech_5d_command_center_1920x1080.png"
NORMALIZED="$OUT/geo_multitech_5d_data.json"

echo "============================================================"
echo "TRFMC_P7E_5D_GEO_MULTITECH_COMMAND_CENTER_V1"
echo "Single-page 5D geo/multitech visual command center"
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

REGIONS = {
    "lab": {
        "title": "Lab / Olginate",
        "subtitle": "Local RF/Telco/Cyber laboratory, proxy, backend, evidence.",
        "x": 52, "y": 47, "color": "#67e8f9",
        "keywords": ["lab", "local", "portal", "mission", "dashboard", "registry", "control"]
    },
    "europe": {
        "title": "Europe / Mediterranean",
        "subtitle": "Private networks, campus, macro/micro-cell, regulatory-aware RF.",
        "x": 49, "y": 38, "color": "#86efac",
        "keywords": ["europe", "italy", "mediterranean", "campus", "private", "mission"]
    },
    "americas": {
        "title": "Americas",
        "subtitle": "Long-haul paths, intercontinental transport, satellite/terrestrial mix.",
        "x": 23, "y": 46, "color": "#38bdf8",
        "keywords": ["usa", "america", "transatlantic", "long-haul", "world", "journey"]
    },
    "apac": {
        "title": "APAC / Indo-Pacific",
        "subtitle": "Dense urban 5G, massive MIMO, mobility, maritime/satellite links.",
        "x": 74, "y": 50, "color": "#fbbf24",
        "keywords": ["japan", "apac", "asia", "india", "indo", "rural", "urban"]
    },
    "africa_me": {
        "title": "Africa / Middle East",
        "subtitle": "Remote coverage, microwave backhaul, resilient field deployments.",
        "x": 54, "y": 62, "color": "#fb7185",
        "keywords": ["africa", "middle", "remote", "rural", "coverage", "backhaul"]
    },
    "ntn_space": {
        "title": "NTN / Space Layer",
        "subtitle": "LEO/MEO/GEO, satellite backhaul, timing, global reach.",
        "x": 80, "y": 24, "color": "#c084fc",
        "keywords": ["ntn", "satellite", "space", "geo", "leo", "meo", "gps"]
    }
}

TECH = {
    "rf": {"title": "RF / Microwave", "color": "#22c55e", "keywords": ["rf", "microwave", "fresnel", "smith", "propagation", "link"]},
    "antenna": {"title": "Antenna / RRU", "color": "#fb7185", "keywords": ["antenna", "rru", "ret", "cpri", "aisg", "mimo", "beam"]},
    "dsp": {"title": "DSP / Spectrum", "color": "#38bdf8", "keywords": ["dsp", "fft", "iq", "waterfall", "spectrum", "signal", "vsa"]},
    "core": {"title": "5G Core / RAN", "color": "#fbbf24", "keywords": ["open5gs", "ueransim", "ngap", "pfcp", "gtp", "core", "ran"]},
    "infra": {"title": "Fiber / DC / Power", "color": "#a3e635", "keywords": ["fiber", "otdr", "fronthaul", "datacenter", "power", "rack", "pdu"]},
    "assurance": {"title": "Assurance / NOC", "color": "#86efac", "keywords": ["alarm", "evidence", "health", "assurance", "noc", "war", "ops"]},
    "security": {"title": "Cyber / Trust", "color": "#c084fc", "keywords": ["security", "cyber", "trust", "identity", "aka", "supi", "suci"]}
}

def text_of(p):
    return " ".join([
        str(p.get("area","")),
        str(p.get("theme","")),
        str(p.get("category","")),
        str(p.get("title","")),
        str(p.get("url","")),
        str(p.get("file",""))
    ]).lower()

def classify_region(p):
    t = text_of(p)
    scores = {}
    for key, r in REGIONS.items():
        score = sum(10 for kw in r["keywords"] if kw in t)
        scores[key] = score
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "lab"

def classify_tech(p):
    t = text_of(p)
    scores = {}
    for key, r in TECH.items():
        score = sum(10 for kw in r["keywords"] if kw in t)
        scores[key] = score
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "rf"

clean_pages = []
for p in pages:
    url = p.get("url", "")
    if not isinstance(url, str) or not url.startswith("/"):
        continue
    q = {
        "title": p.get("title") or p.get("file") or url,
        "url": url,
        "category": p.get("category", "reference"),
        "bytes": int(p.get("bytes", 0) or 0),
        "canvas": int(p.get("canvas", 0) or 0),
        "scripts": int(p.get("scripts", 0) or 0)
    }
    q["region"] = classify_region(p)
    q["tech"] = classify_tech(p)
    clean_pages.append(q)

by_region = defaultdict(list)
by_tech = defaultdict(list)
for p in clean_pages:
    by_region[p["region"]].append(p)
    by_tech[p["tech"]].append(p)

for key, r in REGIONS.items():
    group = by_region[key]
    r["sources"] = len(group)
    r["canvas"] = sum(p["canvas"] for p in group)
    r["scripts"] = sum(p["scripts"] for p in group)
    r["readiness"] = min(99, 55 + len(group) * 3 + sum(p["canvas"] for p in group))
    r["alarms"] = max(0, 3 - min(3, len(group)//6))

for key, t in TECH.items():
    group = by_tech[key]
    t["sources"] = len(group)
    t["canvas"] = sum(p["canvas"] for p in group)
    t["scripts"] = sum(p["scripts"] for p in group)

data = {
    "regions": REGIONS,
    "tech": TECH,
    "pages": clean_pages
}
normalized.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
data_json = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")

html = r'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>TRFMC 5D Geo Multi-Technology Command Center</title>
<style>
:root{
  --bg:#020812;--panel:rgba(3,14,28,.82);--panel2:rgba(0,10,22,.92);
  --line:rgba(103,232,249,.18);--text:#e8f7ff;--muted:#9fb8ca;
  --cyan:#67e8f9;--green:#86efac;--amber:#fbbf24;--red:#fb7185;--violet:#c084fc;
}
*{box-sizing:border-box}
body{
  margin:0;color:var(--text);font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
  background:
    radial-gradient(circle at 15% 7%,rgba(14,165,233,.24),transparent 31%),
    radial-gradient(circle at 84% 4%,rgba(16,185,129,.16),transparent 29%),
    radial-gradient(circle at 50% 45%,rgba(192,132,252,.10),transparent 36%),
    linear-gradient(180deg,#020812,#020617 55%,#00040b);
  overflow-x:hidden;
}
#fx{position:fixed;inset:0;z-index:-3;opacity:.65}
body:before{
  content:"";position:fixed;inset:0;z-index:-2;
  background:
    linear-gradient(rgba(103,232,249,.035) 1px,transparent 1px),
    linear-gradient(90deg,rgba(103,232,249,.035) 1px,transparent 1px);
  background-size:44px 44px;
  mask-image:radial-gradient(circle at 50% 20%,black,transparent 78%);
}
nav{
  position:sticky;top:0;z-index:90;display:flex;gap:8px;flex-wrap:wrap;align-items:center;
  padding:10px 22px;border-bottom:1px solid var(--line);background:rgba(2,8,18,.94);backdrop-filter:blur(18px);
}
nav a,nav button{
  border:1px solid rgba(103,232,249,.24);border-radius:999px;padding:8px 12px;color:var(--text);
  background:rgba(0,12,24,.72);text-decoration:none;font-size:12px;font-weight:950;cursor:pointer;
}
nav a:hover,nav button:hover{color:var(--green);border-color:rgba(134,239,172,.58);box-shadow:0 0 22px rgba(16,185,129,.13)}
.shell{max-width:1920px;margin:0 auto;padding:20px 22px 44px}
.hero{
  border:1px solid var(--line);border-radius:34px;padding:22px;
  background:
    radial-gradient(circle at 86% 8%,rgba(103,232,249,.17),transparent 31%),
    linear-gradient(135deg,rgba(0,19,34,.91),rgba(0,7,16,.76));
  box-shadow:0 38px 140px rgba(0,0,0,.42)
}
.eyebrow{color:var(--cyan);font-size:11px;font-weight:950;letter-spacing:.15em;text-transform:uppercase}
h1{margin:10px 0 0;font-size:52px;letter-spacing:-.065em;line-height:.95}
.hero p{max-width:1240px;color:var(--muted);line-height:1.55}
.kpis{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:10px;margin-top:18px}
.kpi{border:1px solid rgba(103,232,249,.14);border-radius:19px;padding:13px;background:rgba(0,9,20,.65);overflow:hidden;position:relative}
.kpi span{display:block;color:var(--muted);font-size:10px;font-weight:950;text-transform:uppercase;letter-spacing:.11em}
.kpi strong{display:block;margin-top:6px;color:var(--green);font-size:28px}
.layout{display:grid;grid-template-columns:1.2fr 430px;gap:14px;margin-top:14px;align-items:start}
.geo-stage{
  min-height:720px;border:1px solid var(--line);border-radius:30px;background:var(--panel);padding:16px;position:relative;overflow:hidden;
  box-shadow:0 28px 120px rgba(0,0,0,.34)
}
.geo-head{display:flex;justify-content:space-between;gap:12px;border-bottom:1px solid rgba(103,232,249,.10);padding-bottom:12px}
.geo-head h2{margin:4px 0;font-size:30px;letter-spacing:-.04em}
.geo-head p{margin:0;color:var(--muted)}
.mode-pill{border:1px solid rgba(134,239,172,.26);border-radius:999px;padding:8px 11px;color:var(--green);background:rgba(8,47,38,.18);font-weight:950;font-size:12px;height:max-content}
.map-wrap{position:relative;margin-top:14px;height:430px;border:1px solid rgba(103,232,249,.13);border-radius:26px;background:radial-gradient(circle at 50% 50%,rgba(103,232,249,.10),transparent 42%),rgba(0,8,18,.64);overflow:hidden}
.map-svg{position:absolute;inset:0;width:100%;height:100%}
.region-node{
  position:absolute;transform:translate(-50%,-50%);min-width:132px;
  border:1px solid rgba(103,232,249,.22);border-radius:18px;padding:10px;background:rgba(0,12,24,.82);
  box-shadow:0 12px 40px rgba(0,0,0,.28);cursor:pointer
}
.region-node.active{border-color:rgba(134,239,172,.74);box-shadow:0 0 34px rgba(16,185,129,.18)}
.region-node b{display:block;font-size:12px}
.region-node span{display:block;color:var(--muted);font-size:10px;margin-top:4px}
.region-node strong{display:block;color:var(--green);font-size:20px;margin-top:5px}
.layer-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px;margin-top:12px}
.layer{border:1px solid rgba(103,232,249,.12);border-radius:18px;padding:12px;background:rgba(0,9,20,.62)}
.layer b{display:block;color:var(--cyan)}
.layer span{display:block;color:var(--muted);font-size:12px;margin-top:5px;line-height:1.35}
.region-detail{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:12px}
.detail-card{border:1px solid rgba(103,232,249,.12);border-radius:20px;padding:13px;background:rgba(0,9,20,.62)}
.detail-card h3{margin:0 0 8px;font-size:18px}
.meter{height:10px;border-radius:999px;background:rgba(103,232,249,.10);overflow:hidden}
.meter i{display:block;height:100%;border-radius:999px;background:linear-gradient(90deg,var(--green),var(--cyan));width:50%}
.page-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;max-height:245px;overflow:auto}
.page-card{display:flex;flex-direction:column;gap:5px;border:1px solid rgba(103,232,249,.13);border-radius:15px;padding:10px;color:inherit;text-decoration:none;background:rgba(0,8,18,.68)}
.page-card:hover{border-color:rgba(134,239,172,.55);box-shadow:0 0 25px rgba(16,185,129,.10)}
.page-card span{color:var(--cyan);font-size:9px;text-transform:uppercase;font-weight:950}
.page-card strong{font-size:12px;line-height:1.15}
.page-card em{color:var(--muted);font-size:10px;font-style:normal;word-break:break-word}
.side{display:grid;gap:14px}
.panel{border:1px solid var(--line);border-radius:28px;background:var(--panel);padding:16px;box-shadow:0 22px 90px rgba(0,0,0,.30)}
.panel h3{margin:0 0 10px;font-size:20px}
.tech-list{display:grid;gap:8px}
.tech{display:grid;grid-template-columns:1fr auto;gap:8px;align-items:center;border:1px solid rgba(103,232,249,.12);border-radius:16px;padding:10px;background:rgba(0,9,20,.62)}
.tech b{font-size:12px}
.tech span{color:var(--muted);font-size:11px}
.tech strong{color:var(--green)}
.events{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;color:#b8f7d0;line-height:1.45;max-height:210px;overflow:auto}
.event{border-bottom:1px solid rgba(103,232,249,.08);padding:6px 0}
@media(max-width:1500px){.layout{grid-template-columns:1fr}.kpis{grid-template-columns:repeat(3,1fr)}.layer-grid{grid-template-columns:repeat(3,1fr)}}
@media(max-width:900px){h1{font-size:36px}.kpis,.layer-grid,.region-detail,.page-grid{grid-template-columns:1fr}.map-wrap{height:560px}.region-node{min-width:110px}}
</style>
</head>
<body data-trfmc-5d-geo-command-center="mounted">
<canvas id="fx"></canvas>
<nav>
  <button onclick="history.back()">← Indietro</button>
  <a href="/#portal-os-preview">Portal OS</a>
  <a href="/trfmc_visual_enterprise_command_center_v1.html">Visual Enterprise</a>
  <a href="/trfmc_page_review_cockpit_v1.html">Review Cockpit</a>
  <a href="/trfmc_working_pages_control_room_v1.html">Working Pages</a>
</nav>

<div class="shell">
  <section class="hero">
    <div class="eyebrow">TRFMC · 5D geo/multi-technology operational twin</div>
    <h1>5D Geo Multi-Technology Command Center</h1>
    <p>
      Dashboard unica: geografia, tecnologia, assurance, orchestrazione e evidence nello stesso viewport.
      Il modello è una control room TELCO: regioni operative, layer RF/Core/DSP/Antenna/Fiber, widget live e pagine legacy come sorgenti controllate.
    </p>
    <div class="kpis">
      <div class="kpi"><span>Sources</span><strong id="kSources">0</strong></div>
      <div class="kpi"><span>Regions</span><strong id="kRegions">0</strong></div>
      <div class="kpi"><span>Technologies</span><strong id="kTech">0</strong></div>
      <div class="kpi"><span>Canvas</span><strong id="kCanvas">0</strong></div>
      <div class="kpi"><span>Proxy</span><strong id="kProxy">CHECK</strong></div>
      <div class="kpi"><span>Posture</span><strong>QA</strong></div>
    </div>
  </section>

  <section class="layout">
    <main class="geo-stage">
      <div class="geo-head">
        <div>
          <div class="eyebrow">GEOGRAPHIC / SERVICE DIGITAL TWIN</div>
          <h2 id="regionTitle">—</h2>
          <p id="regionSubtitle">—</p>
        </div>
        <div class="mode-pill" id="regionMode">REGION ACTIVE</div>
      </div>

      <section class="map-wrap" id="mapWrap">
        <svg class="map-svg" viewBox="0 0 1000 500">
          <defs>
            <radialGradient id="g"><stop stop-color="#67e8f9" stop-opacity=".18"/><stop offset="1" stop-color="#67e8f9" stop-opacity="0"/></radialGradient>
          </defs>
          <ellipse cx="500" cy="250" rx="430" ry="170" fill="none" stroke="rgba(103,232,249,.16)" stroke-width="2"/>
          <ellipse cx="500" cy="250" rx="310" ry="120" fill="none" stroke="rgba(134,239,172,.13)" stroke-width="1"/>
          <path d="M100 250 C270 110 730 110 900 250 C730 390 270 390 100 250Z" fill="url(#g)" stroke="rgba(192,132,252,.16)"/>
          <path d="M520 80 C490 160 500 340 520 420" fill="none" stroke="rgba(103,232,249,.10)"/>
          <path d="M220 170 C410 250 590 250 780 170" fill="none" stroke="rgba(103,232,249,.08)"/>
          <path d="M220 330 C410 250 590 250 780 330" fill="none" stroke="rgba(103,232,249,.08)"/>
        </svg>
        <div id="regionNodes"></div>
      </section>

      <section class="layer-grid">
        <article class="layer"><b>Geography</b><span>Regioni operative definite: Lab, Europe, Americas, APAC, Africa/ME, NTN.</span></article>
        <article class="layer"><b>Technology</b><span>RF, Antenna, DSP, Core/RAN, Fiber/DC, Assurance, Security.</span></article>
        <article class="layer"><b>Assurance</b><span>Readiness, allarmi, health, evidence e quality state.</span></article>
        <article class="layer"><b>Orchestration</b><span>API proxy, bridge, workflow e integrazione controllata.</span></article>
        <article class="layer"><b>Evidence</b><span>Legacy pages usate come sorgenti, non come navigazione primaria.</span></article>
      </section>

      <section class="region-detail">
        <article class="detail-card">
          <h3>Region readiness</h3>
          <div class="meter"><i id="readinessBar"></i></div>
          <p id="regionStats" style="color:var(--muted);line-height:1.45"></p>
        </article>
        <article class="detail-card">
          <h3>Region source evidence</h3>
          <div class="page-grid" id="pageGrid"></div>
        </article>
      </section>
    </main>

    <aside class="side">
      <section class="panel">
        <h3>Technology Widgets</h3>
        <div class="tech-list" id="techList"></div>
      </section>
      <section class="panel">
        <h3>Live Contracts</h3>
        <div class="tech-list">
          <div class="tech"><b>Backend 8000</b><span id="backendStatus">checking...</span><strong id="backendCode">—</strong></div>
          <div class="tech"><b>Bridge 4181</b><span id="bridgeStatus">checking...</span><strong id="bridgeCode">—</strong></div>
          <div class="tech"><b>Same-origin proxy</b><span id="proxyStatus">checking...</span><strong id="proxyCode">—</strong></div>
        </div>
      </section>
      <section class="panel">
        <h3>Event Stream</h3>
        <div class="events" id="events"></div>
      </section>
    </aside>
  </section>
</div>

<script>
const DATA = __DATA_JSON__;
const regions = DATA.regions || {};
const tech = DATA.tech || {};
const pages = DATA.pages || [];
let activeRegion = Object.keys(regions)[0] || "lab";

function esc(s){return String(s??"").replace(/[&<>"']/g,ch=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#039;"}[ch]))}
function logEvent(msg){
  const el=document.getElementById("events");
  const t=new Date().toLocaleTimeString();
  el.innerHTML = `<div class="event">[${t}] ${esc(msg)}</div>` + el.innerHTML;
}
function renderKpi(){
  document.getElementById("kSources").textContent=pages.length;
  document.getElementById("kRegions").textContent=Object.keys(regions).length;
  document.getElementById("kTech").textContent=Object.keys(tech).length;
  document.getElementById("kCanvas").textContent=pages.reduce((a,p)=>a+(Number(p.canvas)||0),0);
}
function renderRegions(){
  const root=document.getElementById("regionNodes");
  root.innerHTML=Object.entries(regions).map(([key,r])=>`
    <button class="region-node ${key===activeRegion?"active":""}" data-region="${esc(key)}" style="left:${r.x}%;top:${r.y}%;border-color:${esc(r.color)}66">
      <b style="color:${esc(r.color)}">${esc(r.title)}</b>
      <span>${Number(r.canvas)||0} canvas · ${Number(r.alarms)||0} alarms</span>
      <strong>${Number(r.readiness)||0}%</strong>
    </button>
  `).join("");
  root.querySelectorAll("[data-region]").forEach(btn=>btn.addEventListener("click",()=>{
    activeRegion=btn.dataset.region;
    renderAll();
    logEvent(`region switched → ${regions[activeRegion].title}`);
  }));
}
function renderRegionDetail(){
  const r=regions[activeRegion]||{};
  document.getElementById("regionTitle").textContent=r.title||activeRegion;
  document.getElementById("regionSubtitle").textContent=r.subtitle||"";
  document.getElementById("regionMode").textContent=`${Number(r.sources)||0} SOURCES · ${Number(r.readiness)||0}%`;
  document.getElementById("readinessBar").style.width=`${Math.max(2,Number(r.readiness)||0)}%`;
  document.getElementById("regionStats").innerHTML=
    `<b>${Number(r.sources)||0}</b> sources · <b>${Number(r.canvas)||0}</b> canvas · <b>${Number(r.scripts)||0}</b> scripts · <b>${Number(r.alarms)||0}</b> active alarms`;

  const group=pages.filter(p=>p.region===activeRegion).slice(0,12);
  document.getElementById("pageGrid").innerHTML=group.length ? group.map(p=>`
    <a class="page-card" href="${esc(p.url)}" target="_blank" rel="noreferrer">
      <span>${esc(p.tech)} / ${esc(p.category)}</span>
      <strong>${esc(p.title)}</strong>
      <em>${esc(p.url)}</em>
    </a>
  `).join("") : `<div class="empty">Nessuna sorgente classificata in questa regione.</div>`;
}
function renderTech(){
  document.getElementById("techList").innerHTML=Object.entries(tech).map(([key,t])=>`
    <div class="tech" style="border-color:${esc(t.color)}44">
      <div><b style="color:${esc(t.color)}">${esc(t.title)}</b><span>${Number(t.canvas)||0} canvas · ${Number(t.scripts)||0} script</span></div>
      <strong>${Number(t.sources)||0}</strong>
    </div>
  `).join("");
}
async function checkEndpoint(label,url,statusId,codeId){
  try{
    const res=await fetch(url,{cache:"no-store"});
    const txt=await res.text();
    let json=false;
    try{JSON.parse(txt);json=true}catch(e){}
    document.getElementById(statusId).textContent=json?"JSON OK":(txt.includes("<html")?"HTML fallback":"non-json");
    document.getElementById(codeId).textContent=String(res.status);
    logEvent(`${label} ${res.status} ${json?"JSON":"NOJSON"}`);
    return json && res.ok;
  }catch(e){
    document.getElementById(statusId).textContent="offline";
    document.getElementById(codeId).textContent="ERR";
    logEvent(`${label} offline`);
    return false;
  }
}
async function liveContracts(){
  const b=await checkEndpoint("backend","/trfmc-api/backend/api/health","backendStatus","backendCode");
  const br=await checkEndpoint("bridge","/trfmc-api/bridge/api/health","bridgeStatus","bridgeCode");
  const p=b&&br;
  document.getElementById("proxyStatus").textContent=p?"proxy contract OK":"proxy degraded";
  document.getElementById("proxyCode").textContent=p?"OK":"WARN";
  document.getElementById("kProxy").textContent=p?"OK":"WARN";
}
function renderAll(){
  renderKpi();renderRegions();renderRegionDetail();renderTech();
}
renderAll();
liveContracts();
logEvent("5D Geo Multi-Technology Command Center mounted");

const canvas=document.getElementById("fx"),ctx=canvas.getContext("2d");let pts=[];
function resize(){
  canvas.width=innerWidth*devicePixelRatio;canvas.height=innerHeight*devicePixelRatio;
  canvas.style.width=innerWidth+"px";canvas.style.height=innerHeight+"px";ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0);
  pts=Array.from({length:Math.min(150,Math.floor(innerWidth/10))},()=>({x:Math.random()*innerWidth,y:Math.random()*innerHeight,vx:(Math.random()-.5)*.32,vy:(Math.random()-.5)*.32,r:Math.random()*1.6+.4}));
}
function tick(){
  ctx.clearRect(0,0,innerWidth,innerHeight);
  for(const p of pts){p.x+=p.vx;p.y+=p.vy;if(p.x<0||p.x>innerWidth)p.vx*=-1;if(p.y<0||p.y>innerHeight)p.vy*=-1}
  ctx.strokeStyle="rgba(103,232,249,.07)";
  for(let i=0;i<pts.length;i++)for(let j=i+1;j<pts.length;j++){
    const a=pts[i],b=pts[j],dx=a.x-b.x,dy=a.y-b.y,d=Math.sqrt(dx*dx+dy*dy);
    if(d<135){ctx.globalAlpha=1-d/135;ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke()}
  }
  ctx.globalAlpha=1;ctx.fillStyle="rgba(103,232,249,.55)";
  for(const p of pts){ctx.beginPath();ctx.arc(p.x,p.y,p.r,0,Math.PI*2);ctx.fill()}
  requestAnimationFrame(tick);
}
addEventListener("resize",resize);resize();tick();
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
code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" http://127.0.0.1:5173/trfmc_5d_geo_multitech_command_center_v1.html 2>/dev/null || echo 000)"
bytes="$(wc -c < "$tmp" | tr -d ' ')"
hint="TEXT"
grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
result="OK"
[ "$code" != "200" ] && result="NON_200"
[ "$bytes" = "0" ] && result="ZERO_BYTES"
printf "%s\t%s\t%s\t%s\t%s\n" "http://127.0.0.1:5173/trfmc_5d_geo_multitech_command_center_v1.html" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
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
    --dump-dom http://127.0.0.1:5173/trfmc_5d_geo_multitech_command_center_v1.html > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --screenshot="$SCREEN" http://127.0.0.1:5173/trfmc_5d_geo_multitech_command_center_v1.html >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

MOUNT_COUNT="$(grep -o 'data-trfmc-5d-geo-command-center="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
REGION_COUNT="$(grep -o 'class="region-node' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
TECH_COUNT="$(grep -o 'class="tech"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
CANVAS_COUNT="$(grep -o '<canvas' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$MOUNT_COUNT" = "0" ] && RESULT="FAIL_MARKER"
[ "$REGION_COUNT" -lt 5 ] && RESULT="FAIL_REGIONS"
[ "$TECH_COUNT" -lt 5 ] && RESULT="FAIL_TECH_WIDGETS"
[ "$CANVAS_COUNT" = "0" ] && RESULT="FAIL_CANVAS"
[ "$SCREENSHOT_RESULT" != "PASS" ] && RESULT="FAIL_SCREENSHOT"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P7E_5D_GEO_MULTITECH_COMMAND_CENTER_V1",
  "mutation": "public_static_5d_geo_multitech_dashboard",
  "react_mutation": false,
  "backend_mutation": false,
  "data_source": "$DATA_SRC",
  "dashboard": "$DASH",
  "url": "http://127.0.0.1:5173/trfmc_5d_geo_multitech_command_center_v1.html",
  "normalized_data": "$NORMALIZED",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "mount_count": $MOUNT_COUNT,
  "region_count": $REGION_COUNT,
  "tech_widget_count": $TECH_COUNT,
  "canvas_count": $CANVAS_COUNT,
  "http_failures": $HTTP_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p7e_5d_geo_multitech_command_center_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P7E_5D_GEO_MULTITECH_COMMAND_CENTER_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
