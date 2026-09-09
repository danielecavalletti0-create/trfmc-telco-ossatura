import React from "react";

import { RFOperationalDeckV15Lazy } from "./RFOperationalDeckV15Lazy";
import { RFChunkObservatoryV16 } from "../telemetry/RFChunkObservatoryV16";

export function RFOperationalDeckV16ChunkObservatory() {
  return (
    <section>
      <RFChunkObservatoryV16 />
      <RFOperationalDeckV15Lazy />
    </section>
  );
}
