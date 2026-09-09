#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2F_BACKEND_RUNTIME_MAP_V2_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
PROC="$OUT/proc_runtime.tsv"
OPENAPI="$OUT/openapi_8000.json"
OPENAPI_ROUTES="$OUT/openapi_route_check.tsv"
SOURCE_ROUTES="$OUT/source_route_check.tsv"
RESTART_SCRIPT="$OUT/RESTART_BACKEND_PID_8000_CONTROLLED.sh"
TRACE_REPORT="$OUT/live_trace_report.tsv"

echo "============================================================"
echo "TRFMC_BATCH2F_BACKEND_RUNTIME_MAP_V2"
echo "Runtime map · PID/cmdline/cwd · no mutation · no restart"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) RISOLVO PID SU PORTA 8000 ==="

PID="$(ss -ltnp 2>/dev/null | awk '/:8000/ && /pid=/ {split($0,a,"pid="); split(a[2],b,","); print b[1]; exit}' || true)"

if [ -z "${PID:-}" ]; then
  echo "ERRORE: nessun processo in ascolto su :8000"
  exit 1
fi

echo "PID_8000=$PID"

CMDLINE="$(tr '\0' ' ' < "/proc/$PID/cmdline" | sed 's/[[:space:]]*$//')"
CWD="$(readlink -f "/proc/$PID/cwd" || true)"
EXE="$(readlink -f "/proc/$PID/exe" || true)"
PPID="$(awk '/^PPid:/ {print $2}' "/proc/$PID/status" || true)"
PARENT_CMDLINE=""
if [ -n "${PPID:-}" ] && [ -r "/proc/$PPID/cmdline" ]; then
  PARENT_CMDLINE="$(tr '\0' ' ' < "/proc/$PPID/cmdline" | sed 's/[[:space:]]*$//')"
fi

{
  echo -e "field\tvalue"
  echo -e "pid\t$PID"
  echo -e "ppid\t${PPID:-UNKNOWN}"
  echo -e "exe\t${EXE:-UNKNOWN}"
  echo -e "cwd\t${CWD:-UNKNOWN}"
  echo -e "cmdline\t${CMDLINE:-UNKNOWN}"
  echo -e "parent_cmdline\t${PARENT_CMDLINE:-UNKNOWN}"
} | tee "$PROC" | column -t -s $'\t'

echo
echo "=== 2) PROCESS TREE / PS ==="
ps -fp "$PID" | tee "$OUT/ps_pid_8000.txt" || true
echo
ps -fp "${PPID:-0}" | tee "$OUT/ps_parent_pid.txt" || true

echo
echo "=== 3) SOURCE ROUTE CHECK ==="

{
  echo -e "path\tcheck\tresult\tline"
  if [ -f backend/routers/rf_normalized_trace_v1.py ]; then
    grep -n 'prefix="/api/rfpro/normalized"\|@router.get("/spectrum/trace")\|def normalized_spectrum_trace' \
      backend/routers/rf_normalized_trace_v1.py \
      | awk -F: 'BEGIN{OFS="\t"} {print "backend/routers/rf_normalized_trace_v1.py","router_source","PASS",$1 ":" substr($0,index($0,$3))}' \
      || true
  else
    echo -e "backend/routers/rf_normalized_trace_v1.py\trouter_source\tFAIL\tmissing"
  fi

  if [ -f backend/main_v580.py ]; then
    grep -n 'TRFMC BATCH2F RF NORMALIZED TRACE ROUTER START\|rf_normalized_trace_v1\|include_router' \
      backend/main_v580.py \
      | awk -F: 'BEGIN{OFS="\t"} {print "backend/main_v580.py","include_marker","PASS",$1 ":" substr($0,index($0,$3))}' \
      || true
  else
    echo -e "backend/main_v580.py\tinclude_marker\tFAIL\tmissing"
  fi
} | tee "$SOURCE_ROUTES" | column -t -s $'\t'

echo
echo "=== 4) OPENAPI LIVE CHECK ==="

curl -sS -L --max-time 8 "http://127.0.0.1:8000/openapi.json" -o "$OPENAPI" || true

python3 - "$OPENAPI" "$OPENAPI_ROUTES" <<'PY'
import json
import sys
from pathlib import Path

openapi = Path(sys.argv[1])
out = Path(sys.argv[2])

rows = []
normalized_present = 0

if openapi.exists() and openapi.stat().st_size:
    try:
        data = json.loads(openapi.read_text(encoding="utf-8", errors="replace"))
        for route, methods in sorted(data.get("paths", {}).items()):
            if "rfpro" in route or "spectrum" in route or "normalized" in route:
                m = ",".join(sorted(methods.keys()))
                rows.append((route, m))
                if "/api/rfpro/normalized/spectrum/trace" in route:
                    normalized_present += 1
    except Exception as exc:
        rows.append(("OPENAPI_PARSE_ERROR", str(exc)))

out.write_text(
    "route\tmethods\n" + "\n".join("\t".join(r) for r in rows) + "\n",
    encoding="utf-8",
)

print(f"NORMALIZED_ROUTE_PRESENT={normalized_present}")
PY

column -t -s $'\t' "$OPENAPI_ROUTES" | sed -n '1,180p'

echo
echo "=== 5) LIVE TRACE CHECK ==="

TRACE_URL="http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=11"
TRACE_RAW="$OUT/live_trace.raw.json"
TRACE_CODE="$(curl -sS -L --max-time 8 -o "$TRACE_RAW" -w "%{http_code}" "$TRACE_URL" || echo "000")"
TRACE_BYTES="$(wc -c < "$TRACE_RAW" | tr -d ' ')"

python3 - "$TRACE_RAW" "$TRACE_REPORT" "$TRACE_CODE" "$TRACE_BYTES" "$TRACE_URL" <<'PY'
import json
import sys
from pathlib import Path

raw = Path(sys.argv[1])
report = Path(sys.argv[2])
code = sys.argv[3]
bytes_count = sys.argv[4]
url = sys.argv[5]

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
    f"{url}\t{code}\t{bytes_count}\t{parse}\t{trace_len}\t{'YES' if has_metrics else 'NO'}\t{classification}\n",
    encoding="utf-8",
)
PY

column -t -s $'\t' "$TRACE_REPORT"

echo
echo "=== 6) GENERO SCRIPT DI RESTART CONTROLLATO, NON ESEGUITO ==="

python3 - "$PID" "$CWD" "$RESTART_SCRIPT" "$OUT" <<'PY'
import shlex
import sys
from pathlib import Path

pid = sys.argv[1]
cwd = sys.argv[2]
restart = Path(sys.argv[3])
out = Path(sys.argv[4])

cmdline_path = Path(f"/proc/{pid}/cmdline")
args = cmdline_path.read_bytes().split(b"\0")
args = [a.decode(errors="replace") for a in args if a]

if not args:
    restart.write_text("#!/usr/bin/env bash\necho 'ERRORE: cmdline vuota'\nexit 1\n", encoding="utf-8")
else:
    cmd = shlex.join(args)
    log = out / "backend_restart_controlled.log"

    restart.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail

PID="{pid}"
CWD="{cwd}"
LOG="{log}"

echo "============================================================"
echo "CONTROLLED BACKEND RESTART"
echo "PID=$PID"
echo "CWD=$CWD"
echo "LOG=$LOG"
echo "============================================================"

if [ ! -d "/proc/$PID" ]; then
  echo "PID non più attivo: salto TERM"
else
  echo "Invio SIGTERM a PID $PID"
  kill -TERM "$PID" || true
fi

for i in {{1..30}}; do
  if ss -ltnp 2>/dev/null | grep -q ':8000'; then
    sleep 1
  else
    break
  fi
done

if ss -ltnp 2>/dev/null | grep -q ':8000'; then
  echo "ERRORE: porta 8000 ancora occupata dopo SIGTERM"
  ss -ltnp | grep ':8000' || true
  exit 1
fi

cd "$CWD"

echo "Riavvio comando originale:"
echo {shlex.quote(cmd)}

nohup {cmd} > "$LOG" 2>&1 &

sleep 4

echo
echo "=== PORT 8000 ==="
ss -ltnp | grep ':8000' || true

echo
echo "=== NORMALIZED TRACE CHECK ==="
curl -sS -L --max-time 8 "http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=21" | python3 -m json.tool | sed -n '1,80p'

echo
echo "Restart controllato completato"
""", encoding="utf-8")

restart.chmod(0o755)
PY

echo "Script generato:"
echo "$RESTART_SCRIPT"

RUNTIME_USES_MAIN_V580="NO"
if echo "$CMDLINE" | grep -q "main_v580"; then
  RUNTIME_USES_MAIN_V580="YES"
fi

OPENAPI_NORMALIZED_PRESENT="$(grep -c '/api/rfpro/normalized/spectrum/trace' "$OPENAPI_ROUTES" || true)"
TRACE_CLASS="$(awk 'NR==2 {print $7}' "$TRACE_REPORT")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2F_BACKEND_RUNTIME_MAP_V2",
  "mutation": false,
  "pid": "$PID",
  "cwd": "$CWD",
  "cmdline": "$CMDLINE",
  "runtime_uses_main_v580": "$RUNTIME_USES_MAIN_V580",
  "openapi_normalized_present": $OPENAPI_NORMALIZED_PRESENT,
  "trace_classification": "$TRACE_CLASS",
  "restart_script": "$RESTART_SCRIPT",
  "out": "$OUT",
  "result": "RUNTIME_MAP_READY"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2f_backend_runtime_map_v2"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH2F_BACKEND_RUNTIME_MAP_V2 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
