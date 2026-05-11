#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

echo "============================================================"
echo "APPLY v0.11 MISSION CONTROL LAYOUT NORMALIZATION"
echo "============================================================"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
s = p.read_text()

s = re.sub(r'version="0\.\d+\.0"', 'version="0.11.0"', s)
s = re.sub(r'"version": "0\.\d+\.0"', '"version": "0.11.0"', s)

s = s.replace(
    'description="Telco RF Mission Control Platform — RF visualization and enterprise instrument panel."',
    'description="Telco RF Mission Control Platform — normalized mission control layout."'
)

p.write_text(s)
PY

cat > frontend/src/app/main.tsx <<'TSX'
import React from 'react'
import { createRoot } from 'react-dom/client'
import {
  Activity,
  Radio,
  Network,
  Shield,
  Wifi,
  Lock,
  Server,
  Database,
  Clock,
  Radar,
  Waves,
  Gauge,
  Map,
  Cpu,
  Boxes,
  AlertTriangle,
  Eye,
  TerminalSquare
} from 'lucide-react'
import { API_BASE } from '../shared/api'
import '../styles.css'

type AnyObj = Record<string, any>
type SectionId = 'overview' | 'rf' | 'network' | 'assets' | 'soc' | 'events' | 'restricted'

async function apiGet<T = any>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`)
  if (!res.ok) throw new Error(`${path}: ${res.status} ${res.statusText}`)
  return res.json()
}

async function apiPost<T = any>(path: string, body?: any): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: body ? JSON.stringify(body) : undefined
  })
  if (!res.ok) throw new Error(`${path}: ${res.status} ${res.statusText}`)
  return res.json()
}

function n(v:any, digits=2) {
  if (v === undefined || v === null || Number.isNaN(Number(v))) return '—'
  return Number(v).toLocaleString('it-IT', {maximumFractionDigits: digits})
}

function sci(v:any, digits=3) {
  if (v === undefined || v === null || Number.isNaN(Number(v))) return '—'
  return Number(v).toExponential(digits)
}

function cls(v:any) {
  return String(v ?? '').toLowerCase()
}

function Panel({title, icon, children, className=''}: {title: string, icon?: React.ReactNode, children: React.ReactNode, className?: string}) {
  return (
    <section className={`mc-panel ${className}`}>
      <div className="mc-panel-title">{icon}<span>{title}</span></div>
      <div className="mc-panel-body">{children}</div>
    </section>
  )
}

function Kpi({label, value, unit, tone='normal'}: {label: string, value: any, unit?: string, tone?: string}) {
  return (
    <div className={`mc-kpi ${tone}`}>
      <span>{label}</span>
      <b>{value ?? '—'}</b>
      {unit && <em>{unit}</em>}
    </div>
  )
}

function JsonBox({data}: {data:any}) {
  return <pre className="mc-json">{JSON.stringify(data, null, 2)}</pre>
}

function SectionButton({id, active, icon, label, onClick}: {id: SectionId, active: SectionId, icon: React.ReactNode, label: string, onClick: (id: SectionId)=>void}) {
  return (
    <button className={active === id ? 'mc-nav-active' : ''} onClick={() => onClick(id)}>
      {icon}
      <span>{label}</span>
    </button>
  )
}

function App() {
  const [active, setActive] = React.useState<SectionId>('overview')
  const [data, setData] = React.useState<AnyObj>({})
  const [stream, setStream] = React.useState<any[]>([])
  const [selectedTarget, setSelectedTarget] = React.useState<string>('UE-REMOTE-001')
  const [loading, setLoading] = React.useState<boolean>(true)
  const [err, setErr] = React.useState<string>('')
  const [wsState, setWsState] = React.useState<string>('CONNECTING')

  async function load(target = selectedTarget) {
    setLoading(true)
    setErr('')
    const calls: [string,string][] = [
      ['health','/health'],
      ['mission','/mission/status'],
      ['persist','/persistence/status'],
      ['time','/time-cursor/status'],
      ['events','/persistence/events'],
      ['assetGraph','/assets/graph'],
      ['networkOverview','/network-fabric/overview'],
      ['networkPaths','/network-fabric/paths'],
      ['rfCoverage','/rf-coverage/demo'],
      ['rfCoverageRuns','/rf-coverage/runs'],
      ['rfField',`/rf-field/demo?target_asset_id=${encodeURIComponent(target)}`],
      ['rfFieldRuns','/rf-field/runs'],
      ['mns','/telco-mns/status'],
      ['rat','/access-trust/rat/demo'],
      ['wifi','/access-trust/wifi/demo'],
      ['soc','/soc-noc/correlation/demo'],
      ['restricted','/restricted/status']
    ]

    const out: AnyObj = {}
    for (const [k,p] of calls) {
      try {
        out[k] = await apiGet(p)
      } catch (e:any) {
        out[k] = {error: String(e)}
      }
    }
    setData(out)
    setLoading(false)
  }

  React.useEffect(() => {
    load().catch(e => {
      setErr(String(e))
      setLoading(false)
    })

    const ws = new WebSocket('ws://127.0.0.1:8000/api/events/stream')
    ws.onopen = () => setWsState('CONNECTED')
    ws.onclose = () => setWsState('CLOSED')
    ws.onerror = () => setWsState('ERROR')
    ws.onmessage = (ev) => {
      try {
        const msg = JSON.parse(ev.data)
        setStream(prev => [msg, ...prev].slice(0, 20))
      } catch {}
    }
    return () => ws.close()
  }, [])

  async function switchTarget(target: string) {
    setSelectedTarget(target)
    await load(target)
  }

  async function runRfField(target = selectedTarget) {
    await apiPost('/rf-field/run', {
      mission_id: 'MISSION-FULL-TELCO-BOOT-001',
      cell_asset_id: 'CELL-N78-A',
      target_asset_id: target,
      frequency_hz: 3500000000,
      tx_power_dbm: 43,
      tx_gain_dbi: 18,
      antenna_max_dimension_m: 0.8,
      azimuth_deg: 120,
      mechanical_tilt_deg: 4,
      electrical_tilt_deg: 2
    })
    await load(target)
  }

  async function runCoverage() {
    await apiPost('/rf-coverage/run', {
      mission_id: 'MISSION-FULL-TELCO-BOOT-001',
      cell_asset_id: 'CELL-N78-A',
      target_asset_id: selectedTarget,
      frequency_hz: 3500000000,
      tx_power_dbm: 43,
      tx_gain_dbi: 18,
      rx_gain_dbi: 0,
      bandwidth_hz: 100000000,
      noise_figure_db: 7,
      grid_extent_m: 600,
      grid_step_m: 100
    })
    await load(selectedTarget)
  }

  const counts = data.persist?.counts ?? {}
  const rf = data.rfField ?? {}
  const cov = data.rfCoverage ?? {}
  const field = rf.field_at_target ?? {}
  const ant = rf.antenna ?? {}
  const fresnel = rf.fresnel ?? {}
  const link = cov.target_link ?? {}

  return (
    <main className="mc-shell">
      <header className="mc-header">
        <div>
          <h1>TELCO RF MISSION CONTROL PLATFORM</h1>
          <p>v0.11 · Normalized Mission Control Layout · Telco · RF · SOC/NOC · Digital Twin</p>
        </div>
        <div className="mc-header-status">
          <span>{data.health?.version ?? '—'}</span>
          <span>{data.health?.operational_mode ?? 'BOOT'}</span>
          <span>WS {wsState}</span>
        </div>
      </header>

      <section className="mc-statusbar">
        <Kpi label="Mission" value={data.time?.mission_id ?? '—'} />
        <Kpi label="Time Cursor" value={data.time?.cursor_ms ?? '—'} unit="ms" />
        <Kpi label="Assets" value={counts.assets ?? 0} />
        <Kpi label="Events" value={counts.cloud_events ?? 0} />
        <Kpi label="RF Runs" value={counts.rf_field_runs ?? 0} />
        <Kpi label="Coverage" value={counts.rf_coverage_runs ?? 0} />
        <Kpi label="Network Paths" value={counts.network_paths ?? 0} />
      </section>

      <section className="mc-layout">
        <aside className="mc-sidebar">
          <SectionButton id="overview" active={active} icon={<Activity/>} label="Overview" onClick={setActive} />
          <SectionButton id="rf" active={active} icon={<Radio/>} label="RF / Field" onClick={setActive} />
          <SectionButton id="network" active={active} icon={<Network/>} label="Network" onClick={setActive} />
          <SectionButton id="assets" active={active} icon={<Boxes/>} label="Assets" onClick={setActive} />
          <SectionButton id="soc" active={active} icon={<Shield/>} label="SOC / Trust" onClick={setActive} />
          <SectionButton id="events" active={active} icon={<Database/>} label="Events" onClick={setActive} />
          <SectionButton id="restricted" active={active} icon={<Lock/>} label="Restricted" onClick={setActive} />

          <div className="mc-sidebar-footer">
            <button onClick={() => load()}>Refresh</button>
            <button onClick={() => runRfField()}>Run RF Field</button>
            <button onClick={() => runCoverage()}>Run Coverage</button>
          </div>
        </aside>

        <section className="mc-content">
          {loading && <div className="mc-banner">Loading mission telemetry...</div>}
          {err && <div className="mc-error">{err}</div>}

          {active === 'overview' && (
            <div className="mc-grid">
              <Panel title="Mission State" icon={<Clock/>}>
                <Kpi label="Project" value={data.health?.project} />
                <Kpi label="Backend" value={data.health?.version} />
                <Kpi label="Restricted" value={String(data.health?.restricted_enabled)} />
                <Kpi label="Persistence" value={data.health?.persistence} />
              </Panel>

              <Panel title="RF Summary" icon={<Radar/>}>
                <Kpi label="Model" value={rf.model_name} />
                <Kpi label="λ" value={sci(rf.wave?.wavelength_m)} unit="m" />
                <Kpi label="Region" value={field.field_region} />
                <Kpi label="Target Gain" value={n(ant.gain_to_target_dbi)} unit="dBi" />
              </Panel>

              <Panel title="Coverage Summary" icon={<Map/>}>
                <Kpi label="Target" value={link.target_asset_id} />
                <Kpi label="LOS State" value={link.los_state} />
                <Kpi label="SNR" value={n(link.snr_db)} unit="dB" />
                <Kpi label="Class" value={link.classification} tone={cls(link.classification)} />
              </Panel>

              <Panel title="Network Journey" icon={<Network/>}>
                <Kpi label="Paths" value={data.networkOverview?.paths?.length ?? 0} />
                <Kpi label="Persisted" value={data.networkPaths?.length ?? 0} />
                <div className="mc-mini-list">
                  {data.networkOverview?.paths?.slice(0, 5).map((p:any) => (
                    <div key={p.path_id}>{p.destination_label} · RTT {p.estimated_rtt_ms} ms</div>
                  ))}
                </div>
              </Panel>
            </div>
          )}

          {active === 'rf' && (
            <div className="mc-grid mc-grid-wide">
              <Panel title="Target Control" icon={<Crosshair/>}>
                <div className="mc-actions">
                  <button onClick={() => switchTarget('UE-REMOTE-001')}>UE-REMOTE-001</button>
                  <button onClick={() => switchTarget('UAV-ALPHA-001')}>UAV-ALPHA-001</button>
                  <button onClick={() => runRfField()}>Run Field</button>
                  <button onClick={() => runCoverage()}>Run Coverage</button>
                </div>
                <Kpi label="Selected" value={selectedTarget} />
                <Kpi label="Bearing" value={n(ant.bearing_to_target_deg)} unit="°" />
                <Kpi label="Relative Azimuth" value={n(ant.relative_azimuth_deg)} unit="°" />
                <Kpi label="Elevation" value={n(ant.elevation_to_target_deg)} unit="°" />
              </Panel>

              <Panel title="E/H/Poynting Instrument" icon={<Waves/>}>
                <div className="mc-kpi-grid">
                  <Kpi label="E" value={sci(field.electric_field_v_m)} unit="V/m" />
                  <Kpi label="H" value={sci(field.magnetic_field_a_m)} unit="A/m" />
                  <Kpi label="S" value={sci(field.poynting_w_m2)} unit="W/m²" />
                  <Kpi label="Distance" value={n(field.distance_m)} unit="m" />
                </div>
                <div className="mc-wave">
                  <div className="mc-wave-e"></div>
                  <div className="mc-wave-h"></div>
                  <span>k →</span>
                </div>
              </Panel>

              <Panel title="Antenna Pattern" icon={<Radar/>} className="mc-span-2">
                <div className="mc-pattern">
                  {ant.pattern?.azimuth?.map((p:any, idx:number) => (
                    <div
                      key={idx}
                      className="mc-pattern-bar"
                      style={{height: `${Math.max(6, (Number(p.gain_dbi) + 35) * 2.2)}px`}}
                      title={`${p.angle_deg}° · ${p.gain_dbi} dBi`}
                    />
                  ))}
                </div>
              </Panel>

              <Panel title="Fresnel Clearance" icon={<Eye/>}>
                <Kpi label="Total 2D Distance" value={n(fresnel.total_2d_distance_m)} unit="m" />
                <div className={`mc-state ${cls(fresnel.worst_case?.fresnel_state)}`}>
                  {fresnel.worst_case?.obstacle_id ?? '—'} · {fresnel.worst_case?.fresnel_state ?? '—'}
                </div>
                <JsonBox data={fresnel.worst_case} />
              </Panel>

              <Panel title="Coverage Grid" icon={<Map/>}>
                <div className="mc-coverage">
                  {cov.coverage_grid?.slice(0, 49).map((p:any, idx:number) => (
                    <div className={`mc-cell ${cls(p.classification)}`} key={idx} title={`${p.x_m}, ${p.y_m} · ${p.snr_db} dB · ${p.los_state}`}>
                      {n(p.snr_db, 1)}
                    </div>
                  ))}
                </div>
              </Panel>

              <Panel title="Link Budget" icon={<Gauge/>}>
                <Kpi label="FSPL" value={n(link.fspl_db)} unit="dB" />
                <Kpi label="Obstacle Loss" value={n(link.obstacle_loss_db)} unit="dB" />
                <Kpi label="Total Loss" value={n(link.total_path_loss_db)} unit="dB" />
                <Kpi label="Rx Power" value={n(link.rx_power_dbm)} unit="dBm" />
                <Kpi label="Noise Floor" value={n(link.noise_floor_dbm)} unit="dBm" />
                <Kpi label="SNR" value={n(link.snr_db)} unit="dB" />
              </Panel>
            </div>
          )}

          {active === 'network' && (
            <div className="mc-grid">
              <Panel title="Global Network Journey" icon={<Network/>} className="mc-span-2">
                <div className="mc-journey">
                  {data.networkOverview?.paths?.map((p:any) => (
                    <div className="mc-journey-card" key={p.path_id}>
                      <b>{p.destination_label}</b>
                      <span>RTT {p.estimated_rtt_ms} ms · MOS {p.mos_estimate}</span>
                      <em>{p.dominant_latency_segment}</em>
                    </div>
                  ))}
                </div>
              </Panel>
              <Panel title="Persisted Paths" icon={<Database/>}>
                <JsonBox data={data.networkPaths?.slice?.(0, 3) ?? data.networkPaths} />
              </Panel>
            </div>
          )}

          {active === 'assets' && (
            <div className="mc-grid mc-grid-wide">
              <Panel title="Asset Digital Twin Registry" icon={<Boxes/>} className="mc-span-2">
                <div className="mc-assets">
                  {data.assetGraph?.nodes?.map((a:any) => (
                    <div className="mc-asset" key={a.id}>
                      <b>{a.id}</b>
                      <span>{a.type}</span>
                      <em>{a.domain} · {a.status}</em>
                    </div>
                  ))}
                </div>
              </Panel>
            </div>
          )}

          {active === 'soc' && (
            <div className="mc-grid">
              <Panel title="RAT Downgrade Defense" icon={<Shield/>}>
                <JsonBox data={data.rat} />
              </Panel>
              <Panel title="Wi-Fi Trust Defense" icon={<Wifi/>}>
                <JsonBox data={data.wifi} />
              </Panel>
              <Panel title="SOC/NOC Correlation" icon={<AlertTriangle/>} className="mc-span-2">
                <JsonBox data={data.soc} />
              </Panel>
              <Panel title="Telco MnS / OAM" icon={<Server/>} className="mc-span-2">
                <JsonBox data={data.mns} />
              </Panel>
            </div>
          )}

          {active === 'events' && (
            <div className="mc-grid">
              <Panel title="Live Event Stream" icon={<Activity/>} className="mc-span-2">
                <JsonBox data={stream.length ? stream : data.events?.slice?.(0, 10)} />
              </Panel>
              <Panel title="Persistence Status" icon={<Database/>} className="mc-span-2">
                <JsonBox data={data.persist} />
              </Panel>
            </div>
          )}

          {active === 'restricted' && (
            <div className="mc-grid">
              <Panel title="Restricted Intelligence Compartment" icon={<Lock/>} className="mc-span-2">
                <div className="mc-locked">LOCKED · PKI/mTLS/Smartcard required</div>
                <JsonBox data={data.restricted} />
              </Panel>
              <Panel title="Operational Safety Boundary" icon={<TerminalSquare/>} className="mc-span-2">
                <p className="mc-text">
                  Restricted EW/SIGINT/advanced red-team functions remain locked. This section is a controlled placeholder for future PKI, smartcard, mTLS, RBAC/ABAC, immutable audit and RF safety interlock integration.
                </p>
              </Panel>
            </div>
          )}
        </section>
      </section>

      <footer className="mc-footer">
        TRFMC v0.11 · Mission Control Layout · RF / Telco / SOC / Assets / Network / Evidence
      </footer>
    </main>
  )
}

createRoot(document.getElementById('root')!).render(<App />)
TSX

cat >> frontend/src/styles.css <<'CSS'

.mc-shell {
  min-height: 100vh;
  color: #e8f4ff;
  background:
    radial-gradient(circle at 18% 8%, rgba(88,214,249,.13), transparent 28%),
    radial-gradient(circle at 80% 15%, rgba(210,153,34,.10), transparent 24%),
    linear-gradient(135deg, #030711, #06111d 48%, #02040a);
  padding: 18px;
}

.mc-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: center;
  border: 1px solid rgba(88,214,249,.18);
  background: rgba(4,15,26,.78);
  border-radius: 18px;
  padding: 18px;
  box-shadow: 0 0 34px rgba(88,214,249,.08);
}

.mc-header h1 {
  margin: 0;
  font: 900 24px Consolas, monospace;
  letter-spacing: 1px;
  color: #eaf9ff;
}

.mc-header p {
  margin: 6px 0 0;
  color: var(--muted);
  font: 12px Consolas, monospace;
}

.mc-header-status {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.mc-header-status span {
  border: 1px solid rgba(88,214,249,.25);
  background: rgba(88,214,249,.08);
  color: var(--cyan);
  border-radius: 999px;
  padding: 7px 10px;
  font: 800 11px Consolas, monospace;
}

.mc-statusbar {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(145px, 1fr));
  gap: 10px;
  margin: 14px 0;
}

.mc-layout {
  display: grid;
  grid-template-columns: 235px 1fr;
  gap: 14px;
}

.mc-sidebar {
  border: 1px solid rgba(88,214,249,.18);
  background: rgba(4,15,26,.72);
  border-radius: 16px;
  padding: 10px;
  height: fit-content;
  position: sticky;
  top: 12px;
}

.mc-sidebar button {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 7px;
  border: 1px solid rgba(88,214,249,.12);
  background: rgba(255,255,255,.025);
  color: #d8edf6;
  border-radius: 11px;
  padding: 10px;
  font: 800 11px Consolas, monospace;
  text-align: left;
}

.mc-sidebar button svg {
  width: 16px;
  height: 16px;
}

.mc-sidebar button:hover,
.mc-sidebar .mc-nav-active {
  background: rgba(88,214,249,.13);
  border-color: rgba(88,214,249,.36);
  color: var(--cyan);
}

.mc-sidebar-footer {
  margin-top: 14px;
  border-top: 1px solid rgba(255,255,255,.08);
  padding-top: 10px;
}

.mc-content {
  min-width: 0;
}

.mc-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.mc-grid-wide {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.mc-span-2 {
  grid-column: span 2;
}

.mc-panel {
  border: 1px solid rgba(88,214,249,.16);
  background: rgba(4,15,26,.68);
  border-radius: 16px;
  box-shadow: inset 0 0 22px rgba(88,214,249,.035);
  overflow: hidden;
}

.mc-panel-title {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 11px 13px;
  border-bottom: 1px solid rgba(88,214,249,.13);
  color: var(--cyan);
  font: 900 12px Consolas, monospace;
  text-transform: uppercase;
  letter-spacing: .6px;
}

.mc-panel-title svg {
  width: 17px;
  height: 17px;
}

.mc-panel-body {
  padding: 13px;
}

.mc-kpi {
  border: 1px solid rgba(255,255,255,.08);
  background: rgba(255,255,255,.025);
  border-radius: 11px;
  padding: 9px;
  margin-bottom: 8px;
  display: flex;
  gap: 7px;
  align-items: baseline;
  flex-wrap: wrap;
}

.mc-kpi span {
  color: var(--muted);
  font: 700 10px Consolas, monospace;
  text-transform: uppercase;
}

.mc-kpi b {
  color: #f6fbff;
  font: 900 13px Consolas, monospace;
}

.mc-kpi em {
  color: var(--cyan);
  font: 700 10px Consolas, monospace;
  font-style: normal;
}

.mc-kpi.excellent b,
.mc-kpi.good b {
  color: #baffc9;
}

.mc-kpi.degraded b {
  color: #ffe0a3;
}

.mc-kpi.critical b {
  color: #ffd6df;
}

.mc-kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(135px, 1fr));
  gap: 8px;
}

.mc-json {
  max-height: 360px;
  overflow: auto;
  color: #dcecff;
  background: rgba(0,0,0,.23);
  border: 1px solid rgba(255,255,255,.06);
  border-radius: 10px;
  padding: 10px;
  font: 10px Consolas, monospace;
}

.mc-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 12px;
}

.mc-actions button {
  width: auto;
  border: 1px solid rgba(88,214,249,.28);
  background: rgba(88,214,249,.08);
  color: var(--cyan);
  border-radius: 9px;
  padding: 8px 10px;
  font: 800 11px Consolas, monospace;
}

.mc-wave {
  height: 110px;
  border: 1px solid rgba(88,214,249,.13);
  border-radius: 13px;
  margin-top: 12px;
  position: relative;
  background: linear-gradient(90deg, rgba(88,214,249,.04), rgba(210,153,34,.04));
  overflow: hidden;
}

.mc-wave-e,
.mc-wave-h {
  position: absolute;
  left: 6%;
  right: 6%;
  height: 2px;
  top: 50%;
  border-radius: 999px;
}

.mc-wave-e {
  background: rgba(88,214,249,.9);
  box-shadow: 0 0 22px rgba(88,214,249,.6);
  transform: translateY(-18px) skewX(-18deg);
}

.mc-wave-h {
  background: rgba(210,153,34,.9);
  box-shadow: 0 0 22px rgba(210,153,34,.5);
  transform: translateY(18px) skewX(18deg);
}

.mc-wave span {
  position: absolute;
  right: 14px;
  bottom: 10px;
  color: var(--cyan);
  font: 900 12px Consolas, monospace;
}

.mc-pattern {
  min-height: 135px;
  display: flex;
  align-items: end;
  gap: 4px;
  border: 1px solid rgba(88,214,249,.13);
  border-radius: 13px;
  padding: 10px;
  background: rgba(88,214,249,.035);
}

.mc-pattern-bar {
  flex: 1;
  min-width: 4px;
  border-radius: 6px 6px 0 0;
  background: linear-gradient(to top, rgba(88,214,249,.32), rgba(88,214,249,.95));
  box-shadow: 0 0 10px rgba(88,214,249,.22);
}

.mc-state {
  margin: 10px 0;
  border-radius: 10px;
  padding: 9px;
  font: 900 12px Consolas, monospace;
  border: 1px solid rgba(255,255,255,.1);
}

.mc-state.clear {
  color: #baffc9;
  background: rgba(63,185,80,.12);
}

.mc-state.partial_block {
  color: #ffe0a3;
  background: rgba(210,153,34,.13);
}

.mc-state.blocked {
  color: #ffd6df;
  background: rgba(255,77,109,.14);
}

.mc-coverage {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}

.mc-cell {
  min-height: 25px;
  display: grid;
  place-items: center;
  border-radius: 6px;
  font: 800 9px Consolas, monospace;
  border: 1px solid rgba(255,255,255,.08);
}

.mc-cell.excellent {
  background: rgba(63,185,80,.22);
  color: #baffc9;
}

.mc-cell.good {
  background: rgba(88,214,249,.18);
  color: #d7f7ff;
}

.mc-cell.degraded {
  background: rgba(210,153,34,.18);
  color: #ffe0a3;
}

.mc-cell.critical {
  background: rgba(255,77,109,.20);
  color: #ffd6df;
}

.mc-journey,
.mc-assets,
.mc-mini-list {
  display: grid;
  gap: 8px;
}

.mc-journey {
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
}

.mc-journey-card,
.mc-asset {
  border: 1px solid rgba(88,214,249,.13);
  background: rgba(88,214,249,.045);
  border-radius: 11px;
  padding: 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.mc-journey-card b,
.mc-asset b {
  color: var(--cyan);
  font: 900 11px Consolas, monospace;
}

.mc-journey-card span,
.mc-asset span {
  color: #f3fbff;
  font: 700 11px Consolas, monospace;
}

.mc-journey-card em,
.mc-asset em {
  color: var(--muted);
  font: 10px Consolas, monospace;
  font-style: normal;
}

.mc-assets {
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
}

.mc-banner,
.mc-error,
.mc-locked,
.mc-text {
  border-radius: 12px;
  padding: 12px;
  font: 800 12px Consolas, monospace;
}

.mc-banner {
  background: rgba(88,214,249,.08);
  border: 1px solid rgba(88,214,249,.22);
  color: var(--cyan);
  margin-bottom: 12px;
}

.mc-error,
.mc-locked {
  background: rgba(255,77,109,.12);
  border: 1px solid rgba(255,77,109,.28);
  color: #ffd6df;
}

.mc-text {
  color: var(--muted);
  border: 1px solid rgba(255,255,255,.08);
  background: rgba(255,255,255,.025);
}

.mc-footer {
  margin-top: 14px;
  border: 1px solid rgba(88,214,249,.16);
  border-radius: 14px;
  padding: 11px;
  color: var(--muted);
  text-align: center;
  font: 800 11px Consolas, monospace;
  background: rgba(4,15,26,.58);
}

@media (max-width: 1100px) {
  .mc-layout {
    grid-template-columns: 1fr;
  }

  .mc-sidebar {
    position: static;
  }

  .mc-grid,
  .mc-grid-wide {
    grid-template-columns: 1fr;
  }

  .mc-span-2 {
    grid-column: span 1;
  }
}
CSS

echo "=== VERIFICA v0.11 ==="
grep -n 'version=' backend/app/main.py
grep -n '"version":' backend/app/main.py
grep -n "Mission Control Layout" frontend/src/app/main.tsx | head
