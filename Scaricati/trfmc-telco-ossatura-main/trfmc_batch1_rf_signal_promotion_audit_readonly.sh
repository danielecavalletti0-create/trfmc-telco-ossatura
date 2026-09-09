#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH1_RF_SIGNAL_PROMOTION_AUDIT_READONLY_$TS"

mkdir -p "$OUT"

SUMMARY="$OUT/summary.json"
REACT_RF="$OUT/react_rf_signal_sources.tsv"
PUBLIC_RF="$OUT/public_rf_signal_pages.tsv"
ASSET_RF="$OUT/public_rf_signal_assets.tsv"
STYLE_RF="$OUT/rf_signal_style_selectors.tsv"
IMPORTS="$OUT/current_rf_imports_and_mounts.tsv"
API="$OUT/rf_signal_api_contracts.tsv"
CANDIDATES="$OUT/promotion_candidate_matrix.tsv"
PLAN="$OUT/BATCH1_RF_SIGNAL_PROMOTION_PLAN.md"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_batch1_readonly.log"

cd "$BASE"

echo "============================================================"
echo "TRFMC_BATCH1_RF_SIGNAL_PROMOTION_AUDIT_READONLY"
echo "RF Physics / Signal Analyzer promotion audit · read-only"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) REACT RF / SIGNAL SOURCES ==="

{
  echo -e "priority\tkind\tpath\tbytes\tlines\treason"
  find frontend/src -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" \) \
    | grep -Ei "rf|signal|spectrum|fft|iq|constellation|evm|snr|microwave|smith|instrument|waterfall|analyzer" \
    | sort \
    | while read -r f; do
        bytes="$(stat -c%s "$f" 2>/dev/null || echo 0)"
        lines="$(wc -l < "$f" 2>/dev/null | tr -d ' ' || echo 0)"
        prio="P2"
        reason="react source candidate"
        case "$f" in
          *RFOperationalDeckV16ChunkObservatory.tsx*) prio="P0"; reason="already imported / high-value RF operational deck candidate" ;;
          *RFInstrumentSuite*|*Signal*|*Spectrum*|*Analyzer*) prio="P0"; reason="direct Signal Analyzer / RF instrument candidate" ;;
          *rf_instruments*) prio="P1"; reason="RF instrument component family" ;;
          *microwave*|*Smith*|*smith*) prio="P1"; reason="RF/Microwave candidate, useful after RF Physics" ;;
        esac
        printf "%s\tREACT_SOURCE\t%s\t%s\t%s\t%s\n" "$prio" "$f" "$bytes" "$lines" "$reason"
      done
} | tee "$REACT_RF"

echo
echo "=== 2) PUBLIC RF / SIGNAL HTML PAGES ==="

{
  echo -e "priority\tkind\tpath\tbytes\treason"
  find frontend/public -maxdepth 2 -type f -name "*.html" \
    | grep -Ei "rf|signal|spectrum|fft|iq|constellation|evm|snr|microwave|smith|instrument|waterfall|analyzer|metrology|calibration" \
    | sort \
    | while read -r f; do
        bytes="$(stat -c%s "$f" 2>/dev/null || echo 0)"
        prio="P2"
        reason="public page candidate: review and migrate, do not keep as parallel portal"
        case "$f" in
          *rf_instrumentation_signal_cockpit*|*signal*|*spectrum*) prio="P1"; reason="Signal Analyzer public candidate to migrate into React" ;;
          *rf_microwave*|*smith*|*microwave*) prio="P1"; reason="RF/Microwave public candidate to migrate after Signal Analyzer" ;;
          *metrology*|*calibration*) prio="P2"; reason="RF metrology/calibration candidate" ;;
        esac
        printf "%s\tPUBLIC_HTML\t%s\t%s\t%s\n" "$prio" "$f" "$bytes" "$reason"
      done
} | tee "$PUBLIC_RF"

echo
echo "=== 3) PUBLIC RF / SIGNAL ASSETS ==="

{
  echo -e "priority\tkind\tpath\tbytes\treason"
  find frontend/public/assets -type f \
    | grep -Eiv "/vendor/" \
    | grep -Ei "rf|signal|spectrum|fft|iq|constellation|evm|snr|microwave|smith|instrument|waterfall|analyzer|visual_asset_engine" \
    | sort \
    | while read -r f; do
        bytes="$(stat -c%s "$f" 2>/dev/null || echo 0)"
        prio="P3"
        reason="public asset candidate: promote only if source-bound and non-duplicated"
        case "$f" in
          *visual_asset_engine*) prio="P2"; reason="visual engine candidate, verify real interaction and registry binding" ;;
          *smith*|*microwave*) prio="P2"; reason="RF/Microwave visual asset candidate" ;;
          *spectrum*|*fft*|*signal*) prio="P2"; reason="Signal Analyzer asset candidate" ;;
        esac
        printf "%s\tPUBLIC_ASSET\t%s\t%s\t%s\n" "$prio" "$f" "$bytes" "$reason"
      done
} | tee "$ASSET_RF"

echo
echo "=== 4) RF / SIGNAL STYLE SELECTORS ==="

{
  echo -e "path\tline\tselector_or_context"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "rf-suite|rf-dock|rf-source|rf-operational|spectrum|waterfall|constellation|fft|iq|evm|snr|smith|microwave|signal" \
    frontend/src/styles.css frontend/src 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,220)}'
} | tee "$STYLE_RF"

echo
echo "=== 5) CURRENT RF IMPORTS / MOUNTS ==="

{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "RFOperationalDeck|RFInstrument|Signal|Spectrum|Waterfall|FFT|IQ|Constellation|Analyzer|Microwave|Smith" \
    frontend/src/app/main.tsx frontend/src/layout_orchestrator frontend/src/rf_instruments 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,240)}'
} | tee "$IMPORTS"

echo
echo "=== 6) RF / SIGNAL API CONTRACTS ==="

{
  echo -e "path\tline\tendpoint_or_contract"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "/api/rfpro|/api/mission/status|spectrum|sweep|fft|iq|signal|rfpro|RF|Signal" \
    backend frontend/src frontend/public 2>/dev/null \
    | grep -Eiv "/vendor/" \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,260)}'
} | tee "$API"

echo
echo "=== 7) PROMOTION CANDIDATE MATRIX ==="

{
  echo -e "rank\tcandidate\tsource_type\tdomain\tdecision\tnext_action"

  awk -F'\t' 'NR>1 && $1=="P0" {
    print "1\t"$3"\t"$2"\tRF_Physics_Signal_Analyzer\tPROMOTE_FIRST\tinspect component props and mount inside EngineeringConsoleExpansionV4"
  }' "$REACT_RF"

  awk -F'\t' 'NR>1 && $1=="P1" {
    print "2\t"$3"\t"$2"\tRF_Physics_Signal_Analyzer\tPROMOTE_REVIEW\tcompare with P0 React source and reuse only best logic"
  }' "$REACT_RF"

  awk -F'\t' 'NR>1 && $1=="P1" {
    print "3\t"$3"\t"$2"\tSignal_or_Microwave\tMIGRATE_REVIEW\tconvert useful HTML logic into React, avoid iframe/parallel page"
  }' "$PUBLIC_RF"

  awk -F'\t' 'NR>1 && $1=="P2" {
    print "4\t"$3"\t"$2"\tVisual_Asset\tASSET_REVIEW\tpromote only if registry-bound and not duplicated"
  }' "$ASSET_RF"
} | tee "$CANDIDATES"

echo
echo "=== 8) BUILD CHECK READ-ONLY ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

echo
echo "=== 9) HTTP GATE READ-ONLY ==="

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
check_url "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

REACT_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$REACT_RF")"
PUBLIC_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PUBLIC_RF")"
ASSET_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$ASSET_RF")"
STYLE_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$STYLE_RF")"
IMPORT_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$IMPORTS")"
API_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$API")"
CANDIDATE_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$CANDIDATES")"

cat > "$PLAN" <<MD
# TRFMC Batch 1 — RF Physics / Signal Analyzer Promotion Plan

## Baseline
Engineering Console V5 is frozen. Do not modify layout unless an objective gate fails.

## Purpose
Promote RF Physics and Signal Analyzer into the Engineering Console as real source-level React modules.

## Rule
No iframe. No runtime injection. No public-page-as-portal. No backend mutation in this batch.

## Promotion rule for each module
Each promoted module must include:
- theory;
- simulator;
- visual asset;
- endpoint/API contract;
- scenario;
- QA gate.

## Candidate priority
1. P0 React components already present or already imported.
2. P1 React RF instrument family.
3. P1 public HTML only as migration source, never as parallel page.
4. P2/P3 assets only after registry and duplication review.

## Expected next mutation
Create one React component only:
\`frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx\`

Mount it inside:
\`EngineeringConsoleExpansionV4.tsx\`

No change to \`index.html\`.
No change to backend.
No public asset injection.

## QA required after mutation
- npm build PASS
- HTTP PASS
- screenshot 1920x1080 PASS
- DOM marker present
- no iframe
- no public runtime patch
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH1_RF_SIGNAL_PROMOTION_AUDIT_READONLY",
  "mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "react_rf_signal_sources": "$REACT_RF",
  "public_rf_signal_pages": "$PUBLIC_RF",
  "public_rf_signal_assets": "$ASSET_RF",
  "rf_signal_style_selectors": "$STYLE_RF",
  "current_rf_imports_and_mounts": "$IMPORTS",
  "rf_signal_api_contracts": "$API",
  "promotion_candidate_matrix": "$CANDIDATES",
  "plan": "$PLAN",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "react_total": $REACT_TOTAL,
  "public_html_total": $PUBLIC_TOTAL,
  "asset_total": $ASSET_TOTAL,
  "style_match_total": $STYLE_TOTAL,
  "import_mount_total": $IMPORT_TOTAL,
  "api_contract_total": $API_TOTAL,
  "candidate_total": $CANDIDATE_TOTAL,
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo AUDIT_READY || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch1_rf_signal_promotion_audit"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,180p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_BATCH1_RF_SIGNAL_PROMOTION_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
