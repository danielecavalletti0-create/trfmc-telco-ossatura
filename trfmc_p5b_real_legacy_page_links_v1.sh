#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P5B_REAL_LEGACY_PAGE_LINKS_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE" || exit 1

ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
CSS="frontend/src/portal-os/portal-os.css"
MANIFEST="frontend/src/portal-os/portalManifest.ts"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/legacy_page_http.tsv"
DOM="$OUT/war_room_legacy_dom.txt"
SCREEN="$OUT/war_room_legacy_real_1920x1080.png"
DIFF="$OUT/p5b_real_legacy_page_links.diff"
RESTORE="$OUT/RESTORE_P5B_REAL_LEGACY_PAGE_LINKS_V1.sh"

echo "============================================================"
echo "TRFMC_P5B_REAL_LEGACY_PAGE_LINKS_V1"
echo "Attiva link reali verso pagine HTML esistenti in frontend/public"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ROOT" "$CSS" "$MANIFEST"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -u
cd "$BASE" || exit 1
cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"
echo "RESTORE_P5B_REAL_LEGACY_PAGE_LINKS_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH PortalOSRoot: aggiungo legacyUrlForModule + link reale ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

anchor = """function routeForModule(module?: PortalOSModule) {
  const route = module?.route || '#portal-os-preview'
  return route.startsWith('#') ? route : `#${route}`
}

"""

helper = """function legacyUrlForModule(module?: PortalOSModule) {
  const source = module?.source || ''
  if (!source.startsWith('frontend/public/')) return ''
  if (!source.endsWith('.html')) return ''
  return `/${source.replace('frontend/public/', '')}`
}

"""

if helper.strip() not in text:
    if anchor not in text:
        raise SystemExit("ERRORE: routeForModule non trovato")
    text = text.replace(anchor, anchor + helper, 1)

marker_old = """      data-trfmc-p4g-route-registry="mounted"
    >"""
marker_new = """      data-trfmc-p4g-route-registry="mounted"
      data-trfmc-p5b-real-legacy-links="mounted"
    >"""

if marker_old in text and 'data-trfmc-p5b-real-legacy-links="mounted"' not in text:
    text = text.replace(marker_old, marker_new, 1)

# Inserisce un pannello link reale dentro active-card, subito dopo il <dl>...</dl> principale.
insert_after = """            </dl>
          </section>"""

real_link_block = """            </dl>

            <div className="trfmc-command-real-page-link" data-trfmc-real-page-link="active">
              <span>Real page link</span>
              {legacyUrlForModule(activeModule) ? (
                <a href={legacyUrlForModule(activeModule)} target="_blank" rel="noreferrer">
                  Apri pagina reale HTML
                </a>
              ) : (
                <strong>Modulo React / nessuna pagina legacy diretta</strong>
              )}
              <em>{legacyUrlForModule(activeModule) || 'native-react-or-manifest-only'}</em>
            </div>
          </section>"""

if 'data-trfmc-real-page-link="active"' not in text:
    if insert_after not in text:
        raise SystemExit("ERRORE: punto inserimento active-card non trovato")
    text = text.replace(insert_after, real_link_block, 1)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 2) PATCH CSS ==="

if ! grep -q "TRFMC P5B REAL LEGACY PAGE LINKS START" "$CSS"; then
cat >> "$CSS" <<'CSS'

/* TRFMC P5B REAL LEGACY PAGE LINKS START */
.trfmc-command-real-page-link {
  grid-column: 1 / -1;
  border: 1px solid rgba(134, 239, 172, .22);
  border-radius: 14px;
  padding: 10px;
  background: rgba(8, 47, 38, .18);
}

.trfmc-command-real-page-link span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-real-page-link a,
.trfmc-command-real-page-link strong {
  display: inline-block;
  margin-top: 6px;
  color: #86efac;
  font-size: 12px;
  font-weight: 900;
  text-decoration: none;
}

.trfmc-command-real-page-link a:hover {
  text-decoration: underline;
}

.trfmc-command-real-page-link em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 10px;
  font-style: normal;
  word-break: break-word;
}
/* TRFMC P5B REAL LEGACY PAGE LINKS END */
CSS
fi

echo
echo "=== 3) DIFF ==="
git diff -- "$ROOT" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 4) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$OUT/npm_build.log" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$OUT/npm_build.log"

echo
echo "=== 5) HTTP TEST PAGINE REALI ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	has_html	classification
HTTPHDR

check_page() {
  local path="$1"
  local url="http://127.0.0.1:5173$path"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local has_html
  has_html="$(grep -qi '<html\|<!doctype' "$tmp" && echo YES || echo NO)"
  local cls="OK"
  if [ "$code" != "200" ]; then cls="NON_200"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$has_html" != "YES" ]; then cls="NOT_HTML"; fi
  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$has_html" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_page "/trfmc_rf_tm_war_room_v4.html"
check_page "/trfmc_measurement_chain_dsp_engine_v2.html"

echo
echo "=== 6) DOM TEST PAGINA REALE WAR ROOM ==="

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
    --virtual-time-budget=9000 \
    --dump-dom \
    "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html" > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html" >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM"
fi

CANVAS_COUNT="$(grep -o '<canvas' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WAR_TITLE_COUNT="$(grep -o 'TRFMC RF/TM War Room V4' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
REAL_LINK_SOURCE_COUNT="$(grep -o 'data-trfmc-real-page-link="active"' "$ROOT" 2>/dev/null | wc -l | tr -d ' ')"

HTTP_FAILS="$(awk 'NR>1 && $5!="OK"{c++} END {print c+0}' "$HTTP")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_FAILS" != "0" ]; then RESULT="REVIEW_REAL_PAGE_HTTP"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_REAL_PAGE_DOM"; fi
if [ "$CANVAS_COUNT" = "0" ]; then RESULT="REVIEW_REAL_PAGE_CANVAS_MISSING"; fi
if [ "$WAR_TITLE_COUNT" = "0" ]; then RESULT="REVIEW_REAL_PAGE_TITLE_MISSING"; fi
if [ "$REAL_LINK_SOURCE_COUNT" = "0" ]; then RESULT="REVIEW_PORTAL_LINK_NOT_PATCHED"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P5B_REAL_LEGACY_PAGE_LINKS_V1",
  "mutation": "portal_os_real_legacy_page_links",
  "react_promotion": false,
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "http_tsv": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "war_room_real_url": "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html",
  "canvas_count_in_real_page": $CANVAS_COUNT,
  "war_room_title_count_in_real_page": $WAR_TITLE_COUNT,
  "real_link_source_count": $REAL_LINK_SOURCE_COUNT,
  "http_failures": $HTTP_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p5b_real_legacy_page_links_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P5B_REAL_LEGACY_PAGE_LINKS_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
