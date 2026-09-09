#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_SYSTEMD_USER_SERVICE_PACK_V24_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_SYSTEMD_USER_SERVICE_PACK_V24_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_SYSTEMD_USER_SERVICE_PACK_V24_$TS.tar.gz"

NGINX_BIN="$(command -v nginx || true)"

echo "============================================================"
echo "TRFMC SYSTEMD USER SERVICE PACK V24"
echo "systemctl --user · NGINX user-mode service supervision · 4180/4181/4182"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes" "$ROOT/runtime/bin" "$USER_SYSTEMD_DIR"

echo
echo "=== PREFLIGHT ==="

test -n "$NGINX_BIN" || { echo "ERRORE: nginx non trovato"; exit 1; }
test -d "$ROOT/frontend/dist" || { echo "ERRORE: frontend/dist mancante"; exit 1; }
test -f "$ROOT/frontend/dist/index.html" || { echo "ERRORE: dist/index.html mancante"; exit 1; }
test -f "$ROOT/frontend/src/app/main.tsx" || { echo "ERRORE: main.tsx mancante"; exit 1; }

grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" || {
  echo "ERRORE: RFOperationalDeckV16ChunkObservatory non montato"
  exit 1
}

for conf in \
  "$ROOT/runtime/nginx/trfmc_static_4180/conf/nginx.conf" \
  "$ROOT/runtime/nginx/trfmc_static_api_4181/conf/nginx.conf" \
  "$ROOT/runtime/nginx/trfmc_clean_offline_api_4182/conf/nginx.conf"
do
  test -f "$conf" || { echo "ERRORE: nginx conf mancante: $conf"; exit 1; }
  nginx -t -p "$(dirname "$(dirname "$conf")")" -c "$conf"
done

if ! systemctl --user list-units >/dev/null 2>&1; then
  cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_SYSTEMD_USER_SERVICE_PACK_V24",
  "result": "NEEDS_SYSTEMD_USER",
  "reason": "systemctl --user non disponibile nella sessione corrente"
}
JSON
  ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_systemd_user_service_pack_v24"
  cat "$QUALITY_DIR/summary.json" | python3 -m json.tool
  exit 0
fi

echo "OK: nginx, dist, V16, conf e systemd user disponibili"

echo
echo "=== CREA UNIT FILES ==="

cat > "$USER_SYSTEMD_DIR/trfmc-static-4180.service" <<UNIT
[Unit]
Description=TRFMC NGINX Static Production Server 4180
Documentation=TRFMC local runtime
After=network.target

[Service]
Type=simple
ExecStart=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_static_4180 -c $ROOT/runtime/nginx/trfmc_static_4180/conf/nginx.conf -g 'daemon off;'
ExecStop=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_static_4180 -c $ROOT/runtime/nginx/trfmc_static_4180/conf/nginx.conf -s quit
Restart=on-failure
RestartSec=2
WorkingDirectory=$ROOT
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
UNIT

cat > "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" <<UNIT
[Unit]
Description=TRFMC NGINX Static API Proxy Gateway 4181
Documentation=TRFMC local runtime
After=network.target

[Service]
Type=simple
ExecStart=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_static_api_4181 -c $ROOT/runtime/nginx/trfmc_static_api_4181/conf/nginx.conf -g 'daemon off;'
ExecStop=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_static_api_4181 -c $ROOT/runtime/nginx/trfmc_static_api_4181/conf/nginx.conf -s quit
Restart=on-failure
RestartSec=2
WorkingDirectory=$ROOT
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
UNIT

cat > "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" <<UNIT
[Unit]
Description=TRFMC NGINX Clean Offline API Gateway 4182
Documentation=TRFMC local runtime
After=network.target

[Service]
Type=simple
ExecStart=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_clean_offline_api_4182 -c $ROOT/runtime/nginx/trfmc_clean_offline_api_4182/conf/nginx.conf -g 'daemon off;'
ExecStop=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_clean_offline_api_4182 -c $ROOT/runtime/nginx/trfmc_clean_offline_api_4182/conf/nginx.conf -s quit
Restart=on-failure
RestartSec=2
WorkingDirectory=$ROOT
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload

echo
echo "=== CREA CONTROL SCRIPT V24 ==="

cat > "$ROOT/runtime/bin/trfmc_systemd_user_status_v24.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRFMC SYSTEMD USER STATUS V24"
echo "============================================================"

echo
echo "=== SYSTEMD UNITS ==="
systemctl --user --no-pager status trfmc-static-4180.service trfmc-api-proxy-4181.service trfmc-clean-offline-4182.service || true

echo
echo "=== ENABLED STATE ==="
systemctl --user is-enabled trfmc-static-4180.service trfmc-api-proxy-4181.service trfmc-clean-offline-4182.service || true

echo
echo "=== PORTS ==="
ss -ltnp | grep -E ':4180|:4181|:4182' || true

echo
echo "=== HTTP ==="
for u in \
  http://127.0.0.1:4180/ \
  http://127.0.0.1:4181/ \
  http://127.0.0.1:4182/ \
  http://127.0.0.1:4182/api/health \
  http://127.0.0.1:4182/api/mission/status
do
  echo
  echo "--- \$u"
  curl -I --connect-timeout 2 --max-time 6 "\$u" || true
done
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_systemd_user_start_v24.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"

echo "============================================================"
echo "TRFMC SYSTEMD USER START V24"
echo "============================================================"

for s in \
  "\$ROOT/runtime/bin/trfmc_static_nginx_stop_4180.sh" \
  "\$ROOT/runtime/bin/trfmc_static_api_gateway_stop_4181.sh" \
  "\$ROOT/runtime/bin/trfmc_clean_offline_api_stop_4182.sh"
do
  if [ -x "\$s" ]; then
    "\$s" || true
  fi
done

systemctl --user daemon-reload
systemctl --user start trfmc-static-4180.service
systemctl --user start trfmc-api-proxy-4181.service
systemctl --user start trfmc-clean-offline-4182.service

"$ROOT/runtime/bin/trfmc_systemd_user_status_v24.sh"
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_systemd_user_stop_v24.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRFMC SYSTEMD USER STOP V24"
echo "============================================================"

systemctl --user stop trfmc-clean-offline-4182.service || true
systemctl --user stop trfmc-api-proxy-4181.service || true
systemctl --user stop trfmc-static-4180.service || true

ss -ltnp | grep -E ':4180|:4181|:4182' || true
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_systemd_user_enable_v24.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRFMC SYSTEMD USER ENABLE V24"
echo "============================================================"

systemctl --user daemon-reload
systemctl --user enable trfmc-static-4180.service
systemctl --user enable trfmc-api-proxy-4181.service
systemctl --user enable trfmc-clean-offline-4182.service

echo
echo "Servizi abilitati per default.target utente."
echo "Per avvio automatico anche senza login interattivo può servire:"
echo "sudo loginctl enable-linger \$USER"
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_systemd_user_disable_v24.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRFMC SYSTEMD USER DISABLE V24"
echo "============================================================"

systemctl --user disable trfmc-clean-offline-4182.service || true
systemctl --user disable trfmc-api-proxy-4181.service || true
systemctl --user disable trfmc-static-4180.service || true
SCRIPT

chmod +x \
  "$ROOT/runtime/bin/trfmc_systemd_user_status_v24.sh" \
  "$ROOT/runtime/bin/trfmc_systemd_user_start_v24.sh" \
  "$ROOT/runtime/bin/trfmc_systemd_user_stop_v24.sh" \
  "$ROOT/runtime/bin/trfmc_systemd_user_enable_v24.sh" \
  "$ROOT/runtime/bin/trfmc_systemd_user_disable_v24.sh"

echo
echo "=== START SERVICES VIA SYSTEMD USER ==="

"$ROOT/runtime/bin/trfmc_systemd_user_start_v24.sh"

echo
echo "=== HTTP GATE ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

probe "http://127.0.0.1:4180/"
probe "http://127.0.0.1:4181/"
probe "http://127.0.0.1:4182/"
probe "http://127.0.0.1:4182/api/health"
probe "http://127.0.0.1:4182/api/mission/status"

column -t -s $'\t' "$HTTP_TSV"

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$USER_SYSTEMD_DIR/trfmc-static-4180.service" && echo "OK: trfmc-static-4180.service" || echo "MISS: trfmc-static-4180.service"
  test -f "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" && echo "OK: trfmc-api-proxy-4181.service" || echo "MISS: trfmc-api-proxy-4181.service"
  test -f "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" && echo "OK: trfmc-clean-offline-4182.service" || echo "MISS: trfmc-clean-offline-4182.service"

  test -x "$ROOT/runtime/bin/trfmc_systemd_user_status_v24.sh" && echo "OK: status script" || echo "MISS: status script"
  test -x "$ROOT/runtime/bin/trfmc_systemd_user_start_v24.sh" && echo "OK: start script" || echo "MISS: start script"
  test -x "$ROOT/runtime/bin/trfmc_systemd_user_stop_v24.sh" && echo "OK: stop script" || echo "MISS: stop script"
  test -x "$ROOT/runtime/bin/trfmc_systemd_user_enable_v24.sh" && echo "OK: enable script" || echo "MISS: enable script"
  test -x "$ROOT/runtime/bin/trfmc_systemd_user_disable_v24.sh" && echo "OK: disable script" || echo "MISS: disable script"

  systemctl --user is-active --quiet trfmc-static-4180.service && echo "OK: 4180 active" || echo "MISS: 4180 active"
  systemctl --user is-active --quiet trfmc-api-proxy-4181.service && echo "OK: 4181 active" || echo "MISS: 4181 active"
  systemctl --user is-active --quiet trfmc-clean-offline-4182.service && echo "OK: 4182 active" || echo "MISS: 4182 active"

  grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" && echo "OK: V16 mount preserved" || echo "MISS: V16 mount preserved"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/systemd_user_service_manifest_v24.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_SYSTEMD_USER_SERVICE_PACK_V24",
  "systemd_user_dir": "$USER_SYSTEMD_DIR",
  "services": {
    "static_4180": "$USER_SYSTEMD_DIR/trfmc-static-4180.service",
    "api_proxy_4181": "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service",
    "clean_offline_4182": "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service"
  },
  "control_scripts": {
    "status": "$ROOT/runtime/bin/trfmc_systemd_user_status_v24.sh",
    "start": "$ROOT/runtime/bin/trfmc_systemd_user_start_v24.sh",
    "stop": "$ROOT/runtime/bin/trfmc_systemd_user_stop_v24.sh",
    "enable": "$ROOT/runtime/bin/trfmc_systemd_user_enable_v24.sh",
    "disable": "$ROOT/runtime/bin/trfmc_systemd_user_disable_v24.sh"
  },
  "urls": {
    "static": "http://127.0.0.1:4180/",
    "api_proxy": "http://127.0.0.1:4181/",
    "clean_offline": "http://127.0.0.1:4182/"
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "source_mutation": false,
  "dist_mutation": false,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  "$USER_SYSTEMD_DIR/trfmc-static-4180.service" \
  "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" \
  "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" \
  runtime/bin/trfmc_systemd_user_status_v24.sh \
  runtime/bin/trfmc_systemd_user_start_v24.sh \
  runtime/bin/trfmc_systemd_user_stop_v24.sh \
  runtime/bin/trfmc_systemd_user_enable_v24.sh \
  runtime/bin/trfmc_systemd_user_disable_v24.sh \
  "$RELEASE_DIR" \
  frontend/src/app/main.tsx \
  frontend/dist \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_SYSTEMD_USER_SERVICE_PACK_V24",
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

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_systemd_user_service_pack_v24"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_systemd_user_service_pack_v24"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V24 SYSTEMD USER SERVICE PACK COMPLETATO"
echo "Status : runtime/bin/trfmc_systemd_user_status_v24.sh"
echo "Start  : runtime/bin/trfmc_systemd_user_start_v24.sh"
echo "Stop   : runtime/bin/trfmc_systemd_user_stop_v24.sh"
echo "Enable : runtime/bin/trfmc_systemd_user_enable_v24.sh"
echo "Disable: runtime/bin/trfmc_systemd_user_disable_v24.sh"
echo "============================================================"
