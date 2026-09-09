(function(){
  "use strict";

  const $ = (id) => document.getElementById(id);

  const state = {
    season: 0.70,
    freq: 3.5,
    wet: 0.45,
    density: 1.0,
    wind: false,
    focus: false,
    frame: 0,
    lastT: performance.now(),
    fps: 0
  };

  const canvas = $("v68_gl");
  const gl = canvas.getContext("webgl", {
    antialias: false,
    alpha: false,
    powerPreference: "high-performance",
    preserveDrawingBuffer: false
  });

  const log = (msg, cls="") => {
    const el = document.createElement("div");
    if(cls) el.className = cls;
    el.textContent = "AI RF Copilot: " + msg;
    $("ai_log").prepend(el);
    while($("ai_log").children.length > 7) $("ai_log").lastChild.remove();
  };

  async function backendHealth(){
    try {
      const r = await fetch("/api/health", {cache:"no-store"});
      $("backend_state").textContent = r.ok ? "Backend OK" : "Backend WARN";
    } catch(e) {
      $("backend_state").textContent = "Backend N/A";
    }
  }

  const overlay = $("scene_overlay");

  const trees = [
    [-0.72,  0.34, 34], [-0.64, 0.25, 28], [-0.56, 0.38, 38],
    [-0.18, -0.05, 42], [-0.08,-0.12, 35], [0.02,-0.01, 31],
    [0.14, -0.16, 39], [0.22,-0.05, 33], [0.34,0.02,27],
    [0.48, 0.30, 44], [0.60, 0.24, 31], [0.72,0.35,37],
    [-0.38,-0.42, 30], [-0.26,-0.50, 36], [-0.12,-0.44,32],
    [0.38,-0.48, 39], [0.52,-0.38, 34], [0.66,-0.47,29]
  ];

  const buildings = [
    [-0.42,0.20, 54,90], [-0.30,0.12, 42,70], [-0.16,0.28, 50,64],
    [0.06,0.22, 62,84], [0.26,0.14, 44,76], [0.42,0.20, 52,96],
    [-0.62,-0.18, 44,64], [-0.46,-0.24, 64,80], [0.58,-0.14, 54,86],
    [0.74,-0.23, 46,70], [-0.02,-0.34, 58,68], [0.20,-0.36,52,76]
  ];

  const sites = [
    [-0.82,-0.62,"SITE-A"],
    [ 0.12, 0.62,"SITE-B"],
    [ 0.82,-0.50,"SITE-C"]
  ];

  function mapX(x){ return ((x + 1) * 0.5) * 100; }
  function mapY(y){ return ((1 - (y + 1) * 0.5)) * 100; }

  function buildOverlay(){
    overlay.innerHTML = "";
    buildings.forEach(([x,y,w,h]) => {
      const d = document.createElement("div");
      d.className = "building";
      d.style.left = mapX(x) + "%";
      d.style.top = mapY(y) + "%";
      d.style.setProperty("--w", w + "px");
      d.style.setProperty("--h", h + "px");
      overlay.appendChild(d);
    });

    trees.forEach(([x,y,s], i) => {
      const d = document.createElement("div");
      d.className = "tree";
      d.style.left = mapX(x) + "%";
      d.style.top = mapY(y) + "%";
      d.style.setProperty("--s", s + "px");
      d.style.setProperty("--op", (0.38 + state.season * 0.52).toFixed(2));
      d.style.animationDelay = (i * 0.17).toFixed(2) + "s";
      overlay.appendChild(d);
    });

    sites.forEach(([x,y,name]) => {
      const d = document.createElement("div");
      d.className = "site-dot";
      d.style.left = mapX(x) + "%";
      d.style.top = mapY(y) + "%";
      d.dataset.name = name;
      overlay.appendChild(d);
    });
  }

  function setTreeOpacity(){
    document.querySelectorAll(".tree").forEach((t, i) => {
      const op = 0.18 + state.season * 0.58 + state.wet * 0.12;
      const scale = 0.72 + state.season * 0.36 + state.density * 0.08;
      t.style.setProperty("--op", Math.min(.92, op).toFixed(2));
      t.style.setProperty("--s", (trees[i][2] * scale).toFixed(1) + "px");
      t.style.animationPlayState = state.wind ? "running" : "paused";
    });
  }

  if(!gl){
    $("shader_state").textContent = "WebGL FAIL";
    log("WebGL non disponibile nel browser. Verifica accelerazione GPU.", "crit");
    return;
  }

  const vert = `
    attribute vec2 a_pos;
    varying vec2 v_uv;
    void main(){
      v_uv = a_pos * 0.5 + 0.5;
      gl_Position = vec4(a_pos, 0.0, 1.0);
    }
  `;

  const frag = `
    precision highp float;
    varying vec2 v_uv;

    uniform vec2 u_res;
    uniform float u_time;
    uniform float u_season;
    uniform float u_freq;
    uniform float u_wet;
    uniform float u_density;
    uniform float u_wind;
    uniform float u_focus;

    float hash(vec2 p){
      return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
    }

    float noise(vec2 p){
      vec2 i = floor(p);
      vec2 f = fract(p);
      float a = hash(i);
      float b = hash(i + vec2(1.0,0.0));
      float c = hash(i + vec2(0.0,1.0));
      float d = hash(i + vec2(1.0,1.0));
      vec2 u = f*f*(3.0-2.0*f);
      return mix(a,b,u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
    }

    float rect(vec2 p, vec2 c, vec2 s){
      vec2 q = abs(p-c)-s;
      float outside = length(max(q,0.0));
      float inside = min(max(q.x,q.y),0.0);
      return 1.0 - smoothstep(0.0, 0.012, outside + inside);
    }

    float tree(vec2 p, vec2 c, float r){
      float d = length(p-c);
      return 1.0 - smoothstep(r*0.45, r, d);
    }

    float sitePower(vec2 p, vec2 s, float pwr){
      float d = max(distance(p,s), 0.035);
      float fs = pwr / pow(d, 1.65);
      return fs;
    }

    float buildingLoss(vec2 p){
      float l = 0.0;
      l += rect(p, vec2(-0.42,0.20), vec2(.055,.120)) * 1.2;
      l += rect(p, vec2(-0.30,0.12), vec2(.045,.092)) * .9;
      l += rect(p, vec2(-0.16,0.28), vec2(.052,.085)) * .8;
      l += rect(p, vec2( 0.06,0.22), vec2(.065,.110)) * 1.2;
      l += rect(p, vec2( 0.26,0.14), vec2(.047,.095)) * .9;
      l += rect(p, vec2( 0.42,0.20), vec2(.055,.125)) * 1.1;
      l += rect(p, vec2(-0.62,-0.18), vec2(.047,.085)) * .75;
      l += rect(p, vec2(-0.46,-0.24), vec2(.066,.105)) * .95;
      l += rect(p, vec2( 0.58,-0.14), vec2(.058,.115)) * 1.1;
      l += rect(p, vec2( 0.74,-0.23), vec2(.050,.092)) * .85;
      l += rect(p, vec2(-0.02,-0.34), vec2(.060,.090)) * .85;
      l += rect(p, vec2( 0.20,-0.36), vec2(.055,.100)) * .95;

      vec2 sA = vec2(-0.82,-0.62);
      vec2 sB = vec2( 0.12, 0.62);
      vec2 sC = vec2( 0.82,-0.50);

      l += smoothstep(.18,.78,distance(p, sA)) * rect(p-vec2(.055,.035), vec2(-.42,.20), vec2(.09,.15)) * .9;
      l += smoothstep(.18,.78,distance(p, sB)) * rect(p+vec2(.035,-.055), vec2(.06,.22), vec2(.11,.15)) * .9;
      l += smoothstep(.18,.78,distance(p, sC)) * rect(p-vec2(.06,-.035), vec2(.58,-.14), vec2(.10,.15)) * .9;

      return min(l, 2.85);
    }

    float vegetationLoss(vec2 p){
      float wind = u_wind * (noise(p*6.0 + vec2(u_time*.20, u_time*.12)) - .5) * .018;
      vec2 pp = p + vec2(wind, -wind*.6);

      float rScale = mix(.55, 1.18, u_season) * mix(.75, 1.25, u_density);
      float fScale = pow(max(u_freq, .7) / 3.5, .23);
      float wetScale = mix(.82, 1.42, u_wet);

      float leaf = .18 + .82*u_season;
      float v = 0.0;
      v += tree(pp, vec2(-0.72, 0.34), .070*rScale);
      v += tree(pp, vec2(-0.64, 0.25), .060*rScale);
      v += tree(pp, vec2(-0.56, 0.38), .075*rScale);
      v += tree(pp, vec2(-0.18,-0.05), .082*rScale);
      v += tree(pp, vec2(-0.08,-0.12), .070*rScale);
      v += tree(pp, vec2( 0.02,-0.01), .063*rScale);
      v += tree(pp, vec2( 0.14,-0.16), .076*rScale);
      v += tree(pp, vec2( 0.22,-0.05), .065*rScale);
      v += tree(pp, vec2( 0.34, 0.02), .056*rScale);
      v += tree(pp, vec2( 0.48, 0.30), .085*rScale);
      v += tree(pp, vec2( 0.60, 0.24), .062*rScale);
      v += tree(pp, vec2( 0.72, 0.35), .073*rScale);
      v += tree(pp, vec2(-0.38,-0.42), .061*rScale);
      v += tree(pp, vec2(-0.26,-0.50), .070*rScale);
      v += tree(pp, vec2(-0.12,-0.44), .064*rScale);
      v += tree(pp, vec2( 0.38,-0.48), .078*rScale);
      v += tree(pp, vec2( 0.52,-0.38), .068*rScale);
      v += tree(pp, vec2( 0.66,-0.47), .058*rScale);

      v = min(v, 3.0);
      return v * leaf * fScale * wetScale * .52;
    }

    vec3 palette(float x){
      x = clamp(x, 0.0, 1.0);
      vec3 c0 = vec3(0.010,0.025,0.080);
      vec3 c1 = vec3(0.000,0.230,0.520);
      vec3 c2 = vec3(0.000,0.780,1.000);
      vec3 c3 = vec3(0.250,0.960,0.435);
      vec3 c4 = vec3(1.000,0.780,0.160);
      vec3 c5 = vec3(1.000,1.000,0.970);
      if(x < .22) return mix(c0,c1,x/.22);
      if(x < .44) return mix(c1,c2,(x-.22)/.22);
      if(x < .67) return mix(c2,c3,(x-.44)/.23);
      if(x < .86) return mix(c3,c4,(x-.67)/.19);
      return mix(c4,c5,(x-.86)/.14);
    }

    void main(){
      vec2 uv = v_uv;
      vec2 p = (uv - .5) * 2.0;
      p.x *= u_res.x / u_res.y;

      float grid = 0.0;
      vec2 gp = abs(fract(p*18.0)-.5);
      grid = (1.0-smoothstep(.0,.018,min(gp.x,gp.y))) * .06;

      float sig = 0.0;
      sig += sitePower(p, vec2(-0.82,-0.62), 1.16);
      sig += sitePower(p, vec2( 0.12, 0.62), 1.00);
      sig += sitePower(p, vec2( 0.82,-0.50), 1.06);

      float bLoss = buildingLoss(p);
      float vLoss = vegetationLoss(p);
      float rf = log(1.0 + sig * 2.8) - (bLoss*.54 + vLoss*.74);

      if(u_focus > .5){
        float parkFocus = smoothstep(.55,.05,distance(p,vec2(.03,-.08)));
        rf -= parkFocus * vLoss * .42;
      }

      float n = noise(p*34.0 + u_time*.05) * .035;
      float level = clamp(rf*.42 + .48 + n, 0.0, 1.0);
      vec3 col = palette(level);

      float dead = smoothstep(.30,.0,level);
      col = mix(col, vec3(.006,.012,.030), dead*.58);

      vec3 vegTint = vec3(.08,.38,.16) * vegetationLoss(p) * .24;
      col += vegTint;
      col += grid;

      float vign = smoothstep(1.55,.28,length(p));
      col *= mix(.58,1.12,vign);

      gl_FragColor = vec4(col, 1.0);
    }
  `;

  function compile(type, src){
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if(!gl.getShaderParameter(s, gl.COMPILE_STATUS)){
      throw new Error(gl.getShaderInfoLog(s));
    }
    return s;
  }

  let program;
  try {
    program = gl.createProgram();
    gl.attachShader(program, compile(gl.VERTEX_SHADER, vert));
    gl.attachShader(program, compile(gl.FRAGMENT_SHADER, frag));
    gl.linkProgram(program);
    if(!gl.getProgramParameter(program, gl.LINK_STATUS)){
      throw new Error(gl.getProgramInfoLog(program));
    }
    gl.useProgram(program);
    $("shader_state").textContent = "Shader OK";
  } catch(e) {
    $("shader_state").textContent = "Shader FAIL";
    log("compilazione shader fallita: " + e.message, "crit");
    return;
  }

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
    -1,-1,  1,-1, -1, 1,
    -1, 1,  1,-1,  1, 1
  ]), gl.STATIC_DRAW);

  const aPos = gl.getAttribLocation(program, "a_pos");
  gl.enableVertexAttribArray(aPos);
  gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

  const uniforms = {
    res: gl.getUniformLocation(program, "u_res"),
    time: gl.getUniformLocation(program, "u_time"),
    season: gl.getUniformLocation(program, "u_season"),
    freq: gl.getUniformLocation(program, "u_freq"),
    wet: gl.getUniformLocation(program, "u_wet"),
    density: gl.getUniformLocation(program, "u_density"),
    wind: gl.getUniformLocation(program, "u_wind"),
    focus: gl.getUniformLocation(program, "u_focus")
  };

  function resize(){
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.floor(innerWidth * dpr);
    const h = Math.floor(innerHeight * dpr);
    if(canvas.width !== w || canvas.height !== h){
      canvas.width = w;
      canvas.height = h;
      gl.viewport(0,0,w,h);
    }
  }

  function weissbergerInspired(freqGHz, foliageDepthM, season, wet, density){
    const f = Math.max(.7, freqGHz);
    const d = Math.max(1, foliageDepthM);
    let base;
    if(d <= 14){
      base = 0.45 * Math.pow(f, 0.284) * d;
    } else {
      base = 1.33 * Math.pow(f, 0.284) * Math.pow(d, 0.588);
    }
    const seasonFactor = 0.25 + season * 0.95;
    const wetFactor = 0.85 + wet * 0.55;
    const densFactor = 0.55 + density * 0.55;
    return base * seasonFactor * wetFactor * densFactor;
  }

  function updateUi(){
    $("freq_value").textContent = state.freq.toFixed(1) + " GHz";
    $("wet_value").textContent = Math.round(state.wet*100) + "%";
    $("density_value").textContent = state.density.toFixed(2) + "x";

    let seasonName = "Winter";
    if(state.season > .80) seasonName = "Autumn";
    else if(state.season > .55) seasonName = "Summer";
    else if(state.season > .18) seasonName = "Spring";

    const loss = weissbergerInspired(state.freq, 18, state.season, state.wet, state.density);
    const contraction = Math.min(42, loss * 1.18);
    const risk = loss < 6 ? "LOW" : loss < 14 ? "MEDIUM" : loss < 24 ? "HIGH" : "CRITICAL";

    $("veg_score").textContent = loss.toFixed(1) + " dB";
    $("veg_label").textContent = seasonName + " · synthetic foliage penalty";
    $("loss_model").textContent = loss.toFixed(1) + " dB";
    $("season_factor").textContent = seasonName + " / " + (0.25 + state.season*.95).toFixed(2);
    $("coverage_delta").textContent = "-" + contraction.toFixed(0) + "%";
    $("outage_risk").textContent = risk;

    setTreeOpacity();

    if(risk === "CRITICAL") log("attenuazione vegetativa critica: possibili buchi di copertura in NLOS park corridor.", "crit");
    else if(risk === "HIGH") log("attenuazione vegetativa alta: raccomandata verifica tilt/azimuth e densificazione small-cell.", "warn");
  }

  $("season_select").addEventListener("change", e => {
    state.season = parseFloat(e.target.value);
    updateUi();
  });
  $("freq_slider").addEventListener("input", e => {
    state.freq = parseFloat(e.target.value);
    updateUi();
  });
  $("wet_slider").addEventListener("input", e => {
    state.wet = parseFloat(e.target.value);
    updateUi();
  });
  $("density_slider").addEventListener("input", e => {
    state.density = parseFloat(e.target.value);
    updateUi();
  });
  $("btn_wind").addEventListener("click", e => {
    state.wind = !state.wind;
    e.currentTarget.classList.toggle("active", state.wind);
    log(state.wind ? "wind motion attivato: micro-variazioni del canale simulate." : "wind motion disattivato.");
    updateUi();
  });
  $("btn_focus").addEventListener("click", e => {
    state.focus = !state.focus;
    e.currentTarget.classList.toggle("active", state.focus);
    log(state.focus ? "focus sul parco centrale: evidenziata contrazione di copertura." : "focus parco disattivato.");
  });

  function render(t){
    resize();

    const now = performance.now();
    state.frame++;
    if(now - state.lastT > 650){
      state.fps = Math.round(state.frame * 1000 / (now - state.lastT));
      state.frame = 0;
      state.lastT = now;
      $("fps_state").textContent = "FPS " + state.fps;
    }

    gl.useProgram(program);
    gl.uniform2f(uniforms.res, canvas.width, canvas.height);
    gl.uniform1f(uniforms.time, t * 0.001);
    gl.uniform1f(uniforms.season, state.season);
    gl.uniform1f(uniforms.freq, state.freq);
    gl.uniform1f(uniforms.wet, state.wet);
    gl.uniform1f(uniforms.density, state.density);
    gl.uniform1f(uniforms.wind, state.wind ? 1 : 0);
    gl.uniform1f(uniforms.focus, state.focus ? 1 : 0);

    gl.drawArrays(gl.TRIANGLES, 0, 6);
    requestAnimationFrame(render);
  }

  buildOverlay();
  updateUi();
  backendHealth();
  setInterval(backendHealth, 5000);
  requestAnimationFrame(render);

})();
