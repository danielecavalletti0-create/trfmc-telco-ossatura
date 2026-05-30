#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/recovery/FRONTEND_5173_RECOVERY_$TS"

mkdir -p "$OUT" "$BASE/runtime/logs" "$BASE/runtime/recovery"

echo "============================================================"
echo "TRFMC FRONTEND 5173 RECOVERY AFTER CRASH"
echo "solo frontend · no backend · no discovery pesante"
echo "============================================================"

cd "$BASE"

echo
echo "[1/7] Stop porte frontend residue"
for P in 5173 8080; do
  PIDS="$(lsof -ti tcp:$P 2>/dev/null || true)"
  if [ -n "$PIDS" ]; then
    echo "Kill porta $P: $PIDS"
    kill $PIDS 2>/dev/null || true
  else
    echo "Porta $P libera"
  fi
done

sleep 2

echo
echo "[2/7] Controllo file essenziali"
{
  ls -lh "$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
  ls -lh "$PUBLIC/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html"
  ls -lh "$PUBLIC/trfmc_core_network_live_ops_bridge_v1.html"
  ls -lh "$PUBLIC/vendor/three/build/three.module.js"
} | tee "$OUT/key_files.txt"

echo
echo "[3/7] Controllo Node/NPM"
{
  echo "node: $(node -v 2>/dev/null || echo MISSING)"
  echo "npm:  $(npm -v 2>/dev/null || echo MISSING)"
  echo
  echo "package.json:"
  ls -lh "$FRONT/package.json" 2>/dev/null || true
} | tee "$OUT/node_npm.txt"

echo
echo "[4/7] Avvio Vite 5173 strict"
if [ -d "$FRONT" ] && [ -f "$FRONT/package.json" ]; then
  nohup bash -lc "
    cd '$FRONT'
    if [ -d node_modules/.bin ]; then
      ./node_modules/.bin/vite --host 127.0.0.1 --port 5173 --strictPort
    else
      npx vite --host 127.0.0.1 --port 5173 --strictPort
    fi
  " > "$BASE/runtime/logs/frontend_5173_recovery_vite.log" 2>&1 &
else
  echo "WARN: frontend/package.json non trovato, salto Vite"
fi

sleep 8

probe() {
  local url="$1"
  local r code bytes
  r="$(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "$url" 2>/dev/null || true)"
  code="$(echo "$r" | awk '{print $1}')"
  bytes="$(echo "$r" | awk '{print $2}')"
  [ -n "$code" ] || code="000"
  [ -n "$bytes" ] || bytes="0"
  echo "$code $bytes"
}

echo
echo "[5/7] Gate Vite"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
    /trfmc_core_network_live_ops_bridge_v1.html \
    /vendor/three/build/three.module.js
  do
    read -r code bytes < <(probe "http://127.0.0.1:5173$u")
    echo -e "$u\t$code\t$bytes"
  done
} | tee "$OUT/http_vite.tsv"

NON200="$(awk -F'\t' 'NR>1 && $2!="200"{n++} END{print n+0}' "$OUT/http_vite.tsv")"

if [ "$NON200" != "0" ]; then
  echo
  echo "[6/7] Vite non OK: fallback static server su 5173"
  PIDS="$(lsof -ti tcp:5173 2>/dev/null || true)"
  [ -n "$PIDS" ] && kill $PIDS 2>/dev/null || true
  sleep 2

  nohup bash -lc "
    cd '$PUBLIC'
    exec python3 -m http.server 5173 --bind 127.0.0.1
  " > "$BASE/runtime/logs/frontend_5173_recovery_static.log" 2>&1 &

  sleep 5

  {
    echo -e "url\tstatus\tbytes"
    for u in \
      /trfmc_official_safe_entrypoint_v6r3_command_center.html \
      /trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
      /trfmc_core_network_live_ops_bridge_v1.html \
      /vendor/three/build/three.module.js
    do
      read -r code bytes < <(probe "http://127.0.0.1:5173$u")
      echo -e "$u\t$code\t$bytes"
    done
  } | tee "$OUT/http_static.tsv"
else
  echo
  echo "[6/7] Vite OK, fallback non necessario"
  cp "$OUT/http_vite.tsv" "$OUT/http_static.tsv"
fi

echo
echo "[7/7] Report finale"
{
  echo "=== PORTS ==="
  ss -ltnup 2>/dev/null | egrep '(:5173|:8080|:8000)' || true
  echo
  echo "=== VITE LOG ==="
  tail -n 120 "$BASE/runtime/logs/frontend_5173_recovery_vite.log" 2>/dev/null || true
  echo
  echo "=== STATIC LOG ==="
  tail -n 80 "$BASE/runtime/logs/frontend_5173_recovery_static.log" 2>/dev/null || true
} | tee "$OUT/final_report.txt"

echo
echo "============================================================"
echo "FRONTEND RECOVERY COMPLETATO"
echo "Report:"
echo "$OUT"
echo
echo "Apri ora:"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
echo "============================================================"
