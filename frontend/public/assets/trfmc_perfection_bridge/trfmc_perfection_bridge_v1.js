/*
 TRFMC Perfection Bridge V1
 Paints small engineering scope canvases inside bridged pages.
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

  function log10(x){return Math.log(x)/Math.LN10}

  function drawScope(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const domain=c.dataset.domain||"rf";
    const t=ms*.001;

    const g=ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");
    g.addColorStop(1,"#010409");
    ctx.fillStyle=g;
    ctx.fillRect(0,0,w,h);

    ctx.strokeStyle="rgba(0,229,255,.11)";
    for(let i=0;i<10;i++){
      const x=w*i/9;
      ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();
    }
    for(let i=0;i<5;i++){
      const y=h*i/4;
      ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();
    }

    ctx.lineWidth=2*dpr;

    if(domain==="core"){
      const nodes=[["UE",.12,.62],["gNB",.28,.38],["AMF",.46,.42],["SMF",.62,.38],["UPF",.80,.58]];
      ctx.strokeStyle="rgba(0,229,255,.36)";
      for(let i=0;i<nodes.length-1;i++){
        ctx.beginPath();ctx.moveTo(w*nodes[i][1],h*nodes[i][2]);ctx.lineTo(w*nodes[i+1][1],h*nodes[i+1][2]);ctx.stroke();
      }
      nodes.forEach((n,i)=>{
        ctx.fillStyle=i<2?"rgba(117,255,91,.13)":"rgba(0,229,255,.13)";
        ctx.strokeStyle=i<2?"rgba(117,255,91,.55)":"rgba(0,229,255,.55)";
        ctx.beginPath();ctx.roundRect(w*n[1]-24*dpr,h*n[2]-12*dpr,48*dpr,24*dpr,6*dpr);ctx.fill();ctx.stroke();
        ctx.fillStyle=i<2?"#75ff5b":"#00e5ff";
        ctx.font=(9*dpr)+"px ui-monospace,Consolas,monospace";
        ctx.fillText(n[0],w*n[1]-10*dpr,h*n[2]+3*dpr);
      });
    } else if(domain==="antenna"){
      const ox=w*.22, oy=h*.70;
      ctx.fillStyle="#d9e5e8";
      ctx.fillRect(ox-5*dpr,h*.20,10*dpr,h*.62);
      ctx.fillStyle="#b7c7cc";
      ctx.beginPath();ctx.roundRect(ox+40*dpr,h*.26,45*dpr,86*dpr,12*dpr);ctx.fill();
      ctx.save();ctx.globalCompositeOperation="lighter";
      for(let i=0;i<34;i++){
        const a=-.36+(i/33)*.72;
        ctx.strokeStyle=`rgba(0,229,255,${.03+.13*Math.cos((i/33-.5)*Math.PI)})`;
        ctx.beginPath();ctx.moveTo(ox+88*dpr,h*.44);ctx.lineTo(ox+88*dpr+Math.cos(a)*w*.62,h*.44+Math.sin(a)*h*.42);ctx.stroke();
      }
      ctx.restore();
    } else {
      ctx.strokeStyle=domain==="fiber"?"#75ff5b":domain==="cyber"?"#ff3d7f":"#00e5ff";
      ctx.beginPath();
      for(let i=0;i<420;i++){
        const x=w*i/419;
        let y=h*.68 - Math.sin(i*.045+t*2)*h*.04;
        if(domain==="microwave"){
          y-=Math.exp(-Math.pow(i/419-.42,2)/.001)*h*.34;
          y-=Math.exp(-Math.pow(i/419-.68,2)/.002)*h*.22;
        } else if(domain==="fiber"){
          y=h*.20+(i/419)*h*.46+((i%90)<4?h*.10:0);
        } else if(domain==="cyber"){
          y=h*.62-Math.abs(Math.sin(i*.055+t*3))*h*.22;
        }
        if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
      }
      ctx.stroke();
    }

    ctx.fillStyle="#8fb8c8";
    ctx.font=(10*dpr)+"px ui-monospace,Consolas,monospace";
    ctx.fillText("TRFMC PERFECTION BRIDGE · "+domain.toUpperCase(),10*dpr,18*dpr);
  }

  function frame(ms){
    document.querySelectorAll("canvas.trfmc-bridge-scope").forEach(c=>drawScope(c,ms));
    requestAnimationFrame(frame);
  }

  if(document.readyState==="loading"){
    document.addEventListener("DOMContentLoaded",()=>requestAnimationFrame(frame));
  } else {
    requestAnimationFrame(frame);
  }
})();
