#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P1C_RF_PHYSICS_ROUTE_ISOLATION_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM_RF="$OUT/dom_rf_physics.txt"
DOM_MISSION="$OUT/dom_mission_overview.txt"
ERR_RF="$OUT/chrome_rf_physics.stderr.log"
ERR_MISSION="$OUT/chrome_mission_overview.stderr.log"
SCREEN_RF="$OUT/rf_physics_route_1920x1080.png"
SCREEN_MISSION="$OUT/mission_overview_route_1920x1080.png"
ROUTE_COUNTS="$OUT/route_isolation_counts.tsv"
PLAN="$OUT/TRFMC_P1C_ROUTE_ISOLATION_PLAN.md"

safe_count_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return 0
  fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_P1C_RF_PHYSICS_ROUTE_ISOLATION_AUDIT_READONLY"
echo "Read-only · route isolation audit · no source mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) HTTP GATE ==="

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
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

echo
echo "=== 2) DOM / SCREENSHOT READONLY ==="

DOM_RF_RESULT="SKIPPED"
DOM_MISSION_RESULT="SKIPPED"
SCREEN_RF_RESULT="SKIPPED"
SCREEN_MISSION_RESULT="SKIPPED"

BROWSER=""
if command -v google-chrome >/dev/null 2>&1; then
  BROWSER="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  BROWSER="chromium"
fi

if [ -n "$BROWSER" ]; then
  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --dump-dom \
    "http://127.0.0.1:5173/#rf-physics" > "$DOM_RF" 2> "$ERR_RF" && DOM_RF_RESULT="PASS" || DOM_RF_RESULT="FAIL"

  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --screenshot="$SCREEN_RF" \
    "http://127.0.0.1:5173/#rf-physics" >/dev/null 2>> "$ERR_RF" && SCREEN_RF_RESULT="PASS" || SCREEN_RF_RESULT="FAIL"

  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --dump-dom \
    "http://127.0.0.1:5173/#mission-overview" > "$DOM_MISSION" 2> "$ERR_MISSION" && DOM_MISSION_RESULT="PASS" || DOM_MISSION_RESULT="FAIL"

  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --screenshot="$SCREEN_MISSION" \
    "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>> "$ERR_MISSION" && SCREEN_MISSION_RESULT="PASS" || SCREEN_MISSION_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM_RF"
  echo "NO_CHROME_AVAILABLE" > "$DOM_MISSION"
  echo "NO_CHROME_AVAILABLE" > "$ERR_RF"
  echo "NO_CHROME_AVAILABLE" > "$ERR_MISSION"
fi

RF_P1B="$(safe_count_literal 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_RF")"
RF_P0B="$(safe_count_literal 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_RF")"
RF_P0C="$(safe_count_literal 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_RF")"
RF_MISSION_V49="$(safe_count_literal 'V49_SECTION_MISSION_OVERVIEW' "$DOM_RF")"
RF_ENGINEERING_ORCH="$(safe_count_literal 'Engineering Orchestrator' "$DOM_RF")"
RF_TOP_HEADER="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM_RF")"

MISSION_P1B="$(safe_count_literal 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_MISSION")"
MISSION_P0B="$(safe_count_literal 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_MISSION")"
MISSION_P0C="$(safe_count_literal 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_MISSION")"
MISSION_V49="$(safe_count_literal 'V49_SECTION_MISSION_OVERVIEW' "$DOM_MISSION")"

{
  echo -e "route\tmarker\tcount\tinterpretation"
  echo -e "rf-physics\tp1b_rf_physics\t$RF_P1B\tmust_be_present"
  echo -e "rf-physics\tp0b_registry\t$RF_P0B\tshould_be_0_or_shell_only_later"
  echo -e "rf-physics\tp0c_mission_content\t$RF_P0C\tshould_be_0_for_clean_domain_route"
  echo -e "rf-physics\tv49_mission_overview\t$RF_MISSION_V49\tshould_be_0_for_clean_domain_route"
  echo -e "rf-physics\tengineering_orchestrator\t$RF_ENGINEERING_ORCH\treview_layout_shell_weight"
  echo -e "rf-physics\ttop_telco_header\t$RF_TOP_HEADER\treview_global_shell_weight"
  echo -e "mission-overview\tp1b_rf_physics\t$MISSION_P1B\tshould_be_0_on_mission_route"
  echo -e "mission-overview\tp0b_registry\t$MISSION_P0B\tmust_be_present"
  echo -e "mission-overview\tp0c_mission_content\t$MISSION_P0C\tmust_be_present"
  echo -e "mission-overview\tv49_mission_overview\t$MISSION_V49\tmust_be_present"
} | tee "$ROUTE_COUNTS" | column -t -s $'\t'

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

ROUTE_ISOLATION="PASS"
if [ "$RF_P1B" = "0" ]; then ROUTE_ISOLATION="FAIL_RF_P1B_NOT_MOUNTED"; fi
if [ "$RF_P0C" != "0" ]; then ROUTE_ISOLATION="REVIEW_RF_ROUTE_CONTAINS_P0C"; fi
if [ "$RF_MISSION_V49" != "0" ]; then ROUTE_ISOLATION="REVIEW_RF_ROUTE_CONTAINS_MISSION_V49"; fi
if [ "$MISSION_P1B" != "0" ]; then ROUTE_ISOLATION="REVIEW_MISSION_ROUTE_CONTAINS_RF_DOMAIN"; fi

cat > "$PLAN" <<MD
# TRFMC P1C Route Isolation Plan

## Finding target

P1B is technically valid, but P1C checks whether \`#rf-physics\` is visually and architecturally isolated.

## Clean-route rule

For \`#rf-physics\`:
- P1B RF Physics must be present.
- P0C Mission Control content should not be present.
- V49 Mission Overview should not be present.
- P0B registry may later become a compact global nav, but should not dominate the domain route.

For \`#mission-overview\`:
- P0B and P0C must remain present.
- P1B RF Physics should not be present.

## If route isolation fails

Next mutation should be:

\`TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_V1\`

Required behavior:
- Mission route renders P0B/P0C Mission content.
- RF Physics route renders P1B domain content.
- No iframe.
- No public HTML runtime mount.
- No unsafe HTML injection.
- Build, HTTP, DOM, screenshot gates.
MD

RESULT="P1C_ROUTE_ISOLATION_AUDIT_READY"
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [[ "$ROUTE_ISOLATION" == REVIEW* || "$ROUTE_ISOLATION" == FAIL* ]]; then RESULT="$ROUTE_ISOLATION"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P1C_RF_PHYSICS_ROUTE_ISOLATION_AUDIT_READONLY",
  "mutation": false,
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "out": "$OUT",
  "http_tsv": "$HTTP",
  "route_counts": "$ROUTE_COUNTS",
  "dom_rf_physics": "$DOM_RF",
  "dom_mission_overview": "$DOM_MISSION",
  "screenshot_rf_physics": "$SCREEN_RF",
  "screenshot_mission_overview": "$SCREEN_MISSION",
  "plan": "$PLAN",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_rf_result": "$DOM_RF_RESULT",
  "dom_mission_result": "$DOM_MISSION_RESULT",
  "screenshot_rf_result": "$SCREEN_RF_RESULT",
  "screenshot_mission_result": "$SCREEN_MISSION_RESULT",
  "rf_route_p1b_marker": $RF_P1B,
  "rf_route_p0b_marker": $RF_P0B,
  "rf_route_p0c_marker": $RF_P0C,
  "rf_route_mission_v49_marker": $RF_MISSION_V49,
  "mission_route_p1b_marker": $MISSION_P1B,
  "mission_route_p0b_marker": $MISSION_P0B,
  "mission_route_p0c_marker": $MISSION_P0C,
  "route_isolation": "$ROUTE_ISOLATION",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1c_rf_physics_route_isolation_audit_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,180p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P1C_RF_PHYSICS_ROUTE_ISOLATION_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
