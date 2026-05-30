#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_OPERATIONAL_DECK_V14_AUTO_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_OPERATIONAL_DECK_V14_AUTO_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF OPERATIONAL DECK V14 AUTO"
echo "Auto-adaptive deck from existing V5/V7/V8/V9/V10 chain"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/telemetry src/rf_instruments/instruments

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }

test -f src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx || { echo "ERRORE: RFInstrumentSuiteV5.tsx mancante"; exit 1; }
test -f src/rf_instruments/sources/RFSourceBridgePanelV7.tsx || { echo "ERRORE: RFSourceBridgePanelV7.tsx mancante"; exit 1; }
test -f src/rf_instruments/sources/RFSourceRuntimeProbeV8.tsx || { echo "ERRORE: RFSourceRuntimeProbeV8.tsx mancante"; exit 1; }
test -f src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx || { echo "ERRORE: RFBridgeReadinessV9.tsx mancante"; exit 1; }
test -f src/rf_instruments/evidence/RFEvidenceFlightRecorderV10.tsx || { echo "ERRORE: RFEvidenceFlightRecorderV10.tsx mancante"; exit 1; }

echo "OK: base V5/V7/V8/V9/V10 presente"

echo
echo "=== BACKUP STATO ATTUALE ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_operational_deck_v14_auto_${TS}"
cp src/styles.css "src/styles.css.bak_rf_operational_deck_v14_auto_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== CREO HEADLESS GOVERNOR V14 AUTO ==="

cat > src/rf_instruments/telemetry/RFRenderGovernorHeadlessV14.tsx <<'TSX'
import { useEffect, useRef } from "react";

type GovernorProfile = "ULTRA" | "HIGH" | "BALANCED" | "SAFE" | "BACKGROUND";

type GovernorPolicy = {
  profile: GovernorProfile;
  fpsTarget: number;
  waterfallEveryNFrames: number;
  iqPointBudget: number;
  animationEnabled: boolean;
  reason: string;
  timestamp: string;
};

const STORAGE_KEY = "TRFMC_RF_RENDER_GOVERNOR_V14_POLICY";
const EVENT_NAME = "trfmc:rf-render-governor:v14";

function buildPolicy(fps: number, jitterMs: number, visibility: DocumentVisibilityState): GovernorPolicy {
  let profile: GovernorProfile = "ULTRA";
  let reason = "headless V14 policy";

  if (visibility === "hidden") {
    profile = "BACKGROUND";
    reason = "document hidden";
  } else if (fps < 24 || jitterMs > 42) {
    profile = "SAFE";
    reason = "severe UI pressure";
  } else if (fps < 42 || jitterMs > 28) {
    profile = "BALANCED";
    reason = "moderate UI pressure";
  } else if (fps < 55 || jitterMs > 18) {
    profile = "HIGH";
    reason = "minor UI pressure";
  }

  const map: Record<GovernorProfile, Omit<GovernorPolicy, "profile" | "reason" | "timestamp">> = {
    ULTRA: {
      fpsTarget: 60,
      waterfallEveryNFrames: 1,
      iqPointBudget: 800,
      animationEnabled: true
    },
    HIGH: {
      fpsTarget: 50,
      waterfallEveryNFrames: 2,
      iqPointBudget: 500,
      animationEnabled: true
    },
    BALANCED: {
      fpsTarget: 36,
      waterfallEveryNFrames: 3,
      iqPointBudget: 320,
      animationEnabled: true
    },
    SAFE: {
      fpsTarget: 24,
      waterfallEveryNFrames: 5,
      iqPointBudget: 160,
      animationEnabled: true
    },
    BACKGROUND: {
      fpsTarget: 5,
      waterfallEveryNFrames: 12,
      iqPointBudget: 64,
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

function publish(policy: GovernorPolicy) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(policy));
  window.dispatchEvent(new CustomEvent(EVENT_NAME, { detail: policy }));
}

export function RFRenderGovernorHeadlessV14() {
  const frames = useRef<number[]>([]);
  const raf = useRef<number | null>(null);
  const lastPublish = useRef(0);

  useEffect(() => {
    const loop = (t: number) => {
      const list = frames.current;
      list.push(t);

      while (list.length > 90) list.shift();

      if (list.length > 12) {
        const deltas = list.slice(1).map((value, index) => value - list[index]);
        const avg = deltas.reduce((a, b) => a + b, 0) / deltas.length;
        const max = Math.max(...deltas);
        const min = Math.min(...deltas);

        const fps = Math.round(1000 / avg);
        const jitterMs = Math.round((max - min) * 10) / 10;
        const now = performance.now();

        if (now - lastPublish.current > 1000) {
          publish(buildPolicy(fps, jitterMs, document.visibilityState));
          lastPublish.current = now;
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

if ! grep -q "TRFMC_RF_OPERATIONAL_DECK_V14_AUTO_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_OPERATIONAL_DECK_V14_AUTO_STYLE */
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
echo "=== CREO OPERATIONAL DECK V14 AUTO ==="

cat > src/rf_instruments/instruments/RFOperationalDeckV14.tsx <<'TSX'
import React, { useMemo, useState } from "react";

import { RFInstrumentSuiteV5 } from "./RFInstrumentSuiteV5";
import { RFSourceBridgePanelV7 } from "../sources/RFSourceBridgePanelV7";
import { RFSourceRuntimeProbeV8 } from "../sources/RFSourceRuntimeProbeV8";
import { RFBridgeReadinessV9 } from "../telemetry/RFBridgeReadinessV9";
import { RFEvidenceFlightRecorderV10 } from "../evidence/RFEvidenceFlightRecorderV10";
import { RFRenderGovernorHeadlessV14 } from "../telemetry/RFRenderGovernorHeadlessV14";

type DeckTab =
  | "instruments"
  | "sources"
  | "runtime"
  | "bridge"
  | "evidence"
  | "ops";

const tabs: { id: DeckTab; label: string }[] = [
  { id: "instruments", label: "Instruments" },
  { id: "sources", label: "Sources" },
  { id: "runtime", label: "Runtime" },
  { id: "bridge", label: "Bridge" },
  { id: "evidence", label: "Evidence" },
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
        value: "V14 AUTO",
        detail: "Console a tab sopra la catena realmente presente."
      },
      {
        label: "Default",
        value: "Instruments",
        detail: "La suite strumenti è la superficie principale."
      },
      {
        label: "Governor",
        value: "Headless",
        detail: "Policy leggera sempre attiva anche fuori dai tab diagnostici."
      },
      {
        label: "Rendering",
        value: "Lazy View",
        detail: "Diagnostica a richiesta, non più stack verticale continuo."
      },
      {
        label: "Safety",
        value: "Read-only",
        detail: "Nessun controllo SDR, nessuna mutazione Open5GS."
      }
    ],
    []
  );

  return (
    <section className="rf-op14">
      <RFRenderGovernorHeadlessV14 />

      <header className="rf-op14-header">
        <div>
          <div className="rf-op14-title">TRFMC RF Operational Deck V14</div>
          <div className="rf-op14-sub">
            Compact mission deck · instruments first · diagnostics on demand · safe RF/Telco cockpit
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

        {active === "ops" && (
          <div>
            <details className="rf-op14-collapse" open>
              <summary>Instrument Suite</summary>
              <div><RFInstrumentSuiteV5 /></div>
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
          </div>
        )}
      </div>
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx -> RFOperationalDeckV14 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

backup = s

# Rimuove import precedenti dei componenti RF montati come root.
patterns = [
    r"import\s+\{\s*RFInstrumentSuiteV13GovernorBinding\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV12RenderGovernor\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV11PerformanceTelemetry\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV11PerformanceTelemetry['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV10EvidenceRecorder\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV10EvidenceRecorder['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV9BridgeReadiness\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV8SourceRuntime\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV7SourceBridge\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV6TurboSafe\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe['\"];?\n",
    r"import\s+\{\s*RFInstrumentSuiteV5\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV5['\"];?\n",
    r"import\s+\{\s*RFInstrumentDockV4\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentDockV4['\"];?\n",
    r"import\s+\{\s*RFSignalAnalyzerWorkbenchV3\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3['\"];?\n",
    r"import\s+\{\s*RFSignalAnalyzerWorkbenchV2\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFSignalAnalyzerWorkbenchV2['\"];?\n",
    r"import\s+\{\s*TrueSpectrumAnalyzer\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/TrueSpectrumAnalyzer['\"];?\n",
    r"import\s+\{\s*RFOperationalDeckV14\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFOperationalDeckV14['\"];?\n",
]

for pattern in patterns:
    s = re.sub(pattern, "", s)

# Inserisce import V14 dopo l'ultimo import esistente.
lines = s.splitlines(True)
insert_at = 0
for i, line in enumerate(lines):
    if line.lstrip().startswith("import "):
        insert_at = i + 1

lines.insert(insert_at, "import { RFOperationalDeckV14 } from '../rf_instruments/instruments/RFOperationalDeckV14'\n")
s = "".join(lines)

# Sostituisce il componente RF montato con il deck V14.
components = [
    "RFInstrumentSuiteV13GovernorBinding",
    "RFInstrumentSuiteV12RenderGovernor",
    "RFInstrumentSuiteV11PerformanceTelemetry",
    "RFInstrumentSuiteV10EvidenceRecorder",
    "RFInstrumentSuiteV9BridgeReadiness",
    "RFInstrumentSuiteV8SourceRuntime",
    "RFInstrumentSuiteV7SourceBridge",
    "RFInstrumentSuiteV6TurboSafe",
    "RFInstrumentSuiteV5",
    "RFInstrumentDockV4",
    "RFSignalAnalyzerWorkbenchV3",
    "RFSignalAnalyzerWorkbenchV2",
    "TrueSpectrumAnalyzer",
]

replaced = False
for component in components:
    if f"<{component} />" in s:
        s = s.replace(f"<{component} />", "<RFOperationalDeckV14 />")
        replaced = True

if not replaced:
    raise SystemExit("ERRORE: non ho trovato il componente RF root da sostituire in main.tsx")

p.write_text(s)
print("OK: main.tsx patched to RFOperationalDeckV14")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v14_operational_deck_auto.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_operational_deck_v14_auto_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_operational_deck_v14_auto_${TS}" src/styles.css
echo "Rollback V14 Operational Deck Auto completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v14_operational_deck_auto.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_OPERATIONAL_DECK_V14_AUTO",
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
    "headless_governor",
    "content_visibility",
    "details_ops_mode",
    "no_backend_mutation",
    "no_sdr_control"
  ],
  "pre_patch_freeze": "${FREEZE}",
  "rollback": "${QUALITY_DIR}/rollback_v14_operational_deck_auto.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_operational_deck_v14

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFOperationalDeckV14\|RFInstrumentSuiteV13GovernorBinding\|RFInstrumentSuiteV10EvidenceRecorder\|RFSignalAnalyzerWorkbenchV3" src/app/main.tsx || true

echo
echo "=== FILES V14 ==="
ls -lh \
  src/rf_instruments/telemetry/RFRenderGovernorHeadlessV14.tsx \
  src/rf_instruments/instruments/RFOperationalDeckV14.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_operational_deck_v14/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V14 AUTO CREATO. RIAVVIA VITE."
echo "============================================================"
