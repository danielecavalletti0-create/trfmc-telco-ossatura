(function(){
  "use strict";

  const rows = document.getElementById("pr86Rows");
  const filterButtons = document.querySelectorAll("[data-filter]");

  const state = {
    registry: null,
    activeFilter: "all",
    runtime: {},
    checking: false,
    checkedOnce: false
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
    const res = await fetch("/reports/trfmc_v86c_r1_portal_registry.json", {cache:"no-store"});
    state.registry = await res.json();
    markAllPending();
    render();
    await runHttpCheck(true);
  }

  function markAllPending(){
    for(const p of state.registry?.pages || []){
      state.runtime[p.route] = "pending";
    }
  }

  function render(){
    const pages = filteredPages();
    rows.innerHTML = "";

    if(!pages.length){
      rows.innerHTML = '<tr><td colspan="9">Nessuna pagina nel filtro selezionato.</td></tr>';
      updateKpis();
      return;
    }

    for(const p of pages){
      const http = state.runtime[p.route] || "pending";
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><span class="pr86-pill pr86-${p.priority.toLowerCase()}">${esc(p.priority)}</span></td>
        <td><strong>${esc(p.file)}</strong><br><span>${esc(p.title)}</span></td>
        <td>${esc(p.domain)}</td>
        <td>${esc(p.generation)}</td>
        <td>${esc(p.role)}</td>
        <td>${formatSize(p.size_bytes)}</td>
        <td class="${httpClass(http)}">${esc(String(http))}</td>
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

    if(state.checking){
      $("pr86Health").textContent = "CHECKING";
      $("pr86HealthText").textContent = `${ok}/${all.length} pages HTTP 200`;
    } else if(state.checkedOnce) {
      $("pr86Health").textContent = `${health}%`;
      $("pr86HealthText").textContent = `${ok}/${all.length} pages HTTP 200`;
    } else {
      $("pr86Health").textContent = "READY";
      $("pr86HealthText").textContent = "inventory loaded";
    }
  }

  async function runHttpCheck(rerender=true){
    const pages = state.registry?.pages || [];
    state.checking = true;

    for(const p of pages){
      state.runtime[p.route] = "checking";
    }

    if(rerender) render();
    else updateKpis();

    const checks = pages.map(async p => {
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
    });

    await Promise.all(checks);

    state.checking = false;
    state.checkedOnce = true;
    render();
  }

  function exportJson(){
    const payload = {
      version: "TRFMC v0.86C-R1 runtime registry export",
      timestamp: new Date().toISOString(),
      activeFilter: state.activeFilter,
      runtime: state.runtime,
      registry: state.registry,
      result: {
        total: state.registry?.pages?.length || 0,
        ok: (state.registry?.pages || []).filter(p => state.runtime[p.route] === 200).length
      }
    };

    const blob = new Blob([JSON.stringify(payload,null,2)], {type:"application/json"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "trfmc_v86c_r1_portal_registry_runtime.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  function formatSize(n){
    if(n > 1024*1024) return `${(n/(1024*1024)).toFixed(1)} MB`;
    if(n > 1024) return `${(n/1024).toFixed(1)} KB`;
    return `${n} B`;
  }

  function httpClass(v){
    if(v === 200) return "pr86-http-ok";
    if(v === "checking") return "pr86-http-checking";
    if(v === "pending") return "";
    return "pr86-http-bad";
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
