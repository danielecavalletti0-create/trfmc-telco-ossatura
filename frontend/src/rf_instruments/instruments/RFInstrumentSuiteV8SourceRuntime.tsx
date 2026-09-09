import React from "react";

import { RFInstrumentSuiteV7SourceBridge } from "./RFInstrumentSuiteV7SourceBridge";
import { RFSourceRuntimeProbeV8 } from "../sources/RFSourceRuntimeProbeV8";

export function RFInstrumentSuiteV8SourceRuntime() {
  return (
    <section>
      <RFSourceRuntimeProbeV8 />
      <RFInstrumentSuiteV7SourceBridge />
    </section>
  );
}
