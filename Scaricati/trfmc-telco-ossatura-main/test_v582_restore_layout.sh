#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"

echo "============================================================"
echo "TEST RF PRO v5.8.2 RESTORE LAYOUT"
echo "============================================================"

echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool

echo "== PAGE =="
curl -sS -o /tmp/v582_page.html -w 'HTTP=%{http_code} BYTES=%{size_download}\n' "$API/api/v582/workbench/page"
head -c 220 /tmp/v582_page.html
echo

echo "== V581 API STILL ACTIVE =="
curl -sS "$API/api/v581/selftest" | python3 -m json.tool

echo "== V580 SWEEP STILL ACTIVE =="
curl -sS -X POST "$API/api/v580/workbench/sweep/window" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":1000000,"stop_hz":5000000,"bin_hz":100000,"points":256,"use_hackrf":false}' \
  | python3 -m json.tool | sed -n '1,120p'

rm -f /tmp/v582_page.html
