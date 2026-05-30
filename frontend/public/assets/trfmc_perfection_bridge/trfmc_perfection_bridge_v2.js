/*
 TRFMC Perfection Bridge V2
 Domain scope renderer for surgical leaf remediation.
*/
(function(){
  "use strict";

  function fit(c){
    const dpr=Math.min(2,window.devicePixelRatio||1);
    const w=Math.max(2,Math.floor(c.clientWidth*dpr));
    const h=Math.max(2,Math.floor(c.clientHeight*dpr));
    if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
    return {ctx:c.getContext("2d"),w,h,dpr};
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

  function grid(ctx,w,h){
    ctx.strokeStyle="rgba(0,229,255,.10)";
    for(let i=0;i<12;i++){
      const x=w*i/11;
      ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();
    }
    for(let i=0;i<6;i++){
      const y=h*i/5;
      ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();
    }
  }

  function drawCore(ctx,w,h,dpr,t){
    const nodes=[
      ["UE",.08,.62,"g"],["gNB",.23,.38,"g"],["AMF",.43,.34,"c"],
      ["AUSF",.43,.66,"c"],["UDM",.61,.66,"c"],["SMF",.61,.34,"c"],["UPF",.82,.50,"c"]
    ];
    const links=[[0,1],[1,2],[2,3],[3,4],[2,5],[5,6],[4,5]];
    ctx.lineWidth=2*dpr;
    links.forEach(([a,b],idx)=>{
      const A=nodes[a],B=nodes[b];
      const p=(Math.sin(t*2+idx)+1)/2;
      ctx.strokeStyle=`rgba(0,229,255,${.18+.22*p})`;
      ctx.beginPath();ctx.moveTo(w*A[1],h*A[2]);ctx.lineTo(w*B[1],h*B[2]);ctx.stroke();
    });
    nodes.forEach((n,idx)=>{
      const x=w*n[1], y=h*n[2], green=n[3]==="g";
      ctx.fillStyle=green?"rgba(117,255,91,.12)":"rgba(0,229,255,.12)";
      ctx.strokeStyle=green?"rgba(117,255,91,.58)":"rgba(0,229,255,.58)";
      rr(ctx,x-32*dpr,y-14*dpr,64*dpr,28*dpr,7*dpr);ctx.fill();ctx.stroke();
      ctx.fillStyle=green?"#75ff5b":"#00e5ff";
      ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
      ctx.fillText(n[0],x-ctx.measureText(n[0]).width/2,y+3*dpr);
    });
  }

  function drawRF(ctx,w,h,dpr,t,color){
    ctx.strokeStyle=color;
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<640;i++){
      const x=w*i/639;
      let y=h*.66 - Math.sin(i*.036+t*2.0)*h*.035;
      y-=Math.exp(-Math.pow(i/639-.26,2)/.0006)*h*.22;
      y-=Math.exp(-Math.pow(i/639-.52,2)/.0008)*h*.34;
      y-=Math.exp(-Math.pow(i/639-.78,2)/.0012)*h*.18;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
  }

  function drawAntenna(ctx,w,h,dpr,t){
    const ox=w*.18, oy=h*.72;
    ctx.fillStyle="#dce8ed";
    rr(ctx,ox-5*dpr,h*.18,10*dpr,h*.68,5*dpr);ctx.fill();
    ctx.fillStyle="#aebfc5";
    rr(ctx,ox+50*dpr,h*.22,54*dpr,102*dpr,13*dpr);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.38)";ctx.stroke();
    ctx.save();ctx.globalCompositeOperation="lighter";
    for(let i=0;i<42;i++){
      const f=i/41;
      const a=-.40+f*.80;
      ctx.strokeStyle=`rgba(0,229,255,${.025+.14*Math.cos((f-.5)*Math.PI)})`;
      ctx.lineWidth=(.5+1.5*Math.cos((f-.5)*Math.PI))*dpr;
      ctx.beginPath();ctx.moveTo(ox+108*dpr,h*.42);ctx.lineTo(ox+108*dpr+Math.cos(a)*w*.70,h*.42+Math.sin(a)*h*.52);ctx.stroke();
    }
    ctx.restore();
  }

  function drawScope(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const domain=c.dataset.domain||"core";
    const t=ms*.001;

    const bg=ctx.createLinearGradient(0,0,0,h);
    bg.addColorStop(0,"#061827");
    bg.addColorStop(1,"#010409");
    ctx.fillStyle=bg;
    ctx.fillRect(0,0,w,h);
    grid(ctx,w,h);

    if(domain==="core"){ drawCore(ctx,w,h,dpr,t); }
    else if(domain==="antenna"){ drawAntenna(ctx,w,h,dpr,t); }
    else if(domain==="cyber"){ drawRF(ctx,w,h,dpr,t,"#ff3d7f"); }
    else if(domain==="fiber"){
      ctx.strokeStyle="#75ff5b";ctx.lineWidth=2*dpr;ctx.beginPath();
      for(let i=0;i<420;i++){
        const x=w*i/419;
        const y=h*.18+(i/419)*h*.52+(((i+20)%105)<5?h*.12:0);
        if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
      }
      ctx.stroke();
    }
    else { drawRF(ctx,w,h,dpr,t,"#00e5ff"); }

    ctx.fillStyle="#8fb8c8";
    ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("BATCH B LEAF ONLY · "+domain.toUpperCase()+" · LIVE CANVAS",10*dpr,18*dpr);
  }

  function frame(ms){
    document.querySelectorAll("canvas.trfmc-b2-scope").forEach(c=>drawScope(c,ms));
    requestAnimationFrame(frame);
  }

  if(document.readyState==="loading"){
    document.addEventListener("DOMContentLoaded",()=>requestAnimationFrame(frame));
  } else {
    requestAnimationFrame(frame);
  }
})();
