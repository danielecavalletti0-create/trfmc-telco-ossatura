#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"
echo "============================================================"
echo "TEST RF PRO v5.8.5 REALTIME UI"
echo "============================================================"
echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool
echo "== REALTIME STATE =="
curl -sS "$API/api/v585/realtime/state" | python3 -m json.tool
echo "== ONE FRAME =="
curl -sS "$API/api/v585/realtime/one_frame?start_hz=1000000&stop_hz=5000000&bin_hz=100000&use_hackrf=false" \
  -o /tmp/v585_frame.json
python3 -m json.tool /tmp/v585_frame.json | sed -n '1,220p'
echo "== PAGE =="
curl -sS -o /tmp/v585_page.html -w 'HTTP=%{http_code} BYTES=%{size_download}\n' "$API/api/v585/realtime/page"
head -c 180 /tmp/v585_page.html
echo
rm -f /tmp/v585_frame.json /tmp/v585_page.html
