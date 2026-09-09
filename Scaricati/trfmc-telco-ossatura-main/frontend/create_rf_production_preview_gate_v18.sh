#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_PRODUCTION_PREVIEW_GATE_V18_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_PRODUCTION_PREVIEW_GATE_V18_${TS}.tar.gz"
PREVIEW_LOG="${QUALITY_DIR}/vite_preview.log"
HTTP_TSV="${QUALITY_DIR}/http.tsv"
SUMMARY="${QUALITY_DIR}/summary.json"

echo "============================================================"
echo "TRFMC RF PRODUCTION PREVIEW GATE V18"
echo "dist preview · production HTTP validation · lazy chunk serving"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"

echo
echo "=== PREFLIGHT ==="

test -f package.json || { echo "ERRORE: package.json mancante"; exit 1; }
test -d node_modules || { echo "ERRORE: node_modules mancante"; exit 1; }
test -x node_modules/.bin/vite || { echo "ERRORE: vite locale non trovato"; exit 1; }
test -d dist || { echo "ERRORE: dist mancante. Prima eseguire V17 / npm run build."; exit 1; }
test -f dist/index.html || { echo "ERRORE: dist/index.html mancante"; exit 1; }
test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }

grep -q "RFOperationalDeckV16ChunkObservatory" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta RFOperationalDeckV16ChunkObservatory"
  exit 1
}

echo "OK: dist presente e V16 montato"

echo
echo "=== FREEZE PREVIEW PRE-GATE ==="

tar -czf "$FREEZE" \
  index.html \
  package.json \
  dist \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

echo "Freeze pre-preview: $FREEZE"

echo
echo "=== STOP EVENTUALI PREVIEW SU 4173 ==="

pkill -f "vite preview" 2>/dev/null || true
sleep 1

echo
echo "=== AVVIO VITE PREVIEW 4173 ==="

(
  npm run preview -- --host 127.0.0.1 --port 4173 --strictPort
) > "$PREVIEW_LOG" 2>&1 &

PREVIEW_PID=$!
echo "$PREVIEW_PID" > "$QUALITY_DIR/preview.pid"

sleep 3

if ! ps -p "$PREVIEW_PID" >/dev/null 2>&1; then
  echo "ERRORE: vite preview non è rimasto attivo"
  cat "$PREVIEW_LOG" || true

  cat > "$SUMMARY" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_PRODUCTION_PREVIEW_GATE_V18",
  "preview_started": false,
  "preview_pid": ${PREVIEW_PID},
  "result": "FAIL",
  "log": "${PREVIEW_LOG}"
}
JSON

  ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_production_preview_gate_v18
  exit 1
fi

echo "OK: vite preview PID $PREVIEW_PID"

echo
echo "=== HTTP PRODUCTION PREVIEW GATE ==="

{
  echo -e "url\tstatus\tbytes"

  for u in \
    / \
    /index.html \
    /api/health \
    /api/docs/index \
    /api/portal/index
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --connect-timeout 2 --max-time 6 "http://127.0.0.1:4173$u" || echo "000 0")
    echo -e "$u\t$code\t$bytes"
  done

  find dist/assets -maxdepth 1 -type f \( -name '*.js' -o -name '*.css' \) | sort | sed 's#^dist##' | while read -r u; do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --connect-timeout 2 --max-time 6 "http://127.0.0.1:4173$u" || echo "000 0")
    echo -e "$u\t$code\t$bytes"
  done
} > "$HTTP_TSV"

column -t -s $'\t' "$HTTP_TSV" | sed -n '1,140p'

echo
echo "=== DIST CHECKS ==="

CONTENT_CHECK="${QUALITY_DIR}/content_checks.txt"

{
  test -f dist/index.html && echo "OK: dist/index.html" || echo "MISS: dist/index.html"

  find dist/assets -maxdepth 1 -type f -name 'index-*.js' | grep -q . \
    && echo "OK: main index JS chunk" || echo "MISS: main index JS chunk"

  find dist/assets -maxdepth 1 -type f -name 'index-*.css' | grep -q . \
    && echo "OK: main index CSS chunk" || echo "MISS: main index CSS chunk"

  find dist/assets -maxdepth 1 -type f -name 'RFInstrumentSuiteV5-*.js' | grep -q . \
    && echo "OK: lazy RFInstrumentSuiteV5 chunk" || echo "MISS: lazy RFInstrumentSuiteV5 chunk"

  find dist/assets -maxdepth 1 -type f -name 'RFSourceBridgePanelV7-*.js' | grep -q . \
    && echo "OK: lazy RFSourceBridgePanelV7 chunk" || echo "MISS: lazy RFSourceBridgePanelV7 chunk"

  find dist/assets -maxdepth 1 -type f -name 'RFSourceRuntimeProbeV8-*.js' | grep -q . \
    && echo "OK: lazy RFSourceRuntimeProbeV8 chunk" || echo "MISS: lazy RFSourceRuntimeProbeV8 chunk"

  find dist/assets -maxdepth 1 -type f -name 'RFBridgeReadinessV9-*.js' | grep -q . \
    && echo "OK: lazy RFBridgeReadinessV9 chunk" || echo "MISS: lazy RFBridgeReadinessV9 chunk"

  find dist/assets -maxdepth 1 -type f -name 'RFEvidenceFlightRecorderV10-*.js' | grep -q . \
    && echo "OK: lazy RFEvidenceFlightRecorderV10 chunk" || echo "MISS: lazy RFEvidenceFlightRecorderV10 chunk"

  find dist/assets -maxdepth 1 -type f -name 'RFSignalDspWorkerV3-*.js' | grep -q . \
    && echo "OK: RFSignalDspWorkerV3 worker chunk" || echo "MISS: RFSignalDspWorkerV3 worker chunk"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
JS_COUNT="$(find dist/assets -type f -name '*.js' | wc -l | tr -d ' ')"
CSS_COUNT="$(find dist/assets -type f -name '*.css' | wc -l | tr -d ' ')"
TOTAL_BYTES="$(find dist -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_PRODUCTION_PREVIEW_GATE_V18",
  "preview_url": "http://127.0.0.1:4173/",
  "preview_pid": ${PREVIEW_PID},
  "preview_started": true,
  "mounted_expected": "RFOperationalDeckV16ChunkObservatory",
  "http_non_200": ${HTTP_NON_200},
  "http_zero_bytes": ${HTTP_ZERO_BYTES},
  "miss_count": ${MISS_COUNT},
  "dist": {
    "js_files": ${JS_COUNT},
    "css_files": ${CSS_COUNT},
    "total_bytes": ${TOTAL_BYTES}
  },
  "pre_preview_freeze": "${FREEZE}",
  "preview_log": "${PREVIEW_LOG}",
  "http_tsv": "${HTTP_TSV}",
  "content_checks": "${CONTENT_CHECK}",
  "result": "${RESULT}"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_production_preview_gate_v18

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_production_preview_gate_v18/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V18 PRODUCTION PREVIEW GATE COMPLETATO"
echo "Apri produzione locale: http://127.0.0.1:4173/"
echo "============================================================"
