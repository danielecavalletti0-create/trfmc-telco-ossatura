(() => {
  const VERSION = "V51R5";

  function boot() {
    document.documentElement.dataset.trfmcV51r5 = "emergency-layout-rescue";

    if (!document.body) return;

    document.body.classList.add("trfmc-v51r5-rescue-active");
    document.body.dataset.trfmcLayoutRescue = VERSION;

    removeBadInjectedBlocks();
    removeInlineScale();
    widenHardcodedShells();
    tagLongMenuItems();
    markReady();
  }

  function removeBadInjectedBlocks() {
    const bad = [
      document.getElementById("trfmc-v51r3-matrix-host"),
      document.getElementById("trfmc-v51r3-mini")
    ];

    bad.forEach((el) => {
      if (!el) return;
      el.setAttribute("aria-hidden", "true");
      el.style.display = "none";
      el.style.visibility = "hidden";
      el.style.pointerEvents = "none";
    });
  }

  function removeInlineScale() {
    document.querySelectorAll("[style]").forEach((el) => {
      const s = el.getAttribute("style") || "";
      if (/transform\s*:\s*scale/i.test(s)) {
        el.style.transform = "none";
      }
    });
  }

  function widenHardcodedShells() {
    const vw = window.innerWidth || 1920;
    const target = Math.min(1900, Math.max(1320, vw - 84));

    const candidates = document.querySelectorAll(
      "main, .app, .App, .shell, .Shell, .layout, .Layout, .workspace, .Workspace, .dashboard, .Dashboard, [class*='layout' i], [class*='workspace' i], [class*='dashboard' i], [class*='mission' i], [class*='control' i]"
    );

    candidates.forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (!rect.width) return;

      if (vw >= 1400 && rect.width < 1150) {
        el.style.maxWidth = target + "px";
        el.style.width = target + "px";
        el.style.marginLeft = "auto";
        el.style.marginRight = "auto";
      }
    });
  }

  function tagLongMenuItems() {
    const items = document.querySelectorAll("aside a, aside button, nav a, nav button, [role='navigation'] a, [role='navigation'] button");
    items.forEach((el) => {
      const t = (el.textContent || "").trim();
      if (t.length > 34) el.title = t;
    });
  }

  function markReady() {
    let marker = document.getElementById("trfmc-v51r5-layout-rescue-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r5-layout-rescue-marker";
      marker.name = "trfmc-v51r5-layout-rescue";
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
  window.addEventListener("resize", () => setTimeout(boot, 150));

  setTimeout(boot, 400);
  setTimeout(boot, 1200);
  setTimeout(boot, 2200);
})();
