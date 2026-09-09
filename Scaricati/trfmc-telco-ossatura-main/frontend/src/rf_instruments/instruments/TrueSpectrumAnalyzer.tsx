import React, { useEffect, useMemo, useRef } from "react";

import { InstrumentShell } from "../core/InstrumentShell";
import { RFSurfaceEngine } from "../renderers/RFSurfaceEngine";

function generateTrace(t: number, bins = 1024): Float32Array {
  const out = new Float32Array(bins);

  for (let i = 0; i < bins; i++) {
    const f = i / (bins - 1);

    let v =
      0.08 +
      0.02 * Math.sin(i * 0.04 + t * 0.0012) +
      0.015 * Math.sin(i * 0.017);

    const peaks = [
      { p: 0.12, a: 0.18, w: 0.018 },
      { p: 0.21, a: 0.26, w: 0.012 },
      { p: 0.34, a: 0.42, w: 0.010 },
      { p: 0.50, a: 0.30, w: 0.016 },
      { p: 0.63, a: 0.48, w: 0.008 },
      { p: 0.74, a: 0.36, w: 0.014 },
      { p: 0.86, a: 0.25, w: 0.020 }
    ];

    peaks.forEach(({ p, a, w }) => {
      v += a * Math.exp(-Math.pow((f - p) / w, 2));
    });

    const noise =
      Math.sin(i * 0.9 + t * 0.0002) * 0.003 +
      Math.cos(i * 0.2) * 0.002;

    v += noise;

    out[i] = Math.max(0, Math.min(1, v));
  }

  return out;
}

export function TrueSpectrumAnalyzer() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  const maxHoldRef = useRef<Float32Array | null>(null);

  const engineRef = useRef(new RFSurfaceEngine());

  const left = useMemo(
    () => (
      <div>
        <h2 style={{ color: "#00e5ff" }}>RF INPUT</h2>

        <div style={{ lineHeight: 1.8 }}>
          <p>Mode ............. REALTIME FFT</p>
          <p>Detector ......... RMS</p>
          <p>Trace A .......... CLEAR/WRITE</p>
          <p>Trace B .......... MAX HOLD</p>
          <p>Trace C .......... AVERAGE</p>
          <p>RBW .............. 10 kHz</p>
          <p>VBW .............. 30 kHz</p>
          <p>Reference ........ -10 dBm</p>
          <p>Attenuator ....... 10 dB</p>
          <p>Preamp ........... OFF</p>
          <p>FFT Size ......... 4096</p>
          <p>Sample Rate ...... 122.88 MS/s</p>
        </div>
      </div>
    ),
    []
  );

  const right = useMemo(
    () => (
      <div>
        <h2 style={{ color: "#78ff63" }}>MEASUREMENTS</h2>

        <div style={{ lineHeight: 1.8 }}>
          <p>SNR .............. 31.2 dB</p>
          <p>EVM RMS .......... 2.1 %</p>
          <p>MER .............. 34.7 dB</p>
          <p>OBW .............. 12.6 MHz</p>
          <p>ACLR LOW ......... -52.1 dBc</p>
          <p>ACLR HIGH ........ -51.7 dBc</p>
          <p>Channel Power .... -18.3 dBm</p>
          <p>Noise Floor ...... -96.4 dBm</p>
          <p>Crest Factor ..... 9.7 dB</p>
          <p>Signal Type ...... OFDM / FHSS</p>
          <p>Classification ... VALIDATED</p>
        </div>
      </div>
    ),
    []
  );

  useEffect(() => {
    let raf = 0;

    const loop = (t: number) => {
      const canvas = canvasRef.current;

      if (!canvas) return;

      const bins = generateTrace(t);

      if (
        !maxHoldRef.current ||
        maxHoldRef.current.length !== bins.length
      ) {
        maxHoldRef.current = bins.slice();
      } else {
        for (let i = 0; i < bins.length; i++) {
          maxHoldRef.current[i] = Math.max(
            maxHoldRef.current[i] * 0.997,
            bins[i]
          );
        }
      }

      const avg = new Float32Array(bins.length);

      for (let i = 0; i < bins.length; i++) {
        avg[i] = bins[i] * 0.82;
      }

      engineRef.current.draw(
        canvas,
        {
          primary: bins,
          maxHold: maxHoldRef.current,
          average: avg
        },
        [
          { index: 140, label: "M1" },
          { index: 344, label: "LTE" },
          { index: 512, label: "NR5G" },
          { index: 770, label: "FHSS" }
        ]
      );

      raf = requestAnimationFrame(loop);
    };

    raf = requestAnimationFrame(loop);

    return () => cancelAnimationFrame(raf);
  }, []);

  return (
    <InstrumentShell
      title="TRFMC TRUE SPECTRUM ANALYZER"
      subtitle="Instrument-grade RF spectrum surface · Persistence · Max Hold · Telemetry HUD · Marker Engine"
      left={left}
      center={
        <canvas
          ref={canvasRef}
          style={{
            width: "100%",
            height: "760px",
            display: "block",
            borderRadius: "18px"
          }}
        />
      }
      right={right}
    />
  );
}
