#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

mkdir -p runtime logs

trap 'echo; echo "============================================================"; echo "FINE SCRIPT - il terminale resta aperto."; echo "Log in: logs/start_v08_last.log"; echo "============================================================"; read -rp "Premi INVIO per chiudere..." _ || true' EXIT

exec > >(tee -a logs/start_v08_last.log) 2>&1

echo "============================================================"
echo "TRFMC START v0.8 SAFE"
echo "Data: $(date)"
echo "Root: $ROOT"
echo "============================================================"

echo
echo "=== 1. Stato Git ==="
git branch --show-current || true
git status --short || true

echo
echo "=== 2. Controllo sorgente v0.8 ==="
grep -n 'version=' backend/app/main.py || true
grep -n '"version":' backend/app/main.py || true

if [ ! -d backend/app/domains/rf_coverage ]; then
  echo
  echo "ERRORE: backend/app/domains/rf_coverage non esiste."
  echo "La patch v0.8 non è applicata. Serve rigenerare/applicare la patch v0.8."
  exit 1
fi

grep -R "rf_coverage" -n backend/app/main.py backend/app/domains/rf_coverage | head -n 60 || true

echo
echo "=== 3. Stop backend/frontend precedenti ==="
sudo docker rm -f \
  trfmc_backend_v02 \
  trfmc_backend_v03 \
  trfmc_backend_v04 \
  trfmc_backend_v05 \
  trfmc_backend_v06 \
  trfmc_backend_v07 \
  trfmc_backend_v08 \
  trfmc_frontend_v05 \
  trfmc_frontend_v06 \
  trfmc_frontend_v07 \
  trfmc_frontend_v08 \
  2>/dev/null || true

sudo fuser -k 8000/tcp 2>/dev/null || true

echo
echo "=== 4. Build backend v0.8 ==="
sudo docker build --no-cache -t trfmc-backend:v0.8 ./backend

echo
echo "=== 5. Start backend v0.8 ==="
sudo docker run -d --name trfmc_backend_v08 \
  -p 127.0.0.1:8000:8000 \
  -v "$PWD/runtime:/runtime" \
  -e TRFMC_ENV=dev \
  -e TRFMC_OPERATIONAL_MODE=SIMULATION_ONLY \
  -e TRFMC_RESTRICTED_ENABLED=false \
  -e TRFMC_SQLITE_PATH=/runtime/trfmc.db \
  trfmc-backend:v0.8

echo
echo "=== 6. Attesa backend ==="
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8000/api/health >/dev/null 2>&1; then
    echo "Backend raggiungibile."
    break
  fi
  sleep 1
done

echo
echo "=== 7. Log backend ==="
sudo docker logs trfmc_backend_v08 --tail 80 || true

echo
echo "=== 8. Test backend v0.8 ==="
curl -s http://127.0.0.1:8000/api/health | python3 -m json.tool || true
curl -s http://127.0.0.1:8000/api/rf-coverage/demo | python3 -m json.tool | head -n 80 || true
curl -s http://127.0.0.1:8000/api/persistence/status | python3 -m json.tool || true

echo
echo "=== 9. Start frontend v0.8 ==="
sudo docker run -d --name trfmc_frontend_v08 \
  -p 127.0.0.1:5173:5173 \
  -v "$PWD/frontend:/app" \
  -w /app \
  -e npm_config_cache=/tmp/.npm \
  --user "$(id -u):$(id -g)" \
  node:22-alpine \
  sh -c "npm install && npm run dev -- --host 0.0.0.0 --port 5173"

echo
echo "=== 10. Attesa frontend ==="
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:5173 >/dev/null 2>&1; then
    echo "Frontend raggiungibile."
    break
  fi
  sleep 1
done

echo
echo "============================================================"
echo "TRFMC v0.8 START COMPLETATO"
echo "Backend : http://127.0.0.1:8000/api/health"
echo "Frontend: http://127.0.0.1:5173"
echo "============================================================"
