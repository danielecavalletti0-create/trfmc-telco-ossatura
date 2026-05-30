import React from "react";

import { RFInstrumentSuiteV5 } from "./RFInstrumentSuiteV5";

const cards = [
  {
    label: "Runtime",
    value: "React + Vite",
    detail: "Root SPA attiva, static shell preservata."
  },
  {
    label: "DSP",
    value: "Worker V3",
    detail: "Pipeline RF off-main-thread per telemetria e synthetic IQ."
  },
  {
    label: "Suite",
    value: "VSA/VNA/ANT/MW/OFDM",
    detail: "V5 modulare pronta per estensione scientifica."
  },
  {
    label: "Safety",
    value: "Freeze + Rollback",
    detail: "Ogni turbo step crea backup e quality summary."
  }
];

export function RFInstrumentSuiteV6TurboSafe() {
  return (
    <section className="rf-suite-v6-turbo">
      <header className="rf-suite-v6-turbo-header">
        <div>
          <div className="rf-suite-v6-turbo-title">TRFMC RF Instrument Suite V6 Turbo Safe</div>
          <div className="rf-suite-v6-turbo-sub">
            Safe missile mode · no destructive mutation · V5 preserved · DSP Worker V3 · RF/Telco instrumentation expansion rail
          </div>
        </div>

        <div className="rf-suite-v6-turbo-badges">
          <span className="rf-suite-v6-badge">TURBO SAFE</span>
          <span className="rf-suite-v6-badge">NO STATIC SHELL MUTATION</span>
          <span className="rf-suite-v6-badge">V4/V5 FREEZE PROTECTED</span>
          <span className="rf-suite-v6-badge">NEXT: REAL DSP / SDR BRIDGE</span>
        </div>
      </header>

      <div className="rf-suite-v6-turbo-panel">
        {cards.map((card) => (
          <div className="rf-suite-v6-card" key={card.label}>
            <b>{card.label}</b>
            <span>{card.value}</span>
            <small>{card.detail}</small>
          </div>
        ))}
      </div>

      <div className="rf-suite-v6-stage">
        <RFInstrumentSuiteV5 />
      </div>
    </section>
  );
}
