#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_SOURCE_BRIDGE_V7_PREP_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_SOURCE_BRIDGE_V7_PREP_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF SOURCE BRIDGE V7 PREP"
echo "Synthetic · File IQ · WebSocket IQ · SDR Bridge · Open5GS Events"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/sources

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe.tsx || { echo "ERRORE: RFInstrumentSuiteV6TurboSafe.tsx mancante. Prima completare V6."; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx || { echo "ERRORE: RFInstrumentSuiteV5.tsx mancante"; exit 1; }
test -f src/rf_instruments/dsp/workers/RFSignalDspWorkerV3.ts || { echo "ERRORE: DSP Worker V3 mancante"; exit 1; }

grep -q "RFInstrumentSuiteV6TurboSafe" src/app/main.tsx || {
  echo "ERRORE: main.tsx non sta montando RFInstrumentSuiteV6TurboSafe. Non procedo per evitare sovrapposizioni."
  exit 1
}

echo "OK: V6 Turbo Safe presente e montata"

echo
echo "=== BACKUP STATO V6 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_source_bridge_v7_${TS}"
cp src/styles.css "src/styles.css.bak_rf_source_bridge_v7_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== CREO TIPI RF SOURCE ==="

cat > src/rf_instruments/sources/RFSourceTypes.ts <<'TS'
export type RFSourceMode =
  | "synthetic"
  | "file_iq"
  | "websocket_iq"
  | "sdr_bridge"
  | "open5gs_events";

export type RFSourceStatus =
  | "disabled"
  | "standby"
  | "ready"
  | "connected"
  | "streaming"
  | "error";

export type RFSourceDescriptor = {
  mode: RFSourceMode;
  label: string;
  status: RFSourceStatus;
  endpoint?: string;
  sampleRate?: number;
  centerFrequency?: number;
  bandwidth?: number;
  format?: "complex64" | "int16_iq" | "float32_iq" | "json_events" | "pcap_meta";
  safety: "synthetic_only" | "local_lab_only" | "read_only_bridge";
  notes: string;
};

export type RFBridgeFrameMeta = {
  source: RFSourceMode;
  timestamp: number;
  sequence: number;
  sampleRate?: number;
  centerFrequency?: number;
  bytes?: number;
  format?: string;
};

export type RFSourceHealth = {
  mode: RFSourceMode;
  status: RFSourceStatus;
  lastFrameAt?: number;
  frames: number;
  drops: number;
  message: string;
};

export const RF_SOURCE_DESCRIPTORS: RFSourceDescriptor[] = [
  {
    mode: "synthetic",
    label: "Synthetic DSP Worker",
    status: "ready",
    sampleRate: 122_880_000,
    centerFrequency: 2_440_000_000,
    bandwidth: 80_000_000,
    format: "float32_iq",
    safety: "synthetic_only",
    notes: "Current safe source. Generates synthetic RF/IQ evidence inside DSP Worker V3."
  },
  {
    mode: "file_iq",
    label: "File IQ Replay",
    status: "standby",
    endpoint: "local file / future upload pipeline",
    format: "complex64",
    safety: "local_lab_only",
    notes: "Prepared for offline IQ replay without touching live SDR."
  },
  {
    mode: "websocket_iq",
    label: "Binary WebSocket IQ",
    status: "standby",
    endpoint: "ws://127.0.0.1:8090/ws/iq",
    format: "float32_iq",
    safety: "local_lab_only",
    notes: "Prepared for ArrayBuffer IQ frames. Not auto-connected in V7."
  },
  {
    mode: "sdr_bridge",
    label: "SDR / HackRF Bridge",
    status: "standby",
    endpoint: "ws://127.0.0.1:8090/ws/sdr",
    format: "int16_iq",
    safety: "read_only_bridge",
    notes: "Future read-only bridge for SDR capture pipeline."
  },
  {
    mode: "open5gs_events",
    label: "Open5GS / UERANSIM Events",
    status: "standby",
    endpoint: "ws://127.0.0.1:8000/api/events/stream",
    format: "json_events",
    safety: "read_only_bridge",
    notes: "Future event correlation layer for NAS/NGAP/PFCP/GTP-U evidence."
  }
];
TS

echo
echo "=== CREO SOURCE ADAPTER INTERFACE ==="

cat > src/rf_instruments/sources/RFSourceAdapter.ts <<'TS'
import type { RFBridgeFrameMeta, RFSourceHealth, RFSourceMode } from "./RFSourceTypes";

export type RFSourceFrameHandler = (payload: ArrayBuffer | Float32Array | unknown, meta: RFBridgeFrameMeta) => void;

export interface RFSourceAdapter {
  readonly mode: RFSourceMode;
  connect(): Promise<void>;
  disconnect(): void;
  onFrame(handler: RFSourceFrameHandler): void;
  getHealth(): RFSourceHealth;
}

export function nowFrameMeta(mode: RFSourceMode, sequence: number, extra: Partial<RFBridgeFrameMeta> = {}): RFBridgeFrameMeta {
  return {
    source: mode,
    timestamp: Date.now(),
    sequence,
    ...extra
  };
}
TS

echo
echo "=== CREO SYNTHETIC SOURCE ADAPTER ==="

cat > src/rf_instruments/sources/SyntheticRFSourceAdapter.ts <<'TS'
import type { RFSourceAdapter, RFSourceFrameHandler } from "./RFSourceAdapter";
import { nowFrameMeta } from "./RFSourceAdapter";
import type { RFSourceHealth } from "./RFSourceTypes";

export class SyntheticRFSourceAdapter implements RFSourceAdapter {
  readonly mode = "synthetic" as const;

  private handler: RFSourceFrameHandler | null = null;
  private timer: number | null = null;
  private frames = 0;

  async connect() {
    if (this.timer !== null) return;

    this.timer = window.setInterval(() => {
      const bins = new Float32Array(1024);

      for (let i = 0; i < bins.length; i++) {
        const f = i / (bins.length - 1);
        bins[i] =
          0.07 +
          0.02 * Math.sin(i * 0.03 + this.frames * 0.1) +
          0.35 * Math.exp(-Math.pow((f - 0.50) / 0.015, 2));
      }

      this.handler?.(
        bins,
        nowFrameMeta(this.mode, this.frames, {
          sampleRate: 122_880_000,
          centerFrequency: 2_440_000_000,
          format: "float32_spectrum"
        })
      );

      this.frames++;
    }, 100);
  }

  disconnect() {
    if (this.timer !== null) {
      window.clearInterval(this.timer);
      this.timer = null;
    }
  }

  onFrame(handler: RFSourceFrameHandler) {
    this.handler = handler;
  }

  getHealth(): RFSourceHealth {
    return {
      mode: this.mode,
      status: this.timer === null ? "ready" : "streaming",
      frames: this.frames,
      drops: 0,
      message: "Synthetic source adapter prepared."
    };
  }
}
TS

echo
echo "=== CREO WEBSOCKET IQ SOURCE ADAPTER PREP ==="

cat > src/rf_instruments/sources/WebSocketIQSourceAdapter.ts <<'TS'
import type { RFSourceAdapter, RFSourceFrameHandler } from "./RFSourceAdapter";
import { nowFrameMeta } from "./RFSourceAdapter";
import type { RFSourceHealth } from "./RFSourceTypes";

export class WebSocketIQSourceAdapter implements RFSourceAdapter {
  readonly mode = "websocket_iq" as const;

  private ws: WebSocket | null = null;
  private handler: RFSourceFrameHandler | null = null;
  private frames = 0;
  private drops = 0;
  private status: RFSourceHealth["status"] = "standby";
  private message = "Prepared. Not connected.";

  constructor(private endpoint: string) {}

  async connect() {
    if (this.ws) return;

    this.status = "connected";
    this.message = `Connecting to ${this.endpoint}`;

    this.ws = new WebSocket(this.endpoint);
    this.ws.binaryType = "arraybuffer";

    this.ws.onopen = () => {
      this.status = "streaming";
      this.message = "Binary IQ WebSocket connected.";
    };

    this.ws.onmessage = (ev) => {
      if (ev.data instanceof ArrayBuffer) {
        this.handler?.(
          ev.data,
          nowFrameMeta(this.mode, this.frames, {
            bytes: ev.data.byteLength,
            format: "arraybuffer"
          })
        );
        this.frames++;
      } else {
        this.drops++;
      }
    };

    this.ws.onerror = () => {
      this.status = "error";
      this.message = "WebSocket IQ error.";
    };

    this.ws.onclose = () => {
      this.status = "standby";
      this.message = "WebSocket IQ closed.";
      this.ws = null;
    };
  }

  disconnect() {
    this.ws?.close();
    this.ws = null;
    this.status = "standby";
    this.message = "Disconnected.";
  }

  onFrame(handler: RFSourceFrameHandler) {
    this.handler = handler;
  }

  getHealth(): RFSourceHealth {
    return {
      mode: this.mode,
      status: this.status,
      frames: this.frames,
      drops: this.drops,
      message: this.message
    };
  }
}
TS

echo
echo "=== CREO BRIDGE PANEL V7 ==="

cat > src/rf_instruments/sources/RFSourceBridgePanelV7.tsx <<'TSX'
import React, { useMemo, useState } from "react";

import { RF_SOURCE_DESCRIPTORS, RFSourceMode } from "./RFSourceTypes";

const sourceOrder: RFSourceMode[] = [
  "synthetic",
  "file_iq",
  "websocket_iq",
  "sdr_bridge",
  "open5gs_events"
];

export function RFSourceBridgePanelV7() {
  const [selected, setSelected] = useState<RFSourceMode>("synthetic");

  const active = useMemo(
    () => RF_SOURCE_DESCRIPTORS.find((s) => s.mode === selected) ?? RF_SOURCE_DESCRIPTORS[0],
    [selected]
  );

  return (
    <section className="rf-source-v7">
      <header className="rf-source-v7-header">
        <div>
          <div className="rf-source-v7-title">TRFMC RF Source Bridge V7 Prep</div>
          <div className="rf-source-v7-sub">
            Source abstraction rail · synthetic safe source now · file IQ / binary WebSocket / SDR bridge / Open5GS events prepared
          </div>
        </div>

        <div className="rf-source-v7-badges">
          <span>SOURCE MODE: {active.mode}</span>
          <span>SAFETY: {active.safety}</span>
          <span>STATUS: {active.status}</span>
        </div>
      </header>

      <div className="rf-source-v7-grid">
        <div className="rf-source-v7-card">
          <h3>Source Selector</h3>

          <div className="rf-source-v7-selector">
            {sourceOrder.map((mode) => {
              const item = RF_SOURCE_DESCRIPTORS.find((s) => s.mode === mode)!;

              return (
                <button
                  key={mode}
                  className={selected === mode ? "rf-source-v7-button active" : "rf-source-v7-button"}
                  onClick={() => setSelected(mode)}
                >
                  {item.label}
                </button>
              );
            })}
          </div>
        </div>

        <div className="rf-source-v7-card">
          <h3>Selected Source Contract</h3>

          <table className="rf-source-v7-table">
            <tbody>
              <tr><th>Field</th><th>Value</th></tr>
              <tr><td>Mode</td><td>{active.mode}</td></tr>
              <tr><td>Label</td><td>{active.label}</td></tr>
              <tr><td>Status</td><td>{active.status}</td></tr>
              <tr><td>Endpoint</td><td>{active.endpoint ?? "local/internal"}</td></tr>
              <tr><td>Sample Rate</td><td>{active.sampleRate ? `${active.sampleRate.toLocaleString()} S/s` : "not negotiated"}</td></tr>
              <tr><td>Center</td><td>{active.centerFrequency ? `${(active.centerFrequency / 1e9).toFixed(6)} GHz` : "not negotiated"}</td></tr>
              <tr><td>Format</td><td>{active.format}</td></tr>
              <tr><td>Safety</td><td>{active.safety}</td></tr>
            </tbody>
          </table>
        </div>

        <div className="rf-source-v7-card rf-source-v7-wide">
          <h3>Bridge Roadmap</h3>

          <div className="rf-source-v7-flow">
            <span>RF Source</span>
            <b>→</b>
            <span>Frame Adapter</span>
            <b>→</b>
            <span>DSP Worker</span>
            <b>→</b>
            <span>Metrics</span>
            <b>→</b>
            <span>VSA / VNA / OFDM Views</span>
          </div>

          <p className="rf-source-v7-note">
            {active.notes}
          </p>

          <p className="rf-source-v7-note">
            V7 does not auto-connect to SDR or external sockets. It prepares typed contracts and UI routing only.
            Live bridges will be enabled later behind explicit local-lab safety gates.
          </p>
        </div>
      </div>
    </section>
  );
}
TSX

echo
echo "=== APPENDO CSS SOURCE BRIDGE V7 ==="

if ! grep -q "TRFMC_RF_SOURCE_BRIDGE_V7_PREP_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_SOURCE_BRIDGE_V7_PREP_STYLE */
.rf-source-v7{
  margin-bottom:12px;
  border:1px solid rgba(255,209,102,.28);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 88% 0%,rgba(255,209,102,.10),transparent 34%),
    linear-gradient(145deg,rgba(16,20,9,.94),rgba(1,5,10,.99));
  box-shadow:
    0 24px 90px rgba(0,0,0,.60),
    inset 0 0 44px rgba(255,209,102,.035);
}

.rf-source-v7-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:14px;
  padding:14px;
  border-bottom:1px solid rgba(255,209,102,.20);
  background:linear-gradient(180deg,rgba(38,31,12,.92),rgba(4,8,12,.98));
}

.rf-source-v7-title{
  color:#fff7d6;
  font-size:17px;
  font-weight:950;
  letter-spacing:.12em;
  text-transform:uppercase;
  text-shadow:0 0 18px rgba(255,209,102,.38);
}

.rf-source-v7-sub{
  margin-top:5px;
  color:#b9a979;
  font-size:11px;
}

.rf-source-v7-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-source-v7-badges span{
  border:1px solid rgba(255,209,102,.26);
  background:rgba(255,209,102,.06);
  color:#ffd166;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-source-v7-grid{
  padding:10px;
  display:grid;
  grid-template-columns:.75fr 1fr;
  gap:10px;
}

.rf-source-v7-card{
  border:1px solid rgba(255,209,102,.20);
  border-radius:18px;
  padding:10px;
  background:
    linear-gradient(145deg,rgba(18,17,9,.86),rgba(1,5,10,.98)),
    radial-gradient(circle at 100% 0%,rgba(255,209,102,.08),transparent 35%);
}

.rf-source-v7-card h3{
  margin:0 0 9px;
  color:#ffd166;
  text-transform:uppercase;
  letter-spacing:.10em;
  font-size:12px;
}

.rf-source-v7-wide{
  grid-column:span 2;
}

.rf-source-v7-selector{
  display:grid;
  gap:7px;
}

.rf-source-v7-button{
  justify-content:flex-start;
  text-align:left;
  border-color:rgba(255,209,102,.25);
}

.rf-source-v7-button.active{
  color:#171100;
  background:linear-gradient(180deg,#ffe28a,#ffbf3c);
  border-color:#fff1b8;
  box-shadow:0 0 18px rgba(255,209,102,.35);
}

.rf-source-v7-table{
  width:100%;
  border-collapse:collapse;
  font-family:ui-monospace,Consolas,monospace;
  font-size:12px;
}

.rf-source-v7-table th,
.rf-source-v7-table td{
  border-bottom:1px solid rgba(255,209,102,.14);
  padding:7px 8px;
  text-align:left;
}

.rf-source-v7-table th{
  color:#ffd166;
  background:rgba(255,209,102,.055);
  text-transform:uppercase;
  letter-spacing:.08em;
  font-size:10px;
}

.rf-source-v7-flow{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  align-items:center;
  font-family:ui-monospace,Consolas,monospace;
}

.rf-source-v7-flow span{
  border:1px solid rgba(57,215,255,.20);
  border-radius:12px;
  padding:8px 10px;
  color:#dff3ff;
  background:rgba(57,215,255,.045);
}

.rf-source-v7-flow b{
  color:#ffd166;
}

.rf-source-v7-note{
  color:#b9a979;
  line-height:1.5;
  margin:10px 0 0;
}

@media(max-width:1200px){
  .rf-source-v7-header,
  .rf-source-v7-grid{
    grid-template-columns:1fr;
  }

  .rf-source-v7-wide{
    grid-column:span 1;
  }

  .rf-source-v7-badges{
    justify-content:flex-start;
  }
}
CSS
fi

echo
echo "=== CREO SUITE V7 WRAPPER ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge.tsx <<'TSX'
import React from "react";

import { RFInstrumentSuiteV6TurboSafe } from "./RFInstrumentSuiteV6TurboSafe";
import { RFSourceBridgePanelV7 } from "../sources/RFSourceBridgePanelV7";

export function RFInstrumentSuiteV7SourceBridge() {
  return (
    <section>
      <RFSourceBridgePanelV7 />
      <RFInstrumentSuiteV6TurboSafe />
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V6 -> V7 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV6TurboSafe\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV6TurboSafe['\"];?\n",
    "import { RFInstrumentSuiteV7SourceBridge } from '../rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge'\n",
    s,
    count=1
)

if "RFInstrumentSuiteV7SourceBridge" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFInstrumentSuiteV7SourceBridge } from '../rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV6TurboSafe />", "<RFInstrumentSuiteV7SourceBridge />")

p.write_text(s)
print("OK: main.tsx patched to V7 Source Bridge")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v7_source_bridge.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_source_bridge_v7_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_source_bridge_v7_${TS}" src/styles.css
echo "Rollback V7 Source Bridge completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v7_source_bridge.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_SOURCE_BRIDGE_V7_PREP",
  "created": [
    "src/rf_instruments/sources/RFSourceTypes.ts",
    "src/rf_instruments/sources/RFSourceAdapter.ts",
    "src/rf_instruments/sources/SyntheticRFSourceAdapter.ts",
    "src/rf_instruments/sources/WebSocketIQSourceAdapter.ts",
    "src/rf_instruments/sources/RFSourceBridgePanelV7.tsx",
    "src/rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "source_modes": [
    "synthetic",
    "file_iq",
    "websocket_iq",
    "sdr_bridge",
    "open5gs_events"
  ],
  "auto_connect_live_sources": false,
  "preserves_v6_turbo_safe": true,
  "rollback": "${QUALITY_DIR}/rollback_v7_source_bridge.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_source_bridge_v7_prep

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV7SourceBridge\\|RFInstrumentSuiteV6TurboSafe\\|RFInstrumentSuiteV5" src/app/main.tsx || true

echo
echo "=== FILES ==="
ls -lh \
  src/rf_instruments/sources/RFSourceTypes.ts \
  src/rf_instruments/sources/RFSourceAdapter.ts \
  src/rf_instruments/sources/SyntheticRFSourceAdapter.ts \
  src/rf_instruments/sources/WebSocketIQSourceAdapter.ts \
  src/rf_instruments/sources/RFSourceBridgePanelV7.tsx \
  src/rf_instruments/instruments/RFInstrumentSuiteV7SourceBridge.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_source_bridge_v7_prep/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V7 SOURCE BRIDGE PREP CREATO. ORA RIAVVIA VITE."
echo "============================================================"
