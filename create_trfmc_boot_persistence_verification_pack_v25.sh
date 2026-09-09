#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_BOOT_PERSISTENCE_VERIFICATION_PACK_V25_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_BOOT_PERSISTENCE_VERIFICATION_PACK_V25_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_BOOT_PERSISTENCE_VERIFICATION_PACK_V25_$TS.tar.gz"

echo "============================================================"
echo "TRFMC BOOT PERSISTENCE VERIFICATION PACK V25"
echo "systemd --user enabled state · linger · HTTP · journal · reboot checklist"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes" "$ROOT/runtime/bin"

echo
echo "=== PREFLIGHT ==="

test -f "$ROOT/runtime/quality/latest_systemd_user_service_pack_v24/summary.json" || {
  echo "ERRORE: V24 summary mancante"
  exit 1
}

for unit in \
  "$HOME/.config/systemd/user/trfmc-static-4180.service" \
  "$HOME/.config/systemd/user/trfmc-api-proxy-4181.service" \
  "$HOME/.config/systemd/user/trfmc-clean-offline-4182.service"
do
  test -f "$unit" || { echo "ERRORE: unit mancante: $unit"; exit 1; }
done

echo "OK: V24 presente e unit file esistenti"

echo
echo "=== CREA POST-BOOT VERIFY SCRIPT ==="

cat > "$ROOT/runtime/bin/trfmc_boot_persistence_verify_v25.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"
USER_NAME="\${USER:-$(whoami)}"

echo "============================================================"
echo "TRFMC BOOT PERSISTENCE VERIFY V25"
echo "============================================================"

echo
echo "=== USER / LINGER ==="
echo "USER=\$USER_NAME"
loginctl show-user "\$USER_NAME" -p Linger -p State -p RuntimePath 2>/dev/null || true

echo
echo "=== SYSTEMD USER ENABLED ==="
systemctl --user is-enabled trfmc-static-4180.service trfmc-api-proxy-4181.service trfmc-clean-offline-4182.service || true

echo
echo "=== SYSTEMD USER ACTIVE ==="
systemctl --user is-active trfmc-static-4180.service trfmc-api-proxy-4181.service trfmc-clean-offline-4182.service || true

echo
echo "=== SYSTEMD USER STATUS COMPACT ==="
systemctl --user --no-pager --full status trfmc-static-4180.service trfmc-api-proxy-4181.service trfmc-clean-offline-4182.service || true

echo
echo "=== PORTS ==="
ss -ltnp | grep -E ':4180|:4181|:4182' || true

echo
echo "=== HTTP MATRIX ==="
printf "%-12s %-8s %-10s %-60s\n" "service" "status" "bytes" "url"

probe() {
  local name="\$1"
  local url="\$2"
  local meta code bytes
  meta="\$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 6 "\$url" 2>/dev/null || printf "000\t0")"
  code="\${meta%%	*}"
  bytes="\${meta#*	}"
  printf "%-12s %-8s %-10s %-60s\n" "\$name" "\$code" "\$bytes" "\$url"
}

probe "static4180" "http://127.0.0.1:4180/"
probe "proxy4181" "http://127.0.0.1:4181/"
probe "offline4182" "http://127.0.0.1:4182/"
probe "health4182" "http://127.0.0.1:4182/api/health"
probe "api4182" "http://127.0.0.1:4182/api/mission/status"

echo
echo "=== JOURNAL LAST 80 LINES ==="
journalctl --user -u trfmc-static-4180.service -u trfmc-api-proxy-4181.service -u trfmc-clean-offline-4182.service --no-pager -n 80 || true

echo
echo "=== FINAL VERDICT HINT ==="
echo "Expected: Linger=yes, all three enabled, all three active, ports 4180/4181/4182 listening, HTTP 200."
SCRIPT

chmod +x "$ROOT/runtime/bin/trfmc_boot_persistence_verify_v25.sh"

echo
echo "=== ESEGUO VERIFICA CORRENTE ==="

CURRENT_STATUS="$RELEASE_DIR/current_boot_persistence_status_v25.txt"
"$ROOT/runtime/bin/trfmc_boot_persistence_verify_v25.sh" | tee "$CURRENT_STATUS"

echo
echo "=== CREA REBOOT CHECKLIST ==="

CHECKLIST="$RELEASE_DIR/reboot_checklist_v25.md"

cat > "$CHECKLIST" <<MD
# TRFMC V25 Boot Persistence Verification

## Stato atteso dopo reboot

Aprire un terminale e lanciare:

\`\`\`bash
cd $ROOT
runtime/bin/trfmc_boot_persistence_verify_v25.sh
\`\`\`

## Criteri PASS

- \`loginctl show-user \$USER -p Linger\` deve mostrare \`Linger=yes\`.
- \`systemctl --user is-enabled trfmc-static-4180.service trfmc-api-proxy-4181.service trfmc-clean-offline-4182.service\` deve restituire \`enabled\` per tutti e tre.
- \`systemctl --user is-active ...\` deve restituire \`active\` per tutti e tre.
- \`ss -ltnp\` deve mostrare porte \`4180\`, \`4181\`, \`4182\`.
- I seguenti URL devono rispondere HTTP 200:
  - http://127.0.0.1:4180/
  - http://127.0.0.1:4181/
  - http://127.0.0.1:4182/
  - http://127.0.0.1:4182/api/health
  - http://127.0.0.1:4182/api/mission/status

## Comandi utili

Start manuale:

\`\`\`bash
runtime/bin/trfmc_systemd_user_start_v24.sh
\`\`\`

Stop manuale:

\`\`\`bash
runtime/bin/trfmc_systemd_user_stop_v24.sh
\`\`\`

Status systemd:

\`\`\`bash
runtime/bin/trfmc_systemd_user_status_v24.sh
\`\`\`

Status boot persistence:

\`\`\`bash
runtime/bin/trfmc_boot_persistence_verify_v25.sh
\`\`\`
MD

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -x "$ROOT/runtime/bin/trfmc_boot_persistence_verify_v25.sh" && echo "OK: boot persistence verify script" || echo "MISS: boot persistence verify script"
  test -f "$CURRENT_STATUS" && echo "OK: current status capture" || echo "MISS: current status capture"
  test -f "$CHECKLIST" && echo "OK: reboot checklist" || echo "MISS: reboot checklist"

  systemctl --user is-enabled --quiet trfmc-static-4180.service && echo "OK: 4180 enabled" || echo "MISS: 4180 enabled"
  systemctl --user is-enabled --quiet trfmc-api-proxy-4181.service && echo "OK: 4181 enabled" || echo "MISS: 4181 enabled"
  systemctl --user is-enabled --quiet trfmc-clean-offline-4182.service && echo "OK: 4182 enabled" || echo "MISS: 4182 enabled"

  systemctl --user is-active --quiet trfmc-static-4180.service && echo "OK: 4180 active" || echo "MISS: 4180 active"
  systemctl --user is-active --quiet trfmc-api-proxy-4181.service && echo "OK: 4181 active" || echo "MISS: 4181 active"
  systemctl --user is-active --quiet trfmc-clean-offline-4182.service && echo "OK: 4182 active" || echo "MISS: 4182 active"

  loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes' && echo "OK: linger enabled" || echo "MISS: linger enabled"

  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4180/ >/dev/null && echo "OK: 4180 HTTP" || echo "MISS: 4180 HTTP"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/ >/dev/null && echo "OK: 4181 HTTP" || echo "MISS: 4181 HTTP"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4182/ >/dev/null && echo "OK: 4182 HTTP" || echo "MISS: 4182 HTTP"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4182/api/health >/dev/null && echo "OK: 4182 API health" || echo "MISS: 4182 API health"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/boot_persistence_manifest_v25.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BOOT_PERSISTENCE_VERIFICATION_PACK_V25",
  "release_dir": "$RELEASE_DIR",
  "verify_script": "$ROOT/runtime/bin/trfmc_boot_persistence_verify_v25.sh",
  "current_status_capture": "$CURRENT_STATUS",
  "reboot_checklist": "$CHECKLIST",
  "content_checks": "$CONTENT_CHECK",
  "expected_services": [
    "trfmc-static-4180.service",
    "trfmc-api-proxy-4181.service",
    "trfmc-clean-offline-4182.service"
  ],
  "expected_urls": [
    "http://127.0.0.1:4180/",
    "http://127.0.0.1:4181/",
    "http://127.0.0.1:4182/",
    "http://127.0.0.1:4182/api/health",
    "http://127.0.0.1:4182/api/mission/status"
  ],
  "source_mutation": false,
  "dist_mutation": false,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  runtime/bin/trfmc_boot_persistence_verify_v25.sh \
  "$RELEASE_DIR" \
  "$HOME/.config/systemd/user/trfmc-static-4180.service" \
  "$HOME/.config/systemd/user/trfmc-api-proxy-4181.service" \
  "$HOME/.config/systemd/user/trfmc-clean-offline-4182.service" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BOOT_PERSISTENCE_VERIFICATION_PACK_V25",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "verify_script": "$ROOT/runtime/bin/trfmc_boot_persistence_verify_v25.sh",
  "reboot_checklist": "$CHECKLIST",
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_boot_persistence_verification_pack_v25"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_boot_persistence_verification_pack_v25"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V25 BOOT PERSISTENCE VERIFICATION PACK COMPLETATO"
echo "Verify now/after reboot:"
echo "runtime/bin/trfmc_boot_persistence_verify_v25.sh"
echo "============================================================"
