from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_SCENARIO_KNOWLEDGE_BINDING_V40_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_SCENARIO_KNOWLEDGE_BINDING_V40_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_SCENARIO_KNOWLEDGE_BINDING_V40_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
STYLES = ROOT / "frontend/src/styles.css"

BIND_DIR = ROOT / "frontend/src/knowledge_binding"
BIND_DATA = BIND_DIR / "scenarioKnowledgeBindingDataV40.ts"
BIND_COMPONENT = BIND_DIR / "ScenarioKnowledgeBindingV40.tsx"
WRAPPER = ROOT / "frontend/src/rf_instruments/instruments/RFOperationalDeckV40ScenarioKnowledgeFusion.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
BIND_DIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC SCENARIO-TO-KNOWLEDGE BINDING V40")
print("domain → scenario → theory → endpoint → asset · above V39")
print("=" * 60)

if not MAIN.exists():
    raise SystemExit("ERRORE: main.tsx mancante")
if not STYLES.exists():
    raise SystemExit("ERRORE: styles.css mancante")

for rel in [
    "runtime/quality/latest_navigation_map_v39r1/summary.json",
    "runtime/quality/latest_unified_design_system_v38/summary.json",
    "runtime/quality/latest_command_center_fusion_v37/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

main_txt = MAIN.read_text(encoding="utf-8")
if "RFOperationalDeckV40ScenarioKnowledgeFusion" in main_txt:
    active_state = "already_v40"
elif "RFOperationalDeckV39NavigationFusion" in main_txt:
    active_state = "v39_ready"
else:
    print("ERRORE: main.tsx non monta V39/V40")
    print("\n".join([line for line in main_txt.splitlines() if "RFOperationalDeck" in line]))
    raise SystemExit(1)

print(f"OK: active_state={active_state}")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:4181/api/mission/status"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0 or "TRFMC_READONLY_BACKEND_BRIDGE_V28" not in probe.stdout:
    raise SystemExit("ERRORE: API 4181 non operative")
print("OK: API 4181 live")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_SCENARIO_KNOWLEDGE_BINDING_V40_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/app/main.tsx",
    "frontend/src/styles.css",
    "frontend/src/knowledge_binding",
    "frontend/src/rf_instruments/instruments",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

(RDIR / f"main.tsx.before_v40_{TS}").write_text(main_txt, encoding="utf-8")
(RDIR / f"styles.css.before_v40_{TS}").write_text(STYLES.read_text(encoding="utf-8"), encoding="utf-8")

BIND_DATA.write_text(r"""
export type BindingSourceModeV40 = 'live' | 'contract' | 'synthetic' | 'future-live'

export type ScenarioKnowledgeBindingV40Item = {
  id: string
  domainId: string
  domainTitle: string
  scenarioId: string
  scenarioTitle: string
  sourceMode: BindingSourceModeV40
  liveEndpoint?: string
  assetHint?: string
  theory: string[]
  formulas: string[]
  instruments: string[]
  evidence: string[]
  nextEngineeringStep: string
}

export const scenarioKnowledgeBindingsV40: ScenarioKnowledgeBindingV40Item[] = [
  {
    id: 'mission-control-binding',
    domainId: 'mission-control',
    domainTitle: 'Mission Control',
    scenarioId: 'command-center',
    scenarioTitle: 'Command Center / Runtime Governance',
    sourceMode: 'live',
    liveEndpoint: '/api/mission/status',
    theory: [
      'La mission layer governa stato, sorgente dati, modalità read-only e salute del portale.',
      'Ogni dominio deve dichiarare se i dati sono live, contract, synthetic o future-live.',
      'La UI superiore non deve comandare sistemi reali se il modello operativo è read-only.'
    ],
    formulas: ['readiness = f(service, endpoint, source, safety)', 'risk = mutation_enabled ∨ tx_enabled'],
    instruments: ['Runtime health probe', 'NGINX/API proxy', 'Vite frontend', 'FastAPI backend'],
    evidence: ['summary.json', 'http.tsv', 'build log', 'active mount check'],
    nextEngineeringStep: 'Collegare il Command Center agli stati di tutti i domini V39.',
  },
  {
    id: 'rf-physics-binding',
    domainId: 'rf-physics',
    domainTitle: 'RF Physics',
    scenarioId: 'beamwidth',
    scenarioTitle: 'Beamwidth and Coverage',
    sourceMode: 'synthetic',
    assetHint: '/trfmc_assets/visual_knowledge/03_antennas_types/beamwidth_narrow_wide.jpg',
    theory: [
      'Il beamwidth descrive l’ampiezza angolare del lobo principale, tipicamente misurata ai punti -3 dB.',
      'Un fascio stretto aumenta gain e selettività, mentre un fascio largo aumenta copertura e probabilità di interferenza.',
      'Lo scenario deve collegare pattern, copertura, link budget e capacità radio.'
    ],
    formulas: ['HPBW = θ₂ - θ₁ @ -3 dB', 'EIRP = P_tx + G_tx - L_tx', 'Pr = Pt + Gt + Gr - Lp - Lmisc'],
    instruments: ['Spectrum analyzer', 'Antenna range', 'Drive test tool', 'RF planning tool'],
    evidence: ['coverage model', 'pattern overlay', 'scenario hotspot', 'KPI card'],
    nextEngineeringStep: 'Aggiungere una mini-simulazione di HPBW/gain/interferenza read-only.',
  },
  {
    id: 'signal-analyzer-binding',
    domainId: 'signal-analyzer',
    domainTitle: 'Signal Analyzer',
    scenarioId: 'rf-spectrum',
    scenarioTitle: 'Spectrum / Waterfall / IQ Workbench',
    sourceMode: 'contract',
    liveEndpoint: '/api/rfpro/spectrum/sweep',
    theory: [
      'Il signal analyzer deve rappresentare spettro, waterfall, IQ e misure derivate in modo coerente.',
      'La catena corretta è acquisition → windowing → FFT → power scaling → markers → classification.',
      'Il dato contract deve essere distinguibile dal dato acquisito da SDR o strumento reale.'
    ],
    formulas: ['Δf = Fs/N', 'P_dBm = 10log10(P_mW)', 'FFT{x[n]} = X[k]'],
    instruments: ['Spectrum analyzer', 'VSA', 'SDR receiver', 'DSP worker'],
    evidence: ['sweep contract', 'FFT parameters', 'marker table', 'waterfall frame'],
    nextEngineeringStep: 'Collegare il dominio Signal Analyzer al worker DSP e alla tabella marker.',
  },
  {
    id: 'microwave-engineering-binding',
    domainId: 'rf-microwave-engineering',
    domainTitle: 'RF / Microwave Engineering',
    scenarioId: 'rf-lab',
    scenarioTitle: 'RF & Microwave Engineering Lab',
    sourceMode: 'synthetic',
    assetHint: '/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.jpg',
    theory: [
      'Il laboratorio RF collega teoria, DUT, strumentazione, calibrazione e incertezza di misura.',
      'S-parameters e Smith chart sono strumenti fondamentali per reti RF e adattamento di impedenza.',
      'La scena deve evolvere in un percorso misurabile: setup → calibrazione → misura → interpretazione.'
    ],
    formulas: ['Γ = (ZL - Z0)/(ZL + Z0)', 'S11[dB] = 20log10(|Γ|)', 'VSWR = (1+|Γ|)/(1-|Γ|)'],
    instruments: ['VNA', 'Spectrum analyzer', 'Signal generator', 'Power meter'],
    evidence: ['calibration state', 'S11/S21 panel', 'Smith chart card', 'instrument setup card'],
    nextEngineeringStep: 'Inserire pannelli Smith/S-parameter con formule e casi didattici.',
  },
  {
    id: 'antenna-system-binding',
    domainId: 'antenna-system',
    domainTitle: 'Antenna System',
    scenarioId: 'antenna-system',
    scenarioTitle: 'Antenna Systems Explorer',
    sourceMode: 'contract',
    liveEndpoint: '/api/rfpro/bandplan',
    assetHint: '/trfmc_assets/visual_knowledge/03_antennas_types/types_of_telecom_antennas.jpg',
    theory: [
      'Ogni famiglia di antenna rappresenta un compromesso tra gain, bandwidth, polarizzazione, dimensione e installazione.',
      'Il portale deve collegare tassonomia antenna, banda, pattern, applicazione e contesto infrastrutturale.',
      'La bandplan contract layer permette di collegare antenna e spettro in modo coerente.'
    ],
    formulas: ['G ≈ ηD', 'λ = c/f', 'A_eff = λ²G/(4π)'],
    instruments: ['Antenna range', 'VNA', 'Field strength meter', 'Spectrum analyzer'],
    evidence: ['antenna taxonomy', 'bandplan endpoint', 'pattern context', 'visual asset'],
    nextEngineeringStep: 'Associare ogni antenna a bande, applicazioni e KPI di copertura.',
  },
  {
    id: 'microwave-link-binding',
    domainId: 'microwave-link',
    domainTitle: 'Microwave Link',
    scenarioId: 'tower-infrastructure',
    scenarioTitle: 'Telecom Tower Infrastructure / Microwave Backhaul',
    sourceMode: 'future-live',
    assetHint: '/trfmc_assets/visual_knowledge/04_telco_infrastructure/cellular_satellite_site_photo.jpg',
    theory: [
      'I link microwave richiedono LOS, margine di fading, controllo interferenza e corretto puntamento.',
      'Il link budget è il modello centrale per progettazione, verifica e troubleshooting.',
      'La scena tower deve mostrare il passaggio da sito fisico a trasporto logico.'
    ],
    formulas: ['FSPL[dB] = 32.44 + 20log10(f_MHz) + 20log10(d_km)', 'Fade margin = Pr - RxSensitivity'],
    instruments: ['Microwave link analyzer', 'Spectrum analyzer', 'GPS compass', 'Power meter'],
    evidence: ['tower asset', 'backhaul path', 'link budget placeholder', 'future-live marker'],
    nextEngineeringStep: 'Creare un calcolatore link budget read-only e una mappa PTP.',
  },
  {
    id: 'fiber-optic-binding',
    domainId: 'fiber-optic',
    domainTitle: 'Fiber Optic',
    scenarioId: 'transport-layer',
    scenarioTitle: 'Fiber / Transport Layer',
    sourceMode: 'future-live',
    theory: [
      'La fibra collega accesso radio, backhaul, fronthaul e core transport.',
      'Il dominio è partial: serve una sezione dedicata per OTDR, attenuazione, giunzioni e budget ottico.',
      'Deve essere collegato a tower, private network e data center infrastructure.'
    ],
    formulas: ['Loss_total = ΣLoss_splice + ΣLoss_connector + αL', 'Power_margin = Tx - Rx_sensitivity - Loss_total'],
    instruments: ['OTDR', 'Optical power meter', 'Fusion splicer', 'Light source'],
    evidence: ['partial domain marker', 'future-live plan', 'transport dependency'],
    nextEngineeringStep: 'Espandere il dominio Fiber con asset, teoria e procedure OTDR.',
  },
  {
    id: 'private-networks-binding',
    domainId: 'private-networks',
    domainTitle: 'Private Networks',
    scenarioId: 'private-5g-lab',
    scenarioTitle: 'Private 5G Lab Topology',
    sourceMode: 'live',
    liveEndpoint: '/api/core/open5gs/status',
    theory: [
      'Una rete privata 5G richiede integrazione tra RAN, core, SIM/identity, policy e trasporto.',
      'Il laboratorio deve mostrare chiaramente separazione tra topology, runtime status e call-flow.',
      'Open5GS/UERANSIM forniscono il riferimento didattico per core/RAN controllato.'
    ],
    formulas: ['registration_state = f(RRC, NAS, AKA, PDU)', 'QoS_flow = f(S-NSSAI, DNN, policy)'],
    instruments: ['Open5GS', 'UERANSIM', 'tcpdump', 'Wireshark'],
    evidence: ['core readiness', 'RAN readiness', 'PDU session map', 'PCAP plan'],
    nextEngineeringStep: 'Collegare topology map a Open5GS/UERANSIM readiness.',
  },
  {
    id: 'core-network-binding',
    domainId: 'core-network',
    domainTitle: 'Core Network',
    scenarioId: '5g-core-security',
    scenarioTitle: '5G Core / Identity / Security Flow',
    sourceMode: 'live',
    liveEndpoint: '/api/core/open5gs/status',
    theory: [
      'Il core 5G deve rappresentare AMF, SMF, UPF, AUSF, UDM, NRF e le relazioni SBI/NAS.',
      'La parte identity/security deve includere SUPI/SUCI, 5G-AKA/EAP-AKA e NAS security.',
      'Lo stato runtime read-only evita azioni di start/stop e preserva sicurezza operativa.'
    ],
    formulas: ['NAS_security = f(K_AMF, algorithm, count)', 'PDU_session = f(DNN, S-NSSAI, SMF, UPF)'],
    instruments: ['Open5GS logs', 'Wireshark NGAP/NAS/PFCP', 'tcpdump', 'UERANSIM'],
    evidence: ['open5gs status endpoint', 'readiness state', 'future call-flow graph'],
    nextEngineeringStep: 'Creare il 5G call-flow visual binding con SUPI/SUCI/NAS/PFCP.',
  },
  {
    id: 'data-center-binding',
    domainId: 'data-center-infrastructure',
    domainTitle: 'Data Center Infrastructure',
    scenarioId: 'runtime-infrastructure',
    scenarioTitle: 'Runtime / Service Infrastructure',
    sourceMode: 'future-live',
    theory: [
      'Il portale stesso ha una topologia infrastrutturale: frontend Vite, proxy 4181, backend 8000, runtime quality.',
      'Il dominio data center deve evolvere verso mapping compute, network, storage e servizi.',
      'Le evidenze runtime devono diventare visibili nel Command Center.'
    ],
    formulas: ['availability = uptime / observation_window', 'service_health = f(port, process, endpoint, log)'],
    instruments: ['systemd user services', 'ss', 'curl', 'runtime manifests'],
    evidence: ['ports 8000/4181/5173', 'summary files', 'freeze files', 'release manifests'],
    nextEngineeringStep: 'Creare topology card dei servizi locali e relative porte.',
  },
  {
    id: 'cyber-rf-binding',
    domainId: 'cyber-rf-intelligence',
    domainTitle: 'Cyber RF Intelligence',
    scenarioId: 'soc-noc-correlation',
    scenarioTitle: 'SOC/NOC RF-Cyber Correlation',
    sourceMode: 'contract',
    liveEndpoint: '/api/soc-noc/correlation/demo',
    theory: [
      'Il dominio cyber/RF deve correlare eventi radio, rete, core, endpoint e infrastruttura.',
      'Il modello deve rimanere read-only: correlazione e evidence, non azione offensiva.',
      'Il valore tecnico nasce dalla relazione fra evento, sorgente, evidenza e impatto.'
    ],
    formulas: ['correlation_score = f(time, source, domain, severity)', 'risk = likelihood × impact'],
    instruments: ['SOC/NOC dashboard', 'PCAP analyzer', 'log collector', 'RF monitor'],
    evidence: ['correlation contract', 'event list', 'evidence timeline', 'read-only safety markers'],
    nextEngineeringStep: 'Costruire timeline eventi e matrice impatto RF/Telco/Cyber.',
  },
  {
    id: 'knowledge-base-binding',
    domainId: 'knowledge-base',
    domainTitle: 'Knowledge Base',
    scenarioId: 'knowledge-library',
    scenarioTitle: 'Knowledge / Glossary / Visual Library',
    sourceMode: 'future-live',
    assetHint: '/trfmc_assets/visual_knowledge/visual_asset_registry_v35.json',
    theory: [
      'La Knowledge Base deve essere il collegamento tra scenari, formule, immagini, documentazione e procedure.',
      'Il dominio è partial: esiste il concetto, ma serve una struttura didattica navigabile.',
      'Ogni scenario deve avere teoria, formule, strumenti, evidenze e riferimenti visuali.'
    ],
    formulas: ['knowledge_node = concept + formula + visual + instrument + evidence'],
    instruments: ['visual registry', 'markdown/docs', 'scenario cards', 'glossary'],
    evidence: ['asset registry', 'scenario binding', 'formula cards', 'domain map'],
    nextEngineeringStep: 'Creare pagina Knowledge Base con indice concetti e formule.',
  },
]

export const scenarioKnowledgeMetaV40 = {
  title: 'TRFMC V40 Scenario-to-Knowledge Binding',
  subtitle: 'Domain → scenario → theory → formula → instrument → evidence map.',
  liveCount: 4,
  contractCount: 3,
  syntheticCount: 2,
  futureLiveCount: 3,
}
""".strip() + "\n", encoding="utf-8")

BIND_COMPONENT.write_text(r"""
import { useMemo, useState } from 'react'
import { scenarioKnowledgeBindingsV40, scenarioKnowledgeMetaV40, type BindingSourceModeV40 } from './scenarioKnowledgeBindingDataV40'

function modeLabel(mode: BindingSourceModeV40) {
  if (mode === 'future-live') return 'FUTURE-LIVE'
  return mode.toUpperCase()
}

function modeRank(mode: BindingSourceModeV40) {
  if (mode === 'live') return 0
  if (mode === 'contract') return 1
  if (mode === 'synthetic') return 2
  return 3
}

export function ScenarioKnowledgeBindingV40() {
  const [modeFilter, setModeFilter] = useState<BindingSourceModeV40 | 'all'>('all')
  const [selectedId, setSelectedId] = useState(scenarioKnowledgeBindingsV40[0]?.id ?? 'mission-control-binding')

  const visibleBindings = useMemo(() => {
    return scenarioKnowledgeBindingsV40
      .filter((item) => modeFilter === 'all' || item.sourceMode === modeFilter)
      .sort((a, b) => modeRank(a.sourceMode) - modeRank(b.sourceMode))
  }, [modeFilter])

  const selected = useMemo(() => {
    return scenarioKnowledgeBindingsV40.find((item) => item.id === selectedId) ?? scenarioKnowledgeBindingsV40[0]
  }, [selectedId])

  return (
    <section className="v40-binding-shell">
      <div className="v40-binding-header">
        <div>
          <p>V40 SCENARIO-TO-KNOWLEDGE BINDING</p>
          <h2>{scenarioKnowledgeMetaV40.title}</h2>
          <span>{scenarioKnowledgeMetaV40.subtitle}</span>
        </div>
        <div className="v40-binding-score">
          <strong>{scenarioKnowledgeBindingsV40.length}</strong>
          <small>domain bindings</small>
        </div>
      </div>

      <div className="v40-mode-controls">
        {(['all', 'live', 'contract', 'synthetic', 'future-live'] as const).map((mode) => (
          <button
            key={mode}
            type="button"
            className={modeFilter === mode ? 'v40-mode-active' : ''}
            onClick={() => setModeFilter(mode)}
          >
            {mode === 'all' ? 'ALL SOURCES' : modeLabel(mode)}
          </button>
        ))}
      </div>

      <div className="v40-binding-layout">
        <div className="v40-binding-list">
          {visibleBindings.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`v40-binding-card v40-source-${item.sourceMode} ${selected.id === item.id ? 'v40-binding-selected' : ''}`}
              onClick={() => setSelectedId(item.id)}
            >
              <span>{item.domainTitle}</span>
              <strong>{item.scenarioTitle}</strong>
              <small>{modeLabel(item.sourceMode)}</small>
            </button>
          ))}
        </div>

        <aside className="v40-binding-detail">
          <div className="v40-detail-top">
            <span>{selected.domainTitle}</span>
            <strong className={`v40-mode-pill v40-pill-${selected.sourceMode}`}>{modeLabel(selected.sourceMode)}</strong>
          </div>

          <h3>{selected.scenarioTitle}</h3>
          <p>{selected.theory[0]}</p>

          <div className="v40-source-box">
            <span>{selected.liveEndpoint ? 'endpoint' : selected.assetHint ? 'asset/reference' : 'binding'}</span>
            <strong>{selected.liveEndpoint ?? selected.assetHint ?? 'local knowledge model'}</strong>
          </div>

          <div className="v40-detail-grid">
            <article>
              <span>Theory</span>
              <ul>
                {selected.theory.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </article>

            <article>
              <span>Formulas</span>
              <ul>
                {selected.formulas.map((item) => <li key={item}><code>{item}</code></li>)}
              </ul>
            </article>

            <article>
              <span>Instruments</span>
              <ul>
                {selected.instruments.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </article>

            <article>
              <span>Evidence</span>
              <ul>
                {selected.evidence.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </article>
          </div>

          <footer>
            <span>Next engineering step</span>
            <strong>{selected.nextEngineeringStep}</strong>
          </footer>
        </aside>
      </div>
    </section>
  )
}
""".strip() + "\n", encoding="utf-8")

WRAPPER.write_text(r"""
import { ScenarioKnowledgeBindingV40 } from '../../knowledge_binding/ScenarioKnowledgeBindingV40'
import { RFOperationalDeckV39NavigationFusion } from './RFOperationalDeckV39NavigationFusion'

export function RFOperationalDeckV40ScenarioKnowledgeFusion() {
  return (
    <>
      <ScenarioKnowledgeBindingV40 />
      <RFOperationalDeckV39NavigationFusion />
    </>
  )
}
""".strip() + "\n", encoding="utf-8")

styles = STYLES.read_text(encoding="utf-8")
if "TRFMC V40 SCENARIO KNOWLEDGE BINDING" not in styles:
    STYLES.write_text(styles + r"""

/* === TRFMC V40 SCENARIO KNOWLEDGE BINDING === */
.v40-binding-shell{
  margin:18px;
  padding:18px;
  border:1px solid var(--trfmc-border, rgba(117,234,255,.22));
  border-radius:var(--trfmc-radius-xl, 28px);
  background:var(--trfmc-gradient-shell, linear-gradient(135deg,rgba(2,9,17,.98),rgba(4,14,25,.98)));
  box-shadow:var(--trfmc-shadow-deep, 0 34px 95px rgba(0,0,0,.42)), inset 0 0 44px rgba(80,215,255,.045);
}

.v40-binding-shell::before{
  content:"";
  display:block;
  height:1px;
  margin:-4px 0 14px;
  background:linear-gradient(90deg,transparent,rgba(117,234,255,.45),rgba(141,255,189,.30),transparent);
}

.v40-binding-header{
  display:flex;
  justify-content:space-between;
  align-items:flex-start;
  gap:20px;
  margin-bottom:14px;
}

.v40-binding-header p{
  margin:0 0 6px;
  color:var(--trfmc-cyan, #75eaff);
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v40-binding-header h2{
  margin:0;
  color:var(--trfmc-text, #f1fbff);
  font-size:25px;
}

.v40-binding-header span{
  display:block;
  margin-top:8px;
  color:var(--trfmc-muted, #9ab5c9);
  font-size:13px;
}

.v40-binding-score{
  min-width:132px;
  padding:12px;
  border:1px solid var(--trfmc-border-green, rgba(141,255,189,.26));
  border-radius:var(--trfmc-radius-md, 16px);
  background:rgba(5,36,34,.58);
  text-align:center;
}

.v40-binding-score strong{
  display:block;
  color:var(--trfmc-green, #8dffbd);
  font-size:25px;
}

.v40-binding-score small{
  color:#9bb7a9;
}

.v40-mode-controls{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  margin-bottom:14px;
}

.v40-mode-controls button{
  border:1px solid rgba(117,234,255,.22);
  border-radius:999px;
  background:rgba(6,19,34,.78);
  color:#a6bdd2;
  padding:8px 12px;
  cursor:pointer;
  font-size:12px;
}

.v40-mode-controls button.v40-mode-active{
  color:#06131d;
  background:linear-gradient(135deg,var(--trfmc-cyan, #75eaff),var(--trfmc-green, #8dffbd));
  border-color:transparent;
}

.v40-binding-layout{
  display:grid;
  grid-template-columns:minmax(0,.95fr) minmax(420px,1.05fr);
  gap:14px;
}

.v40-binding-list{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:10px;
  align-content:start;
}

.v40-binding-card{
  min-height:112px;
  text-align:left;
  padding:13px;
  border-radius:18px;
  border:1px solid rgba(117,234,255,.16);
  background:rgba(8,25,42,.62);
  cursor:pointer;
}

.v40-binding-card span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:7px;
}

.v40-binding-card strong{
  display:block;
  color:var(--trfmc-text, #f1fbff);
  font-size:15px;
  line-height:1.1;
}

.v40-binding-card small{
  display:inline-block;
  margin-top:10px;
  padding:4px 8px;
  border-radius:999px;
  font-weight:900;
  font-size:10px;
}

.v40-binding-selected{
  border-color:rgba(117,234,255,.42);
  box-shadow:0 0 24px rgba(117,234,255,.16);
}

.v40-source-live small,
.v40-pill-live{
  color:var(--trfmc-green, #8dffbd);
  background:rgba(141,255,189,.12);
}

.v40-source-contract small,
.v40-pill-contract{
  color:var(--trfmc-cyan, #75eaff);
  background:rgba(117,234,255,.12);
}

.v40-source-synthetic small,
.v40-pill-synthetic{
  color:var(--trfmc-amber, #ffd37b);
  background:rgba(255,211,123,.12);
}

.v40-source-future-live small,
.v40-pill-future-live{
  color:#c6a8ff;
  background:rgba(198,168,255,.12);
}

.v40-binding-detail{
  padding:16px;
  border-radius:22px;
  border:1px solid rgba(117,234,255,.18);
  background:rgba(5,17,31,.76);
}

.v40-detail-top{
  display:flex;
  justify-content:space-between;
  gap:12px;
  align-items:center;
  margin-bottom:10px;
}

.v40-detail-top > span,
.v40-source-box span,
.v40-detail-grid article > span,
.v40-binding-detail footer span{
  display:block;
  color:var(--trfmc-cyan, #75eaff);
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:5px;
}

.v40-mode-pill{
  border-radius:999px;
  padding:5px 9px;
  font-size:10px;
  font-weight:900;
}

.v40-binding-detail h3{
  margin:0 0 8px;
  color:var(--trfmc-text, #f1fbff);
  font-size:24px;
}

.v40-binding-detail p{
  color:var(--trfmc-muted, #9ab5c9);
  line-height:1.45;
}

.v40-source-box{
  margin:10px 0;
  padding:10px;
  border:1px solid rgba(141,255,189,.14);
  border-radius:14px;
  background:rgba(7,31,31,.48);
}

.v40-source-box strong{
  color:var(--trfmc-green, #8dffbd);
  font-size:12px;
  word-break:break-word;
}

.v40-detail-grid{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:10px;
  margin-top:12px;
}

.v40-detail-grid article{
  padding:10px;
  border:1px solid rgba(117,234,255,.14);
  border-radius:14px;
  background:rgba(8,25,42,.62);
}

.v40-detail-grid ul{
  margin:0;
  padding-left:18px;
  color:#c5d8e7;
  font-size:12px;
  line-height:1.45;
}

.v40-detail-grid code{
  color:var(--trfmc-cyan, #75eaff);
}

.v40-binding-detail footer{
  margin-top:12px;
  padding:10px;
  border-radius:14px;
  background:rgba(2,9,17,.52);
}

.v40-binding-detail footer strong{
  color:var(--trfmc-text, #f1fbff);
  font-size:12px;
}

@media (max-width:1200px){
  .v40-binding-layout{grid-template-columns:1fr}
}

@media (max-width:760px){
  .v40-binding-header{flex-direction:column}
  .v40-binding-list{grid-template-columns:1fr}
  .v40-detail-grid{grid-template-columns:1fr}
}
""", encoding="utf-8")

# Patch main
main_txt = MAIN.read_text(encoding="utf-8")
old_import = "import { RFOperationalDeckV39NavigationFusion } from '../rf_instruments/instruments/RFOperationalDeckV39NavigationFusion'"
new_import = "import { RFOperationalDeckV40ScenarioKnowledgeFusion } from '../rf_instruments/instruments/RFOperationalDeckV40ScenarioKnowledgeFusion'"

if new_import not in main_txt:
    if old_import not in main_txt and "RFOperationalDeckV40ScenarioKnowledgeFusion" not in main_txt:
        raise SystemExit("ERRORE: import V39 non trovato in main.tsx")
    main_txt = main_txt.replace(old_import, new_import, 1)

main_txt = main_txt.replace("<RFOperationalDeckV39NavigationFusion />", "<RFOperationalDeckV40ScenarioKnowledgeFusion />")
MAIN.write_text(main_txt, encoding="utf-8")

# Checks
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

main_now = MAIN.read_text(encoding="utf-8")
styles_now = STYLES.read_text(encoding="utf-8")
data_now = BIND_DATA.read_text(encoding="utf-8")
component_now = BIND_COMPONENT.read_text(encoding="utf-8")
wrapper_now = WRAPPER.read_text(encoding="utf-8")

ok("scenarioKnowledgeBindingDataV40.ts exists", BIND_DATA.exists())
ok("ScenarioKnowledgeBindingV40.tsx exists", BIND_COMPONENT.exists())
ok("RFOperationalDeckV40ScenarioKnowledgeFusion.tsx exists", WRAPPER.exists())
ok("main imports/mounts V40", "RFOperationalDeckV40ScenarioKnowledgeFusion" in main_now)
ok("main JSX mounts V40", "<RFOperationalDeckV40ScenarioKnowledgeFusion />" in main_now)
ok("V39 preserved below V40", "RFOperationalDeckV39NavigationFusion" in wrapper_now)
ok("ScenarioKnowledgeBindingV40 export exists", "export function ScenarioKnowledgeBindingV40" in component_now)
ok("Mission Control binding exists", "Mission Control" in data_now)
ok("Signal Analyzer binding exists", "Signal Analyzer" in data_now)
ok("Core Network binding exists", "Core Network" in data_now)
ok("Knowledge Base binding exists", "Knowledge Base" in data_now)
ok("live/contract/synthetic/future-live modes present", all(x in data_now for x in ["'live'", "'contract'", "'synthetic'", "'future-live'"]))
ok("V40 CSS present", "v40-binding-shell" in styles_now)
ok("no iframe in V40 binding component", "<iframe" not in component_now.lower())

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())
miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build
build_log = RDIR / "npm_build_v40.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)
build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result == "FAIL":
    print(build_log.read_text(errors="ignore")[-6000:])

# HTTP gate
http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:4181/api/mission/status",
    "http://127.0.0.1:4181/api/core/open5gs/status",
    "http://127.0.0.1:4181/api/rfpro/spectrum/sweep",
    "http://127.0.0.1:4181/api/soc-noc/correlation/demo",
]
lines = ["url\tstatus\tbytes"]
for url in urls:
    pr = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}\t%{size_download}", "--connect-timeout", "2", "--max-time", "8", url],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if pr.returncode != 0:
        code, size = "000", "0"
    else:
        parts = pr.stdout.strip().split()
        code = parts[0] if len(parts) > 0 else "000"
        size = parts[1] if len(parts) > 1 else "0"
    lines.append(f"{url}\t{code}\t{size}")

http_tsv.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(http_tsv.read_text())

http_non_200 = sum(1 for line in lines[1:] if line.split("\t")[1] != "200")
http_zero_bytes = sum(1 for line in lines[1:] if line.split("\t")[2] == "0")

rollback = RDIR / "rollback_v40_scenario_knowledge_binding.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/main.tsx.before_v40_{TS}" frontend/src/app/main.tsx
cp "{RDIR}/styles.css.before_v40_{TS}" frontend/src/styles.css
rm -rf frontend/src/knowledge_binding
rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV40ScenarioKnowledgeFusion.tsx
echo "Rollback V40 Scenario Knowledge Binding completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "scenario_knowledge_binding_manifest_v40.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_SCENARIO_KNOWLEDGE_BINDING_V40",
    "strategy": "domain_to_scenario_to_theory_formula_instrument_evidence_binding",
    "frontend_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "created": [str(BIND_DATA), str(BIND_COMPONENT), str(WRAPPER)],
    "patched": [str(MAIN), str(STYLES)],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "bindings_count": 12,
    "source_modes": {
        "live": 4,
        "contract": 3,
        "synthetic": 2,
        "future_live": 3
    },
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_SCENARIO_KNOWLEDGE_BINDING_V40",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_mount": "RFOperationalDeckV40ScenarioKnowledgeFusion",
    "preserves": "RFOperationalDeckV39NavigationFusion",
    "bindings_count": 12,
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/src/app/main.tsx",
    "frontend/src/styles.css",
    "frontend/src/knowledge_binding",
    "frontend/src/rf_instruments/instruments/RFOperationalDeckV40ScenarioKnowledgeFusion.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_scenario_knowledge_binding_v40"
latest_r = ROOT / "runtime/releases/latest_scenario_knowledge_binding_v40"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
