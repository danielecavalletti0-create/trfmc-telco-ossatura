import React from 'react'
import { createRoot } from 'react-dom/client'
import { Activity, Radio, Network, Shield, Wifi, Lock, Server, Database, Satellite, Clock } from 'lucide-react'
import { apiGet, API_BASE } from '../shared/api'
import '../styles.css'

function Panel({title, icon, children}: {title: string, icon?: React.ReactNode, children: React.ReactNode}) {
  return <section className="panel">
    <div className="panel-h">{icon}{title}</div>
    <div className="panel-b">{children}</div>
  </section>
}

async function apiPost(path: string, body?: any): Promise<any> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: body ? JSON.stringify(body) : undefined
  })
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`)
  return res.json()
}

function App() {
  const [data, setData] = React.useState<any>({})
  const [err, setErr] = React.useState<string>('')
  const [stream, setStream] = React.useState<any[]>([])
  const [wsState, setWsState] = React.useState<string>('CONNECTING')

  async function load() {
    const keys: [string,string][] = [
      ['health','/health'],
      ['mission','/mission/status'],
      ['events','/events/demo'],
      ['plane','/scientific/plane-wave/demo'],
      ['network','/network-fabric/path?destination=New%20York'],
      ['networkOverview','/network-fabric/overview'],
      ['networkPaths','/network-fabric/paths'],
      ['mns','/telco-mns/status'],
      ['assets','/assets/demo'],
      ['assetGraph','/assets/graph'],
      ['assetLinks','/persistence/asset-links'],
      ['rat','/access-trust/rat/demo'],
      ['wifi','/access-trust/wifi/demo'],
      ['soc','/soc-noc/correlation/demo'],
      ['restricted','/restricted/status'],
      ['time','/time-cursor/status'],
      ['persist','/persistence/status'],
      ['timeline','/time-cursor/timeline']
    ]
    const results: any = {}
    for (const [k,p] of keys) results[k] = await apiGet<any>(p)
    setData(results)
  }

  React.useEffect(() => {
    load().catch(e => setErr(String(e)))

    const ws = new WebSocket('ws://127.0.0.1:8000/api/events/stream')
    ws.onopen = () => setWsState('CONNECTED')
    ws.onclose = () => setWsState('CLOSED')
    ws.onerror = () => setWsState('ERROR')
    ws.onmessage = (ev) => {
      try {
        const msg = JSON.parse(ev.data)
        setStream(prev => [msg, ...prev].slice(0, 12))
      } catch {}
    }

    return () => ws.close()
  }, [])

  async function publishDemo() {
    await apiPost('/events/publish-demo')
    await load()
  }

  async function setCursor(cursor_ms: number) {
    await apiPost('/time-cursor/set', {
      mission_id: 'MISSION-FULL-TELCO-BOOT-001',
      cursor_ms,
      reason: 'frontend_operator_update'
    })
    await load()
  }

  return <main className="shell">
    <header className="top">
      <div>
        <h1>TELCO RF MISSION CONTROL PLATFORM</h1>
        <p>Full Telco Skeleton · Mission Orchestrator · CloudEvents · RF/EM/DSP · GWAN · Global Time Cursor</p>
      </div>
      <div className="badge">v0.7 · {data.health?.operational_mode ?? 'BOOT'} · WS {wsState}</div>
    </header>

    <section className="layout">
      <aside className="nav">
        {['Mission', 'Global Time Cursor', 'CloudEvents', 'Scientific Core', 'Global Network', 'Telco MnS', 'Assets', 'RAT Defense', 'Wi-Fi Trust', 'SOC/NOC', 'Evidence', 'Restricted'].map(x => <div className="navitem" key={x}>{x}</div>)}
      </aside>

      <section className="main">
        {err && <div className="error">{err}</div>}

        <Panel title="Mission Orchestrator" icon={<Activity/>}>
          <pre>{JSON.stringify(data.mission, null, 2)}</pre>
        </Panel>

        <Panel title="Global Time Cursor" icon={<Clock/>}>
          <div className="metric">Mission: {data.time?.mission_id}</div>
          <div className="metric">Cursor: {data.time?.cursor_ms ?? '—'} ms</div>
          <div className="metric">State: {data.time?.status}</div>
          <div className="buttons">
            <button onClick={() => setCursor(0)}>T+0 ms</button>
            <button onClick={() => setCursor(1200)}>T+1200 ms</button>
            <button onClick={() => setCursor(1800)}>T+1800 ms</button>
            <button onClick={() => setCursor(5000)}>T+5000 ms</button>
            <button onClick={publishDemo}>Publish demo events</button>
          </div>
        </Panel>

        <div className="grid2">
          <Panel title="Scientific RF/EM Core" icon={<Radio/>}>
            <div className="metric">f: {fmt(data.plane?.frequency_hz)} Hz</div>
            <div className="metric">λ: {sci(data.plane?.wavelength_m)} m</div>
            <div className="metric">η: {sci(data.plane?.intrinsic_impedance_ohm)} Ω</div>
            <div className="metric">S: {sci(data.plane?.poynting_w_per_m2)} W/m²</div>
            <div className="emview"><span>E</span><span>H</span><span>k</span></div>
          </Panel>

          <Panel title="Global Network Journey" icon={<Network/>}>
            <div className="path">
              {data.network?.segments?.map((s:any) => <div className="hop" key={s.segment_id}><b>{s.type}</b><span>{s.latency_ms} ms</span></div>)}
            </div>
            <div className="metric">RTT: {data.network?.estimated_rtt_ms} ms · MOS {data.network?.mos_estimate}</div>
          </Panel>
        </div>

        <Panel title="Live Event Stream / CloudEvents" icon={<Database/>}>
          <pre>{JSON.stringify(stream.length ? stream : data.timeline, null, 2)}</pre>
        </Panel>

        
        
        <Panel title="Network Journey Digital Twin" icon={<Network/>}>
          <div className="metric">Demo global destinations: {data.networkOverview?.paths?.length ?? '—'}</div>
          <div className="metric">Persisted paths: {data.networkPaths?.length ?? 0}</div>
          <div className="journey-grid">
            {data.networkOverview?.paths?.slice(0, 9).map((p:any) => (
              <div className="journey-card" key={p.path_id}>
                <b>{p.destination_label}</b>
                <span>RTT {p.estimated_rtt_ms} ms · MOS {p.mos_estimate}</span>
                <em>Dominant: {p.dominant_latency_segment}</em>
              </div>
            ))}
          </div>
        </Panel>

        <Panel title="Asset Digital Twin Registry" icon={<Database/>}>
          <div className="metric">Assets: {data.assetGraph?.nodes?.length ?? '—'}</div>
          <div className="metric">Links: {data.assetGraph?.links?.length ?? '—'}</div>
          <div className="asset-grid">
            {data.assetGraph?.nodes?.slice(0, 18).map((n:any) => (
              <div className="asset-card" key={n.id}>
                <b>{n.id}</b>
                <span>{n.type}</span>
                <em>{n.domain} · {n.status}</em>
              </div>
            ))}
          </div>
        </Panel>

        <Panel title="Telco MnS / 3GPP OAM Predisposition" icon={<Server/>}>
          <pre>{JSON.stringify(data.mns, null, 2)}</pre>
        </Panel>
      </section>

      <aside className="context">
        <Panel title="Persistence Status" icon={<Database/>}>
          <pre>{JSON.stringify(data.persist, null, 2)}</pre>
        </Panel>

        <Panel title="RAT Downgrade Defense" icon={<Shield/>}>
          <div className="risk high">{data.rat?.classification}</div>
          <pre>{JSON.stringify(data.rat, null, 2)}</pre>
        </Panel>

        <Panel title="Wi-Fi Trust Defense" icon={<Wifi/>}>
          <div className="risk critical">{data.wifi?.classification}</div>
          <pre>{JSON.stringify(data.wifi, null, 2)}</pre>
        </Panel>

        <Panel title="SOC/NOC Correlation" icon={<Satellite/>}>
          <pre>{JSON.stringify(data.soc, null, 2)}</pre>
        </Panel>

        <Panel title="Restricted Intelligence" icon={<Lock/>}>
          <div className="locked">LOCKED</div>
          <pre>{JSON.stringify(data.restricted, null, 2)}</pre>
        </Panel>
      </aside>
    </section>

    <footer className="timeline">GLOBAL TIME CURSOR · waveform · spectrum · protocol · logs · KPI · evidence · network path</footer>
  </main>
}

function fmt(v:any){ return v === undefined ? '—' : Number(v).toLocaleString('it-IT') }
function sci(v:any){ return v === undefined ? '—' : Number(v).toExponential(3) }

createRoot(document.getElementById('root')!).render(<App />)
