import { create } from 'zustand'

export type SectionId = 'overview' | 'rf' | 'network' | 'assets' | 'soc' | 'events' | 'restricted'
export type WsState = 'CONNECTING' | 'CONNECTED' | 'DISCONNECTED' | 'ERROR' | 'CLOSED'

export interface AppStateStore {
  active: SectionId
  selectedTarget: string
  loading: boolean
  err: string
  setActive: (section: SectionId) => void
  setSelectedTarget: (target: string) => void
  setLoading: (loading: boolean) => void
  setErr: (err: string) => void
}

export const useAppStateStore = create<AppStateStore>((set) => ({
  active: 'overview',
  selectedTarget: 'UE-REMOTE-001',
  loading: true,
  err: '',
  setActive: (section) => set({ active: section }),
  setSelectedTarget: (target) => set({ selectedTarget: target }),
  setLoading: (loading) => set({ loading }),
  setErr: (err) => set({ err })
}))
