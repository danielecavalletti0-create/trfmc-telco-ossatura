#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRFMC STOP"
echo "============================================================"

sudo docker rm -f \
  trfmc_backend_v02 \
  trfmc_backend_v03 \
  trfmc_backend_v04 \
  trfmc_backend_v05 \
  trfmc_frontend_v02 \
  trfmc_frontend_v05 \
  2>/dev/null || true

echo
echo "Container TRFMC fermati."
echo
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true
