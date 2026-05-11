#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/trfmc_env.sh"
cd "$TRFMC_ROOT"

mkdir -p runtime logs

exec > >(tee logs/trfmc_start_last.log) 2>&1

echo "============================================================"
echo "TRFMC START HARDENED"
echo "Data: $(date)"
echo "Root: $TRFMC_ROOT"
echo "Backend image: $TRFMC_BACKEND_IMAGE"
echo "============================================================"

echo
echo "=== 1. Git state ==="
git branch --show-current || true
git status --short || true

echo
echo "=== 2. Stop container/porte precedenti ==="
sudo docker rm -f \
  trfmc_backend_v02 \
  trfmc_backend_v03 \
  trfmc_backend_v04 \
  trfmc_backend_v05 \
  trfmc_backend_v06 \
  trfmc_backend_v07 \
  trfmc_backend_v08 \
  trfmc_backend_v09 \
  trfmc_backend_v10 \
  trfmc_backend_v11 \
  trfmc_backend_v12 \
  trfmc_frontend_v05 \
  trfmc_frontend_v06 \
  trfmc_frontend_v07 \
  trfmc_frontend_v08 \
  trfmc_frontend_v09 \
  trfmc_frontend_v10 \
  trfmc_frontend_v11 \
  trfmc_frontend_v12 \
  2>/dev/null || true

sudo fuser -k "${TRFMC_BACKEND_PORT}/tcp" 2>/dev/null || true
sudo fuser -k "${TRFMC_FRONTEND_PORT}/tcp" 2>/dev/null || true

echo
echo "=== 3. Build backend v0.13 ==="
sudo docker build --no-cache -t "$TRFMC_BACKEND_IMAGE" ./backend

echo
echo "=== 4. Start backend ==="
sudo docker run -d --name "$TRFMC_BACKEND_CONTAINER" \
  -p "127.0.0.1:${TRFMC_BACKEND_PORT}:8000" \
  -v "$PWD/runtime:/runtime" \
  -e TRFMC_ENV="$TRFMC_ENV" \
  -e TRFMC_OPERATIONAL_MODE="$TRFMC_OPERATIONAL_MODE" \
  -e TRFMC_RESTRICTED_ENABLED="$TRFMC_RESTRICTED_ENABLED" \
  -e TRFMC_SQLITE_PATH="$TRFMC_SQLITE_PATH" \
  "$TRFMC_BACKEND_IMAGE"

echo
echo "=== 5. Attendo backend health ==="
for i in $(seq 1 60); do
  if curl -fsS "$TRFMC_BACKEND_URL/api/health" >/tmp/trfmc_health.json 2>/dev/null; then
    echo "Backend raggiungibile."
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "ERRORE: backend non risponde."
    sudo docker logs "$TRFMC_BACKEND_CONTAINER" --tail 160 || true
    exit 1
  fi
done

cat /tmp/trfmc_health.json | python3 -m json.tool

python3 - <<'PYCHECK'
import json
from pathlib import Path

data = json.loads(Path("/tmp/trfmc_health.json").read_text())
version = data.get("version")
if version != "0.13.0":
    raise SystemExit(f"ERRORE: backend non è v0.13.0, rilevato: {version}")
PYCHECK

echo
echo "=== 6. Start frontend ==="
sudo docker run -d --name "$TRFMC_FRONTEND_CONTAINER" \
  -p "127.0.0.1:${TRFMC_FRONTEND_PORT}:5173" \
  -v "$PWD/frontend:/app" \
  -w /app \
  -e npm_config_cache=/tmp/.npm \
  --user "$(id -u):$(id -g)" \
  node:22-alpine \
  sh -c "npm install && npm run dev -- --host 0.0.0.0 --port 5173"

echo
echo "=== 7. Attendo frontend ==="
for i in $(seq 1 90); do
  if curl -fsS "$TRFMC_FRONTEND_URL" >/dev/null 2>&1; then
    echo "Frontend raggiungibile."
    break
  fi
  sleep 1
  if [ "$i" -eq 90 ]; then
    echo "ERRORE: frontend non risponde."
    sudo docker logs "$TRFMC_FRONTEND_CONTAINER" --tail 200 || true
    exit 1
  fi
done

echo
echo "=== 8. Smoke test API ==="
curl -fsS "$TRFMC_BACKEND_URL/api/rf-field/demo" | python3 -m json.tool | head -n 60
curl -fsS "$TRFMC_BACKEND_URL/api/persistence/status" | python3 -m json.tool

echo
echo "============================================================"
echo "TRFMC AVVIATO"
echo "Backend : $TRFMC_BACKEND_URL/api/health"
echo "Frontend: $TRFMC_FRONTEND_URL"
echo "Log     : logs/trfmc_start_last.log"
echo "============================================================"
