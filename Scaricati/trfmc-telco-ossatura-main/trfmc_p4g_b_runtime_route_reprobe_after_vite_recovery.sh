#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4G_B_RUNTIME_ROUTE_REPROBE_AFTER_VITE_RECOVERY_$TS"
ROUTE_DOM_DIR="$OUT/route_dom"
ROUTE_SCREEN_DIR="$OUT/route_screens"

mkdir -p "$OUT" "$ROUTE_DOM_DIR" "$ROUTE_SCREEN_DIR"
cd "$BASE"

MAIN="frontend/src/app/main.tsx"
ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
MANIFEST="frontend/src/portal-os/portalManifest.ts"

SUMMARY="$OUT/summary.json"
SOURCE_GATE="$OUT/source_marker_gate.tsv"
HTTP="$OUT/http.tsv"
ROUTE_TARGETS="$OUT/route_targets.tsv"
ROUTE_PROBE="$OUT/route_probe.tsv"
DOM_MAIN="$OUT/dom_main_war_room.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN_MAIN="$OUT/war_room_route_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
BUILDLOG="$OUT/npm_build_p4g_b_reprobe.log"

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
echo "TRFMC_P4G_B_RUNTIME_ROUTE_REPROBE_AFTER_VITE_RECOVERY"
echo "No source mutation · verifica route hash con Vite vivo"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$MAIN" "$ROOT" "$MANIFEST"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

echo
echo "=== 1) SOURCE MARKER GATE ==="

{
  echo -e "check\tresult\tcount"
  MAIN_ROUTE_GATE="$(safe_count_files "trfmcPortalOsManifestRoute|trfmcPortalOsRouteActive|portalOSModules" "$MAIN")"
  ROOT_HASH_SYNC="$(safe_count_files "moduleFromCurrentHash|laneIdForModule|data-trfmc-p4g-route-registry" "$ROOT")"
  P4F_ROUTE_LINKS="$(safe_count_files "data-trfmc-dashboard-route-links|data-trfmc-route-link" "$ROOT")"
  PORTALOS_IMPORT="$(safe_count_files "PortalOSRoot" "$MAIN")"
  MANIFEST_COUNT="$(grep -c '"id":' "$MANIFEST" || true)"

  echo -e "main_manifest_route_gate_present\t$([ "$MAIN_ROUTE_GATE" -gt 2 ] && echo PASS || echo FAIL)\t$MAIN_ROUTE_GATE"
  echo -e "root_hash_sync_present\t$([ "$ROOT_HASH_SYNC" -gt 2 ] && echo PASS || echo FAIL)\t$ROOT_HASH_SYNC"
  echo -e "dashboard_route_links_present\t$([ "$P4F_ROUTE_LINKS" -gt 1 ] && echo PASS || echo FAIL)\t$P4F_ROUTE_LINKS"
  echo -e "portal_os_import_present\t$([ "$PORTALOS_IMPORT" -gt 0 ] && echo PASS || echo FAIL)\t$PORTALOS_IMPORT"
  echo -e "manifest_modules_gt_100\t$([ "$MANIFEST_COUNT" -gt 100 ] && echo PASS || echo FAIL)\t$MANIFEST_COUNT"
} | tee "$SOURCE_GATE" | column -t -s $'\t'

SOURCE_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$SOURCE_GATE")"

echo
echo "=== 2) BUILD CURRENT SOURCE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

echo
echo "=== 3) HTTP GATE ==="

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
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:5173/#antenna-system"
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 4) GENERO ROUTE TARGETS DA MANIFEST ==="

python3 - "$MANIFEST" "$ROUTE_TARGETS" <<'PY'
import csv
import json
import re
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
out = Path(sys.argv[2])
text = manifest.read_text(encoding="utf-8", errors="replace")

m = re.search(
    r"export const portalOSModules: PortalOSModule\[\] =\s*(\[.*?\])\s*\n\s*export const promotedPortalOSModules",
    text,
    re.S,
)
if not m:
    raise SystemExit("ERRORE: portalOSModules non trovato")

modules = json.loads(m.group(1))

wanted = [
    "#trfmc-rf-tm-war-room-v4",
    "#signal-analyzer",
    "#antenna-system",
    "#webgl-rf-physics-engine-v85d-runtime-identity-lock",
    "#executive-mission-dashboard-v-next",
    "#trfmc-datacenter-power-pdu-infrastructure-v1",
    "#trfmc-emergency-reset-layout-state",
    "#trfmc-knowledge-base-theory-procedures-v1",
    "#portal-os-preview",
    "#rf-physics",
]

def norm(route):
    route = route or ""
    return route if route.startswith("#") else "#" + route

by_route = {norm(m.get("route")): m for m in modules}

rows = []
for route in wanted:
    m = by_route.get(route, {})
    rows.append({
        "route": route,
        "expected_title": m.get("title") or {
            "#portal-os-preview": "Command Center Home",
            "#rf-physics": "RF Physics",
            "#signal-analyzer": "Signal Analyzer",
            "#antenna-system": "Antenna System",
        }.get(route, route),
        "module_id": m.get("id", "-"),
        "category": m.get("category", "-"),
        "status": m.get("status", "-"),
        "source": m.get("source", "-"),
    })

with out.open("w", encoding="utf-8", newline="") as f:
    fields = ["route", "expected_title", "module_id", "category", "status", "source"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(rows)
PY

column -t -s $'\t' "$ROUTE_TARGETS"

echo
echo "=== 5) CHROME DOM MAIN ROUTE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

if [ "$BUILD_RESULT" = "PASS" ] && [ -n "$CHROME_BIN" ]; then
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --dump-dom \
    "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4" > "$DOM_MAIN" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --screenshot="$SCREEN_MAIN" \
    "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
else
  echo "NO_CHROME_OR_BUILD_FAIL" > "$DOM_MAIN"
  echo "NO_CHROME_OR_BUILD_FAIL" > "$DOMERR"
  echo "NO_CHROME_OR_BUILD_FAIL" > "$SCREENERR"
fi

MAIN_PORTAL_COUNT="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$DOM_MAIN")"
MAIN_P4G_COUNT="$(safe_count_literal 'data-trfmc-p4g-route-registry="mounted"' "$DOM_MAIN")"
MAIN_WAR_ROOM_COUNT="$(safe_count_literal 'TRFMC RF/TM War Room V4' "$DOM_MAIN")"
MAIN_V42_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM_MAIN")"

echo "DOM_RESULT=$DOM_RESULT"
echo "MAIN_PORTAL_COUNT=$MAIN_PORTAL_COUNT"
echo "MAIN_P4G_COUNT=$MAIN_P4G_COUNT"
echo "MAIN_WAR_ROOM_COUNT=$MAIN_WAR_ROOM_COUNT"
echo "MAIN_V42_COUNT=$MAIN_V42_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

echo
echo "=== 6) ROUTE PROBE ==="

cat > "$ROUTE_PROBE" <<PROBEHDR
route	expected_title	http_status	dom_bytes	portal_os_count	p4g_count	expected_title_count	v42_title_count	result
PROBEHDR

if [ "$BUILD_RESULT" = "PASS" ] && [ -n "$CHROME_BIN" ]; then
  tail -n +2 "$ROUTE_TARGETS" | while IFS=$'\t' read -r route expected module_id category status source; do
    safe="$(echo "$route" | tr '#/' '__' | tr -cd 'A-Za-z0-9_.-')"
    dom_file="$ROUTE_DOM_DIR/${safe}.dom.txt"
    screen_file="$ROUTE_SCREEN_DIR/${safe}.png"
    url="http://127.0.0.1:5173/${route}"

    tmp="$(mktemp)"
    code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
    rm -f "$tmp"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1440,900 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "$url" > "$dom_file" 2>/dev/null || true

    case "$route" in
      "#trfmc-rf-tm-war-room-v4"|"#signal-analyzer"|"#antenna-system"|"#portal-os-preview")
        "$CHROME_BIN" \
          --headless=new \
          --disable-gpu \
          --no-sandbox \
          --window-size=1440,900 \
          --virtual-time-budget=9000 \
          --screenshot="$screen_file" \
          "$url" >/dev/null 2>/dev/null || true
        ;;
    esac

    bytes="$(wc -c < "$dom_file" | tr -d ' ')"
    portal="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$dom_file")"
    p4g="$(safe_count_literal 'data-trfmc-p4g-route-registry="mounted"' "$dom_file")"
    title_count="$(safe_count_literal "$expected" "$dom_file")"
    v42="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$dom_file")"

    res="REVIEW"
    if [ "$code" != "200" ]; then res="NON_200"; fi
    if [ "$code" = "200" ] && [ "$portal" -gt 0 ] && [ "$p4g" -gt 0 ] && [ "$title_count" -gt 0 ] && [ "$v42" = "0" ]; then res="PASS"; fi
    if [ "$code" = "200" ] && [ "$portal" = "0" ]; then res="NO_PORTAL_OS_RENDER"; fi
    if [ "$code" = "200" ] && [ "$p4g" = "0" ]; then res="NO_P4G_REGISTRY"; fi
    if [ "$code" = "200" ] && [ "$title_count" = "0" ]; then res="EXPECTED_TITLE_MISSING"; fi
    if [ "$v42" != "0" ]; then res="V42_LEAK"; fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$route" "$expected" "$code" "$bytes" "$portal" "$p4g" "$title_count" "$v42" "$res" >> "$ROUTE_PROBE"
  done
else
  echo "chrome_or_build_unavailable	-	000	0	0	0	0	0	SKIPPED" >> "$ROUTE_PROBE"
fi

column -t -s $'\t' "$ROUTE_PROBE"

ROUTE_PASS="$(awk -F'\t' 'NR>1 && $9=="PASS"{c++} END {print c+0}' "$ROUTE_PROBE")"
ROUTE_FAILS="$(awk -F'\t' 'NR>1 && $9!="PASS"{c++} END {print c+0}' "$ROUTE_PROBE")"

RESULT="PASS"
if [ "$SOURCE_FAILS" != "0" ]; then RESULT="REVIEW_SOURCE_MARKERS"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP_NON_200"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_ZERO_BYTES"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$MAIN_PORTAL_COUNT" = "0" ]; then RESULT="REVIEW_PORTAL_OS_RENDER"; fi
if [ "$MAIN_P4G_COUNT" = "0" ]; then RESULT="REVIEW_P4G_REGISTRY_MARKER"; fi
if [ "$MAIN_WAR_ROOM_COUNT" = "0" ]; then RESULT="REVIEW_WAR_ROOM_RENDER"; fi
if [ "$MAIN_V42_COUNT" != "0" ]; then RESULT="REVIEW_V42_LEAK"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi
if [ "$RESULT" = "PASS" ] && [ "$ROUTE_FAILS" != "0" ]; then RESULT="REVIEW_ROUTE_REGISTRY_PARTIAL"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4G_B_RUNTIME_ROUTE_REPROBE_AFTER_VITE_RECOVERY",
  "mutation": false,
  "source_mutation": false,
  "source_marker_gate": "$SOURCE_GATE",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "route_targets": "$ROUTE_TARGETS",
  "route_probe": "$ROUTE_PROBE",
  "dom_main": "$DOM_MAIN",
  "screenshot_main": "$SCREEN_MAIN",
  "source_failures": $SOURCE_FAILS,
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "main_portal_count": $MAIN_PORTAL_COUNT,
  "main_p4g_count": $MAIN_P4G_COUNT,
  "main_war_room_count": $MAIN_WAR_ROOM_COUNT,
  "main_v42_count": $MAIN_V42_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "route_pass": $ROUTE_PASS,
  "route_fails": $ROUTE_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4g_b_runtime_route_reprobe_after_vite_recovery"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4G_B_RUNTIME_ROUTE_REPROBE_AFTER_VITE_RECOVERY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
