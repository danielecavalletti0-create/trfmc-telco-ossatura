(function(){
  const VERSION = "TRFMC_V0_59A_EXECUTIVE_DASHBOARD_NEXT_ENTERPRISE_PRODUCTION_LAYER";
  const API = "/api";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  async function getJson(url){
    const r = await fetch(url, {cache: "no-store"});
    if(!r.ok) throw new Error(url + " HTTP " + r.status);
    return await r.json();
  }

  function set(id, value){
    const el = document.getElementById(id);
    if(el) el.textContent = value ?? "—";
  }

  function cls(id, name){
    const el = document.getElementById(id);
    if(!el) return;
    el.classList.remove("good", "warn", "bad");
    if(name) el.classList.add(name);
  }

  function ensureEnterprisePanel(){
    if(document.querySelector(".v59-enterprise-ops")) return;

    const panel = document.createElement("section");
    panel.className = "v59-enterprise-ops";
    panel.id = "enterprise_ops";
    panel.innerHTML = `
      <div class="v59-enterprise-head">
        <div>
          <h2>Enterprise Operations / Production Readiness</h2>
          <p>
            ${VERSION} · executive ufficiale: readiness operativo, release posture, RF/Telco core,
            evidence chain, golden baseline e stato UI. Nessuna modifica backend, localhost-only, simulation posture.
          </p>
        </div>
        <div class="v59-release-badge">OFFICIAL EXECUTIVE · v0.59A</div>
      </div>

      <div class="v59-enterprise-grid">
        <div class="v59-op-tile" id="v59_tile_runtime"><span>Runtime</span><b id="v59_runtime">—</b><small id="v59_runtime_detail">backend</small></div>
        <div class="v59-op-tile" id="v59_tile_release"><span>Release</span><b id="v59_release">v0.59A</b><small>enterprise production layer</small></div>
        <div class="v59-op-tile" id="v59_tile_golden"><span>Golden</span><b id="v59_golden">—</b><small id="v59_golden_detail">checks</small></div>
        <div class="v59-op-tile" id="v59_tile_rf"><span>RF/Telco</span><b id="v59_rf">—</b><small>coverage / field</small></div>
        <div class="v59-op-tile" id="v59_tile_evidence"><span>Evidence</span><b id="v59_evidence">—</b><small>vault / incidents</small></div>
        <div class="v59-op-tile" id="v59_tile_ui"><span>UI State</span><b id="v59_ui">ACTIVE</b><small>next dashboard official</small></div>
      </div>

      <div class="v59-enterprise-actions">
        <a href="/executive_mission_dashboard_v_next.html">Executive Official</a>
        <a href="/runtime_golden_check_console_v29.html">Golden Check</a>
        <a href="/operator_handbook_console_v23.html">Operator Handbook</a>
        <a href="/evidence_vault_console_v20.html">Evidence Vault</a>
        <a href="/backup_console_v21.html">Backup Console</a>
        <a href="/restore_readiness_console_v22.html">Restore Readiness</a>
        <button type="button" id="v59_print">Print / Review</button>
      </div>
    `;

    const control = document.querySelector(".control-strip");
    if(control) control.insertAdjacentElement("afterend", panel);
    else {
      const hero = document.querySelector(".hero-next");
      if(hero) hero.insertAdjacentElement("afterend", panel);
      else document.body.prepend(panel);
    }
  }

  function ensureEnterpriseButtons(){
    const strip = document.querySelector(".strip-actions");
    if(!strip || document.getElementById("btn_enterprise_freeze")) return;

    const freeze = document.createElement("button");
    freeze.type = "button";
    freeze.id = "btn_enterprise_freeze";
    freeze.textContent = "Freeze Visuals";
    strip.appendChild(freeze);

    freeze.addEventListener("click", () => {
      document.body.classList.toggle("freeze-visuals");
      freeze.classList.toggle("active");
      freeze.textContent = document.body.classList.contains("freeze-visuals") ? "Resume Visuals" : "Freeze Visuals";
    });
  }

  function updateIdentity(){
    document.body.classList.add("v59-enterprise-production");

    const brandSpan = document.querySelector(".brand span");
    if(brandSpan){
      brandSpan.textContent = "Executive Dashboard Next · Enterprise Production Layer · v0.59A";
    }

    const eyebrow = document.querySelector(".eyebrow");
    if(eyebrow){
      eyebrow.textContent = "TRFMC v0.59A · ENTERPRISE PRODUCTION LAYER";
    }

    const heroText = document.querySelector(".hero-copy p");
    if(heroText){
      heroText.textContent =
        "Plancia executive enterprise per RF/Telco, scenario command, KPI live, evidence posture e runtime readiness. Questa versione promuove la v_next a console executive ufficiale: grafica space calibrata, postura operativa, readiness e collegamenti di governo.";
    }

    const footer = document.querySelector(".next-footer");
    if(footer){
      footer.textContent = "TRFMC v0.59A · Executive Dashboard Next / Enterprise Production Layer · official executive console · frontend-only · localhost-only · backend simulation-only";
    }

    document.title = "TRFMC v0.59A · Executive Dashboard Next Enterprise Production Layer";
  }

  function bindActions(){
    const print = document.getElementById("v59_print");
    if(print) print.addEventListener("click", () => window.print());
  }

  async function refreshEnterprise(){
    try {
      const health = await getJson(API + "/health");
      const portal = await getJson(API + "/portal/health-summary").catch(() => ({}));
      const snap = await getJson("/runtime_golden_check_snapshot.json?nocache=" + Date.now()).catch(() => ({}));
      const counts = portal.high_value_counts || {};

      const runtimeOk = health.status === "ok";
      const goldenOk = snap.overall_status === "OK";
      const rfCov = counts.rf_coverage_runs ?? "—";
      const rfField = counts.rf_field_runs ?? "—";
      const evidence = counts.evidence ?? "—";
      const incidents = counts.incidents ?? "—";

      set("v59_runtime", runtimeOk ? "ONLINE" : "ATTENTION");
      set("v59_runtime_detail", "backend " + (health.version || "—") + " · " + (health.operational_mode || "—"));
      cls("v59_tile_runtime", runtimeOk ? "good" : "bad");

      set("v59_golden", goldenOk ? "OK" : (snap.overall_status || "—"));
      set("v59_golden_detail", ((snap.checks || []).length || "—") + " checks");
      cls("v59_tile_golden", goldenOk ? "good" : "warn");

      set("v59_rf", rfCov + " / " + rfField);
      cls("v59_tile_rf", Number(rfCov) > 0 && Number(rfField) > 0 ? "good" : "warn");

      set("v59_evidence", incidents + " / " + evidence);
      cls("v59_tile_evidence", Number(evidence) > 0 ? "good" : "warn");

      set("v59_ui", "OFFICIAL");
      cls("v59_tile_ui", "good");
      cls("v59_tile_release", "good");
    } catch(e) {
      set("v59_runtime", "DEGRADED");
      set("v59_runtime_detail", String(e).slice(0, 80));
      cls("v59_tile_runtime", "bad");
      set("v59_ui", "DEGRADED");
      cls("v59_tile_ui", "bad");
    }
  }

  function keyboardShortcuts(){
    document.addEventListener("keydown", (ev) => {
      if(!ev.altKey) return;
      const key = ev.key.toLowerCase();
      if(key === "e"){
        document.body.classList.toggle("show-engineering");
      }
      if(key === "f"){
        document.body.classList.toggle("freeze-visuals");
      }
      if(key === "p"){
        window.print();
      }
    });
  }

  ready(function(){
    updateIdentity();
    ensureEnterpriseButtons();
    ensureEnterprisePanel();
    bindActions();
    keyboardShortcuts();
    refreshEnterprise();
    setInterval(refreshEnterprise, 30000);
  });
})();
