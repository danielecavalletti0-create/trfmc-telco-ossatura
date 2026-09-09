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

    float siteField(vec2 uv, vec2 s, float power){
      float d = distance(uv, s);
      return power / (0.045 + d*d*4.2);
    }

    float rectShadow(vec2 uv, vec2 c, vec2 size){
      vec2 q = abs(uv - c) - size;
      float outside = length(max(q,0.0));
      float inside = min(max(q.x,q.y),0.0);
      return smoothstep(0.06, 0.0, outside + inside);
    }

    vec3 palette(float x){
      vec3 deep = vec3(0.01,0.03,0.08);
      vec3 blue = vec3(0.02,0.30,0.75);
      vec3 cyan = vec3(0.00,0.82,0.92);
      vec3 green = vec3(0.13,0.95,0.30);
      vec3 amber = vec3(1.00,0.75,0.10);
      vec3 red = vec3(1.00,0.08,0.22);

      if(x < 0.22) return mix(deep, blue, x/0.22);
      if(x < 0.42) return mix(blue, cyan, (x-0.22)/0.20);
      if(x < 0.62) return mix(cyan, green, (x-0.42)/0.20);
      if(x < 0.82) return mix(green, amber, (x-0.62)/0.20);
      return mix(amber, red, (x-0.82)/0.18);
    }

    void main(){
      vec2 uv = v_uv;
      uv.x *= u_resolution.x / u_resolution.y;
      vec2 p = uv;

      vec2 sA = vec2(0.18,0.28);
      vec2 sB = vec2(0.72,0.70);
      vec2 sC = vec2(1.22,0.32);

      float field = 0.0;
      field += siteField(p, sA + vec2(0.02*sin(u_time*.23+u_shift),0.0), 0.88);
      field += siteField(p, sB, 0.74);
      field += siteField(p, sC, 0.68);

      float veg = noise(p*7.0 + vec2(u_shift, u_time*0.035));
      float foliage = smoothstep(0.35,0.95,veg) * u_veg;

      float sh = 0.0;
      sh += rectShadow(v_uv, vec2(0.37,0.56), vec2(0.075,0.18));
      sh += rectShadow(v_uv, vec2(0.59,0.58), vec2(0.105,0.15));
      sh += rectShadow(v_uv, vec2(0.72,0.35), vec2(0.075,0.11));
      sh += rectShadow(v_uv, vec2(0.83,0.56), vec2(0.07,0.17));
      sh = clamp(sh,0.0,1.0) * u_shadow;

      float fade = noise(p*28.0 + u_time*0.045) * u_noise * 0.25;
      float freqPenalty = mix(0.82, 1.35, u_freq);

      float signal = field / freqPenalty;
      signal -= foliage * 0.58;
      signal -= sh * 0.72;
      signal += fade;

      signal = clamp(signal * 0.82, 0.0, 1.0);

      vec3 col = palette(signal);

      float grid = 0.0;
      grid += smoothstep(0.012,0.0,abs(fract(v_uv.x*34.0)-0.5));
      grid += smoothstep(0.012,0.0,abs(fract(v_uv.y*24.0)-0.5));
      col += grid * vec3(0.02,0.10,0.12);

      float vignette = smoothstep(0.98,0.25,distance(v_uv,vec2(0.5,0.52)));
      col *= 0.55 + 0.55*vignette;

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
    if(v <= .30) return "700 MHz";
    if(v <= .70) return "3.5 GHz";
    return "28 GHz";
  }

  function updateUI(){
    const f = val("#freq");
    const veg = val("#veg");
    const shadow = val("#shadow");
    const noise = val("#noise");

    qs("#freqVal").textContent = freqLabel(f);
    qs("#vegVal").textContent = veg.toFixed(2);
    qs("#shadowVal").textContent = shadow.toFixed(2);
    qs("#noiseVal").textContent = noise.toFixed(2);

    const loss = 4 + veg*16 + shadow*8 + f*7;
    const cov = Math.max(0, 100 - Math.round(loss*2.1 + noise*12));
    const risk = loss > 24 ? "CRITICAL" : loss > 17 ? "HIGH" : loss > 10 ? "MEDIUM" : "LOW";

    qs("#lossVal").textContent = loss.toFixed(1) + " dB";
    qs("#coverageVal").textContent = cov + "%";
    qs("#riskVal").textContent = risk;
    qs("#gpuScore").textContent = cov + "%";
    qs("#gpuMode").textContent = "native shader field";
    qs("#captionText").textContent = "f=" + freqLabel(f) + " · veg=" + veg.toFixed(2) + " · shadow=" + shadow.toFixed(2);
    qs("#eventBus").innerHTML = "<b>AI RF Copilot</b><p>GPU RF field refreshed. Loss=" + loss.toFixed(1) + " dB, coverage=" + cov + "%, risk=" + risk + ".</p>";
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

    ["#freq","#veg","#shadow","#noise"].forEach(id => {
      qs(id).addEventListener("input", updateUI);
    });

    qs("#pauseBtn").addEventListener("click", () => {
      paused = !paused;
      qs("#pauseBtn").textContent = paused ? "Resume" : "Pause";
    });

    qs("#resetBtn").addEventListener("click", () => {
      qs("#freq").value = 62;
      qs("#veg").value = 58;
      qs("#shadow").value = 48;
      qs("#noise").value = 36;
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
