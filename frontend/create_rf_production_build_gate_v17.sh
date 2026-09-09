#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_PRODUCTION_BUILD_GATE_V17_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_PRODUCTION_BUILD_GATE_V17_${TS}.tar.gz"
BUILD_LOG="${QUALITY_DIR}/vite_build.log"
DIST_REPORT="${QUALITY_DIR}/dist_assets.tsv"

echo "============================================================"
echo "TRFMC RF PRODUCTION BUILD GATE V17"
echo "Vite build · lazy chunks · dist assets · production readiness"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f package.json || { echo "ERRORE: package.json mancante"; exit 1; }
test -d node_modules || { echo "ERRORE: node_modules mancante. Eseguire npm install prima del gate."; exit 1; }
test -x node_modules/.bin/vite || { echo "ERRORE: vite locale non trovato in node_modules/.bin/vite"; exit 1; }

test -f src/rf_instruments/instruments/RFOperationalDeckV16ChunkObservatory.tsx || {
  echo "ERRORE: RFOperationalDeckV16ChunkObservatory.tsx mancante"
  exit 1
}

test -f src/rf_instruments/telemetry/RFChunkObservatoryV16.tsx || {
  echo "ERRORE: RFChunkObservatoryV16.tsx mancante"
  exit 1
}

grep -q "RFOperationalDeckV16ChunkObservatory" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta RFOperationalDeckV16ChunkObservatory"
  exit 1
}

echo "OK: V16 presente e montato"

echo
echo "=== FREEZE PRE-BUILD ==="

tar -czf "$FREEZE" \
  index.html \
  package.json \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

echo "Freeze pre-build: $FREEZE"

echo
echo "=== PACKAGE SCRIPTS ==="

python3 - <<'PY' > "../runtime/quality/TRFMC_RF_PRODUCTION_BUILD_GATE_V17_TMP_scripts.txt"
import json
from pathlib import Path

pkg = json.loads(Path("package.json").read_text())
scripts = pkg.get("scripts", {})
for k, v in sorted(scripts.items()):
    print(f"{k}\t{v}")
PY

cat "../runtime/quality/TRFMC_RF_PRODUCTION_BUILD_GATE_V17_TMP_scripts.txt"

echo
echo "=== VITE BUILD ==="

set +e
if python3 - <<'PY'
import json
from pathlib import Path
pkg=json.loads(Path("package.json").read_text())
raise SystemExit(0 if "build" in pkg.get("scripts", {}) else 1)
PY
then
  npm run build > "$BUILD_LOG" 2>&1
  BUILD_RC=$?
else
  ./node_modules/.bin/vite build > "$BUILD_LOG" 2>&1
  BUILD_RC=$?
fi
set -e

echo "Build exit code: $BUILD_RC"

if [ "$BUILD_RC" -ne 0 ]; then
  echo
  echo "=== BUILD FAILED LOG TAIL ==="
  tail -n 120 "$BUILD_LOG" || true

  cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_PRODUCTION_BUILD_GATE_V17",
  "vite_build_exit_code": ${BUILD_RC},
  "build_pass": false,
  "mounted": "RFOperationalDeckV16ChunkObservatory",
  "result": "FAIL",
  "log": "${BUILD_LOG}"
}
JSON

  ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_production_build_gate_v17

  echo
  echo "ERRORE: build fallita. Non procedere oltre. Inviami il tail del log."
  exit 1
fi

echo
echo "=== BUILD OK ==="
tail -n 80 "$BUILD_LOG" || true

echo
echo "=== DIST ASSET REPORT ==="

if [ ! -d dist ]; then
  echo "ERRORE: dist non generata"
  exit 1
fi

{
  echo -e "type\tpath\tbytes"
  find dist -type f | sort | while read -r f; do
    case "$f" in
      *.js) typ="js" ;;
      *.css) typ="css" ;;
      *.html) typ="html" ;;
      *.json) typ="json" ;;
      *) typ="asset" ;;
    esac
    bytes="$(stat -c '%s' "$f" 2>/dev/null || wc -c < "$f")"
    echo -e "${typ}\t${f}\t${bytes}"
  done
} > "$DIST_REPORT"

column -t -s $'\t' "$DIST_REPORT" | sed -n '1,120p'

JS_COUNT="$(awk -F '\t' '$1=="js"{c++} END{print c+0}' "$DIST_REPORT")"
CSS_COUNT="$(awk -F '\t' '$1=="css"{c++} END{print c+0}' "$DIST_REPORT")"
HTML_COUNT="$(awk -F '\t' '$1=="html"{c++} END{print c+0}' "$DIST_REPORT")"
TOTAL_BYTES="$(awk -F '\t' 'NR>1{s+=$3} END{print s+0}' "$DIST_REPORT")"

echo
echo "=== SOURCE CHECKS ==="

CONTENT_CHECK="${QUALITY_DIR}/content_checks.txt"

{
  grep -q "RFOperationalDeckV16ChunkObservatory" src/app/main.tsx && echo "OK: main mounts RFOperationalDeckV16ChunkObservatory" || echo "MISS: RFOperationalDeckV16ChunkObservatory"
  grep -q "React.lazy\|lazy(()" src/rf_instruments/instruments/RFOperationalDeckV15Lazy.tsx && echo "OK: React.lazy in V15" || echo "MISS: React.lazy in V15"
  grep -q "PerformanceResourceTiming\|getEntriesByType" src/rf_instruments/telemetry/RFChunkObservatoryV16.tsx && echo "OK: resource timing observatory" || echo "MISS: resource timing observatory"
  grep -q "RFRenderGovernorHeadlessV14" src/rf_instruments/instruments/RFOperationalDeckV15Lazy.tsx && echo "OK: headless governor preserved in lazy deck" || echo "MISS: headless governor in lazy deck"
  test -f dist/index.html && echo "OK: dist/index.html" || echo "MISS: dist/index.html"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="WARN"
fi

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_PRODUCTION_BUILD_GATE_V17",
  "vite_build_exit_code": ${BUILD_RC},
  "build_pass": true,
  "mounted": "RFOperationalDeckV16ChunkObservatory",
  "react_lazy_expected": true,
  "chunk_observatory": true,
  "dist": {
    "html_files": ${HTML_COUNT},
    "js_files": ${JS_COUNT},
    "css_files": ${CSS_COUNT},
    "total_bytes": ${TOTAL_BYTES}
  },
  "miss_count": ${MISS_COUNT},
  "pre_build_freeze": "${FREEZE}",
  "build_log": "${BUILD_LOG}",
  "dist_report": "${DIST_REPORT}",
  "content_checks": "${CONTENT_CHECK}",
  "result": "${RESULT}"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_production_build_gate_v17

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_production_build_gate_v17/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V17 PRODUCTION BUILD GATE COMPLETATO"
echo "============================================================"
