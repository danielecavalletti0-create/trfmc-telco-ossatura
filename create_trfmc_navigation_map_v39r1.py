from pathlib import Path
import json
import subprocess
import time
import os

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_NAVIGATION_MAP_V39R1_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_NAVIGATION_MAP_V39R1_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_NAVIGATION_MAP_V39R1_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
STYLES = ROOT / "frontend/src/styles.css"

NAV_DIR = ROOT / "frontend/src/navigation"
NAV_DATA = NAV_DIR / "navigationDataV39.ts"
NAV_COMPONENT = NAV_DIR / "NavigationMapV39.tsx"
WRAPPER = ROOT / "frontend/src/rf_instruments/instruments/RFOperationalDeckV39NavigationFusion.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
NAV_DIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC NAVIGATION MAP V39R1")
print("React navigation layer · above V37 · no backend/nginx/systemd mutation")
print("=" * 60)

if not MAIN.exists():
    raise SystemExit("ERRORE: main.tsx mancante")
if not STYLES.exists():
    raise SystemExit("ERRORE: styles.css mancante")

# Preconditions
v39a_summary = ROOT / "runtime/quality/latest_navigation_inventory_audit_v39a/summary.json"
v38_summary = ROOT / "runtime/quality/latest_unified_design_system_v38/summary.json"
v37_summary = ROOT / "runtime/quality/latest_command_center_fusion_v37/summary.json"

for p in [v39a_summary, v38_summary, v37_summary]:
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {p}")

for p in [v39a_summary, v38_summary, v37_summary]:
    data = json.loads(p.read_text())
    if data.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {p} non PASS: {data.get('result')}")

main_txt = MAIN.read_text(encoding="utf-8")

if "RFOperationalDeckV39NavigationFusion" in main_txt:
    active_state = "already_v39"
elif "RFOperationalDeckV37CommandCenterFusion" in main_txt:
    active_state = "v37_ready"
else:
    print("ERRORE: main.tsx non monta V37/V39")
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

print("OK: API 4181 live")

# Backup
pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_NAVIGATION_MAP_V39R1_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/app/main.tsx",
    "frontend/src/styles.css",
    "frontend/src/navigation",
    "frontend/src/rf_instruments/instruments",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

(RDIR / f"main.tsx.before_v39r1_{TS}").write_text(main_txt, encoding="utf-8")
(RDIR / f"styles.css.before_v39r1_{TS}").write_text(STYLES.read_text(encoding="utf-8"), encoding="utf-8")

NAV_DATA.write_text(r"""
export type NavigationStatusV39 = 'ready' | 'partial' | 'planned'

export type NavigationDomainV39 = {
  id: string
  title: string
  subtitle: string
  status: NavigationStatusV39
  priority: number
  domain: string
  routeHint: string
  liveEndpoint?: string
  anchors: string[]
  capabilities: string[]
  nextStep: string
}

export const navigationDomainsV39: NavigationDomainV39[] = [
  {
    id: 'mission-control',
    title: 'Mission Control',
    subtitle: 'Command Center, runtime status, health, read-only source and portal governance.',
    status: 'ready',
    priority: 1,
    domain: 'mission',
    routeHint: 'V37 Command Center Fusion',
    liveEndpoint: '/api/mission/status',
    anchors: ['CommandCenterFusionV37', 'V37', 'V38 design system'],
    capabilities: ['global readiness', 'live API source', 'safe entrypoint fusion'],
    nextStep: 'Use as top-level operational dashboard.',
  },
  {
    id: 'rf-physics',
    title: 'RF Physics',
    subtitle: 'Maxwell, propagation, fields, spectrum concepts, RF theory and scenario links.',
    status: 'ready',
    priority: 2,
    domain: 'rf',
    routeHint: '02_RF_Physics',
    anchors: ['RF Physics', 'Maxwell', 'V36 physics overlay'],
    capabilities: ['theory layer', 'field visualization', 'scenario binding'],
    nextStep: 'Bind formulas and theory cards to V36 scenarios.',
  },
  {
    id: 'signal-analyzer',
    title: 'Signal Analyzer',
    subtitle: 'Spectrum, waterfall, IQ, markers, DSP worker and instrument workbench.',
    status: 'ready',
    priority: 2,
    domain: 'rf',
    routeHint: '03_Signal_Analyzer',
    liveEndpoint: '/api/rfpro/spectrum/sweep',
    anchors: ['Spectrum', 'Waterfall', 'IQ', 'RFInstrument'],
    capabilities: ['spectrum contract', 'waterfall', 'IQ pipeline', 'measurement UX'],
    nextStep: 'Unify RF instrument deck with Navigation Map domain.',
  },
  {
    id: 'rf-microwave-engineering',
    title: 'RF / Microwave Engineering',
    subtitle: 'Smith chart, S-parameters, VNA, microwave components and lab procedures.',
    status: 'ready',
    priority: 3,
    domain: 'rf-lab',
    routeHint: '04_RF_Microwave_Engineering',
    anchors: ['microwave', 'Smith', 'S-parameters', 'VNA'],
    capabilities: ['measurement theory', 'lab workflow', 'instrument correlation'],
    nextStep: 'Add Smith/S-parameter knowledge cards.',
  },
  {
    id: 'antenna-system',
    title: 'Antenna System',
    subtitle: 'Antenna families, microstrip, tower systems, beamwidth and coverage.',
    status: 'ready',
    priority: 2,
    domain: 'antenna',
    routeHint: '05_Antenna_System',
    liveEndpoint: '/api/rfpro/bandplan',
    anchors: ['Antenna', 'microstrip', 'beamwidth', 'tower'],
    capabilities: ['antenna taxonomy', 'pattern context', 'coverage scenarios'],
    nextStep: 'Connect visual render assets to V36 antenna scenes.',
  },
  {
    id: 'microwave-link',
    title: 'Microwave Link',
    subtitle: 'Backhaul, dish links, link budget, fade margin and point-to-point systems.',
    status: 'ready',
    priority: 4,
    domain: 'transport',
    routeHint: '06_Microwave_Link',
    anchors: ['link budget', 'microwave', 'dish', 'backhaul'],
    capabilities: ['link budget', 'backhaul topology', 'coverage tradeoff'],
    nextStep: 'Create link-budget calculator/read-only scenario.',
  },
  {
    id: 'fiber-optic',
    title: 'Fiber Optic',
    subtitle: 'Optical transport, fiber plant, backbone links and physical connectivity.',
    status: 'partial',
    priority: 4,
    domain: 'transport',
    routeHint: '07_Fiber_Optic',
    anchors: ['fiber'],
    capabilities: ['fiber context placeholder', 'transport knowledge'],
    nextStep: 'Expand with fiber topology, OTDR, splice and transport cards.',
  },
  {
    id: 'private-networks',
    title: 'Private Networks',
    subtitle: 'Private 5G, enterprise deployments, network slicing context and lab topology.',
    status: 'ready',
    priority: 3,
    domain: '5g',
    routeHint: '08_Private_Networks',
    anchors: ['private', '5g', 'network'],
    capabilities: ['private 5G architecture', 'lab topology', 'enterprise scenarios'],
    nextStep: 'Bind to Open5GS/UERANSIM state and topology map.',
  },
  {
    id: 'core-network',
    title: 'Core Network',
    subtitle: 'Open5GS, AMF, SMF, UPF, AUSF, UDM, NAS, PFCP and GTP-U.',
    status: 'ready',
    priority: 2,
    domain: '5g-core',
    routeHint: '09_Core_Network',
    liveEndpoint: '/api/core/open5gs/status',
    anchors: ['Open5GS', 'core/open5gs', 'AMF'],
    capabilities: ['core readiness', '5G call-flow context', 'identity/security model'],
    nextStep: 'Connect SUPI/SUCI, AKA, NAS and PDU session visual flows.',
  },
  {
    id: 'data-center-infrastructure',
    title: 'Data Center Infrastructure',
    subtitle: 'Compute, infrastructure, server/runtime services and future telco cloud mapping.',
    status: 'ready',
    priority: 4,
    domain: 'infrastructure',
    routeHint: '10_Data_Center_Infrastructure',
    anchors: ['data center', 'infrastructure'],
    capabilities: ['infrastructure context', 'runtime services', 'future telco cloud'],
    nextStep: 'Map backend/frontend/proxy/systemd services into topology.',
  },
  {
    id: 'cyber-rf-intelligence',
    title: 'Cyber RF Intelligence',
    subtitle: 'SOC/NOC correlation, RF/cyber event context, evidence and safe read-only analysis.',
    status: 'ready',
    priority: 3,
    domain: 'cyber',
    routeHint: '11_Cyber_RF_Intelligence',
    liveEndpoint: '/api/soc-noc/correlation/demo',
    anchors: ['SOC', 'NOC', 'correlation', 'cyber'],
    capabilities: ['correlation contract', 'evidence view', 'RF/cyber awareness'],
    nextStep: 'Create event timeline and evidence binding.',
  },
  {
    id: 'knowledge-base',
    title: 'Knowledge Base',
    subtitle: 'Glossary, theory, assets, visual references, teaching and engineering documentation.',
    status: 'partial',
    priority: 3,
    domain: 'knowledge',
    routeHint: '12_Knowledge_Base',
    anchors: ['Knowledge', 'visual assets'],
    capabilities: ['knowledge index', 'visual context', 'training library'],
    nextStep: 'Bind scenarios to formulas, visuals and glossary pages.',
  },
]

export const navigationMetaV39 = {
  title: 'TRFMC V39 Navigation Architecture',
  subtitle: 'Official mission/domain map above the V37 Command Center.',
  readyCount: 10,
  partialCount: 2,
  missingCount: 0,
  source: 'V39A inventory audit',
}
""".strip() + "\n", encoding="utf-8")

NAV_COMPONENT.write_text(r"""
import { useMemo, useState } from 'react'
import { navigationDomainsV39, navigationMetaV39, type NavigationDomainV39, type NavigationStatusV39 } from './navigationDataV39'

function statusLabel(status: NavigationStatusV39) {
  if (status === 'ready') return 'READY'
  if (status === 'partial') return 'FUTURE-LIVE'
  return 'PLANNED'
}

function statusRank(status: NavigationStatusV39) {
  if (status === 'ready') return 0
  if (status === 'partial') return 1
  return 2
}

export function NavigationMapV39() {
  const [filter, setFilter] = useState<NavigationStatusV39 | 'all'>('all')
  const [selected, setSelected] = useState<string>('mission-control')

  const domains = useMemo(() => {
    return navigationDomainsV39
      .filter((domain) => filter === 'all' || domain.status === filter)
      .sort((a, b) => statusRank(a.status) - statusRank(b.status) || a.priority - b.priority)
  }, [filter])

  const selectedDomain = useMemo<NavigationDomainV39>(() => {
    return navigationDomainsV39.find((domain) => domain.id === selected) ?? navigationDomainsV39[0]
  }, [selected])

  return (
    <section className="v39-navigation-shell">
      <div className="v39-navigation-header">
        <div>
          <p>V39 NAVIGATION ARCHITECTURE</p>
          <h2>{navigationMetaV39.title}</h2>
          <span>{navigationMetaV39.subtitle}</span>
        </div>
        <div className="v39-navigation-score">
          <strong>{navigationMetaV39.readyCount}/{navigationDomainsV39.length}</strong>
          <small>ready domains</small>
        </div>
      </div>

      <div className="v39-navigation-controls">
        {(['all', 'ready', 'partial', 'planned'] as const).map((item) => (
          <button
            key={item}
            type="button"
            className={filter === item ? 'v39-filter-active' : ''}
            onClick={() => setFilter(item)}
          >
            {item === 'all' ? 'ALL' : statusLabel(item)}
          </button>
        ))}
      </div>

      <div className="v39-navigation-layout">
        <div className="v39-domain-grid">
          {domains.map((domain) => (
            <button
              key={domain.id}
              type="button"
              className={`v39-domain-card v39-domain-${domain.status} ${selectedDomain.id === domain.id ? 'v39-domain-selected' : ''}`}
              onClick={() => setSelected(domain.id)}
            >
              <span>{domain.domain}</span>
              <strong>{domain.title}</strong>
              <small>{statusLabel(domain.status)}</small>
            </button>
          ))}
        </div>

        <aside className="v39-domain-detail">
          <div className="v39-detail-top">
            <span>{selectedDomain.domain}</span>
            <strong className={`v39-status-pill v39-status-${selectedDomain.status}`}>
              {statusLabel(selectedDomain.status)}
            </strong>
          </div>

          <h3>{selectedDomain.title}</h3>
          <p>{selectedDomain.subtitle}</p>

          <code>{selectedDomain.routeHint}</code>

          {selectedDomain.liveEndpoint ? (
            <div className="v39-live-endpoint">
              <span>live endpoint</span>
              <strong>{selectedDomain.liveEndpoint}</strong>
            </div>
          ) : (
            <div className="v39-live-endpoint v39-live-endpoint-local">
              <span>binding</span>
              <strong>local / scenario / knowledge layer</strong>
            </div>
          )}

          <div className="v39-detail-columns">
            <article>
              <span>Anchors</span>
              <ul>
                {selectedDomain.anchors.map((anchor) => (
                  <li key={`${selectedDomain.id}-${anchor}`}>{anchor}</li>
                ))}
              </ul>
            </article>

            <article>
              <span>Capabilities</span>
              <ul>
                {selectedDomain.capabilities.map((capability) => (
                  <li key={`${selectedDomain.id}-${capability}`}>{capability}</li>
                ))}
              </ul>
            </article>
          </div>

          <footer>
            <span>Next engineering step</span>
            <strong>{selectedDomain.nextStep}</strong>
          </footer>
        </aside>
      </div>
    </section>
  )
}
""".strip() + "\n", encoding="utf-8")

WRAPPER.write_text(r"""
import { NavigationMapV39 } from '../../navigation/NavigationMapV39'
import { RFOperationalDeckV37CommandCenterFusion } from './RFOperationalDeckV37CommandCenterFusion'

export function RFOperationalDeckV39NavigationFusion() {
  return (
    <>
      <NavigationMapV39 />
      <RFOperationalDeckV37CommandCenterFusion />
    </>
  )
}
""".strip() + "\n", encoding="utf-8")

styles = STYLES.read_text(encoding="utf-8")
if "TRFMC V39 NAVIGATION MAP" not in styles:
    STYLES.write_text(styles + r"""

/* === TRFMC V39 NAVIGATION MAP === */
.v39-navigation-shell{
  margin:18px;
  padding:18px;
  border:1px solid var(--trfmc-border, rgba(117,234,255,.22));
  border-radius:var(--trfmc-radius-xl, 28px);
  background:var(--trfmc-gradient-shell, linear-gradient(135deg,rgba(2,9,17,.98),rgba(4,14,25,.98)));
  box-shadow:var(--trfmc-shadow-deep, 0 34px 95px rgba(0,0,0,.42)), inset 0 0 44px rgba(80,215,255,.045);
}

.v39-navigation-shell::before{
  content:"";
  display:block;
  height:1px;
  margin:-4px 0 14px;
  background:linear-gradient(90deg,transparent,rgba(117,234,255,.45),rgba(141,255,189,.30),transparent);
}

.v39-navigation-header{
  display:flex;
  justify-content:space-between;
  align-items:flex-start;
  gap:20px;
  margin-bottom:14px;
}

.v39-navigation-header p{
  margin:0 0 6px;
  color:var(--trfmc-cyan, #75eaff);
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v39-navigation-header h2{
  margin:0;
  color:var(--trfmc-text, #f1fbff);
  font-size:25px;
}

.v39-navigation-header span{
  display:block;
  margin-top:8px;
  color:var(--trfmc-muted, #9ab5c9);
  font-size:13px;
}

.v39-navigation-score{
  min-width:132px;
  padding:12px;
  border:1px solid var(--trfmc-border-green, rgba(141,255,189,.26));
  border-radius:var(--trfmc-radius-md, 16px);
  background:rgba(5,36,34,.58);
  text-align:center;
}

.v39-navigation-score strong{
  display:block;
  color:var(--trfmc-green, #8dffbd);
  font-size:25px;
}

.v39-navigation-score small{
  color:#9bb7a9;
}

.v39-navigation-controls{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  margin-bottom:14px;
}

.v39-navigation-controls button{
  border:1px solid rgba(117,234,255,.22);
  border-radius:999px;
  background:rgba(6,19,34,.78);
  color:#a6bdd2;
  padding:8px 12px;
  cursor:pointer;
  font-size:12px;
}

.v39-navigation-controls button.v39-filter-active{
  color:#06131d;
  background:linear-gradient(135deg,var(--trfmc-cyan, #75eaff),var(--trfmc-green, #8dffbd));
  border-color:transparent;
}

.v39-navigation-layout{
  display:grid;
  grid-template-columns:minmax(0,1.15fr) minmax(360px,.85fr);
  gap:14px;
}

.v39-domain-grid{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:10px;
}

.v39-domain-card{
  min-height:116px;
  text-align:left;
  padding:13px;
  border-radius:18px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(8,25,42,.62);
  cursor:pointer;
}

.v39-domain-card span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:7px;
}

.v39-domain-card strong{
  display:block;
  color:var(--trfmc-text, #f1fbff);
  font-size:15px;
  line-height:1.1;
}

.v39-domain-card small{
  display:inline-block;
  margin-top:10px;
  padding:4px 8px;
  border-radius:999px;
  font-weight:800;
  font-size:10px;
}

.v39-domain-ready small{
  color:var(--trfmc-green, #8dffbd);
  background:rgba(141,255,189,.12);
}

.v39-domain-partial small{
  color:var(--trfmc-amber, #ffd37b);
  background:rgba(255,211,123,.12);
}

.v39-domain-planned small{
  color:var(--trfmc-muted, #9ab5c9);
  background:rgba(154,181,201,.10);
}

.v39-domain-selected{
  border-color:rgba(117,234,255,.42);
  box-shadow:0 0 24px rgba(117,234,255,.16);
}

.v39-domain-detail{
  padding:16px;
  border-radius:22px;
  border:1px solid rgba(117,234,255,.18);
  background:rgba(5,17,31,.76);
}

.v39-detail-top{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  margin-bottom:10px;
}

.v39-detail-top > span{
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.16em;
  text-transform:uppercase;
}

.v39-status-pill{
  border-radius:999px;
  padding:5px 9px;
  font-size:10px;
  font-weight:900;
}

.v39-status-ready{
  color:var(--trfmc-green, #8dffbd);
  background:rgba(141,255,189,.12);
}

.v39-status-partial{
  color:var(--trfmc-amber, #ffd37b);
  background:rgba(255,211,123,.12);
}

.v39-status-planned{
  color:var(--trfmc-muted, #9ab5c9);
  background:rgba(154,181,201,.10);
}

.v39-domain-detail h3{
  margin:0 0 8px;
  color:var(--trfmc-text, #f1fbff);
  font-size:23px;
}

.v39-domain-detail p{
  color:var(--trfmc-muted, #9ab5c9);
  line-height:1.45;
}

.v39-domain-detail code{
  display:block;
  padding:8px 10px;
  border-radius:12px;
  color:var(--trfmc-cyan, #75eaff);
  background:rgba(1,8,15,.58);
  font-size:11px;
}

.v39-live-endpoint{
  margin:10px 0;
  padding:10px;
  border:1px solid rgba(141,255,189,.14);
  border-radius:14px;
  background:rgba(7,31,31,.48);
}

.v39-live-endpoint span,
.v39-detail-columns article > span,
.v39-domain-detail footer span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.13em;
  text-transform:uppercase;
  margin-bottom:5px;
}

.v39-live-endpoint strong{
  color:var(--trfmc-green, #8dffbd);
  font-size:12px;
}

.v39-live-endpoint-local strong{
  color:var(--trfmc-amber, #ffd37b);
}

.v39-detail-columns{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:10px;
  margin-top:12px;
}

.v39-detail-columns article{
  padding:10px;
  border:1px solid rgba(117,234,255,.14);
  border-radius:14px;
  background:rgba(8,25,42,.62);
}

.v39-detail-columns ul{
  margin:0;
  padding-left:18px;
  color:#c5d8e7;
  font-size:12px;
  line-height:1.45;
}

.v39-domain-detail footer{
  margin-top:12px;
  padding:10px;
  border-radius:14px;
  background:rgba(2,9,17,.52);
}

.v39-domain-detail footer strong{
  color:var(--trfmc-text, #f1fbff);
  font-size:12px;
}

@media (max-width:1200px){
  .v39-navigation-layout{grid-template-columns:1fr}
  .v39-domain-grid{grid-template-columns:repeat(2,minmax(0,1fr))}
}

@media (max-width:760px){
  .v39-navigation-header{flex-direction:column}
  .v39-domain-grid{grid-template-columns:1fr}
  .v39-detail-columns{grid-template-columns:1fr}
}
""", encoding="utf-8")

# Patch main
main_txt = MAIN.read_text(encoding="utf-8")
old_import = "import { RFOperationalDeckV37CommandCenterFusion } from '../rf_instruments/instruments/RFOperationalDeckV37CommandCenterFusion'"
new_import = "import { RFOperationalDeckV39NavigationFusion } from '../rf_instruments/instruments/RFOperationalDeckV39NavigationFusion'"

if new_import not in main_txt:
    if old_import not in main_txt and "RFOperationalDeckV39NavigationFusion" not in main_txt:
        raise SystemExit("ERRORE: import V37 non trovato in main.tsx")
    main_txt = main_txt.replace(old_import, new_import, 1)

main_txt = main_txt.replace("<RFOperationalDeckV37CommandCenterFusion />", "<RFOperationalDeckV39NavigationFusion />")
MAIN.write_text(main_txt, encoding="utf-8")

# Checks
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

main_now = MAIN.read_text(encoding="utf-8")
styles_now = STYLES.read_text(encoding="utf-8")
data_now = NAV_DATA.read_text(encoding="utf-8")
component_now = NAV_COMPONENT.read_text(encoding="utf-8")
wrapper_now = WRAPPER.read_text(encoding="utf-8")

ok("navigationDataV39.ts exists", NAV_DATA.exists())
ok("NavigationMapV39.tsx exists", NAV_COMPONENT.exists())
ok("RFOperationalDeckV39NavigationFusion.tsx exists", WRAPPER.exists())
ok("main imports/mounts V39", "RFOperationalDeckV39NavigationFusion" in main_now)
ok("main JSX mounts V39", "<RFOperationalDeckV39NavigationFusion />" in main_now)
ok("V37 preserved below V39", "RFOperationalDeckV37CommandCenterFusion" in wrapper_now)
ok("NavigationMapV39 export exists", "export function NavigationMapV39" in component_now)
ok("Mission Control domain exists", "Mission Control" in data_now)
ok("Signal Analyzer domain exists", "Signal Analyzer" in data_now)
ok("Core Network domain exists", "Core Network" in data_now)
ok("Knowledge Base domain exists", "Knowledge Base" in data_now)
ok("V39 CSS present", "v39-navigation-shell" in styles_now)
ok("no iframe in V39 navigation component", "<iframe" not in component_now.lower())

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())
miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build
build_log = RDIR / "npm_build_v39r1.log"
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

rollback = RDIR / "rollback_v39r1_navigation_map.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/main.tsx.before_v39r1_{TS}" frontend/src/app/main.tsx
cp "{RDIR}/styles.css.before_v39r1_{TS}" frontend/src/styles.css
rm -rf frontend/src/navigation
rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV39NavigationFusion.tsx
echo "Rollback V39R1 Navigation Map completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "navigation_map_manifest_v39r1.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_NAVIGATION_MAP_V39R1",
    "strategy": "official_navigation_layer_above_v37_command_center",
    "frontend_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "created": [str(NAV_DATA), str(NAV_COMPONENT), str(WRAPPER)],
    "patched": [str(MAIN), str(STYLES)],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "domains_count": 12,
    "ready_count": 10,
    "partial_count": 2,
    "missing_count": 0,
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_NAVIGATION_MAP_V39R1",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_mount": "RFOperationalDeckV39NavigationFusion",
    "preserves": "RFOperationalDeckV37CommandCenterFusion",
    "domains_count": 12,
    "ready_count": 10,
    "partial_count": 2,
    "missing_count": 0,
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
    "frontend/src/navigation",
    "frontend/src/rf_instruments/instruments/RFOperationalDeckV39NavigationFusion.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_navigation_map_v39r1"
latest_r = ROOT / "runtime/releases/latest_navigation_map_v39r1"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
