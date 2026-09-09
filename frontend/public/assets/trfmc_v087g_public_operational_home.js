(function () {
  "use strict";

  const root = document.querySelector('[data-trfmc-page="v87g-public-home"]');
  if (!root) return;

  const missionRoutes = [
    {
      title: "RF Physics Console",
      tag: "P0 · RF Physics",
      href: "/rf_physics_sapienza_console_v86a.html",
      text: "Console fisica del segnale, propagazione, componenti RF e analisi ingegneristica."
    },
    {
      title: "Stable RF Field",
      tag: "P0 · RF Baseline",
      href: "/webgl_rf_physics_engine_v85e_viewport_discipline.html",
      text: "Viewport stabile per campo RF, propagazione e disciplina visuale WebGL."
    },
    {
      title: "Infrastructure Digital Twin",
      tag: "P1 · Infrastructure",
      href: "/infrastructure_digital_twin_v63.html",
      text: "Modello infrastrutturale per siti, shelter, energia, rete e apparati."
    },
    {
      title: "Handover Dynamics",
      tag: "P1 · Mobility",
      href: "/webgl_rf_heatmap_engine_v69.html",
      text: "Simulazione mobilità, copertura e dinamiche di handover tra celle."
    },
    {
      title: "Vegetation / Clutter Lab",
      tag: "P2 · RF Visualization",
      href: "/webgl_rf_heatmap_engine_v68_surgical_v81.html",
      text: "Analisi visuale clutter, attenuazione, vegetazione e ostacoli."
    },
    {
      title: "Theory Spine",
      tag: "P0 · Academy",
      href: "/trfmc_theory_spine_v86e.html",
      text: "Struttura teorica: Maxwell, Fourier, IQ, modulazioni, OFDM e misure."
    }
  ];

  const routeGrid = document.getElementById("g87-route-grid");
  const routeCount = document.getElementById("g87-route-count");
  const coreState = document.getElementById("g87-core-state");
  const clock = document.getElementById("g87-clock");

  if (routeCount) routeCount.textContent = String(missionRoutes.length);

  if (routeGrid) {
    routeGrid.innerHTML = "";
    missionRoutes.forEach((route) => {
      const a = document.createElement("a");
      a.className = "g87-route-card";
      a.href = route.href;
      a.innerHTML = [
        "<strong>" + route.title + "</strong>",
        "<span>" + route.text + "</span>",
        "<em data-route-status=\"pending\">" + route.tag + " · CHECK</em>"
      ].join("");
      routeGrid.appendChild(a);

      const badge = a.querySelector("[data-route-status]");
      fetch(route.href, { method: "HEAD", cache: "no-store" })
        .then((res) => {
          badge.textContent = route.tag + " · " + (res.ok ? "ONLINE" : "HTTP " + res.status);
          badge.style.color = res.ok ? "#8effcf" : "#ffd27d";
        })
        .catch(() => {
          badge.textContent = route.tag + " · VERIFY";
          badge.style.color = "#ffd27d";
        });
    });
  }

  function tickClock() {
    if (!clock) return;
    const now = new Date();
    clock.textContent = now.toLocaleTimeString("it-IT", { hour12: false });
  }
  tickClock();
  setInterval(tickClock, 1000);

  fetch("/api/health", { cache: "no-store" })
    .then((res) => {
      if (coreState) {
        coreState.textContent = res.ok ? "ONLINE" : "HTTP " + res.status;
        coreState.style.color = res.ok ? "#8effcf" : "#ffd27d";
      }
    })
    .catch(() => {
      if (coreState) {
        coreState.textContent = "OFFLINE";
        coreState.style.color = "#ff9a9a";
      }
    });

  const bgCanvas = root.querySelector(".g87-canvas");
  const spectrumCanvas = root.querySelector(".g87-spectrum");
  const bgCtx = bgCanvas ? bgCanvas.getContext("2d") : null;
  const spCtx = spectrumCanvas ? spectrumCanvas.getContext("2d") : null;

  function sizeCanvas(canvas) {
    const rect = canvas.getBoundingClientRect();
    const ratio = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.floor(rect.width * ratio));
    canvas.height = Math.max(1, Math.floor(rect.height * ratio));
    return { w: canvas.width, h: canvas.height, r: ratio };
  }

  let bgSize = bgCanvas ? sizeCanvas(bgCanvas) : null;
  let spSize = spectrumCanvas ? sizeCanvas(spectrumCanvas) : null;

  window.addEventListener("resize", () => {
    if (bgCanvas) bgSize = sizeCanvas(bgCanvas);
    if (spectrumCanvas) spSize = sizeCanvas(spectrumCanvas);
  });

  function drawBackground(t) {
    if (!bgCtx || !bgSize) return;
    const w = bgSize.w;
    const h = bgSize.h;
    bgCtx.clearRect(0, 0, w, h);

    bgCtx.globalAlpha = 0.22;
    bgCtx.strokeStyle = "rgba(105,225,255,.28)";
    bgCtx.lineWidth = 1;

    const step = Math.max(42, Math.floor(w / 28));
    const shift = (t * 0.025) % step;

    for (let x = -step; x < w + step; x += step) {
      bgCtx.beginPath();
      bgCtx.moveTo(x + shift, 0);
      bgCtx.lineTo(x - shift * 0.4, h);
      bgCtx.stroke();
    }

    for (let y = -step; y < h + step; y += step) {
      bgCtx.beginPath();
      bgCtx.moveTo(0, y + shift);
      bgCtx.lineTo(w, y - shift * 0.3);
      bgCtx.stroke();
    }

    bgCtx.globalAlpha = 0.9;
    for (let i = 0; i < 18; i++) {
      const px = (Math.sin(t * 0.0007 + i * 1.7) * 0.5 + 0.5) * w;
      const py = (Math.cos(t * 0.0009 + i * 1.1) * 0.5 + 0.5) * h;
      const rad = 1.5 + (i % 5);
      const g = bgCtx.createRadialGradient(px, py, 0, px, py, rad * 14);
      g.addColorStop(0, "rgba(90,247,255,.28)");
      g.addColorStop(1, "rgba(90,247,255,0)");
      bgCtx.fillStyle = g;
      bgCtx.beginPath();
      bgCtx.arc(px, py, rad * 14, 0, Math.PI * 2);
      bgCtx.fill();
    }
  }

  function drawSpectrum(t) {
    if (!spCtx || !spSize) return;
    const w = spSize.w;
    const h = spSize.h;
    spCtx.clearRect(0, 0, w, h);

    const grad = spCtx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, "rgba(6,24,44,.96)");
    grad.addColorStop(1, "rgba(1,5,14,.96)");
    spCtx.fillStyle = grad;
    spCtx.fillRect(0, 0, w, h);

    spCtx.strokeStyle = "rgba(118,229,255,.12)";
    spCtx.lineWidth = 1;
    for (let i = 1; i < 8; i++) {
      const y = (h / 8) * i;
      spCtx.beginPath();
      spCtx.moveTo(0, y);
      spCtx.lineTo(w, y);
      spCtx.stroke();
    }

    const bins = 96;
    const barW = w / bins;
    for (let i = 0; i < bins; i++) {
      const f1 = Math.sin(i * 0.17 + t * 0.003);
      const f2 = Math.cos(i * 0.071 - t * 0.0022);
      const peak = Math.exp(-Math.pow((i - 30 - Math.sin(t * 0.001) * 8) / 7, 2)) * 0.78;
      const peak2 = Math.exp(-Math.pow((i - 67 - Math.cos(t * 0.0013) * 10) / 9, 2)) * 0.64;
      const noise = 0.18 + Math.abs(f1 * f2) * 0.22;
      const amp = Math.min(0.95, noise + peak + peak2);
      const bh = amp * h * 0.82;
      const x = i * barW;
      const y = h - bh;

      const barGrad = spCtx.createLinearGradient(0, y, 0, h);
      barGrad.addColorStop(0, "rgba(142,255,207,.95)");
      barGrad.addColorStop(0.42, "rgba(90,247,255,.72)");
      barGrad.addColorStop(1, "rgba(72,115,255,.10)");
      spCtx.fillStyle = barGrad;
      spCtx.fillRect(x + 1, y, Math.max(1, barW - 2), bh);
    }

    spCtx.strokeStyle = "rgba(255,255,255,.22)";
    spCtx.beginPath();
    for (let i = 0; i < bins; i++) {
      const x = i * barW + barW / 2;
      const y = h * 0.5 + Math.sin(i * 0.22 + t * 0.004) * h * 0.09;
      if (i === 0) spCtx.moveTo(x, y);
      else spCtx.lineTo(x, y);
    }
    spCtx.stroke();
  }

  function frame(t) {
    drawBackground(t);
    drawSpectrum(t);
    requestAnimationFrame(frame);
  }

  requestAnimationFrame(frame);
})();
