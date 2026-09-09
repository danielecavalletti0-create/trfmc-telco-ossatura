export class AntennaPatternRenderer {
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

    const cx = w * 0.50;
    const cy = h * 0.54;
    const r = Math.min(w, h) * 0.36;

    ctx.strokeStyle = "rgba(0,229,255,.13)";
    ctx.lineWidth = 1;

    for (let k = 1; k <= 5; k++) {
      ctx.beginPath();
      ctx.arc(cx, cy, (r * k) / 5, 0, Math.PI * 2);
      ctx.stroke();
    }

    for (let a = 0; a < 360; a += 15) {
      const rad = (a * Math.PI) / 180;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + Math.cos(rad) * r, cy + Math.sin(rad) * r);
      ctx.stroke();
    }

    const steer = Math.sin(t * 0.0008) * 0.65;

    ctx.shadowColor = "#00e5ff";
    ctx.shadowBlur = 16;
    ctx.strokeStyle = "#00e5ff";
    ctx.lineWidth = 2.4;
    ctx.beginPath();

    for (let i = 0; i <= 720; i++) {
      const a = (i / 720) * Math.PI * 2;
      const main = Math.pow(Math.max(0, Math.cos(a - steer)), 10);
      const back = 0.18 * Math.pow(Math.max(0, Math.cos(a - steer + Math.PI)), 4);
      const side = 0.10 + 0.09 * Math.abs(Math.sin(4 * a + t * 0.001));
      const gain = Math.max(side, main + back);
      const rr = r * (0.18 + 0.82 * gain);
      const x = cx + Math.cos(a) * rr;
      const y = cy + Math.sin(a) * rr;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }

    ctx.closePath();
    ctx.stroke();
    ctx.shadowBlur = 0;

    ctx.strokeStyle = "#ffd166";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(steer) * r * 1.05, cy + Math.sin(steer) * r * 1.05);
    ctx.stroke();

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("ANTENNA PATTERN · ARRAY FACTOR · BEAM STEERING · SIDE LOBES", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#7dffb2";
    ctx.fillText(`θ steer ${(steer * 180 / Math.PI).toFixed(1)}° · Gain 17.4 dBi · SLL -13.2 dB`, 14 * dpr, h - 18 * dpr);
  }
}
