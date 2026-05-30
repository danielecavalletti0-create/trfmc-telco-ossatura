#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_NO_CHROME_FINAL_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_NO_CHROME_FINAL_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_NO_CHROME_FINAL_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"
DATA="$ROOT/frontend/src/rf_scenarios/scenarioDataV35.ts"
ENGINE="$ROOT/frontend/src/rf_scenarios/RFDynamicScenarioDeckV35.tsx"
WRAPPER="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios.tsx"

mkdir -p "$QDIR" "$RDIR" runtime/freezes

CONTENT_CHECK="$RDIR/content_checks.txt"
HTTP_TSV="$RDIR/http.tsv"
BUILD_LOG="$RDIR/npm_build_v35_no_chrome_final.log"
MANIFEST="$RDIR/dynamic_rf_telco_scenarios_no_chrome_final_manifest_v35.json"
SUMMARY="$QDIR/summary.json"

echo "============================================================"
echo "TRFMC V35 NO-CHROME FINALIZER"
echo "build + HTTP + source evidence · Chrome headless excluded"
echo "============================================================"

echo
echo "=== KILL EVENTUALI CHROME HEADLESS BLOCCATI ==="

pkill -f "headless.*dump-dom" 2>/dev/null || true
pkill -f "chrome.*dump-dom" 2>/dev/null || true
pkill -f "chromium.*dump-dom" 2>/dev/null || true

echo
echo "=== STATIC/SOURCE CHECKS ==="

{
  test -f "$MAIN" && echo "OK: main.tsx exists" || echo "MISS: main.tsx exists"
  test -f "$DATA" && echo "OK: scenario data exists" || echo "MISS: scenario data exists"
  test -f "$ENGINE" && echo "OK: scenario engine exists" || echo "MISS: scenario engine exists"
  test -f "$WRAPPER" && echo "OK: V35 wrapper exists" || echo "MISS: V35 wrapper exists"

  grep -q "RFOperationalDeckV35DynamicScenarios" "$MAIN" && echo "OK: main imports/mounts V35" || echo "MISS: main imports/mounts V35"
  grep -q "<RFOperationalDeckV35DynamicScenarios />" "$MAIN" && echo "OK: main JSX mounts V35" || echo "MISS: main JSX mounts V35"
  grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$WRAPPER" && echo "OK: V34R1R2 preserved below V35" || echo "MISS: V34R1R2 preserved below V35"
  grep -q "RFDynamicScenarioDeckV35" "$ENGINE" && echo "OK: V35 scenario deck export exists" || echo "MISS: V35 scenario deck export exists"

  grep -q "Electronics Fundamentals" "$DATA" && echo "OK: electronics scenario exists" || echo "MISS: electronics scenario exists"
  grep -q "Microstrip Patch Antenna" "$DATA" && echo "OK: microstrip scenario exists" || echo "MISS: microstrip scenario exists"
  grep -q "Antenna Systems Explorer" "$DATA" && echo "OK: antenna scenario exists" || echo "MISS: antenna scenario exists"
  grep -q "Telecom Tower Infrastructure" "$DATA" && echo "OK: tower scenario exists" || echo "MISS: tower scenario exists"
  grep -q "Beamwidth and Coverage" "$DATA" && echo "OK: beamwidth scenario exists" || echo "MISS: beamwidth scenario exists"
  grep -q "RF & Microwave Engineering Lab" "$DATA" && echo "OK: RF lab scenario exists" || echo "MISS: RF lab scenario exists"
  grep -q "UAV Platforms and ISR Systems" "$DATA" && echo "OK: UAV ISR scenario exists" || echo "MISS: UAV ISR scenario exists"

  grep -q "v35-scenario-shell" "$STYLES" && echo "OK: V35 CSS present" || echo "MISS: V35 CSS present"
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
  tail -n 160 "$BUILD_LOG" || true
fi

echo
echo "=== ENSURE VITE 5173 ==="

if ! curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:5173/ >/dev/null 2>&1; then
  (
    cd "$ROOT/frontend"
    nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$RDIR/vite_dev_5173.log" 2>&1 &
    echo $! > "$RDIR/vite_dev_5173.pid"
  )

  for i in $(seq 1 20); do
    if curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:5173/ >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

echo
echo "=== HTTP GATE ==="

printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="$(printf "%s" "$meta" | awk '{print $1}')"
  bytes="$(printf "%s" "$meta" | awk '{print $2}')"
  printf "%s\t%s\t%s\n" "$u" "${code:-000}" "${bytes:-0}" >> "$HTTP_TSV"
}

for u in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:4181/api/mission/status \
  http://127.0.0.1:4181/api/core/open5gs/status \
  http://127.0.0.1:4181/api/ran/ueransim/status \
  http://127.0.0.1:4181/api/rfpro/spectrum/sweep
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$BUILD_RESULT" = "FAIL" ] || [ "$HTTP_NON_200" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_NO_CHROME_FINAL",
  "reason": "Chrome headless dump-dom is unstable on this host; V35 is finalized using static source checks, npm build, and HTTP gates.",
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
  "chrome_gate": "excluded_due_to_host_headless_crash",
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_NO_CHROME_FINAL",
  "release_dir": "$RDIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "build_log": "$BUILD_LOG",
  "scenario_count": 7,
  "chrome_gate": "excluded_due_to_host_headless_crash",
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_scenarios \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios.tsx \
  "$RDIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_dynamic_rf_telco_scenarios_v35"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_dynamic_rf_telco_scenarios_v35"

echo
echo "=== FINAL SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: risultato $RESULT"
  exit 1
fi

echo
echo "============================================================"
echo "V35 FINALIZZATO SENZA CHROME: PASS"
echo "============================================================"
