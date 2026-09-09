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
import { topWorkingPages, workingPageCategories, workingPagesByCategory } from './workingPagesRegistry'

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
  { id: 'backend', label: 'Backend 8000', url: '/trfmc-api/backend/api/health', state: 'pending', detail: 'same-origin proxy → 8000' },
  { id: 'bridge', label: 'Bridge 4181', url: '/trfmc-api/bridge/api/health', state: 'pending', detail: 'same-origin proxy → 4181' },
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

function bestModuleIdForLane(laneId: string) {
  const lane = lanes.find((item) => item.id === laneId) ?? lanes[0]
  const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]
  return first?.id ?? 'home'
}

function routeForModule(module?: PortalOSModule) {
  const route = module?.route || '#portal-os-preview'
  return route.startsWith('#') ? route : `#${route}`
}

function legacyUrlForModule(module?: PortalOSModule) {
  const source = module?.source || ''
  if (!source.startsWith('frontend/public/')) return ''
  if (!source.endsWith('.html')) return ''
  return `/${source.replace('frontend/public/', '')}`
}

function moduleFromCurrentHash() {
  if (typeof window === 'undefined') return undefined
  return portalOSModules.find((module) => routeForModule(module) === window.location.hash)
}

function laneIdForModule(module?: PortalOSModule) {
  const lane = lanes.find((item) => item.category === module?.category)
  return lane?.id ?? 'core-ran'
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

const dashboardLaneIds = ['core-ran', 'dsp', 'antenna', 'digital-twin', 'war-room', 'noc', 'sigint', 'knowledge']

const highRiskSummary = [
  { id: 'html_runtime_link', label: 'HTML runtime links', policy: 'manifest governed, not primary navigation' },
  { id: 'dangerous_dom', label: 'Dangerous DOM', policy: 'React rewrite before promotion' },
  { id: 'cdn', label: 'CDN assets', policy: 'localize before enterprise/offline packaging' },
  { id: 'iframe', label: 'Iframe', policy: 'not architecture, only controlled leaf if unavoidable' },
]

export function PortalOSRoot() {
  const [selectedLaneId, setSelectedLaneId] = React.useState(() => laneIdForModule(moduleFromCurrentHash()))
  const [activeModuleId, setActiveModuleId] = React.useState(() => moduleFromCurrentHash()?.id ?? bestModuleIdForLane('core-ran'))
  const [endpoints, setEndpoints] = React.useState<EndpointState[]>(initialEndpoints)
  const [tick, setTick] = React.useState(0)

  React.useEffect(() => {
    const syncFromHash = () => {
      const module = moduleFromCurrentHash()
      if (!module) return
      setActiveModuleId(module.id)
      setSelectedLaneId(laneIdForModule(module))
    }

    syncFromHash()
    window.addEventListener('hashchange', syncFromHash)

    return () => {
      window.removeEventListener('hashchange', syncFromHash)
    }
  }, [])

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
              detail:
                endpoint.id === 'bridge'
                  ? 'same-origin proxy pending; restart Vite if still blocked'
                  : error instanceof Error
                    ? error.message.slice(0, 90)
                    : 'browser probe blocked/offline',
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
  const riskModuleIds = new Set([...riskyPortalOSModules, ...reviewPortalOSModules].map((module) => module.id))
  const totalRisks = riskModuleIds.size

  return (
    <section
      className="trfmc-pos-root-v2 trfmc-command-center-v63"
      data-trfmc-portal-os-preview="mounted"
      data-trfmc-p4d-command-center-home="mounted"
      data-trfmc-p4dc-visual-correction="mounted"
      data-trfmc-p4e-data-fabric-dashboard="mounted"
      data-trfmc-p4f-dashboard-route-links="mounted"
      data-trfmc-p4g-route-registry="mounted"
      data-trfmc-p5b-real-legacy-links="mounted"
      data-trfmc-p6a-working-real-pages="mounted"
    >
      <header className="trfmc-command-topbar">
        <div className="trfmc-command-brand">
          <span>TRFMC Portal OS</span>
          <a
            className="trfmc-p8d-academy-ops-entry"
            href="/trfmc_academy_operations_center_v1.html"
            target="_blank"
            rel="noreferrer"
            data-trfmc-p8d-academy-ops-entry="mounted"
          >
            Academy / Operations Center
          </a>
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

          <section className="trfmc-command-working-pages" data-trfmc-working-real-pages="active">
            <div className="trfmc-command-strip-head">
              <span>Working real pages</span>
              <strong>{topWorkingPages.length} verified links · {workingPageCategories.length} categories</strong>
            </div>

            <div className="trfmc-command-working-category-row">
              {workingPageCategories.slice(0, 12).map((category) => (
                <span key={category}>
                  {category} · {workingPagesByCategory(category).length}
                </span>
              ))}
            </div>

            <div className="trfmc-command-working-grid">
              {topWorkingPages.map((page) => (
                <a key={page.url} href={page.url} target="_blank" rel="noreferrer" data-trfmc-working-page-link={page.url}>
                  <span>{page.category}</span>
                  <strong>{page.title}</strong>
                  <em>{page.url} · canvas {page.domCanvas || page.sourceCanvas} · RF hits {page.rfHits}</em>
                </a>
              ))}
            </div>
          </section>

          <section className="trfmc-command-dashboard-pages" data-trfmc-dashboard-pages="active">
            <div className="trfmc-command-strip-head">
              <span>Dashboard pages</span>
              <strong>principal routes active</strong>
            </div>

            <div className="trfmc-command-dashboard-grid">
              {dashboardLaneIds.map((laneId) => {
                const lane = lanes.find((item) => item.id === laneId)
                if (!lane) return null
                const stats = getLaneStats(lane.category)
                const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]

                return (
                  <button
                    key={lane.id}
                    type="button"
                    className={lane.id === selectedLane.id ? 'is-active' : ''}
                    onClick={() => {
                      setSelectedLaneId(lane.id)
                      if (first) setActiveModuleId(first.id)
                    }}
                  >
                    <span>dashboard</span>
                    <strong>{lane.title}</strong>
                    <em>{stats.total} modules · {stats.visual} visual · {first?.title ?? 'no module'}</em>
                  </button>
                )
              })}
            </div>
          </section>

          <section className="trfmc-command-route-links" data-trfmc-dashboard-route-links="active">
            <div className="trfmc-command-strip-head">
              <span>Page links / route verification</span>
              <strong>manifest controlled</strong>
            </div>

            <div className="trfmc-command-route-grid">
              {dashboardLaneIds.map((laneId) => {
                const lane = lanes.find((item) => item.id === laneId)
                if (!lane) return null
                const first = modulesByCategory(lane.category).sort((a, b) => moduleScore(b) - moduleScore(a))[0]
                const route = routeForModule(first)

                return (
                  <a
                    key={lane.id}
                    href={route}
                    data-trfmc-route-link={lane.id}
                    onClick={() => {
                      setSelectedLaneId(lane.id)
                      if (first) setActiveModuleId(first.id)
                    }}
                  >
                    <span>open route</span>
                    <strong>{lane.title}</strong>
                    <em>{route} · {first?.title ?? 'no module mapped'}</em>
                  </a>
                )
              })}
            </div>
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

            <div className="trfmc-command-real-page-link" data-trfmc-real-page-link="active">
              <span>Real page link</span>
              {legacyUrlForModule(activeModule) ? (
                <a href={legacyUrlForModule(activeModule)} target="_blank" rel="noreferrer">
                  Apri pagina reale HTML
                </a>
              ) : (
                <strong>Modulo React / nessuna pagina legacy diretta</strong>
              )}
              <em>{legacyUrlForModule(activeModule) || 'native-react-or-manifest-only'}</em>
            </div>
          </section>
        </main>

        <aside className="trfmc-command-right">
          <div className="trfmc-command-panel-title">
            <span>Command / Evidence</span>
            <strong>P4E</strong>
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
            <p>Portal OS route registry is active: manifest hashes now open governed Portal OS module views.</p>
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
