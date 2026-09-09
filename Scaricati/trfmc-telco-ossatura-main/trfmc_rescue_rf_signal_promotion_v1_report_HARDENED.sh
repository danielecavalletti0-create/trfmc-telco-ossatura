#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RESCUE_RF_SIGNAL_PROMOTION_V1_REPORT_HARDENED_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
FILES="$OUT/file_gate.tsv"
IMPORTS="$OUT/import_mount_gate.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_signal_promotion_v1_rescue_1920x1080.png"
BUILDLOG="$OUT/npm_build_rescue_rf_signal_promotion_v1.log"
NOTES="$OUT/RESCUE_NOTES.md"

COMP="frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx"
EXP="frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx"
CSS="frontend/src/styles.css"

safe_count_fixed() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

safe_count_file() {
  local pattern="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return 0
  fi
  awk -v pat="$pattern" 'index($0, pat) {c++} END {print c+0}' "$file"
}

safe_grep_line() {
  local pattern="$1"
  local file="$2"
  if [ -f "$file" ]; then
    grep -n "$pattern" "$file" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true
  fi
}

echo "============================================================"
echo "TRFMC_RESCUE_RF_SIGNAL_PROMOTION_V1_REPORT_HARDENED"
echo "Report rescue only · no source mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) FILE GATE ==="

{
  echo -e "path\texists\tbytes\tlines\tsha256"
  for f in "$COMP" "$EXP" "$CSS"; do
    if [ -f "$f" ]; then
      printf "%s\tYES\t%s\t%s\t%s\n" \
        "$f" \
        "$(stat -c%s "$f")" \
        "$(wc -l < "$f" | tr -d ' ')" \
        "$(sha256sum "$f" | awk '{print $1}')"
    else
      printf "%s\tNO\t0\t0\tMISSING\n" "$f"
    fi
  done
} | tee "$FILES"

echo
echo "=== 2) IMPORT / MOUNT GATE ==="

{
  echo -e "check\tresult\tmatch"

  if grep -q "RFSignalAnalyzerPromotionV1" "$EXP" 2>/dev/null; then
    echo -e "EngineeringConsoleExpansionV4_imports_or_mounts_RFSignalAnalyzerPromotionV1\tPASS\t$(safe_grep_line "RFSignalAnalyzerPromotionV1" "$EXP")"
  else
    echo -e "EngineeringConsoleExpansionV4_imports_or_mounts_RFSignalAnalyzerPromotionV1\tFAIL\t-"
  fi

  if grep -q "data-trfmc-rf-signal-promotion-v1" "$COMP" 2>/dev/null; then
    echo -e "RFSignalAnalyzerPromotionV1_has_DOM_marker\tPASS\t$(safe_grep_line "data-trfmc-rf-signal-promotion-v1" "$COMP")"
  else
    echo -e "RFSignalAnalyzerPromotionV1_has_DOM_marker\tFAIL\t-"
  fi

  if grep -q "RFSignalAnalyzerWorkbenchV3" "$COMP" 2>/dev/null; then
    echo -e "RFSignalAnalyzerWorkbenchV3_mounted\tPASS\t$(safe_grep_line "RFSignalAnalyzerWorkbenchV3" "$COMP")"
  else
    echo -e "RFSignalAnalyzerWorkbenchV3_mounted\tFAIL\t-"
  fi

  if grep -q "RFInstrumentDockV4" "$COMP" 2>/dev/null; then
    echo -e "RFInstrumentDockV4_mounted\tPASS\t$(safe_grep_line "RFInstrumentDockV4" "$COMP")"
  else
    echo -e "RFInstrumentDockV4_mounted\tFAIL\t-"
  fi

  if grep -q "TrueSpectrumAnalyzer" "$COMP" 2>/dev/null; then
    echo -e "TrueSpectrumAnalyzer_mounted\tPASS\t$(safe_grep_line "TrueSpectrumAnalyzer" "$COMP")"
  else
    echo -e "TrueSpectrumAnalyzer_mounted\tFAIL\t-"
  fi

  IFRAME_COUNT="$(safe_count_fixed "<iframe" "$COMP" "$EXP")"
  if [ "$IFRAME_COUNT" = "0" ]; then
    echo -e "iframe_absent\tPASS\t0"
  else
    echo -e "iframe_absent\tFAIL\t$IFRAME_COUNT"
  fi

  PUBLIC_PATCH_COUNT="$(safe_count_fixed "frontend/public\|/assets/trfmc_.*v51\|trfmc_.*v51r" "$COMP" "$EXP" "$CSS")"
  if [ "$PUBLIC_PATCH_COUNT" = "0" ]; then
    echo -e "public_runtime_patch_refs_absent\tPASS\t0"
  else
    echo -e "public_runtime_patch_refs_absent\tFAIL\t$PUBLIC_PATCH_COUNT"
  fi
} | tee "$IMPORTS"

echo
echo "=== 3) BUILD GATE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

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
echo "=== 5) DOM GATE ==="

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

DOM_MARKER_COUNT="$(safe_count_file 'data-trfmc-rf-signal-promotion-v1="mounted"' "$DOM")"
DOM_TEXT_COUNT="$(safe_count_file 'RF Signal Analyzer: teoria, DSP, visual asset, contract, scenario, QA' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "DOM_MARKER_COUNT=$DOM_MARKER_COUNT"
echo "DOM_TEXT_COUNT=$DOM_TEXT_COUNT"

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

FILE_FAILS="$(awk 'NR>1 && $2!="YES" {c++} END{print c+0}' "$FILES")"
IMPORT_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END{print c+0}' "$IMPORTS")"

cat > "$NOTES" <<MD
# TRFMC Rescue Report — RF Signal Analyzer Promotion V1

## Diagnosi
Il modulo RF/Signal risulta visibile nella UI, ma il precedente rescue si fermava durante i conteggi opzionali perché grep ritorna 1 quando non trova match.

## Esito
Questo rescue hardened evita pipeline fragili e produce il report stabile.

## Interpretazione
- Se build = PASS, file/import gate = PASS e DOM marker > 0, il frontend è salvo.
- Se /api/rfpro/spectrum/sweep non risponde 200, è debito API/bridge, non errore del componente React.
- Il prossimo lavoro corretto è compattare lo stage strumenti RF, perché ora il modulo è potente ma troppo alto e con scrollbar interna pesante.
MD

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FILE_FAILS" != "0" ]; then RESULT="REVIEW_FILES"; fi
if [ "$IMPORT_FAILS" != "0" ]; then RESULT="REVIEW_IMPORTS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$DOM_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RESCUE_RF_SIGNAL_PROMOTION_V1_REPORT_HARDENED",
  "mutation": false,
  "source_mutation": false,
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "file_gate": "$FILES",
  "import_mount_gate": "$IMPORTS",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "notes": "$NOTES",
  "build_result": "$BUILD_RESULT",
  "file_failures": $FILE_FAILS,
  "import_failures": $IMPORT_FAILS,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "dom_marker_count": $DOM_MARKER_COUNT,
  "dom_text_count": $DOM_TEXT_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch1_rf_signal_analyzer_promotion_v1"
ln -sfn "$OUT" "$BASE/runtime/quality/latest_rescue_rf_signal_promotion_v1_report"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== NOTES ==="
sed -n '1,180p' "$NOTES"

echo
echo "============================================================"
echo "TRFMC_RESCUE_RF_SIGNAL_PROMOTION_V1_REPORT_HARDENED COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
