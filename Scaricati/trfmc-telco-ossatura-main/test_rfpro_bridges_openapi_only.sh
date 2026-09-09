#!/usr/bin/env bash
set -Eeuo pipefail
set +H

API="${API:-http://127.0.0.1:8000}"

echo "============================================================"
echo "TEST RF PRO BRIDGE OPENAPI ONLY"
echo "============================================================"

TMP_OPENAPI="$(mktemp)"
trap 'rm -f "$TMP_OPENAPI"' EXIT

curl -sS "$API/openapi.json" -o "$TMP_OPENAPI"

python3 - "$TMP_OPENAPI" <<'PY2'
import sys, json

with open(sys.argv[1], "r", encoding="utf-8") as f:
    j = json.load(f)

routes = sorted(p for p in j.get("paths", {}) if "/api/rfpro/bridges" in p)

for p in routes:
    print(p)

print()
print("COUNT_BRIDGE_ROUTES=", len(routes))

required = [
    "/api/rfpro/bridges/state",
    "/api/rfpro/bridges/gnuradio/export",
    "/api/rfpro/bridges/sdrpp/export",
    "/api/rfpro/bridges/files",
]

missing = [p for p in required if p not in routes]
if missing:
    print("MISSING_BRIDGE_ROUTES=", missing)
    sys.exit(2)

print("OK: bridge routes presenti")
PY2
