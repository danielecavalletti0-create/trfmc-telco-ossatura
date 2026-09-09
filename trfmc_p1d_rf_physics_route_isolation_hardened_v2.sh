#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_HARDENED_V2_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

ORCH="frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
PATCHLOG="$OUT/patch_log.tsv"
BUILDLOG="$OUT/npm_build_p1d_hardened_v2.log"
HTTP="$OUT/http.tsv"
STATIC="$OUT/static_gate.tsv"
DOM_RF="$OUT/dom_rf_physics.txt"
DOM_MISSION="$OUT/dom_mission_overview.txt"
ERR_RF="$OUT/chrome_rf_physics.stderr.log"
ERR_MISSION="$OUT/chrome_mission_overview.stderr.log"
SCREEN_RF="$OUT/rf_physics_isolated_1920x1080.png"
SCREEN_MISSION="$OUT/mission_overview_after_p1d_1920x1080.png"
ROUTE_COUNTS="$OUT/route_isolation_counts.tsv"
DIFF="$OUT/p1d_rf_physics_route_isolation_hardened_v2.diff"
RESTORE="$OUT/RESTORE_P1D_RF_PHYSICS_ROUTE_ISOLATION_HARDENED_V2.sh"

safe_count_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return 0
  fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

safe_count_files() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn -E "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

write_summary() {
  local result="$1"
  cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_HARDENED_V2",
  "mutation": "frontend_source_route_isolation",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "out": "$OUT",
  "restore_script": "$RESTORE",
  "patch_log": "$PATCHLOG",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "route_counts": "$ROUTE_COUNTS",
  "dom_rf_physics": "$DOM_RF",
  "dom_mission_overview": "$DOM_MISSION",
  "screenshot_rf_physics": "$SCREEN_RF",
  "screenshot_mission_overview": "$SCREEN_MISSION",
  "result": "$result"
}
JSON
}

echo "============================================================"
echo "TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_HARDENED_V2"
echo "Route isolation · hardened · summary always generated"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ORCH" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    write_summary "FAIL_MISSING_FILE_$f"
    exit 1
  fi
  cp -a "$f" "$BACKUP/$(basename "$f").before_$TS"
done

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/$(basename "$ORCH").before_$TS" "$ORCH"
cp -a "$BACKUP/$(basename "$CSS").before_$TS" "$CSS"
echo "RESTORE_P1D_RF_PHYSICS_ROUTE_ISOLATION_HARDENED_V2 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH ORCHESTRATOR ROUTE ISOLATION ==="

PATCH_RESULT="PASS"

python3 - "$ORCH" "$PATCHLOG" <<'PY' || PATCH_RESULT="FAIL"
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
patchlog = Path(sys.argv[2])

text = path.read_text(encoding="utf-8", errors="replace")
before = text

rows = []

def log(item, result, detail):
    rows.append((item, result, detail.replace("\t", " ").replace("\n", " ")[:500]))

# 1) Ensure React hooks import.
named_react = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]react['\"]", text)
if named_react:
    names = [x.strip() for x in named_react.group(1).split(",") if x.strip()]
    changed = False
    for needed in ["useEffect", "useState"]:
        if needed not in names:
            names.append(needed)
            changed = True
    if changed:
        replacement = "import { " + ", ".join(names) + " } from 'react'"
        text = text[:named_react.start()] + replacement + text[named_react.end():]
        log("react_hook_import", "PATCHED", replacement)
    else:
        log("react_hook_import", "OK", "useEffect/useState already present")
else:
    insert = "import { useEffect, useState } from 'react'\n"
    import_matches = list(re.finditer(r"^import\s+.*$", text, flags=re.M))
    if import_matches:
        last = import_matches[-1]
        text = text[:last.end()] + "\n" + insert.rstrip("\n") + text[last.end():]
    else:
        text = insert + text
    log("react_hook_import", "PATCHED", "added named React hook import")

# 2) Ensure RF domain import.
domain_import = "import { RFPhysicsDomainP1 } from '../domains/rf-physics/RFPhysicsDomainP1'"
if domain_import not in text:
    import_matches = list(re.finditer(r"^import\s+.*$", text, flags=re.M))
    if import_matches:
        last = import_matches[-1]
        text = text[:last.end()] + "\n" + domain_import + text[last.end():]
    else:
        text = domain_import + "\n" + text
    log("rf_domain_import", "PATCHED", domain_import)
else:
    log("rf_domain_import", "OK", "already present")

# 3) Remove stale P1D block if present.
text = re.sub(
    r"\n?\s*/\* TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 START \*/.*?/\* TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 END \*/\s*\n?",
    "\n",
    text,
    flags=re.S,
)

# 4) Locate the component body and the main return.
component_patterns = [
    r"export\s+default\s+function\s+MissionLayoutOrchestratorV42[^{]*\{",
    r"export\s+function\s+MissionLayoutOrchestratorV42[^{]*\{",
    r"function\s+MissionLayoutOrchestratorV42[^{]*\{",
    r"const\s+MissionLayoutOrchestratorV42\s*=\s*(?:\([^)]*\)|[^=]+)\s*=>\s*\{",
]

match = None
for pattern in component_patterns:
    match = re.search(pattern, text, flags=re.S)
    if match:
        log("component_locator", "PASS", pattern)
        break

if not match:
    log("component_locator", "FAIL", "MissionLayoutOrchestratorV42 component not found")
    patchlog.write_text("check\tresult\tdetail\n" + "\n".join("\t".join(r) for r in rows) + "\n", encoding="utf-8")
    raise SystemExit(2)

return_match = re.search(r"\n(\s*)return\s*\(", text[match.end():], flags=re.S)
if not return_match:
    log("return_locator", "FAIL", "main return (...) not found after component")
    patchlog.write_text("check\tresult\tdetail\n" + "\n".join("\t".join(r) for r in rows) + "\n", encoding="utf-8")
    raise SystemExit(3)

return_idx = match.end() + return_match.start()
indent = return_match.group(1)

block = f"""
{indent}/* TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 START */
{indent}const [trfmcP1DHashRoute, setTrfmcP1DHashRoute] = useState(() =>
{indent}  typeof window !== 'undefined' && window.location.hash ? window.location.hash : '#mission-overview'
{indent})

{indent}useEffect(() => {{
{indent}  const trfmcP1DOnHashChange = () => {{
{indent}    setTrfmcP1DHashRoute(
{indent}      typeof window !== 'undefined' && window.location.hash ? window.location.hash : '#mission-overview'
{indent}    )
{indent}  }}
{indent}  window.addEventListener('hashchange', trfmcP1DOnHashChange)
{indent}  trfmcP1DOnHashChange()
{indent}  return () => window.removeEventListener('hashchange', trfmcP1DOnHashChange)
{indent}}}, [])

{indent}if (trfmcP1DHashRoute === '#rf-physics') {{
{indent}  return (
{indent}    <section
{indent}      className="v42-orchestrator-shell trfmc-native-orchestrator-shell trfmc-p1d-route-shell"
{indent}      data-trfmc-p1d-route-isolation="rf-physics"
{indent}    >
{indent}      <div className="v42-orchestrator-header trfmc-native-orchestrator-header trfmc-p1d-route-header">
{indent}        <div>
{indent}          <p>P1D ROUTE ISOLATION · RF PHYSICS</p>
{indent}          <h2>RF Physics Domain Route</h2>
{indent}          <span>
{indent}            Route isolata: il dominio RF Physics viene renderizzato senza P0B/P0C Mission Control
{indent}            e senza V49 Mission Overview nello stesso stack verticale.
{indent}          </span>
{indent}        </div>
{indent}        <div className="v42-orchestrator-score">
{indent}          <strong>P1D</strong>
{indent}          <small>isolated</small>
{indent}        </div>
{indent}      </div>
{indent}      <RFPhysicsDomainP1 />
{indent}    </section>
{indent}  )
{indent}}}
{indent}/* TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 END */

"""

text = text[:return_idx] + block + text[return_idx:]

path.write_text(text, encoding="utf-8")

log("patch_write", "PASS", f"changed={text != before}")
patchlog.write_text("check\tresult\tdetail\n" + "\n".join("\t".join(r) for r in rows) + "\n", encoding="utf-8")
PY

cat "$PATCHLOG" | column -t -s $'\t' || true

if [ "$PATCH_RESULT" != "PASS" ]; then
  echo "PATCH FALLITA: restore automatico"
  "$RESTORE"
  write_summary "FAIL_PATCH_ORCHESTRATOR"
  python3 -m json.tool "$SUMMARY"
  ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1d_rf_physics_route_isolation_v1"
  ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1d_rf_physics_route_isolation_hardened_v2"
  exit 1
fi

echo
echo "=== 2) PATCH CSS ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 START === \*/.*?/\* === TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 START === */
.trfmc-p1d-route-shell {
  margin-top: 28px;
}

.trfmc-p1d-route-header {
  border-bottom: 1px solid rgba(103, 232, 249, .14);
}

.trfmc-p1d-route-header h2 {
  color: #e8f7ff;
}

.trfmc-p1d-route-header p {
  color: #67e8f9;
}

.trfmc-p1d-route-header span {
  color: #9fb8ca;
}

.trfmc-p1d-route-shell .trfmc-p1-rf-domain {
  margin-top: 14px;
}
/* === TRFMC P1D RF PHYSICS ROUTE ISOLATION V2 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
PY

echo
echo "=== 3) DIFF ==="
git diff -- "$ORCH" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

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
  write_summary "FAIL_BUILD_RESTORED"
  python3 -m json.tool "$SUMMARY"
  ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1d_rf_physics_route_isolation_v1"
  ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1d_rf_physics_route_isolation_hardened_v2"
  exit 1
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
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 6) STATIC SAFETY GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" "$ORCH")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body" "$ORCH")"
  P1D_MARKER_SOURCE="$(safe_count_files "data-trfmc-p1d-route-isolation" "$ORCH")"
  RF_DOMAIN_IMPORT="$(safe_count_files "RFPhysicsDomainP1" "$ORCH")"
  HOOK_IMPORT="$(safe_count_files "useEffect|useState" "$ORCH")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_html_injection_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "p1d_route_marker_source_present\t$([ "$P1D_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$P1D_MARKER_SOURCE"
  echo -e "rf_domain_import_present\t$([ "$RF_DOMAIN_IMPORT" -gt 0 ] && echo PASS || echo FAIL)\t$RF_DOMAIN_IMPORT"
  echo -e "route_hooks_present\t$([ "$HOOK_IMPORT" -gt 0 ] && echo PASS || echo FAIL)\t$HOOK_IMPORT"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 7) DOM / SCREENSHOT GATE ==="

DOM_RF_RESULT="SKIPPED"
DOM_MISSION_RESULT="SKIPPED"
SCREEN_RF_RESULT="SKIPPED"
SCREEN_MISSION_RESULT="SKIPPED"

BROWSER=""
if command -v google-chrome >/dev/null 2>&1; then
  BROWSER="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  BROWSER="chromium"
fi

if [ -n "$BROWSER" ]; then
  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --dump-dom \
    "http://127.0.0.1:5173/#rf-physics" > "$DOM_RF" 2> "$ERR_RF" && DOM_RF_RESULT="PASS" || DOM_RF_RESULT="FAIL"

  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --screenshot="$SCREEN_RF" \
    "http://127.0.0.1:5173/#rf-physics" >/dev/null 2>> "$ERR_RF" && SCREEN_RF_RESULT="PASS" || SCREEN_RF_RESULT="FAIL"

  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --dump-dom \
    "http://127.0.0.1:5173/#mission-overview" > "$DOM_MISSION" 2> "$ERR_MISSION" && DOM_MISSION_RESULT="PASS" || DOM_MISSION_RESULT="FAIL"

  "$BROWSER" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --screenshot="$SCREEN_MISSION" \
    "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>> "$ERR_MISSION" && SCREEN_MISSION_RESULT="PASS" || SCREEN_MISSION_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM_RF"
  echo "NO_CHROME_AVAILABLE" > "$DOM_MISSION"
  echo "NO_CHROME_AVAILABLE" > "$ERR_RF"
  echo "NO_CHROME_AVAILABLE" > "$ERR_MISSION"
fi

RF_P1D="$(safe_count_literal 'data-trfmc-p1d-route-isolation="rf-physics"' "$DOM_RF")"
RF_P1B="$(safe_count_literal 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_RF")"
RF_P0B="$(safe_count_literal 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_RF")"
RF_P0C="$(safe_count_literal 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_RF")"
RF_MISSION_V49="$(safe_count_literal 'V49_SECTION_MISSION_OVERVIEW' "$DOM_RF")"
RF_FORMULA="$(safe_count_literal 'Formula registry' "$DOM_RF")"
RF_SCENARIO="$(safe_count_literal 'Scenario binding' "$DOM_RF")"

MISSION_P1D="$(safe_count_literal 'data-trfmc-p1d-route-isolation="rf-physics"' "$DOM_MISSION")"
MISSION_P1B="$(safe_count_literal 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM_MISSION")"
MISSION_P0B="$(safe_count_literal 'data-trfmc-p0b-portal-navigation="mounted"' "$DOM_MISSION")"
MISSION_P0C="$(safe_count_literal 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM_MISSION")"
MISSION_V49="$(safe_count_literal 'V49_SECTION_MISSION_OVERVIEW' "$DOM_MISSION")"

{
  echo -e "route\tmarker\tcount\texpected"
  echo -e "rf-physics\tp1d_route_isolation\t$RF_P1D\t>0"
  echo -e "rf-physics\tp1b_rf_physics\t$RF_P1B\t>0"
  echo -e "rf-physics\tp0b_registry\t$RF_P0B\t0"
  echo -e "rf-physics\tp0c_mission_content\t$RF_P0C\t0"
  echo -e "rf-physics\tv49_mission_overview\t$RF_MISSION_V49\t0"
  echo -e "rf-physics\tformula_registry\t$RF_FORMULA\t>0"
  echo -e "rf-physics\tscenario_binding\t$RF_SCENARIO\t>0"
  echo -e "mission-overview\tp1d_route_isolation\t$MISSION_P1D\t0"
  echo -e "mission-overview\tp1b_rf_physics\t$MISSION_P1B\t0"
  echo -e "mission-overview\tp0b_registry\t$MISSION_P0B\t>0"
  echo -e "mission-overview\tp0c_mission_content\t$MISSION_P0C\t>0"
  echo -e "mission-overview\tv49_mission_overview\t$MISSION_V49\t>0"
} | tee "$ROUTE_COUNTS" | column -t -s $'\t'

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RF_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM_RF"; fi
if [ "$DOM_MISSION_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM_MISSION"; fi
if [ "$RF_P1D" = "0" ]; then RESULT="REVIEW_RF_P1D_MARKER"; fi
if [ "$RF_P1B" = "0" ]; then RESULT="REVIEW_RF_P1B_MISSING"; fi
if [ "$RF_P0B" != "0" ]; then RESULT="REVIEW_RF_ROUTE_CONTAINS_P0B"; fi
if [ "$RF_P0C" != "0" ]; then RESULT="REVIEW_RF_ROUTE_CONTAINS_P0C"; fi
if [ "$RF_MISSION_V49" != "0" ]; then RESULT="REVIEW_RF_ROUTE_CONTAINS_MISSION_V49"; fi
if [ "$MISSION_P1B" != "0" ]; then RESULT="REVIEW_MISSION_ROUTE_CONTAINS_RF"; fi
if [ "$MISSION_P0B" = "0" ]; then RESULT="REVIEW_MISSION_P0B_MISSING"; fi
if [ "$MISSION_P0C" = "0" ]; then RESULT="REVIEW_MISSION_P0C_MISSING"; fi
if [ "$MISSION_V49" = "0" ]; then RESULT="REVIEW_MISSION_V49_MISSING"; fi
if [ "$SCREEN_RF_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT_RF"; fi
if [ "$SCREEN_MISSION_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT_MISSION"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_HARDENED_V2",
  "mutation": "frontend_source_route_isolation",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "files_modified": [
    "$ORCH",
    "$CSS"
  ],
  "restore_script": "$RESTORE",
  "patch_log": "$PATCHLOG",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "route_counts": "$ROUTE_COUNTS",
  "dom_rf_physics": "$DOM_RF",
  "dom_mission_overview": "$DOM_MISSION",
  "screenshot_rf_physics": "$SCREEN_RF",
  "screenshot_mission_overview": "$SCREEN_MISSION",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "static_failures": $STATIC_FAILS,
  "dom_rf_result": "$DOM_RF_RESULT",
  "dom_mission_result": "$DOM_MISSION_RESULT",
  "screenshot_rf_result": "$SCREEN_RF_RESULT",
  "screenshot_mission_result": "$SCREEN_MISSION_RESULT",
  "rf_route_p1d_marker": $RF_P1D,
  "rf_route_p1b_marker": $RF_P1B,
  "rf_route_p0b_marker": $RF_P0B,
  "rf_route_p0c_marker": $RF_P0C,
  "rf_route_mission_v49_marker": $RF_MISSION_V49,
  "rf_route_formula_marker": $RF_FORMULA,
  "rf_route_scenario_marker": $RF_SCENARIO,
  "mission_route_p1d_marker": $MISSION_P1D,
  "mission_route_p1b_marker": $MISSION_P1B,
  "mission_route_p0b_marker": $MISSION_P0B,
  "mission_route_p0c_marker": $MISSION_P0C,
  "mission_route_v49_marker": $MISSION_V49,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1d_rf_physics_route_isolation_v1"
ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1d_rf_physics_route_isolation_hardened_v2"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_HARDENED_V2 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
