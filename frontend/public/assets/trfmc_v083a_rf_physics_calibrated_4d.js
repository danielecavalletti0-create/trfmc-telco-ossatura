(function(){
  const $ = (s) => document.querySelector(s);
  let gl, program, raf, paused=false, t0=performance.now();

  const vertexSrc = `
    attribute vec2 a_position;
    varying vec2 v_uv;
    void main(){
      v_uv = a_position * 0.5 + 0.5;
      gl_Position = vec4(a_position, 0.0, 1.0);
    }
  `;

  const fragmentSrc = `
    precision highp float;
    varying vec2 v_uv;

    uniform vec2 u_res;
    uniform float u_time;
    uniform float u_freqMHz;
    uniform float u_eirp;
    uniform float u_pathN;
    uniform float u_vegDepth;
    uniform float u_shadowDb;
    uniform float u_sectorGainDb;
    uniform float u_fadingDb;

    float log10(float x){ return log(max(x, 0.000001)) / log(10.0); }

    float fspl1m(float fMHz){
      return 32.44 + 20.0 * log10(fMHz) + 20.0 * log10(0.001);
    }

    float pathLoss(float fMHz, float d_m, float n){
      float d0 = 1.0;
      return fspl1m(fMHz) + 10.0 * n * log10(max(d_m, d0) / d0);
    }

    float hash(vec2 p){
      p = fract(p * vec2(123.34,345.45));
      p += dot(p, p + 34.345);
      return fract(p.x * p.y);
    }

    float noise(vec2 p){
      vec2 i = floor(p);
      vec2 f = fract(p);
      float a = hash(i);
      float b = hash(i + vec2(1.0,0.0));
      float c = hash(i + vec2(0.0,1.0));
      float d = hash(i + vec2(1.0,1.0));
      vec2 u = f*f*(3.0-2.0*f);
      return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
    }

    float sectorGain(vec2 p, vec2 s, float angle, float width, float gainDb){
      vec2 v = normalize(p - s);
      float a = atan(v.y, v.x);
      float diff = abs(atan(sin(a-angle), cos(a-angle)));
      return gainDb * smoothstep(width, 0.0, diff);
    }

    float boxMask(vec2 uv, vec2 c, vec2 size){
      vec2 q = abs(uv - c) - size;
      float outside = length(max(q,0.0));
      float inside = min(max(q.x,q.y),0.0);
      return smoothstep(0.050,0.0,outside + inside);
    }

    float buildingShadow(vec2 uv){
      float s = 0.0;
      s += boxMask(uv, vec2(0.35,0.56), vec2(0.055,0.145));
      s += boxMask(uv, vec2(0.58,0.59), vec2(0.070,0.125));
      s += boxMask(uv, vec2(0.72,0.37), vec2(0.055,0.090));
      s += boxMask(uv, vec2(0.84,0.56), vec2(0.048,0.135));
      s += boxMask(uv, vec2(0.51,0.23), vec2(0.060,0.085));
      return clamp(s,0.0,1.0);
    }

    float foliageMask(vec2 uv){
      float n = noise(uv*7.0 + vec2(0.0, u_time*0.025));
      float clusters = smoothstep(0.46,0.90,n);
      float corridor = smoothstep(0.18,0.0,abs(uv.y - (0.32 + 0.16*sin(uv.x*5.5))));
      return clamp(clusters*0.70 + corridor*0.45,0.0,1.0);
    }

    float foliageLoss(float fMHz, float depth_m, float density){
      float fGHz = fMHz / 1000.0;
      float K = 0.42;
      return K * pow(max(fGHz,0.1),0.30) * pow(max(depth_m,0.0),0.60) * density;
    }

    vec3 palette(float rsrp){
      float x = clamp((rsrp + 118.0) / 50.0, 0.0, 1.0);
      vec3 outage = vec3(0.005,0.010,0.030);
      vec3 weak = vec3(0.030,0.150,0.420);
      vec3 edge = vec3(0.000,0.650,0.780);
      vec3 good = vec3(0.150,0.900,0.360);
      vec3 margin = vec3(0.930,0.780,0.160);
      vec3 hot = vec3(0.930,0.090,0.160);

      if(x < 0.18) return mix(outage, weak, x/0.18);
      if(x < 0.38) return mix(weak, edge, (x-0.18)/0.20);
      if(x < 0.58) return mix(edge, good, (x-0.38)/0.20);
      if(x < 0.78) return mix(good, margin, (x-0.58)/0.20);
      return mix(margin, hot, (x-0.78)/0.22);
    }

    float contour(float value, float level){
      return 1.0 - smoothstep(0.0,0.75,abs(value-level));
    }

    void main(){
      vec2 uv = v_uv;
      vec2 p = uv;
      p.x *= u_res.x / u_res.y;

      vec2 sA = vec2(0.18,0.30);
      vec2 sB = vec2(0.72,0.70);
      vec2 sC = vec2(1.22,0.34);

      float scaleMeters = 720.0;
      float dA = distance(p,sA) * scaleMeters + 8.0;
      float dB = distance(p,sB) * scaleMeters + 8.0;
      float dC = distance(p,sC) * scaleMeters + 8.0;

      float sh = buildingShadow(uv);
      float fol = foliageMask(uv);

      float Lveg = foliageLoss(u_freqMHz, u_vegDepth, fol);
      float Lshadow = u_shadowDb * sh;

      float fade = (noise(p*19.0 + u_time*0.08) - 0.5) * 2.0 * u_fadingDb;

      float gA = sectorGain(p,sA,-0.10,0.74,u_sectorGainDb);
      float gB = sectorGain(p,sB,-2.55,0.68,u_sectorGainDb);
      float gC = sectorGain(p,sC,3.08,0.74,u_sectorGainDb);

      float prA = u_eirp + gA - pathLoss(u_freqMHz,dA,u_pathN) - Lveg - Lshadow + fade;
      float prB = u_eirp + gB - pathLoss(u_freqMHz,dB,u_pathN) - Lveg - Lshadow + fade;
      float prC = u_eirp + gC - pathLoss(u_freqMHz,dC,u_pathN) - Lveg - Lshadow + fade;

      float rsrp = max(max(prA,prB),prC);
      vec3 col = palette(rsrp);

      col += contour(rsrp,-110.0) * vec3(0.00,0.18,0.32);
      col += contour(rsrp,-100.0) * vec3(0.00,0.34,0.36);
      col += contour(rsrp,-90.0)  * vec3(0.20,0.30,0.05);
      col += contour(rsrp,-80.0)  * vec3(0.32,0.05,0.05);

      col = mix(col, vec3(0.0,0.01,0.035), sh*0.35);
      col = mix(col, vec3(0.02,0.18,0.09), fol*0.12);

      float grid = 0.0;
      grid += smoothstep(0.010,0.0,abs(fract(uv.x*34.0)-0.5));
      grid += smoothstep(0.010,0.0,abs(fract(uv.y*24.0)-0.5));
      col += grid * vec3(0.014,0.065,0.080);

      float vignette = smoothstep(0.96,0.24,distance(uv,vec2(0.5,0.52)));
      col *= 0.62 + 0.50*vignette;

      gl_FragColor = vec4(col,1.0);
    }
  `;

  function compile(type, src){
    const sh = gl.createShader(type);
    gl.shaderSource(sh, src);
    gl.compileShader(sh);
    if(!gl.getShaderParameter(sh, gl.COMPILE_STATUS)){
      throw new Error(gl.getShaderInfoLog(sh));
    }
    return sh;
  }

  function link(){
    const vs = compile(gl.VERTEX_SHADER, vertexSrc);
    const fs = compile(gl.FRAGMENT_SHADER, fragmentSrc);
    const p = gl.createProgram();
    gl.attachShader(p, vs);
    gl.attachShader(p, fs);
    gl.linkProgram(p);
    if(!gl.getProgramParameter(p, gl.LINK_STATUS)){
      throw new Error(gl.getProgramInfoLog(p));
    }
    return p;
  }

  function resize(){
    const c = $("#rfCanvas");
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.floor(c.clientWidth * dpr);
    const h = Math.floor(c.clientHeight * dpr);
    if(c.width !== w || c.height !== h){
      c.width = w;
      c.height = h;
      gl.viewport(0,0,w,h);
    }
  }

  function num(id){ return Number($(id).value); }
  function log10(x){ return Math.log10(Math.max(x, 1e-9)); }

  function fsplMHzKm(fMHz, dKm){
    return 32.44 + 20*log10(fMHz) + 20*log10(dKm);
  }

  function fspl1m(fMHz){
    return 32.44 + 20*log10(fMHz) + 20*log10(0.001);
  }

  function pathLoss(fMHz, dM, n){
    return fspl1m(fMHz) + 10*n*log10(Math.max(dM,1));
  }

  function foliageLoss(fMHz, dVeg, density){
    const fGHz = fMHz / 1000;
    return 0.42 * Math.pow(Math.max(fGHz,0.1),0.30) * Math.pow(Math.max(dVeg,0),0.60) * density;
  }

  function updateLabels(){
    const fMHz = num("#freqMHz");
    const eirp = num("#eirp");
    const n = num("#pathN") / 10;
    const veg = num("#vegDepth");
    const shadow = num("#shadowDb");
    const gain = num("#sectorGain") / 10;
    const fade = num("#fading") / 10;

    $("#freqMHzVal").textContent = fMHz + " MHz";
    $("#eirpVal").textContent = eirp + " dBm";
    $("#pathNVal").textContent = n.toFixed(1);
    $("#vegDepthVal").textContent = veg + " m";
    $("#shadowDbVal").textContent = shadow + " dB";
    $("#sectorGainVal").textContent = gain.toFixed(1) + " dB";
    $("#fadingVal").textContent = fade.toFixed(1) + " dB";

    const probeD = 180;
    const fspl = fsplMHzKm(fMHz, probeD/1000);
    const pl = pathLoss(fMHz, probeD, n);
    const lveg = foliageLoss(fMHz, veg, 0.68);
    const prx = eirp + gain - pl - lveg - shadow*0.45 - fade*0.30;
    const rival = prx - (6 + shadow*0.15);
    const sinr = Math.max(-8, Math.min(34, prx - rival - 4.5));
    const totalLoss = pl + lveg + shadow*0.45 + fade*0.30;
    const coverage = Math.max(0, Math.min(100, Math.round((prx + 118) * 2.0 + sinr * 1.2)));

    let cell = "SITE-B";
    if(prx < -96 && shadow > 18) cell = "SITE-C";
    if(gain > 8 && shadow < 10) cell = "SITE-A/B";

    $("#rsrpVal").textContent = prx.toFixed(1) + " dBm";
    $("#sinrVal").textContent = sinr.toFixed(1) + " dB";
    $("#lossVal").textContent = totalLoss.toFixed(1) + " dB";
    $("#coverageVal").textContent = coverage + "%";
    $("#cellVal").textContent = cell;
    $("#physicsScore").textContent = coverage + "%";

    $("#fsplLive").textContent = "d=180 m, f=" + fMHz + " MHz → FSPL≈" + fspl.toFixed(1) + " dB.";
    $("#plLive").textContent = "n=" + n.toFixed(1) + ", d=180 m → PL≈" + pl.toFixed(1) + " dB.";
    $("#vegLive").textContent = "dveg=" + veg + " m, density=0.68 → Lveg≈" + lveg.toFixed(1) + " dB.";
    $("#prxLive").textContent = "EIRP=" + eirp + " dBm, Gsector=" + gain.toFixed(1) + " dB → Prx≈" + prx.toFixed(1) + " dBm.";

    $("#captionText").textContent =
      "f=" + fMHz + " MHz · EIRP=" + eirp + " dBm · n=" + n.toFixed(1) +
      " · Lveg=" + lveg.toFixed(1) + " dB · shadow=" + shadow + " dB";

    $("#copilot").innerHTML =
      "<b>AI RF Copilot</b><p>Physics model refreshed. RSRP=" +
      prx.toFixed(1) + " dBm, SINR=" + sinr.toFixed(1) +
      " dB, total loss=" + totalLoss.toFixed(1) +
      " dB, dominant cell=" + cell + ".</p>";
  }

  function uniforms(now){
    gl.uniform2f(gl.getUniformLocation(program,"u_res"), $("#rfCanvas").width, $("#rfCanvas").height);
    gl.uniform1f(gl.getUniformLocation(program,"u_time"), (now - t0)/1000);
    gl.uniform1f(gl.getUniformLocation(program,"u_freqMHz"), num("#freqMHz"));
    gl.uniform1f(gl.getUniformLocation(program,"u_eirp"), num("#eirp"));
    gl.uniform1f(gl.getUniformLocation(program,"u_pathN"), num("#pathN")/10);
    gl.uniform1f(gl.getUniformLocation(program,"u_vegDepth"), num("#vegDepth"));
    gl.uniform1f(gl.getUniformLocation(program,"u_shadowDb"), num("#shadowDb"));
    gl.uniform1f(gl.getUniformLocation(program,"u_sectorGainDb"), num("#sectorGain")/10);
    gl.uniform1f(gl.getUniformLocation(program,"u_fadingDb"), num("#fading")/10);
  }

  function render(now){
    if(!paused){
      resize();
      gl.useProgram(program);
      uniforms(now);
      gl.drawArrays(gl.TRIANGLES,0,6);
    }
    raf = requestAnimationFrame(render);
  }

  function preset(values){
    Object.entries(values).forEach(([id,value]) => {
      const el = $("#" + id);
      if(el){
        el.value = value;
        el.dispatchEvent(new Event("input",{bubbles:true}));
      }
    });
  }

  function init(){
    const c = $("#rfCanvas");
    gl = c.getContext("webgl",{antialias:true,alpha:false,powerPreference:"high-performance"})
      || c.getContext("experimental-webgl");

    if(!gl){
      document.body.classList.add("no-webgl");
      $("#webglBadge").textContent = "NO WEBGL";
      $("#rendererVal").textContent = "fallback";
      return;
    }

    $("#webglBadge").textContent = "WEBGL OK";
    $("#rendererVal").textContent = "WebGL";

    program = link();
    gl.useProgram(program);

    const vertices = new Float32Array([
      -1,-1, 1,-1, -1,1,
      -1,1, 1,-1, 1,1
    ]);

    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

    const loc = gl.getAttribLocation(program,"a_position");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);

    ["#freqMHz","#eirp","#pathN","#vegDepth","#shadowDb","#sectorGain","#fading"].forEach(id => {
      $(id).addEventListener("input", updateLabels);
    });

    $("#pauseBtn").addEventListener("click", () => {
      paused = !paused;
      $("#pauseBtn").textContent = paused ? "Resume" : "Pause";
    });

    $("#baselineBtn").addEventListener("click", () => preset({
      freqMHz:3500,eirp:46,pathN:32,vegDepth:20,shadowDb:8,sectorGain:72,fading:18
    }));

    $("#urbanBtn").addEventListener("click", () => preset({
      freqMHz:3500,eirp:46,pathN:38,vegDepth:18,shadowDb:24,sectorGain:58,fading:32
    }));

    $("#foliageBtn").addEventListener("click", () => preset({
      freqMHz:3500,eirp:46,pathN:33,vegDepth:62,shadowDb:12,sectorGain:62,fading:38
    }));

    $("#recoveryBtn").addEventListener("click", () => preset({
      freqMHz:3500,eirp:48,pathN:31,vegDepth:28,shadowDb:11,sectorGain:92,fading:18
    }));

    window.addEventListener("resize", resize);
    updateLabels();
    raf = requestAnimationFrame(render);
  }

  document.addEventListener("DOMContentLoaded", init);
})();
