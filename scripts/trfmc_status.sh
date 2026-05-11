#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

echo "============================================================"
echo "TRFMC STATUS"
echo "============================================================"

echo
echo "=== GIT ==="
git branch --show-current || true
git status --short || true
git log --oneline --decorate --graph --all -n 8 || true

echo
echo "=== DOCKER CONTAINERS ==="
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true

echo
echo "=== PORTS ==="
sudo ss -ltnp | grep -E ':(8000|5173)\b' || true

echo
echo "=== BACKEND HEALTH ==="
curl -fsS http://127.0.0.1:8000/api/health | python3 -m json.tool || {
  echo "Backend non raggiungibile."
  sudo docker logs trfmc_backend_v05 --tail 80 2>/dev/null || true
}

echo
echo "=== PERSISTENCE STATUS ==="
curl -fsS http://127.0.0.1:8000/api/persistence/status | python3 -m json.tool || true

echo
echo "=== TIME CURSOR ==="
curl -fsS http://127.0.0.1:8000/api/time-cursor/status | python3 -m json.tool || true

echo
echo "=== FRONTEND ==="
if curl -fsS http://127.0.0.1:5173 >/dev/null 2>&1; then
  echo "Frontend OK: http://127.0.0.1:5173"
else
  echo "Frontend non raggiungibile."
  sudo docker logs trfmc_frontend_v05 --tail 80 2>/dev/null || true
fi

echo
echo "=== RUNTIME DB ==="
ls -lh runtime/ || true
