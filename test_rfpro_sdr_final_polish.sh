#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"
echo "============================================================"
echo "TEST RF PRO SDR FINAL POLISH"
echo "============================================================"
echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool
echo "== STATE =="
curl -sS "$API/api/rfpro/state" | python3 -m json.tool | sed -n '1,180p'
echo "== DEVICE INFO =="
curl -sS "$API/api/rfpro/device/info" | python3 -m json.tool | sed -n '1,80p'
echo "== CONSOLE PAGE =="
curl -sS -o /tmp/rfpro_sdr.html -w 'HTTP=%{http_code} BYTES=%{size_download}\n' "$API/api/rfpro/console"
grep -o "RF PRO · SDR Laboratory Receiver" /tmp/rfpro_sdr.html || true
echo "== SYNTH SWEEP =="
curl -sS -X POST "$API/api/rfpro/spectrum/sweep" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":1000000,"stop_hz":11000000,"rbw_hz":100000,"points":1200,"use_hackrf":false,"timeout_s":60}' \
  | python3 -m json.tool | sed -n '1,150p'
echo "== SYNTH IQ CAPTURE =="
curl -sS -X POST "$API/api/rfpro/iq/capture" \
  -H 'Content-Type: application/json' \
  -d '{"center_hz":6101000,"sample_rate":2000000,"seconds":1,"lna_gain":16,"vga_gain":32,"use_hackrf":false}' \
  | python3 -m json.tool | sed -n '1,140p'
rm -f /tmp/rfpro_sdr.html
