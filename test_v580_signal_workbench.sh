#!/usr/bin/env bash
set -Eeuo pipefail

API="${API:-http://127.0.0.1:8000}"

echo "== STATE =="
curl -s "$API/api/v580/workbench/state" | python3 -m json.tool | sed -n '1,120p'

echo
echo "== SWEEP WINDOW =="
curl -s -X POST "$API/api/v580/workbench/sweep/window" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":88000000,"stop_hz":108000000,"bin_hz":100000,"points":512,"use_hackrf":false}' \
  | python3 -m json.tool | sed -n '1,160p'

echo
echo "== FILES =="
curl -s "$API/api/v580/workbench/files" | python3 -m json.tool | sed -n '1,160p'
