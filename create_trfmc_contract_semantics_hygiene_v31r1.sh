#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
APP="$ROOT/backend/readonly_bridge_v28/app.py"
PY="$ROOT/.venv_trfmc_backend_v28/bin/python"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_CONTRACT_SEMANTICS_HYGIENE_V31R1_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_CONTRACT_SEMANTICS_HYGIENE_V31R1_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_CONTRACT_SEMANTICS_HYGIENE_V31R1_$TS.tar.gz"

echo "============================================================"
echo "TRFMC CONTRACT SEMANTICS HYGIENE V31R1"
echo "backend-only · preserve global source · normalize contract-only fields"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$RELEASE_DIR/samples" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f "$APP" || { echo "ERRORE: app.py mancante"; exit 1; }
test -x "$PY" || { echo "ERRORE: venv Python mancante: $PY"; exit 1; }

test -f "$ROOT/runtime/quality/latest_contract_coverage_expansion_v31/summary.json" || {
  echo "ERRORE: V31 summary mancante"
  exit 1
}

test -f "$ROOT/runtime/quality/latest_backend_8000_guard_v29r1/summary.json" || {
  echo "ERRORE: V29R1 guard summary mancante"
  exit 1
}

systemctl --user is-active --quiet trfmc-readonly-backend-8000.service || {
  echo "ERRORE: backend 8000 non active"
  exit 1
}

systemctl --user is-active --quiet trfmc-backend-8000-guard.timer || {
  echo "ERRORE: backend guard timer non active"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/bandplan | grep -q "TRFMC_CONTRACT_COVERAGE_V31" || {
  echo "ERRORE: V31 contract non raggiungibile via 4181"
  exit 1
}

cp "$APP" "$RELEASE_DIR/app.py.bak_before_v31r1_$TS"

echo "OK: V31 presente, backend active, guard active"

echo
echo "=== PATCH SEMANTICS ==="

"$PY" - "$APP" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

replacements = {
    '"source": "contract_only"': '"data_source": "contract_only"',
    '"source": "synthetic_contract"': '"data_source": "synthetic_contract"',
    '"source": "contract"': '"data_source": "contract"',
}

changed = False
for old, new in replacements.items():
    if old in txt:
        txt = txt.replace(old, new)
        changed = True

marker = "# === TRFMC_V31R1_CONTRACT_SEMANTICS_HYGIENE ==="
if marker not in txt:
    txt = txt.rstrip() + "\n\n" + marker + "\n# Global response source must remain TRFMC_READONLY_BACKEND_BRIDGE_V28.\n# Contract-local provenance fields use data_source / analysis_source / catalog_source.\n"
    changed = True

p.write_text(txt, encoding="utf-8")
print("OK: semantics patch applied" if changed else "OK: no semantic replacement needed")
PY

echo
echo "=== SYNTAX CHECK ==="

"$PY" -m py_compile "$APP"

echo
echo "=== RESTART BACKEND ONLY ==="

systemctl --user restart trfmc-readonly-backend-8000.service
sleep 3

systemctl --user is-active trfmc-readonly-backend-8000.service

echo
echo "=== HTTP GATE V31R1 ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

ENDPOINTS=(
  "/api/health"
  "/api/mission/status"
  "/api/core/open5gs/status"
  "/api/ran/ueransim/status"
  "/api/rfpro/bandplan"
  "/api/rfpro/spectrum/sweep"
  "/api/rfpro/iq/capture"
  "/api/rfpro/bridges/soapy/probe"
  "/api/rfpro/uav/fhss"
  "/api/rfpro/uav/profiles"
  "/api/v585/ws/spectrum"
  "/api/access-trust/rat/demo"
  "/api/access-trust/wifi/demo"
  "/api/soc-noc/correlation/demo"
)

for base in http://127.0.0.1:8000 http://127.0.0.1:4181
do
  for ep in "${ENDPOINTS[@]}"
  do
    probe "$base$ep"
  done
done

column -t -s $'\t' "$HTTP_TSV" | sed -n '1,120p'

echo
echo "=== SAMPLE PAYLOADS ==="

for ep in \
  /api/rfpro/spectrum/sweep \
  /api/rfpro/uav/fhss \
  /api/rfpro/uav/profiles \
  /api/access-trust/rat/demo \
  /api/soc-noc/correlation/demo
do
  safe="$(echo "$ep" | sed 's#/#_#g' | sed 's/^_//')"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181$ep" | python3 -m json.tool > "$RELEASE_DIR/samples/${safe}.json"
done

echo
echo "=== SEMANTIC CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

get_json_field() {
  local ep="$1"
  local field="$2"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181$ep" | "$PY" - "$field" <<'PY'
import json, sys
field = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
print(d.get(field, ""))
PY
}

SOC_SOURCE="$(get_json_field /api/soc-noc/correlation/demo source)"
SOC_DATA_SOURCE="$(get_json_field /api/soc-noc/correlation/demo data_source)"
SWEEP_SOURCE="$(get_json_field /api/rfpro/spectrum/sweep source)"
FHSS_SOURCE="$(get_json_field /api/rfpro/uav/fhss source)"
RAT_SOURCE="$(get_json_field /api/access-trust/rat/demo source)"

FALLBACK_COUNT=0
BAD_SOURCE_COUNT=0

for ep in "${ENDPOINTS[@]}"
do
  payload="$(curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181$ep")"

  if echo "$payload" | grep -q 'trfmc-nginx-v21-api-fallback'; then
    FALLBACK_COUNT=$((FALLBACK_COUNT + 1))
  fi

  if echo "$payload" | grep -q '"contract_version": "TRFMC_CONTRACT_COVERAGE_V31"'; then
    src="$(echo "$payload" | "$PY" -c 'import json,sys; print(json.load(sys.stdin).get("source",""))' 2>/dev/null || true)"
    if [ "$src" != "TRFMC_READONLY_BACKEND_BRIDGE_V28" ]; then
      BAD_SOURCE_COUNT=$((BAD_SOURCE_COUNT + 1))
    fi
  fi
done

{
  grep -q "TRFMC_V31R1_CONTRACT_SEMANTICS_HYGIENE" "$APP" && echo "OK: V31R1 marker in app" || echo "MISS: V31R1 marker in app"
  ! grep -q '"source": "contract_only"' "$APP" && echo "OK: no contract_only source override in app" || echo "MISS: contract_only source override remains in app"
  ! grep -q '"source": "synthetic_contract"' "$APP" && echo "OK: no synthetic_contract source override in app" || echo "MISS: synthetic_contract source override remains in app"
  ! grep -q '"source": "contract"' "$APP" && echo "OK: no generic contract source override in app" || echo "MISS: generic contract source override remains in app"

  systemctl --user is-active --quiet trfmc-readonly-backend-8000.service && echo "OK: backend service active" || echo "MISS: backend service active"
  systemctl --user is-active --quiet trfmc-backend-8000-guard.timer && echo "OK: backend guard timer active" || echo "MISS: backend guard timer active"

  [ "$SOC_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: soc/noc global source preserved" || echo "MISS: soc/noc global source preserved"
  [ "$SOC_DATA_SOURCE" = "contract_only" ] && echo "OK: soc/noc data_source contract_only" || echo "MISS: soc/noc data_source contract_only"

  [ "$SWEEP_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: spectrum global source preserved" || echo "MISS: spectrum global source preserved"
  [ "$FHSS_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: fhss global source preserved" || echo "MISS: fhss global source preserved"
  [ "$RAT_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: access-trust global source preserved" || echo "MISS: access-trust global source preserved"

  [ "$FALLBACK_COUNT" -eq 0 ] && echo "OK: no V21 fallback in V31R1 endpoint set" || echo "MISS: V21 fallback present"
  [ "$BAD_SOURCE_COUNT" -eq 0 ] && echo "OK: all V31 contracts preserve global source" || echo "MISS: V31 contract bad source count $BAD_SOURCE_COUNT"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/contract_semantics_hygiene_manifest_v31r1.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_CONTRACT_SEMANTICS_HYGIENE_V31R1",
  "backend_url": "http://127.0.0.1:8000/",
  "proxy_url": "http://127.0.0.1:4181/",
  "app": "$APP",
  "semantic_rule": {
    "global_source": "TRFMC_READONLY_BACKEND_BRIDGE_V28",
    "contract_version": "TRFMC_CONTRACT_COVERAGE_V31",
    "local_contract_provenance_fields": [
      "data_source",
      "analysis_source",
      "catalog_source"
    ]
  },
  "safety": {
    "backend_only": true,
    "frontend_mutation": false,
    "dist_mutation": false,
    "nginx_mutation": false,
    "systemd_mutation": false,
    "no_sdr_tx_control": true,
    "no_file_write": true,
    "no_runtime_action_execution": true
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "fallback_count": $FALLBACK_COUNT,
  "bad_source_count": $BAD_SOURCE_COUNT,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  backend/readonly_bridge_v28/app.py \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_CONTRACT_SEMANTICS_HYGIENE_V31R1",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "fallback_count": $FALLBACK_COUNT,
  "bad_source_count": $BAD_SOURCE_COUNT,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_contract_semantics_hygiene_v31r1"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_contract_semantics_hygiene_v31r1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V31R1 CONTRACT SEMANTICS HYGIENE COMPLETATO"
echo "Summary: runtime/quality/latest_contract_semantics_hygiene_v31r1/summary.json"
echo "============================================================"
