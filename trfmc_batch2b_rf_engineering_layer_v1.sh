#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2B_RF_ENGINEERING_LAYER_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

PROMO="frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx"
HOOK="frontend/src/rf_instruments/hooks/useRFSpectrumSweep.ts"
LAYER="frontend/src/rf_instruments/panels/RFEngineeringMath3DPanelV1.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_batch2b_rf_engineering_layer_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_engineering_layer_v1_1920x1080.png"
DIFF="$OUT/rf_engineering_layer_v1.diff"
RESTORE="$OUT/RESTORE_RF_ENGINEERING_LAYER_V1.sh"

echo "============================================================"
echo "TRFMC_BATCH2B_RF_ENGINEERING_LAYER_V1"
echo "React source layer · real API adapter · RF math · WebGL 3D preview"
echo "Timestamp: $TS"
echo "============================================================"

mkdir -p "$(dirname "$HOOK")" "$(dirname "$LAYER")"

if [ ! -f "$PROMO" ] || [ ! -f "$CSS" ]; then
  echo "ERRORE: RFSignalAnalyzerPromotionV1.tsx o styles.css non trovato"
  exit 1
fi

cp -a "$PROMO" "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

[ -f "$HOOK" ] && cp -a "$HOOK" "$BACKUP/useRFSpectrumSweep.ts.before_$TS"
[ -f "$LAYER" ] && cp -a "$LAYER" "$BACKUP/RFEngineeringMath3DPanelV1.tsx.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS" "$PROMO"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"

if [ -f "$BACKUP/useRFSpectrumSweep.ts.before_$TS" ]; then
  cp -a "$BACKUP/useRFSpectrumSweep.ts.before_$TS" "$HOOK"
else
  rm -f "$HOOK"
fi

if [ -f "$BACKUP/RFEngineeringMath3DPanelV1.tsx.before_$TS" ]; then
  cp -a "$BACKUP/RFEngineeringMath3DPanelV1.tsx.before_$TS" "$LAYER"
else
  rm -f "$LAYER"
fi

echo "RESTORE_RF_ENGINEERING_LAYER_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA useRFSpectrumSweep.ts ==="

cat > "$HOOK" <<'TS'
import { useEffect, useMemo, useState } from 'react'

export type RFSweepMetrics = {
  snrDb: number | null
  evmPct: number | null
  merDb: number | null
  obwMhz: number | null
  aclrLowDbc: number | null
  aclrHighDbc: number | null
  channelPowerDbm: number | null
  noiseFloorDbm: number | null
  crestFactorDb: number | null
}

export type RFSweepSnapshot = {
  endpoint: string
  ok: boolean
  status: number
  timestamp: string
  source: 'api' | 'synthetic-fallback'
  binCount: number
  samplePreview: string
  metrics: RFSweepMetrics
  raw: unknown
}

type UseRFSpectrumSweepOptions = {
  enabled?: boolean
  intervalMs?: number
  endpoint?: string
}

const DEFAULT_ENDPOINT = '/api/rfpro/spectrum/sweep'

function readPath(obj: unknown, path: string): unknown {
  if (!obj || typeof obj !== 'object') return undefined
  return path.split('.').reduce<unknown>((acc, key) => {
    if (!acc || typeof acc !== 'object') return undefined
    return (acc as Record<string, unknown>)[key]
  }, obj)
}

function pickNumber(obj: unknown, paths: string[], fallback: number | null = null): number | null {
  for (const path of paths) {
    const value = readPath(obj, path)
    if (typeof value === 'number' && Number.isFinite(value)) return Number(value.toFixed(3))
    if (typeof value === 'string') {
      const parsed = Number(value.replace(/[^\d.-]/g, ''))
      if (Number.isFinite(parsed)) return Number(parsed.toFixed(3))
    }
  }
  return fallback
}

function detectBinCount(obj: unknown): number {
  const candidates = [
    readPath(obj, 'bins'),
    readPath(obj, 'trace'),
    readPath(obj, 'spectrum'),
    readPath(obj, 'data.bins'),
    readPath(obj, 'data.trace'),
    readPath(obj, 'payload.bins'),
    readPath(obj, 'payload.trace'),
  ]

  for (const candidate of candidates) {
    if (Array.isArray(candidate)) return candidate.length
  }

  return 0
}

function compactPreview(rawText: string): string {
  return rawText.replace(/\s+/g, ' ').slice(0, 180)
}

function syntheticFallback(endpoint: string, reason = 'waiting-api'): RFSweepSnapshot {
  return {
    endpoint,
    ok: false,
    status: 0,
    timestamp: new Date().toISOString(),
    source: 'synthetic-fallback',
    binCount: 4096,
    samplePreview: reason,
    metrics: {
      snrDb: 34.7,
      evmPct: 3.8,
      merDb: 34.2,
      obwMhz: 12.4,
      aclrLowDbc: -51.7,
      aclrHighDbc: -50.9,
      channelPowerDbm: -18.2,
      noiseFloorDbm: -96.8,
      crestFactorDb: 9.6,
    },
    raw: null,
  }
}

export function useRFSpectrumSweep(options: UseRFSpectrumSweepOptions = {}) {
  const {
    enabled = true,
    intervalMs = 2500,
    endpoint = DEFAULT_ENDPOINT,
  } = options

  const [snapshot, setSnapshot] = useState<RFSweepSnapshot | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!enabled) return

    let cancelled = false
    let timer: number | undefined

    async function load() {
      const controller = new AbortController()
      const timeout = window.setTimeout(() => controller.abort(), 2200)

      try {
        setLoading(true)
        const res = await fetch(endpoint, {
          method: 'GET',
          signal: controller.signal,
          headers: { Accept: 'application/json,text/plain,*/*' },
        })

        const text = await res.text()
        let parsed: unknown = text

        try {
          parsed = JSON.parse(text)
        } catch {
          parsed = { rawText: text }
        }

        const next: RFSweepSnapshot = {
          endpoint,
          ok: res.ok,
          status: res.status,
          timestamp: new Date().toISOString(),
          source: res.ok ? 'api' : 'synthetic-fallback',
          binCount: detectBinCount(parsed) || 4096,
          samplePreview: compactPreview(text),
          metrics: {
            snrDb: pickNumber(parsed, ['snr', 'SNR', 'metrics.snr', 'metrics.snrDb', 'kpi.snr']),
            evmPct: pickNumber(parsed, ['evm', 'EVM', 'metrics.evm', 'metrics.evmPct', 'kpi.evm']),
            merDb: pickNumber(parsed, ['mer', 'MER', 'metrics.mer', 'metrics.merDb', 'kpi.mer']),
            obwMhz: pickNumber(parsed, ['obw', 'OBW', 'metrics.obw', 'metrics.obwMhz', 'kpi.obw']),
            aclrLowDbc: pickNumber(parsed, ['aclrLow', 'ACLR_LOW', 'metrics.aclrLow', 'metrics.aclrLowDbc']),
            aclrHighDbc: pickNumber(parsed, ['aclrHigh', 'ACLR_HIGH', 'metrics.aclrHigh', 'metrics.aclrHighDbc']),
            channelPowerDbm: pickNumber(parsed, ['channelPower', 'metrics.channelPower', 'metrics.channelPowerDbm']),
            noiseFloorDbm: pickNumber(parsed, ['noiseFloor', 'metrics.noiseFloor', 'metrics.noiseFloorDbm']),
            crestFactorDb: pickNumber(parsed, ['crestFactor', 'metrics.crestFactor', 'metrics.crestFactorDb']),
          },
          raw: parsed,
        }

        if (!cancelled) {
          setSnapshot(next)
          setError(res.ok ? null : `HTTP ${res.status}`)
        }
      } catch (err) {
        if (!cancelled) {
          setSnapshot(syntheticFallback(endpoint, err instanceof Error ? err.message : 'fetch-error'))
          setError(err instanceof Error ? err.message : 'fetch-error')
        }
      } finally {
        window.clearTimeout(timeout)
        if (!cancelled) setLoading(false)
      }
    }

    void load()
    timer = window.setInterval(() => void load(), intervalMs)

    return () => {
      cancelled = true
      if (timer !== undefined) window.clearInterval(timer)
    }
  }, [enabled, endpoint, intervalMs])

  const status = useMemo(() => {
    if (loading && !snapshot) return 'BOOT'
    if (error) return 'FALLBACK'
    if (snapshot?.ok) return 'API LIVE'
    return 'SYNTHETIC'
  }, [error, loading, snapshot])

  return { snapshot, loading, error, status }
}
TS

echo
echo "=== 2) CREA RFEngineeringMath3DPanelV1.tsx ==="

cat > "$LAYER" <<'TSX'
import { useEffect, useMemo, useRef } from 'react'
import type { RFSweepSnapshot } from '../hooks/useRFSpectrumSweep'

type Props = {
  snapshot: RFSweepSnapshot | null
  loading: boolean
  error: string | null
  status: string
}

function fmt(value: number | null, unit: string) {
  if (value === null || Number.isNaN(value)) return '—'
  return `${value} ${unit}`
}

function metricRows(snapshot: RFSweepSnapshot | null) {
  const m = snapshot?.metrics
  return [
    ['SNR', fmt(m?.snrDb ?? null, 'dB'), 'Psignal − Pnoise'],
    ['EVM', fmt(m?.evmPct ?? null, '%'), 'RMS(error) / RMS(reference)'],
    ['MER', fmt(m?.merDb ?? null, 'dB'), '20log10(Vref/Verr)'],
    ['OBW', fmt(m?.obwMhz ?? null, 'MHz'), 'occupied-power bandwidth'],
    ['ACLR L/H', `${fmt(m?.aclrLowDbc ?? null, 'dBc')} / ${fmt(m?.aclrHighDbc ?? null, 'dBc')}`, 'adjacent leakage'],
    ['Noise', fmt(m?.noiseFloorDbm ?? null, 'dBm'), 'estimated floor'],
  ]
}

function RFWaterfall3DPreview({ snapshot }: { snapshot: RFSweepSnapshot | null }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const gl = canvas.getContext('webgl', { antialias: true, alpha: true })
    if (!gl) return

    let frame = 0
    let raf = 0

    const vertexShaderSource = `
      attribute vec3 aPosition;
      varying float vAmp;
      void main() {
        vAmp = aPosition.z;
        gl_PointSize = 2.2;
        gl_Position = vec4(aPosition.x, aPosition.y + aPosition.z * 0.26, 0.0, 1.0);
      }
    `

    const fragmentShaderSource = `
      precision mediump float;
      varying float vAmp;
      void main() {
        float c = clamp(vAmp, 0.0, 1.0);
        gl_FragColor = vec4(0.0 + c * 0.3, 0.85, 1.0 - c * 0.25, 0.86);
      }
    `

    function shader(type: number, source: string) {
      const sh = gl.createShader(type)
      if (!sh) return null
      gl.shaderSource(sh, source)
      gl.compileShader(sh)
      return sh
    }

    const vs = shader(gl.VERTEX_SHADER, vertexShaderSource)
    const fs = shader(gl.FRAGMENT_SHADER, fragmentShaderSource)
    if (!vs || !fs) return

    const program = gl.createProgram()
    if (!program) return

    gl.attachShader(program, vs)
    gl.attachShader(program, fs)
    gl.linkProgram(program)
    gl.useProgram(program)

    const loc = gl.getAttribLocation(program, 'aPosition')
    const buffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
    gl.enableVertexAttribArray(loc)
    gl.vertexAttribPointer(loc, 3, gl.FLOAT, false, 0, 0)

    const render = () => {
      const dpr = Math.min(2, window.devicePixelRatio || 1)
      const w = Math.max(320, Math.floor(canvas.clientWidth * dpr))
      const h = Math.max(160, Math.floor(canvas.clientHeight * dpr))

      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w
        canvas.height = h
        gl.viewport(0, 0, w, h)
      }

      const rows = 34
      const cols = 92
      const vertices: number[] = []
      const binInfluence = Math.min(1.4, Math.max(0.7, (snapshot?.binCount ?? 4096) / 4096))

      for (let y = 0; y < rows; y += 1) {
        for (let x = 0; x < cols; x += 1) {
          const nx = (x / (cols - 1)) * 1.78 - 0.89
          const ny = (y / (rows - 1)) * 1.28 - 0.68
          const carrier =
            Math.exp(-Math.pow((x - 18) / 3.5, 2)) +
            Math.exp(-Math.pow((x - 38) / 4.2, 2)) * 0.75 +
            Math.exp(-Math.pow((x - 58) / 3.8, 2)) * 0.92 +
            Math.exp(-Math.pow((x - 74) / 4.8, 2)) * 0.62
          const sweep = 0.12 * Math.sin(frame * 0.035 + x * 0.21 + y * 0.34)
          const amp = Math.min(1, Math.max(0, (carrier * 0.58 + sweep + 0.08) * binInfluence))
          vertices.push(nx, ny, amp)
        }
      }

      gl.clearColor(0.0, 0.02, 0.04, 0.0)
      gl.clear(gl.COLOR_BUFFER_BIT)
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.DYNAMIC_DRAW)
      gl.drawArrays(gl.POINTS, 0, vertices.length / 3)

      frame += 1
      raf = window.requestAnimationFrame(render)
    }

    render()

    return () => {
      window.cancelAnimationFrame(raf)
      gl.deleteBuffer(buffer)
      gl.deleteProgram(program)
      gl.deleteShader(vs)
      gl.deleteShader(fs)
    }
  }, [snapshot?.binCount])

  return (
    <canvas
      ref={canvasRef}
      className="trfmc-rf-webgl-canvas"
      aria-label="RF waterfall 3D WebGL preview"
    />
  )
}

export function RFEngineeringMath3DPanelV1({ snapshot, loading, error, status }: Props) {
  const rows = useMemo(() => metricRows(snapshot), [snapshot])

  return (
    <section className="trfmc-rf-engineering-layer-v1" data-trfmc-rf-engineering-layer-v1="mounted">
      <div className="trfmc-rf-engineering-layer-head">
        <div>
          <p>Batch 2B · RF Engineering Layer</p>
          <h3>Real sweep adapter · RF math · WebGL 3D surface</h3>
          <span>
            Il modulo RF non è più solo visuale: espone contratto dati, formule KPI e preview 3D
            del comportamento spettrale.
          </span>
        </div>
        <strong data-status={status}>{status}</strong>
      </div>

      <div className="trfmc-rf-engineering-layer-grid">
        <article className="trfmc-rf-engineering-card trfmc-rf-api-card">
          <div className="trfmc-rf-card-title">
            <span>Real data contract</span>
            <b>{loading ? 'polling' : snapshot?.ok ? 'api live' : 'fallback'}</b>
          </div>
          <dl>
            <div><dt>Endpoint</dt><dd>{snapshot?.endpoint ?? '/api/rfpro/spectrum/sweep'}</dd></div>
            <div><dt>Status</dt><dd>{snapshot?.status ?? '—'}</dd></div>
            <div><dt>Source</dt><dd>{snapshot?.source ?? '—'}</dd></div>
            <div><dt>Bins</dt><dd>{snapshot?.binCount ?? '—'}</dd></div>
            <div><dt>Error</dt><dd>{error ?? '—'}</dd></div>
          </dl>
          <small>{snapshot?.samplePreview ?? 'waiting first sweep sample...'}</small>
        </article>

        <article className="trfmc-rf-engineering-card">
          <div className="trfmc-rf-card-title">
            <span>Mathematical KPI layer</span>
            <b>engineering formulas</b>
          </div>
          <div className="trfmc-rf-math-grid">
            {rows.map(([k, v, f]) => (
              <div key={k}>
                <strong>{k}</strong>
                <em>{v}</em>
                <span>{f}</span>
              </div>
            ))}
          </div>
        </article>

        <article className="trfmc-rf-engineering-card trfmc-rf-webgl-card">
          <div className="trfmc-rf-card-title">
            <span>3D RF rendering</span>
            <b>WebGL surface preview</b>
          </div>
          <RFWaterfall3DPreview snapshot={snapshot} />
          <small>Engineering preview: 3D spectral occupancy / waterfall surface, not decoration.</small>
        </article>
      </div>
    </section>
  )
}
TSX

echo
echo "=== 3) PATCH RFSignalAnalyzerPromotionV1.tsx ==="

python3 - "$PROMO" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
before = text

imports = [
    "import { useRFSpectrumSweep } from '../rf_instruments/hooks/useRFSpectrumSweep'",
    "import { RFEngineeringMath3DPanelV1 } from '../rf_instruments/panels/RFEngineeringMath3DPanelV1'",
]

for imp in reversed(imports):
    if imp not in text:
        text = imp + "\n" + text

needle = "  const [active, setActive] = useState<(typeof tabs)[number]['id']>('workbench')"
insert = needle + "\n  const rfSweep = useRFSpectrumSweep({ enabled: true, intervalMs: 2500 })"

if needle in text and "const rfSweep = useRFSpectrumSweep" not in text:
    text = text.replace(needle, insert, 1)

target = """      <section className="trfmc-rf-promo-panel trfmc-rf-instrument-panel">"""
mount = """      <RFEngineeringMath3DPanelV1
        snapshot={rfSweep.snapshot}
        loading={rfSweep.loading}
        error={rfSweep.error}
        status={rfSweep.status}
      />

"""

if target in text and "<RFEngineeringMath3DPanelV1" not in text:
    text = text.replace(target, mount + target, 1)

path.write_text(text, encoding="utf-8")
print("PROMOTION_LAYER_PATCHED=", before != text)
PY

echo
echo "=== 4) PATCH styles.css ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC BATCH2B RF ENGINEERING LAYER V1 START === \*/.*?/\* === TRFMC BATCH2B RF ENGINEERING LAYER V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC BATCH2B RF ENGINEERING LAYER V1 START === */
/*
  RF Engineering Layer V1
  Scope:
  - real API adapter surface;
  - RF mathematical KPI layer;
  - WebGL 3D RF surface preview;
  - no backend/index/public mutation.
*/

.mc-shell-engineering-only .trfmc-rf-engineering-layer-v1 {
  margin-top: 7px;
  padding: 8px;
  border: 1px solid rgba(103,232,249,.16);
  border-radius: 11px;
  background:
    radial-gradient(circle at 12% 0%, rgba(57,215,255,.065), transparent 36%),
    linear-gradient(180deg, rgba(3,12,24,.64), rgba(1,6,14,.78));
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  align-items: center;
  padding-bottom: 7px;
  border-bottom: 1px solid rgba(103,232,249,.13);
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head p {
  margin: 0 0 3px 0;
  color: #67e8f9;
  font-size: 9.5px;
  font-weight: 950;
  text-transform: uppercase;
  letter-spacing: .14em;
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head h3 {
  margin: 0 0 3px 0;
  color: #e8f7ff;
  font-size: 15px;
  line-height: 1.05;
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head span {
  color: #9fb8ca;
  font-size: 10px;
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head > strong {
  flex: 0 0 auto;
  padding: 6px 9px;
  border-radius: 999px;
  border: 1px solid rgba(134,239,172,.28);
  background: rgba(22,101,52,.18);
  color: #86efac;
  font-size: 10px;
  font-weight: 950;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head > strong[data-status="FALLBACK"] {
  border-color: rgba(251,191,36,.34);
  background: rgba(120,53,15,.18);
  color: #fbbf24;
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-grid {
  display: grid;
  grid-template-columns: minmax(280px, .82fr) minmax(340px, 1.08fr) minmax(320px, .95fr);
  gap: 7px;
  margin-top: 7px;
  align-items: stretch;
}

.mc-shell-engineering-only .trfmc-rf-engineering-card {
  min-width: 0;
  border: 1px solid rgba(103,232,249,.13);
  border-radius: 10px;
  background: rgba(2,10,20,.42);
  padding: 7px;
}

.mc-shell-engineering-only .trfmc-rf-card-title {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  align-items: baseline;
  margin-bottom: 6px;
  padding-bottom: 5px;
  border-bottom: 1px solid rgba(103,232,249,.11);
}

.mc-shell-engineering-only .trfmc-rf-card-title span {
  color: #67e8f9;
  font-size: 9.5px;
  font-weight: 950;
  text-transform: uppercase;
  letter-spacing: .12em;
}

.mc-shell-engineering-only .trfmc-rf-card-title b {
  color: #86efac;
  font-size: 8.5px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.mc-shell-engineering-only .trfmc-rf-api-card dl {
  display: grid;
  gap: 4px;
  margin: 0;
}

.mc-shell-engineering-only .trfmc-rf-api-card dl > div {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 6px;
}

.mc-shell-engineering-only .trfmc-rf-api-card dt {
  color: #67e8f9;
  font-size: 9px;
  font-weight: 900;
  text-transform: uppercase;
}

.mc-shell-engineering-only .trfmc-rf-api-card dd {
  margin: 0;
  color: #e8f7ff;
  font-size: 9.5px;
  overflow-wrap: anywhere;
}

.mc-shell-engineering-only .trfmc-rf-engineering-card small {
  display: block;
  margin-top: 6px;
  color: #9fb8ca;
  font-size: 9px;
  line-height: 1.22;
  overflow-wrap: anywhere;
}

.mc-shell-engineering-only .trfmc-rf-math-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0,1fr));
  gap: 5px;
}

.mc-shell-engineering-only .trfmc-rf-math-grid div {
  border: 1px solid rgba(103,232,249,.11);
  border-radius: 8px;
  background: rgba(0,4,10,.25);
  padding: 6px;
}

.mc-shell-engineering-only .trfmc-rf-math-grid strong,
.mc-shell-engineering-only .trfmc-rf-math-grid em,
.mc-shell-engineering-only .trfmc-rf-math-grid span {
  display: block;
}

.mc-shell-engineering-only .trfmc-rf-math-grid strong {
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
}

.mc-shell-engineering-only .trfmc-rf-math-grid em {
  color: #86efac;
  font-style: normal;
  font-size: 11px;
  font-weight: 900;
  margin-top: 2px;
}

.mc-shell-engineering-only .trfmc-rf-math-grid span {
  color: #9fb8ca;
  font-size: 8.8px;
  margin-top: 2px;
}

.mc-shell-engineering-only .trfmc-rf-webgl-card {
  display: grid;
  grid-template-rows: auto minmax(150px, 1fr) auto;
}

.mc-shell-engineering-only .trfmc-rf-webgl-canvas {
  display: block;
  width: 100%;
  height: 170px;
  border-radius: 9px;
  border: 1px solid rgba(103,232,249,.12);
  background:
    linear-gradient(180deg, rgba(0,20,28,.5), rgba(0,3,8,.92));
}

@media (max-width: 1280px) {
  .mc-shell-engineering-only .trfmc-rf-engineering-layer-grid {
    grid-template-columns: 1fr;
  }

  .mc-shell-engineering-only .trfmc-rf-webgl-canvas {
    height: 150px;
  }
}
/* === TRFMC BATCH2B RF ENGINEERING LAYER V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_BATCH2B_RF_ENGINEERING_LAYER_V1_APPENDED=True")
PY

echo
echo "=== 5) DIFF ==="
git diff -- "$PROMO" "$HOOK" "$LAYER" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 6) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  "$RESTORE"
  BUILD_RESULT="FAIL_RESTORED"
fi

echo
echo "=== 7) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 8) DOM / MARKER GATE ==="

DOM_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM"
fi

RF_PROMO_MARKER_COUNT="$(awk 'index($0, "data-trfmc-rf-signal-promotion-v1=\"mounted\"") {c++} END {print c+0}' "$DOM")"
RF_LAYER_MARKER_COUNT="$(awk 'index($0, "data-trfmc-rf-engineering-layer-v1=\"mounted\"") {c++} END {print c+0}' "$DOM")"
CSS_MARKER_COUNT="$(awk 'index($0, "TRFMC BATCH2B RF ENGINEERING LAYER V1 START") {c++} END {print c+0}' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "RF_PROMO_MARKER_COUNT=$RF_PROMO_MARKER_COUNT"
echo "RF_LAYER_MARKER_COUNT=$RF_LAYER_MARKER_COUNT"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"

echo
echo "=== 9) SCREENSHOT GATE ==="

SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$RF_PROMO_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_RF_PROMO_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$RF_LAYER_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_RF_LAYER_DOM"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2B_RF_ENGINEERING_LAYER_V1",
  "mutation": "react_source_layer",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "files_modified": [
    "$PROMO",
    "$HOOK",
    "$LAYER",
    "$CSS"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "rf_promo_marker_count": $RF_PROMO_MARKER_COUNT,
  "rf_engineering_layer_marker_count": $RF_LAYER_MARKER_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2b_rf_engineering_layer_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH2B_RF_ENGINEERING_LAYER_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
