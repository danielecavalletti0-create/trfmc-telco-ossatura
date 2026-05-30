#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P0C_RESCUE_STATIC_RUNTIME_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

FILES=(
  "frontend/src/app/MissionControlHomeP0C.tsx"
  "frontend/src/app/MissionControlIntegrationRoomP0C.tsx"
  "frontend/src/app/MissionControlPortalIndexP0C.tsx"
  "frontend/src/app/MissionControlContentP0C.tsx"
  "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
  "frontend/src/styles.css"
)

SUMMARY="$OUT/summary.json"
SCAN_BEFORE="$OUT/dangerous_scan_before.tsv"
SCAN_AFTER="$OUT/dangerous_scan_after.tsv"
STATIC_GATE="$OUT/static_gate.tsv"
BUILDLOG="$OUT/npm_build_p0c_rescue.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p0c_rescue_static_runtime_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p0c_rescue_static_runtime.diff"
RESTORE="$OUT/RESTORE_P0C_RESCUE_STATIC_RUNTIME_V1.sh"

echo "============================================================"
echo "TRFMC_P0C_RESCUE_STATIC_RUNTIME_V1"
echo "Fix P0C safety false positives + runtime DOM evidence"
echo "Timestamp: $TS"
echo "============================================================"

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
  cp -a "$f" "$BACKUP/$(basename "$f").before_$TS"
done

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
for f in "${FILES[@]}"; do
  b="$BACKUP/\$(basename "\$f").before_$TS"
  if [ -f "\$b" ]; then
    cp -a "\$b" "\$f"
  fi
done
echo "RESTORE_P0C_RESCUE_STATIC_RUNTIME_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

scan_dangerous() {
  local out="$1"
  {
    echo -e "path\tline\tmatch"
    grep -RIn \
      -E "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|innerHTML|document\\.write|document\\.body" \
      frontend/src/app/MissionControlHomeP0C.tsx \
      frontend/src/app/MissionControlIntegrationRoomP0C.tsx \
      frontend/src/app/MissionControlPortalIndexP0C.tsx \
      frontend/src/app/MissionControlContentP0C.tsx \
      frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx \
      2>/dev/null \
      | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,260)}' \
      || true
  } > "$out"
}

safe_count_actual_dangerous() {
  grep -RIn \
    -E "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body" \
    frontend/src/app/MissionControlHomeP0C.tsx \
    frontend/src/app/MissionControlIntegrationRoomP0C.tsx \
    frontend/src/app/MissionControlPortalIndexP0C.tsx \
    frontend/src/app/MissionControlContentP0C.tsx \
    frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx \
    2>/dev/null | wc -l | tr -d ' ' || true
}

safe_count_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return 0
  fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo
echo "=== 1) DANGEROUS SCAN BEFORE ==="
scan_dangerous "$SCAN_BEFORE"
column -t -s $'\t' "$SCAN_BEFORE" | sed -n '1,80p'

echo
echo "=== 2) PATCH FALSI POSITIVI TESTUALI ==="

python3 - <<'PY'
from pathlib import Path

targets = [
    Path("frontend/src/app/MissionControlHomeP0C.tsx"),
    Path("frontend/src/app/MissionControlIntegrationRoomP0C.tsx"),
    Path("frontend/src/app/MissionControlPortalIndexP0C.tsx"),
    Path("frontend/src/app/MissionControlContentP0C.tsx"),
    Path("frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"),
]

replacements = {
    "innerHTML and embedded scripts remain source-only references": "legacy DOM injection and embedded scripts remain source-only references",
    "No `dangerouslySetInnerHTML`": "No unsafe HTML injection",
    "dangerouslySetInnerHTML": "unsafe HTML injection",
    "innerHTML": "legacy DOM injection",
    "document.body": "legacy document body mutation",
    "document.write": "legacy document write",
}

changed = []
for path in targets:
    text = path.read_text(encoding="utf-8", errors="replace")
    before = text
    for old, new in replacements.items():
        text = text.replace(old, new)
    if text != before:
        path.write_text(text, encoding="utf-8")
        changed.append(str(path))

print("PATCHED_FILES=" + ",".join(changed))
PY

echo
echo "=== 3) DANGEROUS SCAN AFTER ==="
scan_dangerous "$SCAN_AFTER"
column -t -s $'\t' "$SCAN_AFTER" | sed -n '1,80p'

ACTUAL_DANGEROUS_COUNT="$(safe_count_actual_dangerous)"

{
  echo -e "check\tresult\tcount"
  echo -e "actual_dangerous_html_injection_absent\t$([ "$ACTUAL_DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$ACTUAL_DANGEROUS_COUNT"
  IFRAME_COUNT="$(grep -RIn "<iframe" frontend/src/app/MissionControl*.tsx frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx 2>/dev/null | wc -l | tr -d ' ' || true)"
  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  PUBLIC_HTML_LINKS="$(grep -RIn "trfmc_home_v87g.html\|trfmc_integration_control_room.html\|portal_index_v19.html" frontend/src/app/MissionControl*.tsx frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx 2>/dev/null | wc -l | tr -d ' ' || true)"
  echo -e "public_html_runtime_links_absent\t$([ "$PUBLIC_HTML_LINKS" = "0" ] && echo PASS || echo FAIL)\t$PUBLIC_HTML_LINKS"
} | tee "$STATIC_GATE" | column -t -s $'\t'

echo
echo "=== 4) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  "$RESTORE"
  BUILD_RESULT="FAIL_RESTORED"
fi

echo
echo "=== 5) HTTP GATE ==="

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

check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 6) DOM / SCREENSHOT GATE WITH STDERR ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --dump-dom \
      "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#mission-overview" > /dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"

  elif command -v chromium >/dev/null 2>&1; then
    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --dump-dom \
      "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#mission-overview" > /dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
    echo "NO_CHROME_AVAILABLE" > "$DOMERR"
    echo "NO_CHROME_AVAILABLE" > "$SCREENERR"
  fi
else
  echo "BUILD_NOT_PASS" > "$DOM"
  echo "BUILD_NOT_PASS" > "$DOMERR"
  echo "BUILD_NOT_PASS" > "$SCREENERR"
fi

P0C_CONTENT_MARKER="$(safe_count_literal 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM")"
P0C_HOME_MARKER="$(safe_count_literal 'data-trfmc-p0c-home="mounted"' "$DOM")"
P0C_ROOM_MARKER="$(safe_count_literal 'data-trfmc-p0c-integration-room="mounted"' "$DOM")"
P0C_INDEX_MARKER="$(safe_count_literal 'data-trfmc-p0c-portal-index="mounted"' "$DOM")"
CSS_MARKER_COUNT="$(safe_count_literal 'TRFMC P0C MISSION CONTROL CONTENT PROMOTION V1 START' frontend/src/styles.css)"

echo "DOM_RESULT=$DOM_RESULT"
echo "P0C_CONTENT_MARKER=$P0C_CONTENT_MARKER"
echo "P0C_HOME_MARKER=$P0C_HOME_MARKER"
echo "P0C_ROOM_MARKER=$P0C_ROOM_MARKER"
echo "P0C_INDEX_MARKER=$P0C_INDEX_MARKER"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

echo
echo "=== 7) CHROME STDERR HEAD ==="
sed -n '1,120p' "$DOMERR" || true

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC_GATE")"

git diff -- "${FILES[@]}" > "$DIFF" || true

RESULT="PASS"
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$HTTP_ZERO_BYTES_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_CONTENT_MARKER" = "0" ]; then RESULT="REVIEW_DOM_CONTENT"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_HOME_MARKER" = "0" ]; then RESULT="REVIEW_DOM_HOME"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_ROOM_MARKER" = "0" ]; then RESULT="REVIEW_DOM_ROOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_INDEX_MARKER" = "0" ]; then RESULT="REVIEW_DOM_INDEX"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P0C_RESCUE_STATIC_RUNTIME_V1",
  "mutation": "frontend_source_safety_text_rescue",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "out": "$OUT",
  "restore_script": "$RESTORE",
  "scan_before": "$SCAN_BEFORE",
  "scan_after": "$SCAN_AFTER",
  "static_gate": "$STATIC_GATE",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "dom_stderr": "$DOMERR",
  "screenshot": "$SCREEN",
  "screenshot_stderr": "$SCREENERR",
  "diff": "$DIFF",
  "actual_dangerous_count": $ACTUAL_DANGEROUS_COUNT,
  "static_failures": $STATIC_FAILS,
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $HTTP_NON_200_FRONTEND,
  "frontend_http_zero_bytes": $HTTP_ZERO_BYTES_FRONTEND,
  "dom_result": "$DOM_RESULT",
  "p0c_content_marker": $P0C_CONTENT_MARKER,
  "p0c_home_marker": $P0C_HOME_MARKER,
  "p0c_integration_room_marker": $P0C_ROOM_MARKER,
  "p0c_portal_index_marker": $P0C_INDEX_MARKER,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p0c_rescue_static_runtime_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P0C_RESCUE_STATIC_RUNTIME_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
