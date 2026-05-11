#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

echo "============================================================"
echo "TRFMC START"
echo "Root: $ROOT"
echo "============================================================"

mkdir -p runtime

echo
echo "1) Verifico immagine backend trfmc-backend:v0.5"
if ! sudo docker image inspect trfmc-backend:v0.5 >/dev/null 2>&1; then
  echo "Immagine non trovata. Build backend v0.5..."
  sudo docker build -t trfmc-backend:v0.5 ./backend
else
  echo "Immagine backend già presente."
fi

echo
echo "2) Pulizia container precedenti"
sudo docker rm -f trfmc_backend_v05 trfmc_frontend_v05 2>/dev/null || true

echo
echo "3) Avvio backend"
sudo docker run -d --name trfmc_backend_v05 \
  -p 127.0.0.1:8000:8000 \
  -v "$PWD/runtime:/runtime" \
  -e TRFMC_ENV=dev \
  -e TRFMC_OPERATIONAL_MODE=SIMULATION_ONLY \
  -e TRFMC_RESTRICTED_ENABLED=false \
  -e TRFMC_SQLITE_PATH=/runtime/trfmc.db \
  trfmc-backend:v0.5

echo
echo "4) Attendo backend /api/health"
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8000/api/health >/dev/null 2>&1; then
    echo "Backend OK."
    break
  fi
  sleep 1
  if [ "$i" -eq 30 ]; then
    echo "ERRORE: backend non risponde."
    sudo docker logs trfmc_backend_v05 --tail 80 || true
    exit 1
  fi
done

echo
echo "5) Sistemo permessi frontend"
sudo chown -R "$(id -u):$(id -g)" frontend 2>/dev/null || true

echo
echo "6) Avvio frontend"
sudo docker run -d --name trfmc_frontend_v05 \
  -p 127.0.0.1:5173:5173 \
  -v "$PWD/frontend:/app" \
  -w /app \
  -e npm_config_cache=/tmp/.npm \
  --user "$(id -u):$(id -g)" \
  node:22-alpine \
  sh -c "npm install && npm run dev -- --host 0.0.0.0 --port 5173"

echo
echo "7) Attendo frontend"
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:5173 >/dev/null 2>&1; then
    echo "Frontend OK."
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "ATTENZIONE: frontend non ancora raggiungibile. Log:"
    sudo docker logs trfmc_frontend_v05 --tail 100 || true
    exit 1
  fi
done

echo
echo "============================================================"
echo "TRFMC AVVIATO"
echo "Backend : http://127.0.0.1:8000/api/health"
echo "Frontend: http://127.0.0.1:5173"
echo "============================================================"
