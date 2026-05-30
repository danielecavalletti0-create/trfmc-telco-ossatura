export type RFScenarioType =
  | 'electronics'
  | 'microstrip'
  | 'antenna-system'
  | 'tower-infrastructure'
  | 'beamwidth'
  | 'rf-lab'
  | 'uav-isr'

export type RFScenarioHotspot = {
  id: string
  label: string
  value: string
  x: number
  y: number
}

export type RFScenario = {
  id: RFScenarioType
  title: string
  subtitle: string
  mission: string
  visualMode: RFScenarioType
  kpis: Array<{ label: string; value: string }>
  hotspots: RFScenarioHotspot[]
  knowledge: string[]
}

export const rfScenariosV35: RFScenario[] = [
  {
    id: 'electronics',
    title: 'Electronics Fundamentals',
    subtitle: 'Symbol systems · circuit language · RF building blocks',
    mission: 'Trasforma la tabella dei simboli elettronici in una lavagna tecnica interattiva per componenti, strumenti e segnali.',
    visualMode: 'electronics',
    kpis: [
      { label: 'Families', value: '14+' },
      { label: 'Layer', value: 'Circuit' },
      { label: 'Use', value: 'Training' },
    ],
    hotspots: [
      { id: 'resistors', label: 'Passive network', value: 'R/L/C symbols', x: 22, y: 32 },
      { id: 'semiconductors', label: 'Active devices', value: 'Diodes/BJT/FET', x: 49, y: 45 },
      { id: 'logic', label: 'Digital layer', value: 'Gates/FF', x: 72, y: 36 },
    ],
    knowledge: [
      'I simboli sono il linguaggio comune tra schema, PCB, misura e troubleshooting.',
      'Il portale deve collegare simbolo, funzione, misura strumentale e comportamento RF.',
      'Questa scena diventa base per knowledge-base, quiz e simulazioni di circuito.'
    ],
  },
  {
    id: 'microstrip',
    title: 'Microstrip Patch Antenna',
    subtitle: 'Patch · substrate · feed line · ground plane · radiation pattern',
    mission: 'Scenario 3D per antenna patch con layer fisici, campo E, S11, gain e polar diagram.',
    visualMode: 'microstrip',
    kpis: [
      { label: 'Impedance', value: '50 Ω' },
      { label: 'Layer', value: '4' },
      { label: 'Mode', value: '5G/IoT' },
    ],
    hotspots: [
      { id: 'patch', label: 'Copper patch', value: 'radiating element', x: 50, y: 34 },
      { id: 'feed', label: 'Feed line', value: 'microstrip 50Ω', x: 29, y: 63 },
      { id: 'pattern', label: 'Radiation', value: 'E-plane/H-plane', x: 78, y: 28 },
    ],
    knowledge: [
      'La patch microstrip è compatta, piatta e adatta a array, IoT, terminali e moduli RF.',
      'I parametri critici sono εr, altezza substrato, dimensioni patch, feed e ground plane.',
      'Scenario ideale per collegare geometria, S11, bandwidth, polarizzazione e pattern.'
    ],
  },
  {
    id: 'antenna-system',
    title: 'Antenna Systems Explorer',
    subtitle: 'Yagi · phased array · horn · sector · MIMO · small cell · GPS',
    mission: 'Vetrina dinamica delle famiglie di antenne con applicazioni, pattern e casi d’uso.',
    visualMode: 'antenna-system',
    kpis: [
      { label: 'Families', value: '10' },
      { label: 'Domain', value: 'RF/TLC' },
      { label: 'Ready', value: '5G' },
    ],
    hotspots: [
      { id: 'mimo', label: 'Massive MIMO', value: 'beamforming', x: 78, y: 32 },
      { id: 'dish', label: 'Microwave dish', value: 'backhaul/PTP', x: 26, y: 67 },
      { id: 'sector', label: 'Sector antenna', value: 'cellular coverage', x: 69, y: 55 },
    ],
    knowledge: [
      'Ogni antenna è una soluzione di compromesso tra gain, beamwidth, bandwidth, costo e installazione.',
      'La tassonomia deve diventare interattiva: selezione antenna → applicazione → KPI → pattern.',
      'Questa scena alimenta le pagine antenna, link budget, tower mapping e coverage.'
    ],
  },
  {
    id: 'tower-infrastructure',
    title: 'Telecom Tower Infrastructure',
    subtitle: 'Macro site · microwave backhaul · radome · smart pole · power cabinets',
    mission: 'Scenario infrastrutturale per torri TLC, apparati, cabinet, backhaul, alimentazione e sostenibilità.',
    visualMode: 'tower-infrastructure',
    kpis: [
      { label: 'Sites', value: '6' },
      { label: 'Uptime', value: '98.7%' },
      { label: 'Energy', value: '72%' },
    ],
    hotspots: [
      { id: 'macro', label: '4G/5G macro', value: 'multi-band', x: 72, y: 40 },
      { id: 'backhaul', label: 'Microwave', value: 'PTP transport', x: 50, y: 31 },
      { id: 'power', label: 'Power chain', value: 'cabinet/solar', x: 83, y: 68 },
    ],
    knowledge: [
      'Un sito TLC è un sistema integrato: antenne, RRU/AAU, cabinet, energia, backhaul e gestione.',
      'La scena deve supportare mapping fisico-logico: antenna → radio unit → trasporto → core.',
      'È il ponte naturale tra RF, infrastruttura, NOC e cyber/physical security.'
    ],
  },
  {
    id: 'beamwidth',
    title: 'Beamwidth and Coverage',
    subtitle: 'Narrow beam · wide beam · gain · interference · capacity',
    mission: 'Scenario comparativo dinamico tra fascio stretto PTP e fascio largo per copertura area.',
    visualMode: 'beamwidth',
    kpis: [
      { label: 'Narrow', value: '3°' },
      { label: 'Wide', value: '90°' },
      { label: 'Metric', value: '-3 dB' },
    ],
    hotspots: [
      { id: 'narrow', label: 'Narrow beam', value: 'high gain/PTP', x: 26, y: 39 },
      { id: 'wide', label: 'Wide beam', value: 'area coverage', x: 73, y: 45 },
      { id: 'interference', label: 'Spillover', value: 'coverage tradeoff', x: 66, y: 69 },
    ],
    knowledge: [
      'Il beamwidth definisce l’angolo fra i punti a metà potenza, tipicamente -3 dB.',
      'Fascio stretto: più gain, meno interferenza, link lunghi. Fascio largo: più copertura, più utenti.',
      'Questa scena deve collegare coverage, capacità, interferenza e orientamento antenne.'
    ],
  },
  {
    id: 'rf-lab',
    title: 'RF & Microwave Engineering Lab',
    subtitle: 'S-parameters · Smith chart · VNA · spectrum · Maxwell · antennas',
    mission: 'Scenario laboratorio RF per collegare teoria, misura, strumenti e comportamento reale.',
    visualMode: 'rf-lab',
    kpis: [
      { label: 'VNA', value: 'S11/S21' },
      { label: 'Range', value: 'GHz' },
      { label: 'Model', value: 'Lab' },
    ],
    hotspots: [
      { id: 'smith', label: 'Smith chart', value: 'impedance match', x: 47, y: 29 },
      { id: 'sparams', label: 'S-parameters', value: 'network response', x: 61, y: 36 },
      { id: 'instrument', label: 'Analyzer', value: 'measurement chain', x: 52, y: 66 },
    ],
    knowledge: [
      'Lo scenario lab deve unire teoria elettromagnetica, strumentazione e procedure operative.',
      'È la base per pagine su VNA, spectrum analyzer, S-parameters, Smith chart e calibrazione.',
      'Ogni misura deve essere collegata a setup, sorgente, DUT, ricevitore e incertezza.'
    ],
  },
  {
    id: 'uav-isr',
    title: 'UAV Platforms and ISR Systems',
    subtitle: 'MALE UAV · ISR payload · RF links · mission profile',
    mission: 'Scenario comparativo per piattaforme UAV ISR, payload RF, data link e sorveglianza.',
    visualMode: 'uav-isr',
    kpis: [
      { label: 'Endurance', value: '24–27h' },
      { label: 'Role', value: 'ISR' },
      { label: 'Links', value: 'C2/Data' },
    ],
    hotspots: [
      { id: 'payload', label: 'EO/IR payload', value: 'surveillance', x: 34, y: 49 },
      { id: 'datalink', label: 'RF data link', value: 'C2 + telemetry', x: 62, y: 33 },
      { id: 'mission', label: 'ISR profile', value: 'persistent coverage', x: 69, y: 66 },
    ],
    knowledge: [
      'Scenario utile per analisi RF dei data link, telemetria, payload e profilo missione.',
      'Da collegare a sezioni UAV, SDR, spectrum monitoring, MAVLink, GCS e compliance RF.',
      'Resta in modalità didattica/read-only: niente trasmissione, niente spoofing, niente azioni operative.'
    ],
  },
]
