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
  peakDbm: number | null
  meanDbm: number | null
}

export type NormalizedRFSweep = {
  endpoint: string
  ok: boolean
  status: number
  timestamp: string
  source: 'api' | 'api-derived' | 'synthetic-fallback'
  contentType: string
  binCount: number
  tracePreview: number[]
  samplePreview: string
  metrics: RFSweepMetrics
  raw: unknown
  normalizationNotes: string[]
}

type UseRFSpectrumSweepOptions = {
  enabled?: boolean
  intervalMs?: number
  endpoint?: string
}

const BRIDGE_ENDPOINT = 'http://127.0.0.1:4181/api/rfpro/spectrum/sweep'

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  return value as Record<string, unknown>
}

function compactPreview(text: string): string {
  return text.replace(/\s+/g, ' ').trim().slice(0, 220)
}

function parseNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return Number(value.toFixed(3))
  if (typeof value === 'string') {
    const parsed = Number(value.replace(',', '.').replace(/[^\d.+-]/g, ''))
    if (Number.isFinite(parsed)) return Number(parsed.toFixed(3))
  }
  return null
}

function keyMatches(key: string, needles: string[]): boolean {
  const normalized = key.toLowerCase().replace(/[^a-z0-9]/g, '')
  return needles.some((needle) => normalized === needle || normalized.includes(needle))
}

function findFirstNumberDeep(value: unknown, needles: string[]): number | null {
  const visited = new Set<unknown>()

  function walk(node: unknown): number | null {
    if (node && typeof node === 'object') {
      if (visited.has(node)) return null
      visited.add(node)
    }

    if (Array.isArray(node)) {
      for (const item of node) {
        const result = walk(item)
        if (result !== null) return result
      }
      return null
    }

    const rec = asRecord(node)
    if (!rec) return null

    for (const [key, val] of Object.entries(rec)) {
      if (keyMatches(key, needles)) {
        const direct = parseNumber(val)
        if (direct !== null) return direct

        const nested = walk(val)
        if (nested !== null) return nested
      }
    }

    for (const val of Object.values(rec)) {
      const nested = walk(val)
      if (nested !== null) return nested
    }

    return null
  }

  return walk(value)
}

function findNumericArraysDeep(value: unknown): number[][] {
  const arrays: number[][] = []
  const visited = new Set<unknown>()

  function walk(node: unknown) {
    if (node && typeof node === 'object') {
      if (visited.has(node)) return
      visited.add(node)
    }

    if (Array.isArray(node)) {
      const nums = node
        .map((item) => {
          if (typeof item === 'number') return item
          if (Array.isArray(item) && typeof item[1] === 'number') return item[1]
          if (asRecord(item)) {
            return (
              parseNumber((item as Record<string, unknown>).power) ??
              parseNumber((item as Record<string, unknown>).dbm) ??
              parseNumber((item as Record<string, unknown>).y) ??
              parseNumber((item as Record<string, unknown>).value)
            )
          }
          return null
        })
        .filter((item): item is number => typeof item === 'number' && Number.isFinite(item))

      if (nums.length >= 16) arrays.push(nums)

      for (const item of node) walk(item)
      return
    }

    const rec = asRecord(node)
    if (!rec) return
    for (const val of Object.values(rec)) walk(val)
  }

  walk(value)
  return arrays.sort((a, b) => b.length - a.length)
}

function percentile(values: number[], q: number): number | null {
  if (!values.length) return null
  const sorted = [...values].sort((a, b) => a - b)
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.round((sorted.length - 1) * q)))
  return Number(sorted[idx].toFixed(3))
}

function avg(values: number[]): number | null {
  if (!values.length) return null
  return Number((values.reduce((a, b) => a + b, 0) / values.length).toFixed(3))
}

function deriveFromTrace(trace: number[]) {
  if (!trace.length) {
    return {
      peakDbm: null,
      meanDbm: null,
      noiseFloorDbm: null,
      snrDb: null,
      crestFactorDb: null,
    }
  }

  const peak = Number(Math.max(...trace).toFixed(3))
  const mean = avg(trace)
  const noise = percentile(trace, 0.20)
  const snr = noise === null ? null : Number((peak - noise).toFixed(3))
  const rms = Math.sqrt(trace.reduce((s, x) => s + x * x, 0) / trace.length)
  const crest = rms > 0 ? Number((20 * Math.log10(Math.abs(peak) / rms)).toFixed(3)) : null

  return {
    peakDbm: peak,
    meanDbm: mean,
    noiseFloorDbm: noise,
    snrDb: snr,
    crestFactorDb: crest,
  }
}

function normalizeSweep(raw: unknown, endpoint: string, status: number, contentType: string, rawText: string): NormalizedRFSweep {
  const notes: string[] = []
  const numericArrays = findNumericArraysDeep(raw)
  const trace = numericArrays[0] ?? []
  const derived = deriveFromTrace(trace)

  if (trace.length > 0) notes.push(`trace_detected:${trace.length}`)
  else notes.push('trace_not_detected')

  const metrics: RFSweepMetrics = {
    snrDb:
      findFirstNumberDeep(raw, ['snr', 'snrdb', 'signaltonoise']) ??
      derived.snrDb,
    evmPct:
      findFirstNumberDeep(raw, ['evm', 'evmpct', 'evmpercent', 'evmrms']) ??
      null,
    merDb:
      findFirstNumberDeep(raw, ['mer', 'merdb']) ??
      null,
    obwMhz:
      findFirstNumberDeep(raw, ['obw', 'obwmhz', 'occupiedbandwidth']) ??
      null,
    aclrLowDbc:
      findFirstNumberDeep(raw, ['aclrlow', 'aclrldb', 'adjacentlow']) ??
      null,
    aclrHighDbc:
      findFirstNumberDeep(raw, ['aclrhigh', 'aclrhdb', 'adjacenthigh']) ??
      null,
    channelPowerDbm:
      findFirstNumberDeep(raw, ['channelpower', 'channelpowerdbm', 'chpower']) ??
      null,
    noiseFloorDbm:
      findFirstNumberDeep(raw, ['noisefloor', 'noisefloordbm', 'noise']) ??
      derived.noiseFloorDbm,
    crestFactorDb:
      findFirstNumberDeep(raw, ['crestfactor', 'crestfactordb']) ??
      derived.crestFactorDb,
    peakDbm: derived.peakDbm,
    meanDbm: derived.meanDbm,
  }

  const hasAnyMetric = Object.values(metrics).some((value) => typeof value === 'number')

  return {
    endpoint,
    ok: status >= 200 && status < 300,
    status,
    timestamp: new Date().toISOString(),
    source: hasAnyMetric || trace.length > 0 ? 'api' : 'api-derived',
    contentType,
    binCount:
      findFirstNumberDeep(raw, ['bincount', 'bins', 'fft', 'fftsize', 'samples']) ??
      trace.length ??
      0,
    tracePreview: trace.slice(0, 32).map((v) => Number(v.toFixed(3))),
    samplePreview: compactPreview(rawText),
    metrics,
    raw,
    normalizationNotes: notes,
  }
}

function syntheticFallback(endpoint: string, reason: string): NormalizedRFSweep {
  return {
    endpoint,
    ok: false,
    status: 0,
    timestamp: new Date().toISOString(),
    source: 'synthetic-fallback',
    contentType: 'synthetic',
    binCount: 4096,
    tracePreview: [],
    samplePreview: reason,
    normalizationNotes: [`fallback:${reason}`],
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
      peakDbm: -18.2,
      meanDbm: -58.4,
    },
    raw: null,
  }
}

export function useRFSpectrumSweep(options: UseRFSpectrumSweepOptions = {}) {
  const {
    enabled = true,
    intervalMs = 2500,
    endpoint = BRIDGE_ENDPOINT,
  } = options

  const [snapshot, setSnapshot] = useState<NormalizedRFSweep | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!enabled) return

    let cancelled = false
    let timer: number | undefined

    async function load() {
      const controller = new AbortController()
      const timeout = window.setTimeout(() => controller.abort(), 2400)

      try {
        setLoading(true)

        const res = await fetch(endpoint, {
          method: 'GET',
          signal: controller.signal,
          headers: { Accept: 'application/json,text/plain,*/*' },
          cache: 'no-store',
        })

        const text = await res.text()
        const contentType = res.headers.get('content-type') ?? ''

        let parsed: unknown = text
        try {
          parsed = JSON.parse(text)
        } catch {
          parsed = { rawText: text }
        }

        const normalized = normalizeSweep(parsed, endpoint, res.status, contentType, text)

        if (!cancelled) {
          setSnapshot(normalized)
          setError(res.ok ? null : `HTTP ${res.status}`)
        }
      } catch (err) {
        if (!cancelled) {
          const message = err instanceof Error ? err.message : 'fetch-error'
          setSnapshot(syntheticFallback(endpoint, message))
          setError(message)
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
    if (snapshot?.source === 'api') return 'API LIVE'
    if (snapshot?.source === 'api-derived') return 'API DERIVED'
    if (error) return 'FALLBACK'
    return 'SYNTHETIC'
  }, [error, loading, snapshot])

  return { snapshot, loading, error, status }
}
