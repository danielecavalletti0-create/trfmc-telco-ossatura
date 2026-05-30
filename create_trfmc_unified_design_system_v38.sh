#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_UNIFIED_DESIGN_SYSTEM_V38_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_UNIFIED_DESIGN_SYSTEM_V38_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_UNIFIED_DESIGN_SYSTEM_V38_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"

CONTENT_CHECK="$RDIR/content_checks.txt"
HTTP_TSV="$RDIR/http.tsv"
BUILD_LOG="$RDIR/npm_build_v38.log"

mkdir -p "$QDIR" "$RDIR" runtime/freezes

echo "============================================================"
echo "TRFMC UNIFIED DESIGN SYSTEM V38"
echo "CSS normalization layer · no backend/nginx/systemd mutation"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$STYLES" || { echo "ERRORE: styles.css mancante"; exit 1; }

test -f runtime/quality/latest_command_center_fusion_v37/summary.json || {
  echo "ERRORE: V37 final summary mancante"
  exit 1
}

V37_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_command_center_fusion_v37/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V37_RESULT" = "PASS" ] || {
  echo "ERRORE: V37 non PASS: $V37_RESULT"
  exit 1
}

grep -q "RFOperationalDeckV37CommandCenterFusion" "$MAIN" || {
  echo "ERRORE: main.tsx non monta V37"
  grep -n "RFOperationalDeck" "$MAIN" || true
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: API 4181 non operative"
  exit 1
}

echo "OK: V37 PASS, ramo attivo V37, API live"

echo
echo "=== BACKUP PRE-PATCH ==="

PRE_FREEZE="$ROOT/runtime/freezes/TRFMC_BEFORE_UNIFIED_DESIGN_SYSTEM_V38_$TS.tar.gz"

tar -czf "$PRE_FREEZE" \
  frontend/src/styles.css \
  frontend/src/app/main.tsx \
  frontend/src/command_center \
  frontend/src/rf_scenarios \
  frontend/src/rf_instruments \
  2>/dev/null || true

cp "$STYLES" "$RDIR/styles.css.before_v38_$TS"
cp "$MAIN" "$RDIR/main.tsx.before_v38_$TS"

echo "Pre-freeze: $PRE_FREEZE"

echo
echo "=== APPEND V38 DESIGN SYSTEM CSS ==="

if grep -q "TRFMC V38 UNIFIED DESIGN SYSTEM" "$STYLES"; then
  echo "V38 CSS già presente: non duplico."
else
cat >> "$STYLES" <<'CSS'

/* === TRFMC V38 UNIFIED DESIGN SYSTEM === */
:root{
  --trfmc-bg-0:#020812;
  --trfmc-bg-1:#06111f;
  --trfmc-bg-2:#081a2d;
  --trfmc-panel:rgba(5,17,31,.78);
  --trfmc-panel-strong:rgba(5,20,36,.92);
  --trfmc-panel-soft:rgba(8,25,42,.62);
  --trfmc-border:rgba(117,234,255,.22);
  --trfmc-border-strong:rgba(117,234,255,.34);
  --trfmc-border-green:rgba(141,255,189,.26);
  --trfmc-cyan:#75eaff;
  --trfmc-cyan-soft:#9eefff;
  --trfmc-green:#8dffbd;
  --trfmc-amber:#ffd37b;
  --trfmc-red:#ff7890;
  --trfmc-text:#f1fbff;
  --trfmc-muted:#9ab5c9;
  --trfmc-muted-2:#7894a8;
  --trfmc-radius-xl:28px;
  --trfmc-radius-lg:22px;
  --trfmc-radius-md:16px;
  --trfmc-shadow-deep:0 34px 95px rgba(0,0,0,.42);
  --trfmc-shadow-panel:0 22px 65px rgba(0,0,0,.32);
  --trfmc-gradient-shell:
    radial-gradient(circle at 12% 0%,rgba(80,215,255,.18),transparent 34%),
    radial-gradient(circle at 88% 10%,rgba(141,255,189,.11),transparent 30%),
    linear-gradient(135deg,rgba(2,9,17,.98),rgba(4,14,25,.98));
}

/* Global TRFMC panel coherence */
.v37-command-shell,
.v36-scenario-shell,
.v35-scenario-shell,
.v34r1-native-readiness-strip,
.v32r1-live-contract-shell{
  border-radius:var(--trfmc-radius-xl) !important;
  border-color:var(--trfmc-border) !important;
  background:var(--trfmc-gradient-shell) !important;
  box-shadow:var(--trfmc-shadow-deep), inset 0 0 44px rgba(80,215,255,.045) !important;
}

/* Unified headers */
.v37-command-header h2,
.v36-scenario-header h2,
.v35-scenario-header h2,
.v32r1-live-contract-header h2,
.v34r1-native-readiness-head h3{
  color:var(--trfmc-text) !important;
  letter-spacing:-.02em;
}

.v37-command-header p,
.v36-scenario-header p,
.v35-scenario-header p,
.v32r1-eyebrow,
.v34r1-native-readiness-head p{
  color:var(--trfmc-cyan) !important;
  letter-spacing:.22em !important;
  text-transform:uppercase !important;
}

/* Unified descriptive text */
.v37-command-header span,
.v36-scenario-header span,
.v35-scenario-header span,
.v32r1-live-contract-header span,
.v37-command-tile p,
.v36-control-panel > p:not(.v36-eyebrow),
.v35-scenario-info > p:not(.v35-eyebrow){
  color:var(--trfmc-muted) !important;
}

/* Unified cards and tiles */
.v37-command-tile,
.v36-control-panel,
.v35-scenario-info,
.v32r1-contract-card,
.v34r1-native-readiness-grid article,
.v36-profile-grid article,
.v35-knowledge-stack div,
.v37-kpis div{
  border-radius:var(--trfmc-radius-md) !important;
  border-color:rgba(117,234,255,.16) !important;
  background:var(--trfmc-panel-soft) !important;
}

/* Unified active controls */
.v37-command-controls button.v37-domain-active,
.v36-tabs button.v36-tab-active,
.v36-layer-switches button.v36-layer-on,
.v35-scenario-tabs button.v35-tab-active{
  color:#06131d !important;
  background:linear-gradient(135deg,var(--trfmc-cyan),var(--trfmc-green)) !important;
  border-color:transparent !important;
  box-shadow:0 0 22px rgba(117,234,255,.22) !important;
}

/* Unified inactive controls */
.v37-command-controls button,
.v36-tabs button,
.v36-layer-switches button,
.v35-scenario-tabs button,
.v32r1-contract-footer button,
.v34r1-native-readiness-strip footer button{
  border-color:rgba(117,234,255,.22) !important;
  background:rgba(6,19,34,.78) !important;
  color:#a6bdd2 !important;
  border-radius:999px !important;
}

/* Unified status badges */
.v37-live-badge,
.v32r1-contract-card-head strong,
.v34r1-native-readiness-head > strong,
.v36-status-pack,
.v37-command-score,
.v35-scenario-header > strong{
  border-radius:var(--trfmc-radius-md) !important;
}

.v37-live-ok,
.v32r1-contract-card-ok .v32r1-contract-card-head strong{
  color:var(--trfmc-green) !important;
}

.v37-live-warn,
.v37-live-local,
.v32r1-contract-card-warn .v32r1-contract-card-head strong{
  color:var(--trfmc-amber) !important;
}

.v37-live-down,
.v32r1-contract-card-down .v32r1-contract-card-head strong{
  color:var(--trfmc-red) !important;
}

/* Unified code/source labels */
.v37-command-tile code,
.v32r1-contract-card code{
  border-radius:12px !important;
  color:var(--trfmc-cyan) !important;
  background:rgba(1,8,15,.58) !important;
}

/* Unified visual runtime frames */
.v36-asset-frame,
.v36-procedural,
.v35-scenario-visual{
  border-radius:24px !important;
  border-color:rgba(117,234,255,.22) !important;
  box-shadow:var(--trfmc-shadow-panel) !important;
}

/* Unified KPI elements */
.v37-kpis strong,
.v36-floating-metrics strong,
.v36-status-pack strong,
.v35-kpi-grid strong,
.v37-command-score strong,
.v34r1-native-readiness-head > strong,
.v32r1-score strong{
  color:var(--trfmc-green) !important;
}

/* Unified hotspot styling */
.v36-hotspot,
.v35-hotspot{
  border-color:rgba(117,234,255,.34) !important;
  background:rgba(3,13,24,.76) !important;
  color:var(--trfmc-text) !important;
  box-shadow:0 0 22px rgba(80,215,255,.16) !important;
}

.v36-hotspot i,
.v35-hotspot span{
  background:var(--trfmc-cyan) !important;
  box-shadow:0 0 18px var(--trfmc-cyan) !important;
}

/* Layout rhythm normalization */
.v37-command-shell,
.v36-scenario-shell,
.v35-scenario-shell,
.v32r1-live-contract-shell{
  margin:18px !important;
  padding:18px !important;
}

/* High-value lab identity overlay */
.v37-command-shell::before,
.v36-scenario-shell::before,
.v35-scenario-shell::before{
  content:"";
  display:block;
  height:1px;
  margin:-4px 0 14px;
  background:linear-gradient(90deg,transparent,rgba(117,234,255,.45),rgba(141,255,189,.30),transparent);
}

/* Accessibility/legibility improvements */
.v37-command-tile,
.v36-control-panel,
.v35-scenario-info,
.v32r1-contract-card{
  backdrop-filter:blur(4px);
}

.v37-command-tile h3,
.v36-control-panel h3,
.v35-scenario-info h3{
  line-height:1.12;
}

/* Responsive consistency */
@media (max-width:900px){
  .v37-command-shell,
  .v36-scenario-shell,
  .v35-scenario-shell,
  .v32r1-live-contract-shell{
    margin:12px !important;
    padding:14px !important;
  }
}
CSS
fi

echo
echo "=== STATIC CHECKS ==="

{
  grep -q "TRFMC V38 UNIFIED DESIGN SYSTEM" "$STYLES" && echo "OK: V38 CSS marker present" || echo "MISS: V38 CSS marker present"
  grep -q -- "--trfmc-bg-0" "$STYLES" && echo "OK: design tokens present" || echo "MISS: design tokens present"
  grep -q ".v37-command-shell" "$STYLES" && echo "OK: V37 normalized" || echo "MISS: V37 normalized"
  grep -q ".v36-scenario-shell" "$STYLES" && echo "OK: V36 normalized" || echo "MISS: V36 normalized"
  grep -q ".v35-scenario-shell" "$STYLES" && echo "OK: V35 normalized" || echo "MISS: V35 normalized"
  grep -q ".v34r1-native-readiness-strip" "$STYLES" && echo "OK: V34 normalized" || echo "MISS: V34 normalized"
  grep -q ".v32r1-live-contract-shell" "$STYLES" && echo "OK: V32 normalized" || echo "MISS: V32 normalized"
  grep -q "RFOperationalDeckV37CommandCenterFusion" "$MAIN" && echo "OK: active V37 preserved" || echo "MISS: active V37 preserved"
  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" && echo "OK: backend API still live" || echo "MISS: backend API still live"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

echo
echo "=== BUILD CHECK ==="

(
  cd "$ROOT/frontend"
  npm run build > "$BUILD_LOG" 2>&1
) && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"

echo "Build result: $BUILD_RESULT"

if [ "$BUILD_RESULT" = "FAIL" ]; then
  tail -n 180 "$BUILD_LOG" || true
fi

echo
echo "=== HTTP GATE ==="

printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="$(printf "%s" "$meta" | awk '{print $1}')"
  bytes="$(printf "%s" "$meta" | awk '{print $2}')"
  printf "%s\t%s\t%s\n" "$u" "${code:-000}" "${bytes:-0}" >> "$HTTP_TSV"
}

for u in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:4181/api/mission/status \
  http://127.0.0.1:4181/api/core/open5gs/status \
  http://127.0.0.1:4181/api/rfpro/spectrum/sweep
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== CREATE ROLLBACK ==="

ROLLBACK="$RDIR/rollback_v38_unified_design_system.sh"

cat > "$ROLLBACK" <<ROLLBACK_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "$RDIR/styles.css.before_v38_$TS" frontend/src/styles.css
cp "$RDIR/main.tsx.before_v38_$TS" frontend/src/app/main.tsx
echo "Rollback V38 Unified Design System completato"
ROLLBACK_EOF

chmod +x "$ROLLBACK"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$BUILD_RESULT" = "FAIL" ] || [ "$HTTP_NON_200" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

MANIFEST="$RDIR/unified_design_system_manifest_v38.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_UNIFIED_DESIGN_SYSTEM_V38",
  "strategy": "css_design_token_and_component_normalization_layer",
  "frontend_mutation": true,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "patched": [
    "$STYLES"
  ],
  "preserves_active_mount": "RFOperationalDeckV37CommandCenterFusion",
  "normalizes": [
    "V37 command center",
    "V36 scenario runtime",
    "V35 scenario shell",
    "V34 readiness strip",
    "V32 live contract overlay"
  ],
  "pre_freeze": "$PRE_FREEZE",
  "rollback": "$ROLLBACK",
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_UNIFIED_DESIGN_SYSTEM_V38",
  "release_dir": "$RDIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "pre_freeze": "$PRE_FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "build_log": "$BUILD_LOG",
  "rollback": "$ROLLBACK",
  "active_mount": "RFOperationalDeckV37CommandCenterFusion",
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/styles.css \
  frontend/src/app/main.tsx \
  "$RDIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_unified_design_system_v38"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_unified_design_system_v38"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: risultato $RESULT"
  exit 1
fi

echo
echo "============================================================"
echo "V38 UNIFIED DESIGN SYSTEM COMPLETATO IN PASS"
echo "============================================================"
