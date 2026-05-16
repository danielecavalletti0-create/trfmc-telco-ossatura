(function(){
  "use strict";

  const rows = document.getElementById("pr86Rows");
  const filterButtons = document.querySelectorAll("[data-filter]");
  const state = {
    registry: null,
    activeFilter: "all",
    runtime: {}
  };

  const $ = id => document.getElementById(id);

  async function checkBackend(){
    try{
      const r = await fetch("/api/health", {cache:"no-store"});
      $("pr86Backend").textContent = r.ok ? "Backend OK" : "Backend ERR";
    } catch {
      $("pr86Backend").textContent = "Backend OFF";
    }
  }

  async function loadRegistry(){
    const res = await fetch("/reports/trfmc_v86c_portal_registry.json", {cache:"no-store"});
    state.registry = await res.json();
    render();
    await runHttpCheck(false);
  }

  function render(){
    const pages = filteredPages();
    rows.innerHTML = "";

    if(!pages.length){
      rows.innerHTML = '<tr><td colspan="9">Nessuna pagina nel filtro selezionato.</td></tr>';
      return;
    }

    for(const p of pages){
      const http = state.runtime[p.route] || p.http || "pending";
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><span class="pr86-pill pr86-${p.priority.toLowerCase()}">${esc(p.priority)}</span></td>
        <td><strong>${esc(p.file)}</strong><br><span>${esc(p.title)}</span></td>
        <td>${esc(p.domain)}</td>
        <td>${esc(p.generation)}</td>
        <td>${esc(p.role)}</td>
        <td>${formatSize(p.size_bytes)}</td>
        <td class="${http === 200 ? "pr86-http-ok" : http === "pending" ? "" : "pr86-http-bad"}">${esc(String(http))}</td>
        <td>${esc(p.promotion)}</td>
        <td><a class="pr86-open" href="${esc(p.route)}">Open</a></td>
      `;
      rows.appendChild(tr);
    }

    updateKpis();
  }

  function filteredPages(){
    const all = state.registry?.pages || [];
    if(state.activeFilter === "all") return all;
    return all.filter(p => p.priority === state.activeFilter);
  }

  function updateKpis(){
    const all = state.registry?.pages || [];
    const ok = all.filter(p => state.runtime[p.route] === 200).length;
    const critical = all.filter(p => p.priority === "P0" || p.priority === "P1").length;
    const hold = all.filter(p => p.priority === "P3" || p.priority === "P4").length;
    const domains = new Set(all.map(p => p.domain)).size;

    $("pr86Total").textContent = String(all.length);
    $("pr86Ok").textContent = String(ok);
    $("pr86Critical").textContent = String(critical);
    $("pr86Hold").textContent = String(hold);
    $("pr86Domains").textContent = String(domains);

    const health = all.length ? Math.round((ok / all.length) * 100) : 0;
    $("pr86Health").textContent = ok ? `${health}%` : "MEASURING";
    $("pr86HealthText").textContent = ok ? `${ok}/${all.length} pages HTTP 200` : "inventory loaded";
  }

  async function runHttpCheck(rerender=true){
    const pages = state.registry?.pages || [];
    for(const p of pages){
      try{
        const r = await fetch(p.route, {method:"HEAD", cache:"no-store"});
        state.runtime[p.route] = r.status;
      } catch {
        state.runtime[p.route] = "ERR";
      }
    }
    if(rerender) render();
    else updateKpis();
  }

  function exportJson(){
    const payload = {
      version: "TRFMC v0.86C runtime registry export",
      timestamp: new Date().toISOString(),
      activeFilter: state.activeFilter,
      runtime: state.runtime,
      registry: state.registry
    };
    const blob = new Blob([JSON.stringify(payload,null,2)], {type:"application/json"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "trfmc_v86c_portal_registry_runtime.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  function formatSize(n){
    if(n > 1024*1024) return `${(n/(1024*1024)).toFixed(1)} MB`;
    if(n > 1024) return `${(n/1024).toFixed(1)} KB`;
    return `${n} B`;
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

  filterButtons.forEach(btn=>{
    btn.addEventListener("click",()=>{
      state.activeFilter = btn.dataset.filter || "all";
      filterButtons.forEach(b => b.classList.toggle("is-active", b === btn));
      render();
    });
  });

  document.getElementById("pr86RunHttp")?.addEventListener("click",()=>runHttpCheck(true));
  document.getElementById("pr86Export")?.addEventListener("click",exportJson);

  checkBackend();
  loadRegistry().catch(err=>{
    rows.innerHTML = `<tr><td colspan="9">ERRORE caricamento registry: ${esc(err.message || err)}</td></tr>`;
  });
})();
