#!/usr/bin/env bash
set -Eeuo pipefail
set +H

API="${API:-http://127.0.0.1:8000}"

echo "============================================================"
echo "TEST RF PRO OPENAPI ROUTES"
echo "============================================================"

TMP_OPENAPI="$(mktemp)"
trap 'rm -f "$TMP_OPENAPI"' EXIT

echo
echo "== DOWNLOAD OPENAPI JSON =="
curl -sS "$API/openapi.json" -o "$TMP_OPENAPI"

python3 -m json.tool "$TMP_OPENAPI" >/dev/null
echo "OK: openapi.json valido"

echo
echo "== RFPRO ROUTES =="
python3 - "$TMP_OPENAPI" <<'PY2'
import sys, json

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    j = json.load(f)

routes = sorted(p for p in j.get("paths", {}) if "/api/rfpro" in p)

for p in routes:
    print(p)

print()
print("COUNT_RFPRO_ROUTES=", len(routes))

required = [
    "/api/rfpro/console",
    "/api/rfpro/state",
    "/api/rfpro/spectrum/sweep",
    "/api/rfpro/bridges/state",
    "/api/rfpro/bridges/gnuradio/export",
    "/api/rfpro/bridges/sdrpp/export",
]

missing = [p for p in required if p not in routes]
if missing:
    print("MISSING_HTTP_ROUTES=", missing)
    sys.exit(2)

print("OK: rotte HTTP principali presenti")
PY2

echo
echo "== BRIDGE STATE QUICK =="
curl -sS "$API/api/rfpro/bridges/state" | python3 -m json.tool | sed -n '1,120p'
