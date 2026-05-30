/*
 TRFMC Visual Asset Engine V3
 Canvas component library for RF/Telco/Cyber visual modules.
 Components:
 tower-site, rru-panel, microwave-dish, fiber-otdr, spectrum-scope,
 smith-chart, rack-pdu, core-map, cyber-evidence.
*/
(function(){
  "use strict";

  const ENGINE_ID = "TRFMC_VISUAL_ASSET_ENGINE_V3";
  const C = 299792458;

  function fit(canvas){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(2, Math.floor(canvas.clientWidth * dpr));
    const h = Math.max(2, Math.floor(canvas.clientHeight * dpr));
    if (canvas.width !== w || canvas.height !== h){
      canvas.width = w;
      canvas.height = h;
    }
    const ctx = canvas.getContext("2d");
    return {ctx,w,h,dpr};
  }

  function rr(ctx,x,y,w,h,r){
    ctx.beginPath();
    ctx.moveTo(x+r,y);
    ctx.arcTo(x+w,y,x+w,y+h,r);
    ctx.arcTo(x+w,y+h,x,y+h,r);
    ctx.arcTo(x,y+h,x,y,r);
    ctx.arcTo(x,y,x+w,y,r);
    ctx.closePath();
  }

  function metal(ctx,x1,y1,x2,y2){
    const g = ctx.createLinearGradient(x1,y1,x2,y2);
    g.addColorStop(0,"#46535a");
    g.addColorStop(.16,"#e9f3f5");
    g.addColorStop(.38,"#7f9098");
    g.addColorStop(.62,"#f7fcff");
    g.addColorStop(1,"#526169");
    return g;
  }

  function cable(ctx,x1,y1,x2,y2,c1x,c1y,c2x,c2y,color,w){
    ctx.strokeStyle=color;
    ctx.lineWidth=w;
    ctx.lineCap="round";
    ctx.beginPath();
    ctx.moveTo(x1,y1);
    ctx.bezierCurveTo(c1x,c1y,c2x,c2y,x2,y2);
    ctx.stroke();
    ctx.strokeStyle="rgba(255,255,255,.22)";
    ctx.lineWidth=Math.max(1,w*.18);
    ctx.beginPath();
    ctx.moveTo(x1,y1);
    ctx.bezierCurveTo(c1x,c1y,c2x,c2y,x2,y2);
    ctx.stroke();
  }

  function bg(ctx,w,h,t){
    const g=ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#071a2a");
    g.addColorStop(.55,"#03101a");
    g.addColorStop(1,"#010409");
    ctx.fillStyle=g;
    ctx.fillRect(0,0,w,h);

    ctx.strokeStyle="rgba(0,229,255,.055)";
    for(let i=0;i<18;i++){
      const y=h*.58+i*h*.025;
      ctx.beginPath();ctx.moveTo(w*.06,y);ctx.lineTo(w*.94,y+i*i*.10);ctx.stroke();
    }
    for(let i=-14;i<=14;i++){
      ctx.beginPath();ctx.moveTo(w*.50,h*.58);ctx.lineTo(w*.50+i*w*.042,h);ctx.stroke();
    }

    ctx.globalAlpha=.18;
    ctx.fillStyle="#0b3544";
    ctx.beginPath();
    ctx.moveTo(0,h*.72);
    for(let i=0;i<10;i++) ctx.lineTo(w*i/9,h*(.62+.045*Math.sin(i*1.7+t*.15)));
    ctx.lineTo(w,h);ctx.lineTo(0,h);ctx.closePath();ctx.fill();
    ctx.globalAlpha=1;
  }

  function label(ctx,dpr,text,sub){
    ctx.fillStyle="rgba(0,8,14,.70)";
    rr(ctx,14*dpr,14*dpr,360*dpr,54*dpr,8*dpr);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.38)";ctx.stroke();
    ctx.fillStyle="#00e5ff";ctx.font=(13*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText(text,28*dpr,38*dpr);
    ctx.fillStyle="#8fb8c8";ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText(sub,28*dpr,56*dpr);
  }

  function drawTower(ctx,w,h,dpr,t,kind){
    bg(ctx,w,h,t);

    const cx=w*.43, base=h*.82;
    const mastTop=h*.16, mastBot=h*.93, mastW=22*dpr;

    ctx.fillStyle="rgba(0,0,0,.32)";
    ctx.beginPath();ctx.ellipse(cx+80*dpr,base+40*dpr,220*dpr,42*dpr,0,0,Math.PI*2);ctx.fill();

    ctx.fillStyle=metal(ctx,cx-mastW/2,0,cx+mastW/2,0);
    rr(ctx,cx-mastW/2,mastTop,mastW,mastBot-mastTop,12*dpr);ctx.fill();
    ctx.strokeStyle="rgba(255,255,255,.25)";ctx.stroke();

    [h*.42,h*.54,h*.66].forEach(y=>{
      ctx.fillStyle=metal(ctx,cx-44*dpr,y,cx+86*dpr,y);
      rr(ctx,cx-42*dpr,y-7*dpr,130*dpr,14*dpr,6*dpr);ctx.fill();
      ctx.strokeStyle="rgba(0,0,0,.45)";ctx.stroke();
    });

    const panelX=cx+102*dpr, panelY=h*.25, panelW=102*dpr, panelH=300*dpr;
    ctx.save();
    ctx.translate(panelX+panelW/2,panelY+panelH/2);
    ctx.rotate(-7*Math.PI/180);
    ctx.translate(-(panelX+panelW/2),-(panelY+panelH/2));

    ctx.fillStyle="#5b686f";
    rr(ctx,panelX+12*dpr,panelY+10*dpr,panelW,panelH,22*dpr);ctx.fill();
    const pg=ctx.createLinearGradient(panelX,panelY,panelX+panelW,panelY+panelH);
    pg.addColorStop(0,"#f5fbfc");pg.addColorStop(.35,"#b8c5ca");pg.addColorStop(.7,"#eef7f8");pg.addColorStop(1,"#88999f");
    ctx.fillStyle=pg;
    rr(ctx,panelX,panelY,panelW,panelH,24*dpr);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.34)";ctx.stroke();

    ctx.strokeStyle="rgba(40,70,80,.24)";
    for(let i=1;i<7;i++){
      let xx=panelX+i*panelW/7;
      ctx.beginPath();ctx.moveTo(xx,panelY+28*dpr);ctx.bezierCurveTo(xx+5*dpr,panelY+panelH*.40,xx-4*dpr,panelY+panelH*.68,xx,panelY+panelH-26*dpr);ctx.stroke();
    }

    const cbx=panelX+18*dpr, cby=panelY+panelH-31*dpr;
    ctx.fillStyle="#263840";rr(ctx,cbx,cby,panelW-36*dpr,34*dpr,8*dpr);ctx.fill();
    for(let i=0;i<8;i++){
      ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
      ctx.beginPath();ctx.arc(cbx+10*dpr+i*(panelW-56*dpr)/7,cby+18*dpr,4*dpr,0,Math.PI*2);ctx.fill();
    }
    ctx.restore();

    const rruX=cx-82*dpr, rruY=h*.50, rruW=136*dpr, rruH=145*dpr;
    const rg=ctx.createLinearGradient(rruX,rruY,rruX+rruW,rruY+rruH);
    rg.addColorStop(0,"#eaf1f2");rg.addColorStop(.28,"#93a2a8");rg.addColorStop(.58,"#dbe5e7");rg.addColorStop(1,"#65757d");
    ctx.fillStyle=rg;rr(ctx,rruX,rruY,rruW,rruH,18*dpr);ctx.fill();
    ctx.strokeStyle="rgba(255,255,255,.28)";ctx.stroke();

    for(let i=0;i<13;i++){
      let fx=rruX+16*dpr+i*8*dpr;
      ctx.fillStyle=metal(ctx,fx,rruY,fx+5*dpr,rruY);
      rr(ctx,fx,rruY+14*dpr,5*dpr,rruH-28*dpr,3*dpr);ctx.fill();
    }

    const bottom=rruY+rruH+7*dpr;
    for(let i=0;i<8;i++){
      const sx=rruX+16*dpr+i*(rruW-34*dpr)/7;
      const tx=panelX+20*dpr+i*(panelW-40*dpr)/7;
      const color=i%2?"rgba(0,229,255,.80)":"rgba(255,216,77,.88)";
      ctx.fillStyle=i%2?"#00e5ff":"#ffd84d";
      ctx.beginPath();ctx.arc(sx,bottom+8*dpr,4*dpr,0,Math.PI*2);ctx.fill();
      cable(ctx,sx,bottom+10*dpr,tx,panelY+panelH+6*dpr,sx+28*dpr,bottom+70*dpr,tx-45*dpr,panelY+panelH+48*dpr,color,5*dpr);
    }

    cable(ctx,rruX+22*dpr,bottom+25*dpr,rruX-24*dpr,h*.94,rruX+5*dpr,bottom+85*dpr,rruX-40*dpr,h*.80,"rgba(255,118,55,.86)",5*dpr);
    cable(ctx,rruX+48*dpr,bottom+25*dpr,rruX+18*dpr,h*.95,rruX+68*dpr,bottom+85*dpr,rruX,h*.80,"rgba(0,229,255,.72)",4*dpr);

    ctx.strokeStyle="rgba(180,200,205,.82)";ctx.lineWidth=7*dpr;
    ctx.beginPath();ctx.moveTo(cx+12*dpr,h*.54);ctx.lineTo(panelX+16*dpr,panelY+panelH*.42);ctx.stroke();

    const originX=panelX+panelW+10*dpr, originY=panelY+panelH*.34;
    const az=-.18;
    const len=Math.min(w,h)*.62, bw=.42;
    ctx.save();
    for(let layer=0;layer<10;layer++){
      const grad=ctx.createRadialGradient(originX,originY,5*dpr,originX+Math.cos(az)*len*.65,originY+Math.sin(az)*len*.65,len);
      grad.addColorStop(0,`rgba(0,229,255,${.16-layer*.010})`);
      grad.addColorStop(.42,`rgba(30,156,255,${.10-layer*.007})`);
      grad.addColorStop(1,"rgba(0,229,255,0)");
      ctx.fillStyle=grad;
      ctx.beginPath();ctx.moveTo(originX,originY);ctx.arc(originX,originY,len*(.80+layer*.05),az-bw,az+bw);ctx.closePath();ctx.fill();
    }
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<42;i++){
      const f=i/41,a=az-bw+bw*2*f,l=len*(.65+.22*Math.cos((f-.5)*Math.PI));
      ctx.strokeStyle=`rgba(0,229,255,${.025+.16*Math.cos((f-.5)*Math.PI)})`;
      ctx.lineWidth=(.5+1.5*Math.cos((f-.5)*Math.PI))*dpr;
      ctx.beginPath();ctx.moveTo(originX,originY);
      ctx.bezierCurveTo(originX+Math.cos(a)*l*.32,originY+Math.sin(a)*l*.2,originX+Math.cos(a)*l*.70,originY+Math.sin(a)*l*.72,originX+Math.cos(a)*l,originY+Math.sin(a)*l);
      ctx.stroke();
    }
    ctx.restore();

    label(ctx,dpr,"TOWER / RRU / PANEL REALITY ASSET","RF visual component · canvas engineered");
  }

  function drawDish(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    const cx=w*.46,cy=h*.50,r=Math.min(w,h)*.22;
    ctx.fillStyle="rgba(0,0,0,.30)";ctx.beginPath();ctx.ellipse(cx+80*dpr,cy+210*dpr,220*dpr,40*dpr,0,0,Math.PI*2);ctx.fill();

    const poleX=cx-r*1.2;
    ctx.fillStyle=metal(ctx,poleX-10*dpr,0,poleX+10*dpr,0);
    rr(ctx,poleX-10*dpr,h*.20,20*dpr,h*.68,10*dpr);ctx.fill();

    const dg=ctx.createRadialGradient(cx-r*.18,cy-r*.18,10*dpr,cx,cy,r*1.15);
    dg.addColorStop(0,"#f6fbfb");dg.addColorStop(.42,"#b6c4c8");dg.addColorStop(1,"#526169");
    ctx.fillStyle=dg;
    ctx.beginPath();ctx.ellipse(cx,cy,r*1.15,r*.78,-.18,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.34)";ctx.lineWidth=2*dpr;ctx.stroke();

    ctx.fillStyle="#1f3138";rr(ctx,cx-r*.18,cy+r*.38,95*dpr,55*dpr,10*dpr);ctx.fill();
    cable(ctx,cx-r*.10,cy+r*.55,cx-r*.82,h*.86,cx-r*.30,cy+r*.90,cx-r*.92,h*.72,"rgba(0,229,255,.80)",5*dpr);

    ctx.save();ctx.globalCompositeOperation="lighter";
    for(let i=0;i<34;i++){
      const a=-.10+(i/33-.5)*.20,l=Math.min(w,h)*.72;
      ctx.strokeStyle=`rgba(0,229,255,${.03+.13*Math.cos((i/33-.5)*Math.PI)})`;
      ctx.lineWidth=1.4*dpr;
      ctx.beginPath();ctx.moveTo(cx+r*.92,cy-r*.08);ctx.lineTo(cx+r*.92+Math.cos(a)*l,cy-r*.08+Math.sin(a)*l);ctx.stroke();
    }
    ctx.restore();
    label(ctx,dpr,"MICROWAVE DISH / LOS LINK","backhaul visual component · E-band ready");
  }

  function drawSpectrum(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    const left=w*.08,right=w*.94,top=h*.18,bottom=h*.82;
    ctx.strokeStyle="rgba(0,229,255,.13)";
    for(let i=0;i<12;i++){let x=left+(right-left)*i/11;ctx.beginPath();ctx.moveTo(x,top);ctx.lineTo(x,bottom);ctx.stroke();}
    for(let i=0;i<7;i++){let y=top+(bottom-top)*i/6;ctx.beginPath();ctx.moveTo(left,y);ctx.lineTo(right,y);ctx.stroke();}
    ctx.strokeStyle="#00e5ff";ctx.lineWidth=2*dpr;ctx.beginPath();
    for(let i=0;i<800;i++){
      const x=left+(right-left)*i/799;
      let y=bottom-(bottom-top)*(.18+.04*Math.sin(i*.07+t*2));
      for(let p of [.22,.38,.61,.77]){
        const d=(i/799-p);
        y-=Math.exp(-d*d/(.00055))*h*.24;
      }
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
    ctx.fillStyle="rgba(0,229,255,.10)";
    ctx.fillRect(left,top,right-left,bottom-top);
    label(ctx,dpr,"SPECTRUM SCOPE / VSA DISPLAY","FFT · peaks · noise floor · waterfall-ready");
  }

  function drawSmith(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    const cx=w*.50,cy=h*.52,r=Math.min(w,h)*.33;
    ctx.strokeStyle="rgba(0,229,255,.22)";
    ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.stroke();
    for(let k of [.2,.4,.6,.8]){
      ctx.beginPath();ctx.arc(cx+r*k*.5,cy,r*(1-k*.35),0,Math.PI*2);ctx.stroke();
      ctx.beginPath();ctx.arc(cx-r*k*.5,cy,r*(1-k*.35),0,Math.PI*2);ctx.stroke();
    }
    ctx.strokeStyle="rgba(255,216,77,.72)";ctx.lineWidth=2*dpr;ctx.beginPath();
    for(let i=0;i<180;i++){
      const a=-2.5+i/179*4.2;
      const rr=r*(.52+.10*Math.sin(i*.08+t));
      const x=cx+Math.cos(a)*rr,y=cy+Math.sin(a)*rr;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
    ctx.fillStyle="#ff3d7f";ctx.beginPath();ctx.arc(cx,cy,5*dpr,0,Math.PI*2);ctx.fill();
    label(ctx,dpr,"SMITH CHART ENGINE","impedance matching · Γ · VSWR · stub");
  }

  function drawRack(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    const rx=w*.36, ry=h*.18, rw=w*.28, rh=h*.68;
    ctx.fillStyle=metal(ctx,rx,ry,rx+rw,ry);
    rr(ctx,rx,ry,rw,rh,10*dpr);ctx.fill();
    ctx.fillStyle="#07111a";rr(ctx,rx+18*dpr,ry+18*dpr,rw-36*dpr,rh-36*dpr,8*dpr);ctx.fill();
    for(let i=0;i<8;i++){
      const y=ry+36*dpr+i*(rh-72*dpr)/8;
      ctx.fillStyle=i%2?"#102635":"#0b1b26";
      rr(ctx,rx+30*dpr,y,rw-60*dpr,34*dpr,5*dpr);ctx.fill();
      ctx.fillStyle="#75ff5b";ctx.beginPath();ctx.arc(rx+rw-54*dpr,y+17*dpr,3*dpr,0,Math.PI*2);ctx.fill();
      ctx.fillStyle="#00e5ff";ctx.fillRect(rx+52*dpr,y+10*dpr,42*dpr,4*dpr);
    }
    label(ctx,dpr,"DATA CENTER RACK / PDU","power · thermal · network · SNMP telemetry");
  }

  function drawCore(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    const nodes=[
      ["AMF",.30,.30],["SMF",.52,.30],["UPF",.72,.47],
      ["AUSF",.24,.55],["UDM",.45,.64],["gNB",.18,.40],["UE",.10,.62]
    ];
    ctx.strokeStyle="rgba(0,229,255,.32)";ctx.lineWidth=2*dpr;
    const pairs=[[0,1],[1,2],[0,3],[3,4],[5,0],[6,5],[2,4]];
    pairs.forEach(([a,b])=>{
      const A=nodes[a],B=nodes[b];
      ctx.beginPath();ctx.moveTo(w*A[1],h*A[2]);ctx.lineTo(w*B[1],h*B[2]);ctx.stroke();
    });
    nodes.forEach((n,i)=>{
      const x=w*n[1],y=h*n[2];
      ctx.fillStyle=i<5?"rgba(0,229,255,.12)":"rgba(117,255,91,.11)";
      rr(ctx,x-42*dpr,y-18*dpr,84*dpr,36*dpr,8*dpr);ctx.fill();
      ctx.strokeStyle=i<5?"rgba(0,229,255,.55)":"rgba(117,255,91,.55)";ctx.stroke();
      ctx.fillStyle=i<5?"#00e5ff":"#75ff5b";ctx.font=(12*dpr)+"px ui-monospace,Consolas,monospace";
      ctx.fillText(n[0],x-18*dpr,y+4*dpr);
    });
    label(ctx,dpr,"5G CORE / RAN MAP","SUPI/SUCI · AKA · NGAP · PFCP · GTP-U");
  }

  function drawFiber(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    const left=w*.10,right=w*.90, mid=h*.52;
    ctx.strokeStyle="rgba(0,229,255,.20)";
    ctx.lineWidth=8*dpr;
    ctx.beginPath();ctx.moveTo(left,mid);ctx.bezierCurveTo(w*.35,mid-h*.18,w*.55,mid+h*.18,right,mid);ctx.stroke();
    ctx.strokeStyle="rgba(117,255,91,.86)";ctx.lineWidth=2*dpr;
    for(let i=0;i<28;i++){
      const x=left+(right-left)*i/27;
      const y=mid+Math.sin(i*.9+t*2)*h*.025;
      ctx.beginPath();ctx.arc(x,y,4*dpr,0,Math.PI*2);ctx.stroke();
    }
    ctx.strokeStyle="#ffd84d";ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<240;i++){
      const x=left+(right-left)*i/239;
      const loss=(i/239)*h*.30;
      const drop=(i%60===0)?h*.04:0;
      const y=h*.22+loss+drop;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
    label(ctx,dpr,"FIBER / OTDR WORKBENCH","loss · events · reflection · CPRI/eCPRI latency");
  }

  function drawCyber(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    for(let i=0;i<26;i++){
      const x=w*(.12+Math.random()*.76), y=h*(.22+Math.random()*.58);
      ctx.strokeStyle=i%3?"rgba(0,229,255,.28)":"rgba(255,61,127,.32)";
      ctx.beginPath();ctx.arc(x,y,(12+Math.random()*28)*dpr,0,Math.PI*2);ctx.stroke();
    }
    ctx.fillStyle="rgba(255,61,127,.10)";
    rr(ctx,w*.28,h*.34,w*.44,h*.26,16*dpr);ctx.fill();
    ctx.strokeStyle="rgba(255,61,127,.55)";ctx.stroke();
    ctx.fillStyle="#ff3d7f";ctx.font=(18*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("RF / CYBER EVIDENCE",w*.32,h*.45);
    ctx.fillStyle="#8fb8c8";ctx.font=(11*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("spectrum anomaly · rogue RF · event chain",w*.32,h*.50);
    label(ctx,dpr,"CYBER RF INTELLIGENCE","evidence · anomaly · timeline · correlation");
  }

  function drawPortMap(ctx,w,h,dpr,t){
    bg(ctx,w,h,t);
    const cols=8, rows=4;
    for(let r=0;r<rows;r++){
      for(let c=0;c<cols;c++){
        const x=w*.15+c*w*.09, y=h*.22+r*h*.14;
        ctx.fillStyle=(c+r)%2?"#00e5ff":"#ffd84d";
        ctx.beginPath();ctx.arc(x,y,10*dpr,0,Math.PI*2);ctx.fill();
        ctx.fillStyle="#e9fbff";ctx.font=(9*dpr)+"px ui-monospace,Consolas,monospace";
        ctx.fillText("RF"+(r*cols+c+1),x-11*dpr,y+25*dpr);
      }
    }
    label(ctx,dpr,"RRU / ANTENNA PORT MAP","RF branches · polarization · fronthaul group");
  }

  const renderers = {
    "tower-site": drawTower,
    "rru-panel": drawTower,
    "microwave-dish": drawDish,
    "spectrum-scope": drawSpectrum,
    "smith-chart": drawSmith,
    "rack-pdu": drawRack,
    "core-map": drawCore,
    "fiber-otdr": drawFiber,
    "cyber-evidence": drawCyber,
    "port-map": drawPortMap
  };

  class TRFMCVisualAsset extends HTMLElement{
    constructor(){
      super();
      this.canvas = document.createElement("canvas");
      this.canvas.style.width="100%";
      this.canvas.style.height="100%";
      this.canvas.style.display="block";
      this.caption = document.createElement("div");
      this.caption.className = "trfmc-vae-caption";
      this.appendChild(this.canvas);
      this.appendChild(this.caption);
      this._running=false;
    }

    connectedCallback(){
      this._running=true;
      this.caption.textContent = (this.getAttribute("title") || this.getAttribute("kind") || "TRFMC ASSET").toUpperCase();
      requestAnimationFrame(this.frame.bind(this));
    }

    disconnectedCallback(){
      this._running=false;
    }

    frame(ms){
      if(!this._running) return;
      const kind=this.getAttribute("kind") || "tower-site";
      const renderer=renderers[kind] || drawTower;
      const {ctx,w,h,dpr}=fit(this.canvas);
      renderer(ctx,w,h,dpr,ms*.001,kind);
      requestAnimationFrame(this.frame.bind(this));
    }
  }

  if(!customElements.get("trfmc-visual-asset")){
    customElements.define("trfmc-visual-asset", TRFMCVisualAsset);
  }

  window.TRFMC_VISUAL_ASSET_ENGINE_V3 = {
    id: ENGINE_ID,
    components: Object.keys(renderers),
    renderers,
    version: "3.0.0",
    createdAt: new Date().toISOString()
  };
})();
