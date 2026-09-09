#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P7A_THEMATIC_COMMAND_CENTER_V1_$TS"

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

DASH="frontend/public/trfmc_thematic_command_center_v1.html"
DATA_JSON="$OUT/thematic_command_center_data.json"
SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_thematic_command_center.txt"
SCREEN="$OUT/thematic_command_center_1920x1080.png"

echo "============================================================"
echo "TRFMC_P7A_THEMATIC_COMMAND_CENTER_V1"
echo "Dashboard tematica enterprise statica, no React mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$AUDIT_SRC" ] || [ ! -f "$AUDIT_SRC" ]; then
  echo "ERRORE: audit sorgente non trovato."
  exit 1
fi

python3 - "$AUDIT_SRC" "$DASH" "$DATA_JSON" <<'PY'
import csv, html, json, sys
from pathlib import Path
from collections import defaultdict

audit = Path(sys.argv[1])
dash = Path(sys.argv[2])
data_json = Path(sys.argv[3])

THEMES = {
    "mission-control": {
        "label": "Mission Control / Portal OS",
        "keywords": ["mission", "dashboard", "portal", "control", "registry", "executive", "nexus"],
        "icon": "◈",
        "goal": "Home operativa, indice, orchestrazione, stato globale."
    },
    "rf-physics": {
        "label": "RF Physics / Microwave",
        "keywords": ["rf", "physics", "microwave", "spectrum", "smith", "fresnel", "link budget", "wave", "propagation"],
        "icon": "λ",
        "goal": "Fisica RF, formule, simulatori, link budget, microonde."
    },
    "signal-dsp": {
        "label": "Signal / DSP / Measurement",
        "keywords": ["signal", "dsp", "fft", "iq", "waterfall", "spectrum", "measurement", "vsa", "analyzer"],
        "icon": "∿",
        "goal": "FFT, waterfall, IQ, misure, strumentazione e catena DSP."
    },
    "antenna-system": {
        "label": "Antenna / RRU / RET / CPRI",
        "keywords": ["antenna", "rru", "ret", "cpri", "aisg", "beam", "array", "mimo", "pattern"],
        "icon": "⌁",
        "goal": "Pattern, array, port mapping, apparati radio e tilt."
    },
    "core-ran": {
        "label": "5G Core / RAN / Open5GS",
        "keywords": ["core", "ran", "open5gs", "ueransim", "ngap", "pfcp", "gtp", "supi", "suci", "aka"],
        "icon": "5G",
        "goal": "Core/RAN, identità, call-flow, API, proxy e stato live."
    },
    "war-room": {
        "label": "War Room / NOC / Evidence",
        "keywords": ["war", "room", "evidence", "noc", "ops", "alarm", "flight", "recorder"],
        "icon": "◎",
        "goal": "Vista operativa, eventi, evidence, readiness e scenari."
    },
    "fiber-datacenter": {
        "label": "Fiber / Data Center / Power",
        "keywords": ["fiber", "otdr", "fronthaul", "odf", "datacenter", "pdu", "power", "ups", "rack"],
        "icon": "▦",
        "goal": "Infrastruttura fisica, fibra, energia, rack e PDU."
    },
    "knowledge-base": {
        "label": "Knowledge Base / Theory",
        "keywords": ["knowledge", "theory", "academy", "glossary", "procedure", "training", "lesson"],
        "icon": "Σ",
        "goal": "Teoria, procedure, formule, glossario, materiale didattico."
    },
    "reference-lab": {
        "label": "Reference / Lab Utilities",
        "keywords": [],
        "icon": "◇",
        "goal": "Pagine utili, reference, tool secondari e materiale non classificato."
    },
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
    for key, theme in THEMES.items():
        if key == "reference-lab":
            continue
        if any(k in text for k in theme["keywords"]):
            return key
    return "reference-lab"

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
        theme = classify(r)
        pages.append({
            "theme": theme,
            "themeLabel": THEMES[theme]["label"],
            "title": title,
            "url": url,
            "file": (r.get("file") or "").strip(),
            "category": (r.get("category") or "reference").strip(),
            "bytes": get_num(r, "bytes"),
            "canvas": get_num(r, "canvas", "canvas_source", "dom_canvas_count"),
            "scripts": get_num(r, "scripts", "script_tags"),
        })

pages.sort(key=lambda p: (p["theme"], -p["canvas"], p["title"].lower()))
by_theme = defaultdict(list)
for p in pages:
    by_theme[p["theme"]].append(p)

data_json.write_text(json.dumps({
    "themes": THEMES,
    "pages": pages,
}, indent=2, ensure_ascii=False), encoding="utf-8")

theme_tiles = []
theme_sections = []

for key, theme in THEMES.items():
    group = by_theme.get(key, [])
    count = len(group)
    canvas = sum(p["canvas"] for p in group)
    scripts = sum(p["scripts"] for p in group)

    theme_tiles.append(f"""
      <button class="theme-tile" data-theme-target="{html.escape(key)}">
        <span class="theme-icon">{html.escape(theme['icon'])}</span>
        <strong>{html.escape(theme['label'])}</strong>
        <em>{count} pagine · canvas {canvas} · script {scripts}</em>
      </button>
    """)

    cards = []
    for p in group:
        cards.append(f"""
          <a class="page-link" href="{html.escape(p['url'])}" target="_blank" rel="noreferrer">
            <span>{html.escape(p['category'])}</span>
            <strong>{html.escape(p['title'])}</strong>
            <em>{html.escape(p['url'])}</em>
            <small>canvas {p['canvas']} · script {p['scripts']} · {p['bytes']} B</small>
          </a>
        """)

    if not cards:
        cards.append('<div class="empty">Nessuna pagina ACTIVE in questo sottoinsieme.</div>')

    theme_sections.append(f"""
      <section class="theme-section" id="{html.escape(key)}" data-theme="{html.escape(key)}">
        <div class="section-head">
          <div>
            <span>{html.escape(theme['icon'])}</span>
            <h2>{html.escape(theme['label'])}</h2>
            <p>{html.escape(theme['goal'])}</p>
          </div>
          <div class="section-kpi">
            <b>{count}</b>
            <small>ACTIVE</small>
          </div>
        </div>
        <div class="page-grid">
          {''.join(cards)}
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
  <title>TRFMC Thematic Command Center</title>
  <style>
    :root {{
      --bg:#020812; --panel:rgba(3,14,28,.82); --line:rgba(103,232,249,.18);
      --text:#e8f7ff; --muted:#9fb8ca; --cyan:#67e8f9; --green:#86efac;
      --amber:#fbbf24; --red:#fb7185; --violet:#c084fc;
    }}
    * {{ box-sizing:border-box; }}
    body {{
      margin:0; color:var(--text);
      font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
      background:
        radial-gradient(circle at 10% 5%, rgba(14,165,233,.22), transparent 28%),
        radial-gradient(circle at 90% 0%, rgba(16,185,129,.14), transparent 30%),
        radial-gradient(circle at 45% 45%, rgba(192,132,252,.09), transparent 34%),
        linear-gradient(180deg,#020812,#020617 52%,#00040b);
    }}
    .return-nav {{
      position:sticky; top:0; z-index:60; display:flex; flex-wrap:wrap; gap:8px; align-items:center;
      padding:10px 22px; border-bottom:1px solid var(--line); background:rgba(2,8,18,.94); backdrop-filter:blur(18px);
    }}
    .return-nav a,.return-nav button {{
      border:1px solid rgba(103,232,249,.22); border-radius:999px; padding:8px 11px;
      color:var(--text); background:rgba(0,12,24,.72); text-decoration:none; font-size:12px; font-weight:900; cursor:pointer;
    }}
    .return-nav a:hover,.return-nav button:hover {{ border-color:rgba(134,239,172,.58); color:var(--green); }}
    header {{ max-width:1880px; margin:0 auto; padding:28px 24px 14px; }}
    .hero {{
      border:1px solid var(--line); border-radius:30px; padding:24px;
      background:
        radial-gradient(circle at 85% 10%, rgba(103,232,249,.16), transparent 32%),
        linear-gradient(135deg, rgba(0,19,34,.86), rgba(0,7,16,.76));
      box-shadow:0 30px 120px rgba(0,0,0,.38);
    }}
    .eyebrow {{ color:var(--cyan); font-size:11px; font-weight:950; letter-spacing:.14em; text-transform:uppercase; }}
    h1 {{ margin:8px 0 0; font-size:42px; letter-spacing:-.055em; line-height:1; }}
    .hero p {{ max-width:1180px; color:var(--muted); line-height:1.55; font-size:15px; }}
    .kpis {{ display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; margin-top:18px; }}
    .kpi {{ border:1px solid rgba(103,232,249,.16); border-radius:18px; padding:13px; background:rgba(0,9,20,.6); }}
    .kpi span {{ display:block; color:var(--muted); font-size:10px; text-transform:uppercase; font-weight:900; letter-spacing:.11em; }}
    .kpi strong {{ display:block; margin-top:5px; color:var(--green); font-size:28px; }}
    main {{ max-width:1880px; margin:0 auto; padding:10px 24px 46px; }}
    .theme-map {{
      display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; margin:10px 0 18px;
    }}
    .theme-tile {{
      text-align:left; border:1px solid rgba(103,232,249,.15); border-radius:22px; padding:15px;
      background:rgba(0,9,20,.72); color:inherit; cursor:pointer;
    }}
    .theme-tile:hover {{
      border-color:rgba(134,239,172,.52); transform:translateY(-1px);
      box-shadow:0 18px 60px rgba(0,0,0,.26),0 0 30px rgba(16,185,129,.11);
    }}
    .theme-icon {{ display:inline-flex; align-items:center; justify-content:center; width:34px; height:34px; border-radius:12px;
      background:linear-gradient(135deg,rgba(103,232,249,.20),rgba(134,239,172,.12)); color:var(--cyan); font-weight:950; }}
    .theme-tile strong {{ display:block; margin-top:9px; font-size:15px; }}
    .theme-tile em {{ display:block; margin-top:5px; color:var(--muted); font-size:11px; font-style:normal; }}
    .theme-section {{
      margin-top:14px; border:1px solid var(--line); border-radius:28px; padding:16px;
      background:rgba(3,14,28,.70);
    }}
    .section-head {{ display:flex; justify-content:space-between; gap:12px; align-items:flex-start; border-bottom:1px solid rgba(103,232,249,.10); padding-bottom:12px; }}
    .section-head span {{ color:var(--cyan); font-size:24px; font-weight:950; }}
    .section-head h2 {{ margin:4px 0 4px; font-size:24px; letter-spacing:-.03em; }}
    .section-head p {{ margin:0; color:var(--muted); }}
    .section-kpi {{ text-align:center; border:1px solid rgba(134,239,172,.18); border-radius:18px; padding:10px 16px; background:rgba(8,47,38,.18); }}
    .section-kpi b {{ display:block; color:var(--green); font-size:26px; }}
    .section-kpi small {{ color:var(--muted); font-weight:900; letter-spacing:.1em; }}
    .page-grid {{ display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; margin-top:12px; }}
    .page-link {{
      min-height:126px; display:flex; flex-direction:column; gap:7px; text-decoration:none; color:inherit;
      border:1px solid rgba(103,232,249,.13); border-radius:18px; padding:12px;
      background:radial-gradient(circle at 85% 0%,rgba(103,232,249,.10),transparent 30%), rgba(0,8,18,.70);
    }}
    .page-link:hover {{ border-color:rgba(134,239,172,.50); box-shadow:0 0 30px rgba(16,185,129,.10); }}
    .page-link span {{ color:var(--cyan); font-size:9px; font-weight:950; letter-spacing:.11em; text-transform:uppercase; }}
    .page-link strong {{ line-height:1.16; font-size:13px; }}
    .page-link em {{ color:var(--muted); font-size:10px; font-style:normal; word-break:break-word; }}
    .page-link small {{ margin-top:auto; color:var(--amber); font-size:10px; font-weight:850; }}
    .empty {{ color:var(--muted); padding:12px; }}
    @media(max-width:1500px){{ .theme-map,.page-grid{{grid-template-columns:repeat(3,minmax(0,1fr));}} }}
    @media(max-width:1000px){{ .theme-map,.page-grid,.kpis{{grid-template-columns:repeat(2,minmax(0,1fr));}} h1{{font-size:34px;}} }}
    @media(max-width:640px){{ .theme-map,.page-grid,.kpis{{grid-template-columns:1fr;}} }}
  </style>
</head>
<body data-trfmc-thematic-command-center="mounted">
  <nav class="return-nav">
    <button type="button" onclick="history.back()">← Indietro</button>
    <a href="/#portal-os-preview">Portal OS principale</a>
    <a href="/trfmc_working_pages_control_room_v1.html">Working Pages</a>
    <a href="/trfmc_page_review_cockpit_v1.html">Page Review Cockpit</a>
    <a href="/trfmc_rf_tm_war_room_v4.html">War Room</a>
  </nav>
  <header>
    <section class="hero">
      <div class="eyebrow">TRFMC / RF TELCO LAB · thematic orchestration cockpit</div>
      <h1>Thematic Command Center</h1>
      <p>
        Dashboard madre per sottoinsiemi: organizza le pagine ACTIVE per area tecnica, collega le control room,
        e prepara la revisione pagina-per-pagina prima dell'integrazione nel Portal OS.
      </p>
      <div class="kpis">
        <div class="kpi"><span>Active pages</span><strong>{len(pages)}</strong></div>
        <div class="kpi"><span>Thematic areas</span><strong>{len(THEMES)}</strong></div>
        <div class="kpi"><span>Total canvas</span><strong>{total_canvas}</strong></div>
        <div class="kpi"><span>Total scripts</span><strong>{total_scripts}</strong></div>
      </div>
    </section>
  </header>
  <main>
    <section class="theme-map">
      {''.join(theme_tiles)}
    </section>
    {''.join(theme_sections)}
  </main>
  <script>
    document.querySelectorAll('[data-theme-target]').forEach(button => {{
      button.addEventListener('click', () => {{
        const target = document.getElementById(button.dataset.themeTarget);
        if (target) target.scrollIntoView({{ behavior: 'smooth', block: 'start' }});
      }});
    }});
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
code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" http://127.0.0.1:5173/trfmc_thematic_command_center_v1.html 2>/dev/null || echo 000)"
bytes="$(wc -c < "$tmp" | tr -d ' ')"
hint="TEXT"
grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
result="OK"
[ "$code" != "200" ] && result="NON_200"
[ "$bytes" = "0" ] && result="ZERO_BYTES"
printf "%s\t%s\t%s\t%s\t%s\n" "http://127.0.0.1:5173/trfmc_thematic_command_center_v1.html" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
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
    --dump-dom http://127.0.0.1:5173/trfmc_thematic_command_center_v1.html > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=7000 \
    --screenshot="$SCREEN" http://127.0.0.1:5173/trfmc_thematic_command_center_v1.html >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

MOUNT_COUNT="$(grep -o 'data-trfmc-thematic-command-center="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
THEME_COUNT="$(grep -o 'class="theme-section"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
PAGE_LINK_COUNT="$(grep -o 'class="page-link"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$MOUNT_COUNT" = "0" ] && RESULT="FAIL_MARKER"
[ "$THEME_COUNT" = "0" ] && RESULT="FAIL_NO_THEMES"
[ "$PAGE_LINK_COUNT" = "0" ] && RESULT="FAIL_NO_PAGE_LINKS"
[ "$SCREENSHOT_RESULT" != "PASS" ] && RESULT="FAIL_SCREENSHOT"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P7A_THEMATIC_COMMAND_CENTER_V1",
  "mutation": "public_static_thematic_dashboard_only",
  "react_mutation": false,
  "backend_mutation": false,
  "audit_source": "$AUDIT_SRC",
  "dashboard": "$DASH",
  "url": "http://127.0.0.1:5173/trfmc_thematic_command_center_v1.html",
  "data_json": "$DATA_JSON",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "mount_count": $MOUNT_COUNT,
  "theme_count": $THEME_COUNT,
  "page_link_count": $PAGE_LINK_COUNT,
  "http_failures": $HTTP_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p7a_thematic_command_center_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P7A_THEMATIC_COMMAND_CENTER_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
