#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
OP="TRFMC_ENGINEERING_CONTENT_ENRICHMENT_RUNTIME_QA_V49R1"

QDIR="$ROOT/runtime/quality/${OP}_${TS}"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
FREEZE="$ROOT/runtime/freezes/${OP}_${TS}.tar.gz"

mkdir -p "$QDIR" "$RDIR/dom" "$RDIR/screenshots" runtime/freezes

HTTP_TSV="$RDIR/http.tsv"
CONTENT_CHECK="$RDIR/content_checks.txt"
META_JSON="$RDIR/engineering_content_enrichment_runtime_metadata_v49r1.json"

echo "============================================================"
echo "$OP"
echo "runtime DOM/screenshot QA · V49 engineering enrichment · read-only"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f runtime/quality/latest_engineering_content_enrichment_v49/summary.json || {
  echo "ERRORE: V49 summary mancante"
  exit 1
}

V49_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path("runtime/quality/latest_engineering_content_enrichment_v49/summary.json")
d=json.loads(p.read_text())
print(d.get("result",""))
PY
)"

[ "$V49_RESULT" = "PASS" ] || {
  echo "ERRORE: V49 non PASS: $V49_RESULT"
  exit 1
}

grep -q "<MissionLayoutOrchestratorV42 />" frontend/src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta MissionLayoutOrchestratorV42"
  exit 1
}

grep -q "EngineeringContentEnrichmentV49" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx || {
  echo "ERRORE: V42 non monta EngineeringContentEnrichmentV49"
  exit 1
}

grep -q "data-trfmc-v49-engineering-enrichment" frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx || {
  echo "ERRORE: marker V49 enrichment non presente"
  exit 1
}

grep -q "TRFMC V49 ENGINEERING CONTENT ENRICHMENT" frontend/src/styles.css || {
  echo "ERRORE: CSS V49 non presente"
  exit 1
}

echo "OK: V49 PASS, V42 active, V49 component/CSS presenti"

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

for url in \
  "http://127.0.0.1:5173/#mission-overview" \
  "http://127.0.0.1:5173/#visual-assets" \
  "http://127.0.0.1:5173/#scenario-knowledge" \
  "http://127.0.0.1:5173/#navigation-architecture" \
  "http://127.0.0.1:5173/#command-center" \
  "http://127.0.0.1:5173/#dynamic-scenarios" \
  "http://127.0.0.1:5173/#full-engineering-stack" \
  "http://127.0.0.1:4181/api/health" \
  "http://127.0.0.1:4181/api/mission/status" \
  "http://127.0.0.1:4181/api/rfpro/spectrum/sweep"
do
  probe "$url"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== DOM / SCREENSHOT CAPTURE ==="

python3 - "$RDIR" "$META_JSON" <<'PY'
from pathlib import Path
import json
import shutil
import subprocess
import sys

rdir = Path(sys.argv[1])
meta_json = Path(sys.argv[2])

targets = [
    ("mission-overview", "http://127.0.0.1:5173/#mission-overview"),
    ("visual-assets", "http://127.0.0.1:5173/#visual-assets"),
    ("scenario-knowledge", "http://127.0.0.1:5173/#scenario-knowledge"),
    ("navigation-architecture", "http://127.0.0.1:5173/#navigation-architecture"),
    ("command-center", "http://127.0.0.1:5173/#command-center"),
    ("dynamic-scenarios", "http://127.0.0.1:5173/#dynamic-scenarios"),
    ("full-engineering-stack", "http://127.0.0.1:5173/#full-engineering-stack"),
]

chrome = None
for name in ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]:
    found = shutil.which(name)
    if found:
        chrome = found
        break

results = {
    "chrome_found": bool(chrome),
    "chrome_path": chrome,
    "targets": [],
}

if not chrome:
    meta_json.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    raise SystemExit("Chrome/Chromium not found")

base_cmd = [
    chrome,
    "--headless=new",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--no-sandbox",
    "--window-size=1920,1900",
    "--virtual-time-budget=9000",
]

for slug, url in targets:
    dom_file = rdir / "dom" / f"trfmc_v49r1_{slug}_dom.html"
    shot_file = rdir / "screenshots" / f"trfmc_v49r1_{slug}_5173.png"

    item = {
        "slug": slug,
        "url": url,
        "dom_path": str(dom_file),
        "screenshot_path": str(shot_file),
        "dom_written": False,
        "screenshot_written": False,
        "errors": [],
    }

    try:
        proc = subprocess.run(
            base_cmd + ["--dump-dom", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=45,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            dom_file.write_text(proc.stdout, encoding="utf-8", errors="ignore")
            item["dom_written"] = True
        else:
            item["errors"].append("dump-dom failed: " + proc.stderr[-1600:])
    except Exception as exc:
        item["errors"].append("dump-dom exception: " + str(exc))

    try:
        proc = subprocess.run(
            base_cmd + [f"--screenshot={shot_file}", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=50,
        )
        if proc.returncode == 0 and shot_file.exists() and shot_file.stat().st_size > 0:
            item["screenshot_written"] = True
            item["screenshot_size_bytes"] = shot_file.stat().st_size
            try:
                from PIL import Image
                img = Image.open(shot_file)
                item["screenshot_width"] = img.width
                item["screenshot_height"] = img.height
                item["screenshot_png"] = img.format == "PNG"
            except Exception as exc:
                item["errors"].append("PIL metadata exception: " + str(exc))
        else:
            item["errors"].append("screenshot failed: " + proc.stderr[-1600:])
    except Exception as exc:
        item["errors"].append("screenshot exception: " + str(exc))

    results["targets"].append(item)

meta_json.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(results, indent=2, ensure_ascii=False))
PY

echo
echo "=== CONTENT CHECKS ==="

{
  for slug in mission-overview visual-assets scenario-knowledge navigation-architecture command-center dynamic-scenarios full-engineering-stack; do
    f="$RDIR/dom/trfmc_v49r1_${slug}_dom.html"
    test -s "$f" && echo "OK: DOM exists for $slug" || echo "MISS: DOM exists for $slug"
  done

  for slug in mission-overview visual-assets scenario-knowledge navigation-architecture command-center dynamic-scenarios full-engineering-stack; do
    f="$RDIR/screenshots/trfmc_v49r1_${slug}_5173.png"
    test -s "$f" && echo "OK: screenshot exists for $slug" || echo "WARN: screenshot exists for $slug"
  done

  for slug in mission-overview visual-assets scenario-knowledge navigation-architecture command-center dynamic-scenarios full-engineering-stack; do
    f="$RDIR/dom/trfmc_v49r1_${slug}_dom.html"
    grep -q "data-trfmc-v49-engineering-enrichment" "$f" && echo "OK: V49 enrichment marker visible for $slug" || echo "MISS: V49 enrichment marker visible for $slug"
    grep -q "TRFMC V49 · Engineering Content Enrichment Baseline" "$f" && echo "OK: V49 title visible for $slug" || echo "MISS: V49 title visible for $slug"
    grep -q "Operational meaning" "$f" && echo "OK: operational meaning visible for $slug" || echo "MISS: operational meaning visible for $slug"
    grep -q "Live / contract endpoints" "$f" && echo "OK: live contract endpoints visible for $slug" || echo "MISS: live contract endpoints visible for $slug"
    grep -q "Operator workflow" "$f" && echo "OK: operator workflow visible for $slug" || echo "MISS: operator workflow visible for $slug"
  done

  grep -q "Mission Overview · Operational State Interpretation" "$RDIR/dom/trfmc_v49r1_mission-overview_dom.html" && echo "OK: mission-specific V49 content visible" || echo "MISS: mission-specific V49 content visible"
  grep -q "Visual Assets · RF Render Evidence Layer" "$RDIR/dom/trfmc_v49r1_visual-assets_dom.html" && echo "OK: visual-assets-specific V49 content visible" || echo "MISS: visual-assets-specific V49 content visible"
  grep -q "Scenario Knowledge · RF/Telco Concept Binding" "$RDIR/dom/trfmc_v49r1_scenario-knowledge_dom.html" && echo "OK: scenario-specific V49 content visible" || echo "MISS: scenario-specific V49 content visible"
  grep -q "Navigation Architecture · SPA Control Plane" "$RDIR/dom/trfmc_v49r1_navigation-architecture_dom.html" && echo "OK: navigation-specific V49 content visible" || echo "MISS: navigation-specific V49 content visible"
  grep -q "Command Center · Live Contract Interpretation" "$RDIR/dom/trfmc_v49r1_command-center_dom.html" && echo "OK: command-center-specific V49 content visible" || echo "MISS: command-center-specific V49 content visible"
  grep -q "Dynamic Scenarios · RF/Telco Runtime Laboratory" "$RDIR/dom/trfmc_v49r1_dynamic-scenarios_dom.html" && echo "OK: dynamic-scenarios-specific V49 content visible" || echo "MISS: dynamic-scenarios-specific V49 content visible"
  grep -q "Full Engineering Stack · Integration View" "$RDIR/dom/trfmc_v49r1_full-engineering-stack_dom.html" && echo "OK: full-stack-specific V49 content visible" || echo "MISS: full-stack-specific V49 content visible"

  grep -q "data-trfmc-v46-deeplink-index" "$RDIR/dom/trfmc_v49r1_command-center_dom.html" && echo "OK: V46 navigation still visible" || echo "MISS: V46 navigation still visible"
  grep -q "data-trfmc-v45a-visual-assets-active" "$RDIR/dom/trfmc_v49r1_visual-assets_dom.html" && echo "OK: V45 visual assets active marker still visible" || echo "MISS: V45 visual assets active marker still visible"
  grep -q "TRFMC V44 Visual Asset Zoom/Autofit" "$RDIR/dom/trfmc_v49r1_visual-assets_dom.html" && echo "OK: V44 zoom viewer still visible" || echo "MISS: V44 zoom viewer still visible"
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

MANIFEST="$RDIR/engineering_content_enrichment_runtime_qa_manifest_v49r1.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "frontend_mutation": false,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "tested_sections": [
    "mission-overview",
    "visual-assets",
    "scenario-knowledge",
    "navigation-architecture",
    "command-center",
    "dynamic-scenarios",
    "full-engineering-stack"
  ],
  "content_checks": "$CONTENT_CHECK",
  "http_tsv": "$HTTP_TSV",
  "metadata": "$META_JSON",
  "miss_count": $MISS_COUNT,
  "warn_count": $WARN_COUNT,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

cp "$MANIFEST" "$SUMMARY"

tar -czf "$FREEZE" "$RDIR" "$SUMMARY" create_trfmc_engineering_content_enrichment_runtime_qa_v49r1.sh 2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_engineering_content_enrichment_runtime_qa_v49r1"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_engineering_content_enrichment_runtime_qa_v49r1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" = "FAIL" ]; then
  echo "ATTENZIONE: V49R1 runtime QA FAIL"
  exit 1
fi

echo
echo "============================================================"
echo "$OP COMPLETATO: $RESULT"
echo "============================================================"
