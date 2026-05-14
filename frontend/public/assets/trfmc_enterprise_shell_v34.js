(function () {
  "use strict";

  const API = "http://127.0.0.1:8000/api";

  const NAV = [
    { label: "Portal", href: "/portal_index_v19.html" },
    { label: "Executive", href: "/executive_mission_dashboard_v_next.html" },
    { label: "RF/Telco", href: "/rf_telco_mission_portal_v35.html" },
    { label: "RF Cockpit", href: "/rf_telco_visual_cockpit_v36.html" },
    { label: "World Journey", href: "/network_journey_world_map_v37.html" },
    { label: "RF Instruments", href: "/rf_instrumentation_signal_cockpit_v38.html" },
    { label: "Golden", href: "/runtime_golden_check_console_v29.html" },
    { label: "Handbook", href: "/operator_handbook_console_v23.html" },
    { label: "Security", href: "/security_console_v18.html" },
    { label: "Scenarios", href: "/scenario_runner_console_v16.html" },
    { label: "Reports", href: "/scenario_report_console_v17.html" },
    { label: "Observability", href: "/observability_console_v13.html" },
    { label: "Backup", href: "/operational_backup_console_v21.html" },
    { label: "Restore", href: "/restore_readiness_console_v22.html" }
  ];

  function currentPath() {
    return window.location.pathname || "/";
  }

  function esc(value) {
    return String(value == null ? "" : value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  async function getJson(url) {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(url + " HTTP " + r.status);
    return await r.json();
  }

  function pageLabel() {
    const p = currentPath();
    if (p.includes("portal_index")) return "Unified Portal Index";
    if (p.includes("operator_handbook")) return "Operator Handbook";
    if (p.includes("runtime_golden")) return "Runtime Golden Check";
    if (p.includes("observability")) return "Observability Evidence";
    if (p.includes("timeline")) return "Evidence Timeline";
    if (p.includes("mission_graph")) return "Mission Graph";
    if (p.includes("scenario_runner")) return "Scenario Runner";
    if (p.includes("scenario_report")) return "Scenario Report";
    if (p.includes("security")) return "Security Baseline";
    if (p.includes("evidence_vault")) return "Evidence Vault";
    if (p.includes("operational_backup")) return "Operational Backup";
    if (p.includes("restore_readiness")) return "Restore Readiness";
    return "Mission Control";
  }

  function buildShell() {
    if (document.getElementById("trfmc-shell-topbar")) return;

    const path = currentPath();

    const navHtml = NAV.map(item => {
      const active = path === item.href ? " trfmc-shell-active" : "";
      return `<a class="${active.trim()}" href="${esc(item.href)}">${esc(item.label)}</a>`;
    }).join("");

    const shell = document.createElement("section");
    shell.id = "trfmc-shell-topbar";
    shell.className = "trfmc-shell-topbar";
    shell.innerHTML = `
      <div class="trfmc-shell-row">
        <div class="trfmc-shell-brand">
          <div class="trfmc-shell-mark" aria-hidden="true"></div>
          <div class="trfmc-shell-title">
            <b>TRFMC Mission Control</b>
            <span>${esc(pageLabel())} · Enterprise Navigation Shell v0.34</span>
          </div>
        </div>

        <nav class="trfmc-shell-nav" aria-label="TRFMC enterprise navigation">
          ${navHtml}
        </nav>

        <div class="trfmc-shell-status">
          <span id="trfmc-shell-backend" class="trfmc-shell-pill">Backend <strong>...</strong></span>
          <span id="trfmc-shell-snapshot" class="trfmc-shell-pill">Golden <strong>...</strong></span>
          <span id="trfmc-shell-mode" class="trfmc-shell-pill">Mode <strong>...</strong></span>
        </div>
      </div>

      <div class="trfmc-shell-subbar">
        <span>localhost-only · simulation-only · controlled lab posture</span>
        <span>
          API <code>127.0.0.1:8000</code>
          Frontend <code>127.0.0.1:5173</code>
        </span>
      </div>
    `;

    document.body.insertBefore(shell, document.body.firstChild);

    const footer = document.createElement("section");
    footer.id = "trfmc-shell-footer";
    footer.className = "trfmc-shell-footer";
    footer.innerHTML = `
      <b>TRFMC v0.34 Enterprise Navigation Shell</b>
      · unified console navigation · runtime status · golden check · operational lab mode
    `;
    document.body.appendChild(footer);
  }

  function setPill(id, label, value, state) {
    const el = document.getElementById(id);
    if (!el) return;

    el.classList.remove("ok", "warn", "error");
    if (state) el.classList.add(state);
    el.innerHTML = `${esc(label)} <strong>${esc(value)}</strong>`;
  }

  async function updateStatus() {
    try {
      const health = await getJson(API + "/health");
      const version = health.version || "UNKNOWN";
      const mode = health.operational_mode || "UNKNOWN";
      setPill("trfmc-shell-backend", "Backend", version, health.status === "ok" ? "ok" : "warn");
      setPill("trfmc-shell-mode", "Mode", mode, mode === "SIMULATION_ONLY" ? "ok" : "warn");
    } catch (e) {
      setPill("trfmc-shell-backend", "Backend", "ERROR", "error");
      setPill("trfmc-shell-mode", "Mode", "UNKNOWN", "warn");
    }

    try {
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now());
      const status = snap.overall_status || "UNKNOWN";
      setPill("trfmc-shell-snapshot", "Golden", status, status === "OK" ? "ok" : "warn");
    } catch (e) {
      setPill("trfmc-shell-snapshot", "Golden", "ERROR", "error");
    }
  }

  function boot() {
    buildShell();
    updateStatus();
    window.setInterval(updateStatus, 30000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
