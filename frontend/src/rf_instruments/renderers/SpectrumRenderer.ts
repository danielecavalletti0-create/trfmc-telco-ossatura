export type SpectrumTrace = {
  bins: Float32Array;
  maxHold?: Float32Array;
};

export function drawSpectrum(
  canvas: HTMLCanvasElement,
  trace: SpectrumTrace,
  label = "TRFMC TRUE SPECTRUM ANALYZER"
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

  ctx.clearRect(0, 0, w, h);

  const bg = ctx.createLinearGradient(0, 0, 0, h);
  bg.addColorStop(0, "#061827");
  bg.addColorStop(1, "#000307");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, w, h);

  ctx.strokeStyle = "rgba(0,229,255,.10)";
  ctx.lineWidth = 1 * dpr;

  for (let i = 0; i <= 12; i++) {
    const x = (w * i) / 12;
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, h);
    ctx.stroke();
  }

  for (let i = 0; i <= 8; i++) {
    const y = (h * i) / 8;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  if (trace.maxHold) {
    ctx.strokeStyle = "rgba(255,216,77,.55)";
    ctx.lineWidth = 1 * dpr;
    ctx.beginPath();

    trace.maxHold.forEach((v, i) => {
      const x = (w * i) / (trace.maxHold!.length - 1);
      const y = h * (0.88 - v * 0.72);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });

    ctx.stroke();
  }

  ctx.strokeStyle = "#00e5ff";
  ctx.lineWidth = 2 * dpr;
  ctx.beginPath();

  trace.bins.forEach((v, i) => {
    const x = (w * i) / (trace.bins.length - 1);
    const y = h * (0.88 - v * 0.72);
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  });

  ctx.stroke();

  ctx.fillStyle = "#eafbff";
  ctx.font = `${10 * dpr}px ui-monospace, Consolas, monospace`;
  ctx.fillText(label, 12 * dpr, 18 * dpr);

  ctx.fillStyle = "#78ff63";
  ctx.fillText("CENTER 2.440 GHz · SPAN 80 MHz · RBW 10 kHz · MAX HOLD ON", 12 * dpr, h - 12 * dpr);
}
