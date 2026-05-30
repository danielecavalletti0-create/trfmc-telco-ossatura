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
