from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_MISSION_LAYOUT_ORCHESTRATOR_V42_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_MISSION_LAYOUT_ORCHESTRATOR_V42_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_MISSION_LAYOUT_ORCHESTRATOR_V42_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
STYLES = ROOT / "frontend/src/styles.css"

ORCH_DIR = ROOT / "frontend/src/layout_orchestrator"
ORCH_COMPONENT = ORCH_DIR / "MissionLayoutOrchestratorV42.tsx"
WRAPPER = ROOT / "frontend/src/rf_instruments/instruments/RFOperationalDeckV42MissionLayoutOrchestrator.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
ORCH_DIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC MISSION LAYOUT ORCHESTRATOR V42")
print("section switch · compact view · full engineering view · above V41")
print("=" * 60)

for rel in [
    "runtime/quality/latest_visual_asset_runtime_binding_v41r1/summary.json",
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

main_txt = MAIN.read_text(encoding="utf-8")
if "RFOperationalDeckV42MissionLayoutOrchestrator" in main_txt:
    active_state = "already_v42"
elif "RFOperationalDeckV41VisualAssetFusion" in main_txt:
    active_state = "v41_ready"
else:
    print("ERRORE: main.tsx non monta V41/V42")
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
    raise SystemExit("ERRORE: registry asset V41 non raggiungibile")

print("OK: API 4181 live e asset registry servito da Vite")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_MISSION_LAYOUT_ORCHESTRATOR_V42_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/app/main.tsx",
    "frontend/src/styles.css",
    "frontend/src/layout_orchestrator",
    "frontend/src/rf_instruments/instruments",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

(RDIR / f"main.tsx.before_v42_{TS}").write_text(main_txt, encoding="utf-8")
(RDIR / f"styles.css.before_v42_{TS}").write_text(STYLES.read_text(encoding="utf-8"), encoding="utf-8")

ORCH_COMPONENT.write_text(r"""
import { useMemo, useState } from 'react'
import { VisualAssetRuntimeV41 } from '../visual_assets/VisualAssetRuntimeV41'
import { ScenarioKnowledgeBindingV40 } from '../knowledge_binding/ScenarioKnowledgeBindingV40'
import { NavigationMapV39 } from '../navigation/NavigationMapV39'
import { CommandCenterFusionV37 } from '../command_center/CommandCenterFusionV37'
import { RFDynamicScenarioDeckV36 } from '../rf_scenarios/RFDynamicScenarioDeckV36'
import { RFOperationalDeckV41VisualAssetFusion } from '../rf_instruments/instruments/RFOperationalDeckV41VisualAssetFusion'

type SectionIdV42 =
  | 'mission'
  | 'visual-assets'
  | 'knowledge'
  | 'navigation'
  | 'command'
  | 'scenarios'
  | 'full-engineering'

type SectionV42 = {
  id: SectionIdV42
  title: string
  subtitle: string
  badge: string
  priority: 'executive' | 'engineering' | 'deep'
}

const sections: SectionV42[] = [
  {
    id: 'mission',
    title: 'Mission Overview',
    subtitle: 'Vista compatta dello stato portale e della catena V42→V41→V40→V39→V37.',
    badge: 'compact',
    priority: 'executive',
  },
  {
    id: 'visual-assets',
    title: 'Visual Assets',
    subtitle: 'Registry visuale, fallback SVG, asset sostituibili con render reali.',
    badge: 'V41',
    priority: 'engineering',
  },
  {
    id: 'knowledge',
    title: 'Scenario Knowledge',
    subtitle: 'Dominio → scenario → teoria → formule → strumenti → evidenze.',
    badge: 'V40',
    priority: 'engineering',
  },
  {
    id: 'navigation',
    title: 'Navigation Architecture',
    subtitle: 'Mappa ufficiale dei 12 domini del portale.',
    badge: 'V39',
    priority: 'executive',
  },
  {
    id: 'command',
    title: 'Command Center',
    subtitle: 'Mission Control, live contracts e health dei domini principali.',
    badge: 'V37',
    priority: 'executive',
  },
  {
    id: 'scenarios',
    title: 'Dynamic Scenarios',
    subtitle: 'Motore dinamico RF/Telco/Antenna con layer visivi e hotspot.',
    badge: 'V36',
    priority: 'deep',
  },
  {
    id: 'full-engineering',
    title: 'Full Engineering Stack',
    subtitle: 'Vista completa legacy-safe: tutti i layer V41/V40/V39/V37/V36 in sequenza.',
    badge: 'FULL',
    priority: 'deep',
  },
]

function MissionCompactOverview() {
  return (
    <section className="v42-compact-overview">
      <div className="v42-overview-grid">
        <article>
          <span>Active Mount</span>
          <strong>RFOperationalDeckV42MissionLayoutOrchestrator</strong>
        </article>
        <article>
          <span>Preserved Stack</span>
          <strong>V41 → V40 → V39 → V37 → V36</strong>
        </article>
        <article>
          <span>Runtime</span>
          <strong>8000 / 4181 / 5173</strong>
        </article>
        <article>
          <span>Safety</span>
          <strong>read-only contracts · no iframe · no backend mutation</strong>
        </article>
      </div>

      <div className="v42-flow">
        <div>V42<br /><small>Orchestrator</small></div>
        <i />
        <div>V41<br /><small>Visual Assets</small></div>
        <i />
        <div>V40<br /><small>Knowledge</small></div>
        <i />
        <div>V39<br /><small>Navigation</small></div>
        <i />
        <div>V37<br /><small>Command</small></div>
        <i />
        <div>V36<br /><small>Scenarios</small></div>
      </div>

      <div className="v42-executive-note">
        <h3>Mission layout objective</h3>
        <p>
          Questa vista evita lo stack verticale infinito: seleziona un layer operativo alla volta,
          mantenendo disponibile la vista completa quando serve fare debug o revisione ingegneristica.
        </p>
      </div>
    </section>
  )
}

export function MissionLayoutOrchestratorV42() {
  const [active, setActive] = useState<SectionIdV42>('mission')

  const activeSection = useMemo(() => {
    return sections.find((section) => section.id === active) ?? sections[0]
  }, [active])

  return (
    <section className="v42-orchestrator-shell">
      <div className="v42-orchestrator-header">
        <div>
          <p>V42 MISSION LAYOUT ORCHESTRATOR</p>
          <h2>TRFMC Mission Control Layout</h2>
          <span>
            Section switch, compact executive view and full engineering stack on demand.
          </span>
        </div>
        <div className="v42-orchestrator-score">
          <strong>{sections.length}</strong>
          <small>sections</small>
        </div>
      </div>

      <div className="v42-layout">
        <nav className="v42-section-rail" aria-label="TRFMC section selector">
          {sections.map((section) => (
            <button
              key={section.id}
              type="button"
              className={active === section.id ? 'v42-section-active' : ''}
              onClick={() => setActive(section.id)}
            >
              <span>{section.badge}</span>
              <strong>{section.title}</strong>
              <small>{section.priority}</small>
            </button>
          ))}
        </nav>

        <main className="v42-section-stage">
          <div className="v42-stage-heading">
            <div>
              <span>{activeSection.badge}</span>
              <h3>{activeSection.title}</h3>
              <p>{activeSection.subtitle}</p>
            </div>
            <strong>{activeSection.priority}</strong>
          </div>

          {active === 'mission' ? <MissionCompactOverview /> : null}
          {active === 'visual-assets' ? <VisualAssetRuntimeV41 /> : null}
          {active === 'knowledge' ? <ScenarioKnowledgeBindingV40 /> : null}
          {active === 'navigation' ? <NavigationMapV39 /> : null}
          {active === 'command' ? <CommandCenterFusionV37 /> : null}
          {active === 'scenarios' ? <RFDynamicScenarioDeckV36 /> : null}
          {active === 'full-engineering' ? <RFOperationalDeckV41VisualAssetFusion /> : null}
        </main>
      </div>
    </section>
  )
}
""".strip() + "\n", encoding="utf-8")

WRAPPER.write_text(r"""
import { MissionLayoutOrchestratorV42 } from '../../layout_orchestrator/MissionLayoutOrchestratorV42'

export function RFOperationalDeckV42MissionLayoutOrchestrator() {
  return <MissionLayoutOrchestratorV42 />
}
""".strip() + "\n", encoding="utf-8")

styles = STYLES.read_text(encoding="utf-8")
if "TRFMC V42 MISSION LAYOUT ORCHESTRATOR" not in styles:
    STYLES.write_text(styles + r"""

/* === TRFMC V42 MISSION LAYOUT ORCHESTRATOR === */
.v42-orchestrator-shell{
  margin:18px;
  padding:18px;
  border:1px solid var(--trfmc-border, rgba(117,234,255,.22));
  border-radius:var(--trfmc-radius-xl, 28px);
  background:
    radial-gradient(circle at 8% 0%,rgba(117,234,255,.16),transparent 34%),
    radial-gradient(circle at 92% 8%,rgba(141,255,189,.10),transparent 30%),
    linear-gradient(135deg,rgba(2,9,17,.99),rgba(4,14,25,.99));
  box-shadow:var(--trfmc-shadow-deep, 0 34px 95px rgba(0,0,0,.42)), inset 0 0 44px rgba(80,215,255,.045);
}

.v42-orchestrator-shell::before{
  content:"";
  display:block;
  height:1px;
  margin:-4px 0 14px;
  background:linear-gradient(90deg,transparent,rgba(117,234,255,.50),rgba(141,255,189,.32),transparent);
}

.v42-orchestrator-header{
  display:flex;
  justify-content:space-between;
  align-items:flex-start;
  gap:20px;
  margin-bottom:14px;
}

.v42-orchestrator-header p{
  margin:0 0 6px;
  color:var(--trfmc-cyan, #75eaff);
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v42-orchestrator-header h2{
  margin:0;
  color:var(--trfmc-text, #f1fbff);
  font-size:27px;
}

.v42-orchestrator-header span{
  display:block;
  margin-top:8px;
  color:var(--trfmc-muted, #9ab5c9);
  font-size:13px;
}

.v42-orchestrator-score{
  min-width:132px;
  padding:12px;
  border:1px solid var(--trfmc-border-green, rgba(141,255,189,.26));
  border-radius:var(--trfmc-radius-md, 16px);
  background:rgba(5,36,34,.58);
  text-align:center;
}

.v42-orchestrator-score strong{
  display:block;
  color:var(--trfmc-green, #8dffbd);
  font-size:26px;
}

.v42-orchestrator-score small{
  color:#9bb7a9;
}

.v42-layout{
  display:grid;
  grid-template-columns:280px minmax(0,1fr);
  gap:14px;
}

.v42-section-rail{
  display:flex;
  flex-direction:column;
  gap:9px;
  align-self:start;
  position:sticky;
  top:10px;
}

.v42-section-rail button{
  text-align:left;
  padding:12px;
  min-height:78px;
  border-radius:18px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(8,25,42,.62);
  cursor:pointer;
}

.v42-section-rail button span{
  display:inline-block;
  margin-bottom:6px;
  padding:3px 7px;
  border-radius:999px;
  color:var(--trfmc-cyan, #75eaff);
  background:rgba(117,234,255,.10);
  font-size:10px;
  font-weight:900;
}

.v42-section-rail button strong{
  display:block;
  color:var(--trfmc-text, #f1fbff);
  font-size:14px;
}

.v42-section-rail button small{
  color:var(--trfmc-muted, #9ab5c9);
  text-transform:uppercase;
  letter-spacing:.12em;
  font-size:10px;
}

.v42-section-rail button.v42-section-active{
  border-color:rgba(117,234,255,.44);
  box-shadow:0 0 24px rgba(117,234,255,.16);
  background:linear-gradient(135deg,rgba(8,35,55,.84),rgba(7,31,31,.72));
}

.v42-section-stage{
  min-width:0;
}

.v42-stage-heading{
  display:flex;
  justify-content:space-between;
  align-items:flex-start;
  gap:16px;
  margin-bottom:12px;
  padding:14px;
  border-radius:20px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(5,17,31,.72);
}

.v42-stage-heading span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.18em;
  text-transform:uppercase;
  margin-bottom:5px;
}

.v42-stage-heading h3{
  margin:0;
  color:var(--trfmc-text, #f1fbff);
  font-size:22px;
}

.v42-stage-heading p{
  margin:6px 0 0;
  color:var(--trfmc-muted, #9ab5c9);
}

.v42-stage-heading > strong{
  padding:5px 9px;
  border-radius:999px;
  color:var(--trfmc-green, #8dffbd);
  background:rgba(141,255,189,.12);
  font-size:10px;
  text-transform:uppercase;
}

.v42-compact-overview{
  padding:2px;
}

.v42-overview-grid{
  display:grid;
  grid-template-columns:repeat(4,minmax(0,1fr));
  gap:10px;
  margin-bottom:14px;
}

.v42-overview-grid article{
  padding:12px;
  border-radius:16px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(8,25,42,.62);
}

.v42-overview-grid span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:6px;
}

.v42-overview-grid strong{
  color:var(--trfmc-green, #8dffbd);
  font-size:13px;
}

.v42-flow{
  display:flex;
  flex-wrap:wrap;
  align-items:center;
  gap:10px;
  margin:14px 0;
  padding:14px;
  border-radius:20px;
  border:1px solid rgba(141,255,189,.18);
  background:rgba(7,31,31,.42);
}

.v42-flow div{
  min-width:120px;
  padding:10px;
  border-radius:14px;
  color:var(--trfmc-text, #f1fbff);
  background:rgba(1,8,15,.52);
  border:1px solid rgba(117,234,255,.16);
  text-align:center;
  font-weight:900;
}

.v42-flow small{
  color:var(--trfmc-muted, #9ab5c9);
  font-weight:500;
}

.v42-flow i{
  width:26px;
  height:2px;
  background:linear-gradient(90deg,var(--trfmc-cyan, #75eaff),var(--trfmc-green, #8dffbd));
  opacity:.8;
}

.v42-executive-note{
  padding:14px;
  border-radius:20px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(5,17,31,.72);
}

.v42-executive-note h3{
  margin:0 0 8px;
  color:var(--trfmc-text, #f1fbff);
}

.v42-executive-note p{
  margin:0;
  color:var(--trfmc-muted, #9ab5c9);
  line-height:1.5;
}

@media (max-width:1200px){
  .v42-layout{grid-template-columns:1fr}
  .v42-section-rail{position:static;display:grid;grid-template-columns:repeat(2,minmax(0,1fr))}
  .v42-overview-grid{grid-template-columns:repeat(2,minmax(0,1fr))}
}

@media (max-width:760px){
  .v42-orchestrator-header{flex-direction:column}
  .v42-section-rail{grid-template-columns:1fr}
  .v42-stage-heading{flex-direction:column}
  .v42-overview-grid{grid-template-columns:1fr}
}
""", encoding="utf-8")

# Patch main
main_txt = MAIN.read_text(encoding="utf-8")
old_import = "import { RFOperationalDeckV41VisualAssetFusion } from '../rf_instruments/instruments/RFOperationalDeckV41VisualAssetFusion'"
new_import = "import { RFOperationalDeckV42MissionLayoutOrchestrator } from '../rf_instruments/instruments/RFOperationalDeckV42MissionLayoutOrchestrator'"

if new_import not in main_txt:
    if old_import not in main_txt and "RFOperationalDeckV42MissionLayoutOrchestrator" not in main_txt:
        raise SystemExit("ERRORE: import V41 non trovato in main.tsx")
    main_txt = main_txt.replace(old_import, new_import, 1)

main_txt = main_txt.replace("<RFOperationalDeckV41VisualAssetFusion />", "<RFOperationalDeckV42MissionLayoutOrchestrator />")
MAIN.write_text(main_txt, encoding="utf-8")

# Checks
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

main_now = MAIN.read_text(encoding="utf-8")
styles_now = STYLES.read_text(encoding="utf-8")
component_now = ORCH_COMPONENT.read_text(encoding="utf-8")
wrapper_now = WRAPPER.read_text(encoding="utf-8")

ok("MissionLayoutOrchestratorV42.tsx exists", ORCH_COMPONENT.exists())
ok("RFOperationalDeckV42MissionLayoutOrchestrator.tsx exists", WRAPPER.exists())
ok("main imports/mounts V42", "RFOperationalDeckV42MissionLayoutOrchestrator" in main_now)
ok("main JSX mounts V42", "<RFOperationalDeckV42MissionLayoutOrchestrator />" in main_now)
ok("V41 preserved as full engineering option", "RFOperationalDeckV41VisualAssetFusion" in component_now)
ok("VisualAssetRuntimeV41 imported", "VisualAssetRuntimeV41" in component_now)
ok("ScenarioKnowledgeBindingV40 imported", "ScenarioKnowledgeBindingV40" in component_now)
ok("NavigationMapV39 imported", "NavigationMapV39" in component_now)
ok("CommandCenterFusionV37 imported", "CommandCenterFusionV37" in component_now)
ok("RFDynamicScenarioDeckV36 imported", "RFDynamicScenarioDeckV36" in component_now)
ok("V42 CSS present", "v42-orchestrator-shell" in styles_now)
ok("no iframe in V42 orchestrator", "<iframe" not in component_now.lower())

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())
miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build
build_log = RDIR / "npm_build_v42.log"
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
    "http://127.0.0.1:4181/api/mission/status",
    "http://127.0.0.1:4181/api/core/open5gs/status",
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

rollback = RDIR / "rollback_v42_mission_layout_orchestrator.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/main.tsx.before_v42_{TS}" frontend/src/app/main.tsx
cp "{RDIR}/styles.css.before_v42_{TS}" frontend/src/styles.css
rm -rf frontend/src/layout_orchestrator
rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV42MissionLayoutOrchestrator.tsx
echo "Rollback V42 Mission Layout Orchestrator completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "mission_layout_orchestrator_manifest_v42.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_MISSION_LAYOUT_ORCHESTRATOR_V42",
    "strategy": "section_orchestrator_to_avoid_vertical_stack_and_preserve_full_engineering_view",
    "frontend_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "created": [str(ORCH_COMPONENT), str(WRAPPER)],
    "patched": [str(MAIN), str(STYLES)],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
    "preserves_full_stack": "RFOperationalDeckV41VisualAssetFusion",
    "sections": ["mission", "visual-assets", "knowledge", "navigation", "command", "scenarios", "full-engineering"],
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_MISSION_LAYOUT_ORCHESTRATOR_V42",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
    "preserves": "RFOperationalDeckV41VisualAssetFusion",
    "sections_count": 7,
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
    "frontend/src/layout_orchestrator",
    "frontend/src/rf_instruments/instruments/RFOperationalDeckV42MissionLayoutOrchestrator.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_mission_layout_orchestrator_v42"
latest_r = ROOT / "runtime/releases/latest_mission_layout_orchestrator_v42"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
