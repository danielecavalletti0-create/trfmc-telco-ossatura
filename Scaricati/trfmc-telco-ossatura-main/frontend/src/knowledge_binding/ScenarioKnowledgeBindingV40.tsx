import { useMemo, useState } from 'react'
import { scenarioKnowledgeBindingsV40, scenarioKnowledgeMetaV40, type BindingSourceModeV40 } from './scenarioKnowledgeBindingDataV40'

function modeLabel(mode: BindingSourceModeV40) {
  if (mode === 'future-live') return 'FUTURE-LIVE'
  return mode.toUpperCase()
}

function modeRank(mode: BindingSourceModeV40) {
  if (mode === 'live') return 0
  if (mode === 'contract') return 1
  if (mode === 'synthetic') return 2
  return 3
}

export function ScenarioKnowledgeBindingV40() {
  const [modeFilter, setModeFilter] = useState<BindingSourceModeV40 | 'all'>('all')
  const [selectedId, setSelectedId] = useState(scenarioKnowledgeBindingsV40[0]?.id ?? 'mission-control-binding')

  const visibleBindings = useMemo(() => {
    return scenarioKnowledgeBindingsV40
      .filter((item) => modeFilter === 'all' || item.sourceMode === modeFilter)
      .sort((a, b) => modeRank(a.sourceMode) - modeRank(b.sourceMode))
  }, [modeFilter])

  const selected = useMemo(() => {
    return scenarioKnowledgeBindingsV40.find((item) => item.id === selectedId) ?? scenarioKnowledgeBindingsV40[0]
  }, [selectedId])

  return (
    <section className="v40-binding-shell">
      <div className="v40-binding-header">
        <div>
          <p>V40 SCENARIO-TO-KNOWLEDGE BINDING</p>
          <h2>{scenarioKnowledgeMetaV40.title}</h2>
          <span>{scenarioKnowledgeMetaV40.subtitle}</span>
        </div>
        <div className="v40-binding-score">
          <strong>{scenarioKnowledgeBindingsV40.length}</strong>
          <small>domain bindings</small>
        </div>
      </div>

      <div className="v40-mode-controls">
        {(['all', 'live', 'contract', 'synthetic', 'future-live'] as const).map((mode) => (
          <button
            key={mode}
            type="button"
            className={modeFilter === mode ? 'v40-mode-active' : ''}
            onClick={() => setModeFilter(mode)}
          >
            {mode === 'all' ? 'ALL SOURCES' : modeLabel(mode)}
          </button>
        ))}
      </div>

      <div className="v40-binding-layout">
        <div className="v40-binding-list">
          {visibleBindings.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`v40-binding-card v40-source-${item.sourceMode} ${selected.id === item.id ? 'v40-binding-selected' : ''}`}
              onClick={() => setSelectedId(item.id)}
            >
              <span>{item.domainTitle}</span>
              <strong>{item.scenarioTitle}</strong>
              <small>{modeLabel(item.sourceMode)}</small>
            </button>
          ))}
        </div>

        <aside className="v40-binding-detail">
          <div className="v40-detail-top">
            <span>{selected.domainTitle}</span>
            <strong className={`v40-mode-pill v40-pill-${selected.sourceMode}`}>{modeLabel(selected.sourceMode)}</strong>
          </div>

          <h3>{selected.scenarioTitle}</h3>
          <p>{selected.theory[0]}</p>

          <div className="v40-source-box">
            <span>{selected.liveEndpoint ? 'endpoint' : selected.assetHint ? 'asset/reference' : 'binding'}</span>
            <strong>{selected.liveEndpoint ?? selected.assetHint ?? 'local knowledge model'}</strong>
          </div>

          <div className="v40-detail-grid">
            <article>
              <span>Theory</span>
              <ul>
                {selected.theory.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </article>

            <article>
              <span>Formulas</span>
              <ul>
                {selected.formulas.map((item) => <li key={item}><code>{item}</code></li>)}
              </ul>
            </article>

            <article>
              <span>Instruments</span>
              <ul>
                {selected.instruments.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </article>

            <article>
              <span>Evidence</span>
              <ul>
                {selected.evidence.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </article>
          </div>

          <footer>
            <span>Next engineering step</span>
            <strong>{selected.nextEngineeringStep}</strong>
          </footer>
        </aside>
      </div>
    </section>
  )
}
