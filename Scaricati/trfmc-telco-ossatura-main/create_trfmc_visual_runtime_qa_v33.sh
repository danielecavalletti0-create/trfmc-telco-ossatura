#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_VISUAL_RUNTIME_QA_V33_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_VISUAL_RUNTIME_QA_V33_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_VISUAL_RUNTIME_QA_V33_$TS.tar.gz"

FRONTEND="$ROOT/frontend"
URL_DEV="http://127.0.0.1:5173/"
SCREENSHOT="$RELEASE_DIR/screenshots/trfmc_v33_runtime_5173.png"
DOM_DUMP="$RELEASE_DIR/dom/trfmc_v33_runtime_5173.html"
HTTP_TSV="$RELEASE_DIR/http.tsv"
CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

echo "============================================================"
echo "TRFMC VISUAL RUNTIME QA V33"
echo "screenshot gate · DOM gate · API source gate · no source mutation"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR/screenshots" "$RELEASE_DIR/dom" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -d "$FRONTEND" || { echo "ERRORE: frontend mancante"; exit 1; }
test -f "$FRONTEND/src/app/main.tsx" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$FRONTEND/src/rf_instruments/telemetry/RFLiveContractStatusV32R1.tsx" || { echo "ERRORE: pannello V32R1 mancante"; exit 1; }
test -f "$ROOT/runtime/quality/latest_frontend_live_contract_overlay_v32r1/summary.json" || { echo "ERRORE: V32R1 summary mancante"; exit 1; }

V32R1_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_frontend_live_contract_overlay_v32r1/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V32R1_RESULT" = "PASS" ] || {
  echo "ERRORE: V32R1 non PASS: $V32R1_RESULT"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: 4181 non passa al backend reale"
  exit 1
}

echo "OK: V32R1 PASS, API 4181 live"

echo
echo "=== FIND CHROME/CHROMIUM ==="

CHROME_BIN=""

for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME_BIN="$(command -v "$c")"
    break
  fi
done

if [ -z "$CHROME_BIN" ]; then
  echo "ERRORE: Chrome/Chromium non trovato. Installa o rendi disponibile google-chrome/chromium."
  exit 1
fi

echo "Chrome: $CHROME_BIN"

echo
echo "=== ENSURE VITE DEV SERVER 5173 ==="

if curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null 2>&1; then
  echo "OK: Vite dev già attivo su $URL_DEV"
  VITE_STARTED_BY_V33=false
else
  echo "Vite dev non attivo. Avvio temporaneo su 127.0.0.1:5173..."
  VITE_LOG="$RELEASE_DIR/vite_dev_5173.log"
  (
    cd "$FRONTEND"
    nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$VITE_LOG" 2>&1 &
    echo $! > "$RELEASE_DIR/vite_dev_5173.pid"
  )
  VITE_STARTED_BY_V33=true

  for i in $(seq 1 20); do
    if curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null 2>&1; then
      echo "OK: Vite dev avviato"
      break
    fi
    sleep 1
  done

  curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null || {
    echo "ERRORE: Vite dev non raggiungibile dopo avvio"
    tail -n 120 "$VITE_LOG" || true
    exit 1
  }
fi

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
  "http://127.0.0.1:4181/api/rfpro/bandplan" \
  "http://127.0.0.1:4181/api/rfpro/spectrum/sweep" \
  "http://127.0.0.1:4181/api/soc-noc/correlation/demo"
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

echo
echo "=== HEADLESS CHROME SCREENSHOT ==="

"$CHROME_BIN" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --window-size=1920,1600 \
  --virtual-time-budget=10000 \
  --screenshot="$SCREENSHOT" \
  "$URL_DEV" >/dev/null 2>"$RELEASE_DIR/chrome_screenshot.stderr" || {
    echo "ERRORE: screenshot Chrome fallito"
    cat "$RELEASE_DIR/chrome_screenshot.stderr" || true
    exit 1
  }

"$CHROME_BIN" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --window-size=1920,1600 \
  --virtual-time-budget=10000 \
  --dump-dom \
  "$URL_DEV" > "$DOM_DUMP" 2>"$RELEASE_DIR/chrome_dom.stderr" || {
    echo "ERRORE: DOM dump Chrome fallito"
    cat "$RELEASE_DIR/chrome_dom.stderr" || true
    exit 1
  }

ls -lh "$SCREENSHOT" "$DOM_DUMP"

echo
echo "=== SCREENSHOT METADATA ==="

PNG_META="$RELEASE_DIR/screenshot_metadata.json"

python3 - "$SCREENSHOT" > "$PNG_META" <<'PY'
from pathlib import Path
import json
import struct
import sys

p = Path(sys.argv[1])
meta = {
    "path": str(p),
    "exists": p.exists(),
    "size_bytes": p.stat().st_size if p.exists() else 0,
    "png": False,
    "width": None,
    "height": None,
}

if p.exists():
    data = p.read_bytes()
    if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
        meta["png"] = True
        meta["width"], meta["height"] = struct.unpack(">II", data[16:24])

print(json.dumps(meta, indent=2))
PY

cat "$PNG_META"

echo
echo "=== DOM VISUAL CONTRACT CHECK ==="

# Nota: dump-dom di Chrome esegue JS; cerchiamo testo renderizzato dal pannello React.
{
  grep -q "TRFMC Read-Only Contract Overlay" "$DOM_DUMP" && echo "OK: overlay title visible in DOM" || echo "MISS: overlay title visible in DOM"
  grep -q "Mission Backend" "$DOM_DUMP" && echo "OK: Mission Backend card visible" || echo "MISS: Mission Backend card visible"
  grep -q "Open5GS Core" "$DOM_DUMP" && echo "OK: Open5GS card visible" || echo "MISS: Open5GS card visible"
  grep -q "UERANSIM RAN" "$DOM_DUMP" && echo "OK: UERANSIM card visible" || echo "MISS: UERANSIM card visible"
  grep -q "RF Bandplan" "$DOM_DUMP" && echo "OK: RF Bandplan card visible" || echo "MISS: RF Bandplan card visible"
  grep -q "Spectrum Contract" "$DOM_DUMP" && echo "OK: Spectrum card visible" || echo "MISS: Spectrum card visible"
  grep -q "SOC/NOC Correlation" "$DOM_DUMP" && echo "OK: SOC/NOC card visible" || echo "MISS: SOC/NOC card visible"

  grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" "$DOM_DUMP" && echo "OK: backend source visible in DOM" || echo "MISS: backend source visible in DOM"
  grep -q "not_running_or_not_detected" "$DOM_DUMP" && echo "OK: not_running readiness visible" || echo "MISS: not_running readiness visible"

  grep -q "trfmc-nginx-v21-api-fallback" "$DOM_DUMP" && echo "MISS: V21 fallback visible in DOM" || echo "OK: no V21 fallback visible in DOM"

  test -s "$SCREENSHOT" && echo "OK: screenshot file non-empty" || echo "MISS: screenshot file non-empty"

  python3 - "$PNG_META" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
ok = d.get("png") and d.get("width",0) >= 1600 and d.get("height",0) >= 1000 and d.get("size_bytes",0) > 10000
print("OK: screenshot dimensions valid" if ok else "MISS: screenshot dimensions valid")
PY
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$HTTP_NON_200" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/visual_runtime_qa_manifest_v33.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_VISUAL_RUNTIME_QA_V33",
  "frontend_url": "$URL_DEV",
  "chrome_bin": "$CHROME_BIN",
  "vite_started_by_v33": $VITE_STARTED_BY_V33,
  "screenshot": "$SCREENSHOT",
  "dom_dump": "$DOM_DUMP",
  "screenshot_metadata": "$PNG_META",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "checks": {
    "overlay_title": "TRFMC Read-Only Contract Overlay",
    "cards": [
      "Mission Backend",
      "Open5GS Core",
      "UERANSIM RAN",
      "RF Bandplan",
      "Spectrum Contract",
      "SOC/NOC Correlation"
    ],
    "no_v21_fallback": true
  },
  "safety": {
    "source_mutation": false,
    "frontend_mutation": false,
    "backend_mutation": false,
    "dist_mutation": false,
    "nginx_mutation": false,
    "systemd_mutation": false
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_VISUAL_RUNTIME_QA_V33",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "screenshot": "$SCREENSHOT",
  "dom_dump": "$DOM_DUMP",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_visual_runtime_qa_v33"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_visual_runtime_qa_v33"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V33 VISUAL RUNTIME QA COMPLETATO"
echo "Screenshot: $SCREENSHOT"
echo "DOM dump  : $DOM_DUMP"
echo "============================================================"

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: V33 result=$RESULT"
  exit 1
fi
