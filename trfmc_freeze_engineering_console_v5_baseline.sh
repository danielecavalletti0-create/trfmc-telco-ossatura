#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ENGINEERING_CONSOLE_V5_BASELINE_$TS"
FREEZE="$BASE/_archive/TRFMC_ENGINEERING_CONSOLE_V5_BASELINE_$TS"

mkdir -p "$OUT" "$FREEZE"/{src,runtime_quality,screenshots}

cd "$BASE"

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DIFF="$OUT/git_diff_engineering_v5_baseline.diff"
STATUS="$OUT/git_status_engineering_v5_baseline.txt"
SCREEN="$OUT/full_engineering_stack_v5_1920x1080.png"
NOTES="$OUT/ENGINEERING_CONSOLE_V5_BASELINE_NOTES.md"

echo "============================================================"
echo "TRFMC_ENGINEERING_CONSOLE_V5_BASELINE"
echo "Read-only baseline freeze · no portal mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) SNAPSHOT FILE SORGENTE CRITICI ==="

cp -a frontend/src/app/main.tsx "$FREEZE/src/main.tsx"
cp -a frontend/src/styles.css "$FREEZE/src/styles.css"
cp -a frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx "$FREEZE/src/MissionLayoutOrchestratorV42.tsx"
cp -a frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx "$FREEZE/src/EngineeringContentEnrichmentV49.tsx"

if [ -f frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx ]; then
  cp -a frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx "$FREEZE/src/EngineeringConsoleExpansionV4.tsx"
fi

echo
echo "=== 2) GIT STATUS / DIFF ==="

git status --porcelain=v1 | tee "$STATUS"
git diff -- frontend/src/app/main.tsx \
           frontend/src/styles.css \
           frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx \
           frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx \
           frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx \
           > "$DIFF" || true

echo
echo "=== 3) HTTP GATE ==="

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

echo
echo "=== 4) SCREENSHOT GATE ==="

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

[ -f "$SCREEN" ] && cp -a "$SCREEN" "$FREEZE/screenshots/full_engineering_stack_v5_1920x1080.png" || true

echo
echo "=== 5) BUILD CHECK ==="

BUILDLOG="$OUT/npm_build_v5_baseline.log"
BUILD_RESULT="PASS"

(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$NOTES" <<MD
# TRFMC Engineering Console V5 Baseline

## Esito
La V5 è la prima baseline visiva accettabile della vista \`#full-engineering-stack\`.

## Stato
- Doppio portale: risolto.
- Engineering-only rendering: attivo.
- V49: contenuto principale.
- V4 expansion: montata come console di governo.
- Layout: da congelare, non da ritoccare ulteriormente salvo difetti oggettivi.
- Prossima fase: completamento domini, non CSS.

## Prossimo dominio consigliato
1. RF Physics
2. Signal Analyzer
3. RF/Microwave
4. Antenna System
5. Core Network / RAN

## Regola
Da qui in avanti ogni nuovo modulo deve avere:
- teoria;
- simulatore;
- asset visuale;
- endpoint o contract;
- scenario;
- QA gate.
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_ENGINEERING_CONSOLE_V5_BASELINE",
  "mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "freeze": "$FREEZE",
  "status": "$STATUS",
  "diff": "$DIFF",
  "http_tsv": "$HTTP",
  "screenshot": "$SCREEN",
  "notes": "$NOTES",
  "build_log": "$BUILDLOG",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo BASELINE_READY || echo REVIEW)"
}
JSON

cp -a "$OUT"/. "$FREEZE/runtime_quality/"

ln -sfn "$OUT" "$BASE/runtime/quality/latest_engineering_console_v5_baseline"
ln -sfn "$FREEZE" "$BASE/_archive/latest_engineering_console_v5_baseline"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== NOTES ==="
sed -n '1,180p' "$NOTES"

echo
echo "============================================================"
echo "TRFMC_ENGINEERING_CONSOLE_V5_BASELINE COMPLETATO"
echo "Output: $OUT"
echo "Freeze: $FREEZE"
echo "============================================================"
