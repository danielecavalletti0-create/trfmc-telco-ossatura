(function(){
  const ROOT = document.querySelector('[data-trfmc-page="cinematic-mission-atlas-v87c"]');
  if(!ROOT) return;

  const $ = (s) => ROOT.querySelector(s);
  const canvas = $("#ca87Canvas");
  const ctx = canvas.getContext("2d", {alpha:true});

  const state = {
    manifest:null,
    ok:{},
    selected:null,
    particles:[]
  };

  function esc(s){
    return String(s ?? "")
      .replaceAll("&","&amp;")
      .replaceAll("<","&lt;")
      .replaceAll(">","&gt;")
      .replaceAll('"',"&quot;");
  }

  function resize(){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = Math.floor(window.innerWidth * dpr);
    canvas.height = Math.floor(window.innerHeight * dpr);
    ctx.setTransform(dpr,0,0,dpr,0,0);
  }

  function initParticles(){
    state.particles = Array.from({length:95}, () => ({
      x: Math.random() * window.innerWidth,
      y: Math.random() * window.innerHeight,
      r: 0.6 + Math.random() * 2.1,
      vx: -0.16 + Math.random() * 0.32,
      vy: -0.09 + Math.random() * 0.18,
      a: 0.18 + Math.random() * 0.42
    }));
  }

  function draw(){
    if(!ctx) return;
    ctx.clearRect(0,0,window.innerWidth,window.innerHeight);

    const w = window.innerWidth;
    const h = window.innerHeight;
    const t = performance.now() * 0.001;

    ctx.save();
    ctx.globalCompositeOperation = "lighter";

    for(const p of state.particles){
      p.x += p.vx;
      p.y += p.vy;
      if(p.x < -20) p.x = w + 20;
      if(p.x > w + 20) p.x = -20;
      if(p.y < -20) p.y = h + 20;
      if(p.y > h + 20) p.y = -20;

      ctx.beginPath();
      ctx.fillStyle = `rgba(143,240,255,${p.a})`;
      ctx.arc(p.x,p.y,p.r,0,Math.PI*2);
      ctx.fill();
    }

    for(let i=0;i<7;i++){
      const y = (h * 0.18) + i * 82 + Math.sin(t + i) * 18;
      const grad = ctx.createLinearGradient(0,y,w,y);
      grad.addColorStop(0,"rgba(143,240,255,0)");
      grad.addColorStop(0.5,"rgba(143,240,255,0.13)");
      grad.addColorStop(1,"rgba(66,245,111,0)");
      ctx.strokeStyle = grad;
      ctx.lineWidth = 1;
      ctx.beginPath();
      for(let x=0;x<=w;x+=24){
        const yy = y + Math.sin(x*0.007 + t*1.6 + i) * 18;
        if(x===0) ctx.moveTo(x,yy);
        else ctx.lineTo(x,yy);
      }
      ctx.stroke();
    }

    ctx.restore();
    requestAnimationFrame(draw);
  }

  async function routeOk(file){
    try{
      const res = await fetch("/" + file + "?ts=" + Date.now(), {cache:"no-store"});
      return res.ok;
    }catch(_){
      return false;
    }
  }

  function renderMap(){
    const routes = state.manifest.mission_routes || [];
    const map = $("#ca87Map");
    const center = {x:50,y:50};

    const links = routes.map(r => {
      const dx = r.x - center.x;
      const dy = r.y - center.y;
      const len = Math.sqrt(dx*dx + dy*dy);
      const angle = Math.atan2(dy,dx) * 180 / Math.PI;
      return `<div class="ca87-link" style="left:${center.x}%;top:${center.y}%;width:${len}%;transform:rotate(${angle}deg);"></div>`;
    }).join("");

    const nodes = routes.map((r, i) => `
      <button class="ca87-node ${state.selected && state.selected.id === r.id ? "active" : ""}" data-id="${esc(r.id)}" style="left:${r.x}%;top:${r.y}%;">
        <b>${esc(r.title)}</b>
        <small>${esc(r.subtitle)}</small>
        <i>${state.ok[r.file] ? "HTTP 200" : "CHECK"}</i>
      </button>
    `).join("");

    map.innerHTML = links + nodes;

    Array.from(map.querySelectorAll(".ca87-node")).forEach(btn => {
      btn.addEventListener("click", () => {
        const id = btn.getAttribute("data-id");
        state.selected = routes.find(r => r.id === id) || routes[0];
        renderMap();
        renderSelected();
      });
    });
  }

  function renderSelected(){
    const box = $("#ca87SelectedBox");
    const r = state.selected || (state.manifest.mission_routes || [])[0];

    if(!r){
      box.textContent = "Nessuna rotta disponibile.";
      return;
    }

    $("#ca87SelectedStatus").textContent = state.ok[r.file] ? "HTTP 200" : "check";

    box.innerHTML = `
      <b>${esc(r.title)}</b>
      <p>${esc(r.subtitle)}</p>
      <code>domain: ${esc(r.domain)}
file: ${esc(r.file)}
state: ${state.ok[r.file] ? "reachable" : "not validated"}
role: ${esc(r.kind)}</code>
      <p>${missionText(r.kind)}</p>
      <a class="ca87-open" href="/${encodeURIComponent(r.file)}">Open selected mission layer</a>
    `;
  }

  function missionText(kind){
    const map = {
      primary:"Strato principale: qui si misura, si interpreta e si decide.",
      stable:"Base di rientro: preserva una condizione sana e confrontabile.",
      infra:"Strato fisico: collega RF, shelter, torre, alimentazione e trasporto.",
      mobility:"Strato dinamico: UE, handover, margine e continuità di servizio.",
      theory:"Strato didattico: formule, metodo, evidenza e trasmissione della conoscenza."
    };
    return map[kind] || "Strato missione.";
  }

  function renderDeck(){
    const routes = state.manifest.mission_routes || [];
    $("#ca87DeckCount").textContent = routes.length + " mission routes";

    $("#ca87Deck").innerHTML = routes.map(r => `
      <article class="ca87-card">
        <b>${esc(r.title)}</b>
        <small>${esc(r.domain)}</small>
        <p>${esc(r.subtitle)}</p>
        <a class="ca87-open" href="/${encodeURIComponent(r.file)}">Open</a>
      </article>
    `).join("");

    $("#ca87EngineeringDeck").innerHTML = (state.manifest.engineering_routes || []).map(r => `
      <article class="ca87-eng-card">
        <b>${esc(r.title)}</b>
        <small>service / engineering</small>
        <p>Disponibile dietro la baia tecnica, non come facciata operativa.</p>
        <a class="ca87-open" href="/${encodeURIComponent(r.file)}">Open service</a>
      </article>
    `).join("");
  }

  async function boot(){
    resize();
    initParticles();
    requestAnimationFrame(draw);

    try{
      const res = await fetch("/reports/trfmc_v87c_cinematic_mission_atlas_manifest.json?ts=" + Date.now(), {cache:"no-store"});
      if(!res.ok) throw new Error("manifest HTTP " + res.status);
      state.manifest = await res.json();

      const routes = state.manifest.mission_routes || [];
      const checks = await Promise.all(routes.map(r => routeOk(r.file)));
      routes.forEach((r,i) => state.ok[r.file] = checks[i]);

      const okCount = checks.filter(Boolean).length;
      const score = Math.round((okCount / Math.max(1,routes.length)) * 100);

      $("#ca87Status").textContent = score >= 80 ? "READY" : "WATCH";
      $("#ca87Score").textContent = score + "%";
      $("#ca87ScoreText").textContent = okCount + "/" + routes.length + " mission routes HTTP 200";
      $("#ca87MissionCount").textContent = routes.length;
      $("#ca87EngCount").textContent = (state.manifest.engineering_routes || []).length;
      $("#ca87OkCount").textContent = okCount;

      state.selected = routes[0] || null;
      renderMap();
      renderSelected();
      renderDeck();

    }catch(err){
      $("#ca87Status").textContent = "ERROR";
      $("#ca87Score").textContent = "0%";
      $("#ca87SelectedBox").textContent = "Errore manifest: " + err.message;
    }
  }

  window.addEventListener("resize", () => {
    resize();
    initParticles();
  });

  boot();
})();
