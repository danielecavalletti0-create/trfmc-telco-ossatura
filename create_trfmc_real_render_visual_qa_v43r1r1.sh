#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_REAL_RENDER_VISUAL_QA_V43R1R1_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_REAL_RENDER_VISUAL_QA_V43R1R1_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_REAL_RENDER_VISUAL_QA_V43R1R1_$TS.tar.gz"

mkdir -p "$QDIR" "$RDIR/dom" "$RDIR/screenshots" runtime/freezes

CONTENT_CHECK="$RDIR/content_checks.txt"
HTTP_TSV="$RDIR/http.tsv"
DOM_FILE="$RDIR/dom/trfmc_v43r1r1_runtime_dom.html"
SHOT_FILE="$RDIR/screenshots/trfmc_v43r1r1_runtime_5173.png"
META_FILE="$RDIR/screenshot_metadata.json"

echo "============================================================"
echo "TRFMC REAL RENDER VISUAL QA V43R1R1"
echo "active registry · real PNG render · DOM/screenshot gate · read-only"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f runtime/quality/latest_safe_single_render_import_v43r1/summary.json || {
  echo "ERRORE: V43R1 summary mancante"
  exit 1
}

V43_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_safe_single_render_import_v43r1/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V43_RESULT" = "PASS" ] || {
  echo "ERRORE: V43R1 non PASS: $V43_RESULT"
  exit 1
}

grep -q "RFOperationalDeckV42MissionLayoutOrchestrator" frontend/src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V42"
  exit 1
}

grep -q "visual_asset_registry_active.json" frontend/src/visual_assets/VisualAssetRuntimeV41.tsx || {
  echo "ERRORE: VisualAssetRuntimeV41 non usa registry active"
  exit 1
}

test -s frontend/public/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png || {
  echo "ERRORE: render PNG reale mancante"
  exit 1
}

echo "OK: V43R1 PASS, V42 active, active registry configured, PNG render present"

echo
echo "=== HTTP GATE ==="

printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="$(printf "%s" "$meta" | awk '{print $1}')"
  bytes="$(printf "%s" "$meta" | awk '{print $2}')"
  printf "%s\t%s\t%s\n" "$u" "${code:-000}" "${bytes:-0}" >> "$HTTP_TSV"
}

for u in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json \
  http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v43.json \
  http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png \
  http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg \
  http://127.0.0.1:4181/api/mission/status \
  http://127.0.0.1:4181/api/rfpro/spectrum/sweep
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== REGISTRY SEMANTIC CHECK ==="

REGISTRY_CHECK="$RDIR/registry_semantic_check.json"

python3 - "$REGISTRY_CHECK" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
registry_path = Path("frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json")
d = json.loads(registry_path.read_text(encoding="utf-8"))

assets = d.get("assets", [])
rf = next((a for a in assets if a.get("id") == "rf_microwave_engineering_lab"), None)
fallback_count = sum(1 for a in assets if a.get("source_mode") == "fallback")
real_count = sum(1 for a in assets if a.get("source_mode") == "real-render")

result = {
    "registry_path": str(registry_path),
    "operation": d.get("operation"),
    "assets_count": len(assets),
    "fallback_count": fallback_count,
    "real_render_count": real_count,
    "rf_microwave_engineering_lab": rf,
    "checks": {
        "rf_asset_exists": rf is not None,
        "rf_source_mode_real_render": bool(rf and rf.get("source_mode") == "real-render"),
        "rf_real_render_path_set": bool(rf and rf.get("real_render_path") == "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png"),
        "rf_fallback_preserved": bool(rf and rf.get("fallback_path", "").endswith("rf_microwave_engineering_lab.svg")),
        "fallback_assets_preserved": fallback_count == 7,
        "single_real_render": real_count == 1,
    }
}

out.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(result, indent=2, ensure_ascii=False))
PY

echo
echo "=== DOM / SCREENSHOT QA ==="

python3 - "$ROOT" "$DOM_FILE" "$SHOT_FILE" "$META_FILE" <<'PY'
from pathlib import Path
import json
import shutil
import subprocess
import sys

root = Path(sys.argv[1])
dom_file = Path(sys.argv[2])
shot_file = Path(sys.argv[3])
meta_file = Path(sys.argv[4])

url = "http://127.0.0.1:5173/"

chrome_candidates = [
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
]

chrome = None
for name in chrome_candidates:
    found = shutil.which(name)
    if found:
        chrome = found
        break

result = {
    "chrome_found": bool(chrome),
    "chrome_path": chrome,
    "dom_written": False,
    "screenshot_written": False,
    "screenshot_path": str(shot_file),
    "dom_path": str(dom_file),
    "errors": [],
}

if chrome:
    base_cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--no-sandbox",
        "--window-size=1920,1600",
        "--virtual-time-budget=5000",
    ]

    try:
        proc = subprocess.run(
            base_cmd + ["--dump-dom", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=25,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            dom_file.write_text(proc.stdout, encoding="utf-8", errors="ignore")
            result["dom_written"] = True
        else:
            result["errors"].append("chrome dump-dom failed: " + proc.stderr[-1200:])
    except Exception as exc:
        result["errors"].append("chrome dump-dom exception: " + str(exc))

    try:
        proc = subprocess.run(
            base_cmd + [f"--screenshot={shot_file}", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
        if proc.returncode == 0 and shot_file.exists() and shot_file.stat().st_size > 0:
            result["screenshot_written"] = True
            result["screenshot_size_bytes"] = shot_file.stat().st_size
        else:
            result["errors"].append("chrome screenshot failed: " + proc.stderr[-1200:])
    except Exception as exc:
        result["errors"].append("chrome screenshot exception: " + str(exc))

if not result["dom_written"]:
    try:
        proc = subprocess.run(
            ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=12,
        )
        if proc.returncode == 0:
            dom_file.write_text(proc.stdout, encoding="utf-8", errors="ignore")
            result["dom_written"] = True
            result["dom_fallback"] = "curl_static_html_only"
        else:
            result["errors"].append("curl DOM fallback failed: " + proc.stderr[-800:])
    except Exception as exc:
        result["errors"].append("curl DOM fallback exception: " + str(exc))

if shot_file.exists() and shot_file.stat().st_size > 0:
    result["screenshot_size_bytes"] = shot_file.stat().st_size
    try:
        from PIL import Image
        img = Image.open(shot_file)
        result["screenshot_width"] = img.width
        result["screenshot_height"] = img.height
        result["screenshot_png"] = img.format == "PNG"
    except Exception as exc:
        result["errors"].append("PIL metadata exception: " + str(exc))

meta_file.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(result, indent=2, ensure_ascii=False))
PY

echo
echo "=== CONTENT CHECKS ==="

{
  test -s "$DOM_FILE" && echo "OK: DOM file exists" || echo "MISS: DOM file exists"
  test -s "$SHOT_FILE" && echo "OK: screenshot file non-empty" || echo "WARN: screenshot file missing or empty"

  grep -q "RFOperationalDeckV42MissionLayoutOrchestrator" frontend/src/app/main.tsx && echo "OK: V42 active mount preserved" || echo "MISS: V42 active mount preserved"
  grep -q "visual_asset_registry_active.json" frontend/src/visual_assets/VisualAssetRuntimeV41.tsx && echo "OK: V41 runtime uses active registry" || echo "MISS: V41 runtime uses active registry"
  grep -q "selected.real_render_path" frontend/src/visual_assets/VisualAssetRuntimeV41.tsx && echo "OK: V41 runtime prefers real_render_path" || echo "MISS: V41 runtime prefers real_render_path"

  test -s frontend/public/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png && echo "OK: RF lab real PNG exists" || echo "MISS: RF lab real PNG exists"
  test -s frontend/public/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg && echo "OK: RF lab fallback SVG preserved" || echo "MISS: RF lab fallback SVG preserved"

  grep -q '"source_mode": "real-render"' frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json && echo "OK: active registry has real-render mode" || echo "MISS: active registry has real-render mode"
  grep -q '"source_mode": "fallback"' frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json && echo "OK: active registry keeps fallback modes" || echo "MISS: active registry keeps fallback modes"

  python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json").read_text())
assets=d.get("assets",[])
real=sum(1 for a in assets if a.get("source_mode")=="real-render")
fallback=sum(1 for a in assets if a.get("source_mode")=="fallback")
if real==1 and fallback==7:
    print("OK: registry source mode counts 1 real-render / 7 fallback")
else:
    print(f"MISS: registry source mode counts unexpected real={real} fallback={fallback}")
PY
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"
WARN_COUNT="$(grep -c '^WARN:' "$CONTENT_CHECK" || true)"

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$HTTP_NON_200" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ] || [ "$WARN_COUNT" -ne 0 ]; then
  RESULT="WARN"
fi

MANIFEST="$RDIR/real_render_visual_qa_manifest_v43r1r1.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_REAL_RENDER_VISUAL_QA_V43R1R1",
  "strategy": "readonly_runtime_validation_of_active_registry_and_real_render_png",
  "frontend_mutation": false,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
  "active_registry": "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json",
  "real_render": "frontend/public/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png",
  "registry_semantic_check": "$REGISTRY_CHECK",
  "dom_file": "$DOM_FILE",
  "screenshot": "$SHOT_FILE",
  "screenshot_metadata": "$META_FILE",
  "miss_count": $MISS_COUNT,
  "warn_count": $WARN_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_REAL_RENDER_VISUAL_QA_V43R1R1",
  "release_dir": "$RDIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "registry_semantic_check": "$REGISTRY_CHECK",
  "dom_dump": "$DOM_FILE",
  "screenshot": "$SHOT_FILE",
  "screenshot_metadata": "$META_FILE",
  "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
  "real_render_validated": "rf_microwave_engineering_lab.png",
  "miss_count": $MISS_COUNT,
  "warn_count": $WARN_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  "$RDIR" \
  "$SUMMARY" \
  create_trfmc_real_render_visual_qa_v43r1r1.sh \
  2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_real_render_visual_qa_v43r1r1"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_real_render_visual_qa_v43r1r1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" = "FAIL" ]; then
  echo "ATTENZIONE: V43R1R1 visual QA FAIL"
  exit 1
fi

echo
echo "============================================================"
echo "V43R1R1 REAL RENDER VISUAL QA COMPLETATO: $RESULT"
echo "============================================================"
