#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"

SCENARIO_DIR="$ROOT/frontend/src/rf_scenarios"
DATA="$SCENARIO_DIR/scenarioDataV35.ts"
ENGINE="$SCENARIO_DIR/RFDynamicScenarioDeckV35.tsx"
WRAPPER="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios.tsx"

echo "============================================================"
echo "TRFMC DYNAMIC RF/TELCO SCENARIOS V35"
echo "dynamic scenario deck · active portal mount · frontend-only"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$SCENARIO_DIR" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$STYLES" || { echo "ERRORE: styles.css mancante"; exit 1; }

test -f "$ROOT/runtime/quality/latest_native_rf_bridge_readiness_runtime_visibility_v34r1r2/summary.json" || {
  echo "ERRORE: V34R1R2 summary mancante"
  exit 1
}

V34R1R2_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path("runtime/quality/latest_native_rf_bridge_readiness_runtime_visibility_v34r1r2/summary.json")
d=json.loads(p.read_text())
print(d.get("result",""))
PY
)"

[ "$V34R1R2_RESULT" = "PASS" ] || {
  echo "ERRORE: V34R1R2 non PASS: $V34R1R2_RESULT"
  exit 1
}

grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$MAIN" || {
  echo "ERRORE: main.tsx non monta V34R1NativeBridgeVisible; non procedo"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: API 4181 non operative"
  exit 1
}

echo "OK: V34R1R2 PASS, ramo attivo corretto, API live"

echo
echo "=== BACKUP PRE-PATCH ==="

PRE_FREEZE="$ROOT/runtime/freezes/TRFMC_BEFORE_DYNAMIC_RF_TELCO_SCENARIOS_V35_$TS.tar.gz"

tar -czf "$PRE_FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_instruments/instruments \
  frontend/src/rf_scenarios \
  2>/dev/null || true

cp "$MAIN" "$RELEASE_DIR/main.tsx.before_v35_$TS"
cp "$STYLES" "$RELEASE_DIR/styles.css.before_v35_$TS"

echo "Pre-freeze: $PRE_FREEZE"

echo
echo "=== CREATE SCENARIO DATA ==="

cat > "$DATA" <<'TS'
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
TS

echo
echo "=== CREATE DYNAMIC SCENARIO ENGINE ==="

cat > "$ENGINE" <<'TSX'
import { useMemo, useState } from 'react'
import { rfScenariosV35, type RFScenario } from './scenarioDataV35'

function ScenarioVisual({ scenario }: { scenario: RFScenario }) {
  return (
    <div className={`v35-scenario-visual v35-mode-${scenario.visualMode}`}>
      <div className="v35-grid-floor" />
      <div className="v35-ambient-glow" />

      <div className="v35-object-stage">
        {scenario.visualMode === 'electronics' ? (
          <div className="v35-electronics-board">
            {['R', 'C', 'L', 'GND', 'DIODE', 'BJT', 'FET', 'LOGIC', 'RF'].map((item) => (
              <span key={item}>{item}</span>
            ))}
          </div>
        ) : null}

        {scenario.visualMode === 'microstrip' ? (
          <div className="v35-microstrip-stack">
            <div className="v35-layer v35-patch" />
            <div className="v35-layer v35-substrate" />
            <div className="v35-layer v35-ground" />
            <div className="v35-feed" />
            <div className="v35-radiation-lobe" />
          </div>
        ) : null}

        {scenario.visualMode === 'antenna-system' ? (
          <div className="v35-antenna-gallery">
            <div className="v35-yagi" />
            <div className="v35-panel" />
            <div className="v35-dish" />
            <div className="v35-horn" />
            <div className="v35-smallcell" />
          </div>
        ) : null}

        {scenario.visualMode === 'tower-infrastructure' ? (
          <div className="v35-tower-yard">
            <div className="v35-lattice-tower" />
            <div className="v35-monopole" />
            <div className="v35-radome" />
            <div className="v35-cabinet" />
            <div className="v35-solar" />
          </div>
        ) : null}

        {scenario.visualMode === 'beamwidth' ? (
          <div className="v35-beamwidth-scene">
            <div className="v35-tower-left" />
            <div className="v35-tower-right" />
            <div className="v35-beam-narrow" />
            <div className="v35-beam-wide" />
          </div>
        ) : null}

        {scenario.visualMode === 'rf-lab' ? (
          <div className="v35-rf-lab">
            <div className="v35-screen v35-smith">SMITH</div>
            <div className="v35-screen v35-sparams">S11/S21</div>
            <div className="v35-instrument">VSA/VNA</div>
            <div className="v35-parabola" />
          </div>
        ) : null}

        {scenario.visualMode === 'uav-isr' ? (
          <div className="v35-uav-scene">
            <div className="v35-uav v35-uav-a" />
            <div className="v35-uav v35-uav-b" />
            <div className="v35-uav-link" />
          </div>
        ) : null}
      </div>

      {scenario.hotspots.map((hotspot) => (
        <button
          type="button"
          key={hotspot.id}
          className="v35-hotspot"
          style={{ left: `${hotspot.x}%`, top: `${hotspot.y}%` }}
          title={`${hotspot.label}: ${hotspot.value}`}
        >
          <span />
          <strong>{hotspot.label}</strong>
          <small>{hotspot.value}</small>
        </button>
      ))}
    </div>
  )
}

export function RFDynamicScenarioDeckV35() {
  const [activeId, setActiveId] = useState(rfScenariosV35[0]?.id ?? 'electronics')

  const active = useMemo(
    () => rfScenariosV35.find((scenario) => scenario.id === activeId) ?? rfScenariosV35[0],
    [activeId],
  )

  return (
    <section className="v35-scenario-shell">
      <div className="v35-scenario-header">
        <div>
          <p>V35 DYNAMIC SCENARIO ENGINE</p>
          <h2>RF / Telco / Antenna Interactive Knowledge Scenarios</h2>
          <span>
            Scenari dinamici integrati nel portale: antenne, beamwidth, tower infrastructure, microstrip, 
            laboratorio RF, UAV ISR e simboli elettronici.
          </span>
        </div>
        <strong>{rfScenariosV35.length} scenarios</strong>
      </div>

      <div className="v35-scenario-tabs" role="tablist" aria-label="RF scenario selector">
        {rfScenariosV35.map((scenario) => (
          <button
            key={scenario.id}
            type="button"
            className={scenario.id === active.id ? 'v35-tab-active' : ''}
            onClick={() => setActiveId(scenario.id)}
          >
            {scenario.title}
          </button>
        ))}
      </div>

      <div className="v35-scenario-layout">
        <ScenarioVisual scenario={active} />

        <aside className="v35-scenario-info">
          <p className="v35-eyebrow">{active.subtitle}</p>
          <h3>{active.title}</h3>
          <p>{active.mission}</p>

          <div className="v35-kpi-grid">
            {active.kpis.map((kpi) => (
              <article key={`${active.id}-${kpi.label}`}>
                <span>{kpi.label}</span>
                <strong>{kpi.value}</strong>
              </article>
            ))}
          </div>

          <div className="v35-knowledge-stack">
            {active.knowledge.map((item, index) => (
              <div key={`${active.id}-knowledge-${index}`}>
                <span>{String(index + 1).padStart(2, '0')}</span>
                <p>{item}</p>
              </div>
            ))}
          </div>
        </aside>
      </div>
    </section>
  )
}
TSX

echo
echo "=== CREATE ACTIVE WRAPPER ==="

cat > "$WRAPPER" <<'TSX'
import { RFOperationalDeckV34R1NativeBridgeVisible } from './RFOperationalDeckV34R1NativeBridgeVisible'
import { RFDynamicScenarioDeckV35 } from '../../rf_scenarios/RFDynamicScenarioDeckV35'

export function RFOperationalDeckV35DynamicScenarios() {
  return (
    <>
      <RFDynamicScenarioDeckV35 />
      <RFOperationalDeckV34R1NativeBridgeVisible />
    </>
  )
}
TSX

echo
echo "=== APPEND CSS ==="

if ! grep -q "TRFMC V35 DYNAMIC RF TELCO SCENARIOS" "$STYLES"; then
cat >> "$STYLES" <<'CSS'

/* === TRFMC V35 DYNAMIC RF TELCO SCENARIOS === */
.v35-scenario-shell{
  margin:18px;
  padding:18px;
  border:1px solid rgba(92,211,255,.22);
  border-radius:24px;
  background:
    radial-gradient(circle at 12% 0%,rgba(36,178,255,.16),transparent 30%),
    radial-gradient(circle at 86% 10%,rgba(255,168,57,.11),transparent 28%),
    linear-gradient(135deg,rgba(4,12,24,.96),rgba(2,9,17,.98));
  box-shadow:0 28px 80px rgba(0,0,0,.38), inset 0 0 34px rgba(80,215,255,.05);
}

.v35-scenario-header{
  display:flex;
  justify-content:space-between;
  align-items:flex-start;
  gap:18px;
  margin-bottom:14px;
}

.v35-scenario-header p,
.v35-eyebrow{
  margin:0 0 6px;
  color:#62e6ff;
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v35-scenario-header h2{
  margin:0;
  color:#effbff;
  font-size:23px;
}

.v35-scenario-header span{
  display:block;
  margin-top:7px;
  color:#91abc4;
  font-size:13px;
}

.v35-scenario-header > strong{
  min-width:120px;
  text-align:center;
  color:#8dffbd;
  border:1px solid rgba(141,255,189,.24);
  border-radius:16px;
  background:rgba(8,44,38,.42);
  padding:12px 14px;
}

.v35-scenario-tabs{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  margin-bottom:14px;
}

.v35-scenario-tabs button{
  border:1px solid rgba(94,184,255,.22);
  border-radius:999px;
  background:rgba(6,20,35,.78);
  color:#9cb8d3;
  padding:8px 12px;
  font-size:12px;
  cursor:pointer;
}

.v35-scenario-tabs button.v35-tab-active{
  color:#06131d;
  background:linear-gradient(135deg,#72e9ff,#8dffbd);
  border-color:transparent;
  box-shadow:0 0 18px rgba(108,231,255,.25);
}

.v35-scenario-layout{
  display:grid;
  grid-template-columns:minmax(0,1.65fr) minmax(320px,.8fr);
  gap:16px;
}

.v35-scenario-visual{
  position:relative;
  min-height:430px;
  overflow:hidden;
  border:1px solid rgba(86,199,255,.20);
  border-radius:22px;
  background:
    linear-gradient(180deg,rgba(9,30,48,.74),rgba(3,10,20,.94)),
    radial-gradient(circle at 50% 35%,rgba(84,214,255,.10),transparent 38%);
}

.v35-grid-floor{
  position:absolute;
  inset:0;
  background:
    linear-gradient(rgba(94,211,255,.08) 1px, transparent 1px),
    linear-gradient(90deg,rgba(94,211,255,.08) 1px, transparent 1px);
  background-size:42px 42px;
  transform:perspective(600px) rotateX(58deg) translateY(190px) scale(1.8);
  opacity:.55;
}

.v35-ambient-glow{
  position:absolute;
  inset:0;
  background:
    radial-gradient(circle at 30% 30%,rgba(64,219,255,.18),transparent 28%),
    radial-gradient(circle at 72% 38%,rgba(255,168,57,.16),transparent 24%);
  animation:v35Pulse 4.8s ease-in-out infinite alternate;
}

@keyframes v35Pulse{
  from{opacity:.52}
  to{opacity:.95}
}

.v35-object-stage{
  position:absolute;
  inset:0;
  z-index:2;
}

.v35-hotspot{
  position:absolute;
  z-index:5;
  transform:translate(-50%,-50%);
  min-width:128px;
  border:1px solid rgba(116,229,255,.35);
  border-radius:14px;
  padding:8px 10px;
  background:rgba(3,14,24,.72);
  color:#eaffff;
  text-align:left;
  box-shadow:0 0 18px rgba(80,215,255,.16);
}

.v35-hotspot span{
  position:absolute;
  left:-9px;
  top:50%;
  width:10px;
  height:10px;
  transform:translateY(-50%);
  border-radius:50%;
  background:#77f2ff;
  box-shadow:0 0 14px #77f2ff;
}

.v35-hotspot strong{
  display:block;
  font-size:11px;
  color:#8ff4ff;
}

.v35-hotspot small{
  display:block;
  margin-top:3px;
  color:#cce4f3;
  font-size:10px;
}

.v35-scenario-info{
  border:1px solid rgba(94,184,255,.18);
  border-radius:22px;
  padding:16px;
  background:rgba(5,17,31,.72);
}

.v35-scenario-info h3{
  margin:0 0 8px;
  color:#f1fbff;
  font-size:24px;
}

.v35-scenario-info > p:not(.v35-eyebrow){
  color:#a9bed0;
  line-height:1.45;
}

.v35-kpi-grid{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:8px;
  margin:14px 0;
}

.v35-kpi-grid article{
  padding:10px;
  border-radius:14px;
  border:1px solid rgba(141,255,189,.18);
  background:rgba(7,35,32,.50);
}

.v35-kpi-grid span{
  display:block;
  color:#88a7ba;
  font-size:10px;
  text-transform:uppercase;
}

.v35-kpi-grid strong{
  color:#8dffbd;
  font-size:16px;
}

.v35-knowledge-stack{
  display:grid;
  gap:9px;
}

.v35-knowledge-stack div{
  display:grid;
  grid-template-columns:36px 1fr;
  gap:10px;
  padding:10px;
  border:1px solid rgba(94,184,255,.14);
  border-radius:14px;
  background:rgba(8,23,38,.58);
}

.v35-knowledge-stack span{
  color:#6ce7ff;
  font-weight:800;
}

.v35-knowledge-stack p{
  margin:0;
  color:#c2d5e4;
  font-size:12px;
  line-height:1.42;
}

/* Electronics holographic board */
.v35-electronics-board{
  position:absolute;
  left:8%;
  top:12%;
  width:84%;
  height:72%;
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:10px;
  padding:18px;
  border:1px solid rgba(111,236,255,.34);
  border-radius:22px;
  background:rgba(5,28,45,.58);
  box-shadow:0 0 34px rgba(64,219,255,.18);
}

.v35-electronics-board span{
  display:flex;
  align-items:center;
  justify-content:center;
  color:#bdf7ff;
  border:1px solid rgba(111,236,255,.22);
  border-radius:14px;
  background:rgba(1,11,22,.48);
  font-weight:800;
  letter-spacing:.08em;
}

/* Microstrip */
.v35-microstrip-stack{
  position:absolute;
  left:22%;
  top:20%;
  width:54%;
  height:56%;
  transform:perspective(900px) rotateX(58deg) rotateZ(-14deg);
}

.v35-layer{
  position:absolute;
  left:15%;
  width:70%;
  height:42%;
  border-radius:8px;
  box-shadow:0 20px 40px rgba(0,0,0,.38);
}

.v35-patch{
  top:0;
  background:linear-gradient(135deg,#cc6b29,#ffb06d);
  transform:translateZ(80px);
}

.v35-substrate{
  top:30%;
  background:linear-gradient(135deg,#8d9a77,#d1d8b7);
  transform:translateZ(28px);
}

.v35-ground{
  top:58%;
  background:linear-gradient(135deg,#7a3b18,#c16d35);
}

.v35-feed{
  position:absolute;
  left:8%;
  top:45%;
  width:40%;
  height:8px;
  background:#dd7f3a;
  transform:translateZ(88px);
}

.v35-radiation-lobe{
  position:absolute;
  left:42%;
  top:-28%;
  width:130px;
  height:130px;
  border-radius:50%;
  background:radial-gradient(circle,#ffdf63 0%,#3ce2ff 48%,transparent 70%);
  filter:blur(1px);
  opacity:.72;
  animation:v35Float 3.2s ease-in-out infinite alternate;
}

/* Antenna gallery */
.v35-antenna-gallery > div,
.v35-tower-yard > div,
.v35-beamwidth-scene > div,
.v35-rf-lab > div,
.v35-uav-scene > div{
  position:absolute;
  z-index:3;
}

.v35-yagi{left:10%;top:22%;width:170px;height:80px;border-top:4px solid #dcecff;border-bottom:4px solid #dcecff}
.v35-yagi:before{content:'';position:absolute;left:50%;top:-38px;width:4px;height:150px;background:#dcecff}
.v35-panel{left:67%;top:20%;width:90px;height:185px;border-radius:12px;background:linear-gradient(135deg,#e6edf3,#8ca0ae);box-shadow:0 0 24px rgba(108,231,255,.22)}
.v35-dish{left:20%;top:60%;width:145px;height:92px;border-radius:50%;background:radial-gradient(circle at 30% 40%,#f4f7fa,#6f7f8a)}
.v35-horn{left:50%;top:51%;width:150px;height:90px;clip-path:polygon(0 35%,100% 0,100% 100%,0 65%);background:#b7c3cc}
.v35-smallcell{left:48%;top:72%;width:58px;height:105px;border-radius:18px;background:linear-gradient(#f2f5f8,#7c909b)}

/* Tower infrastructure */
.v35-lattice-tower{left:18%;top:13%;width:100px;height:270px;background:linear-gradient(90deg,transparent 46%,#cbd6dd 47%,#cbd6dd 53%,transparent 54%);border-left:3px solid #cbd6dd;border-right:3px solid #cbd6dd}
.v35-monopole{left:42%;top:18%;width:34px;height:250px;background:#aebbc3;border-radius:14px}
.v35-radome{left:57%;top:34%;width:120px;height:120px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#fff,#adb7bf)}
.v35-cabinet{left:70%;top:68%;width:120px;height:72px;background:#ccd3d7;border-radius:8px}
.v35-solar{left:80%;top:30%;width:110px;height:70px;background:repeating-linear-gradient(90deg,#193d61 0 14px,#2d6ca0 15px 28px);transform:skewY(-12deg)}

/* Beamwidth */
.v35-tower-left,.v35-tower-right{width:70px;height:220px;background:linear-gradient(90deg,transparent 43%,#d9e7ef 44%,#d9e7ef 56%,transparent 57%);border-left:3px solid #d9e7ef;border-right:3px solid #d9e7ef}
.v35-tower-left{left:16%;top:32%}
.v35-tower-right{right:16%;top:32%}
.v35-beam-narrow{left:22%;top:42%;width:42%;height:12px;background:#43dfff;box-shadow:0 0 18px #43dfff;transform:rotate(-4deg)}
.v35-beam-wide{right:16%;top:36%;width:34%;height:190px;background:linear-gradient(90deg,rgba(136,255,132,.55),transparent);clip-path:polygon(0 44%,100% 0,100% 100%,0 56%)}

/* RF lab */
.v35-screen{border:1px solid rgba(108,231,255,.34);border-radius:14px;background:rgba(3,17,30,.82);color:#c8f8ff;display:flex;align-items:center;justify-content:center;font-weight:900}
.v35-smith{left:12%;top:16%;width:180px;height:130px}
.v35-sparams{left:42%;top:16%;width:220px;height:130px}
.v35-instrument{left:34%;top:58%;width:240px;height:110px;border-radius:18px;background:#8c98a4;color:#06131d;display:flex;align-items:center;justify-content:center;font-weight:900}
.v35-parabola{right:15%;top:38%;width:145px;height:145px;border-radius:50%;background:radial-gradient(circle at 35% 40%,#fff,#697884)}

/* UAV */
.v35-uav{width:260px;height:70px;background:#cad4dd;border-radius:50% 50% 40% 40%;box-shadow:0 16px 34px rgba(0,0,0,.28)}
.v35-uav:before{content:'';position:absolute;left:-90px;top:25px;width:440px;height:8px;background:#dce5ec;border-radius:8px}
.v35-uav:after{content:'';position:absolute;right:-30px;top:-28px;width:80px;height:110px;border-right:14px solid #c9d4dd;border-top:10px solid #c9d4dd;transform:rotate(8deg)}
.v35-uav-a{left:22%;top:26%;transform:rotate(-5deg)}
.v35-uav-b{left:42%;top:58%;transform:rotate(4deg)}
.v35-uav-link{left:34%;top:48%;width:38%;height:2px;background:#6ce7ff;box-shadow:0 0 20px #6ce7ff;transform:rotate(12deg)}

@keyframes v35Float{
  from{transform:translateY(0) scale(.92)}
  to{transform:translateY(-18px) scale(1.05)}
}

@media (max-width:1100px){
  .v35-scenario-layout{grid-template-columns:1fr}
  .v35-scenario-visual{min-height:390px}
}

@media (max-width:760px){
  .v35-scenario-header{flex-direction:column}
  .v35-kpi-grid{grid-template-columns:1fr}
  .v35-scenario-tabs button{font-size:11px}
}
CSS
fi

echo
echo "=== PATCH main.tsx V34R1R2 -> V35 ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

old_import = "import { RFOperationalDeckV34R1NativeBridgeVisible } from '../rf_instruments/instruments/RFOperationalDeckV34R1NativeBridgeVisible'"
new_import = "import { RFOperationalDeckV35DynamicScenarios } from '../rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios'"

if new_import not in txt:
    if old_import not in txt:
        raise SystemExit("ERRORE: import V34R1NativeBridgeVisible non trovato")
    txt = txt.replace(old_import, new_import, 1)

txt = txt.replace("<RFOperationalDeckV34R1NativeBridgeVisible />", "<RFOperationalDeckV35DynamicScenarios />")

p.write_text(txt, encoding="utf-8")
print("OK: main.tsx patched to V35 dynamic scenarios wrapper")
PY

echo
echo "=== STATIC CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$DATA" && echo "OK: scenario data exists" || echo "MISS: scenario data exists"
  test -f "$ENGINE" && echo "OK: scenario engine exists" || echo "MISS: scenario engine exists"
  test -f "$WRAPPER" && echo "OK: V35 wrapper exists" || echo "MISS: V35 wrapper exists"

  grep -q "RFDynamicScenarioDeckV35" "$ENGINE" && echo "OK: scenario deck export exists" || echo "MISS: scenario deck export exists"
  grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$WRAPPER" && echo "OK: V34R1R2 preserved below scenarios" || echo "MISS: V34R1R2 preserved below scenarios"
  grep -q "RFOperationalDeckV35DynamicScenarios" "$MAIN" && echo "OK: main imports/mounts V35" || echo "MISS: main imports/mounts V35"
  grep -q "<RFOperationalDeckV35DynamicScenarios />" "$MAIN" && echo "OK: main JSX mounts V35" || echo "MISS: main JSX mounts V35"

  grep -q "Microstrip Patch Antenna" "$DATA" && echo "OK: microstrip scenario exists" || echo "MISS: microstrip scenario exists"
  grep -q "Beamwidth and Coverage" "$DATA" && echo "OK: beamwidth scenario exists" || echo "MISS: beamwidth scenario exists"
  grep -q "Telecom Tower Infrastructure" "$DATA" && echo "OK: tower scenario exists" || echo "MISS: tower scenario exists"
  grep -q "UAV Platforms and ISR Systems" "$DATA" && echo "OK: UAV scenario exists" || echo "MISS: UAV scenario exists"
  grep -q "v35-scenario-shell" "$STYLES" && echo "OK: V35 CSS present" || echo "MISS: V35 CSS present"

  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/spectrum/sweep | grep -q "TRFMC_CONTRACT_COVERAGE_V31" && echo "OK: backend contracts still live" || echo "MISS: backend contracts still live"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

echo
echo "=== BUILD CHECK ==="

BUILD_LOG="$RELEASE_DIR/npm_build_v35.log"

(
  cd "$ROOT/frontend"
  npm run build > "$BUILD_LOG" 2>&1
) && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"

echo "Build result: $BUILD_RESULT"

if [ "$BUILD_RESULT" = "FAIL" ]; then
  tail -n 180 "$BUILD_LOG" || true
fi

echo
echo "=== OPTIONAL DOM / SCREENSHOT GATE ==="

URL_DEV="http://127.0.0.1:5173/"
DOM_DUMP="$RELEASE_DIR/trfmc_v35_dom.html"
SCREENSHOT="$RELEASE_DIR/trfmc_v35_runtime.png"
DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

CHROME_BIN=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME_BIN="$(command -v "$c")"
    break
  fi
done

if [ -n "$CHROME_BIN" ]; then
  pkill -f "vite.*5173" 2>/dev/null || true
  pkill -f "vite --host 127.0.0.1 --port 5173" 2>/dev/null || true
  sleep 2

  (
    cd "$ROOT/frontend"
    nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$RELEASE_DIR/vite_dev_5173.log" 2>&1 &
    echo $! > "$RELEASE_DIR/vite_dev_5173.pid"
  )

  for i in $(seq 1 25); do
    if curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if curl -fsS --connect-timeout 2 --max-time 6 "$URL_DEV" >/dev/null 2>&1; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,2000 \
      --virtual-time-budget=12000 \
      --dump-dom \
      "$URL_DEV" > "$DOM_DUMP" 2>"$RELEASE_DIR/chrome_dom.stderr" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,2000 \
      --virtual-time-budget=12000 \
      --screenshot="$SCREENSHOT" \
      "$URL_DEV" >/dev/null 2>"$RELEASE_DIR/chrome_screenshot.stderr" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"

    if [ "$DOM_RESULT" = "PASS" ]; then
      DOM_CHECK="$RELEASE_DIR/dom_checks.txt"
      {
        grep -q "V35 DYNAMIC SCENARIO ENGINE" "$DOM_DUMP" && echo "OK: V35 marker visible in DOM" || echo "MISS: V35 marker visible in DOM"
        grep -q "RF / Telco / Antenna Interactive Knowledge Scenarios" "$DOM_DUMP" && echo "OK: V35 title visible in DOM" || echo "MISS: V35 title visible in DOM"
        grep -q "Microstrip Patch Antenna" "$DOM_DUMP" && echo "OK: microstrip tab visible in DOM" || echo "MISS: microstrip tab visible in DOM"
        grep -q "Beamwidth and Coverage" "$DOM_DUMP" && echo "OK: beamwidth tab visible in DOM" || echo "MISS: beamwidth tab visible in DOM"
        grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$MAIN" || grep -q "Bridge Readiness" "$DOM_DUMP" && echo "OK: V34R1R2 preserved in DOM path" || echo "MISS: V34R1R2 preserved in DOM path"
        grep -q "trfmc-nginx-v21-api-fallback" "$DOM_DUMP" && echo "MISS: V21 fallback visible" || echo "OK: no V21 fallback visible"
      } > "$DOM_CHECK"

      cat "$DOM_CHECK"

      DOM_MISS="$(grep -c '^MISS:' "$DOM_CHECK" || true)"
      if [ "$DOM_MISS" -ne 0 ]; then
        DOM_RESULT="FAIL"
      fi
    fi
  fi
fi

echo "DOM result       : $DOM_RESULT"
echo "Screenshot result: $SCREENSHOT_RESULT"

echo
echo "=== CREATE ROLLBACK ==="

ROLLBACK="$RELEASE_DIR/rollback_v35_dynamic_scenarios.sh"

cat > "$ROLLBACK" <<ROLLBACK_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"

cp "$RELEASE_DIR/main.tsx.before_v35_$TS" frontend/src/app/main.tsx
cp "$RELEASE_DIR/styles.css.before_v35_$TS" frontend/src/styles.css

rm -rf frontend/src/rf_scenarios
rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios.tsx

echo "Rollback V35 Dynamic Scenarios completato"
ROLLBACK_EOF

chmod +x "$ROLLBACK"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$BUILD_RESULT" = "FAIL" ] || [ "$DOM_RESULT" = "FAIL" ]; then
  RESULT="FAIL"
fi

echo
echo "=== MANIFEST / SUMMARY ==="

MANIFEST="$RELEASE_DIR/dynamic_rf_telco_scenarios_manifest_v35.json"
SUMMARY="$QUALITY_DIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35",
  "strategy": "dynamic_scenario_engine_mounted_above_existing_v34r1r2_operational_deck",
  "frontend_mutation": true,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "created": [
    "$DATA",
    "$ENGINE",
    "$WRAPPER"
  ],
  "patched": [
    "$MAIN",
    "$STYLES"
  ],
  "scenario_count": 7,
  "scenarios": [
    "electronics",
    "microstrip",
    "antenna-system",
    "tower-infrastructure",
    "beamwidth",
    "rf-lab",
    "uav-isr"
  ],
  "pre_freeze": "$PRE_FREEZE",
  "rollback": "$ROLLBACK",
  "miss_count": $MISS_COUNT,
  "build_result": "$BUILD_RESULT",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V35",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "pre_freeze": "$PRE_FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "build_log": "$BUILD_LOG",
  "rollback": "$ROLLBACK",
  "dom_dump": "$DOM_DUMP",
  "screenshot": "$SCREENSHOT",
  "scenario_count": 7,
  "miss_count": $MISS_COUNT,
  "build_result": "$BUILD_RESULT",
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_scenarios \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios.tsx \
  "$RELEASE_DIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_dynamic_rf_telco_scenarios_v35"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_dynamic_rf_telco_scenarios_v35"

cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V35 DYNAMIC RF/TELCO SCENARIOS COMPLETATO"
echo "Rollback: $ROLLBACK"
echo "============================================================"

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: risultato $RESULT"
  exit 1
fi
