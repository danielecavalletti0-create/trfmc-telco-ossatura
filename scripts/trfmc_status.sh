#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/trfmc_env.sh"
cd "$TRFMC_ROOT"

mkdir -p logs

{
  echo "============================================================"
  echo "TRFMC STATUS"
  echo "Data: $(date)"
  echo "============================================================"

  echo
  echo "=== GIT ==="
  git branch --show-current || true
  git status --short || true
  git log --oneline --decorate --graph --all -n 12 || true

  echo
  echo "=== DOCKER CONTAINERS ==="
  sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true

  echo
  echo "=== PORTS ==="
  sudo ss -ltnp | grep -E ":(${TRFMC_BACKEND_PORT}|${TRFMC_FRONTEND_PORT})\b" || true

  echo
  echo "=== BACKEND HEALTH ==="
  curl -fsS "$TRFMC_BACKEND_URL/api/health" | python3 -m json.tool || {
    echo "Backend non raggiungibile."
    sudo docker logs "$TRFMC_BACKEND_CONTAINER" --tail 120 2>/dev/null || true
  }

  echo
  echo "=== FRONTEND HTTP ==="
  curl -I "$TRFMC_FRONTEND_URL" || {
    echo "Frontend non raggiungibile."
    sudo docker logs "$TRFMC_FRONTEND_CONTAINER" --tail 120 2>/dev/null || true
  }

  echo
  echo "=== PERSISTENCE STATUS ==="
  curl -fsS "$TRFMC_BACKEND_URL/api/persistence/status" | python3 -m json.tool || true

  echo
  echo "=== RF FIELD QUICK ==="
  curl -fsS "$TRFMC_BACKEND_URL/api/rf-field/demo" | python3 -m json.tool | head -n 60 || true

  echo
  echo "=== RUNTIME DB ==="
  ls -lh runtime/ || true
} | tee logs/trfmc_status_last.log
