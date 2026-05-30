/*
 TRFMC GPU Visual Runtime V2
 WebGL shader background + plugin registry + WebGPU capability probe.
 Safe mode: only decorative global runtime. No navbar, no iframe, no network.
*/
(function(){
  "use strict";

  const RUNTIME_ID = "TRFMC_GPU_VISUAL_RUNTIME_V2";
  const DISABLE_KEY = "TRFMC_GPU_RUNTIME";
  const PERF_KEY = "TRFMC_GPU_PERF";

  if (window.localStorage && localStorage.getItem(DISABLE_KEY) === "off") return;

  const plugins = [
    {id:"rf_interference_field", type:"shader", status:"active"},
    {id:"spectral_grid_depth", type:"shader", status:"active"},
    {id:"instrument_glass_hud", type:"css", status:"active"},
    {id:"panel_depth_lighting", type:"css", status:"active"},
    {id:"webgpu_capability_probe", type:"probe", status:"passive"},
    {id:"reduced_motion_guard", type:"safety", status:"active"}
  ];

  function createCanvas(){
    const canvas = document.createElement("canvas");
    canvas.className = "trfmc-gpu-layer";
    canvas.setAttribute("aria-hidden", "true");
    document.body.prepend(canvas);
    return canvas;
  }

  function createFallback(){
    const div = document.createElement("div");
    div.className = "trfmc-gpu-fallback";
    div.setAttribute("aria-hidden", "true");
    document.body.prepend(div);
    return div;
  }

  function createHud(state){
    if (localStorage.getItem(PERF_KEY) === "quiet") return;
    const hud = document.createElement("div");
    hud.className = "trfmc-gpu-hud";
    hud.innerHTML =
      "<b>GPU RUNTIME</b> " + state.mode +
      "<br>WebGPU: <b>" + (state.webgpu ? "available" : "not exposed") + "</b>" +
      "<br>Plugins: <b>" + plugins.length + "</b>";
    document.body.appendChild(hud);
  }

  function shader(gl, type, source){
    const s = gl.createShader(type);
    gl.shaderSource(s, source);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      throw new Error(gl.getShaderInfoLog(s) || "shader compile error");
    }
    return s;
  }

  function program(gl, vs, fs){
    const p = gl.createProgram();
    gl.attachShader(p, shader(gl, gl.VERTEX_SHADER, vs));
    gl.attachShader(p, shader(gl, gl.FRAGMENT_SHADER, fs));
    gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
      throw new Error(gl.getProgramInfoLog(p) || "program link error");
    }
    return p;
  }

  function initWebGL(canvas){
    const gl =
      canvas.getContext("webgl2", {alpha:true, antialias:false, depth:false, stencil:false, powerPreference:"high-performance"}) ||
      canvas.getContext("webgl",  {alpha:true, antialias:false, depth:false, stencil:false});

    if (!gl) return null;

    const vertex = `
      attribute vec2 p;
      varying vec2 v;
      void main(){
        v = p;
        gl_Position = vec4(p, 0.0, 1.0);
      }
    `;

    const fragment = `
      precision mediump float;
      varying vec2 v;
      uniform float t;
      uniform vec2 r;
      uniform vec2 m;
      uniform float power;

      float hash(vec2 p){
        p = fract(p * vec2(123.34, 345.45));
        p += dot(p, p + 34.345);
        return fract(p.x * p.y);
      }

      float wave(vec2 p, vec2 c, float f, float s){
        float d = length(p - c);
        return sin(d * f - t * s) / (1.0 + d * 7.5);
      }

      float beam(vec2 p, vec2 a, vec2 b){
        vec2 pa = p - a;
        vec2 ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        return length(pa - ba * h);
      }

      void main(){
        vec2 uv = (v + 1.0) * 0.5;
        vec2 p = uv * 2.0 - 1.0;
        p.x *= r.x / r.y;

        vec2 mouse = (m * 2.0 - 1.0);
        mouse.x *= r.x / r.y;

        float e = 0.0;
        e += wave(p, vec2(-0.70, -0.28), 28.0, 2.2);
        e += wave(p, vec2( 0.64,  0.18), 31.0, 2.8);
        e += wave(p, mouse * 0.72,       36.0, 3.1);

        float rayA = beam(p, vec2(-0.92, 0.20), vec2(0.92, -0.20));
        float rayB = beam(p, vec2(-0.72,-0.55), vec2(0.80,  0.35));
        float rays = 0.010 / (rayA + 0.018) + 0.008 / (rayB + 0.022);

        float grid =
          step(0.988, fract(uv.x * 34.0)) * 0.10 +
          step(0.988, fract(uv.y * 22.0)) * 0.08;

        float rings = abs(sin(22.0 * length(p - mouse * 0.18) - t * 1.7));
        rings = 0.045 / (abs(rings - 0.72) + 0.18);

        float n = hash(uv + t * 0.015) * 0.025;
        float vignette = smoothstep(1.45, 0.18, length(p));

        vec3 base = vec3(0.002, 0.014, 0.026);
        vec3 cyan = vec3(0.00, 0.72, 1.00);
        vec3 green = vec3(0.35, 1.00, 0.22);
        vec3 gold = vec3(1.00, 0.78, 0.22);
        vec3 blue = vec3(0.12, 0.25, 1.00);

        vec3 col = base;
        col += cyan * abs(e) * 0.155 * power;
        col += cyan * rays * 0.118 * power;
        col += blue * rings * 0.180 * power;
        col += green * grid * 0.120 * power;
        col += gold * n;

        col *= vignette;
        gl_FragColor = vec4(col, 0.92);
      }
    `;

    const prg = program(gl, vertex, fragment);
    gl.useProgram(prg);

    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, 1,1]), gl.STATIC_DRAW);

    const loc = gl.getAttribLocation(prg, "p");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    const ut = gl.getUniformLocation(prg, "t");
    const ur = gl.getUniformLocation(prg, "r");
    const um = gl.getUniformLocation(prg, "m");
    const up = gl.getUniformLocation(prg, "power");

    let mx = 0.50, my = 0.45, tx = mx, ty = my;
    window.addEventListener("pointermove", function(ev){
      tx = ev.clientX / Math.max(1, innerWidth);
      ty = 1.0 - ev.clientY / Math.max(1, innerHeight);
      document.documentElement.style.setProperty("--trfmc-gpu-x", (tx * 100).toFixed(2) + "%");
      document.documentElement.style.setProperty("--trfmc-gpu-y", ((1.0 - ty) * 100).toFixed(2) + "%");
    }, {passive:true});

    function resize(){
      const dpr = Math.min(2, window.devicePixelRatio || 1);
      const w = Math.max(2, Math.floor(canvas.clientWidth * dpr));
      const h = Math.max(2, Math.floor(canvas.clientHeight * dpr));
      if (canvas.width !== w || canvas.height !== h){
        canvas.width = w;
        canvas.height = h;
        gl.viewport(0,0,w,h);
      }
    }

    function frame(ms){
      resize();
      mx += (tx - mx) * 0.045;
      my += (ty - my) * 0.045;
      gl.uniform1f(ut, ms * 0.001);
      gl.uniform2f(ur, canvas.width, canvas.height);
      gl.uniform2f(um, mx, my);
      gl.uniform1f(up, parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--trfmc-gpu-power")) || 0.68);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      requestAnimationFrame(frame);
    }

    requestAnimationFrame(frame);
    return gl;
  }

  function boot(){
    document.body.classList.add("trfmc-gpu-v2");

    const reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const state = {
      id: RUNTIME_ID,
      plugins: plugins,
      webgpu: !!navigator.gpu,
      mode: "fallback",
      createdAt: new Date().toISOString()
    };

    if (!reduce){
      const canvas = createCanvas();
      try {
        const gl = initWebGL(canvas);
        if (gl){
          state.mode = gl instanceof WebGL2RenderingContext ? "webgl2" : "webgl1";
        } else {
          canvas.remove();
          createFallback();
          state.mode = "css-fallback";
        }
      } catch(e){
        canvas.remove();
        createFallback();
        state.mode = "css-fallback";
        state.error = String(e && e.message ? e.message : e);
      }
    } else {
      createFallback();
      state.mode = "reduced-motion";
    }

    document.body.dataset.trfmcGpuRuntime = state.mode;
    window.TRFMC_GPU_RUNTIME = state;
    createHud(state);
  }

  if (document.readyState === "loading"){
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
