#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2D_RF_REAL_DATA_ROUTE_DISCOVERY_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
OPENAPI_4181="$OUT/openapi_4181.json"
OPENAPI_8000="$OUT/openapi_8000.json"
ROUTES_SRC="$OUT/rf_routes_source_scan.tsv"
ROUTES_OPENAPI="$OUT/rf_routes_openapi_scan.tsv"
CANDIDATE_TESTS="$OUT/rf_candidate_endpoint_tests.tsv"
CANDIDATE_JSON_DIR="$OUT/candidate_json"
PLAN="$OUT/BATCH2D_RF_REAL_DATA_ROUTE_DISCOVERY_PLAN.md"

mkdir -p "$CANDIDATE_JSON_DIR"

echo "============================================================"
echo "TRFMC_BATCH2D_RF_REAL_DATA_ROUTE_DISCOVERY_READONLY"
echo "Read-only route discovery · no source/backend/index/public mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) FETCH OPENAPI 4181 / 8000 ==="

curl -sS -L --max-time 8 "http://127.0.0.1:4181/openapi.json" -o "$OPENAPI_4181" || true
curl -sS -L --max-time 8 "http://127.0.0.1:8000/openapi.json" -o "$OPENAPI_8000" || true

python3 - "$OPENAPI_4181" "$OPENAPI_8000" "$ROUTES_OPENAPI" <<'PY'
import json, sys
from pathlib import Path

out = Path(sys.argv[3])
rows = []

for label, path in [("4181", Path(sys.argv[1])), ("8000", Path(sys.argv[2]))]:
    if not path.exists() or path.stat().st_size == 0:
        continue
    try:
        data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except Exception as exc:
        rows.append([label, "OPENAPI_PARSE_ERROR", "-", str(exc)[:180]])
        continue

    paths = data.get("paths", {})
    for route, methods in sorted(paths.items()):
        hay = route.lower() + " " + json.dumps(methods).lower()
        if any(k in hay for k in [
            "rf", "spectrum", "sweep", "hackrf", "iq", "waterfall",
            "constellation", "fft", "signal", "v585", "realtime"
        ]):
            rows.append([label, route, ",".join(sorted(methods.keys())), json.dumps(methods)[:240]])

with out.open("w", encoding="utf-8") as f:
    f.write("port\troute\tmethods\tcontext\n")
    for row in rows:
        f.write("\t".join(row).replace("\n", " ") + "\n")
PY

column -t -s $'\t' "$ROUTES_OPENAPI" | sed -n '1,160p'

echo
echo "=== 2) SOURCE ROUTE SCAN ==="

{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "APIRouter|@app\\.|@router\\.|/api/|websocket|WebSocket|hackrf_sweep|REAL_HACKRF_SWEEP|sweep_once|parse_hackrf_sweep|spectrum|waterfall|iq|fft" \
    backend frontend/src 2>/dev/null \
    | grep -Ei "rf|spectrum|sweep|hackrf|iq|waterfall|constellation|fft|signal|v585|realtime|websocket" \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,300)}'
} | tee "$ROUTES_SRC" | sed -n '1,180p'

echo
echo "=== 3) CANDIDATE ENDPOINT TESTS ==="

cat > "$CANDIDATE_TESTS" <<'TSV'
url	status	bytes	json_parse	numeric_arrays	best_array_len	has_metrics	classification
TSV

test_candidate() {
  local url="$1"
  local safe
  safe="$(echo "$url" | sed 's#[/:?&=]#_#g')"
  local raw="$CANDIDATE_JSON_DIR/${safe}.raw"
  local json="$CANDIDATE_JSON_DIR/${safe}.json"

  local code
  code="$(curl -sS -L --max-time 10 -o "$raw" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$raw" | tr -d ' ')"

  python3 - "$url" "$code" "$bytes" "$raw" "$json" "$CANDIDATE_TESTS" <<'PY'
import json, sys, re
from pathlib import Path

url, code, bytes_count = sys.argv[1], sys.argv[2], sys.argv[3]
raw_path, json_path, out_path = Path(sys.argv[4]), Path(sys.argv[5]), Path(sys.argv[6])

raw = raw_path.read_text(encoding="utf-8", errors="replace")
parsed = None
json_parse = "NO"

try:
    parsed = json.loads(raw)
    json_parse = "YES"
except Exception:
    parsed = {"rawText": raw}

json_path.write_text(json.dumps(parsed, indent=2, ensure_ascii=False), encoding="utf-8")

numeric_arrays = []
metrics_keys = set()

def walk(x):
    if isinstance(x, dict):
        for k, v in x.items():
            kl = k.lower()
            if any(m in kl for m in ["snr", "evm", "mer", "obw", "aclr", "dbm", "noise", "power"]):
                metrics_keys.add(k)
            walk(v)
    elif isinstance(x, list):
        nums = []
        for item in x:
            if isinstance(item, (int, float)):
                nums.append(float(item))
            elif isinstance(item, list) and len(item) >= 2 and isinstance(item[1], (int, float)):
                nums.append(float(item[1]))
            elif isinstance(item, dict):
                for key in ["power", "dbm", "y", "value", "amp", "amplitude"]:
                    if isinstance(item.get(key), (int, float)):
                        nums.append(float(item[key]))
                        break
        if len(nums) >= 16:
            numeric_arrays.append(len(nums))
        for item in x:
            walk(item)

walk(parsed)

best = max(numeric_arrays) if numeric_arrays else 0
has_metrics = "YES" if metrics_keys else "NO"

classification = "NO_DATA"
if code == "000":
    classification = "UNREACHABLE"
elif code != "200":
    classification = "NON_200"
elif best >= 256:
    classification = "TRACE_CANDIDATE_STRONG"
elif best >= 16:
    classification = "TRACE_CANDIDATE_WEAK"
elif has_metrics == "YES":
    classification = "METADATA_METRICS_ONLY"
elif json_parse == "YES":
    classification = "JSON_METADATA_ONLY"

with out_path.open("a", encoding="utf-8") as f:
    f.write(f"{url}\t{code}\t{bytes_count}\t{json_parse}\t{len(numeric_arrays)}\t{best}\t{has_metrics}\t{classification}\n")
PY
}

# Contratti già noti
test_candidate "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
test_candidate "http://127.0.0.1:8000/api/rfpro/spectrum/sweep"

# Possibili rotte RF realtime emerse da backend/routers/realtime_v585.py
test_candidate "http://127.0.0.1:4181/api/v585/spectrum"
test_candidate "http://127.0.0.1:8000/api/v585/spectrum"
test_candidate "http://127.0.0.1:4181/api/v585/realtime/spectrum"
test_candidate "http://127.0.0.1:8000/api/v585/realtime/spectrum"
test_candidate "http://127.0.0.1:4181/api/v585/sweep"
test_candidate "http://127.0.0.1:8000/api/v585/sweep"
test_candidate "http://127.0.0.1:4181/api/v585/sweep_once"
test_candidate "http://127.0.0.1:8000/api/v585/sweep_once"
test_candidate "http://127.0.0.1:4181/api/v585/files"
test_candidate "http://127.0.0.1:8000/api/v585/files"

# Possibili query param conservative, senza TX e senza mutazione
test_candidate "http://127.0.0.1:4181/api/v585/spectrum?use_hackrf=false"
test_candidate "http://127.0.0.1:8000/api/v585/spectrum?use_hackrf=false"
test_candidate "http://127.0.0.1:4181/api/v585/sweep?use_hackrf=false"
test_candidate "http://127.0.0.1:8000/api/v585/sweep?use_hackrf=false"
test_candidate "http://127.0.0.1:4181/api/v585/sweep_once?use_hackrf=false"
test_candidate "http://127.0.0.1:8000/api/v585/sweep_once?use_hackrf=false"

column -t -s $'\t' "$CANDIDATE_TESTS"

echo
echo "=== 4) PLAN ==="

cat > "$PLAN" <<'MD'
# TRFMC Batch 2D — RF Real Data Route Discovery

## Diagnosi
`/api/rfpro/spectrum/sweep` risponde 200, ma oggi restituisce un contratto read-only descrittivo, non una traccia RF. Per questo il frontend mostra `API DERIVED`, `Bins 0`, KPI non valorizzati.

## Criterio di promozione endpoint
Un endpoint può diventare sorgente RF reale solo se restituisce almeno una delle seguenti strutture:
- array numerico >= 256 punti;
- lista di punti `{freq, dbm}` / `{frequency, power}`;
- metriche RF esplicite: SNR, EVM, MER, OBW, ACLR, channel power, noise floor;
- WebSocket documentato con stream spectrum/IQ.

## Decisione dopo questo audit
- Se esiste un `TRACE_CANDIDATE_STRONG`, Batch 2E aggiorna `useRFSpectrumSweep()` per consumarlo.
- Se non esiste, Batch 2E deve creare un endpoint bridge read-only normalizzato, senza TX, senza SDR control, senza mutazione sistema.
- Se esiste solo WebSocket, Batch 2E introduce adapter WebSocket read-only e fallback HTTP.
MD

cat "$PLAN"

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$OUT/npm_build_batch2d_readonly.log" 2>&1 || BUILD_RESULT="FAIL"

HTTP_STRONG="$(awk 'NR>1 && $8=="TRACE_CANDIDATE_STRONG" {c++} END{print c+0}' "$CANDIDATE_TESTS")"
HTTP_WEAK="$(awk 'NR>1 && $8=="TRACE_CANDIDATE_WEAK" {c++} END{print c+0}' "$CANDIDATE_TESTS")"
HTTP_METRICS="$(awk 'NR>1 && $8=="METADATA_METRICS_ONLY" {c++} END{print c+0}' "$CANDIDATE_TESTS")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2D_RF_REAL_DATA_ROUTE_DISCOVERY_READONLY",
  "mutation": false,
  "backend_mutation": false,
  "frontend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "openapi_4181": "$OPENAPI_4181",
  "openapi_8000": "$OPENAPI_8000",
  "routes_openapi": "$ROUTES_OPENAPI",
  "routes_source_scan": "$ROUTES_SRC",
  "candidate_endpoint_tests": "$CANDIDATE_TESTS",
  "candidate_json_dir": "$CANDIDATE_JSON_DIR",
  "plan": "$PLAN",
  "build_result": "$BUILD_RESULT",
  "trace_candidate_strong": $HTTP_STRONG,
  "trace_candidate_weak": $HTTP_WEAK,
  "metadata_metrics_only": $HTTP_METRICS,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && echo AUDIT_READY || echo REVIEW_BUILD)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2d_rf_real_data_route_discovery"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH2D_RF_REAL_DATA_ROUTE_DISCOVERY_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
