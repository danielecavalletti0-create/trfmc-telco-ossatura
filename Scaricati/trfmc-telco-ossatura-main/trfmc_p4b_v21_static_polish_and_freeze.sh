#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4B_V21_STATIC_POLISH_AND_FREEZE_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

MAIN="frontend/src/app/main.tsx"
PORTAL_DIR="frontend/src/portal-os"
ROOT="$PORTAL_DIR/PortalOSRoot.tsx"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_p4b_v21.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/portal_os_v21_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4b_v21.diff"
RESTORE="$OUT/RESTORE_P4B_V21_STATIC_POLISH_AND_FREEZE.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4B_V21_PORTAL_OS_PREVIEW_PASS_$TS"

safe_count_files() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn -E "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

safe_count_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then echo 0; return 0; fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_P4B_V21_STATIC_POLISH_AND_FREEZE"
echo "Fix falso positivo createRoot text · freeze Portal OS preview"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$ROOT" ]; then
  echo "ERRORE: PortalOSRoot.tsx non trovato. P4B V2 non presente."
  exit 1
fi

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"
echo "RESTORE_P4B_V21_STATIC_POLISH_AND_FREEZE completato"
RESTORE_EOF
chmod +x "$RESTORE"

echo
echo "=== 1) PATCH TESTO: elimina createRoot dal copy visibile ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

text = text.replace(
    "Preview V2 · existing React root · no overlay · no second createRoot",
    "Preview V2.1 · existing React root · no overlay · no secondary root"
)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 2) DIFF ==="
git diff -- "$ROOT" "$MAIN" > "$DIFF" || true
sed -n '1,160p' "$DIFF"

echo
echo "=== 3) BUILD ==="

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

check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

FRONTEND_HTTP_NON_200="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
FRONTEND_HTTP_ZERO_BYTES="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 5) STATIC GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" "$PORTAL_DIR" "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" "$PORTAL_DIR" "$MAIN")"

  # Gate corretto: non cerca la parola createRoot nel testo, cerca una vera invocazione.
  EXTRA_ROOT_CALLS="$(safe_count_files "\\bcreateRoot[[:space:]]*\\(" "$PORTAL_DIR")"

  V42_P4B_COUNT="$(safe_count_files "P4B PORTAL OS|PortalOSRoot|portal-os-preview" frontend/src/layout_orchestrator 2>/dev/null || true)"
  MAIN_PREVIEW_COUNT="$(safe_count_files "trfmcPortalOsPreview|PortalOSRoot" "$MAIN")"
  PREVIEW_MARKER_SOURCE="$(safe_count_files "data-trfmc-portal-os-preview" "$PORTAL_DIR")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_call_in_portal_os\t$([ "$EXTRA_ROOT_CALLS" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_CALLS"
  echo -e "v42_not_touched_by_p4b_v21\t$([ "$V42_P4B_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4B_COUNT"
  echo -e "main_conditional_preview_present\t$([ "$MAIN_PREVIEW_COUNT" -gt 0 ] && echo PASS || echo FAIL)\t$MAIN_PREVIEW_COUNT"
  echo -e "preview_marker_source_present\t$([ "$PREVIEW_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$PREVIEW_MARKER_SOURCE"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 6) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    CHROME_BIN="google-chrome"
  elif command -v chromium >/dev/null 2>&1; then
    CHROME_BIN="chromium"
  else
    CHROME_BIN=""
  fi

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
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

PREVIEW_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$DOM")"
HOME_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-home="mounted"' "$DOM")"
VIEWPORT_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-viewport="mounted"' "$DOM")"
LAUNCHER_COUNT="$(safe_count_literal 'Operational Modules' "$DOM")"
EVIDENCE_COUNT="$(safe_count_literal 'Command / Evidence' "$DOM")"
TITLE_COUNT="$(safe_count_literal 'TRFMC Unified Portal OS' "$DOM")"
V42_TITLE_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "PREVIEW_MARKER_COUNT=$PREVIEW_MARKER_COUNT"
echo "HOME_MARKER_COUNT=$HOME_MARKER_COUNT"
echo "VIEWPORT_MARKER_COUNT=$VIEWPORT_MARKER_COUNT"
echo "LAUNCHER_COUNT=$LAUNCHER_COUNT"
echo "EVIDENCE_COUNT=$EVIDENCE_COUNT"
echo "TITLE_COUNT=$TITLE_COUNT"
echo "V42_TITLE_COUNT=$V42_TITLE_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FRONTEND_HTTP_NON_200" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$FRONTEND_HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$PREVIEW_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_PREVIEW_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$HOME_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_HOME_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$LAUNCHER_COUNT" = "0" ]; then RESULT="REVIEW_LAUNCHER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$EVIDENCE_COUNT" = "0" ]; then RESULT="REVIEW_EVIDENCE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$TITLE_COUNT" = "0" ]; then RESULT="REVIEW_TITLE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE_IN_PORTAL_OS"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4B V2.1 PORTAL OS PREVIEW PASS

Timestamp: $TS

Status:
- Portal OS preview mounted inside existing React App root.
- No secondary createRoot invocation inside portal-os.
- No iframe.
- No dangerous DOM mutation.
- V42 not touched.
- V42 title absent from #portal-os-preview.
- Build PASS.
- HTTP PASS.
- DOM PASS.
- Screenshot PASS.

Next:
P4C_PORTAL_OS_MANIFEST_EXPANSION_V1.
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4B_V21_STATIC_POLISH_AND_FREEZE",
  "mutation": "portal_os_copy_polish_plus_freeze",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "preview_route": "#portal-os-preview",
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $FRONTEND_HTTP_NON_200,
  "frontend_http_zero_bytes": $FRONTEND_HTTP_ZERO_BYTES,
  "static_failures": $STATIC_FAILS,
  "dom_result": "$DOM_RESULT",
  "preview_marker_count": $PREVIEW_MARKER_COUNT,
  "home_marker_count": $HOME_MARKER_COUNT,
  "viewport_marker_count": $VIEWPORT_MARKER_COUNT,
  "launcher_count": $LAUNCHER_COUNT,
  "evidence_count": $EVIDENCE_COUNT,
  "title_count": $TITLE_COUNT,
  "v42_title_count": $V42_TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4b_v21_static_polish_and_freeze"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4B_V21_STATIC_POLISH_AND_FREEZE COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
