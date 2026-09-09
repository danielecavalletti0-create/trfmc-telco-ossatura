#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
FRONTEND="$ROOT/frontend"
DIST="$FRONTEND/dist"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_STATIC_PRODUCTION_SERVER_PACK_V20_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_STATIC_PRODUCTION_SERVER_PACK_V20_$TS"
NGINX_ROOT="$ROOT/runtime/nginx/trfmc_static_4180"
NGINX_CONF="$NGINX_ROOT/conf/nginx.conf"
FREEZE="$ROOT/runtime/freezes/TRFMC_STATIC_PRODUCTION_SERVER_PACK_V20_$TS.tar.gz"

echo "============================================================"
echo "TRFMC STATIC PRODUCTION SERVER PACK V20"
echo "NGINX user-mode · static dist server · localhost:4180"
echo "============================================================"

mkdir -p \
  "$QUALITY_DIR" \
  "$RELEASE_DIR" \
  "$ROOT/runtime/freezes" \
  "$ROOT/runtime/bin" \
  "$NGINX_ROOT/conf" \
  "$NGINX_ROOT/logs" \
  "$NGINX_ROOT/client_body_temp" \
  "$NGINX_ROOT/proxy_temp" \
  "$NGINX_ROOT/fastcgi_temp" \
  "$NGINX_ROOT/uwsgi_temp" \
  "$NGINX_ROOT/scgi_temp"

echo
echo "=== PREFLIGHT ==="

test -d "$FRONTEND" || { echo "ERRORE: frontend mancante"; exit 1; }
test -d "$DIST" || { echo "ERRORE: frontend/dist mancante"; exit 1; }
test -f "$DIST/index.html" || { echo "ERRORE: dist/index.html mancante"; exit 1; }
test -f "$FRONTEND/src/app/main.tsx" || { echo "ERRORE: main.tsx mancante"; exit 1; }

grep -q "RFOperationalDeckV16ChunkObservatory" "$FRONTEND/src/app/main.tsx" || {
  echo "ERRORE: main.tsx non monta RFOperationalDeckV16ChunkObservatory"
  exit 1
}

if ! command -v nginx >/dev/null 2>&1; then
  cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_STATIC_PRODUCTION_SERVER_PACK_V20",
  "result": "NEEDS_NGINX",
  "install_hint": "sudo apt update && sudo apt install -y nginx"
}
JSON
  ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_static_production_server_pack_v20"
  cat "$QUALITY_DIR/summary.json" | python3 -m json.tool
  exit 0
fi

echo "OK: dist presente, V16 montato, nginx disponibile"

echo
echo "=== CREA NGINX CONFIG USER-MODE ==="

cat > "$NGINX_CONF" <<NGINX
worker_processes  1;
pid $NGINX_ROOT/nginx.pid;
error_log $NGINX_ROOT/logs/error.log info;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log $NGINX_ROOT/logs/access.log;
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;

    gzip on;
    gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        text/xml
        application/xml
        image/svg+xml;

    server {
        listen 127.0.0.1:4180;
        server_name trfmc.local localhost 127.0.0.1;

        root $DIST;
        index index.html;

        location /assets/ {
            try_files \$uri =404;
            add_header Cache-Control "public, max-age=31536000, immutable";
        }

        location /api/ {
            try_files \$uri \$uri/ =404;
            add_header Cache-Control "no-cache";
        }

        location / {
            try_files \$uri \$uri/ /index.html;
            add_header Cache-Control "no-cache";
        }
    }
}
NGINX

nginx -t -p "$NGINX_ROOT" -c "$NGINX_CONF"

echo
echo "=== CREA CONTROL SCRIPT NGINX STATIC ==="

cat > "$ROOT/runtime/bin/trfmc_static_nginx_start_4180.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"
NGINX_ROOT="$NGINX_ROOT"
NGINX_CONF="$NGINX_CONF"

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:4180/ >/dev/null 2>&1; then
  echo "OK: TRFMC static NGINX already reachable at http://127.0.0.1:4180/"
  ss -ltnp | grep ':4180' || true
  exit 0
fi

nginx -p "\$NGINX_ROOT" -c "\$NGINX_CONF"

sleep 1

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:4180/ >/dev/null 2>&1; then
  echo "OK: TRFMC static NGINX started"
  echo "URL: http://127.0.0.1:4180/"
  ss -ltnp | grep ':4180' || true
else
  echo "ERRORE: TRFMC static NGINX not reachable"
  tail -n 80 "\$NGINX_ROOT/logs/error.log" || true
  exit 1
fi
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_static_nginx_stop_4180.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

NGINX_ROOT="$NGINX_ROOT"
NGINX_CONF="$NGINX_CONF"

if [ -f "\$NGINX_ROOT/nginx.pid" ]; then
  nginx -p "\$NGINX_ROOT" -c "\$NGINX_CONF" -s quit || true
  sleep 1
fi

if ss -ltnp | grep -q ':4180'; then
  PID="\$(ss -ltnp | awk '/:4180/ { if (match(\$0,/pid=[0-9]+/)) { print substr(\$0,RSTART+4,RLENGTH-4); exit } }')"
  [ -n "\$PID" ] && kill "\$PID" 2>/dev/null || true
fi

echo "OK: TRFMC static NGINX stop requested"
ss -ltnp | grep ':4180' || true
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_static_nginx_status_4180.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== PORT 4180 ==="
ss -ltnp | grep ':4180' || true

echo
echo "=== HTTP ==="
curl -I --connect-timeout 2 --max-time 6 http://127.0.0.1:4180/ || true
curl -I --connect-timeout 2 --max-time 6 http://127.0.0.1:4180/index.html || true
curl -I --connect-timeout 2 --max-time 6 http://127.0.0.1:4180/api/health || true

echo
echo "=== FIRST ASSETS ==="
find "$DIST/assets" -maxdepth 1 -type f \( -name '*.js' -o -name '*.css' \) | sort | sed -n '1,25p'

echo
echo "=== LOGS ==="
tail -n 20 "$NGINX_ROOT/logs/access.log" 2>/dev/null || true
tail -n 20 "$NGINX_ROOT/logs/error.log" 2>/dev/null || true
SCRIPT

chmod +x \
  "$ROOT/runtime/bin/trfmc_static_nginx_start_4180.sh" \
  "$ROOT/runtime/bin/trfmc_static_nginx_stop_4180.sh" \
  "$ROOT/runtime/bin/trfmc_static_nginx_status_4180.sh"

echo
echo "=== AVVIO STATIC NGINX 4180 ==="

"$ROOT/runtime/bin/trfmc_static_nginx_start_4180.sh"

echo
echo "=== HTTP GATE ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "http://127.0.0.1:4180$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

probe "/"
probe "/index.html"
probe "/api/health"
probe "/api/docs/index"
probe "/api/portal/index"

while IFS= read -r f; do
  probe "/${f#$DIST/}"
done < <(find "$DIST/assets" -maxdepth 1 -type f \( -name '*.js' -o -name '*.css' \) | sort | sed -n '1,80p')

column -t -s $'\t' "$HTTP_TSV" | sed -n '1,120p'

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$DIST/index.html" && echo "OK: dist/index.html" || echo "MISS: dist/index.html"

  find "$DIST/assets" -maxdepth 1 -type f -name 'index-*.js' | grep -q . \
    && echo "OK: main index JS chunk" || echo "MISS: main index JS chunk"

  find "$DIST/assets" -maxdepth 1 -type f -name 'index-*.css' | grep -q . \
    && echo "OK: main index CSS chunk" || echo "MISS: main index CSS chunk"

  find "$DIST/assets" -maxdepth 1 -type f -name 'RFInstrumentSuiteV5-*.js' | grep -q . \
    && echo "OK: lazy RFInstrumentSuiteV5 chunk" || echo "MISS: lazy RFInstrumentSuiteV5 chunk"

  find "$DIST/assets" -maxdepth 1 -type f -name 'RFSourceBridgePanelV7-*.js' | grep -q . \
    && echo "OK: lazy RFSourceBridgePanelV7 chunk" || echo "MISS: lazy RFSourceBridgePanelV7 chunk"

  find "$DIST/assets" -maxdepth 1 -type f -name 'RFSourceRuntimeProbeV8-*.js' | grep -q . \
    && echo "OK: lazy RFSourceRuntimeProbeV8 chunk" || echo "MISS: lazy RFSourceRuntimeProbeV8 chunk"

  find "$DIST/assets" -maxdepth 1 -type f -name 'RFBridgeReadinessV9-*.js' | grep -q . \
    && echo "OK: lazy RFBridgeReadinessV9 chunk" || echo "MISS: lazy RFBridgeReadinessV9 chunk"

  find "$DIST/assets" -maxdepth 1 -type f -name 'RFEvidenceFlightRecorderV10-*.js' | grep -q . \
    && echo "OK: lazy RFEvidenceFlightRecorderV10 chunk" || echo "MISS: lazy RFEvidenceFlightRecorderV10 chunk"

  find "$DIST/assets" -maxdepth 1 -type f -name 'RFSignalDspWorkerV3-*.js' | grep -q . \
    && echo "OK: RFSignalDspWorkerV3 worker chunk" || echo "MISS: RFSignalDspWorkerV3 worker chunk"

  test -x "$ROOT/runtime/bin/trfmc_static_nginx_start_4180.sh" && echo "OK: nginx start script" || echo "MISS: nginx start script"
  test -x "$ROOT/runtime/bin/trfmc_static_nginx_stop_4180.sh" && echo "OK: nginx stop script" || echo "MISS: nginx stop script"
  test -x "$ROOT/runtime/bin/trfmc_static_nginx_status_4180.sh" && echo "OK: nginx status script" || echo "MISS: nginx status script"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
TOTAL_BYTES="$(find "$DIST" -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')"
JS_COUNT="$(find "$DIST/assets" -type f -name '*.js' | wc -l | tr -d ' ')"
CSS_COUNT="$(find "$DIST/assets" -type f -name '*.css' | wc -l | tr -d ' ')"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/static_server_manifest_v20.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_STATIC_PRODUCTION_SERVER_PACK_V20",
  "server": "nginx-user-mode",
  "static_url": "http://127.0.0.1:4180/",
  "dist_root": "$DIST",
  "nginx_root": "$NGINX_ROOT",
  "nginx_conf": "$NGINX_CONF",
  "mounted": "RFOperationalDeckV16ChunkObservatory",
  "dist": {
    "js_files": $JS_COUNT,
    "css_files": $CSS_COUNT,
    "total_bytes": $TOTAL_BYTES
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "control_scripts": {
    "start": "$ROOT/runtime/bin/trfmc_static_nginx_start_4180.sh",
    "stop": "$ROOT/runtime/bin/trfmc_static_nginx_stop_4180.sh",
    "status": "$ROOT/runtime/bin/trfmc_static_nginx_status_4180.sh"
  },
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  frontend/dist \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_instruments \
  runtime/nginx/trfmc_static_4180 \
  runtime/bin/trfmc_static_nginx_start_4180.sh \
  runtime/bin/trfmc_static_nginx_stop_4180.sh \
  runtime/bin/trfmc_static_nginx_status_4180.sh \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_STATIC_PRODUCTION_SERVER_PACK_V20",
  "static_url": "http://127.0.0.1:4180/",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_static_production_server_pack_v20"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_static_production_server_pack_v20"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V20 STATIC PRODUCTION SERVER PACK COMPLETATO"
echo "URL   : http://127.0.0.1:4180/"
echo "Start : runtime/bin/trfmc_static_nginx_start_4180.sh"
echo "Stop  : runtime/bin/trfmc_static_nginx_stop_4180.sh"
echo "Status: runtime/bin/trfmc_static_nginx_status_4180.sh"
echo "============================================================"
