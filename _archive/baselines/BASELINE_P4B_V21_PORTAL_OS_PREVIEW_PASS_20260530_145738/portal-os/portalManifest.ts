export type PortalOSModuleStatus = 'preview' | 'promoted' | 'reference' | 'candidate'

export type PortalOSModule = {
  id: string
  title: string
  category: string
  route: string
  status: PortalOSModuleStatus
  source: string
  description: string
}

export const portalOSModules: PortalOSModule[] = [
  {
    id: 'home',
    title: 'Unified Portal OS Home',
    category: 'portal-os',
    route: '#portal-os-preview',
    status: 'preview',
    source: 'frontend/src/portal-os',
    description: 'Home unica: shell, launcher, viewport, evidence panel e data fabric.'
  },
  {
    id: 'v63-command-center',
    title: 'V63 Command Center Reference',
    category: 'command-center-shell',
    route: '#command-center',
    status: 'reference',
    source: 'frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html',
    description: 'Riferimento visuale e operativo per la nuova architettura.'
  },
  {
    id: 'rf-physics',
    title: 'RF Physics',
    category: 'rf-physics',
    route: '#rf-physics',
    status: 'promoted',
    source: 'frontend/src/domains/rf-physics/RFPhysicsDomainP1.tsx',
    description: 'Dominio React promosso: teoria, formule e base RF.'
  },
  {
    id: 'signal-analyzer',
    title: 'Signal Analyzer',
    category: 'fft-dsp-signal',
    route: '#signal-analyzer',
    status: 'promoted',
    source: 'frontend/src/domains/signal-analyzer/SignalAnalyzerDomainP2.tsx',
    description: 'Dominio React promosso: spectrum, waterfall, IQ, FFT, EVM.'
  },
  {
    id: 'antenna-system',
    title: 'Antenna System',
    category: 'antenna-system',
    route: '#antenna-system',
    status: 'promoted',
    source: 'frontend/src/domains/antenna-system/AntennaSystemDomainP3.tsx',
    description: 'Dominio React promosso: antenna, RRU, RET, CPRI, AISG.'
  },
  {
    id: 'core-ran',
    title: '5G Core/RAN Identity',
    category: '5g-core-ran',
    route: '#core-ran',
    status: 'candidate',
    source: 'frontend/public / backend APIs',
    description: 'Open5GS, UERANSIM, SUPI/SUCI, AKA, NGAP, PFCP, GTP-U.'
  },
  {
    id: 'war-room',
    title: 'RF/TM War Room',
    category: 'war-room',
    route: '#war-room',
    status: 'candidate',
    source: 'frontend/public war-room references',
    description: 'Scenario, evidence, RF/cyber correlation and operational console.'
  },
  {
    id: 'knowledge-base',
    title: 'Knowledge Base',
    category: 'knowledge-academy',
    route: '#knowledge-base',
    status: 'candidate',
    source: 'frontend/public knowledge references',
    description: 'Formule, teoria, procedure, glossary and teaching content.'
  }
]

export const promotedPortalOSModules = portalOSModules.filter((module) => module.status === 'promoted')
export const candidatePortalOSModules = portalOSModules.filter((module) => module.status === 'candidate')
export const referencePortalOSModules = portalOSModules.filter((module) => module.status === 'reference')
