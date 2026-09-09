const contractRows = [
  { label: 'Frontend route', value: '127.0.0.1:5173', state: 'PASS' },
  { label: 'Bridge API', value: '127.0.0.1:4181', state: 'PASS' },
  { label: 'Backend API', value: '127.0.0.1:8000', state: 'PASS' },
  { label: 'Runtime mode', value: 'readonly / no backend mutation', state: 'LOCKED' },
]

const domains = [
  { id: '01', title: 'Mission Control', status: 'baseline', focus: 'operator state, readiness, evidence' },
  { id: '02', title: 'RF Physics', status: 'to promote', focus: 'Maxwell, FFT, I/Q, dB, SNR, EVM' },
  { id: '03', title: 'Signal Analyzer', status: 'to promote', focus: 'spectrum, waterfall, IQ, constellation' },
  { id: '04', title: 'RF / Microwave', status: 'to promote', focus: 'Smith chart, link budget, waveguide, filters' },
  { id: '05', title: 'Antenna System', status: 'to promote', focus: 'array, pattern, gain, RET/AISG, CPRI mapping' },
  { id: '06', title: 'Fiber Optic', status: 'to promote', focus: 'OTDR, ODF, attenuation, splice loss' },
  { id: '07', title: '5G Core / RAN', status: 'critical', focus: 'Open5GS, UERANSIM, NAS, NGAP, PFCP, GTP-U' },
  { id: '08', title: 'Cyber RF Intelligence', status: 'locked', focus: 'evidence, restricted areas, safe readonly workflows' },
]

const matrix = [
  ['Theory', 'partial', 'RF/Telco formulas must be indexed per module'],
  ['Simulator', 'partial', 'visual engines must bind to operational scenarios'],
  ['Endpoint', 'partial', '4181/8000 contracts must be mapped per module'],
  ['Visual Asset', 'review', 'promote real interactive assets, archive duplicates'],
  ['Scenario', 'review', 'scenario cards must drive evidence and QA'],
  ['QA Gate', 'active', 'build, HTTP, screenshot gate already present'],
]

const qa = [
  { k: 'Build', v: 'PASS' },
  { k: 'HTTP', v: '0 non-200' },
  { k: 'Screenshot', v: 'PASS' },
  { k: 'V51 residues', v: 'quarantined' },
  { k: 'Runtime injection', v: 'none' },
  { k: 'Source mode', v: 'React/Vite' },
]

export function EngineeringConsoleExpansionV4() {
  return (
    <section className="trfmc-eng-v4" aria-label="TRFMC Engineering Console Expansion">
      <div className="trfmc-eng-v4-top">
        <div>
          <p className="trfmc-eng-v4-kicker">TRFMC V4 · Engineering Console Expansion</p>
          <h2>Completion cockpit: domini, contratti, QA, promozione moduli</h2>
          <p>
            Questa sezione trasforma la vista Engineering da semplice scheda V49 a console di governo:
            ogni dominio deve convergere su teoria, simulatore, endpoint, asset, scenario e collaudo.
          </p>
        </div>
        <div className="trfmc-eng-v4-score">
          <strong>12</strong>
          <span>target domains</span>
        </div>
      </div>

      <div className="trfmc-eng-v4-grid trfmc-eng-v4-grid-contracts">
        {contractRows.map((row) => (
          <article className="trfmc-eng-v4-card trfmc-eng-v4-contract" key={row.label}>
            <span>{row.label}</span>
            <strong>{row.value}</strong>
            <em data-state={row.state}>{row.state}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-eng-v4-split">
        <section className="trfmc-eng-v4-panel">
          <div className="trfmc-eng-v4-panel-head">
            <span>Domain promotion board</span>
            <b>React source of truth</b>
          </div>
          <div className="trfmc-eng-v4-domain-grid">
            {domains.map((domain) => (
              <article className="trfmc-eng-v4-domain" key={domain.id}>
                <div>
                  <span>{domain.id}</span>
                  <h3>{domain.title}</h3>
                </div>
                <em data-status={domain.status}>{domain.status}</em>
                <p>{domain.focus}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="trfmc-eng-v4-panel">
          <div className="trfmc-eng-v4-panel-head">
            <span>Engineering completeness matrix</span>
            <b>module acceptance rule</b>
          </div>
          <div className="trfmc-eng-v4-matrix">
            {matrix.map(([name, state, note]) => (
              <div className="trfmc-eng-v4-matrix-row" key={name}>
                <strong>{name}</strong>
                <em data-state={state}>{state}</em>
                <span>{note}</span>
              </div>
            ))}
          </div>
        </section>
      </div>

      <section className="trfmc-eng-v4-panel trfmc-eng-v4-qa">
        <div className="trfmc-eng-v4-panel-head">
          <span>Evidence and quality strip</span>
          <b>current baseline: Engineering Only V3</b>
        </div>
        <div className="trfmc-eng-v4-qa-grid">
          {qa.map((item) => (
            <div className="trfmc-eng-v4-qa-item" key={item.k}>
              <span>{item.k}</span>
              <strong>{item.v}</strong>
            </div>
          ))}
        </div>
      </section>
    </section>
  )
}
