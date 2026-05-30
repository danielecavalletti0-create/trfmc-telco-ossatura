#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

echo "============================================================"
echo "RF PRO v5.8.0 - STANDALONE FASTAPI ENTRYPOINT FIX"
echo "Corregge:"
echo "- backend.main assente"
echo "- backend.main_engine assente"
echo "- avvio diretto con backend.main_v580:app"
echo "============================================================"

echo
echo "[1/6] Verifico virtualenv"
if [ ! -d ".venv" ]; then
  echo "ERRORE: .venv non trovato. Rilancia prima fix_v580_backend_only.sh"
  exit 1
fi

source .venv/bin/activate

echo
echo "[2/6] Verifico router workbench"
if [ ! -f "backend/routers/workbench_v580.py" ]; then
  echo "ERRORE: backend/routers/workbench_v580.py non trovato."
  echo "Rilancia prima step_v580_rf_signal_workbench.sh"
  exit 1
fi

mkdir -p backend/routers
touch backend/__init__.py backend/routers/__init__.py

echo
echo "[3/6] Creo backend/main_v580.py"
cat > backend/main_v580.py <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from backend.routers.workbench_v580 import router as workbench_v580_router

app = FastAPI(
    title="RF PRO v5.8.0 Signal Workbench",
    version="5.8.0",
    description="HackRF RX-only Signal Workbench: sweep, IQ capture, IQ analysis, audio demod, observers, evidence.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:8000",
        "http://localhost:8000",
        "http://127.0.0.1:5173",
        "http://localhost:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(workbench_v580_router)

@app.get("/")
def root():
    return RedirectResponse(url="/api/v580/workbench/page")

@app.get("/health")
def health():
    return {
        "ok": True,
        "service": "rf-pro-v580-signal-workbench",
        "mode": "RX_ONLY",
    }
PY

echo
echo "[4/6] Verifico import e sintassi"
python -m py_compile backend/routers/workbench_v580.py
python -m py_compile backend/main_v580.py

python - <<'PY'
import importlib
m = importlib.import_module("backend.main_v580")
print("OK import:", m.app.title)
PY

echo
echo "[5/6] Creo launcher corretto"
cat > run_v580_backend_only.sh <<'SH'
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
SH

chmod +x run_v580_backend_only.sh

echo
echo "[6/6] Creo test robusto"
cat > test_v580_backend_only.sh <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

API="http://127.0.0.1:8000"

echo "============================================================"
echo "TEST RF PRO v5.8.0 BACKEND ONLY"
echo "============================================================"

echo
echo "== 0) HEALTH =="
curl -sS "$API/health" | python3 -m json.tool

echo
echo "== 1) HTTP STATE =="
curl -sS "$API/api/v580/workbench/state" | python3 -m json.tool | sed -n '1,180p'

echo
echo "== 2) HTML PAGE =="
curl -sS -o /tmp/v580_page.html \
  -w 'HTTP=%{http_code} BYTES=%{size_download}\n' \
  "$API/api/v580/workbench/page"
head -c 220 /tmp/v580_page.html
echo

echo
echo "== 3) SWEEP WINDOW TEST 1-5 MHz SIMULATO =="
curl -sS -X POST "$API/api/v580/workbench/sweep/window" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":1000000,"stop_hz":5000000,"bin_hz":100000,"points":512,"use_hackrf":false}' \
  -o /tmp/v580_sweep.json

python3 -m json.tool /tmp/v580_sweep.json | sed -n '1,220p'

rm -f /tmp/v580_page.html /tmp/v580_sweep.json
SH

chmod +x test_v580_backend_only.sh

echo
echo "============================================================"
echo "FIX COMPLETATO"
echo "Avvia ora:"
echo "  cd $BASE"
echo "  ./run_v580_backend_only.sh"
echo
echo "Poi apri:"
echo "  http://127.0.0.1:8000/api/v580/workbench/page"
echo
echo "Test in secondo terminale:"
echo "  cd $BASE"
echo "  ./test_v580_backend_only.sh"
echo "============================================================"
