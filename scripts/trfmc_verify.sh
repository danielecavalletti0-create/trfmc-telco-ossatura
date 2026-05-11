#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/trfmc_env.sh"
cd "$TRFMC_ROOT"

echo "============================================================"
echo "TRFMC VERIFY"
echo "============================================================"

HEALTH="$(curl -fsS "$TRFMC_BACKEND_URL/api/health")"
echo "$HEALTH" | python3 -m json.tool

echo "$HEALTH" | grep '"version": "0.12.0"' >/dev/null || {
  echo "ERRORE: versione backend inattesa."
  exit 1
}

curl -fsS "$TRFMC_BACKEND_URL/api/rf-field/demo" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/rf-coverage/demo" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/persistence/status" | python3 -m json.tool

curl -fsS "$TRFMC_FRONTEND_URL" >/dev/null

echo
echo "VERIFY OK"
