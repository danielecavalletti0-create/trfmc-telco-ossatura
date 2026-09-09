import type { RFSourceAdapter, RFSourceFrameHandler } from "./RFSourceAdapter";
import { nowFrameMeta } from "./RFSourceAdapter";
import type { RFSourceHealth } from "./RFSourceTypes";

export class WebSocketIQSourceAdapter implements RFSourceAdapter {
  readonly mode = "websocket_iq" as const;

  private ws: WebSocket | null = null;
  private handler: RFSourceFrameHandler | null = null;
  private frames = 0;
  private drops = 0;
  private status: RFSourceHealth["status"] = "standby";
  private message = "Prepared. Not connected.";

  constructor(private endpoint: string) {}

  async connect() {
    if (this.ws) return;

    this.status = "connected";
    this.message = `Connecting to ${this.endpoint}`;

    this.ws = new WebSocket(this.endpoint);
    this.ws.binaryType = "arraybuffer";

    this.ws.onopen = () => {
      this.status = "streaming";
      this.message = "Binary IQ WebSocket connected.";
    };

    this.ws.onmessage = (ev) => {
      if (ev.data instanceof ArrayBuffer) {
        this.handler?.(
          ev.data,
          nowFrameMeta(this.mode, this.frames, {
            bytes: ev.data.byteLength,
            format: "arraybuffer"
          })
        );
        this.frames++;
      } else {
        this.drops++;
      }
    };

    this.ws.onerror = () => {
      this.status = "error";
      this.message = "WebSocket IQ error.";
    };

    this.ws.onclose = () => {
      this.status = "standby";
      this.message = "WebSocket IQ closed.";
      this.ws = null;
    };
  }

  disconnect() {
    this.ws?.close();
    this.ws = null;
    this.status = "standby";
    this.message = "Disconnected.";
  }

  onFrame(handler: RFSourceFrameHandler) {
    this.handler = handler;
  }

  getHealth(): RFSourceHealth {
    return {
      mode: this.mode,
      status: this.status,
      frames: this.frames,
      drops: this.drops,
      message: this.message
    };
  }
}
