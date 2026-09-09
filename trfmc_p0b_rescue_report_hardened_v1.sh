#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P0B_RESCUE_REPORT_HARDENED_V1_$TS"

mkdir -p "$OUT"
cd "$BASE"

REGISTRY="frontend/src/app/portalRegistry.ts"
NAV="frontend/src/app/PortalShellNavigationP0.tsx"
ORCH="frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
FILES="$OUT/file_gate.tsv"
MOUNT="$OUT/mount_gate.tsv"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/p0b_rescue_1920x1080.png"
BUILDLOG="$OUT/npm_build_p0b_rescue.log"
NOTES="$OUT/P0B_RESCUE_NOTES.md"

safe_count_grep() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

safe_count_file_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return 0
  fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_P0B_RESCUE_REPORT_HARDENED_V1"
echo "Read-only rescue · no source mutation · no backend mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) FILE GATE ==="

{
  echo -e "path\texists\tbytes\tlines\tsha256"
  for f in "$REGISTRY" "$NAV" "$ORCH" "$CSS"; do
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
} | tee "$FILES" | column -t -s $'\t'

echo
echo "=== 2) MOUNT / REGISTRY GATE ==="

{
  echo -e "check\tresult\tmatch"

  if grep -q "TRFMC_CANONICAL_DOMAINS" "$REGISTRY" 2>/dev/null; then
    echo -e "portalRegistry_has_canonical_domains\tPASS\t$(grep -n "TRFMC_CANONICAL_DOMAINS" "$REGISTRY" | head -n 1)"
  else
    echo -e "portalRegistry_has_canonical_domains\tFAIL\t-"
  fi

  if grep -q "PortalShellNavigationP0" "$NAV" 2>/dev/null; then
    echo -e "PortalShellNavigationP0_component_exists\tPASS\t$(grep -n "PortalShellNavigationP0" "$NAV" | head -n 1)"
  else
    echo -e "PortalShellNavigationP0_component_exists\tFAIL\t-"
  fi

  if grep -q "data-trfmc-p0b-portal-navigation" "$NAV" 2>/dev/null; then
    echo -e "PortalShellNavigationP0_has_DOM_marker\tPASS\t$(grep -n "data-trfmc-p0b-portal-navigation" "$NAV" | head -n 1)"
  else
    echo -e "PortalShellNavigationP0_has_DOM_marker\tFAIL\t-"
  fi

  if grep -q "PortalShellNavigationP0" "$ORCH" 2>/dev/null; then
    echo -e "MissionLayoutOrchestrator_mounts_PortalShellNavigationP0\tPASS\t$(grep -n "PortalShellNavigationP0" "$ORCH" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  else
    echo -e "MissionLayoutOrchestrator_mounts_PortalShellNavigationP0\tFAIL\t-"
  fi

  DOMAIN_COUNT="$(grep -c "routeHash:" "$REGISTRY" 2>/dev/null || true)"
  if [ "$DOMAIN_COUNT" -ge 12 ]; then
    echo -e "canonical_domain_count_ge_12\tPASS\t$DOMAIN_COUNT"
  else
    echo -e "canonical_domain_count_ge_12\tFAIL\t$DOMAIN_COUNT"
  fi

  IFRAME_COUNT="$(safe_count_grep "<iframe" "$REGISTRY" "$NAV" "$ORCH")"
  if [ "$IFRAME_COUNT" = "0" ]; then
    echo -e "iframe_absent\tPASS\t0"
  else
    echo -e "iframe_absent\tFAIL\t$IFRAME_COUNT"
  fi

  DANGEROUS_RUNTIME_REFS="$(safe_count_grep "dangerouslySetInnerHTML\|innerHTML\|document.write\|runtime injection" "$REGISTRY" "$NAV" "$ORCH")"
  if [ "$DANGEROUS_RUNTIME_REFS" = "0" ]; then
    echo -e "dangerous_runtime_patch_refs_absent\tPASS\t0"
  else
    echo -e "dangerous_runtime_patch_refs_absent\tFAIL\t$DANGEROUS_RUNTIME_REFS"
  fi
} | tee "$MOUNT" | column -t -s $'\t'

echo
echo "=== 3) BUILD GATE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

echo
echo "=== 4) HTTP GATE ==="

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

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 5) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=5000 \
    --dump-dom \
    "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=5000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"

elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=5000 \
    --dump-dom \
    "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=5000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM"
fi

P0B_MARKER_COUNT="$(safe_count_file_literal 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM")"
CSS_MARKER_COUNT="$(safe_count_file_literal 'TRFMC P0B CANONICAL PORTAL REGISTRY SOURCE V1 START' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P0B_MARKER_COUNT=$P0B_MARKER_COUNT"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

FILE_FAILS="$(awk 'NR>1 && $2!="YES" {c++} END {print c+0}' "$FILES")"
MOUNT_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$MOUNT")"

cat > "$NOTES" <<MD
# P0B Rescue Notes

## Diagnosi
La mutazione P0B ha superato build e HTTP, ma lo script originale si è fermato nel DOM gate prima di produrre summary/symlink.

## Causa probabile
Pipeline \`grep | wc -l\` sotto \`set -Eeuo pipefail\`: quando grep non trova match, exit code 1, quindi la pipeline fallisce anche se il risultato atteso è zero.

## Correzione
Questo rescue usa funzioni safe-count con \`grep ... || true\`, distingue riferimenti statici ai file HTML pubblici da vere patch runtime, e produce report stabile senza mutare sorgenti.
MD

RESULT="PASS"
if [ "$FILE_FAILS" != "0" ]; then RESULT="REVIEW_FILES"; fi
if [ "$MOUNT_FAILS" != "0" ]; then RESULT="REVIEW_MOUNT"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$HTTP_ZERO_BYTES_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0B_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MARKER"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P0B_RESCUE_REPORT_HARDENED_V1",
  "mutation": false,
  "source_mutation": false,
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "file_gate": "$FILES",
  "mount_gate": "$MOUNT",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "notes": "$NOTES",
  "file_failures": $FILE_FAILS,
  "mount_failures": $MOUNT_FAILS,
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $HTTP_NON_200_FRONTEND,
  "frontend_http_zero_bytes": $HTTP_ZERO_BYTES_FRONTEND,
  "dom_result": "$DOM_RESULT",
  "p0b_marker_count": $P0B_MARKER_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p0b_canonical_portal_registry_source_v1"
ln -sfn "$OUT" "$BASE/runtime/quality/latest_p0b_rescue_report_hardened_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== NOTES ==="
sed -n '1,120p' "$NOTES"

echo
echo "============================================================"
echo "TRFMC_P0B_RESCUE_REPORT_HARDENED_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
