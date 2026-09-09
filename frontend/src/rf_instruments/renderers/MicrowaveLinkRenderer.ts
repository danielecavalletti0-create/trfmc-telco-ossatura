export class MicrowaveLinkRenderer {
  draw(canvas: HTMLCanvasElement, t = 0) {
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

    ctx.strokeStyle = "rgba(0,229,255,.08)";
    for (let i = 0; i <= 14; i++) {
      const x = (w * i) / 14;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }

    const leftX = w * 0.18;
    const rightX = w * 0.82;
    const topY = h * 0.34;
    const baseY = h * 0.84;

    ctx.strokeStyle = "rgba(230,250,255,.75)";
    ctx.lineWidth = 4 * dpr;
    ctx.beginPath();
    ctx.moveTo(leftX, baseY);
    ctx.lineTo(leftX, topY);
    ctx.moveTo(rightX, baseY);
    ctx.lineTo(rightX, topY);
    ctx.stroke();

    ctx.fillStyle = "rgba(230,250,255,.92)";
    ctx.beginPath();
    ctx.ellipse(leftX + 42 * dpr, topY + 10 * dpr, 34 * dpr, 58 * dpr, -0.18, 0, Math.PI * 2);
    ctx.fill();

    ctx.beginPath();
    ctx.ellipse(rightX - 42 * dpr, topY + 10 * dpr, 34 * dpr, 58 * dpr, 0.18, 0, Math.PI * 2);
    ctx.fill();

    ctx.save();
    ctx.globalCompositeOperation = "lighter";

    for (let i = 0; i < 28; i++) {
      const k = i / 28;
      ctx.strokeStyle = `rgba(0,229,255,${0.035 * (1 - k)})`;
      ctx.lineWidth = (1 + k * 6) * dpr;
      ctx.beginPath();
      ctx.moveTo(leftX + 70 * dpr, topY + 8 * dpr);
      ctx.quadraticCurveTo(w * 0.50, h * (0.23 + 0.035 * Math.sin(t * 0.001 + k)), rightX - 70 * dpr, topY + 8 * dpr);
      ctx.stroke();
    }

    ctx.restore();

    ctx.strokeStyle = "rgba(255,209,102,.55)";
    ctx.setLineDash([8 * dpr, 8 * dpr]);
    ctx.beginPath();
    ctx.ellipse(w * 0.50, topY + 8 * dpr, w * 0.25, h * 0.11, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("MICROWAVE LINK · LOS · FRESNEL · FSPL · RSL · FADE MARGIN", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#7dffb2";
    ctx.fillText("18 GHz · 12.4 km · FSPL 139.4 dB · RSL -47.8 dBm · Fade Margin 27.1 dB", 14 * dpr, h - 18 * dpr);
  }
}
