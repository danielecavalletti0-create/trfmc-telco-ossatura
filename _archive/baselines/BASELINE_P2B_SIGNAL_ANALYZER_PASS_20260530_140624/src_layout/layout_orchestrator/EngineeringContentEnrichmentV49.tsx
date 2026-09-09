type EngineeringSectionV49 = {
  id: string
  marker: string
  title: string
  subtitle: string
  operationalMeaning: string
  liveContracts: string[]
  microKpis: Array<{ label: string; meaning: string; target: string }>
  engineeringFocus: string[]
  operatorActions: string[]
}

const sectionAliasesV49: Record<string, string> = {
  'mission': 'mission-overview',
  'mission-control': 'mission-overview',
  'mission-overview': 'mission-overview',
  'overview': 'mission-overview',

  'visual': 'visual-assets',
  'visual-assets': 'visual-assets',
  'assets': 'visual-assets',

  'scenario': 'scenario-knowledge',
  'scenario-knowledge': 'scenario-knowledge',
  'knowledge': 'scenario-knowledge',
  'knowledge-binding': 'scenario-knowledge',
  'scenario-binding': 'scenario-knowledge',

  'navigation': 'navigation-architecture',
  'navigation-architecture': 'navigation-architecture',
  'navigation-map': 'navigation-architecture',
  'architecture': 'navigation-architecture',

  'command': 'command-center',
  'command-center': 'command-center',
  'mission-command': 'command-center',

  'dynamic': 'dynamic-scenarios',
  'dynamic-scenarios': 'dynamic-scenarios',
  'scenarios': 'dynamic-scenarios',
  'rf-scenarios': 'dynamic-scenarios',

  'engineering': 'full-engineering-stack',
  'full-engineering': 'full-engineering-stack',
  'full-engineering-stack': 'full-engineering-stack',
  'engineering-stack': 'full-engineering-stack',
}

const sectionsV49: EngineeringSectionV49[] = [
  {
    id: 'mission-overview',
    marker: 'V49_SECTION_MISSION_OVERVIEW',
    title: 'Mission Overview - Operational State Interpretation',
    subtitle: 'Readiness, liveness and control-plane trust baseline for the entire TRFMC stack.',
    operationalMeaning:
      'This section translates raw service status into an operator-grade view: frontend reachability, backend bridge health, FastAPI liveness, runtime freshness and degradation surface.',
    liveContracts: ['/api/health', '/api/mission/status'],
    microKpis: [
      { label: 'Liveness', meaning: 'Portal/API path is reachable and returning non-empty payloads.', target: 'HTTP 200 - non-zero bytes' },
      { label: 'Bridge source', meaning: 'Identifies whether data comes from readonly backend bridge, synthetic contract or future live source.', target: 'source field present' },
      { label: 'Runtime freshness', meaning: 'Confirms that the view is not stale after root-mount or hash routing changes.', target: 'Chrome DOM + screenshot evidence' },
    ],
    engineeringFocus: ['mission state', 'runtime health', 'API reachability', 'evidence chain'],
    operatorActions: ['verify port 5173/4181/8000', 'check mission status JSON', 'preserve freeze + rollback path'],
  },
  {
    id: 'visual-assets',
    marker: 'V49_SECTION_VISUAL_ASSETS',
    title: 'Visual Assets - RF Render Evidence Layer',
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
    marker: 'V49_SECTION_SCENARIO_KNOWLEDGE',
    title: 'Scenario Knowledge - RF/Telco Concept Binding',
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
    marker: 'V49_SECTION_NAVIGATION_ARCHITECTURE',
    title: 'Navigation Architecture - SPA Control Plane',
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
    marker: 'V49_SECTION_COMMAND_CENTER',
    title: 'Command Center - Live Contract Interpretation',
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
    marker: 'V49_SECTION_DYNAMIC_SCENARIOS',
    title: 'Dynamic Scenarios - RF/Telco Runtime Laboratory',
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
    marker: 'V49_SECTION_FULL_ENGINEERING_STACK',
    title: 'Full Engineering Stack - Integration View',
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

function normalizeSectionV49(activeSection: string) {
  const key = String(activeSection || '').trim().toLowerCase()
  return sectionAliasesV49[key] ?? key
}

function resolveSection(activeSection: string) {
  const normalized = normalizeSectionV49(activeSection)
  return sectionsV49.find((section) => section.id === normalized) ?? sectionsV49[0]
}

export function EngineeringContentEnrichmentV49({ activeSection }: { activeSection: string }) {
  const normalizedSection = normalizeSectionV49(activeSection)
  const section = resolveSection(activeSection)

  return (
    <section
      className="v49-engineering-enrichment trfmc-native-engineering-enrichment"
      data-trfmc-v49-engineering-enrichment="true"
      data-trfmc-v49-active-section={section.id}
      data-trfmc-v49-input-section={activeSection}
      data-trfmc-v49-normalized-section={normalizedSection}
    >
      <div className="v49-section-machine-marker" data-trfmc-v49-section-marker={section.marker}>
        {section.marker}
      </div>

      <div className="v49-enrichment-header trfmc-native-enrichment-header">
        <p>TRFMC V49 - Engineering Content Enrichment Baseline</p>
        <h2>{section.title}</h2>
        <span>{section.subtitle}</span>
      </div>

      <div className="v49-enrichment-grid trfmc-native-enrichment-grid">
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
