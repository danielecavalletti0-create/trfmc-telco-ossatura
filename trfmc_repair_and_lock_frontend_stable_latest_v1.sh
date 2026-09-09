#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_POST_CRASH_FRONTEND_STABLE_LOCK_$TS"
LATEST="$BASE/runtime/quality/latest_post_crash_frontend_stable_lock"

mkdir -p "$OUT" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC REPAIR + FRONTEND STABLE LOCK"
echo "creo report mancante + latest assoluto"
echo "============================================================"

cd "$BASE"

echo
echo "[1/6] Controllo Vite/porta 5173"
ss -ltnup 2>/dev/null | egrep '(:5173)' || {
  echo "WARN: porta 5173 non in ascolto. Rilancio Vite..."
  nohup bash -lc "
    cd '$BASE/frontend'
    if [ -x node_modules/.bin/vite ]; then
      ./node_modules/.bin/vite --host 127.0.0.1 --port 5173 --strictPort
    else
      npx vite --host 127.0.0.1 --port 5173 --strictPort
    fi
  " > "$BASE/runtime/logs/frontend_5173_lock_repair.log" 2>&1 &
  sleep 6
}

echo
echo "[2/6] HTTP gate frontend"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
    /trfmc_core_network_live_ops_bridge_v1.html \
    /vendor/three/build/three.module.js \
    /vendor/three/examples/jsm/controls/OrbitControls.js
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" || echo "000 0")
    echo -e "$u\t$code\t$bytes"
  done
} | tee "$OUT/http.tsv"

echo
echo "[3/6] No nested shell iframe"
grep -nEi '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html \
  frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
  frontend/public/trfmc_core_network_live_ops_bridge_v1.html \
  > "$OUT/nested_shell_iframe_refs.txt" 2>/dev/null || true

echo
echo "[4/6] No external CDN/remote refs"
grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' \
  frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html \
  frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
  frontend/public/trfmc_core_network_live_ops_bridge_v1.html \
  > "$OUT/external_refs_raw.txt" 2>/dev/null || true

# Mantengo solo riferimenti davvero esterni, non localhost/127 se presenti come testo operativo.
grep -vE '127\.0\.0\.1|localhost' "$OUT/external_refs_raw.txt" > "$OUT/external_refs.txt" 2>/dev/null || true

echo
echo "[5/6] Summary + latest symlink assoluto"
export OUT
python3 - <<'PY'
import json, os
from pathlib import Path
from datetime import datetime, timezone

out = Path(os.environ["OUT"])

http_non_200 = 0
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 2 and p[1].strip() != "200":
        http_non_200 += 1

nested = sum(1 for x in (out / "nested_shell_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
external = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "v6r3": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "webgl_v2r2": "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html",
    "core_page": "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html",
    "backend_core_live": "isolated_not_started",
    "http_non_200": http_non_200,
    "nested_shell_iframe_refs": nested,
    "external_refs": external,
    "result": "PASS" if http_non_200 == 0 and nested == 0 and external == 0 else "WARN"
}

(out / "summary.json").write_text(json.dumps(data, indent=4) + "\n")
(out / "result.flag").write_text(data["result"] + "\n")
print(json.dumps(data, indent=4))
PY

ln -sfn "$OUT" "$LATEST"

echo
echo "[6/6] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_POST_CRASH_FRONTEND_STABLE_LOCK_$TS.tar.gz"

  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .

  echo "=== FREEZE CREATO ==="
  ls -lh "$FREEZE"
else
  echo "WARN: freeze non creato perché il gate non è PASS"
fi

echo
echo "=== SUMMARY ==="
cat "$LATEST/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$LATEST/http.tsv"

echo
echo "=== EXTERNAL ==="
cat "$LATEST/external_refs.txt"

echo
echo "=== NESTED ==="
cat "$LATEST/nested_shell_iframe_refs.txt"

echo
echo "============================================================"
echo "LOCK RIPARATO"
echo "Latest:"
echo "$LATEST"
echo
echo "Apri V6R3:"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
echo "============================================================"
