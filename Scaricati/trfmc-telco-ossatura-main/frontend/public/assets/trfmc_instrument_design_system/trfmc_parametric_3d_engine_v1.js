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
