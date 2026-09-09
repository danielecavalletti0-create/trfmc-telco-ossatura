#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4E_DATA_FABRIC_PROXY_DASHBOARD_ACTIVATION_V1_$TS"
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
BUILDLOG="$OUT/npm_build_p4e_data_fabric_dashboard.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p4e_data_fabric_dashboard_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4e_data_fabric_dashboard.diff"
RESTORE="$OUT/RESTORE_P4E_DATA_FABRIC_PROXY_DASHBOARD_ACTIVATION_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4E_DATA_FABRIC_DASHBOARD_PASS_$TS"
RESTART_NOTE="$OUT/RESTART_VITE_REQUIRED.txt"

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
echo "TRFMC_P4E_DATA_FABRIC_PROXY_DASHBOARD_ACTIVATION_V1"
echo "Same-origin Vite proxy + dashboard pages principali"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$VITE_CONFIG" ]; then
  echo "ERRORE: vite.config non trovato in frontend/"
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

echo "RESTORE_P4E_DATA_FABRIC_PROXY_DASHBOARD_ACTIVATION_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH vite.config: aggiungo proxy same-origin ==="

python3 - "$VITE_CONFIG" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

proxy_block = """  server: {
    proxy: {
      '/trfmc-api/backend': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/backend/, ''),
      },
      '/trfmc-api/bridge': {
        target: 'http://127.0.0.1:4181',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/bridge/, ''),
      },
    },
  },
"""

if "/trfmc-api/bridge" in text and "/trfmc-api/backend" in text:
    print("VITE_PROXY_ALREADY_PRESENT=1")
    print("PATCHED=0")
    sys.exit(0)

if "server:" in text:
    raise SystemExit("REVIEW_REQUIRED: vite.config contiene già server:. Non faccio merge cieco.")

# defineConfig({ ... })
m = re.search(r"defineConfig\s*\(\s*\{", text)
if m:
    insert_at = m.end()
    text = text[:insert_at] + "\n" + proxy_block + text[insert_at:]
else:
    # fallback: export default { ... }
    m = re.search(r"export\s+default\s+\{", text)
    if not m:
      raise SystemExit("REVIEW_REQUIRED: formato vite.config non riconosciuto.")
    insert_at = m.end()
    text = text[:insert_at] + "\n" + proxy_block + text[insert_at:]

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 2) PATCH PortalOSRoot: endpoint same-origin + dashboard pages ==="

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

helper_anchor = """const topOperationalModules = [...portalOSModules]
  .filter((module) => module.status === 'promoted' || String(module.status).startsWith('candidate'))
  .sort((a, b) => moduleScore(b) - moduleScore(a))
  .slice(0, 16)

"""

dashboard_const = """const dashboardLaneIds = ['core-ran', 'dsp', 'antenna', 'digital-twin', 'war-room', 'noc', 'sigint', 'knowledge']

"""

if dashboard_const.strip() not in text:
    if helper_anchor not in text:
        raise SystemExit("ERRORE: anchor topOperationalModules non trovato")
    text = text.replace(helper_anchor, helper_anchor + dashboard_const, 1)

marker_old = """      data-trfmc-p4dc-visual-correction="mounted"
    >"""
marker_new = """      data-trfmc-p4dc-visual-correction="mounted"
      data-trfmc-p4e-data-fabric-dashboard="mounted"
    >"""
if marker_old in text and "data-trfmc-p4e-data-fabric-dashboard" not in text:
    text = text.replace(marker_old, marker_new, 1)

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

insert_before = """          <section className="trfmc-command-module-strip">"""
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
    if insert_before not in text:
        raise SystemExit("ERRORE: punto inserimento dashboard pages non trovato")
    text = text.replace(insert_before, dashboard_section + insert_before, 1)

text = text.replace("<strong>P4D-B</strong>", "<strong>P4E</strong>")
text = text.replace(
    "Portal OS home is now manifest-governed. Legacy HTML remains source/reference, not primary runtime.",
    "Portal OS home is manifest-governed; dashboard pages and same-origin data fabric are active."
)

p.write_text(text, encoding="utf-8")
print("PATCHED=", text != before)
PY

echo
echo "=== 3) PATCH CSS: dashboard pages ==="

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
PROXY_NON_200="$(awk 'NR>1 && $1 ~ /trfmc-api/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"

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
else
  echo "BUILD_NOT_PASS" > "$DOM"
  echo "BUILD_NOT_PASS" > "$DOMERR"
  echo "BUILD_NOT_PASS" > "$SCREENERR"
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

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FRONTEND_HTTP_NON_200" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$FRONTEND_HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P4E_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P4E_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$DASHBOARD_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DASHBOARD_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$DASHBOARD_TITLE_COUNT" = "0" ]; then RESULT="REVIEW_DASHBOARD_TITLE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE_IN_PORTAL_OS"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$PROXY_NON_200" != "0" ]; then
  RESULT="SOURCE_READY_RESTART_VITE_FOR_PROXY"
  cat > "$RESTART_NOTE" <<NOTE
P4E ha modificato vite.config per attivare il proxy same-origin.

Il dev server Vite potrebbe dover essere riavviato perché la configurazione proxy venga caricata.

Procedura manuale consigliata:
1) chiudi il processo Vite attuale sulla porta 5173;
2) riavvia da:
   cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend
   npm run dev -- --host 127.0.0.1 --port 5173

Poi riesegui:
curl -sS -o /tmp/p4e_bridge.json -w "%{http_code} %{size_download}\n" http://127.0.0.1:5173/trfmc-api/bridge/api/health
NOTE
fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$VITE_CONFIG" "$FREEZE/$(basename "$VITE_CONFIG")"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4E DATA FABRIC DASHBOARD PASS

Timestamp: $TS

Status:
- Vite same-origin proxy configured for backend 8000 and bridge 4181.
- PortalOSRoot uses /trfmc-api/backend and /trfmc-api/bridge.
- Dashboard pages principali activated inside Command Center Home.
- V42 untouched.
- No iframe.
- No unsafe DOM mutation.
- No secondary root.
- Build/HTTP/static/DOM/screenshot PASS.

Next:
P4F default home promotion or P5 first real dashboard module promotion.
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4E_DATA_FABRIC_PROXY_DASHBOARD_ACTIVATION_V1",
  "mutation": "vite_proxy_plus_portal_os_dashboard_pages",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "vite_config": "$VITE_CONFIG",
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "restart_note": "$RESTART_NOTE",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $FRONTEND_HTTP_NON_200,
  "frontend_http_zero_bytes": $FRONTEND_HTTP_ZERO_BYTES,
  "proxy_non_200": $PROXY_NON_200,
  "static_failures": $STATIC_FAILS,
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

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4e_data_fabric_proxy_dashboard_activation_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4E_DATA_FABRIC_PROXY_DASHBOARD_ACTIVATION_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
