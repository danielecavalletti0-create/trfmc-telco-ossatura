#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

echo "============================================================"
echo "RF PRO v5.8.0 - FIX BACKEND ONLY"
echo "Corregge:"
echo "- uvicorn mancante"
echo "- bypass Vite 5173 occupata"
echo "- pagina Signal Workbench servita da FastAPI"
echo "============================================================"

echo
echo "[1/7] Pulizia variabili placeholder MarkVII/Blueway non valide"
unset MARKVII_RECON_URL || true
unset MARKVII_TOKEN || true
unset BLUEWAY_STATUS_URL || true
unset BLUEWAY_STATUS_JSON || true

echo
echo "[2/7] Creo virtual environment Python locale"
if [ ! -d ".venv" ]; then
  python3 -m venv .venv || {
    echo
    echo "ERRORE: python3-venv non disponibile."
    echo "Installa con:"
    echo "  sudo apt update"
    echo "  sudo apt install -y python3-venv python3-pip"
    exit 1
  }
fi

source .venv/bin/activate

echo
echo "[3/7] Installo dipendenze backend nel venv"
python -m pip install --upgrade pip setuptools wheel
python -m pip install 'fastapi' 'uvicorn[standard]' 'pydantic' 'numpy'

echo
echo "[4/7] Patch router: aggiungo pagina HTML servita dal backend"
ROUTER="$BASE/backend/routers/workbench_v580.py"

if [ ! -f "$ROUTER" ]; then
  echo "ERRORE: router non trovato: $ROUTER"
  echo "Rilancia prima step_v580_rf_signal_workbench.sh"
  exit 1
fi

if ! grep -q "HTMLResponse" "$ROUTER"; then
  sed -i 's/from fastapi.responses import FileResponse/from fastapi.responses import FileResponse, HTMLResponse/' "$ROUTER"
fi

if ! grep -q "def workbench_v580_page" "$ROUTER"; then
cat >> "$ROUTER" <<'PY'

# ---------------------------------------------------------------------
# RF PRO v5.8.0 - Backend-served HTML page
# ---------------------------------------------------------------------
@router.get("/workbench/page", response_class=HTMLResponse)
def workbench_v580_page():
    page = ROOT / "frontend" / "public" / "signal_workbench_v580.html"
    if not page.exists():
        raise HTTPException(status_code=404, detail=f"Pagina non trovata: {page}")
    return HTMLResponse(page.read_text(encoding="utf-8", errors="ignore"))
PY
fi

echo
echo "[5/7] Creo launcher backend stabile su 127.0.0.1:8000"
cat > "$BASE/run_v580_backend_only.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

source .venv/bin/activate

echo "============================================================"
echo "RF PRO v5.8.0 - Backend Only"
echo "URL pagina:"
echo "  http://127.0.0.1:8000/api/v580/workbench/page"
echo "API state:"
echo "  http://127.0.0.1:8000/api/v580/workbench/state"
echo "============================================================"

echo
echo "[1/3] Libero porta backend 8000, se occupata"
if command -v fuser >/dev/null 2>&1; then
  fuser -k 8000/tcp 2>/dev/null || true
else
  pkill -f "uvicorn.*8000" 2>/dev/null || true
fi

echo
echo "[2/3] Verifico modulo backend"
if python - <<'PY'
import importlib.util
raise SystemExit(0 if importlib.util.find_spec("backend.main") else 1)
PY
then
  APP="backend.main:app"
elif python - <<'PY'
import importlib.util
raise SystemExit(0 if importlib.util.find_spec("backend.main_engine") else 1)
PY
then
  APP="backend.main_engine:app"
else
  echo "ERRORE: non trovo backend.main né backend.main_engine"
  exit 1
fi

echo "APP=$APP"

echo
echo "[3/3] Avvio Uvicorn"
python -m uvicorn "$APP" --host 127.0.0.1 --port 8000
SH

chmod +x "$BASE/run_v580_backend_only.sh"

echo
echo "[6/7] Creo test backend-only"
cat > "$BASE/test_v580_backend_only.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

API="http://127.0.0.1:8000"

echo "============================================================"
echo "TEST RF PRO v5.8.0 BACKEND ONLY"
echo "============================================================"

echo
echo "== 1) HTTP STATE =="
curl -sS -D /tmp/v580_hdr.txt -o /tmp/v580_state.json \
  -w 'HTTP=%{http_code} BYTES=%{size_download}\n' \
  "$API/api/v580/workbench/state"

echo "--- headers ---"
cat /tmp/v580_hdr.txt

echo "--- json ---"
python3 -m json.tool /tmp/v580_state.json | sed -n '1,160p'

echo
echo "== 2) HTML PAGE =="
curl -sS -o /tmp/v580_page.html \
  -w 'HTTP=%{http_code} BYTES=%{size_download}\n' \
  "$API/api/v580/workbench/page"
head -c 180 /tmp/v580_page.html
echo

echo
echo "== 3) SWEEP WINDOW TEST SIMULATO =="
curl -sS -X POST "$API/api/v580/workbench/sweep/window" \
  -H 'Content-Type: application/json' \
  -d '{"start_hz":1000000,"stop_hz":5000000,"bin_hz":100000,"points":512,"use_hackrf":false}' \
  -o /tmp/v580_sweep.json

python3 -m json.tool /tmp/v580_sweep.json | sed -n '1,220p'

rm -f /tmp/v580_hdr.txt /tmp/v580_state.json /tmp/v580_page.html /tmp/v580_sweep.json
SH

chmod +x "$BASE/test_v580_backend_only.sh"

echo
echo "[7/7] Verifica sintassi Python"
python -m py_compile "$ROUTER"

echo
echo "============================================================"
echo "FIX COMPLETATO"
echo "Avvia ora con:"
echo "  cd $BASE"
echo "  ./run_v580_backend_only.sh"
echo
echo "Poi apri:"
echo "  http://127.0.0.1:8000/api/v580/workbench/page"
echo
echo "Test in altro terminale:"
echo "  cd $BASE"
echo "  ./test_v580_backend_only.sh"
echo "============================================================"
