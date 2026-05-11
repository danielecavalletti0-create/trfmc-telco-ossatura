#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/trfmc_env.sh"
cd "$TRFMC_ROOT"

mkdir -p logs

{
  echo "============================================================"
  echo "TRFMC STOP"
  echo "Data: $(date)"
  echo "============================================================"

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
    trfmc_backend_v13 \
    trfmc_backend_v14 \
    trfmc_backend_v15 \
    trfmc_backend_v16 \
    trfmc_backend_v17 \
    trfmc_backend_v18 \
    trfmc_backend_v19 \
    trfmc_backend_v20 \
    trfmc_backend_v21 \
    trfmc_frontend_v05 \
    trfmc_frontend_v06 \
    trfmc_frontend_v07 \
    trfmc_frontend_v08 \
    trfmc_frontend_v09 \
    trfmc_frontend_v10 \
    trfmc_frontend_v11 \
    trfmc_frontend_v12 \
    trfmc_frontend_v13 \
    trfmc_frontend_v14 \
    trfmc_frontend_v15 \
    trfmc_frontend_v16 \
    trfmc_frontend_v17 \
    trfmc_frontend_v18 \
    trfmc_frontend_v19 \
    trfmc_frontend_v20 \
    trfmc_frontend_v21 \
    2>/dev/null || true

  sudo fuser -k "${TRFMC_BACKEND_PORT}/tcp" 2>/dev/null || true
  sudo fuser -k "${TRFMC_FRONTEND_PORT}/tcp" 2>/dev/null || true

  echo
  echo "Container TRFMC fermati."
  sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true

  echo
  echo "Porte residue:"
  sudo ss -ltnp | grep -E ":(${TRFMC_BACKEND_PORT}|${TRFMC_FRONTEND_PORT})\b" || true
} | tee logs/trfmc_stop_last.log
