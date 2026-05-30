(function(){
  "use strict";

  const $ = id => document.getElementById(id);
  const canvas = $("v69_canvas");
  const ctx = canvas.getContext("2d", { alpha:false });

  const state = {
    ueCount: 64,
    speed: 1.35,
    hyst: 3,
    ttt: 320,
    clutter: 0.74,
    paused: false,
    rush: false,
    park: false,
    fps: 0,
    frame: 0,
    lastFps: performance.now(),
    lastT: performance.now(),
    hoEvents: [],
    pingpong: 0,
    drops: 0,
    handoverTotal: 0,
    particles: [],
    logSeen: 0
  };

  const dpr = () => Math.min(window.devicePixelRatio || 1, 2);

  const sites = [
    { id:"SITE-A", x:.17, y:.72, color:"#8ff0ff", rgb:[143,240,255] },
    { id:"SITE-B", x:.52, y:.28, color:"#42f56f", rgb:[66,245,111] },
    { id:"SITE-C", x:.82, y:.70, color:"#ff4dff", rgb:[255,77,255] }
  ];

  const buildings = [
    [.29,.28,.075,.19], [.39,.22,.060,.15], [.61,.30,.085,.20],
    [.71,.24,.070,.17], [.22,.52,.070,.15], [.34,.58,.110,.18],
    [.55,.56,.065,.16], [.69,.54,.090,.20], [.45,.74,.080,.14],
    [.77,.78,.075,.16], [.14,.36,.060,.14], [.86,.40,.055,.13]
  ];

  const trees = [
    [.24,.42,.055], [.29,.45,.045], [.34,.40,.050], [.42,.43,.058],
    [.47,.47,.044], [.52,.42,.048], [.58,.45,.055],
    [.33,.79,.050], [.40,.83,.060], [.48,.80,.052], [.56,.84,.048],
    [.67,.37,.050], [.73,.35,.058], [.79,.33,.044], [.84,.31,.049]
  ];

  let ues = [];

  function clamp(v,min,max){ return Math.max(min, Math.min(max, v)); }
  function lerp(a,b,t){ return a + (b-a)*t; }
  function dist(a,b,c,d){ return Math.hypot(a-c,b-d); }

  function resize(){
    const r = dpr();
    const w = Math.floor(innerWidth * r);
    const h = Math.floor(innerHeight * r);
    if(canvas.width !== w || canvas.height !== h){
      canvas.width = w;
      canvas.height = h;
      canvas.style.width = innerWidth + "px";
      canvas.style.height = innerHeight + "px";
      ctx.setTransform(r,0,0,r,0,0);
    }
  }

  function addLog(msg, cls=""){
    const log = $("event_log");
    const el = document.createElement("div");
    if(cls) el.className = cls;
    el.textContent = "AI RF Copilot: " + msg;
    log.prepend(el);
    while(log.children.length > 10) log.lastChild.remove();
  }

  function initUE(){
    ues = [];
    const count = state.ueCount;
    for(let i=0;i<count;i++){
      const roadBand = i % 4;
      const x = 0.10 + Math.random()*0.80;
      const y = [0.36,0.50,0.64,0.78][roadBand] + (Math.random()-.5)*0.025;
      const a = Math.random() * Math.PI * 2;
      const serving = nearestSite(x,y);
      ues.push({
        id:i,
        x,y,
        vx: Math.cos(a) * (0.00025 + Math.random()*0.00038),
        vy: Math.sin(a) * (0.00018 + Math.random()*0.00030),
        type: Math.random() < .22 ? "V2X" : "UE",
        serving,
        lastServing: serving,
        candidate: serving,
        candidateMs: 0,
        rsrp: -90,
        sinr: 12,
        dropped: false,
        handovers: 0,
        lastHo: 0,
        trail: [],
        jitter: Math.random()*1000
      });
    }
    state.hoEvents = [];
    state.pingpong = 0;
    state.drops = 0;
    state.handoverTotal = 0;
    addLog("popolazione UE rigenerata: " + count + " entità mobili.", "ok");
  }

  function nearestSite(x,y){
    let best = 0, bd = Infinity;
    sites.forEach((s,i)=>{
      const d = dist(x,y,s.x,s.y);
      if(d < bd){ bd = d; best = i; }
    });
    return best;
  }

  function lineIntersectsRect(x1,y1,x2,y2,rx,ry,rw,rh){
    const minX = rx-rw, maxX = rx+rw;
    const minY = ry-rh, maxY = ry+rh;
    const steps = 18;
    for(let i=0;i<=steps;i++){
      const t = i/steps;
      const x = lerp(x1,x2,t);
      const y = lerp(y1,y2,t);
      if(x>=minX && x<=maxX && y>=minY && y<=maxY) return true;
    }
    return false;
  }

  function lineCrossesCircle(x1,y1,x2,y2,cx,cy,r){
    const dx = x2-x1, dy = y2-y1;
    const l2 = dx*dx + dy*dy;
    if(l2 === 0) return dist(x1,y1,cx,cy) <= r;
    let t = ((cx-x1)*dx + (cy-y1)*dy) / l2;
    t = clamp(t,0,1);
    const px = x1 + t*dx;
    const py = y1 + t*dy;
    return dist(px,py,cx,cy) <= r;
  }

  function clutterLoss(site, ue){
    let loss = 0;
    for(const b of buildings){
      if(lineIntersectsRect(site.x,site.y,ue.x,ue.y,b[0],b[1],b[2],b[3])){
        loss += 13 + 12*state.clutter;
      }
    }
    for(const tr of trees){
      if(lineCrossesCircle(site.x,site.y,ue.x,ue.y,tr[0],tr[1],tr[2]*(0.9+state.clutter*.4))){
        loss += 3.5 + 7.5*state.clutter;
      }
    }
    if(state.park && ue.x > .22 && ue.x < .62 && ue.y > .35 && ue.y < .55) loss += 8;
    return Math.min(loss, 42);
  }

  function signalFor(siteIdx, ue){
    const s = sites[siteIdx];
    const d = Math.max(0.035, dist(s.x,s.y,ue.x,ue.y));
    const fspl = 37 * Math.log10(1 + d*18);
    const loadPenalty = state.rush ? 3.5 : 0;
    const randomFading = Math.sin(performance.now()*0.0015 + ue.jitter + siteIdx*1.7) * 1.8;
    const loss = clutterLoss(s, ue);
    return -54 - fspl - loss - loadPenalty + randomFading;
  }

  function updateUE(dt, now){
    const loads = [0,0,0];
    let rsrpSum = 0, sinrSum = 0, drops = 0;

    for(const ue of ues){
      if(!state.paused){
        const speedBoost = state.speed * (state.rush && ue.type === "V2X" ? 1.35 : 1);
        ue.x += ue.vx * dt * speedBoost;
        ue.y += ue.vy * dt * speedBoost;

        if(ue.x < .07 || ue.x > .93){ ue.vx *= -1; ue.x = clamp(ue.x,.07,.93); }
        if(ue.y < .23 || ue.y > .88){ ue.vy *= -1; ue.y = clamp(ue.y,.23,.88); }

        if(state.rush){
          const lanePull = [.36,.50,.64,.78][ue.id % 4];
          ue.y = lerp(ue.y, lanePull + Math.sin(now*.001 + ue.id)*0.012, .014);
        }
      }

      const signals = sites.map((_,i)=>signalFor(i,ue));
      let bestIdx = 0;
      for(let i=1;i<signals.length;i++) if(signals[i] > signals[bestIdx]) bestIdx = i;

      const current = signals[ue.serving];
      const best = signals[bestIdx];

      if(bestIdx !== ue.serving && best > current + state.hyst){
        if(ue.candidate === bestIdx) ue.candidateMs += dt;
        else {
          ue.candidate = bestIdx;
          ue.candidateMs = 0;
        }

        if(ue.candidateMs >= state.ttt){
          const old = ue.serving;
          ue.lastServing = old;
          ue.serving = bestIdx;
          ue.candidate = bestIdx;
          ue.candidateMs = 0;
          ue.handovers++;
          state.handoverTotal++;
          state.hoEvents.push(now);
          state.particles.push({
            x:ue.x,y:ue.y,t:0,color:sites[bestIdx].color,txt:sites[old].id+" → "+sites[bestIdx].id
          });

          if(now - ue.lastHo < 4500){
            state.pingpong++;
            addLog("ping-pong rilevato su " + ue.type + "-" + ue.id + " tra " + sites[old].id + " e " + sites[bestIdx].id + ".", "warn");
          } else if(state.handoverTotal % 8 === 0){
            addLog("handover stabile completato: " + sites[old].id + " → " + sites[bestIdx].id + ".", "ok");
          }
          ue.lastHo = now;
        }
      } else {
        ue.candidateMs = Math.max(0, ue.candidateMs - dt*0.8);
      }

      ue.rsrp = signals[ue.serving];
      const interference = signals.reduce((a,v,i)=> i===ue.serving ? a : a + Math.pow(10, v/10), 0);
      const servingLin = Math.pow(10, ue.rsrp/10);
      const sinrLin = servingLin / (interference + Math.pow(10, -112/10));
      ue.sinr = clamp(10*Math.log10(sinrLin) - state.clutter*2, -8, 32);
      ue.dropped = ue.rsrp < -112 || ue.sinr < -3;

      if(ue.dropped) drops++;
      else loads[ue.serving]++;

      rsrpSum += ue.rsrp;
      sinrSum += ue.sinr;

      if(!state.paused){
        ue.trail.push([ue.x,ue.y]);
        if(ue.trail.length > 24) ue.trail.shift();
      }
    }

    state.drops = drops;

    const avgRsrp = rsrpSum / Math.max(1, ues.length);
    const avgSinr = sinrSum / Math.max(1, ues.length);
    const cutoff = now - 60000;
    state.hoEvents = state.hoEvents.filter(t => t >= cutoff);
    const hoRate = state.hoEvents.length;
    const dropRisk = (drops / Math.max(1, ues.length)) * 100;
    const maxLoad = Math.max(...loads);
    const dominant = loads.indexOf(maxLoad);

    $("avg_rsrp").textContent = avgRsrp.toFixed(1) + " dBm";
    $("avg_sinr").textContent = avgSinr.toFixed(1) + " dB";
    $("ho_rate").textContent = hoRate + "/min";
    $("drop_risk").textContent = dropRisk.toFixed(1) + "%";
    $("pingpong").textContent = state.pingpong;
    $("dominant_site").textContent = sites[dominant].id;

    const denom = Math.max(1, loads.reduce((a,b)=>a+b,0));
    [["load_a",0],["load_b",1],["load_c",2]].forEach(([id,idx])=>{
      const pct = Math.round(loads[idx]*100/denom);
      $(id).style.width = pct + "%";
      $(id+"_txt").textContent = pct + "%";
    });

    const stability = clamp(100 - dropRisk*2.2 - state.pingpong*.55 - Math.max(0, hoRate-26)*.9, 0, 100);
    $("mobility_score").textContent = Math.round(stability) + "%";
    $("mobility_state").textContent =
      stability > 86 ? "stable mobility domain" :
      stability > 68 ? "watch handover borders" :
      stability > 44 ? "unstable mobility / tune hyst + TTT" :
      "critical RF mobility degradation";

    document.body.dataset.risk =
      stability > 68 ? "ok" : stability > 44 ? "warn" : "crit";
  }

  function heatColor(v){
    v = clamp(v,0,1);
    const stops = [
      [0.00,[3,7,22]],
      [0.25,[0,70,150]],
      [0.45,[0,200,255]],
      [0.66,[66,245,111]],
      [0.84,[251,191,36]],
      [1.00,[255,255,245]]
    ];
    for(let i=0;i<stops.length-1;i++){
      const a=stops[i], b=stops[i+1];
      if(v>=a[0] && v<=b[0]){
        const t=(v-a[0])/(b[0]-a[0]);
        return `rgb(${Math.round(lerp(a[1][0],b[1][0],t))},${Math.round(lerp(a[1][1],b[1][1],t))},${Math.round(lerp(a[1][2],b[1][2],t))})`;
      }
    }
    return "rgb(255,255,245)";
  }

  function drawGrid(w,h){
    ctx.fillStyle = "#020713";
    ctx.fillRect(0,0,w,h);

    const cell = Math.max(22, Math.round(Math.min(w,h)/42));
    ctx.globalAlpha = .92;
    for(let y=0;y<h;y+=cell){
      for(let x=0;x<w;x+=cell){
        const nx = x/w, ny = y/h;
        const fake = {x:nx,y:ny,jitter:0,serving:0};
        const maxSig = Math.max(signalFor(0,fake), signalFor(1,fake), signalFor(2,fake));
        const level = clamp((maxSig + 118) / 56, 0, 1);
        ctx.fillStyle = heatColor(level);
        ctx.globalAlpha = .18 + level*.28;
        ctx.fillRect(x,y,cell+1,cell+1);
      }
    }
    ctx.globalAlpha = 1;

    ctx.strokeStyle = "rgba(143,240,255,.08)";
    ctx.lineWidth = 1;
    for(let x=0;x<w;x+=44){ ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke(); }
    for(let y=0;y<h;y+=44){ ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke(); }
  }

  function drawEnvironment(w,h,now){
    ctx.save();

    for(const b of buildings){
      const x=b[0]*w, y=b[1]*h, rw=b[2]*w, rh=b[3]*h;
      const grd=ctx.createLinearGradient(x-rw,y-rh,x+rw,y+rh);
      grd.addColorStop(0,"rgba(143,240,255,.26)");
      grd.addColorStop(1,"rgba(3,8,18,.86)");
      ctx.fillStyle=grd;
      ctx.strokeStyle="rgba(143,240,255,.24)";
      ctx.lineWidth=1;
      ctx.fillRect(x-rw,y-rh,rw*2,rh*2);
      ctx.strokeRect(x-rw,y-rh,rw*2,rh*2);
      ctx.strokeStyle="rgba(143,240,255,.08)";
      for(let ix=x-rw+8; ix<x+rw; ix+=12){
        ctx.beginPath(); ctx.moveTo(ix,y-rh+3); ctx.lineTo(ix,y+rh-3); ctx.stroke();
      }
    }

    for(const tr of trees){
      const pulse = 1 + Math.sin(now*.002 + tr[0]*40)*.06;
      const r = tr[2]*Math.min(w,h)*(.70+state.clutter*.28)*pulse;
      const x=tr[0]*w, y=tr[1]*h;
      const g=ctx.createRadialGradient(x,y,0,x,y,r);
      g.addColorStop(0,"rgba(66,245,111,.42)");
      g.addColorStop(.55,"rgba(66,245,111,.16)");
      g.addColorStop(1,"rgba(66,245,111,0)");
      ctx.fillStyle=g;
      ctx.beginPath(); ctx.arc(x,y,r,0,Math.PI*2); ctx.fill();
      ctx.fillStyle="rgba(122,78,38,.85)";
      ctx.fillRect(x-1.5,y+r*.18,3,r*.55);
    }

    sites.forEach((s,i)=>{
      const x=s.x*w,y=s.y*h;
      ctx.shadowColor=s.color;
      ctx.shadowBlur=28;
      ctx.fillStyle=s.color;
      ctx.beginPath(); ctx.arc(x,y,9,0,Math.PI*2); ctx.fill();
      ctx.shadowBlur=0;
      ctx.strokeStyle=s.color;
      ctx.lineWidth=2;
      ctx.beginPath(); ctx.arc(x,y,24+Math.sin(now*.003+i)*5,0,Math.PI*2); ctx.stroke();
      ctx.font="11px Consolas";
      ctx.fillStyle="#eafcff";
      ctx.fillText(s.id,x+16,y-14);
    });

    ctx.restore();
  }

  function drawUE(w,h,now){
    for(const ue of ues){
      const sx = sites[ue.serving].x*w;
      const sy = sites[ue.serving].y*h;
      const ux = ue.x*w;
      const uy = ue.y*h;
      const site = sites[ue.serving];

      ctx.save();

      if(ue.trail.length > 2){
        ctx.beginPath();
        ue.trail.forEach((p,i)=>{
          const x=p[0]*w, y=p[1]*h;
          if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
        });
        ctx.strokeStyle = ue.dropped ? "rgba(255,59,92,.32)" : site.color + "55";
        ctx.lineWidth = ue.type === "V2X" ? 1.8 : 1.1;
        ctx.stroke();
      }

      ctx.beginPath();
      ctx.moveTo(sx,sy);
      ctx.lineTo(ux,uy);
      ctx.setLineDash(ue.dropped ? [8,7] : []);
      ctx.strokeStyle = ue.dropped ? "rgba(255,59,92,.88)" : site.color + "aa";
      ctx.lineWidth = ue.type === "V2X" ? 1.6 : 1.0;
      ctx.shadowColor = ue.dropped ? "#ff3b5c" : site.color;
      ctx.shadowBlur = ue.dropped ? 18 : 10;
      ctx.stroke();
      ctx.setLineDash([]);

      const r = ue.type === "V2X" ? 4.2 : 3.1;
      ctx.beginPath();
      ctx.fillStyle = ue.dropped ? "#ff3b5c" : site.color;
      ctx.shadowBlur = ue.dropped ? 24 : 16;
      ctx.arc(ux,uy,r,0,Math.PI*2);
      ctx.fill();

      if(ue.candidate !== ue.serving && ue.candidateMs > 0){
        const pct = clamp(ue.candidateMs/state.ttt,0,1);
        ctx.beginPath();
        ctx.strokeStyle = sites[ue.candidate].color;
        ctx.lineWidth = 2;
        ctx.arc(ux,uy,7 + pct*11, -Math.PI/2, -Math.PI/2 + pct*Math.PI*2);
        ctx.stroke();
      }

      ctx.restore();
    }
  }

  function drawParticles(w,h,dt){
    for(let i=state.particles.length-1;i>=0;i--){
      const p=state.particles[i];
      p.t += dt;
      const life = 850;
      const a = 1 - p.t/life;
      if(a<=0){ state.particles.splice(i,1); continue; }
      const x=p.x*w, y=p.y*h;
      ctx.save();
      ctx.globalAlpha=a;
      ctx.strokeStyle=p.color;
      ctx.lineWidth=2;
      ctx.shadowColor=p.color;
      ctx.shadowBlur=22;
      ctx.beginPath();
      ctx.arc(x,y,16 + p.t*.045,0,Math.PI*2);
      ctx.stroke();
      ctx.font="10px Consolas";
      ctx.fillStyle="#fff";
      ctx.fillText(p.txt,x+18,y-16-p.t*.01);
      ctx.restore();
    }
  }

  function draw(now){
    resize();
    const w=innerWidth,h=innerHeight;
    const dt = Math.min(80, now - state.lastT);
    state.lastT = now;

    if(!state.paused) updateUE(dt, now);

    drawGrid(w,h);
    drawEnvironment(w,h,now);
    drawUE(w,h,now);
    drawParticles(w,h,dt);

    state.frame++;
    if(now - state.lastFps > 650){
      state.fps = Math.round(state.frame*1000/(now-state.lastFps));
      state.frame = 0;
      state.lastFps = now;
      $("fps_state").textContent = "FPS " + state.fps;
    }

    requestAnimationFrame(draw);
  }

  function bind(){
    $("ue_count").addEventListener("input", e=>{
      state.ueCount = parseInt(e.target.value,10);
      $("ue_count_value").textContent = state.ueCount + " UE";
      initUE();
    });
    $("ue_speed").addEventListener("input", e=>{
      state.speed = parseFloat(e.target.value);
      $("ue_speed_value").textContent = state.speed.toFixed(2) + "x";
    });
    $("ho_hyst").addEventListener("input", e=>{
      state.hyst = parseFloat(e.target.value);
      $("ho_hyst_value").textContent = state.hyst.toFixed(1) + " dB";
      addLog("hysteresis margin aggiornato a " + state.hyst.toFixed(1) + " dB.", "ok");
    });
    $("ho_ttt").addEventListener("input", e=>{
      state.ttt = parseInt(e.target.value,10);
      $("ho_ttt_value").textContent = state.ttt + " ms";
      addLog("time-to-trigger aggiornato a " + state.ttt + " ms.", "ok");
    });
    $("clutter").addEventListener("input", e=>{
      state.clutter = parseFloat(e.target.value);
      $("clutter_value").textContent = state.clutter.toFixed(2) + "x";
    });

    $("btn_pause").addEventListener("click", e=>{
      state.paused = !state.paused;
      e.currentTarget.classList.toggle("active", state.paused);
      e.currentTarget.textContent = state.paused ? "Resume" : "Pause";
      addLog(state.paused ? "simulazione congelata." : "simulazione ripresa.", "ok");
    });

    $("btn_reset").addEventListener("click", ()=>{
      initUE();
      addLog("reset completo della mobilità e delle metriche HO.", "ok");
    });

    $("btn_rush").addEventListener("click", e=>{
      state.rush = !state.rush;
      e.currentTarget.classList.toggle("active", state.rush);
      addLog(state.rush ? "rush hour attivata: densità, velocità e load penalty aumentati." : "rush hour disattivata.", state.rush ? "warn" : "ok");
    });

    $("btn_park").addEventListener("click", e=>{
      state.park = !state.park;
      e.currentTarget.classList.toggle("active", state.park);
      addLog(state.park ? "park stress attivato: clutter vegetativo extra nel corridoio centrale." : "park stress disattivato.", state.park ? "warn" : "ok");
    });
  }

  async function backendHealth(){
    try{
      const r = await fetch("/api/health", { cache:"no-store" });
      $("backend_state").textContent = r.ok ? "Backend OK" : "Backend WARN";
    }catch(e){
      $("backend_state").textContent = "Backend N/A";
    }
  }

  function boot(){
    $("ue_count_value").textContent = state.ueCount + " UE";
    $("ue_speed_value").textContent = state.speed.toFixed(2) + "x";
    $("ho_hyst_value").textContent = state.hyst.toFixed(1) + " dB";
    $("ho_ttt_value").textContent = state.ttt + " ms";
    $("clutter_value").textContent = state.clutter.toFixed(2) + "x";
    $("engine_state").textContent = "Engine READY";

    bind();
    initUE();
    backendHealth();
    setInterval(backendHealth, 5000);
    addLog("UE Mobility & Handover Dynamics online: RSRP, hysteresis, TTT e clutter attivi.", "ok");
    requestAnimationFrame(t=>{
      state.lastT = t;
      requestAnimationFrame(draw);
    });
  }

  document.addEventListener("DOMContentLoaded", boot);
})();
