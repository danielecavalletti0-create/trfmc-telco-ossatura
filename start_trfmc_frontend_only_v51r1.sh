#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
OP="TRFMC_FRONTEND_ONLY_SAFE_START_V51R1"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
QDIR="$ROOT/runtime/quality/${OP}_${TS}"

mkdir -p "$RDIR" "$QDIR" runtime/logs runtime/freezes

SUMMARY="$QDIR/summary.json"
PORTS_BEFORE="$RDIR/ports_before.txt"
PORTS_AFTER="$RDIR/ports_after.txt"
HTTP_TSV="$RDIR/http.tsv"
BUILD_LOG="$RDIR/npm_build_v51r1.log"
FRONTEND_LOG="$ROOT/runtime/logs/frontend_vite_5173_v51r1_${TS}.log"
START_LOG="$RDIR/start_frontend_only_actions.log"

log() {
  echo "[$(date -Is)] $*" | tee -a "$START_LOG"
}

pids_on_port() {
  local port="$1"
  ss -ltnp 2>/dev/null \
    | awk -v p=":${port}" '$0 ~ p {print $0}' \
    | grep -oE 'pid=[0-9]+' \
    | cut -d= -f2 \
    | sort -u
}

echo "============================================================"
echo "$OP"
echo "Start only Vite frontend 5173 · preserve existing 4181/8000"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

ss -ltnp | grep -E ':5173|:4181|:8000|:8080|:8090' > "$PORTS_BEFORE" || true
cat "$PORTS_BEFORE" || true

PORT_8000_BEFORE="false"
PORT_4181_BEFORE="false"
PORT_5173_BEFORE="false"

[ -n "$(pids_on_port 8000 || true)" ] && PORT_8000_BEFORE="true"
[ -n "$(pids_on_port 4181 || true)" ] && PORT_4181_BEFORE="true"
[ -n "$(pids_on_port 5173 || true)" ] && PORT_5173_BEFORE="true"

log "port_8000_before=$PORT_8000_BEFORE"
log "port_4181_before=$PORT_4181_BEFORE"
log "port_5173_before=$PORT_5173_BEFORE"

echo
echo "=== BUILD FRONTEND ==="

pushd "$ROOT/frontend" >/dev/null
npm run build > "$BUILD_LOG" 2>&1
popd >/dev/null

log "OK: npm run build PASS"

echo
echo "=== START OR KEEP FRONTEND 5173 ==="

if [ -n "$(pids_on_port 5173 || true)" ]; then
  log "OK: 5173 already active; no new Vite instance started"
else
  log "Starting Vite frontend on 127.0.0.1:5173 strictPort"
  pushd "$ROOT/frontend" >/dev/null
  nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort \
    > "$FRONTEND_LOG" 2>&1 &
  echo "$!" > "$RDIR/frontend_vite_5173.pid"
  popd >/dev/null
fi

echo
echo "=== WAIT FRONTEND HTTP ==="

FRONTEND_HTTP="000"
for i in $(seq 1 30); do
  FRONTEND_HTTP="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 1 --max-time 3 http://127.0.0.1:5173/ 2>/dev/null || true)"
  if [ "$FRONTEND_HTTP" = "200" ]; then
    log "OK: frontend HTTP 200"
    break
  fi
  sleep 1
done

echo
echo "=== PORTS AFTER ==="

ss -ltnp | grep -E ':5173|:4181|:8000|:8080|:8090' > "$PORTS_AFTER" || true
cat "$PORTS_AFTER" || true

echo
echo "=== HTTP GATE ==="

printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local url="$1"
  local meta
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$url" 2>/dev/null || printf "000\t0")"
  printf "%s\t%s\n" "$url" "$meta" >> "$HTTP_TSV"
}

for url in \
  "http://127.0.0.1:5173/" \
  "http://127.0.0.1:5173/#mission-overview" \
  "http://127.0.0.1:5173/#visual-assets" \
  "http://127.0.0.1:5173/#full-engineering-stack" \
  "http://127.0.0.1:4181/api/health" \
  "http://127.0.0.1:4181/api/mission/status" \
  "http://127.0.0.1:4181/api/rfpro/spectrum/sweep" \
  "http://127.0.0.1:8000/api/health"
do
  probe "$url"
done

column -t -s $'\t' "$HTTP_TSV" || cat "$HTTP_TSV"

PORT_5173_AFTER="false"
PORT_4181_AFTER="false"
PORT_8000_AFTER="false"

[ -n "$(pids_on_port 5173 || true)" ] && PORT_5173_AFTER="true"
[ -n "$(pids_on_port 4181 || true)" ] && PORT_4181_AFTER="true"
[ -n "$(pids_on_port 8000 || true)" ] && PORT_8000_AFTER="true"

HTTP_5173="$(awk -F '\t' '$1=="http://127.0.0.1:5173/"{print $2}' "$HTTP_TSV")"
HTTP_4181="$(awk -F '\t' '$1=="http://127.0.0.1:4181/api/health"{print $2}' "$HTTP_TSV")"
HTTP_8000="$(awk -F '\t' '$1=="http://127.0.0.1:8000/api/health"{print $2}' "$HTTP_TSV")"

RESULT="PASS"
if [ "$PORT_5173_AFTER" != "true" ] || [ "$HTTP_5173" != "200" ]; then
  RESULT="FAIL"
elif [ "$PORT_4181_AFTER" != "true" ] || [ "$HTTP_4181" != "200" ]; then
  RESULT="WARN"
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "release_dir": "$RDIR",
  "build_log": "$BUILD_LOG",
  "frontend_log": "$FRONTEND_LOG",
  "start_log": "$START_LOG",
  "ports_before": "$PORTS_BEFORE",
  "ports_after": "$PORTS_AFTER",
  "http_tsv": "$HTTP_TSV",
  "port_8000_before": "$PORT_8000_BEFORE",
  "port_4181_before": "$PORT_4181_BEFORE",
  "port_5173_before": "$PORT_5173_BEFORE",
  "port_5173_after": "$PORT_5173_AFTER",
  "port_4181_after": "$PORT_4181_AFTER",
  "port_8000_after": "$PORT_8000_AFTER",
  "http_5173": "$HTTP_5173",
  "http_4181_health": "$HTTP_4181",
  "http_8000_health": "$HTTP_8000",
  "result": "$RESULT"
}
JSON

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_frontend_only_safe_start_v51r1"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_frontend_only_safe_start_v51r1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "$OP COMPLETATO: $RESULT"
echo "============================================================"

if [ "$RESULT" = "FAIL" ]; then
  exit 1
fi
