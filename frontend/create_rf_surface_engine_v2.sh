#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC RF SURFACE ENGINE V2 - WATERFALL + IQ + MARKERS"
echo "============================================================"

echo
echo "=== BACKUP STATO BUONO ==="
mkdir -p ../runtime/freezes ../runtime/quality/TRFMC_RF_SURFACE_ENGINE_V2_${TS}
tar -czf "../runtime/freezes/TRFMC_BEFORE_RF_SURFACE_ENGINE_V2_${TS}.tar.gz" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_surface_v2_${TS}"

echo
echo "=== CREO RF WATERFALL RENDERER ==="
cat > src/rf_instruments/renderers/RFWaterfallRenderer.ts <<'TS'
export class RFWaterfallRenderer {
  private rows: Float32Array[] = [];
  private maxRows = 180;

  push(trace: Float32Array) {
    this.rows.unshift(trace.slice());
    if (this.rows.length > this.maxRows) this.rows.pop();
  }

  draw(canvas: HTMLCanvasElement) {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.floor(canvas.clientWidth * dpr);
    const h = Math.floor(canvas.clientHeight * dpr);

    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.fillStyle = "#00050a";
    ctx.fillRect(0, 0, w, h);

    const rowH = Math.max(1, h / this.maxRows);

    for (let y = 0; y < this.rows.length; y++) {
      const row = this.rows[y];
      const alpha = 1 - y / this.maxRows;

      for (let x = 0; x < w; x++) {
        const idx = Math.floor((x / w) * (row.length - 1));
        const v = Math.max(0, Math.min(1, row[idx]));
        const c = this.color(v, alpha);
        ctx.fillStyle = c;
        ctx.fillRect(x, y * rowH, 1, Math.ceil(rowH));
      }
    }

    ctx.strokeStyle = "rgba(0,229,255,.22)";
    ctx.strokeRect(0, 0, w, h);

    ctx.fillStyle = "#00e5ff";
    ctx.font = `${10 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("DENSE PERSISTENT WATERFALL · spectral memory · burst occupancy", 12 * dpr, 18 * dpr);
  }

  private color(v: number, alpha: number) {
    const a = 0.10 + alpha * 0.80;

    if (v > 0.70) return `rgba(255,216,77,${a})`;
    if (v > 0.46) return `rgba(0,229,255,${a})`;
    if (v > 0.25) return `rgba(0,120,180,${a * 0.75})`;
    return `rgba(0,36,64,${a * 0.45})`;
  }
}
TS

echo
echo "=== CREO IQ CONSTELLATION RENDERER ==="
cat > src/rf_instruments/renderers/IQConstellationRenderer.ts <<'TS'
export type IQPoint = {
  i: number;
  q: number;
  err?: number;
};

export class IQConstellationRenderer {
  draw(canvas: HTMLCanvasElement, points: IQPoint[]) {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.floor(canvas.clientWidth * dpr);
    const h = Math.floor(canvas.clientHeight * dpr);

    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.fillStyle = "#00050a";
    ctx.fillRect(0, 0, w, h);

    ctx.strokeStyle = "rgba(0,229,255,.12)";
    ctx.lineWidth = 1;

    for (let i = 0; i <= 8; i++) {
      const x = (w * i) / 8;
      const y = (h * i) / 8;

      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(0,229,255,.40)";
    ctx.beginPath();
    ctx.moveTo(w / 2, 0);
    ctx.lineTo(w / 2, h);
    ctx.moveTo(0, h / 2);
    ctx.lineTo(w, h / 2);
    ctx.stroke();

    for (const p of points) {
      const x = w / 2 + p.i * w * 0.34;
      const y = h / 2 - p.q * h * 0.34;
      const e = p.err ?? 0;

      ctx.fillStyle = e > 0.12 ? "#ff5f7a" : "#00e5ff";
      ctx.shadowColor = e > 0.12 ? "#ff5f7a" : "#00e5ff";
      ctx.shadowBlur = 12;
      ctx.beginPath();
      ctx.arc(x, y, 3 * dpr, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;

      if (e > 0.08) {
        ctx.strokeStyle = "rgba(255,95,122,.42)";
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(w / 2 + Math.sign(p.i) * w * 0.24, h / 2 - Math.sign(p.q) * h * 0.24);
        ctx.stroke();
      }
    }

    ctx.fillStyle = "#00e5ff";
    ctx.font = `${10 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("I/Q CONSTELLATION · EVM vectors · QPSK/OFDM evidence", 12 * dpr, 18 * dpr);
  }
}
TS

echo
echo "=== CREO RF SIGNAL ANALYZER WORKBENCH V2 ==="
cat > src/rf_instruments/instruments/RFSignalAnalyzerWorkbenchV2.tsx <<'TSX'
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
TSX

echo
echo "=== PATCH main.tsx: V1 -> V2 ==="
python3 - <<'PY'
from pathlib import Path

p = Path("src/app/main.tsx")
s = p.read_text()

old_imp = "import { TrueSpectrumAnalyzer } from '../rf_instruments/instruments/TrueSpectrumAnalyzer'\n"
new_imp = "import { RFSignalAnalyzerWorkbenchV2 } from '../rf_instruments/instruments/RFSignalAnalyzerWorkbenchV2'\n"

if old_imp in s:
    s = s.replace(old_imp, new_imp, 1)
elif new_imp not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, new_imp)
    s = "".join(lines)

s = s.replace("<TrueSpectrumAnalyzer />", "<RFSignalAnalyzerWorkbenchV2 />")

p.write_text(s)
print("OK: main.tsx patched")
PY

echo
echo "=== QUALITY SUMMARY ==="
cat > "../runtime/quality/TRFMC_RF_SURFACE_ENGINE_V2_${TS}/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_SURFACE_ENGINE_V2",
  "created": [
    "src/rf_instruments/renderers/RFWaterfallRenderer.ts",
    "src/rf_instruments/renderers/IQConstellationRenderer.ts",
    "src/rf_instruments/instruments/RFSignalAnalyzerWorkbenchV2.tsx"
  ],
  "patched": [
    "src/app/main.tsx"
  ],
  "protected_static_enterprise_prime": true,
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/../runtime/quality/TRFMC_RF_SURFACE_ENGINE_V2_${TS}" ../runtime/quality/latest_rf_surface_engine_v2

echo
echo "=== VERIFICA FILE ==="
find src/rf_instruments -maxdepth 3 -type f | sort

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFSignalAnalyzerWorkbenchV2\\|TrueSpectrumAnalyzer" src/app/main.tsx || true

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_surface_engine_v2/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "RF SURFACE ENGINE V2 CREATO. ORA RIAVVIA VITE."
echo "============================================================"
