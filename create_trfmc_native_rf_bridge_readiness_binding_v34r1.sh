#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_NATIVE_RF_BRIDGE_READINESS_BINDING_V34R1_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_NATIVE_RF_BRIDGE_READINESS_BINDING_V34R1_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_NATIVE_RF_BRIDGE_READINESS_BINDING_V34R1_$TS.tar.gz"

TARGET="$ROOT/frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx"
BASE="$ROOT/frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9Base.tsx"
STRIP="$ROOT/frontend/src/rf_instruments/telemetry/RFNativeLiveReadinessStripV34R1.tsx"
STYLES="$ROOT/frontend/src/styles.css"
CLIENT="$ROOT/frontend/src/shared/liveContractsV32R1.ts"

echo "============================================================"
echo "TRFMC NATIVE RF BRIDGE READINESS BINDING V34R1"
echo "single-component wrapper · live V31 contracts · build + DOM gate"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f "$TARGET" || { echo "ERRORE: target RFBridgeReadinessV9.tsx mancante"; exit 1; }
test -f "$STYLES" || { echo "ERRORE: styles.css mancante"; exit 1; }
test -f "$CLIENT" || { echo "ERRORE: liveContractsV32R1.ts mancante"; exit 1; }

test -f "$ROOT/runtime/quality/latest_native_rf_panels_binding_feasibility_v34/summary.json" || {
  echo "ERRORE: V34 feasibility summary mancante"
  exit 1
}

test -f "$ROOT/runtime/quality/latest_visual_runtime_qa_v33/summary.json" || {
  echo "ERRORE: V33 visual QA summary mancante"
  exit 1
}

V34_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_native_rf_panels_binding_feasibility_v34/summary.json").read_text())
print(d.get("result",""))
PY
)"

V33_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_visual_runtime_qa_v33/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V34_RESULT" = "PASS" ] || { echo "ERRORE: V34 non PASS"; exit 1; }
[ "$V33_RESULT" = "PASS" ] || { echo "ERRORE: V33 non PASS"; exit 1; }

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: 4181 non passa al backend reale"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/spectrum/sweep | grep -q "TRFMC_CONTRACT_COVERAGE_V31" || {
  echo "ERRORE: contratti V31 non raggiungibili via 4181"
  exit 1
}

if grep -q "RFNativeLiveReadinessStripV34R1" "$TARGET"; then
  echo "ERRORE: target già wrappato da V34R1. Non procedo per evitare doppio wrapper."
  exit 1
fi

grep -q "export function RFBridgeReadinessV9\|export const RFBridgeReadinessV9" "$TARGET" || {
  echo "ERRORE: export RFBridgeReadinessV9 non trovato nel target"
  exit 1
}

echo "OK: V33/V34 PASS, API live, target patchabile"

echo
echo "=== BACKUP PRE-PATCH ==="

PRE_FREEZE="$ROOT/runtime/freezes/TRFMC_BEFORE_NATIVE_RF_BRIDGE_READINESS_BINDING_V34R1_$TS.tar.gz"

tar -czf "$PRE_FREEZE" \
  frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx \
  frontend/src/styles.css \
  frontend/src/shared/liveContractsV32R1.ts \
  2>/dev/null || true

cp "$TARGET" "$RELEASE_DIR/RFBridgeReadinessV9.tsx.before_v34r1_$TS"
cp "$STYLES" "$RELEASE_DIR/styles.css.before_v34r1_$TS"

echo "Pre-freeze: $PRE_FREEZE"

echo
echo "=== CREATE BASE COPY ==="

cp "$TARGET" "$BASE"

echo
echo "=== CREATE NATIVE LIVE READINESS STRIP ==="

cat > "$STRIP" <<'TSX'
import { useEffect, useMemo, useState } from 'react'
import {
  extractString,
  fetchLiveContractSnapshot,
  getEndpointHealth,
  type LiveContractSnapshot,
} from '../../shared/liveContractsV32R1'

export function RFNativeLiveReadinessStripV34R1() {
  const [snapshot, setSnapshot] = useState<LiveContractSnapshot | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [tick, setTick] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    let alive = true

    fetchLiveContractSnapshot(controller.signal)
      .then((next) => {
        if (!alive) return
        setSnapshot(next)
        setError(null)
      })
      .catch((err) => {
        if (!alive) return
        setError(err instanceof Error ? err.message : String(err))
      })

    return () => {
      alive = false
      controller.abort()
    }
  }, [tick])

  useEffect(() => {
    const timer = window.setInterval(() => {
      setTick((value) => value + 1)
    }, 15000)

    return () => window.clearInterval(timer)
  }, [])

  const derived = useMemo(() => {
    const missionSource = extractString(snapshot?.mission.data, ['source'])
    const coreReadiness = extractString(snapshot?.open5gs.data, ['open5gs', 'readiness'])
    const ranReadiness = extractString(snapshot?.ueransim.data, ['ueransim', 'readiness'])
    const spectrumSource = extractString(snapshot?.spectrumSweep.data, ['spectrum', 'data_source'])
    const socSource = extractString(snapshot?.socNoc.data, ['data_source'])
    const contractVersion = extractString(snapshot?.spectrumSweep.data, ['contract_version'])

    const health = [
      snapshot?.mission,
      snapshot?.open5gs,
      snapshot?.ueransim,
      snapshot?.bandplan,
      snapshot?.spectrumSweep,
      snapshot?.socNoc,
    ].filter((item) => getEndpointHealth(item) === 'ok').length

    return {
      missionSource,
      coreReadiness,
      ranReadiness,
      spectrumSource,
      socSource,
      contractVersion,
      health,
    }
  }, [snapshot])

  return (
    <section className="v34r1-native-readiness-strip">
      <div className="v34r1-native-readiness-head">
        <div>
          <p>V34R1 NATIVE RF PANEL BINDING</p>
          <h3>Bridge Readiness · Live Contract Layer</h3>
        </div>
        <strong>{derived.health}/6 API</strong>
      </div>

      {error ? <div className="v34r1-native-readiness-error">Live contract error: {error}</div> : null}

      <div className="v34r1-native-readiness-grid">
        <article>
          <span>Backend</span>
          <strong>{derived.missionSource}</strong>
        </article>
        <article>
          <span>Open5GS</span>
          <strong>{derived.coreReadiness}</strong>
        </article>
        <article>
          <span>UERANSIM</span>
          <strong>{derived.ranReadiness}</strong>
        </article>
        <article>
          <span>Spectrum</span>
          <strong>{derived.spectrumSource}</strong>
        </article>
        <article>
          <span>SOC/NOC</span>
          <strong>{derived.socSource}</strong>
        </article>
        <article>
          <span>Contract</span>
          <strong>{derived.contractVersion}</strong>
        </article>
      </div>

      <footer>
        <span>Refresh 15s · read-only · no SDR TX · no Open5GS/UERANSIM start-stop</span>
        <button type="button" onClick={() => setTick((value) => value + 1)}>
          Refresh native readiness
        </button>
      </footer>
    </section>
  )
}
TSX

echo
echo "=== CREATE WRAPPER TARGET ==="

cat > "$TARGET" <<'TSX'
import { RFBridgeReadinessV9 as RFBridgeReadinessV9Base } from './RFBridgeReadinessV9Base'
import { RFNativeLiveReadinessStripV34R1 } from './RFNativeLiveReadinessStripV34R1'

export function RFBridgeReadinessV9() {
  return (
    <>
      <RFNativeLiveReadinessStripV34R1 />
      <RFBridgeReadinessV9Base />
    </>
  )
}
TSX

echo
echo "=== APPEND CSS ==="

if ! grep -q "TRFMC V34R1 NATIVE RF BRIDGE READINESS BINDING" "$STYLES"; then
cat >> "$STYLES" <<'CSS'

/* === TRFMC V34R1 NATIVE RF BRIDGE READINESS BINDING === */
.v34r1-native-readiness-strip{
  margin:12px 0 16px;
  padding:14px;
  border:1px solid rgba(124,255,178,.26);
  border-radius:18px;
  background:
    radial-gradient(circle at 10% 0%,rgba(124,255,178,.13),transparent 30%),
    linear-gradient(135deg,rgba(5,28,34,.88),rgba(3,12,21,.94));
  box-shadow:0 18px 55px rgba(0,0,0,.26), inset 0 0 28px rgba(124,255,178,.04);
}

.v34r1-native-readiness-head{
  display:flex;
  justify-content:space-between;
  gap:14px;
  align-items:flex-start;
  margin-bottom:12px;
}

.v34r1-native-readiness-head p{
  margin:0 0 5px;
  color:#7dffb2;
  font-size:10px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v34r1-native-readiness-head h3{
  margin:0;
  color:#efffff;
  font-size:18px;
}

.v34r1-native-readiness-head > strong{
  min-width:86px;
  text-align:center;
  color:#7dffb2;
  border:1px solid rgba(124,255,178,.24);
  border-radius:14px;
  padding:8px 10px;
  background:rgba(7,46,38,.42);
}

.v34r1-native-readiness-grid{
  display:grid;
  grid-template-columns:repeat(6,minmax(0,1fr));
  gap:10px;
}

.v34r1-native-readiness-grid article{
  min-width:0;
  padding:10px;
  border:1px solid rgba(81,183,255,.16);
  border-radius:14px;
  background:rgba(7,18,31,.72);
}

.v34r1-native-readiness-grid span{
  display:block;
  color:#84a9c8;
  font-size:10px;
  letter-spacing:.08em;
  text-transform:uppercase;
  margin-bottom:6px;
}

.v34r1-native-readiness-grid strong{
  display:block;
  color:#e9fbff;
  font-size:12px;
  word-break:break-word;
}

.v34r1-native-readiness-strip footer{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:12px;
  margin-top:12px;
  color:#8ea9bd;
  font-size:12px;
}

.v34r1-native-readiness-error{
  margin-bottom:10px;
  padding:9px 11px;
  border:1px solid rgba(255,95,122,.32);
  border-radius:12px;
  background:rgba(77,8,22,.42);
  color:#ffc1ca;
}

@media (max-width:1200px){
  .v34r1-native-readiness-grid{
    grid-template-columns:repeat(3,minmax(0,1fr));
  }
}

@media (max-width:760px){
  .v34r1-native-readiness-head,
  .v34r1-native-readiness-strip footer{
    flex-direction:column;
    align-items:stretch;
  }

  .v34r1-native-readiness-grid{
    grid-template-columns:1fr;
  }
}
CSS
fi

echo
echo "=== STATIC CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$BASE" && echo "OK: base copy exists" || echo "MISS: base copy exists"
  test -f "$STRIP" && echo "OK: native live strip exists" || echo "MISS: native live strip exists"
  grep -q "RFBridgeReadinessV9Base" "$TARGET" && echo "OK: wrapper imports base" || echo "MISS: wrapper imports base"
  grep -q "RFNativeLiveReadinessStripV34R1" "$TARGET" && echo "OK: wrapper renders live strip" || echo "MISS: wrapper renders live strip"
  grep -q "export function RFBridgeReadinessV9" "$TARGET" && echo "OK: export preserved" || echo "MISS: export preserved"
  grep -q "fetchLiveContractSnapshot" "$STRIP" && echo "OK: live snapshot fetch used" || echo "MISS: live snapshot fetch used"
  grep -q "V34R1 NATIVE RF PANEL BINDING" "$STRIP" && echo "OK: unique DOM marker in strip" || echo "MISS: unique DOM marker in strip"
  grep -q "v34r1-native-readiness-strip" "$STYLES" && echo "OK: V34R1 CSS present" || echo "MISS: V34R1 CSS present"

  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/core/open5gs/status | grep -q "v30_no_curl_no_pgrep_no_self_match" && echo "OK: open5gs hygiene live" || echo "MISS: open5gs hygiene live"
  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/spectrum/sweep | grep -q "TRFMC_CONTRACT_COVERAGE_V31" && echo "OK: spectrum contract live" || echo "MISS: spectrum contract live"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

echo
echo "=== BUILD CHECK ==="

BUILD_LOG="$RELEASE_DIR/npm_build_v34r1.log"
BUILD_RESULT="SKIPPED"

if [ -f "$ROOT/frontend/package.json" ]; then
  (
    cd "$ROOT/frontend"
    npm run build > "$BUILD_LOG" 2>&1
  ) && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"
else
  BUILD_RESULT="NO_PACKAGE_JSON"
  echo "NO_PACKAGE_JSON" > "$BUILD_LOG"
fi

echo "Build result: $BUILD_RESULT"

if [ "$BUILD_RESULT" = "FAIL" ]; then
  echo
  echo "=== BUILD LOG TAIL ==="
  tail -n 180 "$BUILD_LOG" || true
fi

echo
echo "=== OPTIONAL DOM/SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"
URL_DEV="http://127.0.0.1:5173/"
DOM_DUMP="$RELEASE_DIR/trfmc_v34r1_dom.html"
SCREENSHOT="$RELEASE_DIR/trfmc_v34r1_runtime.png"

CHROME_BIN=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME_BIN="$(command -v "$c")"
    break
  fi
done

if [ -n "$CHROME_BIN" ] && curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null 2>&1; then
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1800 \
    --virtual-time-budget=10000 \
    --dump-dom \
    "$URL_DEV" > "$DOM_DUMP" 2>"$RELEASE_DIR/chrome_dom.stderr" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1800 \
    --virtual-time-budget=10000 \
    --screenshot="$SCREENSHOT" \
    "$URL_DEV" >/dev/null 2>"$RELEASE_DIR/chrome_screenshot.stderr" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"

  if [ "$DOM_RESULT" = "PASS" ]; then
    {
      grep -q "V34R1 NATIVE RF PANEL BINDING" "$DOM_DUMP" && echo "OK: V34R1 marker visible in DOM" || echo "MISS: V34R1 marker visible in DOM"
      grep -q "Bridge Readiness · Live Contract Layer" "$DOM_DUMP" && echo "OK: V34R1 title visible in DOM" || echo "MISS: V34R1 title visible in DOM"
      grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" "$DOM_DUMP" && echo "OK: backend source visible in DOM" || echo "MISS: backend source visible in DOM"
      grep -q "trfmc-nginx-v21-api-fallback" "$DOM_DUMP" && echo "MISS: V21 fallback visible in DOM" || echo "OK: no V21 fallback visible in DOM"
    } > "$RELEASE_DIR/dom_checks.txt"

    cat "$RELEASE_DIR/dom_checks.txt"

    DOM_MISS="$(grep -c '^MISS:' "$RELEASE_DIR/dom_checks.txt" || true)"
    if [ "$DOM_MISS" -ne 0 ]; then
      DOM_RESULT="FAIL"
    fi
  fi
else
  echo "DOM gate skipped: Chrome assente o Vite dev 5173 non attivo."
fi

echo "DOM result       : $DOM_RESULT"
echo "Screenshot result: $SCREENSHOT_RESULT"

echo
echo "=== CREATE ROLLBACK ==="

ROLLBACK="$RELEASE_DIR/rollback_v34r1_native_bridge_readiness.sh"

cat > "$ROLLBACK" <<ROLLBACK_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"

cp "$RELEASE_DIR/RFBridgeReadinessV9.tsx.before_v34r1_$TS" frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx
cp "$RELEASE_DIR/styles.css.before_v34r1_$TS" frontend/src/styles.css
rm -f frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9Base.tsx
rm -f frontend/src/rf_instruments/telemetry/RFNativeLiveReadinessStripV34R1.tsx

echo "Rollback V34R1 completato"
ROLLBACK_EOF

chmod +x "$ROLLBACK"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$BUILD_RESULT" = "FAIL" ] || [ "$DOM_RESULT" = "FAIL" ]; then
  RESULT="FAIL"
fi

echo
echo "=== MANIFEST / SUMMARY ==="

MANIFEST="$RELEASE_DIR/native_bridge_readiness_binding_manifest_v34r1.json"
SUMMARY="$QUALITY_DIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_NATIVE_RF_BRIDGE_READINESS_BINDING_V34R1",
  "strategy": "wrapper_preserves_original_as_base_and_adds_live_readiness_strip",
  "frontend_mutation": true,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "target": "$TARGET",
  "base_copy": "$BASE",
  "live_strip": "$STRIP",
  "patched_styles": "$STYLES",
  "pre_patch_freeze": "$PRE_FREEZE",
  "rollback": "$ROLLBACK",
  "api_binding": [
    "/api/mission/status",
    "/api/core/open5gs/status",
    "/api/ran/ueransim/status",
    "/api/rfpro/bandplan",
    "/api/rfpro/spectrum/sweep",
    "/api/soc-noc/correlation/demo"
  ],
  "miss_count": $MISS_COUNT,
  "build_result": "$BUILD_RESULT",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_NATIVE_RF_BRIDGE_READINESS_BINDING_V34R1",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "pre_patch_freeze": "$PRE_FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "build_log": "$BUILD_LOG",
  "rollback": "$ROLLBACK",
  "dom_dump": "$DOM_DUMP",
  "screenshot": "$SCREENSHOT",
  "miss_count": $MISS_COUNT,
  "build_result": "$BUILD_RESULT",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx \
  frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9Base.tsx \
  frontend/src/rf_instruments/telemetry/RFNativeLiveReadinessStripV34R1.tsx \
  frontend/src/styles.css \
  "$RELEASE_DIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_native_rf_bridge_readiness_binding_v34r1"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_native_rf_bridge_readiness_binding_v34r1"

cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V34R1 NATIVE RF BRIDGE READINESS BINDING COMPLETATO"
echo "Rollback: $ROLLBACK"
echo "============================================================"

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: risultato $RESULT"
  echo "Rollback disponibile:"
  echo "$ROLLBACK"
  exit 1
fi
