#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

echo "============================================================"
echo "RF PRO v5.8.0 Signal Workbench"
echo "============================================================"
echo "Backend tipico: http://127.0.0.1:8000"
echo "Frontend Vite:  http://127.0.0.1:5173/signal_workbench_v580.html"
echo

if command -v hackrf_info >/dev/null 2>&1; then
  echo "[HackRF]"
  hackrf_info || true
else
  echo "WARN: hackrf_info non trovato. Installa hackrf-tools per usare HackRF reale."
fi

echo
echo "Avvio manuale consigliato, in due terminali:"
echo "  Terminale 1:"
echo "    cd $(pwd)"
echo "    python3 -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload"
echo "    # oppure, se il tuo backend storico usa main_engine:"
echo "    python3 -m uvicorn backend.main_engine:app --host 127.0.0.1 --port 8000 --reload"
echo
echo "  Terminale 2:"
echo "    cd $(pwd)/frontend"
echo "    npm run dev -- --host 127.0.0.1 --port 5173"
echo
echo "Apri:"
echo "  http://127.0.0.1:5173/signal_workbench_v580.html"
