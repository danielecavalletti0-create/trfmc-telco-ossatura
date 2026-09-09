import React, { useMemo, useState } from "react";

import { RF_SOURCE_DESCRIPTORS, RFSourceMode } from "./RFSourceTypes";

const sourceOrder: RFSourceMode[] = [
  "synthetic",
  "file_iq",
  "websocket_iq",
  "sdr_bridge",
  "open5gs_events"
];

export function RFSourceBridgePanelV7() {
  const [selected, setSelected] = useState<RFSourceMode>("synthetic");

  const active = useMemo(
    () => RF_SOURCE_DESCRIPTORS.find((s) => s.mode === selected) ?? RF_SOURCE_DESCRIPTORS[0],
    [selected]
  );

  return (
    <section className="rf-source-v7">
      <header className="rf-source-v7-header">
        <div>
          <div className="rf-source-v7-title">TRFMC RF Source Bridge V7 Prep</div>
          <div className="rf-source-v7-sub">
            Source abstraction rail · synthetic safe source now · file IQ / binary WebSocket / SDR bridge / Open5GS events prepared
          </div>
        </div>

        <div className="rf-source-v7-badges">
          <span>SOURCE MODE: {active.mode}</span>
          <span>SAFETY: {active.safety}</span>
          <span>STATUS: {active.status}</span>
        </div>
      </header>

      <div className="rf-source-v7-grid">
        <div className="rf-source-v7-card">
          <h3>Source Selector</h3>

          <div className="rf-source-v7-selector">
            {sourceOrder.map((mode) => {
              const item = RF_SOURCE_DESCRIPTORS.find((s) => s.mode === mode)!;

              return (
                <button
                  key={mode}
                  className={selected === mode ? "rf-source-v7-button active" : "rf-source-v7-button"}
                  onClick={() => setSelected(mode)}
                >
                  {item.label}
                </button>
              );
            })}
          </div>
        </div>

        <div className="rf-source-v7-card">
          <h3>Selected Source Contract</h3>

          <table className="rf-source-v7-table">
            <tbody>
              <tr><th>Field</th><th>Value</th></tr>
              <tr><td>Mode</td><td>{active.mode}</td></tr>
              <tr><td>Label</td><td>{active.label}</td></tr>
              <tr><td>Status</td><td>{active.status}</td></tr>
              <tr><td>Endpoint</td><td>{active.endpoint ?? "local/internal"}</td></tr>
              <tr><td>Sample Rate</td><td>{active.sampleRate ? `${active.sampleRate.toLocaleString()} S/s` : "not negotiated"}</td></tr>
              <tr><td>Center</td><td>{active.centerFrequency ? `${(active.centerFrequency / 1e9).toFixed(6)} GHz` : "not negotiated"}</td></tr>
              <tr><td>Format</td><td>{active.format}</td></tr>
              <tr><td>Safety</td><td>{active.safety}</td></tr>
            </tbody>
          </table>
        </div>

        <div className="rf-source-v7-card rf-source-v7-wide">
          <h3>Bridge Roadmap</h3>

          <div className="rf-source-v7-flow">
            <span>RF Source</span>
            <b>→</b>
            <span>Frame Adapter</span>
            <b>→</b>
            <span>DSP Worker</span>
            <b>→</b>
            <span>Metrics</span>
            <b>→</b>
            <span>VSA / VNA / OFDM Views</span>
          </div>

          <p className="rf-source-v7-note">
            {active.notes}
          </p>

          <p className="rf-source-v7-note">
            V7 does not auto-connect to SDR or external sockets. It prepares typed contracts and UI routing only.
            Live bridges will be enabled later behind explicit local-lab safety gates.
          </p>
        </div>
      </div>
    </section>
  );
}
