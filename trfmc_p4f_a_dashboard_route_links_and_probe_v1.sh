#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4F_A_DASHBOARD_ROUTE_LINKS_AND_PROBE_V1_$TS"
BACKUP="$OUT/backup"
ROUTE_DOM_DIR="$OUT/route_dom"

mkdir -p "$OUT" "$BACKUP" "$ROUTE_DOM_DIR"
cd "$BASE"

ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
CSS="frontend/src/portal-os/portal-os.css"
MAIN="frontend/src/app/main.tsx"
MANIFEST="frontend/src/portal-os/portalManifest.ts"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
ROUTE_TARGETS="$OUT/dashboard_route_targets.tsv"
ROUTE_PROBE="$OUT/dashboard_route_probe.tsv"
BUILDLOG="$OUT/npm_build_p4f_a_route_links.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p4f_a_dashboard_route_links_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4f_a_dashboard_route_links.diff"
RESTORE="$OUT/RESTORE_P4F_A_DASHBOARD_ROUTE_LINKS_AND_PROBE_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4F_A_DASHBOARD_ROUTE_LINKS_PASS_$TS"

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
echo "TRFMC_P4F_A_DASHBOARD_ROUTE_LINKS_AND_PROBE_V1"
echo "Attiva link dashboard + verifica route con Chrome DOM probe"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ROOT" "$CSS" "$MAIN" "$MANIFEST"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"
cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"
cp -a "$MANIFEST" "$BACKUP/portalManifest.ts.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"
cp -a "$BACKUP/portalManifest.ts.before_$TS" "$MANIFEST"

echo "RESTORE_P4F_A_DASHBOARD_ROUTE_LINKS_AND_PROBE_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH PortalOSRoot: link reali alle dashboard/page route ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

helper_anchor = """function bestModuleIdForLane(laneId: string) {
  const lane = lanes.find((item) => item.id === laneId) ?? lanes[0]
  const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]
  return first?.id ?? 'home'
}

"""

helper = """function routeForModule(module?: PortalOSModule) {
  const route = module?.route || '#portal-os-preview'
  return route.startsWith('#') ? route : `#${route}`
}

"""

if helper.strip() not in text:
    if helper_anchor not in text:
        raise SystemExit("ERRORE: anchor bestModuleIdForLane non trovato")
    text = text.replace(helper_anchor, helper_anchor + helper, 1)

marker_old = """      data-trfmc-p4e-data-fabric-dashboard="mounted"
    >"""
marker_new = """      data-trfmc-p4e-data-fabric-dashboard="mounted"
      data-trfmc-p4f-dashboard-route-links="mounted"
    >"""

if marker_old in text and 'data-trfmc-p4f-dashboard-route-links="mounted"' not in text:
    text = text.replace(marker_old, marker_new, 1)

route_section = """          <section className="trfmc-command-route-links" data-trfmc-dashboard-route-links="active">
            <div className="trfmc-command-strip-head">
              <span>Page links / route verification</span>
              <strong>manifest controlled</strong>
            </div>

            <div className="trfmc-command-route-grid">
              {dashboardLaneIds.map((laneId) => {
                const lane = lanes.find((item) => item.id === laneId)
                if (!lane) return null
                const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]
                const route = routeForModule(first)

                return (
                  <a
                    key={lane.id}
                    href={route}
                    data-trfmc-route-link={lane.id}
                    onClick={() => {
                      setSelectedLaneId(lane.id)
                      if (first) setActiveModuleId(first.id)
                    }}
                  >
                    <span>open route</span>
                    <strong>{lane.title}</strong>
                    <em>{route} · {first?.title ?? 'no module mapped'}</em>
                  </a>
                )
              })}
            </div>
          </section>

"""

insert_before = """          <section className="trfmc-command-module-strip">"""

if 'data-trfmc-dashboard-route-links="active"' not in text:
    if insert_before not in text:
        raise SystemExit("ERRORE: punto inserimento route-links non trovato")
    text = text.replace(insert_before, route_section + insert_before, 1)

text = text.replace(
    "Portal OS home is manifest-governed; dashboard pages and same-origin data fabric are active.",
    "Portal OS home is manifest-governed; dashboard pages, route links and same-origin data fabric are active."
)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 2) PATCH CSS route links ==="

if ! grep -q "TRFMC P4F DASHBOARD ROUTE LINKS START" "$CSS"; then
cat >> "$CSS" <<'CSS'

/* TRFMC P4F DASHBOARD ROUTE LINKS START */
.trfmc-command-route-links {
  margin-top: 10px;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 18px;
  background:
    radial-gradient(circle at 82% 0%, rgba(134, 239, 172, .08), transparent 34%),
    rgba(0, 6, 16, .34);
  padding: 10px;
}

.trfmc-command-route-grid {
  margin-top: 8px;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
}

.trfmc-command-route-grid a {
  display: block;
  text-decoration: none;
  border: 1px solid rgba(103, 232, 249, .14);
  border-radius: 14px;
  background: linear-gradient(180deg, rgba(0, 18, 30, .62), rgba(0, 7, 16, .46));
  color: inherit;
  padding: 10px;
}

.trfmc-command-route-grid a:hover {
  border-color: rgba(134, 239, 172, .48);
  background: rgba(8, 47, 38, .24);
  box-shadow: inset 0 0 0 1px rgba(134, 239, 172, .18), 0 0 28px rgba(16, 185, 129, .12);
}

.trfmc-command-route-grid span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-route-grid strong {
  display: block;
  margin-top: 5px;
  color: #e8f7ff;
  font-size: 12px;
  line-height: 1.12;
}

.trfmc-command-route-grid em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 9px;
  font-style: normal;
  line-height: 1.25;
  word-break: break-word;
}

@media (max-width: 1440px) {
  .trfmc-command-route-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
/* TRFMC P4F DASHBOARD ROUTE LINKS END */
CSS
fi

echo
echo "=== 3) GENERO target route dal manifest ==="

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

lanes = [
    ("core-ran", "5g-core-ran", "5G Core / RAN"),
    ("dsp", "fft-dsp-signal", "FFT / DSP / Signal"),
    ("antenna", "antenna-system", "RF / Antenna System"),
    ("digital-twin", "3d-rf-visual-twin", "3D RF Visual Twin"),
    ("war-room", "war-room", "War Room / Evidence"),
    ("noc", "noc-operations", "NOC / Operations"),
    ("sigint", "signal-intelligence", "Signal Intelligence"),
    ("knowledge", "knowledge-academy", "Knowledge / Academy"),
]

def score(item):
    try:
        return int(item.get("promotionScore") or 0)
    except Exception:
        return 0

rows = []
for lane_id, category, lane_title in lanes:
    candidates = [m for m in modules if m.get("category") == category]
    candidates = sorted(candidates, key=lambda item: (-score(item), item.get("title", "")))
    first = candidates[0] if candidates else {}
    route = first.get("route") or "#portal-os-preview"
    if not route.startswith("#"):
        route = "#" + route

    rows.append({
        "lane_id": lane_id,
        "category": category,
        "lane_title": lane_title,
        "module_title": first.get("title", "-"),
        "route": route,
        "status": first.get("status", "-"),
        "source": first.get("source", "-"),
        "score": score(first) if first else 0,
    })

# aggiungo route note già note/promosse
known = [
    ("known-mission", "mission-overview", "Mission Overview", "Mission Overview", "#mission-overview", "known", "app route", 0),
    ("known-engineering", "full-engineering-stack", "Full Engineering Stack", "Full Engineering Stack", "#full-engineering-stack", "known", "app route", 0),
    ("known-rf", "rf-physics", "RF Physics", "RF Physics", "#rf-physics", "known", "app route", 0),
    ("known-signal", "signal-analyzer", "Signal Analyzer", "Signal Analyzer", "#signal-analyzer", "known", "app route", 0),
    ("known-portal-os", "portal-os", "Portal OS Preview", "Portal OS Preview", "#portal-os-preview", "known", "app route", 0),
]
for lane_id, category, lane_title, module_title, route, status, source, score_value in known:
    rows.append({
        "lane_id": lane_id,
        "category": category,
        "lane_title": lane_title,
        "module_title": module_title,
        "route": route,
        "status": status,
        "source": source,
        "score": score_value,
    })

with out.open("w", encoding="utf-8", newline="") as f:
    fields = ["lane_id", "category", "lane_title", "module_title", "route", "status", "source", "score"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(rows)
PY

column -t -s $'\t' "$ROUTE_TARGETS"

echo
echo "=== 4) DIFF ==="
git diff -- "$ROOT" "$CSS" "$MAIN" "$MANIFEST" > "$DIFF" || true
sed -n '1,260p' "$DIFF"

echo
echo "=== 5) BUILD ==="

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
echo "=== 6) HTTP GATE ==="

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
echo "=== 7) STATIC GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" frontend/src/portal-os "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" frontend/src/portal-os "$MAIN")"
  EXTRA_ROOT_CALLS="$(safe_count_files "\\bcreateRoot[[:space:]]*\\(" frontend/src/portal-os)"
  V42_P4F_COUNT="$(safe_count_files "P4F|dashboard-route-links|trfmc-route-link" frontend/src/layout_orchestrator 2>/dev/null || true)"
  P4F_MARKER_SOURCE="$(safe_count_files "data-trfmc-p4f-dashboard-route-links" "$ROOT")"
  ROUTE_LINK_MARKER_SOURCE="$(safe_count_files "data-trfmc-dashboard-route-links|data-trfmc-route-link" "$ROOT")"
  ROUTE_CSS_SOURCE="$(safe_count_files "trfmc-command-route-links|trfmc-command-route-grid" "$CSS")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_call_in_portal_os\t$([ "$EXTRA_ROOT_CALLS" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_CALLS"
  echo -e "v42_not_touched_by_p4f\t$([ "$V42_P4F_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4F_COUNT"
  echo -e "p4f_marker_source_present\t$([ "$P4F_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$P4F_MARKER_SOURCE"
  echo -e "route_link_marker_source_present\t$([ "$ROUTE_LINK_MARKER_SOURCE" -gt 1 ] && echo PASS || echo FAIL)\t$ROUTE_LINK_MARKER_SOURCE"
  echo -e "route_css_source_present\t$([ "$ROUTE_CSS_SOURCE" -gt 3 ] && echo PASS || echo FAIL)\t$ROUTE_CSS_SOURCE"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 8) DOM / SCREENSHOT GATE PORTAL OS ==="

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
fi

P4F_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p4f-dashboard-route-links="mounted"' "$DOM")"
ROUTE_LINKS_MARKER_COUNT="$(safe_count_literal 'data-trfmc-dashboard-route-links="active"' "$DOM")"
ROUTE_LINK_ITEM_COUNT="$(safe_count_literal 'data-trfmc-route-link=' "$DOM")"
ROUTE_TITLE_COUNT="$(safe_count_literal 'Page links / route verification' "$DOM")"
V42_TITLE_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P4F_MARKER_COUNT=$P4F_MARKER_COUNT"
echo "ROUTE_LINKS_MARKER_COUNT=$ROUTE_LINKS_MARKER_COUNT"
echo "ROUTE_LINK_ITEM_COUNT=$ROUTE_LINK_ITEM_COUNT"
echo "ROUTE_TITLE_COUNT=$ROUTE_TITLE_COUNT"
echo "V42_TITLE_COUNT=$V42_TITLE_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

echo
echo "=== 9) ROUTE PROBE DASHBOARD LINKS ==="

cat > "$ROUTE_PROBE" <<PROBEHDR
lane_id	category	route	expected_title	http_status	dom_bytes	expected_title_count	portal_os_count	mission_count	engineering_count	route_result
PROBEHDR

if [ "$BUILD_RESULT" = "PASS" ] && [ -n "${CHROME_BIN:-}" ]; then
  tail -n +2 "$ROUTE_TARGETS" | while IFS=$'\t' read -r lane_id category lane_title module_title route status source score; do
    SAFE_NAME="$(echo "${lane_id}_${route}" | tr '#/' '__' | tr -cd 'A-Za-z0-9_.-')"
    DOM_ROUTE="$ROUTE_DOM_DIR/${SAFE_NAME}.dom.txt"
    URL="http://127.0.0.1:5173/${route}"

    TMP="$(mktemp)"
    HTTP_CODE="$(curl -sS -L --max-time 8 -o "$TMP" -w "%{http_code}" "$URL" || echo "000")"
    rm -f "$TMP"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1440,900 \
      --virtual-time-budget=7000 \
      --dump-dom \
      "$URL" > "$DOM_ROUTE" 2>/dev/null || true

    DOM_BYTES="$(wc -c < "$DOM_ROUTE" | tr -d ' ')"
    TITLE_COUNT="$(safe_count_literal "$module_title" "$DOM_ROUTE")"
    PORTAL_OS_COUNT="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$DOM_ROUTE")"
    MISSION_COUNT="$(safe_count_literal 'Mission Overview' "$DOM_ROUTE")"
    ENG_COUNT="$(safe_count_literal 'Engineering Orchestrator' "$DOM_ROUTE")"

    ROUTE_RESULT="REVIEW"
    if [ "$HTTP_CODE" != "200" ]; then
      ROUTE_RESULT="NON_200"
    elif [ "$DOM_BYTES" = "0" ]; then
      ROUTE_RESULT="EMPTY_DOM"
    elif [ "$TITLE_COUNT" -gt 0 ]; then
      ROUTE_RESULT="EXPECTED_TITLE_VISIBLE"
    elif [ "$PORTAL_OS_COUNT" -gt 0 ]; then
      ROUTE_RESULT="PORTAL_OS_FALLBACK_VISIBLE"
    elif [ "$MISSION_COUNT" -gt 0 ] || [ "$ENG_COUNT" -gt 0 ]; then
      ROUTE_RESULT="APP_ROUTE_VISIBLE_NO_EXPECTED_TITLE"
    else
      ROUTE_RESULT="UNKNOWN_RENDER"
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$lane_id" "$category" "$route" "$module_title" "$HTTP_CODE" "$DOM_BYTES" "$TITLE_COUNT" "$PORTAL_OS_COUNT" "$MISSION_COUNT" "$ENG_COUNT" "$ROUTE_RESULT" \
      >> "$ROUTE_PROBE"
  done
else
  echo "chrome	unavailable	-	-	000	0	0	0	0	0	SKIPPED_NO_CHROME_OR_BUILD_FAIL" >> "$ROUTE_PROBE"
fi

column -t -s $'\t' "$ROUTE_PROBE"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"
ROUTE_NON_200="$(awk -F'\t' 'NR>1 && $5!="200"{c++} END {print c+0}' "$ROUTE_PROBE")"
ROUTE_EXPECTED_VISIBLE="$(awk -F'\t' 'NR>1 && $11=="EXPECTED_TITLE_VISIBLE"{c++} END {print c+0}' "$ROUTE_PROBE")"
ROUTE_REVIEW_COUNT="$(awk -F'\t' 'NR>1 && $11!="EXPECTED_TITLE_VISIBLE"{c++} END {print c+0}' "$ROUTE_PROBE")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FRONTEND_HTTP_NON_200" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$FRONTEND_HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P4F_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P4F_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$ROUTE_LINKS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_ROUTE_LINKS_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$ROUTE_LINK_ITEM_COUNT" -lt 8 ]; then RESULT="REVIEW_ROUTE_LINK_ITEMS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE_IN_PORTAL_OS"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

# I link sono attivi anche se alcune route legacy risultano da promuovere.
# In quel caso il risultato è operativo ma richiede route promotion.
if [ "$RESULT" = "PASS" ] && [ "$ROUTE_REVIEW_COUNT" != "0" ]; then
  RESULT="PASS_LINKS_ACTIVE_ROUTE_REVIEW_NEEDED"
fi

if [ "$RESULT" = "PASS" ] || [ "$RESULT" = "PASS_LINKS_ACTIVE_ROUTE_REVIEW_NEEDED" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4F-A DASHBOARD ROUTE LINKS

Timestamp: $TS

Status:
- Dashboard route links activated inside Portal OS.
- Route probe generated for dashboard pages and known routes.
- V42 untouched.
- No iframe.
- No unsafe DOM mutation.
- No secondary root.
- Build/HTTP/static/DOM/screenshot executed.

Route result:
- expected_visible: $ROUTE_EXPECTED_VISIBLE
- review_count: $ROUTE_REVIEW_COUNT

Next:
Promote missing legacy routes into clean React route components where route_probe marks fallback/review.
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4F_A_DASHBOARD_ROUTE_LINKS_AND_PROBE_V1",
  "mutation": "portal_os_dashboard_route_links",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "diff": "$DIFF",
  "route_targets": "$ROUTE_TARGETS",
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
  "p4f_marker_count": $P4F_MARKER_COUNT,
  "route_links_marker_count": $ROUTE_LINKS_MARKER_COUNT,
  "route_link_item_count": $ROUTE_LINK_ITEM_COUNT,
  "route_title_count": $ROUTE_TITLE_COUNT,
  "v42_title_count": $V42_TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "route_non_200": $ROUTE_NON_200,
  "route_expected_visible": $ROUTE_EXPECTED_VISIBLE,
  "route_review_count": $ROUTE_REVIEW_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4f_a_dashboard_route_links_and_probe_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4F_A_DASHBOARD_ROUTE_LINKS_AND_PROBE_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
