/**
 * CANDIDATE-ONLY — NOT ROUTED TO PRODUCTION
 *
 * iqJsonWsDspWorkerV2.candidate.ts
 *
 * Dedicated Module Worker.  Opens /api/iq/ws directly, validates the JSON
 * legacy P1 schema, converts payload.i / payload.q number arrays to
 * Float32Array, applies a Hann window, runs an in-place Radix-2 FFT, and
 * posts Transferable ArrayBuffer output to the main thread at no more than
 * 60 fps.
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
  readonly latencyMs: number
}

export type WorkerInbound =
  | { readonly type: "connect";    readonly wsUrl: string }
  | { readonly type: "disconnect" }

export type WorkerOutbound =
  | { readonly type: "worker_ready" }
  | { readonly type: "ws_open" }
  | { readonly type: "ws_closed";    readonly code: number; readonly reason: string }
  | { readonly type: "worker_error"; readonly message: string }
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

// Local interface — avoids dependency on the WebWorker lib not listed in tsconfig.
interface WorkerPostScope {
  postMessage(message: WorkerOutbound, transfer?: Transferable[]): void
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const OUTPUT_INTERVAL_MS = 1000 / 60   // ~16.67 ms — caps output at 60 fps
const FPS_WINDOW_MS      = 1000        // 1-second sliding FPS counter window

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
let droppedFrames = 0
let parseErrors   = 0
let schemaErrors  = 0
let lastOutputMs  = 0

// 1-second sliding window FPS counters
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

function processFrame(frame: LegacyIQFrame): void {
  const receiveMs = performance.now()
  fpsInAccum++
  tickFps(receiveMs)

  const { seq, sample_rate, frame_size, i, q } = frame.payload

  // Corrupt payload: both channel arrays must have equal length
  if (i.length !== q.length) { droppedFrames++; return }

  // Throttle: skip DSP computation inside the 60-fps output interval
  if (receiveMs - lastOutputMs < OUTPUT_INTERVAL_MS) return

  // Guard frame_size vs actual array length to avoid silent overread
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

  const metrics: DspMetrics = {
    seq,
    sampleRate:   sample_rate,
    frameSize:    frame_size,
    fpsIn:        currentFpsIn,
    fpsOut:       currentFpsOut,
    droppedFrames,
    parseErrors,
    schemaErrors,
    latencyMs:    outputMs - receiveMs,
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
// WebSocket management
// ---------------------------------------------------------------------------

function openSocket(wsUrl: string): void {
  if (socket !== null) { socket.close(); socket = null }

  try {
    socket = new WebSocket(wsUrl)
  } catch (err) {
    post({ type: "worker_error", message: `WebSocket constructor: ${String(err)}` })
    return
  }

  socket.onopen = (): void => {
    post({ type: "ws_open" })
  }

  // Guard on ev.data type before calling JSON.parse
  socket.onmessage = (ev: MessageEvent): void => {
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
    try {
      processFrame(parsed)
    } catch (err) {
      post({ type: "worker_error", message: `processFrame: ${String(err)}` })
    }
  }

  socket.onerror = (): void => {
    post({ type: "worker_error", message: "WebSocket error event" })
  }

  socket.onclose = (ev: CloseEvent): void => {
    post({ type: "ws_closed", code: ev.code, reason: ev.reason })
    socket = null
  }
}

function closeSocket(): void {
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
