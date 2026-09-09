#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"
echo "============================================================"
echo "TEST RF PRO BRIDGES"
echo "============================================================"
echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool
echo "== BRIDGE STATE =="
curl -sS "$API/api/rfpro/bridges/state" | python3 -m json.tool | sed -n '1,220p'
echo "== GNU RADIO EXPORT =="
curl -sS -X POST "$API/api/rfpro/bridges/gnuradio/export" \
  -H 'Content-Type: application/json' \
  -d '{"sample_rate":2000000,"freq_offset_hz":0,"channel_bw_hz":25000,"decimation":20}' \
  | python3 -m json.tool | sed -n '1,180p'
echo "== SDR++ EXPORT =="
curl -sS "$API/api/rfpro/bridges/sdrpp/export" | python3 -m json.tool
echo "== BRIDGE FILES =="
curl -sS "$API/api/rfpro/bridges/files" | python3 -m json.tool | sed -n '1,220p'
echo "== OPENAPI BRIDGE ROUTES =="
curl -sS "$API/openapi.json" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
for p in sorted(j.get("paths",{})):
    if "/api/rfpro/bridges" in p:
        print(p)
PY
