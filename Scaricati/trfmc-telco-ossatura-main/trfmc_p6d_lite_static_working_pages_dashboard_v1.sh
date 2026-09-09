#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P6D_LITE_STATIC_WORKING_PAGES_DASHBOARD_V1_$TS"

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

DASH="frontend/public/trfmc_working_pages_control_room_v1.html"
SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_working_pages_control_room.txt"
SCREEN="$OUT/working_pages_control_room_1920x1080.png"
BACKUP="$OUT/backup"
mkdir -p "$BACKUP"

echo "============================================================"
echo "TRFMC_P6D_LITE_STATIC_WORKING_PAGES_DASHBOARD_V1"
echo "Dashboard statica reale: tutte le pagine ACTIVE, senza toccare React"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$AUDIT_SRC" ] || [ ! -f "$AUDIT_SRC" ]; then
  echo "ERRORE: nessun audit sorgente trovato per public pages."
  exit 1
fi

echo "AUDIT_SRC=$AUDIT_SRC"

if [ -f "$DASH" ]; then
  cp -a "$DASH" "$BACKUP/$(basename "$DASH").before_$TS"
fi

echo
echo "=== 1) GENERO DASHBOARD HTML STATICA ==="

python3 - "$AUDIT_SRC" "$DASH" "$OUT/working_pages_active.json" "$OUT/working_pages_category_counts.tsv" <<'PY'
import csv
import html
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

audit = Path(sys.argv[1])
dash = Path(sys.argv[2])
json_out = Path(sys.argv[3])
cat_out = Path(sys.argv[4])

rows = []
with audit.open("r", encoding="utf-8", errors="replace", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for r in reader:
        status = (r.get("status") or r.get("result") or "").strip()
        if not status.startswith("ACTIVE"):
            continue

        title = (r.get("title") or r.get("file") or r.get("url") or "Untitled").strip()
        url = (r.get("url") or "").strip()
        category = (r.get("category") or "reference").strip()
        file_path = (r.get("file") or "").strip()
        canvas = int((r.get("canvas") or r.get("canvas_source") or r.get("dom_canvas_count") or "0") or 0)
        scripts = int((r.get("scripts") or r.get("script_tags") or "0") or 0)
        bytes_len = int((r.get("bytes") or "0") or 0)

        if not url.startswith("/"):
            continue

        rows.append({
            "title": title,
            "url": url,
            "category": category,
            "file": file_path,
            "canvas": canvas,
            "scripts": scripts,
            "bytes": bytes_len,
        })

rows.sort(key=lambda x: (x["category"], x["title"].lower()))

cat_counts = Counter(r["category"] for r in rows)
json_out.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")

with cat_out.open("w", encoding="utf-8") as f:
    f.write("category\tcount\n")
    for k, v in sorted(cat_counts.items()):
        f.write(f"{k}\t{v}\n")

cards = []
for r in rows:
    cards.append(f"""
      <a class="card" href="{html.escape(r['url'])}" target="_blank" rel="noreferrer"
         data-category="{html.escape(r['category'])}"
         data-title="{html.escape(r['title'].lower())}"
         data-url="{html.escape(r['url'].lower())}">
        <span class="cat">{html.escape(r['category'])}</span>
        <strong>{html.escape(r['title'])}</strong>
        <em>{html.escape(r['url'])}</em>
        <small>canvas {r['canvas']} · script {r['scripts']} · {r['bytes']} B</small>
      </a>
    """)

category_buttons = ['<button class="active" data-filter="all">ALL <b>' + str(len(rows)) + '</b></button>']
for cat, count in sorted(cat_counts.items()):
    category_buttons.append(
        f'<button data-filter="{html.escape(cat)}">{html.escape(cat)} <b>{count}</b></button>'
    )

doc = f"""<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>TRFMC Working Pages Control Room</title>
  <style>
    :root {{
      --bg: #020812;
      --panel: rgba(4, 18, 33, .82);
      --line: rgba(103, 232, 249, .18);
      --text: #e8f7ff;
      --muted: #9fb8ca;
      --cyan: #67e8f9;
      --green: #86efac;
      --amber: #fbbf24;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      color: var(--text);
      background:
        radial-gradient(circle at 18% 12%, rgba(14, 165, 233, .18), transparent 28%),
        radial-gradient(circle at 78% 0%, rgba(16, 185, 129, .14), transparent 30%),
        linear-gradient(180deg, #020812, #030712 46%, #020617);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    header {{
      position: sticky;
      top: 0;
      z-index: 5;
      border-bottom: 1px solid var(--line);
      background: rgba(2, 8, 18, .88);
      backdrop-filter: blur(18px);
      padding: 18px 22px;
    }}
    .topline {{
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      max-width: 1780px;
      margin: 0 auto;
    }}
    h1 {{
      margin: 0;
      font-size: 24px;
      letter-spacing: -.03em;
    }}
    .subtitle {{
      margin-top: 6px;
      color: var(--muted);
      font-size: 13px;
      max-width: 980px;
      line-height: 1.45;
    }}
    .kpis {{
      display: grid;
      grid-template-columns: repeat(3, minmax(120px, 1fr));
      gap: 8px;
      min-width: 420px;
    }}
    .kpi {{
      border: 1px solid var(--line);
      border-radius: 16px;
      background: rgba(0, 12, 24, .62);
      padding: 10px;
    }}
    .kpi span {{
      display: block;
      color: var(--muted);
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: .11em;
      font-weight: 900;
    }}
    .kpi strong {{
      display: block;
      margin-top: 4px;
      font-size: 22px;
      color: var(--green);
    }}
    main {{
      max-width: 1780px;
      margin: 0 auto;
      padding: 18px 22px 40px;
    }}
    .controls {{
      border: 1px solid var(--line);
      background: var(--panel);
      border-radius: 22px;
      padding: 14px;
      box-shadow: 0 24px 90px rgba(0, 0, 0, .32);
    }}
    input {{
      width: 100%;
      border: 1px solid rgba(103, 232, 249, .22);
      border-radius: 16px;
      padding: 13px 14px;
      background: rgba(0, 7, 16, .7);
      color: var(--text);
      outline: none;
      font-size: 14px;
    }}
    input:focus {{
      border-color: rgba(134, 239, 172, .58);
      box-shadow: 0 0 0 3px rgba(134, 239, 172, .09);
    }}
    .filters {{
      margin-top: 12px;
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }}
    button {{
      border: 1px solid rgba(103, 232, 249, .18);
      color: var(--muted);
      background: rgba(0, 12, 24, .54);
      border-radius: 999px;
      padding: 8px 10px;
      font-weight: 800;
      cursor: pointer;
    }}
    button.active {{
      color: #02130d;
      border-color: rgba(134, 239, 172, .82);
      background: linear-gradient(90deg, var(--green), var(--cyan));
    }}
    button b {{ margin-left: 4px; }}
    .grid {{
      margin-top: 16px;
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 10px;
    }}
    .card {{
      min-height: 132px;
      text-decoration: none;
      border: 1px solid rgba(103, 232, 249, .14);
      border-radius: 18px;
      background:
        radial-gradient(circle at 85% 0%, rgba(103, 232, 249, .12), transparent 32%),
        rgba(0, 9, 20, .72);
      padding: 13px;
      color: inherit;
      display: flex;
      flex-direction: column;
      gap: 7px;
    }}
    .card:hover {{
      border-color: rgba(134, 239, 172, .55);
      transform: translateY(-1px);
      box-shadow: 0 18px 55px rgba(0, 0, 0, .24), 0 0 26px rgba(16, 185, 129, .12);
    }}
    .cat {{
      width: fit-content;
      border: 1px solid rgba(103, 232, 249, .18);
      border-radius: 999px;
      padding: 4px 7px;
      color: var(--cyan);
      font-size: 9px;
      text-transform: uppercase;
      font-weight: 950;
      letter-spacing: .1em;
    }}
    .card strong {{
      line-height: 1.15;
      font-size: 14px;
    }}
    .card em {{
      color: var(--muted);
      font-style: normal;
      font-size: 11px;
      word-break: break-word;
    }}
    .card small {{
      margin-top: auto;
      color: var(--amber);
      font-size: 10px;
      font-weight: 800;
    }}
    .hidden {{ display: none; }}
    @media (max-width: 1420px) {{
      .grid {{ grid-template-columns: repeat(3, minmax(0, 1fr)); }}
      .topline {{ flex-direction: column; }}
      .kpis {{ min-width: 0; width: 100%; }}
    }}
    @media (max-width: 920px) {{
      .grid {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}
    }}
    @media (max-width: 620px) {{
      .grid {{ grid-template-columns: 1fr; }}
    }}
  </style>
</head>
<body data-trfmc-working-pages-control-room="mounted">
  <header>
    <div class="topline">
      <div>
        <h1>TRFMC Working Pages Control Room</h1>
        <div class="subtitle">
          Dashboard statica read-only generata dalle pagine HTML reali classificate ACTIVE. 
          Ogni card apre un file servito da <code>frontend/public</code> tramite path root Vite.
        </div>
      </div>
      <div class="kpis">
        <div class="kpi"><span>Active pages</span><strong id="kpiActive">{len(rows)}</strong></div>
        <div class="kpi"><span>Categories</span><strong>{len(cat_counts)}</strong></div>
        <div class="kpi"><span>Visible</span><strong id="kpiVisible">{len(rows)}</strong></div>
      </div>
    </div>
  </header>
  <main>
    <section class="controls">
      <input id="search" placeholder="Cerca pagina, categoria, URL..." autocomplete="off" />
      <div class="filters" id="filters">
        {''.join(category_buttons)}
      </div>
    </section>
    <section class="grid" id="grid">
      {''.join(cards)}
    </section>
  </main>
  <script>
    const cards = Array.from(document.querySelectorAll('.card'));
    const search = document.getElementById('search');
    const visible = document.getElementById('kpiVisible');
    let activeFilter = 'all';

    function applyFilter() {{
      const q = search.value.trim().toLowerCase();
      let count = 0;

      cards.forEach(card => {{
        const category = card.dataset.category;
        const haystack = `${{card.dataset.title}} ${{card.dataset.url}} ${{category}}`;
        const matchFilter = activeFilter === 'all' || category === activeFilter;
        const matchSearch = !q || haystack.includes(q);
        const show = matchFilter && matchSearch;
        card.classList.toggle('hidden', !show);
        if (show) count += 1;
      }});

      visible.textContent = String(count);
    }}

    document.getElementById('filters').addEventListener('click', (event) => {{
      const button = event.target.closest('button[data-filter]');
      if (!button) return;
      document.querySelectorAll('button[data-filter]').forEach(btn => btn.classList.remove('active'));
      button.classList.add('active');
      activeFilter = button.dataset.filter;
      applyFilter();
    }});

    search.addEventListener('input', applyFilter);
  </script>
</body>
</html>
"""
dash.write_text(doc, encoding="utf-8")
print(f"ACTIVE_ROWS={len(rows)}")
print(f"CATEGORIES={len(cat_counts)}")
PY

echo
echo "=== 2) HTTP / DOM VERIFY ==="

cat > "$HTTP" <<HDR
url	status	bytes	hint	result
HDR

check_http() {
  url="$1"
  tmp="$(mktemp)"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
  result="OK"
  [ "$code" != "200" ] && result="NON_200"
  [ "$bytes" = "0" ] && result="ZERO_BYTES"
  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_http "http://127.0.0.1:5173/trfmc_working_pages_control_room_v1.html"

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
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=6000 \
    --dump-dom \
    "http://127.0.0.1:5173/trfmc_working_pages_control_room_v1.html" > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=6000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/trfmc_working_pages_control_room_v1.html" >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

MOUNT_COUNT="$(grep -o 'data-trfmc-working-pages-control-room="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
CARD_COUNT="$(grep -o 'class="card"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$MOUNT_COUNT" = "0" ] && RESULT="FAIL_MARKER"
[ "$CARD_COUNT" = "0" ] && RESULT="FAIL_NO_CARDS"
[ "$SCREENSHOT_RESULT" != "PASS" ] && RESULT="FAIL_SCREENSHOT"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P6D_LITE_STATIC_WORKING_PAGES_DASHBOARD_V1",
  "mutation": "public_static_dashboard_only",
  "react_mutation": false,
  "backend_mutation": false,
  "audit_source": "$AUDIT_SRC",
  "dashboard": "$DASH",
  "url": "http://127.0.0.1:5173/trfmc_working_pages_control_room_v1.html",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "mount_count": $MOUNT_COUNT,
  "card_count": $CARD_COUNT,
  "http_failures": $HTTP_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p6d_lite_static_working_pages_dashboard_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P6D_LITE_STATIC_WORKING_PAGES_DASHBOARD_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
