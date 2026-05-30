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
