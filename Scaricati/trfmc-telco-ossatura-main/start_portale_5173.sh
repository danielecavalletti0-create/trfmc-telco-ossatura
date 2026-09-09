#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONTEND="$BASE/frontend"
LOGDIR="$BASE/runtime/logs"

mkdir -p "$LOGDIR"

echo "============================================================"
echo "TRFMC START PORTALE - SOLO PORTA 5173"
echo "============================================================"
date
echo "BASE=$BASE"
echo

echo "=== 1) STOP EVENTUALE PROCESSO PRECEDENTE SU 5173 ==="
PIDS="$(lsof -ti tcp:5173 2>/dev/null || true)"
if [ -n "$PIDS" ]; then
  echo "Fermo processo/i su 5173: $PIDS"
  kill $PIDS 2>/dev/null || true
  sleep 2
else
  echo "Nessun processo precedente su 5173"
fi

echo
echo "=== 2) AVVIO VITE SU 5173 ==="
cd "$FRONTEND"

nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort \
  > "$LOGDIR/frontend_5173.log" 2>&1 &

sleep 4

echo
echo "=== 3) PORTE ATTIVE ==="
ss -ltnp | grep ':5173' || true

echo
echo "=== 4) TEST PORTALE ==="
for url in \
  http://127.0.0.1:5173/trfmc_home_v87g.html \
  http://127.0.0.1:5173/rf_physics_sapienza_console_v86a.html \
  http://127.0.0.1:5173/webgl_rf_physics_engine_v85e_viewport_discipline.html \
  http://127.0.0.1:5173/api/health
do
  echo
  echo "----- $url -----"
  if [[ "$url" == *"/api/health" ]]; then
    curl -s --max-time 5 "$url" | python3 -m json.tool
  else
    curl -I --max-time 5 "$url"
  fi
done

echo
echo "=== 5) LOG VITE ==="
tail -n 60 "$LOGDIR/frontend_5173.log"

echo
echo "PORTALE DISPONIBILE:"
echo "http://127.0.0.1:5173/trfmc_home_v87g.html"
