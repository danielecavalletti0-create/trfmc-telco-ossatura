import { useMemo, useState } from 'react'
import { rfScenariosV35, type RFScenario } from './scenarioDataV35'

function ScenarioVisual({ scenario }: { scenario: RFScenario }) {
  return (
    <div className={`v35-scenario-visual v35-mode-${scenario.visualMode}`}>
      <div className="v35-grid-floor" />
      <div className="v35-ambient-glow" />

      <div className="v35-object-stage">
        {scenario.visualMode === 'electronics' ? (
          <div className="v35-electronics-board">
            {['R', 'C', 'L', 'GND', 'DIODE', 'BJT', 'FET', 'LOGIC', 'RF'].map((item) => (
              <span key={item}>{item}</span>
            ))}
          </div>
        ) : null}

        {scenario.visualMode === 'microstrip' ? (
          <div className="v35-microstrip-stack">
            <div className="v35-layer v35-patch" />
            <div className="v35-layer v35-substrate" />
            <div className="v35-layer v35-ground" />
            <div className="v35-feed" />
            <div className="v35-radiation-lobe" />
          </div>
        ) : null}

        {scenario.visualMode === 'antenna-system' ? (
          <div className="v35-antenna-gallery">
            <div className="v35-yagi" />
            <div className="v35-panel" />
            <div className="v35-dish" />
            <div className="v35-horn" />
            <div className="v35-smallcell" />
          </div>
        ) : null}

        {scenario.visualMode === 'tower-infrastructure' ? (
          <div className="v35-tower-yard">
            <div className="v35-lattice-tower" />
            <div className="v35-monopole" />
            <div className="v35-radome" />
            <div className="v35-cabinet" />
            <div className="v35-solar" />
          </div>
        ) : null}

        {scenario.visualMode === 'beamwidth' ? (
          <div className="v35-beamwidth-scene">
            <div className="v35-tower-left" />
            <div className="v35-tower-right" />
            <div className="v35-beam-narrow" />
            <div className="v35-beam-wide" />
          </div>
        ) : null}

        {scenario.visualMode === 'rf-lab' ? (
          <div className="v35-rf-lab">
            <div className="v35-screen v35-smith">SMITH</div>
            <div className="v35-screen v35-sparams">S11/S21</div>
            <div className="v35-instrument">VSA/VNA</div>
            <div className="v35-parabola" />
          </div>
        ) : null}

        {scenario.visualMode === 'uav-isr' ? (
          <div className="v35-uav-scene">
            <div className="v35-uav v35-uav-a" />
            <div className="v35-uav v35-uav-b" />
            <div className="v35-uav-link" />
          </div>
        ) : null}
      </div>

      {scenario.hotspots.map((hotspot) => (
        <button
          type="button"
          key={hotspot.id}
          className="v35-hotspot"
          style={{ left: `${hotspot.x}%`, top: `${hotspot.y}%` }}
          title={`${hotspot.label}: ${hotspot.value}`}
        >
          <span />
          <strong>{hotspot.label}</strong>
          <small>{hotspot.value}</small>
        </button>
      ))}
    </div>
  )
}

export function RFDynamicScenarioDeckV35() {
  const [activeId, setActiveId] = useState(rfScenariosV35[0]?.id ?? 'electronics')

  const active = useMemo(
    () => rfScenariosV35.find((scenario) => scenario.id === activeId) ?? rfScenariosV35[0],
    [activeId],
  )

  return (
    <section className="v35-scenario-shell">
      <div className="v35-scenario-header">
        <div>
          <p>V35 DYNAMIC SCENARIO ENGINE</p>
          <h2>RF / Telco / Antenna Interactive Knowledge Scenarios</h2>
          <span>
            Scenari dinamici integrati nel portale: antenne, beamwidth, tower infrastructure, microstrip,
            laboratorio RF, UAV ISR e simboli elettronici.
          </span>
        </div>
        <strong>{rfScenariosV35.length} scenarios</strong>
      </div>

      <div className="v35-scenario-tabs" role="tablist" aria-label="RF scenario selector">
        {rfScenariosV35.map((scenario) => (
          <button
            key={scenario.id}
            type="button"
            className={scenario.id === active.id ? 'v35-tab-active' : ''}
            onClick={() => setActiveId(scenario.id)}
          >
            {scenario.title}
          </button>
        ))}
      </div>

      <div className="v35-scenario-layout">
        <ScenarioVisual scenario={active} />

        <aside className="v35-scenario-info">
          <p className="v35-eyebrow">{active.subtitle}</p>
          <h3>{active.title}</h3>
          <p>{active.mission}</p>

          <div className="v35-kpi-grid">
            {active.kpis.map((kpi) => (
              <article key={`${active.id}-${kpi.label}`}>
                <span>{kpi.label}</span>
                <strong>{kpi.value}</strong>
              </article>
            ))}
          </div>

          <div className="v35-knowledge-stack">
            {active.knowledge.map((item, index) => (
              <div key={`${active.id}-knowledge-${index}`}>
                <span>{String(index + 1).padStart(2, '0')}</span>
                <p>{item}</p>
              </div>
            ))}
          </div>
        </aside>
      </div>
    </section>
  )
}
