export type TRFMCDomainId =
  | '01_Mission_Control'
  | '02_RF_Physics'
  | '03_Signal_Analyzer'
  | '04_RF_Microwave_Engineering'
  | '05_Antenna_System'
  | '06_Microwave_Link'
  | '07_Fiber_Optic'
  | '08_Private_Networks'
  | '09_Core_Network'
  | '10_Data_Center_Infrastructure'
  | '11_Cyber_RF_Intelligence'
  | '12_Knowledge_Base'

export type TRFMCDomainRegistryEntry = {
  order: string
  domain: TRFMCDomainId
  routeHash: string
  label: string
  purpose: string
  candidateCount: number
  primaryCandidate: string
  nextAction: 'PROMOTE_DOMAIN_ENTRY' | 'CREATE_DOMAIN_PLACEHOLDER'
  status: 'P0_READY' | 'P0_PLACEHOLDER'
}

export type TRFMCP0ShellCandidate = {
  priority: string
  domain: string
  path: string
  recommendedUse: string
  score: number
  debtHits: number
  reason: string
}

export const TRFMC_CANONICAL_DOMAINS: TRFMCDomainRegistryEntry[] = [
  {
    order: '01',
    domain: '01_Mission_Control',
    routeHash: '#mission-overview',
    label: 'Mission Control',
    purpose: 'Portal shell, NOC, command deck, integration control room',
    candidateCount: 13,
    primaryCandidate: 'frontend/public/portal_index_v19.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '02',
    domain: '02_RF_Physics',
    routeHash: '#rf-physics',
    label: 'RF Physics',
    purpose: 'Maxwell, propagation, field models, RF theory engines',
    candidateCount: 8,
    primaryCandidate: 'frontend/public/webgl_rf_physics_engine_v85d_runtime_identity_lock.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '03',
    domain: '03_Signal_Analyzer',
    routeHash: '#signal-analyzer',
    label: 'Signal Analyzer',
    purpose: 'Spectrum, waterfall, I/Q, VSA, RF instruments',
    candidateCount: 14,
    primaryCandidate: 'frontend/public/rf_instrumentation_signal_cockpit_v38.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '04',
    domain: '04_RF_Microwave_Engineering',
    routeHash: '#rf-microwave',
    label: 'RF/Microwave',
    purpose: 'Smith chart, microwave links, filters, RF chain',
    candidateCount: 2,
    primaryCandidate: 'frontend/public/trfmc_rf_microwave_engineering_v1.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '05',
    domain: '05_Antenna_System',
    routeHash: '#antenna-system',
    label: 'Antenna System',
    purpose: 'Antenna explorer, RRU/RET/CPRI, radiation patterns',
    candidateCount: 16,
    primaryCandidate: 'frontend/public/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '06',
    domain: '06_Microwave_Link',
    routeHash: '#microwave-link',
    label: 'Microwave Link',
    purpose: 'Path profile, Fresnel zone, fade margin',
    candidateCount: 0,
    primaryCandidate: '-',
    nextAction: 'CREATE_DOMAIN_PLACEHOLDER',
    status: 'P0_PLACEHOLDER',
  },
  {
    order: '07',
    domain: '07_Fiber_Optic',
    routeHash: '#fiber-optic',
    label: 'Fiber Optic',
    purpose: 'OTDR, fronthaul, fiber diagnostics',
    candidateCount: 1,
    primaryCandidate: 'frontend/public/trfmc_fiber_fronthaul_otdr_workbench_v2.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '08',
    domain: '08_Private_Networks',
    routeHash: '#private-networks',
    label: 'Private Networks',
    purpose: 'Wi-Fi, mesh, private 5G/Wi-Fi integration',
    candidateCount: 1,
    primaryCandidate: 'frontend/public/trfmc_wifi_5_6_7_8_qam_engine_v1.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '09',
    domain: '09_Core_Network',
    routeHash: '#core-network',
    label: 'Core/RAN',
    purpose: 'Open5GS, UERANSIM, AKA, NAS, NGAP, PFCP',
    candidateCount: 2,
    primaryCandidate: 'frontend/public/trfmc_5g_core_ran_identity_aka_engine_v1.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '10',
    domain: '10_Data_Center_Infrastructure',
    routeHash: '#data-center',
    label: 'Data Center',
    purpose: 'Power, PDU, racks, digital twin infrastructure',
    candidateCount: 0,
    primaryCandidate: '-',
    nextAction: 'CREATE_DOMAIN_PLACEHOLDER',
    status: 'P0_PLACEHOLDER',
  },
  {
    order: '11',
    domain: '11_Cyber_RF_Intelligence',
    routeHash: '#cyber-rf-intelligence',
    label: 'Cyber RF Intelligence',
    purpose: 'Evidence, cyber/RF, supervision, reports',
    candidateCount: 2,
    primaryCandidate: 'frontend/public/security_console_v18.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '12',
    domain: '12_Knowledge_Base',
    routeHash: '#knowledge-base',
    label: 'Knowledge Base',
    purpose: 'Theory, procedures, glossary, doctrine',
    candidateCount: 3,
    primaryCandidate: 'frontend/public/rf_telco_knowledge_os_v60.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
]

export const TRFMC_P0_SHELL_CANDIDATES: TRFMCP0ShellCandidate[] = [
  {
    priority: 'P0.01',
    domain: '00_Unclassified',
    path: 'frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html',
    recommendedUse: 'P0_SHELL_BEHAVIOR_REFERENCE',
    score: 100,
    debtHits: 0,
    reason: 'latest official safe command center, latest version marker',
  },
  {
    priority: 'P0.02',
    domain: '01_Mission_Control',
    path: 'frontend/public/trfmc_home_v87g.html',
    recommendedUse: 'P0_HOME_REFERENCE',
    score: 95,
    debtHits: 0,
    reason: 'home candidate, latest version marker',
  },
  {
    priority: 'P0.05',
    domain: '01_Mission_Control',
    path: 'frontend/public/trfmc_integration_control_room.html',
    recommendedUse: 'P0_CONTROL_ROOM_CONTENT_SOURCE',
    score: 80,
    debtHits: 1,
    reason: 'integration control room, has debt hits',
  },
  {
    priority: 'P0.07',
    domain: '01_Mission_Control',
    path: 'frontend/public/portal_index_v19.html',
    recommendedUse: 'P0_INDEX_STRUCTURE_SOURCE',
    score: 70,
    debtHits: 2,
    reason: 'portal index, has debt hits',
  },
]

export const TRFMC_P0_GOVERNANCE = {
  phase: 'P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1',
  shellRule: 'One React shell, one navigation registry, no public HTML as parallel portal',
  mutationScope: 'frontend source only',
  backendMutation: false,
  iframeAllowed: false,
  runtimePatchAllowed: false,
}
