#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4D_C_VISUAL_CORRECTNESS_GATE_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
CSS="frontend/src/portal-os/portal-os.css"
MAIN="frontend/src/app/main.tsx"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_p4d_c_visual_correctness.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p4d_c_visual_correctness_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4d_c_visual_correctness.diff"
RESTORE="$OUT/RESTORE_P4D_C_VISUAL_CORRECTNESS_GATE_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4D_C_VISUAL_CORRECTNESS_PASS_$TS"

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
echo "TRFMC_P4D_C_VISUAL_CORRECTNESS_GATE_V1"
echo "Fix selected module, risk count, bridge-CORS wording, minor visual polish"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ROOT" "$CSS" "$MAIN"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"
cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"

echo "RESTORE_P4D_C_VISUAL_CORRECTNESS_GATE_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH PortalOSRoot.tsx ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

insert_after = """function modulesByCategory(category: string) {
  return portalOSModules.filter((module) => module.category === category)
}

"""

helper = """function bestModuleIdForLane(laneId: string) {
  const lane = lanes.find((item) => item.id === laneId) ?? lanes[0]
  const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]
  return first?.id ?? 'home'
}

"""

if helper.strip() not in text:
    if insert_after not in text:
        raise SystemExit("ERRORE: punto inserimento bestModuleIdForLane non trovato")
    text = text.replace(insert_after, insert_after + helper, 1)

old_state = """  const [activeModuleId, setActiveModuleId] = React.useState('home')
  const [selectedLaneId, setSelectedLaneId] = React.useState('core-ran')
"""

new_state = """  const [selectedLaneId, setSelectedLaneId] = React.useState('core-ran')
  const [activeModuleId, setActiveModuleId] = React.useState(() => bestModuleIdForLane('core-ran'))
"""

if old_state in text:
    text = text.replace(old_state, new_state, 1)
elif "React.useState('home')" in text:
    raise SystemExit("ERRORE: stato activeModuleId trovato ma pattern inatteso")

old_error = """detail: error instanceof Error ? error.message.slice(0, 90) : 'browser probe blocked/offline',"""
new_error = """detail:
                endpoint.id === 'bridge'
                  ? 'browser fetch blocked/offline; CORS/proxy pending'
                  : error instanceof Error
                    ? error.message.slice(0, 90)
                    : 'browser probe blocked/offline',"""
if old_error in text:
    text = text.replace(old_error, new_error, 1)

old_risk = """  const totalRisks = riskyPortalOSModules.length + reviewPortalOSModules.length"""
new_risk = """  const riskModuleIds = new Set([...riskyPortalOSModules, ...reviewPortalOSModules].map((module) => module.id))
  const totalRisks = riskModuleIds.size"""
if old_risk in text:
    text = text.replace(old_risk, new_risk, 1)

old_marker = """      data-trfmc-p4d-command-center-home="mounted"
    >"""
new_marker = """      data-trfmc-p4d-command-center-home="mounted"
      data-trfmc-p4dc-visual-correction="mounted"
    >"""
if old_marker in text:
    text = text.replace(old_marker, new_marker, 1)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 2) PATCH CSS polish ==="

cat >> "$CSS" <<'CSS'

/* TRFMC P4D-C VISUAL CORRECTNESS START */
.trfmc-command-lanes,
.trfmc-command-center,
.trfmc-command-right {
  scrollbar-width: thin;
  scrollbar-color: rgba(103, 232, 249, .38) rgba(2, 12, 24, .22);
}

.trfmc-command-module-grid button.is-active {
  box-shadow: inset 0 0 0 1px rgba(134, 239, 172, .32), 0 0 28px rgba(16, 185, 129, .14);
}

.trfmc-command-active-card dd {
  max-height: 48px;
  overflow: hidden;
}

.trfmc-command-endpoint.is-offline em {
  color: #fbbf24;
}

.trfmc-command-evidence-block article strong,
.trfmc-command-evidence-block p {
  word-break: normal;
}
/* TRFMC P4D-C VISUAL CORRECTNESS END */
CSS

echo
echo "=== 3) DIFF ==="
git diff -- "$ROOT" "$CSS" "$MAIN" > "$DIFF" || true
sed -n '1,260p' "$DIFF"

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
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

FRONTEND_HTTP_NON_200="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
FRONTEND_HTTP_ZERO_BYTES="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 6) STATIC GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" frontend/src/portal-os "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" frontend/src/portal-os "$MAIN")"
  EXTRA_ROOT_CALLS="$(safe_count_files "\\bcreateRoot[[:space:]]*\\(" frontend/src/portal-os)"
  V42_P4DC_COUNT="$(safe_count_files "P4D-C|p4dc|bestModuleIdForLane|visual-correction" frontend/src/layout_orchestrator 2>/dev/null || true)"
  P4DC_MARKER_SOURCE="$(safe_count_files "data-trfmc-p4dc-visual-correction" "$ROOT")"
  BEST_MODULE_SOURCE="$(safe_count_files "bestModuleIdForLane\\('core-ran'\\)" "$ROOT")"
  RISK_SET_SOURCE="$(safe_count_files "new Set\\(\\[\\.\\.\\.riskyPortalOSModules" "$ROOT")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_call_in_portal_os\t$([ "$EXTRA_ROOT_CALLS" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_CALLS"
  echo -e "v42_not_touched_by_p4dc\t$([ "$V42_P4DC_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4DC_COUNT"
  echo -e "p4dc_marker_source_present\t$([ "$P4DC_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$P4DC_MARKER_SOURCE"
  echo -e "initial_module_from_lane_present\t$([ "$BEST_MODULE_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$BEST_MODULE_SOURCE"
  echo -e "deduplicated_risk_set_present\t$([ "$RISK_SET_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$RISK_SET_SOURCE"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 7) DOM / SCREENSHOT GATE ==="

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
P4D_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p4d-command-center-home="mounted"' "$DOM")"
P4DC_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p4dc-visual-correction="mounted"' "$DOM")"
ACTIVE_VIEWPORT_COUNT="$(safe_count_literal 'Active Mission Viewport' "$DOM")"
LANES_COUNT="$(safe_count_literal 'Operational Lanes' "$DOM")"
EVIDENCE_COUNT="$(safe_count_literal 'Command / Evidence' "$DOM")"
WAR_ROOM_COUNT="$(safe_count_literal 'TRFMC RF/TM War Room V4' "$DOM")"
HOME_SELECTED_COUNT="$(safe_count_literal '<strong>Unified Portal OS Home</strong><em>portal-os · PREVIEW</em>' "$DOM")"
RISK_187_COUNT="$(safe_count_literal 'Risk queue: 187 modules' "$DOM")"
CORS_HINT_COUNT="$(safe_count_literal 'CORS/proxy pending' "$DOM")"
V42_TITLE_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "PREVIEW_MARKER_COUNT=$PREVIEW_MARKER_COUNT"
echo "P4D_MARKER_COUNT=$P4D_MARKER_COUNT"
echo "P4DC_MARKER_COUNT=$P4DC_MARKER_COUNT"
echo "ACTIVE_VIEWPORT_COUNT=$ACTIVE_VIEWPORT_COUNT"
echo "LANES_COUNT=$LANES_COUNT"
echo "EVIDENCE_COUNT=$EVIDENCE_COUNT"
echo "WAR_ROOM_COUNT=$WAR_ROOM_COUNT"
echo "HOME_SELECTED_COUNT=$HOME_SELECTED_COUNT"
echo "RISK_187_COUNT=$RISK_187_COUNT"
echo "CORS_HINT_COUNT=$CORS_HINT_COUNT"
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
if [ "$DOM_RESULT" = "PASS" ] && [ "$P4DC_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P4DC_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$WAR_ROOM_COUNT" = "0" ]; then RESULT="REVIEW_ACTIVE_MODULE_NOT_PROMOTED_FROM_LANE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$HOME_SELECTED_COUNT" != "0" ]; then RESULT="REVIEW_HOME_STILL_SELECTED"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$RISK_187_COUNT" != "0" ]; then RESULT="REVIEW_RISK_DUPLICATE_COUNT"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE_IN_PORTAL_OS"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4D-C VISUAL CORRECTNESS PASS

Timestamp: $TS

Fixes:
- Active module now initialized from selected lane.
- 5G Core/RAN lane selects TRFMC RF/TM War Room V4 instead of Portal OS Home.
- Risk queue deduplicated.
- Bridge browser fetch wording clarified as CORS/proxy pending.
- V42 untouched.
- Build/HTTP/static/DOM/screenshot PASS.

Next:
P4E Data Fabric / same-origin bridge proxy / CORS normalization.
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4D_C_VISUAL_CORRECTNESS_GATE_V1",
  "mutation": "portal_os_visual_correctness_patch",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
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
  "p4d_marker_count": $P4D_MARKER_COUNT,
  "p4dc_marker_count": $P4DC_MARKER_COUNT,
  "active_viewport_count": $ACTIVE_VIEWPORT_COUNT,
  "lanes_count": $LANES_COUNT,
  "evidence_count": $EVIDENCE_COUNT,
  "war_room_count": $WAR_ROOM_COUNT,
  "home_selected_count": $HOME_SELECTED_COUNT,
  "risk_187_count": $RISK_187_COUNT,
  "cors_hint_count": $CORS_HINT_COUNT,
  "v42_title_count": $V42_TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4d_c_visual_correctness_gate_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4D_C_VISUAL_CORRECTNESS_GATE_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
