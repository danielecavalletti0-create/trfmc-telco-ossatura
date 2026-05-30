#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

source .venv/bin/activate

echo "============================================================"
echo "RF PRO v5.8.0 - Backend Only Standalone"
echo "APP: backend.main_v580:app"
echo "URL pagina:"
echo "  http://127.0.0.1:8000/api/v580/workbench/page"
echo "API state:"
echo "  http://127.0.0.1:8000/api/v580/workbench/state"
echo "Health:"
echo "  http://127.0.0.1:8000/health"
echo "============================================================"

echo
echo "[1/2] Libero porta 8000"
if command -v fuser >/dev/null 2>&1; then
  fuser -k 8000/tcp 2>/dev/null || true
else
  pkill -f "uvicorn.*8000" 2>/dev/null || true
fi

echo
echo "[2/2] Avvio Uvicorn"
python -m uvicorn backend.main_v580:app --host 127.0.0.1 --port 8000
