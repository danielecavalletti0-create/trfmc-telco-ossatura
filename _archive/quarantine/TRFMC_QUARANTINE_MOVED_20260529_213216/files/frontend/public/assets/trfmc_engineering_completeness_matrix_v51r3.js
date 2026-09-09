(() => {
  const VERSION = "V51R3";
  const HOST_ID = "trfmc-v51r3-matrix-host";
  const MINI_ID = "trfmc-v51r3-mini";

  const modules = [
    {
      title: "Mission Control / NOC",
      state: "validated",
      theory: "Mission model, SOC/NOC telemetry, operational readiness, evidence chain.",
      simulator: "Mission status correlation and live-readiness probes.",
      endpoint: "4181/api/mission/status · 4181/api/health",
      visual: "Command HUD, status cards, runtime evidence layer.",
      scenario: "Lab power-on, operator validation, baseline freeze.",
      qa: "HTTP 200, DOM marker, screenshot capture, zero-miss runtime QA."
    },
    {
      title: "RF Physics / Signal Theory",
      state: "engineering",
      theory: "Maxwell spine, Fourier/FFT, I/Q, dB/dBm, noise floor, SNR, EVM/BLER.",
      simulator: "Spectrum, waterfall, constellation and deterministic synthetic RF feed.",
      endpoint: "4181/api/rfpro/spectrum/sweep",
      visual: "RF spectrum cockpit, waterfall, signal cards, measurement gauges.",
      scenario: "Known signal, degraded channel, NLOS and RF impairment analysis.",
      qa: "Sweep endpoint online, rendered plots present, no CDN dependency."
    },
    {
      title: "Visual Asset System",
      state: "engineering",
      theory: "Asset-to-domain mapping, RF object taxonomy, instrumentation representation.",
      simulator: "Procedural WebGL/Canvas visual assets and local SVG registry.",
      endpoint: "5173 local visual asset registry",
      visual: "Antenna, tower, microwave, fiber, RF lab and infrastructure diagrams.",
      scenario: "Operator navigates asset → theory → scenario → evidence.",
      qa: "Registry load, local assets present, no remote image dependency."
    },
    {
      title: "Navigation Architecture",
      state: "validated",
      theory: "Unified portal topology, hash routing, shell discipline, section identity.",
      simulator: "Route/section resolver and active-section binding.",
      endpoint: "5173/#section hash contracts",
      visual: "Unified shell, matrix navigation, cross-domain launch points.",
      scenario: "Operator jumps between mission, visual, scenario and engineering stack.",
      qa: "Hash routes return 200, active section marker correct."
    },
    {
      title: "Dynamic Scenarios",
      state: "engineering",
      theory: "Operational scenario graph, RF/Telco/Cyber correlation, evidence generation.",
      simulator: "Scenario runner, event stream, mission graph and report console.",
      endpoint: "4181 APIs + 8000 health/backend contracts",
      visual: "Scenario cards, graph console, report console, evidence vault.",
      scenario: "RF degradation, private network, microwave, fiber and core correlation.",
      qa: "Scenario page visible, endpoint contract documented, report path defined."
    },
    {
      title: "5G Core / RAN Security",
      state: "engineering",
      theory: "Open5GS/UERANSIM, SUPI/SUCI, 5G-AKA, NAS, NGAP, PFCP, GTP-U.",
      simulator: "Readonly call-flow and identity/security analysis console.",
      endpoint: "8000/api/health and future Open5GS/UERANSIM bridge.",
      visual: "Core/RAN flow, PDU session chain, identity/security inspection panels.",
      scenario: "UE registration, authentication, PDU session establishment, tunnel readiness.",
      qa: "Backend reachable, readonly mode preserved, no unsafe live mutation."
    },
    {
      title: "Security Interlock / Restricted Areas",
      state: "locked",
      theory: "PKI, smartcard, mTLS, RBAC/ABAC, immutable audit, RF safety gates.",
      simulator: "Locked simulation-only control state.",
      endpoint: "backend security baseline · locked contracts",
      visual: "Safety lock indicators and operator authorization map.",
      scenario: "Controlled lab governance before any sensitive capability activation.",
      qa: "Restricted EW/SIGINT/red-team functions remain non-emissive and locked."
    },
    {
      title: "Engineering Completeness Matrix",
      state: "validated",
      theory: "Each module must map theory, simulator, endpoint, asset, scenario and QA.",
      simulator: "This V51R3 matrix binds visible portal quality to measurable evidence.",
      endpoint: "5173 local injected matrix asset",
      visual: "Enterprise T&M matrix embedded into the current shell.",
      scenario: "Operator can see what is complete, what is locked, what is next.",
      qa: "Frontend-only injection, build PASS required, no backend/nginx/systemd mutation."
    }
  ];

  const probes = [
    { key: "Frontend", url: "http://127.0.0.1:5173/" },
    { key: "Bridge", url: "http://127.0.0.1:4181/api/health" },
    { key: "Backend", url: "http://127.0.0.1:8000/api/health" }
  ];

  function shouldExpand() {
    const h = window.location.hash || "";
    return h === "#full-engineering-stack" ||
           h === "#mission-overview" ||
           h === "#command-center";
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[c]));
  }

  function moduleCard(m) {
    const locked = m.state === "locked";
    return `
      <article class="trfmc-v51r3-module">
        <div class="trfmc-v51r3-module-top">
          <div class="trfmc-v51r3-module-title">${esc(m.title)}</div>
          <div class="trfmc-v51r3-badge ${locked ? "locked" : ""}">${esc(m.state)}</div>
        </div>
        <dl class="trfmc-v51r3-kv">
          <dt>Teoria</dt><dd>${esc(m.theory)}</dd>
          <dt>Simulatore</dt><dd>${esc(m.simulator)}</dd>
          <dt>Endpoint</dt><dd>${esc(m.endpoint)}</dd>
          <dt>Asset</dt><dd>${esc(m.visual)}</dd>
          <dt>Scenario</dt><dd>${esc(m.scenario)}</dd>
          <dt>QA</dt><dd>${esc(m.qa)}</dd>
        </dl>
      </article>
    `;
  }

  async function probeRuntime() {
    const result = {};
    await Promise.all(probes.map(async p => {
      try {
        const r = await fetch(p.url, { cache: "no-store" });
        result[p.key] = r.ok ? `ONLINE ${r.status}` : `WARN ${r.status}`;
      } catch {
        result[p.key] = "PROBE UNAVAILABLE";
      }
    }));
    return result;
  }

  function renderMini() {
    let mini = document.getElementById(MINI_ID);
    if (!mini) {
      mini = document.createElement("div");
      mini.id = MINI_ID;
      mini.className = "trfmc-v51r3-mini";
      document.body.appendChild(mini);
    }
    mini.innerHTML = `
      <b>TRFMC ${VERSION} · Engineering Matrix attiva</b>
      <small>Apri <code>#full-engineering-stack</code> per la matrice completa. Frontend-only, nessuna mutazione backend/nginx/systemd.</small>
    `;
  }

  async function renderExpanded() {
    let host = document.getElementById(HOST_ID);
    if (!host) {
      host = document.createElement("section");
      host.id = HOST_ID;
      document.body.appendChild(host);
    }

    const runtime = await probeRuntime();

    host.innerHTML = `
      <div class="trfmc-v51r3-shell">
        <header class="trfmc-v51r3-header">
          <div>
            <div class="trfmc-v51r3-eyebrow"><span class="trfmc-v51r3-dot"></span>TRFMC ${VERSION} · Enterprise Engineering Completeness Matrix</div>
            <h2 class="trfmc-v51r3-title">Dal contenuto al collaudo: ogni modulo deve avere teoria, simulatore, endpoint, asset, scenario e QA.</h2>
            <p class="trfmc-v51r3-subtitle">
              Questa matrice rende visibile la maturità tecnica del portale: non solo pagine, ma contratti verificabili.
              Le aree sensibili restano bloccate e non emissive; l’obiettivo è qualità T&amp;M, controllo operativo e tracciabilità.
            </p>
          </div>
          <div class="trfmc-v51r3-status-grid">
            <div class="trfmc-v51r3-status-card"><b>Frontend</b><span>${esc(runtime.Frontend || "checking")}</span></div>
            <div class="trfmc-v51r3-status-card"><b>Bridge</b><span>${esc(runtime.Bridge || "checking")}</span></div>
            <div class="trfmc-v51r3-status-card"><b>Backend</b><span>${esc(runtime.Backend || "checking")}</span></div>
          </div>
        </header>
        <main class="trfmc-v51r3-grid">
          ${modules.map(moduleCard).join("")}
        </main>
        <footer class="trfmc-v51r3-footer">
          <div>
            <b>Rule:</b> nessuna funzione avanzata viene attivata senza PKI/smartcard/mTLS/RBAC/ABAC, audit immutabile e interlock RF.
          </div>
          <div>V51R3 · frontend-only · local assets</div>
        </footer>
      </div>
    `;
  }

  function clearExpanded() {
    const host = document.getElementById(HOST_ID);
    if (host && !shouldExpand()) host.innerHTML = "";
  }

  async function boot() {
    renderMini();
    if (shouldExpand()) await renderExpanded();
    else clearExpanded();
  }

  window.addEventListener("hashchange", boot);
  document.addEventListener("DOMContentLoaded", boot);
  setTimeout(boot, 700);
})();
