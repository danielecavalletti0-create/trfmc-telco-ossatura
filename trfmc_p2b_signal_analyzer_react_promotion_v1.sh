#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

DOMAIN_DIR="frontend/src/domains/signal-analyzer"
REGISTRY="$DOMAIN_DIR/signalAnalyzerRegistry.ts"
CANVAS="$DOMAIN_DIR/SignalAnalyzerCanvasP2.tsx"
DOMAIN="$DOMAIN_DIR/SignalAnalyzerDomainP2.tsx"
ROUTE="frontend/src/app/SignalAnalyzerRouteP2.tsx"
ORCH="frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_p2b_signal_analyzer_react_promotion_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/p2b_signal_analyzer_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p2b_signal_analyzer_react_promotion.diff"
STATIC_GATE="$OUT/static_gate.tsv"
RESTORE="$OUT/RESTORE_P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1.sh"

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
echo "TRFMC_P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1"
echo "Signal Analyzer React domain · spectrum/waterfall/IQ · QA"
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

echo "RESTORE_P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA signalAnalyzerRegistry.ts ==="

cat > "$REGISTRY" <<'TS'
export type SignalAnalyzerKpi = {
  id: string
  label: string
  value: string
  note: string
  state: 'ready' | 'derived' | 'review'
}

export type SignalAnalyzerMeasurement = {
  id: string
  label: string
  expression: string
  meaning: string
  unit: string
}

export type SignalAnalyzerScenario = {
  id: string
  title: string
  objective: string
  evidence: string
}

export const signalAnalyzerPromotionSource = {
  phase: 'P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1',
  selectedSource: 'rf_instrumentation_signal_cockpit_v38',
  sourceScore: 234,
  contentHits: 22,
  canvasTags: 1,
  debtHits: 9,
  rule: 'Extract spectrum, waterfall, IQ, FFT, constellation and EVM concepts into React. Do not mount public HTML.',
}

export const signalAnalyzerKpis: SignalAnalyzerKpi[] = [
  {
    id: 'center',
    label: 'Center',
    value: '2.440 GHz',
    note: 'synthetic lab carrier',
    state: 'ready',
  },
  {
    id: 'span',
    label: 'Span',
    value: '80 MHz',
    note: 'spectrum viewport',
    state: 'ready',
  },
  {
    id: 'rbw',
    label: 'RBW',
    value: '100 kHz',
    note: 'resolution model',
    state: 'derived',
  },
  {
    id: 'noise',
    label: 'Noise floor',
    value: '-108 dBm',
    note: 'synthetic receiver floor',
    state: 'derived',
  },
  {
    id: 'evm',
    label: 'EVM',
    value: '2.8 %',
    note: 'modulation quality placeholder',
    state: 'derived',
  },
  {
    id: 'pipeline',
    label: 'Pipeline',
    value: 'FFT · IQ · Waterfall',
    note: 'React-governed visual chain',
    state: 'ready',
  },
]

export const signalAnalyzerMeasurements: SignalAnalyzerMeasurement[] = [
  {
    id: 'fft-bin',
    label: 'FFT bin width',
    expression: 'Δf = fs / N',
    meaning: 'Frequency spacing between adjacent FFT bins.',
    unit: 'Hz',
  },
  {
    id: 'dbfs',
    label: 'Amplitude reference',
    expression: 'A(dBFS) = 20log10(|X[k]| / FullScale)',
    meaning: 'Digital full-scale normalized amplitude reference.',
    unit: 'dBFS',
  },
  {
    id: 'dbm',
    label: 'RF power display',
    expression: 'P(dBm) = 10log10(PmW)',
    meaning: 'RF power representation used in spectrum and receiver displays.',
    unit: 'dBm',
  },
  {
    id: 'evm',
    label: 'Error Vector Magnitude',
    expression: 'EVM% = RMS(error vector) / RMS(reference vector) · 100',
    meaning: 'Vector modulation quality metric for IQ constellations.',
    unit: '%',
  },
  {
    id: 'obw',
    label: 'Occupied bandwidth',
    expression: 'OBW = f_high − f_low at target integrated power',
    meaning: 'Bandwidth occupied by a defined percentage of total signal power.',
    unit: 'Hz',
  },
  {
    id: 'aclr',
    label: 'Adjacent Channel Leakage Ratio',
    expression: 'ACLR = P_main / P_adjacent',
    meaning: 'Spectral leakage indicator for adjacent-channel compliance reasoning.',
    unit: 'dB',
  },
]

export const signalAnalyzerScenarios: SignalAnalyzerScenario[] = [
  {
    id: 'spectrum-baseline',
    title: 'Spectrum baseline',
    objective: 'Validate span, center frequency, noise floor and peak markers.',
    evidence: 'Spectrum trace + KPI strip + formula registry.',
  },
  {
    id: 'iq-quality',
    title: 'IQ quality review',
    objective: 'Interpret constellation stability and EVM placeholder metrics.',
    evidence: 'Constellation panel + EVM card + measurement registry.',
  },
  {
    id: 'waterfall-evolution',
    title: 'Waterfall time evolution',
    objective: 'Show time-frequency persistence and burst behavior.',
    evidence: 'Canvas waterfall + spectral event tags.',
  },
]
TS

echo
echo "=== 2) CREA SignalAnalyzerCanvasP2.tsx ==="

cat > "$CANVAS" <<'TSX'
import { useEffect, useRef } from 'react'

type SignalAnalyzerCanvasP2Props = {
  widthHint?: number
  heightHint?: number
}

function gauss(x: number, mu: number, sigma: number, amp: number) {
  const z = (x - mu) / sigma
  return amp * Math.exp(-0.5 * z * z)
}

function spectrumValue(x: number, t: number) {
  const base = -106 + 2.4 * Math.sin(x * 22 + t * 0.08)
  const carrier = gauss(x, 0.50 + 0.015 * Math.sin(t * 0.03), 0.028, 46)
  const left = gauss(x, 0.36, 0.018, 22)
  const right = gauss(x, 0.66, 0.024, 18)
  const spur = gauss(x, 0.82, 0.009, 13)
  return base + carrier + left + right + spur
}

function normDb(dbm: number) {
  return Math.max(0, Math.min(1, (dbm + 112) / 62))
}

export function SignalAnalyzerCanvasP2({ widthHint = 980, heightHint = 430 }: SignalAnalyzerCanvasP2Props) {
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

    const draw = (time: number) => {
      const t = time / 33.3
      ctx.clearRect(0, 0, width, height)

      const bg = ctx.createLinearGradient(0, 0, width, height)
      bg.addColorStop(0, 'rgba(1, 13, 25, 1)')
      bg.addColorStop(0.62, 'rgba(0, 18, 25, 1)')
      bg.addColorStop(1, 'rgba(0, 5, 12, 1)')
      ctx.fillStyle = bg
      ctx.fillRect(0, 0, width, height)

      const spectrumH = height * 0.42
      const waterfallY = spectrumH + 26
      const waterfallH = height * 0.30
      const iqX = width * 0.78
      const iqY = waterfallY + waterfallH + 22
      const iqR = Math.min(width * 0.15, height * 0.13)

      ctx.strokeStyle = 'rgba(103, 232, 249, .18)'
      ctx.lineWidth = 1

      for (let gx = 0; gx <= 10; gx += 1) {
        const x = gx * width / 10
        ctx.beginPath()
        ctx.moveTo(x, 0)
        ctx.lineTo(x, spectrumH)
        ctx.stroke()
      }

      for (let gy = 0; gy <= 4; gy += 1) {
        const y = gy * spectrumH / 4
        ctx.beginPath()
        ctx.moveTo(0, y)
        ctx.lineTo(width, y)
        ctx.stroke()
      }

      ctx.beginPath()
      for (let i = 0; i < 512; i += 1) {
        const xNorm = i / 511
        const db = spectrumValue(xNorm, t)
        const y = spectrumH - normDb(db) * (spectrumH - 20) - 8
        const x = xNorm * width
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }

      ctx.strokeStyle = 'rgba(103, 232, 249, .95)'
      ctx.lineWidth = 2
      ctx.stroke()

      ctx.fillStyle = 'rgba(103, 232, 249, .10)'
      ctx.lineTo(width, spectrumH)
      ctx.lineTo(0, spectrumH)
      ctx.closePath()
      ctx.fill()

      ctx.fillStyle = '#e8f7ff'
      ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
      ctx.fillText('SPECTRUM · CENTER 2.440 GHz · SPAN 80 MHz · RBW 100 kHz', 18, 22)

      ctx.fillStyle = '#86efac'
      ctx.fillText('Peak -51.6 dBm · Noise floor -108 dBm · EVM 2.8%', 18, 42)

      for (let row = 0; row < 58; row += 1) {
        for (let col = 0; col < 160; col += 1) {
          const xNorm = col / 159
          const db = spectrumValue(xNorm, t - row * 1.6)
          const n = normDb(db)
          ctx.fillStyle = `rgba(${Math.floor(10 + n * 80)}, ${Math.floor(65 + n * 175)}, ${Math.floor(110 + n * 130)}, ${0.18 + n * 0.62})`
          ctx.fillRect(col * width / 160, waterfallY + row * waterfallH / 58, width / 160 + 1, waterfallH / 58 + 1)
        }
      }

      ctx.strokeStyle = 'rgba(103, 232, 249, .24)'
      ctx.strokeRect(0, waterfallY, width, waterfallH)
      ctx.fillStyle = '#67e8f9'
      ctx.fillText('WATERFALL · time-frequency persistence', 18, waterfallY + 18)

      const iqCenterX = iqX
      const iqCenterY = iqY + iqR * 0.52

      ctx.strokeStyle = 'rgba(103, 232, 249, .28)'
      ctx.beginPath()
      ctx.arc(iqCenterX, iqCenterY, iqR, 0, Math.PI * 2)
      ctx.stroke()

      ctx.beginPath()
      ctx.moveTo(iqCenterX - iqR, iqCenterY)
      ctx.lineTo(iqCenterX + iqR, iqCenterY)
      ctx.moveTo(iqCenterX, iqCenterY - iqR)
      ctx.lineTo(iqCenterX, iqCenterY + iqR)
      ctx.stroke()

      const qam = [-0.55, -0.18, 0.18, 0.55]
      ctx.fillStyle = 'rgba(134, 239, 172, .82)'
      for (const i of qam) {
        for (const q of qam) {
          const jitterI = Math.sin(t * 0.13 + i * 17 + q * 11) * 3.5
          const jitterQ = Math.cos(t * 0.11 + i * 13 - q * 19) * 3.5
          ctx.beginPath()
          ctx.arc(iqCenterX + i * iqR + jitterI, iqCenterY + q * iqR + jitterQ, 2.8, 0, Math.PI * 2)
          ctx.fill()
        }
      }

      ctx.fillStyle = '#e8f7ff'
      ctx.fillText('IQ CONSTELLATION · 16-QAM reference', iqCenterX - iqR, iqCenterY - iqR - 12)

      ctx.fillStyle = 'rgba(0, 0, 0, .35)'
      ctx.fillRect(16, height - 72, 360, 54)
      ctx.strokeStyle = 'rgba(103, 232, 249, .42)'
      ctx.strokeRect(16, height - 72, 360, 54)
      ctx.fillStyle = '#67e8f9'
      ctx.fillText('P2B SIGNAL ANALYZER · React Canvas', 28, height - 50)
      ctx.fillStyle = '#86efac'
      ctx.fillText('FFT · spectrum · waterfall · IQ · EVM · OBW/ACLR registry', 28, height - 30)
    }

    draw(0)
  }, [widthHint, heightHint])

  return (
    <canvas
      ref={canvasRef}
      className="trfmc-p2-signal-canvas"
      aria-label="Signal Analyzer spectrum waterfall IQ canvas"
    />
  )
}
TSX

echo
echo "=== 3) CREA SignalAnalyzerDomainP2.tsx ==="

cat > "$DOMAIN" <<'TSX'
import { SignalAnalyzerCanvasP2 } from './SignalAnalyzerCanvasP2'
import {
  signalAnalyzerKpis,
  signalAnalyzerMeasurements,
  signalAnalyzerPromotionSource,
  signalAnalyzerScenarios,
} from './signalAnalyzerRegistry'

export function SignalAnalyzerDomainP2() {
  return (
    <section className="trfmc-p2-signal-domain" data-trfmc-p2-signal-analyzer-domain="mounted">
      <div className="trfmc-p2-signal-head">
        <div>
          <p>P2B · Signal Analyzer React Promotion</p>
          <h2>Signal Analyzer · Spectrum, Waterfall, IQ, FFT, EVM</h2>
          <span>
            Dominio Signal Analyzer promosso dal cockpit P2A selezionato. Il contenuto legacy viene
            convertito in componenti React governati: KPI, registry misure, canvas visuale e scenari.
          </span>
        </div>
        <article>
          <strong>{signalAnalyzerPromotionSource.sourceScore}</strong>
          <span>source score</span>
          <em>{signalAnalyzerPromotionSource.selectedSource}</em>
        </article>
      </div>

      <div className="trfmc-p2-signal-kpi-grid">
        {signalAnalyzerKpis.map((kpi) => (
          <article key={kpi.id} data-state={kpi.state}>
            <span>{kpi.label}</span>
            <strong>{kpi.value}</strong>
            <em>{kpi.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p2-signal-main-grid">
        <section className="trfmc-p2-signal-panel trfmc-p2-signal-canvas-panel">
          <div className="trfmc-p2-signal-panel-head">
            <span>Visual chain</span>
            <b>React Canvas · spectrum / waterfall / IQ</b>
          </div>
          <SignalAnalyzerCanvasP2 />
        </section>

        <section className="trfmc-p2-signal-panel">
          <div className="trfmc-p2-signal-panel-head">
            <span>Measurement registry</span>
            <b>FFT · EVM · OBW · ACLR</b>
          </div>
          <div className="trfmc-p2-signal-measure-grid">
            {signalAnalyzerMeasurements.map((item) => (
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

      <section className="trfmc-p2-signal-panel">
        <div className="trfmc-p2-signal-panel-head">
          <span>Scenario binding</span>
          <b>instrument evidence chain</b>
        </div>
        <div className="trfmc-p2-signal-scenario-grid">
          {signalAnalyzerScenarios.map((scenario) => (
            <article key={scenario.id}>
              <strong>{scenario.title}</strong>
              <span>{scenario.objective}</span>
              <em>{scenario.evidence}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="trfmc-p2-signal-acceptance">
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
echo "=== 4) CREA SignalAnalyzerRouteP2.tsx ==="

cat > "$ROUTE" <<'TSX'
import { useEffect, useState } from 'react'
import { SignalAnalyzerDomainP2 } from '../domains/signal-analyzer/SignalAnalyzerDomainP2'

function currentHash() {
  if (typeof window === 'undefined') return ''
  return window.location.hash || ''
}

export function SignalAnalyzerRouteP2() {
  const [hash, setHash] = useState(currentHash)

  useEffect(() => {
    const onHashChange = () => setHash(currentHash())
    window.addEventListener('hashchange', onHashChange)
    onHashChange()
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  if (hash !== '#signal-analyzer') return null

  return <SignalAnalyzerDomainP2 />
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

import_line = "import { SignalAnalyzerRouteP2 } from '../app/SignalAnalyzerRouteP2'"

if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

if "<SignalAnalyzerRouteP2 />" not in text:
    if "<RFPhysicsRouteP1 />" in text:
        text = text.replace(
            "<RFPhysicsRouteP1 />",
            "<RFPhysicsRouteP1 />\n        <SignalAnalyzerRouteP2 />",
            1,
        )
    elif "<MissionControlContentP0C />" in text:
        text = text.replace(
            "<MissionControlContentP0C />",
            "<MissionControlContentP0C />\n        <SignalAnalyzerRouteP2 />",
            1,
        )
    elif "<PortalShellNavigationP0 />" in text:
        text = text.replace(
            "<PortalShellNavigationP0 />",
            "<PortalShellNavigationP0 />\n        <SignalAnalyzerRouteP2 />",
            1,
        )
    else:
        raise SystemExit("ERRORE: mount point P0/P1 non trovato")

path.write_text(text, encoding="utf-8")
print("ORCHESTRATOR_P2B_PATCHED=", before != text)
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
    r"\n/\* === TRFMC P2B SIGNAL ANALYZER REACT PROMOTION V1 START === \*/.*?/\* === TRFMC P2B SIGNAL ANALYZER REACT PROMOTION V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC P2B SIGNAL ANALYZER REACT PROMOTION V1 START === */
.trfmc-p2-signal-domain {
  margin-top: 8px;
  padding: 10px;
  border: 1px solid rgba(103, 232, 249, .17);
  border-radius: 14px;
  background:
    radial-gradient(circle at 15% 0%, rgba(103, 232, 249, .08), transparent 34%),
    radial-gradient(circle at 88% 20%, rgba(168, 85, 247, .08), transparent 30%),
    linear-gradient(180deg, rgba(2, 12, 24, .78), rgba(0, 5, 13, .90));
}

.trfmc-p2-signal-head {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 210px;
  gap: 10px;
  align-items: stretch;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(103, 232, 249, .13);
}

.trfmc-p2-signal-head p,
.trfmc-p2-signal-panel-head span,
.trfmc-p2-signal-acceptance span {
  margin: 0 0 4px 0;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.trfmc-p2-signal-head h2 {
  margin: 0 0 5px 0;
  color: #e8f7ff;
  font-size: 18px;
  line-height: 1.05;
}

.trfmc-p2-signal-head span {
  color: #9fb8ca;
  font-size: 10.5px;
  line-height: 1.34;
}

.trfmc-p2-signal-head article {
  display: grid;
  align-content: center;
  justify-items: center;
  border: 1px solid rgba(134, 239, 172, .18);
  border-radius: 12px;
  background: rgba(8, 47, 38, .18);
  padding: 8px;
  text-align: center;
}

.trfmc-p2-signal-head article strong {
  color: #86efac;
  font-size: 26px;
  line-height: 1;
}

.trfmc-p2-signal-head article span {
  color: #9fb8ca;
  font-size: 8px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p2-signal-head article em {
  margin-top: 5px;
  color: #67e8f9;
  font-size: 8.5px;
  font-style: normal;
  word-break: break-word;
}

.trfmc-p2-signal-kpi-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 7px;
  margin-top: 8px;
}

.trfmc-p2-signal-kpi-grid article,
.trfmc-p2-signal-measure-grid article,
.trfmc-p2-signal-scenario-grid article,
.trfmc-p2-signal-acceptance {
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 10px;
  background: rgba(0, 4, 10, .26);
  padding: 8px;
  min-width: 0;
}

.trfmc-p2-signal-kpi-grid article[data-state="ready"] {
  border-color: rgba(134, 239, 172, .18);
}

.trfmc-p2-signal-kpi-grid article[data-state="review"] {
  border-color: rgba(251, 191, 36, .23);
}

.trfmc-p2-signal-kpi-grid span,
.trfmc-p2-signal-measure-grid span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.trfmc-p2-signal-kpi-grid strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 12px;
}

.trfmc-p2-signal-kpi-grid em {
  display: block;
  margin-top: 4px;
  color: #9fb8ca;
  font-size: 8.8px;
  font-style: normal;
  line-height: 1.22;
}

.trfmc-p2-signal-main-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.18fr) minmax(360px, .82fr);
  gap: 8px;
  margin-top: 8px;
}

.trfmc-p2-signal-panel {
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 12px;
  background: rgba(2, 10, 20, .38);
  padding: 9px;
}

.trfmc-p2-signal-panel-head {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  align-items: baseline;
  padding-bottom: 7px;
  margin-bottom: 7px;
  border-bottom: 1px solid rgba(103, 232, 249, .12);
}

.trfmc-p2-signal-panel-head b {
  color: #86efac;
  font-size: 9px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p2-signal-canvas {
  width: 100%;
  min-height: 430px;
  display: block;
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 12px;
  background: #020711;
}

.trfmc-p2-signal-measure-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 7px;
}

.trfmc-p2-signal-measure-grid strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 11px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.trfmc-p2-signal-measure-grid p {
  margin: 5px 0 0 0;
  color: #9fb8ca;
  font-size: 9.5px;
  line-height: 1.26;
}

.trfmc-p2-signal-measure-grid em {
  display: inline-block;
  margin-top: 6px;
  color: #86efac;
  font-size: 8px;
  font-style: normal;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p2-signal-scenario-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 7px;
}

.trfmc-p2-signal-scenario-grid strong {
  display: block;
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-p2-signal-scenario-grid span {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 9.5px;
  line-height: 1.25;
}

.trfmc-p2-signal-scenario-grid em {
  display: block;
  margin-top: 6px;
  color: #86efac;
  font-size: 8.5px;
  font-style: normal;
  line-height: 1.22;
}

.trfmc-p2-signal-acceptance {
  margin-top: 8px;
}

.trfmc-p2-signal-acceptance strong {
  color: #e8f7ff;
  font-size: 10.5px;
  line-height: 1.25;
}

@media (max-width: 1420px) {
  .trfmc-p2-signal-kpi-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .trfmc-p2-signal-main-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 880px) {
  .trfmc-p2-signal-head,
  .trfmc-p2-signal-kpi-grid,
  .trfmc-p2-signal-scenario-grid {
    grid-template-columns: 1fr;
  }
}
/* === TRFMC P2B SIGNAL ANALYZER REACT PROMOTION V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_P2B_APPENDED=True")
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
check_url "http://127.0.0.1:5173/#signal-analyzer"
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
  PUBLIC_HTML_LINKS="$(safe_count_files "rf_instrumentation_signal_cockpit_v38\\.html|trfmc_measurement_chain_dsp_engine_v3\\.html|trfmc_rf_spectrum_lab_v1\\.html|trfmc_rf_tm_signal_universe_v3\\.html|trfmc_signal_world_engine_v2\\.html" "$REGISTRY" "$CANVAS" "$DOMAIN" "$ROUTE" "$ORCH")"
  ROUTE_MOUNT_COUNT="$(safe_count_files "SignalAnalyzerRouteP2" "$ORCH")"
  DOMAIN_MARKER_SOURCE_COUNT="$(safe_count_files "data-trfmc-p2-signal-analyzer-domain" "$DOMAIN")"

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
      "http://127.0.0.1:5173/#signal-analyzer" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#signal-analyzer" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  elif command -v chromium >/dev/null 2>&1; then
    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#signal-analyzer" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#signal-analyzer" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
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

P2B_MARKER_COUNT="$(safe_count_literal 'data-trfmc-p2-signal-analyzer-domain="mounted"' "$DOM")"
P2B_CANVAS_COUNT="$(safe_count_literal 'trfmc-p2-signal-canvas' "$DOM")"
P2B_MEASURE_COUNT="$(safe_count_literal 'Measurement registry' "$DOM")"
P2B_SCENARIO_COUNT="$(safe_count_literal 'Scenario binding' "$DOM")"
CSS_MARKER_COUNT="$(safe_count_literal 'TRFMC P2B SIGNAL ANALYZER REACT PROMOTION V1 START' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P2B_MARKER_COUNT=$P2B_MARKER_COUNT"
echo "P2B_CANVAS_COUNT=$P2B_CANVAS_COUNT"
echo "P2B_MEASURE_COUNT=$P2B_MEASURE_COUNT"
echo "P2B_SCENARIO_COUNT=$P2B_SCENARIO_COUNT"
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
if [ "$DOM_RESULT" = "PASS" ] && [ "$P2B_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P2B_CANVAS_COUNT" = "0" ]; then RESULT="REVIEW_DOM_CANVAS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P2B_MEASURE_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MEASUREMENTS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P2B_SCENARIO_COUNT" = "0" ]; then RESULT="REVIEW_DOM_SCENARIOS"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1",
  "mutation": "frontend_source_signal_analyzer_domain_promotion",
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
  "p2b_marker_count": $P2B_MARKER_COUNT,
  "p2b_canvas_count": $P2B_CANVAS_COUNT,
  "p2b_measurement_count": $P2B_MEASURE_COUNT,
  "p2b_scenario_count": $P2B_SCENARIO_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p2b_signal_analyzer_react_promotion_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P2B_SIGNAL_ANALYZER_REACT_PROMOTION_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
