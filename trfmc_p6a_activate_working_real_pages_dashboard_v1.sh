#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1_$TS"
BACKUP="$OUT/backup"
DOM_DIR="$OUT/page_dom"

mkdir -p "$OUT" "$BACKUP" "$DOM_DIR"
cd "$BASE" || exit 1

ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
CSS="frontend/src/portal-os/portal-os.css"
REGISTRY="frontend/src/portal-os/workingPagesRegistry.ts"

SUMMARY="$OUT/summary.json"
PAGE_AUDIT="$OUT/working_pages_audit.tsv"
CATEGORY_AUDIT="$OUT/working_pages_category_matrix.tsv"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http_gate.tsv"
DOM="$OUT/dashboard_dom.txt"
SCREEN="$OUT/dashboard_working_pages_1920x1080.png"
DIFF="$OUT/p6a_working_pages_dashboard.diff"
BUILDLOG="$OUT/npm_build_p6a_working_pages.log"
RESTORE="$OUT/RESTORE_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P6A_WORKING_REAL_PAGES_DASHBOARD_PASS_$TS"

echo "============================================================"
echo "TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1"
echo "Audit tutte le pagine HTML reali + dashboard link funzionanti"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ROOT" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"
if [ -f "$REGISTRY" ]; then
  cp -a "$REGISTRY" "$BACKUP/workingPagesRegistry.ts.before_$TS"
fi

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -u
cd "$BASE" || exit 1

cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"

if [ -f "$BACKUP/workingPagesRegistry.ts.before_$TS" ]; then
  cp -a "$BACKUP/workingPagesRegistry.ts.before_$TS" "$REGISTRY"
else
  rm -f "$REGISTRY"
fi

echo "RESTORE_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) AUDIT TUTTE LE PAGINE HTML REALI IN frontend/public ==="

python3 - "$BASE" "$PAGE_AUDIT" "$CATEGORY_AUDIT" "$REGISTRY" "$DOM_DIR" <<'PY'
import csv
import html
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

base = Path(sys.argv[1])
page_audit = Path(sys.argv[2])
category_audit = Path(sys.argv[3])
registry = Path(sys.argv[4])
dom_dir = Path(sys.argv[5])

public = base / "frontend" / "public"
html_files = sorted(public.glob("*.html"))

def classify(name: str, text: str) -> str:
    s = f"{name} {text[:4000]}".lower()
    if any(x in s for x in ["war_room", "war room", "evidence", "mission dashboard", "executive mission"]):
        return "war-room"
    if any(x in s for x in ["signal", "spectrum", "fft", "dsp", "iq", "waterfall", "measurement_chain"]):
        return "signal-dsp"
    if any(x in s for x in ["antenna", "rru", "ret", "cpri", "aisg", "beam"]):
        return "antenna-rf"
    if any(x in s for x in ["webgl", "3d", "digital twin", "spatial", "three"]):
        return "3d-visual"
    if any(x in s for x in ["core", "ran", "open5gs", "ueransim", "ngap", "pfcp", "gtp", "supi", "suci"]):
        return "5g-core-ran"
    if any(x in s for x in ["fiber", "otdr", "fronthaul", "odf", "splice"]):
        return "fiber"
    if any(x in s for x in ["microwave", "link budget", "fresnel", "smith"]):
        return "microwave"
    if any(x in s for x in ["datacenter", "pdu", "power", "ups", "rack"]):
        return "datacenter-power"
    if any(x in s for x in ["knowledge", "theory", "procedure", "academy", "glossary"]):
        return "knowledge"
    if any(x in s for x in ["noc", "ops", "alarm", "runtime", "health"]):
        return "noc-ops"
    return "reference"

def extract_title(text: str, fallback: str) -> str:
    for pat in [r"<title[^>]*>(.*?)</title>", r"<h1[^>]*>(.*?)</h1>", r"<h2[^>]*>(.*?)</h2>"]:
        m = re.search(pat, text, re.I | re.S)
        if m:
            t = re.sub(r"<[^>]+>", "", m.group(1))
            t = html.unescape(re.sub(r"\s+", " ", t).strip())
            if t:
                return t[:120]
    return fallback.replace("_", " ").replace("-", " ").replace(".html", "").strip().title()[:120]

def safe_count(pattern: str, text: str) -> int:
    return len(re.findall(pattern, text, re.I | re.S))

chrome = None
for c in ["google-chrome", "chromium"]:
    try:
        subprocess.run([c, "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        chrome = c
        break
    except FileNotFoundError:
        pass

rows = []

for path in html_files:
    rel = "/" + path.name
    text = path.read_text(encoding="utf-8", errors="replace")
    title = extract_title(text, path.name)
    category = classify(path.name, text)

    url = f"http://127.0.0.1:5173{rel}"
    curl_tmp = dom_dir / f"{path.stem}.curl.html"
    code = "000"
    try:
        proc = subprocess.run(
            ["curl", "-sS", "-L", "--max-time", "8", "-o", str(curl_tmp), "-w", "%{http_code}", url],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        code = (proc.stdout or "000").strip()
    except Exception:
        code = "000"

    curl_text = curl_tmp.read_text(encoding="utf-8", errors="replace") if curl_tmp.exists() else ""
    bytes_len = len(curl_text.encode("utf-8"))
    has_html = bool(re.search(r"<html|<!doctype", curl_text, re.I))
    fallback = "Vite" in curl_text and "type=\"module\"" in curl_text and path.name not in curl_text

    dom_status = "SKIPPED_NO_CHROME"
    dom_bytes = 0
    dom_title_count = 0
    dom_canvas_count = 0

    if chrome:
        dom_file = dom_dir / f"{path.stem}.dom.txt"
        try:
            dom_proc = subprocess.run(
                [
                    chrome,
                    "--headless=new",
                    "--disable-gpu",
                    "--no-sandbox",
                    "--window-size=1440,900",
                    "--virtual-time-budget=6000",
                    "--dump-dom",
                    url,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            dom_text = dom_proc.stdout or ""
            dom_file.write_text(dom_text, encoding="utf-8")
            dom_status = "PASS" if dom_proc.returncode == 0 and dom_text else f"FAIL_RC_{dom_proc.returncode}"
            dom_bytes = len(dom_text.encode("utf-8"))
            dom_title_count = dom_text.count(title)
            dom_canvas_count = dom_text.lower().count("<canvas")
        except Exception:
            dom_status = "FAIL_EXCEPTION"

    dangerous = safe_count(r"innerHTML|outerHTML|document\.write|insertAdjacentHTML|eval\(|new Function", text)
    iframe = safe_count(r"<iframe\b", text)
    canvas = safe_count(r"<canvas\b", text)
    scripts = safe_count(r"<script\b", text)
    links = safe_count(r'href=["\']/', text)
    rf_hits = safe_count(r"\brf\b|spectrum|fft|iq|waterfall|antenna|open5gs|ueransim|ngap|pfcp|gtp|war room|evidence|dashboard", text)

    working = (
        code == "200"
        and bytes_len > 500
        and has_html
        and not fallback
        and dom_status == "PASS"
        and dom_bytes > 500
        and dangerous == 0
        and iframe == 0
    )

    if working and (dom_title_count > 0 or dom_canvas_count > 0 or rf_hits > 0):
        status = "ACTIVE_REAL_PAGE"
    elif working:
        status = "ACTIVE_GENERIC_PAGE"
    else:
        status = "REVIEW"

    rows.append({
        "status": status,
        "category": category,
        "title": title,
        "url": rel,
        "file": str(path.relative_to(base)),
        "http_status": code,
        "bytes": bytes_len,
        "has_html": "YES" if has_html else "NO",
        "fallback": "YES" if fallback else "NO",
        "dom_status": dom_status,
        "dom_bytes": dom_bytes,
        "dom_title_count": dom_title_count,
        "dom_canvas_count": dom_canvas_count,
        "canvas_source": canvas,
        "script_tags": scripts,
        "root_links": links,
        "rf_hits": rf_hits,
        "dangerous_dom": dangerous,
        "iframe": iframe,
    })

active_rows = [r for r in rows if r["status"].startswith("ACTIVE")]
review_rows = [r for r in rows if not r["status"].startswith("ACTIVE")]

active_rows.sort(key=lambda r: (r["category"], -int(r["rf_hits"]), r["title"]))
rows_sorted = active_rows + review_rows

with page_audit.open("w", encoding="utf-8", newline="") as f:
    fields = [
        "status", "category", "title", "url", "file", "http_status", "bytes", "has_html",
        "fallback", "dom_status", "dom_bytes", "dom_title_count", "dom_canvas_count",
        "canvas_source", "script_tags", "root_links", "rf_hits", "dangerous_dom", "iframe"
    ]
    w = csv.DictWriter(f, delimiter="\t", fieldnames=fields)
    w.writeheader()
    w.writerows(rows_sorted)

cat_counter = Counter(r["category"] for r in active_rows)
with category_audit.open("w", encoding="utf-8", newline="") as f:
    f.write("category\tactive_pages\n")
    for cat, count in sorted(cat_counter.items()):
        f.write(f"{cat}\t{count}\n")

# Limite dashboard: tutte le attive nel registry, ma UI mostrerà top per categoria.
registry_items = []
for r in active_rows:
    registry_items.append({
        "status": r["status"],
        "category": r["category"],
        "title": r["title"],
        "url": r["url"],
        "file": r["file"],
        "domCanvas": int(r["dom_canvas_count"]),
        "sourceCanvas": int(r["canvas_source"]),
        "rfHits": int(r["rf_hits"]),
        "scriptTags": int(r["script_tags"]),
        "rootLinks": int(r["root_links"]),
    })

ts = []
ts.append("export type WorkingPage = {")
ts.append("  status: string")
ts.append("  category: string")
ts.append("  title: string")
ts.append("  url: string")
ts.append("  file: string")
ts.append("  domCanvas: number")
ts.append("  sourceCanvas: number")
ts.append("  rfHits: number")
ts.append("  scriptTags: number")
ts.append("  rootLinks: number")
ts.append("}")
ts.append("")
ts.append("export const workingPages: WorkingPage[] = ")
ts.append(json.dumps(registry_items, indent=2, ensure_ascii=False))
ts.append("")
ts.append("export const workingPageCategories = Array.from(new Set(workingPages.map((page) => page.category))).sort()")
ts.append("export const workingPagesByCategory = (category: string) => workingPages.filter((page) => page.category === category)")
ts.append("export const topWorkingPages = [...workingPages].sort((a, b) => b.rfHits - a.rfHits).slice(0, 24)")
ts.append("")
registry.write_text("\n".join(ts), encoding="utf-8")
PY

echo
echo "=== AUDIT SUMMARY ==="
echo "ACTIVE=$(awk -F'\t' 'NR>1 && $1 ~ /^ACTIVE/ {c++} END {print c+0}' "$PAGE_AUDIT")"
echo "REVIEW=$(awk -F'\t' 'NR>1 && $1 !~ /^ACTIVE/ {c++} END {print c+0}' "$PAGE_AUDIT")"
column -t -s $'\t' "$CATEGORY_AUDIT" | sed -n '1,120p'

echo
echo "=== 2) PATCH PortalOSRoot: correlo workingPages sulla dashboard ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

import_line = "import { topWorkingPages, workingPageCategories, workingPagesByCategory } from './workingPagesRegistry'"
if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

marker_old = """      data-trfmc-p5b-real-legacy-links="mounted"
    >"""
marker_new = """      data-trfmc-p5b-real-legacy-links="mounted"
      data-trfmc-p6a-working-real-pages="mounted"
    >"""

if marker_old in text and 'data-trfmc-p6a-working-real-pages="mounted"' not in text:
    text = text.replace(marker_old, marker_new, 1)

section = """          <section className="trfmc-command-working-pages" data-trfmc-working-real-pages="active">
            <div className="trfmc-command-strip-head">
              <span>Working real pages</span>
              <strong>{topWorkingPages.length} verified links · {workingPageCategories.length} categories</strong>
            </div>

            <div className="trfmc-command-working-category-row">
              {workingPageCategories.slice(0, 12).map((category) => (
                <span key={category}>
                  {category} · {workingPagesByCategory(category).length}
                </span>
              ))}
            </div>

            <div className="trfmc-command-working-grid">
              {topWorkingPages.map((page) => (
                <a key={page.url} href={page.url} target="_blank" rel="noreferrer" data-trfmc-working-page-link={page.url}>
                  <span>{page.category}</span>
                  <strong>{page.title}</strong>
                  <em>{page.url} · canvas {page.domCanvas || page.sourceCanvas} · RF hits {page.rfHits}</em>
                </a>
              ))}
            </div>
          </section>

"""

insert_before = """          <section className="trfmc-command-dashboard-pages" data-trfmc-dashboard-pages="active">"""

if 'data-trfmc-working-real-pages="active"' not in text:
    if insert_before not in text:
        raise SystemExit("ERRORE: punto inserimento dashboard-pages non trovato")
    text = text.replace(insert_before, section + insert_before, 1)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 3) PATCH CSS working pages ==="

if ! grep -q "TRFMC P6A WORKING REAL PAGES START" "$CSS"; then
cat >> "$CSS" <<'CSS'

/* TRFMC P6A WORKING REAL PAGES START */
.trfmc-command-working-pages {
  margin-top: 10px;
  border: 1px solid rgba(134, 239, 172, .18);
  border-radius: 18px;
  background:
    radial-gradient(circle at 18% 0%, rgba(134, 239, 172, .08), transparent 30%),
    rgba(0, 6, 16, .36);
  padding: 10px;
}

.trfmc-command-working-category-row {
  margin-top: 8px;
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.trfmc-command-working-category-row span {
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 999px;
  padding: 4px 7px;
  color: #9fb8ca;
  font-size: 9px;
  background: rgba(0, 10, 22, .48);
}

.trfmc-command-working-grid {
  margin-top: 8px;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  max-height: 360px;
  overflow: auto;
  padding-right: 3px;
}

.trfmc-command-working-grid a {
  display: block;
  text-decoration: none;
  border: 1px solid rgba(103, 232, 249, .14);
  border-radius: 14px;
  background: linear-gradient(180deg, rgba(0, 18, 30, .62), rgba(0, 7, 16, .46));
  color: inherit;
  padding: 10px;
}

.trfmc-command-working-grid a:hover {
  border-color: rgba(134, 239, 172, .48);
  background: rgba(8, 47, 38, .24);
  box-shadow: inset 0 0 0 1px rgba(134, 239, 172, .18), 0 0 28px rgba(16, 185, 129, .12);
}

.trfmc-command-working-grid span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-working-grid strong {
  display: block;
  margin-top: 5px;
  color: #e8f7ff;
  font-size: 12px;
  line-height: 1.12;
}

.trfmc-command-working-grid em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 9px;
  font-style: normal;
  line-height: 1.25;
  word-break: break-word;
}

@media (max-width: 1440px) {
  .trfmc-command-working-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
/* TRFMC P6A WORKING REAL PAGES END */
CSS
fi

echo
echo "=== 4) DIFF ==="
git diff -- "$ROOT" "$CSS" "$REGISTRY" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 5) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG"

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  "$RESTORE"
fi

echo
echo "=== 6) HTTP GATE PRIME PAGINE ACTIVE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	has_html	classification
HTTPHDR

tail -n +2 "$PAGE_AUDIT" | awk -F'\t' '$1 ~ /^ACTIVE/ {print $4}' | head -n 20 | while read -r urlpath; do
  url="http://127.0.0.1:5173${urlpath}"
  tmp="$(mktemp)"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  has_html="$(grep -qi '<html\|<!doctype' "$tmp" && echo YES || echo NO)"
  cls="OK"
  if [ "$code" != "200" ]; then cls="NON_200"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$has_html" != "YES" ]; then cls="NOT_HTML"; fi
  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$has_html" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
done

echo
echo "=== 7) DOM DASHBOARD GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

if [ -n "$CHROME_BIN" ] && [ "$BUILD_RESULT" = "PASS" ]; then
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --dump-dom \
    "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
else
  echo "NO_CHROME_OR_BUILD_FAIL" > "$DOM"
fi

P6A_MARKER_COUNT="$(grep -o 'data-trfmc-p6a-working-real-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WORKING_SECTION_COUNT="$(grep -o 'data-trfmc-working-real-pages="active"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WORKING_LINK_COUNT="$(grep -o 'data-trfmc-working-page-link=' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
V42_COUNT="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"

ACTIVE_COUNT="$(awk -F'\t' 'NR>1 && $1 ~ /^ACTIVE/ {c++} END {print c+0}' "$PAGE_AUDIT")"
REVIEW_COUNT="$(awk -F'\t' 'NR>1 && $1 !~ /^ACTIVE/ {c++} END {print c+0}' "$PAGE_AUDIT")"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK" {c++} END {print c+0}' "$HTTP")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$ACTIVE_COUNT" = "0" ]; then RESULT="REVIEW_NO_ACTIVE_PAGES"; fi
if [ "$HTTP_FAILS" != "0" ]; then RESULT="REVIEW_ACTIVE_PAGE_HTTP"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DASHBOARD_DOM"; fi
if [ "$P6A_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P6A_MARKER"; fi
if [ "$WORKING_SECTION_COUNT" = "0" ]; then RESULT="REVIEW_WORKING_SECTION"; fi
if [ "$WORKING_LINK_COUNT" = "0" ]; then RESULT="REVIEW_WORKING_LINKS"; fi
if [ "$V42_COUNT" != "0" ]; then RESULT="REVIEW_V42_LEAK"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P6A WORKING REAL PAGES DASHBOARD PASS

Timestamp: $TS

Status:
- Working real HTML pages audited from frontend/public.
- Only pages passing HTTP + HTML + DOM + safety gate are activated.
- Dashboard correlated with working real pages.
- Active pages: $ACTIVE_COUNT
- Review pages: $REVIEW_COUNT
- Working links visible in dashboard: $WORKING_LINK_COUNT
- V42 leak: $V42_COUNT
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1",
  "mutation": "portal_os_working_real_pages_dashboard",
  "react_promotion": false,
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "page_audit": "$PAGE_AUDIT",
  "category_audit": "$CATEGORY_AUDIT",
  "registry": "$REGISTRY",
  "diff": "$DIFF",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "active_pages": $ACTIVE_COUNT,
  "review_pages": $REVIEW_COUNT,
  "http_failures": $HTTP_FAILS,
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "p6a_marker_count": $P6A_MARKER_COUNT,
  "working_section_count": $WORKING_SECTION_COUNT,
  "working_link_count": $WORKING_LINK_COUNT,
  "v42_count": $V42_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p6a_activate_working_real_pages_dashboard_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
