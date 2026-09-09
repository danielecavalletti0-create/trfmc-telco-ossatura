#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_VISUAL_GATE_ENGINEERING_ONLY_V3_$TS"

mkdir -p "$OUT"

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
SCREEN="$OUT/full_engineering_stack_1920x1080.png"
NOTES="$OUT/VISUAL_REVIEW_NOTES.md"

cd "$BASE"

echo "============================================================"
echo "TRFMC_VISUAL_GATE_ENGINEERING_ONLY_V3"
echo "Read-only visual gate · no source mutation"
echo "Timestamp: $TS"
echo "============================================================"

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

check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

cat > "$NOTES" <<MD
# TRFMC Visual Review - Engineering Only V3

## Esito visivo manuale preliminare
- Doppio portale: risolto.
- Header TELCO RF sopra Engineering: rimosso.
- V49 usato come contenuto principale: sì.
- Problema residuo: console troppo vuota e poco ricca.
- Prossima fase consigliata: non layout, ma contenuto/strumentazione.

## Prossimo sviluppo corretto
Aggiungere nella console Engineering:
1. Engineering Completeness Matrix compatta.
2. Contract/API live status.
3. Navigation/Asset/Scenario binding map.
4. RF/Telco domain cards.
5. QA/evidence strip.
6. Accesso ordinato ai moduli:
   - RF Physics
   - Signal Analyzer
   - Antenna
   - Microwave
   - Fiber
   - Core Network
   - Cyber RF Intelligence
MD

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_VISUAL_GATE_ENGINEERING_ONLY_V3",
  "mutation": false,
  "http_tsv": "$HTTP",
  "screenshot": "$SCREEN",
  "visual_notes": "$NOTES",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$([ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_visual_gate_engineering_only_v3"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== NOTES ==="
sed -n '1,180p' "$NOTES"

echo
echo "============================================================"
echo "VISUAL GATE COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
