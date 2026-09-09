#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V36_VISUAL_RUNTIME_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V36_VISUAL_RUNTIME_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V36_VISUAL_RUNTIME_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"

DATA_V35="$ROOT/frontend/src/rf_scenarios/scenarioDataV35.ts"
ENGINE_V36="$ROOT/frontend/src/rf_scenarios/RFDynamicScenarioDeckV36.tsx"
WRAPPER_V36="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV36VisualScenarioRuntime.tsx"

CONTENT_CHECK="$RDIR/content_checks.txt"
BUILD_LOG="$RDIR/npm_build_v36.log"
HTTP_TSV="$RDIR/http.tsv"

mkdir -p "$QDIR" "$RDIR" runtime/freezes

echo "============================================================"
echo "TRFMC V36 DYNAMIC RF/TELCO VISUAL SCENARIO RUNTIME"
echo "asset-ready scenes · interactive layers · V34R1R2 preserved"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$STYLES" || { echo "ERRORE: styles.css mancante"; exit 1; }
test -f "$DATA_V35" || { echo "ERRORE: scenarioDataV35.ts mancante"; exit 1; }

test -f "$ROOT/runtime/quality/latest_dynamic_rf_telco_scenarios_v35/summary.json" || {
  echo "ERRORE: V35 summary mancante"
  exit 1
}

V35_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_dynamic_rf_telco_scenarios_v35/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V35_RESULT" = "PASS" ] || {
  echo "ERRORE: V35 non PASS: $V35_RESULT"
  exit 1
}

grep -q "RFOperationalDeckV35DynamicScenarios" "$MAIN" || {
  echo "ERRORE: main.tsx non monta V35; non procedo"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: API 4181 non operative"
  exit 1
}

echo "OK: V35 PASS, mount attivo corretto, API live"

echo
echo "=== BACKUP PRE-PATCH ==="

PRE_FREEZE="$ROOT/runtime/freezes/TRFMC_BEFORE_DYNAMIC_RF_TELCO_SCENARIOS_V36_$TS.tar.gz"

tar -czf "$PRE_FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_scenarios \
  frontend/src/rf_instruments/instruments \
  2>/dev/null || true

cp "$MAIN" "$RDIR/main.tsx.before_v36_$TS"
cp "$STYLES" "$RDIR/styles.css.before_v36_$TS"

echo "Pre-freeze: $PRE_FREEZE"

echo
echo "=== CREATE V36 VISUAL SCENARIO ENGINE ==="

cat > "$ENGINE_V36" <<'TSX'
import { useMemo, useState } from 'react'
import { rfScenariosV35, type RFScenario } from './scenarioDataV35'

type LayerKey = 'render' | 'physics' | 'metrics' | 'hotspots'

const assetHints: Record<string, string> = {
  electronics: '/trfmc_assets/visual_knowledge/01_electronics_symbols/electronics_symbols_basic_concepts.jpg',
  microstrip: '/trfmc_assets/visual_knowledge/02_antennas_microstrip/microstrip_patch_antenna_5g.jpg',
  'antenna-system': '/trfmc_assets/visual_knowledge/03_antennas_types/types_of_telecom_antennas.jpg',
  'tower-infrastructure': '/trfmc_assets/visual_knowledge/04_telco_infrastructure/telecom_towers_arabic_overview.jpg',
  beamwidth: '/trfmc_assets/visual_knowledge/03_antennas_types/beamwidth_narrow_wide.jpg',
  'rf-lab': '/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.jpg',
  'uav-isr': '/trfmc_assets/visual_knowledge/06_uav_rf_links/falco_xplorer_vs_bayraktar_tb2.jpg',
}

const sceneProfiles: Record<string, { stack: string; equation: string; instrument: string; action: string }> = {
  electronics: {
    stack: 'schematic → PCB → measurement',
    equation: 'V = I · R',
    instrument: 'DMM / Scope / Logic',
    action: 'Symbol-to-measurement mapping',
  },
  microstrip: {
    stack: 'patch → substrate → feed → ground',
    equation: 'S11 / Zin / εr',
    instrument: 'VNA / EM solver',
    action: 'Impedance and radiation analysis',
  },
  'antenna-system': {
    stack: 'element → array → sector → coverage',
    equation: 'G(θ,φ), HPBW',
    instrument: 'Antenna range / VSA',
    action: 'Pattern and application selection',
  },
  'tower-infrastructure': {
    stack: 'antenna → RRU/AAU → backhaul → core',
    equation: 'EIRP + link budget',
    instrument: 'NOC / spectrum / field test',
    action: 'Physical-logical site mapping',
  },
  beamwidth: {
    stack: 'main lobe → -3 dB points → coverage',
    equation: 'HPBW @ -3 dB',
    instrument: 'Spectrum / drive test',
    action: 'Coverage vs interference tradeoff',
  },
  'rf-lab': {
    stack: 'source → DUT → receiver → analysis',
    equation: 'S-parameters',
    instrument: 'VNA / VSA / SA',
    action: 'Measurement chain validation',
  },
  'uav-isr': {
    stack: 'airframe → payload → datalink → GCS',
    equation: 'C/N0, link margin',
    instrument: 'SDR / spectrum / telemetry',
    action: 'ISR RF link awareness',
  },
}

function ProceduralRender({ scenario, layers }: { scenario: RFScenario; layers: Record<LayerKey, boolean> }) {
  return (
    <div className={`v36-procedural v36-procedural-${scenario.visualMode}`}>
      <div className="v36-perspective-grid" />
      <div className="v36-atmosphere" />

      {layers.render ? (
        <div className="v36-render-stage">
          <div className="v36-render-core" />
          <div className="v36-render-secondary" />
          <div className="v36-render-tertiary" />
          <div className="v36-render-signal" />
        </div>
      ) : null}

      {layers.physics ? (
        <div className="v36-physics-layer">
          <div className="v36-field-lobe v36-field-a" />
          <div className="v36-field-lobe v36-field-b" />
          <div className="v36-vector-lines">
            {Array.from({ length: 9 }).map((_, index) => (
              <span key={index} style={{ transform: `rotate(${index * 20 - 80}deg)` }} />
            ))}
          </div>
        </div>
      ) : null}

      {layers.hotspots ? (
        <>
          {scenario.hotspots.map((hotspot) => (
            <button
              key={hotspot.id}
              type="button"
              className="v36-hotspot"
              style={{ left: `${hotspot.x}%`, top: `${hotspot.y}%` }}
              title={`${hotspot.label}: ${hotspot.value}`}
            >
              <i />
              <strong>{hotspot.label}</strong>
              <small>{hotspot.value}</small>
            </button>
          ))}
        </>
      ) : null}

      {layers.metrics ? (
        <div className="v36-floating-metrics">
          {scenario.kpis.map((kpi) => (
            <article key={`${scenario.id}-${kpi.label}`}>
              <span>{kpi.label}</span>
              <strong>{kpi.value}</strong>
            </article>
          ))}
        </div>
      ) : null}
    </div>
  )
}

export function RFDynamicScenarioDeckV36() {
  const [activeId, setActiveId] = useState(rfScenariosV35[0]?.id ?? 'electronics')
  const [layers, setLayers] = useState<Record<LayerKey, boolean>>({
    render: true,
    physics: true,
    metrics: true,
    hotspots: true,
  })

  const active = useMemo(
    () => rfScenariosV35.find((scenario) => scenario.id === activeId) ?? rfScenariosV35[0],
    [activeId],
  )

  const profile = sceneProfiles[active.id] ?? sceneProfiles.electronics
  const assetUrl = assetHints[active.id]

  const toggleLayer = (layer: LayerKey) => {
    setLayers((current) => ({ ...current, [layer]: !current[layer] }))
  }

  return (
    <section className="v36-scenario-shell">
      <div className="v36-scenario-header">
        <div>
          <p>V36 VISUAL SCENARIO RUNTIME</p>
          <h2>Dynamic RF/Telco Scenario Simulator</h2>
          <span>
            Scenari dinamici con render procedurale, layer fisici, hotspot, metriche e predisposizione asset 3D.
          </span>
        </div>
        <div className="v36-status-pack">
          <strong>{rfScenariosV35.length}</strong>
          <small>active scenarios</small>
        </div>
      </div>

      <div className="v36-tabs" role="tablist" aria-label="V36 scenario selector">
        {rfScenariosV35.map((scenario) => (
          <button
            key={scenario.id}
            type="button"
            className={scenario.id === active.id ? 'v36-tab-active' : ''}
            onClick={() => setActiveId(scenario.id)}
          >
            {scenario.title}
          </button>
        ))}
      </div>

      <div className="v36-layer-switches" aria-label="Scenario visual layers">
        {(['render', 'physics', 'metrics', 'hotspots'] as LayerKey[]).map((layer) => (
          <button
            key={layer}
            type="button"
            className={layers[layer] ? 'v36-layer-on' : ''}
            onClick={() => toggleLayer(layer)}
          >
            {layer}
          </button>
        ))}
      </div>

      <div className="v36-layout">
        <div className="v36-visual-column">
          <div className="v36-asset-frame" style={{ backgroundImage: `linear-gradient(90deg, rgba(2,9,17,.82), rgba(2,9,17,.34)), url(${assetUrl})` }}>
            <div>
              <span>asset-ready reference layer</span>
              <strong>{active.title}</strong>
              <small>{assetUrl}</small>
            </div>
          </div>

          <ProceduralRender scenario={active} layers={layers} />
        </div>

        <aside className="v36-control-panel">
          <p className="v36-eyebrow">{active.subtitle}</p>
          <h3>{active.title}</h3>
          <p>{active.mission}</p>

          <div className="v36-profile-grid">
            <article>
              <span>Signal stack</span>
              <strong>{profile.stack}</strong>
            </article>
            <article>
              <span>Equation / model</span>
              <strong>{profile.equation}</strong>
            </article>
            <article>
              <span>Instrument</span>
              <strong>{profile.instrument}</strong>
            </article>
            <article>
              <span>Scenario action</span>
              <strong>{profile.action}</strong>
            </article>
          </div>

          <div className="v36-knowledge-list">
            {active.knowledge.map((item, index) => (
              <div key={`${active.id}-${index}`}>
                <span>{index + 1}</span>
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
echo "=== CREATE V36 ACTIVE WRAPPER ==="

cat > "$WRAPPER_V36" <<'TSX'
import { RFOperationalDeckV34R1NativeBridgeVisible } from './RFOperationalDeckV34R1NativeBridgeVisible'
import { RFDynamicScenarioDeckV36 } from '../../rf_scenarios/RFDynamicScenarioDeckV36'

export function RFOperationalDeckV36VisualScenarioRuntime() {
  return (
    <>
      <RFDynamicScenarioDeckV36 />
      <RFOperationalDeckV34R1NativeBridgeVisible />
    </>
  )
}
TSX

echo
echo "=== APPEND V36 CSS ==="

if ! grep -q "TRFMC V36 VISUAL SCENARIO RUNTIME" "$STYLES"; then
cat >> "$STYLES" <<'CSS'

/* === TRFMC V36 VISUAL SCENARIO RUNTIME === */
.v36-scenario-shell{
  margin:18px;
  padding:18px;
  border:1px solid rgba(92,211,255,.25);
  border-radius:26px;
  background:
    radial-gradient(circle at 10% 0%,rgba(70,200,255,.18),transparent 34%),
    radial-gradient(circle at 90% 8%,rgba(255,166,74,.12),transparent 28%),
    linear-gradient(135deg,rgba(3,10,20,.98),rgba(2,8,15,.98));
  box-shadow:0 30px 90px rgba(0,0,0,.42), inset 0 0 42px rgba(80,215,255,.05);
}

.v36-scenario-header{
  display:flex;
  justify-content:space-between;
  gap:20px;
  align-items:flex-start;
  margin-bottom:14px;
}

.v36-scenario-header p,
.v36-eyebrow{
  margin:0 0 6px;
  color:#6deaff;
  font-size:11px;
  letter-spacing:.22em;
  text-transform:uppercase;
}

.v36-scenario-header h2{
  margin:0;
  color:#f1fbff;
  font-size:24px;
}

.v36-scenario-header span{
  display:block;
  margin-top:8px;
  color:#94aec4;
  font-size:13px;
}

.v36-status-pack{
  min-width:120px;
  padding:12px;
  border-radius:18px;
  border:1px solid rgba(141,255,189,.24);
  background:rgba(5,36,34,.58);
  text-align:center;
}

.v36-status-pack strong{
  display:block;
  color:#8dffbd;
  font-size:25px;
}

.v36-status-pack small{
  color:#9bb7a9;
}

.v36-tabs,
.v36-layer-switches{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  margin-bottom:12px;
}

.v36-tabs button,
.v36-layer-switches button{
  border:1px solid rgba(103,198,255,.22);
  border-radius:999px;
  padding:8px 12px;
  background:rgba(6,19,34,.78);
  color:#a6bdd2;
  cursor:pointer;
  font-size:12px;
}

.v36-tabs button.v36-tab-active,
.v36-layer-switches button.v36-layer-on{
  color:#06131d;
  background:linear-gradient(135deg,#75eaff,#8dffbd);
  border-color:transparent;
  box-shadow:0 0 20px rgba(108,231,255,.22);
}

.v36-layout{
  display:grid;
  grid-template-columns:minmax(0,1.45fr) minmax(340px,.8fr);
  gap:16px;
}

.v36-visual-column{
  display:grid;
  gap:14px;
}

.v36-asset-frame{
  min-height:150px;
  border:1px solid rgba(103,198,255,.20);
  border-radius:22px;
  background-size:cover;
  background-position:center;
  overflow:hidden;
  display:flex;
  align-items:flex-end;
  padding:16px;
}

.v36-asset-frame div{
  max-width:680px;
  padding:12px 14px;
  border:1px solid rgba(255,255,255,.12);
  border-radius:16px;
  background:rgba(3,12,22,.74);
  backdrop-filter:blur(6px);
}

.v36-asset-frame span{
  display:block;
  color:#6deaff;
  font-size:10px;
  letter-spacing:.18em;
  text-transform:uppercase;
}

.v36-asset-frame strong{
  display:block;
  color:#f2fbff;
  font-size:20px;
  margin:3px 0;
}

.v36-asset-frame small{
  color:#8aa7bc;
  word-break:break-all;
}

.v36-procedural{
  position:relative;
  min-height:440px;
  overflow:hidden;
  border-radius:24px;
  border:1px solid rgba(103,198,255,.22);
  background:
    radial-gradient(circle at 44% 38%,rgba(83,225,255,.12),transparent 32%),
    linear-gradient(180deg,rgba(8,29,48,.86),rgba(2,8,17,.98));
}

.v36-perspective-grid{
  position:absolute;
  inset:0;
  background:
    linear-gradient(rgba(112,231,255,.08) 1px,transparent 1px),
    linear-gradient(90deg,rgba(112,231,255,.08) 1px,transparent 1px);
  background-size:44px 44px;
  transform:perspective(620px) rotateX(60deg) translateY(210px) scale(1.9);
  opacity:.52;
}

.v36-atmosphere{
  position:absolute;
  inset:0;
  background:
    radial-gradient(circle at 25% 28%,rgba(80,215,255,.17),transparent 30%),
    radial-gradient(circle at 74% 44%,rgba(255,183,72,.15),transparent 26%);
  animation:v36Glow 5s ease-in-out infinite alternate;
}

@keyframes v36Glow{
  from{opacity:.50}
  to{opacity:.95}
}

.v36-render-stage{
  position:absolute;
  inset:0;
  z-index:2;
}

.v36-render-core,
.v36-render-secondary,
.v36-render-tertiary,
.v36-render-signal{
  position:absolute;
  box-shadow:0 20px 50px rgba(0,0,0,.34);
}

.v36-render-core{
  left:28%;
  top:24%;
  width:32%;
  height:30%;
  border-radius:18px;
  background:linear-gradient(135deg,#dfe8ef,#7d929f);
  transform:perspective(720px) rotateX(56deg) rotateZ(-12deg);
}

.v36-render-secondary{
  left:18%;
  top:62%;
  width:22%;
  height:13%;
  border-radius:16px;
  background:linear-gradient(135deg,#d38743,#ffbf7b);
  transform:skewX(-16deg);
}

.v36-render-tertiary{
  right:18%;
  top:28%;
  width:17%;
  height:38%;
  border-radius:18px;
  background:linear-gradient(135deg,#eff4f6,#7f9099);
}

.v36-render-signal{
  left:42%;
  top:16%;
  width:170px;
  height:170px;
  border-radius:50%;
  background:radial-gradient(circle,#ffe16d 0%,rgba(77,226,255,.72) 46%,transparent 70%);
  filter:blur(1px);
  opacity:.7;
  animation:v36Float 3.2s ease-in-out infinite alternate;
}

@keyframes v36Float{
  from{transform:translateY(0) scale(.92)}
  to{transform:translateY(-18px) scale(1.06)}
}

.v36-physics-layer{
  position:absolute;
  inset:0;
  z-index:3;
  pointer-events:none;
}

.v36-field-lobe{
  position:absolute;
  border-radius:50%;
  border:1px solid rgba(118,238,255,.35);
  background:radial-gradient(circle,rgba(118,238,255,.20),transparent 68%);
}

.v36-field-a{
  left:24%;
  top:18%;
  width:250px;
  height:250px;
}

.v36-field-b{
  right:18%;
  top:30%;
  width:210px;
  height:210px;
  background:radial-gradient(circle,rgba(141,255,189,.16),transparent 68%);
}

.v36-vector-lines{
  position:absolute;
  left:50%;
  top:48%;
  width:1px;
  height:1px;
}

.v36-vector-lines span{
  position:absolute;
  left:-210px;
  top:0;
  width:420px;
  height:1px;
  background:linear-gradient(90deg,transparent,rgba(117,234,255,.42),transparent);
  transform-origin:center;
}

.v36-hotspot{
  position:absolute;
  z-index:6;
  min-width:136px;
  transform:translate(-50%,-50%);
  padding:8px 10px;
  border-radius:15px;
  border:1px solid rgba(117,234,255,.34);
  background:rgba(3,13,24,.76);
  color:#eefcff;
  text-align:left;
  box-shadow:0 0 22px rgba(80,215,255,.16);
}

.v36-hotspot i{
  position:absolute;
  left:-10px;
  top:50%;
  width:11px;
  height:11px;
  border-radius:50%;
  transform:translateY(-50%);
  background:#75eaff;
  box-shadow:0 0 18px #75eaff;
}

.v36-hotspot strong{
  display:block;
  color:#8ff4ff;
  font-size:11px;
}

.v36-hotspot small{
  display:block;
  margin-top:3px;
  color:#cce4f3;
  font-size:10px;
}

.v36-floating-metrics{
  position:absolute;
  left:16px;
  bottom:16px;
  z-index:7;
  display:flex;
  gap:8px;
  flex-wrap:wrap;
}

.v36-floating-metrics article{
  min-width:96px;
  padding:9px 10px;
  border-radius:14px;
  border:1px solid rgba(141,255,189,.22);
  background:rgba(6,31,30,.72);
}

.v36-floating-metrics span{
  display:block;
  color:#94adbd;
  font-size:10px;
  text-transform:uppercase;
}

.v36-floating-metrics strong{
  color:#8dffbd;
}

.v36-control-panel{
  padding:16px;
  border-radius:24px;
  border:1px solid rgba(103,198,255,.18);
  background:rgba(5,17,31,.76);
}

.v36-control-panel h3{
  margin:0 0 8px;
  color:#f3fbff;
  font-size:25px;
}

.v36-control-panel > p:not(.v36-eyebrow){
  color:#a9bed0;
  line-height:1.45;
}

.v36-profile-grid{
  display:grid;
  grid-template-columns:1fr;
  gap:9px;
  margin:14px 0;
}

.v36-profile-grid article{
  padding:10px;
  border:1px solid rgba(103,198,255,.16);
  border-radius:15px;
  background:rgba(8,25,42,.64);
}

.v36-profile-grid span{
  display:block;
  color:#6deaff;
  font-size:10px;
  text-transform:uppercase;
  letter-spacing:.12em;
  margin-bottom:4px;
}

.v36-profile-grid strong{
  color:#eaf7ff;
  font-size:13px;
}

.v36-knowledge-list{
  display:grid;
  gap:9px;
}

.v36-knowledge-list div{
  display:grid;
  grid-template-columns:34px 1fr;
  gap:10px;
  padding:10px;
  border-radius:14px;
  border:1px solid rgba(141,255,189,.14);
  background:rgba(7,31,31,.48);
}

.v36-knowledge-list span{
  color:#8dffbd;
  font-weight:800;
}

.v36-knowledge-list p{
  margin:0;
  color:#c2d5e4;
  font-size:12px;
  line-height:1.42;
}

.v36-procedural-electronics .v36-render-core{background:linear-gradient(135deg,#123655,#2f88bb)}
.v36-procedural-microstrip .v36-render-core{background:linear-gradient(135deg,#c66b2d,#ffb06d)}
.v36-procedural-antenna-system .v36-render-tertiary{height:46%;border-radius:12px}
.v36-procedural-tower-infrastructure .v36-render-tertiary{height:62%;top:18%;width:9%}
.v36-procedural-beamwidth .v36-render-signal{width:360px;height:120px;border-radius:60%}
.v36-procedural-rf-lab .v36-render-core{background:linear-gradient(135deg,#182d43,#68d9ff)}
.v36-procedural-uav-isr .v36-render-core{border-radius:50%;height:12%;top:42%;width:42%}

@media (max-width:1120px){
  .v36-layout{grid-template-columns:1fr}
}

@media (max-width:760px){
  .v36-scenario-header{flex-direction:column}
  .v36-procedural{min-height:360px}
  .v36-tabs button,
  .v36-layer-switches button{font-size:11px}
}
CSS
fi

echo
echo "=== PATCH main.tsx V35 -> V36 ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import sys

p=Path(sys.argv[1])
txt=p.read_text(encoding="utf-8")

old_import="import { RFOperationalDeckV35DynamicScenarios } from '../rf_instruments/instruments/RFOperationalDeckV35DynamicScenarios'"
new_import="import { RFOperationalDeckV36VisualScenarioRuntime } from '../rf_instruments/instruments/RFOperationalDeckV36VisualScenarioRuntime'"

if new_import not in txt:
    if old_import not in txt:
        raise SystemExit("ERRORE: import V35 non trovato")
    txt=txt.replace(old_import,new_import,1)

txt=txt.replace("<RFOperationalDeckV35DynamicScenarios />","<RFOperationalDeckV36VisualScenarioRuntime />")

p.write_text(txt, encoding="utf-8")
print("OK: main.tsx patched to V36 visual scenario runtime")
PY

echo
echo "=== STATIC CHECKS ==="

{
  test -f "$ENGINE_V36" && echo "OK: V36 engine exists" || echo "MISS: V36 engine exists"
  test -f "$WRAPPER_V36" && echo "OK: V36 wrapper exists" || echo "MISS: V36 wrapper exists"
  grep -q "RFDynamicScenarioDeckV36" "$ENGINE_V36" && echo "OK: V36 deck export exists" || echo "MISS: V36 deck export exists"
  grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$WRAPPER_V36" && echo "OK: V34R1R2 preserved below V36" || echo "MISS: V34R1R2 preserved below V36"
  grep -q "RFOperationalDeckV36VisualScenarioRuntime" "$MAIN" && echo "OK: main imports/mounts V36" || echo "MISS: main imports/mounts V36"
  grep -q "<RFOperationalDeckV36VisualScenarioRuntime />" "$MAIN" && echo "OK: main JSX mounts V36" || echo "MISS: main JSX mounts V36"
  grep -q "V36 VISUAL SCENARIO RUNTIME" "$ENGINE_V36" && echo "OK: V36 marker present" || echo "MISS: V36 marker present"
  grep -q "asset-ready reference layer" "$ENGINE_V36" && echo "OK: asset-ready layer present" || echo "MISS: asset-ready layer present"
  grep -q "v36-scenario-shell" "$STYLES" && echo "OK: V36 CSS present" || echo "MISS: V36 CSS present"
  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/spectrum/sweep | grep -q "TRFMC_CONTRACT_COVERAGE_V31" && echo "OK: backend contracts still live" || echo "MISS: backend contracts still live"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

echo
echo "=== BUILD CHECK ==="

(
  cd "$ROOT/frontend"
  npm run build > "$BUILD_LOG" 2>&1
) && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"

echo "Build result: $BUILD_RESULT"

if [ "$BUILD_RESULT" = "FAIL" ]; then
  tail -n 180 "$BUILD_LOG" || true
fi

echo
echo "=== HTTP GATE ==="

if ! curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:5173/ >/dev/null 2>&1; then
  (
    cd "$ROOT/frontend"
    nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$RDIR/vite_dev_5173.log" 2>&1 &
    echo $! > "$RDIR/vite_dev_5173.pid"
  )
  sleep 4
fi

printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="$(printf "%s" "$meta" | awk '{print $1}')"
  bytes="$(printf "%s" "$meta" | awk '{print $2}')"
  printf "%s\t%s\t%s\n" "$u" "${code:-000}" "${bytes:-0}" >> "$HTTP_TSV"
}

for u in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:4181/api/mission/status \
  http://127.0.0.1:4181/api/core/open5gs/status \
  http://127.0.0.1:4181/api/rfpro/spectrum/sweep
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== CREATE ROLLBACK ==="

ROLLBACK="$RDIR/rollback_v36_visual_scenario_runtime.sh"

cat > "$ROLLBACK" <<ROLLBACK_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"

cp "$RDIR/main.tsx.before_v36_$TS" frontend/src/app/main.tsx
cp "$RDIR/styles.css.before_v36_$TS" frontend/src/styles.css
rm -f frontend/src/rf_scenarios/RFDynamicScenarioDeckV36.tsx
rm -f frontend/src/rf_instruments/instruments/RFOperationalDeckV36VisualScenarioRuntime.tsx

echo "Rollback V36 Visual Scenario Runtime completato"
ROLLBACK_EOF

chmod +x "$ROLLBACK"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$BUILD_RESULT" = "FAIL" ] || [ "$HTTP_NON_200" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

MANIFEST="$RDIR/dynamic_rf_telco_scenarios_visual_runtime_manifest_v36.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V36_VISUAL_RUNTIME",
  "strategy": "upgrade_v35_dynamic_scenarios_to_asset_ready_visual_runtime",
  "frontend_mutation": true,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "created": [
    "$ENGINE_V36",
    "$WRAPPER_V36"
  ],
  "patched": [
    "$MAIN",
    "$STYLES"
  ],
  "pre_freeze": "$PRE_FREEZE",
  "rollback": "$ROLLBACK",
  "scenario_count": 7,
  "features": [
    "asset_ready_reference_layer",
    "procedural_3d_visual_stage",
    "physics_overlay",
    "hotspot_toggle",
    "metrics_toggle",
    "scenario_profile_panel",
    "preserve_v34r1r2_live_contract_deck"
  ],
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DYNAMIC_RF_TELCO_SCENARIOS_V36_VISUAL_RUNTIME",
  "release_dir": "$RDIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "pre_freeze": "$PRE_FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "build_log": "$BUILD_LOG",
  "rollback": "$ROLLBACK",
  "scenario_count": 7,
  "miss_count": $MISS_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_scenarios \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV36VisualScenarioRuntime.tsx \
  "$RDIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_dynamic_rf_telco_scenarios_v36"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_dynamic_rf_telco_scenarios_v36"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: risultato $RESULT"
  exit 1
fi

echo
echo "============================================================"
echo "V36 VISUAL SCENARIO RUNTIME COMPLETATO IN PASS"
echo "============================================================"
