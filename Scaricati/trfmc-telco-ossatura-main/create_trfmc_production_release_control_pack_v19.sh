#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
FRONTEND="$ROOT/frontend"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_PRODUCTION_RELEASE_CONTROL_PACK_V19_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_PRODUCTION_RELEASE_CONTROL_PACK_V19_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_PRODUCTION_RELEASE_CONTROL_PACK_V19_$TS.tar.gz"

echo "============================================================"
echo "TRFMC PRODUCTION RELEASE CONTROL PACK V19"
echo "manifest · checksums · dist inventory · start/stop/status"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes" "$ROOT/runtime/bin"

echo
echo "=== PREFLIGHT ==="

test -d "$FRONTEND" || { echo "ERRORE: frontend mancante"; exit 1; }
test -f "$FRONTEND/package.json" || { echo "ERRORE: package.json mancante"; exit 1; }
test -d "$FRONTEND/dist" || { echo "ERRORE: frontend/dist mancante"; exit 1; }
test -f "$FRONTEND/dist/index.html" || { echo "ERRORE: dist/index.html mancante"; exit 1; }
test -f "$FRONTEND/src/app/main.tsx" || { echo "ERRORE: main.tsx mancante"; exit 1; }

grep -q "RFOperationalDeckV16ChunkObservatory" "$FRONTEND/src/app/main.tsx" || {
  echo "ERRORE: main.tsx non monta RFOperationalDeckV16ChunkObservatory"
  exit 1
}

echo "OK: dist production presente e V16 montato"

echo
echo "=== DIST INVENTORY ==="

DIST_TSV="$RELEASE_DIR/dist_inventory.tsv"
DIST_SHA="$RELEASE_DIR/dist_sha256.txt"

{
  echo -e "type\tpath\tbytes"
  find "$FRONTEND/dist" -type f | sort | while read -r f; do
    rel="${f#$FRONTEND/}"
    case "$f" in
      *.js) typ="js" ;;
      *.css) typ="css" ;;
      *.html) typ="html" ;;
      *.json) typ="json" ;;
      *) typ="asset" ;;
    esac
    bytes="$(stat -c '%s' "$f")"
    echo -e "$typ\t$rel\t$bytes"
  done
} > "$DIST_TSV"

(
  cd "$FRONTEND"
  find dist -type f | sort | xargs -r sha256sum
) > "$DIST_SHA"

JS_COUNT="$(awk -F '\t' '$1=="js"{c++} END{print c+0}' "$DIST_TSV")"
CSS_COUNT="$(awk -F '\t' '$1=="css"{c++} END{print c+0}' "$DIST_TSV")"
HTML_COUNT="$(awk -F '\t' '$1=="html"{c++} END{print c+0}' "$DIST_TSV")"
TOTAL_BYTES="$(awk -F '\t' 'NR>1{s+=$3} END{print s+0}' "$DIST_TSV")"

column -t -s $'\t' "$DIST_TSV" | sed -n '1,120p'

echo
echo "=== RELEASE CONTROL SCRIPTS ==="

cat > "$ROOT/runtime/bin/trfmc_prod_preview_start_4173.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$FRONTEND"

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:4173/ >/dev/null 2>&1; then
  echo "OK: production preview already reachable at http://127.0.0.1:4173/"
  ss -ltnp | grep ':4173' || true
  exit 0
fi

mkdir -p "$ROOT/runtime/logs"
LOG="$ROOT/runtime/logs/trfmc_prod_preview_4173_\$(date +%Y%m%d_%H%M%S).log"

nohup npm run preview -- --host 127.0.0.1 --port 4173 --strictPort > "\$LOG" 2>&1 &
PID=\$!

echo "\$PID" > "$ROOT/runtime/trfmc_prod_preview_4173.pid"

sleep 2

if curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:4173/ >/dev/null 2>&1; then
  echo "OK: production preview started"
  echo "URL: http://127.0.0.1:4173/"
  echo "PID: \$PID"
  echo "LOG: \$LOG"
else
  echo "ERRORE: production preview not reachable"
  echo "PID: \$PID"
  echo "LOG: \$LOG"
  tail -n 80 "\$LOG" || true
  exit 1
fi
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_prod_preview_stop_4173.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

if [ -f "$ROOT/runtime/trfmc_prod_preview_4173.pid" ]; then
  PID="\$(cat "$ROOT/runtime/trfmc_prod_preview_4173.pid")"
  if ps -p "\$PID" >/dev/null 2>&1; then
    kill "\$PID" || true
    sleep 1
  fi
fi

pkill -f "vite preview.*4173" 2>/dev/null || true

echo "OK: production preview stop requested"
ss -ltnp | grep ':4173' || true
SCRIPT

cat > "$ROOT/runtime/bin/trfmc_prod_preview_status_4173.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== PORT 4173 ==="
ss -ltnp | grep ':4173' || true

echo
echo "=== HTTP ==="
curl -I --connect-timeout 2 --max-time 6 http://127.0.0.1:4173/ || true

echo
echo "=== DIST ASSETS ==="
find "$FRONTEND/dist/assets" -maxdepth 1 -type f \( -name '*.js' -o -name '*.css' \) | sort | sed -n '1,40p'
SCRIPT

chmod +x \
  "$ROOT/runtime/bin/trfmc_prod_preview_start_4173.sh" \
  "$ROOT/runtime/bin/trfmc_prod_preview_stop_4173.sh" \
  "$ROOT/runtime/bin/trfmc_prod_preview_status_4173.sh"

echo "OK: runtime/bin scripts created"

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$FRONTEND/dist/index.html" && echo "OK: dist/index.html" || echo "MISS: dist/index.html"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'index-*.js' | grep -q . \
    && echo "OK: main index JS chunk" || echo "MISS: main index JS chunk"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'index-*.css' | grep -q . \
    && echo "OK: main index CSS chunk" || echo "MISS: main index CSS chunk"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'RFInstrumentSuiteV5-*.js' | grep -q . \
    && echo "OK: lazy RFInstrumentSuiteV5 chunk" || echo "MISS: lazy RFInstrumentSuiteV5 chunk"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'RFSourceBridgePanelV7-*.js' | grep -q . \
    && echo "OK: lazy RFSourceBridgePanelV7 chunk" || echo "MISS: lazy RFSourceBridgePanelV7 chunk"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'RFSourceRuntimeProbeV8-*.js' | grep -q . \
    && echo "OK: lazy RFSourceRuntimeProbeV8 chunk" || echo "MISS: lazy RFSourceRuntimeProbeV8 chunk"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'RFBridgeReadinessV9-*.js' | grep -q . \
    && echo "OK: lazy RFBridgeReadinessV9 chunk" || echo "MISS: lazy RFBridgeReadinessV9 chunk"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'RFEvidenceFlightRecorderV10-*.js' | grep -q . \
    && echo "OK: lazy RFEvidenceFlightRecorderV10 chunk" || echo "MISS: lazy RFEvidenceFlightRecorderV10 chunk"

  find "$FRONTEND/dist/assets" -maxdepth 1 -type f -name 'RFSignalDspWorkerV3-*.js' | grep -q . \
    && echo "OK: RFSignalDspWorkerV3 worker chunk" || echo "MISS: RFSignalDspWorkerV3 worker chunk"

  test -x "$ROOT/runtime/bin/trfmc_prod_preview_start_4173.sh" && echo "OK: start script" || echo "MISS: start script"
  test -x "$ROOT/runtime/bin/trfmc_prod_preview_stop_4173.sh" && echo "OK: stop script" || echo "MISS: stop script"
  test -x "$ROOT/runtime/bin/trfmc_prod_preview_status_4173.sh" && echo "OK: status script" || echo "MISS: status script"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

echo
echo "=== RELEASE MANIFEST ==="

MANIFEST="$RELEASE_DIR/release_manifest_v19.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_PRODUCTION_RELEASE_CONTROL_PACK_V19",
  "project_root": "$ROOT",
  "frontend_root": "$FRONTEND",
  "production_preview_url": "http://127.0.0.1:4173/",
  "dev_url": "http://127.0.0.1:5173/",
  "mounted": "RFOperationalDeckV16ChunkObservatory",
  "validated_previous_gate": "TRFMC_RF_PRODUCTION_PREVIEW_GATE_V18R2_RUNTIME_OK",
  "dist": {
    "html_files": $HTML_COUNT,
    "js_files": $JS_COUNT,
    "css_files": $CSS_COUNT,
    "total_bytes": $TOTAL_BYTES
  },
  "artifacts": {
    "dist_inventory": "$DIST_TSV",
    "dist_sha256": "$DIST_SHA",
    "content_checks": "$CONTENT_CHECK"
  },
  "control_scripts": {
    "start": "$ROOT/runtime/bin/trfmc_prod_preview_start_4173.sh",
    "stop": "$ROOT/runtime/bin/trfmc_prod_preview_stop_4173.sh",
    "status": "$ROOT/runtime/bin/trfmc_prod_preview_status_4173.sh"
  },
  "safety": {
    "source_mutation": false,
    "dist_rebuild": false,
    "open5gs_mutation": false,
    "sdr_control": false
  },
  "miss_count": $MISS_COUNT,
  "result": "$([ "$MISS_COUNT" -eq 0 ] && echo PASS || echo FAIL)"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE RELEASE PACK ==="

tar -czf "$FREEZE" \
  frontend/index.html \
  frontend/package.json \
  frontend/dist \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/rf_instruments \
  runtime/bin/trfmc_prod_preview_start_4173.sh \
  runtime/bin/trfmc_prod_preview_stop_4173.sh \
  runtime/bin/trfmc_prod_preview_status_4173.sh \
  "$RELEASE_DIR" \
  2>/dev/null || true

echo "Freeze: $FREEZE"

echo
echo "=== QUALITY SUMMARY ==="

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_PRODUCTION_RELEASE_CONTROL_PACK_V19",
  "release_dir": "$RELEASE_DIR",
  "release_manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "dist_inventory": "$DIST_TSV",
  "dist_sha256": "$DIST_SHA",
  "miss_count": $MISS_COUNT,
  "start_script": "$ROOT/runtime/bin/trfmc_prod_preview_start_4173.sh",
  "stop_script": "$ROOT/runtime/bin/trfmc_prod_preview_stop_4173.sh",
  "status_script": "$ROOT/runtime/bin/trfmc_prod_preview_status_4173.sh",
  "result": "$([ "$MISS_COUNT" -eq 0 ] && echo PASS || echo FAIL)"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_production_release_control_pack_v19"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_production_release_control_pack_v19"

cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V19 RELEASE CONTROL PACK COMPLETATO"
echo "Start : runtime/bin/trfmc_prod_preview_start_4173.sh"
echo "Stop  : runtime/bin/trfmc_prod_preview_stop_4173.sh"
echo "Status: runtime/bin/trfmc_prod_preview_status_4173.sh"
echo "============================================================"
