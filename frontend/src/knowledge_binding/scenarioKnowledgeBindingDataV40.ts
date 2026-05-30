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
