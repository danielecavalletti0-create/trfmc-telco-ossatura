#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P6B_EXPOSE_ALL_WORKING_PAGES_DASHBOARD_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE" || exit 1

ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
CSS="frontend/src/portal-os/portal-os.css"
REGISTRY="frontend/src/portal-os/workingPagesRegistry.ts"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http_gate.tsv"
DOM="$OUT/dashboard_dom.txt"
SCREEN="$OUT/dashboard_all_working_pages_1920x1080.png"
DIFF="$OUT/p6b_all_working_pages_dashboard.diff"
BUILDLOG="$OUT/npm_build_p6b_all_working_pages.log"
RESTORE="$OUT/RESTORE_P6B_EXPOSE_ALL_WORKING_PAGES_DASHBOARD_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P6B_ALL_WORKING_PAGES_DASHBOARD_PASS_$TS"

echo "============================================================"
echo "TRFMC_P6B_EXPOSE_ALL_WORKING_PAGES_DASHBOARD_V1"
echo "Espone tutte le pagine reali attive nella dashboard"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ROOT" "$CSS" "$REGISTRY"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"
cp -a "$REGISTRY" "$BACKUP/workingPagesRegistry.ts.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -u
cd "$BASE" || exit 1

cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"
cp -a "$BACKUP/workingPagesRegistry.ts.before_$TS" "$REGISTRY"

echo "RESTORE_P6B_EXPOSE_ALL_WORKING_PAGES_DASHBOARD_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH registry: aggiungo allWorkingPages e per-category ordering ==="

python3 - "$REGISTRY" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

if "export const allWorkingPages" not in text:
    text = text.rstrip() + """

export const allWorkingPages = [...workingPages].sort((a, b) => {
  if (a.category !== b.category) return a.category.localeCompare(b.category)
  if (b.rfHits !== a.rfHits) return b.rfHits - a.rfHits
  return a.title.localeCompare(b.title)
})

export const workingPageCount = workingPages.length
"""

p.write_text(text + ("\n" if not text.endswith("\n") else ""), encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 2) PATCH PortalOSRoot: mostra tutte le pagine, non solo top 24 ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

old_import = "import { topWorkingPages, workingPageCategories, workingPagesByCategory } from './workingPagesRegistry'"
new_import = "import { allWorkingPages, topWorkingPages, workingPageCategories, workingPageCount, workingPagesByCategory } from './workingPagesRegistry'"
if old_import in text:
    text = text.replace(old_import, new_import, 1)
elif new_import not in text:
    raise SystemExit("ERRORE: import workingPagesRegistry non trovato")

text = text.replace(
    "<strong>{topWorkingPages.length} verified links · {workingPageCategories.length} categories</strong>",
    "<strong>{workingPageCount} verified links · {workingPageCategories.length} categories</strong>"
)

text = text.replace(
    "{topWorkingPages.map((page) => (",
    "{allWorkingPages.map((page) => ("
)

marker_old = """      data-trfmc-p6a-working-real-pages="mounted"
    >"""
marker_new = """      data-trfmc-p6a-working-real-pages="mounted"
      data-trfmc-p6b-all-working-pages="mounted"
    >"""
if marker_old in text and 'data-trfmc-p6b-all-working-pages="mounted"' not in text:
    text = text.replace(marker_old, marker_new, 1)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 3) PATCH CSS: griglia più gestibile per 111 pagine ==="

cat >> "$CSS" <<'CSS'

/* TRFMC P6B ALL WORKING PAGES START */
.trfmc-command-working-pages {
  scroll-margin-top: 80px;
}

.trfmc-command-working-grid {
  max-height: 520px;
  grid-template-columns: repeat(5, minmax(0, 1fr));
}

.trfmc-command-working-grid a {
  min-height: 86px;
}

@media (max-width: 1680px) {
  .trfmc-command-working-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}

@media (max-width: 1440px) {
  .trfmc-command-working-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
/* TRFMC P6B ALL WORKING PAGES END */
CSS

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
echo "=== 6) STATIC GATE ==="

cat > "$STATIC" <<STATIC_EOF
check	result	count
STATIC_EOF

count_pattern() {
  pattern="$1"
  file="$2"
  grep -RInE "$pattern" "$file" 2>/dev/null | wc -l | tr -d ' '
}

ALL_IMPORT_COUNT="$(count_pattern "allWorkingPages" "$ROOT")"
WORKING_COUNT_IMPORT="$(count_pattern "workingPageCount" "$ROOT")"
P6B_MARKER_SRC="$(count_pattern "data-trfmc-p6b-all-working-pages" "$ROOT")"
REGISTRY_ALL_COUNT="$(count_pattern "export const allWorkingPages" "$REGISTRY")"
DANGEROUS_COUNT="$(grep -RInE "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" frontend/src/portal-os 2>/dev/null | wc -l | tr -d ' ')"
IFRAME_COUNT="$(grep -RIn "<iframe" frontend/src/portal-os 2>/dev/null | wc -l | tr -d ' ')"

printf "all_working_pages_import\t%s\t%s\n" "$([ "$ALL_IMPORT_COUNT" -gt 0 ] && echo PASS || echo FAIL)" "$ALL_IMPORT_COUNT" >> "$STATIC"
printf "working_page_count_import\t%s\t%s\n" "$([ "$WORKING_COUNT_IMPORT" -gt 0 ] && echo PASS || echo FAIL)" "$WORKING_COUNT_IMPORT" >> "$STATIC"
printf "p6b_marker_source\t%s\t%s\n" "$([ "$P6B_MARKER_SRC" -gt 0 ] && echo PASS || echo FAIL)" "$P6B_MARKER_SRC" >> "$STATIC"
printf "registry_all_export\t%s\t%s\n" "$([ "$REGISTRY_ALL_COUNT" -gt 0 ] && echo PASS || echo FAIL)" "$REGISTRY_ALL_COUNT" >> "$STATIC"
printf "dangerous_dom_absent\t%s\t%s\n" "$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)" "$DANGEROUS_COUNT" >> "$STATIC"
printf "iframe_absent\t%s\t%s\n" "$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)" "$IFRAME_COUNT" >> "$STATIC"

column -t -s $'\t' "$STATIC"

echo
echo "=== 7) HTTP GATE CAMPIONE PAGINE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	has_html	classification
HTTPHDR

python3 - "$REGISTRY" "$OUT/sample_urls.txt" <<'PY'
import json
import re
import sys
from pathlib import Path

registry = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
out = Path(sys.argv[2])

m = re.search(r"export const workingPages: WorkingPage\[\] =\s*(\[.*?\])\s*export const workingPageCategories", registry, re.S)
if not m:
    raise SystemExit("workingPages array non trovato")

pages = json.loads(m.group(1))
sample = pages[:10] + pages[len(pages)//2:len(pages)//2+5] + pages[-5:]
seen = []
for p in sample:
    u = p.get("url")
    if u and u not in seen:
        seen.append(u)
out.write_text("\n".join(seen) + "\n", encoding="utf-8")
PY

while read -r urlpath; do
  [ -z "$urlpath" ] && continue
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
done < "$OUT/sample_urls.txt"

echo
echo "=== 8) DOM DASHBOARD GATE ==="

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

P6B_MARKER_COUNT="$(grep -o 'data-trfmc-p6b-all-working-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WORKING_SECTION_COUNT="$(grep -o 'data-trfmc-working-real-pages="active"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WORKING_LINK_COUNT="$(grep -o 'data-trfmc-working-page-link=' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
V42_COUNT="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
REGISTRY_PAGE_COUNT="$(grep -c '"url":' "$REGISTRY" 2>/dev/null | tr -d ' ')"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK" {c++} END {print c+0}' "$HTTP")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC"; fi
if [ "$HTTP_FAILS" != "0" ]; then RESULT="REVIEW_HTTP_SAMPLE"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$P6B_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P6B_MARKER"; fi
if [ "$WORKING_SECTION_COUNT" = "0" ]; then RESULT="REVIEW_WORKING_SECTION"; fi
if [ "$WORKING_LINK_COUNT" != "$REGISTRY_PAGE_COUNT" ]; then RESULT="REVIEW_NOT_ALL_LINKS_RENDERED"; fi
if [ "$V42_COUNT" != "0" ]; then RESULT="REVIEW_V42_LEAK"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P6B ALL WORKING PAGES DASHBOARD PASS

Timestamp: $TS

Status:
- All working real pages rendered in dashboard.
- Registry pages: $REGISTRY_PAGE_COUNT
- DOM working links: $WORKING_LINK_COUNT
- V42 leak: $V42_COUNT
- Build: $BUILD_RESULT
- DOM: $DOM_RESULT
- Screenshot: $SCREENSHOT_RESULT
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P6B_EXPOSE_ALL_WORKING_PAGES_DASHBOARD_V1",
  "mutation": "portal_os_show_all_working_pages",
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "registry": "$REGISTRY",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "build_log": "$BUILDLOG",
  "build_result": "$BUILD_RESULT",
  "static_failures": $STATIC_FAILS,
  "http_failures": $HTTP_FAILS,
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "registry_page_count": $REGISTRY_PAGE_COUNT,
  "working_link_count": $WORKING_LINK_COUNT,
  "p6b_marker_count": $P6B_MARKER_COUNT,
  "working_section_count": $WORKING_SECTION_COUNT,
  "v42_count": $V42_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p6b_expose_all_working_pages_dashboard_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P6B_EXPOSE_ALL_WORKING_PAGES_DASHBOARD_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
