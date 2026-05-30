const integrationRows = [
  {
    area: 'Frontend shell',
    status: 'P0B PASS',
    evidence: 'Canonical registry mounted in Mission Overview',
    next: 'Promote Mission Control content without iframe',
  },
  {
    area: 'Source discipline',
    status: 'ACTIVE',
    evidence: 'No backend, index or public asset mutation in P0C',
    next: 'Convert source structure into typed React cards',
  },
  {
    area: 'Runtime contract',
    status: 'OBSERVED',
    evidence: '5173 / 4181 / 8000 checked by gate',
    next: 'Bind APIs only after domain content is promoted',
  },
  {
    area: 'Debt control',
    status: 'ENFORCED',
    evidence: 'legacy DOM injection and embedded scripts remain source-only references',
    next: 'No dangerous HTML injection in promoted components',
  },
]

const priorityQueue = [
  'Mission Control home and integration room',
  'Portal index and domain navigation',
  'RF Physics and Signal Analyzer domain entries',
  'Antenna System and 5G Core/RAN domain entries',
]

export function MissionControlIntegrationRoomP0C() {
  return (
    <section className="trfmc-p0c-room" data-trfmc-p0c-integration-room="mounted">
      <div className="trfmc-p0c-section-head">
        <p>P0C · Integration Control Room</p>
        <h3>Control room di integrazione</h3>
        <span>
          Conversione controllata della Control Room: stato, evidenze, priorità e prossima azione,
          senza importare script legacy o manipolazioni DOM.
        </span>
      </div>

      <div className="trfmc-p0c-integration-table" role="table" aria-label="P0C integration status">
        <div className="trfmc-p0c-table-row trfmc-p0c-table-head" role="row">
          <span>Area</span>
          <span>Status</span>
          <span>Evidence</span>
          <span>Next action</span>
        </div>
        {integrationRows.map((row) => (
          <div className="trfmc-p0c-table-row" role="row" key={row.area}>
            <strong>{row.area}</strong>
            <em>{row.status}</em>
            <span>{row.evidence}</span>
            <span>{row.next}</span>
          </div>
        ))}
      </div>

      <div className="trfmc-p0c-priority-strip">
        {priorityQueue.map((item, index) => (
          <article key={item}>
            <small>P{index}</small>
            <strong>{item}</strong>
          </article>
        ))}
      </div>
    </section>
  )
}
