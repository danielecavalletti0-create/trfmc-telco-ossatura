#!/usr/bin/env bash
set -Eeuo pipefail
set +H

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
OUT="$ROOT/frontend/public/runtime_golden_check_snapshot.json"
TMP="$OUT.tmp"

cd "$ROOT"

http_code() {
  curl -s -o /dev/null -w "%{http_code}" "$1" || echo "000"
}

safe_curl_json() {
  curl -s "$1" || echo "{}"
}

BRANCH="$(git branch --show-current 2>/dev/null || echo UNKNOWN)"
HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)"
TAGS="$(git tag --points-at HEAD 2>/dev/null | tr '\n' ' ')"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
STATUS_SHORT="$(git status --short 2>/dev/null || true)"

HEALTH_JSON="$(safe_curl_json http://127.0.0.1:8000/api/health)"
DOCS_JSON="$(safe_curl_json http://127.0.0.1:8000/api/docs/index)"
PORTAL_SUMMARY_JSON="$(safe_curl_json http://127.0.0.1:8000/api/portal/health-summary)"
PERSISTENCE_JSON="$(safe_curl_json http://127.0.0.1:8000/api/persistence/status)"

PORTAL_HTTP="$(http_code http://127.0.0.1:5173/portal_index_v19.html)"
HANDBOOK_HTTP="$(http_code http://127.0.0.1:5173/operator_handbook_console_v23.html)"
RESTORE_HTTP="$(http_code http://127.0.0.1:5173/restore_readiness_console_v22.html)"
BACKUP_HTTP="$(http_code http://127.0.0.1:5173/operational_backup_console_v21.html)"

DOCKER_PS="$(sudo -n docker ps --format '{{.Names}}	{{.Image}}	{{.Status}}	{{.Ports}}' 2>/dev/null || docker ps --format '{{.Names}}	{{.Image}}	{{.Status}}	{{.Ports}}' 2>/dev/null || true)"
PORTS="$(sudo -n ss -ltnp 2>/dev/null | grep -E ':(8000|5173)\b' || ss -ltnp 2>/dev/null | grep -E ':(8000|5173)\b' || true)"

LATEST_BACKUP="$(ls -1t /home/sentinel/Scaricati/trfmc_full_project_backup_v28_*.tar.gz 2>/dev/null | head -n 1 || true)"
LATEST_MANIFEST="$(ls -1t /home/sentinel/Scaricati/trfmc_full_project_backup_v28_*_manifest.txt 2>/dev/null | head -n 1 || true)"
BACKUP_SHA=""
if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP" ]; then
  BACKUP_SHA="$(sha256sum "$LATEST_BACKUP" | awk '{print $1}')"
fi

export BRANCH HEAD TAGS DIRTY_COUNT STATUS_SHORT
export HEALTH_JSON DOCS_JSON PORTAL_SUMMARY_JSON PERSISTENCE_JSON
export PORTAL_HTTP HANDBOOK_HTTP RESTORE_HTTP BACKUP_HTTP
export DOCKER_PS PORTS LATEST_BACKUP LATEST_MANIFEST BACKUP_SHA

python3 - <<'PY' > "$TMP"
import json
import os
from datetime import datetime, timezone

def parse_json_env(name):
    raw = os.environ.get(name, "{}")
    try:
        return json.loads(raw)
    except Exception:
        return {"parse_error": True, "raw": raw[:1000]}

def split_lines(value):
    return [line for line in value.splitlines() if line.strip()]

health = parse_json_env("HEALTH_JSON")
docs = parse_json_env("DOCS_JSON")
portal_summary = parse_json_env("PORTAL_SUMMARY_JSON")
persistence = parse_json_env("PERSISTENCE_JSON")

branch = os.environ.get("BRANCH", "UNKNOWN")
head = os.environ.get("HEAD", "UNKNOWN")
tags = os.environ.get("TAGS", "").strip()
dirty_count = int(os.environ.get("DIRTY_COUNT", "999") or "999")

portal_http = os.environ.get("PORTAL_HTTP", "000")
handbook_http = os.environ.get("HANDBOOK_HTTP", "000")
restore_http = os.environ.get("RESTORE_HTTP", "000")
backup_http = os.environ.get("BACKUP_HTTP", "000")

checks = [
    {
        "name": "backend_health_version",
        "ok": health.get("version") == "0.28.0",
        "value": health.get("version"),
        "expected": "0.28.0",
    },
    {
        "name": "docs_api_version",
        "ok": docs.get("version") == "0.28.0",
        "value": docs.get("version"),
        "expected": "0.28.0",
    },
    {
        "name": "docs_count",
        "ok": docs.get("count") == 6,
        "value": docs.get("count"),
        "expected": 6,
    },
    {
        "name": "portal_health_summary",
        "ok": portal_summary.get("overall_status") == "OK",
        "value": portal_summary.get("overall_status"),
        "expected": "OK",
    },
    {
        "name": "portal_index_http",
        "ok": portal_http == "200",
        "value": portal_http,
        "expected": "200",
    },
    {
        "name": "operator_handbook_http",
        "ok": handbook_http == "200",
        "value": handbook_http,
        "expected": "200",
    },
    {
        "name": "restore_console_http",
        "ok": restore_http == "200",
        "value": restore_http,
        "expected": "200",
    },
    {
        "name": "backup_console_http",
        "ok": backup_http == "200",
        "value": backup_http,
        "expected": "200",
    },
    {
        "name": "git_dirty_files",
        "ok": dirty_count == 0,
        "value": dirty_count,
        "expected": 0,
    },
    {
        "name": "backup_v28_present",
        "ok": bool(os.environ.get("LATEST_BACKUP")),
        "value": os.environ.get("LATEST_BACKUP"),
        "expected": "latest v28 backup present",
    },
]

overall_ok = all(c["ok"] for c in checks)

payload = {
    "service": "TRFMC_RUNTIME_STATUS_GOLDEN_CHECK_CONSOLE_V0_29",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "overall_status": "OK" if overall_ok else "ATTENTION_REQUIRED",
    "project": "Telco RF Mission Control Platform",
    "release_context": {
        "current_feature_branch": branch,
        "base_runtime_version": health.get("version"),
        "console_version": "0.29.0",
        "head": head,
        "tags_on_head": tags,
        "git_dirty_files": dirty_count,
    },
    "checks": checks,
    "runtime": {
        "health": health,
        "docs": docs,
        "portal_summary": portal_summary,
        "persistence": persistence,
    },
    "frontend_http": {
        "portal_index_v19": portal_http,
        "operator_handbook_v23": handbook_http,
        "restore_readiness_v22": restore_http,
        "operational_backup_v21": backup_http,
    },
    "host": {
        "docker_ps": split_lines(os.environ.get("DOCKER_PS", "")),
        "ports": split_lines(os.environ.get("PORTS", "")),
        "git_status_short": split_lines(os.environ.get("STATUS_SHORT", "")),
    },
    "backup": {
        "latest_backup": os.environ.get("LATEST_BACKUP", ""),
        "latest_manifest": os.environ.get("LATEST_MANIFEST", ""),
        "sha256": os.environ.get("BACKUP_SHA", ""),
    },
}
print(json.dumps(payload, indent=2, ensure_ascii=False))
PY

mv "$TMP" "$OUT"

python3 - <<PY
import json
from pathlib import Path
p = Path("$OUT")
d = json.loads(p.read_text(encoding="utf-8"))
print("snapshot=" + str(p))
print("overall_status=" + d.get("overall_status", "UNKNOWN"))
print("checks=" + str(len(d.get("checks", []))))
PY
