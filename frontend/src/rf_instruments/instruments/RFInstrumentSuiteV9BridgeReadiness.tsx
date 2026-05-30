import React from "react";

import { RFInstrumentSuiteV8SourceRuntime } from "./RFInstrumentSuiteV8SourceRuntime";
import { RFBridgeReadinessV9 } from "../telemetry/RFBridgeReadinessV9";

export function RFInstrumentSuiteV9BridgeReadiness() {
  return (
    <section>
      <RFBridgeReadinessV9 />
      <RFInstrumentSuiteV8SourceRuntime />
    </section>
  );
}
