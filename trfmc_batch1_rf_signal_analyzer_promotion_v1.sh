#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH1_RF_SIGNAL_ANALYZER_PROMOTION_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"

EXP="$BASE/frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx"
COMP="$BASE/frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx"
CSS="$BASE/frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_rf_signal_promotion_v1.log"
HTTP="$OUT/http.tsv"
DIFF="$OUT/rf_signal_promotion_v1.diff"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_signal_promotion_v1_1920x1080.png"
RESTORE="$OUT/RESTORE_RF_SIGNAL_PROMOTION_V1.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_BATCH1_RF_SIGNAL_ANALYZER_PROMOTION_V1"
echo "Source React promotion · RF Physics + Signal Analyzer"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$EXP" ] || [ ! -f "$CSS" ]; then
  echo "ERRORE: EngineeringConsoleExpansionV4.tsx o styles.css non trovato"
  exit 1
fi

cp -a "$EXP" "$BACKUP/EngineeringConsoleExpansionV4.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

if [ -f "$COMP" ]; then
  cp -a "$COMP" "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS"
fi

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cp -a "$BACKUP/EngineeringConsoleExpansionV4.tsx.before_$TS" "$EXP"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
if [ -f "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS" ]; then
  cp -a "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS" "$COMP"
else
  rm -f "$COMP"
fi
echo "RESTORE_RF_SIGNAL_PROMOTION_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA RFSignalAnalyzerPromotionV1.tsx ==="

cat > "$COMP" <<'TSX'
import { useState } from 'react'
import { RFSignalAnalyzerWorkbenchV3 } from '../rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3'
import { RFInstrumentDockV4 } from '../rf_instruments/instruments/RFInstrumentDockV4'
import { TrueSpectrumAnalyzer } from '../rf_instruments/instruments/TrueSpectrumAnalyzer'

const tabs = [
  { id: 'workbench', label: 'VSA Workbench', note: 'DSP worker · Spectrum · Waterfall · I/Q' },
  { id: 'dock', label: 'RF Instrument Dock', note: 'VSA surface · markers · measurements' },
  { id: 'spectrum', label: 'True Spectrum', note: 'Realtime FFT console baseline' },
] as const

const theory = [
  { k: 'FFT', v: 'time-domain IQ → frequency bins', q: 'N=4096 · windowed detector' },
  { k: 'I/Q', v: 'complex baseband representation', q: 'constellation + error vectors' },
  { k: 'SNR', v: 'signal/noise quality metric', q: 'dB evidence indicator' },
  { k: 'EVM', v: 'modulation quality / error vector', q: 'digital RF KPI' },
]

const contracts = [
  { k: 'Route', v: '#full-engineering-stack', state: 'mounted' },
  { k: 'API', v: '/api/rfpro/spectrum/sweep', state: 'contract' },
  { k: 'Source', v: 'synthetic IQ / future bridge', state: 'safe' },
  { k: 'QA', v: 'build + HTTP + screenshot + DOM', state: 'required' },
]

const scenarios = [
  'Controlled RF sweep validation',
  'Synthetic OFDM / FHSS visual classification',
  'I/Q constellation degradation evidence',
  'Spectrum + waterfall persistence review',
]

export function RFSignalAnalyzerPromotionV1() {
  const [active, setActive] = useState<(typeof tabs)[number]['id']>('workbench')

  return (
    <section className="trfmc-rf-promo-v1" data-trfmc-rf-signal-promotion-v1="mounted">
      <div className="trfmc-rf-promo-head">
        <div>
          <p className="trfmc-rf-promo-kicker">Batch 1 · RF Physics / Signal Analyzer Promotion</p>
          <h2>RF Signal Analyzer: teoria, DSP, visual asset, contract, scenario, QA</h2>
          <p>
            Primo innesto tecnico reale nella console Engineering V5: il modulo RF/Signal viene promosso
            da candidato a strumento sorgente React, senza iframe e senza pagine pubbliche parallele.
          </p>
        </div>
        <div className="trfmc-rf-promo-readiness">
          <strong>V1</strong>
          <span>source promoted</span>
        </div>
      </div>

      <div className="trfmc-rf-promo-grid">
        <section className="trfmc-rf-promo-panel">
          <div className="trfmc-rf-promo-panel-head">
            <span>Theory binding</span>
            <b>RF physics</b>
          </div>
          <div className="trfmc-rf-theory-grid">
            {theory.map((item) => (
              <article className="trfmc-rf-theory-card" key={item.k}>
                <strong>{item.k}</strong>
                <span>{item.v}</span>
                <em>{item.q}</em>
              </article>
            ))}
          </div>
        </section>

        <section className="trfmc-rf-promo-panel">
          <div className="trfmc-rf-promo-panel-head">
            <span>Runtime contracts</span>
            <b>readonly bridge</b>
          </div>
          <div className="trfmc-rf-contract-grid">
            {contracts.map((item) => (
              <article className="trfmc-rf-contract-card" key={item.k}>
                <span>{item.k}</span>
                <strong>{item.v}</strong>
                <em>{item.state}</em>
              </article>
            ))}
          </div>
        </section>
      </div>

      <section className="trfmc-rf-promo-panel trfmc-rf-instrument-panel">
        <div className="trfmc-rf-promo-panel-head">
          <span>Instrument selector</span>
          <b>Canvas / DSP source modules</b>
        </div>

        <div className="trfmc-rf-tabbar" role="tablist" aria-label="RF Signal Analyzer instruments">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              className={active === tab.id ? 'active' : ''}
              type="button"
              onClick={() => setActive(tab.id)}
            >
              <strong>{tab.label}</strong>
              <span>{tab.note}</span>
            </button>
          ))}
        </div>

        <div className="trfmc-rf-instrument-stage">
          {active === 'workbench' ? <RFSignalAnalyzerWorkbenchV3 /> : null}
          {active === 'dock' ? <RFInstrumentDockV4 /> : null}
          {active === 'spectrum' ? <TrueSpectrumAnalyzer /> : null}
        </div>
      </section>

      <section className="trfmc-rf-promo-panel trfmc-rf-scenario-panel">
        <div className="trfmc-rf-promo-panel-head">
          <span>Scenario binding</span>
          <b>acceptance evidence</b>
        </div>
        <div className="trfmc-rf-scenario-grid">
          {scenarios.map((scenario) => (
            <article key={scenario}>
              <strong>{scenario}</strong>
              <span>Required evidence: screenshot, route marker, API contract and no iframe/public-page fallback.</span>
            </article>
          ))}
        </div>
      </section>
    </section>
  )
}
TSX

echo
echo "=== 2) PATCH EngineeringConsoleExpansionV4.tsx ==="

python3 - "$EXP" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

import_line = "import { RFSignalAnalyzerPromotionV1 } from './RFSignalAnalyzerPromotionV1'"
if import_line not in text:
    text = import_line + "\n" + text

marker = "<RFSignalAnalyzerPromotionV1 />"
if marker not in text:
    target = "    </section>\n  )\n}"
    if target not in text:
        raise SystemExit("ERRORE: chiusura componente EngineeringConsoleExpansionV4 non trovata")
    text = text.replace(target, f"      {marker}\n{target}", 1)

p.write_text(text, encoding="utf-8")
print("ENGINEERING_CONSOLE_EXPANSION_CHANGED=", before != text)
PY

echo
echo "=== 3) PATCH styles.css ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC RF SIGNAL ANALYZER PROMOTION V1 START === \*/.*?/\* === TRFMC RF SIGNAL ANALYZER PROMOTION V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC RF SIGNAL ANALYZER PROMOTION V1 START === */
/*
  Batch 1: RF Physics / Signal Analyzer source promotion.
  Scope: React source only, no iframe, no public-page runtime patch.
*/

.trfmc-rf-promo-v1 {
  margin-top: 10px;
  padding: 10px;
  border: 1px solid rgba(103,232,249,.18);
  border-radius: 12px;
  background:
    radial-gradient(circle at 12% 0%, rgba(57,215,255,.07), transparent 34%),
    linear-gradient(180deg, rgba(4,14,26,.66), rgba(2,8,17,.80));
}

.trfmc-rf-promo-head {
  display: grid;
  grid-template-columns: minmax(0,1fr) 104px;
  gap: 10px;
  align-items: stretch;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(103,232,249,.14);
}

.trfmc-rf-promo-kicker {
  margin: 0 0 4px 0;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-rf-promo-v1 h2 {
  margin: 0 0 5px 0;
  font-size: 18px;
  line-height: 1.05;
}

.trfmc-rf-promo-v1 p {
  margin: 0;
  color: #a9c6d8;
  font-size: 12px;
  line-height: 1.36;
}

.trfmc-rf-promo-readiness {
  display: grid;
  place-items: center;
  border: 1px solid rgba(134,239,172,.24);
  border-radius: 11px;
  background: rgba(8,47,38,.30);
}

.trfmc-rf-promo-readiness strong {
  color: #86efac;
  font-size: 23px;
  line-height: 1;
}

.trfmc-rf-promo-readiness span {
  color: #9fb8ca;
  font-size: 9px;
  text-transform: uppercase;
  letter-spacing: .08em;
  text-align: center;
}

.trfmc-rf-promo-grid {
  display: grid;
  grid-template-columns: minmax(0,1fr) minmax(0,1fr);
  gap: 8px;
  margin-top: 8px;
}

.trfmc-rf-promo-panel {
  border: 1px solid rgba(103,232,249,.14);
  border-radius: 11px;
  background: rgba(2,10,20,.42);
  padding: 8px;
}

.trfmc-rf-promo-panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 7px;
  padding-bottom: 6px;
  border-bottom: 1px solid rgba(103,232,249,.12);
}

.trfmc-rf-promo-panel-head span {
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .13em;
  text-transform: uppercase;
}

.trfmc-rf-promo-panel-head b {
  color: #86efac;
  font-size: 9px;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-rf-theory-grid,
.trfmc-rf-contract-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0,1fr));
  gap: 7px;
}

.trfmc-rf-theory-card,
.trfmc-rf-contract-card {
  border: 1px solid rgba(103,232,249,.12);
  border-radius: 9px;
  background: rgba(2,10,20,.35);
  padding: 7px 8px;
  min-width: 0;
}

.trfmc-rf-theory-card strong,
.trfmc-rf-contract-card span {
  display: block;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.trfmc-rf-theory-card span,
.trfmc-rf-contract-card strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 11px;
  overflow-wrap: anywhere;
}

.trfmc-rf-theory-card em,
.trfmc-rf-contract-card em {
  display: inline-flex;
  width: fit-content;
  margin-top: 5px;
  padding: 3px 7px;
  border-radius: 999px;
  color: #86efac;
  border: 1px solid rgba(134,239,172,.22);
  background: rgba(22,101,52,.18);
  font-style: normal;
  font-size: 9px;
  font-weight: 900;
  text-transform: uppercase;
}

.trfmc-rf-instrument-panel {
  margin-top: 8px;
}

.trfmc-rf-tabbar {
  display: grid;
  grid-template-columns: repeat(3, minmax(0,1fr));
  gap: 7px;
  margin-bottom: 8px;
}

.trfmc-rf-tabbar button {
  text-align: left;
  border: 1px solid rgba(103,232,249,.14);
  border-radius: 10px;
  background: rgba(5,16,31,.72);
  color: #e8f7ff;
  padding: 7px 8px;
  cursor: pointer;
}

.trfmc-rf-tabbar button.active {
  border-color: rgba(134,239,172,.42);
  background: rgba(8,47,38,.22);
}

.trfmc-rf-tabbar strong,
.trfmc-rf-tabbar span {
  display: block;
}

.trfmc-rf-tabbar strong {
  font-size: 12px;
}

.trfmc-rf-tabbar span {
  margin-top: 3px;
  color: #9fb8ca;
  font-size: 10px;
}

.trfmc-rf-instrument-stage {
  max-height: 720px;
  overflow: auto;
  border: 1px solid rgba(103,232,249,.12);
  border-radius: 10px;
  background: rgba(0,4,10,.28);
  padding: 8px;
}

.trfmc-rf-instrument-stage canvas {
  max-width: 100%;
}

.trfmc-rf-instrument-stage * {
  box-sizing: border-box;
}

.trfmc-rf-scenario-panel {
  margin-top: 8px;
}

.trfmc-rf-scenario-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0,1fr));
  gap: 7px;
}

.trfmc-rf-scenario-grid article {
  border: 1px solid rgba(103,232,249,.12);
  border-radius: 9px;
  padding: 7px 8px;
  background: rgba(2,10,20,.35);
}

.trfmc-rf-scenario-grid strong {
  display: block;
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-rf-scenario-grid span {
  display: block;
  color: #9fb8ca;
  font-size: 10px;
  line-height: 1.28;
  margin-top: 4px;
}

@media (max-width: 1200px) {
  .trfmc-rf-promo-grid,
  .trfmc-rf-theory-grid,
  .trfmc-rf-contract-grid,
  .trfmc-rf-tabbar,
  .trfmc-rf-scenario-grid {
    grid-template-columns: 1fr;
  }

  .trfmc-rf-promo-head {
    grid-template-columns: 1fr;
  }
}
/* === TRFMC RF SIGNAL ANALYZER PROMOTION V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_RF_SIGNAL_PROMOTION_V1_APPENDED=True")
PY

echo
echo "=== 4) DIFF ==="
git diff -- \
  frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx \
  frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx \
  frontend/src/styles.css > "$DIFF" || true

sed -n '1,220p' "$DIFF"

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
url	status	bytes
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 6 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  rm -f "$tmp"
  printf "%s\t%s\t%s\n" "$url" "$code" "$bytes" | tee -a "$HTTP"
}

check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 7) DOM / IFRAME / PUBLIC PATCH GATE ==="

DOM_RESULT="SKIPPED"
IFRAME_COUNT="$(grep -RIn "<iframe" frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx 2>/dev/null | wc -l | tr -d ' ')"
PUBLIC_PATCH_REFS="$(grep -RIn "frontend/public\|/assets/trfmc_.*v51\|trfmc_.*v51r" frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx frontend/src/styles.css 2>/dev/null | wc -l | tr -d ' ')"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM"
fi

DOM_MARKER_COUNT="$(grep -c "data-trfmc-rf-signal-promotion-v1=\"mounted\"" "$DOM" 2>/dev/null || true)"

echo "DOM_RESULT=$DOM_RESULT"
echo "DOM_MARKER_COUNT=$DOM_MARKER_COUNT"
echo "IFRAME_COUNT=$IFRAME_COUNT"
echo "PUBLIC_PATCH_REFS=$PUBLIC_PATCH_REFS"

echo
echo "=== 8) SCREENSHOT GATE ==="

SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH1_RF_SIGNAL_ANALYZER_PROMOTION_V1",
  "mutation": "source_react_component_promotion",
  "runtime_injection": false,
  "public_asset_mutation": false,
  "index_mutation": false,
  "backend_mutation": false,
  "files_modified": [
    "frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx",
    "frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx",
    "frontend/src/styles.css"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "dom_marker_count": $DOM_MARKER_COUNT,
  "iframe_count": $IFRAME_COUNT,
  "public_patch_refs": $PUBLIC_PATCH_REFS,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && [ "$IFRAME_COUNT" = "0" ] && [ "$PUBLIC_PATCH_REFS" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch1_rf_signal_analyzer_promotion_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH1_RF_SIGNAL_ANALYZER_PROMOTION_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
