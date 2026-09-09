#!/usr/bin/env bash
set -Eeuo pipefail
URL="http://127.0.0.1:5173/trfmc_rf_microwave_engineering_v1.html"

echo "============================================================"
echo "TEST TRFMC RF MICROWAVE SMITH CHART LAB V1"
echo "============================================================"
date
echo

echo "=== PORTA 5173 ==="
ss -ltnp | grep -E ':5173' || true
echo

echo "=== HTTP ==="
curl -I "$URL" 2>/dev/null | head || true
echo

echo "=== CONTENT CHECK ==="
HTML="$(curl -sS "$URL" || true)"
for token in \
  "Smith Chart Engine" \
  "Impedance Matching Lab" \
  "Single Shunt Stub Solutions" \
  "VSWR" \
  "Return Loss" \
  "TRFMC Integration"
do
  if echo "$HTML" | grep -q "$token"; then
    echo "OK: $token"
  else
    echo "MISSING: $token"
  fi
done
