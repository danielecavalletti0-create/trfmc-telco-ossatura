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
