/**
 * CANDIDATE-ONLY — NOT ROUTED TO PRODUCTION
 *
 * iqJsonWsDspWorkerV2.candidate.ts  (P2B-A Rev.1.1)
 *
 * Dedicated Module Worker.  Opens /api/iq/ws directly, validates the JSON
 * legacy P1 schema, converts payload.i / payload.q number arrays to
 * Float32Array, applies a Hann window, runs an in-place Radix-2 FFT, and
 * posts Transferable ArrayBuffer output to the main thread at no more than
 * 60 fps.
 *
 * P2B-A additions over P2A:
 * - Async ring buffer (capacity 4, drop-oldest): onmessage only enqueues;
 *   drainLoop() runs asynchronously via setTimeout, paced at 60 fps.
 * - connectionEpoch guards all socket handlers against stale events.
 * - Exponential-backoff reconnect (1 s base, 30 s max, x2); epoch-checked.
 * - Manual disconnect disables auto-reconnect until next explicit connect.
 * - Latency breakdown: workerLatencyMs, queueWaitMs, dspLatencyMs.
 * - sourceClockDeltaMs: diagnostic only (server monotonic != client clock).
 * - Separate counters: currentReconnectAttempt (backoff) vs
 *   totalReconnectAttempts (cumulative, never reset).
 *
 * No SharedArrayBuffer.  No OffscreenCanvas.  No React.
 * No useRtStreamStore.  No unsafe type suppressions.
 */

// ---------------------------------------------------------------------------
// Exported types — imported via `import type` by SignalAnalyzerV2_Candidate
// ---------------------------------------------------------------------------

export interface DspMetrics {
  readonly seq: number
  readonly sampleRate: number
  readonly frameSize: number
  readonly fpsIn: number
  readonly fpsOut: number
  readonly droppedFrames: number
  readonly parseErrors: number
  readonly schemaErrors: number
  // Latency breakdown — P2B-A (all values from client performance.now(); no
  // cross-domain clock ambiguity)
  readonly workerLatencyMs: number        // receiveMs to outputMs (queue wait + DSP)
  readonly queueWaitMs: number            // receiveMs to dspStartMs (time in queue)
  readonly dspLatencyMs: number           // dspStartMs to outputMs (FFT + output)
  /**
   * Diagnostic delta: outputMs minus payload.time times 1000.
   * payload.time is server-side monotonic (seconds since boot) and is NOT
   * comparable with client performance.now().  The absolute value is NOT a
   * network RTT.  Useful only for detecting relative drift across frames.
   * null when payload.time is absent or non-positive.
   */
  readonly sourceClockDeltaMs: number | null
  // Queue metrics — P2B-A
  readonly queueDepth: number
  readonly queueDroppedFrames: number
  readonly queuedFrames: number
  // Reconnect metrics — P2B-A
  readonly totalReconnectAttempts: number
  readonly lastReconnectDelayMs: number
}

export type WorkerInbound =
  | { readonly type: "connect";    readonly wsUrl: string }
  | { readonly type: "disconnect" }

export type WorkerOutbound =
  | { readonly type: "worker_ready" }
  | { readonly type: "ws_open" }
  | { readonly type: "ws_closed";       readonly code: number; readonly reason: string }
  | { readonly type: "ws_reconnecting"; readonly delayMs: number; readonly attempt: number }
  | { readonly type: "worker_error";    readonly message: string }
  | {
      readonly type: "dsp_frame"
      readonly seq: number
      readonly sampleRate: number
      readonly frameSize: number
      readonly primary: Float32Array
      readonly iqPreview: Float32Array
      readonly metrics: DspMetrics
    }

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

interface LegacyIQPayload {
  readonly seq: number
  readonly time: number
  readonly sample_rate: number
  readonly frame_size: number
  readonly i: number[]
  readonly q: number[]
}

interface LegacyIQFrame {
  readonly type: "iq_frame"
  readonly payload: LegacyIQPayload
}

// receiveMs is captured at onmessage time so that queue-wait latency remains
// measurable after the async drain delay.
interface QueuedFrame {
  readonly frame:     LegacyIQFrame
  readonly receiveMs: number
}

// Local interface — avoids dependency on the WebWorker lib not listed in tsconfig.
interface WorkerPostScope {
  postMessage(message: WorkerOutbound, transfer?: Transferable[]): void
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const OUTPUT_INTERVAL_MS = 1000 / 60   // ~16.67 ms — caps output at 60 fps
const FPS_WINDOW_MS      = 1000        // 1-second sliding FPS counter window
const QUEUE_CAPACITY     = 4           // ring buffer max depth (drop-oldest on overflow)
const BACKOFF_BASE_MS    = 1000        // initial reconnect delay (ms)
const BACKOFF_MAX_MS     = 30_000      // maximum reconnect delay (ms)
const BACKOFF_MULTIPLIER = 2.0         // exponential factor per attempt

// ---------------------------------------------------------------------------
// postMessage helper
// ---------------------------------------------------------------------------

const workerScope = self as unknown as WorkerPostScope

function post(msg: WorkerOutbound, transfer?: Transferable[]): void {
  if (transfer !== undefined) {
    workerScope.postMessage(msg, transfer)
  } else {
    workerScope.postMessage(msg)
  }
}

// ---------------------------------------------------------------------------
// DSP utilities
// ---------------------------------------------------------------------------

function hannWindow(n: number): Float32Array {
  const w     = new Float32Array(n)
  const scale = (2.0 * Math.PI) / (n - 1)
  for (let k = 0; k < n; k++) {
    w[k] = 0.5 * (1.0 - Math.cos(scale * k))
  }
  return w
}

/** Largest power of 2 that is <= n.  Returns 1 for n < 1. */
function floorPow2(n: number): number {
  if (n < 1) return 1
  let p = 1
  while (p * 2 <= n) p *= 2
  return p
}

/**
 * In-place Radix-2 Cooley-Tukey FFT.
 * real and imag must have the same power-of-2 length.
 */
function fftInPlace(real: Float32Array, imag: Float32Array): void {
  const n = real.length
  // Bit-reversal permutation
  let j = 0
  for (let i = 1; i < n; i++) {
    let bit = n >> 1
    while (j & bit) { j ^= bit; bit >>= 1 }
    j ^= bit
    if (i < j) {
      let t = real[i]; real[i] = real[j]; real[j] = t
      t = imag[i]; imag[i] = imag[j]; imag[j] = t
    }
  }
  // Butterfly stages
  for (let len = 2; len <= n; len <<= 1) {
    const half    = len >> 1
    const angle   = (-2.0 * Math.PI) / len
    const wBaseRe = Math.cos(angle)
    const wBaseIm = Math.sin(angle)
    for (let k = 0; k < n; k += len) {
      let wRe = 1.0
      let wIm = 0.0
      for (let m = 0; m < half; m++) {
        const uRe = real[k + m]
        const uIm = imag[k + m]
        const vRe = real[k + m + half] * wRe - imag[k + m + half] * wIm
        const vIm = real[k + m + half] * wIm + imag[k + m + half] * wRe
        real[k + m]        = uRe + vRe
        imag[k + m]        = uIm + vIm
        real[k + m + half] = uRe - vRe
        imag[k + m + half] = uIm - vIm
        const nextRe = wRe * wBaseRe - wIm * wBaseIm
        wIm          = wRe * wBaseIm + wIm * wBaseRe
        wRe          = nextRe
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Runtime state
// ---------------------------------------------------------------------------

let socket:       WebSocket | null = null
let currentWsUrl: string | null    = null    // stored for auto-reconnect
let manualDisconnect               = false   // true = user explicitly disconnected
/**
 * Incremented on every openSocket() and closeSocket().
 * Captured as a const by each set of socket handlers so that events arriving
 * from a superseded socket are silently ignored.
 */
let connectionEpoch = 0

// WS error counters
let droppedFrames = 0
let parseErrors   = 0
let schemaErrors  = 0
let lastOutputMs  = 0

// Async ring buffer — P2B-A
// Drop-oldest policy: on overflow the head (oldest frame) is evicted so that
// the drain loop always works on the most recently received data.
const frameQueue:      QueuedFrame[] = []
let queuedFrames       = 0    // cumulative frames accepted into queue (ever)
let queueDepth         = 0    // mirrors frameQueue.length for metrics
let queueDroppedFrames = 0    // frames evicted on overflow (not throttle-dropped)
let drainScheduled     = false  // true while a setTimeout(drainLoop) is pending

// Reconnect state — P2B-A
let currentReconnectAttempt  = 0    // used for backoff; reset to 0 on ws_open
let totalReconnectAttempts   = 0    // cumulative; never reset
let lastReconnectDelayMs     = 0
let reconnectTimerId: ReturnType<typeof setTimeout> | null = null

// 1-second sliding FPS counters
let fpsWindowStart = 0
let fpsInAccum     = 0
let fpsOutAccum    = 0
let currentFpsIn   = 0
let currentFpsOut  = 0

function tickFps(now: number): void {
  if (fpsWindowStart === 0) { fpsWindowStart = now; return }
  if (now - fpsWindowStart >= FPS_WINDOW_MS) {
    currentFpsIn   = fpsInAccum
    currentFpsOut  = fpsOutAccum
    fpsInAccum     = 0
    fpsOutAccum    = 0
    fpsWindowStart = now
  }
}

// ---------------------------------------------------------------------------
// Schema guard
// ---------------------------------------------------------------------------

function isLegacyIQFrame(raw: unknown): raw is LegacyIQFrame {
  if (typeof raw !== "object" || raw === null) return false
  const top = raw as Record<string, unknown>
  if (top["type"] !== "iq_frame") return false
  const p = top["payload"]
  if (typeof p !== "object" || p === null) return false
  const pl = p as Record<string, unknown>
  return (
    typeof pl["seq"]         === "number" &&
    typeof pl["time"]        === "number" &&
    typeof pl["sample_rate"] === "number" &&
    typeof pl["frame_size"]  === "number" &&
    Array.isArray(pl["i"]) &&
    Array.isArray(pl["q"])
  )
}

// ---------------------------------------------------------------------------
// Frame processing
// ---------------------------------------------------------------------------

// processFrame no longer manages the 60-fps throttle — that is delegated to
// drainLoop, which calls processFrame only when the output slot is ready.
function processFrame(
  frame:      LegacyIQFrame,
  receiveMs:  number,    // performance.now() captured at onmessage
  dspStartMs: number,    // performance.now() captured in drainLoop before DSP
): void {
  fpsInAccum++
  tickFps(dspStartMs)

  const { seq, sample_rate, frame_size, i, q } = frame.payload

  // droppedFrames counts only payload/FFT faults, not throttle or queue overflow.
  if (i.length !== q.length) { droppedFrames++; return }

  const actualLen = Math.min(frame_size, i.length, q.length)
  const fftN      = floorPow2(actualLen)
  if (fftN < 2) { droppedFrames++; return }

  // Windowed complex input
  const hann = hannWindow(fftN)
  const real  = new Float32Array(fftN)
  const imag  = new Float32Array(fftN)
  for (let k = 0; k < fftN; k++) {
    real[k] = i[k] * hann[k]
    imag[k] = q[k] * hann[k]
  }

  fftInPlace(real, imag)

  // Full complex spectrum magnitude (N bins — IQ input is complex-valued)
  const primary = new Float32Array(fftN)
  let maxMag    = 1e-12
  for (let k = 0; k < fftN; k++) {
    const mag  = Math.sqrt(real[k] * real[k] + imag[k] * imag[k])
    primary[k] = mag
    if (mag > maxMag) maxMag = mag
  }
  for (let k = 0; k < fftN; k++) primary[k] /= maxMag

  // IQ preview: interleaved i/q, at most 128 pairs = at most 256 floats
  const pairs     = Math.min(128, actualLen)
  const iqPreview = new Float32Array(pairs * 2)
  for (let k = 0; k < pairs; k++) {
    iqPreview[k * 2]     = i[k]
    iqPreview[k * 2 + 1] = q[k]
  }

  const outputMs = performance.now()

  // All three latency values use client performance.now() exclusively.
  const workerLatencyMs = outputMs   - receiveMs    // total: queue wait + DSP
  const queueWaitMs     = dspStartMs - receiveMs    // time spent waiting in queue
  const dspLatencyMs    = outputMs   - dspStartMs   // FFT + output cost

  // Diagnostic: server monotonic vs client performance.now() (different origins).
  // The absolute value is not a network RTT — use only for inter-frame drift.
  const sourceClockDeltaMs: number | null =
    typeof frame.payload.time === "number" && frame.payload.time > 0
      ? outputMs - frame.payload.time * 1000
      : null

  const metrics: DspMetrics = {
    seq,
    sampleRate:            sample_rate,
    frameSize:             frame_size,
    fpsIn:                 currentFpsIn,
    fpsOut:                currentFpsOut,
    droppedFrames,
    parseErrors,
    schemaErrors,
    workerLatencyMs,
    queueWaitMs,
    dspLatencyMs,
    sourceClockDeltaMs,
    queueDepth,
    queueDroppedFrames,
    queuedFrames,
    totalReconnectAttempts,
    lastReconnectDelayMs,
  }

  // Transfer primary.buffer and iqPreview.buffer — zero-copy to main thread.
  // Both typed arrays are local; they go out of scope after this call.
  // The neutered buffers are never reused.
  post(
    { type: "dsp_frame", seq, sampleRate: sample_rate, frameSize: frame_size,
      primary, iqPreview, metrics },
    [primary.buffer, iqPreview.buffer],
  )

  fpsOutAccum++
  lastOutputMs = outputMs
}

// ---------------------------------------------------------------------------
// Async drain loop — P2B-A
// ---------------------------------------------------------------------------

// scheduleDrain() is the ONLY entry point from onmessage.
// drainLoop() is NEVER called inline inside onmessage.
function scheduleDrain(): void {
  if (drainScheduled) return
  drainScheduled = true
  setTimeout(drainLoop, 0)
}

function drainLoop(): void {
  drainScheduled = false
  if (frameQueue.length === 0) return

  const now        = performance.now()
  const timeToNext = lastOutputMs + OUTPUT_INTERVAL_MS - now

  if (timeToNext > 0) {
    // Output slot not yet open — schedule drain at the exact moment it opens.
    // This never burns frames; it just waits.
    drainScheduled = true
    setTimeout(drainLoop, timeToNext)
    return
  }

  // Output slot is open: dequeue one frame and run DSP.
  const queued     = frameQueue.shift()!
  queueDepth       = frameQueue.length
  const dspStartMs = performance.now()

  try {
    processFrame(queued.frame, queued.receiveMs, dspStartMs)
  } catch (err) {
    post({ type: "worker_error", message: `processFrame: ${String(err)}` })
  }

  // If more frames are waiting, schedule next drain at the next 60 fps slot.
  if (frameQueue.length > 0) {
    drainScheduled = true
    setTimeout(drainLoop, OUTPUT_INTERVAL_MS)
  }
}

// ---------------------------------------------------------------------------
// Reconnect management — P2B-A
// ---------------------------------------------------------------------------

function cancelReconnect(): void {
  if (reconnectTimerId !== null) {
    clearTimeout(reconnectTimerId)
    reconnectTimerId = null
  }
}

function scheduleReconnect(): void {
  if (manualDisconnect || currentWsUrl === null) return
  cancelReconnect()
  const epoch   = connectionEpoch  // captured: ignored if stale when timer fires
  const delayMs = Math.min(
    BACKOFF_BASE_MS * Math.pow(BACKOFF_MULTIPLIER, currentReconnectAttempt),
    BACKOFF_MAX_MS,
  )
  currentReconnectAttempt++
  totalReconnectAttempts++
  lastReconnectDelayMs = delayMs
  post({ type: "ws_reconnecting", delayMs, attempt: currentReconnectAttempt })
  reconnectTimerId = setTimeout((): void => {
    reconnectTimerId = null
    if (!manualDisconnect && currentWsUrl !== null && epoch === connectionEpoch) {
      openSocket(currentWsUrl)
    }
  }, delayMs)
}

// ---------------------------------------------------------------------------
// WebSocket management
// ---------------------------------------------------------------------------

function openSocket(wsUrl: string): void {
  if (socket !== null) { socket.close(); socket = null }
  currentWsUrl     = wsUrl
  manualDisconnect = false
  connectionEpoch++
  const epoch = connectionEpoch   // captured once; all handlers below close over it

  try {
    socket = new WebSocket(wsUrl)
  } catch (err) {
    post({ type: "worker_error", message: `WebSocket constructor: ${String(err)}` })
    scheduleReconnect()
    return
  }

  socket.onopen = (): void => {
    if (epoch !== connectionEpoch) return   // stale: a newer socket already took over
    currentReconnectAttempt = 0             // reset backoff counter on successful open
    lastReconnectDelayMs    = 0
    post({ type: "ws_open" })
  }

  socket.onmessage = (ev: MessageEvent): void => {
    if (epoch !== connectionEpoch) return   // stale event from superseded socket

    if (typeof ev.data !== "string") {
      schemaErrors++
      return
    }
    let parsed: unknown
    try {
      parsed = JSON.parse(ev.data)
    } catch {
      parseErrors++
      return
    }
    if (!isLegacyIQFrame(parsed)) { schemaErrors++; return }

    const receiveMs = performance.now()
    queuedFrames++

    // Ring buffer: drop-oldest policy on overflow
    if (frameQueue.length >= QUEUE_CAPACITY) {
      frameQueue.shift()
      queueDroppedFrames++
    }
    frameQueue.push({ frame: parsed, receiveMs })
    queueDepth = frameQueue.length

    // Do NOT call drainLoop() inline — schedule it asynchronously.
    scheduleDrain()
  }

  socket.onerror = (): void => {
    if (epoch !== connectionEpoch) return   // stale
    post({ type: "worker_error", message: "WebSocket error event" })
  }

  socket.onclose = (ev: CloseEvent): void => {
    if (epoch !== connectionEpoch) return   // stale: onclose from a socket we already replaced
    post({ type: "ws_closed", code: ev.code, reason: ev.reason })
    socket = null
    if (!manualDisconnect) {
      scheduleReconnect()
    }
  }
}

function closeSocket(): void {
  connectionEpoch++            // invalidates ALL handlers on the current socket
  manualDisconnect  = true
  cancelReconnect()
  frameQueue.length = 0        // discard queued frames on explicit disconnect
  queueDepth        = 0
  if (socket !== null) { socket.close(); socket = null }
}

// ---------------------------------------------------------------------------
// Main-thread message handler
// ---------------------------------------------------------------------------

self.onmessage = (ev: MessageEvent<WorkerInbound>): void => {
  const msg = ev.data
  switch (msg.type) {
    case "connect":    openSocket(msg.wsUrl); break
    case "disconnect": closeSocket();         break
  }
}

// Signal readiness immediately on script load
post({ type: "worker_ready" })
