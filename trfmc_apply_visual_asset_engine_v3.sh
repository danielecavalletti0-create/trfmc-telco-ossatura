#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSET_DIR="$PUBLIC/assets/trfmc_visual_asset_engine"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_VISUAL_ASSET_ENGINE_V3_$TS"
LATEST="$BASE/runtime/quality/latest_visual_asset_engine_v3"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"
GPU_LAB="$PUBLIC/trfmc_gpu_visual_runtime_lab_v2.html"

CSS="$ASSET_DIR/trfmc_visual_asset_engine_v3.css"
JS="$ASSET_DIR/trfmc_visual_asset_engine_v3.js"
MANIFEST="$PUBLIC/trfmc_visual_asset_engine_manifest_v3.json"
LAB="$PUBLIC/trfmc_visual_asset_engine_lab_v3.html"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC VISUAL ASSET ENGINE V3"
echo "Reusable visual components · GPU-ready cockpit · safe patch"
echo "============================================================"

echo
echo "[1/9] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_VISUAL_ASSET_ENGINE_V3_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_gpu_visual_runtime_v2 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
  [ -f "$GPU_LAB" ] && echo "GPU_LAB_SHA_BEFORE=$(sha256sum "$GPU_LAB" | awk '{print $1}')" || true
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Creo CSS Visual Asset Engine V3"

cat > "$CSS" <<'CSS'
/*
 TRFMC Visual Asset Engine V3
 Reusable premium visual components.
 No CDN. No iframe. No navbar.
*/

trfmc-visual-asset{
  display:block;
  width:100%;
  min-height:280px;
  position:relative;
  overflow:hidden;
  border:1px solid rgba(0,229,255,.34);
  border-radius:10px;
  background:
    radial-gradient(circle at 70% 15%, rgba(0,229,255,.10), transparent 30%),
    linear-gradient(145deg, rgba(2,18,30,.92), rgba(1,7,13,.94));
  box-shadow:
    0 0 34px rgba(0,229,255,.14),
    inset 0 0 24px rgba(0,229,255,.055),
    0 18px 44px rgba(0,0,0,.38);
}

trfmc-visual-asset[data-size="large"]{min-height:520px;}
trfmc-visual-asset[data-size="medium"]{min-height:360px;}
trfmc-visual-asset[data-size="small"]{min-height:220px;}

.trfmc-vae-grid{
  display:grid;
  grid-template-columns:repeat(3,minmax(260px,1fr));
  gap:8px;
}

.trfmc-vae-stage{
  min-height:560px;
}

.trfmc-vae-caption{
  position:absolute;
  left:12px;
  top:10px;
  z-index:3;
  font-family:ui-monospace,Consolas,monospace;
  color:#00e5ff;
  font-size:11px;
  letter-spacing:.08em;
  text-shadow:0 0 14px rgba(0,229,255,.45);
  pointer-events:none;
}

.trfmc-vae-chip{
  display:inline-block;
  border:1px solid rgba(117,255,91,.36);
  background:rgba(117,255,91,.075);
  color:#75ff5b;
  border-radius:6px;
  padding:2px 6px;
  margin-left:6px;
}

@media(max-width:1400px){
  .trfmc-vae-grid{grid-template-columns:1fr;}
}
CSS

echo
echo "[3/9] Creo JS Visual Asset Engine V3"

cat > "$JS" <<'JS'
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
JS

echo
echo "[4/9] Creo manifest Visual Asset Engine"

cat > "$MANIFEST" <<'JSON'
{
  "id": "TRFMC_VISUAL_ASSET_ENGINE_V3",
  "version": "3.0.0",
  "policy": "Reusable visual components. No CDN. No iframe. No new navbar. V6R3 protected.",
  "assets": {
    "css": "/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css",
    "js": "/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"
  },
  "components": [
    "tower-site",
    "rru-panel",
    "microwave-dish",
    "fiber-otdr",
    "spectrum-scope",
    "smith-chart",
    "rack-pdu",
    "core-map",
    "cyber-evidence",
    "port-map"
  ],
  "next": {
    "v4": "Local GLB/GLTF asset loading, PBR material presets, camera orbit controls, object picking and telemetry binding"
  }
}
JSON

echo
echo "[5/9] Creo Visual Asset Engine Lab V3"

cat > "$LAB" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Visual Asset Engine Lab V3</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<style>
.asset-lab{display:grid;grid-template-columns:380px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}
.asset-list{display:grid;grid-template-columns:repeat(2,minmax(280px,1fr));gap:8px}
.mono{font-family:ui-monospace,Consolas,monospace;color:#dffaff;font-size:11px}
@media(max-width:1300px){.asset-lab{grid-template-columns:1fr}.asset-list{grid-template-columns:1fr}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Visual Asset Engine Lab V3</div>
    <div class="leaf-sub">Componenti visuali riusabili: tower, RRU, dish, OTDR, spectrum, Smith chart, rack, 5G core, cyber evidence</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>Components</small><b>10</b></div>
    <div class="leaf-kpi"><small>Runtime</small><b>Canvas</b></div>
    <div class="leaf-kpi"><small>GPU Layer</small><b>WebGL</b></div>
    <div class="leaf-kpi"><small>Mode</small><b>V3</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_gpu_visual_runtime_lab_v2.html">GPU Lab</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="asset-lab">
  <aside class="leaf-panel">
    <h2>Asset Engine</h2>
    <div class="leaf-card">
      <h3>Runtime</h3>
      <pre class="mono" id="runtimeBox">loading...</pre>
    </div>
    <div class="leaf-card">
      <h3>Uso nei moduli</h3>
      <pre class="mono">&lt;trfmc-visual-asset
  kind="tower-site"
  data-size="large"&gt;
&lt;/trfmc-visual-asset&gt;</pre>
    </div>
    <div class="leaf-card">
      <h3>Obiettivo</h3>
      <p>Ogni pagina smette di inventarsi grafica propria e usa asset comuni, coerenti, premium e manutenibili.</p>
    </div>
  </aside>

  <main class="leaf-panel">
    <h2>Premium Visual Components</h2>
    <trfmc-visual-asset kind="tower-site" data-size="large" title="Tower / RRU / Panel Reality Component"></trfmc-visual-asset>
    <div class="asset-list" style="margin-top:8px">
      <trfmc-visual-asset kind="microwave-dish" data-size="medium" title="Microwave Dish LOS"></trfmc-visual-asset>
      <trfmc-visual-asset kind="spectrum-scope" data-size="medium" title="Spectrum Scope"></trfmc-visual-asset>
      <trfmc-visual-asset kind="smith-chart" data-size="medium" title="Smith Chart Engine"></trfmc-visual-asset>
      <trfmc-visual-asset kind="fiber-otdr" data-size="medium" title="Fiber OTDR Workbench"></trfmc-visual-asset>
      <trfmc-visual-asset kind="rack-pdu" data-size="medium" title="Rack / PDU Infrastructure"></trfmc-visual-asset>
      <trfmc-visual-asset kind="core-map" data-size="medium" title="5G Core / RAN Map"></trfmc-visual-asset>
      <trfmc-visual-asset kind="cyber-evidence" data-size="medium" title="Cyber RF Evidence"></trfmc-visual-asset>
      <trfmc-visual-asset kind="port-map" data-size="medium" title="RF Port Mapping"></trfmc-visual-asset>
    </div>
  </main>
</div>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script>
document.getElementById("runtimeBox").textContent = JSON.stringify({
  gpu: window.TRFMC_GPU_RUNTIME || null,
  assetEngine: window.TRFMC_VISUAL_ASSET_ENGINE_V3 || null,
  webgpu: !!navigator.gpu
}, null, 2);
</script>
</body>
</html>
HTML

echo
echo "[6/9] Patch GPU Lab V2: riempio il preview vuoto con Asset Engine"

python3 - "$GPU_LAB" <<'PY'
from pathlib import Path
import re, sys

p=Path(sys.argv[1])
s=p.read_text(errors="ignore")

css='/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css'
js='/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js'

if css not in s:
    s=re.sub(r'</head>', f'<link rel="stylesheet" href="{css}">\n</head>', s, count=1, flags=re.I)

if '<canvas id="localPreview"></canvas>' in s:
    s=s.replace(
        '<canvas id="localPreview"></canvas>',
        '<trfmc-visual-asset kind="tower-site" data-size="large" title="GPU Field Preview · Tower Site Asset"></trfmc-visual-asset>'
    )

if js not in s:
    s=re.sub(r'</body>', f'<script src="{js}"></script>\n</body>', s, count=1, flags=re.I)

p.write_text(s)
PY

echo
echo "[7/9] Registro lab V3 nel registry"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public=Path(sys.argv[1])
reg_path=Path(sys.argv[2])
reg=json.loads(reg_path.read_text(errors="ignore"))
pages=reg.get("pages",[])
by_url={p.get("url"):p for p in pages if p.get("url")}

target=public/"trfmc_visual_asset_engine_lab_v3.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_visual_asset_engine_lab_v3.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_visual_asset_engine_lab_v3.html",
  "url":"/trfmc_visual_asset_engine_lab_v3.html",
  "size":target.stat().st_size,
  "canvas":True,
  "webgl_runtime":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Visual Asset Engine V3 component library lab"
}

reg["pages"]=list(by_url.values())
counts={}
for p in reg["pages"]:
    c=p.get("class","unknown")
    counts[c]=counts.get(c,0)+1
counts["total_html"]=len(reg["pages"])
for k in ["official_shell","service","leaf_operational_candidate","shell_or_legacy_container","orphan_or_legacy_candidate"]:
    counts.setdefault(k,0)

reg["counts"]=counts
reg["last_visual_asset_engine_v3_update"]={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "page":"/trfmc_visual_asset_engine_lab_v3.html",
  "patched":"/trfmc_gpu_visual_runtime_lab_v2.html",
  "policy":"component library added; V6R3 and Control Room protected"
}

reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_visual_asset_engine_v3_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[8/9] Quality gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css \
    /assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js \
    /trfmc_visual_asset_engine_manifest_v3.json \
    /trfmc_visual_asset_engine_lab_v3.html \
    /trfmc_gpu_visual_runtime_lab_v2.html \
    /trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_portal_registry_unified.json
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/fused_forbidden_refs.txt"
: > "$OUT/content_checks.txt"

for f in "$CSS" "$JS" "$MANIFEST" "$LAB" "$GPU_LAB"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
  grep -nEi 'MASTER FUSED|trfmc_master_fused|fallback shell' "$f" >> "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC_VISUAL_ASSET_ENGINE_V3" \
  "customElements.define" \
  "trfmc-visual-asset" \
  "tower-site" \
  "microwave-dish" \
  "fiber-otdr" \
  "spectrum-scope" \
  "smith-chart" \
  "core-map" \
  "cyber-evidence"
do
  if grep -Rqs "$token" "$ASSET_DIR" "$LAB" "$GPU_LAB" "$MANIFEST"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
  [ -f "$GPU_LAB" ] && echo "GPU_LAB_SHA_AFTER=$(sha256sum "$GPU_LAB" | awk '{print $1}')" || true
} > "$OUT/sha_compare.txt"

echo
echo "[9/9] Summary + freeze"

python3 - "$OUT" "$REG" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

out=Path(sys.argv[1])
reg_path=Path(sys.argv[2])

http=[]
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=3:
        http.append({"url":p[0],"status":p[1],"bytes":p[2]})

non200=sum(1 for x in http if x["status"]!="200")
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fused=sum(1 for x in (out/"fused_forbidden_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
content_miss=sum(1 for x in (out/"content_checks.txt").read_text(errors="ignore").splitlines() if x.startswith("MISS:"))

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.strip().split("=",1)
        sha[k]=v

protected_ok=(
    sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER")
)
registry_changed=sha.get("REG_SHA_BEFORE")!=sha.get("REG_SHA_AFTER")
gpu_lab_changed=sha.get("GPU_LAB_SHA_BEFORE")!=sha.get("GPU_LAB_SHA_AFTER")
reg=json.loads(reg_path.read_text(errors="ignore"))

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "engine":"TRFMC_VISUAL_ASSET_ENGINE_V3",
  "lab":"/trfmc_visual_asset_engine_lab_v3.html",
  "patched_gpu_lab":"/trfmc_gpu_visual_runtime_lab_v2.html",
  "http_non_200":non200,
  "external_refs":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "content_check_miss":content_miss,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "gpu_lab_preview_fixed":gpu_lab_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and content_miss==0 and protected_ok and registry_changed and gpu_lab_changed else "WARN",
  "policy":"Visual Asset Engine V3 added as reusable component library. V6R3 and Control Room unchanged."
}
(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_VISUAL_ASSET_ENGINE_V3_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_visual_asset_engine \
    frontend/public/trfmc_visual_asset_engine_manifest_v3.json \
    frontend/public/trfmc_visual_asset_engine_lab_v3.html \
    frontend/public/trfmc_gpu_visual_runtime_lab_v2.html \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_visual_asset_engine_v3 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "Content checks:"
cat "$OUT/content_checks.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_visual_asset_engine_lab_v3.html"
echo "http://127.0.0.1:5173/trfmc_gpu_visual_runtime_lab_v2.html"
echo "============================================================"
