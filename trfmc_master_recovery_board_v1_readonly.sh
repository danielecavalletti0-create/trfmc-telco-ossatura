#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_MASTER_RECOVERY_BOARD_V1_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

REG="$(find runtime/quality -maxdepth 1 -type d -name 'TRFMC_MASTER_PORTAL_REGISTER_READONLY_*' | sort | tail -n 1)"

if [ -z "$REG" ] || [ ! -d "$REG" ]; then
  echo "ERRORE: registro master non trovato"
  exit 1
fi

echo "============================================================"
echo "TRFMC_MASTER_RECOVERY_BOARD_V1_READONLY"
echo "Read-only · no source mutation · no backend restart · no CSS patch"
echo "Timestamp: $TS"
echo "Register: $REG"
echo "============================================================"

BOARD="$OUT/master_recovery_board.tsv"
PLAN="$OUT/TRFMC_MASTER_RECOVERY_BOARD_V1.md"

python3 - "$BASE" "$REG" "$BOARD" "$PLAN" <<'PY'
import csv
import json
import sys
from pathlib import Path

base = Path(sys.argv[1])
reg = Path(sys.argv[2])
board = Path(sys.argv[3])
plan = Path(sys.argv[4])

summary = json.loads((reg / "summary.json").read_text(encoding="utf-8"))

def read_tsv(path):
    p = reg / path
    if not p.exists():
        return []
    with p.open("r", encoding="utf-8", errors="replace", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))

public_html = read_tsv("public_html_inventory.tsv")
promote = read_tsv("promote_candidates.tsv")
debt = read_tsv("placeholder_todo_mock_inventory.tsv")
modules = read_tsv("module_completion_matrix.tsv")

promote_paths = {r.get("path","") for r in promote}
debt_paths = {}
for r in debt:
    debt_paths.setdefault(r.get("path",""), []).append(r)

def domain_for(path):
    p = path.lower()
    if "antenna" in p or "rru" in p or "ret" in p or "cpri" in p:
        return "05_Antenna_System"
    if "fiber" in p or "otdr" in p or "fronthaul" in p:
        return "07_Fiber_Optic"
    if "microwave" in p or "smith" in p or "link" in p:
        return "04_RF_Microwave_Engineering"
    if "core" in p or "ran" in p or "open5gs" in p or "ueransim" in p or "aka" in p:
        return "09_Core_Network"
    if "cyber" in p or "evidence" in p or "security" in p or "restricted" in p:
        return "11_Cyber_RF_Intelligence"
    if "datacenter" in p or "pdu" in p or "infrastructure" in p:
        return "10_Data_Center_Infrastructure"
    if "knowledge" in p or "theory" in p or "procedure" in p:
        return "12_Knowledge_Base"
    if "signal" in p or "spectrum" in p or "rfpro" in p or "instrument" in p:
        return "03_Signal_Analyzer"
    if "rf_physics" in p or "sapienza" in p or "propagation" in p:
        return "02_RF_Physics"
    if "private" in p or "wifi" in p or "mesh" in p:
        return "08_Private_Networks"
    if "mission" in p or "noc" in p or "home" in p or "portal" in p or "control_room" in p:
        return "01_Mission_Control"
    return "00_Unclassified"

def action_for(row):
    path = row.get("path","")
    status = row.get("status_guess","")
    bytes_n = int(row.get("bytes") or 0)
    has_debt = path in debt_paths

    if path in promote_paths:
        return "P0_PROMOTE_REVIEW"
    if "ARCHIVE" in status:
        return "ARCHIVE_REVIEW_COPY_ONLY"
    if has_debt and bytes_n < 6000:
        return "REWRITE_REQUIRED"
    if has_debt:
        return "MERGE_AND_COMPLETE"
    if bytes_n > 40000:
        return "PROMOTE_CANDIDATE_DEEP_REVIEW"
    if bytes_n > 12000:
        return "PROMOTE_CANDIDATE_REVIEW"
    return "REFERENCE_OR_SECONDARY"

rows = []
for r in public_html:
    path = r.get("path","")
    rows.append({
        "domain": domain_for(path),
        "path": path,
        "bytes": r.get("bytes",""),
        "status_guess": r.get("status_guess",""),
        "debt_hits": str(len(debt_paths.get(path, []))),
        "action": action_for(r),
    })

domain_order = [
    "01_Mission_Control",
    "02_RF_Physics",
    "03_Signal_Analyzer",
    "04_RF_Microwave_Engineering",
    "05_Antenna_System",
    "06_Microwave_Link",
    "07_Fiber_Optic",
    "08_Private_Networks",
    "09_Core_Network",
    "10_Data_Center_Infrastructure",
    "11_Cyber_RF_Intelligence",
    "12_Knowledge_Base",
    "00_Unclassified",
]

rank = {d:i for i,d in enumerate(domain_order)}
rows.sort(key=lambda x: (rank.get(x["domain"], 999), x["action"], x["path"]))

with board.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["domain","path","bytes","status_guess","debt_hits","action"], delimiter="\t")
    w.writeheader()
    w.writerows(rows)

counts = {}
for r in rows:
    counts[r["action"]] = counts.get(r["action"], 0) + 1

domain_counts = {}
for r in rows:
    domain_counts[r["domain"]] = domain_counts.get(r["domain"], 0) + 1

md = []
md.append("# TRFMC Master Recovery Board V1")
md.append("")
md.append("## Executive status")
md.append("")
md.append(f"- React source total: {summary.get('react_source_total')}")
md.append(f"- Public HTML total: {summary.get('public_html_total')}")
md.append(f"- Public asset total: {summary.get('public_asset_total')}")
md.append(f"- Debt total: {summary.get('debt_total')}")
md.append(f"- Promote candidates: {summary.get('promote_candidate_total')}")
md.append(f"- Git dirty total: {summary.get('git_dirty_total')}")
md.append("")
md.append("## Action distribution")
md.append("")
for k in sorted(counts):
    md.append(f"- {k}: {counts[k]}")
md.append("")
md.append("## Domain distribution")
md.append("")
for d in domain_order:
    if d in domain_counts:
        md.append(f"- {d}: {domain_counts[d]}")
md.append("")
md.append("## Immediate operating rule")
md.append("")
md.append("No further endpoint, CSS or visual patch is authorized before the promotion board is reviewed.")
md.append("")
md.append("## Correct next phase")
md.append("")
md.append("1. Select official shell and navigation registry.")
md.append("2. Promote P0/P1 pages into React modules.")
md.append("3. Convert high-value public HTML engines into React components.")
md.append("4. Archive duplicate/versioned pages copy-only.")
md.append("5. Add QA gates: build, HTTP, DOM markers, screenshot, placeholder scan.")
md.append("6. Only after page integration, bind backend contracts.")
md.append("")

plan.write_text("\n".join(md) + "\n", encoding="utf-8")
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_master_recovery_board_v1_readonly"

echo
echo "=== SUMMARY SOURCE ==="
cat "$REG/summary.json" | python3 -m json.tool | sed -n '1,120p'

echo
echo "=== RECOVERY BOARD ACTION COUNTS ==="
awk -F'\t' 'NR>1 {c[$6]++} END {for (k in c) print k "\t" c[k]}' "$BOARD" | sort | column -t -s $'\t'

echo
echo "=== DOMAIN COUNTS ==="
awk -F'\t' 'NR>1 {c[$1]++} END {for (k in c) print k "\t" c[k]}' "$BOARD" | sort | column -t -s $'\t'

echo
echo "=== TOP BOARD ==="
column -t -s $'\t' "$BOARD" | sed -n '1,120p'

echo
echo "=== PLAN ==="
sed -n '1,180p' "$PLAN"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_MASTER_RECOVERY_BOARD_V1_READONLY",
  "mutation": false,
  "register": "$REG",
  "board": "$BOARD",
  "plan": "$PLAN",
  "result": "RECOVERY_BOARD_READY"
}
JSON

echo
echo "============================================================"
echo "TRFMC_MASTER_RECOVERY_BOARD_V1_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
