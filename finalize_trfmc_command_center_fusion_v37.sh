#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_COMMAND_CENTER_FUSION_V37_FINAL_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_COMMAND_CENTER_FUSION_V37_FINAL_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_COMMAND_CENTER_FUSION_V37_FINAL_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"
CMD_DATA="$ROOT/frontend/src/command_center/commandCenterDataV37.ts"
CMD_COMPONENT="$ROOT/frontend/src/command_center/CommandCenterFusionV37.tsx"
WRAPPER="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV37CommandCenterFusion.tsx"

CONTENT_CHECK="$RDIR/content_checks.txt"
HTTP_TSV="$RDIR/http.tsv"
BUILD_LOG="$RDIR/npm_build_v37_final.log"

mkdir -p "$QDIR" "$RDIR" runtime/freezes

echo "============================================================"
echo "TRFMC COMMAND CENTER FUSION V37 FINALIZER"
echo "source gate · build gate · HTTP gate · evidence close"
echo "============================================================"

echo
echo "=== STATIC/SOURCE CHECKS ==="

{
  test -f "$MAIN" && echo "OK: main.tsx exists" || echo "MISS: main.tsx exists"
  test -f "$STYLES" && echo "OK: styles.css exists" || echo "MISS: styles.css exists"
  test -f "$CMD_DATA" && echo "OK: commandCenterDataV37.ts exists" || echo "MISS: commandCenterDataV37.ts exists"
  test -f "$CMD_COMPONENT" && echo "OK: CommandCenterFusionV37.tsx exists" || echo "MISS: CommandCenterFusionV37.tsx exists"
  test -f "$WRAPPER" && echo "OK: RFOperationalDeckV37CommandCenterFusion.tsx exists" || echo "MISS: RFOperationalDeckV37CommandCenterFusion.tsx exists"

  grep -q "RFOperationalDeckV37CommandCenterFusion" "$MAIN" && echo "OK: main imports/mounts V37" || echo "MISS: main imports/mounts V37"
  grep -q "<RFOperationalDeckV37CommandCenterFusion />" "$MAIN" && echo "OK: main JSX mounts V37" || echo "MISS: main JSX mounts V37"

  grep -q "CommandCenterFusionV37" "$WRAPPER" && echo "OK: wrapper mounts CommandCenterFusionV37" || echo "MISS: wrapper mounts CommandCenterFusionV37"
  grep -q "RFOperationalDeckV36VisualScenarioRuntime" "$WRAPPER" && echo "OK: V36 preserved below V37" || echo "MISS: V36 preserved below V37"

  grep -q "Mission Control" "$CMD_DATA" && echo "OK: Mission Control tile exists" || echo "MISS: Mission Control tile exists"
  grep -q "5G Core Network" "$CMD_DATA" && echo "OK: 5G Core tile exists" || echo "MISS: 5G Core tile exists"
  grep -q "RAN / UERANSIM" "$CMD_DATA" && echo "OK: RAN tile exists" || echo "MISS: RAN tile exists"
  grep -q "RF Spectrum / Signal Workbench" "$CMD_DATA" && echo "OK: RF Spectrum tile exists" || echo "MISS: RF Spectrum tile exists"
  grep -q "SOC/NOC Correlation" "$CMD_DATA" && echo "OK: SOC/NOC tile exists" || echo "MISS: SOC/NOC tile exists"
  grep -q "Dynamic RF/Telco Scenarios" "$CMD_DATA" && echo "OK: dynamic scenarios tile exists" || echo "MISS: dynamic scenarios tile exists"

  grep -qi "<iframe" "$CMD_COMPONENT" && echo "MISS: iframe present in React fusion component" || echo "OK: no iframe in React fusion component"
  grep -q "fetchLiveContract" "$CMD_COMPONENT" && echo "OK: live contract fetch used" || echo "MISS: live contract fetch used"
  grep -q "v37-command-shell" "$STYLES" && echo "OK: V37 CSS present" || echo "MISS: V37 CSS present"
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
  http://127.0.0.1:4181/api/rfpro/spectrum/sweep \
  http://127.0.0.1:4181/api/rfpro/bandplan \
  http://127.0.0.1:4181/api/soc-noc/correlation/demo
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

echo
echo "=== MANIFEST / SUMMARY ==="

MANIFEST="$RDIR/command_center_fusion_final_manifest_v37.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_COMMAND_CENTER_FUSION_V37_FINAL",
  "strategy": "validate_native_react_command_center_above_v36_no_iframe",
  "frontend_mutation": false,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "active_mount": "RFOperationalDeckV37CommandCenterFusion",
  "preserves": "RFOperationalDeckV36VisualScenarioRuntime",
  "legacy_command_center": "frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html",
  "legacy_mode": "reference_only_no_iframe",
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
  "operation": "TRFMC_COMMAND_CENTER_FUSION_V37_FINAL",
  "release_dir": "$RDIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "build_log": "$BUILD_LOG",
  "active_mount": "RFOperationalDeckV37CommandCenterFusion",
  "preserves": "RFOperationalDeckV36VisualScenarioRuntime",
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
  frontend/src/command_center \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV37CommandCenterFusion.tsx \
  "$RDIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_command_center_fusion_v37"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_command_center_fusion_v37"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: V37 result=$RESULT"
  exit 1
fi

echo
echo "============================================================"
echo "V37 COMMAND CENTER FUSION FINALIZZATO IN PASS"
echo "============================================================"
