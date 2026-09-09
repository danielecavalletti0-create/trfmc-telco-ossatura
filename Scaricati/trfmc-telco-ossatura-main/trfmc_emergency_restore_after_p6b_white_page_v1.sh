#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_EMERGENCY_RESTORE_AFTER_P6B_WHITE_PAGE_V1_$TS"
mkdir -p "$OUT"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_after_restore.txt"
SCREEN="$OUT/screen_after_restore_1920x1080.png"
BUILDLOG="$OUT/npm_build_after_restore.log"
VITELOG="$OUT/vite_restart_5173.log"

echo "============================================================"
echo "TRFMC_EMERGENCY_RESTORE_AFTER_P6B_WHITE_PAGE_V1"
echo "Rollback P6B fallito + restart Vite + DOM gate"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) TROVO RESTORE P6B ==="

RESTORE_P6B=""
if [ -f runtime/quality/latest_p6b_expose_all_working_pages_dashboard_v1/summary.json ]; then
  RESTORE_P6B="$(python3 - <<'PY'
import json
from pathlib import Path
p = Path("runtime/quality/latest_p6b_expose_all_working_pages_dashboard_v1/summary.json")
try:
    print(json.loads(p.read_text()).get("restore_script",""))
except Exception:
    print("")
PY
)"
fi

echo "RESTORE_P6B=$RESTORE_P6B"

if [ -n "$RESTORE_P6B" ] && [ -f "$RESTORE_P6B" ]; then
  echo "Eseguo restore P6B..."
  bash "$RESTORE_P6B"
  RESTORE_RESULT="RESTORED_P6B"
else
  echo "Restore P6B non trovato: provo ripristino da baseline P6A PASS"
  LATEST_P6A_FREEZE="$(find _archive/baselines -maxdepth 1 -type d -name 'BASELINE_P6A_WORKING_REAL_PAGES_DASHBOARD_PASS_*' | sort | tail -n 1)"
  echo "LATEST_P6A_FREEZE=$LATEST_P6A_FREEZE"

  if [ -n "$LATEST_P6A_FREEZE" ] && [ -d "$LATEST_P6A_FREEZE/portal-os" ]; then
    rm -rf frontend/src/portal-os
    cp -a "$LATEST_P6A_FREEZE/portal-os" frontend/src/portal-os
    RESTORE_RESULT="RESTORED_FROM_P6A_FREEZE"
  else
    RESTORE_RESULT="NO_RESTORE_AVAILABLE"
  fi
fi

echo "RESTORE_RESULT=$RESTORE_RESULT"

echo
echo "=== 2) BUILD DOPO RESTORE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG"

echo
echo "=== 3) STOP/RESTART VITE 5173 ==="

PID_5173="$(ss -ltnp 2>/dev/null | awk '/:5173/ {print $NF}' | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | head -n 1)"
echo "PID_5173=${PID_5173:-NONE}"

if [ -n "$PID_5173" ]; then
  echo "Fermo Vite PID=$PID_5173"
  kill "$PID_5173"
  sleep 2
fi

cd "$BASE/frontend"
nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$VITELOG" 2>&1 &
VITE_PID="$!"
cd "$BASE"

sleep 5

echo
echo "=== 4) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  url="$1"
  tmp="$(mktemp)"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  cls="OK"
  if [ "$code" != "200" ]; then cls="NON_200"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html"
check_url "http://127.0.0.1:5173/trfmc_domain_registry_v1.html"

HTTP_FAILS="$(awk -F'\t' 'NR>1 && $4!="OK"{c++} END{print c+0}' "$HTTP")"

echo
echo "=== 5) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

if [ -n "$CHROME_BIN" ] && [ "$BUILD_RESULT" = "PASS" ]; then
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
P6A_COUNT="$(grep -o 'data-trfmc-p6a-working-real-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
P6B_COUNT="$(grep -o 'data-trfmc-p6b-all-working-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WORKING_SECTION_COUNT="$(grep -o 'data-trfmc-working-real-pages="active"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
V42_COUNT="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"

RESULT="PASS"
if [ "$RESTORE_RESULT" = "NO_RESTORE_AVAILABLE" ]; then RESULT="REVIEW_NO_RESTORE"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD_STILL_FAILS"; fi
if [ "$HTTP_FAILS" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$PORTAL_OS_COUNT" = "0" ]; then RESULT="REVIEW_PORTAL_OS_NOT_RENDERED"; fi
if [ "$V42_COUNT" != "0" ]; then RESULT="REVIEW_V42_LEAK"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_EMERGENCY_RESTORE_AFTER_P6B_WHITE_PAGE_V1",
  "mutation": "rollback_failed_p6b",
  "restore_result": "$RESTORE_RESULT",
  "restore_p6b": "$RESTORE_P6B",
  "vite_pid": "$VITE_PID",
  "build_result": "$BUILD_RESULT",
  "build_log": "$BUILDLOG",
  "vite_log": "$VITELOG",
  "http_gate": "$HTTP",
  "http_failures": $HTTP_FAILS,
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "portal_os_count": $PORTAL_OS_COUNT,
  "p6a_count": $P6A_COUNT,
  "p6b_count": $P6B_COUNT,
  "working_section_count": $WORKING_SECTION_COUNT,
  "v42_count": $V42_COUNT,
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_emergency_restore_after_p6b_white_page_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_EMERGENCY_RESTORE_AFTER_P6B_WHITE_PAGE_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
