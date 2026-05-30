#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ENGINEERING_CONSOLE_POLISH_V5_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"

CSS="$BASE/frontend/src/styles.css"
SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_engineering_console_polish_v5.log"
HTTP="$OUT/http.tsv"
DIFF="$OUT/engineering_console_polish_v5.diff"
RESTORE="$OUT/RESTORE_ENGINEERING_CONSOLE_POLISH_V5.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_ENGINEERING_CONSOLE_POLISH_V5"
echo "CSS-only visual polish · no React logic mutation"
echo "Timestamp: $TS"
echo "============================================================"

cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
echo "RESTORE_ENGINEERING_CONSOLE_POLISH_V5 completato"
RESTORE_EOF

chmod +x "$RESTORE"

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC ENGINEERING CONSOLE POLISH V5 START === \*/.*?/\* === TRFMC ENGINEERING CONSOLE POLISH V5 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC ENGINEERING CONSOLE POLISH V5 START === */
/*
  V5 visual polish:
  - keep V4 architecture;
  - reduce generic V42 framing;
  - improve cockpit density;
  - make V49 + V4 read as one engineering console.
*/

.mc-shell-engineering-only {
  width: min(1440px, calc(100vw - 84px)) !important;
  max-width: min(1440px, calc(100vw - 84px)) !important;
  margin-top: 18px !important;
  padding: 12px !important;
}

/* The generic V42 title bar becomes a compact instrument header */
.mc-shell-engineering-only .v42-orchestrator-header {
  min-height: 0 !important;
  padding: 8px 10px !important;
  border-bottom-color: rgba(103,232,249,.10) !important;
}

.mc-shell-engineering-only .v42-orchestrator-header h1,
.mc-shell-engineering-only .v42-orchestrator-header h2 {
  font-size: 16px !important;
  letter-spacing: -.01em !important;
}

.mc-shell-engineering-only .v42-orchestrator-header p {
  font-size: 10px !important;
  opacity: .75 !important;
}

/* The '7 sections' block is redundant in engineering-only mode */
.mc-shell-engineering-only .v42-orchestrator-score {
  display: none !important;
}

/* V49 becomes the compact top engineering summary */
.mc-shell-engineering-only .v49-engineering-enrichment {
  padding: 10px !important;
  border-radius: 12px !important;
}

.mc-shell-engineering-only .v49-section-machine-marker {
  margin-bottom: 6px !important;
}

.mc-shell-engineering-only .v49-enrichment-header {
  margin-bottom: 8px !important;
  padding-bottom: 7px !important;
}

.mc-shell-engineering-only .v49-enrichment-header h1,
.mc-shell-engineering-only .v49-engineering-enrichment h1,
.mc-shell-engineering-only .v49-engineering-enrichment h2 {
  font-size: 18px !important;
}

.mc-shell-engineering-only .v49-enrichment-grid {
  gap: 8px !important;
}

.mc-shell-engineering-only .v49-enrichment-card,
.mc-shell-engineering-only .v49-kpi-card {
  padding: 8px 9px !important;
}

/* V4 expansion visually attaches to V49 */
.mc-shell-engineering-only .trfmc-eng-v4 {
  margin-top: 8px !important;
  padding: 10px !important;
  border-radius: 12px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-top {
  grid-template-columns: minmax(0, 1fr) 88px !important;
  padding-bottom: 8px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4 h2 {
  font-size: 18px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-score strong {
  font-size: 23px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-grid-contracts {
  margin-top: 8px !important;
  gap: 7px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-contract {
  padding: 7px 8px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-split {
  gap: 8px !important;
  margin-top: 8px !important;
  grid-template-columns: minmax(0, 1.45fr) minmax(300px, .55fr) !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-panel {
  padding: 8px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-domain-grid {
  gap: 7px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-domain {
  padding: 7px 8px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-domain h3 {
  font-size: 12px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-domain p {
  font-size: 10.5px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-matrix-row {
  grid-template-columns: 78px 66px minmax(0, 1fr) !important;
  padding: 6px 7px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-qa {
  margin-top: 8px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-qa-grid {
  gap: 7px !important;
}

.mc-shell-engineering-only .trfmc-eng-v4-qa-item {
  padding: 7px 8px !important;
}

/* One-console visual continuity */
.mc-shell-engineering-only .v42-orchestrator-shell,
.mc-shell-engineering-only .v49-engineering-enrichment,
.mc-shell-engineering-only .trfmc-eng-v4 {
  box-shadow: none !important;
}

.mc-shell-engineering-only .v42-layout {
  padding: 8px !important;
}

/* Keep it usable on narrower screens */
@media (max-width: 1200px) {
  .mc-shell-engineering-only .trfmc-eng-v4-split {
    grid-template-columns: 1fr !important;
  }
}
/* === TRFMC ENGINEERING CONSOLE POLISH V5 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_V5_POLISH_APPENDED=True")
PY

git diff -- frontend/src/styles.css > "$DIFF" || true

echo
echo "=== BUILD ==="
BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

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

check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_ENGINEERING_CONSOLE_POLISH_V5",
  "mutation": "css_source_polish_only",
  "runtime_injection": false,
  "public_asset_mutation": false,
  "index_mutation": false,
  "backend_mutation": false,
  "files_modified": [
    "frontend/src/styles.css"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_engineering_console_polish_v5"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_ENGINEERING_CONSOLE_POLISH_V5 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
