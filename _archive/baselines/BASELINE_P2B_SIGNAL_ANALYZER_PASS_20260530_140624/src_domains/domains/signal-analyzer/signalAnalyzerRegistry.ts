export type SignalAnalyzerKpi = {
  id: string
  label: string
  value: string
  note: string
  state: 'ready' | 'derived' | 'review'
}

export type SignalAnalyzerMeasurement = {
  id: string
  label: string
  expression: string
  meaning: string
  unit: string
}

export type SignalAnalyzerScenario = {
  id: string
  title: string
  objective: string
  evidence: string
}

export const signalAnalyzerPromotionSource = {
  phase: 'P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1',
  selectedSource: 'rf_instrumentation_signal_cockpit_v38',
  sourceScore: 234,
  contentHits: 22,
  canvasTags: 1,
  debtHits: 9,
  rule: 'Extract spectrum, waterfall, IQ, FFT, constellation and EVM concepts into React. Do not mount public HTML.',
}

export const signalAnalyzerKpis: SignalAnalyzerKpi[] = [
  {
    id: 'center',
    label: 'Center',
    value: '2.440 GHz',
    note: 'synthetic lab carrier',
    state: 'ready',
  },
  {
    id: 'span',
    label: 'Span',
    value: '80 MHz',
    note: 'spectrum viewport',
    state: 'ready',
  },
  {
    id: 'rbw',
    label: 'RBW',
    value: '100 kHz',
    note: 'resolution model',
    state: 'derived',
  },
  {
    id: 'noise',
    label: 'Noise floor',
    value: '-108 dBm',
    note: 'synthetic receiver floor',
    state: 'derived',
  },
  {
    id: 'evm',
    label: 'EVM',
    value: '2.8 %',
    note: 'modulation quality placeholder',
    state: 'derived',
  },
  {
    id: 'pipeline',
    label: 'Pipeline',
    value: 'FFT · IQ · Waterfall',
    note: 'React-governed visual chain',
    state: 'ready',
  },
]

export const signalAnalyzerMeasurements: SignalAnalyzerMeasurement[] = [
  {
    id: 'fft-bin',
    label: 'FFT bin width',
    expression: 'Δf = fs / N',
    meaning: 'Frequency spacing between adjacent FFT bins.',
    unit: 'Hz',
  },
  {
    id: 'dbfs',
    label: 'Amplitude reference',
    expression: 'A(dBFS) = 20log10(|X[k]| / FullScale)',
    meaning: 'Digital full-scale normalized amplitude reference.',
    unit: 'dBFS',
  },
  {
    id: 'dbm',
    label: 'RF power display',
    expression: 'P(dBm) = 10log10(PmW)',
    meaning: 'RF power representation used in spectrum and receiver displays.',
    unit: 'dBm',
  },
  {
    id: 'evm',
    label: 'Error Vector Magnitude',
    expression: 'EVM% = RMS(error vector) / RMS(reference vector) · 100',
    meaning: 'Vector modulation quality metric for IQ constellations.',
    unit: '%',
  },
  {
    id: 'obw',
    label: 'Occupied bandwidth',
    expression: 'OBW = f_high − f_low at target integrated power',
    meaning: 'Bandwidth occupied by a defined percentage of total signal power.',
    unit: 'Hz',
  },
  {
    id: 'aclr',
    label: 'Adjacent Channel Leakage Ratio',
    expression: 'ACLR = P_main / P_adjacent',
    meaning: 'Spectral leakage indicator for adjacent-channel compliance reasoning.',
    unit: 'dB',
  },
]

export const signalAnalyzerScenarios: SignalAnalyzerScenario[] = [
  {
    id: 'spectrum-baseline',
    title: 'Spectrum baseline',
    objective: 'Validate span, center frequency, noise floor and peak markers.',
    evidence: 'Spectrum trace + KPI strip + formula registry.',
  },
  {
    id: 'iq-quality',
    title: 'IQ quality review',
    objective: 'Interpret constellation stability and EVM placeholder metrics.',
    evidence: 'Constellation panel + EVM card + measurement registry.',
  },
  {
    id: 'waterfall-evolution',
    title: 'Waterfall time evolution',
    objective: 'Show time-frequency persistence and burst behavior.',
    evidence: 'Canvas waterfall + spectral event tags.',
  },
]
