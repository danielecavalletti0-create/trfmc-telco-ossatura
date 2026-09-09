#!/usr/bin/env bash
set -Eeuo pipefail
set +H
BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"
if [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
fi
echo "============================================================"
echo "RF PRO Unified SDR Laboratory Receiver"
echo "URL: http://127.0.0.1:8000/api/rfpro/console"
echo "============================================================"
if command -v fuser >/dev/null 2>&1; then
  fuser -k 8000/tcp 2>/dev/null || true
fi
python -m uvicorn backend.main_v580:app --host 127.0.0.1 --port 8000
