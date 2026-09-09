/**
 * CANDIDATE-ONLY — NOT ROUTED TO PRODUCTION
 *
 * SignalAnalyzerV2_Candidate.tsx  (P2B-A Rev.1.1)
 *
 * Standalone React component.  Connects to /api/iq/ws via a Dedicated Worker,
 * receives Transferable ArrayBuffer output, and draws a live spectrum on a
 * local canvas at no more than 60 fps via requestAnimationFrame.
 *
 * Not imported by main.tsx or any router.
 * Does not modify any existing operational component.
 * Does not use useRtStreamStore as data source.
 * React is NOT in the hot path of I/Q samples.
 * No SharedArrayBuffer.  No OffscreenCanvas.  No global CSS touched.
 */

import { useCallback, useEffect, useRef, useState } from "react"
import type {
  DspMetrics,
  WorkerInbound,
  WorkerOutbound,
} from "../workers/iqJsonWsDspWorkerV2.candidate"

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_WS_URL    = "ws://localhost:8000/api/iq/ws"
const METRICS_UPDATE_MS = 500   // throttle React state updates to 2 fps

// ---------------------------------------------------------------------------
// Canvas drawing — module-level, no React deps
// ---------------------------------------------------------------------------

function drawSpectrum(canvas: HTMLCanvasElement, primary: Float32Array): void {
  const dpr = Math.min(2, window.devicePixelRatio || 1)
  const w   = Math.floor(canvas.clientWidth  * dpr)
  const h   = Math.floor(canvas.clientHeight * dpr)
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width  = w
    canvas.height = h
  }
  const ctx = canvas.getContext("2d")
  if (!ctx) return

  ctx.clearRect(0, 0, w, h)

  const bg = ctx.createLinearGradient(0, 0, 0, h)
  bg.addColorStop(0, "#020d18")
  bg.addColorStop(1, "#000205")
  ctx.fillStyle = bg
  ctx.fillRect(0, 0, w, h)

  // Grid
  ctx.strokeStyle = "rgba(0,229,255,.10)"
  ctx.lineWidth   = 1
  for (let gx = 0; gx <= 10; gx++) {
    const x = (w * gx) / 10
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke()
  }
  for (let gy = 0; gy <= 6; gy++) {
    const y = (h * gy) / 6
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
  }

  // Spectrum trace
  const len = primary.length
  if (len === 0) return
  ctx.strokeStyle = "#00e5ff"
  ctx.lineWidth   = 1.5 * dpr
  ctx.beginPath()
  for (let i = 0; i < len; i++) {
    const x = (w * i) / (len - 1)
    const y = h * (0.9 - primary[i] * 0.78)
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
  }
  ctx.stroke()

  // Watermark
  ctx.fillStyle = "rgba(0,229,255,.55)"
  ctx.font      = `${10 * dpr}px ui-monospace, Consolas, monospace`
  ctx.fillText(
    "SA V2 CANDIDATE · JSON legacy P1 · Worker-first DSP · Transferable ArrayBuffer",
    12 * dpr, 16 * dpr,
  )
}

// ---------------------------------------------------------------------------
// Sub-component
// ---------------------------------------------------------------------------

function MetricRow({ label, value }: { readonly label: string; readonly value: string }) {
  return (
    <div style={styles.metricRow}>
      <span style={styles.metricLabel}>{label}</span>
      <span style={styles.metricValue}>{value}</span>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function SignalAnalyzerV2_Candidate() {
  const [workerStatus,   setWorkerStatus]   = useState("INIT")
  const [wsStatus,       setWsStatus]       = useState("DISCONNECTED")
  const [displayMetrics, setDisplayMetrics] = useState<DspMetrics | null>(null)

  const primaryRef    = useRef<Float32Array | null>(null)
  const iqPreviewRef  = useRef<Float32Array | null>(null)
  const canvasRef     = useRef<HTMLCanvasElement | null>(null)
  const rafIdRef      = useRef<number | null>(null)   // null-safe cancel
  const lastMetricsMs = useRef<number>(0)
  const workerRef     = useRef<Worker | null>(null)   // P2B-A: button handlers

  // Candidate-only controls — access workerRef, never trigger React re-render
  const handleReconnect = useCallback((): void => {
    workerRef.current?.postMessage(
      { type: "connect", wsUrl: DEFAULT_WS_URL } satisfies WorkerInbound,
    )
  }, [])

  const handleDisconnect = useCallback((): void => {
    workerRef.current?.postMessage(
      { type: "disconnect" } satisfies WorkerInbound,
    )
  }, [])

  // Stable draw callback — reads refs only, triggers no React re-render
  const draw = useCallback((): void => {
    const canvas  = canvasRef.current
    const primary = primaryRef.current
    if (!canvas || !primary) return
    drawSpectrum(canvas, primary)
  }, [])

  // RAF render loop
  useEffect((): (() => void) => {
    const loop = (): void => {
      draw()
      rafIdRef.current = requestAnimationFrame(loop)
    }
    rafIdRef.current = requestAnimationFrame(loop)
    return (): void => {
      if (rafIdRef.current !== null) {
        cancelAnimationFrame(rafIdRef.current)
        rafIdRef.current = null
      }
    }
  }, [draw])

  // Worker lifecycle
  useEffect((): (() => void) => {
    const worker = new Worker(
      new URL("../workers/iqJsonWsDspWorkerV2.candidate.ts", import.meta.url),
      { type: "module" },
    )
    workerRef.current = worker

    worker.onmessage = (ev: MessageEvent<WorkerOutbound>): void => {
      const msg = ev.data
      switch (msg.type) {
        case "worker_ready":
          setWorkerStatus("READY")
          worker.postMessage(
            { type: "connect", wsUrl: DEFAULT_WS_URL } satisfies WorkerInbound,
          )
          break
        case "ws_open":
          setWsStatus("CONNECTED")
          break
        case "ws_closed":
          setWsStatus(`CLOSED (${msg.code})`)
          break
        case "ws_reconnecting":
          setWsStatus(
            `RECONNECTING... attempt ${msg.attempt} · ${msg.delayMs} ms`,
          )
          break
        case "worker_error":
          setWorkerStatus(`ERROR: ${msg.message}`)
          break
        case "dsp_frame":
          // Hot path — refs only, zero React re-renders here
          primaryRef.current   = msg.primary
          iqPreviewRef.current = msg.iqPreview
          // Throttled UI metric update at 2 fps
          {
            const now = performance.now()
            if (now - lastMetricsMs.current >= METRICS_UPDATE_MS) {
              lastMetricsMs.current = now
              setDisplayMetrics(msg.metrics)
            }
          }
          break
      }
    }

    worker.onerror = (ev: ErrorEvent): void => {
      setWorkerStatus(`WORKER ERROR: ${ev.message}`)
    }

    return (): void => {
      worker.postMessage({ type: "disconnect" } satisfies WorkerInbound)
      worker.terminate()
      workerRef.current = null
    }
  }, [])

  return (
    <div style={styles.root}>
      <div style={styles.header}>
        <span style={styles.title}>TRFMC Signal Analyzer V2 Candidate</span>
        <span style={styles.badge}>CANDIDATE-ONLY / NOT ROUTED</span>
      </div>

      <div style={styles.statusBar}>
        <span>Worker: <b>{workerStatus}</b></span>
        <span>WS: <b>{wsStatus}</b></span>
        <span style={styles.note}>JSON legacy P1 &middot; Worker-first DSP &middot; Transferable output</span>
      </div>

      {/* Candidate-only control buttons — P2B-A */}
      <div style={styles.controls}>
        {wsStatus !== "CONNECTED" && (
          <button style={styles.btnReconnect} onClick={handleReconnect}>
            Reconnect
          </button>
        )}
        <button style={styles.btnDisconnect} onClick={handleDisconnect}>
          Disconnect
        </button>
      </div>

      <div style={styles.canvasWrap}>
        {displayMetrics === null && (
          <div style={styles.idle}>Candidate DSP Worker Idle</div>
        )}
        <canvas
          ref={canvasRef}
          style={styles.canvas}
          aria-label="TRFMC Signal Analyzer V2 Candidate spectrum"
        />
      </div>

      {displayMetrics !== null && (
        <div style={styles.metrics}>
          <MetricRow label="Seq"          value={String(displayMetrics.seq)} />
          <MetricRow label="Sample rate"  value={`${displayMetrics.sampleRate.toLocaleString("en")} Hz`} />
          <MetricRow label="Frame size"   value={String(displayMetrics.frameSize)} />
          <MetricRow label="FPS in"       value={String(displayMetrics.fpsIn)} />
          <MetricRow label="FPS out"      value={String(displayMetrics.fpsOut)} />
          <MetricRow label="Dropped"      value={String(displayMetrics.droppedFrames)} />
          <MetricRow label="Parse errors" value={String(displayMetrics.parseErrors)} />
          <MetricRow label="Schema errs"  value={String(displayMetrics.schemaErrors)} />
          <MetricRow
            label="Worker latency"
            value={`${displayMetrics.workerLatencyMs.toFixed(2)} ms`}
          />
          <MetricRow
            label="Queue wait"
            value={`${displayMetrics.queueWaitMs.toFixed(2)} ms`}
          />
          <MetricRow
            label="DSP latency"
            value={`${displayMetrics.dspLatencyMs.toFixed(2)} ms`}
          />
          {displayMetrics.sourceClockDeltaMs !== null && (
            <MetricRow
              label="Source clock delta"
              value={`${displayMetrics.sourceClockDeltaMs.toFixed(0)} ms`}
            />
          )}
          <MetricRow label="Queue depth"   value={String(displayMetrics.queueDepth)} />
          <MetricRow label="Queue dropped" value={String(displayMetrics.queueDroppedFrames)} />
          <MetricRow label="Total queued"  value={String(displayMetrics.queuedFrames)} />
          <MetricRow
            label="Reconnects"
            value={String(displayMetrics.totalReconnectAttempts)}
          />
          <MetricRow
            label="Last delay"
            value={displayMetrics.lastReconnectDelayMs > 0
              ? `${displayMetrics.lastReconnectDelayMs} ms`
              : "—"}
          />
          <MetricRow
            label="IQ preview"
            value={iqPreviewRef.current !== null
              ? `${iqPreviewRef.current.length / 2} pairs`
              : "—"}
          />
        </div>
      )}

      <div style={styles.archNote}>
        P2B-A candidate &middot; JSON legacy P1 path &middot; Worker-first DSP &middot;
        Transferable output &middot; Async ring buffer &middot; Epoch-guarded reconnect &middot;
        OffscreenCanvas not active &middot; SharedArrayBuffer not used
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Inline styles — self-contained, no global CSS touched
// ---------------------------------------------------------------------------

const styles = {
  root:         { fontFamily: "ui-monospace, Consolas, monospace", background: "#020b14",
                  color: "#b0d8e8", border: "1px solid #0d3d5c", borderRadius: 4,
                  padding: 12, maxWidth: 900, userSelect: "none" as const },
  header:       { display: "flex", alignItems: "center", gap: 12, marginBottom: 8 },
  title:        { fontSize: 13, fontWeight: 700, color: "#00e5ff", letterSpacing: "0.05em" },
  badge:        { fontSize: 10, fontWeight: 700, color: "#ff6b35",
                  background: "rgba(255,107,53,.12)", border: "1px solid rgba(255,107,53,.35)",
                  borderRadius: 3, padding: "2px 6px", letterSpacing: "0.06em" },
  statusBar:    { display: "flex", gap: 16, fontSize: 11, marginBottom: 8, color: "#7aadcc" },
  note:         { marginLeft: "auto", color: "#3a6a8a", fontSize: 10 },
  controls:     { display: "flex", gap: 8, marginBottom: 8, flexWrap: "wrap" as const },
  btnReconnect: {
    fontSize: 11, fontFamily: "ui-monospace, Consolas, monospace",
    background: "rgba(0,229,255,.10)", color: "#00e5ff",
    border: "1px solid rgba(0,229,255,.28)", borderRadius: 3,
    padding: "4px 12px", cursor: "pointer",
  },
  btnDisconnect: {
    fontSize: 11, fontFamily: "ui-monospace, Consolas, monospace",
    background: "rgba(255,107,53,.08)", color: "#ff6b35",
    border: "1px solid rgba(255,107,53,.22)", borderRadius: 3,
    padding: "4px 12px", cursor: "pointer",
  },
  canvasWrap:   { position: "relative" as const, width: "100%", height: 220,
                  background: "#010810", borderRadius: 3, overflow: "hidden", marginBottom: 8 },
  idle:         { position: "absolute" as const, inset: 0, display: "flex",
                  alignItems: "center", justifyContent: "center",
                  color: "#2a5a7a", fontSize: 12, letterSpacing: "0.1em",
                  pointerEvents: "none" as const },
  canvas:       { display: "block", width: "100%", height: "100%" },
  metrics:      { display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(155px, 1fr))",
                  gap: 4, marginBottom: 8 },
  metricRow:    { display: "flex", flexDirection: "column" as const,
                  background: "rgba(0,229,255,.04)", border: "1px solid rgba(0,229,255,.10)",
                  borderRadius: 3, padding: "4px 8px" },
  metricLabel:  { fontSize: 9, color: "#4a8aaa", textTransform: "uppercase" as const,
                  letterSpacing: "0.08em" },
  metricValue:  { fontSize: 12, color: "#c0e8f8", fontWeight: 600 },
  archNote:     { fontSize: 9, color: "#2a4a5a", letterSpacing: "0.05em", marginTop: 4 },
} as const
