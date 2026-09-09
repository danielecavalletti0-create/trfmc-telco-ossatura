import { create } from 'zustand'

export interface RfMetric {
  id: string
  label: string
  value: number | string
  unit?: string
  timestamp: number
  source?: string
}

export interface RfMetricsStore {
  metrics: Record<string, RfMetric>
  setMetric: (id: string, metric: Omit<RfMetric, 'id'>) => void
  setMetrics: (metrics: Record<string, RfMetric>) => void
  removeMetric: (id: string) => void
  resetMetrics: () => void
}

export const useRfMetricsStore = create<RfMetricsStore>((set) => ({
  metrics: {},
  setMetric: (id, metric) =>
    set((state) => ({
      metrics: {
        ...state.metrics,
        [id]: {
          id,
          ...metric
        }
      }
    })),
  setMetrics: (metrics) => set({ metrics }),
  removeMetric: (id) =>
    set((state) => {
      const metrics = { ...state.metrics }
      delete metrics[id]
      return { metrics }
    }),
  resetMetrics: () => set({ metrics: {} })
}))
