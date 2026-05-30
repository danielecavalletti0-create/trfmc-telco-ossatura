import type { RFBridgeFrameMeta, RFSourceHealth, RFSourceMode } from "./RFSourceTypes";

export type RFSourceFrameHandler = (payload: ArrayBuffer | Float32Array | unknown, meta: RFBridgeFrameMeta) => void;

export interface RFSourceAdapter {
  readonly mode: RFSourceMode;
  connect(): Promise<void>;
  disconnect(): void;
  onFrame(handler: RFSourceFrameHandler): void;
  getHealth(): RFSourceHealth;
}

export function nowFrameMeta(mode: RFSourceMode, sequence: number, extra: Partial<RFBridgeFrameMeta> = {}): RFBridgeFrameMeta {
  return {
    source: mode,
    timestamp: Date.now(),
    sequence,
    ...extra
  };
}
