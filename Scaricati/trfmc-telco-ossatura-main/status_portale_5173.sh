#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
LOG="$BASE/runtime/logs/frontend_5173.log"

echo "============================================================"
echo "TRFMC STATUS PORTALE - 5173"
echo "============================================================"
date
echo

echo "=== 1) PORTA 5173 ==="
ss -ltnp | grep ':5173' || echo "ERRORE: nessun servizio in ascolto su 5173"

echo
echo "=== 2) TEST PAGINE ==="
for url in \
  http://127.0.0.1:5173/trfmc_home_v87g.html \
  http://127.0.0.1:5173/trfmc_home.html \
  http://127.0.0.1:5173/trfmc.html \
  http://127.0.0.1:5173/rf_physics_sapienza_console_v86a.html \
  http://127.0.0.1:5173/webgl_rf_physics_engine_v85e_viewport_discipline.html
do
  code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || true)"
  echo "$url -> $code"
done

echo
echo "=== 3) TEST HEALTH JSON 5173 ==="
curl -s --max-time 5 http://127.0.0.1:5173/api/health | python3 -m json.tool

echo
echo "=== 4) LOG VITE ==="
if [ -f "$LOG" ]; then
  tail -n 80 "$LOG"
else
  echo "Log non trovato: $LOG"
fi
