#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSET_DIR="$PUBLIC/assets/trfmc_gpu_visual_runtime"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_GPU_VISUAL_RUNTIME_V2_$TS"
LATEST="$BASE/runtime/quality/latest_gpu_visual_runtime_v2"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

CSS="$ASSET_DIR/trfmc_gpu_visual_runtime_v2.css"
JS="$ASSET_DIR/trfmc_gpu_visual_runtime_v2.js"
MANIFEST="$PUBLIC/trfmc_gpu_visual_runtime_manifest_v2.json"
LAB="$PUBLIC/trfmc_gpu_visual_runtime_lab_v2.html"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC GPU VISUAL RUNTIME V2"
echo "WebGL shader layer · plugin registry · WebGPU probe · safe leaf patch"
echo "============================================================"

echo
echo "[1/9] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_GPU_VISUAL_RUNTIME_V2_$TS.tar.gz"
find frontend/public -maxdepth 1 -type f -name '*.html' -print0 | tar --null -czf "$BACKUP" --files-from - 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Creo CSS GPU Runtime V2"

cat > "$CSS" <<'CSS'
/*
 TRFMC GPU Visual Runtime V2
 Global leaf-only cinematic GPU skin.
 No navbar. No iframe. No CDN.
*/

:root{
  --trfmc-gpu-x:50%;
  --trfmc-gpu-y:45%;
  --trfmc-gpu-power:.68;
  --trfmc-cyan:#00e5ff;
  --trfmc-green:#75ff5b;
  --trfmc-gold:#ffd84d;
  --trfmc-red:#ff3d7f;
}

body.trfmc-gpu-v2{
  background:#010409 !important;
  color:#e9fbff;
}

.trfmc-gpu-layer{
  position:fixed;
  inset:0;
  z-index:0;
  pointer-events:none;
  opacity:.74;
  mix-blend-mode:screen;
}

.trfmc-gpu-fallback{
  position:fixed;
  inset:0;
  z-index:0;
  pointer-events:none;
  opacity:.55;
  background:
    radial-gradient(circle at var(--trfmc-gpu-x) var(--trfmc-gpu-y), rgba(0,229,255,.18), transparent 34vw),
    radial-gradient(circle at 80% 20%, rgba(117,255,91,.08), transparent 26vw),
    linear-gradient(135deg, #010409, #031421 62%, #010409);
}

body.trfmc-gpu-v2 > *:not(.trfmc-gpu-layer):not(.trfmc-gpu-fallback):not(.trfmc-gpu-hud){
  position:relative;
  z-index:1;
}

body.trfmc-gpu-v2 .leaf-panel,
body.trfmc-gpu-v2 .leaf-card,
body.trfmc-gpu-v2 .plotBox,
body.trfmc-gpu-v2 .leaf-kpi,
body.trfmc-gpu-v2 .formulaLive{
  transform:translateZ(0);
  border-color:rgba(0,229,255,.38) !important;
  box-shadow:
    0 0 30px rgba(0,229,255,.16),
    inset 0 0 22px rgba(0,229,255,.055),
    0 12px 42px rgba(0,0,0,.38) !important;
}

body.trfmc-gpu-v2 .leaf-panel,
body.trfmc-gpu-v2 .leaf-card,
body.trfmc-gpu-v2 .plotBox{
  background:
    linear-gradient(145deg, rgba(2,18,30,.90), rgba(1,7,13,.89)),
    radial-gradient(circle at 88% 8%, rgba(0,229,255,.14), transparent 30%) !important;
  backdrop-filter:blur(15px) saturate(130%);
}

body.trfmc-gpu-v2 canvas{
  image-rendering:auto;
  filter:
    drop-shadow(0 0 18px rgba(0,229,255,.24))
    saturate(1.12)
    contrast(1.06);
}

.trfmc-gpu-hud{
  position:fixed;
  right:12px;
  bottom:12px;
  z-index:20;
  pointer-events:none;
  font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size:10px;
  line-height:1.35;
  color:#8fb8c8;
  padding:8px 10px;
  border:1px solid rgba(0,229,255,.28);
  border-radius:8px;
  background:rgba(1,9,16,.58);
  box-shadow:0 0 24px rgba(0,229,255,.12);
  backdrop-filter:blur(10px);
}

.trfmc-gpu-hud b{
  color:#75ff5b;
  text-shadow:0 0 10px rgba(117,255,91,.35);
}

body.trfmc-gpu-v2 .leaf-title,
body.trfmc-gpu-v2 h1,
body.trfmc-gpu-v2 h2,
body.trfmc-gpu-v2 h3{
  text-shadow:0 0 18px rgba(0,229,255,.35);
}

body.trfmc-gpu-v2 .leaf-btn:hover,
body.trfmc-gpu-v2 button:hover,
body.trfmc-gpu-v2 a:hover{
  filter:brightness(1.16) saturate(1.14);
}

@media (prefers-reduced-motion: reduce){
  .trfmc-gpu-layer{display:none;}
}
CSS

echo
echo "[3/9] Creo JS GPU Runtime V2"

cat > "$JS" <<'JS'
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
JS

echo
echo "[4/9] Creo manifest plugin GPU Runtime"

cat > "$MANIFEST" <<'JSON'
{
  "id": "TRFMC_GPU_VISUAL_RUNTIME_V2",
  "mode": "leaf_global_visual_runtime",
  "policy": "No iframe. No CDN. No new navbar. V6R3 and Control Room protected.",
  "assets": {
    "css": "/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css",
    "js": "/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"
  },
  "plugins": [
    {
      "id": "rf_interference_field",
      "type": "webgl_shader",
      "purpose": "Animated RF interference, wavefront and energy field layer"
    },
    {
      "id": "spectral_grid_depth",
      "type": "webgl_shader",
      "purpose": "Instrument-style depth grid and spectrum ambience"
    },
    {
      "id": "instrument_glass_hud",
      "type": "css_runtime",
      "purpose": "T&M glass panels, glow, depth, HUD diagnostics"
    },
    {
      "id": "panel_depth_lighting",
      "type": "css_runtime",
      "purpose": "Light/reflection model for cards, panels and cockpit components"
    },
    {
      "id": "webgpu_capability_probe",
      "type": "capability_probe",
      "purpose": "Detect navigator.gpu for future compute and WebGPU scene engine"
    },
    {
      "id": "reduced_motion_guard",
      "type": "safety",
      "purpose": "Respect reduced-motion and fallback to static layer"
    }
  ]
}
JSON

echo
echo "[5/9] Creo GPU Runtime Lab V2"

cat > "$LAB" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC GPU Visual Runtime Lab V2</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<style>
.lab-grid{display:grid;grid-template-columns:360px 1fr 420px;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}
.big-stage{min-height:560px;border:1px solid rgba(0,229,255,.34);background:rgba(1,9,16,.72);box-shadow:0 0 40px rgba(0,229,255,.12),inset 0 0 32px rgba(0,229,255,.06);position:relative;overflow:hidden}
.big-stage canvas{width:100%;height:100%;display:block;min-height:560px}
.plugin{border:1px solid rgba(0,229,255,.22);border-radius:8px;padding:8px;margin:6px 0;background:rgba(0,229,255,.045)}
.plugin b{color:#75ff5b}.mono{font-family:ui-monospace,Consolas,monospace;font-size:11px;color:#dffaff}
@media(max-width:1300px){.lab-grid{grid-template-columns:1fr}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2">
<header class="leaf-top">
  <div>
    <div class="leaf-title">GPU Visual Runtime Lab V2</div>
    <div class="leaf-sub">WebGL shader layer · plugin registry · WebGPU probe · no CDN · no iframe · no shell parallela</div>
  </div>
  <div class="leaf-kpis">
    <div class="leaf-kpi"><small>WebGL</small><b id="kWebgl">probe</b></div>
    <div class="leaf-kpi"><small>WebGPU</small><b id="kWebgpu">probe</b></div>
    <div class="leaf-kpi"><small>Plugins</small><b id="kPlugins">--</b></div>
    <div class="leaf-kpi"><small>Mode</small><b>V2</b></div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_expansion_hub_v1.html">Expansion Hub</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="lab-grid">
  <aside class="leaf-panel">
    <h2>GPU Stack</h2>
    <div class="leaf-card">
      <h3>Runtime status</h3>
      <div class="mono" id="runtimeBox">loading...</div>
    </div>
    <div class="leaf-card">
      <h3>Controlli</h3>
      <label class="mono">Shader power</label>
      <input id="power" type="range" min="0.20" max="1.20" step="0.01" value="0.68">
      <p class="mono">localStorage.TRFMC_GPU_RUNTIME = 'off' disabilita il layer.</p>
    </div>
    <div class="leaf-card">
      <h3>Policy</h3>
      <ul>
        <li>No nuove barre.</li>
        <li>No iframe.</li>
        <li>No CDN.</li>
        <li>Solo leaf pages.</li>
        <li>V6R3 protetta.</li>
      </ul>
    </div>
  </aside>

  <main class="leaf-panel">
    <h2>GPU Field Preview</h2>
    <section class="big-stage">
      <canvas id="localPreview"></canvas>
    </section>
  </main>

  <aside class="leaf-panel">
    <h2>Plugin registry</h2>
    <div id="plugins"></div>
    <div class="leaf-card">
      <h3>Prossimo salto</h3>
      <p>V3 dovrà introdurre scene WebGL modulari per tower, antenna, RRU, rack, OTDR, Smith Chart, spectrum analyzer e 5G Core map con componenti riusabili.</p>
    </div>
  </aside>
</div>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script>
(async function(){
  const manifest = await fetch("/trfmc_gpu_visual_runtime_manifest_v2.json").then(r=>r.json());
  const rt = window.TRFMC_GPU_RUNTIME || {};
  document.getElementById("kWebgl").textContent = rt.mode || "unknown";
  document.getElementById("kWebgpu").textContent = navigator.gpu ? "available" : "not exposed";
  document.getElementById("kPlugins").textContent = manifest.plugins.length;
  document.getElementById("runtimeBox").textContent = JSON.stringify(rt, null, 2);
  document.getElementById("plugins").innerHTML = manifest.plugins.map(p =>
    '<div class="plugin"><b>'+p.id+'</b><br><span class="mono">'+p.type+'</span><br>'+p.purpose+'</div>'
  ).join("");
  document.getElementById("power").addEventListener("input", e=>{
    document.documentElement.style.setProperty("--trfmc-gpu-power", e.target.value);
  });
})();
</script>
</body>
</html>
HTML

echo
echo "[6/9] Patch leaf operative con GPU runtime"

python3 - "$PUBLIC" "$REG" "$OUT" <<'PY'
import json, re, sys
from pathlib import Path

public=Path(sys.argv[1])
reg_path=Path(sys.argv[2])
out=Path(sys.argv[3])

css_href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css"
js_src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"

protected={
    "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "/trfmc_integration_control_room.html",
    "/trfmc_portal_registry_unified.json",
    "/trfmc_gpu_visual_runtime_lab_v2.html"
}

reg=json.loads(reg_path.read_text(errors="ignore"))
patched=[]
skipped=[]
missing=[]

def add_body_class(s):
    m=re.search(r"<body\b([^>]*)>", s, flags=re.I)
    if not m:
        return s
    body=m.group(0)
    attrs=m.group(1)
    if "trfmc-gpu-v2" in body:
        return s
    if re.search(r'\bclass\s*=', body, flags=re.I):
        new_body=re.sub(
            r'class\s*=\s*["\']([^"\']*)["\']',
            lambda mm: 'class="' + mm.group(1).strip() + ' trfmc-gpu-v2"',
            body, count=1, flags=re.I
        )
    else:
        new_body="<body class=\"trfmc-gpu-v2\"" + attrs + ">"
    return s[:m.start()] + new_body + s[m.end():]

for p in reg.get("pages",[]):
    url=p.get("url","")
    cls=p.get("class","")
    if cls!="leaf_operational_candidate":
        skipped.append((url,"not_leaf"))
        continue
    if url in protected:
        skipped.append((url,"protected"))
        continue
    if not url.endswith(".html"):
        skipped.append((url,"not_html"))
        continue

    f=public/url.lstrip("/")
    if not f.exists():
        missing.append(url)
        continue

    s=f.read_text(errors="ignore")
    original=s

    if css_href not in s:
        if re.search(r"</head>", s, flags=re.I):
            s=re.sub(r"</head>", f'<link rel="stylesheet" href="{css_href}">\n</head>', s, count=1, flags=re.I)
        else:
            skipped.append((url,"no_head"))
            continue

    if js_src not in s:
        if re.search(r"</body>", s, flags=re.I):
            s=re.sub(r"</body>", f'<script src="{js_src}"></script>\n</body>', s, count=1, flags=re.I)
        else:
            s += f'\n<script src="{js_src}"></script>\n'

    s=add_body_class(s)

    if s != original:
        f.write_text(s)
        patched.append(url)

(out/"patched_pages.tsv").write_text("url\n" + "\n".join(patched) + "\n")
(out/"skipped_pages.tsv").write_text("url\treason\n" + "\n".join(f"{u}\t{r}" for u,r in skipped) + "\n")
(out/"missing_pages.txt").write_text("\n".join(missing) + "\n")

print(json.dumps({"patched":len(patched),"skipped":len(skipped),"missing":len(missing)},indent=2))
PY

echo
echo "[7/9] Aggiorno registry con GPU Runtime Lab"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public=Path(sys.argv[1])
reg_path=Path(sys.argv[2])
reg=json.loads(reg_path.read_text(errors="ignore"))
pages=reg.get("pages",[])
by_url={p.get("url"):p for p in pages if p.get("url")}

target=public/"trfmc_gpu_visual_runtime_lab_v2.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_gpu_visual_runtime_lab_v2.html"]={
  "class":"leaf_operational_candidate",
  "name":"trfmc_gpu_visual_runtime_lab_v2.html",
  "url":"/trfmc_gpu_visual_runtime_lab_v2.html",
  "size":target.stat().st_size,
  "webgl":True,
  "webgpu_probe":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"GPU Visual Runtime V2 Lab"
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
reg["last_gpu_visual_runtime_v2_update"]={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "page":"/trfmc_gpu_visual_runtime_lab_v2.html",
  "policy":"global GPU runtime added to leaf pages; V6R3 and Control Room protected"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["last_gpu_visual_runtime_v2_update"],indent=2,ensure_ascii=False))
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[8/9] Quality gate"

{
  printf "url\tstatus\tbytes\n"

  for u in \
    /assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css \
    /assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js \
    /trfmc_gpu_visual_runtime_manifest_v2.json \
    /trfmc_gpu_visual_runtime_lab_v2.html \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_portal_registry_unified.json \
    /trfmc_expansion_hub_v1.html
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done

  tail -n +2 "$OUT/patched_pages.tsv" | while read -r u; do
    [ -n "$u" ] || continue
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

for f in "$CSS" "$JS" "$MANIFEST" "$LAB"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
  grep -nEi 'MASTER FUSED|trfmc_master_fused|fallback shell' "$f" >> "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC_GPU_VISUAL_RUNTIME_V2" \
  "webgpu_capability_probe" \
  "rf_interference_field" \
  "trfmc-gpu-layer" \
  "navigator.gpu"
do
  if grep -Rqs "$token" "$ASSET_DIR" "$LAB" "$MANIFEST"; then
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
missing_pages=sum(1 for x in (out/"missing_pages.txt").read_text(errors="ignore").splitlines() if x.strip())
patched=max(0, len((out/"patched_pages.tsv").read_text(errors="ignore").splitlines())-1)
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
reg=json.loads(reg_path.read_text(errors="ignore"))

data={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "runtime":"TRFMC_GPU_VISUAL_RUNTIME_V2",
  "patched_leaf_pages":patched,
  "gpu_lab":"/trfmc_gpu_visual_runtime_lab_v2.html",
  "manifest":"/trfmc_gpu_visual_runtime_manifest_v2.json",
  "http_non_200":non200,
  "external_refs":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "missing_pages":missing_pages,
  "content_check_miss":content_miss,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_leaf_operational_candidate":reg.get("counts",{}).get("leaf_operational_candidate"),
  "disable_switch":"localStorage.TRFMC_GPU_RUNTIME='off'",
  "quiet_hud_switch":"localStorage.TRFMC_GPU_PERF='quiet'",
  "result":"PASS" if patched>=1 and non200==0 and external==0 and iframe==0 and fused==0 and missing_pages==0 and content_miss==0 and protected_ok and registry_changed else "WARN",
  "policy":"GPU runtime applied to leaf pages only. V6R3 and official Control Room unchanged."
}
(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_GPU_VISUAL_RUNTIME_V2_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_gpu_visual_runtime \
    frontend/public/trfmc_gpu_visual_runtime_manifest_v2.json \
    frontend/public/trfmc_gpu_visual_runtime_lab_v2.html \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_gpu_visual_runtime_v2 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv" | sed -n '1,120p'
echo
echo "Content checks:"
cat "$OUT/content_checks.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_gpu_visual_runtime_lab_v2.html"
echo "http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"
echo "============================================================"
