(function(){
  const ROOT = document.querySelector('[data-trfmc-page="design-token-audit-v86f"]');
  if(!ROOT) return;

  const state = {
    reg: null,
    risk: "ALL",
    search: "",
    selected: null
  };

  const $ = (s) => ROOT.querySelector(s);

  function esc(s){
    return String(s ?? "")
      .replaceAll("&","&amp;")
      .replaceAll("<","&lt;")
      .replaceAll(">","&gt;")
      .replaceAll('"',"&quot;");
  }

  function readiness(reg){
    const t = reg.totals || {};
    const total = Math.max(1, (t.css_files || 0) + (t.html_pages || 0));
    const high = (t.css_high_risk || 0) + (t.html_high_risk || 0);
    return Math.max(0, Math.min(100, Math.round(100 - (high / total) * 100)));
  }

  function filteredCss(){
    if(!state.reg) return [];
    const q = state.search.toLowerCase().trim();
    return state.reg.css_records.filter(r => {
      const riskOk = state.risk === "ALL" || r.risk === state.risk;
      if(!riskOk) return false;
      if(!q) return true;
      const blob = JSON.stringify(r).toLowerCase();
      return blob.includes(q);
    });
  }

  function filteredHtml(){
    if(!state.reg) return [];
    const q = state.search.toLowerCase().trim();
    return state.reg.html_records.filter(r => {
      const riskOk = state.risk === "ALL" || r.risk === state.risk;
      if(!riskOk) return false;
      if(!q) return true;
      const blob = JSON.stringify(r).toLowerCase();
      return blob.includes(q);
    });
  }

  function renderKpis(){
    const t = state.reg.totals;
    $("#k-html").textContent = t.html_pages;
    $("#k-css").textContent = t.css_files;
    $("#k-colors").textContent = t.unique_colors;
    $("#k-css-risk").textContent = t.css_high_risk;
    $("#k-html-risk").textContent = t.html_high_risk;

    const s = readiness(state.reg);
    $("#dt86-score").textContent = s + "%";
    $("#dt86-score-text").textContent = "token discipline";
    $("#dt86-health").textContent = "READY";
  }

  function renderTokens(){
    const colors = state.reg.top_colors || [];
    $("#colorGrid").innerHTML = colors.slice(0,18).map(([c,n]) => `
      <div class="dt86-color" style="background:${esc(c)}">
        <b>${esc(c)} · ${n}</b>
      </div>
    `).join("");

    $("#fontGrid").innerHTML = (state.reg.top_fonts || []).slice(0,8).map(([f,n]) => `
      <div>${esc(f)} · ${n}</div>
    `).join("");

    $("#radiusGrid").innerHTML = (state.reg.top_radius || []).slice(0,8).map(([r,n]) => `
      <div>${esc(r)} · ${n}</div>
    `).join("");
  }

  function riskBadge(r){
    const cls = r === "HIGH" ? "dt86-risk dt86-high" : "dt86-risk dt86-low";
    return `<span class="${cls}">${esc(r)}</span>`;
  }

  function renderCssTable(){
    const rows = filteredCss();
    $("#cssCount").textContent = rows.length + " files";

    $("#cssTable").innerHTML = rows.map((r, i) => `
      <tr data-i="${i}">
        <td>${riskBadge(r.risk)}</td>
        <td><strong>${esc(r.file)}</strong><br/><small>${r.size_kb} KB</small></td>
        <td>${r.unique_colors}/${r.colors_count}</td>
        <td>${r.fonts_count}</td>
        <td>${r.radius_count}</td>
        <td>${r.scoped_selectors}</td>
        <td>${r.global_selector_hits.length + r.unscoped_selector_hits.length}</td>
        <td>${r.external_refs ? "YES" : "NO"}</td>
      </tr>
    `).join("");

    const tableRows = Array.from(ROOT.querySelectorAll("#cssTable tr"));
    tableRows.forEach((tr, i) => {
      tr.addEventListener("click", () => {
        state.selected = rows[i];
        renderDetail();
      });
    });

    if(!state.selected && rows.length){
      state.selected = rows[0];
      renderDetail();
    }
  }

  function renderHtmlTable(){
    const rows = filteredHtml();
    $("#htmlCount").textContent = rows.length + " pages";

    $("#htmlTable").innerHTML = rows.map(r => `
      <tr>
        <td>${riskBadge(r.risk)}</td>
        <td><strong>${esc(r.file)}</strong><br/><small>${r.size_kb} KB</small></td>
        <td>${esc(r.generation)}</td>
        <td>${r.has_iframe_or_frame_api ? "YES" : "NO"}</td>
        <td>${r.external_refs ? "YES" : "NO"}</td>
        <td>${r.inline_style_count}</td>
        <td>${r.script_tags}</td>
        <td>${r.css_links}</td>
      </tr>
    `).join("");
  }

  function renderDetail(){
    const box = $("#detailBox");
    const r = state.selected;

    if(!r){
      box.className = "dt86-empty";
      box.textContent = "Seleziona un file CSS per vedere selettori globali, rischio e correzioni operative.";
      return;
    }

    const hits = [...(r.global_selector_hits || []), ...(r.unscoped_selector_hits || [])];

    box.className = "dt86-detail-card";
    box.innerHTML = `
      <div>
        <strong>${esc(r.file)}</strong>
        <p>Risk: ${esc(r.risk)} · size ${r.size_kb} KB · scoped selectors ${r.scoped_selectors}</p>
      </div>
      <div>
        <h2>Evidence</h2>
        <code>${esc(JSON.stringify({
          unique_colors:r.unique_colors,
          colors_count:r.colors_count,
          fonts:r.fonts_count,
          radius:r.radius_count,
          shadows:r.shadow_count,
          external_refs:r.external_refs
        }, null, 2))}</code>
      </div>
      <div>
        <h2>Selector findings</h2>
        <code>${hits.length ? esc(hits.map(h => "L"+h.line+": "+h.text).join("\n")) : "OK: nessun selettore globale/unscoped registrato dall'audit."}</code>
      </div>
      <div>
        <h2>Correction doctrine</h2>
        <code>Convertire progressivamente a [data-trfmc-page='...'] .classe; vietati patch globali e restyle a strascico.</code>
      </div>
    `;
  }

  function renderDoctrine(){
    $("#doctrineGrid").innerHTML = (state.reg.promotion_doctrine || []).map((x, i) => `
      <article>
        <h2>Gate ${String(i+1).padStart(2,"0")}</h2>
        <code>${esc(x)}</code>
      </article>
    `).join("");
  }

  function rerender(){
    state.selected = null;
    renderCssTable();
    renderHtmlTable();
  }

  function bind(){
    $("#searchBox").addEventListener("input", ev => {
      state.search = ev.target.value || "";
      rerender();
    });

    Array.from(ROOT.querySelectorAll("#riskButtons button")).forEach(btn => {
      btn.addEventListener("click", () => {
        Array.from(ROOT.querySelectorAll("#riskButtons button")).forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        state.risk = btn.getAttribute("data-risk") || "ALL";
        rerender();
      });
    });
  }

  async function boot(){
    try{
      const res = await fetch("/reports/trfmc_v86f_design_token_audit_registry.json?ts=" + Date.now(), {cache:"no-store"});
      if(!res.ok) throw new Error("registry HTTP " + res.status);
      state.reg = await res.json();
      renderKpis();
      renderTokens();
      renderCssTable();
      renderHtmlTable();
      renderDoctrine();
      bind();
    }catch(err){
      $("#dt86-health").textContent = "ERROR";
      $("#detailBox").className = "dt86-empty";
      $("#detailBox").textContent = "Errore caricamento registry: " + err.message;
    }
  }

  boot();
})();
