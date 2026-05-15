(function(){
  "use strict";

  const $ = id => document.getElementById(id);
  let strictMode = false;
  let lastReport = null;

  const expectedMarkers = {
    shellV70: "trfmc_unified_enterprise_shell_v70",
    objectV70B: "trfmc_object_definition_surfaces_v70b",
    nav: "<nav",
    h1: "<h1",
    canvas: "<canvas",
    iframe: "<iframe"
  };

  function badge(ok, warnText){
    if(ok === true) return `<span class="pill ok">OK</span>`;
    if(ok === "WARN") return `<span class="pill warn">${warnText || "WARN"}</span>`;
    return `<span class="pill crit">${warnText || "NO"}</span>`;
  }

  function scoreClass(score){
    if(score >= 88) return "ok";
    if(score >= 72) return "warn";
    return "crit";
  }

  async function backendHealth(){
    try{
      const r = await fetch("http://127.0.0.1:8000/api/health", {cache:"no-store"});
      $("backend_state").textContent = r.ok ? "Backend OK" : "Backend WARN";
      $("backend_state").className = r.ok ? "" : "warn";
    }catch(e){
      $("backend_state").textContent = "Backend OFF";
      $("backend_state").className = "crit";
    }
  }

  async function loadTargets(){
    const r = await fetch("/trfmc_visual_qa_targets_v71.json", {cache:"no-store"});
    if(!r.ok) throw new Error("targets json " + r.status);
    return await r.json();
  }

  function analyzeHtml(target, html, httpOk){
    const lower = html.toLowerCase();

    const hasShellV70 = html.includes(expectedMarkers.shellV70);
    const hasObjectV70B = html.includes(expectedMarkers.objectV70B);
    const hasNav = lower.includes("<nav");
    const hasH1 = lower.includes("<h1");
    const hasCanvas = lower.includes("<canvas");
    const hasScene = /scene|canvas|cockpit|dashboard|panel|tower|heatmap|handover/i.test(html);
    const hasStatus = /status|state|backend|runtime|health|golden/i.test(html);
    const hasCss = /<link[^>]+stylesheet/i.test(html);
    const hasJs = /<script/i.test(html);

    const divCount = (html.match(/<div/gi) || []).length;
    const buttonCount = (html.match(/<button/gi) || []).length;
    const navLinks = (html.match(/<a /gi) || []).length;
    const panelMarkers = (html.match(/panel|card|tile|surface|metric|kpi|hud/gi) || []).length;

    let score = 0;
    if(httpOk) score += 15;
    if(hasShellV70) score += 14;
    if(hasObjectV70B) score += 16;
    if(hasNav) score += 10;
    if(hasH1) score += 9;
    if(hasScene) score += 10;
    if(hasCanvas) score += 8;
    if(hasStatus) score += 8;
    if(hasCss) score += 5;
    if(hasJs) score += 5;

    let sharpRisk = 0;
    if(panelMarkers < 8) sharpRisk += 10;
    if(divCount > 160 && !hasObjectV70B) sharpRisk += 14;
    if(buttonCount > 8 && navLinks < 5) sharpRisk += 8;
    if(!hasCanvas && target.tier === "rf-simulation") sharpRisk += 10;
    if(strictMode && !hasShellV70) sharpRisk += 8;
    if(strictMode && !hasObjectV70B) sharpRisk += 10;

    score = Math.max(0, Math.min(100, score - sharpRisk));

    const issues = [];
    if(!hasShellV70) issues.push("manca shell v70");
    if(!hasObjectV70B) issues.push("manca object system v70B");
    if(!hasNav) issues.push("manca nav");
    if(!hasH1) issues.push("manca H1");
    if(!hasScene) issues.push("pochi marker scena");
    if(target.tier === "rf-simulation" && !hasCanvas) issues.push("RF sim senza canvas");
    if(sharpRisk > 12) issues.push("sharpness residua alta");

    return {
      ...target,
      httpOk,
      hasShellV70,
      hasObjectV70B,
      hasNav,
      hasH1,
      hasCanvas,
      hasScene,
      hasStatus,
      divCount,
      buttonCount,
      navLinks,
      panelMarkers,
      sharpRisk,
      score,
      issues
    };
  }

  function renderRows(rows){
    const tbody = $("qa_rows");
    tbody.innerHTML = rows.map(r => `
      <tr>
        <td><a href="${r.url}" target="qa_page">${r.label}</a><br/><small>${r.tier}</small></td>
        <td>${badge(r.httpOk)}</td>
        <td>${badge(r.hasShellV70)}</td>
        <td>${badge(r.hasObjectV70B)}</td>
        <td>${badge(r.hasNav)}</td>
        <td>${badge(r.hasH1)}</td>
        <td>${badge(r.hasScene || r.hasCanvas, r.hasScene ? "SCN" : "NO")}</td>
        <td>${r.sharpRisk <= 8 ? badge(true) : r.sharpRisk <= 18 ? badge("WARN","MED") : badge(false,"HIGH")}</td>
        <td><span class="pill ${scoreClass(r.score)}">${r.score}</span></td>
        <td><button data-preview="${r.url}" data-label="${r.label}">Preview</button></td>
      </tr>
    `).join("");

    tbody.querySelectorAll("[data-preview]").forEach(btn => {
      btn.addEventListener("click", () => {
        $("preview_frame").src = btn.dataset.preview;
        $("preview_label").textContent = btn.dataset.label;
      });
    });
  }

  function renderNextSteps(rows){
    const weak = rows
      .filter(r => r.score < 88 || r.issues.length)
      .sort((a,b) => a.score - b.score)
      .slice(0, 7);

    const box = $("next_steps");
    if(!weak.length){
      box.innerHTML = `<div><b>QA PASS</b><span>Tutte le pagine strategiche hanno superato la soglia visuale impostata.</span></div>`;
      return;
    }

    box.innerHTML = weak.map(r => `
      <div>
        <b>${r.label} · ${r.score}/100</b>
        <span>${r.issues.length ? r.issues.join(" · ") : "rifinitura consigliata"}</span>
      </div>
    `).join("");
  }

  async function runQa(){
    $("qa_state").textContent = "QA RUN";
    $("qa_state").className = "warn";

    const cfg = await loadTargets();
    const rows = [];

    for(const target of cfg.targets){
      try{
        const r = await fetch(target.url, {cache:"no-store"});
        const html = r.ok ? await r.text() : "";
        rows.push(analyzeHtml(target, html, r.ok));
      }catch(e){
        rows.push(analyzeHtml(target, "", false));
      }
    }

    lastReport = {
      version: "TRFMC v0.71A",
      strictMode,
      timestamp: new Date().toISOString(),
      rows
    };

    renderRows(rows);
    renderNextSteps(rows);

    const avg = Math.round(rows.reduce((a,r)=>a+r.score,0) / Math.max(1, rows.length));
    $("score_big").textContent = avg + "%";
    $("qa_score").textContent = "Score " + avg + "%";
    $("qa_score").className = avg >= 88 ? "" : avg >= 72 ? "warn" : "crit";
    $("score_label").textContent = avg >= 88 ? "enterprise visual coherence" : avg >= 72 ? "needs surgical refinement" : "major visual governance required";
    $("qa_state").textContent = "QA DONE";
    $("qa_state").className = avg >= 88 ? "" : "warn";

    if(rows.length && !$("preview_frame").src){
      $("preview_frame").src = rows[0].url;
      $("preview_label").textContent = rows[0].label;
    }
  }

  function exportJson(){
    if(!lastReport) return;
    const blob = new Blob([JSON.stringify(lastReport, null, 2)], {type:"application/json"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "trfmc_visual_qa_matrix_v71_report.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  document.addEventListener("DOMContentLoaded", () => {
    $("btn_run").addEventListener("click", runQa);
    $("btn_strict").addEventListener("click", e => {
      strictMode = !strictMode;
      e.currentTarget.classList.toggle("active", strictMode);
      runQa();
    });
    $("btn_export").addEventListener("click", exportJson);

    backendHealth();
    setInterval(backendHealth, 8000);
    runQa();
  });
})();
