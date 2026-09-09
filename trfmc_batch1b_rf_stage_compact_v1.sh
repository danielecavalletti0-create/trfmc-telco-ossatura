#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH1B_RF_STAGE_COMPACT_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

CSS="frontend/src/styles.css"
SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_batch1b_rf_stage_compact_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_stage_compact_v1_1920x1080.png"
DIFF="$OUT/rf_stage_compact_v1.diff"
RESTORE="$OUT/RESTORE_RF_STAGE_COMPACT_V1.sh"

echo "============================================================"
echo "TRFMC_BATCH1B_RF_STAGE_COMPACT_V1"
echo "CSS-only RF stage compacting · no React/backend/index mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$CSS" ]; then
  echo "ERRORE: styles.css non trovato"
  exit 1
fi

cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
echo "RESTORE_RF_STAGE_COMPACT_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CSS COMPACT PATCH ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC BATCH1B RF STAGE COMPACT V1 START === \*/.*?/\* === TRFMC BATCH1B RF STAGE COMPACT V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC BATCH1B RF STAGE COMPACT V1 START === */
/*
  RF Stage Compacting V1
  Scope:
  - CSS source only;
  - no React logic mutation;
  - no backend mutation;
  - no index/public runtime patch;
  - reduce nested-scroll / over-tall instrument feeling.
*/

/* RF promoted module: tighter cockpit rhythm */
.mc-shell-engineering-only .trfmc-rf-promo-v1 {
  margin-top: 8px !important;
  padding: 8px !important;
  border-radius: 11px !important;
}

.mc-shell-engineering-only .trfmc-rf-promo-head {
  grid-template-columns: minmax(0, 1fr) 82px !important;
  gap: 8px !important;
  padding-bottom: 6px !important;
}

.mc-shell-engineering-only .trfmc-rf-promo-v1 h2 {
  font-size: 16px !important;
  margin-bottom: 4px !important;
}

.mc-shell-engineering-only .trfmc-rf-promo-v1 p {
  font-size: 10.5px !important;
  line-height: 1.28 !important;
}

.mc-shell-engineering-only .trfmc-rf-promo-readiness strong {
  font-size: 20px !important;
}

.mc-shell-engineering-only .trfmc-rf-promo-readiness span {
  font-size: 8px !important;
}

/* Theory/contract cards: useful, but not dominant */
.mc-shell-engineering-only .trfmc-rf-promo-grid {
  gap: 7px !important;
  margin-top: 7px !important;
}

.mc-shell-engineering-only .trfmc-rf-promo-panel {
  padding: 7px !important;
  border-radius: 10px !important;
}

.mc-shell-engineering-only .trfmc-rf-theory-grid,
.mc-shell-engineering-only .trfmc-rf-contract-grid {
  gap: 6px !important;
}

.mc-shell-engineering-only .trfmc-rf-theory-card,
.mc-shell-engineering-only .trfmc-rf-contract-card {
  padding: 6px 7px !important;
  border-radius: 8px !important;
}

.mc-shell-engineering-only .trfmc-rf-theory-card strong,
.mc-shell-engineering-only .trfmc-rf-contract-card span {
  font-size: 9px !important;
}

.mc-shell-engineering-only .trfmc-rf-theory-card span,
.mc-shell-engineering-only .trfmc-rf-contract-card strong {
  font-size: 10px !important;
}

.mc-shell-engineering-only .trfmc-rf-theory-card em,
.mc-shell-engineering-only .trfmc-rf-contract-card em {
  font-size: 8px !important;
  padding: 2px 6px !important;
}

/* Instrument selector: compact tabs */
.mc-shell-engineering-only .trfmc-rf-instrument-panel {
  margin-top: 7px !important;
}

.mc-shell-engineering-only .trfmc-rf-tabbar {
  gap: 6px !important;
  margin-bottom: 7px !important;
}

.mc-shell-engineering-only .trfmc-rf-tabbar button {
  padding: 6px 7px !important;
  border-radius: 9px !important;
}

.mc-shell-engineering-only .trfmc-rf-tabbar strong {
  font-size: 11px !important;
}

.mc-shell-engineering-only .trfmc-rf-tabbar span {
  font-size: 9px !important;
  margin-top: 2px !important;
}

/*
  Critical correction:
  remove heavy nested scrollbar from RF stage.
  Let the page scroll naturally; keep the instrument readable.
*/
.mc-shell-engineering-only .trfmc-rf-instrument-stage {
  max-height: none !important;
  overflow: visible !important;
  padding: 6px !important;
  border-radius: 9px !important;
}

/* Generic instrument shell compaction */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-shell,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-instrument-shell,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-shell {
  border-radius: 14px !important;
  margin: 0 !important;
  max-width: 100% !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-header,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-header,
.mc-shell-engineering-only .trfmc-rf-instrument-stage header {
  padding: 10px 12px !important;
  min-height: 0 !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-header h1,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-header h1,
.mc-shell-engineering-only .trfmc-rf-instrument-stage header h1 {
  font-size: 18px !important;
  line-height: 1.05 !important;
  letter-spacing: .08em !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-header p,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-header p,
.mc-shell-engineering-only .trfmc-rf-instrument-stage header p {
  font-size: 10px !important;
  line-height: 1.25 !important;
}

/* Instrument grids: more T&M console, less vertical wall */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-grid,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-grid,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-surface-grid {
  display: grid !important;
  grid-template-columns: minmax(190px, .62fr) minmax(0, 1.45fr) minmax(230px, .78fr) !important;
  gap: 8px !important;
  padding: 8px !important;
  align-items: stretch !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-panel,
.mc-shell-engineering-only .trfmc-rf-instrument-stage aside,
.mc-shell-engineering-only .trfmc-rf-instrument-stage section {
  border-radius: 11px !important;
}

/* Text panels: compact monospace instrumentation */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel,
.mc-shell-engineering-only .trfmc-rf-instrument-stage aside {
  padding: 9px !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel h2,
.mc-shell-engineering-only .trfmc-rf-instrument-stage aside h2 {
  font-size: 13px !important;
  letter-spacing: .10em !important;
  margin-bottom: 7px !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel p,
.mc-shell-engineering-only .trfmc-rf-instrument-stage aside p {
  font-size: 10.5px !important;
  line-height: 1.26 !important;
}

/* Canvas compaction: override inline heights with !important */
.mc-shell-engineering-only .trfmc-rf-instrument-stage canvas {
  max-width: 100% !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-main > div > canvas:first-child,
.mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 420px"] {
  height: 300px !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 260px"] {
  height: 160px !important;
}

/* Dock/spectrum variants often use internal big surfaces */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .spectrum-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .waterfall-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .constellation-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-spectrum-surface {
  min-height: 0 !important;
  max-height: 340px !important;
}

/* Scenario strip: compact final acceptance row */
.mc-shell-engineering-only .trfmc-rf-scenario-panel {
  margin-top: 7px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid {
  gap: 6px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid article {
  padding: 6px 7px !important;
  border-radius: 8px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid strong {
  font-size: 10.5px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid span {
  font-size: 9.5px !important;
}

/* Responsive safety */
@media (max-width: 1280px) {
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-grid,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-grid,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-surface-grid {
    grid-template-columns: 1fr !important;
  }

  .mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-main > div > canvas:first-child,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 420px"] {
    height: 260px !important;
  }

  .mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 260px"] {
    height: 140px !important;
  }
}
/* === TRFMC BATCH1B RF STAGE COMPACT V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_BATCH1B_RF_STAGE_COMPACT_V1_APPENDED=True")
PY

echo
echo "=== 2) DIFF ==="
git diff -- frontend/src/styles.css > "$DIFF" || true
sed -n '1,180p' "$DIFF"

echo
echo "=== 3) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  "$RESTORE"
  BUILD_RESULT="FAIL_RESTORED"
fi

echo
echo "=== 4) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 5) DOM / STYLE GATE ==="

DOM_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM"
fi

DOM_MARKER_COUNT="$(awk 'index($0, "data-trfmc-rf-signal-promotion-v1=\"mounted\"") {c++} END {print c+0}' "$DOM")"
CSS_MARKER_COUNT="$(awk 'index($0, "TRFMC BATCH1B RF STAGE COMPACT V1 START") {c++} END {print c+0}' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "DOM_MARKER_COUNT=$DOM_MARKER_COUNT"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"

echo
echo "=== 6) SCREENSHOT GATE ==="

SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$DOM_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MARKER"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH1B_RF_STAGE_COMPACT_V1",
  "mutation": "css_source_only",
  "react_mutation": false,
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "dom_marker_count": $DOM_MARKER_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch1b_rf_stage_compact_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH1B_RF_STAGE_COMPACT_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
