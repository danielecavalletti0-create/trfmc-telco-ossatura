#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RUNTIME_PROBE_AFTER_P1D_RESTORE_V1_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM_MISSION="$OUT/dom_mission_overview.txt"
DOM_RF="$OUT/dom_rf_physics.txt"
ERR_MISSION="$OUT/chrome_mission.stderr.log"
ERR_RF="$OUT/chrome_rf.stderr.log"
SCREEN_MISSION="$OUT/mission_overview_after_restore.png"
SCREEN_RF="$OUT/rf_physics_after_restore.png"
COUNTS="$OUT/runtime_marker_counts.tsv"

count_lit() {
  local lit="$1"
  local file="$2"
  if [ ! -f "$file" ]; then echo 0; return 0; fi
  awk -v lit="$lit" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_RUNTIME_PROBE_AFTER_P1D_RESTORE_V1"
echo "Read-only · verifica runtime dopo restore P1D"
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

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#rf-physics"
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
SCREEN_MISSION_RESULT="SKIPPED"
SCREEN_RF_RESULT="SKIPPED"

if [ -n "$BROWSER" ]; then
  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 \
    --virtual-time-budget=9000 --dump-dom \
    "http://127.0.0.1:5173/#mission-overview" > "$DOM_MISSION" 2> "$ERR_MISSION" \
    && DOM_MISSION_RESULT="PASS" || DOM_MISSION_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 \
    --virtual-time-budget=9000 --screenshot="$SCREEN_MISSION" \
    "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>> "$ERR_MISSION" \
    && SCREEN_MISSION_RESULT="PASS" || SCREEN_MISSION_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 \
    --virtual-time-budget=9000 --dump-dom \
    "http://127.0.0.1:5173/#rf-physics" > "$DOM_RF" 2> "$ERR_RF" \
    && DOM_RF_RESULT="PASS" || DOM_RF_RESULT="FAIL"

  "$BROWSER" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 \
    --virtual-time-budget=9000 --screenshot="$SCREEN_RF" \
    "http://127.0.0.1:5173/#rf-physics" >/dev/null 2>> "$ERR_RF" \
    && SCREEN_RF_RESULT="PASS" || SCREEN_RF_RESULT="FAIL"
else
  echo "NO_BROWSER" > "$DOM_MISSION"
  echo "NO_BROWSER" > "$DOM_RF"
  echo "NO_BROWSER" > "$ERR_MISSION"
  echo "NO_BROWSER" > "$ERR_RF"
fi

MISSION_P0B="$(count_lit 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_MISSION")"
MISSION_P0C="$(count_lit 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_MISSION")"
MISSION_P1B="$(count_lit 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_MISSION")"
MISSION_P1D="$(count_lit 'data-trfmc-p1d-route-isolation' "$DOM_MISSION")"

RF_P0B="$(count_lit 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_RF")"
RF_P0C="$(count_lit 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_RF")"
RF_P1B="$(count_lit 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_RF")"
RF_P1D="$(count_lit 'data-trfmc-p1d-route-isolation' "$DOM_RF")"

{
  echo -e "route\tmarker\tcount\texpected_after_restore"
  echo -e "mission-overview\tp0b_registry\t$MISSION_P0B\t>0"
  echo -e "mission-overview\tp0c_mission_content\t$MISSION_P0C\t>0"
  echo -e "mission-overview\tp1b_rf_physics\t$MISSION_P1B\t0"
  echo -e "mission-overview\tp1d_residual\t$MISSION_P1D\t0"
  echo -e "rf-physics\tp0b_registry\t$RF_P0B\tcurrent_baseline_may_be_>0"
  echo -e "rf-physics\tp0c_mission_content\t$RF_P0C\tcurrent_baseline_may_be_>0"
  echo -e "rf-physics\tp1b_rf_physics\t$RF_P1B\t>0"
  echo -e "rf-physics\tp1d_residual\t$RF_P1D\t0"
} | tee "$COUNTS" | column -t -s $'\t'

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

RESULT="PASS"
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$DOM_MISSION_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM_MISSION"; fi
if [ "$MISSION_P0B" = "0" ]; then RESULT="REVIEW_MISSION_P0B_MISSING"; fi
if [ "$MISSION_P0C" = "0" ]; then RESULT="REVIEW_MISSION_P0C_MISSING"; fi
if [ "$MISSION_P1D" != "0" ]; then RESULT="REVIEW_P1D_RESIDUAL"; fi
if [ "$RF_P1D" != "0" ]; then RESULT="REVIEW_P1D_RESIDUAL"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RUNTIME_PROBE_AFTER_P1D_RESTORE_V1",
  "mutation": false,
  "out": "$OUT",
  "http_tsv": "$HTTP",
  "runtime_marker_counts": "$COUNTS",
  "dom_mission": "$DOM_MISSION",
  "dom_rf": "$DOM_RF",
  "screen_mission": "$SCREEN_MISSION",
  "screen_rf": "$SCREEN_RF",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_mission_result": "$DOM_MISSION_RESULT",
  "dom_rf_result": "$DOM_RF_RESULT",
  "screenshot_mission_result": "$SCREEN_MISSION_RESULT",
  "screenshot_rf_result": "$SCREEN_RF_RESULT",
  "mission_p0b": $MISSION_P0B,
  "mission_p0c": $MISSION_P0C,
  "mission_p1b": $MISSION_P1B,
  "mission_p1d": $MISSION_P1D,
  "rf_p0b": $RF_P0B,
  "rf_p0c": $RF_P0C,
  "rf_p1b": $RF_P1B,
  "rf_p1d": $RF_P1D,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_runtime_probe_after_p1d_restore_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_RUNTIME_PROBE_AFTER_P1D_RESTORE_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
