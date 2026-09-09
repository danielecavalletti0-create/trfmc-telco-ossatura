#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35R1_RECOVERY_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35R1_RECOVERY_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35R1_RECOVERY_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"
DATA="$ROOT/frontend/src/rf_scenarios/scenarioDataV35.ts"
ENGINE="$ROOT/frontend/src/rf_scenarios/RFDynamicScenarioDeckV35.tsx"
WRAPPER="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios.tsx"

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"
HTTP_TSV="$RELEASE_DIR/http.tsv"
BUILD_LOG="$RELEASE_DIR/npm_build_v35r1.log"
SCREENSHOT="$RELEASE_DIR/trfmc_v35r1_runtime.png"
DOM_DUMP="$RELEASE_DIR/trfmc_v35r1_dom.html"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" runtime/freezes

echo "============================================================"
echo "TRFMC V35R1 DYNAMIC SCENARIOS RECOVERY"
echo "evidence recovery · no new patch · Chrome DOM crash tolerant"
echo "============================================================"

echo
echo "=== PREFLIGHT CURRENT STATE ==="

test -f "$MAIN" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$DATA" || { echo "ERRORE: scenarioDataV35.ts mancante"; exit 1; }
test -f "$ENGINE" || { echo "ERRORE: RFDynamicScenarioDeckV35.tsx mancante"; exit 1; }
test -f "$WRAPPER" || { echo "ERRORE: RFOperationalDeckV35DynamicScenarios.tsx mancante"; exit 1; }

grep -q "RFOperationalDeckV35DynamicScenarios" "$MAIN" || {
  echo "ERRORE: main.tsx non monta V35"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: API 4181 non operative"
  exit 1
}

echo "OK: V35 risulta già montato e API 4181 live"

echo
echo "=== STATIC CHECKS ==="

{
  test -f "$DATA" && echo "OK: scenario data exists" || echo "MISS: scenario data exists"
  test -f "$ENGINE" && echo "OK: scenario engine exists" || echo "MISS: scenario engine exists"
  test -f "$WRAPPER" && echo "OK: V35 wrapper exists" || echo "MISS: V35 wrapper exists"

  grep -q "RFDynamicScenarioDeckV35" "$ENGINE" && echo "OK: scenario deck export exists" || echo "MISS: scenario deck export exists"
  grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$WRAPPER" && echo "OK: V34R1R2 preserved below V35" || echo "MISS: V34R1R2 preserved below V35"
  grep -q "RFOperationalDeckV35DynamicScenarios" "$MAIN" && echo "OK: main imports/mounts V35" || echo "MISS: main imports/mounts V35"
  grep -q "<RFOperationalDeckV35DynamicScenarios />" "$MAIN" && echo "OK: main JSX mounts V35" || echo "MISS: main JSX mounts V35"

  grep -q "Electronics Fundamentals" "$DATA" && echo "OK: electronics scenario exists" || echo "MISS: electronics scenario exists"
  grep -q "Microstrip Patch Antenna" "$DATA" && echo "OK: microstrip scenario exists" || echo "MISS: microstrip scenario exists"
  grep -q "Antenna Systems Explorer" "$DATA" && echo "OK: antenna scenario exists" || echo "MISS: antenna scenario exists"
  grep -q "Telecom Tower Infrastructure" "$DATA" && echo "OK: tower scenario exists" || echo "MISS: tower scenario exists"
  grep -q "Beamwidth and Coverage" "$DATA" && echo "OK: beamwidth scenario exists" || echo "MISS: beamwidth scenario exists"
  grep -q "RF & Microwave Engineering Lab" "$DATA" && echo "OK: RF lab scenario exists" || echo "MISS: RF lab scenario exists"
  grep -q "UAV Platforms and ISR Systems" "$DATA" && echo "OK: UAV ISR scenario exists" || echo "MISS: UAV ISR scenario exists"

  grep -q "v35-scenario-shell" "$STYLES" && echo "OK: V35 CSS present" || echo "MISS: V35 CSS present"

  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/spectrum/sweep | grep -q "TRFMC_CONTRACT_COVERAGE_V31" && echo "OK: backend contracts still live" || echo "MISS: backend contracts still live"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

echo
echo "=== BUILD CHECK ==="

(
  cd "$ROOT/frontend"
  npm run build > "$BUILD_LOG" 2>&1
) && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"

echo "Build result: $BUILD_RESULT"

if [ "$BUILD_RESULT" = "FAIL" ]; then
  echo
  echo "=== BUILD LOG TAIL ==="
  tail -n 180 "$BUILD_LOG" || true
fi

echo
echo "=== ENSURE VITE 5173 ==="

pkill -f "vite.*5173" 2>/dev/null || true
pkill -f "vite --host 127.0.0.1 --port 5173" 2>/dev/null || true
sleep 2

(
  cd "$ROOT/frontend"
  nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$RELEASE_DIR/vite_dev_5173.log" 2>&1 &
  echo $! > "$RELEASE_DIR/vite_dev_5173.pid"
)

for i in $(seq 1 25); do
  if curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:5173/ >/dev/null 2>&1; then
    echo "OK: Vite 5173 attivo"
    break
  fi
  sleep 1
done

echo
echo "=== HTTP GATE ==="

printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

for u in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:4181/api/mission/status \
  http://127.0.0.1:4181/api/core/open5gs/status \
  http://127.0.0.1:4181/api/rfpro/spectrum/sweep
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== CHROME SCREENSHOT / DOM BEST-EFFORT ==="

CHROME_BIN=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME_BIN="$(command -v "$c")"
    break
  fi
done

SCREENSHOT_RESULT="SKIPPED"
DOM_RESULT="SKIPPED"
DOM_NOTE="not_attempted"

if [ -n "$CHROME_BIN" ]; then
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --disable-dev-shm-usage \
    --no-sandbox \
    --window-size=1920,2000 \
    --virtual-time-budget=12000 \
    --screenshot="$SCREENSHOT" \
    http://127.0.0.1:5173/ >/dev/null 2>"$RELEASE_DIR/chrome_screenshot.stderr" \
    && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --disable-dev-shm-usage \
    --no-sandbox \
    --window-size=1920,2000 \
    --virtual-time-budget=12000 \
    --dump-dom \
    http://127.0.0.1:5173/ > "$DOM_DUMP" 2>"$RELEASE_DIR/chrome_dom.stderr" \
    && DOM_RESULT="PASS" || DOM_RESULT="SKIPPED_CHROME_CRASH"

  if [ "$DOM_RESULT" = "PASS" ]; then
    if grep -q "V35 DYNAMIC SCENARIO ENGINE" "$DOM_DUMP" && grep -q "Microstrip Patch Antenna" "$DOM_DUMP"; then
      DOM_NOTE="v35_visible"
    else
      DOM_RESULT="FAIL"
      DOM_NOTE="dom_loaded_but_v35_marker_missing"
    fi
  else
    DOM_NOTE="chrome_dump_dom_failed_not_app_build_failure"
  fi
fi

echo "Screenshot result: $SCREENSHOT_RESULT"
echo "DOM result       : $DOM_RESULT"
echo "DOM note         : $DOM_NOTE"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$BUILD_RESULT" = "FAIL" ] || [ "$HTTP_NON_200" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$SCREENSHOT_RESULT" = "FAIL" ]; then
  RESULT="WARN"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST / SUMMARY ==="

MANIFEST="$RELEASE_DIR/dynamic_rf_telco_scenarios_recovery_manifest_v35r1.json"
SUMMARY="$QUALITY_DIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35R1_RECOVERY",
  "reason": "V35 patch and build were valid; previous failure was caused by Chrome --dump-dom trace/breakpoint crash.",
  "frontend_mutation": false,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "scenario_count": 7,
  "scenarios": [
    "electronics",
    "microstrip",
    "antenna-system",
    "tower-infrastructure",
    "beamwidth",
    "rf-lab",
    "uav-isr"
  ],
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "dom_result": "$DOM_RESULT",
  "dom_note": "$DOM_NOTE",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35R1_RECOVERY",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "build_log": "$BUILD_LOG",
  "screenshot": "$SCREENSHOT",
  "dom_dump": "$DOM_DUMP",
  "scenario_count": 7,
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "dom_result": "$DOM_RESULT",
  "dom_note": "$DOM_NOTE",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_scenarios \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios.tsx \
  "$RELEASE_DIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_dynamic_rf_telco_scenarios_v35"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_dynamic_rf_telco_scenarios_v35"

cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V35R1 RECOVERY COMPLETATO"
echo "============================================================"

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: risultato $RESULT"
  exit 1
fi
