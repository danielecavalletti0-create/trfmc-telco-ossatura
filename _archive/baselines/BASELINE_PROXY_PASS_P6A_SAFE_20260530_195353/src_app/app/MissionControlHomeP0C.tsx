const homeKpis = [
  { label: 'Mission scope', value: 'RF · Telco · SOC/NOC', note: 'single operational cockpit' },
  { label: 'Portal mode', value: 'React SPA', note: 'public HTML is source material' },
  { label: 'Runtime chain', value: '5173 · 4181 · 8000', note: 'frontend + bridges + backend' },
  { label: 'Baseline', value: 'P0B ready', note: 'canonical domain registry mounted' },
]

const operatingPrinciples = [
  'One shell, one registry, one navigational truth.',
  'Mission Control governs domains before deep instrumentation.',
  'HTML sources are promoted into React components, never mounted as parallel portals.',
  'Every promoted section must pass build, HTTP, DOM marker, screenshot and debt gates.',
]

export function MissionControlHomeP0C() {
  return (
    <section className="trfmc-p0c-home" data-trfmc-p0c-home="mounted">
      <div className="trfmc-p0c-section-head">
        <p>P0C · Home promotion</p>
        <h3>RF / Telco Mission Control</h3>
        <span>
          Sintesi operativa estratta dalla home pubblica: il portale viene riportato dentro una
          singola console React, con governance dei domini, runtime chiari e promozione controllata.
        </span>
      </div>

      <div className="trfmc-p0c-kpi-grid">
        {homeKpis.map((item) => (
          <article key={item.label}>
            <span>{item.label}</span>
            <strong>{item.value}</strong>
            <em>{item.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p0c-principles">
        {operatingPrinciples.map((item) => (
          <div key={item}>
            <b>✓</b>
            <span>{item}</span>
          </div>
        ))}
      </div>
    </section>
  )
}
