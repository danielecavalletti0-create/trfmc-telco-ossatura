from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_VISUAL_ASSET_ZOOM_AUTOFIT_V44_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_VISUAL_ASSET_ZOOM_AUTOFIT_V44_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_VISUAL_ASSET_ZOOM_AUTOFIT_V44_{TS}.tar.gz"

VISUAL_COMPONENT = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"
STYLES = ROOT / "frontend/src/styles.css"
MAIN = ROOT / "frontend/src/app/main.tsx"

ACTIVE_REGISTRY = ROOT / "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC VISUAL ASSET ZOOM AUTOFIT V44")
print("responsive image viewer · zoom/pan · fit contain/cover · no backend mutation")
print("=" * 60)

# Preconditions
for rel in [
    "runtime/quality/latest_promote_staged_renders_v43c/summary.json",
    "runtime/quality/latest_mission_layout_orchestrator_v42/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not ACTIVE_REGISTRY.exists():
    raise SystemExit("ERRORE: active registry mancante")

if not VISUAL_COMPONENT.exists():
    raise SystemExit("ERRORE: VisualAssetRuntimeV41.tsx mancante")

if not STYLES.exists():
    raise SystemExit("ERRORE: styles.css mancante")

if not MAIN.exists() or "RFOperationalDeckV42MissionLayoutOrchestrator" not in MAIN.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: main.tsx non monta V42")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0:
    raise SystemExit("ERRORE: active registry non servito da Vite")

print("OK: V43/V42 PASS, active registry servito, V42 attivo")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_VISUAL_ASSET_ZOOM_AUTOFIT_V44_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
    "frontend/src/styles.css",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

before_component = VISUAL_COMPONENT.read_text(encoding="utf-8")
before_styles = STYLES.read_text(encoding="utf-8")

(RDIR / f"VisualAssetRuntimeV41.tsx.before_v44_{TS}").write_text(before_component, encoding="utf-8")
(RDIR / f"styles.css.before_v44_{TS}").write_text(before_styles, encoding="utf-8")

# Replace component entirely with enhanced viewer while keeping same export.
VISUAL_COMPONENT.write_text(r"""
import { PointerEvent, WheelEvent, useEffect, useMemo, useRef, useState } from 'react'

type VisualAssetV41 = {
  id: string
  title: string
  description: string
  category: string
  public_path: string
  expected_real_render_path: string
  fallback_path: string
  real_render_path?: string
  source_mode: string
  replaceable: boolean
  tags: string[]
  usage: string[]
}

type VisualRegistryV41 = {
  timestamp: string
  operation: string
  asset_root: string
  assets_count: number
  fallback_format: string
  real_render_expected_format: string
  assets: VisualAssetV41[]
}

const registryUrl = '/trfmc_assets/visual_knowledge/visual_asset_registry_active.json'

function domainForAsset(asset: VisualAssetV41) {
  if (asset.id.includes('microstrip')) return 'Antenna System'
  if (asset.id.includes('beamwidth')) return 'RF Physics / Antenna'
  if (asset.id.includes('tower') || asset.id.includes('cellular')) return 'Telecom Infrastructure'
  if (asset.id.includes('microwave') || asset.id.includes('lab')) return 'RF / Microwave Engineering'
  if (asset.id.includes('uav')) return 'UAV / RF Links'
  if (asset.id.includes('electronics')) return 'Electronics Fundamentals'
  return 'Knowledge Base'
}

function scenarioForAsset(asset: VisualAssetV41) {
  if (asset.id.includes('microstrip')) return 'Microstrip Patch Antenna'
  if (asset.id.includes('beamwidth')) return 'Beamwidth and Coverage'
  if (asset.id.includes('tower') || asset.id.includes('cellular')) return 'Telecom Tower Infrastructure'
  if (asset.id.includes('microwave') || asset.id.includes('lab')) return 'RF & Microwave Engineering Lab'
  if (asset.id.includes('uav')) return 'UAV Platforms and ISR Systems'
  if (asset.id.includes('antennas')) return 'Antenna Systems Explorer'
  if (asset.id.includes('electronics')) return 'Electronics Fundamentals'
  return 'Knowledge Scenario'
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value))
}

function VisualZoomViewer({ asset }: { asset: VisualAssetV41 }) {
  const frameRef = useRef<HTMLDivElement | null>(null)
  const [fitMode, setFitMode] = useState<'contain' | 'cover'>('contain')
  const [zoom, setZoom] = useState(1)
  const [pan, setPan] = useState({ x: 0, y: 0 })
  const [drag, setDrag] = useState<{ active: boolean; x: number; y: number }>({ active: false, x: 0, y: 0 })
  const [frameSize, setFrameSize] = useState({ width: 0, height: 0 })

  const src = asset.real_render_path || asset.public_path || asset.fallback_path

  useEffect(() => {
    setZoom(1)
    setPan({ x: 0, y: 0 })
    setFitMode('contain')
  }, [asset.id])

  useEffect(() => {
    if (!frameRef.current) return

    const observer = new ResizeObserver((entries) => {
      const entry = entries[0]
      if (!entry) return
      const rect = entry.contentRect
      setFrameSize({ width: Math.round(rect.width), height: Math.round(rect.height) })
    })

    observer.observe(frameRef.current)
    return () => observer.disconnect()
  }, [])

  const setZoomSafe = (nextZoom: number) => {
    const z = clamp(Number(nextZoom.toFixed(2)), 1, 3)
    setZoom(z)
    if (z === 1) setPan({ x: 0, y: 0 })
  }

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (zoom <= 1) return
    event.currentTarget.setPointerCapture(event.pointerId)
    setDrag({ active: true, x: event.clientX, y: event.clientY })
  }

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (!drag.active || zoom <= 1) return

    const dx = event.clientX - drag.x
    const dy = event.clientY - drag.y
    setDrag({ active: true, x: event.clientX, y: event.clientY })

    setPan((current) => ({
      x: clamp(current.x + dx, -420, 420),
      y: clamp(current.y + dy, -300, 300),
    }))
  }

  const onPointerUp = (event: PointerEvent<HTMLDivElement>) => {
    if (drag.active) {
      event.currentTarget.releasePointerCapture(event.pointerId)
    }
    setDrag({ active: false, x: 0, y: 0 })
  }

  const onWheel = (event: WheelEvent<HTMLDivElement>) => {
    if (!event.ctrlKey) return
    event.preventDefault()
    const direction = event.deltaY < 0 ? 0.12 : -0.12
    setZoomSafe(zoom + direction)
  }

  const reset = () => {
    setZoom(1)
    setPan({ x: 0, y: 0 })
    setFitMode('contain')
  }

  return (
    <div className="v44-zoom-shell">
      <div className="v44-zoom-toolbar">
        <div>
          <strong>Interactive Asset Viewer</strong>
          <span>{frameSize.width}×{frameSize.height}px · {fitMode} · {zoom.toFixed(2)}x</span>
        </div>
        <div className="v44-zoom-actions">
          <button type="button" onClick={() => setFitMode(fitMode === 'contain' ? 'cover' : 'contain')}>
            Fit: {fitMode}
          </button>
          <button type="button" onClick={() => setZoomSafe(zoom - 0.25)} disabled={zoom <= 1}>
            −
          </button>
          <input
            aria-label="Image zoom"
            type="range"
            min="1"
            max="3"
            step="0.05"
            value={zoom}
            onChange={(event) => setZoomSafe(Number(event.target.value))}
          />
          <button type="button" onClick={() => setZoomSafe(zoom + 0.25)} disabled={zoom >= 3}>
            +
          </button>
          <button type="button" onClick={reset}>
            Reset
          </button>
        </div>
      </div>

      <div
        ref={frameRef}
        className={`v44-zoom-frame ${zoom > 1 ? 'v44-is-zoomed' : ''}`}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onWheel={onWheel}
        onDoubleClick={() => setZoomSafe(zoom > 1 ? 1 : 2)}
      >
        <img
          src={src}
          alt={asset.title}
          draggable={false}
          style={{
            objectFit: fitMode,
            transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`,
          }}
        />
      </div>

      <div className="v44-zoom-help">
        <span>Double click: quick zoom</span>
        <span>Drag: pan when zoomed</span>
        <span>Ctrl + wheel: precision zoom</span>
      </div>
    </div>
  )
}

export function VisualAssetRuntimeV41() {
  const [registry, setRegistry] = useState<VisualRegistryV41 | null>(null)
  const [error, setError] = useState<string>('')
  const [selectedId, setSelectedId] = useState<string>('')

  useEffect(() => {
    let alive = true

    fetch(registryUrl, { cache: 'no-cache' })
      .then((response) => {
        if (!response.ok) throw new Error(`registry HTTP ${response.status}`)
        return response.json()
      })
      .then((data: VisualRegistryV41) => {
        if (!alive) return
        setRegistry(data)
        setSelectedId(data.assets?.[0]?.id ?? '')
      })
      .catch((err: Error) => {
        if (!alive) return
        setError(err.message)
      })

    return () => {
      alive = false
    }
  }, [])

  const assets = registry?.assets ?? []

  const selected = useMemo(() => {
    return assets.find((asset) => asset.id === selectedId) ?? assets[0]
  }, [assets, selectedId])

  const readyCount = assets.length
  const fallbackCount = assets.filter((asset) => asset.source_mode === 'fallback').length
  const realRenderCount = assets.filter((asset) => asset.source_mode === 'real-render').length
  const replaceableCount = assets.filter((asset) => asset.replaceable).length

  return (
    <section className="v41-visual-shell v44-enhanced-visual-shell">
      <div className="v41-visual-header">
        <div>
          <p>V44 VISUAL ASSET ZOOM / AUTOFIT · V41 RUNTIME BINDING</p>
          <h2>Visual Knowledge / Render Asset Layer</h2>
          <span>
            Registry-driven asset layer with responsive sizing, contain/cover fit, zoom and pan.
          </span>
        </div>
        <div className="v41-visual-score">
          <strong>{readyCount}</strong>
          <small>assets bound</small>
        </div>
      </div>

      {error ? (
        <div className="v41-error">
          <strong>Registry load error</strong>
          <span>{error}</span>
        </div>
      ) : null}

      <div className="v41-visual-metrics">
        <article>
          <span>Registry</span>
          <strong>{registry?.operation ?? 'loading'}</strong>
        </article>
        <article>
          <span>Fallback</span>
          <strong>{fallbackCount}</strong>
        </article>
        <article>
          <span>Real Render</span>
          <strong>{realRenderCount}</strong>
        </article>
        <article>
          <span>Replaceable</span>
          <strong>{replaceableCount}</strong>
        </article>
      </div>

      <div className="v41-visual-layout v44-visual-layout">
        <div className="v41-asset-grid">
          {assets.map((asset) => (
            <button
              key={asset.id}
              type="button"
              className={`v41-asset-card ${selected?.id === asset.id ? 'v41-asset-selected' : ''}`}
              onClick={() => setSelectedId(asset.id)}
            >
              <span>{domainForAsset(asset)}</span>
              <strong>{asset.title}</strong>
              <small>{asset.source_mode.toUpperCase()}</small>
            </button>
          ))}
        </div>

        {selected ? (
          <aside className="v41-asset-detail v44-asset-detail">
            <VisualZoomViewer asset={selected} />

            <div className="v41-asset-info">
              <div className="v41-detail-top">
                <span>{domainForAsset(selected)}</span>
                <strong>{selected.source_mode.toUpperCase()}</strong>
              </div>

              <h3>{selected.title}</h3>
              <p>{selected.description}</p>

              <div className="v41-path-box">
                <span>runtime fallback</span>
                <code>{selected.fallback_path}</code>
              </div>

              <div className="v41-path-box">
                <span>active real render path</span>
                <code>{selected.real_render_path || selected.public_path || selected.expected_real_render_path}</code>
              </div>

              <div className="v41-binding-grid">
                <article>
                  <span>Scenario</span>
                  <strong>{scenarioForAsset(selected)}</strong>
                </article>
                <article>
                  <span>Category</span>
                  <strong>{selected.category}</strong>
                </article>
                <article>
                  <span>Replaceable</span>
                  <strong>{selected.replaceable ? 'yes' : 'no'}</strong>
                </article>
                <article>
                  <span>Usage</span>
                  <strong>{selected.usage.join(' · ')}</strong>
                </article>
              </div>

              <div className="v41-tags">
                {selected.tags.map((tag) => (
                  <span key={`${selected.id}-${tag}`}>{tag}</span>
                ))}
              </div>
            </div>
          </aside>
        ) : (
          <aside className="v41-asset-detail">
            <div className="v41-asset-info">
              <h3>Loading visual registry…</h3>
              <p>Waiting for {registryUrl}</p>
            </div>
          </aside>
        )}
      </div>
    </section>
  )
}
""".strip() + "\n", encoding="utf-8")

styles = STYLES.read_text(encoding="utf-8")
if "TRFMC V44 VISUAL ASSET ZOOM AUTOFIT" not in styles:
    STYLES.write_text(styles + r"""

/* === TRFMC V44 VISUAL ASSET ZOOM AUTOFIT === */
.v44-enhanced-visual-shell{
  scroll-margin-top:16px;
}

.v44-visual-layout{
  grid-template-columns:minmax(320px,.68fr) minmax(640px,1.32fr);
}

.v44-asset-detail{
  grid-template-columns:minmax(520px,1.22fr) minmax(320px,.78fr);
}

.v44-zoom-shell{
  min-width:0;
  display:flex;
  flex-direction:column;
  gap:8px;
}

.v44-zoom-toolbar{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  padding:9px 10px;
  border-radius:14px;
  border:1px solid rgba(117,234,255,.18);
  background:rgba(1,8,15,.58);
}

.v44-zoom-toolbar strong{
  display:block;
  color:var(--trfmc-text, #f1fbff);
  font-size:12px;
  letter-spacing:.05em;
  text-transform:uppercase;
}

.v44-zoom-toolbar span{
  display:block;
  color:var(--trfmc-muted, #9ab5c9);
  font-size:11px;
  margin-top:2px;
}

.v44-zoom-actions{
  display:flex;
  align-items:center;
  gap:6px;
  flex-wrap:wrap;
  justify-content:flex-end;
}

.v44-zoom-actions button{
  border:1px solid rgba(117,234,255,.24);
  border-radius:999px;
  background:rgba(8,25,42,.72);
  color:var(--trfmc-cyan, #75eaff);
  font-size:11px;
  font-weight:900;
  padding:6px 10px;
  cursor:pointer;
}

.v44-zoom-actions button:disabled{
  opacity:.35;
  cursor:not-allowed;
}

.v44-zoom-actions input[type="range"]{
  width:118px;
  accent-color:var(--trfmc-cyan, #75eaff);
}

.v44-zoom-frame{
  position:relative;
  width:100%;
  min-height:420px;
  max-height:62vh;
  aspect-ratio:16 / 9;
  overflow:hidden;
  border-radius:18px;
  border:1px solid rgba(117,234,255,.22);
  background:
    radial-gradient(circle at 50% 50%,rgba(117,234,255,.10),transparent 42%),
    linear-gradient(135deg,rgba(1,8,15,.92),rgba(4,18,32,.92));
  cursor:zoom-in;
  touch-action:none;
  user-select:none;
}

.v44-zoom-frame.v44-is-zoomed{
  cursor:grab;
}

.v44-zoom-frame.v44-is-zoomed:active{
  cursor:grabbing;
}

.v44-zoom-frame img{
  width:100%;
  height:100%;
  display:block;
  object-position:center center;
  transform-origin:center center;
  transition:transform .16s ease, object-fit .16s ease;
  will-change:transform;
  user-select:none;
  -webkit-user-drag:none;
  image-rendering:auto;
}

.v44-zoom-help{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
}

.v44-zoom-help span{
  border:1px solid rgba(117,234,255,.15);
  border-radius:999px;
  padding:5px 8px;
  background:rgba(117,234,255,.07);
  color:var(--trfmc-muted, #9ab5c9);
  font-size:10px;
  font-weight:800;
}

@media (max-width:1380px){
  .v44-visual-layout{
    grid-template-columns:1fr;
  }

  .v44-asset-detail{
    grid-template-columns:1fr;
  }

  .v44-zoom-frame{
    min-height:360px;
  }
}

@media (max-width:760px){
  .v44-zoom-toolbar{
    align-items:flex-start;
    flex-direction:column;
  }

  .v44-zoom-actions{
    justify-content:flex-start;
  }

  .v44-zoom-frame{
    min-height:260px;
    max-height:55vh;
  }
}
""", encoding="utf-8")

# Static checks
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

component_now = VISUAL_COMPONENT.read_text(encoding="utf-8")
styles_now = STYLES.read_text(encoding="utf-8")
registry_now = json.loads(ACTIVE_REGISTRY.read_text(encoding="utf-8"))
assets = registry_now.get("assets", [])
real_count = sum(1 for a in assets if a.get("source_mode") == "real-render")
review_count = sum(1 for a in assets if a.get("source_mode") == "real-render-review")
fallback_count = sum(1 for a in assets if a.get("source_mode") == "fallback")

ok("VisualZoomViewer present", "function VisualZoomViewer" in component_now)
ok("ResizeObserver used", "ResizeObserver" in component_now)
ok("objectFit dynamic fit mode used", "objectFit: fitMode" in component_now)
ok("transform scale used", "scale(${zoom})" in component_now)
ok("pointer pan handlers present", "onPointerDown" in component_now and "onPointerMove" in component_now)
ok("Ctrl wheel zoom present", "event.ctrlKey" in component_now)
ok("double click zoom present", "onDoubleClick" in component_now)
ok("V44 CSS present", "v44-zoom-frame" in styles_now)
ok("V42 still active", "RFOperationalDeckV42MissionLayoutOrchestrator" in MAIN.read_text(encoding="utf-8"))
ok("registry has active real renders", real_count >= 7)
ok("registry has no fallback active mode", fallback_count == 0)
ok("registry has no review active mode after V43D expected", review_count == 0 or real_count == 7)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build gate
build_log = RDIR / "npm_build_v44.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)
build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result == "FAIL":
    print(build_log.read_text(errors="ignore")[-8000:])

# HTTP gate
http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png",
    "http://127.0.0.1:4181/api/mission/status",
]

lines = ["url\tstatus\tbytes"]
for url in urls:
    pr = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}\t%{size_download}", "--connect-timeout", "2", "--max-time", "8", url],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if pr.returncode != 0:
        code, size = "000", "0"
    else:
        parts = pr.stdout.strip().split()
        code = parts[0] if len(parts) > 0 else "000"
        size = parts[1] if len(parts) > 1 else "0"
    lines.append(f"{url}\t{code}\t{size}")

http_tsv.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(http_tsv.read_text())

http_non_200 = sum(1 for line in lines[1:] if line.split("\t")[1] != "200")
http_zero_bytes = sum(1 for line in lines[1:] if line.split("\t")[2] == "0")

rollback = RDIR / "rollback_v44_visual_asset_zoom_autofit.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/VisualAssetRuntimeV41.tsx.before_v44_{TS}" frontend/src/visual_assets/VisualAssetRuntimeV41.tsx
cp "{RDIR}/styles.css.before_v44_{TS}" frontend/src/styles.css
echo "Rollback V44 Visual Asset Zoom/Autofit completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "visual_asset_zoom_autofit_manifest_v44.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_ZOOM_AUTOFIT_V44",
    "strategy": "interactive_autofit_zoom_pan_viewer_for_visual_assets",
    "frontend_mutation": True,
    "static_public_asset_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "patched": [str(VISUAL_COMPONENT), str(STYLES)],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "features": [
        "object-fit contain/cover",
        "zoom range 1x-3x",
        "pointer pan",
        "ctrl-wheel zoom",
        "double-click quick zoom",
        "ResizeObserver frame sizing",
    ],
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_ZOOM_AUTOFIT_V44",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
    "patched_component": str(VISUAL_COMPONENT),
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
    "frontend/src/styles.css",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_visual_asset_zoom_autofit_v44"
latest_r = ROOT / "runtime/releases/latest_visual_asset_zoom_autofit_v44"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
