(function(){
  const ROOT = document.querySelector('[data-trfmc-page="route-normalizer-v87f"]');
  if(!ROOT) return;

  const $ = (s) => ROOT.querySelector(s);

  const state = {
    manifest: null,
    ok: {},
    selected: null
  };

  function esc(s){
    return String(s ?? "")
      .replaceAll("&","&amp;")
      .replaceAll("<","&lt;")
      .replaceAll(">","&gt;")
      .replaceAll('"',"&quot;");
  }

  async function routeOk(file){
    try{
      const res = await fetch("/" + file + "?ts=" + Date.now(), {cache:"no-store"});
      return res.ok;
    }catch(_){
      return false;
    }
  }

  function renderCard(r){
    const status = state.ok[r.file] ? "HTTP 200" : "CHECK";
    return `
      <article class="rn87-card" data-file="${esc(r.file)}">
        <b>${esc(r.label)}</b>
        <span class="rn87-pill">${esc(r.tier)} · ${esc(status)}</span>
        <p>${esc(r.reason)}</p>
        <a class="rn87-open" href="/${encodeURIComponent(r.file)}">Open route</a>
      </article>
    `;
  }

  function renderInspector(){
    const r = state.selected || (state.manifest.visible_navigation || [])[0];
    const box = $("#routeInspector");

    if(!r){
      box.textContent = "Nessuna rotta disponibile.";
      return;
    }

    $("#inspectorStatus").textContent = state.ok[r.file] ? "HTTP 200" : "check";

    box.innerHTML = `
      <b>${esc(r.title)}</b>
      <p>${esc(r.reason)}</p>
      <code>label: ${esc(r.label)}
domain: ${esc(r.domain)}
tier: ${esc(r.tier)}
visibility: ${esc(r.visibility)}
role: ${esc(r.role)}
file: ${esc(r.file)}
state: ${state.ok[r.file] ? "reachable" : "not validated"}</code>
      <p><a class="rn87-open" href="/${encodeURIComponent(r.file)}">Open selected route</a></p>
    `;
  }

  function render(){
    const visible = state.manifest.visible_navigation || [];
    const engineering = state.manifest.engineering_bay || [];
    const okVisible = visible.filter(r => state.ok[r.file]).length;
    const score = Math.round((okVisible / Math.max(1, visible.length)) * 100);

    $("#rn87Status").textContent = score >= 95 ? "READY" : (score >= 80 ? "WATCH" : "HOLD");
    $("#rn87Score").textContent = score + "%";
    $("#rn87ScoreText").textContent = okVisible + "/" + visible.length + " visible routes HTTP 200";

    $("#rn87VisibleCount").textContent = visible.length;
    $("#rn87EngineeringCount").textContent = engineering.length;
    $("#rn87OkCount").textContent = okVisible;
    $("#visibleLabel").textContent = visible.length + " visible routes";

    $("#visibleRoutes").innerHTML = visible.map(renderCard).join("");

    Array.from(ROOT.querySelectorAll(".rn87-card[data-file]")).forEach(card => {
      card.addEventListener("click", (ev) => {
        if(ev.target && ev.target.tagName === "A") return;
        const file = card.getAttribute("data-file");
        state.selected = visible.find(r => r.file === file) || visible[0];
        renderInspector();
      });
    });

    $("#routeTable").innerHTML = visible.map(r => `
      <tr>
        <td>${esc(r.order)}</td>
        <td><strong>${esc(r.label)}</strong><br/><small>${esc(r.title)}</small></td>
        <td>${esc(r.tier)}</td>
        <td>${esc(r.domain)}</td>
        <td>${esc(r.file)}</td>
        <td>${esc(r.role)}</td>
        <td>${state.ok[r.file] ? "200" : "CHECK"}</td>
        <td><a class="rn87-open" href="/${encodeURIComponent(r.file)}">Open</a></td>
      </tr>
    `).join("");

    $("#engineeringRoutes").innerHTML = engineering.map(r => `
      <article class="rn87-eng-card">
        <b>${esc(r.label)}</b>
        <span class="rn87-pill">${esc(r.visibility)}</span>
        <p>${esc(r.role)}</p>
        <a class="rn87-open" href="/${encodeURIComponent(r.file)}">Open service</a>
      </article>
    `).join("");

    state.selected = state.selected || visible[0] || null;
    renderInspector();
  }

  async function boot(){
    try{
      const res = await fetch("/reports/trfmc_v87f_route_normalizer_manifest.json?ts=" + Date.now(), {cache:"no-store"});
      if(!res.ok) throw new Error("manifest HTTP " + res.status);
      state.manifest = await res.json();

      const visible = state.manifest.visible_navigation || [];
      const checks = await Promise.all(visible.map(r => routeOk(r.file)));
      visible.forEach((r,i) => state.ok[r.file] = checks[i]);

      render();
    }catch(err){
      $("#rn87Status").textContent = "ERROR";
      $("#rn87Score").textContent = "0%";
      $("#routeInspector").textContent = "Errore manifest: " + err.message;
    }
  }

  boot();
})();
