#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
OP="TRFMC_FULL_SECTION_COVERAGE_RUNTIME_QA_V47"

QDIR="$ROOT/runtime/quality/${OP}_${TS}"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
FREEZE="$ROOT/runtime/freezes/${OP}_${TS}.tar.gz"

mkdir -p "$QDIR" "$RDIR/dom" "$RDIR/screenshots" runtime/freezes

HTTP_TSV="$RDIR/http.tsv"
CONTENT_CHECK="$RDIR/content_checks.txt"
META_JSON="$RDIR/full_section_coverage_metadata_v47.json"

echo "============================================================"
echo "$OP"
echo "runtime DOM/screenshot QA · remaining V46 sections · read-only"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f runtime/quality/latest_navigation_deeplink_runtime_qa_v46r1/summary.json || {
  echo "ERRORE: V46R1 summary mancante"
  exit 1
}

V46R1_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path("runtime/quality/latest_navigation_deeplink_runtime_qa_v46r1/summary.json")
d=json.loads(p.read_text())
print(d.get("result",""))
PY
)"

[ "$V46R1_RESULT" = "PASS" ] || {
  echo "ERRORE: V46R1 non PASS: $V46R1_RESULT"
  exit 1
}

grep -q "<MissionLayoutOrchestratorV42 />" frontend/src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta MissionLayoutOrchestratorV42"
  exit 1
}

grep -q "data-trfmc-v46-deeplink-index" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx || {
  echo "ERRORE: V46 deeplink index marker non presente"
  exit 1
}

echo "OK: V46R1 PASS, root mount V42, deeplink index presente"

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
  "http://127.0.0.1:5173/#scenario-knowledge" \
  "http://127.0.0.1:5173/#navigation-architecture" \
  "http://127.0.0.1:5173/#dynamic-scenarios" \
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
    ("scenario-knowledge", "http://127.0.0.1:5173/#scenario-knowledge"),
    ("navigation-architecture", "http://127.0.0.1:5173/#navigation-architecture"),
    ("dynamic-scenarios", "http://127.0.0.1:5173/#dynamic-scenarios"),
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

if chrome:
    base_cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--no-sandbox",
        "--window-size=1920,1800",
        "--virtual-time-budget=9000",
    ]

    for slug, url in targets:
        dom_file = rdir / "dom" / f"trfmc_v47_{slug}_dom.html"
        shot_file = rdir / "screenshots" / f"trfmc_v47_{slug}_5173.png"
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
  for slug in scenario-knowledge navigation-architecture dynamic-scenarios; do
    f="$RDIR/dom/trfmc_v47_${slug}_dom.html"
    test -s "$f" && echo "OK: DOM exists for $slug" || echo "MISS: DOM exists for $slug"
  done

  for slug in scenario-knowledge navigation-architecture dynamic-scenarios; do
    f="$RDIR/screenshots/trfmc_v47_${slug}_5173.png"
    test -s "$f" && echo "OK: screenshot exists for $slug" || echo "WARN: screenshot exists for $slug"
  done

  grep -q "data-trfmc-v46-deeplink-index" "$RDIR/dom/trfmc_v47_scenario-knowledge_dom.html" && echo "OK: deeplink index visible in scenario DOM" || echo "MISS: deeplink index visible in scenario DOM"
  grep -q "Scenario Knowledge" "$RDIR/dom/trfmc_v47_scenario-knowledge_dom.html" && echo "OK: scenario knowledge label visible" || echo "MISS: scenario knowledge label visible"

  grep -q "Navigation Architecture" "$RDIR/dom/trfmc_v47_navigation-architecture_dom.html" && echo "OK: navigation architecture label visible" || echo "MISS: navigation architecture label visible"
  grep -q "data-trfmc-v46-deeplink-index" "$RDIR/dom/trfmc_v47_navigation-architecture_dom.html" && echo "OK: deeplink index visible in navigation DOM" || echo "MISS: deeplink index visible in navigation DOM"

  grep -q "Dynamic Scenarios" "$RDIR/dom/trfmc_v47_dynamic-scenarios_dom.html" && echo "OK: dynamic scenarios label visible" || echo "MISS: dynamic scenarios label visible"
  grep -q "data-trfmc-v46-deeplink-index" "$RDIR/dom/trfmc_v47_dynamic-scenarios_dom.html" && echo "OK: deeplink index visible in dynamic scenarios DOM" || echo "MISS: deeplink index visible in dynamic scenarios DOM"

  # Non-placeholder sanity: cerca contenuti tecnici o componenti reali.
  grep -Eiq "scenario|knowledge|binding|RF|Telco|Core|Spectrum|Antenna|Mission|Runtime" "$RDIR/dom/trfmc_v47_scenario-knowledge_dom.html" && echo "OK: scenario knowledge has non-empty technical content" || echo "MISS: scenario knowledge has non-empty technical content"
  grep -Eiq "navigation|architecture|domain|Mission|Signal|Core|Knowledge|Runtime" "$RDIR/dom/trfmc_v47_navigation-architecture_dom.html" && echo "OK: navigation architecture has non-empty technical content" || echo "MISS: navigation architecture has non-empty technical content"
  grep -Eiq "dynamic|scenario|RF|Telco|UAV|antenna|spectrum|Runtime" "$RDIR/dom/trfmc_v47_dynamic-scenarios_dom.html" && echo "OK: dynamic scenarios has non-empty technical content" || echo "MISS: dynamic scenarios has non-empty technical content"
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

MANIFEST="$RDIR/full_section_coverage_manifest_v47.json"
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
    "scenario-knowledge",
    "navigation-architecture",
    "dynamic-scenarios"
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

tar -czf "$FREEZE" "$RDIR" "$SUMMARY" create_trfmc_full_section_coverage_runtime_qa_v47.sh 2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_full_section_coverage_runtime_qa_v47"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_full_section_coverage_runtime_qa_v47"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" = "FAIL" ]; then
  echo "ATTENZIONE: V47 runtime section coverage FAIL"
  exit 1
fi

echo
echo "============================================================"
echo "$OP COMPLETATO: $RESULT"
echo "============================================================"
