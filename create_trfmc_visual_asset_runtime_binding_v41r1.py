from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_VISUAL_ASSET_RUNTIME_BINDING_V41R1_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_VISUAL_ASSET_RUNTIME_BINDING_V41R1_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_VISUAL_ASSET_RUNTIME_BINDING_V41R1_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
STYLES = ROOT / "frontend/src/styles.css"

VISUAL_DIR = ROOT / "frontend/src/visual_assets"
VISUAL_COMPONENT = VISUAL_DIR / "VisualAssetRuntimeV41.tsx"
WRAPPER = ROOT / "frontend/src/rf_instruments/instruments/RFOperationalDeckV41VisualAssetFusion.tsx"

REGISTRY = ROOT / "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
VISUAL_DIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC VISUAL ASSET RUNTIME BINDING V41R1")
print("registry-driven visual layer · above V40 · fallback-aware")
print("=" * 60)

# Preconditions
for rel in [
    "runtime/quality/latest_visual_asset_scaffold_v41b/summary.json",
    "runtime/quality/latest_scenario_knowledge_binding_v40/summary.json",
    "runtime/quality/latest_navigation_map_v39r1/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not MAIN.exists():
    raise SystemExit("ERRORE: main.tsx mancante")
if not STYLES.exists():
    raise SystemExit("ERRORE: styles.css mancante")
if not REGISTRY.exists():
    raise SystemExit("ERRORE: registry V41 fallback mancante")

main_txt = MAIN.read_text(encoding="utf-8")

if "RFOperationalDeckV41VisualAssetFusion" in main_txt:
    active_state = "already_v41"
elif "RFOperationalDeckV40ScenarioKnowledgeFusion" in main_txt:
    active_state = "v40_ready"
else:
    print("ERRORE: main.tsx non monta V40/V41")
    print("\n".join([line for line in main_txt.splitlines() if "RFOperationalDeck" in line]))
    raise SystemExit(1)

print(f"OK: active_state={active_state}")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:4181/api/mission/status"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0 or "TRFMC_READONLY_BACKEND_BRIDGE_V28" not in probe.stdout:
    raise SystemExit("ERRORE: API 4181 non operative")

asset_probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if asset_probe.returncode != 0 or "TRFMC_VISUAL_ASSET_SCAFFOLD_V41B" not in asset_probe.stdout:
    raise SystemExit("ERRORE: registry V41 non servito correttamente da Vite 5173")

print("OK: API 4181 live e registry V41 servito da 5173")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_VISUAL_ASSET_RUNTIME_BINDING_V41R1_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/app/main.tsx",
    "frontend/src/styles.css",
    "frontend/src/visual_assets",
    "frontend/src/rf_instruments/instruments",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

(RDIR / f"main.tsx.before_v41r1_{TS}").write_text(main_txt, encoding="utf-8")
(RDIR / f"styles.css.before_v41r1_{TS}").write_text(STYLES.read_text(encoding="utf-8"), encoding="utf-8")

VISUAL_COMPONENT.write_text(r"""
import { useEffect, useMemo, useState } from 'react'

type VisualAssetV41 = {
  id: string
  title: string
  description: string
  category: string
  public_path: string
  expected_real_render_path: string
  fallback_path: string
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

const registryUrl = '/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json'

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
  const replaceableCount = assets.filter((asset) => asset.replaceable).length

  return (
    <section className="v41-visual-shell">
      <div className="v41-visual-header">
        <div>
          <p>V41 VISUAL ASSET RUNTIME BINDING</p>
          <h2>Visual Knowledge / Render Asset Layer</h2>
          <span>
            Registry-driven asset layer: fallback SVG today, replaceable with real render/3D assets later.
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
          <span>Replaceable</span>
          <strong>{replaceableCount}</strong>
        </article>
        <article>
          <span>Format</span>
          <strong>{registry?.fallback_format ?? 'svg'}</strong>
        </article>
      </div>

      <div className="v41-visual-layout">
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
          <aside className="v41-asset-detail">
            <div className="v41-asset-preview">
              <img src={selected.fallback_path || selected.public_path} alt={selected.title} />
            </div>

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
                <span>future real render path</span>
                <code>{selected.expected_real_render_path}</code>
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

WRAPPER.write_text(r"""
import { VisualAssetRuntimeV41 } from '../../visual_assets/VisualAssetRuntimeV41'
import { RFOperationalDeckV40ScenarioKnowledgeFusion } from './RFOperationalDeckV40ScenarioKnowledgeFusion'

export function RFOperationalDeckV41VisualAssetFusion() {
  return (
    <>
      <VisualAssetRuntimeV41 />
      <RFOperationalDeckV40ScenarioKnowledgeFusion />
    </>
  )
}
""".strip() + "\n", encoding="utf-8")

styles = STYLES.read_text(encoding="utf-8")
if "TRFMC V41 VISUAL ASSET RUNTIME" not in styles:
    STYLES.write_text(styles + r"""

/* === TRFMC V41 VISUAL ASSET RUNTIME === */
.v41-visual-shell{
  margin:18px;
  padding:18px;
  border:1px solid var(--trfmc-border, rgba(117,234,255,.22));
  border-radius:var(--trfmc-radius-xl, 28px);
  background:var(--trfmc-gradient-shell, linear-gradient(135deg,rgba(2,9,17,.98),rgba(4,14,25,.98)));
  box-shadow:var(--trfmc-shadow-deep, 0 34px 95px rgba(0,0,0,.42)), inset 0 0 44px rgba(80,215,255,.045);
}

.v41-visual-shell::before{
  content:"";
  display:block;
  height:1px;
  margin:-4px 0 14px;
  background:linear-gradient(90deg,transparent,rgba(117,234,255,.45),rgba(141,255,189,.30),transparent);
}

.v41-visual-header{
  display:flex;
  justify-content:space-between;
  align-items:flex-start;
  gap:20px;
  margin-bottom:14px;
}

.v41-visual-header p{
  margin:0 0 6px;
  color:var(--trfmc-cyan, #75eaff);
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v41-visual-header h2{
  margin:0;
  color:var(--trfmc-text, #f1fbff);
  font-size:25px;
}

.v41-visual-header span{
  display:block;
  margin-top:8px;
  color:var(--trfmc-muted, #9ab5c9);
  font-size:13px;
}

.v41-visual-score{
  min-width:132px;
  padding:12px;
  border:1px solid var(--trfmc-border-green, rgba(141,255,189,.26));
  border-radius:var(--trfmc-radius-md, 16px);
  background:rgba(5,36,34,.58);
  text-align:center;
}

.v41-visual-score strong{
  display:block;
  color:var(--trfmc-green, #8dffbd);
  font-size:25px;
}

.v41-visual-score small{
  color:#9bb7a9;
}

.v41-error{
  margin-bottom:12px;
  padding:12px;
  border-radius:16px;
  border:1px solid rgba(255,120,144,.35);
  background:rgba(55,8,18,.45);
  color:var(--trfmc-red, #ff7890);
}

.v41-error strong,
.v41-error span{
  display:block;
}

.v41-visual-metrics{
  display:grid;
  grid-template-columns:repeat(4,minmax(0,1fr));
  gap:10px;
  margin-bottom:14px;
}

.v41-visual-metrics article{
  padding:10px;
  border-radius:16px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(8,25,42,.62);
}

.v41-visual-metrics span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:5px;
}

.v41-visual-metrics strong{
  color:var(--trfmc-green, #8dffbd);
  font-size:13px;
  word-break:break-word;
}

.v41-visual-layout{
  display:grid;
  grid-template-columns:minmax(0,.82fr) minmax(500px,1.18fr);
  gap:14px;
}

.v41-asset-grid{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:10px;
  align-content:start;
}

.v41-asset-card{
  min-height:104px;
  text-align:left;
  padding:13px;
  border-radius:18px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(8,25,42,.62);
  cursor:pointer;
}

.v41-asset-card span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:7px;
}

.v41-asset-card strong{
  display:block;
  color:var(--trfmc-text, #f1fbff);
  font-size:15px;
  line-height:1.1;
}

.v41-asset-card small{
  display:inline-block;
  margin-top:10px;
  padding:4px 8px;
  border-radius:999px;
  color:var(--trfmc-amber, #ffd37b);
  background:rgba(255,211,123,.12);
  font-weight:900;
  font-size:10px;
}

.v41-asset-selected{
  border-color:rgba(117,234,255,.42);
  box-shadow:0 0 24px rgba(117,234,255,.16);
}

.v41-asset-detail{
  display:grid;
  grid-template-columns:minmax(260px,.92fr) minmax(0,1.08fr);
  gap:12px;
  padding:14px;
  border-radius:22px;
  border:1px solid rgba(117,234,255,.18);
  background:rgba(5,17,31,.76);
}

.v41-asset-preview{
  min-height:330px;
  border-radius:18px;
  overflow:hidden;
  border:1px solid rgba(117,234,255,.18);
  background:rgba(1,8,15,.58);
}

.v41-asset-preview img{
  width:100%;
  height:100%;
  object-fit:cover;
  display:block;
}

.v41-asset-info{
  min-width:0;
}

.v41-detail-top{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:12px;
  margin-bottom:10px;
}

.v41-detail-top span,
.v41-path-box span,
.v41-binding-grid article span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:5px;
}

.v41-detail-top strong{
  border-radius:999px;
  padding:5px 9px;
  color:var(--trfmc-amber, #ffd37b);
  background:rgba(255,211,123,.12);
  font-size:10px;
  font-weight:900;
}

.v41-asset-info h3{
  margin:0 0 8px;
  color:var(--trfmc-text, #f1fbff);
  font-size:24px;
}

.v41-asset-info p{
  color:var(--trfmc-muted, #9ab5c9);
  line-height:1.45;
}

.v41-path-box{
  margin:9px 0;
  padding:9px 10px;
  border-radius:13px;
  border:1px solid rgba(117,234,255,.14);
  background:rgba(1,8,15,.52);
}

.v41-path-box code{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:11px;
  word-break:break-all;
}

.v41-binding-grid{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:9px;
  margin-top:11px;
}

.v41-binding-grid article{
  padding:9px;
  border-radius:13px;
  border:1px solid rgba(141,255,189,.14);
  background:rgba(7,31,31,.48);
}

.v41-binding-grid article strong{
  color:var(--trfmc-green, #8dffbd);
  font-size:12px;
}

.v41-tags{
  display:flex;
  flex-wrap:wrap;
  gap:6px;
  margin-top:12px;
}

.v41-tags span{
  border-radius:999px;
  padding:5px 8px;
  color:var(--trfmc-text, #f1fbff);
  background:rgba(117,234,255,.10);
  border:1px solid rgba(117,234,255,.16);
  font-size:10px;
  font-weight:800;
}

@media (max-width:1250px){
  .v41-visual-layout{grid-template-columns:1fr}
  .v41-asset-detail{grid-template-columns:1fr}
}

@media (max-width:760px){
  .v41-visual-header{flex-direction:column}
  .v41-visual-metrics{grid-template-columns:1fr 1fr}
  .v41-asset-grid{grid-template-columns:1fr}
  .v41-binding-grid{grid-template-columns:1fr}
}
""", encoding="utf-8")

# Patch main
main_txt = MAIN.read_text(encoding="utf-8")
old_import = "import { RFOperationalDeckV40ScenarioKnowledgeFusion } from '../rf_instruments/instruments/RFOperationalDeckV40ScenarioKnowledgeFusion'"
new_import = "import { RFOperationalDeckV41VisualAssetFusion } from '../rf_instruments/instruments/RFOperationalDeckV41VisualAssetFusion'"

if new_import not in main_txt:
    if old_import not in main_txt and "RFOperationalDeckV41VisualAssetFusion" not in main_txt:
        raise SystemExit("ERRORE: import V40 non trovato in main.tsx")
    main_txt = main_txt.replace(old_import, new_import, 1)

main_txt = main_txt.replace("<RFOperationalDeckV40ScenarioKnowledgeFusion />", "<RFOperationalDeckV41VisualAssetFusion />")
MAIN.write_text(main_txt, encoding="utf-8")

# Checks
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

main_now = MAIN.read_text(encoding="utf-8")
styles_now = STYLES.read_text(encoding="utf-8")
component_now = VISUAL_COMPONENT.read_text(encoding="utf-8")
wrapper_now = WRAPPER.read_text(encoding="utf-8")

ok("VisualAssetRuntimeV41.tsx exists", VISUAL_COMPONENT.exists())
ok("RFOperationalDeckV41VisualAssetFusion.tsx exists", WRAPPER.exists())
ok("main imports/mounts V41", "RFOperationalDeckV41VisualAssetFusion" in main_now)
ok("main JSX mounts V41", "<RFOperationalDeckV41VisualAssetFusion />" in main_now)
ok("V40 preserved below V41", "RFOperationalDeckV40ScenarioKnowledgeFusion" in wrapper_now)
ok("VisualAssetRuntimeV41 export exists", "export function VisualAssetRuntimeV41" in component_now)
ok("registry fetch present", "visual_asset_registry_v41_fallback.json" in component_now)
ok("fallback image render present", "<img" in component_now)
ok("V41 CSS present", "v41-visual-shell" in styles_now)
ok("no iframe in V41 visual component", "<iframe" not in component_now.lower())

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())
miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build
build_log = RDIR / "npm_build_v41r1.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)
build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result == "FAIL":
    print(build_log.read_text(errors="ignore")[-6000:])

# HTTP gate
http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/03_antennas_types/beamwidth_narrow_wide.svg",
    "http://127.0.0.1:4181/api/mission/status",
    "http://127.0.0.1:4181/api/rfpro/spectrum/sweep",
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

rollback = RDIR / "rollback_v41r1_visual_asset_runtime_binding.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/main.tsx.before_v41r1_{TS}" frontend/src/app/main.tsx
cp "{RDIR}/styles.css.before_v41r1_{TS}" frontend/src/styles.css
rm -rf frontend/src/visual_assets
rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV41VisualAssetFusion.tsx
echo "Rollback V41R1 Visual Asset Runtime Binding completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "visual_asset_runtime_binding_manifest_v41r1.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_RUNTIME_BINDING_V41R1",
    "strategy": "registry_driven_visual_asset_layer_above_v40",
    "frontend_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "created": [str(VISUAL_COMPONENT), str(WRAPPER)],
    "patched": [str(MAIN), str(STYLES)],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "registry": "/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json",
    "preserves": "RFOperationalDeckV40ScenarioKnowledgeFusion",
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_RUNTIME_BINDING_V41R1",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_mount": "RFOperationalDeckV41VisualAssetFusion",
    "preserves": "RFOperationalDeckV40ScenarioKnowledgeFusion",
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/src/app/main.tsx",
    "frontend/src/styles.css",
    "frontend/src/visual_assets",
    "frontend/src/rf_instruments/instruments/RFOperationalDeckV41VisualAssetFusion.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_visual_asset_runtime_binding_v41r1"
latest_r = ROOT / "runtime/releases/latest_visual_asset_runtime_binding_v41r1"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
