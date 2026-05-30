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

    ctx.fillStyle = "#00050a";
    ctx.fillRect(0, 0, w, h);

    const rowH = Math.max(1, h / this.maxRows);

    for (let y = 0; y < this.rows.length; y++) {
      const row = this.rows[y];
      const alpha = 1 - y / this.maxRows;

      for (let x = 0; x < w; x++) {
        const idx = Math.floor((x / w) * (row.length - 1));
        const v = Math.max(0, Math.min(1, row[idx]));
        const c = this.color(v, alpha);
        ctx.fillStyle = c;
        ctx.fillRect(x, y * rowH, 1, Math.ceil(rowH));
      }
    }

    ctx.strokeStyle = "rgba(0,229,255,.22)";
    ctx.strokeRect(0, 0, w, h);

    ctx.fillStyle = "#00e5ff";
    ctx.font = `${10 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("DENSE PERSISTENT WATERFALL · spectral memory · burst occupancy", 12 * dpr, 18 * dpr);
  }

  private color(v: number, alpha: number) {
    const a = 0.10 + alpha * 0.80;

    if (v > 0.70) return `rgba(255,216,77,${a})`;
    if (v > 0.46) return `rgba(0,229,255,${a})`;
    if (v > 0.25) return `rgba(0,120,180,${a * 0.75})`;
    return `rgba(0,36,64,${a * 0.45})`;
  }
}
