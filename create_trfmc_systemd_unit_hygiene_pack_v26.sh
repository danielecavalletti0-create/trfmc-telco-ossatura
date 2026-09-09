#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_SYSTEMD_UNIT_HYGIENE_PACK_V26_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_SYSTEMD_UNIT_HYGIENE_PACK_V26_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_SYSTEMD_UNIT_HYGIENE_PACK_V26_$TS.tar.gz"

NGINX_BIN="$(command -v nginx || true)"

echo "============================================================"
echo "TRFMC SYSTEMD UNIT HYGIENE PACK V26"
echo "fix Documentation warnings · cleaner NGINX stop · journal hygiene"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes" "$ROOT/runtime/bin"

echo
echo "=== PREFLIGHT ==="

test -n "$NGINX_BIN" || { echo "ERRORE: nginx non trovato"; exit 1; }

for unit in \
  "$USER_SYSTEMD_DIR/trfmc-static-4180.service" \
  "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" \
  "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service"
do
  test -f "$unit" || { echo "ERRORE: unit mancante: $unit"; exit 1; }
done

for conf in \
  "$ROOT/runtime/nginx/trfmc_static_4180/conf/nginx.conf" \
  "$ROOT/runtime/nginx/trfmc_static_api_4181/conf/nginx.conf" \
  "$ROOT/runtime/nginx/trfmc_clean_offline_api_4182/conf/nginx.conf"
do
  test -f "$conf" || { echo "ERRORE: nginx conf mancante: $conf"; exit 1; }
  nginx -t -p "$(dirname "$(dirname "$conf")")" -c "$conf"
done

echo "OK: unit, nginx e configurazioni presenti"

echo
echo "=== BACKUP UNIT ORIGINALI ==="

mkdir -p "$RELEASE_DIR/original_units"

cp "$USER_SYSTEMD_DIR/trfmc-static-4180.service" "$RELEASE_DIR/original_units/trfmc-static-4180.service.bak_$TS"
cp "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" "$RELEASE_DIR/original_units/trfmc-api-proxy-4181.service.bak_$TS"
cp "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" "$RELEASE_DIR/original_units/trfmc-clean-offline-4182.service.bak_$TS"

echo
echo "=== STOP SERVIZI PRIMA DEL PATCH ==="

systemctl --user stop trfmc-clean-offline-4182.service || true
systemctl --user stop trfmc-api-proxy-4181.service || true
systemctl --user stop trfmc-static-4180.service || true

sleep 1

echo
echo "=== SCRIVO UNIT PULITE ==="

cat > "$USER_SYSTEMD_DIR/trfmc-static-4180.service" <<UNIT
[Unit]
Description=TRFMC NGINX Static Production Server 4180
Documentation=man:nginx(8) man:systemd.service(5)
After=network.target

[Service]
Type=simple
WorkingDirectory=$ROOT
ExecStart=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_static_4180 -c $ROOT/runtime/nginx/trfmc_static_4180/conf/nginx.conf -g 'daemon off;'
Restart=on-failure
RestartSec=2
KillSignal=SIGQUIT
TimeoutStopSec=10
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
UNIT

cat > "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" <<UNIT
[Unit]
Description=TRFMC NGINX Static API Proxy Gateway 4181
Documentation=man:nginx(8) man:systemd.service(5)
After=network.target

[Service]
Type=simple
WorkingDirectory=$ROOT
ExecStart=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_static_api_4181 -c $ROOT/runtime/nginx/trfmc_static_api_4181/conf/nginx.conf -g 'daemon off;'
Restart=on-failure
RestartSec=2
KillSignal=SIGQUIT
TimeoutStopSec=10
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
UNIT

cat > "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" <<UNIT
[Unit]
Description=TRFMC NGINX Clean Offline API Gateway 4182
Documentation=man:nginx(8) man:systemd.service(5)
After=network.target

[Service]
Type=simple
WorkingDirectory=$ROOT
ExecStart=$NGINX_BIN -p $ROOT/runtime/nginx/trfmc_clean_offline_api_4182 -c $ROOT/runtime/nginx/trfmc_clean_offline_api_4182/conf/nginx.conf -g 'daemon off;'
Restart=on-failure
RestartSec=2
KillSignal=SIGQUIT
TimeoutStopSec=10
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload

echo
echo "=== VERIFY UNIT ==="

systemd-analyze --user verify \
  "$USER_SYSTEMD_DIR/trfmc-static-4180.service" \
  "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" \
  "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" \
  > "$RELEASE_DIR/systemd_analyze_verify_v26.txt" 2>&1 || true

cat "$RELEASE_DIR/systemd_analyze_verify_v26.txt" || true

echo
echo "=== RE-ENABLE + START ==="

systemctl --user enable trfmc-static-4180.service
systemctl --user enable trfmc-api-proxy-4181.service
systemctl --user enable trfmc-clean-offline-4182.service

systemctl --user start trfmc-static-4180.service
systemctl --user start trfmc-api-proxy-4181.service
systemctl --user start trfmc-clean-offline-4182.service

sleep 2

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
echo "=== JOURNAL HYGIENE CHECK ==="

JOURNAL_TXT="$RELEASE_DIR/journal_hygiene_v26.txt"

journalctl --user \
  -u trfmc-static-4180.service \
  -u trfmc-api-proxy-4181.service \
  -u trfmc-clean-offline-4182.service \
  --since "2 minutes ago" \
  --no-pager > "$JOURNAL_TXT" 2>/dev/null || true

cat "$JOURNAL_TXT" | sed -n '1,140p'

INVALID_URL_COUNT="$(grep -c 'Invalid URL' "$JOURNAL_TXT" || true)"
PID_MISSING_COUNT="$(grep -c 'nginx.pid.*No such file' "$JOURNAL_TXT" || true)"

echo
echo "Invalid URL count recent: $INVALID_URL_COUNT"
echo "Missing PID count recent: $PID_MISSING_COUNT"

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  grep -q 'Documentation=man:nginx(8) man:systemd.service(5)' "$USER_SYSTEMD_DIR/trfmc-static-4180.service" && echo "OK: 4180 documentation valid" || echo "MISS: 4180 documentation valid"
  grep -q 'Documentation=man:nginx(8) man:systemd.service(5)' "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" && echo "OK: 4181 documentation valid" || echo "MISS: 4181 documentation valid"
  grep -q 'Documentation=man:nginx(8) man:systemd.service(5)' "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" && echo "OK: 4182 documentation valid" || echo "MISS: 4182 documentation valid"

  grep -q 'KillSignal=SIGQUIT' "$USER_SYSTEMD_DIR/trfmc-static-4180.service" && echo "OK: 4180 KillSignal SIGQUIT" || echo "MISS: 4180 KillSignal SIGQUIT"
  grep -q 'KillSignal=SIGQUIT' "$USER_SYSTEMD_DIR/trfmc-api-proxy-4181.service" && echo "OK: 4181 KillSignal SIGQUIT" || echo "MISS: 4181 KillSignal SIGQUIT"
  grep -q 'KillSignal=SIGQUIT' "$USER_SYSTEMD_DIR/trfmc-clean-offline-4182.service" && echo "OK: 4182 KillSignal SIGQUIT" || echo "MISS: 4182 KillSignal SIGQUIT"

  systemctl --user is-enabled --quiet trfmc-static-4180.service && echo "OK: 4180 enabled" || echo "MISS: 4180 enabled"
  systemctl --user is-enabled --quiet trfmc-api-proxy-4181.service && echo "OK: 4181 enabled" || echo "MISS: 4181 enabled"
  systemctl --user is-enabled --quiet trfmc-clean-offline-4182.service && echo "OK: 4182 enabled" || echo "MISS: 4182 enabled"

  systemctl --user is-active --quiet trfmc-static-4180.service && echo "OK: 4180 active" || echo "MISS: 4180 active"
  systemctl --user is-active --quiet trfmc-api-proxy-4181.service && echo "OK: 4181 active" || echo "MISS: 4181 active"
  systemctl --user is-active --quiet trfmc-clean-offline-4182.service && echo "OK: 4182 active" || echo "MISS: 4182 active"

  [ "$INVALID_URL_COUNT" -eq 0 ] && echo "OK: no recent Invalid URL journal warning" || echo "MISS: recent Invalid URL journal warning"
  [ "$PID_MISSING_COUNT" -eq 0 ] && echo "OK: no recent nginx.pid missing warning" || echo "MISS: recent nginx.pid missing warning"
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

MANIFEST="$RELEASE_DIR/systemd_unit_hygiene_manifest_v26.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_SYSTEMD_UNIT_HYGIENE_PACK_V26",
  "systemd_user_dir": "$USER_SYSTEMD_DIR",
  "changed": [
    "Documentation=man:nginx(8) man:systemd.service(5)",
    "KillSignal=SIGQUIT",
    "removed ExecStop nginx -s quit"
  ],
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "invalid_url_count_recent": $INVALID_URL_COUNT,
  "pid_missing_count_recent": $PID_MISSING_COUNT,
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
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_SYSTEMD_UNIT_HYGIENE_PACK_V26",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "journal_hygiene": "$JOURNAL_TXT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "invalid_url_count_recent": $INVALID_URL_COUNT,
  "pid_missing_count_recent": $PID_MISSING_COUNT,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_systemd_unit_hygiene_pack_v26"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_systemd_unit_hygiene_pack_v26"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V26 SYSTEMD UNIT HYGIENE PACK COMPLETATO"
echo "Verifica:"
echo "cat runtime/quality/latest_systemd_unit_hygiene_pack_v26/summary.json | python3 -m json.tool"
echo "runtime/bin/trfmc_boot_persistence_verify_v25.sh"
echo "============================================================"
