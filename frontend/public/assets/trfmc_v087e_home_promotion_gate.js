(function(){
  const ROOT = document.querySelector('[data-trfmc-page="trfmc-home-v87e"]');
  if(!ROOT) return;

  const $ = (s) => ROOT.querySelector(s);
  const canvas = $("#cd87Canvas");
  const ctx = canvas.getContext("2d", {alpha:true});

  const state = {
    manifest:null,
    ok:{},
    selected:null,
    particles:[],
    beams:[]
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
    seedFX();
  }

  function seedFX(){
    state.particles = Array.from({length:135}, () => ({
      x: Math.random() * window.innerWidth,
      y: Math.random() * window.innerHeight,
      r: 0.45 + Math.random() * 2.4,
      vx: -0.20 + Math.random() * 0.40,
      vy: -0.10 + Math.random() * 0.20,
      a: 0.15 + Math.random() * 0.42
    }));

    state.beams = Array.from({length:9}, (_,i) => ({
      y: window.innerHeight * (0.18 + Math.random() * 0.70),
      phase: Math.random() * Math.PI * 2,
      speed: 0.55 + Math.random() * 0.80,
      amp: 14 + Math.random() * 32
    }));
  }

  function draw(){
    if(!ctx) return;

    const w = window.innerWidth;
    const h = window.innerHeight;
    const t = performance.now() * 0.001;

    ctx.clearRect(0,0,w,h);
    ctx.save();
    ctx.globalCompositeOperation = "lighter";

    for(const p of state.particles){
      p.x += p.vx;
      p.y += p.vy;
      if(p.x < -30) p.x = w + 30;
      if(p.x > w + 30) p.x = -30;
      if(p.y < -30) p.y = h + 30;
      if(p.y > h + 30) p.y = -30;

      ctx.beginPath();
      ctx.fillStyle = `rgba(143,240,255,${p.a})`;
      ctx.arc(p.x,p.y,p.r,0,Math.PI*2);
      ctx.fill();
    }

    for(const b of state.beams){
      const y0 = b.y + Math.sin(t * b.speed + b.phase) * b.amp;
      const grad = ctx.createLinearGradient(0,y0,w,y0);
      grad.addColorStop(0,"rgba(143,240,255,0)");
      grad.addColorStop(0.50,"rgba(143,240,255,0.18)");
      grad.addColorStop(1,"rgba(66,245,111,0)");

      ctx.strokeStyle = grad;
      ctx.lineWidth = 1.4;
      ctx.beginPath();

      for(let x=0;x<=w;x+=20){
        const yy = y0 + Math.sin(x*0.008 + t*1.5 + b.phase) * 22;
        if(x===0) ctx.moveTo(x,yy);
        else ctx.lineTo(x,yy);
      }

      ctx.stroke();
    }

    const cx = w * 0.50;
    const cy = h * 0.54;
    for(let r=140;r<620;r+=110){
      ctx.beginPath();
      ctx.strokeStyle = `rgba(66,245,111,${0.045 + 0.025*Math.sin(t+r)})`;
      ctx.lineWidth = 1;
      ctx.arc(cx,cy,r + Math.sin(t+r)*4,0,Math.PI*2);
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
    const map = $("#cd87MissionMap");
    const center = {x:50,y:50};

    const links = routes.map(r => {
      const dx = r.x - center.x;
      const dy = r.y - center.y;
      const len = Math.sqrt(dx*dx + dy*dy);
      const angle = Math.atan2(dy,dx) * 180 / Math.PI;
      return `<div class="cd87-link" style="left:${center.x}%;top:${center.y}%;width:${len}%;transform:rotate(${angle}deg);"></div>`;
    }).join("");

    const nodes = routes.map(r => `
      <button class="cd87-node ${state.selected && state.selected.id === r.id ? "active" : ""}" data-id="${esc(r.id)}" style="left:${r.x}%;top:${r.y}%;">
        <b>${esc(r.title)}</b>
        <small>${esc(r.subtitle)}</small>
        <i>${esc(r.priority)} · ${state.ok[r.file] ? "HTTP 200" : "CHECK"}</i>
      </button>
    `).join("");

    map.innerHTML = `<div class="cd87-core"></div>` + links + nodes;

    Array.from(map.querySelectorAll(".cd87-node")).forEach(btn => {
      btn.addEventListener("click", () => {
        const id = btn.getAttribute("data-id");
        state.selected = routes.find(r => r.id === id) || routes[0];
        renderMap();
        renderInspector();
      });
    });
  }

  function renderInspector(){
    const box = $("#cd87InspectorBody");
    const r = state.selected || (state.manifest.mission_routes || [])[0];

    if(!r){
      box.textContent = "Nessuna rotta disponibile.";
      return;
    }

    $("#cd87LayerStatus").textContent = state.ok[r.file] ? "HTTP 200" : "check";

    box.innerHTML = `
      <b>${esc(r.title)}</b>
      <p>${esc(r.subtitle)}</p>
      <code>domain: ${esc(r.domain)}
metric: ${esc(r.metric)}
priority: ${esc(r.priority)}
file: ${esc(r.file)}
state: ${state.ok[r.file] ? "reachable" : "not validated"}</code>
      <p>${explain(r.id)}</p>
      <a class="cd87-open" href="/${encodeURIComponent(r.file)}">Open selected mission layer</a>
    `;
  }

  function explain(id){
    const m = {
      "rf-console":"Console principale: misura campo, canale, SINR, qualità e decisione.",
      "stable-field":"Rientro sicuro: mantiene una baseline stabile per confronto e rollback.",
      "digital-twin":"Strato fisico: collega RF a sito, shelter, torre, energia e trasporto.",
      "handover":"Strato dinamico: mobilità UE, cell edge, serving decision e continuità.",
      "vegetation":"Strato ambientale: clutter, attenuazione vegetativa e shadowing locale.",
      "theory":"Strato didattico: formula, metodo, evidenza, trasferimento della sapienza."
    };
    return m[id] || "Strato missione.";
  }

  function renderDeck(){
    const routes = state.manifest.mission_routes || [];
    $("#cd87DeckCount").textContent = routes.length + " mission routes";

    $("#cd87LaunchDeck").innerHTML = routes.map(r => `
      <article class="cd87-card">
        <b>${esc(r.title)}</b>
        <small>${esc(r.domain)}</small>
        <p>${esc(r.metric)}</p>
        <a class="cd87-open" href="/${encodeURIComponent(r.file)}">Open</a>
      </article>
    `).join("");

    $("#cd87EngineeringDeck").innerHTML = (state.manifest.engineering_routes || []).map(r => `
      <article class="cd87-eng-card">
        <b>${esc(r.title)}</b>
        <small>engineering / service</small>
        <p>Pagina utile per governo, audit o rientro; non è facciata operativa.</p>
        <a class="cd87-open" href="/${encodeURIComponent(r.file)}">Open service</a>
      </article>
    `).join("");
  }

  async function boot(){
    resize();
    requestAnimationFrame(draw);

    try{
      const res = await fetch("/reports/trfmc_v87e_home_promotion_manifest.json?ts=" + Date.now(), {cache:"no-store"});
      if(!res.ok) throw new Error("manifest HTTP " + res.status);
      state.manifest = await res.json();

      const routes = state.manifest.mission_routes || [];
      const checks = await Promise.all(routes.map(r => routeOk(r.file)));
      routes.forEach((r,i) => state.ok[r.file] = checks[i]);

      const okCount = checks.filter(Boolean).length;
      const score = Math.round((okCount / Math.max(1,routes.length)) * 100);

      $("#cd87Status").textContent = score >= 80 ? "READY" : "WATCH";
      $("#cd87Score").textContent = score + "%";
      $("#cd87ScoreText").textContent = okCount + "/" + routes.length + " mission routes HTTP 200";
      $("#cd87MissionCount").textContent = routes.length;
      $("#cd87OkCount").textContent = okCount;
      $("#cd87EngCount").textContent = (state.manifest.engineering_routes || []).length;

      state.selected = routes[0] || null;
      renderMap();
      renderInspector();
      renderDeck();

    }catch(err){
      $("#cd87Status").textContent = "ERROR";
      $("#cd87Score").textContent = "0%";
      $("#cd87InspectorBody").textContent = "Errore manifest: " + err.message;
    }
  }

  window.addEventListener("resize", resize);
  boot();
})();
