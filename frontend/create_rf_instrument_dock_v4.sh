#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC RF INSTRUMENT DOCK V4"
echo "Docked RF workstation · Spectrum · Waterfall · IQ · Markers"
echo "============================================================"

mkdir -p ../runtime/freezes ../runtime/quality/TRFMC_RF_INSTRUMENT_DOCK_V4_${TS}

echo
echo "=== BACKUP STATO V3 ==="
tar -czf "../runtime/freezes/TRFMC_BEFORE_RF_INSTRUMENT_DOCK_V4_${TS}.tar.gz" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_instrument_dock_v4_${TS}"
cp src/styles.css "src/styles.css.bak_rf_instrument_dock_v4_${TS}" 2>/dev/null || true

echo
echo "=== APPENDO CSS DOCK V4 ==="

if ! grep -q "TRFMC_RF_INSTRUMENT_DOCK_V4_STYLE" src/styles.css 2>/dev/null; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_INSTRUMENT_DOCK_V4_STYLE */
.rf-dock-v4{
  border:1px solid rgba(57,215,255,.28);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 80% 0%,rgba(0,229,255,.16),transparent 35%),
    linear-gradient(145deg,rgba(8,22,38,.96),rgba(1,6,12,.98));
  box-shadow:
    0 28px 90px rgba(0,0,0,.62),
    inset 0 0 45px rgba(57,215,255,.045);
}

.rf-dock-v4-top{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  padding:12px 14px;
  border-bottom:1px solid rgba(57,215,255,.22);
  background:linear-gradient(180deg,rgba(11,31,52,.96),rgba(4,11,20,.98));
}

.rf-dock-v4-title{
  color:#eafbff;
  font-size:18px;
  text-transform:uppercase;
  letter-spacing:.12em;
  text-shadow:0 0 18px rgba(57,215,255,.45);
  font-weight:900;
}

.rf-dock-v4-sub{
  color:#88a9c4;
  font-size:11px;
  margin-top:4px;
}

.rf-dock-v4-state{
  display:flex;
  gap:8px;
  flex-wrap:wrap;
  justify-content:flex-end;
}

.rf-dock-v4-pill{
  border:1px solid rgba(125,255,178,.26);
  background:rgba(125,255,178,.06);
  color:#7dffb2;
  border-radius:999px;
  padding:5px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-dock-v4-tabs{
  display:flex;
  gap:7px;
  flex-wrap:wrap;
  padding:10px;
  border-bottom:1px solid rgba(57,215,255,.16);
  background:rgba(0,4,9,.50);
}

.rf-dock-v4-tab{
  border-radius:11px;
  padding:8px 11px;
  font-size:11px;
  letter-spacing:.08em;
  text-transform:uppercase;
}

.rf-dock-v4-tab.active{
  color:#021018;
  background:linear-gradient(180deg,#7df1ff,#34c9f2);
  border-color:#c7fbff;
  box-shadow:0 0 20px rgba(57,215,255,.38);
}

.rf-dock-v4-body{
  padding:10px;
}

.rf-dock-v4-grid{
  display:grid;
  grid-template-columns:1.35fr .65fr;
  gap:10px;
}

.rf-dock-v4-card{
  border:1px solid rgba(57,215,255,.20);
  border-radius:18px;
  padding:10px;
  background:
    linear-gradient(145deg,rgba(6,17,30,.92),rgba(1,5,11,.98)),
    radial-gradient(circle at 85% 0%,rgba(57,215,255,.07),transparent 35%);
  box-shadow:inset 0 0 26px rgba(57,215,255,.035);
}

.rf-dock-v4-card h3{
  margin:0 0 8px;
  color:#39d7ff;
  font-size:12px;
  text-transform:uppercase;
  letter-spacing:.10em;
}

.rf-dock-v4-canvas{
  display:block;
  width:100%;
  border-radius:16px;
  background:#00050a;
  border:1px solid rgba(57,215,255,.18);
}

.rf-dock-v4-table{
  width:100%;
  border-collapse:collapse;
  font-family:ui-monospace,Consolas,monospace;
  font-size:12px;
}

.rf-dock-v4-table th,
.rf-dock-v4-table td{
  border-bottom:1px solid rgba(57,215,255,.14);
  padding:7px 8px;
  text-align:left;
}

.rf-dock-v4-table th{
  color:#39d7ff;
  background:rgba(57,215,255,.055);
  text-transform:uppercase;
  letter-spacing:.08em;
  font-size:10px;
}

.rf-dock-v4-table td{
  color:#dff3ff;
}

.rf-dock-v4-formula{
  margin-top:10px;
  border:1px solid rgba(255,209,102,.20);
  border-radius:14px;
  background:rgba(255,209,102,.045);
  color:#ffd166;
  padding:10px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:11px;
  line-height:1.55;
}

@media(max-width:1300px){
  .rf-dock-v4-grid{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO COMPONENTE DOCK V4 ==="

cat > src/rf_instruments/instruments/RFInstrumentDockV4.tsx <<'TSX'
import React, { useEffect, useRef, useState } from "react";

import { RFSurfaceEngine } from "../renderers/RFSurfaceEngine";
import { RFWaterfallRenderer } from "../renderers/RFWaterfallRenderer";
import { IQConstellationRenderer, IQPoint } from "../renderers/IQConstellationRenderer";

type DockTab = "overview" | "spectrum" | "waterfall" | "iq" | "markers" | "measurements";

type Marker = {
  index: number;
  label: string;
};

type Metrics = {
  snr: number;
  evm: number;
  mer: number;
  obw: number;
  aclrLow: number;
  aclrHigh: number;
  channelPower: number;
  noiseFloor: number;
  crestFactor: number;
  classifier: string;
  evidence: string;
};

type RFFrame = {
  type: "rf-frame";
  frame: number;
  primary: Float32Array;
  maxHold: Float32Array;
  average: Float32Array;
  iq: IQPoint[];
  markers: Marker[];
  metrics: Metrics;
};

const initialMetrics: Metrics = {
  snr: 0,
  evm: 0,
  mer: 0,
  obw: 0,
  aclrLow: 0,
  aclrHigh: 0,
  channelPower: 0,
  noiseFloor: 0,
  crestFactor: 0,
  classifier: "BOOT",
  evidence: "waiting worker"
};

const tabs: { id: DockTab; label: string }[] = [
  { id: "overview", label: "Overview" },
  { id: "spectrum", label: "Spectrum" },
  { id: "waterfall", label: "Waterfall" },
  { id: "iq", label: "I/Q" },
  { id: "markers", label: "Markers" },
  { id: "measurements", label: "Measurements" }
];

function mhzFromIndex(index: number) {
  const spanMhz = 80;
  const centerMhz = 2440;
  const f = centerMhz - spanMhz / 2 + (index / 1023) * spanMhz;
  return f.toFixed(3);
}

export function RFInstrumentDockV4() {
  const [active, setActive] = useState<DockTab>("overview");
  const [workerState, setWorkerState] = useState("BOOT");
  const [metrics, setMetrics] = useState<Metrics>(initialMetrics);
  const [markers, setMarkers] = useState<Marker[]>([]);
  const [frameNo, setFrameNo] = useState(0);

  const spectrumCanvas = useRef<HTMLCanvasElement | null>(null);
  const waterfallCanvas = useRef<HTMLCanvasElement | null>(null);
  const iqCanvas = useRef<HTMLCanvasElement | null>(null);

  const surface = useRef(new RFSurfaceEngine());
  const waterfall = useRef(new RFWaterfallRenderer());
  const iq = useRef(new IQConstellationRenderer());

  const lastFrame = useRef<RFFrame | null>(null);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    const worker = new Worker(
      new URL("../dsp/workers/RFSignalDspWorkerV3.ts", import.meta.url),
      { type: "module" }
    );

    setWorkerState("ONLINE");

    worker.onmessage = (ev: MessageEvent<RFFrame>) => {
      if (ev.data?.type !== "rf-frame") return;

      lastFrame.current = ev.data;

      if (ev.data.frame % 5 === 0) {
        setMetrics(ev.data.metrics);
        setMarkers(ev.data.markers);
        setFrameNo(ev.data.frame);
      }
    };

    worker.onerror = () => setWorkerState("ERROR");

    worker.postMessage({
      type: "start",
      bins: 1024,
      intervalMs: 33
    });

    const drawLoop = () => {
      const frame = lastFrame.current;

      if (frame) {
        const spec = spectrumCanvas.current;
        const wf = waterfallCanvas.current;
        const iqc = iqCanvas.current;

        if (spec) {
          surface.current.draw(
            spec,
            {
              primary: frame.primary,
              maxHold: frame.maxHold,
              average: frame.average
            },
            frame.markers
          );
        }

        if (wf) {
          waterfall.current.push(frame.primary);
          waterfall.current.draw(wf);
        }

        if (iqc) {
          iq.current.draw(iqc, frame.iq);
        }
      }

      rafRef.current = requestAnimationFrame(drawLoop);
    };

    rafRef.current = requestAnimationFrame(drawLoop);

    return () => {
      worker.postMessage({ type: "stop" });
      worker.terminate();

      if (rafRef.current !== null) {
        cancelAnimationFrame(rafRef.current);
      }
    };
  }, []);

  const measurementRows = [
    ["SNR", `${metrics.snr} dB`, "Signal quality"],
    ["EVM RMS", `${metrics.evm} %`, "Vector modulation quality"],
    ["MER", `${metrics.mer} dB`, "Modulation error ratio"],
    ["OBW", `${metrics.obw} MHz`, "Occupied bandwidth"],
    ["ACLR LOW", `${metrics.aclrLow} dBc`, "Adjacent channel leakage"],
    ["ACLR HIGH", `${metrics.aclrHigh} dBc`, "Adjacent channel leakage"],
    ["Channel Power", `${metrics.channelPower} dBm`, "Integrated in-band power"],
    ["Noise Floor", `${metrics.noiseFloor} dBm`, "Estimated noise reference"],
    ["Crest Factor", `${metrics.crestFactor} dB`, "Peak/RMS ratio"],
    ["Classifier", metrics.classifier, "Signal class"],
    ["Evidence", metrics.evidence, "Acquisition source"]
  ];

  return (
    <section className="rf-dock-v4">
      <header className="rf-dock-v4-top">
        <div>
          <div className="rf-dock-v4-title">TRFMC RF Instrument Dock V4</div>
          <div className="rf-dock-v4-sub">
            Docked VSA workstation · DSP Worker · Spectrum · Waterfall · I/Q · Markers · Measurements
          </div>
        </div>

        <div className="rf-dock-v4-state">
          <span className="rf-dock-v4-pill">WORKER {workerState}</span>
          <span className="rf-dock-v4-pill">FRAME {frameNo}</span>
          <span className="rf-dock-v4-pill">CLASS {metrics.classifier}</span>
          <span className="rf-dock-v4-pill">V3 SAFE / V4 DOCK</span>
        </div>
      </header>

      <nav className="rf-dock-v4-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={active === tab.id ? "rf-dock-v4-tab active" : "rf-dock-v4-tab"}
            onClick={() => setActive(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </nav>

      <div className="rf-dock-v4-body">
        {active === "overview" && (
          <div className="rf-dock-v4-grid">
            <div className="rf-dock-v4-card">
              <h3>Spectrum Surface</h3>
              <canvas ref={spectrumCanvas} className="rf-dock-v4-canvas" style={{ height: 420 }} />
            </div>

            <div className="rf-dock-v4-card">
              <h3>Measurement Snapshot</h3>
              <table className="rf-dock-v4-table">
                <tbody>
                  <tr><th>KPI</th><th>Value</th></tr>
                  <tr><td>SNR</td><td>{metrics.snr} dB</td></tr>
                  <tr><td>EVM</td><td>{metrics.evm} %</td></tr>
                  <tr><td>OBW</td><td>{metrics.obw} MHz</td></tr>
                  <tr><td>Classifier</td><td>{metrics.classifier}</td></tr>
                  <tr><td>Worker</td><td>{workerState}</td></tr>
                </tbody>
              </table>

              <div className="rf-dock-v4-formula">
                FFT → Detector → Max Hold → Average → Waterfall → I/Q → Metrics<br />
                EVM = RMS(error vector) / RMS(reference vector)<br />
                ACLR = P<sub>channel</sub> / P<sub>adjacent</sub>
              </div>
            </div>

            <div className="rf-dock-v4-card">
              <h3>Dense Waterfall</h3>
              <canvas ref={waterfallCanvas} className="rf-dock-v4-canvas" style={{ height: 260 }} />
            </div>

            <div className="rf-dock-v4-card">
              <h3>I/Q Constellation</h3>
              <canvas ref={iqCanvas} className="rf-dock-v4-canvas" style={{ height: 260 }} />
            </div>
          </div>
        )}

        {active === "spectrum" && (
          <div className="rf-dock-v4-card">
            <h3>Full Spectrum Surface</h3>
            <canvas ref={spectrumCanvas} className="rf-dock-v4-canvas" style={{ height: 720 }} />
          </div>
        )}

        {active === "waterfall" && (
          <div className="rf-dock-v4-card">
            <h3>Dense Persistent Waterfall</h3>
            <canvas ref={waterfallCanvas} className="rf-dock-v4-canvas" style={{ height: 720 }} />
          </div>
        )}

        {active === "iq" && (
          <div className="rf-dock-v4-card">
            <h3>I/Q Constellation + Error Vectors</h3>
            <canvas ref={iqCanvas} className="rf-dock-v4-canvas" style={{ height: 720 }} />
          </div>
        )}

        {active === "markers" && (
          <div className="rf-dock-v4-card">
            <h3>Marker Table</h3>
            <table className="rf-dock-v4-table">
              <thead>
                <tr>
                  <th>Marker</th>
                  <th>Index</th>
                  <th>Frequency</th>
                  <th>Role</th>
                </tr>
              </thead>
              <tbody>
                {markers.map((m) => (
                  <tr key={`${m.label}-${m.index}`}>
                    <td>{m.label}</td>
                    <td>{m.index}</td>
                    <td>{mhzFromIndex(m.index)} MHz</td>
                    <td>{m.label.includes("FH") || m.label.includes("FHSS") ? "Hopping / burst evidence" : "Carrier / peak marker"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {active === "measurements" && (
          <div className="rf-dock-v4-card">
            <h3>Measurement Table</h3>
            <table className="rf-dock-v4-table">
              <thead>
                <tr>
                  <th>Measurement</th>
                  <th>Value</th>
                  <th>Engineering Meaning</th>
                </tr>
              </thead>
              <tbody>
                {measurementRows.map((r) => (
                  <tr key={r[0]}>
                    <td>{r[0]}</td>
                    <td>{r[1]}</td>
                    <td>{r[2]}</td>
                  </tr>
                ))}
              </tbody>
            </table>

            <div className="rf-dock-v4-formula">
              RBW ≈ Fs / N · ENBW(window)<br />
              Channel Power = ∫ PSD(f) df over assigned channel<br />
              OBW = bandwidth containing the configured occupied-power percentage<br />
              MER ≈ 20log10(RMS(reference) / RMS(error))
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V3 -> V4 ==="

python3 - <<'PY'
from pathlib import Path

p = Path("src/app/main.tsx")
s = p.read_text()

imports = [
    "import { RFSignalAnalyzerWorkbenchV3 } from '../rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3'\n",
    "import { RFInstrumentDockV4 } from '../rf_instruments/instruments/RFInstrumentDockV4'\n"
]

if imports[0] in s:
    s = s.replace(imports[0], imports[1], 1)
elif imports[1] not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, imports[1])
    s = "".join(lines)

s = s.replace("<RFSignalAnalyzerWorkbenchV3 />", "<RFInstrumentDockV4 />")

p.write_text(s)
print("OK: main.tsx patched to V4")
PY

cat > "../runtime/quality/TRFMC_RF_INSTRUMENT_DOCK_V4_${TS}/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_INSTRUMENT_DOCK_V4",
  "created": [
    "src/rf_instruments/instruments/RFInstrumentDockV4.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "uses_existing_worker": "src/rf_instruments/dsp/workers/RFSignalDspWorkerV3.ts",
  "preserves_v3_runtime_freeze": true,
  "dock_tabs": [
    "Overview",
    "Spectrum",
    "Waterfall",
    "I/Q",
    "Markers",
    "Measurements"
  ],
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/../runtime/quality/TRFMC_RF_INSTRUMENT_DOCK_V4_${TS}" ../runtime/quality/latest_rf_instrument_dock_v4

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentDockV4\\|RFSignalAnalyzerWorkbenchV3\\|RFSignalAnalyzerWorkbenchV2\\|TrueSpectrumAnalyzer" src/app/main.tsx || true

echo
echo "=== FILE ==="
ls -lh src/rf_instruments/instruments/RFInstrumentDockV4.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_instrument_dock_v4/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V4 DOCK CREATO. RIAVVIA VITE E TESTA."
echo "============================================================"
