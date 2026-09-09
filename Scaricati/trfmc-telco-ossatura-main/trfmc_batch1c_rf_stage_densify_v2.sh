#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH1C_RF_STAGE_DENSIFY_V2_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

CSS="frontend/src/styles.css"
SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_batch1c_rf_stage_densify_v2.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_stage_densify_v2_1920x1080.png"
DIFF="$OUT/rf_stage_densify_v2.diff"
RESTORE="$OUT/RESTORE_RF_STAGE_DENSIFY_V2.sh"

echo "============================================================"
echo "TRFMC_BATCH1C_RF_STAGE_DENSIFY_V2"
echo "CSS-only RF instrument densify · no React/backend/index mutation"
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
echo "RESTORE_RF_STAGE_DENSIFY_V2 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CSS DENSIFY PATCH ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC BATCH1C RF STAGE DENSIFY V2 START === \*/.*?/\* === TRFMC BATCH1C RF STAGE DENSIFY V2 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC BATCH1C RF STAGE DENSIFY V2 START === */
/*
  RF Stage Densify V2
  Fix observed issue:
  - Batch1B removed the heavy inner scrollbar;
  - but instrument grid panels still stretch vertically;
  - left/right panels become empty towers;
  - spectrum/waterfall area still wastes vertical space.

  Scope:
  - CSS source only;
  - no React mutation;
  - no backend mutation;
  - no index/public runtime patch.
*/

/* Stage: natural page scroll, not internal window, but no uncontrolled height */
.mc-shell-engineering-only .trfmc-rf-instrument-stage {
  overflow: visible !important;
  max-height: none !important;
  padding: 5px !important;
  background: rgba(0, 4, 10, .18) !important;
}

/* Critical: prevent CSS Grid equal-height stretching */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-grid,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-grid,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-surface-grid {
  align-items: start !important;
  align-content: start !important;
  grid-auto-rows: auto !important;
  gap: 7px !important;
  padding: 7px !important;
  min-height: 0 !important;
  height: auto !important;
}

/* Instrument shell: no forced tall instrument island */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-shell,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-shell,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-surface-shell {
  min-height: 0 !important;
  height: auto !important;
  max-height: none !important;
  border-radius: 12px !important;
}

/* Headers: compact T&M strip */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-header,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-header,
.mc-shell-engineering-only .trfmc-rf-instrument-stage header {
  padding: 8px 10px !important;
  min-height: 0 !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-header h1,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-header h1,
.mc-shell-engineering-only .trfmc-rf-instrument-stage header h1 {
  font-size: 16px !important;
  line-height: 1.05 !important;
  letter-spacing: .10em !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-header p,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-header p,
.mc-shell-engineering-only .trfmc-rf-instrument-stage header p {
  font-size: 9.5px !important;
  line-height: 1.2 !important;
}

/* Left/right panels: fit content, do not stretch into towers */
.mc-shell-engineering-only .trfmc-rf-instrument-stage aside,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-panel {
  align-self: start !important;
  justify-self: stretch !important;
  min-height: 0 !important;
  height: fit-content !important;
  max-height: 310px !important;
  overflow: hidden !important;
  padding: 7px 8px !important;
  border-radius: 10px !important;
}

/* Main visual panel: content-sized, not full-height wall */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-main,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-main,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-surface-main {
  align-self: start !important;
  min-height: 0 !important;
  height: auto !important;
  max-height: none !important;
  overflow: visible !important;
  padding: 7px !important;
}

/* Text density inside instrument side panels */
.mc-shell-engineering-only .trfmc-rf-instrument-stage aside h2,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel h2,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-panel h2 {
  font-size: 12px !important;
  margin: 0 0 5px 0 !important;
  line-height: 1.05 !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage aside p,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel p,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-panel p {
  font-size: 9.5px !important;
  line-height: 1.18 !important;
  margin: 0 !important;
}

/* Main canvas stack: override inline canvas heights */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-main > div {
  gap: 6px !important;
  min-height: 0 !important;
  height: auto !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-main > div > canvas:first-child,
.mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 420px"] {
  height: 230px !important;
  max-height: 230px !important;
}

/* Lower waterfall + constellation row */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-main > div > div[style*="grid-template-columns"],
.mc-shell-engineering-only .trfmc-rf-instrument-stage div[style*="grid-template-columns: 1.35fr 0.65fr"] {
  display: grid !important;
  grid-template-columns: minmax(0, 1.1fr) minmax(180px, .48fr) !important;
  gap: 6px !important;
  min-height: 0 !important;
  height: auto !important;
}

.mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 260px"] {
  height: 112px !important;
  max-height: 112px !important;
}

/* RF Dock V4 / TrueSpectrum variants: common large internal sections */
.mc-shell-engineering-only .trfmc-rf-instrument-stage .spectrum-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .waterfall-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .constellation-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-spectrum-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-waterfall-surface,
.mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-constellation-surface {
  min-height: 0 !important;
  height: auto !important;
  max-height: 260px !important;
  overflow: hidden !important;
}

/* Avoid giant blank zones created by generic sections inside stage */
.mc-shell-engineering-only .trfmc-rf-instrument-stage section,
.mc-shell-engineering-only .trfmc-rf-instrument-stage main,
.mc-shell-engineering-only .trfmc-rf-instrument-stage article {
  min-height: 0 !important;
}

/* Compact scenario acceptance strip */
.mc-shell-engineering-only .trfmc-rf-scenario-panel {
  margin-top: 6px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid {
  grid-template-columns: repeat(4, minmax(0, 1fr)) !important;
  gap: 5px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid article {
  padding: 5px 6px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid strong {
  font-size: 10px !important;
}

.mc-shell-engineering-only .trfmc-rf-scenario-grid span {
  font-size: 9px !important;
  line-height: 1.18 !important;
}

/* If viewport is narrower, keep readability */
@media (max-width: 1280px) {
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-grid,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-grid,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-surface-grid {
    grid-template-columns: 1fr !important;
  }

  .mc-shell-engineering-only .trfmc-rf-instrument-stage aside,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-panel,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage .rf-dock-panel {
    max-height: none !important;
  }

  .mc-shell-engineering-only .trfmc-rf-instrument-stage .trfmc-instrument-main > div > canvas:first-child,
  .mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 420px"] {
    height: 220px !important;
    max-height: 220px !important;
  }

  .mc-shell-engineering-only .trfmc-rf-instrument-stage canvas[style*="height: 260px"] {
    height: 108px !important;
    max-height: 108px !important;
  }

  .mc-shell-engineering-only .trfmc-rf-scenario-grid {
    grid-template-columns: 1fr 1fr !important;
  }
}
/* === TRFMC BATCH1C RF STAGE DENSIFY V2 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_BATCH1C_RF_STAGE_DENSIFY_V2_APPENDED=True")
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
echo "=== 5) DOM / CSS MARKER GATE ==="

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
CSS_MARKER_COUNT="$(awk 'index($0, "TRFMC BATCH1C RF STAGE DENSIFY V2 START") {c++} END {print c+0}' "$CSS")"

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
  "operation": "TRFMC_BATCH1C_RF_STAGE_DENSIFY_V2",
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

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch1c_rf_stage_densify_v2"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH1C_RF_STAGE_DENSIFY_V2 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
