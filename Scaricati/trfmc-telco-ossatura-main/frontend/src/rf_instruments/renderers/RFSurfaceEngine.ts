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
    this.drawAreaFill(ctx, w, h, trace.primary);
    this.drawAverage(ctx, w, h, trace.average);
    this.drawMaxHold(ctx, w, h, trace.maxHold);
    this.drawPrimary(ctx, w, h, trace.primary);
    this.drawMarkers(ctx, w, h, trace.primary, markers);
    this.drawHUD(ctx, w, h);
  }

  private pushPersistence(trace: Float32Array) {
    this.persistence.push(trace.slice());
    if (this.persistence.length > 28) this.persistence.shift();
  }

  private drawBackground(ctx: CanvasRenderingContext2D, w: number, h: number) {
    const bg = ctx.createLinearGradient(0, 0, 0, h);
    bg.addColorStop(0, "#050b14");
    bg.addColorStop(0.45, "#04101c");
    bg.addColorStop(1, "#000004");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    const glowLeft = ctx.createRadialGradient(w * 0.14, h * 0.18, 10, w * 0.14, h * 0.18, w * 0.4);
    glowLeft.addColorStop(0, "rgba(0, 255, 218, 0.10)");
    glowLeft.addColorStop(1, "transparent");
    ctx.fillStyle = glowLeft;
    ctx.fillRect(0, 0, w, h);

    const glowRight = ctx.createRadialGradient(w * 0.85, h * 0.10, 8, w * 0.85, h * 0.10, w * 0.25);
    glowRight.addColorStop(0, "rgba(255, 102, 204, 0.08)");
    glowRight.addColorStop(1, "transparent");
    ctx.fillStyle = glowRight;
    ctx.fillRect(0, 0, w, h);
  }

  private drawGrid(ctx: CanvasRenderingContext2D, w: number, h: number) {
    ctx.strokeStyle = "rgba(0,229,255,0.08)";
    ctx.lineWidth = 1;

    for (let i = 0; i <= 16; i++) {
      const x = (w * i) / 16;
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

    ctx.strokeStyle = "rgba(0,229,255,0.16)";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(0, h * 0.90);
    ctx.lineTo(w, h * 0.90);
    ctx.stroke();
  }

  private drawPersistence(ctx: CanvasRenderingContext2D, w: number, h: number) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";

    this.persistence.forEach((trace, age) => {
      const alpha = Math.pow(age / this.persistence.length, 1.15) * 0.08;
      ctx.strokeStyle = `rgba(0,255,192,${alpha})`;
      ctx.lineWidth = 1.2;
      ctx.beginPath();

      trace.forEach((v, i) => {
        const x = (w * i) / (trace.length - 1);
        const y = h * (0.90 - v * 0.72);
        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });

      ctx.stroke();
    });

    ctx.restore();
  }

  private drawAreaFill(ctx: CanvasRenderingContext2D, w: number, h: number, trace: Float32Array) {
    const gradient = ctx.createLinearGradient(0, h * 0.32, 0, h);
    gradient.addColorStop(0, "rgba(0,229,255,0.24)");
    gradient.addColorStop(1, "rgba(0,229,255,0.02)");

    ctx.fillStyle = gradient;
    ctx.beginPath();

    trace.forEach((v, i) => {
      const x = (w * i) / (trace.length - 1);
      const y = h * (0.90 - v * 0.72);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });

    ctx.lineTo(w, h * 0.90);
    ctx.lineTo(0, h * 0.90);
    ctx.closePath();
    ctx.fill();
  }

  private drawAverage(
    ctx: CanvasRenderingContext2D,
    w: number,
    h: number,
    trace?: Float32Array
  ) {
    if (!trace) return;

    ctx.strokeStyle = "rgba(120,255,99,0.55)";
    ctx.lineWidth = 1.4;
    ctx.setLineDash([6, 6]);
    ctx.beginPath();

    trace.forEach((v, i) => {
      const x = (w * i) / (trace.length - 1);
      const y = h * (0.90 - v * 0.72);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });

    ctx.stroke();
    ctx.setLineDash([]);
  }

  private drawMaxHold(
    ctx: CanvasRenderingContext2D,
    w: number,
    h: number,
    trace?: Float32Array
  ) {
    if (!trace) return;

    ctx.strokeStyle = "rgba(255,210,80,0.82)";
    ctx.lineWidth = 1.2;
    ctx.beginPath();

    trace.forEach((v, i) => {
      const x = (w * i) / (trace.length - 1);
      const y = h * (0.90 - v * 0.72);
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
    ctx.save();
    ctx.shadowColor = "rgba(0,229,255,0.85)";
    ctx.shadowBlur = 20;
    ctx.strokeStyle = "#00e5ff";
    ctx.lineWidth = 2.8;
    ctx.beginPath();

    trace.forEach((v, i) => {
      const x = (w * i) / (trace.length - 1);
      const y = h * (0.90 - v * 0.72);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });

    ctx.stroke();
    ctx.restore();
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
      const y = h * (0.90 - trace[m.index] * 0.72);

      ctx.strokeStyle = "rgba(255,95,122,0.75)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();

      ctx.fillStyle = "rgba(255,95,122,0.95)";
      ctx.beginPath();
      ctx.arc(x, y, 5, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = "rgba(255,255,255,0.96)";
      ctx.fillText(m.label, x + 10, Math.max(18, y - 10));
    });
  }

  private drawHUD(ctx: CanvasRenderingContext2D, w: number, h: number) {
    ctx.fillStyle = "rgba(0,0,0,0.52)";
    ctx.fillRect(12, 12, 320, 84);
    ctx.strokeStyle = "rgba(0,229,255,0.26)";
    ctx.strokeRect(12, 12, 320, 84);

    ctx.fillStyle = "#00e5ff";
    ctx.font = "12px JetBrains Mono, monospace";
    const lines = [
      "CENTER 2.440 GHz",
      "SPAN 80 MHz · RBW 10 kHz · VBW 30 kHz",
      "TRACE 3 / MAX HOLD / AVERAGE",
      "FFT 4096 · SDR/SDP signal chain",
      "REAL-TIME RX GRAPHICS · SOFTWARE-DEFINED LAB"
    ];
    lines.forEach((line, i) => ctx.fillText(line, 22, 28 + i * 14));

    ctx.fillStyle = "#7dffb2";
    ctx.fillText("TRFMC TRUDECK RF SURFACE ENGINE", w - 318, h - 18);
  }
}
