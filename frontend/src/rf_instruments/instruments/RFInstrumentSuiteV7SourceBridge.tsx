import React from "react";

import { RFInstrumentSuiteV6TurboSafe } from "./RFInstrumentSuiteV6TurboSafe";
import { RFSourceBridgePanelV7 } from "../sources/RFSourceBridgePanelV7";

export function RFInstrumentSuiteV7SourceBridge() {
  return (
    <section>
      <RFSourceBridgePanelV7 />
      <RFInstrumentSuiteV6TurboSafe />
    </section>
  );
}
