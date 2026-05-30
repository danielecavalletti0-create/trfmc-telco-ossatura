#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"
CLIENT="$ROOT/frontend/src/shared/liveContractsV32R1.ts"
PANEL="$ROOT/frontend/src/rf_instruments/telemetry/RFLiveContractStatusV32R1.tsx"
WRAPPER="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV32R1LiveContracts.tsx"

echo "============================================================"
echo "TRFMC FRONTEND LIVE CONTRACT OVERLAY V32R1"
echo "React read-only API binding · 4181/8000 contracts · frontend-only"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes" \
  "$ROOT/frontend/src/shared" \
  "$ROOT/frontend/src/rf_instruments/telemetry" \
  "$ROOT/frontend/src/rf_instruments/instruments"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$STYLES" || { echo "ERRORE: styles.css mancante"; exit 1; }
test -f "$ROOT/runtime/quality/latest_frontend_api_binding_audit_v32/summary.json" || {
  echo "ERRORE: V32 audit summary mancante"
  exit 1
}
test -f "$ROOT/runtime/quality/latest_contract_semantics_hygiene_v31r1/summary.json" || {
  echo "ERRORE: V31R1 summary mancante"
  exit 1
}

V31R1_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_contract_semantics_hygiene_v31r1/summary.json").read_text())
print(d.get("result",""))
PY
)"

V32_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_frontend_api_binding_audit_v32/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V31R1_RESULT" = "PASS" ] || { echo "ERRORE: V31R1 non PASS"; exit 1; }
[ "$V32_RESULT" = "PASS" ] || { echo "ERRORE: V32 non PASS"; exit 1; }

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: 4181 non passa al backend reale"
  exit 1
}

grep -q "RFOperationalDeckV16ChunkObservatory" "$MAIN" || {
  echo "ERRORE: V16 deck non trovato in main.tsx; patch non sicura"
  exit 1
}

echo "OK: V31R1 PASS, V32 PASS, 4181 live, V16 mount presente"

echo
echo "=== BACKUP PRE-PATCH ==="

PRE_FREEZE="$ROOT/runtime/freezes/TRFMC_BEFORE_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1_$TS.tar.gz"
tar -czf "$PRE_FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/shared \
  frontend/src/rf_instruments \
  2>/dev/null || true

cp "$MAIN" "$RELEASE_DIR/main.tsx.bak_before_v32r1_$TS"
cp "$STYLES" "$RELEASE_DIR/styles.css.bak_before_v32r1_$TS"

echo "Freeze pre-patch: $PRE_FREEZE"

echo
echo "=== CREATE LIVE CONTRACT CLIENT ==="

cat > "$CLIENT" <<'TS'
export type LiveContractResult<T = unknown> = {
  endpoint: string
  ok: boolean
  status: number
  data: T | null
  error?: string
  latencyMs: number
}

export type LiveContractSnapshot = {
  timestamp: string
  mission: LiveContractResult
  open5gs: LiveContractResult
  ueransim: LiveContractResult
  bandplan: LiveContractResult
  spectrumSweep: LiveContractResult
  socNoc: LiveContractResult
}

const CONTRACT_ENDPOINTS = {
  mission: '/api/mission/status',
  open5gs: '/api/core/open5gs/status',
  ueransim: '/api/ran/ueransim/status',
  bandplan: '/api/rfpro/bandplan',
  spectrumSweep: '/api/rfpro/spectrum/sweep',
  socNoc: '/api/soc-noc/correlation/demo',
} as const

export function getTrfmcApiBase(): string {
  if (typeof window === 'undefined') return ''
  const { protocol, hostname, port } = window.location

  // Vite dev/preview must call the stable NGINX API proxy.
  if (hostname === '127.0.0.1' && (port === '5173' || port === '4173')) {
    return 'http://127.0.0.1:4181'
  }

  // When served by 4181, relative /api routes go through the same origin.
  if (hostname === '127.0.0.1' && port === '4181') {
    return ''
  }

  // Safe local fallback for other local dev ports.
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return `${protocol}//127.0.0.1:4181`
  }

  return ''
}

export async function fetchLiveContract<T = unknown>(
  endpoint: string,
  signal?: AbortSignal,
): Promise<LiveContractResult<T>> {
  const started = performance.now()
  const url = `${getTrfmcApiBase()}${endpoint}`

  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal,
    })

    const text = await response.text()
    let data: T | null = null

    try {
      data = text ? (JSON.parse(text) as T) : null
    } catch {
      return {
        endpoint,
        ok: false,
        status: response.status,
        data: null,
        error: 'invalid_json',
        latencyMs: Math.round(performance.now() - started),
      }
    }

    return {
      endpoint,
      ok: response.ok,
      status: response.status,
      data,
      latencyMs: Math.round(performance.now() - started),
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return {
      endpoint,
      ok: false,
      status: 0,
      data: null,
      error: message,
      latencyMs: Math.round(performance.now() - started),
    }
  }
}

export async function fetchLiveContractSnapshot(signal?: AbortSignal): Promise<LiveContractSnapshot> {
  const [mission, open5gs, ueransim, bandplan, spectrumSweep, socNoc] = await Promise.all([
    fetchLiveContract(CONTRACT_ENDPOINTS.mission, signal),
    fetchLiveContract(CONTRACT_ENDPOINTS.open5gs, signal),
    fetchLiveContract(CONTRACT_ENDPOINTS.ueransim, signal),
    fetchLiveContract(CONTRACT_ENDPOINTS.bandplan, signal),
    fetchLiveContract(CONTRACT_ENDPOINTS.spectrumSweep, signal),
    fetchLiveContract(CONTRACT_ENDPOINTS.socNoc, signal),
  ])

  return {
    timestamp: new Date().toISOString(),
    mission,
    open5gs,
    ueransim,
    bandplan,
    spectrumSweep,
    socNoc,
  }
}

export function extractString(data: unknown, path: string[], fallback = '—'): string {
  let current: unknown = data

  for (const key of path) {
    if (current && typeof current === 'object' && key in current) {
      current = (current as Record<string, unknown>)[key]
    } else {
      return fallback
    }
  }

  if (current === null || current === undefined) return fallback
  if (typeof current === 'string') return current
  if (typeof current === 'number' || typeof current === 'boolean') return String(current)
  return fallback
}

export function extractNumber(data: unknown, path: string[], fallback = 0): number {
  let current: unknown = data

  for (const key of path) {
    if (current && typeof current === 'object' && key in current) {
      current = (current as Record<string, unknown>)[key]
    } else {
      return fallback
    }
  }

  return typeof current === 'number' ? current : fallback
}

export function getEndpointHealth(result: LiveContractResult | undefined): 'ok' | 'warn' | 'down' {
  if (!result) return 'warn'
  if (!result.ok) return 'down'
  const source = extractString(result.data, ['source'], '')
  if (source === 'trfmc-nginx-v21-api-fallback') return 'down'
  return 'ok'
}
TS

echo
echo "=== CREATE LIVE STATUS PANEL ==="

cat > "$PANEL" <<'TSX'
import React, { useEffect, useMemo, useState } from 'react'
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
TSX

echo
echo "=== CREATE WRAPPER ==="

cat > "$WRAPPER" <<'TSX'
import React from 'react'
import { RFOperationalDeckV16ChunkObservatory } from './RFOperationalDeckV16ChunkObservatory'
import { RFLiveContractStatusV32R1 } from '../telemetry/RFLiveContractStatusV32R1'

export function RFOperationalDeckV32R1LiveContracts() {
  return (
    <>
      <RFLiveContractStatusV32R1 />
      <RFOperationalDeckV16ChunkObservatory />
    </>
  )
}
TSX

echo
echo "=== APPEND CSS ==="

cat >> "$STYLES" <<'CSS'

/* === TRFMC V32R1 LIVE CONTRACT OVERLAY === */
.v32r1-live-contract-shell{
  margin:18px;
  padding:18px;
  border:1px solid rgba(77,211,255,.22);
  border-radius:22px;
  background:
    radial-gradient(circle at 15% 0%,rgba(38,173,255,.18),transparent 34%),
    linear-gradient(135deg,rgba(6,18,31,.94),rgba(2,8,16,.96));
  box-shadow:0 24px 70px rgba(0,0,0,.34), inset 0 0 30px rgba(47,191,255,.05);
}

.v32r1-live-contract-header{
  display:flex;
  justify-content:space-between;
  gap:18px;
  align-items:flex-start;
  margin-bottom:16px;
}

.v32r1-eyebrow{
  margin:0 0 6px;
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
  color:#6ce7ff;
}

.v32r1-live-contract-header h2{
  margin:0;
  color:#eaf8ff;
  font-size:22px;
}

.v32r1-live-contract-header span{
  display:block;
  margin-top:8px;
  color:#90aeca;
  font-size:13px;
}

.v32r1-score{
  min-width:124px;
  padding:12px 14px;
  border:1px solid rgba(124,255,177,.24);
  border-radius:16px;
  background:rgba(5,34,28,.42);
  text-align:center;
}

.v32r1-score strong{
  display:block;
  font-size:24px;
  color:#8dffbb;
}

.v32r1-score small{
  color:#87b99e;
}

.v32r1-contract-grid{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:12px;
}

.v32r1-contract-card{
  padding:14px;
  border-radius:16px;
  background:rgba(8,21,36,.78);
  border:1px solid rgba(92,142,180,.18);
}

.v32r1-contract-card-head{
  display:flex;
  justify-content:space-between;
  gap:12px;
  font-size:12px;
  letter-spacing:.08em;
  text-transform:uppercase;
  color:#8fb7d8;
}

.v32r1-contract-card-head strong{
  font-size:11px;
}

.v32r1-contract-card-ok{
  border-color:rgba(125,255,178,.32);
}

.v32r1-contract-card-ok .v32r1-contract-card-head strong{
  color:#8dffbb;
}

.v32r1-contract-card-warn{
  border-color:rgba(255,209,102,.34);
}

.v32r1-contract-card-warn .v32r1-contract-card-head strong{
  color:#ffd166;
}

.v32r1-contract-card-down{
  border-color:rgba(255,95,122,.4);
}

.v32r1-contract-card-down .v32r1-contract-card-head strong{
  color:#ff6f8d;
}

.v32r1-contract-card p{
  margin:12px 0 6px;
  color:#f0fbff;
  font-size:17px;
  font-weight:700;
}

.v32r1-contract-card small{
  color:#93abc2;
}

.v32r1-contract-card code{
  display:block;
  margin-top:10px;
  color:#6ce7ff;
  font-size:11px;
  word-break:break-all;
}

.v32r1-contract-footer{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:16px;
  margin-top:14px;
  color:#8fa8bd;
  font-size:12px;
}

.v32r1-contract-error{
  margin-bottom:12px;
  padding:10px 12px;
  border:1px solid rgba(255,95,122,.32);
  border-radius:12px;
  background:rgba(77,8,22,.42);
  color:#ffc1ca;
}

@media (max-width:1100px){
  .v32r1-contract-grid{
    grid-template-columns:repeat(2,minmax(0,1fr));
  }
}

@media (max-width:760px){
  .v32r1-live-contract-header,
  .v32r1-contract-footer{
    flex-direction:column;
    align-items:stretch;
  }

  .v32r1-contract-grid{
    grid-template-columns:1fr;
  }
}
CSS

echo
echo "=== PATCH main.tsx V16 -> V32R1 WRAPPER ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

old_import = "import { RFOperationalDeckV16ChunkObservatory } from '../rf_instruments/instruments/RFOperationalDeckV16ChunkObservatory'"
new_import = "import { RFOperationalDeckV32R1LiveContracts } from '../rf_instruments/instruments/RFOperationalDeckV32R1LiveContracts'"

if new_import not in txt:
    if old_import not in txt:
        raise SystemExit("ERRORE: import V16 non trovato")
    txt = txt.replace(old_import, new_import, 1)

txt = txt.replace("<RFOperationalDeckV16ChunkObservatory />", "<RFOperationalDeckV32R1LiveContracts />")

p.write_text(txt, encoding="utf-8")
print("OK: main.tsx patched to V32R1 wrapper")
PY

echo
echo "=== CREATE ROLLBACK ==="

ROLLBACK="$RELEASE_DIR/rollback_v32r1_live_contract_overlay.sh"

cat > "$ROLLBACK" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"

cp "$RELEASE_DIR/main.tsx.bak_before_v32r1_$TS" frontend/src/app/main.tsx
cp "$RELEASE_DIR/styles.css.bak_before_v32r1_$TS" frontend/src/styles.css

rm -f \
  frontend/src/shared/liveContractsV32R1.ts \
  frontend/src/rf_instruments/telemetry/RFLiveContractStatusV32R1.tsx \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV32R1LiveContracts.tsx

echo "Rollback V32R1 completato"
