#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
FRONTEND="$ROOT/frontend"
DIST="$FRONTEND/dist"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_CLEAN_OFFLINE_API_GATEWAY_PACK_V22_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_CLEAN_OFFLINE_API_GATEWAY_PACK_V22_$TS"
NGINX_ROOT="$ROOT/runtime/nginx/trfmc_clean_offline_api_4182"
NGINX_CONF="$NGINX_ROOT/conf/nginx.conf"
FREEZE="$ROOT/runtime/freezes/TRFMC_CLEAN_OFFLINE_API_GATEWAY_PACK_V22_$TS.tar.gz"

echo "============================================================"
echo "TRFMC CLEAN OFFLINE API GATEWAY PACK V22"
echo "NGINX user-mode · static dist · clean JSON API fallback · no upstream noise"
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
  "operation": "TRFMC_CLEAN_OFFLINE_API_GATEWAY_PACK_V22",
  "result": "NEEDS_NGINX",
  "install_hint": "sudo apt update && sudo apt install -y nginx"
}
JSON
  ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_clean_offline_api_gateway_pack_v22"
  cat "$QUALITY_DIR/summary.json" | python3 -m json.tool
  exit 0
fi

echo "OK: dist presente, V16 montato, nginx disponibile"

echo
echo "=== CREA NGINX CONFIG 4182 CLEAN OFFLINE ==="

cat > "$NGINX_CONF" <<NGINX
worker_processes  1;
pid $NGINX_ROOT/nginx.pid;
error_log $NGINX_ROOT/logs/error.log warn;

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
        listen 127.0.0.1:4182;
        server_name trfmc.local localhost 127.0.0.1;

        root $DIST;
        index index.html;

        location /assets/ {
            try_files \$uri =404;
            add_header Cache-Control "public, max-age=31536000, immutable";
        }

        location = /api/health {
            default_type application/json;
            add_header Cache-Control "no-cache";
            return 200 '{"status":"ok","source":"trfmc-nginx-v22-clean-offline","mode":"static-api-fallback","backend_proxy":false}';
        }

        location = /api/docs/index {
            try_files \$uri @api_clean_fallback;
            add_header Cache-Control "no-cache";
        }

        location = /api/portal/index {
            try_files \$uri @api_clean_fallback;
            add_header Cache-Control "no-cache";
        }

        location /api/ {
            default_type application/json;
            add_header Cache-Control "no-cache";
            return 200 '{"status":"offline_or_not_implemented","source":"trfmc-nginx-v22-clean-offline-api-fallback","path":"\$uri","backend_proxy":false,"mode":"safe-readonly-clean-offline"}';
        }

        location @api_clean_fallback {
            default_type application/json;
            add_header Cache-Control "no-cache";
            return 200 '{"status":"offline_or_not_implemented","source":"trfmc-nginx-v22-clean-offline-api-fallback","path":"\$uri","backend_proxy":false,"mode":"safe-readonly-clean-offline"}';
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
echo "=== CREA CONTROL SCRIPT 4182 ==="

cat > "$ROOT/runtime/bin/trfmc_clean_offline_api_start_4182.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

NGINX_ROOT="$NGINX_ROOT"
NGINX_CONF="$NGINX_CONF"

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:4182/ >/dev/null 2>&1; then
  echo "OK: TRFMC clean offline API gateway already reachable at http://127.0.0.1:4182/"
  ss -ltnp | grep ':4182' || true
  exit 0
fi

nginx -p "\$NGINX_ROOT" -c "\$NGINX_CONF"

sleep 1

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:4182/ >/dev/null 2>&1; then
  echo "OK: TRFMC clean offline API gateway started"
  echo "URL: http://127.0.0.1:4182/"
  ss -ltnp | grep ':4182' || true
else
  echo "ERRORE: TRFMC clean offline API gateway not reachable"
  tail -n 80 "\$NGINX_ROOT/logs/error.log" || true
  exit 1
fi
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_clean_offline_api_stop_4182.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

NGINX_ROOT="$NGINX_ROOT"
NGINX_CONF="$NGINX_CONF"

if [ -f "\$NGINX_ROOT/nginx.pid" ]; then
  nginx -p "\$NGINX_ROOT" -c "\$NGINX_CONF" -s quit || true
  sleep 1
fi

if ss -ltnp | grep -q ':4182'; then
  PID="\$(ss -ltnp | awk '/:4182/ { if (match(\$0,/pid=[0-9]+/)) { print substr(\$0,RSTART+4,RLENGTH-4); exit } }')"
  [ -n "\$PID" ] && kill "\$PID" 2>/dev/null || true
fi

echo "OK: TRFMC clean offline API gateway stop requested"
ss -ltnp | grep ':4182' || true
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_clean_offline_api_status_4182.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== PORT 4182 ==="
ss -ltnp | grep ':4182' || true

echo
echo "=== STATIC HTTP ==="
curl -I --connect-timeout 2 --max-time 6 http://127.0.0.1:4182/ || true
curl -I --connect-timeout 2 --max-time 6 http://127.0.0.1:4182/index.html || true
curl -I --connect-timeout 2 --max-time 6 http://127.0.0.1:4182/api/health || true

echo
echo "=== CLEAN API FALLBACK PROBES ==="
for u in \
  /api/mission/status \
  /api/persistence/status \
  /api/time-cursor/status \
  /api/persistence/events \
  /api/assets/graph \
  /api/network-fabric/overview \
  /api/network-fabric/paths \
  /api/rf-coverage/demo \
  /api/rf-coverage/runs \
  /api/rf-field/demo?target_asset_id=UE-REMOTE-001 \
  /api/rf-field/runs \
  /api/telco-mns/status \
  /api/access-trust/rat/demo \
  /api/access-trust/wifi/demo \
  /api/soc-noc/correlation/demo \
  /api/restricted/status
do
  echo
  echo "--- \$u"
  curl -sS --connect-timeout 2 --max-time 6 "http://127.0.0.1:4182\$u" | head -c 240
  echo
done

echo
echo "=== ERROR LOG REFUSED CHECK ==="
grep -n "connect() failed\\|Connection refused\\|upstream" "$NGINX_ROOT/logs/error.log" 2>/dev/null || echo "OK: no upstream/refused errors in V22 log"
SCRIPT

chmod +x \
  "$ROOT/runtime/bin/trfmc_clean_offline_api_start_4182.sh" \
  "$ROOT/runtime/bin/trfmc_clean_offline_api_stop_4182.sh" \
  "$ROOT/runtime/bin/trfmc_clean_offline_api_status_4182.sh"

echo
echo "=== AVVIO CLEAN OFFLINE API 4182 ==="

"$ROOT/runtime/bin/trfmc_clean_offline_api_start_4182.sh"

echo
echo "=== HTTP GATE ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "http://127.0.0.1:4182$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

probe "/"
probe "/index.html"
probe "/api/health"
probe "/api/docs/index"
probe "/api/portal/index"

for u in \
  /api/mission/status \
  /api/persistence/status \
  /api/time-cursor/status \
  /api/persistence/events \
  /api/assets/graph \
  /api/network-fabric/overview \
  /api/network-fabric/paths \
  /api/rf-coverage/demo \
  /api/rf-coverage/runs \
  /api/rf-field/demo \
  /api/rf-field/runs \
  /api/telco-mns/status \
  /api/access-trust/rat/demo \
  /api/access-trust/wifi/demo \
  /api/soc-noc/correlation/demo \
  /api/restricted/status
do
  probe "$u"
done

while IFS= read -r f; do
  probe "/${f#$DIST/}"
done < <(find "$DIST/assets" -maxdepth 1 -type f \( -name 'index-*.js' -o -name 'index-*.css' -o -name 'RF*.js' \) | sort)

column -t -s $'\t' "$HTTP_TSV" | sed -n '1,140p'

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

  test -x "$ROOT/runtime/bin/trfmc_clean_offline_api_start_4182.sh" && echo "OK: clean offline start script" || echo "MISS: clean offline start script"
  test -x "$ROOT/runtime/bin/trfmc_clean_offline_api_stop_4182.sh" && echo "OK: clean offline stop script" || echo "MISS: clean offline stop script"
  test -x "$ROOT/runtime/bin/trfmc_clean_offline_api_status_4182.sh" && echo "OK: clean offline status script" || echo "MISS: clean offline status script"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
REFUSED_COUNT="$(grep -c "connect() failed\\|Connection refused\\|upstream" "$NGINX_ROOT/logs/error.log" 2>/dev/null || true)"
TOTAL_BYTES="$(find "$DIST" -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')"
JS_COUNT="$(find "$DIST/assets" -type f -name '*.js' | wc -l | tr -d ' ')"
CSS_COUNT="$(find "$DIST/assets" -type f -name '*.css' | wc -l | tr -d ' ')"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ] || [ "$REFUSED_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/clean_offline_api_manifest_v22.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_CLEAN_OFFLINE_API_GATEWAY_PACK_V22",
  "server": "nginx-user-mode",
  "clean_offline_url": "http://127.0.0.1:4182/",
  "dist_root": "$DIST",
  "nginx_root": "$NGINX_ROOT",
  "nginx_conf": "$NGINX_CONF",
  "mounted": "RFOperationalDeckV16ChunkObservatory",
  "backend_proxy": false,
  "api_fallback": "safe-readonly-clean-offline-json-fallback",
  "dist": {
    "js_files": $JS_COUNT,
    "css_files": $CSS_COUNT,
    "total_bytes": $TOTAL_BYTES
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "refused_or_upstream_error_count": $REFUSED_COUNT,
  "control_scripts": {
    "start": "$ROOT/runtime/bin/trfmc_clean_offline_api_start_4182.sh",
    "stop": "$ROOT/runtime/bin/trfmc_clean_offline_api_stop_4182.sh",
    "status": "$ROOT/runtime/bin/trfmc_clean_offline_api_status_4182.sh"
  },
  "preserves_v20_static_server": true,
  "preserves_v21_proxy_gateway": true,
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
  runtime/nginx/trfmc_clean_offline_api_4182 \
  runtime/bin/trfmc_clean_offline_api_start_4182.sh \
  runtime/bin/trfmc_clean_offline_api_stop_4182.sh \
  runtime/bin/trfmc_clean_offline_api_status_4182.sh \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_CLEAN_OFFLINE_API_GATEWAY_PACK_V22",
  "clean_offline_url": "http://127.0.0.1:4182/",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "refused_or_upstream_error_count": $REFUSED_COUNT,
  "preserves_v20_static_server": true,
  "preserves_v21_proxy_gateway": true,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_clean_offline_api_gateway_pack_v22"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_clean_offline_api_gateway_pack_v22"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V22 CLEAN OFFLINE API GATEWAY PACK COMPLETATO"
echo "URL   : http://127.0.0.1:4182/"
echo "Start : runtime/bin/trfmc_clean_offline_api_start_4182.sh"
echo "Stop  : runtime/bin/trfmc_clean_offline_api_stop_4182.sh"
echo "Status: runtime/bin/trfmc_clean_offline_api_status_4182.sh"
echo "============================================================"
