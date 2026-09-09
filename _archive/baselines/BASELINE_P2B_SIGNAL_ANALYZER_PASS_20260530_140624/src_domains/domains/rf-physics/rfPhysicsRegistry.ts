export type RFPhysicsFormula = {
  id: string
  label: string
  expression: string
  meaning: string
  unit: string
  promotionSource: string
}

export type RFPhysicsKpi = {
  id: string
  label: string
  value: string
  note: string
  state: 'ready' | 'derived' | 'review'
}

export type RFPhysicsScenario = {
  id: string
  title: string
  objective: string
  evidence: string
}

export const rfPhysicsPromotionSource = {
  phase: 'P1B_RF_PHYSICS_REACT_PROMOTION_V1',
  selectedSource: 'webgl_rf_physics_engine_v85b_sapienza_baseline',
  sourceScore: 227,
  formulaHits: 15,
  canvasTags: 2,
  debtHits: 1,
  rule: 'Extract physics model, formulas and visual behavior into React. Do not mount public HTML.',
}

export const rfPhysicsFormulas: RFPhysicsFormula[] = [
  {
    id: 'lambda',
    label: 'Wavelength',
    expression: 'λ = c / f',
    meaning: 'Relates carrier frequency to propagation wavelength in free space.',
    unit: 'm',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'fspl',
    label: 'Free-space path loss',
    expression: 'FSPL(dB) = 32.44 + 20log10(dkm) + 20log10(fMHz)',
    meaning: 'First-order reference model for isotropic free-space propagation loss.',
    unit: 'dB',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'rx-power',
    label: 'Received power',
    expression: 'Prx(dBm) = Ptx + Gtx + Grx − Lpath − Lmisc',
    meaning: 'Link budget accounting of transmit power, antenna gains and propagation losses.',
    unit: 'dBm',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'snr',
    label: 'Signal-to-noise ratio',
    expression: 'SNR(dB) = Psignal(dBm) − Pnoise(dBm)',
    meaning: 'Quality metric for coverage, demodulation margin and link reliability.',
    unit: 'dB',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'sinr',
    label: 'Signal-to-interference-plus-noise',
    expression: 'SINR = S / (I + N)',
    meaning: 'Operational quality model when interference sources are present.',
    unit: 'dB',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'fresnel',
    label: 'First Fresnel radius',
    expression: 'r₁ = √(λ d₁ d₂ / (d₁ + d₂))',
    meaning: 'Clearance model for microwave/RF path obstruction and NLOS degradation.',
    unit: 'm',
    promotionSource: 'RF physics baseline',
  },
]

export const rfPhysicsKpis: RFPhysicsKpi[] = [
  {
    id: 'carrier',
    label: 'Carrier',
    value: '2.440 GHz',
    note: 'ISM/Lab reference carrier for RF visualization',
    state: 'ready',
  },
  {
    id: 'lambda',
    label: 'λ',
    value: '0.123 m',
    note: 'Derived from c / f',
    state: 'derived',
  },
  {
    id: 'rsrp',
    label: 'RSRP profile',
    value: '-52 → -96 dBm',
    note: 'Synthetic field gradient for route/coverage review',
    state: 'derived',
  },
  {
    id: 'sinr',
    label: 'SINR profile',
    value: '4 → 35 dB',
    note: 'Scenario-linked coverage quality model',
    state: 'derived',
  },
  {
    id: 'canvas',
    label: 'Visual engine',
    value: 'React Canvas',
    note: 'No public HTML runtime mount',
    state: 'ready',
  },
  {
    id: 'qa',
    label: 'QA',
    value: 'build + DOM + screenshot',
    note: 'P1B acceptance gate required',
    state: 'review',
  },
]

export const rfPhysicsScenarios: RFPhysicsScenario[] = [
  {
    id: 'controlled-propagation-baseline',
    title: 'Controlled propagation baseline',
    objective: 'Verify wavelength, free-space loss and received-power gradient.',
    evidence: 'Formula registry + canvas field profile + DOM marker.',
  },
  {
    id: 'nlos-obstruction',
    title: 'NLOS / obstruction interpretation',
    objective: 'Demonstrate signal degradation through blocked path and reduced SINR.',
    evidence: 'Fresnel clearance model and synthetic RSRP/SINR contour.',
  },
  {
    id: 'coverage-quality',
    title: 'Coverage quality classification',
    objective: 'Map RSRP/SINR bands into engineering readiness.',
    evidence: 'KPI strip and field canvas visual state.',
  },
]
