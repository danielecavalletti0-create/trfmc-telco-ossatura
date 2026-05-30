export type IQPoint = {
  i: number;
  q: number;
  err?: number;
};

export class IQConstellationRenderer {
  draw(canvas: HTMLCanvasElement, points: IQPoint[]) {
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

    ctx.strokeStyle = "rgba(0,229,255,.12)";
    ctx.lineWidth = 1;

    for (let i = 0; i <= 8; i++) {
      const x = (w * i) / 8;
      const y = (h * i) / 8;

      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(0,229,255,.40)";
    ctx.beginPath();
    ctx.moveTo(w / 2, 0);
    ctx.lineTo(w / 2, h);
    ctx.moveTo(0, h / 2);
    ctx.lineTo(w, h / 2);
    ctx.stroke();

    for (const p of points) {
      const x = w / 2 + p.i * w * 0.34;
      const y = h / 2 - p.q * h * 0.34;
      const e = p.err ?? 0;

      ctx.fillStyle = e > 0.12 ? "#ff5f7a" : "#00e5ff";
      ctx.shadowColor = e > 0.12 ? "#ff5f7a" : "#00e5ff";
      ctx.shadowBlur = 12;
      ctx.beginPath();
      ctx.arc(x, y, 3 * dpr, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;

      if (e > 0.08) {
        ctx.strokeStyle = "rgba(255,95,122,.42)";
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(w / 2 + Math.sign(p.i) * w * 0.24, h / 2 - Math.sign(p.q) * h * 0.24);
        ctx.stroke();
      }
    }

    ctx.fillStyle = "#00e5ff";
    ctx.font = `${10 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("I/Q CONSTELLATION · EVM vectors · QPSK/OFDM evidence", 12 * dpr, 18 * dpr);
  }
}
