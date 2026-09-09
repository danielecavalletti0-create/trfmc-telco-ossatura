#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4D_B_COMMAND_CENTER_HOME_V63_REACT_PREVIEW_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
CSS="frontend/src/portal-os/portal-os.css"
MAIN="frontend/src/app/main.tsx"
MANIFEST="frontend/src/portal-os/portalManifest.ts"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_p4d_b_command_center_home.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p4d_command_center_home_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4d_command_center_home.diff"
RESTORE="$OUT/RESTORE_P4D_B_COMMAND_CENTER_HOME_V63_REACT_PREVIEW_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4D_B_COMMAND_CENTER_HOME_PASS_$TS"

safe_count_files() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn -E "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

safe_count_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then echo 0; return 0; fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_P4D_B_COMMAND_CENTER_HOME_V63_REACT_PREVIEW_V1"
echo "Command Center Home · V63-style · manifest governed · no V42 mutation"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ROOT" "$CSS" "$MAIN" "$MANIFEST"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/portal-os.css.before_$TS"
cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
cp -a "$BACKUP/portal-os.css.before_$TS" "$CSS"
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"

echo "RESTORE_P4D_B_COMMAND_CENTER_HOME_V63_REACT_PREVIEW_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA PortalOSRoot.tsx COMMAND CENTER HOME ==="

cat > "$ROOT" <<'TSX'
import React from 'react'
import {
  candidatePortalOSModules,
  portalOSCategories,
  portalOSModules,
  promotedPortalOSModules,
  referencePortalOSModules,
  reviewPortalOSModules,
  riskyPortalOSModules,
  visualPortalOSModules,
  type PortalOSModule,
} from './portalManifest'
import './portal-os.css'

type EndpointState = {
  id: string
  label: string
  url: string
  state: 'pending' | 'online' | 'offline'
  detail: string
}

type Lane = {
  id: string
  title: string
  category: string
  region: string
  meaning: string
}

const initialEndpoints: EndpointState[] = [
  { id: 'frontend', label: 'Vite frontend', url: '/', state: 'pending', detail: 'SPA shell' },
  { id: 'backend', label: 'Backend 8000', url: 'http://127.0.0.1:8000/api/health', state: 'pending', detail: 'health API' },
  { id: 'bridge', label: 'Bridge 4181', url: 'http://127.0.0.1:4181/api/health', state: 'pending', detail: 'RF bridge' },
]

const lanes: Lane[] = [
  {
    id: 'digital-twin',
    title: '3D RF Visual Twin',
    category: '3d-rf-visual-twin',
    region: 'center viewport',
    meaning: '3D renderer, asset twin, RF spatial context',
  },
  {
    id: 'antenna',
    title: 'RF / Antenna System',
    category: 'antenna-system',
    region: 'left module + viewport',
    meaning: 'Antenna explorer, RRU/RET/CPRI/AISG, pattern/downtilt',
  },
  {
    id: 'dsp',
    title: 'FFT / DSP / Signal',
    category: 'fft-dsp-signal',
    region: 'left module + viewport',
    meaning: 'Spectrum, waterfall, IQ, VSA, DSP chain',
  },
  {
    id: 'core-ran',
    title: '5G Core / RAN',
    category: '5g-core-ran',
    region: 'left module + evidence',
    meaning: 'Open5GS, UERANSIM, NAS, NGAP, PFCP, GTP-U',
  },
  {
    id: 'war-room',
    title: 'War Room / Evidence',
    category: 'war-room',
    region: 'right evidence',
    meaning: 'Event stream, QA, scenario evidence, controlled operations',
  },
  {
    id: 'knowledge',
    title: 'Knowledge / Academy',
    category: 'knowledge-academy',
    region: 'bottom knowledge',
    meaning: 'Theory, formulas, procedures, glossary',
  },
  {
    id: 'fiber',
    title: 'Fiber / Fronthaul',
    category: 'fiber-optic',
    region: 'module leaf',
    meaning: 'OTDR, ODF, attenuation, splice/loss budget',
  },
  {
    id: 'microwave',
    title: 'Microwave Link',
    category: 'microwave-link',
    region: 'module leaf',
    meaning: 'Smith chart, link budget, Fresnel, fade margin',
  },
  {
    id: 'metrology',
    title: 'RF Metrology',
    category: 'rf-metrology',
    region: 'module leaf',
    meaning: 'Calibration, uncertainty, RBW/VBW, attenuation, power',
  },
  {
    id: 'wifi-qam',
    title: 'Wi-Fi / QAM / OFDM',
    category: 'wifi-qam',
    region: 'module leaf',
    meaning: 'Wi-Fi 6/7/8, OFDM/QAM analysis',
  },
  {
    id: 'noc',
    title: 'NOC / Operations',
    category: 'noc-operations',
    region: 'right evidence',
    meaning: 'Health, status, uptime, alarms',
  },
  {
    id: 'sigint',
    title: 'Signal Intelligence',
    category: 'signal-intelligence',
    region: 'right evidence',
    meaning: 'Classification, evidence, restricted workflows',
  },
]

function statusLabel(value: string | undefined) {
  return String(value || 'unknown').toUpperCase()
}

function moduleScore(module: PortalOSModule) {
  return Number(module.promotionScore || 0)
}

function statusClass(module: PortalOSModule) {
  const status = String(module.status || '')
  if (status === 'promoted') return 'is-promoted'
  if (status.startsWith('candidate')) return 'is-candidate'
  if (status.includes('risk') || status.includes('review') || status.includes('quarantine')) return 'is-risk'
  return 'is-reference'
}

function modulesByCategory(category: string) {
  return portalOSModules.filter((module) => module.category === category)
}

function getLaneStats(category: string) {
  const modules = modulesByCategory(category)
  return {
    total: modules.length,
    promoted: modules.filter((module) => module.status === 'promoted').length,
    candidate: modules.filter((module) => String(module.status).startsWith('candidate')).length,
    review: modules.filter((module) => String(module.status).includes('review')).length,
    visual: modules.filter((module) => Number(module.canvas || 0) > 0).length,
    topScore: Math.max(0, ...modules.map(moduleScore)),
  }
}

const topOperationalModules = [...portalOSModules]
  .filter((module) => module.status === 'promoted' || String(module.status).startsWith('candidate'))
  .sort((a, b) => moduleScore(b) - moduleScore(a))
  .slice(0, 16)

const highRiskSummary = [
  { id: 'html_runtime_link', label: 'HTML runtime links', policy: 'manifest governed, not primary navigation' },
  { id: 'dangerous_dom', label: 'Dangerous DOM', policy: 'React rewrite before promotion' },
  { id: 'cdn', label: 'CDN assets', policy: 'localize before enterprise/offline packaging' },
  { id: 'iframe', label: 'Iframe', policy: 'not architecture, only controlled leaf if unavoidable' },
]

export function PortalOSRoot() {
  const [activeModuleId, setActiveModuleId] = React.useState('home')
  const [selectedLaneId, setSelectedLaneId] = React.useState('core-ran')
  const [endpoints, setEndpoints] = React.useState<EndpointState[]>(initialEndpoints)
  const [tick, setTick] = React.useState(0)

  React.useEffect(() => {
    let alive = true

    async function probe() {
      const next = await Promise.all(
        initialEndpoints.map(async (endpoint) => {
          try {
            const response = await fetch(endpoint.url, { cache: 'no-store' })
            return {
              ...endpoint,
              state: response.ok ? 'online' : 'offline',
              detail: `${response.status} ${response.statusText}`.trim(),
            } satisfies EndpointState
          } catch (error) {
            return {
              ...endpoint,
              state: endpoint.id === 'frontend' ? 'online' : 'offline',
              detail: error instanceof Error ? error.message.slice(0, 90) : 'browser probe blocked/offline',
            } satisfies EndpointState
          }
        })
      )

      if (alive) {
        setEndpoints(next)
        setTick((value) => value + 1)
      }
    }

    probe()
    const timer = window.setInterval(probe, 15000)

    return () => {
      alive = false
      window.clearInterval(timer)
    }
  }, [])

  const activeModule = React.useMemo<PortalOSModule>(() => {
    return portalOSModules.find((module) => module.id === activeModuleId) ?? portalOSModules[0]
  }, [activeModuleId])

  const selectedLane = React.useMemo(() => {
    return lanes.find((lane) => lane.id === selectedLaneId) ?? lanes[0]
  }, [selectedLaneId])

  const selectedLaneModules = React.useMemo(() => {
    return modulesByCategory(selectedLane.category)
      .sort((a, b) => moduleScore(b) - moduleScore(a))
      .slice(0, 10)
  }, [selectedLane])

  const onlineCount = endpoints.filter((endpoint) => endpoint.state === 'online').length
  const totalRisks = riskyPortalOSModules.length + reviewPortalOSModules.length

  return (
    <section
      className="trfmc-pos-root-v2 trfmc-command-center-v63"
      data-trfmc-portal-os-preview="mounted"
      data-trfmc-p4d-command-center-home="mounted"
    >
      <header className="trfmc-command-topbar">
        <div className="trfmc-command-brand">
          <span>TRFMC Portal OS</span>
          <strong>Command Center Home</strong>
          <em>V63-style · React governed · manifest source of truth</em>
        </div>

        <div className="trfmc-command-top-metrics">
          <article>
            <span>Modules</span>
            <strong>{portalOSModules.length}</strong>
          </article>
          <article>
            <span>Categories</span>
            <strong>{portalOSCategories.length}</strong>
          </article>
          <article>
            <span>Promoted</span>
            <strong>{promotedPortalOSModules.length}</strong>
          </article>
          <article>
            <span>Endpoints</span>
            <strong>{onlineCount}/{endpoints.length}</strong>
          </article>
        </div>
      </header>

      <div className="trfmc-command-layout">
        <aside className="trfmc-command-left">
          <div className="trfmc-command-panel-title">
            <span>Operational Lanes</span>
            <strong>{lanes.length}</strong>
          </div>

          <div className="trfmc-command-lanes">
            {lanes.map((lane) => {
              const stats = getLaneStats(lane.category)
              return (
                <button
                  key={lane.id}
                  type="button"
                  className={lane.id === selectedLane.id ? 'is-active' : ''}
                  onClick={() => {
                    setSelectedLaneId(lane.id)
                    const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]
                    if (first) setActiveModuleId(first.id)
                  }}
                >
                  <span>{lane.region}</span>
                  <strong>{lane.title}</strong>
                  <em>{stats.total} modules · {stats.candidate} candidate · {stats.visual} visual</em>
                </button>
              )
            })}
          </div>
        </aside>

        <main className="trfmc-command-center" data-trfmc-portal-os-viewport="mounted">
          <section className="trfmc-command-hero" data-trfmc-portal-os-home="mounted">
            <div>
              <p>Active Mission Viewport</p>
              <h1>{selectedLane.title}</h1>
              <span>{selectedLane.meaning}</span>
            </div>
            <article>
              <span>Selected module</span>
              <strong>{activeModule.title}</strong>
              <em>{activeModule.category} · {statusLabel(activeModule.status)}</em>
            </article>
          </section>

          <section className="trfmc-command-radar">
            <div className="trfmc-command-radar-core">
              <span>Manifest</span>
              <strong>{portalOSModules.length}</strong>
              <em>governed assets</em>
            </div>
            {lanes.slice(0, 8).map((lane, index) => {
              const stats = getLaneStats(lane.category)
              return (
                <div
                  key={lane.id}
                  className={`trfmc-command-radar-node node-${index + 1} ${lane.id === selectedLane.id ? 'is-active' : ''}`}
                >
                  <span>{lane.title}</span>
                  <strong>{stats.total}</strong>
                </div>
              )
            })}
          </section>

          <section className="trfmc-command-module-strip">
            <div className="trfmc-command-strip-head">
              <span>Lane modules</span>
              <strong>{selectedLane.category}</strong>
            </div>

            <div className="trfmc-command-module-grid">
              {selectedLaneModules.map((module) => (
                <button
                  key={module.id}
                  type="button"
                  className={activeModule.id === module.id ? `is-active ${statusClass(module)}` : statusClass(module)}
                  onClick={() => setActiveModuleId(module.id)}
                >
                  <span>{statusLabel(module.status)}</span>
                  <strong>{module.title}</strong>
                  <em>{moduleScore(module)} · canvas {module.canvas || 0} · {module.target || module.mode}</em>
                </button>
              ))}
            </div>
          </section>

          <section className="trfmc-command-active-card">
            <div>
              <span>Active module contract</span>
              <strong>{activeModule.title}</strong>
              <p>{activeModule.description || activeModule.mode || 'Manifest-governed module'}</p>
            </div>
            <dl>
              <div>
                <dt>Source</dt>
                <dd>{activeModule.source}</dd>
              </div>
              <div>
                <dt>Route</dt>
                <dd>{activeModule.route}</dd>
              </div>
              <div>
                <dt>Status</dt>
                <dd>{statusLabel(activeModule.status)}</dd>
              </div>
              <div>
                <dt>Risk</dt>
                <dd>{activeModule.risks && activeModule.risks.length ? activeModule.risks.join(', ') : 'clean / governed'}</dd>
              </div>
            </dl>
          </section>
        </main>

        <aside className="trfmc-command-right">
          <div className="trfmc-command-panel-title">
            <span>Command / Evidence</span>
            <strong>P4D-B</strong>
          </div>

          <section className="trfmc-command-evidence-block">
            <h3>Runtime health</h3>
            {endpoints.map((endpoint) => (
              <div key={endpoint.id} className={`trfmc-command-endpoint is-${endpoint.state}`}>
                <span>{endpoint.label}</span>
                <strong>{endpoint.state}</strong>
                <em>{endpoint.detail}</em>
              </div>
            ))}
          </section>

          <section className="trfmc-command-evidence-block">
            <h3>QA / Risk policy</h3>
            {highRiskSummary.map((risk) => (
              <article key={risk.id}>
                <span>{risk.label}</span>
                <strong>{risk.policy}</strong>
              </article>
            ))}
          </section>

          <section className="trfmc-command-evidence-block">
            <h3>Event stream</h3>
            <p>tick #{tick}</p>
            <p>Portal OS home is now manifest-governed. Legacy HTML remains source/reference, not primary runtime.</p>
            <p>Risk queue: {totalRisks} modules · visual candidates: {visualPortalOSModules.length}</p>
          </section>
        </aside>
      </div>

      <footer className="trfmc-command-footer">
        <span>Baseline: P4C-B manifest commit PASS</span>
        <span>Next: promote V63-grade home to default only after visual approval</span>
        <span>No V42 mutation · no iframe · no unsafe DOM</span>
      </footer>
    </section>
  )
}
TSX

echo
echo "=== 2) CREA portal-os.css COMMAND CENTER ==="

cat > "$CSS" <<'CSS'
.trfmc-pos-root-v2.trfmc-command-center-v63 {
  min-height: 100vh;
  overflow: hidden;
  background:
    radial-gradient(circle at 16% 0%, rgba(34, 211, 238, .14), transparent 28%),
    radial-gradient(circle at 84% 16%, rgba(16, 185, 129, .11), transparent 30%),
    radial-gradient(circle at 52% 86%, rgba(59, 130, 246, .09), transparent 34%),
    linear-gradient(135deg, #020712 0%, #031020 48%, #01040a 100%);
  color: #e8f7ff;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

.trfmc-command-topbar {
  height: 70px;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 16px;
  padding: 0 16px;
  border-bottom: 1px solid rgba(103, 232, 249, .18);
  background: rgba(0, 6, 16, .90);
  box-shadow: 0 18px 70px rgba(0, 0, 0, .36);
}

.trfmc-command-brand span,
.trfmc-command-panel-title span,
.trfmc-command-strip-head span,
.trfmc-command-active-card span,
.trfmc-command-evidence-block h3 {
  display: block;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-command-brand strong {
  display: block;
  margin-top: 3px;
  color: #e8f7ff;
  font-size: 20px;
  line-height: 1;
  letter-spacing: .04em;
  text-transform: uppercase;
}

.trfmc-command-brand em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 10px;
  font-style: normal;
}

.trfmc-command-top-metrics {
  display: grid;
  grid-template-columns: repeat(4, minmax(92px, 1fr));
  gap: 8px;
}

.trfmc-command-top-metrics article {
  border: 1px solid rgba(103, 232, 249, .15);
  border-radius: 12px;
  background: rgba(2, 12, 24, .58);
  padding: 8px 10px;
  text-align: center;
}

.trfmc-command-top-metrics span {
  display: block;
  color: #9fb8ca;
  font-size: 8.5px;
  font-weight: 900;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-top-metrics strong {
  display: block;
  margin-top: 4px;
  color: #86efac;
  font-size: 18px;
  line-height: 1;
}

.trfmc-command-layout {
  height: calc(100vh - 112px);
  min-height: 0;
  display: grid;
  grid-template-columns: 300px minmax(0, 1fr) 342px;
  gap: 10px;
  padding: 10px;
}

.trfmc-command-left,
.trfmc-command-center,
.trfmc-command-right {
  min-height: 0;
  border: 1px solid rgba(103, 232, 249, .15);
  border-radius: 18px;
  background: rgba(2, 12, 24, .72);
  box-shadow: 0 24px 90px rgba(0, 0, 0, .34);
}

.trfmc-command-left,
.trfmc-command-right {
  overflow: hidden;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
}

.trfmc-command-center {
  overflow: auto;
  padding: 10px;
}

.trfmc-command-panel-title {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border-bottom: 1px solid rgba(103, 232, 249, .13);
}

.trfmc-command-panel-title strong,
.trfmc-command-strip-head strong {
  color: #86efac;
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-command-lanes {
  overflow: auto;
  padding: 10px;
  display: grid;
  gap: 8px;
}

.trfmc-command-lanes button,
.trfmc-command-module-grid button {
  text-align: left;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 14px;
  background:
    linear-gradient(180deg, rgba(0, 10, 22, .62), rgba(0, 5, 12, .48));
  color: inherit;
  padding: 10px;
  cursor: pointer;
}

.trfmc-command-lanes button.is-active,
.trfmc-command-lanes button:hover,
.trfmc-command-module-grid button.is-active,
.trfmc-command-module-grid button:hover {
  border-color: rgba(134, 239, 172, .42);
  background: rgba(8, 47, 38, .24);
}

.trfmc-command-lanes span,
.trfmc-command-module-grid span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-lanes strong,
.trfmc-command-module-grid strong {
  display: block;
  margin-top: 5px;
  color: #e8f7ff;
  font-size: 12px;
  line-height: 1.12;
}

.trfmc-command-lanes em,
.trfmc-command-module-grid em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 9.5px;
  font-style: normal;
  line-height: 1.25;
}

.trfmc-command-hero {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(230px, .35fr);
  gap: 10px;
  border: 1px solid rgba(103, 232, 249, .14);
  border-radius: 18px;
  padding: 14px;
  background:
    radial-gradient(circle at 15% 0%, rgba(103, 232, 249, .12), transparent 35%),
    linear-gradient(180deg, rgba(2, 18, 34, .80), rgba(0, 6, 16, .52));
}

.trfmc-command-hero p {
  margin: 0 0 8px;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-command-hero h1 {
  margin: 0 0 8px;
  color: #e8f7ff;
  font-size: clamp(28px, 3.1vw, 44px);
  line-height: .96;
}

.trfmc-command-hero span {
  color: #9fb8ca;
  font-size: 13px;
  line-height: 1.42;
}

.trfmc-command-hero article {
  display: grid;
  align-content: center;
  border: 1px solid rgba(134, 239, 172, .18);
  border-radius: 16px;
  padding: 12px;
  background: rgba(8, 47, 38, .20);
}

.trfmc-command-hero article span,
.trfmc-command-active-card dt {
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-hero article strong {
  margin-top: 6px;
  color: #e8f7ff;
  font-size: 16px;
  line-height: 1.08;
}

.trfmc-command-hero article em {
  margin-top: 7px;
  color: #86efac;
  font-size: 10px;
  font-style: normal;
}

.trfmc-command-radar {
  position: relative;
  min-height: 300px;
  margin-top: 10px;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 18px;
  overflow: hidden;
  background:
    radial-gradient(circle at 50% 50%, rgba(103, 232, 249, .08), transparent 12%),
    radial-gradient(circle at 50% 50%, rgba(103, 232, 249, .05), transparent 32%),
    linear-gradient(180deg, rgba(0, 6, 16, .55), rgba(0, 3, 8, .40));
}

.trfmc-command-radar::before,
.trfmc-command-radar::after {
  content: "";
  position: absolute;
  inset: 28px;
  border: 1px solid rgba(103, 232, 249, .14);
  border-radius: 999px;
}

.trfmc-command-radar::after {
  inset: 72px;
  border-color: rgba(134, 239, 172, .12);
}

.trfmc-command-radar-core {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 154px;
  height: 154px;
  transform: translate(-50%, -50%);
  display: grid;
  place-items: center;
  text-align: center;
  border: 1px solid rgba(134, 239, 172, .32);
  border-radius: 999px;
  background: rgba(0, 12, 24, .86);
  z-index: 3;
}

.trfmc-command-radar-core span,
.trfmc-command-radar-node span {
  display: block;
  color: #67e8f9;
  font-size: 9px;
  font-weight: 950;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.trfmc-command-radar-core strong {
  display: block;
  color: #86efac;
  font-size: 34px;
  line-height: 1;
}

.trfmc-command-radar-core em {
  color: #9fb8ca;
  font-size: 10px;
  font-style: normal;
}

.trfmc-command-radar-node {
  position: absolute;
  min-width: 118px;
  max-width: 168px;
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 14px;
  padding: 8px;
  background: rgba(0, 8, 18, .82);
  z-index: 4;
}

.trfmc-command-radar-node.is-active {
  border-color: rgba(134, 239, 172, .55);
  box-shadow: 0 0 0 1px rgba(134, 239, 172, .10), 0 0 34px rgba(16, 185, 129, .13);
}

.trfmc-command-radar-node strong {
  display: block;
  margin-top: 3px;
  color: #e8f7ff;
  font-size: 18px;
}

.trfmc-command-radar-node.node-1 { left: 8%; top: 18%; }
.trfmc-command-radar-node.node-2 { right: 9%; top: 15%; }
.trfmc-command-radar-node.node-3 { left: 13%; bottom: 17%; }
.trfmc-command-radar-node.node-4 { right: 12%; bottom: 18%; }
.trfmc-command-radar-node.node-5 { left: 42%; top: 8%; }
.trfmc-command-radar-node.node-6 { left: 42%; bottom: 8%; }
.trfmc-command-radar-node.node-7 { left: 5%; top: 48%; }
.trfmc-command-radar-node.node-8 { right: 5%; top: 48%; }

.trfmc-command-module-strip,
.trfmc-command-active-card {
  margin-top: 10px;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 18px;
  background: rgba(0, 6, 16, .36);
  padding: 10px;
}

.trfmc-command-strip-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(103, 232, 249, .11);
}

.trfmc-command-module-grid {
  margin-top: 8px;
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 8px;
}

.trfmc-command-module-grid button.is-promoted {
  border-color: rgba(134, 239, 172, .24);
}

.trfmc-command-module-grid button.is-risk {
  border-color: rgba(248, 113, 113, .28);
}

.trfmc-command-active-card {
  display: grid;
  grid-template-columns: minmax(0, .8fr) minmax(0, 1.2fr);
  gap: 12px;
}

.trfmc-command-active-card strong {
  display: block;
  margin-top: 6px;
  color: #e8f7ff;
  font-size: 18px;
}

.trfmc-command-active-card p {
  margin: 8px 0 0;
  color: #9fb8ca;
  font-size: 12px;
  line-height: 1.4;
}

.trfmc-command-active-card dl {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin: 0;
}

.trfmc-command-active-card div {
  min-width: 0;
}

.trfmc-command-active-card dd {
  margin: 4px 0 0;
  color: #e8f7ff;
  font-size: 10.5px;
  line-height: 1.28;
  word-break: break-word;
}

.trfmc-command-right {
  overflow: auto;
}

.trfmc-command-evidence-block {
  margin: 10px;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 14px;
  padding: 10px;
  background: rgba(0, 6, 16, .34);
}

.trfmc-command-evidence-block h3 {
  margin: 0 0 8px;
}

.trfmc-command-evidence-block p {
  margin: 6px 0;
  color: #9fb8ca;
  font-size: 11px;
  line-height: 1.38;
}

.trfmc-command-evidence-block article {
  padding: 8px 0;
  border-top: 1px solid rgba(103, 232, 249, .10);
}

.trfmc-command-evidence-block article span {
  display: block;
  color: #67e8f9;
  font-size: 9px;
  font-weight: 950;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.trfmc-command-evidence-block article strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 10.5px;
  line-height: 1.3;
}

.trfmc-command-endpoint {
  display: grid;
  gap: 3px;
  padding: 8px 0;
  border-top: 1px solid rgba(103, 232, 249, .10);
}

.trfmc-command-endpoint span {
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-command-endpoint strong {
  color: #fbbf24;
  font-size: 10px;
  text-transform: uppercase;
}

.trfmc-command-endpoint.is-online strong {
  color: #86efac;
}

.trfmc-command-endpoint.is-offline strong {
  color: #f87171;
}

.trfmc-command-endpoint em {
  color: #9fb8ca;
  font-size: 9px;
  font-style: normal;
}

.trfmc-command-footer {
  height: 42px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  align-items: center;
  padding: 0 14px;
  border-top: 1px solid rgba(103, 232, 249, .16);
  background: rgba(0, 6, 16, .88);
}

.trfmc-command-footer span {
  color: #9fb8ca;
  font-size: 10px;
  text-align: center;
}

@media (max-width: 1440px) {
  .trfmc-command-layout {
    grid-template-columns: 270px minmax(0, 1fr) 310px;
  }

  .trfmc-command-module-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 1180px) {
  .trfmc-command-layout {
    grid-template-columns: 250px minmax(0, 1fr);
  }

  .trfmc-command-right {
    display: none;
  }

  .trfmc-command-top-metrics {
    grid-template-columns: repeat(2, minmax(92px, 1fr));
  }
}
CSS

echo
echo "=== 3) DIFF ==="
git diff -- "$ROOT" "$CSS" "$MAIN" > "$DIFF" || true
sed -n '1,260p' "$DIFF"

echo
echo "=== 4) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  "$RESTORE"
  BUILD_RESULT="FAIL_RESTORED"
fi

echo
echo "=== 5) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

FRONTEND_HTTP_NON_200="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
FRONTEND_HTTP_ZERO_BYTES="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 6) STATIC GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" frontend/src/portal-os "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" frontend/src/portal-os "$MAIN")"
  EXTRA_ROOT_CALLS="$(safe_count_files "\\bcreateRoot[[:space:]]*\\(" frontend/src/portal-os)"
  V42_P4D_COUNT="$(safe_count_files "P4D|trfmc-command|Command Center Home|PortalOSRoot" frontend/src/layout_orchestrator 2>/dev/null || true)"
  P4D_MARKER_SOURCE="$(safe_count_files "data-trfmc-p4d-command-center-home" "$ROOT")"
  COMMAND_CLASS_SOURCE="$(safe_count_files "trfmc-command-center-v63|trfmc-command-layout|trfmc-command-radar" "$ROOT" "$CSS")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_call_in_portal_os\t$([ "$EXTRA_ROOT_CALLS" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_CALLS"
  echo -e "v42_not_touched_by_p4d\t$([ "$V42_P4D_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4D_COUNT"
  echo -e "p4d_marker_source_present\t$([ "$P4D_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$P4D_MARKER_SOURCE"
  echo -e "command_center_css_present\t$([ "$COMMAND_CLASS_SOURCE" -gt 4 ] && echo PASS || echo FAIL)\t$COMMAND_CLASS_SOURCE"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 7) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    CHROME_BIN="google-chrome"
  elif command -v chromium >/dev/null 2>&1; then
    CHROME_BIN="chromium"
  else
    CHROME_BIN=""
  fi

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
    echo "NO_CHROME_AVAILABLE" > "$DOMERR"
    echo "NO_CHROME_AVAILABLE" > "$SCREENERR"
  fi
else
  echo "BUILD_NOT_PASS" > "$DOM"
  echo "BUILD_NOT_PASS" > "$DOMERR"
  echo "BUILD_NOT_PASS" > "$SCREENERR"
fi

PREVIEW_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$DOM")"
P4D_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p4d-command-center-home="mounted"' "$DOM")"
VIEWPORT_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-viewport="mounted"' "$DOM")"
TITLE_COUNT="$(safe_count_literal 'Command Center Home' "$DOM")"
ACTIVE_VIEWPORT_COUNT="$(safe_count_literal 'Active Mission Viewport' "$DOM")"
LANES_COUNT="$(safe_count_literal 'Operational Lanes' "$DOM")"
EVIDENCE_COUNT="$(safe_count_literal 'Command / Evidence' "$DOM")"
RADAR_COUNT="$(safe_count_literal 'Manifest' "$DOM")"
V42_TITLE_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "PREVIEW_MARKER_COUNT=$PREVIEW_MARKER_COUNT"
echo "P4D_MARKER_COUNT=$P4D_MARKER_COUNT"
echo "VIEWPORT_MARKER_COUNT=$VIEWPORT_MARKER_COUNT"
echo "TITLE_COUNT=$TITLE_COUNT"
echo "ACTIVE_VIEWPORT_COUNT=$ACTIVE_VIEWPORT_COUNT"
echo "LANES_COUNT=$LANES_COUNT"
echo "EVIDENCE_COUNT=$EVIDENCE_COUNT"
echo "RADAR_COUNT=$RADAR_COUNT"
echo "V42_TITLE_COUNT=$V42_TITLE_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FRONTEND_HTTP_NON_200" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$FRONTEND_HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$PREVIEW_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_PREVIEW_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P4D_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_P4D_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$VIEWPORT_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_VIEWPORT"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$TITLE_COUNT" = "0" ]; then RESULT="REVIEW_TITLE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$ACTIVE_VIEWPORT_COUNT" = "0" ]; then RESULT="REVIEW_ACTIVE_VIEWPORT"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$LANES_COUNT" = "0" ]; then RESULT="REVIEW_LANES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$EVIDENCE_COUNT" = "0" ]; then RESULT="REVIEW_EVIDENCE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE_IN_PORTAL_OS"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4D-B COMMAND CENTER HOME PASS

Timestamp: $TS

Status:
- Portal OS preview transformed into V63-style Command Center Home.
- Source of truth: portalOSModules manifest.
- V42 untouched.
- No iframe.
- No unsafe DOM mutation.
- No secondary root.
- Build PASS.
- HTTP PASS.
- Static PASS.
- DOM PASS.
- Screenshot PASS.

Next:
P4D-C visual polish/readability gate or P4E Data Fabric/CORS bridge normalization.
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4D_B_COMMAND_CENTER_HOME_V63_REACT_PREVIEW_V1",
  "mutation": "portal_os_command_center_home",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $FRONTEND_HTTP_NON_200,
  "frontend_http_zero_bytes": $FRONTEND_HTTP_ZERO_BYTES,
  "static_failures": $STATIC_FAILS,
  "dom_result": "$DOM_RESULT",
  "preview_marker_count": $PREVIEW_MARKER_COUNT,
  "p4d_marker_count": $P4D_MARKER_COUNT,
  "viewport_marker_count": $VIEWPORT_MARKER_COUNT,
  "title_count": $TITLE_COUNT,
  "active_viewport_count": $ACTIVE_VIEWPORT_COUNT,
  "lanes_count": $LANES_COUNT,
  "evidence_count": $EVIDENCE_COUNT,
  "radar_count": $RADAR_COUNT,
  "v42_title_count": $V42_TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4d_b_command_center_home_v63_react_preview_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4D_B_COMMAND_CENTER_HOME_V63_REACT_PREVIEW_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
