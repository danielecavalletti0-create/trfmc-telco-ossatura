#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4G_PORTAL_OS_ROUTE_REGISTRY_ACTIVATION_V1_$TS"
BACKUP="$OUT/backup"
ROUTE_DOM_DIR="$OUT/route_dom"

mkdir -p "$OUT" "$BACKUP" "$ROUTE_DOM_DIR"
cd "$BASE"

MAIN="frontend/src/app/main.tsx"
ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
MANIFEST="frontend/src/portal-os/portalManifest.ts"
CSS="frontend/src/portal-os/portal-os.css"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
ROUTE_PROBE="$OUT/route_registry_probe.tsv"
BUILDLOG="$OUT/npm_build_p4g_route_registry.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p4g_route_registry_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4g_route_registry.diff"
RESTORE="$OUT/RESTORE_P4G_PORTAL_OS_ROUTE_REGISTRY_ACTIVATION_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4G_ROUTE_REGISTRY_PASS_$TS"

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
  python3 - "$literal" "$file" <<'PY'
import sys
needle = sys.argv[1]
path = sys.argv[2]
text = open(path, "r", encoding="utf-8", errors="replace").read()
print(text.count(needle))
PY
}

echo "============================================================"
echo "TRFMC_P4G_PORTAL_OS_ROUTE_REGISTRY_ACTIVATION_V1"
echo "Attiva tutte le route manifest dentro PortalOSRoot"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$MAIN" "$ROOT" "$MANIFEST" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"
cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$MANIFEST" "$BACKUP/portalManifest.ts.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"
cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portalManifest.ts.before_$TS" "$MANIFEST"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"
echo "RESTORE_P4G_PORTAL_OS_ROUTE_REGISTRY_ACTIVATION_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH main.tsx: Portal OS route registry gate ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

import_manifest = "import { portalOSModules } from '../portal-os/portalManifest'"
if import_manifest not in text:
    lines = text.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, import_manifest)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

# Inserisce helper dentro App(), subito dopo la variabile trfmcPortalOsPreview.
needle = "  const trfmcPortalOsPreview = trfmcActiveHash === '#portal-os-preview';"
replacement = """  const trfmcPortalOsPreview = trfmcActiveHash === '#portal-os-preview';

  const trfmcPortalOsManifestRoute = portalOSModules.some((module) => {
    const route = module.route?.startsWith('#') ? module.route : `#${module.route}`;
    return route === trfmcActiveHash;
  });

  const trfmcPortalOsRouteActive = trfmcPortalOsPreview || trfmcPortalOsManifestRoute;"""

if "const trfmcPortalOsRouteActive =" not in text:
    if needle not in text:
        raise SystemExit("ERRORE: trfmcPortalOsPreview non trovato in main.tsx")
    text = text.replace(needle, replacement, 1)

# Cambia il gate P4B/P4E da solo #portal-os-preview a registry route.
text = text.replace(
    "  if (trfmcPortalOsPreview) {\n    return <PortalOSRoot />\n  }",
    "  if (trfmcPortalOsRouteActive) {\n    return <PortalOSRoot />\n  }"
)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 2) PATCH PortalOSRoot: sincronizza modulo attivo da hash route ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

anchor = """function routeForModule(module?: PortalOSModule) {
  const route = module?.route || '#portal-os-preview'
  return route.startsWith('#') ? route : `#${route}`
}

"""

helper = """function moduleFromCurrentHash() {
  if (typeof window === 'undefined') return undefined
  return portalOSModules.find((module) => routeForModule(module) === window.location.hash)
}

function laneIdForModule(module?: PortalOSModule) {
  const lane = lanes.find((item) => item.category === module?.category)
  return lane?.id ?? 'core-ran'
}

"""

if helper.strip() not in text:
    if anchor not in text:
        raise SystemExit("ERRORE: routeForModule anchor non trovato")
    text = text.replace(anchor, anchor + helper, 1)

old_state = """  const [selectedLaneId, setSelectedLaneId] = React.useState('core-ran')
  const [activeModuleId, setActiveModuleId] = React.useState(() => bestModuleIdForLane('core-ran'))"""

new_state = """  const [selectedLaneId, setSelectedLaneId] = React.useState(() => laneIdForModule(moduleFromCurrentHash()))
  const [activeModuleId, setActiveModuleId] = React.useState(() => moduleFromCurrentHash()?.id ?? bestModuleIdForLane('core-ran'))"""

if old_state in text:
    text = text.replace(old_state, new_state, 1)

effect_anchor = """  React.useEffect(() => {
    let alive = true
"""

sync_effect = """  React.useEffect(() => {
    const syncFromHash = () => {
      const module = moduleFromCurrentHash()
      if (!module) return
      setActiveModuleId(module.id)
      setSelectedLaneId(laneIdForModule(module))
    }

    syncFromHash()
    window.addEventListener('hashchange', syncFromHash)

    return () => {
      window.removeEventListener('hashchange', syncFromHash)
    }
  }, [])

"""

if "window.addEventListener('hashchange', syncFromHash)" not in text:
    if effect_anchor not in text:
        raise SystemExit("ERRORE: useEffect anchor non trovato")
    text = text.replace(effect_anchor, sync_effect + effect_anchor, 1)

old_marker = """      data-trfmc-p4f-dashboard-route-links="mounted"
    >"""
new_marker = """      data-trfmc-p4f-dashboard-route-links="mounted"
      data-trfmc-p4g-route-registry="mounted"
    >"""

if old_marker in text and 'data-trfmc-p4g-route-registry="mounted"' not in text:
    text = text.replace(old_marker, new_marker, 1)

text = text.replace(
    "Portal OS home is manifest-governed; dashboard pages, route links and same-origin data fabric are active.",
    "Portal OS route registry is active: manifest hashes now open governed Portal OS module views."
)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 3) DIFF ==="
git diff -- "$MAIN" "$ROOT" "$CSS" "$MANIFEST" > "$DIFF" || true
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

check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4"
check_url "http://127.0.0.1:5173/#webgl-rf-physics-engine-v85d-runtime-identity-lock"
check_url "http://127.0.0.1:5173/#executive-mission-dashboard-v-next"
check_url "http://127.0.0.1:5173/#trfmc-datacenter-power-pdu-infrastructure-v1"
check_url "http://127.0.0.1:5173/#trfmc-emergency-reset-layout-state"
check_url "http://127.0.0.1:5173/#trfmc-knowledge-base-theory-procedures-v1"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:5173/#antenna-system"
check_url "http://127.0.0.1:5173/#rf-physics"

FRONTEND_HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
FRONTEND_HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 6) STATIC GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" frontend/src/portal-os "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" frontend/src/portal-os "$MAIN")"
  EXTRA_ROOT_CALLS="$(safe_count_files "\\bcreateRoot[[:space:]]*\\(" frontend/src/portal-os)"
  V42_P4G_COUNT="$(safe_count_files "P4G|trfmcPortalOsManifestRoute|data-trfmc-p4g-route-registry" frontend/src/layout_orchestrator 2>/dev/null || true)"
  MAIN_REGISTRY_COUNT="$(safe_count_files "trfmcPortalOsManifestRoute|trfmcPortalOsRouteActive|portalOSModules" "$MAIN")"
  ROOT_REGISTRY_COUNT="$(safe_count_files "moduleFromCurrentHash|laneIdForModule|data-trfmc-p4g-route-registry" "$ROOT")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_call_in_portal_os\t$([ "$EXTRA_ROOT_CALLS" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_CALLS"
  echo -e "v42_not_touched_by_p4g\t$([ "$V42_P4G_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4G_COUNT"
  echo -e "main_registry_gate_present\t$([ "$MAIN_REGISTRY_COUNT" -gt 2 ] && echo PASS || echo FAIL)\t$MAIN_REGISTRY_COUNT"
  echo -e "root_hash_sync_present\t$([ "$ROOT_REGISTRY_COUNT" -gt 2 ] && echo PASS || echo FAIL)\t$ROOT_REGISTRY_COUNT"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 7) DOM / SCREENSHOT GATE PORTAL OS ==="

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

  if [ -n "${CHROME_BIN:-}" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
    echo "NO_CHROME_AVAILABLE" > "$DOMERR"
    echo "NO_CHROME_AVAILABLE" > "$SCREENERR"
  fi
fi

P4G_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p4g-route-registry="mounted"' "$DOM")"
PORTAL_OS_COUNT="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$DOM")"
WAR_ROOM_COUNT="$(safe_count_literal 'TRFMC RF/TM War Room V4' "$DOM")"
MISSION_COUNT="$(safe_count_literal 'Mission Overview' "$DOM")"
V42_TITLE_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P4G_MARKER_COUNT=$P4G_MARKER_COUNT"
echo "PORTAL_OS_COUNT=$PORTAL_OS_COUNT"
echo "WAR_ROOM_COUNT=$WAR_ROOM_COUNT"
echo "MISSION_COUNT=$MISSION_COUNT"
echo "V42_TITLE_COUNT=$V42_TITLE_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

echo
echo "=== 8) ROUTE REGISTRY PROBE ==="

cat > "$ROUTE_PROBE" <<PROBEHDR
route	expected_title	http_status	dom_bytes	portal_os_count	expected_title_count	v42_title_count	route_result
PROBEHDR

probe_route() {
  local route="$1"
  local expected="$2"
  local safe
  safe="$(echo "$route" | tr '#/' '__' | tr -cd 'A-Za-z0-9_.-')"
  local dom_file="$ROUTE_DOM_DIR/${safe}.dom.txt"
  local url="http://127.0.0.1:5173/${route}"

  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  rm -f "$tmp"

  if [ -n "${CHROME_BIN:-}" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1440,900 \
      --virtual-time-budget=8000 \
      --dump-dom \
      "$url" > "$dom_file" 2>/dev/null || true
  else
    echo "NO_CHROME_AVAILABLE" > "$dom_file"
  fi

  local bytes portal expected_count v42 result
  bytes="$(wc -c < "$dom_file" | tr -d ' ')"
  portal="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$dom_file")"
  expected_count="$(safe_count_literal "$expected" "$dom_file")"
  v42="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$dom_file")"

  result="REVIEW"
  if [ "$code" != "200" ]; then result="NON_200"; fi
  if [ "$code" = "200" ] && [ "$portal" -gt 0 ] && [ "$expected_count" -gt 0 ] && [ "$v42" = "0" ]; then result="PASS"; fi
  if [ "$code" = "200" ] && [ "$portal" = "0" ]; then result="NO_PORTAL_OS_RENDER"; fi
  if [ "$code" = "200" ] && [ "$expected_count" = "0" ]; then result="EXPECTED_TITLE_MISSING"; fi
  if [ "$v42" != "0" ]; then result="V42_LEAK"; fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$route" "$expected" "$code" "$bytes" "$portal" "$expected_count" "$v42" "$result" >> "$ROUTE_PROBE"
}

probe_route "#trfmc-rf-tm-war-room-v4" "TRFMC RF/TM War Room V4"
probe_route "#signal-analyzer" "Signal Analyzer"
probe_route "#antenna-system" "Antenna System"
probe_route "#webgl-rf-physics-engine-v85d-runtime-identity-lock" "TRFMC v0.85D"
probe_route "#executive-mission-dashboard-v-next" "TRFMC v0.70A"
probe_route "#trfmc-datacenter-power-pdu-infrastructure-v1" "Data Center / Power / PDU Infrastructure Lab"
probe_route "#trfmc-emergency-reset-layout-state" "TRFMC Emergency Reset Layout State"
probe_route "#trfmc-knowledge-base-theory-procedures-v1" "Knowledge Base / Theory / Procedures Atlas"
probe_route "#portal-os-preview" "Command Center Home"
probe_route "#rf-physics" "RF Physics"

column -t -s $'\t' "$ROUTE_PROBE"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"
ROUTE_FAILS="$(awk -F'\t' 'NR>1 && $8!="PASS"{c++} END {print c+0}' "$ROUTE_PROBE")"
ROUTE_PASS="$(awk -F'\t' 'NR>1 && $8=="PASS"{c++} END {print c+0}' "$ROUTE_PROBE")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FRONTEND_HTTP_NON_200" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$FRONTEND_HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P4G_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P4G_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$PORTAL_OS_COUNT" = "0" ]; then RESULT="REVIEW_PORTAL_OS_RENDER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$WAR_ROOM_COUNT" = "0" ]; then RESULT="REVIEW_WAR_ROOM_ROUTE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi
if [ "$RESULT" = "PASS" ] && [ "$ROUTE_FAILS" != "0" ]; then RESULT="REVIEW_ROUTE_REGISTRY_PARTIAL"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4G ROUTE REGISTRY PASS

Timestamp: $TS

Status:
- Manifest hash routes now mount PortalOSRoot.
- PortalOSRoot syncs active module and lane from current hash.
- Dashboard links now open governed module views.
- V42 untouched.
- No iframe.
- No unsafe DOM mutation.
- No secondary root.
- Route pass count: $ROUTE_PASS
- Route fail count: $ROUTE_FAILS
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4G_PORTAL_OS_ROUTE_REGISTRY_ACTIVATION_V1",
  "mutation": "main_manifest_route_gate_plus_portal_os_hash_sync",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "diff": "$DIFF",
  "route_probe": "$ROUTE_PROBE",
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
  "p4g_marker_count": $P4G_MARKER_COUNT,
  "portal_os_count": $PORTAL_OS_COUNT,
  "war_room_count": $WAR_ROOM_COUNT,
  "mission_count": $MISSION_COUNT,
  "v42_title_count": $V42_TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "route_pass": $ROUTE_PASS,
  "route_fails": $ROUTE_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4g_portal_os_route_registry_activation_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4G_PORTAL_OS_ROUTE_REGISTRY_ACTIVATION_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
