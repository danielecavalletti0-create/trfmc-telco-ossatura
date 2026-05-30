#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P6E_PAGE_REVIEW_COCKPIT_V1_$TS"

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

DASH="frontend/public/trfmc_page_review_cockpit_v1.html"
DATA_JSON="$OUT/page_review_seed.json"
CATEGORY_TSV="$OUT/page_review_categories.tsv"
SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_page_review_cockpit.txt"
SCREEN="$OUT/page_review_cockpit_1920x1080.png"

echo "============================================================"
echo "TRFMC_P6E_PAGE_REVIEW_COCKPIT_V1"
echo "Dashboard per sottoinsiemi + revisione pagina per pagina"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$AUDIT_SRC" ] || [ ! -f "$AUDIT_SRC" ]; then
  echo "ERRORE: audit sorgente non trovato."
  exit 1
fi

python3 - "$AUDIT_SRC" "$DASH" "$DATA_JSON" "$CATEGORY_TSV" <<'PY'
import csv, html, json, sys
from pathlib import Path
from collections import Counter

audit = Path(sys.argv[1])
dash = Path(sys.argv[2])
data_json = Path(sys.argv[3])
category_tsv = Path(sys.argv[4])

rows = []
with audit.open("r", encoding="utf-8", errors="replace", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for r in reader:
        status = (r.get("status") or r.get("result") or "REVIEW").strip()
        title = (r.get("title") or r.get("file") or r.get("url") or "Untitled").strip()
        url = (r.get("url") or "").strip()
        category = (r.get("category") or "reference").strip()
        file_path = (r.get("file") or "").strip()

        if not url.startswith("/"):
            continue

        def num(*keys):
            for k in keys:
                v = r.get(k)
                if v not in (None, ""):
                    try:
                        return int(v)
                    except Exception:
                        return 0
            return 0

        rows.append({
            "status": status if status else "REVIEW",
            "qa": "UNREVIEWED",
            "category": category,
            "title": title,
            "url": url,
            "file": file_path,
            "bytes": num("bytes"),
            "canvas": num("canvas", "canvas_source", "dom_canvas_count"),
            "scripts": num("scripts", "script_tags"),
            "danger": num("danger", "dangerous_dom"),
            "iframe": num("iframe"),
            "notes": "",
        })

rows.sort(key=lambda x: (x["category"], x["status"], x["title"].lower()))
cats = Counter(r["category"] for r in rows)
active = sum(1 for r in rows if r["status"].startswith("ACTIVE"))
review = len(rows) - active

data_json.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")

with category_tsv.open("w", encoding="utf-8") as f:
    f.write("category\tpages\n")
    for c, n in sorted(cats.items()):
        f.write(f"{c}\t{n}\n")

cards = []
for idx, r in enumerate(rows):
    risk = "risk-ok"
    if r["status"] != "ACTIVE":
        risk = "risk-review"
    if r["danger"] or r["iframe"]:
        risk = "risk-bad"

    cards.append(f"""
      <article class="page-card {risk}"
        data-index="{idx}"
        data-category="{html.escape(r['category'])}"
        data-status="{html.escape(r['status'])}"
        data-title="{html.escape(r['title'].lower())}"
        data-url="{html.escape(r['url'].lower())}">
        <div class="card-head">
          <span>{html.escape(r['category'])}</span>
          <b>{html.escape(r['status'])}</b>
        </div>
        <h3>{html.escape(r['title'])}</h3>
        <p>{html.escape(r['url'])}</p>
        <div class="metrics">
          <small>{r['bytes']} B</small>
          <small>canvas {r['canvas']}</small>
          <small>script {r['scripts']}</small>
          <small>danger {r['danger']}</small>
        </div>
        <div class="actions">
          <a href="{html.escape(r['url'])}" target="_blank" rel="noreferrer">Apri</a>
          <button data-qa="QA_OK">OK</button>
          <button data-qa="IMPROVE">Migliorare</button>
          <button data-qa="INTEGRATE">Integrare</button>
          <button data-qa="REACT_READY">React</button>
          <button data-qa="BROKEN">Broken</button>
        </div>
      </article>
    """)

buttons = [
    f'<button class="active" data-filter-category="all">ALL <b>{len(rows)}</b></button>',
]
for c, n in sorted(cats.items()):
    buttons.append(f'<button data-filter-category="{html.escape(c)}">{html.escape(c)} <b>{n}</b></button>')

doc = f"""<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>TRFMC Page Review Cockpit</title>
  <style>
    :root {{
      --bg:#020812; --panel:rgba(3,14,28,.86); --line:rgba(103,232,249,.18);
      --text:#e8f7ff; --muted:#9fb8ca; --cyan:#67e8f9; --green:#86efac;
      --amber:#fbbf24; --red:#fb7185;
    }}
    * {{ box-sizing:border-box; }}
    body {{
      margin:0; color:var(--text); font-family:Inter,system-ui,sans-serif;
      background:
        radial-gradient(circle at 18% 8%, rgba(14,165,233,.18), transparent 30%),
        radial-gradient(circle at 82% 0%, rgba(16,185,129,.14), transparent 28%),
        linear-gradient(180deg,#020812,#020617);
    }}
    header {{
      position:sticky; top:0; z-index:10; padding:18px 24px;
      border-bottom:1px solid var(--line); background:rgba(2,8,18,.9); backdrop-filter:blur(18px);
    }}
    .top {{ max-width:1880px; margin:0 auto; display:flex; justify-content:space-between; gap:18px; }}
    h1 {{ margin:0; font-size:24px; letter-spacing:-.03em; }}
    .sub {{ color:var(--muted); margin-top:6px; font-size:13px; max-width:1040px; line-height:1.45; }}
    .kpis {{ display:grid; grid-template-columns:repeat(4,120px); gap:8px; }}
    .kpi {{ border:1px solid var(--line); border-radius:16px; padding:10px; background:rgba(0,12,24,.58); }}
    .kpi span {{ display:block; font-size:9px; color:var(--muted); text-transform:uppercase; font-weight:900; letter-spacing:.1em; }}
    .kpi strong {{ display:block; margin-top:4px; font-size:22px; color:var(--green); }}
    main {{ max-width:1880px; margin:0 auto; padding:16px 24px 42px; }}
    .controls {{ border:1px solid var(--line); border-radius:22px; padding:14px; background:var(--panel); }}
    input {{
      width:100%; padding:13px 14px; border-radius:16px; border:1px solid rgba(103,232,249,.24);
      background:rgba(0,7,16,.72); color:var(--text); outline:none;
    }}
    .filters {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:12px; }}
    button {{
      border:1px solid rgba(103,232,249,.18); background:rgba(0,12,24,.62); color:var(--muted);
      border-radius:999px; padding:8px 10px; font-weight:850; cursor:pointer;
    }}
    button.active {{ background:linear-gradient(90deg,var(--green),var(--cyan)); color:#02130d; }}
    .grid {{ margin-top:16px; display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; }}
    .page-card {{
      border:1px solid rgba(103,232,249,.14); border-radius:18px; padding:13px;
      background:rgba(0,9,20,.76); min-height:190px; display:flex; flex-direction:column; gap:8px;
    }}
    .risk-ok {{ box-shadow:inset 0 0 0 1px rgba(134,239,172,.08); }}
    .risk-review {{ box-shadow:inset 0 0 0 1px rgba(251,191,36,.12); }}
    .risk-bad {{ box-shadow:inset 0 0 0 1px rgba(251,113,133,.22); }}
    .card-head {{ display:flex; justify-content:space-between; align-items:center; gap:8px; }}
    .card-head span {{ color:var(--cyan); font-size:9px; text-transform:uppercase; font-weight:950; letter-spacing:.1em; }}
    .card-head b {{ color:var(--amber); font-size:10px; }}
    h3 {{ margin:0; font-size:14px; line-height:1.18; }}
    p {{ margin:0; color:var(--muted); font-size:11px; word-break:break-word; }}
    .metrics {{ display:flex; flex-wrap:wrap; gap:5px; margin-top:auto; }}
    small {{ border:1px solid rgba(103,232,249,.12); border-radius:999px; padding:4px 6px; color:var(--muted); }}
    .actions {{ display:flex; flex-wrap:wrap; gap:6px; margin-top:4px; }}
    .actions a, .actions button {{
      text-decoration:none; border-radius:10px; padding:6px 8px; font-size:10px; font-weight:900;
    }}
    .actions a {{ background:rgba(103,232,249,.14); color:var(--cyan); border:1px solid rgba(103,232,249,.22); }}
    .actions button[data-qa="QA_OK"] {{ color:var(--green); }}
    .actions button[data-qa="BROKEN"] {{ color:var(--red); }}
    .hidden {{ display:none; }}
    @media(max-width:1500px){{ .grid{{grid-template-columns:repeat(3,1fr)}} .top{{flex-direction:column}} .kpis{{grid-template-columns:repeat(4,1fr)}} }}
    @media(max-width:980px){{ .grid{{grid-template-columns:repeat(2,1fr)}} }}
    @media(max-width:640px){{ .grid{{grid-template-columns:1fr}} }}
  </style>
</head>
<body data-trfmc-page-review-cockpit="mounted">
<header>
  <div class="top">
    <div>
      <h1>TRFMC Page Review Cockpit</h1>
      <div class="sub">
        Control room per sottoinsiemi: apri ogni pagina, classificala e decidi se è OK, da migliorare, da integrare o pronta per conversione React.
        Le scelte restano nel browser tramite localStorage e puoi esportarle in JSON.
      </div>
    </div>
    <div class="kpis">
      <div class="kpi"><span>Total</span><strong>{len(rows)}</strong></div>
      <div class="kpi"><span>Active</span><strong>{active}</strong></div>
      <div class="kpi"><span>Review</span><strong>{review}</strong></div>
      <div class="kpi"><span>Visible</span><strong id="visible">{len(rows)}</strong></div>
    </div>
  </div>
</header>
<main>
  <section class="controls">
    <input id="search" placeholder="Cerca titolo, categoria, URL..." />
    <div class="filters">{''.join(buttons)}</div>
    <div class="filters">
      <button data-filter-qa="all" class="active">QA ALL</button>
      <button data-filter-qa="QA_OK">OK</button>
      <button data-filter-qa="IMPROVE">Migliorare</button>
      <button data-filter-qa="INTEGRATE">Integrare</button>
      <button data-filter-qa="REACT_READY">React Ready</button>
      <button data-filter-qa="BROKEN">Broken</button>
      <button id="exportBtn">Export JSON</button>
      <button id="clearBtn">Clear QA</button>
    </div>
  </section>
  <section class="grid" id="grid">{''.join(cards)}</section>
</main>
<script>
const STORAGE_KEY = 'trfmc-page-review-cockpit-v1';
const cards = Array.from(document.querySelectorAll('.page-card'));
const search = document.getElementById('search');
const visible = document.getElementById('visible');
let categoryFilter = 'all';
let qaFilter = 'all';
let qa = {{}};

try {{ qa = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{{}}'); }} catch(e) {{ qa = {{}}; }}

function applyQaVisuals() {{
  cards.forEach(card => {{
    const state = qa[card.dataset.index];
    if (state) card.querySelector('.card-head b').textContent = state;
  }});
}}

function applyFilter() {{
  const q = search.value.trim().toLowerCase();
  let count = 0;
  cards.forEach(card => {{
    const category = card.dataset.category;
    const state = qa[card.dataset.index] || 'UNREVIEWED';
    const hay = `${{card.dataset.title}} ${{card.dataset.url}} ${{category}}`;
    const okCat = categoryFilter === 'all' || category === categoryFilter;
    const okQa = qaFilter === 'all' || state === qaFilter;
    const okSearch = !q || hay.includes(q);
    const show = okCat && okQa && okSearch;
    card.classList.toggle('hidden', !show);
    if (show) count += 1;
  }});
  visible.textContent = String(count);
}}

document.body.addEventListener('click', ev => {{
  const catBtn = ev.target.closest('button[data-filter-category]');
  if (catBtn) {{
    document.querySelectorAll('button[data-filter-category]').forEach(b => b.classList.remove('active'));
    catBtn.classList.add('active');
    categoryFilter = catBtn.dataset.filterCategory;
    applyFilter();
    return;
  }}

  const qaBtn = ev.target.closest('button[data-filter-qa]');
  if (qaBtn) {{
    document.querySelectorAll('button[data-filter-qa]').forEach(b => b.classList.remove('active'));
    qaBtn.classList.add('active');
    qaFilter = qaBtn.dataset.filterQa;
    applyFilter();
    return;
  }}

  const action = ev.target.closest('button[data-qa]');
  if (action) {{
    const card = action.closest('.page-card');
    qa[card.dataset.index] = action.dataset.qa;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(qa, null, 2));
    applyQaVisuals();
    applyFilter();
  }}
}});

document.getElementById('exportBtn').addEventListener('click', () => {{
  const blob = new Blob([JSON.stringify(qa, null, 2)], {{ type: 'application/json' }});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'trfmc_page_review_decisions.json';
  a.click();
  URL.revokeObjectURL(a.href);
}});

document.getElementById('clearBtn').addEventListener('click', () => {{
  if (!confirm('Cancellare tutte le decisioni QA locali?')) return;
  qa = {{}};
  localStorage.removeItem(STORAGE_KEY);
  applyQaVisuals();
  applyFilter();
}});

search.addEventListener('input', applyFilter);
applyQaVisuals();
applyFilter();
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
code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" http://127.0.0.1:5173/trfmc_page_review_cockpit_v1.html 2>/dev/null || echo 000)"
bytes="$(wc -c < "$tmp" | tr -d ' ')"
hint="TEXT"
grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
result="OK"
[ "$code" != "200" ] && result="NON_200"
[ "$bytes" = "0" ] && result="ZERO_BYTES"
printf "%s\t%s\t%s\t%s\t%s\n" "http://127.0.0.1:5173/trfmc_page_review_cockpit_v1.html" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
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
    --dump-dom http://127.0.0.1:5173/trfmc_page_review_cockpit_v1.html > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=7000 \
    --screenshot="$SCREEN" http://127.0.0.1:5173/trfmc_page_review_cockpit_v1.html >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

MOUNT_COUNT="$(grep -o 'data-trfmc-page-review-cockpit="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
CARD_COUNT="$(grep -o 'class="page-card' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
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
  "operation": "TRFMC_P6E_PAGE_REVIEW_COCKPIT_V1",
  "mutation": "public_static_review_cockpit_only",
  "react_mutation": false,
  "backend_mutation": false,
  "audit_source": "$AUDIT_SRC",
  "dashboard": "$DASH",
  "url": "http://127.0.0.1:5173/trfmc_page_review_cockpit_v1.html",
  "data_json": "$DATA_JSON",
  "category_tsv": "$CATEGORY_TSV",
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

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p6e_page_review_cockpit_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P6E_PAGE_REVIEW_COCKPIT_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
