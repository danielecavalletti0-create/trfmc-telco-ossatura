import { RFPhysicsFieldCanvasP1 } from './RFPhysicsFieldCanvasP1'
import {
  rfPhysicsFormulas,
  rfPhysicsKpis,
  rfPhysicsPromotionSource,
  rfPhysicsScenarios,
} from './rfPhysicsRegistry'

export function RFPhysicsDomainP1() {
  return (
    <section className="trfmc-p1-rf-domain" data-trfmc-p1-rf-physics-domain="mounted">
      <div className="trfmc-p1-rf-head">
        <div>
          <p>P1B · RF Physics React Promotion</p>
          <h2>RF Physics · Maxwell, propagazione, link budget, campo</h2>
          <span>
            Primo dominio tecnico promosso dal materiale RF Physics selezionato in P1A.
            Le formule, il modello visuale e gli scenari sono ora componenti React governati,
            non una pagina HTML pubblica montata in parallelo.
          </span>
        </div>
        <article>
          <strong>{rfPhysicsPromotionSource.sourceScore}</strong>
          <span>source score</span>
          <em>{rfPhysicsPromotionSource.selectedSource}</em>
        </article>
      </div>

      <div className="trfmc-p1-rf-kpi-grid">
        {rfPhysicsKpis.map((kpi) => (
          <article key={kpi.id} data-state={kpi.state}>
            <span>{kpi.label}</span>
            <strong>{kpi.value}</strong>
            <em>{kpi.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p1-rf-main-grid">
        <section className="trfmc-p1-rf-panel trfmc-p1-rf-canvas-panel">
          <div className="trfmc-p1-rf-panel-head">
            <span>Visual engine</span>
            <b>React Canvas field model</b>
          </div>
          <RFPhysicsFieldCanvasP1 />
        </section>

        <section className="trfmc-p1-rf-panel">
          <div className="trfmc-p1-rf-panel-head">
            <span>Formula registry</span>
            <b>engineering formulas</b>
          </div>
          <div className="trfmc-p1-rf-formula-grid">
            {rfPhysicsFormulas.map((formula) => (
              <article key={formula.id}>
                <span>{formula.label}</span>
                <strong>{formula.expression}</strong>
                <p>{formula.meaning}</p>
                <em>{formula.unit}</em>
              </article>
            ))}
          </div>
        </section>
      </div>

      <section className="trfmc-p1-rf-panel">
        <div className="trfmc-p1-rf-panel-head">
          <span>Scenario binding</span>
          <b>RF Physics evidence chain</b>
        </div>
        <div className="trfmc-p1-rf-scenario-grid">
          {rfPhysicsScenarios.map((scenario) => (
            <article key={scenario.id}>
              <strong>{scenario.title}</strong>
              <span>{scenario.objective}</span>
              <em>{scenario.evidence}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p1-rf-acceptance">
        <span>Acceptance rule</span>
        <strong>
          Build + HTTP + DOM marker + screenshot + static safety gate. No iframe, no unsafe HTML injection,
          no public HTML runtime link.
        </strong>
      </section>
    </section>
  )
}
