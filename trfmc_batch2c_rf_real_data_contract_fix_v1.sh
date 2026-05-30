#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2C_RF_REAL_DATA_CONTRACT_FIX_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

HOOK="frontend/src/rf_instruments/hooks/useRFSpectrumSweep.ts"
LAYER="frontend/src/rf_instruments/panels/RFEngineeringMath3DPanelV1.tsx"
PROMO="frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_batch2c_rf_real_data_contract_fix_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_real_data_contract_fix_v1_1920x1080.png"
DIFF="$OUT/rf_real_data_contract_fix_v1.diff"
PROBE_JSON="$OUT/bridge_spectrum_sweep_probe.json"
PROBE_TEXT="$OUT/bridge_spectrum_sweep_probe.raw.txt"
PROBE_REPORT="$OUT/bridge_spectrum_sweep_probe_report.txt"
RESTORE="$OUT/RESTORE_RF_REAL_DATA_CONTRACT_FIX_V1.sh"

echo "============================================================"
echo "TRFMC_BATCH2C_RF_REAL_DATA_CONTRACT_FIX_V1"
echo "Real RF sweep contract · robust normalizer · API LIVE gate"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$HOOK" "$LAYER" "$PROMO" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$HOOK" "$BACKUP/useRFSpectrumSweep.ts.before_$TS"
cp -a "$LAYER" "$BACKUP/RFEngineeringMath3DPanelV1.tsx.before_$TS"
cp -a "$PROMO" "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/useRFSpectrumSweep.ts.before_$TS" "$HOOK"
cp -a "$BACKUP/RFEngineeringMath3DPanelV1.tsx.before_$TS" "$LAYER"
cp -a "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS" "$PROMO"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
echo "RESTORE_RF_REAL_DATA_CONTRACT_FIX_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PROBE ENDPOINT REALE BRIDGE 4181 ==="

BRIDGE_URL="http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
HTTP_CODE="$(curl -sS -L --max-time 8 -o "$PROBE_TEXT" -w "%{http_code}" "$BRIDGE_URL" || echo "000")"
BYTES="$(wc -c < "$PROBE_TEXT" | tr -d ' ')"

python3 - "$PROBE_TEXT" "$PROBE_JSON" "$PROBE_REPORT" "$HTTP_CODE" "$BYTES" <<'PY'
import json, sys
from pathlib import Path

raw_path = Path(sys.argv[1])
json_path = Path(sys.argv[2])
report_path = Path(sys.argv[3])
http_code = sys.argv[4]
bytes_count = sys.argv[5]

raw = raw_path.read_text(encoding="utf-8", errors="replace")
parsed = None
parse_ok = False

try:
    parsed = json.loads(raw)
    parse_ok = True
except Exception as exc:
    parsed = {"rawText": raw, "parseError": str(exc)}

json_path.write_text(json.dumps(parsed, indent=2, ensure_ascii=False), encoding="utf-8")

def walk(obj, prefix=""):
    rows = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{prefix}.{k}" if prefix else str(k)
            rows.append((p, type(v).__name__, len(v) if isinstance(v, (list, dict, str)) else ""))
            rows.extend(walk(v, p))
    elif isinstance(obj, list):
        rows.append((prefix or "root", "list", len(obj)))
        for i, v in enumerate(obj[:5]):
            rows.extend(walk(v, f"{prefix}[{i}]"))
    return rows

rows = walk(parsed)
with report_path.open("w", encoding="utf-8") as f:
    f.write(f"HTTP_CODE={http_code}\n")
    f.write(f"BYTES={bytes_count}\n")
    f.write(f"JSON_PARSE_OK={parse_ok}\n")
    f.write("PATH\tTYPE\tLEN\n")
    for p, t, l in rows[:220]:
        f.write(f"{p}\t{t}\t{l}\n")
PY

cat "$PROBE_REPORT" | sed -n '1,80p'

echo
echo "=== 2) RISCRIVO useRFSpectrumSweep.ts CON NORMALIZZATORE ROBUSTO ==="

cat > "$HOOK" <<'TS'
import { useEffect, useMemo, useState } from 'react'

export type RFSweepMetrics = {
  snrDb: number | null
  evmPct: number | null
  merDb: number | null
  obwMhz: number | null
  aclrLowDbc: number | null
  aclrHighDbc: number | null
  channelPowerDbm: number | null
  noiseFloorDbm: number | null
  crestFactorDb: number | null
  peakDbm: number | null
  meanDbm: number | null
}

export type NormalizedRFSweep = {
  endpoint: string
  ok: boolean
  status: number
  timestamp: string
  source: 'api' | 'api-derived' | 'synthetic-fallback'
  contentType: string
  binCount: number
  tracePreview: number[]
  samplePreview: string
  metrics: RFSweepMetrics
  raw: unknown
  normalizationNotes: string[]
}

type UseRFSpectrumSweepOptions = {
  enabled?: boolean
  intervalMs?: number
  endpoint?: string
}

const BRIDGE_ENDPOINT = 'http://127.0.0.1:4181/api/rfpro/spectrum/sweep'

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  return value as Record<string, unknown>
}

function compactPreview(text: string): string {
  return text.replace(/\s+/g, ' ').trim().slice(0, 220)
}

function parseNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return Number(value.toFixed(3))
  if (typeof value === 'string') {
    const parsed = Number(value.replace(',', '.').replace(/[^\d.+-]/g, ''))
    if (Number.isFinite(parsed)) return Number(parsed.toFixed(3))
  }
  return null
}

function keyMatches(key: string, needles: string[]): boolean {
  const normalized = key.toLowerCase().replace(/[^a-z0-9]/g, '')
  return needles.some((needle) => normalized === needle || normalized.includes(needle))
}

function findFirstNumberDeep(value: unknown, needles: string[]): number | null {
  const visited = new Set<unknown>()

  function walk(node: unknown): number | null {
    if (node && typeof node === 'object') {
      if (visited.has(node)) return null
      visited.add(node)
    }

    if (Array.isArray(node)) {
      for (const item of node) {
        const result = walk(item)
        if (result !== null) return result
      }
      return null
    }

    const rec = asRecord(node)
    if (!rec) return null

    for (const [key, val] of Object.entries(rec)) {
      if (keyMatches(key, needles)) {
        const direct = parseNumber(val)
        if (direct !== null) return direct

        const nested = walk(val)
        if (nested !== null) return nested
      }
    }

    for (const val of Object.values(rec)) {
      const nested = walk(val)
      if (nested !== null) return nested
    }

    return null
  }

  return walk(value)
}

function findNumericArraysDeep(value: unknown): number[][] {
  const arrays: number[][] = []
  const visited = new Set<unknown>()

  function walk(node: unknown) {
    if (node && typeof node === 'object') {
      if (visited.has(node)) return
      visited.add(node)
    }

    if (Array.isArray(node)) {
      const nums = node
        .map((item) => {
          if (typeof item === 'number') return item
          if (Array.isArray(item) && typeof item[1] === 'number') return item[1]
          if (asRecord(item)) {
            return (
              parseNumber((item as Record<string, unknown>).power) ??
              parseNumber((item as Record<string, unknown>).dbm) ??
              parseNumber((item as Record<string, unknown>).y) ??
              parseNumber((item as Record<string, unknown>).value)
            )
          }
          return null
        })
        .filter((item): item is number => typeof item === 'number' && Number.isFinite(item))

      if (nums.length >= 16) arrays.push(nums)

      for (const item of node) walk(item)
      return
    }

    const rec = asRecord(node)
    if (!rec) return
    for (const val of Object.values(rec)) walk(val)
  }

  walk(value)
  return arrays.sort((a, b) => b.length - a.length)
}

function percentile(values: number[], q: number): number | null {
  if (!values.length) return null
  const sorted = [...values].sort((a, b) => a - b)
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.round((sorted.length - 1) * q)))
  return Number(sorted[idx].toFixed(3))
}

function avg(values: number[]): number | null {
  if (!values.length) return null
  return Number((values.reduce((a, b) => a + b, 0) / values.length).toFixed(3))
}

function deriveFromTrace(trace: number[]) {
  if (!trace.length) {
    return {
      peakDbm: null,
      meanDbm: null,
      noiseFloorDbm: null,
      snrDb: null,
      crestFactorDb: null,
    }
  }

  const peak = Number(Math.max(...trace).toFixed(3))
  const mean = avg(trace)
  const noise = percentile(trace, 0.20)
  const snr = noise === null ? null : Number((peak - noise).toFixed(3))
  const rms = Math.sqrt(trace.reduce((s, x) => s + x * x, 0) / trace.length)
  const crest = rms > 0 ? Number((20 * Math.log10(Math.abs(peak) / rms)).toFixed(3)) : null

  return {
    peakDbm: peak,
    meanDbm: mean,
    noiseFloorDbm: noise,
    snrDb: snr,
    crestFactorDb: crest,
  }
}

function normalizeSweep(raw: unknown, endpoint: string, status: number, contentType: string, rawText: string): NormalizedRFSweep {
  const notes: string[] = []
  const numericArrays = findNumericArraysDeep(raw)
  const trace = numericArrays[0] ?? []
  const derived = deriveFromTrace(trace)

  if (trace.length > 0) notes.push(`trace_detected:${trace.length}`)
  else notes.push('trace_not_detected')

  const metrics: RFSweepMetrics = {
    snrDb:
      findFirstNumberDeep(raw, ['snr', 'snrdb', 'signaltonoise']) ??
      derived.snrDb,
    evmPct:
      findFirstNumberDeep(raw, ['evm', 'evmpct', 'evmpercent', 'evmrms']) ??
      null,
    merDb:
      findFirstNumberDeep(raw, ['mer', 'merdb']) ??
      null,
    obwMhz:
      findFirstNumberDeep(raw, ['obw', 'obwmhz', 'occupiedbandwidth']) ??
      null,
    aclrLowDbc:
      findFirstNumberDeep(raw, ['aclrlow', 'aclrldb', 'adjacentlow']) ??
      null,
    aclrHighDbc:
      findFirstNumberDeep(raw, ['aclrhigh', 'aclrhdb', 'adjacenthigh']) ??
      null,
    channelPowerDbm:
      findFirstNumberDeep(raw, ['channelpower', 'channelpowerdbm', 'chpower']) ??
      null,
    noiseFloorDbm:
      findFirstNumberDeep(raw, ['noisefloor', 'noisefloordbm', 'noise']) ??
      derived.noiseFloorDbm,
    crestFactorDb:
      findFirstNumberDeep(raw, ['crestfactor', 'crestfactordb']) ??
      derived.crestFactorDb,
    peakDbm: derived.peakDbm,
    meanDbm: derived.meanDbm,
  }

  const hasAnyMetric = Object.values(metrics).some((value) => typeof value === 'number')

  return {
    endpoint,
    ok: status >= 200 && status < 300,
    status,
    timestamp: new Date().toISOString(),
    source: hasAnyMetric || trace.length > 0 ? 'api' : 'api-derived',
    contentType,
    binCount:
      findFirstNumberDeep(raw, ['bincount', 'bins', 'fft', 'fftsize', 'samples']) ??
      trace.length ??
      0,
    tracePreview: trace.slice(0, 32).map((v) => Number(v.toFixed(3))),
    samplePreview: compactPreview(rawText),
    metrics,
    raw,
    normalizationNotes: notes,
  }
}

function syntheticFallback(endpoint: string, reason: string): NormalizedRFSweep {
  return {
    endpoint,
    ok: false,
    status: 0,
    timestamp: new Date().toISOString(),
    source: 'synthetic-fallback',
    contentType: 'synthetic',
    binCount: 4096,
    tracePreview: [],
    samplePreview: reason,
    normalizationNotes: [`fallback:${reason}`],
    metrics: {
      snrDb: 34.7,
      evmPct: 3.8,
      merDb: 34.2,
      obwMhz: 12.4,
      aclrLowDbc: -51.7,
      aclrHighDbc: -50.9,
      channelPowerDbm: -18.2,
      noiseFloorDbm: -96.8,
      crestFactorDb: 9.6,
      peakDbm: -18.2,
      meanDbm: -58.4,
    },
    raw: null,
  }
}

export function useRFSpectrumSweep(options: UseRFSpectrumSweepOptions = {}) {
  const {
    enabled = true,
    intervalMs = 2500,
    endpoint = BRIDGE_ENDPOINT,
  } = options

  const [snapshot, setSnapshot] = useState<NormalizedRFSweep | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!enabled) return

    let cancelled = false
    let timer: number | undefined

    async function load() {
      const controller = new AbortController()
      const timeout = window.setTimeout(() => controller.abort(), 2400)

      try {
        setLoading(true)

        const res = await fetch(endpoint, {
          method: 'GET',
          signal: controller.signal,
          headers: { Accept: 'application/json,text/plain,*/*' },
          cache: 'no-store',
        })

        const text = await res.text()
        const contentType = res.headers.get('content-type') ?? ''

        let parsed: unknown = text
        try {
          parsed = JSON.parse(text)
        } catch {
          parsed = { rawText: text }
        }

        const normalized = normalizeSweep(parsed, endpoint, res.status, contentType, text)

        if (!cancelled) {
          setSnapshot(normalized)
          setError(res.ok ? null : `HTTP ${res.status}`)
        }
      } catch (err) {
        if (!cancelled) {
          const message = err instanceof Error ? err.message : 'fetch-error'
          setSnapshot(syntheticFallback(endpoint, message))
          setError(message)
        }
      } finally {
        window.clearTimeout(timeout)
        if (!cancelled) setLoading(false)
      }
    }

    void load()
    timer = window.setInterval(() => void load(), intervalMs)

    return () => {
      cancelled = true
      if (timer !== undefined) window.clearInterval(timer)
    }
  }, [enabled, endpoint, intervalMs])

  const status = useMemo(() => {
    if (loading && !snapshot) return 'BOOT'
    if (snapshot?.source === 'api') return 'API LIVE'
    if (snapshot?.source === 'api-derived') return 'API DERIVED'
    if (error) return 'FALLBACK'
    return 'SYNTHETIC'
  }, [error, loading, snapshot])

  return { snapshot, loading, error, status }
}
TS

echo
echo "=== 3) PATCH PROMO: USA ENDPOINT ASSOLUTO BRIDGE 4181 ==="

python3 - "$PROMO" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

text = re.sub(
    r"const rfSweep = useRFSpectrumSweep\(\{[^}]*\}\)",
    "const rfSweep = useRFSpectrumSweep({ enabled: true, intervalMs: 2200, endpoint: 'http://127.0.0.1:4181/api/rfpro/spectrum/sweep' })",
    text,
    count=1,
)

p.write_text(text, encoding="utf-8")
print("PROMO_ENDPOINT_PATCHED=", before != text)
PY

echo
echo "=== 4) PATCH LAYER: LABEL API LIVE / API DERIVED PIÙ CHIARI ==="

python3 - "$LAYER" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

text = text.replace("import type { RFSweepSnapshot } from '../hooks/useRFSpectrumSweep'", "import type { NormalizedRFSweep } from '../hooks/useRFSpectrumSweep'")
text = text.replace("snapshot: RFSweepSnapshot | null", "snapshot: NormalizedRFSweep | null")
text = text.replace("Il modulo RF non è più solo visuale: espone contratto dati, formule KPI e preview 3D", "Il modulo RF non è più solo visuale: espone contratto dati reale, normalizzazione KPI e preview 3D")
text = text.replace("<div><dt>Source</dt><dd>{snapshot?.source ?? '—'}</dd></div>", "<div><dt>Source</dt><dd>{snapshot?.source ?? '—'} · {snapshot?.contentType || '—'}</dd></div>")
text = text.replace("<div><dt>Bins</dt><dd>{snapshot?.binCount ?? '—'}</dd></div>", "<div><dt>Bins</dt><dd>{snapshot?.binCount ?? '—'} · preview {snapshot?.tracePreview?.length ?? 0}</dd></div>")
text = text.replace("<div><dt>Error</dt><dd>{error ?? '—'}</dd></div>", "<div><dt>Error</dt><dd>{error ?? 'none'}</dd></div>")

p.write_text(text, encoding="utf-8")
print("LAYER_PATCHED=", before != text)
PY

echo
echo "=== 5) CSS STATUS API DERIVED/API LIVE ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC BATCH2C RF REAL DATA CONTRACT FIX V1 START === \*/.*?/\* === TRFMC BATCH2C RF REAL DATA CONTRACT FIX V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC BATCH2C RF REAL DATA CONTRACT FIX V1 START === */
/*
  RF real data contract fix:
  - endpoint is now bridge absolute 127.0.0.1:4181;
  - API LIVE / API DERIVED state is visible;
  - KPI placeholders should disappear after first successful sweep.
*/

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head > strong[data-status="API LIVE"] {
  border-color: rgba(134,239,172,.42) !important;
  background: rgba(22,101,52,.24) !important;
  color: #86efac !important;
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head > strong[data-status="API DERIVED"] {
  border-color: rgba(103,232,249,.38) !important;
  background: rgba(8,47,73,.24) !important;
  color: #67e8f9 !important;
}

.mc-shell-engineering-only .trfmc-rf-api-card dd {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace !important;
}

.mc-shell-engineering-only .trfmc-rf-api-card small {
  max-height: 42px !important;
  overflow: hidden !important;
  border-top: 1px solid rgba(103,232,249,.10) !important;
  padding-top: 5px !important;
}
/* === TRFMC BATCH2C RF REAL DATA CONTRACT FIX V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_BATCH2C_APPENDED=True")
PY

echo
echo "=== 6) DIFF ==="
git diff -- "$HOOK" "$LAYER" "$PROMO" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 7) BUILD ==="

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
echo "=== 8) HTTP GATE ==="

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

check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 9) DOM GATE CON ATTESA FETCH ==="

DOM_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=7000 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=7000 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM"
fi

RF_LAYER_MARKER_COUNT="$(awk 'index($0, "data-trfmc-rf-engineering-layer-v1=\"mounted\"") {c++} END {print c+0}' "$DOM")"
API_LIVE_COUNT="$(awk 'index($0, "API LIVE") {c++} END {print c+0}' "$DOM")"
API_DERIVED_COUNT="$(awk 'index($0, "API DERIVED") {c++} END {print c+0}' "$DOM")"
SYNTHETIC_COUNT="$(awk 'index($0, ">SYNTHETIC<") {c++} END {print c+0}' "$DOM")"
WAITING_COUNT="$(awk 'index($0, "waiting first sweep sample") {c++} END {print c+0}' "$DOM")"
CSS_MARKER_COUNT="$(awk 'index($0, "TRFMC BATCH2C RF REAL DATA CONTRACT FIX V1 START") {c++} END {print c+0}' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "RF_LAYER_MARKER_COUNT=$RF_LAYER_MARKER_COUNT"
echo "API_LIVE_COUNT=$API_LIVE_COUNT"
echo "API_DERIVED_COUNT=$API_DERIVED_COUNT"
echo "SYNTHETIC_COUNT=$SYNTHETIC_COUNT"
echo "WAITING_COUNT=$WAITING_COUNT"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"

echo
echo "=== 10) SCREENSHOT GATE ==="

SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=7000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=7000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$RF_LAYER_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_LAYER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$API_LIVE_COUNT" = "0" ] && [ "$API_DERIVED_COUNT" = "0" ]; then RESULT="REVIEW_API_STATE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$WAITING_COUNT" != "0" ]; then RESULT="REVIEW_WAITING_STATE"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2C_RF_REAL_DATA_CONTRACT_FIX_V1",
  "mutation": "react_source_data_contract_fix",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "probe_raw": "$PROBE_TEXT",
  "probe_json": "$PROBE_JSON",
  "probe_report": "$PROBE_REPORT",
  "files_modified": [
    "$HOOK",
    "$LAYER",
    "$PROMO",
    "$CSS"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "rf_layer_marker_count": $RF_LAYER_MARKER_COUNT,
  "api_live_count": $API_LIVE_COUNT,
  "api_derived_count": $API_DERIVED_COUNT,
  "synthetic_count": $SYNTHETIC_COUNT,
  "waiting_count": $WAITING_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2c_rf_real_data_contract_fix_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH2C_RF_REAL_DATA_CONTRACT_FIX_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
