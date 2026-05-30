const portalDomains = [
  { id: '01', label: 'Mission Control', route: '#mission-overview', readiness: 'promoted' },
  { id: '02', label: 'RF Physics', route: '#rf-physics', readiness: 'queued' },
  { id: '03', label: 'Signal Analyzer', route: '#signal-analyzer', readiness: 'queued' },
  { id: '04', label: 'RF/Microwave', route: '#rf-microwave', readiness: 'queued' },
  { id: '05', label: 'Antenna System', route: '#antenna-system', readiness: 'queued' },
  { id: '06', label: 'Microwave Link', route: '#microwave-link', readiness: 'placeholder' },
  { id: '07', label: 'Fiber Optic', route: '#fiber-optic', readiness: 'queued' },
  { id: '08', label: 'Private Networks', route: '#private-networks', readiness: 'queued' },
  { id: '09', label: 'Core/RAN', route: '#core-network', readiness: 'queued' },
  { id: '10', label: 'Data Center', route: '#data-center', readiness: 'placeholder' },
  { id: '11', label: 'Cyber RF Intelligence', route: '#cyber-rf-intelligence', readiness: 'queued' },
  { id: '12', label: 'Knowledge Base', route: '#knowledge-base', readiness: 'queued' },
]

const promotionRules = [
  'Promote domain content into React components.',
  'Keep source HTML as reference evidence, not runtime content.',
  'Reject iframe, legacy DOM injection and runtime public patching.',
  'Attach every domain to QA gates before calling it complete.',
]

export function MissionControlPortalIndexP0C() {
  return (
    <section className="trfmc-p0c-index" data-trfmc-p0c-portal-index="mounted">
      <div className="trfmc-p0c-section-head">
        <p>P0C · Portal index promotion</p>
        <h3>Indice operativo dei domini</h3>
        <span>
          Estratto concettuale del Portal Index: non replica il DOM legacy, ma porta nel portale
          ufficiale route, readiness e regole di promozione.
        </span>
      </div>

      <div className="trfmc-p0c-domain-lattice">
        {portalDomains.map((domain) => (
          <a key={domain.id} href={domain.route} className={`trfmc-p0c-domain-node ${domain.readiness}`}>
            <small>{domain.id}</small>
            <strong>{domain.label}</strong>
            <span>{domain.readiness}</span>
          </a>
        ))}
      </div>

      <div className="trfmc-p0c-rule-grid">
        {promotionRules.map((rule) => (
          <article key={rule}>
            <span>rule</span>
            <strong>{rule}</strong>
          </article>
        ))}
      </div>
    </section>
  )
}
