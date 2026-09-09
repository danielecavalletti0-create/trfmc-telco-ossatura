import { useRFSpectrumSweep } from '../rf_instruments/hooks/useRFSpectrumSweep'
import { RFEngineeringMath3DPanelV1 } from '../rf_instruments/panels/RFEngineeringMath3DPanelV1'
import { useState } from 'react'
import { RFSignalAnalyzerWorkbenchV3 } from '../rf_instruments/instruments/RFSignalAnalyzerWorkbenchV3'
import { RFInstrumentDockV4 } from '../rf_instruments/instruments/RFInstrumentDockV4'
import { TrueSpectrumAnalyzer } from '../rf_instruments/instruments/TrueSpectrumAnalyzer'

const tabs = [
  { id: 'workbench', label: 'VSA Workbench', note: 'DSP worker · Spectrum · Waterfall · I/Q' },
  { id: 'dock', label: 'RF Instrument Dock', note: 'VSA surface · markers · measurements' },
  { id: 'spectrum', label: 'True Spectrum', note: 'Realtime FFT console baseline' },
] as const

const theory = [
  { k: 'FFT', v: 'time-domain IQ → frequency bins', q: 'N=4096 · windowed detector' },
  { k: 'I/Q', v: 'complex baseband representation', q: 'constellation + error vectors' },
  { k: 'SNR', v: 'signal/noise quality metric', q: 'dB evidence indicator' },
  { k: 'EVM', v: 'modulation quality / error vector', q: 'digital RF KPI' },
]

const contracts = [
  { k: 'Route', v: '#full-engineering-stack', state: 'mounted' },
  { k: 'API', v: '/api/rfpro/spectrum/sweep', state: 'contract' },
  { k: 'Source', v: 'synthetic IQ / future bridge', state: 'safe' },
  { k: 'QA', v: 'build + HTTP + screenshot + DOM', state: 'required' },
]

const scenarios = [
  'Controlled RF sweep validation',
  'Synthetic OFDM / FHSS visual classification',
  'I/Q constellation degradation evidence',
  'Spectrum + waterfall persistence review',
]

export function RFSignalAnalyzerPromotionV1() {
  const [active, setActive] = useState<(typeof tabs)[number]['id']>('workbench')
  const rfSweep = useRFSpectrumSweep({ enabled: true, intervalMs: 2200, endpoint: 'http://127.0.0.1:4181/api/rfpro/spectrum/sweep' })

  return (
    <section className="trfmc-rf-promo-v1" data-trfmc-rf-signal-promotion-v1="mounted">
      <div className="trfmc-rf-promo-head">
        <div>
          <p className="trfmc-rf-promo-kicker">Batch 1 · RF Physics / Signal Analyzer Promotion</p>
          <h2>RF Signal Analyzer: teoria, DSP, visual asset, contract, scenario, QA</h2>
          <p>
            Primo innesto tecnico reale nella console Engineering V5: il modulo RF/Signal viene promosso
            da candidato a strumento sorgente React, senza iframe e senza pagine pubbliche parallele.
          </p>
        </div>
        <div className="trfmc-rf-promo-readiness">
          <strong>V1</strong>
          <span>source promoted</span>
        </div>
      </div>

      <div className="trfmc-rf-promo-grid">
        <section className="trfmc-rf-promo-panel">
          <div className="trfmc-rf-promo-panel-head">
            <span>Theory binding</span>
            <b>RF physics</b>
          </div>
          <div className="trfmc-rf-theory-grid">
            {theory.map((item) => (
              <article className="trfmc-rf-theory-card" key={item.k}>
                <strong>{item.k}</strong>
                <span>{item.v}</span>
                <em>{item.q}</em>
              </article>
            ))}
          </div>
        </section>

        <section className="trfmc-rf-promo-panel">
          <div className="trfmc-rf-promo-panel-head">
            <span>Runtime contracts</span>
            <b>readonly bridge</b>
          </div>
          <div className="trfmc-rf-contract-grid">
            {contracts.map((item) => (
              <article className="trfmc-rf-contract-card" key={item.k}>
                <span>{item.k}</span>
                <strong>{item.v}</strong>
                <em>{item.state}</em>
              </article>
            ))}
          </div>
        </section>
      </div>

      <RFEngineeringMath3DPanelV1
        snapshot={rfSweep.snapshot}
        loading={rfSweep.loading}
        error={rfSweep.error}
        status={rfSweep.status}
      />

      <section className="trfmc-rf-promo-panel trfmc-rf-instrument-panel">
        <div className="trfmc-rf-promo-panel-head">
          <span>Instrument selector</span>
          <b>Canvas / DSP source modules</b>
        </div>

        <div className="trfmc-rf-tabbar" role="tablist" aria-label="RF Signal Analyzer instruments">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              className={active === tab.id ? 'active' : ''}
              type="button"
              onClick={() => setActive(tab.id)}
            >
              <strong>{tab.label}</strong>
              <span>{tab.note}</span>
            </button>
          ))}
        </div>

        <div className="trfmc-rf-instrument-stage">
          {active === 'workbench' ? <RFSignalAnalyzerWorkbenchV3 /> : null}
          {active === 'dock' ? <RFInstrumentDockV4 /> : null}
          {active === 'spectrum' ? <TrueSpectrumAnalyzer /> : null}
        </div>
      </section>

      <section className="trfmc-rf-promo-panel trfmc-rf-scenario-panel">
        <div className="trfmc-rf-promo-panel-head">
          <span>Scenario binding</span>
          <b>acceptance evidence</b>
        </div>
        <div className="trfmc-rf-scenario-grid">
          {scenarios.map((scenario) => (
            <article key={scenario}>
              <strong>{scenario}</strong>
              <span>Required evidence: screenshot, route marker, API contract and no iframe/public-page fallback.</span>
            </article>
          ))}
        </div>
      </section>
    </section>
  )
}
