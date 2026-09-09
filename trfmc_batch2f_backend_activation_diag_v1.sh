#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2F_BACKEND_ACTIVATION_DIAG_V1_$TS"

mkdir -p "$OUT"
cd "$BASE"

echo "============================================================"
echo "TRFMC_BATCH2F_BACKEND_ACTIVATION_DIAG_V1"
echo "Read-only backend activation diagnostic"
echo "Timestamp: $TS"
echo "============================================================"

ROUTER="backend/routers/rf_normalized_trace_v1.py"
APPFILE="backend/main_v580.py"
ROUTE_URL="http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=7"

echo
echo "=== 1) SOURCE FILE CHECK ==="
{
  echo -e "path\texists\tbytes\tlines"
  for f in "$ROUTER" "$APPFILE"; do
    if [ -f "$f" ]; then
      echo -e "$f\tYES\t$(stat -c%s "$f")\t$(wc -l < "$f" | tr -d ' ')"
    else
      echo -e "$f\tNO\t0\t0"
    fi
  done
} | tee "$OUT/source_file_check.tsv" | column -t -s $'\t'

echo
echo "=== 2) ROUTER INCLUDE MARKER CHECK ==="
grep -n "TRFMC BATCH2F RF NORMALIZED TRACE ROUTER START\|rf_normalized_trace_v1\|include_router" "$APPFILE" \
  | tee "$OUT/include_marker_check.txt" || true

echo
echo "=== 3) PY COMPILE CHECK ==="
PYCOMPILE_RESULT="PASS"
python3 -m py_compile "$ROUTER" "$APPFILE" > "$OUT/py_compile.log" 2>&1 || PYCOMPILE_RESULT="FAIL"
echo "PYCOMPILE_RESULT=$PYCOMPILE_RESULT"
cat "$OUT/py_compile.log" || true

echo
echo "=== 4) PORT 8000 PROCESS ==="
ss -ltnp | grep ':8000' | tee "$OUT/port_8000_process.txt" || true

PID="$(ss -ltnp 2>/dev/null | awk '/:8000/ && /pid=/ {split($0,a,"pid="); split(a[2],b,","); print b[1]; exit}' || true)"

echo
echo "PID_8000=${PID:-NONE}" | tee "$OUT/pid_8000.txt"

if [ -n "${PID:-}" ] && [ -d "/proc/$PID" ]; then
  echo
  echo "=== 5) PROC CMDLINE / CWD ==="
  {
    echo "PID=$PID"
    echo -n "CMDLINE="
    tr '\0' ' ' < "/proc/$PID/cmdline"
    echo
    echo -n "CWD="
    readlink -f "/proc/$PID/cwd" || true
  } | tee "$OUT/proc_backend_runtime.txt"
else
  echo "No PID found on port 8000" | tee "$OUT/proc_backend_runtime.txt"
fi

echo
echo "=== 6) USER SYSTEMD SERVICES POSSIBILI ==="
systemctl --user --type=service --state=running 2>/dev/null \
  | grep -Ei 'trfmc|5g|portal|backend|uvicorn|fastapi' \
  | tee "$OUT/user_services_backend_candidates.txt" || true

echo
echo "=== 7) OPENAPI ROUTE CHECK ==="
curl -sS -L --max-time 8 "http://127.0.0.1:8000/openapi.json" -o "$OUT/openapi_8000.json" || true

python3 - "$OUT/openapi_8000.json" "$OUT/openapi_route_check.tsv" <<'PY'
import json, sys
from pathlib import Path

openapi = Path(sys.argv[1])
out = Path(sys.argv[2])

rows = []
if openapi.exists() and openapi.stat().st_size:
    try:
        data = json.loads(openapi.read_text(encoding="utf-8", errors="replace"))
        for route, methods in sorted(data.get("paths", {}).items()):
            if "normalized" in route or "rfpro" in route or "spectrum" in route:
                rows.append((route, ",".join(sorted(methods.keys()))))
    except Exception as exc:
        rows.append(("OPENAPI_PARSE_ERROR", str(exc)))

out.write_text("route\tmethods\n" + "\n".join("\t".join(r) for r in rows) + "\n", encoding="utf-8")
PY

column -t -s $'\t' "$OUT/openapi_route_check.tsv"

echo
echo "=== 8) NORMALIZED TRACE LIVE CHECK ==="
TRACE_CODE="$(curl -sS -L --max-time 8 -o "$OUT/normalized_trace_live.raw.json" -w "%{http_code}" "$ROUTE_URL" || echo "000")"
TRACE_BYTES="$(wc -c < "$OUT/normalized_trace_live.raw.json" | tr -d ' ')"

python3 - "$OUT/normalized_trace_live.raw.json" "$OUT/normalized_trace_live_report.tsv" "$TRACE_CODE" "$TRACE_BYTES" <<'PY'
import json, sys
from pathlib import Path

raw = Path(sys.argv[1])
report = Path(sys.argv[2])
code = sys.argv[3]
bytes_count = sys.argv[4]

text = raw.read_text(encoding="utf-8", errors="replace")
try:
    data = json.loads(text)
    parse = "YES"
except Exception:
    data = {}
    parse = "NO"

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
elif parse == "YES":
    classification = "JSON_METADATA_ONLY"

report.write_text(
    "url\tstatus\tbytes\tjson_parse\ttrace_len\thas_metrics\tclassification\n"
    f"http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=7\t{code}\t{bytes_count}\t{parse}\t{trace_len}\t{'YES' if has_metrics else 'NO'}\t{classification}\n",
    encoding="utf-8"
)
PY

column -t -s $'\t' "$OUT/normalized_trace_live_report.tsv"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2F_BACKEND_ACTIVATION_DIAG_V1",
  "mutation": false,
  "out": "$OUT",
  "pycompile_result": "$PYCOMPILE_RESULT",
  "pid_8000": "${PID:-NONE}",
  "route_url": "$ROUTE_URL",
  "result": "DIAG_READY"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2f_backend_activation_diag_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$OUT/summary.json"

echo
echo "============================================================"
echo "TRFMC_BATCH2F_BACKEND_ACTIVATION_DIAG_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
