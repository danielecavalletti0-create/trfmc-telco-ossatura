#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4E_RESUME_EXISTING_PROXY_DASHBOARD_V2_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
CSS="frontend/src/portal-os/portal-os.css"
MAIN="frontend/src/app/main.tsx"

VITE_CONFIG=""
for c in frontend/vite.config.ts frontend/vite.config.js frontend/vite.config.mts frontend/vite.config.mjs; do
  if [ -f "$c" ]; then
    VITE_CONFIG="$c"
    break
  fi
done

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
PROXY_JSON="$OUT/proxy_json_gate.tsv"
BUILDLOG="$OUT/npm_build_p4e_resume.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p4e_resume_dashboard_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4e_resume_dashboard.diff"
RESTORE="$OUT/RESTORE_P4E_RESUME_EXISTING_PROXY_DASHBOARD_V2.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4E_RESUME_DASHBOARD_PASS_$TS"

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

json_probe() {
  local label="$1"
  local url="$2"
  local raw="$OUT/${label}.raw"
  local code
  code="$(curl -sS -L --max-time 8 -o "$raw" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$raw" | tr -d ' ')"

  python3 - "$label" "$url" "$code" "$bytes" "$raw" <<'PY'
import json, sys
from pathlib import Path

label, url, code, bytes_, raw = sys.argv[1:]
p = Path(raw)
text = p.read_text(encoding="utf-8", errors="replace") if p.exists() else ""
first = text[:90].replace("\n", " ").replace("\t", " ")

json_parse = "NO"
kind = "UNKNOWN"
classification = "REVIEW"

try:
    obj = json.loads(text)
    json_parse = "YES"
    if isinstance(obj, dict):
        kind = "JSON_OBJECT"
    elif isinstance(obj, list):
        kind = "JSON_ARRAY"
    else:
        kind = "JSON_VALUE"
except Exception:
    if "<html" in text.lower() or "<!doctype" in text.lower():
        kind = "HTML_FALLBACK"
    elif not text:
        kind = "EMPTY"
    else:
        kind = "TEXT_NON_JSON"

if code == "200" and json_parse == "YES":
    classification = "OK_JSON"
elif code == "200" and kind == "HTML_FALLBACK":
    classification = "HTML_FALLBACK_REVIEW"
elif code != "200":
    classification = "NON_200_REVIEW"
else:
    classification = "NON_JSON_REVIEW"

print(f"{label}\t{url}\t{code}\t{bytes_}\t{json_parse}\t{kind}\t{classification}\t{first}")
PY
}

echo "============================================================"
echo "TRFMC_P4E_RESUME_EXISTING_PROXY_DASHBOARD_V2"
echo "No blind vite merge · validate proxy JSON · activate dashboard pages"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$VITE_CONFIG" ]; then
  echo "ERRORE: vite.config non trovato"
  exit 1
fi

for f in "$ROOT" "$CSS" "$MAIN" "$VITE_CONFIG"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"
cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"
cp -a "$VITE_CONFIG" "$BACKUP/$(basename "$VITE_CONFIG").before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"
cp -a "$BACKUP/$(basename "$VITE_CONFIG").before_$TS" "$VITE_CONFIG"
echo "RESTORE_P4E_RESUME_EXISTING_PROXY_DASHBOARD_V2 completato"
RESTORE_EOF
chmod +x "$RESTORE"

echo
echo "=== 1) PROXY JSON GATE PRE-MUTATION ==="
{
  echo -e "label\turl\tstatus\tbytes\tjson_parse\tkind\tclassification\tfirst_bytes"
  json_probe "direct_backend_8000" "http://127.0.0.1:8000/api/health"
  json_probe "direct_bridge_4181" "http://127.0.0.1:4181/api/health"
  json_probe "proxy_backend_5173" "http://127.0.0.1:5173/trfmc-api/backend/api/health"
  json_probe "proxy_bridge_5173" "http://127.0.0.1:5173/trfmc-api/bridge/api/health"
} | tee "$PROXY_JSON" | column -t -s $'\t'

PROXY_BACKEND_OK="$(awk -F'\t' '$1=="proxy_backend_5173" && $7=="OK_JSON"{print 1}' "$PROXY_JSON" | head -n 1)"
PROXY_BRIDGE_OK="$(awk -F'\t' '$1=="proxy_bridge_5173" && $7=="OK_JSON"{print 1}' "$PROXY_JSON" | head -n 1)"

echo
echo "=== 2) PATCH PortalOSRoot: same-origin endpoints + dashboard pages ==="

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

text = text.replace(
    "{ id: 'backend', label: 'Backend 8000', url: 'http://127.0.0.1:8000/api/health', state: 'pending', detail: 'health API' },",
    "{ id: 'backend', label: 'Backend 8000', url: '/trfmc-api/backend/api/health', state: 'pending', detail: 'same-origin proxy → 8000' },"
)
text = text.replace(
    "{ id: 'bridge', label: 'Bridge 4181', url: 'http://127.0.0.1:4181/api/health', state: 'pending', detail: 'RF bridge' },",
    "{ id: 'bridge', label: 'Bridge 4181', url: '/trfmc-api/bridge/api/health', state: 'pending', detail: 'same-origin proxy → 4181' },"
)

old_error = """detail:
                endpoint.id === 'bridge'
                  ? 'browser fetch blocked/offline; CORS/proxy pending'
                  : error instanceof Error
                    ? error.message.slice(0, 90)
                    : 'browser probe blocked/offline',"""
new_error = """detail:
                endpoint.id === 'bridge'
                  ? 'same-origin proxy pending; restart Vite if still blocked'
                  : error instanceof Error
                    ? error.message.slice(0, 90)
                    : 'browser probe blocked/offline',"""
if old_error in text:
    text = text.replace(old_error, new_error, 1)

anchor = """const topOperationalModules = [...portalOSModules]
  .filter((module) => module.status === 'promoted' || String(module.status).startsWith('candidate'))
  .sort((a, b) => moduleScore(b) - moduleScore(a))
  .slice(0, 16)

"""

dashboard_const = """const dashboardLaneIds = ['core-ran', 'dsp', 'antenna', 'digital-twin', 'war-room', 'noc', 'sigint', 'knowledge']

"""

if dashboard_const.strip() not in text:
    if anchor not in text:
        raise SystemExit("ERRORE: anchor topOperationalModules non trovato")
    text = text.replace(anchor, anchor + dashboard_const, 1)

if 'data-trfmc-p4e-data-fabric-dashboard="mounted"' not in text:
    text = text.replace(
        'data-trfmc-p4dc-visual-correction="mounted"\n    >',
        'data-trfmc-p4dc-visual-correction="mounted"\n      data-trfmc-p4e-data-fabric-dashboard="mounted"\n    >',
        1
    )

dashboard_section = """          <section className="trfmc-command-dashboard-pages" data-trfmc-dashboard-pages="active">
            <div className="trfmc-command-strip-head">
              <span>Dashboard pages</span>
              <strong>principal routes active</strong>
            </div>

            <div className="trfmc-command-dashboard-grid">
              {dashboardLaneIds.map((laneId) => {
                const lane = lanes.find((item) => item.id === laneId)
                if (!lane) return null
                const stats = getLaneStats(lane.category)
                const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]

                return (
                  <button
                    key={lane.id}
                    type="button"
                    className={lane.id === selectedLane.id ? 'is-active' : ''}
                    onClick={() => {
                      setSelectedLaneId(lane.id)
                      if (first) setActiveModuleId(first.id)
                    }}
                  >
                    <span>dashboard</span>
                    <strong>{lane.title}</strong>
                    <em>{stats.total} modules · {stats.visual} visual · {first?.title ?? 'no module'}</em>
                  </button>
                )
              })}
            </div>
          </section>

"""

if 'data-trfmc-dashboard-pages="active"' not in text:
    marker = '          <section className="trfmc-command-module-strip">'
    if marker not in text:
        raise SystemExit("ERRORE: punto inserimento dashboard pages non trovato")
    text = text.replace(marker, dashboard_section + marker, 1)

text = text.replace("<strong>P4D-B</strong>", "<strong>P4E</strong>")
text = text.replace(
    "Portal OS home is now manifest-governed. Legacy HTML remains source/reference, not primary runtime.",
    "Portal OS home is manifest-governed; dashboard pages and same-origin data fabric are active."
)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 3) PATCH CSS dashboard pages se mancante ==="

if ! grep -q "TRFMC P4E DATA FABRIC DASHBOARD ACTIVATION START" "$CSS"; then
cat >> "$CSS" <<'CSS'

/* TRFMC P4E DATA FABRIC DASHBOARD ACTIVATION START */
.trfmc-command-dashboard-pages {
  margin-top: 10px;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 18px;
  background:
    radial-gradient(circle at 18% 0%, rgba(103, 232, 249, .08), transparent 32%),
    rgba(0, 6, 16, .36);
  padding: 10px;
}

.trfmc-command-dashboard-grid {
  margin-top: 8px;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
}

.trfmc-command-dashboard-grid button {
  text-align: left;
  border: 1px solid rgba(103, 232, 249, .14);
  border-radius: 14px;
  background: linear-gradient(180deg, rgba(1, 18, 32, .64), rgba(0, 7, 16, .46));
  color: inherit;
  padding: 10px;
  cursor: pointer;
}

.trfmc-command-dashboard-grid button:hover,
.trfmc-command-dashboard-grid button.is-active {
  border-color: rgba(134, 239, 172, .46);
  background: rgba(8, 47, 38, .24);
  box-shadow: inset 0 0 0 1px rgba(134, 239, 172, .18), 0 0 28px rgba(16, 185, 129, .12);
}

.trfmc-command-dashboard-grid span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-dashboard-grid strong {
  display: block;
  margin-top: 5px;
  color: #e8f7ff;
  font-size: 12px;
  line-height: 1.12;
}

.trfmc-command-dashboard-grid em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 9.5px;
  font-style: normal;
  line-height: 1.25;
}

.trfmc-command-endpoint.is-online em {
  color: #86efac;
}

@media (max-width: 1440px) {
  .trfmc-command-dashboard-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
/* TRFMC P4E DATA FABRIC DASHBOARD ACTIVATION END */
CSS
fi

echo
echo "=== 4) DIFF ==="
git diff -- "$ROOT" "$CSS" "$MAIN" "$VITE_CONFIG" > "$DIFF" || true
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
check_url "http://127.0.0.1:5173/trfmc-api/backend/api/health"
check_url "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

FRONTEND_HTTP_NON_200="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
FRONTEND_HTTP_ZERO_BYTES="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 7) STATIC GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" frontend/src/portal-os "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" frontend/src/portal-os "$MAIN")"
  EXTRA_ROOT_CALLS="$(safe_count_files "\\bcreateRoot[[:space:]]*\\(" frontend/src/portal-os)"
  V42_P4E_COUNT="$(safe_count_files "P4E|dashboard-pages|trfmc-api|data-fabric" frontend/src/layout_orchestrator 2>/dev/null || true)"
  P4E_MARKER_SOURCE="$(safe_count_files "data-trfmc-p4e-data-fabric-dashboard" "$ROOT")"
  DASHBOARD_MARKER_SOURCE="$(safe_count_files "data-trfmc-dashboard-pages" "$ROOT")"
  PROXY_SOURCE="$(safe_count_files "/trfmc-api/bridge|/trfmc-api/backend" "$VITE_CONFIG" "$ROOT")"
  DIRECT_4181_IN_ROOT="$(safe_count_files "http://127\\.0\\.0\\.1:4181" "$ROOT")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_call_in_portal_os\t$([ "$EXTRA_ROOT_CALLS" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_CALLS"
  echo -e "v42_not_touched_by_p4e\t$([ "$V42_P4E_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4E_COUNT"
  echo -e "p4e_marker_source_present\t$([ "$P4E_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$P4E_MARKER_SOURCE"
  echo -e "dashboard_pages_source_present\t$([ "$DASHBOARD_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$DASHBOARD_MARKER_SOURCE"
  echo -e "same_origin_proxy_source_present\t$([ "$PROXY_SOURCE" -gt 3 ] && echo PASS || echo FAIL)\t$PROXY_SOURCE"
  echo -e "no_direct_4181_in_portal_root\t$([ "$DIRECT_4181_IN_ROOT" = "0" ] && echo PASS || echo FAIL)\t$DIRECT_4181_IN_ROOT"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 8) DOM / SCREENSHOT GATE ==="

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
fi

P4E_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p4e-data-fabric-dashboard="mounted"' "$DOM")"
DASHBOARD_MARKER_COUNT="$(safe_count_literal 'data-trfmc-dashboard-pages="active"' "$DOM")"
DASHBOARD_TITLE_COUNT="$(safe_count_literal 'Dashboard pages' "$DOM")"
CORE_DASH_COUNT="$(safe_count_literal '5G Core / RAN' "$DOM")"
ANTENNA_DASH_COUNT="$(safe_count_literal 'RF / Antenna System' "$DOM")"
SIGNAL_DASH_COUNT="$(safe_count_literal 'FFT / DSP / Signal' "$DOM")"
V42_TITLE_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P4E_MARKER_COUNT=$P4E_MARKER_COUNT"
echo "DASHBOARD_MARKER_COUNT=$DASHBOARD_MARKER_COUNT"
echo "DASHBOARD_TITLE_COUNT=$DASHBOARD_TITLE_COUNT"
echo "CORE_DASH_COUNT=$CORE_DASH_COUNT"
echo "ANTENNA_DASH_COUNT=$ANTENNA_DASH_COUNT"
echo "SIGNAL_DASH_COUNT=$SIGNAL_DASH_COUNT"
echo "V42_TITLE_COUNT=$V42_TITLE_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"
PROXY_JSON_FAILS="$(awk -F'\t' 'NR>1 && $7!="OK_JSON"{c++} END {print c+0}' "$PROXY_JSON")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FRONTEND_HTTP_NON_200" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$FRONTEND_HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$PROXY_JSON_FAILS" != "0" ]; then RESULT="REVIEW_PROXY_JSON"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P4E_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P4E_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$DASHBOARD_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DASHBOARD_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$DASHBOARD_TITLE_COUNT" = "0" ]; then RESULT="REVIEW_DASHBOARD_TITLE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE_IN_PORTAL_OS"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$VITE_CONFIG" "$FREEZE/$(basename "$VITE_CONFIG")"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4E RESUME DASHBOARD PASS

Timestamp: $TS

Status:
- Existing Vite proxy validated as JSON, not HTML fallback.
- PortalOSRoot uses same-origin data fabric paths.
- Dashboard pages principal routes active.
- V42 untouched.
- No iframe.
- No unsafe DOM mutation.
- No secondary root.
- Build/HTTP/static/proxy-json/DOM/screenshot PASS.

Next:
P4F default Portal OS promotion review or P5 first real dashboard module promotion.
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4E_RESUME_EXISTING_PROXY_DASHBOARD_V2",
  "mutation": "portal_os_dashboard_pages_plus_same_origin_endpoints",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "vite_config": "$VITE_CONFIG",
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "proxy_json_gate": "$PROXY_JSON",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $FRONTEND_HTTP_NON_200,
  "frontend_http_zero_bytes": $FRONTEND_HTTP_ZERO_BYTES,
  "static_failures": $STATIC_FAILS,
  "proxy_json_failures": $PROXY_JSON_FAILS,
  "dom_result": "$DOM_RESULT",
  "p4e_marker_count": $P4E_MARKER_COUNT,
  "dashboard_marker_count": $DASHBOARD_MARKER_COUNT,
  "dashboard_title_count": $DASHBOARD_TITLE_COUNT,
  "core_dash_count": $CORE_DASH_COUNT,
  "antenna_dash_count": $ANTENNA_DASH_COUNT,
  "signal_dash_count": $SIGNAL_DASH_COUNT,
  "v42_title_count": $V42_TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4e_resume_existing_proxy_dashboard_v2"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4E_RESUME_EXISTING_PROXY_DASHBOARD_V2 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
