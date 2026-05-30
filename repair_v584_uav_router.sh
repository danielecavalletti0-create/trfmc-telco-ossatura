#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
SCRIPT="$HOME/Scaricati/rfpro_v584_uav_fhss_burst.sh"

cd "$BASE"

echo "============================================================"
echo "REPAIR RF PRO v5.8.4 UAV ROUTER"
echo "Corregge:"
echo "- python -> python3"
echo "- installazione v5.8.4 interrotta"
echo "- main_v580.py non aggiornato"
echo "- test_v584_uav_fhss.sh mancante"
echo "============================================================"

echo
echo "[1/6] Verifico script v5.8.4"
if [ ! -f "$SCRIPT" ]; then
  echo "ERRORE: non trovo $SCRIPT"
  exit 1
fi

echo
echo "[2/6] Correggo tutte le chiamate python -> python3 nello script"
sed -i \
  -e 's/^python - <</python3 - <</g' \
  -e 's/^python -m /python3 -m /g' \
  -e 's/ python - <</ python3 - <</g' \
  -e 's/ python -m / python3 -m /g' \
  "$SCRIPT"

echo
echo "[3/6] Controllo che non resti python nudo"
grep -nE '(^|[[:space:]])python([[:space:]]|-m)' "$SCRIPT" || true

echo
echo "[4/6] Rieseguo installazione v5.8.4 corretta"
chmod +x "$SCRIPT"
"$SCRIPT"

echo
echo "[5/6] Verifico che main_v580.py includa il router UAV"
grep -n "uav_v584" backend/main_v580.py || {
  echo "ERRORE: backend/main_v580.py non include uav_v584"
  exit 1
}

echo
echo "[6/6] Compilazione Python"
if [ -d ".venv" ]; then
  .venv/bin/python -m py_compile backend/routers/uav_v584.py backend/main_v580.py
else
  python3 -m py_compile backend/routers/uav_v584.py backend/main_v580.py
fi

echo
echo "============================================================"
echo "REPAIR COMPLETATA"
echo "Ora DEVI riavviare Uvicorn."
echo "============================================================"
