import { useEffect, useMemo, useState } from 'react'
import {
  extractNumber,
  extractString,
  fetchLiveContractSnapshot,
  getEndpointHealth,
  type LiveContractResult,
  type LiveContractSnapshot,
} from '../../shared/liveContractsV32R1'

type CardProps = {
  title: string
  result?: LiveContractResult
  detail: string
  subdetail?: string
}

function ContractCard({ title, result, detail, subdetail }: CardProps) {
  const health = getEndpointHealth(result)

  return (
    <article className={`v32r1-contract-card v32r1-contract-card-${health}`}>
      <div className="v32r1-contract-card-head">
        <span>{title}</span>
        <strong>{health.toUpperCase()}</strong>
      </div>
      <p>{detail}</p>
      {subdetail ? <small>{subdetail}</small> : null}
      <code>{result?.endpoint ?? 'endpoint pending'}</code>
    </article>
  )
}

export function RFLiveContractStatusV32R1() {
  const [snapshot, setSnapshot] = useState<LiveContractSnapshot | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [refreshIndex, setRefreshIndex] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    let alive = true

    fetchLiveContractSnapshot(controller.signal)
      .then((next) => {
        if (!alive) return
        setSnapshot(next)
        setError(null)
      })
      .catch((err) => {
        if (!alive) return
        setError(err instanceof Error ? err.message : String(err))
      })

    return () => {
      alive = false
      controller.abort()
    }
  }, [refreshIndex])

  useEffect(() => {
    const timer = window.setInterval(() => {
      setRefreshIndex((value) => value + 1)
    }, 15000)

    return () => window.clearInterval(timer)
  }, [])

  const derived = useMemo(() => {
    const missionSource = extractString(snapshot?.mission.data, ['source'])
    const open5gsReadiness = extractString(snapshot?.open5gs.data, ['open5gs', 'readiness'])
    const ueransimReadiness = extractString(snapshot?.ueransim.data, ['ueransim', 'readiness'])
    const bands = extractNumber(snapshot?.bandplan.data, ['bands', 'length'], 0)
    const spectrumSource = extractString(snapshot?.spectrumSweep.data, ['spectrum', 'data_source'])
    const socEvents = extractNumber(snapshot?.socNoc.data, ['events', 'length'], 0)

    return {
      missionSource,
      open5gsReadiness,
      ueransimReadiness,
      bands,
      spectrumSource,
      socEvents,
    }
  }, [snapshot])

  const contractOkCount = [
    snapshot?.mission,
    snapshot?.open5gs,
    snapshot?.ueransim,
    snapshot?.bandplan,
    snapshot?.spectrumSweep,
    snapshot?.socNoc,
  ].filter((item) => getEndpointHealth(item) === 'ok').length

  return (
    <section className="v32r1-live-contract-shell">
      <div className="v32r1-live-contract-header">
        <div>
          <p className="v32r1-eyebrow">V32R1 LIVE API BINDING</p>
          <h2>TRFMC Read-Only Contract Overlay</h2>
          <span>
            Fonte primaria: NGINX 4181 → FastAPI 8000 → contratti V31. Refresh automatico ogni 15 secondi.
          </span>
        </div>
        <div className="v32r1-score">
          <strong>{contractOkCount}/6</strong>
          <small>contracts online</small>
        </div>
      </div>

      {error ? <div className="v32r1-contract-error">Errore live API: {error}</div> : null}

      <div className="v32r1-contract-grid">
        <ContractCard
          title="Mission Backend"
          result={snapshot?.mission}
          detail={derived.missionSource}
          subdetail={`latency ${snapshot?.mission.latencyMs ?? '—'} ms`}
        />
        <ContractCard
          title="Open5GS Core"
          result={snapshot?.open5gs}
          detail={derived.open5gsReadiness}
          subdetail="Probe read-only senza start/stop"
        />
        <ContractCard
          title="UERANSIM RAN"
          result={snapshot?.ueransim}
          detail={derived.ueransimReadiness}
          subdetail="Probe read-only senza mutazione config"
        />
        <ContractCard
          title="RF Bandplan"
          result={snapshot?.bandplan}
          detail={`${derived.bands} reference bands`}
          subdetail={extractString(snapshot?.bandplan.data, ['contract_version'])}
        />
        <ContractCard
          title="Spectrum Contract"
          result={snapshot?.spectrumSweep}
          detail={derived.spectrumSource}
          subdetail="No SDR sweep executed"
        />
        <ContractCard
          title="SOC/NOC Correlation"
          result={snapshot?.socNoc}
          detail={`${derived.socEvents} live events`}
          subdetail={extractString(snapshot?.socNoc.data, ['data_source'])}
        />
      </div>

      <div className="v32r1-contract-footer">
        <span>Last sample: {snapshot?.timestamp ?? 'waiting...'}</span>
        <button type="button" onClick={() => setRefreshIndex((value) => value + 1)}>
          Refresh contracts
        </button>
      </div>
    </section>
  )
}
