#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC RF SURFACE ENGINE V3 - DSP WORKER PIPELINE"
echo "============================================================"

mkdir -p ../runtime/freezes ../runtime/quality/TRFMC_RF_SURFACE_ENGINE_V3_DSP_WORKER_${TS}

echo
echo "=== BACKUP STATO V2 ==="
tar -czf "../runtime/freezes/TRFMC_BEFORE_RF_SURFACE_ENGINE_V3_DSP_WORKER_${TS}.tar.gz" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_surface_v3_worker_${TS}"

echo
echo "=== CREO DSP WORKER V3 ==="
mkdir -p src/rf_instruments/dsp/workers

cat > src/rf_instruments/dsp/workers/RFSignalDspWorkerV3.ts <<'TS'
type StartMessage = {
  type: "start";
  bins?: number;
  intervalMs?: number;
};

type StopMessage = {
  type: "stop";
};

type WorkerInput = StartMessage | StopMessage;

type IQPoint = {
  i: number;
  q: number;
  err: number;
};

let timer: number | undefined;
let bins = 1024;
let frame = 0;
let maxHold: Float32Array | null = null;
let average: Float32Array | null = null;

function clamp01(v: number) {
  return Math.max(0, Math.min(1, v));
}

function generateTrace(t: number, n: number): Float32Array {
  const out = new Float32Array(n);

  for (let i = 0; i < n; i++) {
    const f = i / (n - 1);

    let v =
      0.060 +
      0.020 * Math.sin(i * 0.030 + t * 0.0010) +
      0.012 * Math.sin(i * 0.090 + t * 0.0008) +
      0.006 * Math.cos(i * 0.017 + frame * 0.03);

    const hopping = [
      0.12 + 0.012 * Math.sin(t * 0.0008),
      0.25,
      0.37 + 0.020 * Math.sin(t * 0.0005),
      0.50,
      0.63,
      0.78 + 0.015 * Math.cos(t * 0.0006),
      0.87
    ];

    hopping.forEach((p, k) => {
      const amp = 0.20 + (k % 3) * 0.09;
      const width = 0.008 + (k % 2) * 0.006;
      v += amp * Math.exp(-Math.pow((f - p) / width, 2));
    });

    const adjacentMaskEnergy =
      f > 0.15 && f < 0.26 ? 0.028 :
      f > 0.73 && f < 0.88 ? 0.024 :
      0;

    out[i] = clamp01(v + adjacentMaskEnergy);
  }

  return out;
}

function generateIQ(t: number, count = 320): IQPoint[] {
  const centers = [
    [-0.65, -0.65],
    [-0.65, 0.65],
    [0.65, -0.65],
    [0.65, 0.65]
  ];

  const pts: IQPoint[] = [];

  for (let i = 0; i < count; i++) {
    const c = centers[i % centers.length];
    const jitter = 0.040 + 0.018 * Math.sin(t * 0.001 + i * 0.73);
    const err = Math.abs(Math.sin(t * 0.0009 + i * 0.31)) * 0.14;

    pts.push({
      i: c[0] + Math.sin(i * 12.989 + t * 0.0010) * jitter,
      q: c[1] + Math.cos(i * 7.123 + t * 0.0011) * jitter,
      err
    });
  }

  return pts;
}

function computeMetrics(trace: Float32Array) {
  let peak = 0;
  let sum = 0;
  let floorSum = 0;
  let floorCount = 0;

  for (let i = 0; i < trace.length; i++) {
    const v = trace[i];
    peak = Math.max(peak, v);
    sum += v;

    if (v < 0.16) {
      floorSum += v;
      floorCount++;
    }
  }

  const mean = sum / trace.length;
  const floor = floorCount ? floorSum / floorCount : 0.08;
  const snr = 20 + (peak - floor) * 38;
  const evm = Math.max(1.4, 4.5 - (snr - 25) * 0.07);
  const obw = 11.0 + Math.sin(frame * 0.02) * 0.7 + peak * 3.0;
  const aclr = -48 - (snr - 25) * 0.35;

  return {
    snr: Number(snr.toFixed(1)),
    evm: Number(evm.toFixed(2)),
    mer: Number((snr + 2.3).toFixed(1)),
    obw: Number(obw.toFixed(2)),
    aclrLow: Number(aclr.toFixed(1)),
    aclrHigh: Number((aclr - 0.5).toFixed(1)),
    channelPower: Number((-18.5 + mean * 4).toFixed(1)),
    noiseFloor: Number((-98 + floor * 14).toFixed(1)),
    crestFactor: Number((8.5 + peak * 2.4).toFixed(1)),
    classifier: "OFDM/FHSS",
    evidence: "DSP worker synthetic lab"
  };
}

function tick() {
  const t = performance.now();
  const primary = generateTrace(t, bins);

  if (!maxHold || maxHold.length !== bins) {
    maxHold = primary.slice();
    average = primary.slice();
  } else {
    for (let i = 0; i < bins; i++) {
      maxHold[i] = Math.max(maxHold[i] * 0.998, primary[i]);
      average![i] = average![i] * 0.94 + primary[i] * 0.06;
    }
  }

  const iq = generateIQ(t);
  const metrics = computeMetrics(primary);

  postMessage({
    type: "rf-frame",
    frame,
    primary,
    maxHold: maxHold.slice(),
    average: average!.slice(),
    iq,
    metrics,
    markers: [
      { index: 128, label: "M1" },
      { index: 260, label: "FH1" },
      { index: 512, label: "NR5G" },
      { index: 645, label: "M4" },
      { index: 800, label: "FHSS" }
    ]
  });

  frame++;
}

self.onmessage = (ev: MessageEvent<WorkerInput>) => {
  const msg = ev.data;

  if (msg.type === "start") {
    bins = msg.bins ?? 1024;
    const intervalMs = msg.intervalMs ?? 33;

    if (timer !== undefined) clearInterval(timer);
    timer = setInterval(tick, intervalMs) as unknown as number;
  }

  if (msg.type === "stop") {
    if (timer !== undefined) clearInterval(timer);
    timer = undefined;
  }
};

export {};
TS

echo
echo "=== CREO WORKBENCH V3 ==="
cat > src/rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3.tsx <<'TSX'
import React, { useEffect, useMemo, useRef, useState } from "react";

import { InstrumentShell } from "../core/InstrumentShell";
import { RFSurfaceEngine } from "../renderers/RFSurfaceEngine";
import { RFWaterfallRenderer } from "../renderers/RFWaterfallRenderer";
import { IQConstellationRenderer, IQPoint } from "../renderers/IQConstellationRenderer";

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

export function RFSignalAnalyzerWorkbenchV3() {
  const spectrumCanvas = useRef<HTMLCanvasElement | null>(null);
  const waterfallCanvas = useRef<HTMLCanvasElement | null>(null);
  const iqCanvas = useRef<HTMLCanvasElement | null>(null);

  const surface = useRef(new RFSurfaceEngine());
  const waterfall = useRef(new RFWaterfallRenderer());
  const iq = useRef(new IQConstellationRenderer());

  const lastFrame = useRef<RFFrame | null>(null);
  const rafRef = useRef<number | null>(null);

  const [metrics, setMetrics] = useState<Metrics>(initialMetrics);
  const [workerState, setWorkerState] = useState("BOOT");

  const left = useMemo(() => (
    <div>
      <h2 style={{ color: "#00e5ff" }}>DSP WORKER CONTROL</h2>
      <p>Pipeline .......... Worker → React → Canvas</p>
      <p>Worker ............ {workerState}</p>
      <p>Acquisition ....... Synthetic IQ Lab</p>
      <p>Detector .......... RMS / Peak</p>
      <p>FFT Size .......... 4096</p>
      <p>Window ............ Blackman-Harris</p>
      <p>RBW ............... 10 kHz</p>
      <p>VBW ............... 30 kHz</p>
      <p>Span .............. 80 MHz</p>
      <p>Center ............ 2.440 GHz</p>
      <p>Trigger ........... Burst/FHSS</p>
      <p>Trace A ........... Live</p>
      <p>Trace B ........... Max Hold</p>
      <p>Trace C ........... Average</p>
    </div>
  ), [workerState]);

  const right = useMemo(() => (
    <div>
      <h2 style={{ color: "#7dffb2" }}>MEASUREMENT STACK</h2>
      <p>SNR ............... {metrics.snr} dB</p>
      <p>EVM RMS ........... {metrics.evm} %</p>
      <p>MER ............... {metrics.mer} dB</p>
      <p>OBW ............... {metrics.obw} MHz</p>
      <p>ACLR LOW .......... {metrics.aclrLow} dBc</p>
      <p>ACLR HIGH ......... {metrics.aclrHigh} dBc</p>
      <p>Channel Power ..... {metrics.channelPower} dBm</p>
      <p>Noise Floor ....... {metrics.noiseFloor} dBm</p>
      <p>Crest Factor ...... {metrics.crestFactor} dB</p>
      <p>Classifier ........ {metrics.classifier}</p>
      <p>Evidence .......... {metrics.evidence}</p>
    </div>
  ), [metrics]);

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
      }
    };

    worker.onerror = () => {
      setWorkerState("ERROR");
    };

    worker.postMessage({
      type: "start",
      bins: 1024,
      intervalMs: 33
    });

    const drawLoop = () => {
      const frame = lastFrame.current;
      const spec = spectrumCanvas.current;
      const wf = waterfallCanvas.current;
      const iqc = iqCanvas.current;

      if (frame && spec && wf && iqc) {
        surface.current.draw(
          spec,
          {
            primary: frame.primary,
            maxHold: frame.maxHold,
            average: frame.average
          },
          frame.markers
        );

        waterfall.current.push(frame.primary);
        waterfall.current.draw(wf);

        iq.current.draw(iqc, frame.iq);
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

  return (
    <InstrumentShell
      title="TRFMC RF Surface Engine V3"
      subtitle="DSP Worker · Spectrum · Waterfall · I/Q constellation · measurement stack · marker evidence"
      left={left}
      center={
        <div style={{ display: "grid", gap: "10px" }}>
          <canvas
            ref={spectrumCanvas}
            style={{ width: "100%", height: "420px", display: "block", borderRadius: "18px" }}
          />
          <div style={{ display: "grid", gridTemplateColumns: "1.35fr .65fr", gap: "10px" }}>
            <canvas
              ref={waterfallCanvas}
              style={{ width: "100%", height: "260px", display: "block", borderRadius: "18px" }}
            />
            <canvas
              ref={iqCanvas}
              style={{ width: "100%", height: "260px", display: "block", borderRadius: "18px" }}
            />
          </div>
        </div>
      }
      right={right}
    />
  );
}
TSX

echo
echo "=== PATCH main.tsx: V2 -> V3 ==="
python3 - <<'PY'
from pathlib import Path

p = Path("src/app/main.tsx")
s = p.read_text()

v2_imp = "import { RFSignalAnalyzerWorkbenchV2 } from '../rf_instruments/instruments/RFSignalAnalyzerWorkbenchV2'\n"
v3_imp = "import { RFSignalAnalyzerWorkbenchV3 } from '../rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3'\n"

if v2_imp in s:
    s = s.replace(v2_imp, v3_imp, 1)
elif v3_imp not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
      if line.lstrip().startswith("import "):
        insert_at = i + 1
    lines.insert(insert_at, v3_imp)
    s = "".join(lines)

s = s.replace("<RFSignalAnalyzerWorkbenchV2 />", "<RFSignalAnalyzerWorkbenchV3 />")

p.write_text(s)
print("OK: main.tsx patched to V3")
PY

cat > "../runtime/quality/TRFMC_RF_SURFACE_ENGINE_V3_DSP_WORKER_${TS}/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_SURFACE_ENGINE_V3_DSP_WORKER",
  "created": [
    "src/rf_instruments/dsp/workers/RFSignalDspWorkerV3.ts",
    "src/rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3.tsx"
  ],
  "patched": [
    "src/app/main.tsx"
  ],
  "worker_pattern": "new Worker(new URL(..., import.meta.url), { type: module })",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/../runtime/quality/TRFMC_RF_SURFACE_ENGINE_V3_DSP_WORKER_${TS}" ../runtime/quality/latest_rf_surface_engine_v3_dsp_worker

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFSignalAnalyzerWorkbenchV3\\|RFSignalAnalyzerWorkbenchV2\\|RFSignalDspWorkerV3" src/app/main.tsx src/rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3.tsx || true

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_surface_engine_v3_dsp_worker/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V3 DSP WORKER CREATO. RIAVVIA VITE E TESTA."
echo "============================================================"
