#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2E_RF_POST_SWEEP_ADAPTER_V1_$TS"
BACKUP="$OUT/backup"
JSONDIR="$OUT/post_candidate_json"

mkdir -p "$OUT" "$BACKUP" "$JSONDIR"
cd "$BASE"

HOOK="frontend/src/rf_instruments/hooks/useRFSpectrumSweep.ts"
PROMO="frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx"
LAYER="frontend/src/rf_instruments/panels/RFEngineeringMath3DPanelV1.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
POST_TESTS="$OUT/rf_post_candidate_endpoint_tests.tsv"
BUILDLOG="$OUT/npm_build_batch2e_rf_post_sweep_adapter_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_post_sweep_adapter_v1_1920x1080.png"
DIFF="$OUT/rf_post_sweep_adapter_v1.diff"
RESTORE="$OUT/RESTORE_RF_POST_SWEEP_ADAPTER_V1.sh"
CHOSEN="$OUT/chosen_trace_candidate.env"
PLAN="$OUT/BATCH2E_RF_POST_SWEEP_ADAPTER_PLAN.md"

echo "============================================================"
echo "TRFMC_BATCH2E_RF_POST_SWEEP_ADAPTER_V1"
echo "POST sweep probe · real trace adapter · conditional frontend patch"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$HOOK" "$PROMO" "$LAYER" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

cp -a "$HOOK" "$BACKUP/useRFSpectrumSweep.ts.before_$TS"
cp -a "$PROMO" "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS"
cp -a "$LAYER" "$BACKUP/RFEngineeringMath3DPanelV1.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/useRFSpectrumSweep.ts.before_$TS" "$HOOK"
cp -a "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS" "$PROMO"
cp -a "$BACKUP/RFEngineeringMath3DPanelV1.tsx.before_$TS" "$LAYER"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
echo "RESTORE_RF_POST_SWEEP_ADAPTER_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) POST / REAL TRACE CANDIDATE PROBE ==="

cat > "$POST_TESTS" <<'TSV'
method	url	payload	status	bytes	json_parse	numeric_arrays	best_array_len	has_metrics	classification
TSV

probe_post() {
  local url="$1"
  local payload="$2"
  local safe
  safe="$(echo "POST_$url" | sed 's#[/:?&=]#_#g')"
  local raw="$JSONDIR/${safe}.raw"
  local pretty="$JSONDIR/${safe}.json"

  local code
  code="$(curl -sS -L --max-time 12 \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json,text/plain,*/*' \
    -X POST \
    --data "$payload" \
    -o "$raw" \
    -w "%{http_code}" \
    "$url" || echo "000")"

  local bytes
  bytes="$(wc -c < "$raw" | tr -d ' ')"

  python3 - "$url" "$payload" "$code" "$bytes" "$raw" "$pretty" "$POST_TESTS" <<'PY'
import json, sys
from pathlib import Path

url, payload, code, bytes_count = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
raw_path, pretty_path, out_path = Path(sys.argv[5]), Path(sys.argv[6]), Path(sys.argv[7])

raw = raw_path.read_text(encoding="utf-8", errors="replace")
json_parse = "NO"
try:
    parsed = json.loads(raw)
    json_parse = "YES"
except Exception as exc:
    parsed = {"rawText": raw, "parse_error": str(exc)}

pretty_path.write_text(json.dumps(parsed, indent=2, ensure_ascii=False), encoding="utf-8")

numeric_arrays = []
metrics_keys = set()

def parse_num(x):
    if isinstance(x, (int, float)):
        return float(x)
    if isinstance(x, str):
        try:
            return float(x.replace(",", ".").replace("dBm", "").replace("dB", "").strip())
        except Exception:
            return None
    return None

def walk(x):
    if isinstance(x, dict):
        for k, v in x.items():
            kl = k.lower().replace("_", "").replace("-", "")
            if any(m in kl for m in ["snr", "evm", "mer", "obw", "aclr", "dbm", "noise", "power", "channelpower"]):
                metrics_keys.add(k)
            walk(v)
    elif isinstance(x, list):
        nums = []
        for item in x:
            if isinstance(item, (int, float)):
                nums.append(float(item))
            elif isinstance(item, list) and len(item) >= 2:
                n = parse_num(item[1])
                if n is not None:
                    nums.append(n)
            elif isinstance(item, dict):
                for key in ["dbm", "power", "power_dbm", "y", "value", "amp", "amplitude"]:
                    n = parse_num(item.get(key))
                    if n is not None:
                        nums.append(n)
                        break
        if len(nums) >= 16:
            numeric_arrays.append(len(nums))
        for item in x:
            walk(item)

walk(parsed)

best = max(numeric_arrays) if numeric_arrays else 0
has_metrics = "YES" if metrics_keys else "NO"

classification = "NO_DATA"
if code == "000":
    classification = "UNREACHABLE"
elif not code.startswith("2"):
    classification = "NON_2XX"
elif best >= 256:
    classification = "TRACE_CANDIDATE_STRONG"
elif best >= 16:
    classification = "TRACE_CANDIDATE_WEAK"
elif has_metrics == "YES":
    classification = "METADATA_METRICS_ONLY"
elif json_parse == "YES":
    classification = "JSON_METADATA_ONLY"

with out_path.open("a", encoding="utf-8") as f:
    safe_payload = payload.replace("\t", " ").replace("\n", " ")
    f.write(f"POST\t{url}\t{safe_payload}\t{code}\t{bytes_count}\t{json_parse}\t{len(numeric_arrays)}\t{best}\t{has_metrics}\t{classification}\n")
PY
}

probe_get() {
  local url="$1"
  local safe
  safe="$(echo "GET_$url" | sed 's#[/:?&=]#_#g')"
  local raw="$JSONDIR/${safe}.raw"
  local pretty="$JSONDIR/${safe}.json"

  local code
  code="$(curl -sS -L --max-time 12 \
    -H 'Accept: application/json,text/plain,*/*' \
    -o "$raw" \
    -w "%{http_code}" \
    "$url" || echo "000")"

  local bytes
  bytes="$(wc -c < "$raw" | tr -d ' ')"

  python3 - "$url" "$code" "$bytes" "$raw" "$pretty" "$POST_TESTS" <<'PY'
import json, sys
from pathlib import Path

url, code, bytes_count = sys.argv[1], sys.argv[2], sys.argv[3]
raw_path, pretty_path, out_path = Path(sys.argv[4]), Path(sys.argv[5]), Path(sys.argv[6])
raw = raw_path.read_text(encoding="utf-8", errors="replace")

json_parse = "NO"
try:
    parsed = json.loads(raw)
    json_parse = "YES"
except Exception as exc:
    parsed = {"rawText": raw, "parse_error": str(exc)}

pretty_path.write_text(json.dumps(parsed, indent=2, ensure_ascii=False), encoding="utf-8")

numeric_arrays = []
metrics_keys = set()

def walk(x):
    if isinstance(x, dict):
        for k, v in x.items():
            kl = k.lower().replace("_", "").replace("-", "")
            if any(m in kl for m in ["snr", "evm", "mer", "obw", "aclr", "dbm", "noise", "power"]):
                metrics_keys.add(k)
            walk(v)
    elif isinstance(x, list):
        nums = []
        for item in x:
            if isinstance(item, (int, float)):
                nums.append(float(item))
            elif isinstance(item, list) and len(item) >= 2 and isinstance(item[1], (int, float)):
                nums.append(float(item[1]))
            elif isinstance(item, dict):
                for key in ["dbm", "power", "y", "value"]:
                    if isinstance(item.get(key), (int, float)):
                        nums.append(float(item[key]))
                        break
        if len(nums) >= 16:
            numeric_arrays.append(len(nums))
        for item in x:
            walk(item)

walk(parsed)
best = max(numeric_arrays) if numeric_arrays else 0
has_metrics = "YES" if metrics_keys else "NO"

classification = "NO_DATA"
if code == "000":
    classification = "UNREACHABLE"
elif not code.startswith("2"):
    classification = "NON_2XX"
elif best >= 256:
    classification = "TRACE_CANDIDATE_STRONG"
elif best >= 16:
    classification = "TRACE_CANDIDATE_WEAK"
elif has_metrics == "YES":
    classification = "METADATA_METRICS_ONLY"
elif json_parse == "YES":
    classification = "JSON_METADATA_ONLY"

with out_path.open("a", encoding="utf-8") as f:
    f.write(f"GET\t{url}\t-\t{code}\t{bytes_count}\t{json_parse}\t{len(numeric_arrays)}\t{best}\t{has_metrics}\t{classification}\n")
PY
}

PAYLOAD_RFPRO='{"start_hz":2400000000,"stop_hz":2480000000,"rbw_hz":10000,"points":1200,"seq":1,"use_hackrf":false,"timeout_s":3}'
PAYLOAD_RFPRO_ALT='{"start_hz":2400000000,"stop_hz":2480000000,"bin_hz":10000,"points":1200,"seq":1,"use_hackrf":false,"timeout_s":3}'
PAYLOAD_V580='{"start_hz":2400000000,"stop_hz":2480000000,"rbw_hz":10000,"points":900,"use_hackrf":false}'
PAYLOAD_V586='{"start_hz":2400000000,"stop_hz":2480000000,"rbw_hz":1000000,"use_hackrf":false,"timeout_s":3}'

probe_post "http://127.0.0.1:8000/api/rfpro/spectrum/sweep" "$PAYLOAD_RFPRO"
probe_post "http://127.0.0.1:4181/api/rfpro/spectrum/sweep" "$PAYLOAD_RFPRO"
probe_post "http://127.0.0.1:8000/api/rfpro/spectrum/sweep" "$PAYLOAD_RFPRO_ALT"
probe_post "http://127.0.0.1:4181/api/rfpro/spectrum/sweep" "$PAYLOAD_RFPRO_ALT"

probe_get "http://127.0.0.1:4181/api/v585/realtime/one_frame?start_hz=2400000000&stop_hz=2480000000&bin_hz=10000&points=1200&use_hackrf=false"
probe_get "http://127.0.0.1:8000/api/v585/realtime/one_frame?start_hz=2400000000&stop_hz=2480000000&bin_hz=10000&points=1200&use_hackrf=false"

probe_post "http://127.0.0.1:8000/api/v580/workbench/sweep/window" "$PAYLOAD_V580"
probe_post "http://127.0.0.1:4181/api/v580/workbench/sweep/window" "$PAYLOAD_V580"

probe_post "http://127.0.0.1:8000/api/v586/fullband/sweep" "$PAYLOAD_V586"
probe_post "http://127.0.0.1:4181/api/v586/fullband/sweep" "$PAYLOAD_V586"

column -t -s $'\t' "$POST_TESTS"

python3 - "$POST_TESTS" "$CHOSEN" <<'PY'
import csv, sys
from pathlib import Path

tsv = Path(sys.argv[1])
chosen = Path(sys.argv[2])

rows = list(csv.DictReader(tsv.open(encoding="utf-8"), delimiter="\t"))

priority = {
    "TRACE_CANDIDATE_STRONG": 0,
    "TRACE_CANDIDATE_WEAK": 1,
    "METADATA_METRICS_ONLY": 2,
    "JSON_METADATA_ONLY": 3,
    "NON_2XX": 4,
    "UNREACHABLE": 5,
    "NO_DATA": 6,
}

rows.sort(key=lambda r: (
    priority.get(r["classification"], 99),
    -int(r["best_array_len"] or 0),
    0 if r["method"] == "POST" else 1,
    0 if ":8000/" in r["url"] else 1,
))

best = rows[0] if rows else None

with chosen.open("w", encoding="utf-8") as f:
    if not best:
        f.write('CHOSEN_CLASSIFICATION="NONE"\n')
    else:
        for k, v in best.items():
            key = "CHOSEN_" + k.upper().replace("/", "_")
            f.write(f'{key}="{v.replace(chr(34), chr(92)+chr(34))}"\n')
PY

cat "$CHOSEN"

# shellcheck disable=SC1090
source "$CHOSEN"

CHOSEN_CLASSIFICATION="${CHOSEN_CLASSIFICATION:-NONE}"
CHOSEN_METHOD="${CHOSEN_METHOD:-}"
CHOSEN_URL="${CHOSEN_URL:-}"
CHOSEN_PAYLOAD="${CHOSEN_PAYLOAD:-}"

PATCH_APPLIED="false"

if [ "$CHOSEN_CLASSIFICATION" = "TRACE_CANDIDATE_STRONG" ]; then
  PATCH_APPLIED="true"

  echo
  echo "=== 2) PATCH useRFSpectrumSweep.ts PER POST TRACE CANDIDATE ==="

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
  method: 'GET' | 'POST'
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
  method?: 'GET' | 'POST'
  body?: Record<string, unknown>
}

const DEFAULT_ENDPOINT = 'http://127.0.0.1:8000/api/rfpro/spectrum/sweep'
const DEFAULT_BODY = {
  start_hz: 2400000000,
  stop_hz: 2480000000,
  rbw_hz: 10000,
  points: 1200,
  seq: 1,
  use_hackrf: false,
  timeout_s: 3,
}

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

  function pointValue(item: unknown): number | null {
    if (typeof item === 'number' && Number.isFinite(item)) return item

    if (Array.isArray(item) && item.length >= 2) {
      return parseNumber(item[1])
    }

    const rec = asRecord(item)
    if (rec) {
      return (
        parseNumber(rec.dbm) ??
        parseNumber(rec.power_dbm) ??
        parseNumber(rec.power) ??
        parseNumber(rec.y) ??
        parseNumber(rec.value) ??
        parseNumber(rec.amp) ??
        parseNumber(rec.amplitude)
      )
    }

    return null
  }

  function walk(node: unknown) {
    if (node && typeof node === 'object') {
      if (visited.has(node)) return
      visited.add(node)
    }

    if (Array.isArray(node)) {
      const nums = node
        .map(pointValue)
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
    return { peakDbm: null, meanDbm: null, noiseFloorDbm: null, snrDb: null, crestFactorDb: null }
  }

  const peak = Number(Math.max(...trace).toFixed(3))
  const mean = avg(trace)
  const noise = percentile(trace, 0.20)
  const snr = noise === null ? null : Number((peak - noise).toFixed(3))

  const linear = trace.map((db) => Math.pow(10, db / 20))
  const rms = Math.sqrt(linear.reduce((s, x) => s + x * x, 0) / linear.length)
  const peakLinear = Math.max(...linear)
  const crest = rms > 0 ? Number((20 * Math.log10(peakLinear / rms)).toFixed(3)) : null

  return { peakDbm: peak, meanDbm: mean, noiseFloorDbm: noise, snrDb: snr, crestFactorDb: crest }
}

function normalizeSweep(raw: unknown, endpoint: string, method: 'GET' | 'POST', status: number, contentType: string, rawText: string): NormalizedRFSweep {
  const notes: string[] = []
  const numericArrays = findNumericArraysDeep(raw)
  const trace = numericArrays[0] ?? []
  const derived = deriveFromTrace(trace)

  notes.push(trace.length > 0 ? `trace_detected:${trace.length}` : 'trace_not_detected')

  const metrics: RFSweepMetrics = {
    snrDb: findFirstNumberDeep(raw, ['snr', 'snrdb', 'signaltonoise']) ?? derived.snrDb,
    evmPct: findFirstNumberDeep(raw, ['evm', 'evmpct', 'evmpercent', 'evmrms']),
    merDb: findFirstNumberDeep(raw, ['mer', 'merdb']),
    obwMhz: findFirstNumberDeep(raw, ['obw', 'obwmhz', 'occupiedbandwidth']),
    aclrLowDbc: findFirstNumberDeep(raw, ['aclrlow', 'aclrldb', 'adjacentlow']),
    aclrHighDbc: findFirstNumberDeep(raw, ['aclrhigh', 'aclrhdb', 'adjacenthigh']),
    channelPowerDbm: findFirstNumberDeep(raw, ['channelpower', 'channelpowerdbm', 'chpower']),
    noiseFloorDbm: findFirstNumberDeep(raw, ['noisefloor', 'noisefloordbm', 'noise']) ?? derived.noiseFloorDbm,
    crestFactorDb: findFirstNumberDeep(raw, ['crestfactor', 'crestfactordb']) ?? derived.crestFactorDb,
    peakDbm: derived.peakDbm,
    meanDbm: derived.meanDbm,
  }

  const explicitBins =
    findFirstNumberDeep(raw, ['bincount', 'bins', 'fftsize', 'samples', 'points']) ?? 0

  return {
    endpoint,
    method,
    ok: status >= 200 && status < 300,
    status,
    timestamp: new Date().toISOString(),
    source: trace.length >= 16 ? 'api' : 'api-derived',
    contentType,
    binCount: trace.length || explicitBins,
    tracePreview: trace.slice(0, 32).map((v) => Number(v.toFixed(3))),
    samplePreview: compactPreview(rawText),
    metrics,
    raw,
    normalizationNotes: notes,
  }
}

function syntheticFallback(endpoint: string, method: 'GET' | 'POST', reason: string): NormalizedRFSweep {
  return {
    endpoint,
    method,
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
    endpoint = DEFAULT_ENDPOINT,
    method = 'POST',
    body = DEFAULT_BODY,
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
      const timeout = window.setTimeout(() => controller.abort(), 3200)

      try {
        setLoading(true)

        const res = await fetch(endpoint, {
          method,
          signal: controller.signal,
          headers: { Accept: 'application/json,text/plain,*/*', 'Content-Type': 'application/json' },
          cache: 'no-store',
          body: method === 'POST' ? JSON.stringify(body) : undefined,
        })

        const text = await res.text()
        const contentType = res.headers.get('content-type') ?? ''

        let parsed: unknown = text
        try {
          parsed = JSON.parse(text)
        } catch {
          parsed = { rawText: text }
        }

        const normalized = normalizeSweep(parsed, endpoint, method, res.status, contentType, text)

        if (!cancelled) {
          setSnapshot(normalized)
          setError(res.ok ? null : `HTTP ${res.status}`)
        }
      } catch (err) {
        if (!cancelled) {
          const message = err instanceof Error ? err.message : 'fetch-error'
          setSnapshot(syntheticFallback(endpoint, method, message))
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
  }, [enabled, endpoint, intervalMs, method, JSON.stringify(body)])

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
  echo "=== 3) PATCH PROMO CON ENDPOINT/METHOD/PAYLOAD SCELTO ==="

  python3 - "$PROMO" "$CHOSEN_URL" "$CHOSEN_METHOD" "$CHOSEN_PAYLOAD" <<'PY'
from pathlib import Path
import json, re, sys

p = Path(sys.argv[1])
url = sys.argv[2]
method = sys.argv[3]
payload = sys.argv[4]

try:
    payload_obj = json.loads(payload) if payload and payload != "-" else {}
except Exception:
    payload_obj = {}

text = p.read_text(encoding="utf-8", errors="replace")
before = text

replacement = (
    "const rfSweep = useRFSpectrumSweep({ "
    "enabled: true, "
    "intervalMs: 2200, "
    f"endpoint: '{url}', "
    f"method: '{method}', "
    f"body: {json.dumps(payload_obj, separators=(',', ':'))} "
    "})"
)

text = re.sub(r"const rfSweep = useRFSpectrumSweep\(\{[^}]*\}\)", replacement, text, count=1)

p.write_text(text, encoding="utf-8")
print("PROMO_TRACE_ENDPOINT_PATCHED=", before != text)
PY

else
  echo
  echo "NESSUN TRACE_CANDIDATE_STRONG: nessuna patch frontend applicata."
fi

echo
echo "=== 4) CSS SMALL STATUS PATCH ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC BATCH2E RF POST SWEEP ADAPTER V1 START === \*/.*?/\* === TRFMC BATCH2E RF POST SWEEP ADAPTER V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC BATCH2E RF POST SWEEP ADAPTER V1 START === */
.mc-shell-engineering-only .trfmc-rf-api-card dd,
.mc-shell-engineering-only .trfmc-rf-api-card small {
  user-select: text;
}

.mc-shell-engineering-only .trfmc-rf-engineering-layer-head > strong[data-status="API LIVE"] {
  box-shadow: 0 0 18px rgba(134,239,172,.14);
}
/* === TRFMC BATCH2E RF POST SWEEP ADAPTER V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
PY

echo
echo "=== 5) DIFF ==="
git diff -- "$HOOK" "$PROMO" "$LAYER" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 6) BUILD ==="

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
echo "=== 7) HTTP GATE ==="

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
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:8000/api/rfpro/state"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 8) DOM GATE CON ATTESA FETCH ==="

DOM_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --dump-dom \
    "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"
else
  echo "NO_CHROME_AVAILABLE" > "$DOM"
fi

RF_LAYER_MARKER_COUNT="$(awk 'index($0, "data-trfmc-rf-engineering-layer-v1=\"mounted\"") {c++} END {print c+0}' "$DOM")"
API_LIVE_COUNT="$(awk 'index($0, "API LIVE") {c++} END {print c+0}' "$DOM")"
API_DERIVED_COUNT="$(awk 'index($0, "API DERIVED") {c++} END {print c+0}' "$DOM")"
BINS_ZERO_COUNT="$(awk 'index($0, "0 · preview 0") {c++} END {print c+0}' "$DOM")"
WAITING_COUNT="$(awk 'index($0, "waiting first sweep sample") {c++} END {print c+0}' "$DOM")"
CSS_MARKER_COUNT="$(awk 'index($0, "TRFMC BATCH2E RF POST SWEEP ADAPTER V1 START") {c++} END {print c+0}' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "RF_LAYER_MARKER_COUNT=$RF_LAYER_MARKER_COUNT"
echo "API_LIVE_COUNT=$API_LIVE_COUNT"
echo "API_DERIVED_COUNT=$API_DERIVED_COUNT"
echo "BINS_ZERO_COUNT=$BINS_ZERO_COUNT"
echo "WAITING_COUNT=$WAITING_COUNT"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"

echo
echo "=== 9) SCREENSHOT GATE ==="

SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=8000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi

STRONG_COUNT="$(awk 'NR>1 && $10=="TRACE_CANDIDATE_STRONG" {c++} END {print c+0}' "$POST_TESTS")"
WEAK_COUNT="$(awk 'NR>1 && $10=="TRACE_CANDIDATE_WEAK" {c++} END {print c+0}' "$POST_TESTS")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$STRONG_COUNT" = "0" ]; then RESULT="REVIEW_NO_STRONG_TRACE_CANDIDATE"; fi
if [ "$PATCH_APPLIED" != "true" ]; then RESULT="REVIEW_NO_FRONTEND_PATCH"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$RF_LAYER_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_LAYER"; fi
if [ "$PATCH_APPLIED" = "true" ] && [ "$DOM_RESULT" = "PASS" ] && [ "$API_LIVE_COUNT" = "0" ]; then RESULT="REVIEW_API_LIVE_NOT_VISIBLE"; fi

cat > "$PLAN" <<MD
# TRFMC Batch 2E — RF POST Sweep Adapter V1

## Result interpretation
- If \`TRACE_CANDIDATE_STRONG > 0\`, the frontend hook is patched to use the selected POST trace endpoint.
- If no strong candidate is found, no frontend data-source patch is applied.
- If DOM shows \`API LIVE\` and bins/preview not zero, the RF layer is finally consuming trace-like data.
- If DOM remains \`API DERIVED\` with bins zero, the backend must expose a normalized read-only trace endpoint.

## Chosen candidate
See: \`$CHOSEN\`
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2E_RF_POST_SWEEP_ADAPTER_V1",
  "mutation": "conditional_react_source_patch",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "post_tests": "$POST_TESTS",
  "candidate_json_dir": "$JSONDIR",
  "chosen_candidate": "$CHOSEN",
  "patch_applied": $PATCH_APPLIED,
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "plan": "$PLAN",
  "build_result": "$BUILD_RESULT",
  "trace_candidate_strong": $STRONG_COUNT,
  "trace_candidate_weak": $WEAK_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "rf_layer_marker_count": $RF_LAYER_MARKER_COUNT,
  "api_live_count": $API_LIVE_COUNT,
  "api_derived_count": $API_DERIVED_COUNT,
  "bins_zero_count": $BINS_ZERO_COUNT,
  "waiting_count": $WAITING_COUNT,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2e_rf_post_sweep_adapter_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH2E_RF_POST_SWEEP_ADAPTER_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
