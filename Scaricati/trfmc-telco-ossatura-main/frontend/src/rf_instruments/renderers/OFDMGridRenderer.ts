export class OFDMGridRenderer {
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

    const cols = 48;
    const rows = 18;
    const padX = 18 * dpr;
    const padY = 42 * dpr;
    const cellW = (w - padX * 2) / cols;
    const cellH = (h - padY * 1.7) / rows;

    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const ssb = x >= 3 && x <= 8 && y >= 6 && y <= 11;
        const prach = x >= 38 && x <= 44 && y >= 1 && y <= 4;
        const pdcch = y <= 1 && x > 10 && x < 36;
        const pdsch = !ssb && !prach && !pdcch && Math.sin(x * 0.7 + y * 0.31 + t * 0.004) > -0.15;

        if (ssb) ctx.fillStyle = "rgba(255,209,102,.92)";
        else if (prach) ctx.fillStyle = "rgba(255,95,122,.78)";
        else if (pdcch) ctx.fillStyle = "rgba(125,255,178,.72)";
        else if (pdsch) ctx.fillStyle = "rgba(0,229,255,.45)";
        else ctx.fillStyle = "rgba(0,70,110,.18)";

        ctx.fillRect(padX + x * cellW + 1, padY + y * cellH + 1, Math.max(1, cellW - 2), Math.max(1, cellH - 2));
      }
    }

    ctx.strokeStyle = "rgba(0,229,255,.18)";
    ctx.strokeRect(padX, padY, cellW * cols, cellH * rows);

    ctx.fillStyle = "#eafbff";
    ctx.font = `${11 * dpr}px ui-monospace, Consolas, monospace`;
    ctx.fillText("5G NR OFDM RESOURCE GRID · SSB · PDCCH · PDSCH · PRACH", 14 * dpr, 22 * dpr);

    ctx.fillStyle = "#ffd166";
    ctx.fillText("μ=1 · SCS 30 kHz · 48 RB view · synthetic allocation map", 14 * dpr, h - 18 * dpr);
  }
}
