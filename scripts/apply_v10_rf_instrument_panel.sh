#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

echo "============================================================"
echo "APPLY v0.10 RF VISUALIZATION / INSTRUMENT PANEL"
echo "============================================================"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
s = p.read_text()

s = re.sub(r'version="0\.\d+\.0"', 'version="0.10.0"', s)
s = re.sub(r'"version": "0\.\d+\.0"', '"version": "0.10.0"', s)

s = s.replace(
    'description="Telco RF Mission Control Platform — RF field, antenna and Fresnel engine skeleton."',
    'description="Telco RF Mission Control Platform — RF visualization and enterprise instrument panel."'
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
  Satellite,
  Clock,
  Radar,
  Crosshair,
  Waves,
  Gauge,
  Map,
  Cpu
} from 'lucide-react'
import { API_BASE } from '../shared/api'
import '../styles.css'

type AnyObj = Record<string, any>

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

function Panel({title, icon, children, wide=false}: {title: string, icon?: React.ReactNode, children: React.ReactNode, wide?: boolean}) {
  return (
    <section className={wide ? 'panel panel-wide' : 'panel'}>
      <div className="panel-h">{icon}{title}</div>
      <div className="panel-b">{children}</div>
    </section>
  )
}

function Metric({label, value, unit}: {label: string, value: any, unit?: string}) {
  return <div className="metric"><span>{label}</span><b>{value ?? '—'}</b>{unit && <em>{unit}</em>}</div>
}

function fmt(v:any, digits=2) {
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

function App() {
  const [data, setData] = React.useState<AnyObj>({})
  const [err, setErr] = React.useState<string>('')
  const [stream, setStream] = React.useState<any[]>([])
  const [wsState, setWsState] = React.useState<string>('CONNECTING')
  const [selectedTarget, setSelectedTarget] = React.useState<string>('UE-REMOTE-001')

  async function load(target = selectedTarget) {
    const calls: [string,string][] = [
      ['health','/health'],
      ['mission','/mission/status'],
      ['persist','/persistence/status'],
      ['time','/time-cursor/status'],
      ['timeline','/time-cursor/timeline'],
      ['events','/persistence/events'],
      ['assetGraph','/assets/graph'],
      ['networkOverview','/network-fabric/overview'],
      ['networkPaths','/network-fabric/paths'],
      ['rfCoverage','/rf-coverage/demo'],
      ['rfCoverageRuns','/rf-coverage/runs'],
      ['rfField',`/rf-field/demo?target_asset_id=${encodeURIComponent(target)}`],
      ['rfFieldRuns','/rf-field/runs'],
      ['antennaPattern','/rf-field/antenna-pattern'],
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
        setStream(prev => [msg, ...prev].slice(0, 16))
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

  async function runRfCoverage() {
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

  const rf = data.rfField ?? {}
  const cov = data.rfCoverage ?? {}
  const ant = rf.antenna ?? {}
  const field = rf.field_at_target ?? {}
  const fresnel = rf.fresnel ?? {}
  const targetLink = cov.target_link ?? {}
  const statusCounts = data.persist?.counts ?? {}

  return (
    <main className="shell instrument-shell">
      <header className="top instrument-top">
        <div>
          <h1>TELCO RF MISSION CONTROL PLATFORM</h1>
          <p>v0.10 · RF Instrument Panel · Maxwell · Antenna · Fresnel · Coverage · Mission Correlation</p>
        </div>
        <div className="badge">BACKEND {data.health?.version ?? '—'} · {data.health?.operational_mode ?? 'BOOT'} · WS {wsState}</div>
      </header>

      <section className="instrument-ribbon">
        <Metric label="λ" value={sci(rf.wave?.wavelength_m)} unit="m" />
        <Metric label="β" value={sci(rf.wave?.beta_rad_m)} unit="rad/m" />
        <Metric label="η0" value={fmt(rf.constants?.eta0_ohm, 2)} unit="Ω" />
        <Metric label="Region" value={field.field_region} />
        <Metric label="RF Runs" value={statusCounts.rf_field_runs ?? 0} />
        <Metric label="Coverage Runs" value={statusCounts.rf_coverage_runs ?? 0} />
      </section>

      <section className="layout">
        <aside className="nav">
          {[
            'RF Instrument',
            'Antenna Pattern',
            'Fresnel Clearance',
            'E/H/Poynting',
            'Coverage Grid',
            'Link Budget',
            'UE/UAV Target',
            'Mission Events',
            'Asset Twin',
            'Network Journey',
            'SOC/NOC',
            'Restricted'
          ].map(x => <div className="navitem" key={x}>{x}</div>)}
        </aside>

        <section className="main instrument-main">
          {err && <div className="error">{err}</div>}

          <div className="grid2">
            <Panel title="RF Field / Maxwell View" icon={<Waves/>}>
              <div className="instrument-kpis">
                <Metric label="E" value={sci(field.electric_field_v_m)} unit="V/m" />
                <Metric label="H" value={sci(field.magnetic_field_a_m)} unit="A/m" />
                <Metric label="S" value={sci(field.poynting_w_m2)} unit="W/m²" />
                <Metric label="Distance" value={fmt(field.distance_m, 2)} unit="m" />
              </div>
              <div className="wave-visual">
                <div className="wave-line wave-e"></div>
                <div className="wave-line wave-h"></div>
                <div className="wave-axis">k →</div>
              </div>
            </Panel>

            <Panel title="Target Selector / UE-UAV" icon={<Crosshair/>}>
              <div className="buttons">
                <button onClick={() => switchTarget('UE-REMOTE-001')}>UE-REMOTE-001</button>
                <button onClick={() => switchTarget('UAV-ALPHA-001')}>UAV-ALPHA-001</button>
                <button onClick={() => runRfField()}>Run RF Field</button>
                <button onClick={() => runRfCoverage()}>Run Coverage</button>
              </div>
              <div className="target-card">
                <b>{selectedTarget}</b>
                <span>Gain to target: {fmt(ant.gain_to_target_dbi, 2)} dBi</span>
                <span>Bearing: {fmt(ant.bearing_to_target_deg, 2)}°</span>
                <span>Relative azimuth: {fmt(ant.relative_azimuth_deg, 2)}°</span>
                <span>Elevation: {fmt(ant.elevation_to_target_deg, 2)}°</span>
              </div>
            </Panel>
          </div>

          <Panel title="Antenna Pattern Instrument" icon={<Radar/>} wide>
            <div className="pattern-wrap">
              <div className="pattern-bars">
                {ant.pattern?.azimuth?.map((p:any, idx:number) => (
                  <div
                    className="pattern-bar"
                    key={idx}
                    style={{height: `${Math.max(6, (Number(p.gain_dbi) + 35) * 2.2)}px`}}
                    title={`${p.angle_deg}° · ${p.gain_dbi} dBi`}
                  />
                ))}
              </div>
              <pre>{JSON.stringify({
                model: ant.pattern?.model,
                max_gain_dbi: ant.pattern?.max_gain_dbi,
                hpbw_h: ant.pattern?.horizontal_hpbw_deg,
                hpbw_v: ant.pattern?.vertical_hpbw_deg,
                mechanical_tilt_deg: ant.pattern?.mechanical_tilt_deg,
                electrical_tilt_deg: ant.pattern?.electrical_tilt_deg
              }, null, 2)}</pre>
            </div>
          </Panel>

          <div className="grid2">
            <Panel title="Fresnel Clearance" icon={<Satellite/>}>
              <Metric label="Total 2D distance" value={fmt(fresnel.total_2d_distance_m, 2)} unit="m" />
              <div className={'fresnel-state ' + cls(fresnel.worst_case?.fresnel_state)}>
                Worst case: {fresnel.worst_case?.obstacle_id ?? '—'} · {fresnel.worst_case?.fresnel_state ?? '—'}
              </div>
              <pre>{JSON.stringify(fresnel.worst_case, null, 2)}</pre>
            </Panel>

            <Panel title="Link Budget / Coverage Target" icon={<Gauge/>}>
              <Metric label="FSPL" value={fmt(targetLink.fspl_db, 2)} unit="dB" />
              <Metric label="Obstacle loss" value={fmt(targetLink.obstacle_loss_db, 2)} unit="dB" />
              <Metric label="Total loss" value={fmt(targetLink.total_path_loss_db, 2)} unit="dB" />
              <Metric label="Rx power" value={fmt(targetLink.rx_power_dbm, 2)} unit="dBm" />
              <Metric label="Noise floor" value={fmt(targetLink.noise_floor_dbm, 2)} unit="dBm" />
              <Metric label="SNR" value={fmt(targetLink.snr_db, 2)} unit="dB" />
              <div className={'risk ' + cls(targetLink.classification)}>{targetLink.classification ?? '—'} · {targetLink.los_state ?? '—'}</div>
            </Panel>
          </div>

          <Panel title="RF Coverage Grid / Urban Obstruction" icon={<Map/>} wide>
            <div className="coverage-grid instrument-coverage">
              {cov.coverage_grid?.slice(0, 49).map((p:any, idx:number) => (
                <div className={'cov-cell ' + cls(p.classification)} key={idx} title={`${p.x_m},${p.y_m} · ${p.snr_db} dB · ${p.los_state}`}>
                  {fmt(p.snr_db, 1)}
                </div>
              ))}
            </div>
            <div className="summary-line">
              Grid: {cov.summary?.grid_points ?? '—'} · NLOS: {cov.summary?.nlos_points ?? '—'} · Excellent: {cov.summary?.excellent ?? '—'} · Good: {cov.summary?.good ?? '—'} · Degraded: {cov.summary?.degraded ?? '—'} · Critical: {cov.summary?.critical ?? '—'}
            </div>
          </Panel>

          <Panel title="Network Journey Correlation" icon={<Network/>}>
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
        </section>

        <aside className="context">
          <Panel title="Mission / Time Cursor" icon={<Clock/>}>
            <pre>{JSON.stringify(data.time, null, 2)}</pre>
          </Panel>

          <Panel title="Persistence / Run History" icon={<Database/>}>
            <pre>{JSON.stringify(data.persist, null, 2)}</pre>
          </Panel>

          <Panel title="RF Field Runs" icon={<Cpu/>}>
            <pre>{JSON.stringify(data.rfFieldRuns?.slice?.(0, 3) ?? data.rfFieldRuns, null, 2)}</pre>
          </Panel>

          <Panel title="Live Event Stream" icon={<Activity/>}>
            <pre>{JSON.stringify(stream.length ? stream : data.events?.slice?.(0, 5), null, 2)}</pre>
          </Panel>

          <Panel title="RAT / Wi-Fi Trust" icon={<Shield/>}>
            <div className="risk high">{data.rat?.classification}</div>
            <div className="risk critical">{data.wifi?.classification}</div>
          </Panel>

          <Panel title="Telco MnS / OAM" icon={<Server/>}>
            <pre>{JSON.stringify(data.mns, null, 2)}</pre>
          </Panel>

          <Panel title="Restricted Intelligence" icon={<Lock/>}>
            <div className="locked">LOCKED</div>
            <pre>{JSON.stringify(data.restricted, null, 2)}</pre>
          </Panel>
        </aside>
      </section>

      <footer className="timeline">
        v0.10 RF INSTRUMENT PANEL · E/H/S · ANTENNA PATTERN · FRESNEL · COVERAGE · LINK BUDGET · UE/UAV · EVENTS
      </footer>
    </main>
  )
}

createRoot(document.getElementById('root')!).render(<App />)
TSX

cat >> frontend/src/styles.css <<'CSS'

.instrument-shell {
  background:
    radial-gradient(circle at 20% 10%, rgba(88,214,249,.12), transparent 30%),
    radial-gradient(circle at 80% 20%, rgba(210,153,34,.10), transparent 25%),
    linear-gradient(135deg, #061019 0%, #08111d 45%, #02060c 100%);
}

.instrument-ribbon {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(145px, 1fr));
  gap: 10px;
  margin: 12px 0;
}

.instrument-ribbon .metric,
.instrument-kpis .metric {
  border: 1px solid rgba(88,214,249,.18);
  background: rgba(4,18,29,.72);
  border-radius: 12px;
  padding: 10px;
}

.metric span {
  color: var(--muted);
  margin-right: 6px;
}

.metric b {
  color: #f2f7fb;
  margin-right: 5px;
}

.metric em {
  color: var(--cyan);
  font-style: normal;
}

.instrument-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(135px, 1fr));
  gap: 8px;
}

.wave-visual {
  height: 120px;
  border: 1px solid rgba(88,214,249,.16);
  border-radius: 12px;
  margin-top: 12px;
  position: relative;
  overflow: hidden;
  background: linear-gradient(90deg, rgba(88,214,249,.04), rgba(210,153,34,.04));
}

.wave-line {
  position: absolute;
  left: 5%;
  right: 5%;
  height: 2px;
  top: 50%;
  border-radius: 999px;
}

.wave-e {
  background: rgba(88,214,249,.85);
  box-shadow: 0 0 22px rgba(88,214,249,.65);
  transform: translateY(-18px) skewX(-20deg);
}

.wave-h {
  background: rgba(210,153,34,.85);
  box-shadow: 0 0 22px rgba(210,153,34,.55);
  transform: translateY(18px) skewX(20deg);
}

.wave-axis {
  position: absolute;
  right: 16px;
  bottom: 12px;
  color: var(--cyan);
  font: 800 12px Consolas, monospace;
}

.target-card {
  margin-top: 12px;
  border: 1px solid rgba(88,214,249,.18);
  background: rgba(88,214,249,.055);
  border-radius: 12px;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 5px;
  font: 12px Consolas, monospace;
}

.target-card b {
  color: var(--cyan);
}

.pattern-wrap {
  display: grid;
  grid-template-columns: 1.5fr 1fr;
  gap: 12px;
}

.pattern-bars {
  min-height: 130px;
  display: flex;
  align-items: end;
  gap: 4px;
  border: 1px solid rgba(88,214,249,.16);
  border-radius: 12px;
  padding: 10px;
  background: rgba(88,214,249,.035);
}

.pattern-bar {
  flex: 1;
  min-width: 4px;
  border-radius: 6px 6px 0 0;
  background: linear-gradient(to top, rgba(88,214,249,.35), rgba(88,214,249,.9));
  box-shadow: 0 0 10px rgba(88,214,249,.20);
}

.fresnel-state {
  margin: 10px 0;
  border-radius: 10px;
  padding: 9px;
  font: 800 12px Consolas, monospace;
  border: 1px solid rgba(255,255,255,.1);
}

.fresnel-state.clear {
  color: #baffc9;
  background: rgba(63,185,80,.12);
}

.fresnel-state.partial_block {
  color: #ffe0a3;
  background: rgba(210,153,34,.13);
}

.fresnel-state.blocked {
  color: #ffd6df;
  background: rgba(255,77,109,.14);
}

.instrument-coverage {
  max-width: 620px;
}

.summary-line {
  margin-top: 10px;
  color: var(--muted);
  font: 11px Consolas, monospace;
}

.panel-wide {
  grid-column: 1 / -1;
}
CSS

echo "=== VERIFICA v0.10 ==="
grep -n 'version=' backend/app/main.py
grep -n '"version":' backend/app/main.py
grep -n "RF Instrument" frontend/src/app/main.tsx | head
