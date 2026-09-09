export class RFWaterfallRenderer {
  private rows: Float32Array[] = [];
  private maxRows = 180;

  push(trace: Float32Array) {
    this.rows.unshift(trace.slice());
    if (this.rows.length > this.maxRows) this.rows.pop();
  }

  draw(canvas: HTMLCanvasElement) {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.floor(canvas.clientWidth * dpr);
    const h = Math.floor(canvas.clientHeight * dpr);

    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const bg = ctx.createLinearGradient(0, 0, 0, h);
    bg.addColorStop(0, "#03060b");
    bg.addColorStop(0.3, "#04121f");
    bg.addColorStop(1, "#020a13");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    const rowH = Math.max(1, h / this.maxRows);

    for (let y = 0; y < this.rows.length; y++) {
      const row = this.rows[y];
      const alpha = 1 - y / this.maxRows;
      const offsetY = y * rowH;

      for (let x = 0; x < w; x++) {
        const idx = Math.floor((x / w) * (row.length - 1));
        const v = Math.max(0, Math.min(1, row[idx]));
        ctx.fillStyle = this.color(v, alpha);
        ctx.fillRect(x, offsetY, 1, Math.ceil(rowH));
      }
    }

    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.strokeStyle = "rgba(0,255,224,0.12)";
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(0, rowH * 1.5);
    ctx.lineTo(w, rowH * 1.5);
    ctx.stroke();
    ctx.restore();

    ctx.strokeStyle = "rgba(0,229,255,0.28)";
    ctx.lineWidth = 1.6;
    ctx.strokeRect(0, 0, w, h);

    ctx.fillStyle = "#b5f5ff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("WATERFALL · spectral persistence · carrier density", 14 * dpr, 18 * dpr);
  }

  private color(v: number, alpha: number) {
    const base = 0.15 + alpha * 0.70;
    if (v > 0.8) return `rgba(255,192,60,${base})`;
    if (v > 0.55) return `rgba(0,238,255,${base})`;
    if (v > 0.30) return `rgba(0,128,186,${base * 0.85})`;
    return `rgba(1,28,42,${base * 0.50})`;
  }
}
