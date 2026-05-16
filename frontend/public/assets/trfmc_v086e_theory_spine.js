(function(){
  const ROOT = document.querySelector('[data-trfmc-page="theory-spine-v86e"]');
  if(!ROOT) return;

  const state = {
    registry: null,
    priority: "ALL",
    search: "",
    selected: null
  };

  const $ = (sel) => ROOT.querySelector(sel);

  function priorityClass(p){
    return "ts86-priority ts86-" + String(p || "P4").toLowerCase();
  }

  function escapeHtml(s){
    return String(s ?? "")
      .replaceAll("&","&amp;")
      .replaceAll("<","&lt;")
      .replaceAll(">","&gt;")
      .replaceAll('"',"&quot;");
  }

  function score(reg){
    const t = reg.totals || {};
    const pages = Math.max(1, t.pages || 1);
    const weighted = ((t.p0 || 0) * 1.0 + (t.p1 || 0) * 0.82 + (t.p2 || 0) * 0.62 + (t.p3 || 0) * 0.42) / pages;
    return Math.max(0, Math.min(100, Math.round(weighted * 100)));
  }

  function filteredRecords(){
    if(!state.registry) return [];
    const q = state.search.trim().toLowerCase();

    return state.registry.records.filter(r => {
      const pOk = state.priority === "ALL" || r.priority === state.priority;
      if(!pOk) return false;
      if(!q) return true;
      const blob = [
        r.file, r.title, r.domain, r.role, r.priority,
        ...(r.formulas || []),
        ...(r.measurements || []),
        r.promotion_rule
      ].join(" ").toLowerCase();
      return blob.includes(q);
    });
  }

  function renderKpis(){
    const reg = state.registry;
    if(!reg) return;

    const t = reg.totals || {};
    $("#k-pages").textContent = t.pages ?? "--";
    $("#k-domains").textContent = t.domains ?? "--";
    $("#k-p0").textContent = t.p0 ?? 0;
    $("#k-p1").textContent = t.p1 ?? 0;
    $("#k-p4").textContent = t.p4 ?? 0;

    const s = score(reg);
    $("#ts86-score").textContent = s + "%";
    $("#ts86-score-text").textContent = "formula traceability";
    $("#ts86-health").textContent = "READY";
  }

  function renderDomains(){
    const grid = $("#domainGrid");
    const domains = state.registry.domain_counts || {};
    const entries = Object.entries(domains).sort((a,b) => b[1] - a[1]);

    grid.innerHTML = entries.map(([domain,count]) => `
      <article>
        <span>${escapeHtml(domain)}</span>
        <strong>${count}</strong>
        <p>Rotte collegate a questo dominio tecnico.</p>
      </article>
    `).join("");
  }

  function renderTable(){
    const tbody = $("#routeTable");
    const records = filteredRecords();

    $("#routeCount").textContent = records.length + " routes";

    tbody.innerHTML = records.map((r, idx) => {
      const f0 = (r.formulas && r.formulas[0]) ? r.formulas[0] : "No formula";
      const m0 = (r.measurements || []).slice(0,3).join(", ");
      return `
        <tr data-index="${idx}">
          <td><span class="${priorityClass(r.priority)}">${escapeHtml(r.priority)}</span></td>
          <td><strong>${escapeHtml(r.file)}</strong><br/><small>${escapeHtml(r.title)}</small></td>
          <td>${escapeHtml(r.domain)}</td>
          <td>${escapeHtml(r.role)}</td>
          <td><code>${escapeHtml(f0)}</code></td>
          <td>${escapeHtml(m0)}</td>
          <td><a class="ts86-open" href="/${encodeURIComponent(r.file)}">Open</a></td>
        </tr>
      `;
    }).join("");

    Array.from(tbody.querySelectorAll("tr")).forEach((row, idx) => {
      row.addEventListener("click", (ev) => {
        if(ev.target && ev.target.closest("a")) return;
        state.selected = records[idx];
        renderDetail();
      });
    });

    if(!state.selected && records.length){
      state.selected = records[0];
      renderDetail();
    }
  }

  function renderDetail(){
    const box = $("#selectedDetail");
    const r = state.selected;

    if(!r){
      box.className = "ts86-detail-empty";
      box.textContent = "Seleziona una rotta per vedere teoria, formule, misure e regola di promozione.";
      return;
    }

    box.className = "ts86-detail-card";
    box.innerHTML = `
      <div>
        <strong>${escapeHtml(r.file)}</strong>
        <p>${escapeHtml(r.title)}</p>
      </div>
      <div>
        <h2>Domain</h2>
        <code>${escapeHtml(r.domain)} · ${escapeHtml(r.priority)}</code>
      </div>
      <div>
        <h2>Formula chain</h2>
        <section class="ts86-formula-list">
          ${(r.formulas || []).map(f => `<div>${escapeHtml(f)}</div>`).join("")}
        </section>
      </div>
      <div>
        <h2>Measurements</h2>
        <section class="ts86-measure-list">
          ${(r.measurements || []).map(m => `<div>${escapeHtml(m)}</div>`).join("")}
        </section>
      </div>
      <div>
        <h2>Promotion rule</h2>
        <code>${escapeHtml(r.promotion_rule)}</code>
      </div>
      <a class="ts86-open" href="/${encodeURIComponent(r.file)}">Apri pagina sorgente</a>
    `;
  }

  function bind(){
    $("#searchBox").addEventListener("input", (ev) => {
      state.search = ev.target.value || "";
      state.selected = null;
      renderTable();
    });

    Array.from(ROOT.querySelectorAll("#priorityFilters button")).forEach(btn => {
      btn.addEventListener("click", () => {
        Array.from(ROOT.querySelectorAll("#priorityFilters button")).forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        state.priority = btn.getAttribute("data-priority") || "ALL";
        state.selected = null;
        renderTable();
      });
    });
  }

  async function boot(){
    try{
      const res = await fetch("/reports/trfmc_v86e_theory_spine_registry.json?ts=" + Date.now(), { cache: "no-store" });
      if(!res.ok) throw new Error("registry HTTP " + res.status);
      state.registry = await res.json();
      renderKpis();
      renderDomains();
      renderTable();
      bind();
    }catch(err){
      $("#ts86-health").textContent = "ERROR";
      $("#selectedDetail").className = "ts86-detail-empty";
      $("#selectedDetail").textContent = "Errore caricamento registry: " + err.message;
    }
  }

  boot();
})();
