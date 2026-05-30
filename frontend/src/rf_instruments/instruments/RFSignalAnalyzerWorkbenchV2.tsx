import React, { useEffect, useMemo, useRef } from "react";

import { InstrumentShell } from "../core/InstrumentShell";
import { RFSurfaceEngine } from "../renderers/RFSurfaceEngine";
import { RFWaterfallRenderer } from "../renderers/RFWaterfallRenderer";
import { IQConstellationRenderer, IQPoint } from "../renderers/IQConstellationRenderer";

function generateTrace(t: number, bins = 1024): Float32Array {
  const out = new Float32Array(bins);

  for (let i = 0; i < bins; i++) {
    const f = i / (bins - 1);

    let v =
      0.065 +
      0.020 * Math.sin(i * 0.030 + t * 0.0012) +
      0.012 * Math.sin(i * 0.090 + t * 0.0007);

    const hopping = [
      0.12 + 0.01 * Math.sin(t * 0.0008),
      0.25,
      0.37 + 0.02 * Math.sin(t * 0.0005),
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

    const maskLeft = f > 0.15 && f < 0.26 ? 0.030 : 0;
    const maskRight = f > 0.73 && f < 0.88 ? 0.026 : 0;

    v += maskLeft + maskRight;
    out[i] = Math.max(0, Math.min(1, v));
  }

  return out;
}

function generateIQ(t: number, count = 280): IQPoint[] {
  const centers = [
    [-0.65, -0.65],
    [-0.65, 0.65],
    [0.65, -0.65],
    [0.65, 0.65]
  ];

  const pts: IQPoint[] = [];

  for (let i = 0; i < count; i++) {
    const c = centers[i % centers.length];
    const jitter = 0.040 + 0.020 * Math.sin(t * 0.001 + i);
    const err = Math.abs(Math.sin(t * 0.0009 + i * 0.31)) * 0.14;

    pts.push({
      i: c[0] + Math.sin(i * 12.989 + t * 0.001) * jitter,
      q: c[1] + Math.cos(i * 7.123 + t * 0.0011) * jitter,
      err
    });
  }

  return pts;
}

export function RFSignalAnalyzerWorkbenchV2() {
  const spectrumCanvas = useRef<HTMLCanvasElement | null>(null);
  const waterfallCanvas = useRef<HTMLCanvasElement | null>(null);
  const iqCanvas = useRef<HTMLCanvasElement | null>(null);

  const surface = useRef(new RFSurfaceEngine());
  const waterfall = useRef(new RFWaterfallRenderer());
  const iq = useRef(new IQConstellationRenderer());

  const maxHoldRef = useRef<Float32Array | null>(null);
  const avgRef = useRef<Float32Array | null>(null);

  const left = useMemo(() => (
    <div>
      <h2 style={{ color: "#00e5ff" }}>RF/VSA CONTROL</h2>
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
  ), []);

  const right = useMemo(() => (
    <div>
      <h2 style={{ color: "#7dffb2" }}>MEASUREMENT STACK</h2>
      <p>SNR ............... 32.8 dB</p>
      <p>EVM RMS ........... 2.0 %</p>
      <p>MER ............... 35.1 dB</p>
      <p>OBW ............... 13.4 MHz</p>
      <p>ACLR LOW .......... -53.6 dBc</p>
      <p>ACLR HIGH ......... -52.9 dBc</p>
      <p>Channel Power ..... -17.8 dBm</p>
      <p>Noise Floor ....... -97.2 dBm</p>
      <p>Crest Factor ...... 9.4 dB</p>
      <p>Classifier ........ OFDM/FHSS</p>
      <p>Evidence .......... Lab-only synthetic</p>
    </div>
  ), []);

  useEffect(() => {
    let raf = 0;
    let frame = 0;

    const loop = (t: number) => {
      const spec = spectrumCanvas.current;
      const wf = waterfallCanvas.current;
      const iqc = iqCanvas.current;

      if (!spec || !wf || !iqc) return;

      const bins = generateTrace(t);

      if (!maxHoldRef.current || maxHoldRef.current.length !== bins.length) {
        maxHoldRef.current = bins.slice();
        avgRef.current = bins.slice();
      } else {
        for (let i = 0; i < bins.length; i++) {
          maxHoldRef.current[i] = Math.max(maxHoldRef.current[i] * 0.998, bins[i]);
          avgRef.current![i] = avgRef.current![i] * 0.94 + bins[i] * 0.06;
        }
      }

      surface.current.draw(
        spec,
        {
          primary: bins,
          maxHold: maxHoldRef.current,
          average: avgRef.current ?? undefined
        },
        [
          { index: 128, label: "M1" },
          { index: 260, label: "FH1" },
          { index: 512, label: "NR5G" },
          { index: 645, label: "M4" },
          { index: 800, label: "FHSS" }
        ]
      );

      if (frame % 2 === 0) {
        waterfall.current.push(bins);
      }

      waterfall.current.draw(wf);
      iq.current.draw(iqc, generateIQ(t));

      frame++;
      raf = requestAnimationFrame(loop);
    };

    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);

  return (
    <InstrumentShell
      title="TRFMC RF Surface Engine V2"
      subtitle="Spectrum · Waterfall · I/Q constellation · marker engine · RF measurement evidence"
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
