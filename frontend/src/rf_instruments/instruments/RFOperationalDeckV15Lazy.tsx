import React, { lazy, Suspense, useMemo, useState } from "react";

import { RFRenderGovernorHeadlessV14 } from "../telemetry/RFRenderGovernorHeadlessV14";

const RFInstrumentSuiteV5 = lazy(() =>
  import("./RFInstrumentSuiteV5").then((module) => ({
    default: module.RFInstrumentSuiteV5
  }))
);

const RFSourceBridgePanelV7 = lazy(() =>
  import("../sources/RFSourceBridgePanelV7").then((module) => ({
    default: module.RFSourceBridgePanelV7
  }))
);

const RFSourceRuntimeProbeV8 = lazy(() =>
  import("../sources/RFSourceRuntimeProbeV8").then((module) => ({
    default: module.RFSourceRuntimeProbeV8
  }))
);

const RFBridgeReadinessV9 = lazy(() =>
  import("../telemetry/RFBridgeReadinessV9").then((module) => ({
    default: module.RFBridgeReadinessV9
  }))
);

const RFEvidenceFlightRecorderV10 = lazy(() =>
  import("../evidence/RFEvidenceFlightRecorderV10").then((module) => ({
    default: module.RFEvidenceFlightRecorderV10
  }))
);

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

function Loader({ label }: { label: string }) {
  return <div className="rf-op15-loader">Loading {label} chunk</div>;
}

function StatusCard(props: { label: string; value: string; detail: string }) {
  return (
    <div className="rf-op14-card">
      <b>{props.label}</b>
      <span>{props.value}</span>
      <small>{props.detail}</small>
    </div>
  );
}

export function RFOperationalDeckV15Lazy() {
  const [active, setActive] = useState<DeckTab>("instruments");

  const cards = useMemo(
    () => [
      {
        label: "Deck",
        value: "V15 LAZY",
        detail: "Console a tab con caricamento dinamico dei pannelli."
      },
      {
        label: "Default",
        value: "Instruments",
        detail: "La suite strumenti resta la superficie principale."
      },
      {
        label: "Loading",
        value: "React.lazy",
        detail: "I moduli pesanti vengono caricati al primo uso."
      },
      {
        label: "Governor",
        value: "Headless",
        detail: "Policy leggera sempre attiva fuori dai chunk."
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
          <div className="rf-op14-title">
            TRFMC RF Operational Deck V15
            <span className="rf-op15-chunk-badge">LAZY MODULE LOADING</span>
          </div>
          <div className="rf-op14-sub">
            Compact mission deck · dynamic chunk loading · instruments first · diagnostics on demand
          </div>
        </div>

        <div className="rf-op14-badges">
          <span>REACT LAZY</span>
          <span>SUSPENSE</span>
          <span>DYNAMIC IMPORT</span>
          <span>HEADLESS GOVERNOR</span>
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
        {active === "instruments" && (
          <Suspense fallback={<Loader label="instrument suite" />}>
            <RFInstrumentSuiteV5 />
          </Suspense>
        )}

        {active === "sources" && (
          <Suspense fallback={<Loader label="source bridge" />}>
            <RFSourceBridgePanelV7 />
          </Suspense>
        )}

        {active === "runtime" && (
          <Suspense fallback={<Loader label="runtime probe" />}>
            <RFSourceRuntimeProbeV8 />
          </Suspense>
        )}

        {active === "bridge" && (
          <Suspense fallback={<Loader label="bridge readiness" />}>
            <RFBridgeReadinessV9 />
          </Suspense>
        )}

        {active === "evidence" && (
          <Suspense fallback={<Loader label="evidence recorder" />}>
            <RFEvidenceFlightRecorderV10 />
          </Suspense>
        )}

        {active === "ops" && (
          <div>
            <details className="rf-op14-collapse" open>
              <summary>Instrument Suite</summary>
              <div>
                <Suspense fallback={<Loader label="instrument suite" />}>
                  <RFInstrumentSuiteV5 />
                </Suspense>
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Source Bridge + Runtime</summary>
              <div className="rf-op14-grid2">
                <Suspense fallback={<Loader label="source bridge" />}>
                  <RFSourceBridgePanelV7 />
                </Suspense>

                <Suspense fallback={<Loader label="runtime probe" />}>
                  <RFSourceRuntimeProbeV8 />
                </Suspense>
              </div>
            </details>

            <details className="rf-op14-collapse">
              <summary>Bridge Readiness + Evidence Recorder</summary>
              <div className="rf-op14-grid2">
                <Suspense fallback={<Loader label="bridge readiness" />}>
                  <RFBridgeReadinessV9 />
                </Suspense>

                <Suspense fallback={<Loader label="evidence recorder" />}>
                  <RFEvidenceFlightRecorderV10 />
                </Suspense>
              </div>
            </details>
          </div>
        )}
      </div>
    </section>
  );
}
