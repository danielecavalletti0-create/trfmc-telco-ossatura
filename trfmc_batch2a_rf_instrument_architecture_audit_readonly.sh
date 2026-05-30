#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2A_RF_INSTRUMENT_ARCHITECTURE_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
FILES="$OUT/rf_instrument_files.tsv"
PROPS="$OUT/rf_component_props_scan.tsv"
CANVAS="$OUT/rf_canvas_height_scan.tsv"
DATA="$OUT/rf_data_source_scan.tsv"
MATH="$OUT/rf_math_kpi_scan.tsv"
API="$OUT/rf_api_contract_scan.tsv"
THREED="$OUT/rf_3d_webgl_scan.tsv"
PLAN="$OUT/BATCH2A_RF_INSTRUMENT_ARCHITECTURE_PLAN.md"
BUILDLOG="$OUT/npm_build_batch2a_readonly.log"
HTTP="$OUT/http.tsv"

echo "============================================================"
echo "TRFMC_BATCH2A_RF_INSTRUMENT_ARCHITECTURE_AUDIT_READONLY"
echo "RF instruments · compactMode · real data · math · 3D audit"
echo "Timestamp: $TS"
echo "============================================================"

TARGETS=(
  "frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx"
  "frontend/src/rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3.tsx"
  "frontend/src/rf_instruments/instruments/RFInstrumentDockV4.tsx"
  "frontend/src/rf_instruments/instruments/TrueSpectrumAnalyzer.tsx"
)

echo
echo "=== 1) FILE GATE ==="
{
  echo -e "path\texists\tbytes\tlines\tsha256"
  for f in "${TARGETS[@]}"; do
    if [ -f "$f" ]; then
      printf "%s\tYES\t%s\t%s\t%s\n" \
        "$f" \
        "$(stat -c%s "$f")" \
        "$(wc -l < "$f" | tr -d ' ')" \
        "$(sha256sum "$f" | awk '{print $1}')"
    else
      printf "%s\tNO\t0\t0\tMISSING\n" "$f"
    fi
  done
} | tee "$FILES"

echo
echo "=== 2) COMPONENT PROPS / EXPORT SCAN ==="
{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "export function|function [A-Za-z0-9_]+\\(|interface .*Props|type .*Props|React\\.FC|props|compact|mode|variant|density|instrumentMode|dataMode" \
    "${TARGETS[@]}" 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,260)}'
} | tee "$PROPS"

echo
echo "=== 3) CANVAS / DIMENSION SCAN ==="
{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "canvas|height|width|style=|clientWidth|clientHeight|getContext|requestAnimationFrame|resize|DPR|devicePixelRatio" \
    "${TARGETS[@]}" frontend/src/rf_instruments 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,260)}'
} | tee "$CANVAS"

echo
echo "=== 4) DATA SOURCE / SYNTHETIC / REAL API SCAN ==="
{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "synthetic|mock|sample|samples|iq|IQ|sweep|fetch|axios|WebSocket|ws://|/api/rfpro|spectrum/sweep|worker|postMessage|Float32Array|ArrayBuffer" \
    "${TARGETS[@]}" frontend/src/rf_instruments backend 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,280)}'
} | tee "$DATA"

echo
echo "=== 5) MATH / KPI SCAN ==="
{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "FFT|fft|RBW|VBW|SNR|EVM|MER|OBW|ACLR|dBm|dB|noise|floor|window|Blackman|Harris|Hann|RMS|Peak|marker|Trace|detector|constellation|waterfall|channel power|link budget" \
    "${TARGETS[@]}" frontend/src/rf_instruments backend 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,280)}'
} | tee "$MATH"

echo
echo "=== 6) RF API CONTRACT SCAN ==="
{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "/api/rfpro|rfpro|spectrum/sweep|bridges|openapi|FastAPI|@app\\.|router\\.|WebSocket|websocket" \
    backend frontend/src 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,300)}'
} | tee "$API"

echo
echo "=== 7) 3D / WEBGL / THREE SCAN ==="
{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "three|THREE|WebGL|webgl|WebGLRenderer|Scene|PerspectiveCamera|OrbitControls|mesh|geometry|shader|antenna|pattern|3D|surface|waterfall3d" \
    frontend/src frontend/package.json 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,260)}'
} | tee "$THREED"

echo
echo "=== 8) BUILD CHECK READ-ONLY ==="
BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

echo
echo "=== 9) HTTP CONTRACT CHECK READ-ONLY ==="
cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"
  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi
  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
check_url "http://127.0.0.1:4181/openapi.json"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END{print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END{print c+0}' "$HTTP")"

FILE_FAILS="$(awk 'NR>1 && $2!="YES" {c++} END{print c+0}' "$FILES")"
PROPS_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PROPS")"
CANVAS_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$CANVAS")"
DATA_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$DATA")"
MATH_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$MATH")"
API_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$API")"
THREED_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$THREED")"

cat > "$PLAN" <<'MD'
# TRFMC Batch 2A — RF Instrument Architecture Plan

## Current state
The RF Signal Analyzer is mounted and verified. Batch1C improved density, but the next phase cannot be solved cleanly by CSS alone.

## Required engineering evolution

### 1. Component-level compact mode
Add controlled props to RF instrument components:
- `compactMode`
- `density`
- `instrumentMode`
- `dataMode`
- `mathOverlay`
- `realDataEnabled`

This replaces blind CSS overrides.

### 2. Real data adapter
Create a typed frontend adapter:
- `useRFSpectrumSweep()`
- source endpoint: `/api/rfpro/spectrum/sweep`
- fallback mode: synthetic IQ
- future mode: WebSocket binary IQ stream

### 3. Mathematical layer
Create a visible RF math/KPI panel:
- FFT bins
- RBW/VBW
- window function
- SNR
- EVM
- MER
- OBW
- ACLR
- channel power
- noise floor
- marker delta
- link budget later

### 4. 3D rendering
Do not insert random 3D decoration.
3D must represent engineering data:
- 3D waterfall surface
- antenna radiation pattern
- RF field heatmap
- multipath / Fresnel zone later
Use WebGL/three.js only if package is available or explicitly installed.

### 5. Instruments roadmap
Promote instruments in this order:
1. RF Signal Analyzer compact/real-data mode
2. RF/Microwave + Smith Chart
3. Antenna pattern / array explorer
4. Link budget / microwave path
5. Open5GS / UERANSIM Core/RAN binding
6. Cyber RF Intelligence evidence console

## Next mutation recommended
Batch 2B:
- modify `RFSignalAnalyzerWorkbenchV3.tsx`, `RFInstrumentDockV4.tsx`, `TrueSpectrumAnalyzer.tsx` to accept compact/data/math props;
- create `frontend/src/rf_instruments/hooks/useRFSpectrumSweep.ts`;
- no backend mutation;
- no public asset mutation;
- keep `/api/rfpro/spectrum/sweep` as readonly data source.
MD

RESULT="AUDIT_READY"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FILE_FAILS" != "0" ]; then RESULT="REVIEW_FILES"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2A_RF_INSTRUMENT_ARCHITECTURE_AUDIT_READONLY",
  "mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "file_gate": "$FILES",
  "component_props_scan": "$PROPS",
  "canvas_dimension_scan": "$CANVAS",
  "data_source_scan": "$DATA",
  "math_kpi_scan": "$MATH",
  "api_contract_scan": "$API",
  "three_webgl_scan": "$THREED",
  "plan": "$PLAN",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "file_failures": $FILE_FAILS,
  "props_total": $PROPS_TOTAL,
  "canvas_total": $CANVAS_TOTAL,
  "data_total": $DATA_TOTAL,
  "math_total": $MATH_TOTAL,
  "api_total": $API_TOTAL,
  "three_webgl_total": $THREED_TOTAL,
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2a_rf_instrument_architecture_audit"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,220p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_BATCH2A_RF_INSTRUMENT_ARCHITECTURE_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
