#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2F_RF_NORMALIZED_TRACE_ENDPOINT_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

ROUTER="backend/routers/rf_normalized_trace_v1.py"
PROMO="frontend/src/layout_orchestrator/RFSignalAnalyzerPromotionV1.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
APP_SCAN="$OUT/backend_app_candidate_scan.tsv"
PATCH_LOG="$OUT/backend_patch_log.tsv"
HTTP="$OUT/http.tsv"
TRACE_RAW="$OUT/normalized_trace_probe.raw.json"
TRACE_REPORT="$OUT/normalized_trace_probe_report.tsv"
BUILDLOG="$OUT/npm_build_batch2f_rf_normalized_trace_endpoint_v1.log"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/rf_normalized_trace_endpoint_v1_1920x1080.png"
DIFF="$OUT/rf_normalized_trace_endpoint_v1.diff"
RESTORE="$OUT/RESTORE_RF_NORMALIZED_TRACE_ENDPOINT_V1.sh"

echo "============================================================"
echo "TRFMC_BATCH2F_RF_NORMALIZED_TRACE_ENDPOINT_V1"
echo "Backend readonly normalized trace endpoint · conditional frontend bind"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$PROMO" ]; then
  echo "ERRORE: file frontend mancante: $PROMO"
  exit 1
fi

mkdir -p "$(dirname "$ROUTER")"

[ -f "$ROUTER" ] && cp -a "$ROUTER" "$BACKUP/rf_normalized_trace_v1.py.before_$TS"
cp -a "$PROMO" "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS"
[ -f "$CSS" ] && cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

if [ -f "$BACKUP/rf_normalized_trace_v1.py.before_$TS" ]; then
  cp -a "$BACKUP/rf_normalized_trace_v1.py.before_$TS" "$ROUTER"
else
  rm -f "$ROUTER"
fi

cp -a "$BACKUP/RFSignalAnalyzerPromotionV1.tsx.before_$TS" "$PROMO"

if [ -f "$BACKUP/styles.css.before_$TS" ]; then
  cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
fi

if [ -f "$BACKUP/backend_app_file.before_$TS" ] && [ -f "$BACKUP/backend_app_path.txt" ]; then
  APPFILE="\$(cat "$BACKUP/backend_app_path.txt")"
  cp -a "$BACKUP/backend_app_file.before_$TS" "\$APPFILE"
fi

echo "RESTORE_RF_NORMALIZED_TRACE_ENDPOINT_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREO ROUTER BACKEND READ-ONLY NORMALIZZATO ==="

cat > "$ROUTER" <<'PY'
from __future__ import annotations

import math
import time
from typing import Any, Dict, List

from fastapi import APIRouter, Query

router = APIRouter(
    prefix="/api/rfpro/normalized",
    tags=["RF PRO Normalized Readonly Trace"],
)

try:
    from routers.rfpro_final import synthetic_spectrum as _rfpro_synthetic_spectrum
    from routers.rfpro_final import spectrum_metrics as _rfpro_spectrum_metrics
except Exception:  # pragma: no cover - import style varies by launcher
    try:
        from backend.routers.rfpro_final import synthetic_spectrum as _rfpro_synthetic_spectrum
        from backend.routers.rfpro_final import spectrum_metrics as _rfpro_spectrum_metrics
    except Exception:
        _rfpro_synthetic_spectrum = None
        _rfpro_spectrum_metrics = None


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _local_synthetic_trace(start_hz: float, stop_hz: float, points: int, seq: int) -> List[Dict[str, float]]:
    points = int(_clamp(points, 256, 4096))
    span = max(1.0, stop_hz - start_hz)
    carriers = [
        (0.17, 18.0, 0.006),
        (0.34, 33.0, 0.0045),
        (0.54, 24.0, 0.0065),
        (0.69, 41.0, 0.0038),
        (0.82, 28.0, 0.007),
    ]

    trace: List[Dict[str, float]] = []

    for i in range(points):
        x = i / max(1, points - 1)
        freq_hz = start_hz + span * x

        floor = -96.0
        ripple = 1.8 * math.sin(2.0 * math.pi * (x * 7.0 + seq * 0.013))
        noise_shape = 1.1 * math.sin(2.0 * math.pi * (x * 19.0 + 0.31))

        peak = 0.0
        for center, gain, width in carriers:
            drift = 0.002 * math.sin(seq * 0.021 + center * 11.0)
            peak += gain * math.exp(-((x - center - drift) ** 2) / (2.0 * width * width))

        dbm = floor + ripple + noise_shape + peak

        trace.append({
            "freq_hz": round(freq_hz, 3),
            "mhz": round(freq_hz / 1_000_000.0, 6),
            "dbm": round(dbm, 3),
        })

    return trace


def _normalize_points(data: Any, start_hz: float, stop_hz: float, points: int) -> List[Dict[str, float]]:
    if not isinstance(data, list):
        return []

    normalized: List[Dict[str, float]] = []
    span = max(1.0, stop_hz - start_hz)

    for idx, item in enumerate(data):
        if isinstance(item, dict):
            freq_hz = (
                item.get("freq_hz")
                or item.get("frequency_hz")
                or item.get("freq")
                or item.get("frequency")
            )
            mhz = item.get("mhz") or item.get("freq_mhz") or item.get("frequency_mhz")
            dbm = item.get("dbm") or item.get("power_dbm") or item.get("power") or item.get("y")

            if freq_hz is None and mhz is not None:
                freq_hz = float(mhz) * 1_000_000.0

            if freq_hz is None:
                freq_hz = start_hz + span * (idx / max(1, len(data) - 1))

            if dbm is None:
                continue

            normalized.append({
                "freq_hz": round(float(freq_hz), 3),
                "mhz": round(float(freq_hz) / 1_000_000.0, 6),
                "dbm": round(float(dbm), 3),
            })

        elif isinstance(item, (int, float)):
            freq_hz = start_hz + span * (idx / max(1, len(data) - 1))
            normalized.append({
                "freq_hz": round(freq_hz, 3),
                "mhz": round(freq_hz / 1_000_000.0, 6),
                "dbm": round(float(item), 3),
            })

    return normalized[:points]


def _percentile(values: List[float], q: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    idx = int(round((len(s) - 1) * q))
    idx = max(0, min(len(s) - 1, idx))
    return s[idx]


def _metrics(trace: List[Dict[str, float]], start_hz: float, stop_hz: float) -> Dict[str, Any]:
    powers = [float(p["dbm"]) for p in trace]
    if not powers:
        return {
            "snr_db": None,
            "evm_pct": None,
            "mer_db": None,
            "obw_mhz": None,
            "aclr_low_dbc": None,
            "aclr_high_dbc": None,
            "channel_power_dbm": None,
            "noise_floor_dbm": None,
            "crest_factor_db": None,
            "peak_dbm": None,
            "mean_dbm": None,
        }

    peak = max(powers)
    mean = sum(powers) / len(powers)
    noise = _percentile(powers, 0.20)
    snr = peak - noise

    threshold = noise + 6.0
    occupied = [trace[i]["freq_hz"] for i, p in enumerate(powers) if p >= threshold]
    if occupied:
        obw_mhz = (max(occupied) - min(occupied)) / 1_000_000.0
    else:
        obw_mhz = (stop_hz - start_hz) / 1_000_000.0 * 0.15

    linear = [10.0 ** (p / 20.0) for p in powers]
    rms = math.sqrt(sum(v * v for v in linear) / len(linear))
    crest = 20.0 * math.log10(max(linear) / rms) if rms > 0 else None

    # Synthetic but deterministic quality estimate from measured/derived SNR.
    evm_pct = max(1.0, min(18.0, 100.0 / max(8.0, snr)))
    mer_db = 20.0 * math.log10(100.0 / evm_pct)

    return {
        "snr_db": round(snr, 3),
        "evm_pct": round(evm_pct, 3),
        "mer_db": round(mer_db, 3),
        "obw_mhz": round(obw_mhz, 3),
        "aclr_low_dbc": round(noise - peak, 3),
        "aclr_high_dbc": round(noise - peak + 0.7, 3),
        "channel_power_dbm": round(peak, 3),
        "noise_floor_dbm": round(noise, 3),
        "crest_factor_db": None if crest is None else round(crest, 3),
        "peak_dbm": round(peak, 3),
        "mean_dbm": round(mean, 3),
    }


@router.get("/spectrum/trace")
def normalized_spectrum_trace(
    start_hz: float = Query(2_400_000_000.0, ge=1_000_000.0, le=6_000_000_000.0),
    stop_hz: float = Query(2_480_000_000.0, ge=1_000_001.0, le=6_000_000_000.0),
    points: int = Query(1200, ge=256, le=4096),
    seq: int = Query(0, ge=0, le=1_000_000),
) -> Dict[str, Any]:
    """
    Read-only normalized RF spectrum trace.

    Safety:
    - no TX;
    - no SDR control;
    - no hackrf_sweep execution;
    - deterministic synthetic/read-only trace when no capture is available.
    """
    if stop_hz <= start_hz:
        stop_hz = start_hz + 80_000_000.0

    points = int(_clamp(points, 256, 4096))

    source = "NORMALIZED_SYNTHETIC_READONLY"
    raw_trace: List[Dict[str, float]]

    if _rfpro_synthetic_spectrum is not None:
        try:
            raw = _rfpro_synthetic_spectrum(start_hz, stop_hz, points, seq=seq)
            raw_trace = _normalize_points(raw, start_hz, stop_hz, points)
            source = "RFPRO_FINAL_SYNTHETIC_REUSED_READONLY"
        except Exception:
            raw_trace = _local_synthetic_trace(start_hz, stop_hz, points, seq)
            source = "NORMALIZED_SYNTHETIC_READONLY_FALLBACK"
    else:
        raw_trace = _local_synthetic_trace(start_hz, stop_hz, points, seq)

    metrics = _metrics(raw_trace, start_hz, stop_hz)

    return {
        "ok": True,
        "version": "batch2f.normalized.trace.v1",
        "source": source,
        "mode": "read-only",
        "rx_only": True,
        "tx_enabled": False,
        "hackrf_control": False,
        "timestamp": time.time(),
        "center_mhz": round(((start_hz + stop_hz) / 2.0) / 1_000_000.0, 6),
        "span_mhz": round((stop_hz - start_hz) / 1_000_000.0, 6),
        "start_hz": round(start_hz, 3),
        "stop_hz": round(stop_hz, 3),
        "points": len(raw_trace),
        "trace": raw_trace,
        "metrics": metrics,
        "contract": {
            "trace_shape": [{"freq_hz": "number", "mhz": "number", "dbm": "number"}],
            "metrics_shape": {
                "snr_db": "number",
                "evm_pct": "number",
                "mer_db": "number",
                "obw_mhz": "number",
                "aclr_low_dbc": "number",
                "aclr_high_dbc": "number",
                "channel_power_dbm": "number",
                "noise_floor_dbm": "number",
            },
        },
    }
PY

echo
echo "=== 2) CERCO APP BACKEND DA PATCHARE ==="

python3 - "$BASE" "$APP_SCAN" "$PATCH_LOG" "$BACKUP" "$TS" <<'PY'
from pathlib import Path
import re
import sys

base = Path(sys.argv[1])
scan = Path(sys.argv[2])
patch_log = Path(sys.argv[3])
backup = Path(sys.argv[4])
ts = sys.argv[5]

candidate_paths = [
    base / "backend/main_v580.py",
    base / "backend/main.py",
    base / "backend/app/main.py",
    base / "backend/core_live_standalone_server.py",
]

rows = []
best = None

for p in candidate_paths:
    if not p.exists():
        rows.append((str(p.relative_to(base)), "NO", "0", "0", "missing"))
        continue

    text = p.read_text(encoding="utf-8", errors="replace")
    score = 0
    if "FastAPI" in text:
        score += 10
    if "include_router" in text:
        score += 10
    if "rfpro_final" in text:
        score += 20
    if "/api/rfpro" in text:
        score += 15
    if "routers" in text:
        score += 5

    rows.append((str(p.relative_to(base)), "YES", str(score), str(len(text)), "candidate"))

    if best is None or score > best[0]:
        best = (score, p, text)

scan.write_text(
    "path\texists\tscore\tbytes\tnote\n" +
    "\n".join("\t".join(r) for r in rows) + "\n",
    encoding="utf-8",
)

if best is None or best[0] < 20:
    patch_log.write_text("result\tmessage\nFAIL\tNo suitable backend app file found\n", encoding="utf-8")
    raise SystemExit(2)

_, appfile, text = best

(backup / "backend_app_path.txt").write_text(str(appfile), encoding="utf-8")
backup_target = backup / f"backend_app_file.before_{ts}"
backup_target.write_text(text, encoding="utf-8")

marker_start = "# === TRFMC BATCH2F RF NORMALIZED TRACE ROUTER START ==="
marker_end = "# === TRFMC BATCH2F RF NORMALIZED TRACE ROUTER END ==="

block = f"""
{marker_start}
try:
    from routers import rf_normalized_trace_v1
except Exception:
    try:
        from backend.routers import rf_normalized_trace_v1
    except Exception:
        rf_normalized_trace_v1 = None

try:
    if rf_normalized_trace_v1 is not None:
        app.include_router(rf_normalized_trace_v1.router)
except Exception as exc:
    print("TRFMC Batch2F normalized RF trace router include failed:", repr(exc))
{marker_end}
"""

if marker_start in text and marker_end in text:
    text = re.sub(
        re.escape(marker_start) + r".*?" + re.escape(marker_end),
        block.strip(),
        text,
        flags=re.S,
    )
else:
    text = text.rstrip() + "\n\n" + block + "\n"

appfile.write_text(text, encoding="utf-8")

patch_log.write_text(
    "result\tappfile\tmessage\n"
    f"PASS\t{appfile.relative_to(base)}\tRouter include block installed\n",
    encoding="utf-8",
)
PY

cat "$APP_SCAN" | column -t -s $'\t'
echo
cat "$PATCH_LOG" | column -t -s $'\t'

APPFILE="$(cat "$BACKUP/backend_app_path.txt")"

echo
echo "=== 3) PY COMPILE ==="
python3 -m py_compile "$ROUTER" "$APPFILE"

echo
echo "=== 4) PROVO ENDPOINT LIVE NORMALIZZATO ==="

TRACE_URL="http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=1"
TRACE_CODE="$(curl -sS -L --max-time 10 -o "$TRACE_RAW" -w "%{http_code}" "$TRACE_URL" || echo "000")"
TRACE_BYTES="$(wc -c < "$TRACE_RAW" | tr -d ' ')"

python3 - "$TRACE_RAW" "$TRACE_REPORT" "$TRACE_CODE" "$TRACE_BYTES" <<'PY'
import json
import sys
from pathlib import Path

raw_path = Path(sys.argv[1])
report = Path(sys.argv[2])
code = sys.argv[3]
bytes_count = sys.argv[4]

raw = raw_path.read_text(encoding="utf-8", errors="replace")
json_parse = "NO"

try:
    data = json.loads(raw)
    json_parse = "YES"
except Exception:
    data = {"rawText": raw}

trace = data.get("trace") if isinstance(data, dict) else None
metrics = data.get("metrics") if isinstance(data, dict) else None

trace_len = len(trace) if isinstance(trace, list) else 0
has_metrics = isinstance(metrics, dict) and any(v is not None for v in metrics.values())

classification = "NO_DATA"
if code == "000":
    classification = "UNREACHABLE"
elif not code.startswith("2"):
    classification = "NON_2XX"
elif trace_len >= 256 and has_metrics:
    classification = "TRACE_CANDIDATE_STRONG"
elif trace_len >= 16:
    classification = "TRACE_CANDIDATE_WEAK"
elif has_metrics:
    classification = "METADATA_METRICS_ONLY"
elif json_parse == "YES":
    classification = "JSON_METADATA_ONLY"

with report.open("w", encoding="utf-8") as f:
    f.write("url\tstatus\tbytes\tjson_parse\ttrace_len\thas_metrics\tclassification\n")
    f.write(f"http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=1\t{code}\t{bytes_count}\t{json_parse}\t{trace_len}\t{'YES' if has_metrics else 'NO'}\t{classification}\n")
PY

column -t -s $'\t' "$TRACE_REPORT"

TRACE_CLASS="$(awk 'NR==2 {print $7}' "$TRACE_REPORT")"
PATCH_FRONTEND="false"

if [ "$TRACE_CLASS" = "TRACE_CANDIDATE_STRONG" ]; then
  PATCH_FRONTEND="true"

  echo
  echo "=== 5) PATCH FRONTEND VERSO ENDPOINT NORMALIZZATO ==="

  python3 - "$PROMO" "$TRACE_URL" <<'PY'
from pathlib import Path
import re
import sys

promo = Path(sys.argv[1])
trace_url = sys.argv[2]

text = promo.read_text(encoding="utf-8", errors="replace")
before = text

replacement = (
    "const rfSweep = useRFSpectrumSweep({ "
    "enabled: true, "
    "intervalMs: 2200, "
    f"endpoint: '{trace_url}' "
    "})"
)

text = re.sub(
    r"const rfSweep = useRFSpectrumSweep\([^)]*\)",
    replacement,
    text,
    count=1,
)

promo.write_text(text, encoding="utf-8")
print("FRONTEND_PROMO_NORMALIZED_TRACE_PATCHED=", before != text)
PY

  echo
  echo "=== 6) BUILD FRONTEND ==="

  BUILD_RESULT="PASS"
  (
    cd frontend
    npm run build
  ) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

  tail -n 80 "$BUILDLOG" || true

else
  BUILD_RESULT="SKIPPED_NEEDS_BACKEND_RESTART"
  echo
  echo "Endpoint normalizzato non ancora live: probabile backend da riavviare."
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
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=2"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 8) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"
API_LIVE_COUNT=0
BINS_ZERO_COUNT=0
RF_LAYER_MARKER_COUNT=0

if [ "$PATCH_FRONTEND" = "true" ] && [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --dump-dom \
      "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

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
      --dump-dom \
      "http://127.0.0.1:5173/#full-engineering-stack" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=8000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
  fi

  RF_LAYER_MARKER_COUNT="$(awk 'index($0, "data-trfmc-rf-engineering-layer-v1=\"mounted\"") {c++} END {print c+0}' "$DOM" 2>/dev/null || echo 0)"
  API_LIVE_COUNT="$(awk 'index($0, "API LIVE") {c++} END {print c+0}' "$DOM" 2>/dev/null || echo 0)"
  BINS_ZERO_COUNT="$(awk 'index($0, "0 · preview 0") {c++} END {print c+0}' "$DOM" 2>/dev/null || echo 0)"
else
  echo "DOM gate skipped: frontend not patched yet or build not PASS." > "$DOM"
fi

echo "DOM_RESULT=$DOM_RESULT"
echo "RF_LAYER_MARKER_COUNT=$RF_LAYER_MARKER_COUNT"
echo "API_LIVE_COUNT=$API_LIVE_COUNT"
echo "BINS_ZERO_COUNT=$BINS_ZERO_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

echo
echo "=== 9) DIFF ==="
git diff -- "$ROUTER" "$APPFILE" "$PROMO" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

RESULT="PASS"
if [ "$TRACE_CLASS" != "TRACE_CANDIDATE_STRONG" ]; then RESULT="SOURCE_READY_RESTART_BACKEND"; fi
if [ "$PATCH_FRONTEND" = "true" ] && [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$PATCH_FRONTEND" = "true" ] && [ "$DOM_RESULT" = "PASS" ] && [ "$API_LIVE_COUNT" = "0" ]; then RESULT="REVIEW_DOM_API_LIVE"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2F_RF_NORMALIZED_TRACE_ENDPOINT_V1",
  "mutation": "backend_router_source_plus_conditional_frontend_bind",
  "backend_mutation": true,
  "backend_router": "$ROUTER",
  "backend_app_file": "$APPFILE",
  "frontend_patch_applied": $PATCH_FRONTEND,
  "index_mutation": false,
  "public_asset_mutation": false,
  "app_scan": "$APP_SCAN",
  "patch_log": "$PATCH_LOG",
  "trace_probe_raw": "$TRACE_RAW",
  "trace_probe_report": "$TRACE_REPORT",
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "trace_classification": "$TRACE_CLASS",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "dom_result": "$DOM_RESULT",
  "rf_layer_marker_count": $RF_LAYER_MARKER_COUNT,
  "api_live_count": $API_LIVE_COUNT,
  "bins_zero_count": $BINS_ZERO_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2f_rf_normalized_trace_endpoint_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH2F_RF_NORMALIZED_TRACE_ENDPOINT_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
