(function(){
  const canvas = () => document.getElementById("rfCanvas");
  const qs = (s) => document.querySelector(s);

  let gl, program, raf, paused = false, t0 = performance.now();
  let scenarioShift = 0.0;

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

    uniform float u_time;
    uniform float u_freq;
    uniform float u_veg;
    uniform float u_shadow;
    uniform float u_noise;
    uniform float u_beam;
    uniform float u_shift;
    uniform vec2 u_resolution;

    float hash(vec2 p){
      p = fract(p * vec2(123.34, 345.45));
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

    float siteField(vec2 p, vec2 s, float power){
      float d = distance(p, s);
      return power / (0.070 + d*d*5.4);
    }

    float sectorGain(vec2 p, vec2 s, float angle, float width){
      vec2 v = normalize(p - s);
      float a = atan(v.y, v.x);
      float diff = abs(atan(sin(a-angle), cos(a-angle)));
      return smoothstep(width, 0.0, diff);
    }

    float rectShadow(vec2 uv, vec2 c, vec2 size){
      vec2 q = abs(uv - c) - size;
      float outside = length(max(q,0.0));
      float inside = min(max(q.x,q.y),0.0);
      return smoothstep(0.050, 0.0, outside + inside);
    }

    vec3 rfPalette(float x){
      x = clamp(x,0.0,1.0);
      vec3 deep = vec3(0.010,0.025,0.070);
      vec3 navy = vec3(0.020,0.105,0.220);
      vec3 blue = vec3(0.020,0.320,0.660);
      vec3 cyan = vec3(0.000,0.780,0.800);
      vec3 green = vec3(0.120,0.920,0.350);
      vec3 yellow = vec3(0.900,0.780,0.160);
      vec3 red = vec3(0.920,0.080,0.170);

      if(x < 0.18) return mix(deep, navy, x/0.18);
      if(x < 0.34) return mix(navy, blue, (x-0.18)/0.16);
      if(x < 0.52) return mix(blue, cyan, (x-0.34)/0.18);
      if(x < 0.70) return mix(cyan, green, (x-0.52)/0.18);
      if(x < 0.88) return mix(green, yellow, (x-0.70)/0.18);
      return mix(yellow, red, (x-0.88)/0.12);
    }

    float contour(float x, float level){
      return 1.0 - smoothstep(0.0, 0.012, abs(x-level));
    }

    void main(){
      vec2 uv = v_uv;
      vec2 p = uv;
      p.x *= u_resolution.x / u_resolution.y;

      vec2 sA = vec2(0.19,0.29);
      vec2 sB = vec2(0.72,0.70);
      vec2 sC = vec2(1.22,0.33);

      float aGain = mix(0.72, 1.18, sectorGain(p, sA, -0.14, 0.74) * u_beam);
      float bGain = mix(0.70, 1.13, sectorGain(p, sB, -2.55, 0.68) * u_beam);
      float cGain = mix(0.70, 1.10, sectorGain(p, sC, 3.08, 0.74) * u_beam);

      float fA = siteField(p, sA, 0.82) * aGain;
      float fB = siteField(p, sB, 0.76) * bGain;
      float fC = siteField(p, sC, 0.70) * cGain;

      float field = max(max(fA, fB), fC);
      float sumField = fA + fB + fC;

      float dominance = field / max(sumField, 0.0001);

      float vegNoise = noise(p*6.3 + vec2(u_shift, u_time*0.025));
      float foliage = smoothstep(0.38,0.92,vegNoise) * u_veg;

      float sh = 0.0;
      sh += rectShadow(v_uv, vec2(0.36,0.56), vec2(0.070,0.18));
      sh += rectShadow(v_uv, vec2(0.58,0.58), vec2(0.095,0.14));
      sh += rectShadow(v_uv, vec2(0.71,0.35), vec2(0.070,0.105));
      sh += rectShadow(v_uv, vec2(0.83,0.56), vec2(0.065,0.16));
      sh += rectShadow(v_uv, vec2(0.66,0.25), vec2(0.055,0.075));
      sh = clamp(sh,0.0,1.0) * u_shadow;

      float freqPenalty = mix(0.86, 1.28, u_freq);
      float fade = (noise(p*24.0 + u_time*0.045 + u_shift) - 0.5) * u_noise * 0.30;

      float signal = field / freqPenalty;
      signal = signal * 0.42 + 0.24;
      signal -= foliage * 0.22;
      signal -= sh * 0.36;
      signal += fade;
      signal = clamp(signal, 0.0, 1.0);

      vec3 col = rfPalette(signal);

      float c1 = contour(signal,0.32);
      float c2 = contour(signal,0.48);
      float c3 = contour(signal,0.66);
      float c4 = contour(signal,0.82);

      col += c1 * vec3(0.05,0.20,0.35);
      col += c2 * vec3(0.05,0.35,0.30);
      col += c3 * vec3(0.25,0.25,0.05);
      col += c4 * vec3(0.36,0.06,0.08);

      col = mix(col, vec3(0.010,0.020,0.050), sh*0.42);
      col = mix(col, vec3(0.75,0.95,1.0), dominance*0.045);

      float grid = 0.0;
      grid += smoothstep(0.010,0.0,abs(fract(v_uv.x*34.0)-0.5));
      grid += smoothstep(0.010,0.0,abs(fract(v_uv.y*24.0)-0.5));
      col += grid * vec3(0.015,0.075,0.085);

      float vignette = smoothstep(0.98,0.25,distance(v_uv,vec2(0.5,0.52)));
      col *= 0.60 + 0.50*vignette;

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
    const prg = gl.createProgram();
    gl.attachShader(prg, vs);
    gl.attachShader(prg, fs);
    gl.linkProgram(prg);
    if(!gl.getProgramParameter(prg, gl.LINK_STATUS)){
      throw new Error(gl.getProgramInfoLog(prg));
    }
    return prg;
  }

  function resize(){
    const c = canvas();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.floor(c.clientWidth * dpr);
    const h = Math.floor(c.clientHeight * dpr);
    if(c.width !== w || c.height !== h){
      c.width = w;
      c.height = h;
      gl.viewport(0,0,w,h);
    }
  }

  function val(id){ return Number(qs(id).value) / 100; }

  function freqLabel(v){
    if(v <= .30) return "700 MHz · low-band";
    if(v <= .70) return "3.5 GHz · C-band";
    return "28 GHz · mmWave";
  }

  function riskFrom(loss, cov){
    if(loss > 25 || cov < 35) return "CRITICAL";
    if(loss > 18 || cov < 55) return "HIGH";
    if(loss > 11 || cov < 75) return "MEDIUM";
    return "LOW";
  }

  function updateUI(){
    const f = val("#freq");
    const veg = val("#veg");
    const shadow = val("#shadow");
    const noise = val("#noise");
    const beam = val("#beam");

    qs("#freqVal").textContent = freqLabel(f);
    qs("#vegVal").textContent = veg.toFixed(2);
    qs("#shadowVal").textContent = shadow.toFixed(2);
    qs("#noiseVal").textContent = noise.toFixed(2);
    qs("#beamVal").textContent = beam.toFixed(2);

    const loss = 4.0 + veg*10.5 + shadow*8.5 + f*5.5 + noise*3.5 - beam*2.0;
    const cov = Math.max(0, Math.min(100, Math.round(96 - loss*2.05 - shadow*9 + beam*6)));
    const risk = riskFrom(loss, cov);

    const dom = cov > 78 ? "SITE-A/B balanced" : cov > 55 ? "SITE-B edge" : "SITE-C degraded";

    qs("#lossVal").textContent = loss.toFixed(1) + " dB";
    qs("#coverageVal").textContent = cov + "%";
    qs("#riskVal").textContent = risk;
    qs("#dominantVal").textContent = dom;
    qs("#gpuScore").textContent = cov + "%";
    qs("#gpuMode").textContent = "calibrated shader field";
    qs("#captionText").textContent = freqLabel(f) + " · veg=" + veg.toFixed(2) + " · shadow=" + shadow.toFixed(2) + " · beam=" + beam.toFixed(2);
    qs("#eventBus").innerHTML =
      "<b>AI RF Copilot</b><p>Calibrated RF field refreshed. Loss=" +
      loss.toFixed(1) + " dB, coverage=" + cov + "%, risk=" + risk +
      ", dominance=" + dom + ".</p>";
  }

  function render(now){
    if(paused){
      raf = requestAnimationFrame(render);
      return;
    }

    resize();
    gl.useProgram(program);

    gl.uniform1f(gl.getUniformLocation(program, "u_time"), (now - t0)/1000);
    gl.uniform1f(gl.getUniformLocation(program, "u_freq"), val("#freq"));
    gl.uniform1f(gl.getUniformLocation(program, "u_veg"), val("#veg"));
    gl.uniform1f(gl.getUniformLocation(program, "u_shadow"), val("#shadow"));
    gl.uniform1f(gl.getUniformLocation(program, "u_noise"), val("#noise"));
    gl.uniform1f(gl.getUniformLocation(program, "u_beam"), val("#beam"));
    gl.uniform1f(gl.getUniformLocation(program, "u_shift"), scenarioShift);
    gl.uniform2f(gl.getUniformLocation(program, "u_resolution"), canvas().width, canvas().height);

    gl.drawArrays(gl.TRIANGLES, 0, 6);
    raf = requestAnimationFrame(render);
  }

  function init(){
    const c = canvas();
    gl = c.getContext("webgl", { antialias: true, alpha: false, powerPreference: "high-performance" })
      || c.getContext("experimental-webgl");

    if(!gl){
      document.body.classList.add("no-webgl");
      qs("#webglStatus").textContent = "NO WEBGL";
      qs("#rendererVal").textContent = "fallback";
      qs("#pathVal").textContent = "DOM";
      return;
    }

    program = link();
    gl.useProgram(program);

    const vertices = new Float32Array([
      -1,-1, 1,-1, -1,1,
      -1,1, 1,-1, 1,1
    ]);
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

    const loc = gl.getAttribLocation(program, "a_position");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    qs("#webglStatus").textContent = "WEBGL OK";
    qs("#rendererVal").textContent = "WebGL";
    qs("#pathVal").textContent = "GPU";

    ["#freq","#veg","#shadow","#noise","#beam"].forEach(id => {
      qs(id).addEventListener("input", updateUI);
    });

    qs("#pauseBtn").addEventListener("click", () => {
      paused = !paused;
      qs("#pauseBtn").textContent = paused ? "Resume" : "Pause";
    });

    qs("#resetBtn").addEventListener("click", () => {
      qs("#freq").value = 58;
      qs("#veg").value = 42;
      qs("#shadow").value = 38;
      qs("#noise").value = 24;
      qs("#beam").value = 66;
      scenarioShift = 0.0;
      updateUI();
    });

    qs("#scenarioBtn").addEventListener("click", () => {
      scenarioShift += 1.37;
      updateUI();
    });

    window.addEventListener("resize", resize);

    updateUI();
    raf = requestAnimationFrame(render);
  }

  document.addEventListener("DOMContentLoaded", init);
})();
