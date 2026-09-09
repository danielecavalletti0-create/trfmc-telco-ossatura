import { AntennaRadiationCanvasP3 } from './AntennaRadiationCanvasP3'
import {
  antennaPortMap,
  antennaScenarios,
  antennaSystemKpis,
  antennaSystemMetrics,
  antennaSystemPromotionSource,
} from './antennaSystemRegistry'

export function AntennaSystemDomainP3() {
  return (
    <section className="trfmc-p3-antenna-domain" data-trfmc-p3-antenna-system-domain="mounted">
      <div className="trfmc-p3-antenna-head">
        <div>
          <p>P3B · Antenna System React Promotion</p>
          <h2>Antenna System · Radiation Pattern, RRU, RET, CPRI, AISG</h2>
          <span>
            Dominio Antenna System promosso dal candidato P3A. La vista porta nel portale React
            pattern di radiazione, KPI antenna, mapping RRU/RET/CPRI/AISG e scenari di collaudo.
          </span>
        </div>
        <article>
          <strong>{antennaSystemPromotionSource.sourceScore}</strong>
          <span>source score</span>
          <em>{antennaSystemPromotionSource.selectedSource}</em>
        </article>
      </div>

      <div className="trfmc-p3-antenna-kpi-grid">
        {antennaSystemKpis.map((kpi) => (
          <article key={kpi.id} data-state={kpi.state}>
            <span>{kpi.label}</span>
            <strong>{kpi.value}</strong>
            <em>{kpi.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p3-antenna-main-grid">
        <section className="trfmc-p3-antenna-panel trfmc-p3-antenna-canvas-panel">
          <div className="trfmc-p3-antenna-panel-head">
            <span>Visual model</span>
            <b>React Canvas · radiation / sector / port mapping</b>
          </div>
          <AntennaRadiationCanvasP3 />
        </section>

        <section className="trfmc-p3-antenna-panel">
          <div className="trfmc-p3-antenna-panel-head">
            <span>Engineering registry</span>
            <b>gain · HPBW · RET · EIRP</b>
          </div>
          <div className="trfmc-p3-antenna-metric-grid">
            {antennaSystemMetrics.map((item) => (
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

      <section className="trfmc-p3-antenna-panel">
        <div className="trfmc-p3-antenna-panel-head">
          <span>RRU / RET / CPRI / AISG</span>
          <b>port mapping traceability</b>
        </div>
        <div className="trfmc-p3-antenna-port-grid">
          {antennaPortMap.map((port) => (
            <article key={port.id}>
              <span>{port.chain}</span>
              <strong>{port.rruPort}</strong>
              <p>{port.cpri} · {port.ret} · {port.aisg}</p>
              <em>{port.polarization} · {port.note}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p3-antenna-panel">
        <div className="trfmc-p3-antenna-panel-head">
          <span>Scenario binding</span>
          <b>antenna evidence chain</b>
        </div>
        <div className="trfmc-p3-antenna-scenario-grid">
          {antennaScenarios.map((scenario) => (
            <article key={scenario.id}>
              <strong>{scenario.title}</strong>
              <span>{scenario.objective}</span>
              <em>{scenario.evidence}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p3-antenna-acceptance">
        <span>Acceptance rule</span>
        <strong>
          Build + HTTP + DOM marker + screenshot + static safety gate. No iframe, no unsafe HTML injection,
          no public HTML runtime link.
        </strong>
      </section>
    </section>
  )
}
