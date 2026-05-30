(() => {
  const VERSION = "V51R7";
  const WRAP_ID = "trfmc-v51r7-single-cockpit";

  function textOf(el) {
    return (el && el.textContent ? el.textContent : "").replace(/\s+/g, " ").trim();
  }

  function findBlockContainingText(patterns) {
    const candidates = Array.from(document.body.querySelectorAll("section, main, article, div, header"));
    let best = null;

    for (const el of candidates) {
      const t = textOf(el);
      if (!t) continue;

      const matched = patterns.some((p) => p.test(t));
      if (!matched) continue;

      const rect = el.getBoundingClientRect();
      if (!rect.width || !rect.height) continue;

      if (!best) {
        best = el;
        continue;
      }

      const area = rect.width * rect.height;
      const bestRect = best.getBoundingClientRect();
      const bestArea = bestRect.width * bestRect.height;

      /*
        Preferiamo un contenitore abbastanza grande ma non body/root.
        Serve catturare il blocco visivo, non il singolo titolo.
      */
      if (area > bestArea && area < window.innerWidth * window.innerHeight * 1.8) {
        best = el;
      }
    }

    return best;
  }

  function nearestDirectRootChild(el) {
    if (!el) return null;

    const root = document.getElementById("root") || document.body;
    let cur = el;
    let prev = el;

    while (cur && cur !== document.body && cur !== root) {
      prev = cur;
      cur = cur.parentElement;
    }

    return prev || el;
  }

  function buildUnifiedShell() {
    if (!document.body) return;

    document.body.classList.add("trfmc-v51r7-unified");
    document.body.dataset.trfmcUnifiedCockpit = VERSION;

    const existing = document.getElementById(WRAP_ID);
    if (existing) {
      markReady();
      return;
    }

    const primaryInner = findBlockContainingText([
      /TELCO RF MISSION CONTROL PLATFORM/i
    ]);

    const orchInner = findBlockContainingText([
      /TRFMC Mission Control Layout/i,
      /Full Engineering Stack - Integration View/i
    ]);

    const primary = nearestDirectRootChild(primaryInner);
    const orchestrator = nearestDirectRootChild(orchInner);

    if (!primary || !orchestrator || primary === orchestrator) {
      markReady("partial");
      return;
    }

    primary.classList.add("trfmc-v51r7-primary-cockpit");
    orchestrator.classList.add("trfmc-v51r7-orchestrator");

    const wrapper = document.createElement("div");
    wrapper.id = WRAP_ID;
    wrapper.dataset.trfmcV51r7 = "single-cockpit-shell";

    const divider = document.createElement("div");
    divider.className = "trfmc-v51r7-shell-divider";
    divider.setAttribute("aria-hidden", "true");

    const parent = primary.parentElement;
    parent.insertBefore(wrapper, primary);

    wrapper.appendChild(primary);
    wrapper.appendChild(divider);
    wrapper.appendChild(orchestrator);

    removeLegacyFloatingBlocks();
    markReady("unified");
  }

  function removeLegacyFloatingBlocks() {
    ["trfmc-v51r3-matrix-host", "trfmc-v51r3-mini"].forEach((id) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.style.display = "none";
      el.style.visibility = "hidden";
      el.style.pointerEvents = "none";
      el.setAttribute("aria-hidden", "true");
    });
  }

  function markReady(mode = "active") {
    let marker = document.getElementById("trfmc-v51r7-unified-cockpit-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r7-unified-cockpit-marker";
      marker.name = "trfmc-v51r7-unified-cockpit";
      document.head.appendChild(marker);
    }
    marker.content = mode;
  }

  function boot() {
    buildUnifiedShell();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.addEventListener("hashchange", () => setTimeout(boot, 120));
  setTimeout(boot, 500);
  setTimeout(boot, 1200);
})();
