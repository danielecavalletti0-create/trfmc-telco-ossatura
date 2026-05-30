#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FREEZE_PROXY_PASS_AND_VERIFY_BASELINE_V1_$TS"
FREEZE="$BASE/_archive/baselines/BASELINE_PROXY_PASS_P6A_SAFE_$TS"

mkdir -p "$OUT" "$FREEZE"/{src_app,src_portal_os,src_config,src_stores,quality}
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
API="$OUT/api_contract.tsv"
DOM="$OUT/dom_portal_os.txt"
SCREEN="$OUT/portal_os_1920x1080.png"
BUILDLOG="$OUT/npm_build.log"

echo "============================================================"
echo "TRFMC_FREEZE_PROXY_PASS_AND_VERIFY_BASELINE_V1"
echo "Freeze baseline buona + verifica runtime"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) FREEZE FILE CRITICI ==="

cp -a frontend/src/app "$FREEZE/src_app/"
cp -a frontend/src/portal-os "$FREEZE/src_portal_os/"
cp -a frontend/src/stores/rtStreamStore.ts "$FREEZE/src_stores/" 2>/dev/null || true
cp -a frontend/vite.config.* "$FREEZE/src_config/" 2>/dev/null || true

cp -a runtime/quality/latest_fix_vite_proxy_contract_v2_correct_root "$FREEZE/quality/proxy_v2" 2>/dev/null || true
cp -a runtime/quality/latest_fix_rtstreamstore_syntax_error_v1 "$FREEZE/quality/rtstream_fix" 2>/dev/null || true
cp -a runtime/quality/latest_p6a_activate_working_real_pages_dashboard_v1 "$FREEZE/quality/p6a" 2>/dev/null || true
cp -a runtime/quality/latest_deep_multi_agent_audit_v2_readonly "$FREEZE/quality/multi_agent_v2" 2>/dev/null || true

cat > "$FREEZE/BASELINE_README.md" <<BASELINE
# BASELINE PROXY PASS + P6A SAFE

Timestamp: $TS

Stato congelato:
- Vite proxy corretto nel root server.proxy.
- /trfmc-api/backend/api/health = JSON OK.
- /trfmc-api/bridge/api/health = JSON OK.
- rtStreamStore.ts corretto.
- P6A presente.
- P6B non deve essere riattivato.
- Prossimo sviluppo ammesso: P6D-LITE, dashboard filtrata/paginata.
BASELINE

echo "Freeze salvato in: $FREEZE"

echo
echo "=== 2) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG"

echo
echo "=== 3) HTTP ==="

cat > "$HTTP" <<HDR
url	status	bytes	hint	result
HDR

check_http() {
  url="$1"
  tmp="$(mktemp)"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
  python3 - "$tmp" <<'PY' >/tmp/trfmc_json_hint_freeze.$$ 2>/dev/null
import json,sys
try:
    json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    print("JSON")
except Exception:
    print("")
PY
  jh="$(cat /tmp/trfmc_json_hint_freeze.$$ 2>/dev/null)"
  rm -f /tmp/trfmc_json_hint_freeze.$$
  [ "$jh" = "JSON" ] && hint="JSON"
  result="OK"
  [ "$code" != "200" ] && result="NON_200"
  [ "$bytes" = "0" ] && result="ZERO_BYTES"
  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_http "http://127.0.0.1:5173/"
check_http "http://127.0.0.1:5173/#portal-os-preview"
check_http "http://127.0.0.1:8000/api/health"
check_http "http://127.0.0.1:4181/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/backend/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/bridge/api/health"
check_http "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html"

HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

echo
echo "=== 4) API JSON CONTRACT ==="

cat > "$API" <<HDR
name	url	status	json	html_fallback	result
HDR

api_contract() {
  name="$1"
  url="$2"
  raw="$OUT/api_${name}.body"
  code="$(curl -sS -L --max-time 8 -o "$raw" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"

  json_parse="$(python3 - "$raw" <<'PY' 2>/dev/null
import json,sys
try:
    json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    print("YES")
except Exception:
    print("NO")
PY
)"
  html_fallback="NO"
  grep -qi '<html\|<!doctype\|/@vite/client' "$raw" && html_fallback="YES"

  result="OK"
  [ "$code" != "200" ] && result="NON_200"
  [ "$json_parse" != "YES" ] && result="NOT_JSON"
  [ "$html_fallback" = "YES" ] && result="HTML_FALLBACK"

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$url" "$code" "$json_parse" "$html_fallback" "$result" | tee -a "$API"
}

api_contract "backend_direct" "http://127.0.0.1:8000/api/health"
api_contract "bridge_direct" "http://127.0.0.1:4181/api/health"
api_contract "proxy_backend" "http://127.0.0.1:5173/trfmc-api/backend/api/health"
api_contract "proxy_bridge" "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

API_FAILS="$(awk -F'\t' 'NR>1 && $6!="OK"{c++} END{print c+0}' "$API")"

echo
echo "=== 5) DOM PORTAL OS ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

if [ "$BUILD_RESULT" = "PASS" ] && [ -n "$CHROME_BIN" ]; then
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --dump-dom \
    "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
else
  echo "NO_CHROME_OR_BUILD_FAIL" > "$DOM"
fi

PORTAL_OS_COUNT="$(grep -o 'data-trfmc-portal-os-preview="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
P4G_COUNT="$(grep -o 'data-trfmc-p4g-route-registry="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
P6A_COUNT="$(grep -o 'data-trfmc-p6a-working-real-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
P6B_COUNT="$(grep -o 'data-trfmc-p6b-all-working-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WORKING_LINKS="$(grep -o 'data-trfmc-working-page-link=' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
V42_COUNT="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"

RESULT="PASS"
[ "$BUILD_RESULT" != "PASS" ] && RESULT="FAIL_BUILD"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$API_FAILS" != "0" ] && RESULT="FAIL_API"
[ "$DOM_RESULT" != "PASS" ] && RESULT="FAIL_DOM"
[ "$PORTAL_OS_COUNT" = "0" ] && RESULT="FAIL_PORTAL_OS"
[ "$P6A_COUNT" = "0" ] && RESULT="FAIL_P6A"
[ "$P6B_COUNT" != "0" ] && RESULT="FAIL_P6B_RESIDUE"
[ "$V42_COUNT" != "0" ] && RESULT="FAIL_V42_LEAK"
[ "$SCREENSHOT_RESULT" != "PASS" ] && RESULT="FAIL_SCREENSHOT"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FREEZE_PROXY_PASS_AND_VERIFY_BASELINE_V1",
  "mutation": false,
  "freeze": "$FREEZE",
  "build_result": "$BUILD_RESULT",
  "http_failures": $HTTP_FAILS,
  "api_failures": $API_FAILS,
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "portal_os_count": $PORTAL_OS_COUNT,
  "p4g_count": $P4G_COUNT,
  "p6a_count": $P6A_COUNT,
  "p6b_count": $P6B_COUNT,
  "working_links": $WORKING_LINKS,
  "v42_count": $V42_COUNT,
  "http_gate": "$HTTP",
  "api_contract": "$API",
  "build_log": "$BUILDLOG",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_freeze_proxy_pass_and_verify_baseline_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_FREEZE_PROXY_PASS_AND_VERIFY_BASELINE_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
