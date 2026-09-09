export type AntennaSystemKpi = {
  id: string
  label: string
  value: string
  note: string
  state: 'ready' | 'derived' | 'review'
}

export type AntennaSystemMetric = {
  id: string
  label: string
  expression: string
  meaning: string
  unit: string
}

export type AntennaPortMap = {
  id: string
  chain: string
  rruPort: string
  cpri: string
  ret: string
  aisg: string
  polarization: string
  note: string
}

export type AntennaScenario = {
  id: string
  title: string
  objective: string
  evidence: string
}

export const antennaSystemPromotionSource = {
  phase: 'P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1',
  selectedSource: 'trfmc_antenna_rru_ret_cpri_port_mapping_v2',
  sourceScore: 259,
  contentHits: 21,
  canvasTags: 3,
  debtHits: 4,
  rule: 'Extract antenna, RRU, RET, CPRI, AISG, radiation pattern and port mapping concepts into React. Do not mount public HTML.',
}

export const antennaSystemKpis: AntennaSystemKpi[] = [
  {
    id: 'band',
    label: 'Band',
    value: 'n78 · 3.5 GHz',
    note: 'lab reference sector',
    state: 'ready',
  },
  {
    id: 'gain',
    label: 'Peak gain',
    value: '17.5 dBi',
    note: 'sector panel approximation',
    state: 'derived',
  },
  {
    id: 'hpbw',
    label: 'HPBW',
    value: '65° az · 8° el',
    note: 'horizontal / vertical beamwidth',
    state: 'derived',
  },
  {
    id: 'tilt',
    label: 'RET downtilt',
    value: '4.0°',
    note: 'remote electrical tilt model',
    state: 'ready',
  },
  {
    id: 'ports',
    label: 'RF chains',
    value: '8T8R',
    note: 'RRU/antenna port mapping',
    state: 'ready',
  },
  {
    id: 'cpri',
    label: 'Fronthaul',
    value: 'CPRI/AISG',
    note: 'mapping and supervision reference',
    state: 'review',
  },
]

export const antennaSystemMetrics: AntennaSystemMetric[] = [
  {
    id: 'gain-pattern',
    label: 'Normalized pattern gain',
    expression: 'G(θ,φ) = Gmax − A(θ,φ)',
    meaning: 'Directional gain model including azimuth and elevation attenuation.',
    unit: 'dBi',
  },
  {
    id: 'hpbw',
    label: 'Half-power beamwidth',
    expression: 'HPBW = θ₂ − θ₁ at Gmax − 3 dB',
    meaning: 'Angular width between half-power points of the main lobe.',
    unit: 'deg',
  },
  {
    id: 'downtilt',
    label: 'Electrical downtilt',
    expression: 'θeffective = θmechanical + θRET',
    meaning: 'Effective vertical steering after mechanical and remote electrical tilt.',
    unit: 'deg',
  },
  {
    id: 'eirp',
    label: 'EIRP',
    expression: 'EIRP(dBm) = Ptx + Gant − Lfeed',
    meaning: 'Equivalent isotropic radiated power for the antenna chain.',
    unit: 'dBm',
  },
  {
    id: 'front-back',
    label: 'Front-to-back ratio',
    expression: 'F/B = Gfront − Gback',
    meaning: 'Antenna discrimination between main direction and rear lobe.',
    unit: 'dB',
  },
  {
    id: 'mimo-map',
    label: 'MIMO chain mapping',
    expression: 'Layer ⇄ RF chain ⇄ RRU port ⇄ antenna element',
    meaning: 'Logical-to-physical mapping for sectorized MIMO operation.',
    unit: 'map',
  },
]

export const antennaPortMap: AntennaPortMap[] = [
  {
    id: 'p1',
    chain: 'TX/RX 1',
    rruPort: 'RRU A1',
    cpri: 'CPRI lane 0',
    ret: 'RET group A',
    aisg: 'AISG bus 1',
    polarization: '+45°',
    note: 'primary sector chain',
  },
  {
    id: 'p2',
    chain: 'TX/RX 2',
    rruPort: 'RRU A2',
    cpri: 'CPRI lane 1',
    ret: 'RET group A',
    aisg: 'AISG bus 1',
    polarization: '-45°',
    note: 'cross-polar pair',
  },
  {
    id: 'p3',
    chain: 'TX/RX 3',
    rruPort: 'RRU B1',
    cpri: 'CPRI lane 2',
    ret: 'RET group B',
    aisg: 'AISG bus 2',
    polarization: '+45°',
    note: 'upper sub-array',
  },
  {
    id: 'p4',
    chain: 'TX/RX 4',
    rruPort: 'RRU B2',
    cpri: 'CPRI lane 3',
    ret: 'RET group B',
    aisg: 'AISG bus 2',
    polarization: '-45°',
    note: 'upper cross-polar pair',
  },
]

export const antennaScenarios: AntennaScenario[] = [
  {
    id: 'sector-coverage-baseline',
    title: 'Sector coverage baseline',
    objective: 'Validate azimuth pattern, gain, HPBW and front-to-back behavior.',
    evidence: 'Radiation canvas + KPI strip + pattern formula registry.',
  },
  {
    id: 'ret-downtilt-change',
    title: 'RET downtilt variation',
    objective: 'Show how electrical tilt affects vertical coverage and overshoot risk.',
    evidence: 'RET card + downtilt formula + elevation overlay.',
  },
  {
    id: 'rru-port-tracing',
    title: 'RRU/CPRI/AISG traceability',
    objective: 'Map RF chain to RRU port, CPRI lane, AISG bus and polarization.',
    evidence: 'Port mapping cards + chain table + QA marker.',
  },
]
