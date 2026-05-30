import { useEffect, useMemo, useState } from 'react'
import { VisualAssetRuntimeV41 } from '../visual_assets/VisualAssetRuntimeV41'
import { ScenarioKnowledgeBindingV40 } from '../knowledge_binding/ScenarioKnowledgeBindingV40'
import { NavigationMapV39 } from '../navigation/NavigationMapV39'
import { CommandCenterFusionV37 } from '../command_center/CommandCenterFusionV37'
import { RFDynamicScenarioDeckV36 } from '../rf_scenarios/RFDynamicScenarioDeckV36'
import { RFOperationalDeckV41VisualAssetFusion } from '../rf_instruments/instruments/RFOperationalDeckV41VisualAssetFusion'
import { EngineeringContentEnrichmentV49 } from './EngineeringContentEnrichmentV49'
import { PortalShellNavigationP0 } from '../app/PortalShellNavigationP0'
import { MissionControlContentP0C } from '../app/MissionControlContentP0C'
import { RFPhysicsRouteP1 } from '../app/RFPhysicsRouteP1'
import { SignalAnalyzerRouteP2 } from '../app/SignalAnalyzerRouteP2'

const trfmcV49ResolveEnrichmentSectionFromHash = (activeSection: string) => {
  if (typeof window !== 'undefined') {
    const raw = window.location.hash.replace(/^#\/?/, '').trim().toLowerCase()
    const first = raw.split('/')[0]

    if (first === 'full-engineering-stack' || first === 'full-engineering' || first === 'engineering-stack') {
      return 'full-engineering-stack'
    }

    if (first === 'mission-overview' || first === 'mission' || first === 'mission-control' || first === 'overview') {
      return 'mission-overview'
    }

    if (first === 'visual-assets' || first === 'visual' || first === 'assets') {
      return 'visual-assets'
    }

    if (first === 'scenario-knowledge' || first === 'scenario' || first === 'knowledge') {
      return 'scenario-knowledge'
    }

    if (first === 'navigation-architecture' || first === 'navigation' || first === 'architecture') {
      return 'navigation-architecture'
    }

    if (first === 'command-center' || first === 'command') {
      return 'command-center'
    }

    if (first === 'dynamic-scenarios' || first === 'dynamic' || first === 'scenarios') {
      return 'dynamic-scenarios'
    }
  }

  if (activeSection === 'full-engineering' || activeSection === 'full-engineering-stack') return 'full-engineering-stack'
  return activeSection || 'mission-overview'
}


const trfmcV46SectionAliases: Record<string, string> = {
  'mission': 'mission-overview',
  'mission-control': 'mission-overview',
  'mission-overview': 'mission-overview',
  'overview': 'mission-overview',
  'visual': 'visual-assets',
  'visual-assets': 'visual-assets',
  'assets': 'visual-assets',
  'scenario': 'scenario-knowledge',
  'scenarios': 'dynamic-scenarios',
  'scenario-knowledge': 'scenario-knowledge',
  'knowledge': 'scenario-knowledge',
  'navigation': 'navigation-architecture',
  'navigation-architecture': 'navigation-architecture',
  'command': 'command-center',
  'command-center': 'command-center',
  'dynamic': 'dynamic-scenarios',
  'dynamic-scenarios': 'dynamic-scenarios',
  'engineering': 'full-engineering-stack',
  'full-engineering': 'full-engineering-stack',
  'engineering-stack': 'full-engineering-stack',
  'full-engineering-stack': 'full-engineering-stack',
}

const trfmcV46NavigationIndex = [
  { id: 'mission-overview', label: 'Mission Overview', hash: '#mission-overview' },
  { id: 'visual-assets', label: 'Visual Assets', hash: '#visual-assets' },
  { id: 'scenario-knowledge', label: 'Scenario Knowledge', hash: '#scenario-knowledge' },
  { id: 'navigation-architecture', label: 'Navigation Architecture', hash: '#navigation-architecture' },
  { id: 'command-center', label: 'Command Center', hash: '#command-center' },
  { id: 'dynamic-scenarios', label: 'Dynamic Scenarios', hash: '#dynamic-scenarios' },
  { id: 'full-engineering-stack', label: 'Full Engineering Stack', hash: '#full-engineering-stack' },
]

const trfmcV46NormalizeHashToSection = () => {
  if (typeof window === 'undefined') return 'mission-overview'
  const raw = window.location.hash.replace(/^#\/?/, '').trim().toLowerCase()
  const first = raw.split('/')[0]
  return trfmcV46SectionAliases[first] ?? 'mission-overview'
}

const trfmcV46WriteHashForSection = (sectionId: string) => {
  if (typeof window === 'undefined') return
  const normalized = trfmcV46SectionAliases[sectionId] ?? sectionId
  const nextHash = `#${normalized}`
  if (window.location.hash !== nextHash) {
    window.history.replaceState(null, '', nextHash)
  }
}


const resolveV42InitialSectionFromHash = () => {
  if (typeof window === 'undefined') return 'mission-overview'
  const hash = window.location.hash.replace(/^#\/?/, '').trim().toLowerCase()
  if (hash === 'visual-assets' || hash.startsWith('visual-assets/')) return 'visual-assets'
  if (hash === 'scenario-knowledge') return 'scenario-knowledge'
  if (hash === 'navigation-architecture') return 'navigation-architecture'
  if (hash === 'command-center') return 'command-center'
  if (hash === 'dynamic-scenarios') return 'dynamic-scenarios'
  if (hash === 'full-engineering-stack') return 'full-engineering-stack'
  return 'mission-overview'
}


type SectionIdV42 =
  | 'mission'
  | 'visual-assets'
  | 'knowledge'
  | 'navigation'
  | 'command'
  | 'scenarios'
  | 'full-engineering'

type SectionV42 = {
  id: SectionIdV42
  title: string
  subtitle: string
  badge: string
  priority: 'executive' | 'engineering' | 'deep'
}


function sectionFromHashV45(hashValue = window.location.hash): SectionIdV42 {
  const clean = hashValue.replace(/^#\/?/, '').trim()
  const first = clean.split('/')[0]

  if (first === 'visual-assets') return 'visual-assets'
  if (first === 'scenario-knowledge' || first === 'knowledge') return 'knowledge'
  if (first === 'navigation' || first === 'navigation-architecture') return 'navigation'
  if (first === 'command' || first === 'command-center') return 'command'
  if (first === 'scenarios' || first === 'dynamic-scenarios') return 'scenarios'
  if (first === 'full-engineering' || first === 'engineering') return 'full-engineering'
  if (first === 'mission' || first === 'mission-control') return 'mission'

  return 'mission'
}

function hashForSectionV45(sectionId: SectionIdV42) {
  if (sectionId === 'knowledge') return '#scenario-knowledge'
  if (sectionId === 'navigation') return '#navigation'
  if (sectionId === 'command') return '#command-center'
  if (sectionId === 'scenarios') return '#dynamic-scenarios'
  if (sectionId === 'full-engineering') return '#full-engineering'
  if (sectionId === 'visual-assets') return '#visual-assets'
  return '#mission'
}

const sections: SectionV42[] = [
  {
    id: 'mission',
    title: 'Mission Overview',
    subtitle: 'Vista compatta dello stato portale e della catena V42→V41→V40→V39→V37.',
    badge: 'compact',
    priority: 'executive',
  },
  {
    id: 'visual-assets',
    title: 'Visual Assets',
    subtitle: 'Registry visuale, fallback SVG, asset sostituibili con render reali.',
    badge: 'V41',
    priority: 'engineering',
  },
  {
    id: 'knowledge',
    title: 'Scenario Knowledge',
    subtitle: 'Dominio → scenario → teoria → formule → strumenti → evidenze.',
    badge: 'V40',
    priority: 'engineering',
  },
  {
    id: 'navigation',
    title: 'Navigation Architecture',
    subtitle: 'Mappa ufficiale dei 12 domini del portale.',
    badge: 'V39',
    priority: 'executive',
  },
  {
    id: 'command',
    title: 'Command Center',
    subtitle: 'Mission Control, live contracts e health dei domini principali.',
    badge: 'V37',
    priority: 'executive',
  },
  {
    id: 'scenarios',
    title: 'Dynamic Scenarios',
    subtitle: 'Motore dinamico RF/Telco/Antenna con layer visivi e hotspot.',
    badge: 'V36',
    priority: 'deep',
  },
  {
    id: 'full-engineering',
    title: 'Full Engineering Stack',
    subtitle: 'Vista completa legacy-safe: tutti i layer V41/V40/V39/V37/V36 in sequenza.',
    badge: 'FULL',
    priority: 'deep',
  },
]

function MissionCompactOverview() {
  return (
    <section className="v42-compact-overview">
      <PortalShellNavigationP0 />
        <MissionControlContentP0C />
        <RFPhysicsRouteP1 />
        <SignalAnalyzerRouteP2 />
      <div className="v42-overview-grid">
        <article>
          <span>Active Mount</span>
          <strong>RFOperationalDeckV42MissionLayoutOrchestrator</strong>
        </article>
        <article>
          <span>Preserved Stack</span>
          <strong>V41 → V40 → V39 → V37 → V36</strong>
        </article>
        <article>
          <span>Runtime</span>
          <strong>8000 / 4181 / 5173</strong>
        </article>
        <article>
          <span>Safety</span>
          <strong>read-only contracts · no iframe · no backend mutation</strong>
        </article>
      </div>

      <div className="v42-flow">
        <div>V42<br /><small>Orchestrator</small></div>
        <i />
        <div>V41<br /><small>Visual Assets</small></div>
        <i />
        <div>V40<br /><small>Knowledge</small></div>
        <i />
        <div>V39<br /><small>Navigation</small></div>
        <i />
        <div>V37<br /><small>Command</small></div>
        <i />
        <div>V36<br /><small>Scenarios</small></div>
      </div>

      <div className="v42-executive-note">
        <h3>Integration objective</h3>
        <p>
          Questa vista evita lo stack verticale infinito: seleziona un layer operativo alla volta,
          mantenendo disponibile la vista completa quando serve fare debug o revisione ingegneristica.
        </p>
      </div>
    </section>
  )
}

export function MissionLayoutOrchestratorV42() {
  const [active, setActive] = useState<SectionIdV42>(() => sectionFromHashV45())

  // TRFMC_V46_HASHCHANGE_BINDING
  useEffect(() => {
    const applyHash = () => {
      setActive(trfmcV46NormalizeHashToSection())
    }

    applyHash()
    window.addEventListener('hashchange', applyHash)
    return () => window.removeEventListener('hashchange', applyHash)
  }, [])

  // TRFMC_V45A_HASHCHANGE_BINDING
  useEffect(() => {
    const applyHash = () => {
      const next = resolveV42InitialSectionFromHash()
      setActive(next)
    }

    applyHash()
    window.addEventListener('hashchange', applyHash)
    return () => window.removeEventListener('hashchange', applyHash)
  }, [])


  useEffect(() => {
    const onHashChangeV45 = () => {
      setActive(sectionFromHashV45())
    }

    window.addEventListener('hashchange', onHashChangeV45)
    onHashChangeV45()

    return () => window.removeEventListener('hashchange', onHashChangeV45)
  }, [])

  const activeSection = useMemo(() => {
    return sections.find((section) => section.id === active) ?? sections[0]
  }, [active])

  return (
    <section className="v42-orchestrator-shell trfmc-native-orchestrator-shell">
      <div className="v42-orchestrator-header trfmc-native-orchestrator-header">
        <div>
          <p>V42 MISSION LAYOUT ORCHESTRATOR</p>
          <h2>Engineering Orchestrator</h2>
          <span>
            Section switch, compact executive view and full engineering stack on demand.
          </span>
        </div>
        <div className="v42-orchestrator-score">
          <strong>{sections.length}</strong>
          <small>sections</small>
        </div>
      </div>

      <div className="v42-layout trfmc-native-orchestrator-layout">
        <nav className="v42-section-rail trfmc-native-section-rail" aria-label="TRFMC section selector">
          {sections.map((section) => (
            <button
              key={section.id}
              type="button"
              className={active === section.id ? 'v42-section-active' : ''}
              onClick={() => {
                setActive(section.id)
                window.location.hash = hashForSectionV45(section.id)
              }}
            >
              <span>{section.badge}</span>
              <strong>{section.title}</strong>
              <small>{section.priority}</small>
            </button>
          ))}
        </nav>

      <EngineeringContentEnrichmentV49 activeSection={trfmcV49ResolveEnrichmentSectionFromHash(active)} />


        <main className="v42-section-stage trfmc-native-section-stage">
          <div className="v42-stage-heading">
            <div>
              <span>{activeSection.badge}</span>
              <h3>{activeSection.title}</h3>
              <p>{activeSection.subtitle}</p>
            </div>
            <strong>{activeSection.priority}</strong>
          </div>

          {active === 'mission' ? <MissionCompactOverview /> : null}

      <nav className="v46-deeplink-index" data-trfmc-v46-deeplink-index="true" aria-label="TRFMC deep link navigation">
        {trfmcV46NavigationIndex.map((entry) => (
          <a
            key={entry.id}
            href={entry.hash}
            className={active === entry.id ? 'v46-deeplink-active' : ''}
            onClick={(event) => {
              event.preventDefault()
              setActive(entry.id)
              trfmcV46WriteHashForSection(entry.id)
            }}
          >
            {entry.label}
          </a>
        ))}
      </nav>

          {active === 'visual-assets' ? <div data-trfmc-v45a-visual-assets-active="true" data-trfmc-section-active="visual-assets"><VisualAssetRuntimeV41 /></div> : null}
          {active === 'knowledge' ? <ScenarioKnowledgeBindingV40 /> : null}
          {active === 'navigation' ? <NavigationMapV39 /> : null}
          {active === 'command' ? <CommandCenterFusionV37 /> : null}
          {active === 'scenarios' ? <RFDynamicScenarioDeckV36 /> : null}
          {active === 'full-engineering' ? <RFOperationalDeckV41VisualAssetFusion /> : null}
        </main>
      </div>
    </section>
  )
}
