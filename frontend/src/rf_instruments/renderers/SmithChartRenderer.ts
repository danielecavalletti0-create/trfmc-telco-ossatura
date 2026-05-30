export class SmithChartRenderer {
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

    const cx = w * 0.48;
    const cy = h * 0.52;
    const r = Math.min(w, h) * 0.38;

    ctx.strokeStyle = "rgba(0,229,255,.16)";
    ctx.lineWidth = 1;

    for (let i = 1; i <= 8; i++) {
      ctx.beginPath();
      ctx.arc(cx + (r * i) / 8, cy, r * (1 - i / 8), 0, Math.PI * 2);
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(cx - (r * i) / 8, cy, r * (1 - i / 8), 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(255,255,255,.60)";
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.stroke();

    ctx.strokeStyle = "rgba(0,229,255,.30)";
    ctx.beginPath();
    ctx.moveTo(cx - r, cy);
    ctx.lineTo(cx + r, cy);
    ctx.moveTo(cx, cy - r);
    ctx.lineTo(cx, cy + r);
    ctx.stroke();

    ctx.shadowColor = "#00e5ff";
    ctx.shadowBlur = 14;
    ctx.strokeStyle = "#00e5ff";
    ctx.lineWidth = 2.2;
    ctx.beginPath();

    for (let i = 0; i < 260; i++) {
      const k = i / 259;
      const a = -2.35 + k * 4.4 + 0.18 * Math.sin(t * 0.001);
      const rho = 0.18 + 0.60 * k + 0.045 * Math.sin(k * 18 + t * 0.002);
      const x = cx + Math.cos(a) * r * rho;
      const y = cy + Math.sin(a) * r * rho;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }

    ctx.stroke();
    ctx.shadowBlur = 0;

    const gamma = 0.42 + 0.06 * Math.sin(t * 0.001);
    const angle = 0.9 + 0.3 * Math.cos(t * 0.001);
    const gx = cx + Math.cos(angle) * r * gamma;
    const gy = cy + Math.sin(angle) * r * gamma;

    ctx.fillStyle = "#ffd166";
    ctx.beginPath();
    ctx.arc(gx, gy, 6 * dpr, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("VNA / SMITH CHART · S11 · Γ · VSWR · RETURN LOSS", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#7dffb2";
    ctx.fillText("Γ≈0.42∠52° · VSWR≈2.45 · RL≈7.5 dB · ML≈0.84 dB", 14 * dpr, h - 18 * dpr);
  }
}
