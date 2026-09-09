import { SignalAnalyzerCanvasP2 } from './SignalAnalyzerCanvasP2'
import {
  signalAnalyzerKpis,
  signalAnalyzerMeasurements,
  signalAnalyzerPromotionSource,
  signalAnalyzerScenarios,
} from './signalAnalyzerRegistry'

export function SignalAnalyzerDomainP2() {
  return (
    <section className="trfmc-p2-signal-domain" data-trfmc-p2-signal-analyzer-domain="mounted">
      <div className="trfmc-p2-signal-head">
        <div>
          <p>P2B · Signal Analyzer React Promotion</p>
          <h2>Signal Analyzer · Spectrum, Waterfall, IQ, FFT, EVM</h2>
          <span>
            Dominio Signal Analyzer promosso dal cockpit P2A selezionato. Il contenuto legacy viene
            convertito in componenti React governati: KPI, registry misure, canvas visuale e scenari.
          </span>
        </div>
        <article>
          <strong>{signalAnalyzerPromotionSource.sourceScore}</strong>
          <span>source score</span>
          <em>{signalAnalyzerPromotionSource.selectedSource}</em>
        </article>
      </div>

      <div className="trfmc-p2-signal-kpi-grid">
        {signalAnalyzerKpis.map((kpi) => (
          <article key={kpi.id} data-state={kpi.state}>
            <span>{kpi.label}</span>
            <strong>{kpi.value}</strong>
            <em>{kpi.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p2-signal-main-grid">
        <section className="trfmc-p2-signal-panel trfmc-p2-signal-canvas-panel">
          <div className="trfmc-p2-signal-panel-head">
            <span>Visual chain</span>
            <b>React Canvas · spectrum / waterfall / IQ</b>
          </div>
          <SignalAnalyzerCanvasP2 />
        </section>

        <section className="trfmc-p2-signal-panel">
          <div className="trfmc-p2-signal-panel-head">
            <span>Measurement registry</span>
            <b>FFT · EVM · OBW · ACLR</b>
          </div>
          <div className="trfmc-p2-signal-measure-grid">
            {signalAnalyzerMeasurements.map((item) => (
              <article key={item.id}>
                <span>{item.label}</span>
                <strong>{item.expression}</strong>
                <p>{item.meaning}</p>
                <em>{item.unit}</em>
              </article>
            ))}
          </div>
        </section>
      </div>

      <section className="trfmc-p2-signal-panel">
        <div className="trfmc-p2-signal-panel-head">
          <span>Scenario binding</span>
          <b>instrument evidence chain</b>
        </div>
        <div className="trfmc-p2-signal-scenario-grid">
          {signalAnalyzerScenarios.map((scenario) => (
            <article key={scenario.id}>
              <strong>{scenario.title}</strong>
              <span>{scenario.objective}</span>
              <em>{scenario.evidence}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p2-signal-acceptance">
        <span>Acceptance rule</span>
        <strong>
          Build + HTTP + DOM marker + screenshot + static safety gate. No iframe, no unsafe HTML injection,
          no public HTML runtime link.
        </strong>
      </section>
    </section>
  )
}
