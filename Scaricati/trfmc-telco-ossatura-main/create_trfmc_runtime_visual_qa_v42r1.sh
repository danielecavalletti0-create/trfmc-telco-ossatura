#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_RUNTIME_VISUAL_QA_V42R1_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_RUNTIME_VISUAL_QA_V42R1_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_RUNTIME_VISUAL_QA_V42R1_$TS.tar.gz"

mkdir -p "$QDIR" "$RDIR/dom" "$RDIR/screenshots" runtime/freezes

CONTENT_CHECK="$RDIR/content_checks.txt"
HTTP_TSV="$RDIR/http.tsv"
DOM_FILE="$RDIR/dom/trfmc_v42r1_runtime_dom.html"
SHOT_FILE="$RDIR/screenshots/trfmc_v42r1_runtime_5173.png"
META_FILE="$RDIR/screenshot_metadata.json"

echo "============================================================"
echo "TRFMC RUNTIME VISUAL QA V42R1"
echo "DOM gate · section visibility · optional screenshot · read-only"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f runtime/quality/latest_mission_layout_orchestrator_v42/summary.json || {
  echo "ERRORE: V42 summary mancante"
  exit 1
}

V42_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_mission_layout_orchestrator_v42/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V42_RESULT" = "PASS" ] || {
  echo "ERRORE: V42 non PASS: $V42_RESULT"
  exit 1
}

grep -q "RFOperationalDeckV42MissionLayoutOrchestrator" frontend/src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V42"
  exit 1
}

echo "OK: V42 PASS e main.tsx monta V42"

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
  http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json \
  http://127.0.0.1:4181/api/mission/status \
  http://127.0.0.1:4181/api/core/open5gs/status \
  http://127.0.0.1:4181/api/rfpro/spectrum/sweep
do
  probe "$u"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== DOM / SCREENSHOT QA ==="

python3 - "$ROOT" "$RDIR" "$DOM_FILE" "$SHOT_FILE" "$META_FILE" <<'PY'
from pathlib import Path
import json
import shutil
import subprocess
import sys
import time

root = Path(sys.argv[1])
rdir = Path(sys.argv[2])
dom_file = Path(sys.argv[3])
shot_file = Path(sys.argv[4])
meta_file = Path(sys.argv[5])

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
        "--virtual-time-budget=4500",
    ]

    # DOM dump
    try:
        proc = subprocess.run(
            base_cmd + ["--dump-dom", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=20,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            dom_file.write_text(proc.stdout, encoding="utf-8", errors="ignore")
            result["dom_written"] = True
        else:
            result["errors"].append("chrome dump-dom failed: " + proc.stderr[-1200:])
    except Exception as exc:
        result["errors"].append("chrome dump-dom exception: " + str(exc))

    # screenshot
    try:
        proc = subprocess.run(
            base_cmd + [f"--screenshot={shot_file}", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=25,
        )
        if proc.returncode == 0 and shot_file.exists() and shot_file.stat().st_size > 0:
            result["screenshot_written"] = True
            result["screenshot_size_bytes"] = shot_file.stat().st_size
        else:
            result["errors"].append("chrome screenshot failed: " + proc.stderr[-1200:])
    except Exception as exc:
        result["errors"].append("chrome screenshot exception: " + str(exc))

# fallback DOM through curl only captures app shell, not rendered React.
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

# compute screenshot image metadata if possible
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

  grep -q "RFOperationalDeckV42MissionLayoutOrchestrator" frontend/src/app/main.tsx && echo "OK: V42 active mount preserved" || echo "MISS: V42 active mount preserved"
  grep -q "MissionLayoutOrchestratorV42" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: V42 component source exists" || echo "MISS: V42 component source exists"
  grep -q "Mission Overview" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: Mission Overview section defined" || echo "MISS: Mission Overview section defined"
  grep -q "Visual Assets" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: Visual Assets section defined" || echo "MISS: Visual Assets section defined"
  grep -q "Scenario Knowledge" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: Scenario Knowledge section defined" || echo "MISS: Scenario Knowledge section defined"
  grep -q "Navigation Architecture" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: Navigation Architecture section defined" || echo "MISS: Navigation Architecture section defined"
  grep -q "Command Center" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: Command Center section defined" || echo "MISS: Command Center section defined"
  grep -q "Dynamic Scenarios" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: Dynamic Scenarios section defined" || echo "MISS: Dynamic Scenarios section defined"
  grep -q "Full Engineering Stack" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx && echo "OK: Full Engineering Stack section defined" || echo "MISS: Full Engineering Stack section defined"

  grep -q "v42-orchestrator-shell" frontend/src/styles.css && echo "OK: V42 CSS present" || echo "MISS: V42 CSS present"

  if [ -s "$SHOT_FILE" ]; then
    echo "OK: screenshot file non-empty"
  else
    echo "WARN: screenshot file missing or empty"
  fi
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

MANIFEST="$RDIR/runtime_visual_qa_manifest_v42r1.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RUNTIME_VISUAL_QA_V42R1",
  "strategy": "runtime_dom_http_screenshot_quality_gate_readonly",
  "frontend_mutation": false,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
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
  "operation": "TRFMC_RUNTIME_VISUAL_QA_V42R1",
  "release_dir": "$RDIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "dom_dump": "$DOM_FILE",
  "screenshot": "$SHOT_FILE",
  "screenshot_metadata": "$META_FILE",
  "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
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
  create_trfmc_runtime_visual_qa_v42r1.sh \
  2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_runtime_visual_qa_v42r1"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_runtime_visual_qa_v42r1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" = "FAIL" ]; then
  echo "ATTENZIONE: V42R1 visual QA FAIL"
  exit 1
fi

echo
echo "============================================================"
echo "V42R1 RUNTIME VISUAL QA COMPLETATO: $RESULT"
echo "============================================================"
