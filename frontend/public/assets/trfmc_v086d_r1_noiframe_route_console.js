(function(){
  "use strict";

  const root = document.body;
  const registryUrl = root.dataset.registryUrl || "/reports/trfmc_v86c_portal_registry.json";

  const state = {
    registry: null,
    pages: [],
    runtime: {},
    filter: "all",
    query: "",
    selected: null
  };

  const $ = id => document.getElementById(id);

  async function backend(){
    try{
      const r = await fetch("/api/health", {cache:"no-store"});
      $("nr86Backend").textContent = r.ok ? "Backend OK" : "Backend ERR";
    } catch {
      $("nr86Backend").textContent = "Backend OFF";
    }
  }

  async function load(){
    const r = await fetch(registryUrl, {cache:"no-store"});
    state.registry = await r.json();
    state.pages = state.registry.pages || [];
    state.selected = state.pages.find(p => p.priority === "P0") || state.pages[0] || null;
    await checkRoutes();
    render();
  }

  async function checkRoutes(){
    await Promise.all(state.pages.map(async p => {
      try{
        const r = await fetch(p.route, {method:"HEAD", cache:"no-store"});
        state.runtime[p.route] = r.status;
      } catch {
        try{
          const r2 = await fetch(p.route, {method:"GET", cache:"no-store"});
          state.runtime[p.route] = r2.status;
        } catch {
          state.runtime[p.route] = "ERR";
        }
      }
    }));
  }

  function filtered(){
    const q = state.query.trim().toLowerCase();
    return state.pages.filter(p => {
      const priority = state.filter === "all" || p.priority === state.filter;
      const hay = `${p.file} ${p.title} ${p.domain} ${p.generation} ${p.role} ${p.promotion}`.toLowerCase();
      return priority && (!q || hay.includes(q));
    });
  }

  function render(){
    renderKpi();
    renderRows();
    renderSelected();
    renderDomains();
  }

  function renderKpi(){
    const total = state.pages.length;
    const ok = state.pages.filter(p => state.runtime[p.route] === 200).length;
    const critical = state.pages.filter(p => p.priority === "P0" || p.priority === "P1").length;
    const domains = new Set(state.pages.map(p => p.domain)).size;
    const hold = state.pages.filter(p => p.promotion === "hold").length;
    const integrity = total ? Math.round(ok / total * 100) : 0;

    $("nr86Total").textContent = total;
    $("nr86Ok").textContent = ok;
    $("nr86Critical").textContent = critical;
    $("nr86Domains").textContent = domains;
    $("nr86Hold").textContent = hold;
    $("nr86Integrity").textContent = `${integrity}%`;
    $("nr86IntegrityText").textContent = `${ok}/${total} routes HTTP 200`;
  }

  function renderRows(){
    const rows = $("nr86Rows");
    const pages = filtered();
    $("nr86Visible").textContent = `${pages.length} routes`;

    if(!pages.length){
      rows.innerHTML = '<div class="nr86-empty">Nessuna rotta nel filtro corrente.</div>';
      return;
    }

    rows.innerHTML = "";
    for(const p of pages){
      const http = state.runtime[p.route] || "—";
      const row = document.createElement("article");
      row.className = "nr86-row" + (state.selected && state.selected.file === p.file ? " is-active" : "");
      row.innerHTML = `
        <span class="nr86-priority nr86-priority-${esc(p.priority.toLowerCase())}">${esc(p.priority)}</span>
        <div>
          <strong>${esc(p.file)}</strong>
          <small>${esc(p.title)}</small>
          <small>${esc(p.domain)} · ${esc(p.generation)} · ${esc(p.role)}</small>
        </div>
        <span class="${http === 200 ? "nr86-http-ok" : "nr86-http-bad"}">${esc(http)}</span>
        <span>${esc(p.promotion)}</span>
        <a class="nr86-open" href="${esc(p.route)}">Open</a>
      `;
      row.addEventListener("click", ev => {
        if(ev.target && ev.target.tagName === "A") return;
        state.selected = p;
        renderRows();
        renderSelected();
      });
      rows.appendChild(row);
    }
  }

  function renderSelected(){
    const p = state.selected;
    if(!p) return;

    $("nr86SelectedHttp").textContent = `HTTP ${state.runtime[p.route] || "—"}`;
    $("nr86SelectedFile").textContent = p.file;
    $("nr86SelectedTitle").textContent = p.title;
    $("nr86SelectedPriority").textContent = p.priority;
    $("nr86SelectedDomain").textContent = p.domain;
    $("nr86SelectedGeneration").textContent = p.generation;
    $("nr86SelectedPromotion").textContent = p.promotion;
    $("nr86OpenSelected").href = p.route;
  }

  function renderDomains(){
    const grid = $("nr86DomainGrid");
    const map = new Map();

    for(const p of state.pages){
      if(!map.has(p.domain)){
        map.set(p.domain, {total:0, p0:0, p1:0, p2:0, p3:0, p4:0});
      }
      const d = map.get(p.domain);
      d.total += 1;
      const key = String(p.priority || "").toLowerCase();
      d[key] = (d[key] || 0) + 1;
    }

    grid.innerHTML = "";
    for(const [domain, d] of [...map.entries()].sort((a,b)=>b[1].total-a[1].total)){
      const card = document.createElement("article");
      card.innerHTML = `
        <h2>${esc(domain)}</h2>
        <strong>${d.total}</strong>
        <p>P0 ${d.p0 || 0} · P1 ${d.p1 || 0} · P2 ${d.p2 || 0} · P3 ${d.p3 || 0} · P4 ${d.p4 || 0}</p>
      `;
      grid.appendChild(card);
    }
  }

  function esc(v){
    return String(v ?? "").replace(/[&<>"']/g, c => ({
      "&":"&amp;",
      "<":"&lt;",
      ">":"&gt;",
      '"':"&quot;",
      "'":"&#039;"
    }[c]));
  }

  document.querySelectorAll("[data-filter]").forEach(btn => {
    btn.addEventListener("click", () => {
      state.filter = btn.dataset.filter || "all";
      document.querySelectorAll("[data-filter]").forEach(b => b.classList.toggle("is-active", b === btn));
      renderRows();
    });
  });

  $("nr86Search").addEventListener("input", ev => {
    state.query = ev.target.value || "";
    renderRows();
  });

  backend();
  load().catch(err => {
    $("nr86Rows").innerHTML = `<div class="nr86-empty">ERRORE registry: ${esc(err.message || err)}</div>`;
    $("nr86Integrity").textContent = "FAIL";
  });
})();
