import type { RFSourceAdapter, RFSourceFrameHandler } from "./RFSourceAdapter";
import { nowFrameMeta } from "./RFSourceAdapter";
import type { RFSourceHealth } from "./RFSourceTypes";

export class SyntheticRFSourceAdapter implements RFSourceAdapter {
  readonly mode = "synthetic" as const;

  private handler: RFSourceFrameHandler | null = null;
  private timer: number | null = null;
  private frames = 0;

  async connect() {
    if (this.timer !== null) return;

    this.timer = window.setInterval(() => {
      const bins = new Float32Array(1024);

      for (let i = 0; i < bins.length; i++) {
        const f = i / (bins.length - 1);
        bins[i] =
          0.07 +
          0.02 * Math.sin(i * 0.03 + this.frames * 0.1) +
          0.35 * Math.exp(-Math.pow((f - 0.50) / 0.015, 2));
      }

      this.handler?.(
        bins,
        nowFrameMeta(this.mode, this.frames, {
          sampleRate: 122_880_000,
          centerFrequency: 2_440_000_000,
          format: "float32_spectrum"
        })
      );

      this.frames++;
    }, 100);
  }

  disconnect() {
    if (this.timer !== null) {
      window.clearInterval(this.timer);
      this.timer = null;
    }
  }

  onFrame(handler: RFSourceFrameHandler) {
    this.handler = handler;
  }

  getHealth(): RFSourceHealth {
    return {
      mode: this.mode,
      status: this.timer === null ? "ready" : "streaming",
      frames: this.frames,
      drops: 0,
      message: "Synthetic source adapter prepared."
    };
  }
}
