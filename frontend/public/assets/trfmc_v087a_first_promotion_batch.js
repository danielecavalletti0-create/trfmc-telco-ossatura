(function(){
  const ROOT = document.querySelector('[data-trfmc-page="first-promotion-batch-v87a"]');
  if(!ROOT) return;

  const $ = (s) => ROOT.querySelector(s);

  function esc(s){
    return String(s ?? "")
      .replaceAll("&","&amp;")
      .replaceAll("<","&lt;")
      .replaceAll(">","&gt;")
      .replaceAll('"',"&quot;");
  }

  function pClass(p){
    return "pb87-priority " + (p === "P0" ? "pb87-p0" : "pb87-p1");
  }

  async function httpOk(path){
    try{
      const res = await fetch("/" + path + "?ts=" + Date.now(), {cache:"no-store"});
      return res.ok;
    }catch(_){
      return false;
    }
  }

  async function boot(){
    try{
      const res = await fetch("/reports/trfmc_v87a_first_promotion_batch_registry.json?ts=" + Date.now(), {cache:"no-store"});
      if(!res.ok) throw new Error("registry HTTP " + res.status);
      const reg = await res.json();

      const batch = reg.promotion_batch || [];
      const hold = reg.hold_routes || [];

      const okResults = await Promise.all(batch.map(r => httpOk(r.file)));
      const ready = okResults.every(Boolean);
      const score = ready ? 100 : Math.round((okResults.filter(Boolean).length / Math.max(1,batch.length)) * 100);

      $("#pb87-health").textContent = ready ? "READY" : "WATCH";
      $("#pb87-score").textContent = score + "%";

      $("#k-routes").textContent = batch.length;
      $("#k-p0").textContent = batch.filter(r => r.priority === "P0").length;
      $("#k-p1").textContent = batch.filter(r => r.priority === "P1").length;
      $("#k-hold").textContent = hold.length;
      $("#k-backend").textContent = "OK";
      $("#routeCount").textContent = batch.length + " candidate routes";

      $("#promotionCards").innerHTML = batch.map((r, i) => `
        <article class="pb87-card">
          <span class="${pClass(r.priority)}">${esc(r.priority)}</span>
          <strong>${esc(r.title)}</strong>
          <p>${esc(r.reason)}</p>
          <code>${esc(r.gate)}</code>
          <p><a class="pb87-open" href="/${encodeURIComponent(r.file)}">Open candidate</a></p>
        </article>
      `).join("");

      $("#holdCards").innerHTML = hold.map(r => `
        <article class="pb87-card">
          <span class="pb87-priority pb87-hold-badge">HOLD</span>
          <strong>${esc(r.file)}</strong>
          <p>${esc(r.reason)}</p>
          <code>${esc(r.state)}</code>
        </article>
      `).join("");

      $("#matrixTable").innerHTML = batch.map(r => `
        <tr>
          <td><span class="${pClass(r.priority)}">${esc(r.priority)}</span></td>
          <td><strong>${esc(r.file)}</strong><br/><small>${esc(r.title)}</small></td>
          <td>${esc(r.domain)}</td>
          <td>${esc(r.reason)}</td>
          <td><code>${esc(r.gate)}</code></td>
          <td>${esc(r.rollback)}</td>
          <td><a class="pb87-open" href="/${encodeURIComponent(r.file)}">Open</a></td>
        </tr>
      `).join("");

    }catch(err){
      $("#pb87-health").textContent = "ERROR";
      $("#pb87-score").textContent = "0%";
      $("#promotionCards").innerHTML = `<article class="pb87-card"><strong>Errore registry</strong><p>${esc(err.message)}</p></article>`;
    }
  }

  boot();
})();
