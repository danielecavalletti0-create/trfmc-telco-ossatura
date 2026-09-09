#!/usr/bin/env bash
set -Eeuo pipefail
set +H

source "$(dirname "$0")/trfmc_env.sh"

cd "$TRFMC_ROOT"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

EXPECTED_BACKEND_VERSION="0.30.0"

print_json_limited() {
  local file="$1"
  local lines="${2:-80}"

  if python3 -m json.tool "$file" > "$TMP_DIR/pretty.json"; then
    awk -v max="$lines" 'NR <= max { print } END { if (NR > max) print "... output truncated after " max " lines ..." }' "$TMP_DIR/pretty.json"
  else
    echo "ERRORE: JSON non valido in $file"
    cat "$file"
    return 1
  fi
}

fetch_json() {
  local name="$1"
  local url="$2"
  local outfile="$TMP_DIR/${name}.json"

  echo
  echo "=== $name ==="
  echo "GET $url"

  curl -fsS "$url" -o "$outfile"
  print_json_limited "$outfile" 80
}

assert_json_field() {
  local file="$1"
  local field="$2"
  local expected="$3"

  python3 - "$file" "$field" "$expected" <<'PY'
import json
import sys

path, field, expected = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(path, encoding="utf-8"))

value = data
for part in field.split("."):
    value = value[part]

if str(value) != expected:
    raise SystemExit(f"ASSERT FAIL: {field}={value!r}, expected={expected!r}")
PY
}

assert_http_200() {
  local name="$1"
  local url="$2"

  echo
  echo "=== HTTP $name ==="
  echo "HEAD $url"

  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" "$url")"
  echo "http_code=$code"

  if [ "$code" != "200" ]; then
    echo "ERRORE: $name HTTP $code"
    return 1
  fi
}

echo "============================================================"
echo "TRFMC VERIFY v0.31"
echo "Root: $TRFMC_ROOT"
echo "Backend: $TRFMC_BACKEND_URL"
echo "Frontend: $TRFMC_FRONTEND_URL"
echo "============================================================"

echo
echo "=== 1. Backend health ==="
HEALTH_FILE="$TMP_DIR/health.json"
curl -fsS "$TRFMC_BACKEND_URL/api/health" -o "$HEALTH_FILE"
print_json_limited "$HEALTH_FILE" 80
assert_json_field "$HEALTH_FILE" "status" "ok"
assert_json_field "$HEALTH_FILE" "version" "$EXPECTED_BACKEND_VERSION"

echo
echo "=== 2. RF Field demo ==="
RF_FIELD_FILE="$TMP_DIR/rf_field.json"
curl -fsS "$TRFMC_BACKEND_URL/api/rf-field/demo" -o "$RF_FIELD_FILE"
print_json_limited "$RF_FIELD_FILE" 80

echo
echo "=== 3. RF Coverage demo ==="
RF_COV_FILE="$TMP_DIR/rf_coverage.json"
curl -fsS "$TRFMC_BACKEND_URL/api/rf-coverage/demo" -o "$RF_COV_FILE"
print_json_limited "$RF_COV_FILE" 80

echo
echo "=== 4. Persistence status ==="
PERSIST_FILE="$TMP_DIR/persistence.json"
curl -fsS "$TRFMC_BACKEND_URL/api/persistence/status" -o "$PERSIST_FILE"
print_json_limited "$PERSIST_FILE" 80
assert_json_field "$PERSIST_FILE" "exists" "True"

echo
echo "=== 5. Docs API ==="
DOCS_FILE="$TMP_DIR/docs.json"
curl -fsS "$TRFMC_BACKEND_URL/api/docs/index" -o "$DOCS_FILE"
print_json_limited "$DOCS_FILE" 80
assert_json_field "$DOCS_FILE" "version" "$EXPECTED_BACKEND_VERSION"
assert_json_field "$DOCS_FILE" "count" "6"

echo
echo "=== 6. Portal health summary ==="
PORTAL_HEALTH_FILE="$TMP_DIR/portal_health.json"
curl -fsS "$TRFMC_BACKEND_URL/api/portal/health-summary" -o "$PORTAL_HEALTH_FILE"
print_json_limited "$PORTAL_HEALTH_FILE" 80
assert_json_field "$PORTAL_HEALTH_FILE" "overall_status" "OK"
assert_json_field "$PORTAL_HEALTH_FILE" "version" "$EXPECTED_BACKEND_VERSION"

echo
echo "=== 7. Portal index ==="
PORTAL_INDEX_FILE="$TMP_DIR/portal_index.json"
curl -fsS "$TRFMC_BACKEND_URL/api/portal/index" -o "$PORTAL_INDEX_FILE"
print_json_limited "$PORTAL_INDEX_FILE" 80
assert_json_field "$PORTAL_INDEX_FILE" "version" "$EXPECTED_BACKEND_VERSION"

echo
echo "=== 8. Observability health matrix ==="
OBS_FILE="$TMP_DIR/observability.json"
curl -fsS "$TRFMC_BACKEND_URL/api/observability/health-matrix" -o "$OBS_FILE"
print_json_limited "$OBS_FILE" 80
assert_json_field "$OBS_FILE" "overall_status" "OK"

echo
echo "=== 9. Frontend pages ==="
assert_http_200 "frontend-root" "$TRFMC_FRONTEND_URL/"
assert_http_200 "portal-index" "$TRFMC_FRONTEND_URL/portal_index_v19.html"
assert_http_200 "operator-handbook" "$TRFMC_FRONTEND_URL/operator_handbook_console_v23.html"
assert_http_200 "golden-check" "$TRFMC_FRONTEND_URL/runtime_golden_check_console_v29.html"
assert_http_200 "golden-snapshot" "$TRFMC_FRONTEND_URL/runtime_golden_check_snapshot.json"

echo
echo "=== 10. Docker containers ==="
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -E 'trfmc|NAMES' || true

echo
echo "=== 11. Listening ports ==="
sudo ss -ltnp | grep -E ':(8000|5173)\b' || true

echo
echo "============================================================"
echo "VERIFY OK"
echo "============================================================"
