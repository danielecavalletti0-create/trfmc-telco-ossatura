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

    const bg = ctx.createRadialGradient(w * 0.45, h * 0.35, 10, w * 0.45, h * 0.35, Math.max(w, h) * 0.75);
    bg.addColorStop(0, "rgba(0, 22, 38, 0.95)");
    bg.addColorStop(0.45, "rgba(0, 14, 25, 0.95)");
    bg.addColorStop(1, "#02070f");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    const centerX = w / 2;
    const centerY = h / 2;
    const radius = Math.min(w, h) * 0.35;

    ctx.strokeStyle = "rgba(0,229,255,0.14)";
    ctx.lineWidth = 1;
    for (let ring = 1; ring <= 4; ring++) {
      ctx.beginPath();
      ctx.arc(centerX, centerY, radius * (ring / 4), 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(0,229,255,0.22)";
    ctx.beginPath();
    ctx.moveTo(centerX - radius, centerY);
    ctx.lineTo(centerX + radius, centerY);
    ctx.moveTo(centerX, centerY - radius);
    ctx.lineTo(centerX, centerY + radius);
    ctx.stroke();

    ctx.strokeStyle = "rgba(108, 255, 227, 0.18)";
    ctx.lineWidth = 0.9;
    for (let i = 0; i < 8; i++) {
      const angle = (Math.PI * 2 * i) / 8;
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.lineTo(centerX + Math.cos(angle) * radius, centerY + Math.sin(angle) * radius);
      ctx.stroke();
    }

    points.forEach((p) => {
      const x = centerX + p.i * radius * 0.86;
      const y = centerY - p.q * radius * 0.86;
      const hue = p.err && p.err > 0.12 ? 358 : 183;
      const color = p.err && p.err > 0.12 ? "rgba(255,95,122,0.98)" : "rgba(0,229,255,0.98)";

      ctx.save();
      ctx.shadowColor = color;
      ctx.shadowBlur = 18;
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(x, y, 3.8 * dpr, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();

      if ((p.err ?? 0) > 0.08) {
        ctx.strokeStyle = "rgba(255,95,122,0.42)";
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.moveTo(centerX, centerY);
        ctx.lineTo(x, y);
        ctx.stroke();
      }
    });

    ctx.fillStyle = "rgba(181, 245, 255, 0.95)";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("IQ CONSTELLATION · 16-QAM / EVM · rx symbol field", 16 * dpr, 22 * dpr);

    ctx.fillStyle = "rgba(255,255,255,0.82)";
    ctx.font = `${10 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("REFERENCE GRID · 45° IQ POLARITY · SIGNAL INTEGRITY", 16 * dpr, 38 * dpr);
  }
}
