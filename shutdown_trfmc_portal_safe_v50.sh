#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
OP="TRFMC_SAFE_SHUTDOWN_V50"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
QDIR="$ROOT/runtime/quality/${OP}_${TS}"

mkdir -p "$RDIR" "$QDIR" runtime/logs runtime/freezes

SUMMARY="$QDIR/summary.json"
PORTS_BEFORE="$RDIR/ports_before.txt"
PORTS_AFTER_TERM="$RDIR/ports_after_term.txt"
PORTS_AFTER_FINAL="$RDIR/ports_after_final.txt"
HTTP_BEFORE="$RDIR/http_before.tsv"
HTTP_AFTER="$RDIR/http_after.tsv"
PROC_BEFORE="$RDIR/processes_before.txt"
PROC_AFTER="$RDIR/processes_after.txt"
STOP_LOG="$RDIR/shutdown_actions.log"

echo "============================================================"
echo "$OP"
echo "Safe shutdown · Vite 5173 · backend 8000 · nginx bridge 4181"
echo "============================================================"

echo
echo "=== SNAPSHOT BEFORE ==="

{
  echo "timestamp=$TS"
  echo "pwd=$PWD"
  echo
  echo "=== ss ports ==="
  ss -ltnp | grep -E ':5173|:4181|:8000|:8080|:8090' || true
  echo
  echo "=== processes ==="
  ps -eo pid,ppid,stat,comm,args | grep -E 'vite|node|uvicorn|FastAPI|python|nginx|open5gs|nr-gnb|nr-ue' | grep -v grep || true
} | tee "$PROC_BEFORE"

ss -ltnp | grep -E ':5173|:4181|:8000|:8080|:8090' > "$PORTS_BEFORE" || true

printf "url\tstatus\tbytes\n" > "$HTTP_BEFORE"
for url in \
  "http://127.0.0.1:5173/" \
  "http://127.0.0.1:4181/api/health" \
  "http://127.0.0.1:4181/api/mission/status" \
  "http://127.0.0.1:8000/api/health"
do
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 5 "$url" 2>/dev/null || printf "000\t0")"
  printf "%s\t%s\n" "$url" "$meta" >> "$HTTP_BEFORE"
done

column -t -s $'\t' "$HTTP_BEFORE" || cat "$HTTP_BEFORE"

echo
echo "=== SAFE STOP FUNCTIONS ==="

log() {
  echo "[$(date -Is)] $*" | tee -a "$STOP_LOG"
}

pids_on_port() {
  local port="$1"
  ss -ltnp 2>/dev/null \
    | awk -v p=":${port}" '$0 ~ p {print $0}' \
    | grep -oE 'pid=[0-9]+' \
    | cut -d= -f2 \
    | sort -u
}

terminate_port() {
  local port="$1"
  local label="$2"
  local graceful_signal="${3:-TERM}"
  local pids

  pids="$(pids_on_port "$port" || true)"

  if [ -z "$pids" ]; then
    log "OK: no listener on port $port ($label)"
    return 0
  fi

  log "Stopping $label on port $port with SIG$graceful_signal: $pids"

  for pid in $pids; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "-$graceful_signal" "$pid" 2>/dev/null || true
    fi
  done

  sleep 3

  pids="$(pids_on_port "$port" || true)"
  if [ -n "$pids" ]; then
    log "WARN: $label still listening on port $port after SIG$graceful_signal: $pids"
    log "Fallback SIGTERM on remaining $label pids"
    for pid in $pids; do
      kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 2
  fi

  pids="$(pids_on_port "$port" || true)"
  if [ -n "$pids" ]; then
    log "WARN: $label still listening on port $port after SIGTERM: $pids"
    log "Fallback SIGKILL on remaining $label pids"
    for pid in $pids; do
      kill -KILL "$pid" 2>/dev/null || true
    done
    sleep 1
  fi

  pids="$(pids_on_port "$port" || true)"
  if [ -z "$pids" ]; then
    log "OK: port $port stopped ($label)"
  else
    log "MISS: port $port still active ($label): $pids"
  fi
}

echo
echo "=== STOP FRONTEND VITE / NODE 5173 ==="
terminate_port 5173 "Vite frontend" TERM

echo
echo "=== STOP BACKEND FASTAPI / PYTHON 8000 ==="
terminate_port 8000 "FastAPI backend" TERM

echo
echo "=== STOP NGINX BRIDGE 4181 ==="
# NGINX supports QUIT as graceful shutdown; if it does not close, fallback logic handles TERM/KILL.
terminate_port 4181 "nginx bridge" QUIT

echo
echo "=== OPTIONAL: STOP 5G LAB USER SERVICES IF PRESENT ==="

for svc in 5g-lab.service 5g-portal-frontend.service 5g-portal-backend.service; do
  if systemctl --user list-units --type=service --all 2>/dev/null | grep -q "$svc"; then
    log "systemctl --user stop $svc"
    systemctl --user stop "$svc" 2>>"$STOP_LOG" || true
  fi
done

echo
echo "=== OPTIONAL: STOP OPEN5GS/UERANSIM LAB SCRIPTS IF PRESENT ==="

if [ -x "$ROOT/bin/5g-stop.sh" ]; then
  log "Running bin/5g-stop.sh"
  "$ROOT/bin/5g-stop.sh" >>"$STOP_LOG" 2>&1 || true
else
  log "No executable bin/5g-stop.sh found; skipping"
fi

echo
echo "=== FINAL PORT CHECK ==="

ss -ltnp | grep -E ':5173|:4181|:8000|:8080|:8090' > "$PORTS_AFTER_TERM" || true
cat "$PORTS_AFTER_TERM" || true

sleep 2

ss -ltnp | grep -E ':5173|:4181|:8000|:8080|:8090' > "$PORTS_AFTER_FINAL" || true

printf "url\tstatus\tbytes\n" > "$HTTP_AFTER"
for url in \
  "http://127.0.0.1:5173/" \
  "http://127.0.0.1:4181/api/health" \
  "http://127.0.0.1:4181/api/mission/status" \
  "http://127.0.0.1:8000/api/health"
do
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 5 "$url" 2>/dev/null || printf "000\t0")"
  printf "%s\t%s\n" "$url" "$meta" >> "$HTTP_AFTER"
done

{
  echo "=== ports after final ==="
  cat "$PORTS_AFTER_FINAL" || true
  echo
  echo "=== HTTP after ==="
  column -t -s $'\t' "$HTTP_AFTER" || cat "$HTTP_AFTER"
  echo
  echo "=== remaining processes ==="
  ps -eo pid,ppid,stat,comm,args | grep -E 'vite|node|uvicorn|FastAPI|python|nginx|open5gs|nr-gnb|nr-ue' | grep -v grep || true
} | tee "$PROC_AFTER"

ACTIVE_PORT_COUNT="$(wc -l < "$PORTS_AFTER_FINAL" | tr -d ' ')"
HTTP_ALIVE_COUNT="$(awk -F '\t' 'NR>1 && $2!="000"{c++} END{print c+0}' "$HTTP_AFTER")"

RESULT="PASS"
if [ "$ACTIVE_PORT_COUNT" -ne 0 ] || [ "$HTTP_ALIVE_COUNT" -ne 0 ]; then
  RESULT="WARN"
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "release_dir": "$RDIR",
  "ports_before": "$PORTS_BEFORE",
  "ports_after_term": "$PORTS_AFTER_TERM",
  "ports_after_final": "$PORTS_AFTER_FINAL",
  "http_before": "$HTTP_BEFORE",
  "http_after": "$HTTP_AFTER",
  "processes_before": "$PROC_BEFORE",
  "processes_after": "$PROC_AFTER",
  "shutdown_log": "$STOP_LOG",
  "active_port_count_after": $ACTIVE_PORT_COUNT,
  "http_alive_count_after": $HTTP_ALIVE_COUNT,
  "target_ports": [5173, 4181, 8000, 8080, 8090],
  "result": "$RESULT"
}
JSON

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_safe_shutdown_v50"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_safe_shutdown_v50"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "$OP COMPLETATO: $RESULT"
echo "============================================================"
