#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_POST_CRASH_FRONTEND_STABLE_LOCK_$TS"

mkdir -p "$OUT" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC POST-CRASH FRONTEND STABLE LOCK"
echo "V6R3 + WebGL V2R2 + Core page served, backend Core Live still isolated"
echo "============================================================"

cd "$BASE"

echo
echo "[1/5] Gate HTTP frontend stabile"
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
echo "[2/5] Gate no external refs sulle pagine principali"
grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' \
  frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html \
  frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
  frontend/public/trfmc_core_network_live_ops_bridge_v1.html \
  > "$OUT/external_refs.txt" 2>/dev/null || true

echo
echo "[3/5] Gate no nested shell iframe"
grep -nEi '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html \
  frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
  frontend/public/trfmc_core_network_live_ops_bridge_v1.html \
  > "$OUT/nested_shell_iframe_refs.txt" 2>/dev/null || true

echo
echo "[4/5] Summary JSON"
export OUT
python3 - <<'PY'
import json, os
from pathlib import Path
from datetime import datetime, timezone

out = Path(os.environ["OUT"])

http_non_200 = 0
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 2 and p[1] != "200":
        http_non_200 += 1

external = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
nested = sum(1 for x in (out / "nested_shell_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "v6r3": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "webgl_v2r2": "http://127.0.0.1:5173/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html",
    "core_page": "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html",
    "backend_core_live": "isolated_not_started",
    "http_non_200": http_non_200,
    "external_refs": external,
    "nested_shell_iframe_refs": nested,
    "result": "PASS" if http_non_200 == 0 and external == 0 and nested == 0 else "WARN"
}

(out / "summary.json").write_text(json.dumps(data, indent=4) + "\n")
(out / "result.flag").write_text(data["result"] + "\n")
print(json.dumps(data, indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_post_crash_frontend_stable_lock"

echo
echo "[5/5] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_POST_CRASH_FRONTEND_STABLE_LOCK_$TS.tar.gz"

  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .

  echo
  echo "=== FREEZE CREATO ==="
  ls -lh "$FREEZE"
fi

echo
echo "=== SUMMARY ==="
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== EXTERNAL ==="
cat "$OUT/external_refs.txt"

echo
echo "=== NESTED ==="
cat "$OUT/nested_shell_iframe_refs.txt"

echo
echo "============================================================"
echo "FRONTEND POST-CRASH STABILE"
echo "Apri V6R3:"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
echo
echo "NON avviare ancora Core Live backend."
echo "============================================================"
