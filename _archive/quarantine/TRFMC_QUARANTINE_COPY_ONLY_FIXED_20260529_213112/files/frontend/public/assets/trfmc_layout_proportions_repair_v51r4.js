(() => {
  const VERSION = "V51R4";

  function markRuntime() {
    document.documentElement.dataset.trfmcV51r4Layout = "on";
    if (document.body) {
      document.body.classList.add("trfmc-v51r4-layout-normalized");
      document.body.dataset.trfmcLayoutRepair = VERSION;
    }
  }

  function suppressNoisyV51R3Mini() {
    const mini = document.getElementById("trfmc-v51r3-mini");
    if (mini) {
      mini.classList.add("trfmc-v51r4-suppressed");
      mini.setAttribute("aria-hidden", "true");
    }
  }

  function clampDangerousOverflow() {
    const candidates = Array.from(document.querySelectorAll(
      "main, section, article, aside, nav, header, footer, div, table, pre"
    ));

    for (const el of candidates) {
      if (!el || el === document.body || el === document.documentElement) continue;

      const style = window.getComputedStyle(el);
      if (style.position === "fixed" && el.id !== "trfmc-v51r3-mini") continue;

      const client = el.clientWidth || 0;
      const scroll = el.scrollWidth || 0;

      if (client > 0 && scroll > client + 16) {
        const tag = el.tagName.toLowerCase();
        if (tag === "table" || tag === "pre") {
          el.classList.add("trfmc-v51r4-horizontal-scroll");
        } else {
          el.classList.add("trfmc-v51r4-overflow-clamped");
        }
      }
    }
  }

  function normalizeMenuLabels() {
    const links = document.querySelectorAll(
      "aside a, aside button, nav a, nav button, [role='navigation'] a, [role='navigation'] button"
    );

    links.forEach((el) => {
      const txt = (el.textContent || "").trim();
      if (txt.length > 42) {
        el.setAttribute("title", txt);
      }
    });
  }

  function addAuditMarker() {
    let marker = document.getElementById("trfmc-v51r4-layout-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r4-layout-marker";
      marker.name = "trfmc-v51r4-layout-repair";
      marker.content = "active";
      document.head.appendChild(marker);
    }
  }

  function boot() {
    markRuntime();
    suppressNoisyV51R3Mini();
    normalizeMenuLabels();
    clampDangerousOverflow();
    addAuditMarker();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.addEventListener("hashchange", () => setTimeout(boot, 120));
  window.addEventListener("resize", () => setTimeout(boot, 160));

  setTimeout(boot, 500);
  setTimeout(boot, 1400);
})();
