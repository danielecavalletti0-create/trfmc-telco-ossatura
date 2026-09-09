import { useEffect, useMemo, useRef } from 'react'
import type { NormalizedRFSweep } from '../hooks/useRFSpectrumSweep'

type Props = {
  snapshot: NormalizedRFSweep | null
  loading: boolean
  error: string | null
  status: string
}

function fmt(value: number | null, unit: string) {
  if (value === null || Number.isNaN(value)) return '—'
  return `${value} ${unit}`
}

function metricRows(snapshot: NormalizedRFSweep | null) {
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

function RFWaterfall3DPreview({ snapshot }: { snapshot: NormalizedRFSweep | null }) {
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
            Il modulo RF non è più solo visuale: espone contratto dati reale, normalizzazione KPI e preview 3D
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
            <div><dt>Source</dt><dd>{snapshot?.source ?? '—'} · {snapshot?.contentType || '—'}</dd></div>
            <div><dt>Bins</dt><dd>{snapshot?.binCount ?? '—'} · preview {snapshot?.tracePreview?.length ?? 0}</dd></div>
            <div><dt>Error</dt><dd>{error ?? 'none'}</dd></div>
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
