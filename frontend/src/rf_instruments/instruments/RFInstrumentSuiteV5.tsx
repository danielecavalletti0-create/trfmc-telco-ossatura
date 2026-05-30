import React, { memo, useCallback, useMemo, useRef, useState } from "react";

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

const smithTableRows = [
  ["S11", "-7.5 dB", "Input return loss"],
  ["S21", "-1.2 dB", "Insertion loss"],
  ["Γ", "0.42 ∠ 52°", "Reflection coefficient"],
  ["VSWR", "2.45", "Mismatch severity"],
  ["Mismatch Loss", "0.84 dB", "Power lost by mismatch"],
  ["Recommended Action", "Stub / L-match", "Matching synthesis candidate"]
] as const;

const antennaTableRows = [
  ["Array", "8 elements", "Uniform linear array"],
  ["Spacing", "0.5 λ", "Grating lobe control"],
  ["Gain", "17.4 dBi", "Peak boresight gain"],
  ["SLL", "-13.2 dB", "Side-lobe level"],
  ["HPBW", "14.6°", "Half-power beamwidth"],
  ["Use Case", "5G sector / beam", "Directional coverage"]
] as const;

const microwaveTableRows = [
  ["Frequency", "18 GHz", "Microwave carrier"],
  ["Distance", "12.4 km", "Path length"],
  ["FSPL", "139.4 dB", "Free-space path loss"],
  ["RSL", "-47.8 dBm", "Received signal level"],
  ["Fade Margin", "27.1 dB", "Availability margin"],
  ["Fresnel", "Clear", "First-zone clearance"]
] as const;

const ofdmTableRows = [
  ["Layer", "Mapped", "Synchronization signal block"],
  ["PDCCH", "Active", "Control channel region"],
  ["PDSCH", "Scheduled", "User data allocation"],
  ["PRACH", "Detected", "Random access opportunity"],
  ["SCS", "30 kHz", "Numerology μ=1"],
  ["Evidence", "Synthetic lab", "Ready for UERANSIM/Open5GS correlation"]
] as const;

const PanelCard = memo(function PanelCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rf-suite-v5-card">
      <h3>{title}</h3>
      {children}
    </div>
  );
});

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

  const drawLoop = useCallback((t: number) => {
    if (smithRef.current) smith.current.draw(smithRef.current, t);
    if (antennaRef.current) antenna.current.draw(antennaRef.current, t);
    if (microwaveRef.current) microwave.current.draw(microwaveRef.current, t);
    if (ofdmRef.current) ofdm.current.draw(ofdmRef.current, t);
  }, []);

  useRAFLoop(drawLoop, []);

  const onSelectTab = useCallback((tab: SuiteTab) => setActive(tab), []);

  const tabButtons = useMemo(
    () => tabs.map((tab) => (
      <button
        key={tab.id}
        className={active === tab.id ? "rf-suite-v5-tab active" : "rf-suite-v5-tab"}
        onClick={() => onSelectTab(tab.id)}
      >
        {tab.label}
      </button>
    )),
    [active, onSelectTab]
  );

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
        {tabButtons}
      </nav>

      <div className="rf-suite-v5-body">
        {active === "vsa" && <RFInstrumentDockV4 />}

        {active === "smith" && (
          <div className="rf-suite-v5-grid">
            <PanelCard title="VNA / Smith Chart Engine">
              <canvas ref={smithRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </PanelCard>

            <PanelCard title="S-Parameter Measurement Table">
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>Parameter</th><th>Value</th><th>Meaning</th></tr>
                  {smithTableRows.map(([parameter, value, meaning]) => (
                    <tr key={parameter}>
                      <td>{parameter}</td>
                      <td>{value}</td>
                      <td>{meaning}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                Γ = (ZL - Z0) / (ZL + Z0)<br />
                VSWR = (1 + |Γ|) / (1 - |Γ|)<br />
                Return Loss = -20log10(|Γ|)<br />
                Mismatch Loss = -10log10(1 - |Γ|²)
              </div>
            </PanelCard>
          </div>
        )}

        {active === "antenna" && (
          <div className="rf-suite-v5-grid">
            <PanelCard title="Antenna Pattern / Array Factor">
              <canvas ref={antennaRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </PanelCard>

            <PanelCard title="Antenna Engineering Panel">
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>KPI</th><th>Value</th><th>Meaning</th></tr>
                  {antennaTableRows.map(([kpi, value, meaning]) => (
                    <tr key={kpi}>
                      <td>{kpi}</td>
                      <td>{value}</td>
                      <td>{meaning}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                AF(θ) = Σ wₙ · e^(j n ψ)<br />
                ψ = k d cos(θ) + β<br />
                EIRP = Ptx + Gant - feeder loss
              </div>
            </PanelCard>
          </div>
        )}

        {active === "microwave" && (
          <div className="rf-suite-v5-grid">
            <PanelCard title="Microwave Link Planner">
              <canvas ref={microwaveRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </PanelCard>

            <PanelCard title="Backhaul Link Budget">
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>Term</th><th>Value</th><th>Meaning</th></tr>
                  {microwaveTableRows.map(([term, value, meaning]) => (
                    <tr key={term}>
                      <td>{term}</td>
                      <td>{value}</td>
                      <td>{meaning}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                FSPL(dB) = 32.44 + 20log10(fMHz) + 20log10(dkm)<br />
                RSL = Pt + Gt + Gr - FSPL - losses<br />
                Fade Margin = RSL - Receiver Sensitivity
              </div>
            </PanelCard>
          </div>
        )}

        {active === "ofdm" && (
          <div className="rf-suite-v5-grid">
            <PanelCard title="5G NR OFDM Resource Grid">
              <canvas ref={ofdmRef} className="rf-suite-v5-canvas" style={{ height: 720 }} />
            </PanelCard>

            <PanelCard title="NR Allocation / PHY Evidence">
              <table className="rf-suite-v5-table">
                <tbody>
                  <tr><th>Layer</th><th>Status</th><th>Meaning</th></tr>
                  {ofdmTableRows.map(([layer, status, meaning]) => (
                    <tr key={layer}>
                      <td>{layer}</td>
                      <td>{status}</td>
                      <td>{meaning}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="rf-suite-v5-formula">
                Δf = 15 kHz · 2^μ<br />
                Tsym ≈ 1 / Δf, excluding CP<br />
                Resource Block = 12 subcarriers × symbols
              </div>
            </PanelCard>
          </div>
        )}
      </div>
    </section>
  );
}
