#!/usr/bin/env bash
set -Eeuo pipefail

API="http://127.0.0.1:8000"

echo "============================================================"
echo "TEST RF PRO v5.8.0 BACKEND ONLY"
echo "============================================================"

echo
echo "== 0) HEALTH =="
curl -sS "$API/health" | python3 -m json.tool

echo
echo "== 1) HTTP STATE =="
curl -sS "$API/api/v580/workbench/state" | python3 -m json.tool | sed -n '1,180p'

echo
echo "== 2) HTML PAGE =="
curl -sS -o /tmp/v580_page.html \
  -w 'HTTP=%{http_code} BYTES=%{size_download}\n' \
  "$API/api/v580/workbench/page"
head -c 220 /tmp/v580_page.html
echo

echo
echo "== 3) SWEEP WINDOW TEST 1-5 MHz SIMULATO =="
curl -sS -X POST "$API/api/v580/workbench/sweep/window" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":1000000,"stop_hz":5000000,"bin_hz":100000,"points":512,"use_hackrf":false}' \
  -o /tmp/v580_sweep.json

python3 -m json.tool /tmp/v580_sweep.json | sed -n '1,220p'

rm -f /tmp/v580_page.html /tmp/v580_sweep.json
