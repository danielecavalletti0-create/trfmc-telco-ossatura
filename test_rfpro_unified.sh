#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"
echo "============================================================"
echo "TEST RF PRO UNIFIED"
echo "============================================================"
echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool
echo "== STATE =="
curl -sS "$API/api/rfpro/state" | python3 -m json.tool | sed -n '1,220p'
echo "== CONSOLE PAGE =="
curl -sS -o /tmp/rfpro_console.html -w 'HTTP=%{http_code} BYTES=%{size_download}\n' "$API/api/rfpro/console"
head -c 180 /tmp/rfpro_console.html
echo
echo "== SPECTRUM SWEEP SYNTHETIC =="
curl -sS -X POST "$API/api/rfpro/spectrum/sweep" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":1000000,"stop_hz":5000000,"rbw_hz":100000,"points":1000,"use_hackrf":false,"timeout_s":60}' \
  -o /tmp/rfpro_sweep.json
python3 -m json.tool /tmp/rfpro_sweep.json | sed -n '1,160p'
echo "== UAV FHSS SYNTHETIC =="
curl -sS -X POST "$API/api/rfpro/uav/fhss" \
  -H 'Content-Type: application/json' \
  -d '{"profile_id":"LOWBAND_TEST_1_5","iterations":4,"threshold_db":7,"use_hackrf":false,"dwell_ms":0}' \
  -o /tmp/rfpro_uav.json
python3 -m json.tool /tmp/rfpro_uav.json | sed -n '1,180p'
echo "== OPENAPI RFPRO ROUTES =="
curl -sS "$API/openapi.json" | python3 - <<'PY'
import sys, json
j=json.load(sys.stdin)
for p in sorted(j.get("paths",{})):
    if "/api/rfpro" in p:
        print(p)
PY
rm -f /tmp/rfpro_console.html /tmp/rfpro_sweep.json /tmp/rfpro_uav.json
