#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
BASE="http://127.0.0.1:4173"
QUALITY_DIR="../runtime/quality/TRFMC_RF_PRODUCTION_PREVIEW_GATE_V18R2_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_PRODUCTION_PREVIEW_GATE_V18R2_${TS}.tar.gz"
PREVIEW_LOG="${QUALITY_DIR}/vite_preview.log"
HTTP_TSV="${QUALITY_DIR}/http.tsv"
CONTENT_CHECK="${QUALITY_DIR}/content_checks.txt"
SUMMARY="${QUALITY_DIR}/summary.json"

echo "============================================================"
echo "TRFMC RF PRODUCTION PREVIEW GATE V18R2"
echo "robust preview validation · existing server reuse · summary always"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"

echo
echo "=== PREFLIGHT ==="

test -f package.json || { echo "ERRORE: package.json mancante"; exit 1; }
test -d node_modules || { echo "ERRORE: node_modules mancante"; exit 1; }
test -x node_modules/.bin/vite || { echo "ERRORE: vite locale non trovato"; exit 1; }
test -d dist || { echo "ERRORE: dist mancante. Prima eseguire npm run build."; exit 1; }
test -f dist/index.html || { echo "ERRORE: dist/index.html mancante"; exit 1; }
test -d dist/assets || { echo "ERRORE: dist/assets mancante"; exit 1; }
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
echo "=== PREVIEW SERVER CHECK ==="

preview_ok=false
if curl -fsS --connect-timeout 2 --max-time 5 "$BASE/" >/dev/null 2>&1; then
  preview_ok=true
fi

PREVIEW_MODE="existing"
PREVIEW_PID="$(ss -ltnp 2>/dev/null | awk '/:4173/ { if (match($0,/pid=[0-9]+/)) { print substr($0,RSTART+4,RLENGTH-4); exit } }' || true)"

if [ "$preview_ok" = true ]; then
  echo "OK: preview già attivo su $BASE"
  echo "${PREVIEW_PID:-unknown}" > "$QUALITY_DIR/preview.pid"
else
  echo "Preview non risponde: avvio vite preview 4173"

  (
    npm run preview -- --host 127.0.0.1 --port 4173 --strictPort
  ) > "$PREVIEW_LOG" 2>&1 &

  PREVIEW_PID=$!
  PREVIEW_MODE="started_by_gate"
  echo "$PREVIEW_PID" > "$QUALITY_DIR/preview.pid"

  for i in $(seq 1 20); do
    if curl -fsS --connect-timeout 2 --max-time 5 "$BASE/" >/dev/null 2>&1; then
      preview_ok=true
      break
    fi
    sleep 0.5
  done
fi

if [ "$preview_ok" != true ]; then
  cat > "$SUMMARY" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_PRODUCTION_PREVIEW_GATE_V18R2",
  "preview_url": "${BASE}/",
  "preview_started_or_reused": false,
  "preview_mode": "${PREVIEW_MODE}",
  "preview_pid": "${PREVIEW_PID:-unknown}",
  "result": "FAIL",
  "reason": "preview server not reachable"
}
JSON

  ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_production_preview_gate_v18r2
  cat "$SUMMARY" | python3 -m json.tool
  exit 1
fi

echo "OK: preview reachable"
echo "Preview PID: ${PREVIEW_PID:-unknown}"
echo "Preview mode: $PREVIEW_MODE"

echo
echo "=== HTTP PROBES ==="

printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe_url() {
  local u="$1"
  local tmp="${QUALITY_DIR}/curl_body.tmp"
  local meta code bytes

  meta="$(curl -sS -o "$tmp" -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "${BASE}${u}" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"

  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

probe_url "/"
probe_url "/index.html"
probe_url "/api/health"
probe_url "/api/docs/index"
probe_url "/api/portal/index"

while IFS= read -r f; do
  u="/${f#dist/}"
  probe_url "$u"
done < <(find dist/assets -maxdepth 1 -type f \( -name '*.js' -o -name '*.css' \) | sort)

rm -f "${QUALITY_DIR}/curl_body.tmp" 2>/dev/null || true

echo "Prime righe HTTP:"
awk -F '\t' 'NR<=80 { printf "%-90s %-8s %s\n", $1, $2, $3 }' "$HTTP_TSV"

echo
echo "=== DIST CONTENT CHECKS ==="

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
  "operation": "TRFMC_RF_PRODUCTION_PREVIEW_GATE_V18R2",
  "preview_url": "${BASE}/",
  "preview_started_or_reused": true,
  "preview_mode": "${PREVIEW_MODE}",
  "preview_pid": "${PREVIEW_PID:-unknown}",
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

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_production_preview_gate_v18r2

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_production_preview_gate_v18r2/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V18R2 PRODUCTION PREVIEW GATE COMPLETATO"
echo "Preview locale: ${BASE}/"
echo "============================================================"
