#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC RF INSTRUMENT SUITE V5"
echo "VSA Dock + VNA/Smith + Antenna + Microwave + OFDM Grid"
echo "============================================================"

mkdir -p ../runtime/freezes ../runtime/quality/TRFMC_RF_INSTRUMENT_SUITE_V5_${TS}

echo
echo "=== BACKUP STATO V4 ==="
tar -czf "../runtime/freezes/TRFMC_BEFORE_RF_INSTRUMENT_SUITE_V5_${TS}.tar.gz" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_instrument_suite_v5_${TS}"
cp src/styles.css "src/styles.css.bak_rf_instrument_suite_v5_${TS}" 2>/dev/null || true

echo
echo "=== CREO RENDERER SMITH / VNA ==="

cat > src/rf_instruments/renderers/SmithChartRenderer.ts <<'TS'
export class SmithChartRenderer {
  draw(canvas: HTMLCanvasElement, t = 0) {
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

    const cx = w * 0.48;
    const cy = h * 0.52;
    const r = Math.min(w, h) * 0.38;

    ctx.strokeStyle = "rgba(0,229,255,.16)";
    ctx.lineWidth = 1;

    for (let i = 1; i <= 8; i++) {
      ctx.beginPath();
      ctx.arc(cx + (r * i) / 8, cy, r * (1 - i / 8), 0, Math.PI * 2);
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(cx - (r * i) / 8, cy, r * (1 - i / 8), 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(255,255,255,.60)";
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.stroke();

    ctx.strokeStyle = "rgba(0,229,255,.30)";
    ctx.beginPath();
    ctx.moveTo(cx - r, cy);
    ctx.lineTo(cx + r, cy);
    ctx.moveTo(cx, cy - r);
    ctx.lineTo(cx, cy + r);
    ctx.stroke();

    ctx.shadowColor = "#00e5ff";
    ctx.shadowBlur = 14;
    ctx.strokeStyle = "#00e5ff";
    ctx.lineWidth = 2.2;
    ctx.beginPath();

    for (let i = 0; i < 260; i++) {
      const k = i / 259;
      const a = -2.35 + k * 4.4 + 0.18 * Math.sin(t * 0.001);
      const rho = 0.18 + 0.60 * k + 0.045 * Math.sin(k * 18 + t * 0.002);
      const x = cx + Math.cos(a) * r * rho;
      const y = cy + Math.sin(a) * r * rho;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }

    ctx.stroke();
    ctx.shadowBlur = 0;

    const gamma = 0.42 + 0.06 * Math.sin(t * 0.001);
    const angle = 0.9 + 0.3 * Math.cos(t * 0.001);
    const gx = cx + Math.cos(angle) * r * gamma;
    const gy = cy + Math.sin(angle) * r * gamma;

    ctx.fillStyle = "#ffd166";
    ctx.beginPath();
    ctx.arc(gx, gy, 6 * dpr, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("VNA / SMITH CHART · S11 · Γ · VSWR · RETURN LOSS", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#7dffb2";
    ctx.fillText("Γ≈0.42∠52° · VSWR≈2.45 · RL≈7.5 dB · ML≈0.84 dB", 14 * dpr, h - 18 * dpr);
  }
}
TS

echo
echo "=== CREO RENDERER ANTENNA PATTERN ==="

cat > src/rf_instruments/renderers/AntennaPatternRenderer.ts <<'TS'
export class AntennaPatternRenderer {
  draw(canvas: HTMLCanvasElement, t = 0) {
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

    const cx = w * 0.50;
    const cy = h * 0.54;
    const r = Math.min(w, h) * 0.36;

    ctx.strokeStyle = "rgba(0,229,255,.13)";
    ctx.lineWidth = 1;

    for (let k = 1; k <= 5; k++) {
      ctx.beginPath();
      ctx.arc(cx, cy, (r * k) / 5, 0, Math.PI * 2);
      ctx.stroke();
    }

    for (let a = 0; a < 360; a += 15) {
      const rad = (a * Math.PI) / 180;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + Math.cos(rad) * r, cy + Math.sin(rad) * r);
      ctx.stroke();
    }

    const steer = Math.sin(t * 0.0008) * 0.65;

    ctx.shadowColor = "#00e5ff";
    ctx.shadowBlur = 16;
    ctx.strokeStyle = "#00e5ff";
    ctx.lineWidth = 2.4;
    ctx.beginPath();

    for (let i = 0; i <= 720; i++) {
      const a = (i / 720) * Math.PI * 2;
      const main = Math.pow(Math.max(0, Math.cos(a - steer)), 10);
      const back = 0.18 * Math.pow(Math.max(0, Math.cos(a - steer + Math.PI)), 4);
      const side = 0.10 + 0.09 * Math.abs(Math.sin(4 * a + t * 0.001));
      const gain = Math.max(side, main + back);
      const rr = r * (0.18 + 0.82 * gain);
      const x = cx + Math.cos(a) * rr;
      const y = cy + Math.sin(a) * rr;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }

    ctx.closePath();
    ctx.stroke();
    ctx.shadowBlur = 0;

    ctx.strokeStyle = "#ffd166";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(steer) * r * 1.05, cy + Math.sin(steer) * r * 1.05);
    ctx.stroke();

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("ANTENNA PATTERN · ARRAY FACTOR · BEAM STEERING · SIDE LOBES", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#7dffb2";
    ctx.fillText(`θ steer ${(steer * 180 / Math.PI).toFixed(1)}° · Gain 17.4 dBi · SLL -13.2 dB`, 14 * dpr, h - 18 * dpr);
  }
}
TS

echo
echo "=== CREO RENDERER MICROWAVE LINK ==="

cat > src/rf_instruments/renderers/MicrowaveLinkRenderer.ts <<'TS'
export class MicrowaveLinkRenderer {
  draw(canvas: HTMLCanvasElement, t = 0) {
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

    ctx.strokeStyle = "rgba(0,229,255,.08)";
    for (let i = 0; i <= 14; i++) {
      const x = (w * i) / 14;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }

    const leftX = w * 0.18;
    const rightX = w * 0.82;
    const topY = h * 0.34;
    const baseY = h * 0.84;

    ctx.strokeStyle = "rgba(230,250,255,.75)";
    ctx.lineWidth = 4 * dpr;
    ctx.beginPath();
    ctx.moveTo(leftX, baseY);
    ctx.lineTo(leftX, topY);
    ctx.moveTo(rightX, baseY);
    ctx.lineTo(rightX, topY);
    ctx.stroke();

    ctx.fillStyle = "rgba(230,250,255,.92)";
    ctx.beginPath();
    ctx.ellipse(leftX + 42 * dpr, topY + 10 * dpr, 34 * dpr, 58 * dpr, -0.18, 0, Math.PI * 2);
    ctx.fill();

    ctx.beginPath();
    ctx.ellipse(rightX - 42 * dpr, topY + 10 * dpr, 34 * dpr, 58 * dpr, 0.18, 0, Math.PI * 2);
    ctx.fill();

    ctx.save();
    ctx.globalCompositeOperation = "lighter";

    for (let i = 0; i < 28; i++) {
      const k = i / 28;
      ctx.strokeStyle = `rgba(0,229,255,${0.035 * (1 - k)})`;
      ctx.lineWidth = (1 + k * 6) * dpr;
      ctx.beginPath();
      ctx.moveTo(leftX + 70 * dpr, topY + 8 * dpr);
      ctx.quadraticCurveTo(w * 0.50, h * (0.23 + 0.035 * Math.sin(t * 0.001 + k)), rightX - 70 * dpr, topY + 8 * dpr);
      ctx.stroke();
    }

    ctx.restore();

    ctx.strokeStyle = "rgba(255,209,102,.55)";
    ctx.setLineDash([8 * dpr, 8 * dpr]);
    ctx.beginPath();
    ctx.ellipse(w * 0.50, topY + 8 * dpr, w * 0.25, h * 0.11, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("MICROWAVE LINK · LOS · FRESNEL · FSPL · RSL · FADE MARGIN", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#7dffb2";
    ctx.fillText("18 GHz · 12.4 km · FSPL 139.4 dB · RSL -47.8 dBm · Fade Margin 27.1 dB", 14 * dpr, h - 18 * dpr);
  }
}
TS

echo
echo "=== CREO RENDERER OFDM GRID ==="

cat > src/rf_instruments/renderers/OFDMGridRenderer.ts <<'TS'
export class OFDMGridRenderer {
  draw(canvas: HTMLCanvasElement, t = 0) {
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

    const cols = 48;
    const rows = 18;
    const padX = 18 * dpr;
    const padY = 42 * dpr;
    const cellW = (w - padX * 2) / cols;
    const cellH = (h - padY * 1.7) / rows;

    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const ssb = x >= 3 && x <= 8 && y >= 6 && y <= 11;
        const prach = x >= 38 && x <= 44 && y >= 1 && y <= 4;
        const pdcch = y <= 1 && x > 10 && x < 36;
        const pdsch = !ssb && !prach && !pdcch && Math.sin(x * 0.7 + y * 0.31 + t * 0.004) > -0.15;

        if (ssb) ctx.fillStyle = "rgba(255,209,102,.92)";
        else if (prach) ctx.fillStyle = "rgba(255,95,122,.78)";
        else if (pdcch) ctx.fillStyle = "rgba(125,255,178,.72)";
        else if (pdsch) ctx.fillStyle = "rgba(0,229,255,.45)";
        else ctx.fillStyle = "rgba(0,70,110,.18)";

        ctx.fillRect(padX + x * cellW + 1, padY + y * cellH + 1, Math.max(1, cellW - 2), Math.max(1, cellH - 2));
      }
    }

    ctx.strokeStyle = "rgba(0,229,255,.18)";
    ctx.strokeRect(padX, padY, cellW * cols, cellH * rows);

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("5G NR OFDM RESOURCE GRID · SSB · PDCCH · PDSCH · PRACH", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#ffd166";
    ctx.fillText("μ=1 · SCS 30 kHz · 48 RB view · synthetic allocation map", 14 * dpr, h - 18 * dpr);
  }
}
TS

echo
echo "=== APPENDO CSS SUITE V5 ==="

if ! grep -q "TRFMC_RF_INSTRUMENT_SUITE_V5_STYLE" src/styles.css 2>/dev/null; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_INSTRUMENT_SUITE_V5_STYLE */
.rf-suite-v5{
  border:1px solid rgba(57,215,255,.30);
  border-radius:26px;
  overflow:hidden;
  background:
    radial-gradient(circle at 80% 0%,rgba(0,229,255,.17),transparent 34%),
    radial-gradient(circle at 10% 100%,rgba(125,255,178,.07),transparent 30%),
    linear-gradient(145deg,rgba(5,16,29,.97),rgba(0,4,9,.99));
  box-shadow:
    0 30px 100px rgba(0,0,0,.68),
    inset 0 0 52px rgba(57,215,255,.045);
}

.rf-suite-v5-top{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:16px;
  padding:14px 16px;
  border-bottom:1px solid rgba(57,215,255,.22);
  background:linear-gradient(180deg,rgba(12,35,58,.98),rgba(3,10,18,.98));
}

.rf-suite-v5-title{
  color:#f1fbff;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.13em;
  font-size:20px;
  text-shadow:0 0 20px rgba(57,215,255,.48);
}

.rf-suite-v5-sub{
  margin-top:4px;
  color:#88a9c4;
  font-size:11px;
}

.rf-suite-v5-tabs{
  display:flex;
  gap:8px;
  flex-wrap:wrap;
  padding:10px;
  border-bottom:1px solid rgba(57,215,255,.16);
  background:rgba(0,4,9,.56);
}

.rf-suite-v5-tab{
  border-radius:11px;
  padding:8px 12px;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.08em;
}

.rf-suite-v5-tab.active{
  color:#021018;
  background:linear-gradient(180deg,#7df1ff,#34c9f2);
  border-color:#c7fbff;
  box-shadow:0 0 20px rgba(57,215,255,.40);
}

.rf-suite-v5-body{
  padding:10px;
}

.rf-suite-v5-grid{
  display:grid;
  grid-template-columns:1.2fr .8fr;
  gap:10px;
}

.rf-suite-v5-card{
  border:1px solid rgba(57,215,255,.22);
  border-radius:18px;
  padding:10px;
  background:
    linear-gradient(145deg,rgba(6,17,30,.94),rgba(1,5,11,.99)),
    radial-gradient(circle at 85% 0%,rgba(57,215,255,.075),transparent 35%);
  box-shadow:inset 0 0 30px rgba(57,215,255,.035);
}

.rf-suite-v5-card h3{
  margin:0 0 8px;
  color:#39d7ff;
  font-size:12px;
  text-transform:uppercase;
  letter-spacing:.10em;
}

.rf-suite-v5-canvas{
  display:block;
  width:100%;
  border-radius:16px;
  background:#00050a;
  border:1px solid rgba(57,215,255,.18);
}

.rf-suite-v5-table{
  width:100%;
  border-collapse:collapse;
  font-family:ui-monospace,Consolas,monospace;
  font-size:12px;
}

.rf-suite-v5-table th,
.rf-suite-v5-table td{
  border-bottom:1px solid rgba(57,215,255,.14);
  padding:7px 8px;
  text-align:left;
}

.rf-suite-v5-table th{
  color:#39d7ff;
  background:rgba(57,215,255,.055);
  text-transform:uppercase;
  letter-spacing:.08em;
  font-size:10px;
}

.rf-suite-v5-formula{
  margin-top:10px;
  border:1px solid rgba(255,209,102,.22);
  border-radius:14px;
  background:rgba(255,209,102,.045);
  color:#ffd166;
  padding:10px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:11px;
  line-height:1.55;
}

@media(max-width:1300px){
  .rf-suite-v5-grid{ grid-template-columns:1fr; }
  .rf-suite-v5-top{ flex-direction:column; align-items:flex-start; }
}
CSS
fi

echo
echo "=== CREO SUITE V5 ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx <<'TSX'
import React, { useEffect, useRef, useState } from "react";

import { RFInstrumentDockV4 } from "./RFInstrumentDockV4";
import { SmithChartRenderer } from "../renderers/SmithChartRenderer";
import { AntennaPatternRenderer } from "../renderers/AntennaPatternRenderer";
import { MicrowaveLinkRenderer } from "../renderers/MicrowaveLinkRenderer";
import { OFDMGridRenderer } from "../renderers/OFDMGridRenderer";

type SuiteTab = "vsa" | "smith" | "antenna" | "microwave" | "ofdm";

const tabs: { id: SuiteTab; label: string }[] = [
  { id: "vsa", label: "VSA Dock" },
  { id: "smith", label: "VNA / Smith" },
  { id: "antenna", label: "Antenna" },
  { id: "microwave", label: "Microwave" },
  { id: "ofdm", label: "OFDM Grid" }
];

export function RFInstrumentSuiteV5() {
  const [active, setActive] = useState<SuiteTab>("vsa");

  const smithRef = useRef<HTMLCanvasElement | null>(null);
  const antennaRef = useRef<HTMLCanvasElement | null>(null);
  const microwaveRef = useRef<HTMLCanvasElement | null>(null);
  const ofdmRef = useRef<HTMLCanvasElement | null>(null);

  const smith = useRef(new SmithChartRenderer());
  const antenna = useRef(new AntennaPatternRenderer());
  const microwave = useRef(new MicrowaveLinkRenderer());
  const ofdm = useRef(new OFDMGridRenderer());

  useEffect(() => {
    let raf = 0;

    const loop = (t: number) => {
      if (smithRef.current) smith.current.draw(smithRef.current, t);
      if (antennaRef.current) antenna.current.draw(antennaRef.current, t);
      if (microwaveRef.current) microwave.current.draw(microwaveRef.current, t);
      if (ofdmRef.current) ofdm.current.draw(ofdmRef.current, t);

      raf = requestAnimationFrame(loop);
    };

    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [active]);

  return (
    <section className="rf-suite-v5">
      <header className="rf-suite-v5-top">
        <div>
          <div className="rf-suite-v5-title">TRFMC RF Instrument Suite V5</div>
          <div className="rf-suite-v5-sub">
            VSA · VNA/Smith · Antenna Pattern · Microwave Link · 5G NR OFDM Resource Grid
          </div>
        </div>

        <div className="rf-dock-v4-state">
          <span className="rf-dock-v4-pill">V4 DOCK PRESERVED</span>
          <span className="rf-dock-v4-pill">V5 SUITE ACTIVE</span>
          <span className="rf-dock-v4-pill">NO STATIC SHELL MUTATION</span>
        </div>
      </header>

      <nav className="rf-suite-v5-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={active === tab.id ? "rf-suite-v5-tab active" : "rf-suite-v5-tab"}
            onClick={() => setActive(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </nav>

      <div className="rf-suite-v5-body">
        {active === "vsa" && <RFInstrumentDockV4 />}

        {active === "smith" && (
          <div className="rf-suite-v5-grid">
            <div className="rf-suite-v5-card">
              <h3>VNA / Smith Chart Engine</h3>
              <canvas ref={smithRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </div>

            <div className="rf-suite-v5-card">
              <h3>S-Parameter Measurement Table</h3>
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>Parameter</th><th>Value</th><th>Meaning</th></tr>
                  <tr><td>S11</td><td>-7.5 dB</td><td>Input return loss</td></tr>
                  <tr><td>S21</td><td>-1.2 dB</td><td>Insertion loss</td></tr>
                  <tr><td>Γ</td><td>0.42 ∠ 52°</td><td>Reflection coefficient</td></tr>
                  <tr><td>VSWR</td><td>2.45</td><td>Mismatch severity</td></tr>
                  <tr><td>Mismatch Loss</td><td>0.84 dB</td><td>Power lost by mismatch</td></tr>
                  <tr><td>Recommended Action</td><td>Stub / L-match</td><td>Matching synthesis candidate</td></tr>
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                Γ = (ZL - Z0) / (ZL + Z0)<br />
                VSWR = (1 + |Γ|) / (1 - |Γ|)<br />
                Return Loss = -20log10(|Γ|)<br />
                Mismatch Loss = -10log10(1 - |Γ|²)
              </div>
            </div>
          </div>
        )}

        {active === "antenna" && (
          <div className="rf-suite-v5-grid">
            <div className="rf-suite-v5-card">
              <h3>Antenna Pattern / Array Factor</h3>
              <canvas ref={antennaRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </div>

            <div className="rf-suite-v5-card">
              <h3>Antenna Engineering Panel</h3>
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>KPI</th><th>Value</th><th>Meaning</th></tr>
                  <tr><td>Array</td><td>8 elements</td><td>Uniform linear array</td></tr>
                  <tr><td>Spacing</td><td>0.5 λ</td><td>Grating lobe control</td></tr>
                  <tr><td>Gain</td><td>17.4 dBi</td><td>Peak boresight gain</td></tr>
                  <tr><td>SLL</td><td>-13.2 dB</td><td>Side-lobe level</td></tr>
                  <tr><td>HPBW</td><td>14.6°</td><td>Half-power beamwidth</td></tr>
                  <tr><td>Use Case</td><td>5G sector / beam</td><td>Directional coverage</td></tr>
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                AF(θ) = Σ wₙ · e^(j n ψ)<br />
                ψ = k d cos(θ) + β<br />
                EIRP = Ptx + Gant - feeder loss
              </div>
            </div>
          </div>
        )}

        {active === "microwave" && (
          <div className="rf-suite-v5-grid">
            <div className="rf-suite-v5-card">
              <h3>Microwave Link Planner</h3>
              <canvas ref={microwaveRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </div>

            <div className="rf-suite-v5-card">
              <h3>Backhaul Link Budget</h3>
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>Term</th><th>Value</th><th>Meaning</th></tr>
                  <tr><td>Frequency</td><td>18 GHz</td><td>Microwave carrier</td></tr>
                  <tr><td>Distance</td><td>12.4 km</td><td>Path length</td></tr>
                  <tr><td>FSPL</td><td>139.4 dB</td><td>Free-space path loss</td></tr>
                  <tr><td>RSL</td><td>-47.8 dBm</td><td>Received signal level</td></tr>
                  <tr><td>Fade Margin</td><td>27.1 dB</td><td>Availability margin</td></tr>
                  <tr><td>Fresnel</td><td>Clear</td><td>First-zone clearance</td></tr>
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                FSPL(dB) = 32.44 + 20log10(fMHz) + 20log10(dkm)<br />
                RSL = Pt + Gt + Gr - FSPL - losses<br />
                Fade Margin = RSL - Receiver Sensitivity
              </div>
            </div>
          </div>
        )}

        {active === "ofdm" && (
          <div className="rf-suite-v5-grid">
            <div className="rf-suite-v5-card">
              <h3>5G NR OFDM Resource Grid</h3>
              <canvas ref={ofdmRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </div>

            <div className="rf-suite-v5-card">
              <h3>NR Allocation / PHY Evidence</h3>
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>Layer</th><th>Status</th><th>Meaning</th></tr>
                  <tr><td>SSB</td><td>Mapped</td><td>Synchronization signal block</td></tr>
                  <tr><td>PDCCH</td><td>Active</td><td>Control channel region</td></tr>
                  <tr><td>PDSCH</td><td>Scheduled</td><td>User data allocation</td></tr>
                  <tr><td>PRACH</td><td>Detected</td><td>Random access opportunity</td></tr>
                  <tr><td>SCS</td><td>30 kHz</td><td>Numerology μ=1</td></tr>
                  <tr><td>Evidence</td><td>Synthetic lab</td><td>Ready for UERANSIM/Open5GS correlation</td></tr>
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                Δf = 15 kHz · 2^μ<br />
                Tsym ≈ 1 / Δf, excluding CP<br />
                Resource Block = 12 subcarriers × symbols
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V4 -> V5 ==="

python3 - <<'PY'
from pathlib import Path

p = Path("src/app/main.tsx")
s = p.read_text()

v4_imp = "import { RFInstrumentDockV4 } from '../rf_instruments/instruments/RFInstrumentDockV4'\n"
v5_imp = "import { RFInstrumentSuiteV5 } from '../rf_instruments/instruments/RFInstrumentSuiteV5'\n"

if v4_imp in s:
    s = s.replace(v4_imp, v5_imp, 1)
elif v5_imp not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, v5_imp)
    s = "".join(lines)

s = s.replace("<RFInstrumentDockV4 />", "<RFInstrumentSuiteV5 />")

p.write_text(s)
print("OK: main.tsx patched to V5")
PY

cat > "../runtime/quality/TRFMC_RF_INSTRUMENT_SUITE_V5_${TS}/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_INSTRUMENT_SUITE_V5",
  "created": [
    "src/rf_instruments/renderers/SmithChartRenderer.ts",
    "src/rf_instruments/renderers/AntennaPatternRenderer.ts",
    "src/rf_instruments/renderers/MicrowaveLinkRenderer.ts",
    "src/rf_instruments/renderers/OFDMGridRenderer.ts",
    "src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "preserves_v4_runtime_freeze": true,
  "suite_tabs": [
    "VSA Dock",
    "VNA / Smith",
    "Antenna",
    "Microwave",
    "OFDM Grid"
  ],
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/../runtime/quality/TRFMC_RF_INSTRUMENT_SUITE_V5_${TS}" ../runtime/quality/latest_rf_instrument_suite_v5

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV5\\|RFInstrumentDockV4\\|RFSignalAnalyzerWorkbenchV3" src/app/main.tsx || true

echo
echo "=== FILES CREATED ==="
ls -lh \
  src/rf_instruments/renderers/SmithChartRenderer.ts \
  src/rf_instruments/renderers/AntennaPatternRenderer.ts \
  src/rf_instruments/renderers/MicrowaveLinkRenderer.ts \
  src/rf_instruments/renderers/OFDMGridRenderer.ts \
  src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_instrument_suite_v5/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V5 SUITE CREATA. RIAVVIA VITE E TESTA."
echo "============================================================"
