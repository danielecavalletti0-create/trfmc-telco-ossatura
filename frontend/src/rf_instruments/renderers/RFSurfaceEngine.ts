export type RFTracePacket = {
  primary: Float32Array;
  maxHold?: Float32Array;
  average?: Float32Array;
};

type Marker = {
  index: number;
  label: string;
};

export class RFSurfaceEngine {
  private persistence: Float32Array[] = [];

  draw(
    canvas: HTMLCanvasElement,
    trace: RFTracePacket,
    markers: Marker[] = []
  ) {
    const dpr = Math.min(2, window.devicePixelRatio || 1);

    const w = Math.floor(canvas.clientWidth * dpr);
    const h = Math.floor(canvas.clientHeight * dpr);

    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    this.pushPersistence(trace.primary);

    ctx.clearRect(0, 0, w, h);

    this.drawBackground(ctx, w, h);
    this.drawGrid(ctx, w, h);
    this.drawPersistence(ctx, w, h);
    this.drawAverage(ctx, w, h, trace.average);
    this.drawMaxHold(ctx, w, h, trace.maxHold);
    this.drawPrimary(ctx, w, h, trace.primary);
    this.drawMarkers(ctx, w, h, trace.primary, markers);
    this.drawHUD(ctx, w, h);
  }

  private pushPersistence(trace: Float32Array) {
    this.persistence.push(trace.slice());

    if (this.persistence.length > 32) {
      this.persistence.shift();
    }
  }

  private drawBackground(ctx: CanvasRenderingContext2D, w: number, h: number) {
    const bg = ctx.createLinearGradient(0, 0, 0, h);

    bg.addColorStop(0, "#06131d");
    bg.addColorStop(.5, "#02060b");
    bg.addColorStop(1, "#000000");

    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    const glow = ctx.createRadialGradient(
      w * .75,
      h * .15,
      10,
      w * .75,
      h * .15,
      w * .6
    );

    glow.addColorStop(0, "rgba(0,229,255,.10)");
    glow.addColorStop(1, "transparent");

    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, w, h);
  }

  private drawGrid(ctx: CanvasRenderingContext2D, w: number, h: number) {
    ctx.strokeStyle = "rgba(0,229,255,.08)";
    ctx.lineWidth = 1;

    for (let i = 0; i <= 14; i++) {
      const x = (w * i) / 14;

      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }

    for (let i = 0; i <= 10; i++) {
      const y = (h * i) / 10;

      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
  }

  private drawPersistence(ctx: CanvasRenderingContext2D, w: number, h: number) {
    this.persistence.forEach((trace, age) => {
      const alpha = age / this.persistence.length;

      ctx.strokeStyle = `rgba(0,255,180,${alpha * .09})`;
      ctx.lineWidth = 1;

      ctx.beginPath();

      trace.forEach((v, i) => {
        const x = (w * i) / (trace.length - 1);
        const y = h * (0.90 - v * 0.74);

        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });

      ctx.stroke();
    });
  }

  private drawAverage(
    ctx: CanvasRenderingContext2D,
    w: number,
    h: number,
    trace?: Float32Array
  ) {
    if (!trace) return;

    ctx.strokeStyle = "rgba(120,255,99,.55)";
    ctx.lineWidth = 1.4;

    ctx.beginPath();

    trace.forEach((v, i) => {
      const x = (w * i) / (trace.length - 1);
      const y = h * (0.90 - v * 0.74);

      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });

    ctx.stroke();
  }

  private drawMaxHold(
    ctx: CanvasRenderingContext2D,
    w: number,
    h: number,
    trace?: Float32Array
  ) {
    if (!trace) return;

    ctx.strokeStyle = "rgba(255,210,80,.80)";
    ctx.lineWidth = 1.1;

    ctx.beginPath();

    trace.forEach((v, i) => {
      const x = (w * i) / (trace.length - 1);
      const y = h * (0.90 - v * 0.74);

      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });

    ctx.stroke();
  }

  private drawPrimary(
    ctx: CanvasRenderingContext2D,
    w: number,
    h: number,
    trace: Float32Array
  ) {
    ctx.shadowColor = "#00e5ff";
    ctx.shadowBlur = 18;

    ctx.strokeStyle = "#00e5ff";
    ctx.lineWidth = 2.2;

    ctx.beginPath();

    trace.forEach((v, i) => {
      const x = (w * i) / (trace.length - 1);
      const y = h * (0.90 - v * 0.74);

      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });

    ctx.stroke();

    ctx.shadowBlur = 0;
  }

  private drawMarkers(
    ctx: CanvasRenderingContext2D,
    w: number,
    h: number,
    trace: Float32Array,
    markers: Marker[]
  ) {
    ctx.font = "11px JetBrains Mono, monospace";

    markers.forEach((m) => {
      const x = (w * m.index) / (trace.length - 1);
      const y = h * (0.90 - trace[m.index] * 0.74);

      ctx.strokeStyle = "#ff4fa3";

      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();

      ctx.fillStyle = "#ff4fa3";
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = "#ffffff";
      ctx.fillText(m.label, x + 8, y - 8);
    });
  }

  private drawHUD(ctx: CanvasRenderingContext2D, w: number, h: number) {
    ctx.fillStyle = "rgba(0,0,0,.48)";
    ctx.fillRect(10, 10, 310, 92);

    ctx.strokeStyle = "rgba(0,229,255,.25)";
    ctx.strokeRect(10, 10, 310, 92);

    ctx.fillStyle = "#00e5ff";
    ctx.font = "12px JetBrains Mono, monospace";

    const lines = [
      "CENTER 2.440 GHz",
      "SPAN 80 MHz",
      "RBW 10 kHz",
      "VBW 30 kHz",
      "REF -10 dBm",
      "ATT 10 dB",
      "TRACE 3 / MAX HOLD",
      "FFT 4096"
    ];

    lines.forEach((line, i) => {
      ctx.fillText(line, 20, 28 + i * 10);
    });

    ctx.fillStyle = "#78ff63";
    ctx.fillText("TRFMC RF SURFACE ENGINE V1", w - 290, h - 16);
  }
}
