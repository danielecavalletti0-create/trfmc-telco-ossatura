import React from "react";

import { RFInstrumentSuiteV9BridgeReadiness } from "./RFInstrumentSuiteV9BridgeReadiness";
import { RFEvidenceFlightRecorderV10 } from "../evidence/RFEvidenceFlightRecorderV10";

export function RFInstrumentSuiteV10EvidenceRecorder() {
  return (
    <section>
      <RFEvidenceFlightRecorderV10 />
      <RFInstrumentSuiteV9BridgeReadiness />
    </section>
  );
}
