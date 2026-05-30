#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V51R2_ENTERPRISE_GAP_AUDIT_$TS"
REL="$BASE/runtime/releases/TRFMC_V51R2_ENTERPRISE_GAP_AUDIT_$TS"

mkdir -p "$OUT" "$REL"
cd "$BASE"

echo "============================================================"
echo "TRFMC_V51R2_ENTERPRISE_GAP_AUDIT"
echo "Read-only engineering audit · no frontend/backend mutation"
echo "Timestamp: $TS"
echo "============================================================"

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
PORTS="$OUT/ports.txt"
TREE="$OUT/project_tree_focus.txt"
GREP_MARKERS="$OUT/markers_and_sections.txt"
PLACEHOLDERS="$OUT/placeholders_todo_mock_stub.txt"
EXTERNAL="$OUT/external_references.txt"
ASSETS="$OUT/assets_inventory.txt"
BUILDLOG="$OUT/npm_build_v51r2.log"
DIST="$OUT/dist_inventory.txt"
NEXT="$OUT/NEXT_V51R3_IMPLEMENTATION_TARGETS.md"

echo
echo "=== 1) PORTE ATTIVE ==="
ss -ltnp | grep -E ':(5173|4181|8000)\b' | tee "$PORTS" || true

echo
echo "=== 2) HTTP GATE ==="
cat > "$HTTP" <<HTTPHDR
url	status	bytes
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 5 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  rm -f "$tmp"
  printf "%s\t%s\t%s\n" "$url" "$code" "$bytes" | tee -a "$HTTP"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#visual-assets"
check_url "http://127.0.0.1:5173/#scenario-knowledge"
check_url "http://127.0.0.1:5173/#navigation-architecture"
check_url "http://127.0.0.1:5173/#command-center"
check_url "http://127.0.0.1:5173/#dynamic-scenarios"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:4181/api/mission/status"
check_url "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
check_url "http://127.0.0.1:8000/api/health"

echo
echo "=== 3) FILE STRATEGICI ==="
{
  echo "BASE=$BASE"
  echo
  find frontend -maxdepth 4 -type f \
    \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' -o -name '*.css' -o -name '*.json' -o -name '*.html' \) \
    | sort \
    | sed -n '1,500p'
} | tee "$TREE"

echo
echo "=== 4) MARKER / SEZIONI / ROUTE HASH ==="
{
  echo "---- full-engineering / section resolver ----"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=runtime \
    "full-engineering-stack\|mission-overview\|visual-assets\|scenario-knowledge\|navigation-architecture\|command-center\|dynamic-scenarios\|ResolveEnrichmentSection\|activeSection" \
    frontend/src frontend/public 2>/dev/null || true

  echo
  echo "---- V tags ----"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=runtime \
    "V44\|V46\|V49\|V51\|V42" \
    frontend/src frontend/public 2>/dev/null || true
} | tee "$GREP_MARKERS"

echo
echo "=== 5) PLACEHOLDER / TODO / MOCK / STUB / LOREM ==="
{
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=runtime \
    -E "TODO|FIXME|placeholder|coming soon|lorem|mock|stub|dummy|fake|demo only|not implemented|implementare|da completare" \
    frontend/src frontend/public backend 2>/dev/null || true
} | tee "$PLACEHOLDERS"

echo
echo "=== 6) RIFERIMENTI ESTERNI / CDN / URL REMOTI ==="
{
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=runtime \
    -E "https?://|cdn\.|unpkg|jsdelivr|googleapis|fonts\.gstatic|cdnjs|bootstrapcdn" \
    frontend/src frontend/public frontend/*.html backend 2>/dev/null || true
} | tee "$EXTERNAL"

echo
echo "=== 7) INVENTARIO ASSET VISIVI ==="
{
  echo "---- immagini / video / font / svg / wasm ----"
  find frontend/public frontend/src -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.svg' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.woff' -o -iname '*.woff2' -o -iname '*.wasm' \) \
    -printf "%s\t%p\n" 2>/dev/null | sort -nr || true
} | tee "$ASSETS"

echo
echo "=== 8) BUILD VALIDATION ==="
if [ -d frontend ]; then
  (
    cd frontend
    npm run build
  ) > "$BUILDLOG" 2>&1 && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"
else
  BUILD_RESULT="FAIL_NO_FRONTEND_DIR"
fi

echo "BUILD_RESULT=$BUILD_RESULT"
tail -n 80 "$BUILDLOG" || true

echo
echo "=== 9) DIST INVENTORY ==="
{
  if [ -d frontend/dist ]; then
    find frontend/dist -type f -printf "%s\t%p\n" | sort -nr
  else
    echo "NO_DIST"
  fi
} | tee "$DIST"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"
PLACEHOLDER_COUNT="$(wc -l < "$PLACEHOLDERS" | tr -d ' ')"
EXTERNAL_COUNT="$(wc -l < "$EXTERNAL" | tr -d ' ')"

cat > "$NEXT" <<MD
# TRFMC V51R3 - Implementation Targets

## Baseline
- V51R1 safe start: frontend/API online.
- V49R3 marker runtime QA: PASS.
- Current V51R2 audit timestamp: $TS.

## Priorità chirurgiche per la prossima mutazione

### P0 — Non rompere ciò che funziona
- Conservare entrypoint ufficiale: \`http://127.0.0.1:5173\`.
- Conservare sezioni hash già validate:
  - \`#mission-overview\`
  - \`#visual-assets\`
  - \`#scenario-knowledge\`
  - \`#navigation-architecture\`
  - \`#command-center\`
  - \`#dynamic-scenarios\`
  - \`#full-engineering-stack\`

### P1 — Eliminare placeholder reali
Controllare:
- \`$PLACEHOLDERS\`

### P2 — Rendere il portale air-gapped / T&M-grade
Controllare:
- \`$EXTERNAL\`

### P3 — Rafforzare asset visivi e simulativi
Controllare:
- \`$ASSETS\`

### P4 — Build e qualità
Controllare:
- \`$BUILDLOG\`
- \`$DIST\`

## Esito automatico V51R2
- HTTP non 200: $HTTP_NON_200
- HTTP zero bytes: $HTTP_ZERO_BYTES
- Build result: $BUILD_RESULT
- Placeholder/TODO/mock/stub lines: $PLACEHOLDER_COUNT
- External/CDN/remote URL lines: $EXTERNAL_COUNT

## Prossimo step consigliato
Se HTTP=OK e BUILD=PASS:
1. Creare V51R3 con mutazione controllata solo su UI/content.
2. Aggiungere una sezione "Engineering Completeness Matrix".
3. Collegare ogni modulo TRFMC a:
   - teoria RF/TLC,
   - simulatore,
   - endpoint API,
   - asset visuale,
   - scenario operativo,
   - criterio di collaudo.
4. Ripetere QA DOM + screenshot.
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_V51R2_ENTERPRISE_GAP_AUDIT",
  "frontend_mutation": false,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "ports": "$PORTS",
  "http_tsv": "$HTTP",
  "project_tree_focus": "$TREE",
  "markers_and_sections": "$GREP_MARKERS",
  "placeholders": "$PLACEHOLDERS",
  "external_references": "$EXTERNAL",
  "assets_inventory": "$ASSETS",
  "build_log": "$BUILDLOG",
  "dist_inventory": "$DIST",
  "next_targets": "$NEXT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "placeholder_count": $PLACEHOLDER_COUNT,
  "external_reference_count": $EXTERNAL_COUNT
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v51r2_enterprise_gap_audit"
ln -sfn "$REL" "$BASE/runtime/releases/latest_v51r2_enterprise_gap_audit"

echo
echo "=== SUMMARY JSON ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== NEXT TARGETS ==="
sed -n '1,220p' "$NEXT"

echo
echo "============================================================"
echo "TRFMC_V51R2_ENTERPRISE_GAP_AUDIT COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
