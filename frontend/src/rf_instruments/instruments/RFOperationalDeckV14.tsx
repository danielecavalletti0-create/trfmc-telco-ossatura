import React, { useMemo, useState } from "react";

import { RFInstrumentSuiteV5 } from "./RFInstrumentSuiteV5";
import { RFSourceBridgePanelV7 } from "../sources/RFSourceBridgePanelV7";
import { RFSourceRuntimeProbeV8 } from "../sources/RFSourceRuntimeProbeV8";
import { RFBridgeReadinessV9 } from "../telemetry/RFBridgeReadinessV9";
import { RFEvidenceFlightRecorderV10 } from "../evidence/RFEvidenceFlightRecorderV10";
import { RFRenderGovernorHeadlessV14 } from "../telemetry/RFRenderGovernorHeadlessV14";

type DeckTab =
  | "instruments"
  | "sources"
  | "runtime"
  | "bridge"
  | "evidence"
  | "ops";

const tabs: { id: DeckTab; label: string }[] = [
  { id: "instruments", label: "Instruments" },
  { id: "sources", label: "Sources" },
  { id: "runtime", label: "Runtime" },
  { id: "bridge", label: "Bridge" },
  { id: "evidence", label: "Evidence" },
  { id: "ops", label: "Ops Deck" }
];

function StatusCard(props: { label: string; value: string; detail: string }) {
  return (
    <div className="rf-op14-card">
      <b>{props.label}</b>
      <span>{props.value}</span>
      <small>{props.detail}</small>
    </div>
  );
}

export function RFOperationalDeckV14() {
  const [active, setActive] = useState<DeckTab>("instruments");

  const cards = useMemo(
    () => [
      {
        label: "Deck",
        value: "V14 AUTO",
        detail: "Console a tab sopra la catena realmente presente."
      },
      {
        label: "Default",
        value: "Instruments",
        detail: "La suite strumenti è la superficie principale."
      },
      {
        label: "Governor",
        value: "Headless",
        detail: "Policy leggera sempre attiva anche fuori dai tab diagnostici."
      },
      {
        label: "Rendering",
        value: "Lazy View",
        detail: "Diagnostica a richiesta, non più stack verticale continuo."
      },
      {
        label: "Safety",
        value: "Read-only",
        detail: "Nessun controllo SDR, nessuna mutazione Open5GS."
      }
    ],
    []
  );

  return (
    <section className="rf-op14">
      <RFRenderGovernorHeadlessV14 />

      <header className="rf-op14-header">
        <div>
          <div className="rf-op14-title">TRFMC RF Operational Deck V14</div>
          <div className="rf-op14-sub">
            Compact mission deck · instruments first · diagnostics on demand · safe RF/Telco cockpit
          </div>
        </div>

        <div className="rf-op14-badges">
          <span>STACK NORMALIZED</span>
          <span>INSTRUMENTS FIRST</span>
          <span>HEADLESS GOVERNOR</span>
          <span>CONTENT VISIBILITY</span>
          <span>NO CORE MUTATION</span>
        </div>
      </header>

      <nav className="rf-op14-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={active === tab.id ? "rf-op14-tab active" : "rf-op14-tab"}
            onClick={() => setActive(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </nav>

      <div className="rf-op14-status">
        {cards.map((card) => (
          <StatusCard key={card.label} {...card} />
        ))}
      </div>

      <div className="rf-op14-stage">
        {active === "instruments" && <RFInstrumentSuiteV5 />}
        {active === "sources" && <RFSourceBridgePanelV7 />}
        {active === "runtime" && <RFSourceRuntimeProbeV8 />}
        {active === "bridge" && <RFBridgeReadinessV9 />}
        {active === "evidence" && <RFEvidenceFlightRecorderV10 />}

        {active === "ops" && (
          <div>
            <details className="rf-op14-collapse" open>
              <summary>Instrument Suite</summary>
              <div><RFInstrumentSuiteV5 /></div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Source Bridge + Runtime</summary>
              <div className="rf-op14-grid2">
                <RFSourceBridgePanelV7 />
                <RFSourceRuntimeProbeV8 />
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Bridge Readiness + Evidence Recorder</summary>
              <div className="rf-op14-grid2">
                <RFBridgeReadinessV9 />
                <RFEvidenceFlightRecorderV10 />
              </div>
            </details>
          </div>
        )}
      </div>
    </section>
  );
}
