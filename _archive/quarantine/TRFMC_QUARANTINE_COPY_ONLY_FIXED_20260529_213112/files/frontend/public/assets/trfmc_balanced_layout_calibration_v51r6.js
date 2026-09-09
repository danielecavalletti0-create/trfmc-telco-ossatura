(() => {
  const VERSION = "V51R6";

  function boot() {
    document.documentElement.dataset.trfmcV51r6 = "balanced-layout-calibration";
    if (!document.body) return;

    document.body.classList.remove("trfmc-v51r5-rescue-active");
    document.body.classList.add("trfmc-v51r6-balanced");
    document.body.dataset.trfmcLayoutCalibration = VERSION;

    removeOldBlocks();
    removeOldInlineOverscale();
    setBalancedWidths();
    markMenuTitles();
    markReady();
  }

  function removeOldBlocks() {
    ["trfmc-v51r3-matrix-host", "trfmc-v51r3-mini"].forEach((id) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.style.display = "none";
      el.style.visibility = "hidden";
      el.style.pointerEvents = "none";
      el.setAttribute("aria-hidden", "true");
    });
  }

  function balancedWidth() {
    const vw = window.innerWidth || 1920;
    if (vw >= 1800) return 1560;
    if (vw >= 1600) return 1480;
    if (vw >= 1400) return 1320;
    return Math.max(980, vw - 64);
  }

  function removeOldInlineOverscale() {
    document.querySelectorAll("[style]").forEach((el) => {
      const s = el.getAttribute("style") || "";
      if (/width\s*:\s*(18|19)\d\dpx/i.test(s) || /max-width\s*:\s*(18|19)\d\dpx/i.test(s)) {
        el.style.width = "";
        el.style.maxWidth = "";
      }
      if (/transform\s*:\s*scale/i.test(s)) {
        el.style.transform = "";
      }
    });
  }

  function setBalancedWidths() {
    const w = balancedWidth();

    const selectors = [
      "#root",
      "main",
      ".app",
      ".App",
      ".shell",
      ".Shell",
      ".layout",
      ".Layout",
      ".workspace",
      ".Workspace",
      ".dashboard",
      ".Dashboard",
      ".orchestrator",
      ".Orchestrator",
      "[class*='layout' i]",
      "[class*='workspace' i]",
      "[class*='dashboard' i]",
      "[class*='orchestrator' i]",
      "[class*='mission' i]",
      "[class*='control' i]"
    ].join(",");

    document.querySelectorAll(selectors).forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (!rect.width) return;

      if (window.innerWidth >= 1400) {
        if (rect.width < 1120 || rect.width > w + 80) {
          el.style.width = w + "px";
          el.style.maxWidth = w + "px";
          el.style.marginLeft = "auto";
          el.style.marginRight = "auto";
        }
      }
    });
  }

  function markMenuTitles() {
    document.querySelectorAll("aside a, aside button, nav a, nav button, [role='navigation'] a, [role='navigation'] button").forEach((el) => {
      const text = (el.textContent || "").trim();
      if (text.length > 32) el.title = text;
    });
  }

  function markReady() {
    let marker = document.getElementById("trfmc-v51r6-balanced-layout-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r6-balanced-layout-marker";
      marker.name = "trfmc-v51r6-balanced-layout";
      marker.content = "active";
      document.head.appendChild(marker);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.addEventListener("hashchange", () => setTimeout(boot, 100));
  window.addEventListener("resize", () => setTimeout(boot, 160));

  setTimeout(boot, 400);
  setTimeout(boot, 1200);
})();
