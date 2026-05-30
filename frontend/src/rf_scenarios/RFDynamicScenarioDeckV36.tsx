import { useMemo, useState } from 'react'
import { rfScenariosV35, type RFScenario } from './scenarioDataV35'

type LayerKey = 'render' | 'physics' | 'metrics' | 'hotspots'

const assetHints: Record<string, string> = {
  electronics: '/trfmc_assets/visual_knowledge/01_electronics_symbols/electronics_symbols_basic_concepts.jpg',
  microstrip: '/trfmc_assets/visual_knowledge/02_antennas_microstrip/microstrip_patch_antenna_5g.jpg',
  'antenna-system': '/trfmc_assets/visual_knowledge/03_antennas_types/types_of_telecom_antennas.jpg',
  'tower-infrastructure': '/trfmc_assets/visual_knowledge/04_telco_infrastructure/telecom_towers_arabic_overview.jpg',
  beamwidth: '/trfmc_assets/visual_knowledge/03_antennas_types/beamwidth_narrow_wide.jpg',
  'rf-lab': '/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.jpg',
  'uav-isr': '/trfmc_assets/visual_knowledge/06_uav_rf_links/falco_xplorer_vs_bayraktar_tb2.jpg',
}

const sceneProfiles: Record<string, { stack: string; equation: string; instrument: string; action: string }> = {
  electronics: {
    stack: 'schematic → PCB → measurement',
    equation: 'V = I · R',
    instrument: 'DMM / Scope / Logic',
    action: 'Symbol-to-measurement mapping',
  },
  microstrip: {
    stack: 'patch → substrate → feed → ground',
    equation: 'S11 / Zin / εr',
    instrument: 'VNA / EM solver',
    action: 'Impedance and radiation analysis',
  },
  'antenna-system': {
    stack: 'element → array → sector → coverage',
    equation: 'G(θ,φ), HPBW',
    instrument: 'Antenna range / VSA',
    action: 'Pattern and application selection',
  },
  'tower-infrastructure': {
    stack: 'antenna → RRU/AAU → backhaul → core',
    equation: 'EIRP + link budget',
    instrument: 'NOC / spectrum / field test',
    action: 'Physical-logical site mapping',
  },
  beamwidth: {
    stack: 'main lobe → -3 dB points → coverage',
    equation: 'HPBW @ -3 dB',
    instrument: 'Spectrum / drive test',
    action: 'Coverage vs interference tradeoff',
  },
  'rf-lab': {
    stack: 'source → DUT → receiver → analysis',
    equation: 'S-parameters',
    instrument: 'VNA / VSA / SA',
    action: 'Measurement chain validation',
  },
  'uav-isr': {
    stack: 'airframe → payload → datalink → GCS',
    equation: 'C/N0, link margin',
    instrument: 'SDR / spectrum / telemetry',
    action: 'ISR RF link awareness',
  },
}

function ProceduralRender({ scenario, layers }: { scenario: RFScenario; layers: Record<LayerKey, boolean> }) {
  return (
    <div className={`v36-procedural v36-procedural-${scenario.visualMode}`}>
      <div className="v36-perspective-grid" />
      <div className="v36-atmosphere" />

      {layers.render ? (
        <div className="v36-render-stage">
          <div className="v36-render-core" />
          <div className="v36-render-secondary" />
          <div className="v36-render-tertiary" />
          <div className="v36-render-signal" />
        </div>
      ) : null}

      {layers.physics ? (
        <div className="v36-physics-layer">
          <div className="v36-field-lobe v36-field-a" />
          <div className="v36-field-lobe v36-field-b" />
          <div className="v36-vector-lines">
            {Array.from({ length: 9 }).map((_, index) => (
              <span key={index} style={{ transform: `rotate(${index * 20 - 80}deg)` }} />
            ))}
          </div>
        </div>
      ) : null}

      {layers.hotspots ? (
        <>
          {scenario.hotspots.map((hotspot) => (
            <button
              key={hotspot.id}
              type="button"
              className="v36-hotspot"
              style={{ left: `${hotspot.x}%`, top: `${hotspot.y}%` }}
              title={`${hotspot.label}: ${hotspot.value}`}
            >
              <i />
              <strong>{hotspot.label}</strong>
              <small>{hotspot.value}</small>
            </button>
          ))}
        </>
      ) : null}

      {layers.metrics ? (
        <div className="v36-floating-metrics">
          {scenario.kpis.map((kpi) => (
            <article key={`${scenario.id}-${kpi.label}`}>
              <span>{kpi.label}</span>
              <strong>{kpi.value}</strong>
            </article>
          ))}
        </div>
      ) : null}
    </div>
  )
}

export function RFDynamicScenarioDeckV36() {
  const [activeId, setActiveId] = useState(rfScenariosV35[0]?.id ?? 'electronics')
  const [layers, setLayers] = useState<Record<LayerKey, boolean>>({
    render: true,
    physics: true,
    metrics: true,
    hotspots: true,
  })

  const active = useMemo(
    () => rfScenariosV35.find((scenario) => scenario.id === activeId) ?? rfScenariosV35[0],
    [activeId],
  )

  const profile = sceneProfiles[active.id] ?? sceneProfiles.electronics
  const assetUrl = assetHints[active.id]

  const toggleLayer = (layer: LayerKey) => {
    setLayers((current) => ({ ...current, [layer]: !current[layer] }))
  }

  return (
    <section className="v36-scenario-shell">
      <div className="v36-scenario-header">
        <div>
          <p>V36 VISUAL SCENARIO RUNTIME</p>
          <h2>Dynamic RF/Telco Scenario Simulator</h2>
          <span>
            Scenari dinamici con render procedurale, layer fisici, hotspot, metriche e predisposizione asset 3D.
          </span>
        </div>
        <div className="v36-status-pack">
          <strong>{rfScenariosV35.length}</strong>
          <small>active scenarios</small>
        </div>
      </div>

      <div className="v36-tabs" role="tablist" aria-label="V36 scenario selector">
        {rfScenariosV35.map((scenario) => (
          <button
            key={scenario.id}
            type="button"
            className={scenario.id === active.id ? 'v36-tab-active' : ''}
            onClick={() => setActiveId(scenario.id)}
          >
            {scenario.title}
          </button>
        ))}
      </div>

      <div className="v36-layer-switches" aria-label="Scenario visual layers">
        {(['render', 'physics', 'metrics', 'hotspots'] as LayerKey[]).map((layer) => (
          <button
            key={layer}
            type="button"
            className={layers[layer] ? 'v36-layer-on' : ''}
            onClick={() => toggleLayer(layer)}
          >
            {layer}
          </button>
        ))}
      </div>

      <div className="v36-layout">
        <div className="v36-visual-column">
          <div className="v36-asset-frame" style={{ backgroundImage: `linear-gradient(90deg, rgba(2,9,17,.82), rgba(2,9,17,.34)), url(${assetUrl})` }}>
            <div>
              <span>asset-ready reference layer</span>
              <strong>{active.title}</strong>
              <small>{assetUrl}</small>
            </div>
          </div>

          <ProceduralRender scenario={active} layers={layers} />
        </div>

        <aside className="v36-control-panel">
          <p className="v36-eyebrow">{active.subtitle}</p>
          <h3>{active.title}</h3>
          <p>{active.mission}</p>

          <div className="v36-profile-grid">
            <article>
              <span>Signal stack</span>
              <strong>{profile.stack}</strong>
            </article>
            <article>
              <span>Equation / model</span>
              <strong>{profile.equation}</strong>
            </article>
            <article>
              <span>Instrument</span>
              <strong>{profile.instrument}</strong>
            </article>
            <article>
              <span>Scenario action</span>
              <strong>{profile.action}</strong>
            </article>
          </div>

          <div className="v36-knowledge-list">
            {active.knowledge.map((item, index) => (
              <div key={`${active.id}-${index}`}>
                <span>{index + 1}</span>
                <p>{item}</p>
              </div>
            ))}
          </div>
        </aside>
      </div>
    </section>
  )
}
