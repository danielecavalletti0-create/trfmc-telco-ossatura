#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

echo "============================================================"
echo "FORCE MOUNT RF PRO v5.8.4 UAV ROUTER"
echo "============================================================"

PY="python3"
if [ -x ".venv/bin/python" ]; then
  PY=".venv/bin/python"
fi

echo "PY=$PY"

echo
echo "[1/7] Verifico file UAV"
ls -l backend/routers/uav_v584.py
ls -l frontend/public/uav_fhss_v584.html

echo
echo "[2/7] Riscrivo backend/main_v580.py con TUTTI i router inclusi"
cat > backend/main_v580.py <<'PYCODE'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from backend.routers.workbench_v580 import router as workbench_v580_router
from backend.routers.demod_v581 import router as demod_v581_router
from backend.routers.workbench_v582 import router as workbench_v582_router
from backend.routers.master_v583 import router as master_v583_router
from backend.routers.uav_v584 import router as uav_v584_router

app = FastAPI(
    title="RF PRO Master Signal Workbench",
    version="5.8.4",
    description="Master integration: v580 workbench + v581 demod + v582 layout + v583 registry + v584 UAV FHSS."
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(workbench_v580_router)
app.include_router(demod_v581_router)
app.include_router(workbench_v582_router)
app.include_router(master_v583_router)
app.include_router(uav_v584_router)

@app.get("/")
def root():
    return RedirectResponse(url="/api/v583/master/page")

@app.get("/health")
def health():
    return {
        "ok": True,
        "service": "rf-pro-v584-uav-fhss",
        "mode": "RX_ONLY",
        "entrypoint": "/api/v583/master/page",
        "uav": "/api/v584/uav/page"
    }
PYCODE

echo
echo "[3/7] Aggiorno pagina master con bottone UAV, se manca"
$PY - <<'PY'
from pathlib import Path

p = Path("frontend/public/rfpro_master_v583.html")
if not p.exists():
    print("WARN: master page non trovata:", p)
    raise SystemExit(0)

txt = p.read_text(encoding="utf-8", errors="ignore")
if "Open v5.8.4 UAV FHSS" not in txt:
    txt = txt.replace(
        '<button class="orange" onclick="audit()">Audit No-Loss</button>',
        '<button class="good" onclick="loadFrame(\\'/api/v584/uav/page\\')">Open v5.8.4 UAV FHSS</button>\\n      <button class="orange" onclick="audit()">Audit No-Loss</button>'
    )
    p.write_text(txt, encoding="utf-8")
    print("OK: bottone UAV aggiunto alla master")
else:
    print("OK: bottone UAV già presente")
PY

echo
echo "[4/7] Ricreo launcher backend corretto"
cat > run_v580_backend_only.sh <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

if [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
fi

echo "============================================================"
echo "RF PRO Backend Only"
echo "APP: backend.main_v580:app"
echo "URL master:"
echo "  http://127.0.0.1:8000/api/v583/master/page"
echo "URL UAV:"
echo "  http://127.0.0.1:8000/api/v584/uav/page"
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
echo "[5/7] Ricreo test v5.8.4"
cat > test_v584_uav_fhss.sh <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

API="${API:-http://127.0.0.1:8000}"

echo "============================================================"
echo "TEST RF PRO v5.8.4 UAV FHSS / BURST"
echo "============================================================"

echo
echo "== HEALTH =="
curl -sS "$API/health" | python3 -m json.tool

echo
echo "== UAV SELFTEST =="
curl -sS "$API/api/v584/uav/selftest" | python3 -m json.tool

echo
echo "== UAV PROFILES =="
curl -sS "$API/api/v584/uav/profiles" | python3 -m json.tool | sed -n '1,160p'

echo
echo "== SYNTHETIC UAV SWEEP LOWBAND 1-5 MHz =="
curl -sS -X POST "$API/api/v584/uav/sweep_band" \
  -H 'Content-Type: application/json' \
  -d '{"profile_id":"LOWBAND_TEST_1_5","threshold_db":6,"iterations":6,"dwell_ms":0,"use_hackrf":false}' \
  -o /tmp/v584_sweep.json

python3 -m json.tool /tmp/v584_sweep.json | sed -n '1,180p'

echo
echo "== HOPPING ANALYZE =="
curl -sS -X POST "$API/api/v584/uav/hopping/analyze" \
  -H 'Content-Type: application/json' \
  -d '{}' \
  -o /tmp/v584_hop.json

python3 -m json.tool /tmp/v584_hop.json | sed -n '1,220p'

echo
echo "== COMPACT =="
python3 - <<'PY'
import json
h=json.load(open('/tmp/v584_hop.json'))
print("likelihood:", h.get("likelihood"))
print("fhss_score:", h.get("fhss_score"))
print("unique_channels:", h.get("unique_channels"))
print("transitions:", h.get("transitions"))
PY

rm -f /tmp/v584_sweep.json /tmp/v584_hop.json
SH

chmod +x test_v584_uav_fhss.sh

echo
echo "[6/7] Verifico sintassi/import"
$PY -m py_compile backend/routers/uav_v584.py backend/main_v580.py

echo
echo "[7/7] Verifico contenuto main"
grep -n "uav_v584\|include_router" backend/main_v580.py

echo
echo "============================================================"
echo "FORCE MOUNT COMPLETATO"
echo "Adesso avvia:"
echo "  ./run_v580_backend_only.sh"
echo "============================================================"
