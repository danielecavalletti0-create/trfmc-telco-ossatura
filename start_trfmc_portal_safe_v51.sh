#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
OP="TRFMC_SAFE_START_AND_AUDIT_V51"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
QDIR="$ROOT/runtime/quality/${OP}_${TS}"

mkdir -p "$RDIR" "$QDIR" runtime/logs runtime/freezes

SUMMARY="$QDIR/summary.json"
START_LOG="$RDIR/start_actions.log"
PORTS_BEFORE="$RDIR/ports_before_start.txt"
PORTS_AFTER="$RDIR/ports_after_start.txt"
HTTP_TSV="$RDIR/http_after_start.tsv"
BUILD_LOG="$RDIR/npm_build_v51.log"
BACKEND_LOG="$ROOT/runtime/logs/backend_8000_v51_${TS}.log"
NGINX_LOG="$ROOT/runtime/logs/nginx_4181_v51_${TS}.log"
FRONTEND_LOG="$ROOT/runtime/logs/frontend_vite_5173_v51_${TS}.log"

echo "============================================================"
echo "$OP"
echo "Safe restart · backend 8000 · nginx bridge 4181 · Vite 5173"
echo "============================================================"

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

wait_http() {
  local url="$1"
  local label="$2"
  local max="${3:-25}"
  local i code

  for i in $(seq 1 "$max"); do
    code="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 1 --max-time 3 "$url" 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
      log "OK: $label HTTP 200 at $url"
      return 0
    fi
    sleep 1
  done

  log "WARN: $label did not return HTTP 200 at $url"
  return 1
}

echo
echo "=== PREFLIGHT: TARGET PORTS BEFORE ==="

ss -ltnp | grep -E ':5173|:4181|:8000|:8080|:8090' > "$PORTS_BEFORE" || true
cat "$PORTS_BEFORE" || true

for port in 5173 4181 8000; do
  if [ -n "$(pids_on_port "$port" || true)" ]; then
    log "ERRORE: porta $port già occupata. Non procedo per evitare conflitti."
    cat "$PORTS_BEFORE"
    exit 1
  fi
done

echo
echo "=== BUILD FRONTEND ==="

if [ ! -d "$ROOT/frontend" ]; then
  log "ERRORE: directory frontend mancante"
  exit 1
fi

pushd "$ROOT/frontend" >/dev/null
npm run build > "$BUILD_LOG" 2>&1
popd >/dev/null

log "OK: npm run build completato"

echo
echo "=== START BACKEND 8000 ==="

BACKEND_STARTED="false"
BACKEND_MODE="none"

# 1) Prefer systemd user service if present.
if systemctl --user list-unit-files 2>/dev/null | grep -q '^5g-portal-backend.service'; then
  log "Starting backend via systemctl --user start 5g-portal-backend.service"
  systemctl --user start 5g-portal-backend.service >>"$START_LOG" 2>&1 || true
  BACKEND_STARTED="true"
  BACKEND_MODE="systemd-user:5g-portal-backend.service"
fi

# 2) Fallback: autodetect FastAPI app and start uvicorn.
if [ -z "$(pids_on_port 8000 || true)" ]; then
  log "No listener on 8000 after systemd attempt; trying uvicorn autodetect"

  APP_TARGET=""
  for candidate in \
    "backend.main_engine:app" \
    "backend.main:app" \
    "backend.app:app" \
    "main_engine:app" \
    "main:app"
  do
    mod="${candidate%%:*}"
    if PYTHONPATH="$ROOT:$ROOT/backend" python3 - <<PY >/dev/null 2>&1
import importlib
m=importlib.import_module("$mod")
assert hasattr(m, "app")
PY
    then
      APP_TARGET="$candidate"
      break
    fi
  done

  if [ -n "$APP_TARGET" ]; then
    log "Starting backend with uvicorn $APP_TARGET on 127.0.0.1:8000"
    nohup env PYTHONPATH="$ROOT:$ROOT/backend" python3 -m uvicorn "$APP_TARGET" \
      --host 127.0.0.1 --port 8000 \
      > "$BACKEND_LOG" 2>&1 &
    echo "$!" > "$RDIR/backend_8000.pid"
    BACKEND_STARTED="true"
    BACKEND_MODE="uvicorn:$APP_TARGET"
  else
    log "WARN: no FastAPI app autodetected. Backend 8000 may remain offline."
  fi
fi

sleep 4

echo
echo "=== START NGINX BRIDGE 4181 ==="

NGINX_STARTED="false"
NGINX_CONF=""
NGINX_PREFIX=""

if [ -z "$(pids_on_port 4181 || true)" ]; then
  # Cerca una conf nginx che ascolti 4181.
  NGINX_CONF="$(grep -RIl "4181" "$ROOT/runtime/nginx" "$ROOT" 2>/dev/null | grep 'nginx.conf$' | head -n 1 || true)"

  if [ -n "$NGINX_CONF" ]; then
    NGINX_PREFIX="$(dirname "$(dirname "$NGINX_CONF")")"
    log "Starting nginx 4181 with prefix=$NGINX_PREFIX conf=$NGINX_CONF"
    nohup nginx -p "$NGINX_PREFIX" -c "$NGINX_CONF" -g 'daemon off;' \
      > "$NGINX_LOG" 2>&1 &
    echo "$!" > "$RDIR/nginx_4181.pid"
    NGINX_STARTED="true"
  else
    log "WARN: nginx.conf for 4181 not found. Bridge 4181 may remain offline."
  fi
else
  log "OK: port 4181 already listening"
  NGINX_STARTED="true"
fi

sleep 3

echo
echo "=== START FRONTEND VITE 5173 ==="

FRONTEND_STARTED="false"

if [ -z "$(pids_on_port 5173 || true)" ]; then
  log "Starting Vite frontend on 127.0.0.1:5173 strictPort"
  pushd "$ROOT/frontend" >/dev/null
  nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort \
    > "$FRONTEND_LOG" 2>&1 &
  echo "$!" > "$RDIR/frontend_vite_5173.pid"
  popd >/dev/null
  FRONTEND_STARTED="true"
else
  log "OK: port 5173 already listening"
  FRONTEND_STARTED="true"
fi

sleep 6

echo
echo "=== PORTS AFTER START ==="

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
  "http://127.0.0.1:5173/#full-engineering-stack" \
  "http://127.0.0.1:5173/#visual-assets" \
  "http://127.0.0.1:4181/api/health" \
  "http://127.0.0.1:4181/api/mission/status" \
  "http://127.0.0.1:4181/api/rfpro/spectrum/sweep" \
  "http://127.0.0.1:8000/api/health"
do
  probe "$url"
done

column -t -s $'\t' "$HTTP_TSV" || cat "$HTTP_TSV"

HTTP_5173="$(awk -F '\t' '$1=="http://127.0.0.1:5173/"{print $2}' "$HTTP_TSV")"
HTTP_4181_HEALTH="$(awk -F '\t' '$1=="http://127.0.0.1:4181/api/health"{print $2}' "$HTTP_TSV")"
HTTP_8000_HEALTH="$(awk -F '\t' '$1=="http://127.0.0.1:8000/api/health"{print $2}' "$HTTP_TSV")"

PORT_5173_ACTIVE="false"
PORT_4181_ACTIVE="false"
PORT_8000_ACTIVE="false"

[ -n "$(pids_on_port 5173 || true)" ] && PORT_5173_ACTIVE="true"
[ -n "$(pids_on_port 4181 || true)" ] && PORT_4181_ACTIVE="true"
[ -n "$(pids_on_port 8000 || true)" ] && PORT_8000_ACTIVE="true"

RESULT="PASS"

if [ "$PORT_5173_ACTIVE" != "true" ]; then
  RESULT="FAIL"
fi

# 4181/8000 sono attesi per bridge+backend. Se uno manca, WARN/FAIL a seconda dell'uso.
if [ "$PORT_4181_ACTIVE" != "true" ] || [ "$PORT_8000_ACTIVE" != "true" ]; then
  RESULT="WARN"
fi

if [ "$HTTP_5173" != "200" ]; then
  RESULT="FAIL"
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "release_dir": "$RDIR",
  "build_log": "$BUILD_LOG",
  "start_log": "$START_LOG",
  "ports_before": "$PORTS_BEFORE",
  "ports_after": "$PORTS_AFTER",
  "http_tsv": "$HTTP_TSV",
  "backend_log": "$BACKEND_LOG",
  "nginx_log": "$NGINX_LOG",
  "frontend_log": "$FRONTEND_LOG",
  "backend_started": "$BACKEND_STARTED",
  "backend_mode": "$BACKEND_MODE",
  "nginx_started": "$NGINX_STARTED",
  "nginx_conf": "$NGINX_CONF",
  "nginx_prefix": "$NGINX_PREFIX",
  "frontend_started": "$FRONTEND_STARTED",
  "port_5173_active": "$PORT_5173_ACTIVE",
  "port_4181_active": "$PORT_4181_ACTIVE",
  "port_8000_active": "$PORT_8000_ACTIVE",
  "http_5173": "$HTTP_5173",
  "http_4181_health": "$HTTP_4181_HEALTH",
  "http_8000_health": "$HTTP_8000_HEALTH",
  "result": "$RESULT"
}
JSON

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_safe_start_and_audit_v51"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_safe_start_and_audit_v51"

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
