export type CommandCenterDomainV37 =
  | 'mission'
  | 'core'
  | 'ran'
  | 'rf'
  | 'soc-noc'
  | 'scenarios'
  | 'knowledge'

export type CommandCenterTileV37 = {
  id: string
  title: string
  subtitle: string
  domain: CommandCenterDomainV37
  liveEndpoint?: string
  routeHint: string
  priority: 'critical' | 'high' | 'medium'
  kpis: Array<{ label: string; value: string }>
  actions: string[]
}

export const commandCenterTilesV37: CommandCenterTileV37[] = [
  {
    id: 'mission-control',
    title: 'Mission Control',
    subtitle: 'Portale operativo, health globale, sorgente dati e modalità read-only.',
    domain: 'mission',
    liveEndpoint: '/api/mission/status',
    routeHint: 'root / operational shell',
    priority: 'critical',
    kpis: [
      { label: 'Mode', value: 'read-only' },
      { label: 'Proxy', value: '4181' },
      { label: 'Frontend', value: '5173' },
    ],
    actions: ['Verifica sorgente backend', 'Controlla fallback', 'Mostra health globale'],
  },
  {
    id: 'core-network',
    title: '5G Core Network',
    subtitle: 'Open5GS, ogstun, SBI, NAS, PFCP, GTP-U e readiness core.',
    domain: 'core',
    liveEndpoint: '/api/core/open5gs/status',
    routeHint: '09_Core_Network',
    priority: 'critical',
    kpis: [
      { label: 'Core', value: 'Open5GS' },
      { label: 'Safety', value: 'no start/stop' },
      { label: 'Probe', value: 'v30 hygiene' },
    ],
    actions: ['Visualizza readiness', 'Collega call-flow', 'Mappa PFCP/GTP-U'],
  },
  {
    id: 'ran-simulator',
    title: 'RAN / UERANSIM',
    subtitle: 'gNB/UE simulator, tunnel UE, NGAP e stato access network.',
    domain: 'ran',
    liveEndpoint: '/api/ran/ueransim/status',
    routeHint: 'RAN simulator / UERANSIM',
    priority: 'high',
    kpis: [
      { label: 'RAN', value: 'UERANSIM' },
      { label: 'UE tun', value: 'uesimtun0' },
      { label: 'Mode', value: 'read-only' },
    ],
    actions: ['Controlla gNB/UE', 'Mappa NGAP', 'Mappa PDU session'],
  },
  {
    id: 'rf-spectrum',
    title: 'RF Spectrum / Signal Workbench',
    subtitle: 'Spectrum sweep contract, synthetic/live-ready RF model, waterfall/IQ path.',
    domain: 'rf',
    liveEndpoint: '/api/rfpro/spectrum/sweep',
    routeHint: '03_Signal_Analyzer',
    priority: 'critical',
    kpis: [
      { label: 'Center', value: '3.64 GHz' },
      { label: 'Span', value: '100 MHz' },
      { label: 'Source', value: 'contract' },
    ],
    actions: ['Apri scenario RF', 'Collega DSP worker', 'Mostra signal path'],
  },
  {
    id: 'rf-bandplan',
    title: 'RF Bandplan / Antenna Context',
    subtitle: 'Bande, antenna systems, beamwidth, microstrip e tower infrastructure.',
    domain: 'rf',
    liveEndpoint: '/api/rfpro/bandplan',
    routeHint: '02_RF_Physics / 05_Antenna_System',
    priority: 'high',
    kpis: [
      { label: 'Layer', value: 'RF knowledge' },
      { label: 'Scenarios', value: 'V36' },
      { label: 'Visual', value: 'asset-ready' },
    ],
    actions: ['Esplora antenne', 'Apri beamwidth', 'Apri microstrip'],
  },
  {
    id: 'soc-noc-correlation',
    title: 'SOC/NOC Correlation',
    subtitle: 'Correlazione eventi RF/Telco/Cyber, evidence e scenario readiness.',
    domain: 'soc-noc',
    liveEndpoint: '/api/soc-noc/correlation/demo',
    routeHint: '11_Cyber_RF_Intelligence',
    priority: 'high',
    kpis: [
      { label: 'Events', value: 'contract' },
      { label: 'Mutation', value: 'disabled' },
      { label: 'Evidence', value: 'ready' },
    ],
    actions: ['Correla eventi', 'Apri evidence view', 'Collega NOC tiles'],
  },
  {
    id: 'dynamic-scenarios',
    title: 'Dynamic RF/Telco Scenarios',
    subtitle: 'Motore scenari V36: electronics, microstrip, antenna, tower, beamwidth, RF lab, UAV.',
    domain: 'scenarios',
    routeHint: 'V36 visual scenario runtime',
    priority: 'critical',
    kpis: [
      { label: 'Scenes', value: '7' },
      { label: 'Layers', value: '4' },
      { label: 'Mode', value: 'interactive' },
    ],
    actions: ['Seleziona scenario', 'Attiva physics layer', 'Attiva hotspots'],
  },
  {
    id: 'knowledge-base',
    title: 'Knowledge Base',
    subtitle: 'Base visuale e documentale RF/Telco/Cyber per didattica e laboratorio.',
    domain: 'knowledge',
    routeHint: '12_Knowledge_Base',
    priority: 'medium',
    kpis: [
      { label: 'Scope', value: 'RF/Telco/Cyber' },
      { label: 'Assets', value: 'visual' },
      { label: 'Use', value: 'training' },
    ],
    actions: ['Apri glossario', 'Apri teoria', 'Collega immagini/render'],
  },
]

export const commandCenterFusionMetaV37 = {
  title: 'TRFMC V37 Command Center Fusion',
  subtitle: 'Mission layer nativo React sopra V36, senza iframe, con contratti live 4181.',
  legacyReference: '/trfmc_official_safe_entrypoint_v6r3_command_center.html',
  legacyMode: 'reference-only-no-iframe',
}
