import { TRFMC_CANONICAL_DOMAINS, TRFMC_P0_GOVERNANCE, TRFMC_P0_SHELL_CANDIDATES } from './portalRegistry'

function statusLabel(status: string) {
  if (status === 'P0_READY') return 'ready'
  return 'placeholder'
}

export function PortalShellNavigationP0() {
  const ready = TRFMC_CANONICAL_DOMAINS.filter((item) => item.status === 'P0_READY').length
  const placeholders = TRFMC_CANONICAL_DOMAINS.length - ready
  const totalCandidates = TRFMC_CANONICAL_DOMAINS.reduce((sum, item) => sum + item.candidateCount, 0)

  return (
    <section className="trfmc-p0b-shell-nav" data-trfmc-p0b-portal-navigation="mounted">
      <div className="trfmc-p0b-shell-nav-head">
        <div>
          <p>TRFMC P0B · Canonical Portal Registry</p>
          <h2>Portale unico: shell, domini, promozione controllata</h2>
          <span>
            Il portale riparte da un registry sorgente React: gli HTML pubblici sono fonti da promuovere,
            non portali paralleli. Ogni dominio ha route, candidato primario e azione di integrazione.
          </span>
        </div>
        <div className="trfmc-p0b-kpi-strip">
          <strong>{TRFMC_CANONICAL_DOMAINS.length}</strong>
          <span>domains</span>
          <strong>{ready}</strong>
          <span>ready</span>
          <strong>{placeholders}</strong>
          <span>placeholder</span>
        </div>
      </div>

      <div className="trfmc-p0b-domain-grid" aria-label="TRFMC canonical domain registry">
        {TRFMC_CANONICAL_DOMAINS.map((domain) => (
          <a
            key={domain.domain}
            className={`trfmc-p0b-domain-card ${domain.status === 'P0_READY' ? 'ready' : 'placeholder'}`}
            href={domain.routeHash}
            title={domain.primaryCandidate}
          >
            <small>{domain.order} · {statusLabel(domain.status)}</small>
            <strong>{domain.label}</strong>
            <span>{domain.purpose}</span>
            <em>{domain.candidateCount} candidate · {domain.nextAction}</em>
          </a>
        ))}
      </div>

      <div className="trfmc-p0b-governance-row">
        <article>
          <span>Governance</span>
          <strong>{TRFMC_P0_GOVERNANCE.phase}</strong>
          <p>{TRFMC_P0_GOVERNANCE.shellRule}</p>
        </article>
        <article>
          <span>P0 shell sources</span>
          <strong>{TRFMC_P0_SHELL_CANDIDATES.length} selected</strong>
          <p>{TRFMC_P0_SHELL_CANDIDATES.map((candidate) => candidate.priority).join(' · ')}</p>
        </article>
        <article>
          <span>Candidate mass</span>
          <strong>{totalCandidates}</strong>
          <p>Promote by domain, not by random patch.</p>
        </article>
      </div>
    </section>
  )
}
