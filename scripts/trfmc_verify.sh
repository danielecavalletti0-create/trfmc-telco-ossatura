#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/trfmc_env.sh"
cd "$TRFMC_ROOT"

echo "============================================================"
echo "TRFMC VERIFY"
echo "============================================================"

HEALTH="$(curl -fsS "$TRFMC_BACKEND_URL/api/health")"
echo "$HEALTH" | python3 -m json.tool

printf '%s' "$HEALTH" > /tmp/trfmc_verify_health.json

python3 - <<'PYCHECK'
import json
from pathlib import Path

data = json.loads(Path("/tmp/trfmc_verify_health.json").read_text())
version = data.get("version")
if version != "0.13.0":
    raise SystemExit(f"ERRORE: versione backend inattesa: {version}")
PYCHECK

curl -fsS "$TRFMC_BACKEND_URL/api/rf-field/demo" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/rf-coverage/demo" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/persistence/status" | python3 -m json.tool

curl -fsS "$TRFMC_FRONTEND_URL" >/dev/null

echo
echo "VERIFY OK"


echo
echo "=== OBSERVABILITY v0.13 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/observability/health-matrix" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/observability/runtime" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_FRONTEND_URL/observability_console_v13.html" >/dev/null
