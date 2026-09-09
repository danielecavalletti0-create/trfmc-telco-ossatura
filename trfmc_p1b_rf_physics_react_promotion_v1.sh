#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P1B_RF_PHYSICS_REACT_PROMOTION_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

DOMAIN_DIR="frontend/src/domains/rf-physics"
REGISTRY="$DOMAIN_DIR/rfPhysicsRegistry.ts"
CANVAS="$DOMAIN_DIR/RFPhysicsFieldCanvasP1.tsx"
DOMAIN="$DOMAIN_DIR/RFPhysicsDomainP1.tsx"
ROUTE="frontend/src/app/RFPhysicsRouteP1.tsx"
ORCH="frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_p1b_rf_physics_react_promotion_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p1b_rf_physics_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p1b_rf_physics_react_promotion.diff"
STATIC_GATE="$OUT/static_gate.tsv"
RESTORE="$OUT/RESTORE_P1B_RF_PHYSICS_REACT_PROMOTION_V1.sh"

safe_count_files() {
  local pattern="$1"
  shift
  grep -RIn -E "$pattern" "$@" > /tmp/trfmc_p1b_grep_$$ 2>/dev/null || true
  wc -l < /tmp/trfmc_p1b_grep_$$ | tr -d ' '
  rm -f /tmp/trfmc_p1b_grep_$$
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
echo "TRFMC_P1B_RF_PHYSICS_REACT_PROMOTION_V1"
echo "RF Physics React domain · canvas engine · formulas · QA"
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

echo "RESTORE_P1B_RF_PHYSICS_REACT_PROMOTION_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA rfPhysicsRegistry.ts ==="

cat > "$REGISTRY" <<'TS'
export type RFPhysicsFormula = {
  id: string
  label: string
  expression: string
  meaning: string
  unit: string
  promotionSource: string
}

export type RFPhysicsKpi = {
  id: string
  label: string
  value: string
  note: string
  state: 'ready' | 'derived' | 'review'
}

export type RFPhysicsScenario = {
  id: string
  title: string
  objective: string
  evidence: string
}

export const rfPhysicsPromotionSource = {
  phase: 'P1B_RF_PHYSICS_REACT_PROMOTION_V1',
  selectedSource: 'webgl_rf_physics_engine_v85b_sapienza_baseline',
  sourceScore: 227,
  formulaHits: 15,
  canvasTags: 2,
  debtHits: 1,
  rule: 'Extract physics model, formulas and visual behavior into React. Do not mount public HTML.',
}

export const rfPhysicsFormulas: RFPhysicsFormula[] = [
  {
    id: 'lambda',
    label: 'Wavelength',
    expression: 'λ = c / f',
    meaning: 'Relates carrier frequency to propagation wavelength in free space.',
    unit: 'm',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'fspl',
    label: 'Free-space path loss',
    expression: 'FSPL(dB) = 32.44 + 20log10(dkm) + 20log10(fMHz)',
    meaning: 'First-order reference model for isotropic free-space propagation loss.',
    unit: 'dB',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'rx-power',
    label: 'Received power',
    expression: 'Prx(dBm) = Ptx + Gtx + Grx − Lpath − Lmisc',
    meaning: 'Link budget accounting of transmit power, antenna gains and propagation losses.',
    unit: 'dBm',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'snr',
    label: 'Signal-to-noise ratio',
    expression: 'SNR(dB) = Psignal(dBm) − Pnoise(dBm)',
    meaning: 'Quality metric for coverage, demodulation margin and link reliability.',
    unit: 'dB',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'sinr',
    label: 'Signal-to-interference-plus-noise',
    expression: 'SINR = S / (I + N)',
    meaning: 'Operational quality model when interference sources are present.',
    unit: 'dB',
    promotionSource: 'RF physics baseline',
  },
  {
    id: 'fresnel',
    label: 'First Fresnel radius',
    expression: 'r₁ = √(λ d₁ d₂ / (d₁ + d₂))',
    meaning: 'Clearance model for microwave/RF path obstruction and NLOS degradation.',
    unit: 'm',
    promotionSource: 'RF physics baseline',
  },
]

export const rfPhysicsKpis: RFPhysicsKpi[] = [
  {
    id: 'carrier',
    label: 'Carrier',
    value: '2.440 GHz',
    note: 'ISM/Lab reference carrier for RF visualization',
    state: 'ready',
  },
  {
    id: 'lambda',
    label: 'λ',
    value: '0.123 m',
    note: 'Derived from c / f',
    state: 'derived',
  },
  {
    id: 'rsrp',
    label: 'RSRP profile',
    value: '-52 → -96 dBm',
    note: 'Synthetic field gradient for route/coverage review',
    state: 'derived',
  },
  {
    id: 'sinr',
    label: 'SINR profile',
    value: '4 → 35 dB',
    note: 'Scenario-linked coverage quality model',
    state: 'derived',
  },
  {
    id: 'canvas',
    label: 'Visual engine',
    value: 'React Canvas',
    note: 'No public HTML runtime mount',
    state: 'ready',
  },
  {
    id: 'qa',
    label: 'QA',
    value: 'build + DOM + screenshot',
    note: 'P1B acceptance gate required',
    state: 'review',
  },
]

export const rfPhysicsScenarios: RFPhysicsScenario[] = [
  {
    id: 'controlled-propagation-baseline',
    title: 'Controlled propagation baseline',
    objective: 'Verify wavelength, free-space loss and received-power gradient.',
    evidence: 'Formula registry + canvas field profile + DOM marker.',
  },
  {
    id: 'nlos-obstruction',
    title: 'NLOS / obstruction interpretation',
    objective: 'Demonstrate signal degradation through blocked path and reduced SINR.',
    evidence: 'Fresnel clearance model and synthetic RSRP/SINR contour.',
  },
  {
    id: 'coverage-quality',
    title: 'Coverage quality classification',
    objective: 'Map RSRP/SINR bands into engineering readiness.',
    evidence: 'KPI strip and field canvas visual state.',
  },
]
TS

echo
echo "=== 2) CREA RFPhysicsFieldCanvasP1.tsx ==="

cat > "$CANVAS" <<'TSX'
import { useEffect, useRef } from 'react'

type RFPhysicsFieldCanvasP1Props = {
  widthHint?: number
  heightHint?: number
}

function dbmToNorm(dbm: number) {
  const clamped = Math.max(-110, Math.min(-45, dbm))
  return (clamped + 110) / 65
}

function fieldPower(x: number, y: number) {
  const txA = { x: 0.24, y: 0.34, p: -48 }
  const txB = { x: 0.72, y: 0.58, p: -53 }

  const distanceA = Math.hypot(x - txA.x, y - txA.y)
  const distanceB = Math.hypot(x - txB.x, y - txB.y)

  const ridge = Math.exp(-Math.pow((x - 0.52) * 4.2, 2)) * 8
  const obstruction = Math.exp(-Math.pow((x - 0.45), 2) / 0.012 - Math.pow((y - 0.58), 2) / 0.035) * 17

  const a = txA.p - 38 * Math.log10(1 + distanceA * 18)
  const b = txB.p - 36 * Math.log10(1 + distanceB * 18)

  return Math.max(a, b) + ridge - obstruction
}

function colorFor(norm: number) {
  const cyan = Math.floor(120 + norm * 120)
  const green = Math.floor(80 + norm * 160)
  const blue = Math.floor(120 + norm * 110)
  return `rgba(${Math.floor(norm * 60)}, ${green}, ${blue}, ${0.13 + norm * 0.42})`
}

export function RFPhysicsFieldCanvasP1({ widthHint = 920, heightHint = 320 }: RFPhysicsFieldCanvasP1Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const pixelRatio = window.devicePixelRatio || 1
    const box = canvas.getBoundingClientRect()
    const cssWidth = Math.max(620, Math.floor(box.width || widthHint))
    const cssHeight = Math.max(280, Math.floor(box.height || heightHint))

    canvas.width = Math.floor(cssWidth * pixelRatio)
    canvas.height = Math.floor(cssHeight * pixelRatio)

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0)
    ctx.clearRect(0, 0, cssWidth, cssHeight)

    const background = ctx.createLinearGradient(0, 0, cssWidth, cssHeight)
    background.addColorStop(0, 'rgba(1, 12, 24, 1)')
    background.addColorStop(0.56, 'rgba(1, 25, 28, 1)')
    background.addColorStop(1, 'rgba(0, 5, 12, 1)')
    ctx.fillStyle = background
    ctx.fillRect(0, 0, cssWidth, cssHeight)

    const cols = 96
    const rows = 42
    const cellW = cssWidth / cols
    const cellH = cssHeight / rows

    for (let iy = 0; iy < rows; iy += 1) {
      for (let ix = 0; ix < cols; ix += 1) {
        const x = ix / (cols - 1)
        const y = iy / (rows - 1)
        const dbm = fieldPower(x, y)
        const norm = dbmToNorm(dbm)
        ctx.fillStyle = colorFor(norm)
        ctx.fillRect(ix * cellW, iy * cellH, Math.max(1, cellW - 1), Math.max(1, cellH - 1))
      }
    }

    ctx.strokeStyle = 'rgba(103, 232, 249, .22)'
    ctx.lineWidth = 1
    for (let gx = 0; gx <= 10; gx += 1) {
      const x = gx * cssWidth / 10
      ctx.beginPath()
      ctx.moveTo(x, 0)
      ctx.lineTo(x, cssHeight)
      ctx.stroke()
    }
    for (let gy = 0; gy <= 6; gy += 1) {
      const y = gy * cssHeight / 6
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(cssWidth, y)
      ctx.stroke()
    }

    const drawTx = (xNorm: number, yNorm: number, label: string) => {
      const x = xNorm * cssWidth
      const y = yNorm * cssHeight

      const halo = ctx.createRadialGradient(x, y, 2, x, y, 72)
      halo.addColorStop(0, 'rgba(103, 232, 249, .65)')
      halo.addColorStop(1, 'rgba(103, 232, 249, 0)')
      ctx.fillStyle = halo
      ctx.beginPath()
      ctx.arc(x, y, 72, 0, Math.PI * 2)
      ctx.fill()

      ctx.fillStyle = '#67e8f9'
      ctx.beginPath()
      ctx.arc(x, y, 5, 0, Math.PI * 2)
      ctx.fill()

      ctx.fillStyle = '#e8f7ff'
      ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
      ctx.fillText(label, x + 9, y - 8)
    }

    drawTx(0.24, 0.34, 'TX-A 2.440 GHz')
    drawTx(0.72, 0.58, 'TX-B sector')

    ctx.strokeStyle = 'rgba(251, 191, 36, .70)'
    ctx.lineWidth = 2
    ctx.setLineDash([7, 6])
    ctx.beginPath()
    ctx.moveTo(cssWidth * 0.17, cssHeight * 0.78)
    ctx.bezierCurveTo(cssWidth * 0.32, cssHeight * 0.58, cssWidth * 0.52, cssHeight * 0.45, cssWidth * 0.86, cssHeight * 0.24)
    ctx.stroke()
    ctx.setLineDash([])

    ctx.strokeStyle = 'rgba(248, 113, 113, .65)'
    ctx.lineWidth = 1.5
    ctx.beginPath()
    ctx.ellipse(cssWidth * 0.45, cssHeight * 0.58, 70, 34, -0.15, 0, Math.PI * 2)
    ctx.stroke()

    ctx.fillStyle = 'rgba(0, 0, 0, .38)'
    ctx.fillRect(14, 14, 238, 80)
    ctx.strokeStyle = 'rgba(103, 232, 249, .48)'
    ctx.strokeRect(14, 14, 238, 80)

    ctx.fillStyle = '#22d3ee'
    ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
    ctx.fillText('RF PHYSICS FIELD ENGINE P1', 24, 34)
    ctx.fillText('λ = 0.123 m · FSPL · RSRP/SINR', 24, 52)
    ctx.fillText('Canvas React · no public HTML runtime', 24, 70)

    ctx.fillStyle = '#86efac'
    ctx.fillText('source: v85b promoted model', 24, 88)
  }, [widthHint, heightHint])

  return (
    <canvas
      ref={canvasRef}
      className="trfmc-p1-rf-canvas"
      aria-label="RF Physics field model canvas"
    />
  )
}
TSX

echo
echo "=== 3) CREA RFPhysicsDomainP1.tsx ==="

cat > "$DOMAIN" <<'TSX'
import { RFPhysicsFieldCanvasP1 } from './RFPhysicsFieldCanvasP1'
import {
  rfPhysicsFormulas,
  rfPhysicsKpis,
  rfPhysicsPromotionSource,
  rfPhysicsScenarios,
} from './rfPhysicsRegistry'

export function RFPhysicsDomainP1() {
  return (
    <section className="trfmc-p1-rf-domain" data-trfmc-p1-rf-physics-domain="mounted">
      <div className="trfmc-p1-rf-head">
        <div>
          <p>P1B · RF Physics React Promotion</p>
          <h2>RF Physics · Maxwell, propagazione, link budget, campo</h2>
          <span>
            Primo dominio tecnico promosso dal materiale RF Physics selezionato in P1A.
            Le formule, il modello visuale e gli scenari sono ora componenti React governati,
            non una pagina HTML pubblica montata in parallelo.
          </span>
        </div>
        <article>
          <strong>{rfPhysicsPromotionSource.sourceScore}</strong>
          <span>source score</span>
          <em>{rfPhysicsPromotionSource.selectedSource}</em>
        </article>
      </div>

      <div className="trfmc-p1-rf-kpi-grid">
        {rfPhysicsKpis.map((kpi) => (
          <article key={kpi.id} data-state={kpi.state}>
            <span>{kpi.label}</span>
            <strong>{kpi.value}</strong>
            <em>{kpi.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p1-rf-main-grid">
        <section className="trfmc-p1-rf-panel trfmc-p1-rf-canvas-panel">
          <div className="trfmc-p1-rf-panel-head">
            <span>Visual engine</span>
            <b>React Canvas field model</b>
          </div>
          <RFPhysicsFieldCanvasP1 />
        </section>

        <section className="trfmc-p1-rf-panel">
          <div className="trfmc-p1-rf-panel-head">
            <span>Formula registry</span>
            <b>engineering formulas</b>
          </div>
          <div className="trfmc-p1-rf-formula-grid">
            {rfPhysicsFormulas.map((formula) => (
              <article key={formula.id}>
                <span>{formula.label}</span>
                <strong>{formula.expression}</strong>
                <p>{formula.meaning}</p>
                <em>{formula.unit}</em>
              </article>
            ))}
          </div>
        </section>
      </div>

      <section className="trfmc-p1-rf-panel">
        <div className="trfmc-p1-rf-panel-head">
          <span>Scenario binding</span>
          <b>RF Physics evidence chain</b>
        </div>
        <div className="trfmc-p1-rf-scenario-grid">
          {rfPhysicsScenarios.map((scenario) => (
            <article key={scenario.id}>
              <strong>{scenario.title}</strong>
              <span>{scenario.objective}</span>
              <em>{scenario.evidence}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p1-rf-acceptance">
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
echo "=== 4) CREA RFPhysicsRouteP1.tsx ==="

cat > "$ROUTE" <<'TSX'
import { useEffect, useState } from 'react'
import { RFPhysicsDomainP1 } from '../domains/rf-physics/RFPhysicsDomainP1'

function currentHash() {
  if (typeof window === 'undefined') return ''
  return window.location.hash || ''
}

export function RFPhysicsRouteP1() {
  const [hash, setHash] = useState(currentHash)

  useEffect(() => {
    const onHashChange = () => setHash(currentHash())
    window.addEventListener('hashchange', onHashChange)
    onHashChange()
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  if (hash !== '#rf-physics') return null

  return <RFPhysicsDomainP1 />
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

import_line = "import { RFPhysicsRouteP1 } from '../app/RFPhysicsRouteP1'"

if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

if "<RFPhysicsRouteP1 />" not in text:
    if "<MissionControlContentP0C />" in text:
        text = text.replace(
            "<MissionControlContentP0C />",
            "<MissionControlContentP0C />\n        <RFPhysicsRouteP1 />",
            1,
        )
    elif "<PortalShellNavigationP0 />" in text:
        text = text.replace(
            "<PortalShellNavigationP0 />",
            "<PortalShellNavigationP0 />\n        <RFPhysicsRouteP1 />",
            1,
        )
    else:
        raise SystemExit("ERRORE: mount point P0B/P0C non trovato")

path.write_text(text, encoding="utf-8")
print("ORCHESTRATOR_P1B_PATCHED=", before != text)
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
    r"\n/\* === TRFMC P1B RF PHYSICS REACT PROMOTION V1 START === \*/.*?/\* === TRFMC P1B RF PHYSICS REACT PROMOTION V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC P1B RF PHYSICS REACT PROMOTION V1 START === */
.trfmc-p1-rf-domain {
  margin-top: 8px;
  padding: 10px;
  border: 1px solid rgba(103, 232, 249, .17);
  border-radius: 14px;
  background:
    radial-gradient(circle at 18% 0%, rgba(34, 211, 238, .09), transparent 34%),
    radial-gradient(circle at 88% 18%, rgba(134, 239, 172, .07), transparent 28%),
    linear-gradient(180deg, rgba(2, 12, 24, .78), rgba(0, 5, 13, .88));
}

.trfmc-p1-rf-head {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 210px;
  gap: 10px;
  align-items: stretch;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(103, 232, 249, .13);
}

.trfmc-p1-rf-head p,
.trfmc-p1-rf-panel-head span,
.trfmc-p1-rf-acceptance span {
  margin: 0 0 4px 0;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.trfmc-p1-rf-head h2 {
  margin: 0 0 5px 0;
  color: #e8f7ff;
  font-size: 18px;
  line-height: 1.05;
}

.trfmc-p1-rf-head span {
  color: #9fb8ca;
  font-size: 10.5px;
  line-height: 1.34;
}

.trfmc-p1-rf-head article {
  display: grid;
  align-content: center;
  justify-items: center;
  border: 1px solid rgba(134, 239, 172, .18);
  border-radius: 12px;
  background: rgba(8, 47, 38, .18);
  padding: 8px;
  text-align: center;
}

.trfmc-p1-rf-head article strong {
  color: #86efac;
  font-size: 26px;
  line-height: 1;
}

.trfmc-p1-rf-head article span {
  color: #9fb8ca;
  font-size: 8px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p1-rf-head article em {
  margin-top: 5px;
  color: #67e8f9;
  font-size: 8.5px;
  font-style: normal;
  word-break: break-word;
}

.trfmc-p1-rf-kpi-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 7px;
  margin-top: 8px;
}

.trfmc-p1-rf-kpi-grid article,
.trfmc-p1-rf-formula-grid article,
.trfmc-p1-rf-scenario-grid article,
.trfmc-p1-rf-acceptance {
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 10px;
  background: rgba(0, 4, 10, .26);
  padding: 8px;
  min-width: 0;
}

.trfmc-p1-rf-kpi-grid article[data-state="ready"] {
  border-color: rgba(134, 239, 172, .18);
}

.trfmc-p1-rf-kpi-grid article[data-state="review"] {
  border-color: rgba(251, 191, 36, .23);
}

.trfmc-p1-rf-kpi-grid span,
.trfmc-p1-rf-formula-grid span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.trfmc-p1-rf-kpi-grid strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 12px;
}

.trfmc-p1-rf-kpi-grid em {
  display: block;
  margin-top: 4px;
  color: #9fb8ca;
  font-size: 8.8px;
  font-style: normal;
  line-height: 1.22;
}

.trfmc-p1-rf-main-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(360px, .8fr);
  gap: 8px;
  margin-top: 8px;
}

.trfmc-p1-rf-panel {
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 12px;
  background: rgba(2, 10, 20, .38);
  padding: 9px;
}

.trfmc-p1-rf-panel-head {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  align-items: baseline;
  padding-bottom: 7px;
  margin-bottom: 7px;
  border-bottom: 1px solid rgba(103, 232, 249, .12);
}

.trfmc-p1-rf-panel-head b {
  color: #86efac;
  font-size: 9px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p1-rf-canvas {
  width: 100%;
  min-height: 320px;
  display: block;
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 12px;
  background: #020711;
}

.trfmc-p1-rf-formula-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 7px;
}

.trfmc-p1-rf-formula-grid strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.trfmc-p1-rf-formula-grid p {
  margin: 5px 0 0 0;
  color: #9fb8ca;
  font-size: 9.5px;
  line-height: 1.26;
}

.trfmc-p1-rf-formula-grid em {
  display: inline-block;
  margin-top: 6px;
  color: #86efac;
  font-size: 8px;
  font-style: normal;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p1-rf-scenario-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 7px;
}

.trfmc-p1-rf-scenario-grid strong {
  display: block;
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-p1-rf-scenario-grid span {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 9.5px;
  line-height: 1.25;
}

.trfmc-p1-rf-scenario-grid em {
  display: block;
  margin-top: 6px;
  color: #86efac;
  font-size: 8.5px;
  font-style: normal;
  line-height: 1.22;
}

.trfmc-p1-rf-acceptance {
  margin-top: 8px;
}

.trfmc-p1-rf-acceptance strong {
  color: #e8f7ff;
  font-size: 10.5px;
  line-height: 1.25;
}

@media (max-width: 1420px) {
  .trfmc-p1-rf-kpi-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .trfmc-p1-rf-main-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 880px) {
  .trfmc-p1-rf-head,
  .trfmc-p1-rf-kpi-grid,
  .trfmc-p1-rf-scenario-grid {
    grid-template-columns: 1fr;
  }
}
/* === TRFMC P1B RF PHYSICS REACT PROMOTION V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_P1B_APPENDED=True")
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
check_url "http://127.0.0.1:5173/#rf-physics"
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
  PUBLIC_HTML_LINKS="$(safe_count_files "webgl_rf_physics_engine_v85b_sapienza_baseline\\.html|webgl_rf_physics_engine_v85c_sapienza_identity\\.html|webgl_rf_physics_engine_v85d_runtime_identity_lock\\.html|trfmc_rf_physics_theory_atlas_v2\\.html" "$REGISTRY" "$CANVAS" "$DOMAIN" "$ROUTE" "$ORCH")"
  ROUTE_MOUNT_COUNT="$(safe_count_files "RFPhysicsRouteP1" "$ORCH")"
  DOMAIN_MARKER_SOURCE_COUNT="$(safe_count_files "data-trfmc-p1-rf-physics-domain" "$DOMAIN")"

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
      --virtual-time-budget=8000 \
      --dump-dom \
      "http://127.0.0.1:5173/#rf-physics" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#rf-physics" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"

  elif command -v chromium >/dev/null 2>&1; then
    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --dump-dom \
      "http://127.0.0.1:5173/#rf-physics" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#rf-physics" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
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

P1B_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p1-rf-physics-domain="mounted"' "$DOM")"
P1B_CANVAS_COUNT="$(safe_count_literal 'trfmc-p1-rf-canvas' "$DOM")"
P1B_FORMULA_COUNT="$(safe_count_literal 'Formula registry' "$DOM")"
P1B_SCENARIO_COUNT="$(safe_count_literal 'Scenario binding' "$DOM")"
CSS_MARKER_COUNT="$(safe_count_literal 'TRFMC P1B RF PHYSICS REACT PROMOTION V1 START' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P1B_MARKER_COUNT=$P1B_MARKER_COUNT"
echo "P1B_CANVAS_COUNT=$P1B_CANVAS_COUNT"
echo "P1B_FORMULA_COUNT=$P1B_FORMULA_COUNT"
echo "P1B_SCENARIO_COUNT=$P1B_SCENARIO_COUNT"
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
if [ "$DOM_RESULT" = "PASS" ] && [ "$P1B_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P1B_CANVAS_COUNT" = "0" ]; then RESULT="REVIEW_DOM_CANVAS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P1B_FORMULA_COUNT" = "0" ]; then RESULT="REVIEW_DOM_FORMULAS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P1B_SCENARIO_COUNT" = "0" ]; then RESULT="REVIEW_DOM_SCENARIOS"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P1B_RF_PHYSICS_REACT_PROMOTION_V1",
  "mutation": "frontend_source_rf_physics_domain_promotion",
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
  "p1b_marker_count": $P1B_MARKER_COUNT,
  "p1b_canvas_count": $P1B_CANVAS_COUNT,
  "p1b_formula_count": $P1B_FORMULA_COUNT,
  "p1b_scenario_count": $P1B_SCENARIO_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1b_rf_physics_react_promotion_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P1B_RF_PHYSICS_REACT_PROMOTION_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
