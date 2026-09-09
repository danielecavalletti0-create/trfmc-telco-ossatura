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
