#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_OPERATIONAL_DECK_V14_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_OPERATIONAL_DECK_V14_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF OPERATIONAL DECK V14"
echo "Tabbed operational deck · no more vertical diagnostic stack"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/telemetry

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }

test -f src/rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding.tsx || { echo "ERRORE: V13 mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx || { echo "ERRORE: RFInstrumentSuiteV5 mancante"; exit 1; }

test -f src/rf_instruments/telemetry/RFGovernorBindingAuditV13.tsx || { echo "ERRORE: RFGovernorBindingAuditV13 mancante"; exit 1; }
test -f src/rf_instruments/telemetry/RFRenderGovernorV12.tsx || { echo "ERRORE: RFRenderGovernorV12 mancante"; exit 1; }
test -f src/rf_instruments/telemetry/RFPerformanceTelemetryV11.tsx || { echo "ERRORE: RFPerformanceTelemetryV11 mancante"; exit 1; }
test -f src/rf_instruments/evidence/RFEvidenceFlightRecorderV10.tsx || { echo "ERRORE: RFEvidenceFlightRecorderV10 mancante"; exit 1; }
test -f src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx || { echo "ERRORE: RFBridgeReadinessV9 mancante"; exit 1; }
test -f src/rf_instruments/sources/RFSourceRuntimeProbeV8.tsx || { echo "ERRORE: RFSourceRuntimeProbeV8 mancante"; exit 1; }
test -f src/rf_instruments/sources/RFSourceBridgePanelV7.tsx || { echo "ERRORE: RFSourceBridgePanelV7 mancante"; exit 1; }

grep -q "RFInstrumentSuiteV13GovernorBinding" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V13 Governor Binding. Non procedo."
  exit 1
}

echo "OK: V13 presente e montato"

echo
echo "=== BACKUP STATO V13 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_operational_deck_v14_${TS}"
cp src/styles.css "src/styles.css.bak_rf_operational_deck_v14_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== CREO HEADLESS GOVERNOR V14 ==="

cat > src/rf_instruments/telemetry/RFRenderGovernorHeadlessV14.tsx <<'TSX'
import { useEffect, useRef } from "react";

import {
  dispatchRFRenderGovernorPolicyV12,
  RFRenderGovernorPolicyV12,
  RFRenderProfileV12
} from "./RFRenderGovernorBusV12";

function buildPolicy(fps: number, jitterMs: number, visibility: DocumentVisibilityState): RFRenderGovernorPolicyV12 {
  let profile: RFRenderProfileV12 = "ULTRA";
  let reason = "headless deck policy";

  if (visibility === "hidden") {
    profile = "BACKGROUND";
    reason = "document hidden";
  } else if (fps < 24 || jitterMs > 42) {
    profile = "SAFE";
    reason = "headless severe UI pressure";
  } else if (fps < 42 || jitterMs > 28) {
    profile = "BALANCED";
    reason = "headless moderate UI pressure";
  } else if (fps < 55 || jitterMs > 18) {
    profile = "HIGH";
    reason = "headless minor UI pressure";
  }

  const map: Record<RFRenderProfileV12, Omit<RFRenderGovernorPolicyV12, "profile" | "reason" | "timestamp">> = {
    ULTRA: {
      fpsTarget: 60,
      canvasScale: 1,
      waterfallEveryNFrames: 1,
      iqPointBudget: 800,
      spectrumBins: 4096,
      animationEnabled: true
    },
    HIGH: {
      fpsTarget: 50,
      canvasScale: 0.9,
      waterfallEveryNFrames: 2,
      iqPointBudget: 500,
      spectrumBins: 2048,
      animationEnabled: true
    },
    BALANCED: {
      fpsTarget: 36,
      canvasScale: 0.75,
      waterfallEveryNFrames: 3,
      iqPointBudget: 320,
      spectrumBins: 1024,
      animationEnabled: true
    },
    SAFE: {
      fpsTarget: 24,
      canvasScale: 0.6,
      waterfallEveryNFrames: 5,
      iqPointBudget: 160,
      spectrumBins: 512,
      animationEnabled: true
    },
    BACKGROUND: {
      fpsTarget: 5,
      canvasScale: 0.5,
      waterfallEveryNFrames: 12,
      iqPointBudget: 64,
      spectrumBins: 256,
      animationEnabled: false
    }
  };

  return {
    profile,
    reason,
    timestamp: new Date().toISOString(),
    ...map[profile]
  };
}

export function RFRenderGovernorHeadlessV14() {
  const frames = useRef<number[]>([]);
  const raf = useRef<number | null>(null);
  const lastDispatch = useRef(0);

  useEffect(() => {
    const loop = (t: number) => {
      const list = frames.current;
      list.push(t);

      while (list.length > 90) list.shift();

      if (list.length > 12) {
        const deltas = list.slice(1).map((v, i) => v - list[i]);
        const avg = deltas.reduce((a, b) => a + b, 0) / deltas.length;
        const max = Math.max(...deltas);
        const min = Math.min(...deltas);

        const fps = Math.round(1000 / avg);
        const jitterMs = Math.round((max - min) * 10) / 10;
        const now = performance.now();

        if (now - lastDispatch.current > 900) {
          dispatchRFRenderGovernorPolicyV12(buildPolicy(fps, jitterMs, document.visibilityState));
          lastDispatch.current = now;
        }
      }

      raf.current = requestAnimationFrame(loop);
    };

    raf.current = requestAnimationFrame(loop);

    return () => {
      if (raf.current !== null) cancelAnimationFrame(raf.current);
    };
  }, []);

  return null;
}
TSX

echo
echo "=== APPENDO CSS V14 ==="

if ! grep -q "TRFMC_RF_OPERATIONAL_DECK_V14_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_OPERATIONAL_DECK_V14_STYLE */
.rf-op14{
  margin:12px 0;
  border:1px solid rgba(57,215,255,.36);
  border-radius:28px;
  overflow:hidden;
  background:
    radial-gradient(circle at 82% 0%,rgba(57,215,255,.16),transparent 34%),
    radial-gradient(circle at 12% 100%,rgba(125,255,178,.08),transparent 30%),
    linear-gradient(145deg,rgba(4,16,30,.97),rgba(0,4,9,.99));
  box-shadow:
    0 34px 120px rgba(0,0,0,.70),
    inset 0 0 60px rgba(57,215,255,.04);
}

.rf-op14-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:16px;
  padding:16px;
  border-bottom:1px solid rgba(57,215,255,.24);
  background:linear-gradient(180deg,rgba(8,32,54,.98),rgba(2,9,16,.99));
}

.rf-op14-title{
  color:#effbff;
  font-size:22px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.14em;
  text-shadow:
    0 0 18px rgba(57,215,255,.48),
    0 0 32px rgba(125,255,178,.18);
}

.rf-op14-sub{
  margin-top:5px;
  color:#91b9c9;
  font-size:12px;
}

.rf-op14-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-op14-badges span{
  border:1px solid rgba(57,215,255,.28);
  background:rgba(57,215,255,.07);
  color:#39d7ff;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-op14-tabs{
  display:flex;
  gap:8px;
  flex-wrap:wrap;
  padding:10px;
  border-bottom:1px solid rgba(57,215,255,.16);
  background:rgba(0,4,9,.58);
  position:sticky;
  top:0;
  z-index:20;
  backdrop-filter:blur(10px);
}

.rf-op14-tab{
  border-radius:12px;
  padding:8px 11px;
  font-size:11px;
  letter-spacing:.08em;
  text-transform:uppercase;
}

.rf-op14-tab.active{
  color:#021018;
  background:linear-gradient(180deg,#7df1ff,#34c9f2);
  border-color:#c7fbff;
  box-shadow:0 0 20px rgba(57,215,255,.40);
}

.rf-op14-status{
  display:grid;
  grid-template-columns:repeat(5,minmax(150px,1fr));
  gap:10px;
  padding:10px;
  border-bottom:1px solid rgba(57,215,255,.14);
}

.rf-op14-card{
  border:1px solid rgba(57,215,255,.22);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(8,22,38,.90),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(57,215,255,.08),transparent 35%);
}

.rf-op14-card b{
  display:block;
  color:#39d7ff;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-op14-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:15px;
  font-weight:850;
}

.rf-op14-card small{
  display:block;
  color:#91b9c9;
  margin-top:6px;
  line-height:1.45;
}

.rf-op14-stage{
  padding:10px;
}

.rf-op14-stage > section,
.rf-op14-collapse,
.rf-op14-collapse > section{
  content-visibility:auto;
  contain-intrinsic-size:auto 780px;
}

.rf-op14-collapse{
  border:1px solid rgba(57,215,255,.18);
  border-radius:18px;
  margin-bottom:10px;
  background:rgba(0,6,12,.50);
  overflow:hidden;
}

.rf-op14-collapse > summary{
  cursor:pointer;
  padding:12px 14px;
  color:#39d7ff;
  font-weight:900;
  letter-spacing:.10em;
  text-transform:uppercase;
  border-bottom:1px solid rgba(57,215,255,.12);
  background:rgba(57,215,255,.045);
}

.rf-op14-collapse > div{
  padding:10px;
}

.rf-op14-grid2{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:10px;
}

@media(max-width:1500px){
  .rf-op14-header{ grid-template-columns:1fr; }
  .rf-op14-badges{ justify-content:flex-start; }
  .rf-op14-status{ grid-template-columns:repeat(2,minmax(150px,1fr)); }
  .rf-op14-grid2{ grid-template-columns:1fr; }
}

@media(max-width:760px){
  .rf-op14-status{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO OPERATIONAL DECK V14 ==="

cat > src/rf_instruments/instruments/RFOperationalDeckV14.tsx <<'TSX'
import React, { useMemo, useState } from "react";

import { RFInstrumentSuiteV5 } from "./RFInstrumentSuiteV5";
import { RFGovernorBindingAuditV13 } from "../telemetry/RFGovernorBindingAuditV13";
import { RFRenderGovernorV12 } from "../telemetry/RFRenderGovernorV12";
import { RFPerformanceTelemetryV11 } from "../telemetry/RFPerformanceTelemetryV11";
import { RFEvidenceFlightRecorderV10 } from "../evidence/RFEvidenceFlightRecorderV10";
import { RFBridgeReadinessV9 } from "../telemetry/RFBridgeReadinessV9";
import { RFSourceRuntimeProbeV8 } from "../sources/RFSourceRuntimeProbeV8";
import { RFSourceBridgePanelV7 } from "../sources/RFSourceBridgePanelV7";
import { RFRenderGovernorHeadlessV14 } from "../telemetry/RFRenderGovernorHeadlessV14";

type DeckTab =
  | "instruments"
  | "sources"
  | "runtime"
  | "bridge"
  | "evidence"
  | "performance"
  | "governor"
  | "binding"
  | "ops";

const tabs: { id: DeckTab; label: string }[] = [
  { id: "instruments", label: "Instruments" },
  { id: "sources", label: "Sources" },
  { id: "runtime", label: "Runtime" },
  { id: "bridge", label: "Bridge" },
  { id: "evidence", label: "Evidence" },
  { id: "performance", label: "Performance" },
  { id: "governor", label: "Governor" },
  { id: "binding", label: "Binding" },
  { id: "ops", label: "Ops Deck" }
];

function StatusCard(props: { label: string; value: string; detail: string }) {
  return (
    <div className="rf-op14-card">
      <b>{props.label}</b>
      <span>{props.value}</span>
      <small>{props.detail}</small>
    </div>
  );
}

export function RFOperationalDeckV14() {
  const [active, setActive] = useState<DeckTab>("instruments");

  const cards = useMemo(
    () => [
      {
        label: "Deck",
        value: "V14",
        detail: "Tabbed operational shell; no vertical diagnostic overload."
      },
      {
        label: "Default",
        value: "Instruments",
        detail: "RF Suite V5 is now the main working surface."
      },
      {
        label: "Governor",
        value: "Headless",
        detail: "V12 policy bus stays alive even when the governor panel is hidden."
      },
      {
        label: "Rendering",
        value: "Lazy",
        detail: "Offscreen panels use content-visibility and tab routing."
      },
      {
        label: "Safety",
        value: "Read-only",
        detail: "No SDR control, no Open5GS mutation, no destructive patch."
      }
    ],
    []
  );

  return (
    <section className="rf-op14">
      {active !== "governor" && active !== "ops" && <RFRenderGovernorHeadlessV14 />}

      <header className="rf-op14-header">
        <div>
          <div className="rf-op14-title">TRFMC RF Operational Deck V14</div>
          <div className="rf-op14-sub">
            Compact mission deck · instruments first · diagnostics on demand · governor always-on · safe RF/Telco cockpit
          </div>
        </div>

        <div className="rf-op14-badges">
          <span>STACK NORMALIZED</span>
          <span>INSTRUMENTS FIRST</span>
          <span>HEADLESS GOVERNOR</span>
          <span>CONTENT VISIBILITY</span>
          <span>NO CORE MUTATION</span>
        </div>
      </header>

      <nav className="rf-op14-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={active === tab.id ? "rf-op14-tab active" : "rf-op14-tab"}
            onClick={() => setActive(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </nav>

      <div className="rf-op14-status">
        {cards.map((card) => (
          <StatusCard key={card.label} {...card} />
        ))}
      </div>

      <div className="rf-op14-stage">
        {active === "instruments" && <RFInstrumentSuiteV5 />}
        {active === "sources" && <RFSourceBridgePanelV7 />}
        {active === "runtime" && <RFSourceRuntimeProbeV8 />}
        {active === "bridge" && <RFBridgeReadinessV9 />}
        {active === "evidence" && <RFEvidenceFlightRecorderV10 />}
        {active === "performance" && <RFPerformanceTelemetryV11 />}
        {active === "governor" && <RFRenderGovernorV12 />}
        {active === "binding" && <RFGovernorBindingAuditV13 />}

        {active === "ops" && (
          <div>
            <details className="rf-op14-collapse" open>
              <summary>Instrument Suite</summary>
              <div><RFInstrumentSuiteV5 /></div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Governor + Binding</summary>
              <div className="rf-op14-grid2">
                <RFRenderGovernorV12 />
                <RFGovernorBindingAuditV13 />
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Source Bridge + Runtime</summary>
              <div className="rf-op14-grid2">
                <RFSourceBridgePanelV7 />
                <RFSourceRuntimeProbeV8 />
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Bridge Readiness + Evidence Recorder</summary>
              <div className="rf-op14-grid2">
                <RFBridgeReadinessV9 />
                <RFEvidenceFlightRecorderV10 />
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Performance Telemetry</summary>
              <div><RFPerformanceTelemetryV11 /></div>
            </details>
          </div>
        )}
      </div>
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V13 -> V14 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV13GovernorBinding\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding['\"];?\n",
    "import { RFOperationalDeckV14 } from '../rf_instruments/instruments/RFOperationalDeckV14'\n",
    s,
    count=1
)

if "RFOperationalDeckV14" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFOperationalDeckV14 } from '../rf_instruments/instruments/RFOperationalDeckV14'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV13GovernorBinding />", "<RFOperationalDeckV14 />")

p.write_text(s)
print("OK: main.tsx patched to V14 Operational Deck")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v14_operational_deck.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_operational_deck_v14_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_operational_deck_v14_${TS}" src/styles.css
echo "Rollback V14 Operational Deck completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v14_operational_deck.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_OPERATIONAL_DECK_V14",
  "created": [
    "src/rf_instruments/telemetry/RFRenderGovernorHeadlessV14.tsx",
    "src/rf_instruments/instruments/RFOperationalDeckV14.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "features": [
    "tabbed_operational_deck",
    "instruments_first_default",
    "diagnostics_on_demand",
    "headless_governor_policy_publisher",
    "content_visibility_for_heavy_sections",
    "details_disclosure_ops_mode",
    "no_backend_mutation",
    "no_sdr_control"
  ],
  "preserves_v13_governor_binding": true,
  "rollback": "${QUALITY_DIR}/rollback_v14_operational_deck.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_operational_deck_v14

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFOperationalDeckV14\\|RFInstrumentSuiteV13GovernorBinding\\|RFInstrumentSuiteV12RenderGovernor" src/app/main.tsx || true

echo
echo "=== FILES ==="
ls -lh \
  src/rf_instruments/telemetry/RFRenderGovernorHeadlessV14.tsx \
  src/rf_instruments/instruments/RFOperationalDeckV14.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_operational_deck_v14/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V14 OPERATIONAL DECK CREATO. ORA RIAVVIA VITE."
echo "============================================================"
