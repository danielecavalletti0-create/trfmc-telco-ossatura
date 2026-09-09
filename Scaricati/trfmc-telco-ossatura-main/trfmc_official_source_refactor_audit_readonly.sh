#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_OFFICIAL_SOURCE_REFACTOR_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
FILES="$OUT/official_files.tsv"
MAIN_SCAN="$OUT/main_tsx_scan.txt"
V42_SCAN="$OUT/MissionLayoutOrchestratorV42_scan.txt"
V49_SCAN="$OUT/EngineeringContentEnrichmentV49_scan.txt"
CSS_SCAN="$OUT/styles_css_scan.txt"
CLASSMAP="$OUT/classname_inventory.tsv"
STRUCTURE="$OUT/react_structure_inventory.tsv"
REFPLAN="$OUT/TRFMC_REFACTOR_TARGET_PLAN.md"

echo "============================================================"
echo "TRFMC_OFFICIAL_SOURCE_REFACTOR_AUDIT_READONLY"
echo "Read-only source audit before real React refactor"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) OFFICIAL FILES ==="
{
  echo -e "path\tbytes\tlines\tsha256"
  for f in \
    frontend/index.html \
    frontend/src/app/main.tsx \
    frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx \
    frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx \
    frontend/src/styles.css
  do
    if [ -f "$f" ]; then
      printf "%s\t%s\t%s\t%s\n" \
        "$f" \
        "$(stat -c%s "$f")" \
        "$(wc -l < "$f" | tr -d ' ')" \
        "$(sha256sum "$f" | awk '{print $1}')"
    else
      printf "%s\t0\t0\tMISSING\n" "$f"
    fi
  done
} | tee "$FILES"

echo
echo "=== 2) main.tsx SCAN ==="
{
  echo "---- imports / orchestrator mount / route-ish markers ----"
  grep -nE "import |MissionLayoutOrchestratorV42|EngineeringContentEnrichmentV49|RFInstrument|hash|section|route|#|createRoot|StrictMode" \
    frontend/src/app/main.tsx || true
} | tee "$MAIN_SCAN"

echo
echo "=== 3) MissionLayoutOrchestratorV42 SCAN ==="
{
  echo "---- top 360 lines ----"
  sed -n '1,360p' frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx

  echo
  echo "---- key markers ----"
  grep -nE "const |function |export |sections|nav|hash|active|sidebar|aside|grid|layout|orchestrator|mission|full-engineering-stack|TRFMC Mission Control Layout|className" \
    frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx || true
} | tee "$V42_SCAN"

echo
echo "=== 4) EngineeringContentEnrichmentV49 SCAN ==="
{
  echo "---- top 320 lines ----"
  sed -n '1,320p' frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx

  echo
  echo "---- key markers ----"
  grep -nE "const |function |export |sections|content|full-engineering-stack|Integration View|className|module|matrix|scenario|endpoint|asset|qa" \
    frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx || true
} | tee "$V49_SCAN"

echo
echo "=== 5) styles.css SCAN ==="
{
  echo "---- size / first 260 lines ----"
  sed -n '1,260p' frontend/src/styles.css

  echo
  echo "---- layout/style selectors of interest ----"
  grep -nE "root|body|#root|\.app|\.shell|\.layout|\.dashboard|\.orchestrator|\.mission|\.sidebar|\.nav|\.grid|\.card|\.panel|full-engineering|v42|v49|instrument|cockpit" \
    frontend/src/styles.css || true
} | tee "$CSS_SCAN"

echo
echo "=== 6) CLASSNAME INVENTORY ==="
python3 - <<'PY' | tee "$CLASSMAP"
from pathlib import Path
import re

files = [
    Path("frontend/src/app/main.tsx"),
    Path("frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"),
    Path("frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx"),
    Path("frontend/src/styles.css"),
]

print("file\tline\tclass_or_selector\tcontext")

for f in files:
    if not f.exists():
        continue
    lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r'className\s*=\s*[{"`]([^"`}]+)', line):
            print(f"{f}\t{i}\t{m.group(1).strip()}\t{line.strip()[:220]}")
        if f.suffix == ".css":
            s = line.strip()
            if s.startswith(".") or s.startswith("#") or s.startswith(":root") or s.startswith("body") or s.startswith("html"):
                print(f"{f}\t{i}\t{s[:120]}\t{s[:220]}")
PY

echo
echo "=== 7) REACT STRUCTURE INVENTORY ==="
python3 - <<'PY' | tee "$STRUCTURE"
from pathlib import Path
import re

targets = [
    Path("frontend/src/app/main.tsx"),
    Path("frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"),
    Path("frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx"),
]

print("file\tline\ttype\tname_or_match")

patterns = [
    ("import", re.compile(r"^\s*import\s+(.+)")),
    ("export_function", re.compile(r"export\s+function\s+([A-Za-z0-9_]+)")),
    ("function", re.compile(r"function\s+([A-Za-z0-9_]+)")),
    ("const_array", re.compile(r"const\s+([A-Za-z0-9_]+)\s*=\s*\[")),
    ("const_object", re.compile(r"const\s+([A-Za-z0-9_]+)\s*=\s*\{")),
    ("jsx_heading", re.compile(r"<h[1-6][^>]*>(.*?)</h[1-6]>")),
    ("hash", re.compile(r"#[a-zA-Z0-9_-]+")),
]

for f in targets:
    if not f.exists():
        continue
    for i, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        for kind, rx in patterns:
            for m in rx.finditer(line):
                val = m.group(1) if m.groups() else m.group(0)
                print(f"{f}\t{i}\t{kind}\t{val.strip()[:180]}")
PY

cat > "$REFPLAN" <<'MD'
# TRFMC React Source Refactor Target Plan

## Scope
No runtime patch. No index injection. No new public asset layer.

## Files allowed for next source-level refactor
- `frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx`
- `frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx`
- `frontend/src/styles.css`

## Objective
Create a single coherent portal shell:
- one official outer shell;
- one sidebar/navigation model;
- one content grid system;
- one engineering content area;
- V49 integrated as native section, not visually appended;
- stable proportions at 1920 px;
- no duplicate portal feeling.

## Expected mutation after this audit
One controlled patch only, with:
- backup of modified source files;
- build gate;
- HTTP gate;
- screenshot gate;
- restore script.
MD

OFFICIAL_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$FILES")"
CLASS_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$CLASSMAP")"
STRUCT_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$STRUCTURE")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_OFFICIAL_SOURCE_REFACTOR_AUDIT_READONLY",
  "mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "official_files": "$FILES",
  "main_scan": "$MAIN_SCAN",
  "v42_scan": "$V42_SCAN",
  "v49_scan": "$V49_SCAN",
  "css_scan": "$CSS_SCAN",
  "classname_inventory": "$CLASSMAP",
  "react_structure_inventory": "$STRUCTURE",
  "refactor_target_plan": "$REFPLAN",
  "official_total": $OFFICIAL_TOTAL,
  "classname_total": $CLASS_TOTAL,
  "structure_total": $STRUCT_TOTAL,
  "result": "SOURCE_AUDIT_CREATED"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_official_source_refactor_audit"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_OFFICIAL_SOURCE_REFACTOR_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
