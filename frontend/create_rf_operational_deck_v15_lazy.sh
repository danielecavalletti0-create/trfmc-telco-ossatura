#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_OPERATIONAL_DECK_V15_LAZY_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_OPERATIONAL_DECK_V15_LAZY_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF OPERATIONAL DECK V15 LAZY"
echo "React.lazy + Suspense + operational deck chunk loading"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/instruments

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }

test -f src/rf_instruments/instruments/RFOperationalDeckV14.tsx || {
  echo "ERRORE: RFOperationalDeckV14.tsx mancante. Prima completare V14 AUTO."
  exit 1
}

grep -q "RFOperationalDeckV14" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta RFOperationalDeckV14. Non procedo."
  exit 1
}

test -f src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx || { echo "ERRORE: RFInstrumentSuiteV5.tsx mancante"; exit 1; }
test -f src/rf_instruments/sources/RFSourceBridgePanelV7.tsx || { echo "ERRORE: RFSourceBridgePanelV7.tsx mancante"; exit 1; }
test -f src/rf_instruments/sources/RFSourceRuntimeProbeV8.tsx || { echo "ERRORE: RFSourceRuntimeProbeV8.tsx mancante"; exit 1; }
test -f src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx || { echo "ERRORE: RFBridgeReadinessV9.tsx mancante"; exit 1; }
test -f src/rf_instruments/evidence/RFEvidenceFlightRecorderV10.tsx || { echo "ERRORE: RFEvidenceFlightRecorderV10.tsx mancante"; exit 1; }
test -f src/rf_instruments/telemetry/RFRenderGovernorHeadlessV14.tsx || { echo "ERRORE: RFRenderGovernorHeadlessV14.tsx mancante"; exit 1; }

echo "OK: V14 presente e montato"

echo
echo "=== BACKUP STATO V14 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_operational_deck_v15_lazy_${TS}"
cp src/styles.css "src/styles.css.bak_rf_operational_deck_v15_lazy_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== APPENDO CSS V15 ==="

if ! grep -q "TRFMC_RF_OPERATIONAL_DECK_V15_LAZY_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_OPERATIONAL_DECK_V15_LAZY_STYLE */
.rf-op15-loader{
  border:1px solid rgba(57,215,255,.26);
  border-radius:18px;
  min-height:180px;
  display:flex;
  align-items:center;
  justify-content:center;
  background:
    radial-gradient(circle at 50% 0%,rgba(57,215,255,.12),transparent 36%),
    linear-gradient(145deg,rgba(8,22,38,.92),rgba(1,5,11,.98));
  color:#39d7ff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:12px;
  letter-spacing:.10em;
  text-transform:uppercase;
  box-shadow:inset 0 0 36px rgba(57,215,255,.04);
}

.rf-op15-loader::before{
  content:"";
  width:10px;
  height:10px;
  margin-right:10px;
  border-radius:50%;
  background:#39d7ff;
  box-shadow:0 0 16px rgba(57,215,255,.8);
  animation:rf-op15-pulse 1s infinite alternate;
}

@keyframes rf-op15-pulse{
  from{ opacity:.35; transform:scale(.75); }
  to{ opacity:1; transform:scale(1.1); }
}

.rf-op15-chunk-badge{
  display:inline-flex;
  align-items:center;
  border:1px solid rgba(125,255,178,.26);
  background:rgba(125,255,178,.06);
  color:#7dffb2;
  border-radius:999px;
  padding:5px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
  margin-left:8px;
}
CSS
fi

echo
echo "=== CREO RFOperationalDeckV15Lazy.tsx ==="

cat > src/rf_instruments/instruments/RFOperationalDeckV15Lazy.tsx <<'TSX'
import React, { lazy, Suspense, useMemo, useState } from "react";

import { RFRenderGovernorHeadlessV14 } from "../telemetry/RFRenderGovernorHeadlessV14";

const RFInstrumentSuiteV5 = lazy(() =>
  import("./RFInstrumentSuiteV5").then((module) => ({
    default: module.RFInstrumentSuiteV5
  }))
);

const RFSourceBridgePanelV7 = lazy(() =>
  import("../sources/RFSourceBridgePanelV7").then((module) => ({
    default: module.RFSourceBridgePanelV7
  }))
);

const RFSourceRuntimeProbeV8 = lazy(() =>
  import("../sources/RFSourceRuntimeProbeV8").then((module) => ({
    default: module.RFSourceRuntimeProbeV8
  }))
);

const RFBridgeReadinessV9 = lazy(() =>
  import("../telemetry/RFBridgeReadinessV9").then((module) => ({
    default: module.RFBridgeReadinessV9
  }))
);

const RFEvidenceFlightRecorderV10 = lazy(() =>
  import("../evidence/RFEvidenceFlightRecorderV10").then((module) => ({
    default: module.RFEvidenceFlightRecorderV10
  }))
);

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

function Loader({ label }: { label: string }) {
  return <div className="rf-op15-loader">Loading {label} chunk</div>;
}

function StatusCard(props: { label: string; value: string; detail: string }) {
  return (
    <div className="rf-op14-card">
      <b>{props.label}</b>
      <span>{props.value}</span>
      <small>{props.detail}</small>
    </div>
  );
}

export function RFOperationalDeckV15Lazy() {
  const [active, setActive] = useState<DeckTab>("instruments");

  const cards = useMemo(
    () => [
      {
        label: "Deck",
        value: "V15 LAZY",
        detail: "Console a tab con caricamento dinamico dei pannelli."
      },
      {
        label: "Default",
        value: "Instruments",
        detail: "La suite strumenti resta la superficie principale."
      },
      {
        label: "Loading",
        value: "React.lazy",
        detail: "I moduli pesanti vengono caricati al primo uso."
      },
      {
        label: "Governor",
        value: "Headless",
        detail: "Policy leggera sempre attiva fuori dai chunk."
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
          <div className="rf-op14-title">
            TRFMC RF Operational Deck V15
            <span className="rf-op15-chunk-badge">LAZY MODULE LOADING</span>
          </div>
          <div className="rf-op14-sub">
            Compact mission deck · dynamic chunk loading · instruments first · diagnostics on demand
          </div>
        </div>

        <div className="rf-op14-badges">
          <span>REACT LAZY</span>
          <span>SUSPENSE</span>
          <span>DYNAMIC IMPORT</span>
          <span>HEADLESS GOVERNOR</span>
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
        {active === "instruments" && (
          <Suspense fallback={<Loader label="instrument suite" />}>
            <RFInstrumentSuiteV5 />
          </Suspense>
        )}

        {active === "sources" && (
          <Suspense fallback={<Loader label="source bridge" />}>
            <RFSourceBridgePanelV7 />
          </Suspense>
        )}

        {active === "runtime" && (
          <Suspense fallback={<Loader label="runtime probe" />}>
            <RFSourceRuntimeProbeV8 />
          </Suspense>
        )}

        {active === "bridge" && (
          <Suspense fallback={<Loader label="bridge readiness" />}>
            <RFBridgeReadinessV9 />
          </Suspense>
        )}

        {active === "evidence" && (
          <Suspense fallback={<Loader label="evidence recorder" />}>
            <RFEvidenceFlightRecorderV10 />
          </Suspense>
        )}

        {active === "ops" && (
          <div>
            <details className="rf-op14-collapse" open>
              <summary>Instrument Suite</summary>
              <div>
                <Suspense fallback={<Loader label="instrument suite" />}>
                  <RFInstrumentSuiteV5 />
                </Suspense>
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Source Bridge + Runtime</summary>
              <div className="rf-op14-grid2">
                <Suspense fallback={<Loader label="source bridge" />}>
                  <RFSourceBridgePanelV7 />
                </Suspense>

                <Suspense fallback={<Loader label="runtime probe" />}>
                  <RFSourceRuntimeProbeV8 />
                </Suspense>
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Bridge Readiness + Evidence Recorder</summary>
              <div className="rf-op14-grid2">
                <Suspense fallback={<Loader label="bridge readiness" />}>
                  <RFBridgeReadinessV9 />
                </Suspense>

                <Suspense fallback={<Loader label="evidence recorder" />}>
                  <RFEvidenceFlightRecorderV10 />
                </Suspense>
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
echo "=== PATCH main.tsx: V14 -> V15 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFOperationalDeckV14\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFOperationalDeckV14['\"];?\n",
    "import { RFOperationalDeckV15Lazy } from '../rf_instruments/instruments/RFOperationalDeckV15Lazy'\n",
    s,
    count=1
)

if "RFOperationalDeckV15Lazy" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFOperationalDeckV15Lazy } from '../rf_instruments/instruments/RFOperationalDeckV15Lazy'\n")
    s = "".join(lines)

s = s.replace("<RFOperationalDeckV14 />", "<RFOperationalDeckV15Lazy />")

p.write_text(s)
print("OK: main.tsx patched to RFOperationalDeckV15Lazy")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v15_lazy_deck.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_operational_deck_v15_lazy_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_operational_deck_v15_lazy_${TS}" src/styles.css
echo "Rollback V15 Lazy Operational Deck completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v15_lazy_deck.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_OPERATIONAL_DECK_V15_LAZY",
  "created": [
    "src/rf_instruments/instruments/RFOperationalDeckV15Lazy.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "features": [
    "React.lazy",
    "Suspense fallback",
    "dynamic_import_chunks",
    "instruments_first_default",
    "diagnostics_on_demand",
    "headless_governor_preserved",
    "no_backend_mutation",
    "no_sdr_control"
  ],
  "pre_patch_freeze": "${FREEZE}",
  "rollback": "${QUALITY_DIR}/rollback_v15_lazy_deck.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_operational_deck_v15_lazy

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFOperationalDeckV15Lazy\\|RFOperationalDeckV14" src/app/main.tsx || true

echo
echo "=== FILE V15 ==="
ls -lh src/rf_instruments/instruments/RFOperationalDeckV15Lazy.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_operational_deck_v15_lazy/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V15 LAZY CREATO. RIAVVIA VITE."
echo "============================================================"
