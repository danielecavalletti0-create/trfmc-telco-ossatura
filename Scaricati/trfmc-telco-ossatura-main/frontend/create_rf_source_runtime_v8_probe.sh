#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_SOURCE_RUNTIME_V8_PROBE_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_SOURCE_RUNTIME_V8_PROBE_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF SOURCE RUNTIME V8 PROBE"
echo "Synthetic runtime health · source frame counter · safe bridge rail"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge.tsx || { echo "ERRORE: RFInstrumentSuiteV7SourceBridge.tsx mancante. Prima completare V7."; exit 1; }
test -f src/rf_instruments/sources/SyntheticRFSourceAdapter.ts || { echo "ERRORE: SyntheticRFSourceAdapter.ts mancante"; exit 1; }
test -f src/rf_instruments/sources/RFSourceBridgePanelV7.tsx || { echo "ERRORE: RFSourceBridgePanelV7.tsx mancante"; exit 1; }

grep -q "RFInstrumentSuiteV7SourceBridge" src/app/main.tsx || {
  echo "ERRORE: main.tsx non sta montando RFInstrumentSuiteV7SourceBridge. Non procedo."
  exit 1
}

echo "OK: V7 Source Bridge presente e montato"

echo
echo "=== BACKUP STATO V7 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_source_runtime_v8_${TS}"
cp src/styles.css "src/styles.css.bak_rf_source_runtime_v8_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== APPENDO CSS V8 ==="

if ! grep -q "TRFMC_RF_SOURCE_RUNTIME_V8_PROBE_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_SOURCE_RUNTIME_V8_PROBE_STYLE */
.rf-runtime-v8{
  margin-bottom:12px;
  border:1px solid rgba(0,229,255,.30);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 80% 0%,rgba(0,229,255,.13),transparent 34%),
    linear-gradient(145deg,rgba(4,18,30,.96),rgba(0,4,9,.99));
  box-shadow:
    0 26px 95px rgba(0,0,0,.62),
    inset 0 0 48px rgba(0,229,255,.035);
}

.rf-runtime-v8-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:14px;
  padding:14px;
  border-bottom:1px solid rgba(0,229,255,.20);
  background:linear-gradient(180deg,rgba(8,31,48,.95),rgba(2,9,16,.98));
}

.rf-runtime-v8-title{
  color:#eafbff;
  font-size:17px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.12em;
  text-shadow:0 0 18px rgba(0,229,255,.42);
}

.rf-runtime-v8-sub{
  margin-top:5px;
  color:#88a9c4;
  font-size:11px;
}

.rf-runtime-v8-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-runtime-v8-badges span{
  border:1px solid rgba(0,229,255,.25);
  background:rgba(0,229,255,.06);
  color:#39d7ff;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-runtime-v8-grid{
  padding:10px;
  display:grid;
  grid-template-columns:repeat(4,minmax(180px,1fr));
  gap:10px;
}

.rf-runtime-v8-card{
  border:1px solid rgba(0,229,255,.20);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(8,22,38,.90),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(0,229,255,.08),transparent 35%);
}

.rf-runtime-v8-card b{
  display:block;
  color:#39d7ff;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-runtime-v8-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:17px;
  font-weight:850;
}

.rf-runtime-v8-card small{
  display:block;
  color:#88a9c4;
  margin-top:6px;
  line-height:1.45;
}

.rf-runtime-v8-log{
  margin:0 10px 10px;
  border:1px solid rgba(0,229,255,.16);
  border-radius:16px;
  background:#02060c;
  color:#dff3ff;
  padding:10px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:11px;
  max-height:150px;
  overflow:auto;
}

@media(max-width:1300px){
  .rf-runtime-v8-grid{ grid-template-columns:repeat(2,minmax(180px,1fr)); }
  .rf-runtime-v8-header{ grid-template-columns:1fr; }
  .rf-runtime-v8-badges{ justify-content:flex-start; }
}

@media(max-width:760px){
  .rf-runtime-v8-grid{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO SOURCE RUNTIME PROBE V8 ==="

cat > src/rf_instruments/sources/RFSourceRuntimeProbeV8.tsx <<'TSX'
import React, { useEffect, useMemo, useRef, useState } from "react";

import { SyntheticRFSourceAdapter } from "./SyntheticRFSourceAdapter";
import type { RFBridgeFrameMeta } from "./RFSourceTypes";

type ProbeState = {
  status: string;
  frames: number;
  drops: number;
  lastFrameAt: string;
  lastBytes: number;
  lastMeta: string;
};

const initialState: ProbeState = {
  status: "BOOT",
  frames: 0,
  drops: 0,
  lastFrameAt: "—",
  lastBytes: 0,
  lastMeta: "waiting synthetic adapter"
};

export function RFSourceRuntimeProbeV8() {
  const adapterRef = useRef<SyntheticRFSourceAdapter | null>(null);
  const [state, setState] = useState<ProbeState>(initialState);
  const [log, setLog] = useState<string[]>([]);

  useEffect(() => {
    const adapter = new SyntheticRFSourceAdapter();
    adapterRef.current = adapter;

    adapter.onFrame((payload, meta: RFBridgeFrameMeta) => {
      const health = adapter.getHealth();

      const bytes =
        payload instanceof Float32Array
          ? payload.byteLength
          : payload instanceof ArrayBuffer
            ? payload.byteLength
            : 0;

      setState({
        status: health.status,
        frames: health.frames,
        drops: health.drops,
        lastFrameAt: new Date(meta.timestamp).toLocaleTimeString(),
        lastBytes: bytes,
        lastMeta: `${meta.source} seq=${meta.sequence} ${meta.format ?? ""}`
      });

      if (meta.sequence % 10 === 0) {
        setLog((old) => [
          `[${new Date(meta.timestamp).toLocaleTimeString()}] source=${meta.source} seq=${meta.sequence} bytes=${bytes} format=${meta.format ?? "n/a"}`,
          ...old
        ].slice(0, 8));
      }
    });

    adapter.connect();

    setLog((old) => [
      "[BOOT] SyntheticRFSourceAdapter connected in safe runtime probe mode.",
      ...old
    ]);

    return () => {
      adapter.disconnect();
      adapterRef.current = null;
    };
  }, []);

  const cards = useMemo(
    () => [
      {
        label: "Source",
        value: "Synthetic",
        detail: "Runtime adapter reale, nessuna sorgente live esterna."
      },
      {
        label: "Status",
        value: state.status,
        detail: "Health ottenuto da SyntheticRFSourceAdapter."
      },
      {
        label: "Frames",
        value: String(state.frames),
        detail: `Drops ${state.drops} · last ${state.lastFrameAt}`
      },
      {
        label: "Payload",
        value: `${state.lastBytes} B`,
        detail: state.lastMeta
      }
    ],
    [state]
  );

  return (
    <section className="rf-runtime-v8">
      <header className="rf-runtime-v8-header">
        <div>
          <div className="rf-runtime-v8-title">TRFMC RF Source Runtime V8 Probe</div>
          <div className="rf-runtime-v8-sub">
            Safe runtime verification · synthetic adapter active · future binary IQ/WebSocket/SDR rails preserved
          </div>
        </div>

        <div className="rf-runtime-v8-badges">
          <span>RUNTIME PROBE ACTIVE</span>
          <span>NO SDR AUTO-CONNECT</span>
          <span>NO OPEN5GS MUTATION</span>
          <span>SOURCE CONTRACT READY</span>
        </div>
      </header>

      <div className="rf-runtime-v8-grid">
        {cards.map((card) => (
          <div className="rf-runtime-v8-card" key={card.label}>
            <b>{card.label}</b>
            <span>{card.value}</span>
            <small>{card.detail}</small>
          </div>
        ))}
      </div>

      <pre className="rf-runtime-v8-log">
        {log.length ? log.join("\n") : "waiting frames..."}
      </pre>
    </section>
  );
}
TSX

echo
echo "=== CREO WRAPPER V8 ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime.tsx <<'TSX'
import React from "react";

import { RFInstrumentSuiteV7SourceBridge } from "./RFInstrumentSuiteV7SourceBridge";
import { RFSourceRuntimeProbeV8 } from "../sources/RFSourceRuntimeProbeV8";

export function RFInstrumentSuiteV8SourceRuntime() {
  return (
    <section>
      <RFSourceRuntimeProbeV8 />
      <RFInstrumentSuiteV7SourceBridge />
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V7 -> V8 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV7SourceBridge\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge['\"];?\n",
    "import { RFInstrumentSuiteV8SourceRuntime } from '../rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime'\n",
    s,
    count=1
)

if "RFInstrumentSuiteV8SourceRuntime" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFInstrumentSuiteV8SourceRuntime } from '../rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV7SourceBridge />", "<RFInstrumentSuiteV8SourceRuntime />")

p.write_text(s)
print("OK: main.tsx patched to V8 Source Runtime")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v8_source_runtime.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_source_runtime_v8_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_source_runtime_v8_${TS}" src/styles.css
echo "Rollback V8 Source Runtime completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v8_source_runtime.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_SOURCE_RUNTIME_V8_PROBE",
  "created": [
    "src/rf_instruments/sources/RFSourceRuntimeProbeV8.tsx",
    "src/rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "runtime_probe": "SyntheticRFSourceAdapter",
  "auto_connect_live_sources": false,
  "preserves_v7_source_bridge": true,
  "rollback": "${QUALITY_DIR}/rollback_v8_source_runtime.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_source_runtime_v8_probe

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV8SourceRuntime\\|RFInstrumentSuiteV7SourceBridge\\|RFInstrumentSuiteV6TurboSafe" src/app/main.tsx || true

echo
echo "=== FILES ==="
ls -lh \
  src/rf_instruments/sources/RFSourceRuntimeProbeV8.tsx \
  src/rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_source_runtime_v8_probe/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V8 SOURCE RUNTIME PROBE CREATO. ORA RIAVVIA VITE."
echo "============================================================"
