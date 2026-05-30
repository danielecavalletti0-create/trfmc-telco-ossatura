#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_READONLY_BACKEND_SYSTEMD_PACK_V29_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_READONLY_BACKEND_SYSTEMD_PACK_V29_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_READONLY_BACKEND_SYSTEMD_PACK_V29_$TS.tar.gz"

VENV="$ROOT/.venv_trfmc_backend_v28"
PY="$VENV/bin/python"
UNIT="$USER_SYSTEMD_DIR/trfmc-readonly-backend-8000.service"

echo "============================================================"
echo "TRFMC READ-ONLY BACKEND SYSTEMD PACK V29"
echo "systemd --user · FastAPI/Uvicorn backend 8000 · NGINX 4181 proxy target"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes" "$ROOT/runtime/bin" "$USER_SYSTEMD_DIR"

echo
echo "=== PREFLIGHT ==="

test -f "$ROOT/backend/readonly_bridge_v28/app.py" || {
  echo "ERRORE: backend/readonly_bridge_v28/app.py mancante. Prima completare V28."
  exit 1
}

test -x "$PY" || {
  echo "ERRORE: venv Python V28 mancante: $PY"
  echo "Rilancia V28R1 bootstrap."
  exit 1
}

"$PY" - <<'PY'
import fastapi
import uvicorn
print("OK: fastapi", fastapi.__version__)
print("OK: uvicorn", uvicorn.__version__)
PY

test -f "$ROOT/runtime/quality/latest_readonly_backend_bridge_v28/summary.json" || {
  echo "ERRORE: V28 summary mancante"
  exit 1
}

grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" || {
  echo "ERRORE: V16 mount non preservato"
  exit 1
}

if ! systemctl --user list-units >/dev/null 2>&1; then
  echo "ERRORE: systemctl --user non disponibile"
  exit 1
fi

echo "OK: V28 app, venv, FastAPI/Uvicorn e systemd user disponibili"

echo
echo "=== STOP BACKEND MANUALE EVENTUALE ==="

if [ -x "$ROOT/runtime/bin/trfmc_readonly_backend_v28_stop_8000.sh" ]; then
  "$ROOT/runtime/bin/trfmc_readonly_backend_v28_stop_8000.sh" || true
else
  pkill -f "backend.readonly_bridge_v28.app:app" 2>/dev/null || true
fi

sleep 1

echo
echo "=== CREA SYSTEMD USER UNIT BACKEND 8000 ==="

cat > "$UNIT" <<UNITEOF
[Unit]
Description=TRFMC Read-only Backend Bridge V28 on 8000
Documentation=man:systemd.service(5)
After=network.target trfmc-api-proxy-4181.service
Wants=trfmc-api-proxy-4181.service

[Service]
Type=simple
WorkingDirectory=$ROOT
Environment=PYTHONUNBUFFERED=1
ExecStart=$PY -m uvicorn backend.readonly_bridge_v28.app:app --host 127.0.0.1 --port 8000
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
UNITEOF

systemctl --user daemon-reload

echo
echo "=== VERIFY UNIT ==="

VERIFY_TXT="$RELEASE_DIR/systemd_analyze_verify_v29.txt"

systemd-analyze --user verify "$UNIT" > "$VERIFY_TXT" 2>&1 || true
cat "$VERIFY_TXT"

echo
echo "=== ENABLE + START BACKEND SERVICE ==="

systemctl --user enable trfmc-readonly-backend-8000.service
systemctl --user restart trfmc-readonly-backend-8000.service

sleep 3

echo
echo "=== CREA CONTROL SCRIPT V29 ==="

cat > "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_status_v29.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRFMC READ-ONLY BACKEND SYSTEMD STATUS V29"
echo "============================================================"

echo
echo "=== SYSTEMD STATUS ==="
systemctl --user --no-pager --full status trfmc-readonly-backend-8000.service || true

echo
echo "=== ENABLED / ACTIVE ==="
systemctl --user is-enabled trfmc-readonly-backend-8000.service || true
systemctl --user is-active trfmc-readonly-backend-8000.service || true

echo
echo "=== PORTS ==="
ss -ltnp | grep -E ':8000|:4181' || true

echo
echo "=== DIRECT 8000 ==="
for u in \
  /api/health \
  /api/mission/status \
  /api/core/open5gs/status \
  /api/ran/ueransim/status \
  /api/runtime/services
do
  echo
  echo "--- http://127.0.0.1:8000\$u"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:8000\$u" | head -c 700
  echo
done

echo
echo "=== PROXY 4181 ==="
for u in \
  /api/mission/status \
  /api/core/open5gs/status \
  /api/ran/ueransim/status \
  /api/network-fabric/overview \
  /api/evidence/index
do
  echo
  echo "--- http://127.0.0.1:4181\$u"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181\$u" | head -c 700
  echo
done

echo
echo "=== JOURNAL LAST 60 ==="
journalctl --user -u trfmc-readonly-backend-8000.service --no-pager -n 60 || true
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_start_v29.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail
systemctl --user start trfmc-readonly-backend-8000.service
"$ROOT/runtime/bin/trfmc_readonly_backend_systemd_status_v29.sh"
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_stop_v29.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail
systemctl --user stop trfmc-readonly-backend-8000.service || true
ss -ltnp | grep ':8000' || true
SCRIPT

chmod +x \
  "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_status_v29.sh" \
  "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_start_v29.sh" \
  "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_stop_v29.sh"

echo
echo "=== HTTP GATE DIRECT + PROXY ==="

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

for base in http://127.0.0.1:8000 http://127.0.0.1:4181
do
  probe "$base/api/health"
  probe "$base/api/mission/status"
  probe "$base/api/runtime/services"
  probe "$base/api/core/open5gs/status"
  probe "$base/api/ran/ueransim/status"
  probe "$base/api/network-fabric/overview"
  probe "$base/api/rf-coverage/demo"
  probe "$base/api/rf-field/demo"
  probe "$base/api/telco-mns/status"
  probe "$base/api/evidence/index"
  probe "$base/api/restricted/status"
done

column -t -s $'\t' "$HTTP_TSV"

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$UNIT" && echo "OK: backend systemd unit" || echo "MISS: backend systemd unit"
  grep -q "backend.readonly_bridge_v28.app:app" "$UNIT" && echo "OK: uvicorn app module in unit" || echo "MISS: uvicorn app module in unit"
  grep -q "$PY" "$UNIT" && echo "OK: unit uses project venv python" || echo "MISS: unit uses project venv python"

  test -x "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_status_v29.sh" && echo "OK: status script" || echo "MISS: status script"
  test -x "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_start_v29.sh" && echo "OK: start script" || echo "MISS: start script"
  test -x "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_stop_v29.sh" && echo "OK: stop script" || echo "MISS: stop script"

  systemctl --user is-enabled --quiet trfmc-readonly-backend-8000.service && echo "OK: backend service enabled" || echo "MISS: backend service enabled"
  systemctl --user is-active --quiet trfmc-readonly-backend-8000.service && echo "OK: backend service active" || echo "MISS: backend service active"

  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:8000/api/health >/dev/null && echo "OK: direct 8000 health" || echo "MISS: direct 8000 health"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/api/ran/ueransim/status >/dev/null && echo "OK: proxy 4181 ran ueransim" || echo "MISS: proxy 4181 ran ueransim"

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

MANIFEST="$RELEASE_DIR/readonly_backend_systemd_manifest_v29.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_READONLY_BACKEND_SYSTEMD_PACK_V29",
  "backend_url": "http://127.0.0.1:8000/",
  "proxy_url": "http://127.0.0.1:4181/",
  "unit": "$UNIT",
  "venv_python": "$PY",
  "app_module": "backend.readonly_bridge_v28.app:app",
  "control_scripts": {
    "status": "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_status_v29.sh",
    "start": "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_start_v29.sh",
    "stop": "$ROOT/runtime/bin/trfmc_readonly_backend_systemd_stop_v29.sh"
  },
  "safety": {
    "read_only_backend": true,
    "no_open5gs_start_stop": true,
    "no_ueransim_start_stop": true,
    "no_sdr_tx_control": true,
    "no_frontend_mutation": true,
    "no_dist_mutation": true,
    "no_nginx_mutation": true
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  "$UNIT" \
  runtime/bin/trfmc_readonly_backend_systemd_status_v29.sh \
  runtime/bin/trfmc_readonly_backend_systemd_start_v29.sh \
  runtime/bin/trfmc_readonly_backend_systemd_stop_v29.sh \
  backend/readonly_bridge_v28 \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_READONLY_BACKEND_SYSTEMD_PACK_V29",
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

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_readonly_backend_systemd_pack_v29"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_readonly_backend_systemd_pack_v29"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V29 READ-ONLY BACKEND SYSTEMD PACK COMPLETATO"
echo "Status: runtime/bin/trfmc_readonly_backend_systemd_status_v29.sh"
echo "============================================================"
