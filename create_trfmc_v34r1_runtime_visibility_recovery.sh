#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_NATIVE_RF_BRIDGE_READINESS_RUNTIME_VISIBILITY_V34R1R2_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_NATIVE_RF_BRIDGE_READINESS_RUNTIME_VISIBILITY_V34R1R2_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_NATIVE_RF_BRIDGE_READINESS_RUNTIME_VISIBILITY_V34R1R2_$TS.tar.gz"

FRONTEND="$ROOT/frontend"
MAIN="$ROOT/frontend/src/app/main.tsx"
ACTIVE_WRAPPER="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV34R1NativeBridgeVisible.tsx"
STRIP="$ROOT/frontend/src/rf_instruments/telemetry/RFNativeLiveReadinessStripV34R1.tsx"
TARGET="$ROOT/frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx"
BASE="$ROOT/frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9Base.tsx"

URL_DEV="http://127.0.0.1:5173/"
DOM_BEFORE="$RELEASE_DIR/dom_before_active_mount.html"
DOM_AFTER="$RELEASE_DIR/dom_after_active_mount.html"
SCREENSHOT="$RELEASE_DIR/trfmc_v34r1r2_runtime.png"
CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"
HTTP_TSV="$RELEASE_DIR/http.tsv"

echo "============================================================"
echo "TRFMC V34R1R2 RUNTIME VISIBILITY RECOVERY"
echo "restart Vite · DOM gate · conditional active mount · rollback"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$TARGET" || { echo "ERRORE: RFBridgeReadinessV9.tsx mancante"; exit 1; }
test -f "$BASE" || { echo "ERRORE: RFBridgeReadinessV9Base.tsx mancante"; exit 1; }
test -f "$STRIP" || { echo "ERRORE: RFNativeLiveReadinessStripV34R1.tsx mancante"; exit 1; }

test -f "$ROOT/runtime/quality/latest_native_rf_bridge_readiness_binding_v34r1/summary.json" || {
  echo "ERRORE: V34R1 summary mancante"
  exit 1
}

grep -q "RFNativeLiveReadinessStripV34R1" "$TARGET" || {
  echo "ERRORE: target V34R1 non contiene la strip"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/core/open5gs/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: backend API 4181 non corretta"
  exit 1
}

echo "OK: V34R1 patch presente, API 4181 live"

echo
echo "=== FIND CHROME ==="

CHROME_BIN=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME_BIN="$(command -v "$c")"
    break
  fi
done

if [ -z "$CHROME_BIN" ]; then
  echo "ERRORE: Chrome/Chromium non trovato"
  exit 1
fi

echo "Chrome: $CHROME_BIN"

echo
echo "=== BACKUP CURRENT STATE ==="

cp "$MAIN" "$RELEASE_DIR/main.tsx.before_v34r1r2_$TS"

if [ -f "$ACTIVE_WRAPPER" ]; then
  cp "$ACTIVE_WRAPPER" "$RELEASE_DIR/RFOperationalDeckV34R1NativeBridgeVisible.tsx.before_v34r1r2_$TS"
fi

PRE_FREEZE="$ROOT/runtime/freezes/TRFMC_BEFORE_V34R1R2_RUNTIME_VISIBILITY_$TS.tar.gz"

tar -czf "$PRE_FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/rf_instruments/instruments \
  frontend/src/rf_instruments/telemetry \
  2>/dev/null || true

echo "Pre-freeze: $PRE_FREEZE"

echo
echo "=== FORCE RESTART VITE DEV 5173 ==="

pkill -f "vite.*5173" 2>/dev/null || true
pkill -f "vite --host 127.0.0.1 --port 5173" 2>/dev/null || true
sleep 2

VITE_LOG="$RELEASE_DIR/vite_dev_5173.log"

(
  cd "$FRONTEND"
  nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$VITE_LOG" 2>&1 &
  echo $! > "$RELEASE_DIR/vite_dev_5173.pid"
)

for i in $(seq 1 25); do
  if curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null 2>&1; then
    echo "OK: Vite dev attivo su $URL_DEV"
    break
  fi
  sleep 1
done

curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null || {
  echo "ERRORE: Vite dev non raggiungibile"
  tail -n 160 "$VITE_LOG" || true
  exit 1
}

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
  "$URL_DEV" \
  "http://127.0.0.1:4181/api/mission/status" \
  "http://127.0.0.1:4181/api/core/open5gs/status" \
  "http://127.0.0.1:4181/api/ran/ueransim/status" \
  "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

echo
echo "=== DOM GATE BEFORE CONDITIONAL ACTIVE MOUNT ==="

"$CHROME_BIN" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --window-size=1920,1800 \
  --virtual-time-budget=12000 \
  --dump-dom \
  "$URL_DEV" > "$DOM_BEFORE" 2>"$RELEASE_DIR/chrome_dom_before.stderr" || {
    echo "ERRORE: Chrome dump-dom before fallito"
    cat "$RELEASE_DIR/chrome_dom_before.stderr" || true
    exit 1
  }

if grep -q "V34R1 NATIVE RF PANEL BINDING" "$DOM_BEFORE"; then
  echo "OK: marker V34R1 già visibile dopo restart Vite"
  ACTIVE_MOUNT_APPLIED=false
  DOM_FINAL="$DOM_BEFORE"
else
  echo "Marker V34R1 non visibile dopo restart. Applico active mount wrapper controllato."
  ACTIVE_MOUNT_APPLIED=true

  cat > "$ACTIVE_WRAPPER" <<'TSX'
import { RFOperationalDeckV32R1LiveContracts } from './RFOperationalDeckV32R1LiveContracts'
import { RFNativeLiveReadinessStripV34R1 } from '../telemetry/RFNativeLiveReadinessStripV34R1'

export function RFOperationalDeckV34R1NativeBridgeVisible() {
  return (
    <>
      <RFNativeLiveReadinessStripV34R1 />
      <RFOperationalDeckV32R1LiveContracts />
    </>
  )
}
TSX

  python3 - "$MAIN" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

old_import = "import { RFOperationalDeckV32R1LiveContracts } from '../rf_instruments/instruments/RFOperationalDeckV32R1LiveContracts'"
new_import = "import { RFOperationalDeckV34R1NativeBridgeVisible } from '../rf_instruments/instruments/RFOperationalDeckV34R1NativeBridgeVisible'"

if new_import not in txt:
    if old_import not in txt:
        raise SystemExit("ERRORE: import V32R1 non trovato in main.tsx")
    txt = txt.replace(old_import, new_import, 1)

txt = txt.replace("<RFOperationalDeckV32R1LiveContracts />", "<RFOperationalDeckV34R1NativeBridgeVisible />")

p.write_text(txt, encoding="utf-8")
print("OK: main.tsx patched to active V34R1 native bridge visible wrapper")
PY

  echo
  echo "=== BUILD AFTER ACTIVE MOUNT ==="

  BUILD_LOG="$RELEASE_DIR/npm_build_v34r1r2.log"
  (
    cd "$FRONTEND"
    npm run build > "$BUILD_LOG" 2>&1
  ) && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"

  echo "Build result: $BUILD_RESULT"

  if [ "$BUILD_RESULT" = "FAIL" ]; then
    tail -n 180 "$BUILD_LOG" || true
    exit 1
  fi

  echo
  echo "=== RESTART VITE AFTER ACTIVE MOUNT ==="

  pkill -f "vite.*5173" 2>/dev/null || true
  pkill -f "vite --host 127.0.0.1 --port 5173" 2>/dev/null || true
  sleep 2

  (
    cd "$FRONTEND"
    nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$RELEASE_DIR/vite_dev_5173_after_mount.log" 2>&1 &
    echo $! > "$RELEASE_DIR/vite_dev_5173_after_mount.pid"
  )

  for i in $(seq 1 25); do
    if curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null 2>&1; then
      echo "OK: Vite dev riattivo dopo active mount"
      break
    fi
    sleep 1
  done

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1800 \
    --virtual-time-budget=12000 \
    --dump-dom \
    "$URL_DEV" > "$DOM_AFTER" 2>"$RELEASE_DIR/chrome_dom_after.stderr" || {
      echo "ERRORE: Chrome dump-dom after fallito"
      cat "$RELEASE_DIR/chrome_dom_after.stderr" || true
      exit 1
    }

  DOM_FINAL="$DOM_AFTER"
fi

echo
echo "=== SCREENSHOT FINAL ==="

"$CHROME_BIN" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --window-size=1920,1800 \
  --virtual-time-budget=12000 \
  --screenshot="$SCREENSHOT" \
  "$URL_DEV" >/dev/null 2>"$RELEASE_DIR/chrome_screenshot.stderr" || {
    echo "ERRORE: screenshot fallito"
    cat "$RELEASE_DIR/chrome_screenshot.stderr" || true
    exit 1
  }

ls -lh "$SCREENSHOT"

echo
echo "=== BUILD CHECK FINAL ==="

BUILD_LOG_FINAL="$RELEASE_DIR/npm_build_final_v34r1r2.log"

(
  cd "$FRONTEND"
  npm run build > "$BUILD_LOG_FINAL" 2>&1
) && BUILD_RESULT_FINAL="PASS" || BUILD_RESULT_FINAL="FAIL"

echo "Build final: $BUILD_RESULT_FINAL"

if [ "$BUILD_RESULT_FINAL" = "FAIL" ]; then
  tail -n 180 "$BUILD_LOG_FINAL" || true
fi

echo
echo "=== CONTENT CHECKS ==="

{
  grep -q "V34R1 NATIVE RF PANEL BINDING" "$DOM_FINAL" && echo "OK: V34R1 marker visible in DOM" || echo "MISS: V34R1 marker visible in DOM"
  grep -q "Bridge Readiness · Live Contract Layer" "$DOM_FINAL" && echo "OK: V34R1 title visible in DOM" || echo "MISS: V34R1 title visible in DOM"
  grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" "$DOM_FINAL" && echo "OK: backend source visible in DOM" || echo "MISS: backend source visible in DOM"
  grep -q "not_running_or_not_detected" "$DOM_FINAL" && echo "OK: readiness visible in DOM" || echo "MISS: readiness visible in DOM"
  grep -q "trfmc-nginx-v21-api-fallback" "$DOM_FINAL" && echo "MISS: V21 fallback visible in DOM" || echo "OK: no V21 fallback visible in DOM"

  test -s "$SCREENSHOT" && echo "OK: screenshot non-empty" || echo "MISS: screenshot non-empty"
  grep -q "RFNativeLiveReadinessStripV34R1" "$MAIN" || grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$MAIN" && echo "OK: active main wrapper state valid" || echo "MISS: active main wrapper state valid"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$HTTP_NON_200" -ne 0 ] || [ "$BUILD_RESULT_FINAL" = "FAIL" ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== CREATE ROLLBACK ==="

ROLLBACK="$RELEASE_DIR/rollback_v34r1r2_runtime_visibility.sh"

cat > "$ROLLBACK" <<ROLLBACK_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"

cp "$RELEASE_DIR/main.tsx.before_v34r1r2_$TS" frontend/src/app/main.tsx

if [ -f "$RELEASE_DIR/RFOperationalDeckV34R1NativeBridgeVisible.tsx.before_v34r1r2_$TS" ]; then
  cp "$RELEASE_DIR/RFOperationalDeckV34R1NativeBridgeVisible.tsx.before_v34r1r2_$TS" frontend/src/rf_instruments/instruments/RFOperationalDeckV34R1NativeBridgeVisible.tsx
else
  rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV34R1NativeBridgeVisible.tsx
fi

echo "Rollback V34R1R2 runtime visibility completato"
ROLLBACK_EOF

chmod +x "$ROLLBACK"

echo
echo "=== MANIFEST / SUMMARY ==="

MANIFEST="$RELEASE_DIR/native_bridge_runtime_visibility_manifest_v34r1r2.json"
SUMMARY="$QUALITY_DIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_NATIVE_RF_BRIDGE_READINESS_RUNTIME_VISIBILITY_V34R1R2",
  "reason": "V34R1 build passed but DOM gate failed; this recovery restarts Vite and conditionally mounts the native readiness strip in the active deck path.",
  "active_mount_applied": $ACTIVE_MOUNT_APPLIED,
  "frontend_mutation": $ACTIVE_MOUNT_APPLIED,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "dom_before": "$DOM_BEFORE",
  "dom_after": "$DOM_AFTER",
  "dom_final": "$DOM_FINAL",
  "screenshot": "$SCREENSHOT",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "pre_freeze": "$PRE_FREEZE",
  "rollback": "$ROLLBACK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "build_result_final": "$BUILD_RESULT_FINAL",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_NATIVE_RF_BRIDGE_READINESS_RUNTIME_VISIBILITY_V34R1R2",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "pre_freeze": "$PRE_FREEZE",
  "rollback": "$ROLLBACK",
  "dom_final": "$DOM_FINAL",
  "screenshot": "$SCREENSHOT",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "active_mount_applied": $ACTIVE_MOUNT_APPLIED,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "build_result_final": "$BUILD_RESULT_FINAL",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV34R1NativeBridgeVisible.tsx \
  frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx \
  frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9Base.tsx \
  frontend/src/rf_instruments/telemetry/RFNativeLiveReadinessStripV34R1.tsx \
  "$RELEASE_DIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_native_rf_bridge_readiness_runtime_visibility_v34r1r2"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_native_rf_bridge_readiness_runtime_visibility_v34r1r2"

cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V34R1R2 RUNTIME VISIBILITY RECOVERY COMPLETATO"
echo "Rollback: $ROLLBACK"
echo "============================================================"

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: risultato $RESULT"
  echo "Rollback disponibile:"
  echo "$ROLLBACK"
  exit 1
fi
