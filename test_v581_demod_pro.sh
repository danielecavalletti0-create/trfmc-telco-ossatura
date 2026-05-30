#!/usr/bin/env bash
set -Eeuo pipefail
API="${API:-http://127.0.0.1:8000}"

echo "============================================================"
echo "TEST RF PRO v5.8.1 DEMOD PRO"
echo "============================================================"

echo "== SELFTEST API =="
curl -sS "$API/api/v581/selftest" | python3 -m json.tool

echo "== CREA IQ SELFTEST NFM =="
curl -sS -X POST "$API/api/v581/iq/selftest_signal" -H 'Content-Type: application/json'   -d '{"mode":"nfm","sample_rate":2000000,"seconds":2,"tone_hz":1000,"carrier_offset_hz":0}'   -o /tmp/v581_selftest.json
python3 -m json.tool /tmp/v581_selftest.json | sed -n '1,120p'
IQ="$(python3 - <<'PY'
import json
print(json.load(open('/tmp/v581_selftest.json'))["file"])
PY
)"

echo "== ANALYZE PLUS =="
curl -sS -X POST "$API/api/v581/iq/analyze_plus" -H 'Content-Type: application/json'   -d "{"filename":"$IQ","sample_rate":2000000,"fft_size":8192,"max_seconds":2}"   -o /tmp/v581_analyze.json
python3 -m json.tool /tmp/v581_analyze.json | sed -n '1,220p'

echo "== CHANNELIZE + DEMOD NFM =="
curl -sS -X POST "$API/api/v581/iq/channelize_demod" -H 'Content-Type: application/json'   -d "{"filename":"$IQ","sample_rate":2000000,"freq_offset_hz":0,"channel_bw_hz":25000,"mode":"nfm","max_seconds":2,"audio_rate":48000}"   -o /tmp/v581_demod.json
python3 -m json.tool /tmp/v581_demod.json | sed -n '1,220p'

echo "== COMPACT =="
python3 - <<'PY'
import json
a=json.load(open('/tmp/v581_analyze.json'))
d=json.load(open('/tmp/v581_demod.json'))
print("classification:", a["metrics"].get("classification_hint"))
print("obw:", a["metrics"].get("occupied_bw_hz"))
print("wav:", d.get("wav_file"))
print("wav_sha256:", d.get("wav_sha256"))
print("audio:", d.get("audio_metrics"))
PY

rm -f /tmp/v581_selftest.json /tmp/v581_analyze.json /tmp/v581_demod.json
