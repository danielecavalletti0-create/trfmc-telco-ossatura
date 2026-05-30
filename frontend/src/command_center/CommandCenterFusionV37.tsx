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
