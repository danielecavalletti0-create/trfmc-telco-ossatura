#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_BATCH2G_PATCH_READONLY_BRIDGE_ENTRYPOINT_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

APP="backend/readonly_bridge_v28/app.py"
ROUTER="backend/routers/rf_normalized_trace_v1.py"

SUMMARY="$OUT/summary.json"
PATCHLOG="$OUT/patch_log.tsv"
COMPILELOG="$OUT/py_compile.log"
HTTP="$OUT/http_before_restart.tsv"
DIFF="$OUT/readonly_bridge_entrypoint_patch.diff"
RESTART="$OUT/RESTART_READONLY_BRIDGE_8000_CONTROLLED.sh"
RESTORE="$OUT/RESTORE_READONLY_BRIDGE_ENTRYPOINT_V1.sh"

echo "============================================================"
echo "TRFMC_BATCH2G_PATCH_READONLY_BRIDGE_ENTRYPOINT_V1"
echo "Patch real active backend entrypoint · no restart automatico"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$APP" ]; then
  echo "ERRORE: entrypoint reale non trovato: $APP"
  exit 1
fi

if [ ! -f "$ROUTER" ]; then
  echo "ERRORE: router normalizzato non trovato: $ROUTER"
  exit 1
fi

cp -a "$APP" "$BACKUP/app.py.before_$TS"
cp -a "$ROUTER" "$BACKUP/rf_normalized_trace_v1.py.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"
cp -a "$BACKUP/app.py.before_$TS" "$APP"
cp -a "$BACKUP/rf_normalized_trace_v1.py.before_$TS" "$ROUTER"
echo "RESTORE_READONLY_BRIDGE_ENTRYPOINT_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH ENTRYPOINT REALE ==="

python3 - "$APP" "$PATCHLOG" <<'PY'
from pathlib import Path
import re
import sys

app_path = Path(sys.argv[1])
patchlog = Path(sys.argv[2])

text = app_path.read_text(encoding="utf-8", errors="replace")
before = text

marker_start = "# === TRFMC BATCH2G RF NORMALIZED TRACE ROUTER START ==="
marker_end = "# === TRFMC BATCH2G RF NORMALIZED TRACE ROUTER END ==="

block = f"""
{marker_start}
try:
    from backend.routers import rf_normalized_trace_v1
except Exception:
    try:
        from routers import rf_normalized_trace_v1
    except Exception:
        rf_normalized_trace_v1 = None

try:
    if rf_normalized_trace_v1 is not None:
        app.include_router(rf_normalized_trace_v1.router)
except Exception as exc:
    print("TRFMC Batch2G normalized RF trace router include failed:", repr(exc))
{marker_end}
""".strip()

if marker_start in text and marker_end in text:
    text = re.sub(
        re.escape(marker_start) + r".*?" + re.escape(marker_end),
        block,
        text,
        flags=re.S,
    )
else:
    text = text.rstrip() + "\n\n" + block + "\n"

app_path.write_text(text, encoding="utf-8")

patchlog.write_text(
    "file\tchanged\tmarker\n"
    f"{app_path}\t{str(before != text).upper()}\t{marker_start}\n",
    encoding="utf-8",
)
PY

column -t -s $'\t' "$PATCHLOG"

echo
echo "=== 2) PY COMPILE ==="

PYCOMPILE_RESULT="PASS"
python3 -m py_compile "$APP" "$ROUTER" > "$COMPILELOG" 2>&1 || PYCOMPILE_RESULT="FAIL"

echo "PYCOMPILE_RESULT=$PYCOMPILE_RESULT"
cat "$COMPILELOG" || true

if [ "$PYCOMPILE_RESULT" != "PASS" ]; then
  echo "ERRORE: py_compile fallito. Eseguo restore."
  "$RESTORE"
  exit 1
fi

echo
echo "=== 3) HTTP BEFORE RESTART ==="

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

check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=31"

echo
echo "=== 4) GENERO RESTART CONTROLLATO PER PROCESSO REALE ==="

PID="$(ss -ltnp 2>/dev/null | sed -n 's/.*:8000.*pid=\([0-9]\+\).*/\1/p' | head -n 1 || true)"

if [ -z "${PID:-}" ]; then
  echo "ERRORE: nessun PID su :8000"
  exit 1
fi

CMDLINE="$(tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null | sed 's/[[:space:]]*$//' || true)"
CWD="$(readlink -f "/proc/$PID/cwd" 2>/dev/null || true)"

python3 - "$PID" "$CWD" "$RESTART" "$OUT" <<'PY'
import shlex
import sys
from pathlib import Path

pid = sys.argv[1]
cwd = sys.argv[2]
restart = Path(sys.argv[3])
out = Path(sys.argv[4])

args = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
args = [a.decode(errors="replace") for a in args if a]

cmd = shlex.join(args)
log = out / "readonly_bridge_restart_controlled.log"

restart.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail

PID="{pid}"
CWD="{cwd}"
LOG="{log}"

echo "============================================================"
echo "CONTROLLED RESTART READONLY BRIDGE BACKEND"
echo "PID=$PID"
echo "CWD=$CWD"
echo "LOG=$LOG"
echo "============================================================"

echo
echo "=== 1) PRE-STOP PORT 8000 ==="
ss -ltnp | grep ':8000' || true

if [ -d "/proc/$PID" ]; then
  echo
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

echo
echo "=== 2) RESTART COMANDO ORIGINALE ==="
echo {shlex.quote(cmd)}

nohup {cmd} > "$LOG" 2>&1 &

sleep 4

echo
echo "=== 3) POST-START PORT 8000 ==="
ss -ltnp | grep ':8000' || true

echo
echo "=== 4) HEALTH ==="
curl -sS -L --max-time 8 "http://127.0.0.1:8000/api/health" | python3 -m json.tool | sed -n '1,80p' || true

echo
echo "=== 5) NORMALIZED TRACE CHECK ==="
curl -sS -L --max-time 8 "http://127.0.0.1:8000/api/rfpro/normalized/spectrum/trace?points=1200&seq=41" | python3 -m json.tool | sed -n '1,120p' || true

echo
echo "Restart controllato completato"
""", encoding="utf-8")

restart.chmod(0o755)
PY

echo "Restart script:"
echo "$RESTART"

git diff -- "$APP" "$ROUTER" > "$DIFF" || true

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BATCH2G_PATCH_READONLY_BRIDGE_ENTRYPOINT_V1",
  "mutation": "backend_entrypoint_patch_only",
  "backend_entrypoint": "$APP",
  "router": "$ROUTER",
  "pycompile_result": "$PYCOMPILE_RESULT",
  "http_before_restart": "$HTTP",
  "restart_script": "$RESTART",
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "active_pid_before_restart": "$PID",
  "active_cmdline_before_restart": "$CMDLINE",
  "result": "ENTRYPOINT_PATCHED_RESTART_REQUIRED"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_batch2g_patch_readonly_bridge_entrypoint_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_BATCH2G_PATCH_READONLY_BRIDGE_ENTRYPOINT_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
