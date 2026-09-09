(function(){
  const $ = (s) => document.querySelector(s);
  const $$ = (s) => Array.from(document.querySelectorAll(s));

  function log10(x){ return Math.log10(Math.max(x, 1e-9)); }

  function fspl1m(fMHz){
    return 32.44 + 20*log10(fMHz) + 20*log10(0.001);
  }

  function pathLoss(fMHz, dM, n){
    return fspl1m(fMHz) + 10*n*log10(Math.max(dM,1));
  }

  function foliageLoss(fMHz, dVeg, density){
    const fGHz = fMHz / 1000;
    return 0.42 * Math.pow(Math.max(fGHz,0.1),0.30) * Math.pow(Math.max(dVeg,0),0.60) * density;
  }

  function num(id, fallback=0){
    const el = $("#" + id);
    return el ? Number(el.value) : fallback;
  }

  function classifyPrx(prx){
    if(prx >= -75) return ["VERY STRONG","v83d-state-good"];
    if(prx >= -90) return ["GOOD","v83d-state-good"];
    if(prx >= -100) return ["EDGE","v83d-state-warn"];
    if(prx >= -110) return ["WEAK","v83d-state-warn"];
    return ["OUTAGE","v83d-state-bad"];
  }

  function computeBudget(){
    const fMHz = num("freqMHz",3500);
    const eirp = num("eirp",46);
    const n = num("pathN",32)/10;
    const dVeg = num("vegDepth",28);
    const shadow = num("shadowDb",11);
    const g = num("sectorGain",72)/10;
    const fade = num("fading",26)/10;

    /*
      Probe UE-42 is treated as the diagnostic probe.
      Distances are synthetic scene distances, not GPS distances.
      The point is consistency and explainability, not field-survey certification.
    */
    const sites = [
      {id:"SITE-A", role:"candidate", d:390, sector:g*0.42, shadowFactor:.38, density:.52},
      {id:"SITE-B", role:"expected serving", d:185, sector:g*0.96, shadowFactor:.24, density:.44},
      {id:"SITE-C", role:"interferer/load", d:265, sector:g*0.58, shadowFactor:.62, density:.58}
    ];

    const rows = sites.map(s => {
      const pl = pathLoss(fMHz, s.d, n);
      const veg = foliageLoss(fMHz, dVeg, s.density);
      const sh = shadow * s.shadowFactor;
      const fd = fade * 0.30;
      const prx = eirp + s.sector - pl - veg - sh - fd;
      return {...s, pl, veg, sh, fd, prx};
    }).sort((a,b) => b.prx - a.prx);

    const serving = rows[0];
    const interferer = rows[1];
    const sinr = Math.max(-8, Math.min(34, serving.prx - interferer.prx - 3.5));
    const totalLoss = serving.pl + serving.veg + serving.sh + serving.fd;

    const rsrpScore = Math.max(0, Math.min(100, ((serving.prx + 112) / 42) * 100));
    const sinrScore = Math.max(0, Math.min(100, ((sinr + 5) / 30) * 100));
    const lossScore = Math.max(0, Math.min(100, 100 - Math.max(0,totalLoss-105)*1.2));
    const coverage = Math.max(0, Math.min(100, Math.round(
      0.50*rsrpScore + 0.40*sinrScore + 0.10*lossScore -
      Math.max(0,shadow-12)*0.55 -
      Math.max(0,fade-3)*2.0
    )));

    return {fMHz,eirp,n,dVeg,shadow,g,fade,rows,serving,interferer,sinr,totalLoss,coverage};
  }

  function ensureDocks(){
    document.body.classList.add("v83d-instrument");
    document.title = "TRFMC v0.83D · Instrument Layout + Link Budget Inspector";

    const formula = $(".formula-dock");
    const stage = $(".stage");

    if(stage && !$(".v83d-serving-vector")){
      const vector = document.createElement("div");
      vector.className = "v83d-serving-vector";
      stage.appendChild(vector);
    }

    if(formula && !$(".v83d-budget-dock")){
      const dock = document.createElement("section");
      dock.className = "v83d-budget-dock";
      dock.innerHTML = `
        <div class="v83d-budget-head">
          <div>
            <h3>Link Budget Inspector · UE-42 Probe</h3>
            <p>Tracciabilità SITE → distanza → path loss → vegetazione/clutter → shadowing → Prx → interferenza → SINR. Questa sezione rende verificabile la matematica sotto la grafica.</p>
          </div>
          <div class="chip" id="v83dBestChip">BEST SERVER —</div>
        </div>
        <table class="v83d-table">
          <thead>
            <tr>
              <th>Site</th>
              <th>Distance</th>
              <th>PL</th>
              <th>Veg</th>
              <th>Shadow</th>
              <th>Sector G</th>
              <th>Prx</th>
              <th>State</th>
            </tr>
          </thead>
          <tbody id="v83dBudgetRows"></tbody>
        </table>
      `;
      formula.insertAdjacentElement("beforebegin", dock);
    }

    if(formula && !$(".v83d-instrument-dock")){
      const info = document.createElement("section");
      info.className = "v83d-instrument-dock";
      info.innerHTML = `
        <article class="v83d-card">
          <h3>Sanity Rule</h3>
          <code>Best-server = max(PrxSITE-A, PrxSITE-B, PrxSITE-C)</code>
          <p>Il sito dominante non è scelto “a occhio”: deriva dalla potenza ricevuta stimata dopo path loss e perdite ambientali.</p>
        </article>
        <article class="v83d-card">
          <h3>Interference Rule</h3>
          <code>SINR ≈ Prx_serving - Prx_interferer - margin</code>
          <p>Se il secondo sito è troppo vicino in potenza, la qualità scende anche con RSRP forte.</p>
        </article>
        <article class="v83d-card">
          <h3>Visual Rule</h3>
          <code>Canvas = soglia RSRP · Score = RSRP + SINR + Loss</code>
          <p>La mappa mostra campo RF; il punteggio operativo include anche interferenza e qualità.</p>
        </article>
      `;
      formula.insertAdjacentElement("beforebegin", info);
    }

    const eyebrow = $(".eyebrow");
    if(eyebrow) eyebrow.textContent = "TRFMC v0.83D · INSTRUMENT LAYOUT + LINK BUDGET INSPECTOR";

    const h1 = $("h1");
    if(h1) h1.textContent = "RF Instrument Layout + Link Budget Inspector";
  }

  function updateVector(){
    const stage = $(".stage");
    const vector = $(".v83d-serving-vector");
    const site = $(".site-b");
    const ue = $(".ue2");

    if(!stage || !vector || !site || !ue) return;

    const sr = stage.getBoundingClientRect();
    const a = site.getBoundingClientRect();
    const b = ue.getBoundingClientRect();

    const x1 = a.left + a.width/2 - sr.left;
    const y1 = a.top + a.height/2 - sr.top;
    const x2 = b.left + b.width/2 - sr.left;
    const y2 = b.top + b.height/2 - sr.top;

    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = Math.sqrt(dx*dx + dy*dy);
    const deg = Math.atan2(dy, dx) * 180 / Math.PI;

    vector.style.left = x1 + "px";
    vector.style.top = y1 + "px";
    vector.style.width = len + "px";
    vector.style.transform = "rotate(" + deg + "deg)";
  }

  function updateBudgetDock(){
    const b = computeBudget();
    const tbody = $("#v83dBudgetRows");
    const chip = $("#v83dBestChip");

    if(tbody){
      tbody.innerHTML = b.rows.map((r, idx) => {
        const [state, cls] = classifyPrx(r.prx);
        const trClass = idx === 0 ? "serving" : "interferer";
        return `
          <tr class="${trClass}">
            <td>${r.id}</td>
            <td>${r.d.toFixed(0)} m</td>
            <td>${r.pl.toFixed(1)} dB</td>
            <td>${r.veg.toFixed(1)} dB</td>
            <td>${r.sh.toFixed(1)} dB</td>
            <td>${r.sector.toFixed(1)} dB</td>
            <td>${r.prx.toFixed(1)} dBm</td>
            <td class="${cls}">${state}</td>
          </tr>
        `;
      }).join("");
    }

    if(chip){
      chip.textContent = `BEST SERVER ${b.serving.id} · SINR ${b.sinr.toFixed(1)} dB · SCORE ${b.coverage}%`;
    }

    const copilot = $("#copilot");
    if(copilot){
      copilot.innerHTML = `
        <b>AI RF Copilot</b>
        <p>v83D inspector: best server ${b.serving.id}, Prx=${b.serving.prx.toFixed(1)} dBm,
        strongest interferer ${b.interferer.id}=${b.interferer.prx.toFixed(1)} dBm,
        SINR≈${b.sinr.toFixed(1)} dB, coverage≈${b.coverage}%.</p>
      `;
    }
  }

  function bind(){
    ["freqMHz","eirp","pathN","vegDepth","shadowDb","sectorGain","fading"].forEach(id => {
      const el = $("#" + id);
      if(el) el.addEventListener("input", () => {
        setTimeout(() => {
          updateBudgetDock();
          updateVector();
        }, 30);
      });
    });

    window.addEventListener("resize", () => {
      setTimeout(updateVector, 100);
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    setTimeout(() => {
      ensureDocks();
      updateBudgetDock();
      updateVector();
      bind();
    }, 350);

    setTimeout(() => {
      ensureDocks();
      updateBudgetDock();
      updateVector();
    }, 900);
  });
})();
