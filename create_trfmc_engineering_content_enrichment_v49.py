from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")
OP = "TRFMC_ENGINEERING_CONTENT_ENRICHMENT_V49"

QDIR = ROOT / f"runtime/quality/{OP}_{TS}"
RDIR = ROOT / f"runtime/releases/{OP}_{TS}"
FREEZE = ROOT / f"runtime/freezes/{OP}_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
V42 = ROOT / "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS = ROOT / "frontend/src/styles.css"
ENRICH = ROOT / "frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print(OP)
print("engineering-grade enrichment · per-section KPI/meaning/live contract · no main.tsx mutation")
print("=" * 60)

print("\n=== PREFLIGHT ===")

for rel in [
    "runtime/quality/latest_content_quality_audit_v48/summary.json",
    "runtime/quality/latest_full_section_coverage_runtime_qa_v47/summary.json",
    "runtime/quality/latest_navigation_deeplink_runtime_qa_v46r1/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

for p in [MAIN, V42, CSS]:
    if not p.exists():
        raise SystemExit(f"ERRORE: file mancante: {p}")

main_before = MAIN.read_text(encoding="utf-8")
v42_before = V42.read_text(encoding="utf-8")
css_before = CSS.read_text(encoding="utf-8")

if "<MissionLayoutOrchestratorV42 />" not in main_before:
    raise SystemExit("ERRORE: main.tsx non monta MissionLayoutOrchestratorV42")

if "data-trfmc-v46-deeplink-index" not in v42_before:
    raise SystemExit("ERRORE: V46 deeplink index non presente")

if "const [active, setActive]" not in v42_before:
    raise SystemExit("ERRORE: active state non trovato in V42")

print("OK: V48/V47/V46R1 PASS, root V42, active section state presente")

(RDIR / f"MissionLayoutOrchestratorV42.tsx.before_v49_{TS}").write_text(v42_before, encoding="utf-8")
(RDIR / f"styles.css.before_v49_{TS}").write_text(css_before, encoding="utf-8")
if ENRICH.exists():
    (RDIR / f"EngineeringContentEnrichmentV49.tsx.before_v49_{TS}").write_text(ENRICH.read_text(encoding="utf-8"), encoding="utf-8")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_ENGINEERING_CONTENT_ENRICHMENT_V49_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/styles.css",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("\n=== WRITE V49 ENRICHMENT COMPONENT ===")

ENRICH.write_text(r'''
type EngineeringSectionV49 = {
  id: string
  title: string
  subtitle: string
  operationalMeaning: string
  liveContracts: string[]
  microKpis: Array<{ label: string; meaning: string; target: string }>
  engineeringFocus: string[]
  operatorActions: string[]
}

const sectionsV49: EngineeringSectionV49[] = [
  {
    id: 'mission-overview',
    title: 'Mission Overview · Operational State Interpretation',
    subtitle: 'Readiness, liveness and control-plane trust baseline for the entire TRFMC stack.',
    operationalMeaning:
      'This section translates raw service status into an operator-grade view: frontend reachability, backend bridge health, FastAPI liveness, runtime freshness and degradation surface.',
    liveContracts: ['/api/health', '/api/mission/status'],
    microKpis: [
      { label: 'Liveness', meaning: 'Portal/API path is reachable and returning non-empty payloads.', target: 'HTTP 200 · non-zero bytes' },
      { label: 'Bridge source', meaning: 'Identifies whether data comes from readonly backend bridge, synthetic contract or future live source.', target: 'source field present' },
      { label: 'Runtime freshness', meaning: 'Confirms that the view is not stale after root-mount or hash routing changes.', target: 'Chrome DOM + screenshot evidence' },
    ],
    engineeringFocus: ['mission state', 'runtime health', 'API reachability', 'evidence chain'],
    operatorActions: ['verify port 5173/4181/8000', 'check mission status JSON', 'preserve freeze + rollback path'],
  },
  {
    id: 'visual-assets',
    title: 'Visual Assets · RF Render Evidence Layer',
    subtitle: 'Registry-driven visual knowledge with zoom/autofit and real RF/Microwave render binding.',
    operationalMeaning:
      'This layer converts static raster material into controlled engineering assets: every render has a registry path, fallback path, source mode and runtime visibility evidence.',
    liveContracts: ['/trfmc_assets/visual_knowledge/visual_asset_registry_active.json'],
    microKpis: [
      { label: 'Real-render ratio', meaning: 'Counts assets served as real engineering renders rather than fallback SVG placeholders.', target: 'real-render active' },
      { label: 'Viewer usability', meaning: 'Confirms operator can inspect fine details with fit, zoom, pan and reset controls.', target: 'V44 DOM controls visible' },
      { label: 'Asset traceability', meaning: 'Validates public path, fallback path and RF/Microwave render path in DOM.', target: 'rf_microwave_engineering_lab.png visible' },
    ],
    engineeringFocus: ['RF bench render', 'zoom/pan inspection', 'asset registry', 'fallback safety net'],
    operatorActions: ['open #visual-assets', 'select RF/Microwave asset', 'test contain/cover + zoom + pan'],
  },
  {
    id: 'scenario-knowledge',
    title: 'Scenario Knowledge · RF/Telco Concept Binding',
    subtitle: 'Links dynamic scenarios to RF, antenna, spectrum, core network and operational knowledge.',
    operationalMeaning:
      'The objective is to make each scenario explain not only what is displayed, but why it matters operationally: measurement target, signal behavior, architecture dependency and training value.',
    liveContracts: ['/api/rfpro/spectrum/sweep', '/api/mission/status'],
    microKpis: [
      { label: 'Scenario coverage', meaning: 'Number of scenario-to-domain bindings visible in the knowledge layer.', target: 'all critical domains represented' },
      { label: 'Technical density', meaning: 'Presence of RF/Telco/Core vocabulary in DOM and screenshot evidence.', target: '>=3 technical hits' },
      { label: 'Binding mode', meaning: 'Differentiates live, contract, synthetic and future-live content.', target: 'mode explicitly visible' },
    ],
    engineeringFocus: ['RF propagation', 'antenna systems', 'spectrum analysis', '5G core procedures'],
    operatorActions: ['map each scenario to a lab objective', 'connect visual asset to measurement KPI', 'flag missing live contracts'],
  },
  {
    id: 'navigation-architecture',
    title: 'Navigation Architecture · SPA Control Plane',
    subtitle: 'Hash-routed section control for deterministic local operation and reproducible QA.',
    operationalMeaning:
      'This section makes the portal behave like an operator console: every major domain is bookmarkable, testable, screenshotable and independently verifiable.',
    liveContracts: ['/#mission-overview', '/#visual-assets', '/#command-center', '/#dynamic-scenarios'],
    microKpis: [
      { label: 'Deep-link coverage', meaning: 'Every section can be opened directly by URL hash.', target: '7/7 primary sections' },
      { label: 'DOM determinism', meaning: 'Each hash renders the expected branch in Chrome headless.', target: 'DOM written per section' },
      { label: 'Navigation stability', meaning: 'Root mount remains V42 while section state changes via hash routing.', target: 'main.tsx unchanged after V46' },
    ],
    engineeringFocus: ['hash routing', 'section state', 'runtime QA', 'operator navigation'],
    operatorActions: ['test all # links', 'capture DOM/screenshots', 'avoid uncontrolled main.tsx rewrites'],
  },
  {
    id: 'command-center',
    title: 'Command Center · Live Contract Interpretation',
    subtitle: 'Mission cards for backend bridge, Open5GS, UERANSIM, RF bandplan, spectrum and SOC/NOC state.',
    operationalMeaning:
      'The command center is the bridge between raw API contracts and operational interpretation: a not-running service is not simply an error, but a readiness state with diagnostic meaning.',
    liveContracts: ['/api/mission/status', '/api/core/open5gs/status', '/api/ran/ueransim/status', '/api/rfpro/spectrum/sweep'],
    microKpis: [
      { label: 'Core readiness', meaning: 'Open5GS process and endpoint readiness, including not-running/not-detected as a valid diagnostic state.', target: 'readiness visible' },
      { label: 'RAN simulation state', meaning: 'UERANSIM/gNB/UE simulation status and future live attach correlation.', target: 'ran status visible' },
      { label: 'RF contract state', meaning: 'Spectrum sweep source, contract version and data-source classification.', target: 'contract_version visible' },
    ],
    engineeringFocus: ['Open5GS', 'UERANSIM', '5G Core', 'RAN simulation', 'SOC/NOC'],
    operatorActions: ['read source fields', 'differentiate live/synthetic data', 'correlate core/RAN/RF alarms'],
  },
  {
    id: 'dynamic-scenarios',
    title: 'Dynamic Scenarios · RF/Telco Runtime Laboratory',
    subtitle: 'Scenario engine for electronics, microstrip, antenna, tower, beamwidth, RF lab and UAV ISR contexts.',
    operationalMeaning:
      'Dynamic scenarios turn the portal into a teaching and analysis console: each scene should expose physical meaning, measurement target, expected signal behavior and operator action.',
    liveContracts: ['/api/rfpro/spectrum/sweep', '/api/mission/status'],
    microKpis: [
      { label: 'Scenario count', meaning: 'Number of operational scenarios bound to the runtime deck.', target: '>=7 scenario families' },
      { label: 'RF measurement relevance', meaning: 'Each scenario should map to spectrum, antenna, link or signal-analysis meaning.', target: 'RF/Telco terms visible' },
      { label: 'Training utility', meaning: 'Scenario can be used as lesson plan, NOC simulation or lab evidence prompt.', target: 'operator workflow present' },
    ],
    engineeringFocus: ['microstrip patch', 'beamwidth', 'tower infrastructure', 'UAV RF links', 'spectrum lab'],
    operatorActions: ['select scenario', 'inspect visual layer', 'connect to measurement/KPI target'],
  },
  {
    id: 'full-engineering-stack',
    title: 'Full Engineering Stack · Integration View',
    subtitle: 'Single consolidated map of navigation, visual assets, scenario knowledge, command center and runtime contracts.',
    operationalMeaning:
      'This is the executive engineering view: it proves that UI, routing, visual evidence, live API contracts and technical content are bound into a single reproducible portal.',
    liveContracts: ['/api/health', '/api/mission/status', '/api/rfpro/spectrum/sweep'],
    microKpis: [
      { label: 'Integration depth', meaning: 'Shows whether all subsystems are visible from one stack-level view.', target: 'navigation + visual + command + scenario' },
      { label: 'Evidence maturity', meaning: 'Confirms each major layer has DOM, screenshot, freeze and rollback evidence.', target: 'latest QA releases present' },
      { label: 'Operational continuity', meaning: 'Preserves the safe entrypoint at 127.0.0.1:5173 with backend bridge on 4181.', target: 'ports stable' },
    ],
    engineeringFocus: ['system integration', 'evidence chain', 'runtime contracts', 'operator workflow'],
    operatorActions: ['review release chain', 'confirm evidence artifacts', 'prepare next enrichment sprint'],
  },
]

function resolveSection(activeSection: string) {
  return sectionsV49.find((section) => section.id === activeSection) ?? sectionsV49[0]
}

export function EngineeringContentEnrichmentV49({ activeSection }: { activeSection: string }) {
  const section = resolveSection(activeSection)

  return (
    <section className="v49-engineering-enrichment" data-trfmc-v49-engineering-enrichment="true">
      <div className="v49-enrichment-header">
        <p>TRFMC V49 · Engineering Content Enrichment Baseline</p>
        <h2>{section.title}</h2>
        <span>{section.subtitle}</span>
      </div>

      <div className="v49-enrichment-grid">
        <article className="v49-enrichment-card v49-operational-meaning">
          <span>Operational meaning</span>
          <p>{section.operationalMeaning}</p>
        </article>

        <article className="v49-enrichment-card">
          <span>Live / contract endpoints</span>
          <div className="v49-chip-list">
            {section.liveContracts.map((endpoint) => (
              <code key={`${section.id}-${endpoint}`}>{endpoint}</code>
            ))}
          </div>
        </article>

        <article className="v49-enrichment-card">
          <span>Engineering focus</span>
          <div className="v49-chip-list">
            {section.engineeringFocus.map((focus) => (
              <em key={`${section.id}-${focus}`}>{focus}</em>
            ))}
          </div>
        </article>
      </div>

      <div className="v49-kpi-grid">
        {section.microKpis.map((kpi) => (
          <article key={`${section.id}-${kpi.label}`} className="v49-kpi-card">
            <strong>{kpi.label}</strong>
            <p>{kpi.meaning}</p>
            <small>Target: {kpi.target}</small>
          </article>
        ))}
      </div>

      <div className="v49-operator-actions">
        <span>Operator workflow</span>
        {section.operatorActions.map((action) => (
          <b key={`${section.id}-${action}`}>{action}</b>
        ))}
      </div>
    </section>
  )
}
'''.strip() + "\n", encoding="utf-8")

print("\n=== PATCH V42 ORCHESTRATOR ===")

s = v42_before

import_line = "import { EngineeringContentEnrichmentV49 } from './EngineeringContentEnrichmentV49'"
if "EngineeringContentEnrichmentV49" not in s:
    lines = s.splitlines()
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    if last_import < 0:
        raise SystemExit("ERRORE: nessun import trovato in V42")
    lines.insert(last_import + 1, import_line)
    s = "\n".join(lines) + "\n"

mount = "      <EngineeringContentEnrichmentV49 activeSection={active} />\n"

if "data-trfmc-v49-engineering-enrichment" not in s and "<EngineeringContentEnrichmentV49 activeSection={active} />" not in s:
    if "</nav>" in s and "data-trfmc-v46-deeplink-index" in s:
        s = s.replace("</nav>", "</nav>\n\n" + mount, 1)
    else:
        # conservative fallback: after return opening first block.
        pos = s.find("return (")
        if pos == -1:
            raise SystemExit("ERRORE: return non trovato in V42")
        nl = s.find("\n", pos)
        s = s[:nl + 1] + mount + s[nl + 1:]

V42.write_text(s, encoding="utf-8")

print("\n=== PATCH CSS ===")

css = css_before
if "TRFMC V49 ENGINEERING CONTENT ENRICHMENT" not in css:
    css += r'''

/* === TRFMC V49 ENGINEERING CONTENT ENRICHMENT === */
.v49-engineering-enrichment{
  margin: 18px 0 26px;
  padding: clamp(16px, 2vw, 26px);
  border-radius: 26px;
  border: 1px solid rgba(117,234,255,.24);
  background:
    radial-gradient(circle at 12% 0%, rgba(117,234,255,.15), transparent 32%),
    radial-gradient(circle at 86% 20%, rgba(120,255,190,.10), transparent 34%),
    linear-gradient(135deg, rgba(3,13,28,.92), rgba(2,8,18,.98));
  box-shadow: 0 18px 60px rgba(0,0,0,.32), inset 0 1px 0 rgba(255,255,255,.06);
}

.v49-enrichment-header{
  display:grid;
  gap:7px;
  margin-bottom:16px;
}

.v49-enrichment-header p{
  margin:0;
  color:rgba(117,234,255,.88);
  text-transform:uppercase;
  letter-spacing:.16em;
  font-size:.72rem;
  font-weight:900;
}

.v49-enrichment-header h2{
  margin:0;
  color:var(--trfmc-text,#f1fbff);
  letter-spacing:-.035em;
}

.v49-enrichment-header span{
  color:var(--trfmc-muted,#9ab5c9);
}

.v49-enrichment-grid{
  display:grid;
  grid-template-columns:1.2fr .9fr .9fr;
  gap:12px;
}

.v49-enrichment-card,
.v49-kpi-card{
  border:1px solid rgba(117,234,255,.16);
  border-radius:18px;
  background:rgba(255,255,255,.045);
  padding:14px;
}

.v49-enrichment-card span,
.v49-operator-actions span{
  display:block;
  color:rgba(117,234,255,.86);
  text-transform:uppercase;
  letter-spacing:.12em;
  font-size:.68rem;
  font-weight:900;
  margin-bottom:8px;
}

.v49-enrichment-card p{
  margin:0;
  color:rgba(236,249,255,.88);
  line-height:1.55;
}

.v49-chip-list{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
}

.v49-chip-list code,
.v49-chip-list em,
.v49-operator-actions b{
  display:inline-flex;
  align-items:center;
  border-radius:999px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(0,0,0,.20);
  color:rgba(236,249,255,.86);
  padding:6px 9px;
  font-size:.72rem;
  font-style:normal;
  font-weight:800;
}

.v49-kpi-grid{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:12px;
  margin-top:12px;
}

.v49-kpi-card strong{
  display:block;
  color:var(--trfmc-cyan,#75eaff);
  font-size:.9rem;
  margin-bottom:6px;
}

.v49-kpi-card p{
  margin:0 0 8px;
  color:rgba(236,249,255,.86);
  line-height:1.45;
}

.v49-kpi-card small{
  color:rgba(120,255,190,.84);
  font-weight:800;
}

.v49-operator-actions{
  display:flex;
  flex-wrap:wrap;
  align-items:center;
  gap:8px;
  margin-top:12px;
  padding-top:12px;
  border-top:1px solid rgba(117,234,255,.12);
}

@media (max-width:1200px){
  .v49-enrichment-grid,
  .v49-kpi-grid{
    grid-template-columns:1fr;
  }
}
'''
CSS.write_text(css, encoding="utf-8")

print("\n=== STATIC CHECKS ===")

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

v42_now = V42.read_text(encoding="utf-8")
css_now = CSS.read_text(encoding="utf-8")
enrich_now = ENRICH.read_text(encoding="utf-8")
main_now = MAIN.read_text(encoding="utf-8")

ok("main.tsx still mounts V42", "<MissionLayoutOrchestratorV42 />" in main_now)
ok("V49 component exists", ENRICH.exists())
ok("V49 component exports EngineeringContentEnrichmentV49", "export function EngineeringContentEnrichmentV49" in enrich_now)
ok("V49 covers seven sections", enrich_now.count("id: '") >= 7)
ok("V49 includes operational meaning", "Operational meaning" in enrich_now)
ok("V49 includes micro KPI layer", "microKpis" in enrich_now)
ok("V49 includes live contract endpoints", "liveContracts" in enrich_now)
ok("V42 imports V49 component", "EngineeringContentEnrichmentV49" in v42_now)
ok("V42 mounts V49 component with active section", "<EngineeringContentEnrichmentV49 activeSection={active} />" in v42_now)
ok("V46 deeplink index preserved", "data-trfmc-v46-deeplink-index" in v42_now)
ok("V44 visual viewer preserved", "VisualZoomViewer" in (ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx").read_text(encoding="utf-8"))
ok("V49 CSS present", "TRFMC V49 ENGINEERING CONTENT ENRICHMENT" in css_now)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

print("\n=== BUILD GATE ===")

build_log = RDIR / "npm_build_v49.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)

build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result != "PASS":
    print(build_log.read_text(errors="ignore")[-10000:])

print("\n=== HTTP GATE ===")

http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/#mission-overview",
    "http://127.0.0.1:5173/#visual-assets",
    "http://127.0.0.1:5173/#scenario-knowledge",
    "http://127.0.0.1:5173/#navigation-architecture",
    "http://127.0.0.1:5173/#command-center",
    "http://127.0.0.1:5173/#dynamic-scenarios",
    "http://127.0.0.1:5173/#full-engineering-stack",
    "http://127.0.0.1:4181/api/health",
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

rollback = RDIR / "rollback_v49_engineering_content_enrichment.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/MissionLayoutOrchestratorV42.tsx.before_v49_{TS}" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx
cp "{RDIR}/styles.css.before_v49_{TS}" frontend/src/styles.css
rm -f frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx
if [ -f "{RDIR}/EngineeringContentEnrichmentV49.tsx.before_v49_{TS}" ]; then
  cp "{RDIR}/EngineeringContentEnrichmentV49.tsx.before_v49_{TS}" frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx
fi
echo "Rollback V49 completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result != "PASS" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "engineering_content_enrichment_manifest_v49.json"
summary = QDIR / "summary.json"

summary_data = {
    "timestamp": TS,
    "operation": OP,
    "frontend_mutation": True,
    "main_tsx_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "patched": [str(ENRICH), str(V42), str(CSS)],
    "sections_enriched": 7,
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}

manifest.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx",
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/styles.css",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_engineering_content_enrichment_v49"
latest_r = ROOT / "runtime/releases/latest_engineering_content_enrichment_v49"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print("\n=== SUMMARY ===")
print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
