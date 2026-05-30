#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

DOMAIN_DIR="frontend/src/domains/antenna-system"
REGISTRY="$DOMAIN_DIR/antennaSystemRegistry.ts"
CANVAS="$DOMAIN_DIR/AntennaRadiationCanvasP3.tsx"
DOMAIN="$DOMAIN_DIR/AntennaSystemDomainP3.tsx"
ROUTE="frontend/src/app/AntennaSystemRouteP3.tsx"
ORCH="frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_p3b_antenna_system_react_promotion_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p3b_antenna_system_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p3b_antenna_system_react_promotion.diff"
STATIC_GATE="$OUT/static_gate.tsv"
RESTORE="$OUT/RESTORE_P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1.sh"

safe_count_files() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn -E "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

safe_count_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return 0
  fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1"
echo "Antenna System React domain · radiation pattern · RRU/RET/CPRI mapping · QA"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ORCH" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file richiesto mancante: $f"
    exit 1
  fi
done

mkdir -p "$DOMAIN_DIR"

for f in "$REGISTRY" "$CANVAS" "$DOMAIN" "$ROUTE" "$ORCH" "$CSS"; do
  if [ -f "$f" ]; then
    cp -a "$f" "$BACKUP/$(basename "$f").before_$TS"
  fi
done

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

restore_or_remove() {
  local file="\$1"
  local backup="\$2"
  if [ -f "\$backup" ]; then
    cp -a "\$backup" "\$file"
  else
    rm -f "\$file"
  fi
}

restore_or_remove "$REGISTRY" "$BACKUP/$(basename "$REGISTRY").before_$TS"
restore_or_remove "$CANVAS" "$BACKUP/$(basename "$CANVAS").before_$TS"
restore_or_remove "$DOMAIN" "$BACKUP/$(basename "$DOMAIN").before_$TS"
restore_or_remove "$ROUTE" "$BACKUP/$(basename "$ROUTE").before_$TS"
restore_or_remove "$ORCH" "$BACKUP/$(basename "$ORCH").before_$TS"
restore_or_remove "$CSS" "$BACKUP/$(basename "$CSS").before_$TS"

echo "RESTORE_P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA antennaSystemRegistry.ts ==="

cat > "$REGISTRY" <<'TS'
export type AntennaSystemKpi = {
  id: string
  label: string
  value: string
  note: string
  state: 'ready' | 'derived' | 'review'
}

export type AntennaSystemMetric = {
  id: string
  label: string
  expression: string
  meaning: string
  unit: string
}

export type AntennaPortMap = {
  id: string
  chain: string
  rruPort: string
  cpri: string
  ret: string
  aisg: string
  polarization: string
  note: string
}

export type AntennaScenario = {
  id: string
  title: string
  objective: string
  evidence: string
}

export const antennaSystemPromotionSource = {
  phase: 'P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1',
  selectedSource: 'trfmc_antenna_rru_ret_cpri_port_mapping_v2',
  sourceScore: 259,
  contentHits: 21,
  canvasTags: 3,
  debtHits: 4,
  rule: 'Extract antenna, RRU, RET, CPRI, AISG, radiation pattern and port mapping concepts into React. Do not mount public HTML.',
}

export const antennaSystemKpis: AntennaSystemKpi[] = [
  {
    id: 'band',
    label: 'Band',
    value: 'n78 · 3.5 GHz',
    note: 'lab reference sector',
    state: 'ready',
  },
  {
    id: 'gain',
    label: 'Peak gain',
    value: '17.5 dBi',
    note: 'sector panel approximation',
    state: 'derived',
  },
  {
    id: 'hpbw',
    label: 'HPBW',
    value: '65° az · 8° el',
    note: 'horizontal / vertical beamwidth',
    state: 'derived',
  },
  {
    id: 'tilt',
    label: 'RET downtilt',
    value: '4.0°',
    note: 'remote electrical tilt model',
    state: 'ready',
  },
  {
    id: 'ports',
    label: 'RF chains',
    value: '8T8R',
    note: 'RRU/antenna port mapping',
    state: 'ready',
  },
  {
    id: 'cpri',
    label: 'Fronthaul',
    value: 'CPRI/AISG',
    note: 'mapping and supervision reference',
    state: 'review',
  },
]

export const antennaSystemMetrics: AntennaSystemMetric[] = [
  {
    id: 'gain-pattern',
    label: 'Normalized pattern gain',
    expression: 'G(θ,φ) = Gmax − A(θ,φ)',
    meaning: 'Directional gain model including azimuth and elevation attenuation.',
    unit: 'dBi',
  },
  {
    id: 'hpbw',
    label: 'Half-power beamwidth',
    expression: 'HPBW = θ₂ − θ₁ at Gmax − 3 dB',
    meaning: 'Angular width between half-power points of the main lobe.',
    unit: 'deg',
  },
  {
    id: 'downtilt',
    label: 'Electrical downtilt',
    expression: 'θeffective = θmechanical + θRET',
    meaning: 'Effective vertical steering after mechanical and remote electrical tilt.',
    unit: 'deg',
  },
  {
    id: 'eirp',
    label: 'EIRP',
    expression: 'EIRP(dBm) = Ptx + Gant − Lfeed',
    meaning: 'Equivalent isotropic radiated power for the antenna chain.',
    unit: 'dBm',
  },
  {
    id: 'front-back',
    label: 'Front-to-back ratio',
    expression: 'F/B = Gfront − Gback',
    meaning: 'Antenna discrimination between main direction and rear lobe.',
    unit: 'dB',
  },
  {
    id: 'mimo-map',
    label: 'MIMO chain mapping',
    expression: 'Layer ⇄ RF chain ⇄ RRU port ⇄ antenna element',
    meaning: 'Logical-to-physical mapping for sectorized MIMO operation.',
    unit: 'map',
  },
]

export const antennaPortMap: AntennaPortMap[] = [
  {
    id: 'p1',
    chain: 'TX/RX 1',
    rruPort: 'RRU A1',
    cpri: 'CPRI lane 0',
    ret: 'RET group A',
    aisg: 'AISG bus 1',
    polarization: '+45°',
    note: 'primary sector chain',
  },
  {
    id: 'p2',
    chain: 'TX/RX 2',
    rruPort: 'RRU A2',
    cpri: 'CPRI lane 1',
    ret: 'RET group A',
    aisg: 'AISG bus 1',
    polarization: '-45°',
    note: 'cross-polar pair',
  },
  {
    id: 'p3',
    chain: 'TX/RX 3',
    rruPort: 'RRU B1',
    cpri: 'CPRI lane 2',
    ret: 'RET group B',
    aisg: 'AISG bus 2',
    polarization: '+45°',
    note: 'upper sub-array',
  },
  {
    id: 'p4',
    chain: 'TX/RX 4',
    rruPort: 'RRU B2',
    cpri: 'CPRI lane 3',
    ret: 'RET group B',
    aisg: 'AISG bus 2',
    polarization: '-45°',
    note: 'upper cross-polar pair',
  },
]

export const antennaScenarios: AntennaScenario[] = [
  {
    id: 'sector-coverage-baseline',
    title: 'Sector coverage baseline',
    objective: 'Validate azimuth pattern, gain, HPBW and front-to-back behavior.',
    evidence: 'Radiation canvas + KPI strip + pattern formula registry.',
  },
  {
    id: 'ret-downtilt-change',
    title: 'RET downtilt variation',
    objective: 'Show how electrical tilt affects vertical coverage and overshoot risk.',
    evidence: 'RET card + downtilt formula + elevation overlay.',
  },
  {
    id: 'rru-port-tracing',
    title: 'RRU/CPRI/AISG traceability',
    objective: 'Map RF chain to RRU port, CPRI lane, AISG bus and polarization.',
    evidence: 'Port mapping cards + chain table + QA marker.',
  },
]
TS

echo
echo "=== 2) CREA AntennaRadiationCanvasP3.tsx ==="

cat > "$CANVAS" <<'TSX'
import { useEffect, useRef } from 'react'

type AntennaRadiationCanvasP3Props = {
  widthHint?: number
  heightHint?: number
}

function degToRad(deg: number) {
  return (deg * Math.PI) / 180
}

function patternGain(angleDeg: number) {
  const main = Math.exp(-Math.pow(angleDeg / 34, 2))
  const sideA = 0.18 * Math.exp(-Math.pow((angleDeg - 72) / 18, 2))
  const sideB = 0.16 * Math.exp(-Math.pow((angleDeg + 72) / 18, 2))
  const rear = 0.08 * Math.exp(-Math.pow((Math.abs(angleDeg) - 180) / 32, 2))
  return Math.max(0.04, main + sideA + sideB + rear)
}

export function AntennaRadiationCanvasP3({ widthHint = 980, heightHint = 430 }: AntennaRadiationCanvasP3Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const pixelRatio = window.devicePixelRatio || 1
    const box = canvas.getBoundingClientRect()
    const width = Math.max(760, Math.floor(box.width || widthHint))
    const height = Math.max(360, Math.floor(box.height || heightHint))

    canvas.width = Math.floor(width * pixelRatio)
    canvas.height = Math.floor(height * pixelRatio)

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0)
    ctx.clearRect(0, 0, width, height)

    const bg = ctx.createLinearGradient(0, 0, width, height)
    bg.addColorStop(0, 'rgba(1, 14, 28, 1)')
    bg.addColorStop(0.58, 'rgba(0, 20, 28, 1)')
    bg.addColorStop(1, 'rgba(0, 5, 12, 1)')
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, width, height)

    const polarCx = width * 0.31
    const polarCy = height * 0.54
    const polarR = Math.min(width * 0.24, height * 0.39)

    ctx.strokeStyle = 'rgba(103, 232, 249, .18)'
    ctx.lineWidth = 1

    for (let ring = 1; ring <= 5; ring += 1) {
      ctx.beginPath()
      ctx.arc(polarCx, polarCy, polarR * ring / 5, 0, Math.PI * 2)
      ctx.stroke()
    }

    for (let deg = 0; deg < 360; deg += 30) {
      const a = degToRad(deg - 90)
      ctx.beginPath()
      ctx.moveTo(polarCx, polarCy)
      ctx.lineTo(polarCx + Math.cos(a) * polarR, polarCy + Math.sin(a) * polarR)
      ctx.stroke()
    }

    ctx.beginPath()
    for (let deg = -180; deg <= 180; deg += 2) {
      const gain = patternGain(deg)
      const r = polarR * (0.16 + gain * 0.84)
      const a = degToRad(deg - 90)
      const x = polarCx + Math.sin(a) * r
      const y = polarCy - Math.cos(a) * r
      if (deg === -180) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()

    const patternFill = ctx.createRadialGradient(polarCx, polarCy, polarR * 0.1, polarCx, polarCy, polarR)
    patternFill.addColorStop(0, 'rgba(134, 239, 172, .50)')
    patternFill.addColorStop(0.62, 'rgba(103, 232, 249, .32)')
    patternFill.addColorStop(1, 'rgba(14, 165, 233, .10)')

    ctx.fillStyle = patternFill
    ctx.fill()
    ctx.strokeStyle = 'rgba(134, 239, 172, .95)'
    ctx.lineWidth = 2
    ctx.stroke()

    ctx.fillStyle = '#e8f7ff'
    ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
    ctx.fillText('AZIMUTH RADIATION PATTERN · 65° HPBW · 17.5 dBi', 18, 24)

    ctx.fillStyle = '#86efac'
    ctx.fillText('RET 4.0° · 8T8R · +45/-45 cross-polar sector model', 18, 44)

    const panelX = width * 0.62
    const panelY = height * 0.16
    const panelW = width * 0.18
    const panelH = height * 0.62

    ctx.fillStyle = 'rgba(2, 10, 20, .88)'
    ctx.fillRect(panelX, panelY, panelW, panelH)
    ctx.strokeStyle = 'rgba(103, 232, 249, .42)'
    ctx.strokeRect(panelX, panelY, panelW, panelH)

    const elements = 8
    for (let i = 0; i < elements; i += 1) {
      const y = panelY + 22 + i * (panelH - 44) / (elements - 1)
      const grad = ctx.createLinearGradient(panelX, y, panelX + panelW, y)
      grad.addColorStop(0, 'rgba(103, 232, 249, .12)')
      grad.addColorStop(0.5, 'rgba(134, 239, 172, .70)')
      grad.addColorStop(1, 'rgba(103, 232, 249, .12)')
      ctx.fillStyle = grad
      ctx.fillRect(panelX + 16, y - 4, panelW - 32, 8)
    }

    ctx.fillStyle = '#67e8f9'
    ctx.fillText('ANTENNA PANEL', panelX + 16, panelY - 12)

    const mapX = width * 0.82
    const mapY = height * 0.18

    ctx.fillStyle = 'rgba(0, 0, 0, .32)'
    ctx.fillRect(mapX - 12, mapY - 26, width * 0.16, 178)
    ctx.strokeStyle = 'rgba(103, 232, 249, .32)'
    ctx.strokeRect(mapX - 12, mapY - 26, width * 0.16, 178)

    ctx.fillStyle = '#e8f7ff'
    ctx.fillText('RRU / RET / CPRI', mapX, mapY)

    const rows = [
      ['A1', 'CPRI0', '+45°'],
      ['A2', 'CPRI1', '-45°'],
      ['B1', 'CPRI2', '+45°'],
      ['B2', 'CPRI3', '-45°'],
    ]

    rows.forEach((row, idx) => {
      const y = mapY + 25 + idx * 30
      ctx.fillStyle = 'rgba(103, 232, 249, .10)'
      ctx.fillRect(mapX - 2, y - 14, width * 0.13, 22)
      ctx.strokeStyle = 'rgba(103, 232, 249, .18)'
      ctx.strokeRect(mapX - 2, y - 14, width * 0.13, 22)
      ctx.fillStyle = idx % 2 === 0 ? '#86efac' : '#67e8f9'
      ctx.fillText(`${row[0]} · ${row[1]} · ${row[2]}`, mapX + 6, y)
    })

    ctx.strokeStyle = 'rgba(251, 191, 36, .70)'
    ctx.lineWidth = 2
    ctx.setLineDash([7, 6])
    ctx.beginPath()
    ctx.moveTo(polarCx, polarCy)
    ctx.bezierCurveTo(width * 0.42, height * 0.20, width * 0.50, height * 0.18, panelX, panelY + panelH * 0.40)
    ctx.stroke()
    ctx.setLineDash([])

    ctx.fillStyle = 'rgba(0, 0, 0, .35)'
    ctx.fillRect(18, height - 70, 430, 52)
    ctx.strokeStyle = 'rgba(103, 232, 249, .42)'
    ctx.strokeRect(18, height - 70, 430, 52)
    ctx.fillStyle = '#67e8f9'
    ctx.fillText('P3B ANTENNA SYSTEM · React Canvas', 30, height - 49)
    ctx.fillStyle = '#86efac'
    ctx.fillText('Radiation pattern · RRU/RET/CPRI/AISG · MIMO port mapping', 30, height - 29)
  }, [widthHint, heightHint])

  return (
    <canvas
      ref={canvasRef}
      className="trfmc-p3-antenna-canvas"
      aria-label="Antenna System radiation pattern and port mapping canvas"
    />
  )
}
TSX

echo
echo "=== 3) CREA AntennaSystemDomainP3.tsx ==="

cat > "$DOMAIN" <<'TSX'
import { AntennaRadiationCanvasP3 } from './AntennaRadiationCanvasP3'
import {
  antennaPortMap,
  antennaScenarios,
  antennaSystemKpis,
  antennaSystemMetrics,
  antennaSystemPromotionSource,
} from './antennaSystemRegistry'

export function AntennaSystemDomainP3() {
  return (
    <section className="trfmc-p3-antenna-domain" data-trfmc-p3-antenna-system-domain="mounted">
      <div className="trfmc-p3-antenna-head">
        <div>
          <p>P3B · Antenna System React Promotion</p>
          <h2>Antenna System · Radiation Pattern, RRU, RET, CPRI, AISG</h2>
          <span>
            Dominio Antenna System promosso dal candidato P3A. La vista porta nel portale React
            pattern di radiazione, KPI antenna, mapping RRU/RET/CPRI/AISG e scenari di collaudo.
          </span>
        </div>
        <article>
          <strong>{antennaSystemPromotionSource.sourceScore}</strong>
          <span>source score</span>
          <em>{antennaSystemPromotionSource.selectedSource}</em>
        </article>
      </div>

      <div className="trfmc-p3-antenna-kpi-grid">
        {antennaSystemKpis.map((kpi) => (
          <article key={kpi.id} data-state={kpi.state}>
            <span>{kpi.label}</span>
            <strong>{kpi.value}</strong>
            <em>{kpi.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p3-antenna-main-grid">
        <section className="trfmc-p3-antenna-panel trfmc-p3-antenna-canvas-panel">
          <div className="trfmc-p3-antenna-panel-head">
            <span>Visual model</span>
            <b>React Canvas · radiation / sector / port mapping</b>
          </div>
          <AntennaRadiationCanvasP3 />
        </section>

        <section className="trfmc-p3-antenna-panel">
          <div className="trfmc-p3-antenna-panel-head">
            <span>Engineering registry</span>
            <b>gain · HPBW · RET · EIRP</b>
          </div>
          <div className="trfmc-p3-antenna-metric-grid">
            {antennaSystemMetrics.map((item) => (
              <article key={item.id}>
                <span>{item.label}</span>
                <strong>{item.expression}</strong>
                <p>{item.meaning}</p>
                <em>{item.unit}</em>
              </article>
            ))}
          </div>
        </section>
      </div>

      <section className="trfmc-p3-antenna-panel">
        <div className="trfmc-p3-antenna-panel-head">
          <span>RRU / RET / CPRI / AISG</span>
          <b>port mapping traceability</b>
        </div>
        <div className="trfmc-p3-antenna-port-grid">
          {antennaPortMap.map((port) => (
            <article key={port.id}>
              <span>{port.chain}</span>
              <strong>{port.rruPort}</strong>
              <p>{port.cpri} · {port.ret} · {port.aisg}</p>
              <em>{port.polarization} · {port.note}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p3-antenna-panel">
        <div className="trfmc-p3-antenna-panel-head">
          <span>Scenario binding</span>
          <b>antenna evidence chain</b>
        </div>
        <div className="trfmc-p3-antenna-scenario-grid">
          {antennaScenarios.map((scenario) => (
            <article key={scenario.id}>
              <strong>{scenario.title}</strong>
              <span>{scenario.objective}</span>
              <em>{scenario.evidence}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p3-antenna-acceptance">
        <span>Acceptance rule</span>
        <strong>
          Build + HTTP + DOM marker + screenshot + static safety gate. No iframe, no unsafe HTML injection,
          no public HTML runtime link.
        </strong>
      </section>
    </section>
  )
}
TSX

echo
echo "=== 4) CREA AntennaSystemRouteP3.tsx ==="

cat > "$ROUTE" <<'TSX'
import { useEffect, useState } from 'react'
import { AntennaSystemDomainP3 } from '../domains/antenna-system/AntennaSystemDomainP3'

function currentHash() {
  if (typeof window === 'undefined') return ''
  return window.location.hash || ''
}

export function AntennaSystemRouteP3() {
  const [hash, setHash] = useState(currentHash)

  useEffect(() => {
    const onHashChange = () => setHash(currentHash())
    window.addEventListener('hashchange', onHashChange)
    onHashChange()
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  if (hash !== '#antenna-system') return null

  return <AntennaSystemDomainP3 />
}
TSX

echo
echo "=== 5) PATCH MissionLayoutOrchestratorV42.tsx ==="

python3 - "$ORCH" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
before = text

import_line = "import { AntennaSystemRouteP3 } from '../app/AntennaSystemRouteP3'"

if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

if "<AntennaSystemRouteP3 />" not in text:
    if "<SignalAnalyzerRouteP2 />" in text:
        text = text.replace(
            "<SignalAnalyzerRouteP2 />",
            "<SignalAnalyzerRouteP2 />\n        <AntennaSystemRouteP3 />",
            1,
        )
    elif "<RFPhysicsRouteP1 />" in text:
        text = text.replace(
            "<RFPhysicsRouteP1 />",
            "<RFPhysicsRouteP1 />\n        <AntennaSystemRouteP3 />",
            1,
        )
    elif "<MissionControlContentP0C />" in text:
        text = text.replace(
            "<MissionControlContentP0C />",
            "<MissionControlContentP0C />\n        <AntennaSystemRouteP3 />",
            1,
        )
    else:
        raise SystemExit("ERRORE: mount point P0/P1/P2 non trovato")

path.write_text(text, encoding="utf-8")
print("ORCHESTRATOR_P3B_PATCHED=", before != text)
PY

echo
echo "=== 6) PATCH styles.css ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC P3B ANTENNA SYSTEM REACT PROMOTION V1 START === \*/.*?/\* === TRFMC P3B ANTENNA SYSTEM REACT PROMOTION V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC P3B ANTENNA SYSTEM REACT PROMOTION V1 START === */
.trfmc-p3-antenna-domain {
  margin-top: 8px;
  padding: 10px;
  border: 1px solid rgba(103, 232, 249, .17);
  border-radius: 14px;
  background:
    radial-gradient(circle at 13% 0%, rgba(134, 239, 172, .09), transparent 34%),
    radial-gradient(circle at 86% 18%, rgba(103, 232, 249, .08), transparent 30%),
    linear-gradient(180deg, rgba(2, 12, 24, .78), rgba(0, 5, 13, .90));
}

.trfmc-p3-antenna-head {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 210px;
  gap: 10px;
  align-items: stretch;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(103, 232, 249, .13);
}

.trfmc-p3-antenna-head p,
.trfmc-p3-antenna-panel-head span,
.trfmc-p3-antenna-acceptance span {
  margin: 0 0 4px 0;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.trfmc-p3-antenna-head h2 {
  margin: 0 0 5px 0;
  color: #e8f7ff;
  font-size: 18px;
  line-height: 1.05;
}

.trfmc-p3-antenna-head span {
  color: #9fb8ca;
  font-size: 10.5px;
  line-height: 1.34;
}

.trfmc-p3-antenna-head article {
  display: grid;
  align-content: center;
  justify-items: center;
  border: 1px solid rgba(134, 239, 172, .18);
  border-radius: 12px;
  background: rgba(8, 47, 38, .18);
  padding: 8px;
  text-align: center;
}

.trfmc-p3-antenna-head article strong {
  color: #86efac;
  font-size: 26px;
  line-height: 1;
}

.trfmc-p3-antenna-head article span {
  color: #9fb8ca;
  font-size: 8px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p3-antenna-head article em {
  margin-top: 5px;
  color: #67e8f9;
  font-size: 8.5px;
  font-style: normal;
  word-break: break-word;
}

.trfmc-p3-antenna-kpi-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 7px;
  margin-top: 8px;
}

.trfmc-p3-antenna-kpi-grid article,
.trfmc-p3-antenna-metric-grid article,
.trfmc-p3-antenna-port-grid article,
.trfmc-p3-antenna-scenario-grid article,
.trfmc-p3-antenna-acceptance {
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 10px;
  background: rgba(0, 4, 10, .26);
  padding: 8px;
  min-width: 0;
}

.trfmc-p3-antenna-kpi-grid article[data-state="ready"] {
  border-color: rgba(134, 239, 172, .18);
}

.trfmc-p3-antenna-kpi-grid article[data-state="review"] {
  border-color: rgba(251, 191, 36, .23);
}

.trfmc-p3-antenna-kpi-grid span,
.trfmc-p3-antenna-metric-grid span,
.trfmc-p3-antenna-port-grid span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.trfmc-p3-antenna-kpi-grid strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 12px;
}

.trfmc-p3-antenna-kpi-grid em {
  display: block;
  margin-top: 4px;
  color: #9fb8ca;
  font-size: 8.8px;
  font-style: normal;
  line-height: 1.22;
}

.trfmc-p3-antenna-main-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.18fr) minmax(360px, .82fr);
  gap: 8px;
  margin-top: 8px;
}

.trfmc-p3-antenna-panel {
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 12px;
  background: rgba(2, 10, 20, .38);
  padding: 9px;
  margin-top: 8px;
}

.trfmc-p3-antenna-main-grid .trfmc-p3-antenna-panel {
  margin-top: 0;
}

.trfmc-p3-antenna-panel-head {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  align-items: baseline;
  padding-bottom: 7px;
  margin-bottom: 7px;
  border-bottom: 1px solid rgba(103, 232, 249, .12);
}

.trfmc-p3-antenna-panel-head b {
  color: #86efac;
  font-size: 9px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p3-antenna-canvas {
  width: 100%;
  min-height: 430px;
  display: block;
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 12px;
  background: #020711;
}

.trfmc-p3-antenna-metric-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 7px;
}

.trfmc-p3-antenna-metric-grid strong,
.trfmc-p3-antenna-port-grid strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 11px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.trfmc-p3-antenna-metric-grid p,
.trfmc-p3-antenna-port-grid p {
  margin: 5px 0 0 0;
  color: #9fb8ca;
  font-size: 9.5px;
  line-height: 1.26;
}

.trfmc-p3-antenna-metric-grid em,
.trfmc-p3-antenna-port-grid em {
  display: inline-block;
  margin-top: 6px;
  color: #86efac;
  font-size: 8px;
  font-style: normal;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p3-antenna-port-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 7px;
}

.trfmc-p3-antenna-scenario-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 7px;
}

.trfmc-p3-antenna-scenario-grid strong {
  display: block;
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-p3-antenna-scenario-grid span {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 9.5px;
  line-height: 1.25;
}

.trfmc-p3-antenna-scenario-grid em {
  display: block;
  margin-top: 6px;
  color: #86efac;
  font-size: 8.5px;
  font-style: normal;
  line-height: 1.22;
}

.trfmc-p3-antenna-acceptance {
  margin-top: 8px;
}

.trfmc-p3-antenna-acceptance strong {
  color: #e8f7ff;
  font-size: 10.5px;
  line-height: 1.25;
}

@media (max-width: 1420px) {
  .trfmc-p3-antenna-kpi-grid,
  .trfmc-p3-antenna-port-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .trfmc-p3-antenna-main-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 880px) {
  .trfmc-p3-antenna-head,
  .trfmc-p3-antenna-kpi-grid,
  .trfmc-p3-antenna-port-grid,
  .trfmc-p3-antenna-scenario-grid {
    grid-template-columns: 1fr;
  }
}
/* === TRFMC P3B ANTENNA SYSTEM REACT PROMOTION V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_P3B_APPENDED=True")
PY

echo
echo "=== 7) DIFF ==="

git diff -- "$REGISTRY" "$CANVAS" "$DOMAIN" "$ROUTE" "$ORCH" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 8) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  "$RESTORE"
  BUILD_RESULT="FAIL_RESTORED"
fi

echo
echo "=== 9) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#antenna-system"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 10) STATIC SAFETY GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" "$REGISTRY" "$CANVAS" "$DOMAIN" "$ROUTE" "$ORCH")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body" "$REGISTRY" "$CANVAS" "$DOMAIN" "$ROUTE" "$ORCH")"
  PUBLIC_HTML_LINKS="$(safe_count_files "trfmc_antenna_rru_ret_cpri_port_mapping_v2\\.html|trfmc_antenna_system_explorer_v17_layout_lock_fullscreen\\.html|antenna.*\\.html" "$REGISTRY" "$CANVAS" "$DOMAIN" "$ROUTE" "$ORCH")"
  ROUTE_MOUNT_COUNT="$(safe_count_files "AntennaSystemRouteP3" "$ORCH")"
  DOMAIN_MARKER_SOURCE_COUNT="$(safe_count_files "data-trfmc-p3-antenna-system-domain" "$DOMAIN")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_html_injection_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "public_html_runtime_links_absent\t$([ "$PUBLIC_HTML_LINKS" = "0" ] && echo PASS || echo FAIL)\t$PUBLIC_HTML_LINKS"
  echo -e "route_mount_present\t$([ "$ROUTE_MOUNT_COUNT" -gt 0 ] && echo PASS || echo FAIL)\t$ROUTE_MOUNT_COUNT"
  echo -e "domain_marker_source_present\t$([ "$DOMAIN_MARKER_SOURCE_COUNT" -gt 0 ] && echo PASS || echo FAIL)\t$DOMAIN_MARKER_SOURCE_COUNT"
} | tee "$STATIC_GATE" | column -t -s $'\t'

echo
echo "=== 11) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#antenna-system" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#antenna-system" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  elif command -v chromium >/dev/null 2>&1; then
    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#antenna-system" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#antenna-system" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
    echo "NO_CHROME_AVAILABLE" > "$DOMERR"
    echo "NO_CHROME_AVAILABLE" > "$SCREENERR"
  fi
else
  echo "BUILD_NOT_PASS" > "$DOM"
  echo "BUILD_NOT_PASS" > "$DOMERR"
  echo "BUILD_NOT_PASS" > "$SCREENERR"
fi

P3B_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p3-antenna-system-domain="mounted"' "$DOM")"
P3B_CANVAS_COUNT="$(safe_count_literal 'trfmc-p3-antenna-canvas' "$DOM")"
P3B_PORTMAP_COUNT="$(safe_count_literal 'port mapping traceability' "$DOM")"
P3B_SCENARIO_COUNT="$(safe_count_literal 'Scenario binding' "$DOM")"
CSS_MARKER_COUNT="$(safe_count_literal 'TRFMC P3B ANTENNA SYSTEM REACT PROMOTION V1 START' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P3B_MARKER_COUNT=$P3B_MARKER_COUNT"
echo "P3B_CANVAS_COUNT=$P3B_CANVAS_COUNT"
echo "P3B_PORTMAP_COUNT=$P3B_PORTMAP_COUNT"
echo "P3B_SCENARIO_COUNT=$P3B_SCENARIO_COUNT"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

echo
echo "=== 12) CHROME STDERR HEAD ==="
sed -n '1,80p' "$DOMERR" || true

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC_GATE")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$HTTP_ZERO_BYTES_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P3B_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P3B_CANVAS_COUNT" = "0" ]; then RESULT="REVIEW_DOM_CANVAS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P3B_PORTMAP_COUNT" = "0" ]; then RESULT="REVIEW_DOM_PORT_MAPPING"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P3B_SCENARIO_COUNT" = "0" ]; then RESULT="REVIEW_DOM_SCENARIOS"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1",
  "mutation": "frontend_source_antenna_system_domain_promotion",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "files_modified": [
    "$REGISTRY",
    "$CANVAS",
    "$DOMAIN",
    "$ROUTE",
    "$ORCH",
    "$CSS"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "static_gate": "$STATIC_GATE",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "dom_stderr": "$DOMERR",
  "screenshot": "$SCREEN",
  "screenshot_stderr": "$SCREENERR",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $HTTP_NON_200_FRONTEND,
  "frontend_http_zero_bytes": $HTTP_ZERO_BYTES_FRONTEND,
  "static_failures": $STATIC_FAILS,
  "dom_result": "$DOM_RESULT",
  "p3b_marker_count": $P3B_MARKER_COUNT,
  "p3b_canvas_count": $P3B_CANVAS_COUNT,
  "p3b_port_mapping_count": $P3B_PORTMAP_COUNT,
  "p3b_scenario_count": $P3B_SCENARIO_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p3b_antenna_system_react_promotion_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
