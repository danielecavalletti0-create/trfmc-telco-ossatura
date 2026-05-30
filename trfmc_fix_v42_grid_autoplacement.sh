#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FIX_V42_GRID_AUTOPLACEMENT_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"

CSS="$BASE/frontend/src/styles.css"
SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build.log"
HTTP="$OUT/http.tsv"
DIFF="$OUT/fix_v42_grid_autoplacement.diff"
RESTORE="$OUT/RESTORE_FIX_V42_GRID_AUTOPLACEMENT.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_FIX_V42_GRID_AUTOPLACEMENT"
echo "Fix griglia V42: extra children non più schiacciati nella sidebar"
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
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
echo "RESTORE_FIX_V42_GRID_AUTOPLACEMENT completato"
RESTORE_EOF

chmod +x "$RESTORE"

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC FIX V42 GRID AUTOPLACEMENT START === \*/.*?/\* === TRFMC FIX V42 GRID AUTOPLACEMENT END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC FIX V42 GRID AUTOPLACEMENT START === */
/*
  Root cause:
  .v42-layout is a 2-column CSS grid, but it contains more than two children.
  Extra children were auto-placed into the first column, crushing MissionCompactOverview,
  flow, notes and deeplink controls.
*/

/* Two-column layout only for the first operational row */
.v42-layout,
.trfmc-native-orchestrator-layout {
  display: grid !important;
  grid-template-columns: minmax(230px, 280px) minmax(0, 1fr) !important;
  grid-auto-flow: row !important;
  align-items: start !important;
  gap: var(--trfmc-source-gap, 16px) !important;
}

/* Explicit placement of the intended first-row children */
.v42-section-rail,
.trfmc-native-section-rail {
  grid-column: 1 !important;
  grid-row: 1 !important;
}

.v42-section-stage,
.trfmc-native-section-stage {
  grid-column: 2 !important;
  grid-row: 1 !important;
  min-width: 0 !important;
}

/* Every extra block after rail+stage must become a full-width continuation,
   not a crushed card inside the sidebar column. */
.v42-layout > .v42-compact-overview,
.v42-layout > .v42-executive-note,
.v42-layout > .v42-flow,
.v42-layout > .v46-deeplink-index,
.v42-layout > section:not(.v42-section-stage):not(.v42-section-rail),
.v42-layout > div:not(.v42-section-stage):not(.v42-section-rail),
.trfmc-native-orchestrator-layout > .v42-compact-overview,
.trfmc-native-orchestrator-layout > .v42-executive-note,
.trfmc-native-orchestrator-layout > .v42-flow,
.trfmc-native-orchestrator-layout > .v46-deeplink-index {
  grid-column: 1 / -1 !important;
  width: 100% !important;
  max-width: 100% !important;
  min-width: 0 !important;
}

/* Compact overview: horizontal engineering strip, not vertical squeezed sidebar content */
.v42-compact-overview {
  margin-top: 12px !important;
  padding: 14px !important;
  border-radius: 18px !important;
  border: 1px solid rgba(103, 232, 249, .16) !important;
  background: rgba(2, 10, 20, .32) !important;
}

.v42-overview-grid {
  display: grid !important;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)) !important;
  gap: 12px !important;
  align-items: stretch !important;
}

.v42-overview-grid > * {
  min-width: 0 !important;
  width: auto !important;
  max-width: 100% !important;
}

/* Flow: must be horizontal/wrapped, never a vertical ladder caused by grid squeeze */
.v42-flow {
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: wrap !important;
  align-items: center !important;
  justify-content: flex-start !important;
  gap: 12px !important;
  padding: 14px !important;
  margin-top: 12px !important;
}

.v42-flow > * {
  min-width: 112px !important;
  max-width: 180px !important;
}

/* Deeplink index: full-width technical action strip */
.v46-deeplink-index {
  grid-column: 1 / -1 !important;
  display: flex !important;
  flex-wrap: wrap !important;
  gap: 8px !important;
  width: 100% !important;
  max-width: 100% !important;
}

/* Stop ultra-narrow cards and text overflow caused by accidental column placement */
.v42-compact-overview *,
.v42-flow *,
.v46-deeplink-index * {
  overflow-wrap: normal !important;
  word-break: normal !important;
}

/* Stage must not create huge fake empty area */
.v42-section-stage,
.trfmc-native-section-stage {
  align-self: start !important;
  height: auto !important;
  min-height: 0 !important;
}

/* At narrow widths, one-column layout remains clean */
@media (max-width: 1100px) {
  .v42-layout,
  .trfmc-native-orchestrator-layout {
    grid-template-columns: 1fr !important;
  }

  .v42-section-rail,
  .trfmc-native-section-rail,
  .v42-section-stage,
  .trfmc-native-section-stage,
  .v42-layout > .v42-compact-overview,
  .v42-layout > .v42-flow,
  .v42-layout > .v46-deeplink-index {
    grid-column: 1 / -1 !important;
    grid-row: auto !important;
  }
}
/* === TRFMC FIX V42 GRID AUTOPLACEMENT END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_GRID_AUTOPLACEMENT_FIX_APPENDED=True")
PY

git diff -- frontend/src/styles.css > "$DIFF" || true

echo
echo "=== DIFF HEAD ==="
sed -n '1,180p' "$DIFF"

echo
echo "=== BUILD ==="
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
echo "=== HTTP GATE ==="
cat > "$HTTP" <<HTTPHDR
url	status	bytes
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 5 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  rm -f "$tmp"
  printf "%s\t%s\t%s\n" "$url" "$code" "$bytes" | tee -a "$HTTP"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FIX_V42_GRID_AUTOPLACEMENT",
  "mutation": "css_source_fix_only",
  "index_mutation": false,
  "public_asset_mutation": false,
  "backend_mutation": false,
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_fix_v42_grid_autoplacement"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_FIX_V42_GRID_AUTOPLACEMENT COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
