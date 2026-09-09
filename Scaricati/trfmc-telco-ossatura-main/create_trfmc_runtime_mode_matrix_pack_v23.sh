#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_RUNTIME_MODE_MATRIX_PACK_V23_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_RUNTIME_MODE_MATRIX_PACK_V23_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_RUNTIME_MODE_MATRIX_PACK_V23_$TS.tar.gz"

echo "============================================================"
echo "TRFMC RUNTIME MODE MATRIX PACK V23"
echo "runtime matrix · service status · control scripts · release dossier"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/bin" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -d "$ROOT/frontend" || { echo "ERRORE: frontend mancante"; exit 1; }
test -f "$ROOT/frontend/src/app/main.tsx" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -d "$ROOT/frontend/dist" || { echo "ERRORE: frontend/dist mancante"; exit 1; }

grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" || {
  echo "ERRORE: RFOperationalDeckV16ChunkObservatory non montato"
  exit 1
}

echo "OK: progetto, dist e V16 presenti"

echo
echo "=== CREA STATUS MATRIX SCRIPT ==="

cat > "$ROOT/runtime/bin/trfmc_runtime_matrix_status_v23.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"

echo "============================================================"
echo "TRFMC RUNTIME MATRIX STATUS V23"
echo "============================================================"

probe() {
  local name="\$1"
  local port="\$2"
  local url="\$3"
  local mode="\$4"
  local meta code bytes

  meta="\$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 5 "\$url" 2>/dev/null || printf "000\t0")"
  code="\${meta%%	*}"
  bytes="\${meta#*	}"

  printf "%-10s %-6s %-8s %-10s %-60s %s\n" "\$name" "\$port" "\$code" "\$bytes" "\$url" "\$mode"
}

echo
echo "=== PORTS ==="
ss -ltnp | grep -E ':5173|:4173|:4180|:4181|:4182|:8000|:8090' || true

echo
echo "=== HTTP MATRIX ==="
printf "%-10s %-6s %-8s %-10s %-60s %s\n" "name" "port" "status" "bytes" "url" "mode"
probe "vite-dev"    "5173" "http://127.0.0.1:5173/" "development"
probe "vite-prev"   "4173" "http://127.0.0.1:4173/" "dist-preview"
probe "static"      "4180" "http://127.0.0.1:4180/" "nginx-static"
probe "api-proxy"   "4181" "http://127.0.0.1:4181/" "nginx-static-proxy-fallback"
probe "offline"     "4182" "http://127.0.0.1:4182/" "nginx-clean-offline"
probe "backend"     "8000" "http://127.0.0.1:8000/api/health" "fastapi-optional"
probe "bridge"      "8090" "http://127.0.0.1:8090/api/health" "bridge-optional"

echo
echo "=== API MODE PROBES ==="
for base in \
  http://127.0.0.1:4180 \
  http://127.0.0.1:4181 \
  http://127.0.0.1:4182
do
  echo
  echo "--- \$base"
  for u in /api/health /api/mission/status /api/network-fabric/overview /api/rf-coverage/demo /api/restricted/status
  do
    printf "%-42s " "\$u"
    curl -sS --connect-timeout 2 --max-time 5 "\$base\$u" 2>/dev/null | head -c 180 || true
    echo
  done
done

echo
echo "=== LATEST GATES ==="
for f in \
  "$ROOT/runtime/quality/latest_rf_production_preview_gate_v18r2_runtime_ok/summary.json" \
  "$ROOT/runtime/quality/latest_production_release_control_pack_v19/summary.json" \
  "$ROOT/runtime/quality/latest_static_production_server_pack_v20/summary.json" \
  "$ROOT/runtime/quality/latest_static_api_gateway_pack_v21/summary.json" \
  "$ROOT/runtime/quality/latest_clean_offline_api_gateway_pack_v22/summary.json"
do
  echo
  echo "--- \$f"
  if [ -f "\$f" ]; then
    python3 -m json.tool "\$f" | sed -n '1,80p'
  else
    echo "MISSING"
  fi
done
SCRIPT

chmod +x "$ROOT/runtime/bin/trfmc_runtime_matrix_status_v23.sh"

echo
echo "=== CREA STOP ALL RUNTIME SCRIPT ==="

cat > "$ROOT/runtime/bin/trfmc_runtime_matrix_stop_all_v23.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"

echo "============================================================"
echo "TRFMC RUNTIME MATRIX STOP ALL V23"
echo "============================================================"

for s in \
  "\$ROOT/runtime/bin/trfmc_clean_offline_api_stop_4182.sh" \
  "\$ROOT/runtime/bin/trfmc_static_api_gateway_stop_4181.sh" \
  "\$ROOT/runtime/bin/trfmc_static_nginx_stop_4180.sh" \
  "\$ROOT/runtime/bin/trfmc_prod_preview_stop_4173.sh"
do
  if [ -x "\$s" ]; then
    echo
    echo "=== RUN \$s ==="
    "\$s" || true
  fi
done

pkill -f "vite --host 127.0.0.1 --port 5173" 2>/dev/null || true
pkill -f "vite.*5173" 2>/dev/null || true

echo
echo "=== PORTS AFTER STOP ==="
ss -ltnp | grep -E ':5173|:4173|:4180|:4181|:4182' || true
SCRIPT

chmod +x "$ROOT/runtime/bin/trfmc_runtime_matrix_stop_all_v23.sh"

echo
echo "=== CREA START PRODUCTION MATRIX SCRIPT ==="

cat > "$ROOT/runtime/bin/trfmc_runtime_matrix_start_production_v23.sh" <<SCRIPT
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$ROOT"

echo "============================================================"
echo "TRFMC RUNTIME MATRIX START PRODUCTION V23"
echo "============================================================"

for s in \
  "\$ROOT/runtime/bin/trfmc_static_nginx_start_4180.sh" \
  "\$ROOT/runtime/bin/trfmc_static_api_gateway_start_4181.sh" \
  "\$ROOT/runtime/bin/trfmc_clean_offline_api_start_4182.sh"
do
  if [ -x "\$s" ]; then
    echo
    echo "=== RUN \$s ==="
    "\$s"
  else
    echo "WARN: script mancante: \$s"
  fi
done

echo
"\$ROOT/runtime/bin/trfmc_runtime_matrix_status_v23.sh"
SCRIPT

chmod +x "$ROOT/runtime/bin/trfmc_runtime_matrix_start_production_v23.sh"

echo
echo "=== CREA TSV/JSON MATRIX ==="

MATRIX_TSV="$RELEASE_DIR/runtime_mode_matrix_v23.tsv"
MATRIX_JSON="$RELEASE_DIR/runtime_mode_matrix_v23.json"

cat > "$MATRIX_TSV" <<TSV
mode	port	url	purpose	mutation	notes
vite-dev	5173	http://127.0.0.1:5173/	Vite development server	source/live dev	hot reload and source debugging
vite-preview	4173	http://127.0.0.1:4173/	Vite dist preview	none	preview server for built dist
nginx-static	4180	http://127.0.0.1:4180/	static production serving	none	pure static dist serving
nginx-api-proxy	4181	http://127.0.0.1:4181/	static plus optional backend proxy/fallback	none	proxy to 8000 when online, JSON fallback otherwise
nginx-clean-offline	4182	http://127.0.0.1:4182/	static plus clean offline JSON fallback	none	no upstream noise, no backend proxy
backend-fastapi	8000	http://127.0.0.1:8000/api/health	optional backend API	backend state only	not required for offline/static modes
bridge-api	8090	http://127.0.0.1:8090/api/health	optional bridge/API layer	bridge state only	not required for clean offline mode
TSV

cat > "$MATRIX_JSON" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RUNTIME_MODE_MATRIX_PACK_V23",
  "modes": [
    {
      "name": "vite-dev",
      "port": 5173,
      "url": "http://127.0.0.1:5173/",
      "purpose": "Vite development server",
      "mutation": "source/live dev"
    },
    {
      "name": "vite-preview",
      "port": 4173,
      "url": "http://127.0.0.1:4173/",
      "purpose": "Vite dist preview",
      "mutation": "none"
    },
    {
      "name": "nginx-static",
      "port": 4180,
      "url": "http://127.0.0.1:4180/",
      "purpose": "static production serving",
      "mutation": "none"
    },
    {
      "name": "nginx-api-proxy",
      "port": 4181,
      "url": "http://127.0.0.1:4181/",
      "purpose": "static plus optional backend proxy/fallback",
      "mutation": "none"
    },
    {
      "name": "nginx-clean-offline",
      "port": 4182,
      "url": "http://127.0.0.1:4182/",
      "purpose": "static plus clean offline JSON fallback",
      "mutation": "none"
    },
    {
      "name": "backend-fastapi",
      "port": 8000,
      "url": "http://127.0.0.1:8000/api/health",
      "purpose": "optional backend API",
      "mutation": "backend state only"
    },
    {
      "name": "bridge-api",
      "port": 8090,
      "url": "http://127.0.0.1:8090/api/health",
      "purpose": "optional bridge/API layer",
      "mutation": "bridge state only"
    }
  ],
  "recommended_default_for_offline_demo": "http://127.0.0.1:4182/",
  "recommended_default_for_static_prod": "http://127.0.0.1:4180/",
  "recommended_default_for_backend_integration": "http://127.0.0.1:4181/"
}
JSON

echo
echo "=== RUN STATUS CAPTURE ==="

STATUS_TXT="$RELEASE_DIR/runtime_status_capture_v23.txt"
"$ROOT/runtime/bin/trfmc_runtime_matrix_status_v23.sh" | tee "$STATUS_TXT"

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -x "$ROOT/runtime/bin/trfmc_runtime_matrix_status_v23.sh" && echo "OK: status matrix script" || echo "MISS: status matrix script"
  test -x "$ROOT/runtime/bin/trfmc_runtime_matrix_stop_all_v23.sh" && echo "OK: stop all script" || echo "MISS: stop all script"
  test -x "$ROOT/runtime/bin/trfmc_runtime_matrix_start_production_v23.sh" && echo "OK: start production script" || echo "MISS: start production script"
  test -f "$MATRIX_TSV" && echo "OK: runtime mode matrix TSV" || echo "MISS: runtime mode matrix TSV"
  test -f "$MATRIX_JSON" && echo "OK: runtime mode matrix JSON" || echo "MISS: runtime mode matrix JSON"
  test -f "$STATUS_TXT" && echo "OK: status capture" || echo "MISS: status capture"
  grep -q "nginx-clean-offline" "$MATRIX_TSV" && echo "OK: 4182 clean offline mode documented" || echo "MISS: 4182 clean offline mode documented"
  grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" && echo "OK: V16 mount preserved" || echo "MISS: V16 mount preserved"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/runtime_mode_matrix_manifest_v23.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RUNTIME_MODE_MATRIX_PACK_V23",
  "release_dir": "$RELEASE_DIR",
  "runtime_mode_matrix_tsv": "$MATRIX_TSV",
  "runtime_mode_matrix_json": "$MATRIX_JSON",
  "status_capture": "$STATUS_TXT",
  "content_checks": "$CONTENT_CHECK",
  "control_scripts": {
    "status": "$ROOT/runtime/bin/trfmc_runtime_matrix_status_v23.sh",
    "stop_all": "$ROOT/runtime/bin/trfmc_runtime_matrix_stop_all_v23.sh",
    "start_production": "$ROOT/runtime/bin/trfmc_runtime_matrix_start_production_v23.sh"
  },
  "recommended_urls": {
    "development": "http://127.0.0.1:5173/",
    "vite_preview": "http://127.0.0.1:4173/",
    "static_production": "http://127.0.0.1:4180/",
    "api_proxy_gateway": "http://127.0.0.1:4181/",
    "clean_offline_gateway": "http://127.0.0.1:4182/"
  },
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
  runtime/bin/trfmc_runtime_matrix_status_v23.sh \
  runtime/bin/trfmc_runtime_matrix_stop_all_v23.sh \
  runtime/bin/trfmc_runtime_matrix_start_production_v23.sh \
  "$RELEASE_DIR" \
  frontend/src/app/main.tsx \
  frontend/dist \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RUNTIME_MODE_MATRIX_PACK_V23",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "status_script": "$ROOT/runtime/bin/trfmc_runtime_matrix_status_v23.sh",
  "stop_all_script": "$ROOT/runtime/bin/trfmc_runtime_matrix_stop_all_v23.sh",
  "start_production_script": "$ROOT/runtime/bin/trfmc_runtime_matrix_start_production_v23.sh",
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_runtime_mode_matrix_pack_v23"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_runtime_mode_matrix_pack_v23"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V23 RUNTIME MODE MATRIX PACK COMPLETATO"
echo "Status          : runtime/bin/trfmc_runtime_matrix_status_v23.sh"
echo "Start production: runtime/bin/trfmc_runtime_matrix_start_production_v23.sh"
echo "Stop all        : runtime/bin/trfmc_runtime_matrix_stop_all_v23.sh"
echo "============================================================"
