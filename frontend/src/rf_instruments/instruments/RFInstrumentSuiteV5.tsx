import React, { useCallback, useEffect, useRef, useState } from "react";

import { RFInstrumentDockV4 } from "./RFInstrumentDockV4";
import { SmithChartRenderer } from "../renderers/SmithChartRenderer";
import { AntennaPatternRenderer } from "../renderers/AntennaPatternRenderer";
import { MicrowaveLinkRenderer } from "../renderers/MicrowaveLinkRenderer";
import { OFDMGridRenderer } from "../renderers/OFDMGridRenderer";
import { useRAFLoop } from "../../hooks/useRAFLoop";

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
