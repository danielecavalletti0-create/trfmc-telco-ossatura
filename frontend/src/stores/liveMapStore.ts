import { create } from 'zustand'
import type { LiveContractResult } from '../shared/liveContractsV32R1'

export type LiveMap = Record<string, LiveContractResult | undefined>

export interface LiveMapStore {
  liveMap: LiveMap
  lastRefresh: number | null
  setLiveMap: (liveMap: LiveMap) => void
  clearLiveMap: () => void
  setLastRefresh: (timestamp: number) => void
}

export const useLiveMapStore = create<LiveMapStore>((set) => ({
  liveMap: {},
  lastRefresh: null,
  setLiveMap: (liveMap) => set({ liveMap, lastRefresh: Date.now() }),
  clearLiveMap: () => set({ liveMap: {} }),
  setLastRefresh: (timestamp) => set({ lastRefresh: timestamp })
}))
