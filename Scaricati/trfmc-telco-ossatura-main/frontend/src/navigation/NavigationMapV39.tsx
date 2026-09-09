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
