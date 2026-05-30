#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
OP="TRFMC_VISUAL_ASSETS_RUNTIME_QA_V45B1"

QDIR="$ROOT/runtime/quality/${OP}_${TS}"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
FREEZE="$ROOT/runtime/freezes/${OP}_${TS}.tar.gz"

mkdir -p "$QDIR" "$RDIR/dom" "$RDIR/screenshots" runtime/freezes

URL="http://127.0.0.1:5173/#visual-assets"
DOM_FILE="$RDIR/dom/trfmc_v45b1_visual_assets_dom.html"
SHOT_FILE="$RDIR/screenshots/trfmc_v45b1_visual_assets_5173.png"
META_FILE="$RDIR/screenshot_metadata.json"
CONTENT_CHECK="$RDIR/content_checks.txt"
HTTP_TSV="$RDIR/http.tsv"

echo "============================================================"
echo "$OP"
echo "runtime DOM/screenshot QA · target #visual-assets · read-only"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f runtime/quality/latest_restore_v42_active_mount_v45b/summary.json || {
  echo "ERRORE: V45B summary mancante"
  exit 1
}

V45B_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path("runtime/quality/latest_restore_v42_active_mount_v45b/summary.json")
d=json.loads(p.read_text())
print(d.get("result",""))
PY
)"

[ "$V45B_RESULT" = "PASS" ] || {
  echo "ERRORE: V45B non PASS: $V45B_RESULT"
  exit 1
}

grep -q "<MissionLayoutOrchestratorV42 />" frontend/src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta MissionLayoutOrchestratorV42"
  exit 1
}

grep -q "VisualAssetRuntimeV41" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx || {
  echo "ERRORE: V42 non monta VisualAssetRuntimeV41"
  exit 1
}

grep -q "VisualZoomViewer" frontend/src/visual_assets/VisualAssetRuntimeV41.tsx || {
  echo "ERRORE: VisualZoomViewer non presente"
  exit 1
}

echo "OK: V45B PASS, V42 active, VisualAssetRuntimeV41/V44 presenti"

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

probe "http://127.0.0.1:5173/"
probe "$URL"
probe "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"
probe "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png"
probe "http://127.0.0.1:4181/api/health"

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== DOM / SCREENSHOT CAPTURE ==="

python3 - "$URL" "$DOM_FILE" "$SHOT_FILE" "$META_FILE" <<'PY'
from pathlib import Path
import json
import shutil
import subprocess
import sys

url = sys.argv[1]
dom_file = Path(sys.argv[2])
shot_file = Path(sys.argv[3])
meta_file = Path(sys.argv[4])

chrome = None
for name in ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]:
    found = shutil.which(name)
    if found:
        chrome = found
        break

result = {
    "target_url": url,
    "chrome_found": bool(chrome),
    "chrome_path": chrome,
    "dom_written": False,
    "screenshot_written": False,
    "dom_path": str(dom_file),
    "screenshot_path": str(shot_file),
    "errors": [],
}

if chrome:
    base_cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--no-sandbox",
        "--window-size=1920,1800",
        "--virtual-time-budget=8000",
    ]

    try:
        proc = subprocess.run(
            base_cmd + ["--dump-dom", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=40,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            dom_file.write_text(proc.stdout, encoding="utf-8", errors="ignore")
            result["dom_written"] = True
        else:
            result["errors"].append("chrome dump-dom failed: " + proc.stderr[-1600:])
    except Exception as exc:
        result["errors"].append("chrome dump-dom exception: " + str(exc))

    try:
        proc = subprocess.run(
            base_cmd + [f"--screenshot={shot_file}", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=45,
        )
        if proc.returncode == 0 and shot_file.exists() and shot_file.stat().st_size > 0:
            result["screenshot_written"] = True
            result["screenshot_size_bytes"] = shot_file.stat().st_size
        else:
            result["errors"].append("chrome screenshot failed: " + proc.stderr[-1600:])
    except Exception as exc:
        result["errors"].append("chrome screenshot exception: " + str(exc))

if shot_file.exists() and shot_file.stat().st_size > 0:
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

  grep -q "TRFMC V44 Visual Asset Zoom/Autofit" "$DOM_FILE" && echo "OK: V44 title visible in DOM" || echo "MISS: V44 title visible in DOM"
  grep -q "Interactive viewer visible" "$DOM_FILE" && echo "OK: Interactive viewer visible in DOM" || echo "MISS: Interactive viewer visible in DOM"
  grep -q "Fit control visible" "$DOM_FILE" && echo "OK: Fit control visible in DOM" || echo "MISS: Fit control visible in DOM"
  grep -q "Reset control visible" "$DOM_FILE" && echo "OK: Reset control visible in DOM" || echo "MISS: Reset control visible in DOM"
  grep -q "Quick zoom help" "$DOM_FILE" && echo "OK: quick zoom help visible in DOM" || echo "MISS: quick zoom help visible in DOM"
  grep -q "Wheel zoom help" "$DOM_FILE" && echo "OK: wheel zoom help visible in DOM" || echo "MISS: wheel zoom help visible in DOM"
  grep -q "rf_microwave_engineering_lab.png" "$DOM_FILE" && echo "OK: RF microwave PNG path visible in DOM" || echo "MISS: RF microwave PNG path visible in DOM"
  grep -q "data-trfmc-v45a-visual-assets-active" "$DOM_FILE" && echo "OK: visual-assets active marker visible in DOM" || echo "MISS: visual-assets active marker visible in DOM"
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

MANIFEST="$RDIR/visual_assets_runtime_qa_manifest_v45b1.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "target_url": "$URL",
  "frontend_mutation": false,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "dom_file": "$DOM_FILE",
  "screenshot": "$SHOT_FILE",
  "screenshot_metadata": "$META_FILE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "miss_count": $MISS_COUNT,
  "warn_count": $WARN_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

cp "$MANIFEST" "$SUMMARY"

tar -czf "$FREEZE" "$RDIR" "$SUMMARY" create_trfmc_visual_assets_runtime_qa_v45b1.sh 2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_visual_assets_runtime_qa_v45b1"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_visual_assets_runtime_qa_v45b1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" = "FAIL" ]; then
  echo "ATTENZIONE: V45B1 runtime QA FAIL"
  exit 1
fi

echo
echo "============================================================"
echo "$OP COMPLETATO: $RESULT"
echo "============================================================"
