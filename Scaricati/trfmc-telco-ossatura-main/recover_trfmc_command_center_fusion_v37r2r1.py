from pathlib import Path
import json
import subprocess
import time
import os

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_COMMAND_CENTER_FUSION_V37R2R1_RECOVERY_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_COMMAND_CENTER_FUSION_V37R2R1_RECOVERY_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_COMMAND_CENTER_FUSION_V37R2R1_RECOVERY_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
STYLES = ROOT / "frontend/src/styles.css"
CMD_DIR = ROOT / "frontend/src/command_center"
CMD_DATA = CMD_DIR / "commandCenterDataV37.ts"
CMD_COMPONENT = CMD_DIR / "CommandCenterFusionV37.tsx"
WRAPPER = ROOT / "frontend/src/rf_instruments/instruments/RFOperationalDeckV37CommandCenterFusion.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
CMD_DIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC COMMAND CENTER FUSION V37R2R1 RECOVERY")
print("atomic Python writer · no iframe · preserve V36 runtime")
print("=" * 60)

if not MAIN.exists():
    raise SystemExit("ERRORE: main.tsx mancante")
if not STYLES.exists():
    raise SystemExit("ERRORE: styles.css mancante")

main_txt = MAIN.read_text(encoding="utf-8")

if "RFOperationalDeckV37CommandCenterFusion" in main_txt:
    active_state = "already_v37"
elif "RFOperationalDeckV36VisualScenarioRuntime" in main_txt:
    active_state = "v36_ready"
else:
    print("ERRORE: ramo attivo non riconosciuto")
    print("\n".join([l for l in main_txt.splitlines() if "RFOperationalDeck" in l]))
    raise SystemExit(1)

print(f"OK: active_state={active_state}")

# API preflight
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
pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_COMMAND_CENTER_FUSION_V37R2R1_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/app/main.tsx",
    "frontend/src/styles.css",
    "frontend/src/command_center",
    "frontend/src/rf_instruments/instruments",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

(RDIR / f"main.tsx.before_v37r2r1_{TS}").write_text(main_txt, encoding="utf-8")
(RDIR / f"styles.css.before_v37r2r1_{TS}").write_text(STYLES.read_text(encoding="utf-8"), encoding="utf-8")

CMD_DATA.write_text(r"""
export type CommandCenterDomainV37 =
  | 'mission'
  | 'core'
  | 'ran'
  | 'rf'
  | 'soc-noc'
  | 'scenarios'
  | 'knowledge'

export type CommandCenterTileV37 = {
  id: string
  title: string
  subtitle: string
  domain: CommandCenterDomainV37
  liveEndpoint?: string
  routeHint: string
  priority: 'critical' | 'high' | 'medium'
  kpis: Array<{ label: string; value: string }>
  actions: string[]
}

export const commandCenterTilesV37: CommandCenterTileV37[] = [
  {
    id: 'mission-control',
    title: 'Mission Control',
    subtitle: 'Portale operativo, health globale, sorgente dati e modalità read-only.',
    domain: 'mission',
    liveEndpoint: '/api/mission/status',
    routeHint: 'root / operational shell',
    priority: 'critical',
    kpis: [
      { label: 'Mode', value: 'read-only' },
      { label: 'Proxy', value: '4181' },
      { label: 'Frontend', value: '5173' },
    ],
    actions: ['Verifica sorgente backend', 'Controlla fallback', 'Mostra health globale'],
  },
  {
    id: 'core-network',
    title: '5G Core Network',
    subtitle: 'Open5GS, ogstun, SBI, NAS, PFCP, GTP-U e readiness core.',
    domain: 'core',
    liveEndpoint: '/api/core/open5gs/status',
    routeHint: '09_Core_Network',
    priority: 'critical',
    kpis: [
      { label: 'Core', value: 'Open5GS' },
      { label: 'Safety', value: 'no start/stop' },
      { label: 'Probe', value: 'v30 hygiene' },
    ],
    actions: ['Visualizza readiness', 'Collega call-flow', 'Mappa PFCP/GTP-U'],
  },
  {
    id: 'ran-simulator',
    title: 'RAN / UERANSIM',
    subtitle: 'gNB/UE simulator, tunnel UE, NGAP e stato access network.',
    domain: 'ran',
    liveEndpoint: '/api/ran/ueransim/status',
    routeHint: 'RAN simulator / UERANSIM',
    priority: 'high',
    kpis: [
      { label: 'RAN', value: 'UERANSIM' },
      { label: 'UE tun', value: 'uesimtun0' },
      { label: 'Mode', value: 'read-only' },
    ],
    actions: ['Controlla gNB/UE', 'Mappa NGAP', 'Mappa PDU session'],
  },
  {
    id: 'rf-spectrum',
    title: 'RF Spectrum / Signal Workbench',
    subtitle: 'Spectrum sweep contract, synthetic/live-ready RF model, waterfall/IQ path.',
    domain: 'rf',
    liveEndpoint: '/api/rfpro/spectrum/sweep',
    routeHint: '03_Signal_Analyzer',
    priority: 'critical',
    kpis: [
      { label: 'Center', value: '3.64 GHz' },
      { label: 'Span', value: '100 MHz' },
      { label: 'Source', value: 'contract' },
    ],
    actions: ['Apri scenario RF', 'Collega DSP worker', 'Mostra signal path'],
  },
  {
    id: 'rf-bandplan',
    title: 'RF Bandplan / Antenna Context',
    subtitle: 'Bande, antenna systems, beamwidth, microstrip e tower infrastructure.',
    domain: 'rf',
    liveEndpoint: '/api/rfpro/bandplan',
    routeHint: '02_RF_Physics / 05_Antenna_System',
    priority: 'high',
    kpis: [
      { label: 'Layer', value: 'RF knowledge' },
      { label: 'Scenarios', value: 'V36' },
      { label: 'Visual', value: 'asset-ready' },
    ],
    actions: ['Esplora antenne', 'Apri beamwidth', 'Apri microstrip'],
  },
  {
    id: 'soc-noc-correlation',
    title: 'SOC/NOC Correlation',
    subtitle: 'Correlazione eventi RF/Telco/Cyber, evidence e scenario readiness.',
    domain: 'soc-noc',
    liveEndpoint: '/api/soc-noc/correlation/demo',
    routeHint: '11_Cyber_RF_Intelligence',
    priority: 'high',
    kpis: [
      { label: 'Events', value: 'contract' },
      { label: 'Mutation', value: 'disabled' },
      { label: 'Evidence', value: 'ready' },
    ],
    actions: ['Correla eventi', 'Apri evidence view', 'Collega NOC tiles'],
  },
  {
    id: 'dynamic-scenarios',
    title: 'Dynamic RF/Telco Scenarios',
    subtitle: 'Motore scenari V36: electronics, microstrip, antenna, tower, beamwidth, RF lab, UAV.',
    domain: 'scenarios',
    routeHint: 'V36 visual scenario runtime',
    priority: 'critical',
    kpis: [
      { label: 'Scenes', value: '7' },
      { label: 'Layers', value: '4' },
      { label: 'Mode', value: 'interactive' },
    ],
    actions: ['Seleziona scenario', 'Attiva physics layer', 'Attiva hotspots'],
  },
  {
    id: 'knowledge-base',
    title: 'Knowledge Base',
    subtitle: 'Base visuale e documentale RF/Telco/Cyber per didattica e laboratorio.',
    domain: 'knowledge',
    routeHint: '12_Knowledge_Base',
    priority: 'medium',
    kpis: [
      { label: 'Scope', value: 'RF/Telco/Cyber' },
      { label: 'Assets', value: 'visual' },
      { label: 'Use', value: 'training' },
    ],
    actions: ['Apri glossario', 'Apri teoria', 'Collega immagini/render'],
  },
]

export const commandCenterFusionMetaV37 = {
  title: 'TRFMC V37 Command Center Fusion',
  subtitle: 'Mission layer nativo React sopra V36, senza iframe, con contratti live 4181.',
  legacyReference: '/trfmc_official_safe_entrypoint_v6r3_command_center.html',
  legacyMode: 'reference-only-no-iframe',
}
""".strip() + "\n", encoding="utf-8")

CMD_COMPONENT.write_text(r"""
import { useEffect, useMemo, useState } from 'react'
import {
  extractString,
  fetchLiveContract,
  getEndpointHealth,
  type LiveContractResult,
} from '../shared/liveContractsV32R1'
import { commandCenterFusionMetaV37, commandCenterTilesV37, type CommandCenterTileV37 } from './commandCenterDataV37'

type LiveMap = Record<string, LiveContractResult | undefined>

function priorityRank(priority: CommandCenterTileV37['priority']) {
  if (priority === 'critical') return 0
  if (priority === 'high') return 1
  return 2
}

function domainLabel(domain: CommandCenterTileV37['domain']) {
  return domain.toUpperCase().replace('-', '/')
}

function LiveBadge({ tile, live }: { tile: CommandCenterTileV37; live?: LiveContractResult }) {
  if (!tile.liveEndpoint) {
    return <span className="v37-live-badge v37-live-local">LOCAL</span>
  }

  const health = getEndpointHealth(live)
  return <span className={`v37-live-badge v37-live-${health}`}>{health.toUpperCase()}</span>
}

function tileLiveDetail(tile: CommandCenterTileV37, live?: LiveContractResult) {
  if (!tile.liveEndpoint || !live?.data) return tile.routeHint

  if (tile.id === 'mission-control') {
    return `${extractString(live.data, ['source'])} · ${extractString(live.data, ['mode'])}`
  }

  if (tile.id === 'core-network') {
    return extractString(live.data, ['open5gs', 'readiness'])
  }

  if (tile.id === 'ran-simulator') {
    return extractString(live.data, ['ueransim', 'readiness'])
  }

  if (tile.id === 'rf-spectrum') {
    return `${extractString(live.data, ['contract_version'])} · ${extractString(live.data, ['spectrum', 'data_source'])}`
  }

  if (tile.id === 'rf-bandplan') {
    return extractString(live.data, ['contract_version'])
  }

  if (tile.id === 'soc-noc-correlation') {
    return extractString(live.data, ['data_source'])
  }

  return tile.routeHint
}

export function CommandCenterFusionV37() {
  const [liveMap, setLiveMap] = useState<LiveMap>({})
  const [tick, setTick] = useState(0)
  const [selectedDomain, setSelectedDomain] = useState<string>('all')

  useEffect(() => {
    const controller = new AbortController()
    let alive = true

    async function load() {
      const entries = await Promise.all(
        commandCenterTilesV37
          .filter((tile) => tile.liveEndpoint)
          .map(async (tile) => [tile.id, await fetchLiveContract(tile.liveEndpoint as string, controller.signal)] as const),
      )

      if (!alive) return
      setLiveMap(Object.fromEntries(entries))
    }

    load().catch(() => {
      if (alive) setLiveMap({})
    })

    return () => {
      alive = false
      controller.abort()
    }
  }, [tick])

  useEffect(() => {
    const timer = window.setInterval(() => setTick((value) => value + 1), 15000)
    return () => window.clearInterval(timer)
  }, [])

  const domains = useMemo(() => ['all', ...Array.from(new Set(commandCenterTilesV37.map((tile) => tile.domain)))], [])

  const visibleTiles = useMemo(() => {
    return commandCenterTilesV37
      .filter((tile) => selectedDomain === 'all' || tile.domain === selectedDomain)
      .sort((a, b) => priorityRank(a.priority) - priorityRank(b.priority))
  }, [selectedDomain])

  const liveOkCount = commandCenterTilesV37.filter((tile) => {
    if (!tile.liveEndpoint) return true
    return getEndpointHealth(liveMap[tile.id]) === 'ok'
  }).length

  return (
    <section className="v37-command-shell">
      <div className="v37-command-header">
        <div>
          <p>V37 COMMAND CENTER FUSION</p>
          <h2>{commandCenterFusionMetaV37.title}</h2>
          <span>{commandCenterFusionMetaV37.subtitle}</span>
        </div>
        <div className="v37-command-score">
          <strong>{liveOkCount}/{commandCenterTilesV37.length}</strong>
          <small>tiles ready</small>
        </div>
      </div>

      <div className="v37-command-controls">
        {domains.map((domain) => (
          <button
            key={domain}
            type="button"
            className={selectedDomain === domain ? 'v37-domain-active' : ''}
            onClick={() => setSelectedDomain(domain)}
          >
            {domain === 'all' ? 'ALL DOMAINS' : domainLabel(domain as CommandCenterTileV37['domain'])}
          </button>
        ))}
        <button type="button" onClick={() => setTick((value) => value + 1)}>
          Refresh live contracts
        </button>
      </div>

      <div className="v37-command-grid">
        {visibleTiles.map((tile) => {
          const live = liveMap[tile.id]
          return (
            <article key={tile.id} className={`v37-command-tile v37-priority-${tile.priority}`}>
              <div className="v37-tile-top">
                <span>{domainLabel(tile.domain)}</span>
                <LiveBadge tile={tile} live={live} />
              </div>
              <h3>{tile.title}</h3>
              <p>{tile.subtitle}</p>
              <code>{tile.liveEndpoint ?? tile.routeHint}</code>
              <div className="v37-live-detail">{tileLiveDetail(tile, live)}</div>

              <div className="v37-kpis">
                {tile.kpis.map((kpi) => (
                  <div key={`${tile.id}-${kpi.label}`}>
                    <span>{kpi.label}</span>
                    <strong>{kpi.value}</strong>
                  </div>
                ))}
              </div>

              <ul>
                {tile.actions.map((action) => (
                  <li key={`${tile.id}-${action}`}>{action}</li>
                ))}
              </ul>
            </article>
          )
        })}
      </div>

      <footer className="v37-command-footer">
        <span>Legacy V6R3: {commandCenterFusionMetaV37.legacyReference}</span>
        <strong>{commandCenterFusionMetaV37.legacyMode}</strong>
      </footer>
    </section>
  )
}
""".strip() + "\n", encoding="utf-8")

WRAPPER.write_text(r"""
import { CommandCenterFusionV37 } from '../../command_center/CommandCenterFusionV37'
import { RFOperationalDeckV36VisualScenarioRuntime } from './RFOperationalDeckV36VisualScenarioRuntime'

export function RFOperationalDeckV37CommandCenterFusion() {
  return (
    <>
      <CommandCenterFusionV37 />
      <RFOperationalDeckV36VisualScenarioRuntime />
    </>
  )
}
""".strip() + "\n", encoding="utf-8")

css_marker = "/* === TRFMC V37 COMMAND CENTER FUSION === */"
styles = STYLES.read_text(encoding="utf-8")
if css_marker not in styles:
    STYLES.write_text(styles + r"""

/* === TRFMC V37 COMMAND CENTER FUSION === */
.v37-command-shell{
  margin:18px;
  padding:18px;
  border:1px solid rgba(117,234,255,.26);
  border-radius:28px;
  background:
    radial-gradient(circle at 12% 0%,rgba(80,215,255,.18),transparent 34%),
    radial-gradient(circle at 88% 10%,rgba(141,255,189,.12),transparent 30%),
    linear-gradient(135deg,rgba(2,9,17,.98),rgba(4,14,25,.98));
  box-shadow:0 34px 95px rgba(0,0,0,.42), inset 0 0 44px rgba(80,215,255,.05);
}

.v37-command-header{
  display:flex;
  justify-content:space-between;
  align-items:flex-start;
  gap:20px;
  margin-bottom:14px;
}

.v37-command-header p{
  margin:0 0 6px;
  color:#75eaff;
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v37-command-header h2{
  margin:0;
  color:#f1fbff;
  font-size:25px;
}

.v37-command-header span{
  display:block;
  margin-top:8px;
  color:#96afc5;
  font-size:13px;
}

.v37-command-score{
  min-width:128px;
  text-align:center;
  border:1px solid rgba(141,255,189,.26);
  border-radius:18px;
  padding:12px;
  background:rgba(5,36,34,.58);
}

.v37-command-score strong{
  display:block;
  color:#8dffbd;
  font-size:25px;
}

.v37-command-score small{
  color:#9bb7a9;
}

.v37-command-controls{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  margin-bottom:14px;
}

.v37-command-controls button{
  border:1px solid rgba(103,198,255,.22);
  border-radius:999px;
  padding:8px 12px;
  background:rgba(6,19,34,.78);
  color:#a6bdd2;
  cursor:pointer;
  font-size:12px;
}

.v37-command-controls button.v37-domain-active{
  color:#06131d;
  background:linear-gradient(135deg,#75eaff,#8dffbd);
  border-color:transparent;
}

.v37-command-grid{
  display:grid;
  grid-template-columns:repeat(4,minmax(0,1fr));
  gap:12px;
}

.v37-command-tile{
  min-width:0;
  padding:14px;
  border-radius:20px;
  border:1px solid rgba(103,198,255,.18);
  background:rgba(5,17,31,.76);
}

.v37-priority-critical{
  border-color:rgba(117,234,255,.32);
}

.v37-priority-high{
  border-color:rgba(141,255,189,.25);
}

.v37-priority-medium{
  border-color:rgba(255,204,113,.22);
}

.v37-tile-top{
  display:flex;
  justify-content:space-between;
  gap:10px;
  align-items:center;
  margin-bottom:8px;
}

.v37-tile-top > span{
  color:#75eaff;
  font-size:10px;
  letter-spacing:.16em;
  text-transform:uppercase;
}

.v37-live-badge{
  border-radius:999px;
  padding:4px 8px;
  font-size:10px;
  font-weight:800;
}

.v37-live-ok{
  background:rgba(141,255,189,.16);
  color:#8dffbd;
}

.v37-live-warn,
.v37-live-local{
  background:rgba(255,204,113,.15);
  color:#ffd37b;
}

.v37-live-down{
  background:rgba(255,98,128,.16);
  color:#ff7890;
}

.v37-command-tile h3{
  margin:0 0 8px;
  color:#f1fbff;
  font-size:18px;
}

.v37-command-tile p{
  min-height:54px;
  color:#a9bed0;
  font-size:12px;
  line-height:1.42;
}

.v37-command-tile code{
  display:block;
  padding:7px 8px;
  border-radius:10px;
  color:#75eaff;
  background:rgba(1,8,15,.58);
  font-size:10px;
  word-break:break-all;
}

.v37-live-detail{
  margin:8px 0;
  color:#d9f9ff;
  font-size:12px;
  min-height:18px;
}

.v37-kpis{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:6px;
  margin:10px 0;
}

.v37-kpis div{
  padding:7px;
  border-radius:11px;
  background:rgba(7,31,31,.48);
  border:1px solid rgba(141,255,189,.12);
}

.v37-kpis span{
  display:block;
  color:#91a9b8;
  font-size:9px;
  text-transform:uppercase;
}

.v37-kpis strong{
  color:#8dffbd;
  font-size:12px;
}

.v37-command-tile ul{
  margin:8px 0 0;
  padding-left:18px;
  color:#c5d8e7;
  font-size:11px;
  line-height:1.4;
}

.v37-command-footer{
  display:flex;
  justify-content:space-between;
  gap:12px;
  margin-top:14px;
  color:#8da8ba;
  font-size:12px;
}

.v37-command-footer strong{
  color:#ffd37b;
}

@media (max-width:1300px){
  .v37-command-grid{grid-template-columns:repeat(2,minmax(0,1fr))}
}

@media (max-width:760px){
  .v37-command-header,
  .v37-command-footer{flex-direction:column}
  .v37-command-grid{grid-template-columns:1fr}
}
""", encoding="utf-8")

# Patch main
main_txt = MAIN.read_text(encoding="utf-8")
old_import = "import { RFOperationalDeckV36VisualScenarioRuntime } from '../rf_instruments/instruments/RFOperationalDeckV36VisualScenarioRuntime'"
new_import = "import { RFOperationalDeckV37CommandCenterFusion } from '../rf_instruments/instruments/RFOperationalDeckV37CommandCenterFusion'"

if new_import not in main_txt:
    if old_import not in main_txt and "RFOperationalDeckV37CommandCenterFusion" not in main_txt:
        raise SystemExit("ERRORE: import V36 non trovato in main.tsx")
    main_txt = main_txt.replace(old_import, new_import, 1)

main_txt = main_txt.replace("<RFOperationalDeckV36VisualScenarioRuntime />", "<RFOperationalDeckV37CommandCenterFusion />")
MAIN.write_text(main_txt, encoding="utf-8")

# Content checks
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

main_now = MAIN.read_text(encoding="utf-8")
styles_now = STYLES.read_text(encoding="utf-8")
component_now = CMD_COMPONENT.read_text(encoding="utf-8")
data_now = CMD_DATA.read_text(encoding="utf-8")
wrapper_now = WRAPPER.read_text(encoding="utf-8")

ok("command center data exists", CMD_DATA.exists())
ok("command center component exists", CMD_COMPONENT.exists())
ok("V37 wrapper exists", WRAPPER.exists())
ok("main imports/mounts V37", "RFOperationalDeckV37CommandCenterFusion" in main_now)
ok("main JSX mounts V37", "<RFOperationalDeckV37CommandCenterFusion />" in main_now)
ok("V36 preserved below V37", "RFOperationalDeckV36VisualScenarioRuntime" in wrapper_now)
ok("no iframe in V37 component", "<iframe" not in component_now.lower())
ok("mission tile exists", "Mission Control" in data_now)
ok("5G core tile exists", "5G Core Network" in data_now)
ok("RF spectrum tile exists", "RF Spectrum / Signal Workbench" in data_now)
ok("dynamic scenarios tile exists", "Dynamic RF/Telco Scenarios" in data_now)
ok("V37 CSS present", "v37-command-shell" in styles_now)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build
build_log = RDIR / "npm_build_v37r2r1.log"
build = subprocess.run(
    ["npm", "run", "build"],
    cwd=ROOT / "frontend",
    stdout=build_log.open("w"),
    stderr=subprocess.STDOUT,
)
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
    "http://127.0.0.1:4181/api/ran/ueransim/status",
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

rollback = RDIR / "rollback_v37r2r1_command_center_fusion.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/main.tsx.before_v37r2r1_{TS}" frontend/src/app/main.tsx
cp "{RDIR}/styles.css.before_v37r2r1_{TS}" frontend/src/styles.css
rm -rf frontend/src/command_center
rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV37CommandCenterFusion.tsx
echo "Rollback V37R2R1 completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "command_center_fusion_manifest_v37r2r1.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_COMMAND_CENTER_FUSION_V37R2R1_RECOVERY",
    "strategy": "native_react_command_center_fusion_above_v36_no_iframe",
    "frontend_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "created": [str(CMD_DATA), str(CMD_COMPONENT), str(WRAPPER)],
    "patched": [str(MAIN), str(STYLES)],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_COMMAND_CENTER_FUSION_V37R2R1_RECOVERY",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
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
    "frontend/src/command_center",
    "frontend/src/rf_instruments/instruments/RFOperationalDeckV37CommandCenterFusion.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_command_center_fusion_v37"
latest_r = ROOT / "runtime/releases/latest_command_center_fusion_v37"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
