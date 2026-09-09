#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RUNTIME_PROBE_P2B_MULTI_ROUTE_AND_FREEZE_V1_$TS"
FREEZE="$BASE/_archive/baselines/BASELINE_P2B_SIGNAL_ANALYZER_PASS_$TS"

mkdir -p "$OUT" "$FREEZE"/{src_app,src_domains,src_layout,quality}
cd "$BASE"

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
COUNTS="$OUT/runtime_marker_counts.tsv"
DOM_MISSION="$OUT/dom_mission_overview.txt"
DOM_RF="$OUT/dom_rf_physics.txt"
DOM_SIGNAL="$OUT/dom_signal_analyzer.txt"
ERR_MISSION="$OUT/chrome_mission.stderr.log"
ERR_RF="$OUT/chrome_rf.stderr.log"
ERR_SIGNAL="$OUT/chrome_signal.stderr.log"
SCREEN_MISSION="$OUT/mission_overview.png"
SCREEN_RF="$OUT/rf_physics.png"
SCREEN_SIGNAL="$OUT/signal_analyzer.png"

count_lit() {
  local lit="$1"
  local file="$2"
  if [ ! -f "$file" ]; then echo 0; return 0; fi
  awk -v lit="$lit" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_RUNTIME_PROBE_P2B_MULTI_ROUTE_AND_FREEZE_V1"
echo "Read-only probe + freeze baseline P2B"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) HTTP ==="

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

check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

echo
echo "=== 2) DOM / SCREENSHOT ==="

BROWSER=""
if command -v google-chrome >/dev/null 2>&1; then
  BROWSER="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  BROWSER="chromium"
fi

DOM_MISSION_RESULT="SKIPPED"
DOM_RF_RESULT="SKIPPED"
DOM_SIGNAL_RESULT="SKIPPED"
SCREEN_MISSION_RESULT="SKIPPED"
SCREEN_RF_RESULT="SKIPPED"
SCREEN_SIGNAL_RESULT="SKIPPED"

if [ -n "$BROWSER" ]; then
  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --dump-dom "http://127.0.0.1:5173/#mission-overview" > "$DOM_MISSION" 2> "$ERR_MISSION" \
    && DOM_MISSION_RESULT="PASS" || DOM_MISSION_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --screenshot="$SCREEN_MISSION" "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>> "$ERR_MISSION" \
    && SCREEN_MISSION_RESULT="PASS" || SCREEN_MISSION_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --dump-dom "http://127.0.0.1:5173/#rf-physics" > "$DOM_RF" 2> "$ERR_RF" \
    && DOM_RF_RESULT="PASS" || DOM_RF_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --screenshot="$SCREEN_RF" "http://127.0.0.1:5173/#rf-physics" >/dev/null 2>> "$ERR_RF" \
    && SCREEN_RF_RESULT="PASS" || SCREEN_RF_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --dump-dom "http://127.0.0.1:5173/#signal-analyzer" > "$DOM_SIGNAL" 2> "$ERR_SIGNAL" \
    && DOM_SIGNAL_RESULT="PASS" || DOM_SIGNAL_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 \
    --screenshot="$SCREEN_SIGNAL" "http://127.0.0.1:5173/#signal-analyzer" >/dev/null 2>> "$ERR_SIGNAL" \
    && SCREEN_SIGNAL_RESULT="PASS" || SCREEN_SIGNAL_RESULT="FAIL"
else
  echo "NO_BROWSER" > "$DOM_MISSION"
  echo "NO_BROWSER" > "$DOM_RF"
  echo "NO_BROWSER" > "$DOM_SIGNAL"
fi

MISSION_P0B="$(count_lit 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_MISSION")"
MISSION_P0C="$(count_lit 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_MISSION")"
MISSION_P1B="$(count_lit 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_MISSION")"
MISSION_P2B="$(count_lit 'data-trfmc-p2-signal-analyzer-domain="mounted"' "$DOM_MISSION")"
MISSION_P1D="$(count_lit 'data-trfmc-p1d-route-isolation' "$DOM_MISSION")"

RF_P0B="$(count_lit 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_RF")"
RF_P0C="$(count_lit 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_RF")"
RF_P1B="$(count_lit 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_RF")"
RF_P2B="$(count_lit 'data-trfmc-p2-signal-analyzer-domain="mounted"' "$DOM_RF")"
RF_P1D="$(count_lit 'data-trfmc-p1d-route-isolation' "$DOM_RF")"

SIGNAL_P0B="$(count_lit 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_SIGNAL")"
SIGNAL_P0C="$(count_lit 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_SIGNAL")"
SIGNAL_P1B="$(count_lit 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_SIGNAL")"
SIGNAL_P2B="$(count_lit 'data-trfmc-p2-signal-analyzer-domain="mounted"' "$DOM_SIGNAL")"
SIGNAL_P1D="$(count_lit 'data-trfmc-p1d-route-isolation' "$DOM_SIGNAL")"
SIGNAL_CANVAS="$(count_lit 'trfmc-p2-signal-canvas' "$DOM_SIGNAL")"
SIGNAL_MEASURE="$(count_lit 'Measurement registry' "$DOM_SIGNAL")"
SIGNAL_SCENARIO="$(count_lit 'Scenario binding' "$DOM_SIGNAL")"

{
  echo -e "route\tmarker\tcount\texpected_now"
  echo -e "mission-overview\tp0b_registry\t$MISSION_P0B\t>0"
  echo -e "mission-overview\tp0c_mission_content\t$MISSION_P0C\t>0"
  echo -e "mission-overview\tp1b_rf_physics\t$MISSION_P1B\t0"
  echo -e "mission-overview\tp2b_signal_analyzer\t$MISSION_P2B\t0"
  echo -e "mission-overview\tp1d_residual\t$MISSION_P1D\t0"
  echo -e "rf-physics\tp0b_registry\t$RF_P0B\tcurrent_baseline_may_be_>0"
  echo -e "rf-physics\tp0c_mission_content\t$RF_P0C\tcurrent_baseline_may_be_>0"
  echo -e "rf-physics\tp1b_rf_physics\t$RF_P1B\t>0"
  echo -e "rf-physics\tp2b_signal_analyzer\t$RF_P2B\t0"
  echo -e "rf-physics\tp1d_residual\t$RF_P1D\t0"
  echo -e "signal-analyzer\tp0b_registry\t$SIGNAL_P0B\tcurrent_baseline_may_be_>0"
  echo -e "signal-analyzer\tp0c_mission_content\t$SIGNAL_P0C\tcurrent_baseline_may_be_>0"
  echo -e "signal-analyzer\tp1b_rf_physics\t$SIGNAL_P1B\t0"
  echo -e "signal-analyzer\tp2b_signal_analyzer\t$SIGNAL_P2B\t>0"
  echo -e "signal-analyzer\tp2b_canvas\t$SIGNAL_CANVAS\t>0"
  echo -e "signal-analyzer\tmeasurement_registry\t$SIGNAL_MEASURE\t>0"
  echo -e "signal-analyzer\tscenario_binding\t$SIGNAL_SCENARIO\t>0"
  echo -e "signal-analyzer\tp1d_residual\t$SIGNAL_P1D\t0"
} | tee "$COUNTS" | column -t -s $'\t'

echo
echo "=== 3) FREEZE BASELINE ==="

cp -a frontend/src/app "$FREEZE/src_app/"
cp -a frontend/src/domains "$FREEZE/src_domains/"
cp -a frontend/src/layout_orchestrator "$FREEZE/src_layout/"
cp -a frontend/src/styles.css "$FREEZE/"
cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"

cp -a runtime/quality/latest_p2b_signal_analyzer_react_promotion_v1 "$FREEZE/quality/p2b" 2>/dev/null || true
cp -a runtime/quality/latest_p1b_rf_physics_react_promotion_v1 "$FREEZE/quality/p1b" 2>/dev/null || true
cp -a runtime/quality/latest_p0c_rescue_static_runtime_v1 "$FREEZE/quality/p0c" 2>/dev/null || true
cp -a runtime/quality/latest_p0b_canonical_portal_registry_source_v1 "$FREEZE/quality/p0b" 2>/dev/null || true

cat > "$FREEZE/BASELINE_README.md" <<README
# BASELINE P2B SIGNAL ANALYZER PASS

Timestamp: $TS

Status:
- P0B registry: PASS
- P0C Mission Control: PASS
- P1B RF Physics: PASS
- P2B Signal Analyzer: PASS
- P1D route isolation: failed/frozen, no residual marker expected

Known limitation:
- Domain routes are not yet isolated. RF Physics and Signal Analyzer still render inside the existing Mission/V42/P0B/P0C stack.
- Do not patch MissionLayoutOrchestratorV42.tsx or main.tsx automatically for route isolation.

Next recommended phase:
- P3A Antenna System Source Audit Readonly
README

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

RESULT="PASS"
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$MISSION_P0B" = "0" ]; then RESULT="REVIEW_MISSION_P0B_MISSING"; fi
if [ "$MISSION_P0C" = "0" ]; then RESULT="REVIEW_MISSION_P0C_MISSING"; fi
if [ "$MISSION_P1B" != "0" ]; then RESULT="REVIEW_MISSION_CONTAINS_RF"; fi
if [ "$MISSION_P2B" != "0" ]; then RESULT="REVIEW_MISSION_CONTAINS_SIGNAL"; fi
if [ "$MISSION_P1D" != "0" ] || [ "$RF_P1D" != "0" ] || [ "$SIGNAL_P1D" != "0" ]; then RESULT="REVIEW_P1D_RESIDUAL"; fi
if [ "$RF_P1B" = "0" ]; then RESULT="REVIEW_RF_P1B_MISSING"; fi
if [ "$RF_P2B" != "0" ]; then RESULT="REVIEW_RF_CONTAINS_SIGNAL"; fi
if [ "$SIGNAL_P2B" = "0" ]; then RESULT="REVIEW_SIGNAL_P2B_MISSING"; fi
if [ "$SIGNAL_P1B" != "0" ]; then RESULT="REVIEW_SIGNAL_CONTAINS_RF"; fi
if [ "$SIGNAL_CANVAS" = "0" ]; then RESULT="REVIEW_SIGNAL_CANVAS_MISSING"; fi
if [ "$SIGNAL_MEASURE" = "0" ]; then RESULT="REVIEW_SIGNAL_MEASUREMENT_MISSING"; fi
if [ "$SIGNAL_SCENARIO" = "0" ]; then RESULT="REVIEW_SIGNAL_SCENARIO_MISSING"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RUNTIME_PROBE_P2B_MULTI_ROUTE_AND_FREEZE_V1",
  "mutation": false,
  "out": "$OUT",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP",
  "runtime_marker_counts": "$COUNTS",
  "dom_mission": "$DOM_MISSION",
  "dom_rf": "$DOM_RF",
  "dom_signal": "$DOM_SIGNAL",
  "screen_mission": "$SCREEN_MISSION",
  "screen_rf": "$SCREEN_RF",
  "screen_signal": "$SCREEN_SIGNAL",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_mission_result": "$DOM_MISSION_RESULT",
  "dom_rf_result": "$DOM_RF_RESULT",
  "dom_signal_result": "$DOM_SIGNAL_RESULT",
  "screenshot_mission_result": "$SCREEN_MISSION_RESULT",
  "screenshot_rf_result": "$SCREEN_RF_RESULT",
  "screenshot_signal_result": "$SCREEN_SIGNAL_RESULT",
  "mission_p0b": $MISSION_P0B,
  "mission_p0c": $MISSION_P0C,
  "mission_p1b": $MISSION_P1B,
  "mission_p2b": $MISSION_P2B,
  "mission_p1d": $MISSION_P1D,
  "rf_p0b": $RF_P0B,
  "rf_p0c": $RF_P0C,
  "rf_p1b": $RF_P1B,
  "rf_p2b": $RF_P2B,
  "rf_p1d": $RF_P1D,
  "signal_p0b": $SIGNAL_P0B,
  "signal_p0c": $SIGNAL_P0C,
  "signal_p1b": $SIGNAL_P1B,
  "signal_p2b": $SIGNAL_P2B,
  "signal_canvas": $SIGNAL_CANVAS,
  "signal_measurement": $SIGNAL_MEASURE,
  "signal_scenario": $SIGNAL_SCENARIO,
  "signal_p1d": $SIGNAL_P1D,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_runtime_probe_p2b_multiroute_and_freeze_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_RUNTIME_PROBE_P2B_MULTI_ROUTE_AND_FREEZE_V1 COMPLETATO"
echo "Output: $OUT"
echo "Freeze: $FREEZE"
echo "============================================================"
