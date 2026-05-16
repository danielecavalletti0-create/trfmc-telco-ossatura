(function(){
  const $ = (id)=>document.getElementById(id);

  const field = $("fieldCanvas");
  const iq = $("iqCanvas");
  const pdp = $("pdpCanvas");
  const hCanvas = $("hCanvas");

  const state = {
    freq:3500,
    eirp:46,
    pathN:3.2,
    shadow:8,
    delay:130,
    kfactor:10,
    beam:18,
    teacher:false,
    t:0
  };

  const sites = [
    {id:"SITE-A", x:.20, y:.70, band:"n78", az:12},
    {id:"SITE-B", x:.53, y:.24, band:"C-band", az:28},
    {id:"SITE-C", x:.83, y:.61, band:"load", az:-25}
  ];

  const ue = {id:"UE-42", x:.64, y:.64};

  const buildings = [
    {x:.31,y:.37,w:.075,h:.22,d:.035,loss:11,name:"glass tower"},
    {x:.47,y:.55,w:.070,h:.22,d:.030,loss:9,name:"mid block"},
    {x:.66,y:.35,w:.060,h:.24,d:.030,loss:15,name:"NLOS slab"},
    {x:.73,y:.51,w:.050,h:.21,d:.027,loss:12,name:"edge block"},
    {x:.39,y:.50,w:.100,h:.17,d:.020,loss:8,name:"clutter"},
    {x:.20,y:.56,w:.080,h:.16,d:.022,loss:7,name:"low block"}
  ];

  const controls = [
    ["freq","freqText"," MHz","freq"],
    ["eirp","eirpText"," dBm","eirp"],
    ["pathN","pathText","","pathN"],
    ["shadow","shadowText"," dB","shadow"],
    ["delay","delayText"," ns","delay"],
    ["kfactor","kText"," dB","kfactor"],
    ["beam","beamText","°","beam"]
  ];

  function bind(){
    controls.forEach(([id,out,suffix,key])=>{
      $(id).addEventListener("input",()=>{
        state[key]=Number($(id).value);
        $(out).textContent=$(id).value+suffix;
        updateAll();
      });
    });

    $("btnBalanced").onclick=()=>setScenario({freq:3500,eirp:46,pathN:3.2,shadow:8,delay:130,kfactor:10,beam:18});
    $("btnNlos").onclick=()=>setScenario({freq:3500,eirp:46,pathN:3.8,shadow:17,delay:360,kfactor:-6,beam:30});
    $("btnSevere").onclick=()=>setScenario({freq:3500,eirp:44,pathN:4.3,shadow:24,delay:560,kfactor:-12,beam:42});
    $("btnTeacher").onclick=()=>{
      state.teacher=!state.teacher;
      $("btnTeacher").textContent=state.teacher ? "Teacher overlay ON" : "Teacher overlay";
      updateAll();
    };

    window.addEventListener("resize",updateAll);
  }

  function setScenario(s){
    Object.assign(state,s);
    controls.forEach(([id,out,suffix,key])=>{
      $(id).value=state[key];
      $(out).textContent=state[key]+suffix;
    });
    updateAll();
  }

  function setupCanvas(c,height){
    const rect=c.getBoundingClientRect();
    const dpr=Math.min(devicePixelRatio||1,2);
    const w=Math.max(320,Math.floor(rect.width*dpr));
    const h=Math.max(180,Math.floor((height||rect.height)*dpr));
    if(c.width!==w || c.height!==h){ c.width=w; c.height=h; }
    const ctx=c.getContext("2d");
    ctx.setTransform(dpr,0,0,dpr,0,0);
    return {ctx,w:rect.width,h:height||rect.height,dpr};
  }

  function fspl(freqMHz,dMeters){
    const dKm=Math.max(dMeters/1000,0.001);
    return 32.44 + 20*Math.log10(freqMHz) + 20*Math.log10(dKm);
  }

  function dist(a,b){
    const dx=a.x-b.x, dy=a.y-b.y;
    return Math.sqrt(dx*dx+dy*dy);
  }

  function obstructionLoss(x,y,site){
    let loss=0;
    buildings.forEach(b=>{
      let hits=0;
      for(let i=0;i<=28;i++){
        const t=i/28;
        const px=site.x+(x-site.x)*t;
        const py=site.y+(y-site.y)*t;
        if(px>=b.x && px<=b.x+b.w && py>=b.y && py<=b.y+b.h) hits++;
      }
      if(hits>0) loss += b.loss * Math.min(1,hits/8);
    });
    return loss;
  }

  function sectorGain(x,y,site){
    const angle=Math.atan2(y-site.y,x-site.x)*180/Math.PI;
    const steer=state.beam + site.az;
    const off=Math.abs(((angle-steer+540)%360)-180);
    const main=Math.pow(Math.max(0,Math.cos(off*Math.PI/180)),10);
    const side=.07*Math.pow(Math.max(0,Math.cos((off-55)*Math.PI/180)),4);
    return 11*(main+side);
  }

  function rxPower(x,y,site){
    const dNorm=Math.max(dist({x,y},site),.018);
    const meters=dNorm*920;
    const base=fspl(state.freq,meters);
    const logExtra=10*(state.pathN-2)*Math.log10(Math.max(meters,1)/100);
    const obs=obstructionLoss(x,y,site);
    const shadow=state.shadow*(0.28+0.72*Math.abs(Math.sin(9*x+6*y+site.x*13)));
    const kPenalty=state.kfactor<0 ? Math.abs(state.kfactor)*.40 : -state.kfactor*.07;
    return state.eirp + sectorGain(x,y,site) - base - logExtra - obs - shadow + kPenalty;
  }

  function channelAt(x,y){
    const powers=sites.map(s=>({site:s,p:rxPower(x,y,s)})).sort((a,b)=>b.p-a.p);
    const best=powers[0];
    const second=powers[1];
    const interf=powers.slice(1).reduce((acc,v)=>acc+Math.pow(10,v.p/10),0);
    const noise=Math.pow(10,-104/10);
    const sinr=10*Math.log10(Math.pow(10,best.p/10)/(interf+noise));
    const gap=best.p-second.p;
    const ds=state.delay*(1+Math.max(0,-state.kfactor)/20+state.shadow/75);
    const evm=Math.max(1.2,Math.min(45,100/Math.pow(10,Math.max(sinr,0)/20)+ds/130+Math.max(0,-state.kfactor)*.75));
    const coh=1/(5*ds*1e-9)/1e6;
    const score=Math.max(0,Math.min(100,44+(best.p+95)*1.18+sinr*3.05-evm*1.10-ds/42));
    return {powers,best,second,sinr,gap,ds,evm,coh,score};
  }

  function classOf(c){
    if(c.best.p < -112 || c.sinr < 0 || c.evm > 28 || c.score < 18) return "critical";
    if(c.best.p < -105 || c.sinr < 5 || c.score < 36) return "weak";
    if(c.best.p < -96 || c.sinr < 10 || c.score < 56) return "edge";
    if(c.score >= 78 && c.sinr >= 12 && c.evm < 11) return "excellent";
    return "good";
  }

  function colorFor(cls){
    if(cls==="critical") return [160,24,42,130];
    if(cls==="weak") return [28,112,185,145];
    if(cls==="edge") return [205,158,42,145];
    if(cls==="excellent") return [150,238,215,135];
    return [48,198,126,128];
  }

  function drawField(){
    const {ctx,w,h}=setupCanvas(field,650);
    ctx.clearRect(0,0,w,h);

    const bg=ctx.createLinearGradient(0,0,w,h);
    bg.addColorStop(0,"#041525");
    bg.addColorStop(.55,"#020b18");
    bg.addColorStop(1,"#01030a");
    ctx.fillStyle=bg;
    ctx.fillRect(0,0,w,h);

    const cols=170, rows=92;
    const data=[];
    const off=document.createElement("canvas");
    off.width=cols; off.height=rows;
    const octx=off.getContext("2d");
    const img=octx.createImageData(cols,rows);

    for(let y=0;y<rows;y++){
      data[y]=[];
      for(let x=0;x<cols;x++){
        const nx=x/(cols-1), ny=y/(rows-1);
        const c=channelAt(nx,ny);
        const cls=classOf(c);
        data[y][x]={c,cls};
        const [r,g,b,a]=colorFor(cls);
        const idx=(y*cols+x)*4;
        img.data[idx]=r;
        img.data[idx+1]=g;
        img.data[idx+2]=b;
        img.data[idx+3]=a;
      }
    }

    octx.putImageData(img,0,0);
    ctx.save();
    ctx.imageSmoothingEnabled=true;
    ctx.filter="blur(2.1px) saturate(.76) brightness(.82) contrast(1.04)";
    ctx.drawImage(off,0,0,w,h);
    ctx.restore();

    drawGrid(ctx,w,h);
    drawDiagnosticContours(ctx,w,h,data,cols,rows);
    drawBeams(ctx,w,h);
    buildings.forEach(b=>drawBuilding(ctx,b,w,h));
    drawLinks(ctx,w,h);
    sites.forEach((s,i)=>drawSite(ctx,s,w,h,i));
    drawUE(ctx,w,h);

    if(state.teacher) drawTeacherOverlay(ctx,w,h);

    drawBadge(ctx,w,channelAt(ue.x,ue.y));
  }

  function drawGrid(ctx,w,h){
    ctx.strokeStyle="rgba(143,240,255,.075)";
    ctx.lineWidth=1;
    for(let x=0;x<w;x+=32){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let y=0;y<h;y+=32){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
  }

  function drawDiagnosticContours(ctx,w,h,data,cols,rows){
    const classes=["critical","weak","edge","excellent"];
    const colors={
      critical:"rgba(255,59,92,.70)",
      weak:"rgba(46,167,255,.52)",
      edge:"rgba(251,191,36,.50)",
      excellent:"rgba(143,240,255,.50)"
    };

    classes.forEach(cls=>{
      ctx.strokeStyle=colors[cls];
      ctx.lineWidth=cls==="critical"?1.8:1.15;
      ctx.setLineDash(cls==="critical"?[7,5]:[]);
      for(let y=1;y<rows-1;y+=2){
        for(let x=1;x<cols-1;x+=2){
          const here=data[y][x].cls===cls;
          const right=data[y][x+1].cls===cls;
          const down=data[y+1][x].cls===cls;
          if(here!==right || here!==down){
            const px=x/(cols-1)*w;
            const py=y/(rows-1)*h;
            ctx.beginPath();
            ctx.moveTo(px-4,py);
            ctx.lineTo(px+4,py);
            ctx.stroke();
          }
        }
      }
      ctx.setLineDash([]);
    });
  }

  function drawBeams(ctx,w,h){
    sites.forEach((s,idx)=>{
      const sx=s.x*w, sy=s.y*h;
      const a=(state.beam+s.az)*Math.PI/180;
      ctx.save();
      ctx.globalCompositeOperation="screen";
      const g=ctx.createRadialGradient(sx,sy,10,sx+Math.cos(a)*w*.24,sy+Math.sin(a)*h*.24,w*.42);
      g.addColorStop(0,idx===1?"rgba(66,245,111,.14)":"rgba(143,240,255,.08)");
      g.addColorStop(.52,"rgba(143,240,255,.045)");
      g.addColorStop(1,"rgba(0,0,0,0)");
      ctx.fillStyle=g;
      ctx.beginPath();
      ctx.ellipse(sx,sy,w*.40,h*.15,a,0,Math.PI*2);
      ctx.fill();
      ctx.restore();
    });
  }

  function drawBuilding(ctx,b,w,h){
    const x=b.x*w,y=b.y*h,bw=b.w*w,bh=b.h*h,d=b.d*w;

    const g=ctx.createLinearGradient(x,y,x+bw,y+bh);
    g.addColorStop(0,"rgba(143,240,255,.22)");
    g.addColorStop(.55,"rgba(20,62,84,.45)");
    g.addColorStop(1,"rgba(1,7,15,.95)");
    ctx.fillStyle=g;
    round(ctx,x,y,bw,bh,10,true,false);

    ctx.fillStyle="rgba(0,0,0,.42)";
    ctx.beginPath();
    ctx.moveTo(x+bw,y+12);
    ctx.lineTo(x+bw+d,y+25);
    ctx.lineTo(x+bw+d,y+bh+d);
    ctx.lineTo(x+bw,y+bh);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle="rgba(143,240,255,.34)";
    ctx.lineWidth=1.2;
    round(ctx,x,y,bw,bh,10,false,true);

    ctx.strokeStyle="rgba(143,240,255,.13)";
    for(let gx=x+10;gx<x+bw;gx+=12){ctx.beginPath();ctx.moveTo(gx,y);ctx.lineTo(gx,y+bh);ctx.stroke();}
    for(let gy=y+10;gy<y+bh;gy+=12){ctx.beginPath();ctx.moveTo(x,gy);ctx.lineTo(x+bw,gy);ctx.stroke();}
  }

  function drawSite(ctx,s,w,h,i){
    const x=s.x*w,y=s.y*h;
    const r=28+i*4;
    const g=ctx.createRadialGradient(x,y,3,x,y,r);
    g.addColorStop(0,"rgba(255,255,255,.96)");
    g.addColorStop(.28,"rgba(143,240,255,.80)");
    g.addColorStop(1,"rgba(66,245,111,.04)");
    ctx.fillStyle=g;
    ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle="rgba(143,240,255,.54)";
    ctx.lineWidth=1.2;
    ctx.stroke();

    ctx.fillStyle="#eaffff";
    ctx.font="bold 11px monospace";
    ctx.textAlign="center";
    ctx.fillText(s.id,x,y+r+18);
    ctx.fillStyle="rgba(66,245,111,.86)";
    ctx.font="9px monospace";
    ctx.fillText(s.band,x,y-34);
    ctx.textAlign="left";
  }

  function drawUE(ctx,w,h){
    const x=ue.x*w,y=ue.y*h;
    ctx.strokeStyle="rgba(255,255,255,.72)";
    ctx.lineWidth=1;
    ctx.beginPath();ctx.arc(x,y,14,0,Math.PI*2);ctx.stroke();
    ctx.beginPath();ctx.moveTo(x-24,y);ctx.lineTo(x+24,y);ctx.moveTo(x,y-24);ctx.lineTo(x,y+24);ctx.stroke();
    ctx.fillStyle="#fff";
    ctx.beginPath();ctx.arc(x,y,5,0,Math.PI*2);ctx.fill();
    ctx.fillStyle="rgba(143,240,255,.95)";
    ctx.font="bold 10px monospace";
    ctx.fillText(ue.id,x+12,y-10);
  }

  function drawLinks(ctx,w,h){
    const d=channelAt(ue.x,ue.y);
    const target={x:ue.x*w,y:ue.y*h};

    d.powers.forEach((p,idx)=>{
      const s=p.site;
      const sx=s.x*w,sy=s.y*h;
      ctx.setLineDash(idx===0?[]:[8,8]);
      ctx.lineWidth=idx===0?2.2:1.2;
      ctx.strokeStyle=idx===0?"rgba(143,240,255,.84)":"rgba(251,191,36,.38)";
      ctx.beginPath();
      if(idx===0){
        ctx.moveTo(sx,sy);ctx.lineTo(target.x,target.y);
      }else{
        const mx=(sx+target.x)/2 + (idx===1?40:-30);
        const my=(sy+target.y)/2 - (idx===1?35:-25);
        ctx.moveTo(sx,sy);ctx.quadraticCurveTo(mx,my,target.x,target.y);
      }
      ctx.stroke();
    });
    ctx.setLineDash([]);
  }

  function drawTeacherOverlay(ctx,w,h){
    const d=channelAt(ue.x,ue.y);
    const rows=[
      ["RSRP",`${d.best.p.toFixed(1)} dBm`],
      ["SINR",`${d.sinr.toFixed(1)} dB`],
      ["Gap",`${d.gap.toFixed(1)} dB`],
      ["EVM",`${d.evm.toFixed(1)}%`],
      ["Delay",`${d.ds.toFixed(0)} ns`],
      ["Bc",`${d.coh.toFixed(2)} MHz`]
    ];

    ctx.fillStyle="rgba(1,6,14,.84)";
    ctx.strokeStyle="rgba(66,245,111,.34)";
    round(ctx,18,18,272,170,18,true,true);
    ctx.font="bold 12px monospace";
    ctx.fillStyle="#42f56f";
    ctx.fillText("TEACHER PROBE · UE-42",36,42);
    ctx.font="11px monospace";
    rows.forEach((r,i)=>{
      ctx.fillStyle="rgba(232,250,255,.62)";
      ctx.fillText(r[0],36,68+i*18);
      ctx.fillStyle="#eaffff";
      ctx.fillText(r[1],120,68+i*18);
    });
  }

  function drawBadge(ctx,w,d){
    ctx.fillStyle="rgba(1,6,14,.86)";
    ctx.strokeStyle="rgba(66,245,111,.34)";
    round(ctx,w-260,18,236,82,20,true,true);
    ctx.fillStyle="#42f56f";
    ctx.font="bold 14px monospace";
    ctx.fillText(`BEST ${d.best.site.id}`,w-238,45);
    ctx.fillStyle="rgba(232,250,255,.82)";
    ctx.font="12px monospace";
    ctx.fillText(`RSRP ${d.best.p.toFixed(1)} dBm`,w-238,66);
    ctx.fillText(`SINR ${d.sinr.toFixed(1)} dB`,w-110,66);
  }

  function makeTaps(){
    const tdl=[
      [0.0000,-13.4],
      [0.3819,0],
      [0.4025,-2.2],
      [0.5868,-4],
      [0.7618,-7.5],
      [1.5375,-15.9],
      [2.2242,-16.7],
      [4.0810,-12.7],
      [5.3043,-19.9],
      [9.6586,-29.7]
    ];
    return tdl.map((t,i)=>({
      delay:t[0]*state.delay,
      power:t[1] - Math.max(0,state.shadow-8)*.09 - i*.20,
      phase:(state.t*.0006+i*1.49)%(Math.PI*2)
    }));
  }

  function drawIQ(){
    const {ctx,w,h}=setupCanvas(iq,260);
    instrumentBg(ctx,w,h,"I","Q");
    const d=channelAt(ue.x,ue.y);
    const cx=w/2,cy=h/2;
    const scale=Math.min(w,h)/8.4;
    const pts=[-3,-1,1,3];

    ctx.fillStyle="rgba(66,245,111,.18)";
    pts.forEach(I=>pts.forEach(Q=>{
      ctx.beginPath();ctx.arc(cx+I*scale,cy-Q*scale,3,0,Math.PI*2);ctx.fill();
    }));

    const snrEff=Math.max(1,d.sinr+12);
    const noise=Math.max(1,30/Math.sqrt(snrEff));
    const phaseJitter=(d.ds/900 + Math.max(0,-state.kfactor)/18)*0.62;
    const ampJitter=(d.evm/100)*scale*1.8;

    for(let n=0;n<900;n++){
      const I=pts[Math.floor(Math.random()*4)];
      const Q=pts[Math.floor(Math.random()*4)];
      const ph=(Math.random()-.5)*phaseJitter;
      const amp=1+(Math.random()-.5)*ampJitter/scale;
      const ii=(I*Math.cos(ph)-Q*Math.sin(ph))*amp;
      const qq=(I*Math.sin(ph)+Q*Math.cos(ph))*amp;
      const x=cx+ii*scale+randn()*noise;
      const y=cy-qq*scale+randn()*noise;
      const err=Math.abs(x-(cx+I*scale))>scale || Math.abs(y-(cy-Q*scale))>scale;
      ctx.fillStyle=err?"rgba(255,59,92,.62)":"rgba(66,245,111,.62)";
      ctx.fillRect(x,y,1.8,1.8);
    }

    ctx.fillStyle="rgba(232,250,255,.74)";
    ctx.font="11px monospace";
    ctx.fillText(`16-QAM · EVM ${d.evm.toFixed(1)}% · K ${state.kfactor} dB`,12,18);
  }

  function drawPDP(){
    const {ctx,w,h}=setupCanvas(pdp,260);
    instrumentBg(ctx,w,h,"τ","P");

    const taps=makeTaps();
    const maxDelay=Math.max(...taps.map(t=>t.delay),1);

    taps.forEach((tap,idx)=>{
      const x=24+(tap.delay/maxDelay)*(w-52);
      const norm=Math.pow(10,tap.power/20);
      const bh=Math.max(3,norm*(h-42)*1.6);
      ctx.fillStyle=idx===1?"rgba(66,245,111,.88)":"rgba(251,191,36,.78)";
      ctx.fillRect(x,h-24-bh,4,bh);
      ctx.strokeStyle="rgba(143,240,255,.18)";
      ctx.beginPath();ctx.moveTo(x,h-24);ctx.lineTo(x,h-24-bh);ctx.stroke();
    });

    ctx.fillStyle="rgba(232,250,255,.74)";
    ctx.font="11px monospace";
    ctx.fillText(`TDL · RMS delay ${channelAt(ue.x,ue.y).ds.toFixed(0)} ns`,12,18);
  }

  function drawH(){
    const {ctx,w,h}=setupCanvas(hCanvas,260);
    instrumentBg(ctx,w,h,"f","|H|");

    const taps=makeTaps();
    ctx.beginPath();
    for(let i=0;i<w;i++){
      const f=(i/w-.5)*100e6;
      let re=0,im=0;
      taps.forEach(t=>{
        const amp=Math.pow(10,t.power/20);
        const ph=-2*Math.PI*f*(t.delay*1e-9)+t.phase;
        re+=amp*Math.cos(ph);
        im+=amp*Math.sin(ph);
      });
      const mag=20*Math.log10(Math.sqrt(re*re+im*im)+1e-6);
      const y=h-24-(Math.max(-42,Math.min(8,mag))+42)/50*(h-44);
      if(i===0)ctx.moveTo(i,y); else ctx.lineTo(i,y);
    }

    ctx.strokeStyle="rgba(143,240,255,.92)";
    ctx.lineWidth=2;
    ctx.shadowColor="rgba(143,240,255,.58)";
    ctx.shadowBlur=9;
    ctx.stroke();
    ctx.shadowBlur=0;

    ctx.fillStyle="rgba(232,250,255,.74)";
    ctx.font="11px monospace";
    ctx.fillText("Frequency-selective fading · coherence depends on delay spread",12,18);
  }

  function drawBudget(){
    const d=channelAt(ue.x,ue.y);
    const distance=dist(ue,d.best.site)*920;
    const rows=[
      ["Best server", d.best.site.id, "serving-cell decision"],
      ["EIRP", `${state.eirp.toFixed(1)} dBm`, "potenza equivalente irradiata"],
      ["Distanza", `${distance.toFixed(0)} m`, "geometria radio"],
      ["FSPL", `${fspl(state.freq,distance).toFixed(1)} dB`, "perdita spazio libero"],
      ["Path exponent", `n=${state.pathN.toFixed(1)}`, "morfologia ambiente"],
      ["Shadowing", `${state.shadow.toFixed(1)} dB`, "variabilità lenta"],
      ["Delay spread", `${d.ds.toFixed(0)} ns`, "dispersione temporale"],
      ["Dominance gap", `${d.gap.toFixed(1)} dB`, "separazione best-server"],
      ["RSRP", `${d.best.p.toFixed(1)} dBm`, "potenza ricevuta"],
      ["SINR", `${d.sinr.toFixed(1)} dB`, "qualità/interferenza"]
    ];
    $("budgetRows").innerHTML=rows.map(r=>`<tr><td>${r[0]}</td><td>${r[1]}</td><td>${r[2]}</td></tr>`).join("");
  }

  function instrumentBg(ctx,w,h,xl,yl){
    const g=ctx.createLinearGradient(0,0,w,h);
    g.addColorStop(0,"rgba(8,38,58,.76)");
    g.addColorStop(1,"rgba(1,5,12,.96)");
    ctx.fillStyle=g;
    ctx.fillRect(0,0,w,h);

    ctx.strokeStyle="rgba(143,240,255,.10)";
    for(let x=0;x<w;x+=28){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let y=0;y<h;y+=28){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}

    ctx.strokeStyle="rgba(143,240,255,.26)";
    ctx.beginPath();
    ctx.moveTo(0,h/2);ctx.lineTo(w,h/2);
    ctx.moveTo(w/2,0);ctx.lineTo(w/2,h);
    ctx.stroke();

    ctx.fillStyle="rgba(232,250,255,.45)";
    ctx.font="10px monospace";
    if(xl)ctx.fillText(xl,w-18,h/2-6);
    if(yl)ctx.fillText(yl,w/2+6,14);
  }

  function updateText(){
    const d=channelAt(ue.x,ue.y);

    $("bestServer").textContent=d.best.site.id;
    $("rsrpVal").textContent=d.best.p.toFixed(1)+" dBm";
    $("sinrVal").textContent=d.sinr.toFixed(1)+" dB";
    $("evmVal").textContent=d.evm.toFixed(1)+"%";
    $("coverageVal").textContent=d.score.toFixed(0)+"%";
    $("dsVal").textContent=d.ds.toFixed(0)+" ns";
    $("cohVal").textContent=d.coh.toFixed(2)+" MHz";
    $("gapVal").textContent=d.gap.toFixed(1)+" dB";
    $("trustScore").textContent=d.score.toFixed(0)+"%";

    setClass("kpiRsrp", d.best.p < -110 ? "critical" : d.best.p < -98 ? "warn" : "good");
    setClass("kpiSinr", d.sinr < 3 ? "critical" : d.sinr < 10 ? "warn" : "good");
    setClass("kpiEvm", d.evm > 24 ? "critical" : d.evm > 12 ? "warn" : "good");
    setClass("mCoverage", d.score < 35 ? "critical" : d.score < 60 ? "warn" : "good");
    setClass("mDelay", d.ds > 420 ? "critical" : d.ds > 220 ? "warn" : "good");
    setClass("mDominance", d.gap < 3 ? "critical" : d.gap < 8 ? "warn" : "good");

    let label="coherent";
    let note="Canale coerente: campo, best-server, IQ, PDP e link budget sono allineati. Questa è la situazione ideale per insegnare il metodo senza confondere potenza e qualità.";

    if(d.score<35){
      label="critical";
      note="Degrado reale: se compare rosso deve essere motivato da SINR basso, RSRP debole, EVM alta o delay spread eccessivo. La mappa non decide da sola: lo dimostrano gli strumenti.";
    }else if(d.evm>14 || d.ds>300){
      label="dispersive";
      note="Canale dispersivo: il campo può sembrare presente, ma PDP e costellazione mostrano multipath e qualità degradata. Caso perfetto per spiegare ISI, selettività in frequenza e OFDM.";
    }else if(d.sinr<8){
      label="interference";
      note="RSRP non nullo ma SINR basso: il problema è interferenza o sovrapposizione di celle. Qui si insegna dominance gap, handover margin e qualità del serving.";
    }

    $("trustLabel").textContent=label;
    $("teacherText").textContent=note;
  }

  function setClass(id,cls){
    const el=$(id);
    if(!el) return;
    el.classList.remove("good","warn","critical");
    el.classList.add(cls);
  }

  function updateAll(){
    updateText();
    drawField();
    drawIQ();
    drawPDP();
    drawH();
    drawBudget();
  }

  function loop(ts){
    state.t=ts||0;
    drawField();
    drawIQ();
    drawPDP();
    drawH();
    requestAnimationFrame(loop);
  }

  function randn(){
    let u=0,v=0;
    while(u===0)u=Math.random();
    while(v===0)v=Math.random();
    return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*v);
  }

  function round(ctx,x,y,w,h,r,fill,stroke){
    ctx.beginPath();
    if(ctx.roundRect){
      ctx.roundRect(x,y,w,h,r);
    }else{
      ctx.moveTo(x+r,y);
      ctx.lineTo(x+w-r,y);
      ctx.quadraticCurveTo(x+w,y,x+w,y+r);
      ctx.lineTo(x+w,y+h-r);
      ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
      ctx.lineTo(x+r,y+h);
      ctx.quadraticCurveTo(x,y+h,x,y+h-r);
      ctx.lineTo(x,y+r);
      ctx.quadraticCurveTo(x,y,x+r,y);
    }
    if(fill)ctx.fill();
    if(stroke)ctx.stroke();
  }

  document.addEventListener("DOMContentLoaded",()=>{
    bind();
    updateAll();
    requestAnimationFrame(loop);
  });
})();
