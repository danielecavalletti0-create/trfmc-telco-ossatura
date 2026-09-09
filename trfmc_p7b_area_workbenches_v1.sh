#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P7B_AREA_WORKBENCHES_V1_$TS"

mkdir -p "$OUT"
cd "$BASE" || exit 1

DATA_JSON=""
if [ -f runtime/quality/latest_p7a_thematic_command_center_v1/thematic_command_center_data.json ]; then
  DATA_JSON="runtime/quality/latest_p7a_thematic_command_center_v1/thematic_command_center_data.json"
else
  DATA_JSON="$(find runtime/quality -path '*TRFMC_P7A_THEMATIC_COMMAND_CENTER_V1_*/*thematic_command_center_data.json' | sort | tail -n 1)"
fi

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom.tsv"

echo "============================================================"
echo "TRFMC_P7B_AREA_WORKBENCHES_V1"
echo "Dashboard per sottoinsieme tecnico, no React mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$DATA_JSON" ] || [ ! -f "$DATA_JSON" ]; then
  echo "ERRORE: thematic_command_center_data.json non trovato."
  exit 1
fi

python3 - "$DATA_JSON" "$BASE/frontend/public" "$OUT/area_pages.tsv" <<'PY'
import json, html, sys
from pathlib import Path
from collections import defaultdict

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
public = Path(sys.argv[2])
area_tsv = Path(sys.argv[3])

themes = data["themes"]
pages = data["pages"]

by_theme = defaultdict(list)
for p in pages:
    by_theme[p["theme"]].append(p)

slug_to_file = {
    "war-room": "trfmc_area_war_room_v1.html",
    "signal-dsp": "trfmc_area_signal_dsp_v1.html",
    "antenna-system": "trfmc_area_antenna_system_v1.html",
    "core-ran": "trfmc_area_core_ran_v1.html",
    "rf-physics": "trfmc_area_rf_physics_v1.html",
    "fiber-datacenter": "trfmc_area_fiber_datacenter_v1.html",
    "knowledge-base": "trfmc_area_knowledge_base_v1.html",
    "mission-control": "trfmc_area_mission_control_v1.html",
    "reference-lab": "trfmc_area_reference_lab_v1.html",
}

def score_page(p):
    score = 0
    score += int(p.get("canvas", 0)) * 5
    score += int(p.get("scripts", 0)) * 2
    title = (p.get("title") or "").lower()
    url = (p.get("url") or "").lower()
    for k in ["war", "dsp", "antenna", "open5gs", "rf", "dashboard", "engine", "simulator", "control", "registry"]:
        if k in title or k in url:
            score += 3
    return score

with area_tsv.open("w", encoding="utf-8") as f:
    f.write("theme\tfile\turl\tpages\n")

    for key, theme in themes.items():
        filename = slug_to_file.get(key, f"trfmc_area_{key}_v1.html")
        out = public / filename
        group = sorted(by_theme.get(key, []), key=score_page, reverse=True)

        total_canvas = sum(int(p.get("canvas", 0)) for p in group)
        total_scripts = sum(int(p.get("scripts", 0)) for p in group)
        top = group[:12]
        backlog = group[12:]

        cards = []
        for p in top:
            cards.append(f"""
              <a class="page-card" href="{html.escape(p['url'])}" target="_blank" rel="noreferrer">
                <span>{html.escape(p.get('category','reference'))}</span>
                <strong>{html.escape(p.get('title','Untitled'))}</strong>
                <em>{html.escape(p.get('url',''))}</em>
                <small>canvas {p.get('canvas',0)} · script {p.get('scripts',0)} · score {score_page(p)}</small>
              </a>
            """)

        backlog_rows = []
        for p in backlog:
            backlog_rows.append(f"""
              <tr>
                <td>{html.escape(p.get('title','Untitled'))}</td>
                <td><a href="{html.escape(p.get('url',''))}" target="_blank" rel="noreferrer">{html.escape(p.get('url',''))}</a></td>
                <td>{p.get('canvas',0)}</td>
                <td>{p.get('scripts',0)}</td>
                <td>REVIEW</td>
              </tr>
            """)

        if not cards:
            cards.append('<div class="empty">Nessuna pagina ACTIVE assegnata a questo sottoinsieme.</div>')

        doc = f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>TRFMC Area Workbench · {html.escape(theme['label'])}</title>
<style>
:root {{
  --bg:#020812; --panel:rgba(3,14,28,.82); --line:rgba(103,232,249,.18);
  --text:#e8f7ff; --muted:#9fb8ca; --cyan:#67e8f9; --green:#86efac;
  --amber:#fbbf24; --red:#fb7185; --violet:#c084fc;
}}
* {{ box-sizing:border-box; }}
body {{
  margin:0; color:var(--text); font-family:Inter,system-ui,sans-serif;
  background:
    radial-gradient(circle at 12% 5%, rgba(14,165,233,.22), transparent 28%),
    radial-gradient(circle at 88% 0%, rgba(16,185,129,.14), transparent 30%),
    linear-gradient(180deg,#020812,#020617);
}}
nav {{
  position:sticky; top:0; z-index:50; display:flex; flex-wrap:wrap; gap:8px; padding:10px 22px;
  border-bottom:1px solid var(--line); background:rgba(2,8,18,.94); backdrop-filter:blur(18px);
}}
nav a, nav button {{
  border:1px solid rgba(103,232,249,.22); border-radius:999px; padding:8px 11px;
  color:var(--text); background:rgba(0,12,24,.72); text-decoration:none; font-weight:900; cursor:pointer;
}}
nav a:hover, nav button:hover {{ color:var(--green); border-color:rgba(134,239,172,.55); }}
main {{ max-width:1880px; margin:0 auto; padding:24px; }}
.hero {{
  border:1px solid var(--line); border-radius:30px; padding:24px;
  background:radial-gradient(circle at 90% 5%,rgba(103,232,249,.16),transparent 32%),rgba(3,14,28,.80);
  box-shadow:0 30px 110px rgba(0,0,0,.36);
}}
.eyebrow {{ color:var(--cyan); font-size:11px; text-transform:uppercase; font-weight:950; letter-spacing:.14em; }}
h1 {{ margin:8px 0 0; font-size:40px; letter-spacing:-.05em; }}
.hero p {{ color:var(--muted); max-width:1120px; line-height:1.55; }}
.kpis {{ display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; margin-top:18px; }}
.kpi {{ border:1px solid rgba(103,232,249,.14); border-radius:18px; padding:13px; background:rgba(0,9,20,.65); }}
.kpi span {{ display:block; color:var(--muted); font-size:10px; font-weight:900; text-transform:uppercase; }}
.kpi strong {{ display:block; color:var(--green); font-size:28px; margin-top:5px; }}
.layout {{ display:grid; grid-template-columns:1.2fr .8fr; gap:14px; margin-top:16px; }}
.panel {{ border:1px solid var(--line); border-radius:24px; padding:16px; background:var(--panel); }}
.panel h2 {{ margin:0 0 10px; font-size:22px; }}
.grid {{ display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:10px; }}
.page-card {{
  min-height:132px; display:flex; flex-direction:column; gap:7px; text-decoration:none; color:inherit;
  border:1px solid rgba(103,232,249,.14); border-radius:18px; padding:12px; background:rgba(0,9,20,.72);
}}
.page-card:hover {{ border-color:rgba(134,239,172,.55); box-shadow:0 0 34px rgba(16,185,129,.12); }}
.page-card span {{ color:var(--cyan); font-size:9px; text-transform:uppercase; font-weight:950; }}
.page-card strong {{ font-size:13px; line-height:1.16; }}
.page-card em {{ color:var(--muted); font-size:10px; word-break:break-word; font-style:normal; }}
.page-card small {{ margin-top:auto; color:var(--amber); font-size:10px; font-weight:850; }}
.workflow {{ display:grid; gap:8px; }}
.step {{ border:1px solid rgba(103,232,249,.12); border-radius:16px; padding:12px; background:rgba(0,8,18,.64); }}
.step b {{ color:var(--green); }}
table {{ width:100%; border-collapse:collapse; margin-top:8px; font-size:12px; }}
th, td {{ border-bottom:1px solid rgba(103,232,249,.10); padding:8px; text-align:left; vertical-align:top; }}
th {{ color:var(--cyan); font-size:10px; text-transform:uppercase; letter-spacing:.1em; }}
td a {{ color:var(--green); }}
.empty {{ color:var(--muted); padding:12px; }}
@media(max-width:1500px){{ .layout{{grid-template-columns:1fr}} .grid{{grid-template-columns:repeat(2,1fr)}} }}
@media(max-width:760px){{ .grid,.kpis{{grid-template-columns:1fr}} h1{{font-size:32px}} }}
</style>
</head>
<body data-trfmc-area-workbench="{html.escape(key)}">
<nav>
  <button onclick="history.back()">← Indietro</button>
  <a href="/#portal-os-preview">Portal OS</a>
  <a href="/trfmc_thematic_command_center_v1.html">Thematic Center</a>
  <a href="/trfmc_page_review_cockpit_v1.html">Review Cockpit</a>
  <a href="/trfmc_working_pages_control_room_v1.html">Working Pages</a>
</nav>
<main>
  <section class="hero">
    <div class="eyebrow">TRFMC area workbench · {html.escape(key)}</div>
    <h1>{html.escape(theme['label'])}</h1>
    <p>{html.escape(theme['goal'])}</p>
    <div class="kpis">
      <div class="kpi"><span>Active pages</span><strong>{len(group)}</strong></div>
      <div class="kpi"><span>Top queue</span><strong>{len(top)}</strong></div>
      <div class="kpi"><span>Total canvas</span><strong>{total_canvas}</strong></div>
      <div class="kpi"><span>Total scripts</span><strong>{total_scripts}</strong></div>
    </div>
  </section>

  <section class="layout">
    <div class="panel">
      <h2>Top candidates da aprire e valutare</h2>
      <div class="grid">{''.join(cards)}</div>
    </div>
    <div class="panel">
      <h2>Flusso corretto</h2>
      <div class="workflow">
        <div class="step"><b>1.</b> Apri ogni pagina candidata.</div>
        <div class="step"><b>2.</b> Valuta: OK / migliorare / integrare / React ready / broken.</div>
        <div class="step"><b>3.</b> Correggi link, ritorno home, contenuti incompleti.</div>
        <div class="step"><b>4.</b> Solo dopo promuovi nel Portal OS.</div>
      </div>
    </div>
  </section>

  <section class="panel" style="margin-top:14px">
    <h2>Backlog del sottoinsieme</h2>
    <table>
      <thead>
        <tr><th>Titolo</th><th>URL</th><th>Canvas</th><th>Script</th><th>Stato</th></tr>
      </thead>
      <tbody>{''.join(backlog_rows) or '<tr><td colspan="5">Nessun backlog.</td></tr>'}</tbody>
    </table>
  </section>
</main>
</body>
</html>
"""
        out.write_text(doc, encoding="utf-8")
        f.write(f"{key}\t{filename}\t/{filename}\t{len(group)}\n")
PY

cat > "$HTTP" <<HDR
theme	url	status	bytes	hint	result
HDR

while IFS=$'\t' read -r theme file url pages; do
  [ "$theme" = "theme" ] && continue
  tmp="$(mktemp)"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "http://127.0.0.1:5173${url}" 2>/dev/null || echo 000)"
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
  result="OK"
  [ "$code" != "200" ] && result="NON_200"
  [ "$bytes" = "0" ] && result="ZERO_BYTES"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$theme" "$url" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
  rm -f "$tmp"
done < "$OUT/area_pages.tsv"

HTTP_FAILS="$(awk -F'\t' 'NR>1 && $6!="OK"{c++} END{print c+0}' "$HTTP")"

DOM_RESULT="SKIPPED"
MOUNT_COUNT=0
if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

if [ -n "$CHROME_BIN" ]; then
  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=7000 \
    --dump-dom http://127.0.0.1:5173/trfmc_area_war_room_v1.html > "$OUT/dom_war_room_area.txt" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
  MOUNT_COUNT="$(grep -o 'data-trfmc-area-workbench="war-room"' "$OUT/dom_war_room_area.txt" 2>/dev/null | wc -l | tr -d ' ')"
fi

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$MOUNT_COUNT" = "0" ] && RESULT="FAIL_MARKER"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P7B_AREA_WORKBENCHES_V1",
  "mutation": "public_static_area_workbenches",
  "react_mutation": false,
  "backend_mutation": false,
  "data_source": "$DATA_JSON",
  "area_pages": "$OUT/area_pages.tsv",
  "http_gate": "$HTTP",
  "http_failures": $HTTP_FAILS,
  "dom_result": "$DOM_RESULT",
  "mount_count": $MOUNT_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p7b_area_workbenches_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P7B_AREA_WORKBENCHES_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
