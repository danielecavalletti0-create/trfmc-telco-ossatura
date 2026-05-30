#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"
echo "============================================================"
echo "TEST RF PRO v5.8.6 FULL BAND CURSOR"
echo "============================================================"
echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool
echo "== STATE =="
curl -sS "$API/api/v586/fullband/state" | python3 -m json.tool
echo "== SYNTH FULL BAND FRAME =="
curl -sS -X POST "$API/api/v586/fullband/sweep" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":1000000,"stop_hz":6000000000,"rbw_hz":1000000,"points":3000,"use_hackrf":false,"timeout_s":60}' \
  -o /tmp/v586_fullband.json
python3 -m json.tool /tmp/v586_fullband.json | sed -n '1,220p'
echo "== PAGE =="
curl -sS -o /tmp/v586_page.html -w 'HTTP=%{http_code} BYTES=%{size_download}\n' "$API/api/v586/fullband/page"
head -c 180 /tmp/v586_page.html
echo
rm -f /tmp/v586_fullband.json /tmp/v586_page.html
