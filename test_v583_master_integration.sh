#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"

echo "============================================================"
echo "TEST RF PRO v5.8.3 MASTER INTEGRATION"
echo "============================================================"

echo
echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool

echo
echo "== MASTER STATE =="
curl -sS "$API/api/v583/master/state" | python3 -m json.tool | sed -n '1,220p'

echo
echo "== MASTER AUDIT =="
curl -sS "$API/api/v583/master/audit" | python3 -m json.tool | sed -n '1,260p'

echo
echo "== PAGE CHECK =="
curl -sS -o /tmp/v583_page.html -w 'HTTP=%{http_code} BYTES=%{size_download}\n' "$API/api/v583/master/page"
head -c 180 /tmp/v583_page.html
echo

echo
echo "== OLD MODULES STILL ACTIVE =="
echo "-- v580 state"
curl -sS "$API/api/v580/workbench/state" | python3 -m json.tool | sed -n '1,60p'
echo "-- v581 selftest"
curl -sS "$API/api/v581/selftest" | python3 -m json.tool
echo "-- v582 selftest"
curl -sS "$API/api/v582/selftest" | python3 -m json.tool

rm -f /tmp/v583_page.html
