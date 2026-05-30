/*
 TRFMC Perfection Bridge V3
 Domain-aware weak-to-premium canvas renderer.
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
      let x=w*i/11;
      ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();
    }
    for(let i=0;i<6;i++){
      let y=h*i/5;
      ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();
    }
  }

  function rf(ctx,w,h,dpr,t,color){
    ctx.strokeStyle=color;
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<720;i++){
      const f=i/719;
      const x=w*f;
      let y=h*.68 - Math.sin(i*.035+t*2.1)*h*.034;
      y-=Math.exp(-Math.pow(f-.24,2)/.0007)*h*.22;
      y-=Math.exp(-Math.pow(f-.52,2)/.0008)*h*.36;
      y-=Math.exp(-Math.pow(f-.79,2)/.0012)*h*.18;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
  }

  function antenna(ctx,w,h,dpr,t){
    const ox=w*.18, oy=h*.48;
    ctx.fillStyle="#dce8ed";
    rr(ctx,ox-5*dpr,h*.15,10*dpr,h*.75,5*dpr);ctx.fill();
    ctx.fillStyle="#aebfc5";
    rr(ctx,ox+48*dpr,h*.22,58*dpr,108*dpr,14*dpr);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.40)";ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<46;i++){
      const f=i/45;
      const a=-.45+f*.90;
      ctx.strokeStyle=`rgba(0,229,255,${.025+.16*Math.cos((f-.5)*Math.PI)})`;
      ctx.lineWidth=(.5+1.7*Math.cos((f-.5)*Math.PI))*dpr;
      ctx.beginPath();
      ctx.moveTo(ox+110*dpr,h*.45);
      ctx.lineTo(ox+110*dpr+Math.cos(a)*w*.70,h*.45+Math.sin(a)*h*.55);
      ctx.stroke();
    }
    ctx.restore();
  }

  function microwave(ctx,w,h,dpr,t){
    const cx=w*.28, cy=h*.55, r=Math.min(w,h)*.23;
    ctx.fillStyle="#aebfc5";
    ctx.beginPath();ctx.ellipse(cx,cy,r*1.15,r*.72,-.16,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle="rgba(0,229,255,.42)";ctx.lineWidth=2*dpr;ctx.stroke();

    ctx.save();ctx.globalCompositeOperation="lighter";
    for(let i=0;i<34;i++){
      const f=i/33;
      const a=-.08+(f-.5)*.20;
      ctx.strokeStyle=`rgba(0,229,255,${.04+.15*Math.cos((f-.5)*Math.PI)})`;
      ctx.beginPath();ctx.moveTo(cx+r*.9,cy-r*.06);ctx.lineTo(cx+r*.9+Math.cos(a)*w*.65,cy-r*.06+Math.sin(a)*h*.40);ctx.stroke();
    }
    ctx.restore();
  }

  function fiber(ctx,w,h,dpr,t){
    ctx.strokeStyle="rgba(117,255,91,.78)";
    ctx.lineWidth=3*dpr;
    ctx.beginPath();
    for(let i=0;i<400;i++){
      const f=i/399;
      const x=w*.05+f*w*.90;
      const y=h*.54+Math.sin(f*9+t*2)*h*.06;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();

    ctx.strokeStyle="#ffd84d";
    ctx.lineWidth=2*dpr;
    ctx.beginPath();
    for(let i=0;i<380;i++){
      const f=i/379;
      const x=w*.07+f*w*.86;
      const y=h*.20+f*h*.48+(((i+24)%95)<5?h*.10:0);
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.stroke();
  }

  function cyber(ctx,w,h,dpr,t){
    for(let i=0;i<22;i++){
      const x=w*(.12+((i*37)%100)/100*.78);
      const y=h*(.20+((i*53)%100)/100*.62);
      ctx.strokeStyle=i%3?"rgba(0,229,255,.25)":"rgba(255,61,127,.35)";
      ctx.beginPath();ctx.arc(x,y,(8+(i%7)*4)*dpr,0,Math.PI*2);ctx.stroke();
    }
    rf(ctx,w,h,dpr,t,"#ff3d7f");
  }

  function generic(ctx,w,h,dpr,t){
    ctx.strokeStyle="rgba(117,255,91,.58)";
    ctx.lineWidth=2*dpr;
    const nodes=[["FLOW",.16,.60],["TOKEN",.35,.36],["ASSET",.55,.60],["KPI",.75,.36],["GATE",.88,.62]];
    for(let i=0;i<nodes.length-1;i++){
      const A=nodes[i],B=nodes[i+1];
      ctx.beginPath();ctx.moveTo(w*A[1],h*A[2]);ctx.lineTo(w*B[1],h*B[2]);ctx.stroke();
    }
    nodes.forEach(n=>{
      const x=w*n[1],y=h*n[2];
      ctx.fillStyle="rgba(0,229,255,.11)";
      ctx.strokeStyle="rgba(0,229,255,.55)";
      rr(ctx,x-32*dpr,y-13*dpr,64*dpr,26*dpr,7*dpr);ctx.fill();ctx.stroke();
      ctx.fillStyle="#75ff5b";
      ctx.font=(9*dpr)+"px ui-monospace,Consolas,monospace";
      ctx.fillText(n[0],x-ctx.measureText(n[0]).width/2,y+3*dpr);
    });
  }

  function draw(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const domain=c.dataset.domain||"generic";
    const t=ms*.001;

    const bg=ctx.createLinearGradient(0,0,0,h);
    bg.addColorStop(0,"#061827");
    bg.addColorStop(1,"#010409");
    ctx.fillStyle=bg;
    ctx.fillRect(0,0,w,h);
    grid(ctx,w,h);

    if(domain==="antenna") antenna(ctx,w,h,dpr,t);
    else if(domain==="microwave") microwave(ctx,w,h,dpr,t);
    else if(domain==="fiber") fiber(ctx,w,h,dpr,t);
    else if(domain==="cyber") cyber(ctx,w,h,dpr,t);
    else if(domain==="rf") rf(ctx,w,h,dpr,t,"#00e5ff");
    else generic(ctx,w,h,dpr,t);

    ctx.fillStyle="#8fb8c8";
    ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("BATCH C · WEAK TO PREMIUM · "+domain.toUpperCase(),10*dpr,18*dpr);
  }

  function frame(ms){
    document.querySelectorAll("canvas.trfmc-c3-scope").forEach(c=>draw(c,ms));
    requestAnimationFrame(frame);
  }

  if(document.readyState==="loading"){
    document.addEventListener("DOMContentLoaded",()=>requestAnimationFrame(frame));
  }else{
    requestAnimationFrame(frame);
  }
})();
