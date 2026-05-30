#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P7C_SINGLE_ENTERPRISE_TELCO_DASHBOARD_V1_$TS"

mkdir -p "$OUT"
cd "$BASE" || exit 1

AUDIT_SRC=""
if [ -f runtime/quality/latest_restart_vite_5173_and_retry_runtime_audit_v1/public_pages_runtime_retry.tsv ]; then
  AUDIT_SRC="runtime/quality/latest_restart_vite_5173_and_retry_runtime_audit_v1/public_pages_runtime_retry.tsv"
elif [ -f runtime/quality/latest_deep_multi_agent_audit_v2_readonly/agent_07_public_pages.tsv ]; then
  AUDIT_SRC="runtime/quality/latest_deep_multi_agent_audit_v2_readonly/agent_07_public_pages.tsv"
elif [ -f runtime/quality/latest_p6a_activate_working_real_pages_dashboard_v1/working_pages_audit.tsv ]; then
  AUDIT_SRC="runtime/quality/latest_p6a_activate_working_real_pages_dashboard_v1/working_pages_audit.tsv"
fi

DASH="frontend/public/trfmc_enterprise_telco_command_center_v1.html"
DATA_JSON="$OUT/enterprise_telco_dashboard_data.json"
SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_enterprise_telco_dashboard.txt"
SCREEN="$OUT/enterprise_telco_dashboard_1920x1080.png"
OBSOLETE="$OUT/P7B_OBSOLETE_NOTICE.md"

echo "============================================================"
echo "TRFMC_P7C_SINGLE_ENTERPRISE_TELCO_DASHBOARD_V1"
echo "Una sola dashboard enterprise con aree interne, no nuove pagine-area"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$AUDIT_SRC" ] || [ ! -f "$AUDIT_SRC" ]; then
  echo "ERRORE: audit sorgente non trovato."
  exit 1
fi

cat > "$OBSOLETE" <<TXT
# P7B OBSOLETO

P7B ha creato pagine area separate e ha classificato male le pagine:
- rf-physics = quasi tutte le pagine;
- molte aree = zero pagine.

Regola nuova:
- non creare più pagine per area;
- una sola dashboard enterprise;
- aree come pannelli interni;
- pagine legacy solo come link/evidence.
TXT

python3 - "$AUDIT_SRC" "$DASH" "$DATA_JSON" <<'PY'
import csv, html, json, sys
from pathlib import Path
from collections import defaultdict, Counter

audit = Path(sys.argv[1])
dash = Path(sys.argv[2])
data_json = Path(sys.argv[3])

AREAS = {
    "mission": {
        "title": "Mission Control",
        "subtitle": "Vista executive/NOC, stato globale, readiness, indice operativo.",
        "keywords": ["mission", "overview", "dashboard", "control", "registry", "portal", "command", "executive", "nexus"],
        "icon": "◈"
    },
    "assurance": {
        "title": "Assurance / Observability",
        "subtitle": "Eventi, allarmi, evidence, SLA, readiness e correlazione.",
        "keywords": ["assurance", "alarm", "alarms", "evidence", "flight", "recorder", "health", "readiness", "correlation", "noc", "ops", "war_room", "war room"],
        "icon": "◎"
    },
    "orchestration": {
        "title": "Orchestration / Automation",
        "subtitle": "Lifecycle, scenari, workflow, activation, proxy API, bridge.",
        "keywords": ["orchestr", "automation", "lifecycle", "scenario", "runner", "activation", "proxy", "api", "bridge", "workflow"],
        "icon": "⟲"
    },
    "core_ran": {
        "title": "5G Core / RAN",
        "subtitle": "Open5GS, UERANSIM, NGAP, PFCP, GTP-U, identità e slice.",
        "keywords": ["open5gs", "ueransim", "ngap", "pfcp", "gtp", "supi", "suci", "aka", "core", "ran", "slice", "slicing", "gnb"],
        "icon": "5G"
    },
    "signal_dsp": {
        "title": "Signal / DSP / Measurement",
        "subtitle": "FFT, IQ, waterfall, VSA, measurement chain e strumentazione.",
        "keywords": ["dsp", "fft", "iq", "waterfall", "signal", "spectrum", "measurement", "vsa", "analyzer", "trace"],
        "icon": "∿"
    },
    "rf_microwave": {
        "title": "RF / Microwave Physics",
        "subtitle": "Fisica RF, propagazione, microonde, link budget, modelli e formule.",
        "keywords": ["microwave", "fresnel", "smith", "propagation", "link budget", "rf_physics", "wave", "em_", "maxwell"],
        "icon": "λ"
    },
    "antenna": {
        "title": "Antenna / RRU / RET / CPRI",
        "subtitle": "Pattern, array, MIMO, mapping porte, AISG/RET/CPRI.",
        "keywords": ["antenna", "rru", "ret", "cpri", "aisg", "mimo", "beam", "array", "pattern", "downtilt"],
        "icon": "⌁"
    },
    "infrastructure": {
        "title": "Infrastructure / Fiber / Power",
        "subtitle": "Fibra, DC, power, rack, ODF, fronthaul, physical plant.",
        "keywords": ["fiber", "otdr", "fronthaul", "odf", "datacenter", "data_center", "power", "pdu", "ups", "rack"],
        "icon": "▦"
    },
    "knowledge": {
        "title": "Knowledge Base / Academy",
        "subtitle": "Teoria, glossario, procedure, tutorial, lesson plan.",
        "keywords": ["knowledge", "theory", "academy", "glossary", "lesson", "procedure", "training", "reference"],
        "icon": "Σ"
    }
}

def get_num(row, *keys):
    for k in keys:
        v = row.get(k)
        if v not in (None, ""):
            try:
                return int(v)
            except Exception:
                return 0
    return 0

def classify(row):
    text = " ".join([
        row.get("category",""),
        row.get("title",""),
        row.get("url",""),
        row.get("file",""),
    ]).lower()

    scores = {}
    for key, area in AREAS.items():
        score = 0
        for kw in area["keywords"]:
            if kw in text:
                score += 10 if len(kw) > 3 else 2
        scores[key] = score

    best = max(scores, key=scores.get)
    if scores[best] <= 0:
        return "knowledge"
    return best

pages = []
with audit.open("r", encoding="utf-8", errors="replace", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for r in reader:
        status = (r.get("status") or r.get("result") or "").strip()
        if not status.startswith("ACTIVE"):
            continue

        url = (r.get("url") or "").strip()
        if not url.startswith("/"):
            continue

        title = (r.get("title") or r.get("file") or url).strip()
        area = classify(r)

        pages.append({
            "area": area,
            "title": title,
            "url": url,
            "file": (r.get("file") or "").strip(),
            "category": (r.get("category") or "reference").strip(),
            "bytes": get_num(r, "bytes"),
            "canvas": get_num(r, "canvas", "canvas_source", "dom_canvas_count"),
            "scripts": get_num(r, "scripts", "script_tags"),
        })

# Bilanciamento: una pagina può comunque essere RF generica, ma non usiamo mai "rf" da solo per classificare.
pages.sort(key=lambda p: (p["area"], -p["canvas"], -p["scripts"], p["title"].lower()))
by_area = defaultdict(list)
for p in pages:
    by_area[p["area"]].append(p)

data_json.write_text(json.dumps({"areas": AREAS, "pages": pages}, indent=2, ensure_ascii=False), encoding="utf-8")

area_buttons = []
area_panels = []

for key, area in AREAS.items():
    group = by_area.get(key, [])
    count = len(group)
    canvas = sum(p["canvas"] for p in group)
    scripts = sum(p["scripts"] for p in group)

    area_buttons.append(f"""
      <button class="area-button" data-area-button="{html.escape(key)}">
        <span>{html.escape(area['icon'])}</span>
        <strong>{html.escape(area['title'])}</strong>
        <em>{count} pagine · canvas {canvas}</em>
      </button>
    """)

    cards = []
    for p in group[:24]:
        cards.append(f"""
          <a class="page-card" href="{html.escape(p['url'])}" target="_blank" rel="noreferrer">
            <span>{html.escape(p['category'])}</span>
            <strong>{html.escape(p['title'])}</strong>
            <em>{html.escape(p['url'])}</em>
            <small>canvas {p['canvas']} · script {p['scripts']}</small>
          </a>
        """)

    if not cards:
        cards.append('<div class="empty">Nessuna pagina ACTIVE assegnata. Questa area richiede recupero o classificazione manuale.</div>')

    area_panels.append(f"""
      <section class="area-panel" data-area-panel="{html.escape(key)}">
        <div class="panel-head">
          <div>
            <div class="panel-icon">{html.escape(area['icon'])}</div>
            <h2>{html.escape(area['title'])}</h2>
            <p>{html.escape(area['subtitle'])}</p>
          </div>
          <div class="mini-kpis">
            <div><b>{count}</b><span>pagine</span></div>
            <div><b>{canvas}</b><span>canvas</span></div>
            <div><b>{scripts}</b><span>script</span></div>
          </div>
        </div>
        <div class="panel-body">
          <div class="enterprise-lanes">
            <article><b>Assurance</b><span>QA visivo, DOM, link, ritorno home.</span></article>
            <article><b>Integration</b><span>Promuovere solo pagine mature nel Portal OS.</span></article>
            <article><b>React Candidate</b><span>War Room, DSP, Antenna e Core/RAN prima degli altri.</span></article>
          </div>
          <div class="page-grid">{''.join(cards)}</div>
        </div>
      </section>
    """)

total_canvas = sum(p["canvas"] for p in pages)
total_scripts = sum(p["scripts"] for p in pages)

doc = f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>TRFMC Enterprise Telco Command Center</title>
<style>
:root {{
  --bg:#020812; --panel:rgba(3,14,28,.82); --line:rgba(103,232,249,.18);
  --text:#e8f7ff; --muted:#9fb8ca; --cyan:#67e8f9; --green:#86efac;
  --amber:#fbbf24; --red:#fb7185; --violet:#c084fc;
}}
* {{ box-sizing:border-box; }}
body {{
  margin:0; color:var(--text); font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
  background:
    radial-gradient(circle at 12% 7%, rgba(14,165,233,.22), transparent 30%),
    radial-gradient(circle at 88% 0%, rgba(16,185,129,.16), transparent 28%),
    radial-gradient(circle at 48% 42%, rgba(192,132,252,.08), transparent 34%),
    linear-gradient(180deg,#020812,#020617 55%,#00040b);
}}
.top-nav {{
  position:sticky; top:0; z-index:60; display:flex; flex-wrap:wrap; gap:8px; padding:10px 22px;
  border-bottom:1px solid var(--line); background:rgba(2,8,18,.94); backdrop-filter:blur(18px);
}}
.top-nav a,.top-nav button {{
  border:1px solid rgba(103,232,249,.22); border-radius:999px; padding:8px 11px;
  color:var(--text); background:rgba(0,12,24,.72); text-decoration:none; font-size:12px; font-weight:900; cursor:pointer;
}}
.top-nav a:hover,.top-nav button:hover {{ color:var(--green); border-color:rgba(134,239,172,.55); }}
.shell {{ max-width:1900px; margin:0 auto; padding:22px; }}
.hero {{
  border:1px solid var(--line); border-radius:32px; padding:24px;
  background:
    radial-gradient(circle at 88% 10%, rgba(103,232,249,.17), transparent 30%),
    linear-gradient(135deg, rgba(0,19,34,.88), rgba(0,7,16,.76));
  box-shadow:0 35px 130px rgba(0,0,0,.40);
}}
.eyebrow {{ color:var(--cyan); font-size:11px; font-weight:950; letter-spacing:.14em; text-transform:uppercase; }}
h1 {{ margin:8px 0 0; font-size:44px; letter-spacing:-.055em; line-height:1; }}
.hero p {{ color:var(--muted); max-width:1220px; line-height:1.55; }}
.kpis {{ display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:10px; margin-top:18px; }}
.kpi {{ border:1px solid rgba(103,232,249,.14); border-radius:18px; padding:13px; background:rgba(0,9,20,.65); }}
.kpi span {{ display:block; color:var(--muted); font-size:10px; font-weight:900; text-transform:uppercase; letter-spacing:.11em; }}
.kpi strong {{ display:block; color:var(--green); font-size:28px; margin-top:5px; }}
.command-layout {{ display:grid; grid-template-columns:380px 1fr; gap:14px; margin-top:16px; align-items:start; }}
.area-map {{
  position:sticky; top:62px; border:1px solid var(--line); border-radius:26px; padding:12px;
  background:rgba(3,14,28,.82);
}}
.area-button {{
  width:100%; text-align:left; margin-bottom:8px; border:1px solid rgba(103,232,249,.13);
  border-radius:18px; padding:12px; background:rgba(0,9,20,.72); color:inherit; cursor:pointer;
}}
.area-button.active {{ border-color:rgba(134,239,172,.60); box-shadow:0 0 28px rgba(16,185,129,.10); }}
.area-button span {{ display:inline-flex; width:32px; height:32px; align-items:center; justify-content:center;
  border-radius:12px; background:rgba(103,232,249,.12); color:var(--cyan); font-weight:950; }}
.area-button strong {{ display:block; margin-top:8px; }}
.area-button em {{ display:block; margin-top:4px; color:var(--muted); font-style:normal; font-size:11px; }}
.area-panel {{
  display:none; border:1px solid var(--line); border-radius:28px; padding:16px; background:rgba(3,14,28,.76);
}}
.area-panel.active {{ display:block; }}
.panel-head {{ display:flex; justify-content:space-between; gap:12px; border-bottom:1px solid rgba(103,232,249,.10); padding-bottom:12px; }}
.panel-icon {{ color:var(--cyan); font-size:28px; font-weight:950; }}
.panel-head h2 {{ margin:4px 0; font-size:30px; letter-spacing:-.04em; }}
.panel-head p {{ margin:0; color:var(--muted); }}
.mini-kpis {{ display:grid; grid-template-columns:repeat(3,90px); gap:8px; }}
.mini-kpis div {{ border:1px solid rgba(103,232,249,.13); border-radius:16px; text-align:center; padding:10px; background:rgba(0,9,20,.62); }}
.mini-kpis b {{ display:block; color:var(--green); font-size:22px; }}
.mini-kpis span {{ color:var(--muted); font-size:10px; text-transform:uppercase; font-weight:900; }}
.enterprise-lanes {{ display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:10px; margin:14px 0; }}
.enterprise-lanes article {{ border:1px solid rgba(103,232,249,.12); border-radius:18px; padding:12px; background:rgba(0,9,20,.62); }}
.enterprise-lanes b {{ display:block; color:var(--cyan); }}
.enterprise-lanes span {{ display:block; margin-top:5px; color:var(--muted); font-size:12px; line-height:1.35; }}
.page-grid {{ display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:10px; }}
.page-card {{
  min-height:130px; display:flex; flex-direction:column; gap:7px; color:inherit; text-decoration:none;
  border:1px solid rgba(103,232,249,.14); border-radius:18px; padding:12px; background:rgba(0,8,18,.72);
}}
.page-card:hover {{ border-color:rgba(134,239,172,.54); box-shadow:0 0 32px rgba(16,185,129,.10); }}
.page-card span {{ color:var(--cyan); font-size:9px; font-weight:950; text-transform:uppercase; letter-spacing:.10em; }}
.page-card strong {{ font-size:13px; line-height:1.16; }}
.page-card em {{ color:var(--muted); font-size:10px; font-style:normal; word-break:break-word; }}
.page-card small {{ margin-top:auto; color:var(--amber); font-size:10px; font-weight:850; }}
.empty {{ color:var(--muted); padding:16px; }}
@media(max-width:1400px) {{ .command-layout {{ grid-template-columns:1fr; }} .area-map {{ position:relative; top:auto; display:grid; grid-template-columns:repeat(3,1fr); gap:8px; }} .area-button {{ margin-bottom:0; }} }}
@media(max-width:900px) {{ .kpis,.enterprise-lanes,.page-grid,.mini-kpis,.area-map {{ grid-template-columns:1fr; }} h1 {{ font-size:34px; }} }}
</style>
</head>
<body data-trfmc-enterprise-telco-command-center="mounted">
<nav class="top-nav">
  <button onclick="history.back()">← Indietro</button>
  <a href="/#portal-os-preview">Portal OS</a>
  <a href="/trfmc_page_review_cockpit_v1.html">Review Cockpit</a>
  <a href="/trfmc_working_pages_control_room_v1.html">Working Pages</a>
  <a href="/trfmc_rf_tm_war_room_v4.html">War Room legacy</a>
</nav>

<div class="shell">
  <section class="hero">
    <div class="eyebrow">TRFMC · enterprise telco operational shell</div>
    <h1>Enterprise Telco Command Center</h1>
    <p>
      Unica dashboard madre: aree tematiche interne, non nuove pagine sparse. 
      Le pagine legacy restano link/evidence; l'integrazione nel Portal OS avviene solo dopo QA e maturazione.
    </p>
    <div class="kpis">
      <div class="kpi"><span>Active sources</span><strong>{len(pages)}</strong></div>
      <div class="kpi"><span>Areas</span><strong>{len(AREAS)}</strong></div>
      <div class="kpi"><span>Canvas</span><strong>{sum(p['canvas'] for p in pages)}</strong></div>
      <div class="kpi"><span>Scripts</span><strong>{sum(p['scripts'] for p in pages)}</strong></div>
      <div class="kpi"><span>Mode</span><strong>QA</strong></div>
    </div>
  </section>

  <section class="command-layout">
    <aside class="area-map">
      {''.join(area_buttons)}
    </aside>
    <main>
      {''.join(area_panels)}
    </main>
  </section>
</div>

<script>
const buttons = Array.from(document.querySelectorAll('[data-area-button]'));
const panels = Array.from(document.querySelectorAll('[data-area-panel]'));

function activate(area) {{
  buttons.forEach(btn => btn.classList.toggle('active', btn.dataset.areaButton === area));
  panels.forEach(panel => panel.classList.toggle('active', panel.dataset.areaPanel === area));
}}

buttons.forEach(btn => btn.addEventListener('click', () => activate(btn.dataset.areaButton)));
activate('mission');
</script>
</body>
</html>
"""
dash.write_text(doc, encoding="utf-8")
PY

cat > "$HTTP" <<HDR
url	status	bytes	hint	result
HDR

tmp="$(mktemp)"
code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" http://127.0.0.1:5173/trfmc_enterprise_telco_command_center_v1.html 2>/dev/null || echo 000)"
bytes="$(wc -c < "$tmp" | tr -d ' ')"
hint="TEXT"
grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
result="OK"
[ "$code" != "200" ] && result="NON_200"
[ "$bytes" = "0" ] && result="ZERO_BYTES"
printf "%s\t%s\t%s\t%s\t%s\n" "http://127.0.0.1:5173/trfmc_enterprise_telco_command_center_v1.html" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
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
  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=7000 \
    --dump-dom http://127.0.0.1:5173/trfmc_enterprise_telco_command_center_v1.html > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=7000 \
    --screenshot="$SCREEN" http://127.0.0.1:5173/trfmc_enterprise_telco_command_center_v1.html >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

MOUNT_COUNT="$(grep -o 'data-trfmc-enterprise-telco-command-center="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
AREA_BUTTON_COUNT="$(grep -o 'data-area-button=' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
AREA_PANEL_COUNT="$(grep -o 'data-area-panel=' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
PAGE_CARD_COUNT="$(grep -o 'class="page-card"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$MOUNT_COUNT" = "0" ] && RESULT="FAIL_MARKER"
[ "$AREA_BUTTON_COUNT" -lt 5 ] && RESULT="FAIL_AREAS"
[ "$PAGE_CARD_COUNT" = "0" ] && RESULT="FAIL_NO_CARDS"
[ "$SCREENSHOT_RESULT" != "PASS" ] && RESULT="FAIL_SCREENSHOT"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P7C_SINGLE_ENTERPRISE_TELCO_DASHBOARD_V1",
  "mutation": "public_static_single_enterprise_dashboard",
  "react_mutation": false,
  "backend_mutation": false,
  "audit_source": "$AUDIT_SRC",
  "dashboard": "$DASH",
  "url": "http://127.0.0.1:5173/trfmc_enterprise_telco_command_center_v1.html",
  "obsolete_notice": "$OBSOLETE",
  "data_json": "$DATA_JSON",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "mount_count": $MOUNT_COUNT,
  "area_button_count": $AREA_BUTTON_COUNT,
  "area_panel_count": $AREA_PANEL_COUNT,
  "page_card_count": $PAGE_CARD_COUNT,
  "http_failures": $HTTP_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p7c_single_enterprise_telco_dashboard_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P7C_SINGLE_ENTERPRISE_TELCO_DASHBOARD_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
