(function(){
  const $ = (id)=>document.getElementById(id);
  const field = $("fieldCanvas");
  const iq = $("iqCanvas");
  const pdp = $("pdpCanvas");
  const freqCanvas = $("freqCanvas");
  const budget = $("budgetCanvas");

  const state = {
    freq:3500, eirp:46, pathN:3.2, delay:120, kfactor:9, shadow:11, beam:18,
    mode:"calibrated", t:0
  };

  const sites = [
    {id:"SITE-A",x:.18,y:.72,p:0,band:"n78"},
    {id:"SITE-B",x:.52,y:.25,p:0,band:"C-band"},
    {id:"SITE-C",x:.82,y:.66,p:0,band:"load"}
  ];

  const ue = {x:.63,y:.70,id:"UE-42"};
  const buildings = [
    {x:.31,y:.35,w:.07,h:.22,d:.035,loss:13,label:"glass tower"},
    {x:.50,y:.62,w:.07,h:.22,d:.030,loss:9,label:"mid block"},
    {x:.67,y:.34,w:.06,h:.24,d:.030,loss:16,label:"NLOS slab"},
    {x:.72,y:.52,w:.05,h:.20,d:.026,loss:11,label:"edge"},
    {x:.40,y:.50,w:.10,h:.18,d:.020,loss:8,label:"clutter"},
    {x:.20,y:.58,w:.08,h:.16,d:.022,loss:7,label:"low block"}
  ];

  const controls = [
    ["freq","freqText"," MHz","freq"],
    ["eirp","eirpText"," dBm","eirp"],
    ["pathN","pathText","","pathN"],
    ["delay","delayText"," ns","delay"],
    ["kfactor","kText"," dB","kfactor"],
    ["shadow","shadowText"," dB","shadow"],
    ["beam","beamText","°","beam"]
  ];

  function bind(){
    controls.forEach(([id,out,suffix,key])=>{
      const el=$(id);
      el.addEventListener("input",()=>{
        state[key]=Number(el.value);
        $(out).textContent = el.value + suffix;
        update();
      });
    });
    $("btnCalm").onclick=()=>{ state.mode="calibrated"; setVals({shadow:9,delay:90,kfactor:12,beam:12,pathN:3.0}); };
    $("btnStress").onclick=()=>{ state.mode="stress"; setVals({shadow:24,delay:420,kfactor:-8,beam:34,pathN:4.1}); };
    window.addEventListener("resize",resizeAll);
  }

  function setVals(obj){
    Object.entries(obj).forEach(([k,v])=>{
      state[k]=v;
      const el=$(k==="pathN"?"pathN":k);
      if(el) el.value=v;
    });
    controls.forEach(([id,out,suffix])=>$(out).textContent=$(id).value+suffix);
    update();
  }

  function setupCanvas(c, h){
    const rect = c.getBoundingClientRect();
    const dpr = Math.min(devicePixelRatio||1,2);
    const w = Math.max(320, Math.floor(rect.width*dpr));
    const hh = Math.max(160, Math.floor((h||rect.height)*dpr));
    if(c.width!==w || c.height!==hh){ c.width=w; c.height=hh; }
    const ctx=c.getContext("2d");
    ctx.setTransform(dpr,0,0,dpr,0,0);
    return {ctx,w:rect.width,h:h||rect.height,dpr};
  }

  function fspl(freqMHz, dMeters){
    const dKm=Math.max(dMeters/1000,0.001);
    return 32.44 + 20*Math.log10(freqMHz) + 20*Math.log10(dKm);
  }

  function dist(a,b){
    const dx=a.x-b.x, dy=a.y-b.y;
    return Math.sqrt(dx*dx+dy*dy);
  }

  function obstacleLoss(x,y,site){
    let loss=0;
    buildings.forEach(b=>{
      const near = x>b.x-.03 && x<b.x+b.w+.03 && y>b.y-.03 && y<b.y+b.h+.03;
      const between = Math.abs((x-site.x)*(ue.y-site.y)-(y-site.y)*(ue.x-site.x)) < .015;
      if(near) loss += b.loss*.65;
      if(between && x>Math.min(site.x,ue.x)-.02 && x<Math.max(site.x,ue.x)+.02) loss += b.loss*.18;
    });
    return loss;
  }

  function rxPowerAt(x,y,site){
    const dNorm = Math.max(dist({x,y},site),.018);
    const meters = dNorm*900;
    const base = fspl(state.freq, meters);
    const logExtra = 10*(state.pathN-2)*Math.log10(Math.max(meters,1)/100);
    const angle = Math.atan2(y-site.y,x-site.x)*180/Math.PI;
    const steering = state.beam;
    const off = Math.abs(((angle-steering+540)%360)-180);
    const sectorGain = 9*Math.pow(Math.max(0,Math.cos(off*Math.PI/180)),3);
    const obs = obstacleLoss(x,y,site);
    const slow = state.shadow * (0.35 + 0.65*Math.abs(Math.sin(8*x+5*y+site.x*7)));
    const kPenalty = state.kfactor < 0 ? Math.abs(state.kfactor)*.35 : -state.kfactor*.08;
    return state.eirp + sectorGain - base - logExtra - obs - slow + kPenalty;
  }

  function colorForScore(score){
    if(score>=85) return [238,255,255,.86];
    if(score>=68) return [66,245,111,.80];
    if(score>=48) return [251,191,36,.76];
    if(score>=28) return [46,167,255,.64];
    return [0,6,18,.86];
  }

  function computeAtUE(){
    const powers = sites.map(s=>({site:s,p:rxPowerAt(ue.x,ue.y,s)})).sort((a,b)=>b.p-a.p);
    const best=powers[0], second=powers[1];
    const interf = Math.pow(10,second.p/10) + Math.pow(10,powers[2].p/10);
    const noise = Math.pow(10,-104/10);
    const sinr = 10*Math.log10(Math.pow(10,best.p/10)/(interf+noise));
    const evm = Math.max(1.2, Math.min(38, 100/Math.pow(10,Math.max(sinr,0)/20) + state.delay/95 + Math.max(0,-state.kfactor)*.9));
    const ds = state.delay*(1 + Math.max(0,-state.kfactor)/20 + state.shadow/80);
    const score = Math.max(0,Math.min(100, 52 + (best.p+95)*1.6 + sinr*2.2 - evm*.75 - ds/45));
    return {powers,best,second,sinr,evm,ds,score};
  }

  function drawField(){
    const {ctx,w,h}=setupCanvas(field,640);
    ctx.clearRect(0,0,w,h);

    const bg=ctx.createLinearGradient(0,0,w,h);
    bg.addColorStop(0,"rgba(11,40,62,.98)");
    bg.addColorStop(.58,"rgba(2,9,22,.98)");
    bg.addColorStop(1,"rgba(1,4,10,.98)");
    ctx.fillStyle=bg; ctx.fillRect(0,0,w,h);

    ctx.strokeStyle="rgba(143,240,255,.055)";
    ctx.lineWidth=1;
    for(let x=0;x<w;x+=34){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let y=0;y<h;y+=34){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

    const step=10;
    for(let y=0;y<h;y+=step){
      for(let x=0;x<w;x+=step){
        const nx=x/w, ny=y/h;
        const ps = sites.map(s=>rxPowerAt(nx,ny,s)).sort((a,b)=>b-a);
        const best=ps[0], second=ps[1];
        const sinr=best-second;
        const score=Math.max(0,Math.min(100, 58 + (best+92)*1.4 + sinr*2.6 - state.delay/35 - state.shadow*.55));
        const [r,g,b,a]=colorForScore(score);
        ctx.fillStyle=`rgba(${r},${g},${b},${a})`;
        ctx.fillRect(x,y,step+1,step+1);
      }
    }

    ctx.globalCompositeOperation="screen";
    const beamAngle=state.beam*Math.PI/180;
    const s=sites[1];
    const sx=s.x*w, sy=s.y*h;
    const grd=ctx.createRadialGradient(sx,sy,20,sx+Math.cos(beamAngle)*w*.28,sy+Math.sin(beamAngle)*h*.28,w*.48);
    grd.addColorStop(0,"rgba(66,245,111,.25)");
    grd.addColorStop(.35,"rgba(143,240,255,.12)");
    grd.addColorStop(1,"rgba(0,0,0,0)");
    ctx.fillStyle=grd;
    ctx.beginPath();ctx.ellipse(sx,sy,w*.55,h*.24,beamAngle,0,Math.PI*2);ctx.fill();
    ctx.globalCompositeOperation="source-over";

    buildings.forEach(b=>drawBuilding(ctx,b,w,h));
    sites.forEach((s,i)=>drawSite(ctx,s,w,h,i));
    drawRays(ctx,w,h);
    drawUE(ctx,w,h);

    const data=computeAtUE();
    ctx.fillStyle="rgba(1,6,14,.82)";
    ctx.strokeStyle="rgba(66,245,111,.38)";
    ctx.lineWidth=1;
    roundRect(ctx,w-260,18,236,74,18,true,true);
    ctx.fillStyle="#42f56f"; ctx.font="bold 15px monospace";
    ctx.fillText(`BEST ${data.best.site.id}`,w-238,45);
    ctx.fillStyle="rgba(232,250,255,.80)"; ctx.font="12px monospace";
    ctx.fillText(`RSRP ${data.best.p.toFixed(1)} dBm · SINR ${data.sinr.toFixed(1)} dB`,w-238,66);
  }

  function drawBuilding(ctx,b,w,h){
    const x=b.x*w,y=b.y*h,bw=b.w*w,bh=b.h*h,d=b.d*w;
    const grad=ctx.createLinearGradient(x,y,x+bw,y+bh);
    grad.addColorStop(0,"rgba(143,240,255,.24)");
    grad.addColorStop(.50,"rgba(18,55,76,.42)");
    grad.addColorStop(1,"rgba(1,6,14,.88)");
    ctx.fillStyle=grad;
    ctx.strokeStyle="rgba(143,240,255,.36)";
    ctx.lineWidth=1.2;
    roundRect(ctx,x,y,bw,bh,8,true,true);

    ctx.fillStyle="rgba(0,0,0,.35)";
    ctx.beginPath();ctx.moveTo(x+bw,y+12);ctx.lineTo(x+bw+d,y+22);ctx.lineTo(x+bw+d,y+bh+d);ctx.lineTo(x+bw,y+bh);ctx.closePath();ctx.fill();
    ctx.strokeStyle="rgba(143,240,255,.13)";
    for(let gx=x+10;gx<x+bw;gx+=12){ctx.beginPath();ctx.moveTo(gx,y);ctx.lineTo(gx,y+bh);ctx.stroke();}
    for(let gy=y+10;gy<y+bh;gy+=12){ctx.beginPath();ctx.moveTo(x,gy);ctx.lineTo(x+bw,gy);ctx.stroke();}
  }

  function drawSite(ctx,s,w,h,i){
    const x=s.x*w,y=s.y*h;
    const r=28+i*5;
    const grad=ctx.createRadialGradient(x,y,4,x,y,r);
    grad.addColorStop(0,"rgba(255,255,255,.95)");
    grad.addColorStop(.28,"rgba(143,240,255,.75)");
    grad.addColorStop(1,"rgba(66,245,111,.06)");
    ctx.fillStyle=grad;
    ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle="rgba(143,240,255,.50)";ctx.lineWidth=1.2;ctx.stroke();

    ctx.fillStyle="#eaffff";ctx.font="bold 11px monospace";ctx.textAlign="center";
    ctx.fillText(s.id,x,y+r+18);
    ctx.fillStyle="rgba(66,245,111,.86)";ctx.font="9px monospace";
    ctx.fillText(s.band,x,y-35);
    ctx.textAlign="left";
  }

  function drawUE(ctx,w,h){
    const x=ue.x*w,y=ue.y*h;
    ctx.strokeStyle="rgba(255,255,255,.58)";ctx.lineWidth=1;
    ctx.beginPath();ctx.arc(x,y,13,0,Math.PI*2);ctx.stroke();
    ctx.beginPath();ctx.moveTo(x-22,y);ctx.lineTo(x+22,y);ctx.moveTo(x,y-22);ctx.lineTo(x,y+22);ctx.stroke();

    ctx.fillStyle="white";ctx.beginPath();ctx.arc(x,y,5,0,Math.PI*2);ctx.fill();
    ctx.fillStyle="rgba(143,240,255,.92)";ctx.font="bold 10px monospace";
    ctx.fillText(ue.id,x+12,y-10);
  }

  function drawRays(ctx,w,h){
    const target={x:ue.x*w,y:ue.y*h};
    const best=computeAtUE().best.site;
    const sx=best.x*w, sy=best.y*h;

    ctx.lineWidth=2;
    ctx.strokeStyle="rgba(143,240,255,.76)";
    ctx.beginPath();ctx.moveTo(sx,sy);ctx.lineTo(target.x,target.y);ctx.stroke();

    ctx.setLineDash([8,7]);
    ctx.strokeStyle="rgba(251,191,36,.58)";
    buildings.slice(0,3).forEach((b,idx)=>{
      const bx=(b.x+b.w*.5)*w, by=(b.y+b.h*.5)*h;
      ctx.beginPath();ctx.moveTo(sx,sy);ctx.quadraticCurveTo(bx,by,target.x,target.y);ctx.stroke();
    });
    ctx.setLineDash([]);
  }

  function drawIQ(){
    const {ctx,w,h}=setupCanvas(iq,210);
    ctx.clearRect(0,0,w,h);
    drawInstrumentBackground(ctx,w,h,"I","Q");

    const data=computeAtUE();
    const cx=w/2, cy=h/2;
    const scale=Math.min(w,h)/8;
    const snr=Math.max(1,data.sinr+12);
    const noise=Math.max(1,32/Math.sqrt(snr));
    const phaseJitter=(state.delay/800 + Math.max(0,-state.kfactor)/20)*0.55;
    const pts=[-3,-1,1,3];

    ctx.fillStyle="rgba(66,245,111,.20)";
    pts.forEach(I=>pts.forEach(Q=>{
      ctx.beginPath();ctx.arc(cx+I*scale,cy-Q*scale,3,0,Math.PI*2);ctx.fill();
    }));

    for(let n=0;n<850;n++){
      const I=pts[Math.floor(Math.random()*4)], Q=pts[Math.floor(Math.random()*4)];
      const ph=(Math.random()-.5)*phaseJitter;
      const ii=I*Math.cos(ph)-Q*Math.sin(ph);
      const qq=I*Math.sin(ph)+Q*Math.cos(ph);
      const x=cx+ii*scale+randn()*noise;
      const y=cy-qq*scale+randn()*noise;
      const err=Math.abs(x-(cx+I*scale))>scale || Math.abs(y-(cy-Q*scale))>scale;
      ctx.fillStyle=err?"rgba(255,59,92,.75)":"rgba(66,245,111,.60)";
      ctx.fillRect(x,y,1.8,1.8);
    }

    ctx.fillStyle="rgba(232,250,255,.72)";
    ctx.font="11px monospace";
    ctx.fillText(`16-QAM · EVM ${data.evm.toFixed(1)}% · K=${state.kfactor} dB`,12,18);
  }

  function drawPDP(){
    const {ctx,w,h}=setupCanvas(pdp,210);
    ctx.clearRect(0,0,w,h);
    drawInstrumentBackground(ctx,w,h,"τ","P");

    const taps=makeTaps();
    const maxDelay=Math.max(...taps.map(t=>t.delay));
    taps.forEach((tap,idx)=>{
      const x=24+(tap.delay/maxDelay)*(w-52);
      const pow=Math.pow(10,tap.power/20);
      const bh=Math.max(3,pow*h*.95);
      ctx.fillStyle=idx===0 && state.kfactor>0 ? "rgba(66,245,111,.86)" : "rgba(251,191,36,.78)";
      ctx.fillRect(x,h-22-bh,4,bh);
      ctx.strokeStyle="rgba(143,240,255,.18)";
      ctx.beginPath();ctx.moveTo(x,h-22);ctx.lineTo(x,h-22-bh);ctx.stroke();
    });

    ctx.fillStyle="rgba(232,250,255,.72)";
    ctx.font="11px monospace";
    ctx.fillText(`TDL taps · RMS delay ${computeAtUE().ds.toFixed(0)} ns`,12,18);
  }

  function drawFreq(){
    const {ctx,w,h}=setupCanvas(freqCanvas,210);
    ctx.clearRect(0,0,w,h);
    drawInstrumentBackground(ctx,w,h,"f","|H|");

    const taps=makeTaps();
    ctx.beginPath();
    for(let i=0;i<w;i++){
      const f=(i/w-.5)*80e6;
      let re=0,im=0;
      taps.forEach(t=>{
        const amp=Math.pow(10,t.power/20);
        const ph=-2*Math.PI*f*(t.delay*1e-9)+t.phase;
        re+=amp*Math.cos(ph); im+=amp*Math.sin(ph);
      });
      const mag=20*Math.log10(Math.sqrt(re*re+im*im)+1e-6);
      const y=h-24-(Math.max(-38,Math.min(8,mag))+38)/46*(h-42);
      if(i===0)ctx.moveTo(i,y);else ctx.lineTo(i,y);
    }
    ctx.strokeStyle="rgba(143,240,255,.92)";
    ctx.lineWidth=2;
    ctx.shadowColor="rgba(143,240,255,.6)";
    ctx.shadowBlur=10;
    ctx.stroke();
    ctx.shadowBlur=0;

    ctx.fillStyle="rgba(232,250,255,.72)";
    ctx.font="11px monospace";
    ctx.fillText("Frequency-selective fading from TDL",12,18);
  }

  function drawBudget(){
    const {ctx,w,h}=setupCanvas(budget,210);
    ctx.clearRect(0,0,w,h);
    drawInstrumentBackground(ctx,w,h,"","");

    const data=computeAtUE();
    const rows=[
      ["EIRP", state.eirp, "dBm", "#42f56f"],
      ["FSPL", -fspl(state.freq, Math.max(dist(ue,data.best.site)*900,20)), "dB", "#8ff0ff"],
      ["Shadow", -state.shadow, "dB", "#fbbf24"],
      ["Delay penalty", -data.ds/60, "dB eq", "#2ea7ff"],
      ["RSRP", data.best.p, "dBm", "#eaffff"],
      ["SINR", data.sinr, "dB", data.sinr<6?"#ff3b5c":data.sinr<12?"#fbbf24":"#42f56f"]
    ];

    ctx.font="12px monospace";
    rows.forEach((r,i)=>{
      const y=26+i*28;
      ctx.fillStyle="rgba(232,250,255,.62)";
      ctx.fillText(r[0],14,y);
      ctx.fillStyle=r[3];
      ctx.fillText(`${r[1].toFixed(1)} ${r[2]}`,150,y);
      const bar=Math.max(8,Math.min(w-300,Math.abs(r[1])*3));
      ctx.fillStyle=r[3]+"99";
      ctx.fillRect(270,y-10,bar,10);
    });

    ctx.fillStyle="rgba(66,245,111,.88)";
    ctx.font="bold 12px monospace";
    ctx.fillText(`Best server ${data.best.site.id} · ${data.score.toFixed(0)}%`,w-230,26);
  }

  function drawInstrumentBackground(ctx,w,h,xl,yl){
    const g=ctx.createLinearGradient(0,0,w,h);
    g.addColorStop(0,"rgba(8,38,58,.74)");
    g.addColorStop(1,"rgba(1,5,12,.95)");
    ctx.fillStyle=g;ctx.fillRect(0,0,w,h);
    ctx.strokeStyle="rgba(143,240,255,.09)";
    for(let x=0;x<w;x+=28){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let y=0;y<h;y+=28){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
    ctx.strokeStyle="rgba(143,240,255,.28)";
    ctx.beginPath();ctx.moveTo(0,h/2);ctx.lineTo(w,h/2);ctx.moveTo(w/2,0);ctx.lineTo(w/2,h);ctx.stroke();
    ctx.fillStyle="rgba(232,250,255,.45)";
    ctx.font="10px monospace";
    if(xl)ctx.fillText(xl,w-18,h/2-6);
    if(yl)ctx.fillText(yl,w/2+6,14);
  }

  function makeTaps(){
    const base=[
      [0, state.kfactor>0 ? 0 : -13.4],
      [.3819,0],
      [.4025,-2.2],
      [.5868,-4],
      [.7618,-7.5],
      [1.5375,-15.9],
      [2.2242,-16.7],
      [4.0810,-12.7],
      [5.3043,-19.9]
    ];
    return base.map((t,i)=>({
      delay:t[0]*state.delay,
      power:t[1] - Math.max(0,state.shadow-10)*.10 - i*.35,
      phase:(i*1.7 + state.t*.0008)%(Math.PI*2)
    }));
  }

  function updateMetrics(){
    const d=computeAtUE();
    $("servingCell").textContent=d.best.site.id;
    $("rsrpVal").textContent=d.best.p.toFixed(1)+" dBm";
    $("sinrVal").textContent=d.sinr.toFixed(1)+" dB";
    $("evmVal").textContent=d.evm.toFixed(1)+"%";
    $("dsVal").textContent=d.ds.toFixed(0)+" ns";
    $("covVal").textContent=d.score.toFixed(0)+"%";
    $("integrityVal").textContent=d.score.toFixed(0)+"%";

    const txt = d.sinr<6
      ? "Margine radio critico: SINR basso, multipath/ostacoli dominanti. Serve beam recovery o cambio serving cell."
      : d.evm>12
      ? "Qualità intermedia: RSRP utile ma canale dispersivo. Osserva PDP e costellazione IQ prima di fidarti della heatmap."
      : "Canale coerente: campo, IQ, PDP e budget sono allineati. La pagina ora lavora come console T&M, non come decorazione.";
    $("copilotText").textContent=txt;
  }

  function update(){
    updateMetrics();
    drawField();
    drawIQ();
    drawPDP();
    drawFreq();
    drawBudget();
  }

  function animate(ts){
    state.t=ts||0;
    drawField();
    drawIQ();
    drawPDP();
    drawFreq();
    drawBudget();
    requestAnimationFrame(animate);
  }

  function resizeAll(){ update(); }

  function randn(){
    let u=0,v=0;
    while(u===0)u=Math.random();
    while(v===0)v=Math.random();
    return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*v);
  }

  function roundRect(ctx,x,y,w,h,r,fill,stroke){
    if(ctx.roundRect){
      ctx.beginPath();ctx.roundRect(x,y,w,h,r);
      if(fill)ctx.fill(); if(stroke)ctx.stroke();
    }else{
      ctx.beginPath();
      ctx.moveTo(x+r,y);ctx.lineTo(x+w-r,y);ctx.quadraticCurveTo(x+w,y,x+w,y+r);
      ctx.lineTo(x+w,y+h-r);ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
      ctx.lineTo(x+r,y+h);ctx.quadraticCurveTo(x,y+h,x,y+h-r);
      ctx.lineTo(x,y+r);ctx.quadraticCurveTo(x,y,x+r,y);ctx.closePath();
      if(fill)ctx.fill(); if(stroke)ctx.stroke();
    }
  }

  document.addEventListener("DOMContentLoaded",()=>{
    bind();
    update();
    requestAnimationFrame(animate);
  });
})();
