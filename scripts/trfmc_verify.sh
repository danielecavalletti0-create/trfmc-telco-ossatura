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
if version != "0.22.0":
    raise SystemExit(f"ERRORE: versione backend inattesa: {version}")
PYCHECK

curl -fsS "$TRFMC_BACKEND_URL/api/rf-field/demo" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/rf-coverage/demo" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/persistence/status" | python3 -m json.tool

curl -fsS "$TRFMC_FRONTEND_URL" >/dev/null

echo
echo "VERIFY OK"


echo
echo "=== OBSERVABILITY v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/observability/health-matrix" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_BACKEND_URL/api/observability/runtime" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_FRONTEND_URL/observability_console_v13.html" >/dev/null


echo
echo "=== TIMELINE v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/timeline/evidence?limit=20" | python3 -m json.tool | head -n 100
curl -fsS "$TRFMC_BACKEND_URL/api/timeline/replay" | python3 -m json.tool | head -n 100
curl -fsS "$TRFMC_FRONTEND_URL/timeline_console_v14.html" >/dev/null


echo
echo "=== CORRELATION v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/correlation/graph?limit=50" | python3 -m json.tool | head -n 120
curl -fsS "$TRFMC_BACKEND_URL/api/correlation/incidents" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_FRONTEND_URL/mission_graph_console_v15.html" >/dev/null


echo
echo "=== SCENARIOS v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/scenarios/catalog" | python3 -m json.tool | head -n 120
curl -fsS "$TRFMC_BACKEND_URL/api/scenarios/runs" | python3 -m json.tool | head -n 80
curl -fsS "$TRFMC_FRONTEND_URL/scenario_runner_console_v16.html" >/dev/null


echo
echo "=== REPORTS v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/reports/latest" | python3 -m json.tool | head -n 140
curl -fsS "$TRFMC_FRONTEND_URL/scenario_report_console_v17.html" >/dev/null


echo
echo "=== SECURITY v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/security/posture" | python3 -m json.tool | head -n 120
curl -fsS "$TRFMC_BACKEND_URL/api/security/readiness" | python3 -m json.tool | head -n 120
curl -fsS "$TRFMC_FRONTEND_URL/security_console_v18.html" >/dev/null


echo
echo "=== PORTAL INDEX v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/portal/index" | python3 -m json.tool | head -n 140
curl -fsS "$TRFMC_BACKEND_URL/api/portal/health-summary" | python3 -m json.tool | head -n 120
curl -fsS "$TRFMC_FRONTEND_URL/portal_index_v19.html" >/dev/null


echo
echo "=== EVIDENCE VAULT v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/vault/status" | python3 -m json.tool | head -n 140
curl -fsS "$TRFMC_BACKEND_URL/api/vault/reports" | python3 -m json.tool | head -n 120
curl -fsS "$TRFMC_FRONTEND_URL/evidence_vault_console_v20.html" >/dev/null


echo
echo "=== OPERATIONAL BACKUP v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/ops/backup/status" | python3 -m json.tool | head -n 140
curl -fsS "$TRFMC_BACKEND_URL/api/ops/backup/list" | python3 -m json.tool | head -n 120
curl -fsS "$TRFMC_FRONTEND_URL/operational_backup_console_v21.html" >/dev/null


echo
echo "=== RESTORE READINESS v0.22 ==="
curl -fsS "$TRFMC_BACKEND_URL/api/restore/readiness" | python3 -m json.tool | head -n 160
curl -fsS "$TRFMC_BACKEND_URL/api/restore/drill" | python3 -m json.tool | head -n 160
curl -fsS "$TRFMC_FRONTEND_URL/restore_readiness_console_v22.html" >/dev/null
