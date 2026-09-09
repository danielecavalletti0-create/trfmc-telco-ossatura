#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_INSTRUMENT_SUITE_V6_TURBO_SAFE_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_INSTRUMENT_SUITE_V6_TURBO_SAFE_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF INSTRUMENT SUITE V6 TURBO SAFE"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx || { echo "ERRORE: RFInstrumentSuiteV5.tsx mancante. Prima completare V5."; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentDockV4.tsx || { echo "ERRORE: RFInstrumentDockV4.tsx mancante"; exit 1; }
test -f src/rf_instruments/dsp/workers/RFSignalDspWorkerV3.ts || { echo "ERRORE: DSP Worker V3 mancante"; exit 1; }

grep -q "RFInstrumentSuiteV5" src/app/main.tsx || {
  echo "ERRORE: main.tsx non sta montando RFInstrumentSuiteV5. Non procedo per evitare sovrapposizioni."
  exit 1
}

echo "OK: V5 presente e montata"

echo
echo "=== BACKUP STATO V5 ==="
tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_suite_v6_turbo_${TS}"
cp src/styles.css "src/styles.css.bak_rf_suite_v6_turbo_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== CSS V6 TURBO ==="

if ! grep -q "TRFMC_RF_INSTRUMENT_SUITE_V6_TURBO_SAFE_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_INSTRUMENT_SUITE_V6_TURBO_SAFE_STYLE */
.rf-suite-v6-turbo{
  border:1px solid rgba(125,255,178,.30);
  border-radius:28px;
  overflow:hidden;
  background:
    radial-gradient(circle at 85% 0%,rgba(125,255,178,.12),transparent 32%),
    radial-gradient(circle at 10% 100%,rgba(0,229,255,.10),transparent 30%),
    linear-gradient(145deg,rgba(3,14,25,.98),rgba(0,3,8,.99));
  box-shadow:
    0 35px 120px rgba(0,0,0,.72),
    inset 0 0 65px rgba(125,255,178,.035);
}

.rf-suite-v6-turbo-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:16px;
  padding:16px;
  border-bottom:1px solid rgba(125,255,178,.22);
  background:
    linear-gradient(180deg,rgba(10,35,50,.98),rgba(2,9,16,.99));
}

.rf-suite-v6-turbo-title{
  font-size:22px;
  font-weight:950;
  letter-spacing:.14em;
  text-transform:uppercase;
  color:#efffff;
  text-shadow:
    0 0 18px rgba(125,255,178,.45),
    0 0 28px rgba(0,229,255,.24);
}

.rf-suite-v6-turbo-sub{
  margin-top:5px;
  color:#8fb8c8;
  font-size:12px;
}

.rf-suite-v6-turbo-badges{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  justify-content:flex-end;
  align-content:start;
}

.rf-suite-v6-badge{
  border:1px solid rgba(125,255,178,.28);
  background:rgba(125,255,178,.065);
  color:#7dffb2;
  border-radius:999px;
  padding:6px 10px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
  letter-spacing:.06em;
}

.rf-suite-v6-turbo-panel{
  padding:12px;
  display:grid;
  grid-template-columns:repeat(4,minmax(180px,1fr));
  gap:10px;
  border-bottom:1px solid rgba(57,215,255,.14);
  background:rgba(0,4,9,.50);
}

.rf-suite-v6-card{
  border:1px solid rgba(57,215,255,.22);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(8,22,38,.92),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(57,215,255,.08),transparent 36%);
  box-shadow:inset 0 0 30px rgba(57,215,255,.035);
}

.rf-suite-v6-card b{
  display:block;
  color:#39d7ff;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-suite-v6-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:17px;
  font-weight:850;
}

.rf-suite-v6-card small{
  display:block;
  color:#88a9c4;
  margin-top:6px;
  line-height:1.45;
}

.rf-suite-v6-stage{
  padding:10px;
}

@media(max-width:1400px){
  .rf-suite-v6-turbo-panel{ grid-template-columns:repeat(2,minmax(180px,1fr)); }
  .rf-suite-v6-turbo-header{ grid-template-columns:1fr; }
  .rf-suite-v6-turbo-badges{ justify-content:flex-start; }
}

@media(max-width:760px){
  .rf-suite-v6-turbo-panel{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO RFInstrumentSuiteV6TurboSafe.tsx ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe.tsx <<'TSX'
import React from "react";

import { RFInstrumentSuiteV5 } from "./RFInstrumentSuiteV5";

const cards = [
  {
    label: "Runtime",
    value: "React + Vite",
    detail: "Root SPA attiva, static shell preservata."
  },
  {
    label: "DSP",
    value: "Worker V3",
    detail: "Pipeline RF off-main-thread per telemetria e synthetic IQ."
  },
  {
    label: "Suite",
    value: "VSA/VNA/ANT/MW/OFDM",
    detail: "V5 modulare pronta per estensione scientifica."
  },
  {
    label: "Safety",
    value: "Freeze + Rollback",
    detail: "Ogni turbo step crea backup e quality summary."
  }
];

export function RFInstrumentSuiteV6TurboSafe() {
  return (
    <section className="rf-suite-v6-turbo">
      <header className="rf-suite-v6-turbo-header">
        <div>
          <div className="rf-suite-v6-turbo-title">TRFMC RF Instrument Suite V6 Turbo Safe</div>
          <div className="rf-suite-v6-turbo-sub">
            Safe missile mode · no destructive mutation · V5 preserved · DSP Worker V3 · RF/Telco instrumentation expansion rail
          </div>
        </div>

        <div className="rf-suite-v6-turbo-badges">
          <span className="rf-suite-v6-badge">TURBO SAFE</span>
          <span className="rf-suite-v6-badge">NO STATIC SHELL MUTATION</span>
          <span className="rf-suite-v6-badge">V4/V5 FREEZE PROTECTED</span>
          <span className="rf-suite-v6-badge">NEXT: REAL DSP / SDR BRIDGE</span>
        </div>
      </header>

      <div className="rf-suite-v6-turbo-panel">
        {cards.map((card) => (
          <div className="rf-suite-v6-card" key={card.label}>
            <b>{card.label}</b>
            <span>{card.value}</span>
            <small>{card.detail}</small>
          </div>
        ))}
      </div>

      <div className="rf-suite-v6-stage">
        <RFInstrumentSuiteV5 />
      </div>
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V5 -> V6 TURBO SAFE ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV5\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV5['\"];?\n",
    "import { RFInstrumentSuiteV6TurboSafe } from '../rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe'\n",
    s,
    count=1
)

if "RFInstrumentSuiteV6TurboSafe" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFInstrumentSuiteV6TurboSafe } from '../rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV5 />", "<RFInstrumentSuiteV6TurboSafe />")

p.write_text(s)
print("OK: main.tsx patched to V6 Turbo Safe")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v6_turbo_safe.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_suite_v6_turbo_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_suite_v6_turbo_${TS}" src/styles.css
echo "Rollback V6 Turbo Safe completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v6_turbo_safe.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_INSTRUMENT_SUITE_V6_TURBO_SAFE",
  "created": [
    "src/rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "pre_patch_freeze": "${FREEZE}",
  "preserves_v5_suite": true,
  "preserves_v4_dock": true,
  "uses_dsp_worker_v3": true,
  "rollback": "${QUALITY_DIR}/rollback_v6_turbo_safe.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_instrument_suite_v6_turbo_safe

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV6TurboSafe\|RFInstrumentSuiteV5\|RFInstrumentDockV4" src/app/main.tsx || true

echo
echo "=== FILE ==="
ls -lh src/rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_instrument_suite_v6_turbo_safe/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V6 TURBO SAFE CREATA. ORA RIAVVIA VITE."
echo "============================================================"
