(function(){
  const ROOT = document.querySelector('[data-trfmc-page="real-mission-home-v87b"]');
  if(!ROOT) return;

  const $ = (s) => ROOT.querySelector(s);

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

  async function boot(){
    try{
      const res = await fetch("/reports/trfmc_v87b_real_mission_home_manifest.json?ts=" + Date.now(), {cache:"no-store"});
      if(!res.ok) throw new Error("manifest HTTP " + res.status);

      const manifest = await res.json();
      const frontline = manifest.frontline_routes || [];
      const engineering = manifest.engineering_routes || [];

      const checks = await Promise.all(frontline.map(r => routeOk(r.file)));
      const okCount = checks.filter(Boolean).length;
      const score = Math.round((okCount / Math.max(1, frontline.length)) * 100);

      $("#mc87-health").textContent = score >= 80 ? "READY" : "WATCH";
      $("#mc87-score").textContent = score + "%";
      $("#mc87-score-text").textContent = okCount + "/" + frontline.length + " mission routes HTTP 200";

      $("#k-frontline").textContent = frontline.length;
      $("#k-engineering").textContent = engineering.length;
      $("#k-http").textContent = okCount;

      $("#frontlineCount").textContent = frontline.length + " real routes";

      $("#frontlineCards").innerHTML = frontline.map((r, i) => `
        <article class="mc87-card">
          <b>${esc(r.label)}</b>
          <small>${esc(r.domain)}</small>
          <span class="mc87-pill">${esc(r.status)} · ${checks[i] ? "HTTP 200" : "CHECK"}</span>
          <p>${esc(r.description)}</p>
          <a class="mc87-open" href="/${encodeURIComponent(r.file)}">Open mission route</a>
        </article>
      `).join("");

      $("#engineeringCards").innerHTML = engineering.map(r => `
        <article class="mc87-eng-card">
          <b>${esc(r.label)}</b>
          <p>${esc(r.role)}</p>
          <a class="mc87-open" href="/${encodeURIComponent(r.file)}">Open engineering bay</a>
        </article>
      `).join("");

      $("#liveList").innerHTML = [
        "No iframe shell: route reali, niente portale dentro portale.",
        "Servizi nascosti: audit e registry restano disponibili ma non dominano la UX.",
        "Mission first: RF, Digital Twin, Handover, Theory.",
        "Rollback preserved: stable v85E resta la base di rientro."
      ].map(x => `<div>${esc(x)}</div>`).join("");

    }catch(err){
      $("#mc87-health").textContent = "ERROR";
      $("#mc87-score").textContent = "0%";
      $("#frontlineCards").innerHTML = `<article class="mc87-card"><b>Manifest error</b><p>${esc(err.message)}</p></article>`;
    }
  }

  boot();
})();
