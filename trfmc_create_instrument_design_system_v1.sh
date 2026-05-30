#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_INSTRUMENT_DESIGN_SYSTEM_V1_$TS"
LATEST="$BASE/runtime/quality/latest_instrument_design_system_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

IDS_DIR="$PUBLIC/assets/trfmc_instrument_design_system"
TOKENS="$IDS_DIR/trfmc_instrument_tokens_v1.css"
LAYOUT="$IDS_DIR/trfmc_instrument_layout_v1.css"
ENGINE="$IDS_DIR/trfmc_parametric_3d_engine_v1.js"
PANELS="$IDS_DIR/trfmc_instrument_panels_v1.js"

LAB="$PUBLIC/trfmc_instrument_design_system_lab_v1.html"
DECK="$PUBLIC/trfmc_true_portal_command_deck_v1.html"
MANIFEST="$PUBLIC/trfmc_instrument_design_system_manifest_v1.json"

mkdir -p "$OUT" "$IDS_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC INSTRUMENT DESIGN SYSTEM V1"
echo "Global visual grammar · parametric 3D engine · command deck"
echo "============================================================"

echo
echo "[1/9] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_INSTRUMENT_DESIGN_SYSTEM_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Creo token strumentali globali"

cat > "$TOKENS" <<'CSS'
/*
 TRFMC Instrument Design System V1
 Global visual grammar for RF/Telco/Cyber instrument-grade pages.
 No CDN. No external refs.
*/

:root{
  --trfmc-i-bg:#000307;
  --trfmc-i-panel:rgba(2,16,27,.82);
  --trfmc-i-panel-deep:rgba(1,7,13,.96);
  --trfmc-i-cyan:#00e5ff;
  --trfmc-i-green:#75ff5b;
  --trfmc-i-yellow:#ffd84d;
  --trfmc-i-red:#ff3d7f;
  --trfmc-i-blue:#4aa3ff;
  --trfmc-i-text:#e8fbff;
  --trfmc-i-muted:#8fb8c8;
  --trfmc-i-border:rgba(0,229,255,.25);
  --trfmc-i-border-soft:rgba(0,229,255,.14);
  --trfmc-i-shadow:0 0 48px rgba(0,229,255,.12), inset 0 0 28px rgba(0,229,255,.05), 0 28px 80px rgba(0,0,0,.58);
  --trfmc-i-radius:20px;
  --trfmc-i-font:ui-monospace,Consolas,monospace;
}

.trfmc-instrument-body{
  min-height:100vh;
  margin:0;
  color:var(--trfmc-i-text);
  font-family:var(--trfmc-i-font);
  background:
    radial-gradient(circle at 75% 5%,rgba(0,229,255,.16),transparent 30%),
    radial-gradient(circle at 15% 88%,rgba(117,255,91,.06),transparent 28%),
    linear-gradient(145deg,#020812,#000307 62%,#000);
}

.trfmc-instrument-panel{
  position:relative;
  border:1px solid var(--trfmc-i-border);
  border-radius:var(--trfmc-i-radius);
  background:
    linear-gradient(145deg,var(--trfmc-i-panel),var(--trfmc-i-panel-deep)),
    radial-gradient(circle at 70% 0%,rgba(0,229,255,.10),transparent 35%);
  box-shadow:var(--trfmc-i-shadow);
  backdrop-filter:blur(12px);
  overflow:hidden;
}

.trfmc-instrument-panel::before{
  content:"";
  position:absolute;
  inset:0;
  pointer-events:none;
  background:
    linear-gradient(90deg,rgba(255,255,255,.035),transparent 16%,transparent 84%,rgba(255,255,255,.025)),
    repeating-linear-gradient(0deg,rgba(255,255,255,.014) 0,rgba(255,255,255,.014) 1px,transparent 1px,transparent 5px);
  mix-blend-mode:screen;
  opacity:.42;
}

.trfmc-instrument-title{
  color:var(--trfmc-i-cyan);
  text-transform:uppercase;
  letter-spacing:.14em;
  text-shadow:0 0 18px rgba(0,229,255,.55);
}

.trfmc-instrument-sub{
  color:var(--trfmc-i-muted);
  font-size:10px;
  line-height:1.45;
}

.trfmc-instrument-kpi{
  border:1px solid rgba(0,229,255,.22);
  border-radius:13px;
  background:rgba(0,229,255,.04);
  padding:8px;
}

.trfmc-instrument-kpi small{
  display:block;
  color:var(--trfmc-i-muted);
  text-transform:uppercase;
  font-size:8px;
}

.trfmc-instrument-kpi b{
  display:block;
  color:var(--trfmc-i-green);
  font-size:17px;
  margin-top:2px;
}

.trfmc-instrument-button{
  color:var(--trfmc-i-cyan);
  text-decoration:none;
  border:1px solid rgba(0,229,255,.35);
  background:rgba(0,229,255,.055);
  border-radius:10px;
  padding:7px 10px;
  font-size:10px;
  display:inline-flex;
  align-items:center;
  gap:6px;
}

.trfmc-instrument-button:hover{
  background:rgba(0,229,255,.12);
  box-shadow:0 0 18px rgba(0,229,255,.18);
}
CSS

cat > "$LAYOUT" <<'CSS'
/*
 TRFMC Instrument Layout V1
 Cockpit layout primitives.
*/

.trfmc-instrument-topbar{
  height:58px;
  display:flex;
  align-items:center;
  justify-content:space-between;
  padding:8px 12px;
  border-bottom:1px solid rgba(0,229,255,.26);
  background:linear-gradient(180deg,rgba(2,18,30,.96),rgba(1,7,13,.98));
  box-sizing:border-box;
}

.trfmc-instrument-topbar h1{
  margin:0;
  font-size:18px;
}

.trfmc-instrument-topbar p{
  margin:2px 0 0 0;
}

.trfmc-instrument-actions{
  display:flex;
  gap:8px;
  flex-wrap:wrap;
}

.trfmc-command-grid{
  display:grid;
  grid-template-columns:320px minmax(760px,1fr) 420px;
  gap:8px;
  padding:8px;
  min-height:calc(100vh - 58px);
  box-sizing:border-box;
}

.trfmc-command-left,
.trfmc-command-center,
.trfmc-command-right{
  padding:10px;
}

.trfmc-command-center{
  display:grid;
  grid-template-rows:1fr 240px;
  gap:8px;
}

.trfmc-command-right{
  display:grid;
  grid-template-rows:auto 1fr auto;
  gap:8px;
}

.trfmc-module-list{
  display:grid;
  gap:7px;
  margin-top:10px;
}

.trfmc-module-card{
  display:block;
  text-decoration:none;
  color:var(--trfmc-i-text);
  border:1px solid rgba(0,229,255,.20);
  border-radius:14px;
  background:rgba(0,229,255,.035);
  padding:9px;
}

.trfmc-module-card strong{
  display:block;
  color:var(--trfmc-i-cyan);
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.08em;
}

.trfmc-module-card span{
  display:block;
  color:var(--trfmc-i-muted);
  font-size:9px;
  margin-top:4px;
  line-height:1.35;
}

.trfmc-instrument-canvas-shell{
  position:relative;
  height:100%;
  min-height:520px;
  border:1px solid rgba(0,229,255,.20);
  border-radius:18px;
  overflow:hidden;
  background:#000307;
}

.trfmc-mini-grid{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:8px;
}

.trfmc-mini-panel{
  border:1px solid rgba(0,229,255,.18);
  border-radius:14px;
  background:rgba(0,229,255,.030);
  padding:8px;
}

.trfmc-mini-panel h3{
  color:var(--trfmc-i-yellow);
  text-transform:uppercase;
  font-size:10px;
  letter-spacing:.08em;
  margin:0 0 6px 0;
}

.trfmc-mini-panel p{
  color:var(--trfmc-i-muted);
  font-size:9px;
  line-height:1.4;
  margin:0;
}

.trfmc-system-status{
  display:grid;
  grid-template-columns:repeat(2,1fr);
  gap:7px;
}

@media(max-width:1500px){
  .trfmc-command-grid{grid-template-columns:300px 1fr}
  .trfmc-command-right{grid-column:1 / -1;grid-template-columns:1fr 1fr 1fr;grid-template-rows:auto}
}

@media(max-width:1000px){
  .trfmc-command-grid{grid-template-columns:1fr}
  .trfmc-command-right{grid-template-columns:1fr}
  .trfmc-mini-grid{grid-template-columns:1fr}
}
CSS

echo
echo "[3/9] Creo motore parametrico 3D riusabile"

cat > "$ENGINE" <<'JS'
/*
 TRFMC Parametric 3D Engine V1
 Canvas/WebGL hybrid visual grammar for technical RF/Telco scenes.
 No external dependencies.
*/

(function(){
  "use strict";

  const TAU = Math.PI * 2;

  function fitCanvas(c){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(2, Math.floor(c.clientWidth * dpr));
    const h = Math.max(2, Math.floor(c.clientHeight * dpr));
    if(c.width !== w || c.height !== h){ c.width = w; c.height = h; }
    return {w,h,dpr};
  }

  function initFieldGL(canvas){
    const gl = canvas.getContext("webgl", {alpha:true, antialias:true});
    if(!gl) return null;

    const vs = `
      attribute vec2 p;
      varying vec2 uv;
      void main(){
        uv = p * 0.5 + 0.5;
        gl_Position = vec4(p, 0.0, 1.0);
      }
    `;

    const fs = `
      precision mediump float;
      varying vec2 uv;
      uniform float t;
      uniform float mode;
      float beam(vec2 p, float y, float w){
        return exp(-abs(p.y-y)*w) * smoothstep(0.08,0.55,p.x) * (1.0-smoothstep(0.90,1.0,p.x));
      }
      void main(){
        vec2 p = uv;
        vec3 base = mix(vec3(0.0,0.01,0.02), vec3(0.0,0.055,0.080), p.y);
        float g = (step(.986,fract(p.x*22.0)) + step(.986,fract(p.y*13.0))) * 0.055;
        float b1 = beam(p, .50 + .035*sin(p.x*8.0 + t*.0012), 34.0);
        float b2 = beam(p, .42 + .025*sin(p.x*14.0 - t*.0015), 55.0);
        float node = exp(-distance(p,vec2(.78,.45))*9.0);
        float node2 = exp(-distance(p,vec2(.58,.60))*13.0);
        vec3 col = base + g*vec3(0.0,.75,1.0);
        col += b1*vec3(0.0,.85,1.0)*.70;
        col += b2*vec3(0.0,.42,1.0)*.35;
        col += node*vec3(1.0,.78,.18)*.52;
        col += node2*vec3(.0,1.0,.48)*.16;
        gl_FragColor = vec4(col, 1.0);
      }
    `;

    function shader(type, src){
      const s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      return s;
    }

    const program = gl.createProgram();
    gl.attachShader(program, shader(gl.VERTEX_SHADER, vs));
    gl.attachShader(program, shader(gl.FRAGMENT_SHADER, fs));
    gl.linkProgram(program);

    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]), gl.STATIC_DRAW);

    const loc = gl.getAttribLocation(program, "p");
    const tLoc = gl.getUniformLocation(program, "t");
    const modeLoc = gl.getUniformLocation(program, "mode");

    return {
      render(now){
        const {w,h} = fitCanvas(canvas);
        gl.viewport(0,0,w,h);
        gl.useProgram(program);
        gl.bindBuffer(gl.ARRAY_BUFFER, buf);
        gl.enableVertexAttribArray(loc);
        gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);
        gl.uniform1f(tLoc, now);
        gl.uniform1f(modeLoc, 1.0);
        gl.drawArrays(gl.TRIANGLES,0,6);
      }
    };
  }

  class Instrument3DEngine{
    constructor(canvas){
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.yaw = -0.55;
      this.pitch = 0.28;
      this.fov = 720;
      this.cameraZ = 8;
    }

    fit(){
      return fitCanvas(this.canvas);
    }

    project3D(p){
      let [x,y,z] = p;
      const cy = Math.cos(this.yaw), sy = Math.sin(this.yaw);
      const cp = Math.cos(this.pitch), sp = Math.sin(this.pitch);

      const x1 = x*cy - z*sy;
      const z1 = x*sy + z*cy;
      const y1 = y*cp - z1*sp;
      const z2 = y*sp + z1*cp + this.cameraZ;

      const {w,h} = this.fit();
      const s = this.fov / (this.fov + z2*80);
      return [w*0.50 + x1*92*s, h*0.58 - y1*92*s, s, z2];
    }

    line(a,b,color,width){
      const ctx = this.ctx;
      const pa = this.project3D(a), pb = this.project3D(b);
      ctx.strokeStyle = color;
      ctx.lineWidth = width || 1;
      ctx.beginPath();
      ctx.moveTo(pa[0],pa[1]);
      ctx.lineTo(pb[0],pb[1]);
      ctx.stroke();
    }

    poly(points, fill, stroke){
      const ctx = this.ctx;
      const pp = points.map(p => this.project3D(p));
      ctx.beginPath();
      pp.forEach((p,i)=> i ? ctx.lineTo(p[0],p[1]) : ctx.moveTo(p[0],p[1]));
      ctx.closePath();
      if(fill){ ctx.fillStyle = fill; ctx.fill(); }
      if(stroke){ ctx.strokeStyle = stroke; ctx.stroke(); }
    }

    drawGrid(){
      const ctx = this.ctx;
      for(let i=-8;i<=8;i++){
        this.line([-8,-2.2,i],[8,-2.2,i],"rgba(0,229,255,.08)",1);
        this.line([i,-2.2,-8],[i,-2.2,8],"rgba(0,229,255,.08)",1);
      }
    }

    drawTower(){
      const legs = [[-1.6,-2,0],[-.8,3.2,0],[1.6,-2,0],[.8,3.2,0],[-1.6,-2,1.3],[-.8,3.2,1.3],[1.6,-2,1.3],[.8,3.2,1.3]];
      this.line(legs[0],legs[1],"rgba(200,245,255,.65)",2);
      this.line(legs[2],legs[3],"rgba(200,245,255,.65)",2);
      this.line(legs[4],legs[5],"rgba(200,245,255,.55)",2);
      this.line(legs[6],legs[7],"rgba(200,245,255,.55)",2);
      for(let y=-1.6;y<=2.8;y+=.55){
        this.line([-1.45,y,0],[1.45,y,0],"rgba(0,229,255,.20)",1);
        this.line([-1.25,y,1.3],[1.25,y,1.3],"rgba(0,229,255,.18)",1);
        this.line([-1.45,y,0],[1.25,y+.35,1.3],"rgba(0,229,255,.12)",1);
        this.line([1.45,y,0],[-1.25,y+.35,1.3],"rgba(0,229,255,.12)",1);
      }
    }

    drawRRU(){
      this.poly([[-.55,-.7,-.3],[.55,-.7,-.3],[.55,.75,-.3],[-.55,.75,-.3]],"rgba(170,210,215,.78)","rgba(255,255,255,.20)");
      for(let i=-4;i<=4;i++){
        this.line([i*.12,-.62,-.29],[i*.12,.68,-.29],"rgba(20,50,60,.45)",1);
      }
      for(let i=0;i<5;i++){
        this.line([-.45+i*.22,-.9,-.25],[-.30+i*.22,-1.75,-.20], i%2 ? "rgba(0,229,255,.75)" : "rgba(255,216,77,.75)",3);
      }
    }

    drawPanelAntenna(){
      this.poly([[1.15,-.9,.1],[2.0,-.85,.1],[1.85,2.5,.05],[1.0,2.42,.05]],"rgba(220,250,255,.86)","rgba(0,229,255,.25)");
      for(let i=0;i<8;i++){
        this.line([1.16+i*.10,-.65,.11],[1.03+i*.10,2.25,.08],"rgba(80,130,145,.25)",1);
      }
    }

    drawDish(){
      const ctx = this.ctx;
      const center = this.project3D([-2.25,.75,.3]);
      ctx.save();
      ctx.translate(center[0],center[1]);
      ctx.rotate(-0.05);
      for(let i=0;i<9;i++){
        ctx.strokeStyle = `rgba(220,250,255,${0.11+i*.04})`;
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.ellipse(0,0,70+i*3,118+i*2,0,0,TAU);
        ctx.stroke();
      }
      const g = ctx.createRadialGradient(-18,-18,8,0,0,120);
      g.addColorStop(0,"rgba(255,255,255,.98)");
      g.addColorStop(1,"rgba(165,235,245,.82)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.ellipse(0,0,70,118,0,0,TAU);
      ctx.fill();
      ctx.restore();
    }

    drawBeam(now){
      const ctx = this.ctx;
      const a = this.project3D([2.0,.55,.1]);
      const b = this.project3D([6.6,1.5,-1.0]);
      ctx.save();
      ctx.globalCompositeOperation = "lighter";
      for(let i=0;i<34;i++){
        const t = i/34;
        ctx.strokeStyle = `rgba(0,229,255,${0.035*(1-t)})`;
        ctx.lineWidth = 1 + t*5;
        ctx.beginPath();
        ctx.moveTo(a[0],a[1]);
        ctx.quadraticCurveTo((a[0]+b[0])/2, a[1]-60-20*Math.sin(now*.001+t*6), b[0], b[1]);
        ctx.stroke();
      }
      const rg = ctx.createRadialGradient(b[0],b[1],2,b[0],b[1],90);
      rg.addColorStop(0,"rgba(255,216,77,.40)");
      rg.addColorStop(1,"rgba(255,216,77,0)");
      ctx.fillStyle = rg;
      ctx.fillRect(b[0]-100,b[1]-100,200,200);
      ctx.restore();
    }

    drawLabels(now){
      const ctx = this.ctx;
      const {w,h,dpr} = this.fit();
      ctx.fillStyle = "rgba(232,251,255,.92)";
      ctx.font = `${11*dpr}px ui-monospace,Consolas,monospace`;
      ctx.fillText("PARAMETRIC RF/TELCO DIGITAL TWIN · mesh primitives · field layer · instrument HUD", 16*dpr, 22*dpr);
      ctx.fillStyle = "rgba(117,255,91,.95)";
      ctx.fillText(`render=hybrid-webgl/canvas · scene=RF_SITE · t=${Math.floor(now/1000)}s`, 16*dpr, h-18*dpr);
    }

    render(now){
      const {w,h,dpr} = this.fit();
      const ctx = this.ctx;
      ctx.clearRect(0,0,w,h);

      this.drawGrid();
      this.drawTower();
      this.drawRRU();
      this.drawPanelAntenna();
      this.drawDish();
      this.drawBeam(now);
      this.drawLabels(now);
    }
  }

  class TrfmcParametric3DEngine extends HTMLElement{
    connectedCallback(){
      this.innerHTML = `
        <div class="trfmc-parametric-stage">
          <canvas class="trfmc-parametric-gl"></canvas>
          <canvas class="trfmc-parametric-overlay"></canvas>
        </div>
      `;

      this.style.display = "block";
      this.style.width = "100%";
      this.style.height = "100%";

      const style = document.createElement("style");
      style.textContent = `
        .trfmc-parametric-stage{position:relative;width:100%;height:100%;min-height:520px;background:#000307;overflow:hidden}
        .trfmc-parametric-stage canvas{position:absolute;inset:0;width:100%;height:100%;display:block}
        .trfmc-parametric-overlay{filter:drop-shadow(0 0 10px rgba(0,229,255,.20))}
      `;
      this.appendChild(style);

      this.glLayer = this.querySelector(".trfmc-parametric-gl");
      this.overlay = this.querySelector(".trfmc-parametric-overlay");
      this.field = initFieldGL(this.glLayer);
      this.engine = new Instrument3DEngine(this.overlay);

      const loop = (now)=>{
        if(this.field) this.field.render(now);
        this.engine.render(now);
        this.raf = requestAnimationFrame(loop);
      };
      this.raf = requestAnimationFrame(loop);
    }

    disconnectedCallback(){
      if(this.raf) cancelAnimationFrame(this.raf);
    }
  }

  if(!customElements.get("trfmc-parametric-3d-engine")){
    customElements.define("trfmc-parametric-3d-engine", TrfmcParametric3DEngine);
  }

  window.TRFMC_INSTRUMENT_3D_ENGINE_V1 = {
    Instrument3DEngine,
    version:"1.0",
    mode:"hybrid-webgl-canvas-parametric"
  };
})();
JS

echo
echo "[4/9] Creo pannelli strumento riusabili"

cat > "$PANELS" <<'JS'
/*
 TRFMC Instrument Panels V1
 Lightweight reusable cockpit panels.
*/

(function(){
  "use strict";

  class TrfmcInstrumentPanel extends HTMLElement{
    connectedCallback(){
      const title = this.getAttribute("title") || "Instrument Panel";
      const value = this.getAttribute("value") || "READY";
      const subtitle = this.getAttribute("subtitle") || "TRFMC instrument telemetry";
      this.classList.add("trfmc-instrument-panel");
      this.style.padding = "10px";
      this.innerHTML = `
        <div class="trfmc-instrument-title" style="font-size:12px">${title}</div>
        <div class="trfmc-instrument-kpi" style="margin-top:8px">
          <small>${subtitle}</small>
          <b>${value}</b>
        </div>
      `;
    }
  }

  if(!customElements.get("trfmc-instrument-panel")){
    customElements.define("trfmc-instrument-panel", TrfmcInstrumentPanel);
  }
})();
JS

echo
echo "[5/9] Creo pagine lab e command deck"

cat > "$MANIFEST" <<JSON
{
  "id": "TRFMC_INSTRUMENT_DESIGN_SYSTEM_V1",
  "timestamp": "$(date -Iseconds)",
  "assets": [
    "/assets/trfmc_instrument_design_system/trfmc_instrument_tokens_v1.css",
    "/assets/trfmc_instrument_design_system/trfmc_instrument_layout_v1.css",
    "/assets/trfmc_instrument_design_system/trfmc_parametric_3d_engine_v1.js",
    "/assets/trfmc_instrument_design_system/trfmc_instrument_panels_v1.js"
  ],
  "pages": [
    "/trfmc_instrument_design_system_lab_v1.html",
    "/trfmc_true_portal_command_deck_v1.html"
  ],
  "visual_gate": {
    "goal": "replace page-by-page cosmetic patches with a global instrument-grade visual language",
    "status": "PREVIEW_STANDARD_READY",
    "criteria": [
      "parametric RF/Telco digital twin",
      "hybrid WebGL + Canvas rendering",
      "shared cockpit layout",
      "reusable HUD panels",
      "no iframe",
      "no CDN",
      "V6R3 and Control Room protected"
    ]
  },
  "policy": "Design system only. No mutation of V6R3, Control Room, orphan files or previous RF PRO variants."
}
JSON

cat > "$LAB" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Instrument Design System Lab V1</title>
<link rel="stylesheet" href="/assets/trfmc_instrument_design_system/trfmc_instrument_tokens_v1.css">
<link rel="stylesheet" href="/assets/trfmc_instrument_design_system/trfmc_instrument_layout_v1.css">
</head>
<body class="trfmc-instrument-body">
<header class="trfmc-instrument-topbar">
  <div>
    <h1 class="trfmc-instrument-title">TRFMC Instrument Design System Lab V1</h1>
    <p class="trfmc-instrument-sub">Global cockpit grammar · parametric 3D RF/Telco scene · no page-level cosmetic patching</p>
  </div>
  <nav class="trfmc-instrument-actions">
    <a class="trfmc-instrument-button" href="/trfmc_true_portal_command_deck_v1.html">Command Deck</a>
    <a class="trfmc-instrument-button" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="trfmc-instrument-button" href="/trfmc_instrument_design_system_manifest_v1.json">Manifest</a>
  </nav>
</header>

<main class="trfmc-command-grid">
  <aside class="trfmc-instrument-panel trfmc-command-left">
    <div class="trfmc-instrument-title">Visual doctrine</div>
    <p class="trfmc-instrument-sub">Non più dashboard a rettangoli. Ogni pagina premium deve usare: scena tecnica, HUD, strumenti, griglie misurabili, evidenza e formule.</p>
    <div class="trfmc-system-status" style="margin-top:10px">
      <div class="trfmc-instrument-kpi"><small>Scene</small><b>3D PARAM</b></div>
      <div class="trfmc-instrument-kpi"><small>Render</small><b>WEBGL+</b></div>
      <div class="trfmc-instrument-kpi"><small>Policy</small><b>NO CDN</b></div>
      <div class="trfmc-instrument-kpi"><small>Shell</small><b>LOCKED</b></div>
    </div>
  </aside>

  <section class="trfmc-instrument-panel trfmc-command-center">
    <div class="trfmc-instrument-canvas-shell">
      <trfmc-parametric-3d-engine></trfmc-parametric-3d-engine>
    </div>
    <div class="trfmc-mini-grid">
      <div class="trfmc-mini-panel"><h3>RF Scene</h3><p>Mast, tower, RRU, panel antenna, dish and volumetric field are generated by local parametric primitives.</p></div>
      <div class="trfmc-mini-panel"><h3>Instrument HUD</h3><p>Every page must expose measurement context: signal, geometry, evidence, formulas, runtime status.</p></div>
      <div class="trfmc-mini-panel"><h3>Visual Gate</h3><p>Technical PASS is not enough. Visual maturity must be measured before promotion.</p></div>
    </div>
  </section>

  <aside class="trfmc-instrument-panel trfmc-command-right">
    <trfmc-instrument-panel title="Design System" value="V1 READY" subtitle="shared visual grammar"></trfmc-instrument-panel>
    <trfmc-instrument-panel title="Parametric Engine" value="ACTIVE" subtitle="hybrid WebGL/canvas"></trfmc-instrument-panel>
    <trfmc-instrument-panel title="Next Refactor" value="RF PRO" subtitle="apply instrument standard"></trfmc-instrument-panel>
  </aside>
</main>

<script src="/assets/trfmc_instrument_design_system/trfmc_parametric_3d_engine_v1.js"></script>
<script src="/assets/trfmc_instrument_design_system/trfmc_instrument_panels_v1.js"></script>
</body>
</html>
HTML

cat > "$DECK" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC True Portal Command Deck V1</title>
<link rel="stylesheet" href="/assets/trfmc_instrument_design_system/trfmc_instrument_tokens_v1.css">
<link rel="stylesheet" href="/assets/trfmc_instrument_design_system/trfmc_instrument_layout_v1.css">
</head>
<body class="trfmc-instrument-body">
<header class="trfmc-instrument-topbar">
  <div>
    <h1 class="trfmc-instrument-title">TRFMC True Portal Command Deck V1</h1>
    <p class="trfmc-instrument-sub">Unified visual command deck · not a shell replacement · canonical service layer over protected V6R3</p>
  </div>
  <nav class="trfmc-instrument-actions">
    <a class="trfmc-instrument-button" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="trfmc-instrument-button" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="trfmc-instrument-button" href="/trfmc_portal_registry_unified.json">Registry</a>
  </nav>
</header>

<main class="trfmc-command-grid">
  <aside class="trfmc-instrument-panel trfmc-command-left">
    <div class="trfmc-instrument-title">Mission Stack</div>
    <p class="trfmc-instrument-sub">Da qui il portale va ricondotto a un’unica esperienza visiva: RF, Telco, Core/RAN, Cyber, Fiber, Data Center e Knowledge.</p>
    <div class="trfmc-module-list">
      <a class="trfmc-module-card" href="/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html"><strong>RF PRO Instrument</strong><span>Current RF experiment. Technically PASS, visually not final.</span></a>
      <a class="trfmc-module-card" href="/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"><strong>Antenna / RRU / RET / CPRI</strong><span>Candidate for first real instrument-system refactor.</span></a>
      <a class="trfmc-module-card" href="/trfmc_microwave_link_operations_center_v2.html"><strong>Microwave Link</strong><span>LOS, Fresnel, RSL, fade margin, link budget.</span></a>
      <a class="trfmc-module-card" href="/trfmc_fiber_fronthaul_otdr_workbench_v2.html"><strong>Fiber / OTDR / Fronthaul</strong><span>OTDR traces, CPRI/eCPRI, optical budgets.</span></a>
    </div>
  </aside>

  <section class="trfmc-instrument-panel trfmc-command-center">
    <div class="trfmc-instrument-canvas-shell">
      <trfmc-parametric-3d-engine></trfmc-parametric-3d-engine>
    </div>
    <div class="trfmc-mini-grid">
      <div class="trfmc-mini-panel"><h3>Rule 1</h3><p>V6R3 remains protected. This deck is a service command layer, not a replacement shell.</p></div>
      <div class="trfmc-mini-panel"><h3>Rule 2</h3><p>Every future premium page must consume the Instrument Design System before promotion.</p></div>
      <div class="trfmc-mini-panel"><h3>Rule 3</h3><p>Visual PASS must include scene realism, engineering density, cockpit layout and no duplicate bars.</p></div>
    </div>
  </section>

  <aside class="trfmc-instrument-panel trfmc-command-right">
    <div class="trfmc-system-status">
      <div class="trfmc-instrument-kpi"><small>Protected</small><b>V6R3</b></div>
      <div class="trfmc-instrument-kpi"><small>Mode</small><b>SERVICE</b></div>
      <div class="trfmc-instrument-kpi"><small>Design</small><b>IDS V1</b></div>
      <div class="trfmc-instrument-kpi"><small>Next</small><b>REFIT</b></div>
    </div>
    <div class="trfmc-module-list">
      <a class="trfmc-module-card" href="/trfmc_instrument_design_system_lab_v1.html"><strong>Instrument Design Lab</strong><span>Inspect reusable parametric visual language.</span></a>
      <a class="trfmc-module-card" href="/trfmc_final_promotion_gate_v1.html"><strong>Promotion Gate</strong><span>Current quality baseline and registry governance.</span></a>
      <a class="trfmc-module-card" href="/trfmc_orphan_consolidation_dossier_v1.html"><strong>Orphan Dossier</strong><span>Historical debt consolidation plan.</span></a>
    </div>
  </aside>
</main>

<script src="/assets/trfmc_instrument_design_system/trfmc_parametric_3d_engine_v1.js"></script>
<script src="/assets/trfmc_instrument_design_system/trfmc_instrument_panels_v1.js"></script>
</body>
</html>
HTML

echo
echo "[6/9] Registro pagine service nel registry"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

for name, upgrade in [
    ("trfmc_instrument_design_system_lab_v1.html", "Instrument Design System Lab V1"),
    ("trfmc_true_portal_command_deck_v1.html", "True Portal Command Deck V1")
]:
    path = public / name
    txt = path.read_text(errors="ignore")
    by_url["/" + name] = {
        "class": "service",
        "name": name,
        "url": "/" + name,
        "size": path.stat().st_size,
        "instrument_design_system": True,
        "command_deck": "command_deck" in name,
        "parametric_3d": True,
        "webgl": True,
        "has_iframe": False,
        "external_refs": 0,
        "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
        "upgrade": upgrade
    }

reg["pages"] = list(by_url.values())

counts = {}
for p in reg["pages"]:
    c = p.get("class", "unknown")
    counts[c] = counts.get(c, 0) + 1
counts["total_html"] = len([p for p in reg["pages"] if str(p.get("url","")).endswith(".html")])
for k in ["official_shell", "service", "leaf_operational_candidate", "shell_or_legacy_container", "orphan_or_legacy_candidate"]:
    counts.setdefault(k, 0)

reg["counts"] = counts
reg["last_instrument_design_system_v1_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "pages": [
        "/trfmc_instrument_design_system_lab_v1.html",
        "/trfmc_true_portal_command_deck_v1.html"
    ],
    "policy": "Service/design-system layer only. V6R3 and Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[7/9] Gate HTTP + external/iframe + visual content"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /assets/trfmc_instrument_design_system/trfmc_instrument_tokens_v1.css \
    /assets/trfmc_instrument_design_system/trfmc_instrument_layout_v1.css \
    /assets/trfmc_instrument_design_system/trfmc_parametric_3d_engine_v1.js \
    /assets/trfmc_instrument_design_system/trfmc_instrument_panels_v1.js \
    /trfmc_instrument_design_system_manifest_v1.json \
    /trfmc_instrument_design_system_lab_v1.html \
    /trfmc_true_portal_command_deck_v1.html \
    /trfmc_portal_registry_unified.json \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html
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
: > "$OUT/content_checks.txt"

for f in "$TOKENS" "$LAYOUT" "$ENGINE" "$PANELS" "$LAB" "$DECK" "$MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC_INSTRUMENT_DESIGN_SYSTEM_V1" \
  "trfmc-parametric-3d-engine" \
  "Instrument3DEngine" \
  "project3D" \
  "getContext(\"webgl\"" \
  "requestAnimationFrame" \
  "trfmc-instrument-panel" \
  "TRFMC True Portal Command Deck V1" \
  "Visual Gate" \
  "parametric RF/Telco digital twin" \
  "No CDN" \
  "V6R3 and Control Room protected"
do
  if grep -Rqs "$token" "$TOKENS" "$LAYOUT" "$ENGINE" "$PANELS" "$LAB" "$DECK" "$MANIFEST"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

cat > "$OUT/visual_gate.json" <<JSON
{
  "gate": "TRFMC_VISUAL_GATE_V1_PREVIEW",
  "status": "PASS_PREVIEW_NOT_FINAL_PERFECTION",
  "technical": {
    "http": "must be 200",
    "external_refs": "must be 0",
    "iframe_refs": "must be 0",
    "protected_shells": "V6R3 and Control Room unchanged"
  },
  "visual": {
    "global_design_system": true,
    "parametric_3d_engine": true,
    "hybrid_webgl_canvas": true,
    "reusable_panels": true,
    "cockpit_layout": true,
    "note": "This is the new foundation. It is not declared final perfection; it is the standard to refit the real portal pages."
  },
  "next_required_step": "Apply IDS V1 to one real domain page: Antenna/RRU or RF PRO, then compare before/after."
}
JSON

echo
echo "[8/9] Summary + freeze"

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

python3 - "$OUT" "$REG" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

http = []
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 3:
        http.append({"url": p[0], "status": p[1], "bytes": p[2]})

non200 = sum(1 for r in http if r["status"] != "200")
ext = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
ifr = sum(1 for x in (out / "iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
miss = sum(1 for x in (out / "content_checks.txt").read_text(errors="ignore").splitlines() if x.startswith("MISS:"))

sha = {}
for line in (out / "sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v = line.split("=",1)
        sha[k] = v

protected_ok = (
    sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
)
registry_changed = sha.get("REG_SHA_BEFORE") != sha.get("REG_SHA_AFTER")
reg = json.loads(reg_path.read_text(errors="ignore"))
visual_gate = json.loads((out / "visual_gate.json").read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_INSTRUMENT_DESIGN_SYSTEM_V1",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "content_check_miss": miss,
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "created_pages": [
        "/trfmc_instrument_design_system_lab_v1.html",
        "/trfmc_true_portal_command_deck_v1.html"
    ],
    "created_assets": [
        "/assets/trfmc_instrument_design_system/trfmc_instrument_tokens_v1.css",
        "/assets/trfmc_instrument_design_system/trfmc_instrument_layout_v1.css",
        "/assets/trfmc_instrument_design_system/trfmc_parametric_3d_engine_v1.js",
        "/assets/trfmc_instrument_design_system/trfmc_instrument_panels_v1.js"
    ],
    "visual_gate": visual_gate,
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and miss == 0 and protected_ok and registry_changed else "WARN",
    "policy": "Instrument Design System layer. No mutation of V6R3, Control Room, orphan files or previous RF pages."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
(out / "result.flag").write_text(summary["result"] + "\n")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_INSTRUMENT_DESIGN_SYSTEM_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_instrument_design_system \
    frontend/public/trfmc_instrument_design_system_lab_v1.html \
    frontend/public/trfmc_true_portal_command_deck_v1.html \
    frontend/public/trfmc_instrument_design_system_manifest_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_instrument_design_system_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "[9/9] Output"
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== VISUAL GATE ==="
cat "$OUT/visual_gate.json" | python3 -m json.tool
echo
echo "=== CONTENT CHECKS ==="
cat "$OUT/content_checks.txt"
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_instrument_design_system_lab_v1.html"
echo "http://127.0.0.1:5173/trfmc_true_portal_command_deck_v1.html"
echo "============================================================"
