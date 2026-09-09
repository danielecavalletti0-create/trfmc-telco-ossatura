import { useEffect, useMemo, useState } from 'react'
import {
  extractString,
  fetchLiveContractSnapshot,
  getEndpointHealth,
  type LiveContractSnapshot,
} from '../../shared/liveContractsV32R1'

export function RFNativeLiveReadinessStripV34R1() {
  const [snapshot, setSnapshot] = useState<LiveContractSnapshot | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [tick, setTick] = useState(0)

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
  }, [tick])

  useEffect(() => {
    const timer = window.setInterval(() => {
      setTick((value) => value + 1)
    }, 15000)

    return () => window.clearInterval(timer)
  }, [])

  const derived = useMemo(() => {
    const missionSource = extractString(snapshot?.mission.data, ['source'])
    const coreReadiness = extractString(snapshot?.open5gs.data, ['open5gs', 'readiness'])
    const ranReadiness = extractString(snapshot?.ueransim.data, ['ueransim', 'readiness'])
    const spectrumSource = extractString(snapshot?.spectrumSweep.data, ['spectrum', 'data_source'])
    const socSource = extractString(snapshot?.socNoc.data, ['data_source'])
    const contractVersion = extractString(snapshot?.spectrumSweep.data, ['contract_version'])

    const health = [
      snapshot?.mission,
      snapshot?.open5gs,
      snapshot?.ueransim,
      snapshot?.bandplan,
      snapshot?.spectrumSweep,
      snapshot?.socNoc,
    ].filter((item) => getEndpointHealth(item) === 'ok').length

    return {
      missionSource,
      coreReadiness,
      ranReadiness,
      spectrumSource,
      socSource,
      contractVersion,
      health,
    }
  }, [snapshot])

  return (
    <section className="v34r1-native-readiness-strip">
      <div className="v34r1-native-readiness-head">
        <div>
          <p>V34R1 NATIVE RF PANEL BINDING</p>
          <h3>Bridge Readiness · Live Contract Layer</h3>
        </div>
        <strong>{derived.health}/6 API</strong>
      </div>

      {error ? <div className="v34r1-native-readiness-error">Live contract error: {error}</div> : null}

      <div className="v34r1-native-readiness-grid">
        <article>
          <span>Backend</span>
          <strong>{derived.missionSource}</strong>
        </article>
        <article>
          <span>Open5GS</span>
          <strong>{derived.coreReadiness}</strong>
        </article>
        <article>
          <span>UERANSIM</span>
          <strong>{derived.ranReadiness}</strong>
        </article>
        <article>
          <span>Spectrum</span>
          <strong>{derived.spectrumSource}</strong>
        </article>
        <article>
          <span>SOC/NOC</span>
          <strong>{derived.socSource}</strong>
        </article>
        <article>
          <span>Contract</span>
          <strong>{derived.contractVersion}</strong>
        </article>
      </div>

      <footer>
        <span>Refresh 15s · read-only · no SDR TX · no Open5GS/UERANSIM start-stop</span>
        <button type="button" onClick={() => setTick((value) => value + 1)}>
          Refresh native readiness
        </button>
      </footer>
    </section>
  )
}
