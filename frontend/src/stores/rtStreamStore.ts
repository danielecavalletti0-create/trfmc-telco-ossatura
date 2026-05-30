import { create } from 'zustand'

export interface StreamMessage {
  id: string
  timestamp: number
  type: string
  data: Record<string, any>
  latency_ms?: number
}

export type WsState = 'CONNECTING' | 'CONNECTED' | 'DISCONNECTED' | 'ERROR' | 'CLOSED'

export interface StreamMetrics {
  total_messages: number
  dropped_messages: number
  queue_depth: number
  avg_latency_ms: number
  max_latency_ms: number
  min_latency_ms: number
  p95_latency_ms: number
  last_error?: string
  last_error_time?: number
}

class RingBuffer<T> {
  private buffer: (T | undefined)[]
  private head = 0
  private count = 0
  private readonly capacity: number

  constructor(capacity: number) {
    this.capacity = capacity
    this.buffer = new Array(capacity).fill(undefined)
  }

  push(item: T): void {
    this.buffer[this.head] = item
    this.head = (this.head + 1) % this.capacity
    if (this.count < this.capacity) {
      this.count++
    }
  }

  toArray(): T[] {
    const result: T[] = []
    for (let i = 0; i < this.count; i++) {
      const idx = (this.head - 1 - i + this.capacity * 2) % this.capacity
      const item = this.buffer[idx]
      if (item !== undefined) {
        result.push(item)
      }
    }
    return result
  }

  clear(): void {
    this.buffer.fill(undefined)
    this.head = 0
    this.count = 0
  }

  size(): number {
    return this.count
  }
}

function createThrottle(maxPerSecond: number = 100) {
  let lastTime = Date.now()
  let messageCount = 0
  const windowSize = 1000

  return (fn: () => void) => {
    const now = Date.now()
    const elapsed = now - lastTime

    if (elapsed >= windowSize) {
      lastTime = now
      messageCount = 1
      fn()
    } else if (messageCount < maxPerSecond) {
      messageCount++
      fn()
    }
  }
}

function createBackoffStrategy() {
  let retryCount = 0
  const maxRetries = 10
  const baseDelay = 1000

  return {
    getDelay: () => {
      const delay = baseDelay * Math.pow(2, Math.min(retryCount, maxRetries))
      return Math.min(delay, 30000)
    },
    increment: () => {
      retryCount++
    },
    reset: () => {
      retryCount = 0
    },
    canRetry: () => retryCount < maxRetries
  }
}

class LatencyTracker {
  private samples: number[] = []
  private readonly maxSamples = 1000

  record(latency: number): void {
    this.samples.push(latency)
    if (this.samples.length > this.maxSamples) {
      this.samples.shift()
    }
  }

  getStats() {
    if (this.samples.length === 0) {
      return { avg: 0, min: 0, max: 0, p95: 0 }
    }

    const sorted = [...this.samples].sort((a, b) => a - b)
    const avg = this.samples.reduce((a, b) => a + b, 0) / this.samples.length
    const p95Idx = Math.floor(sorted.length * 0.95)

    return {
      avg: Math.round(avg),
      min: sorted[0],
      max: sorted[sorted.length - 1],
      p95: sorted[p95Idx]
    }
  }

  clear(): void {
    this.samples = []
  }
}

interface RtStreamState {
  messages: StreamMessage[]
  wsState: WsState
  metrics: StreamMetrics
  _buffer: RingBuffer<StreamMessage>
  _throttle: (fn: () => void) => void
  _backoff: ReturnType<typeof createBackoffStrategy>
  _latencyTracker: LatencyTracker
  _ws: WebSocket | null
  _reconnectTimer: number | null
  _nextId: number
  addMessage: (msg: Omit<StreamMessage, 'id' | 'timestamp'>) => void
  setWsState: (state: WsState) => void
  connect: (url: string) => Promise<void>
  disconnect: () => void
  getMessages: (limit?: number) => StreamMessage[]
  getMetrics: () => StreamMetrics
  clearMessages: () => void
  reset: () => void
}

export const useRtStreamStore = create<RtStreamState>((set, get) => {
  const buffer = new RingBuffer<StreamMessage>(512)
  const throttle = createThrottle(100)
  const backoff = createBackoffStrategy()
  const latencyTracker = new LatencyTracker()

  return {
    messages: [],
    wsState: 'CONNECTING',
    metrics: {
      total_messages: 0,
      dropped_messages: 0,
      queue_depth: 0,
      avg_latency_ms: 0,
      max_latency_ms: 0,
      min_latency_ms: 0,
      p95_latency_ms: 0
    },
    _buffer: buffer,
    _throttle: throttle,
    _backoff: backoff,
    _latencyTracker: latencyTracker,
    _ws: null,
    _reconnectTimer: null,
    _nextId: 0,

    addMessage: (msg) => {
      throttle(() => {
        const now = Date.now()
        const message: StreamMessage = {
          ...msg,
          id: String(get()._nextId++),
          timestamp: now,
          latency_ms: now - (msg.data?.timestamp ?? now)
        }

        if (message.latency_ms > 0) {
          latencyTracker.record(message.latency_ms)
        }

        buffer.push(message)

        let dropped = 0
        if (buffer.size() > 400) {
          const messages = buffer.toArray()
          buffer.clear()
          const keep = messages.slice(0, 300)
          keep.reverse().forEach((entry) => buffer.push(entry))
          dropped = Math.max(0, messages.length - 300)
        }

        const stats = latencyTracker.getStats()
        set((state) => ({
          messages: buffer.toArray(),
          metrics: {
            total_messages: state.metrics.total_messages + 1,
            dropped_messages: state.metrics.dropped_messages + dropped,
            queue_depth: buffer.size(),
            avg_latency_ms: stats.avg,
            max_latency_ms: stats.max,
            min_latency_ms: stats.min,
            p95_latency_ms: stats.p95,
            last_error: state.metrics.last_error,
            last_error_time: state.metrics.last_error_time
          }
        }))
      })
    },

    setWsState: (state) => {
      set({ wsState: state })
    },

    connect: async (url: string) => {
      const state = get()
      if (state._ws) {
        state._ws.close()
      }

      set({ wsState: 'CONNECTING' })

      try {
        const ws = new WebSocket(url)

        ws.onopen = () => {
          set({ wsState: 'CONNECTED' })
          backoff.reset()
        }

        ws.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data)
            get().addMessage({
              type: typeof msg.type === 'string' ? msg.type : 'stream',
              data: msg
            })
          } catch (error) {
            const err = String(error)
            set((state) => ({
              metrics: {
                ...state.metrics,
                last_error: `Parse error: ${err}`,
                last_error_time: Date.now()
              }
            }))
            console.warn('[RTStreamStore] WebSocket parse error:', error)
          }
        }

        ws.onerror = (event) => {
          set({ wsState: 'ERROR' })
          const err = 'WebSocket error'
          set((state) => ({
            metrics: {
              ...state.metrics,
              last_error: err,
              last_error_time: Date.now()
            }
          }))
          console.warn('[RTStreamStore]', err, event)
        }

        ws.onclose = () => {
          set({ wsState: 'CLOSED', _ws: null })

          if (backoff.canRetry()) {
            const delay = backoff.getDelay()
            backoff.increment()
            console.info(`[RTStreamStore] reconnect in ${delay}ms`)
            const timer = window.setTimeout(() => {
              get().connect(url)
            }, delay)
            set({ _reconnectTimer: timer })
          }
        }

        set({ _ws: ws })
      } catch (error) {
        const err = String(error)
        set((state) => ({
          wsState: 'ERROR',
          metrics: {
            ...state.metrics,
            last_error: `Connection error: ${err}`,
            last_error_time: Date.now()
          }
        }))
        console.error('[RTStreamStore] Connection error:', error)
      }
    },

    disconnect: () => {
      const state = get()
      if (state._ws) {
        state._ws.close()
        set({ _ws: null })
      }
      if (state._reconnectTimer) {
        clearTimeout(state._reconnectTimer)
        set({ _reconnectTimer: null })
      }
      set({ wsState: 'DISCONNECTED' })
    },

    getMessages: (limit) => {
      const all = get().messages
      return limit ? all.slice(0, limit) : all
    },

    getMetrics: () => get().metrics,

    clearMessages: () => {
      buffer.clear()
      set((state) => ({
        messages: [],
        metrics: {
          ...state.metrics,
          queue_depth: 0
        }
      }))
    },

    reset: () => {
      get().disconnect()
      buffer.clear()
      latencyTracker.clear()
      set({
        messages: [],
        wsState: 'CONNECTING',
        metrics: {
          total_messages: 0,
          dropped_messages: 0,
          queue_depth: 0,
          avg_latency_ms: 0,
          max_latency_ms: 0,
          min_latency_ms: 0,
          p95_latency_ms: 0
        },
        _nextId: 0
      })
    }
  }
})
