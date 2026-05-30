#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4C_A_MANIFEST_EXPANSION_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
MANIFEST_JSON="$OUT/portal_os_manifest_candidate.json"
MANIFEST_TS="$OUT/portal_os_manifest_candidate.ts"
QUEUE="$OUT/module_promotion_queue.tsv"
CATEGORY="$OUT/category_matrix.tsv"
RISK="$OUT/risk_summary.tsv"
PROMOTED="$OUT/current_promoted_domains.tsv"
PLAN="$OUT/P4C_PORTAL_OS_MANIFEST_EXPANSION_PLAN.md"
BUILDLOG="$OUT/npm_build_p4c_a_readonly.log"

P4A="runtime/quality/latest_p4a_safe_v2_total_audit_readonly"
P4B="runtime/quality/latest_p4b_v21_static_polish_and_freeze"

echo "============================================================"
echo "TRFMC_P4C_A_MANIFEST_EXPANSION_READONLY"
echo "No source mutation · manifest candidate only · post P4B baseline"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -d "$P4A" ]; then
  echo "ERRORE: P4A non trovato: $P4A"
  exit 1
fi

if [ ! -d "$P4B" ]; then
  echo "ERRORE: P4B V2.1 baseline non trovata: $P4B"
  exit 1
fi

echo
echo "=== 1) BUILD SAFETY CURRENT SOURCE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 50 "$BUILDLOG" || true

echo
echo "=== 2) GENERO MANIFEST CANDIDATO DA P4A/P4B ==="

python3 - "$BASE" "$OUT" "$MANIFEST_JSON" "$MANIFEST_TS" "$QUEUE" "$CATEGORY" "$RISK" "$PROMOTED" "$PLAN" "$SUMMARY" "$BUILD_RESULT" <<'PY'
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

base = Path(sys.argv[1])
out = Path(sys.argv[2])
manifest_json = Path(sys.argv[3])
manifest_ts = Path(sys.argv[4])
queue_tsv = Path(sys.argv[5])
category_tsv = Path(sys.argv[6])
risk_tsv = Path(sys.argv[7])
promoted_tsv = Path(sys.argv[8])
plan_md = Path(sys.argv[9])
summary_json = Path(sys.argv[10])
build_result = sys.argv[11]

p4a = base / "runtime/quality/latest_p4a_safe_v2_total_audit_readonly"
p4b = base / "runtime/quality/latest_p4b_v21_static_polish_and_freeze"

def read_tsv(path):
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))

def write_tsv(path, rows, fields):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
        w.writeheader()
        for row in rows:
            w.writerow(row)

html_class = read_tsv(p4a / "html_classification.tsv")
html_inv = read_tsv(p4a / "html_inventory.tsv")
risk_rows = read_tsv(p4a / "runtime_risk_scan.tsv")
promoted_rows = read_tsv(p4a / "promoted_domains.tsv")

html_by_path = {row.get("path", ""): row for row in html_inv}
risk_by_path = defaultdict(list)
for row in risk_rows:
    risk_by_path[row.get("path", "")].append(row.get("risk", ""))

category_counts = Counter()
status_counts = Counter()
risk_counts = Counter()
queue_rows = []
manifest_modules = []

def to_int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default

def classify_status(row):
    path = row.get("path", "")
    category = row.get("category", "legacy-generic")
    mode = row.get("mode", "reference-or-promote")
    priority = row.get("priority", "P2_REVIEW")
    risks = set(risk_by_path.get(path, []))

    if priority == "P0_CORE_REFERENCE":
        return "reference"
    if "reference-only-risk" in mode:
        return "reference-risk"
    if "iframe" in risks:
        return "legacy-leaf-review"
    if "dangerous_dom" in risks:
        return "quarantine-review"
    if mode == "promote-to-react-visual-leaf":
        return "candidate-visual"
    if mode == "promote-to-react-operational-leaf":
        return "candidate-operational"
    if category in ["legacy-generic"]:
        return "reference"
    return "candidate"

def promotion_score(row):
    path = row.get("path", "")
    inv = html_by_path.get(path, {})
    category = row.get("category", "")
    mode = row.get("mode", "")
    score = to_int(row.get("score", 0))
    shell = to_int(row.get("shell_score", 0))
    canvas = to_int(inv.get("canvas", 0))
    iframe = to_int(inv.get("iframe", 0))
    script = to_int(inv.get("script", 0))
    risks = set(risk_by_path.get(path, []))

    value = score * 10 + canvas * 8 + shell * 4 + min(script, 20)

    if category in ["3d-rf-visual-twin", "antenna-system", "fft-dsp-signal", "5g-core-ran", "war-room", "rf-metrology"]:
        value += 40
    if "visual" in mode:
        value += 25
    if "operational" in mode:
        value += 25
    if iframe:
        value -= 35
    if "dangerous_dom" in risks:
        value -= 50
    if category == "legacy-generic":
        value -= 20

    return value

for row in html_class:
    path = row.get("path", "")
    inv = html_by_path.get(path, {})
    category = row.get("category", "legacy-generic")
    status = classify_status(row)
    score = promotion_score(row)
    risks = sorted(set(risk_by_path.get(path, [])))

    category_counts[category] += 1
    status_counts[status] += 1
    for risk in risks:
        risk_counts[risk] += 1

    module_id = path.replace("frontend/public/", "").replace(".html", "").lower()
    module_id = "".join(ch if ch.isalnum() else "-" for ch in module_id).strip("-")

    item = {
        "id": module_id,
        "title": row.get("title", "-"),
        "category": category,
        "source": path,
        "route": row.get("route_guess", "#" + module_id),
        "status": status,
        "mode": row.get("mode", "-"),
        "priority": row.get("priority", "-"),
        "promotionScore": score,
        "shellScore": to_int(row.get("shell_score", 0)),
        "canvas": to_int(inv.get("canvas", 0)),
        "iframe": to_int(inv.get("iframe", 0)),
        "script": to_int(inv.get("script", 0)),
        "risks": risks,
        "target": "promote-react" if status.startswith("candidate") else ("reference-only" if status.startswith("reference") else "manual-review"),
    }
    manifest_modules.append(item)

    queue_rows.append({
        "rank": 0,
        "module_id": module_id,
        "title": item["title"],
        "category": category,
        "status": status,
        "target": item["target"],
        "promotion_score": score,
        "canvas": item["canvas"],
        "iframe": item["iframe"],
        "shell_score": item["shellScore"],
        "risks": ",".join(risks) if risks else "-",
        "source": path,
    })

queue_rows.sort(key=lambda row: (-int(row["promotion_score"]), row["category"], row["source"]))
for idx, row in enumerate(queue_rows, 1):
    row["rank"] = idx

manifest_modules.sort(key=lambda row: (-int(row["promotionScore"]), row["category"], row["source"]))

category_rows = []
for category, count in sorted(category_counts.items()):
    category_rows.append({
        "category": category,
        "total": count,
        "candidate": sum(1 for m in manifest_modules if m["category"] == category and str(m["status"]).startswith("candidate")),
        "reference": sum(1 for m in manifest_modules if m["category"] == category and str(m["status"]).startswith("reference")),
        "review": sum(1 for m in manifest_modules if m["category"] == category and "review" in str(m["status"])),
        "top_score": max([m["promotionScore"] for m in manifest_modules if m["category"] == category] or [0]),
    })

risk_summary_rows = []
for risk, count in sorted(risk_counts.items(), key=lambda x: (-x[1], x[0])):
    risk_summary_rows.append({
        "risk": risk,
        "count": count,
        "interpretation": {
            "iframe": "legacy leaf only; no architectural iframe",
            "dangerous_dom": "manual rewrite before React promotion",
            "external_url": "review offline/air-gapped readiness",
            "cdn": "must be localized before enterprise packaging",
            "html_runtime_link": "must not become default runtime navigation",
        }.get(risk, "review"),
    })

# Inject confirmed promoted React modules at the top as canonical internal modules.
canonical_modules = [
    {
        "id": "portal-os-home",
        "title": "Unified Portal OS Home",
        "category": "portal-os",
        "source": "frontend/src/portal-os/PortalOSRoot.tsx",
        "route": "#portal-os-preview",
        "status": "promoted",
        "mode": "native-react",
        "priority": "P0",
        "promotionScore": 10000,
        "shellScore": 0,
        "canvas": 0,
        "iframe": 0,
        "script": 0,
        "risks": [],
        "target": "core-root",
    },
    {
        "id": "rf-physics",
        "title": "RF Physics",
        "category": "rf-physics",
        "source": "frontend/src/domains/rf-physics/RFPhysicsDomainP1.tsx",
        "route": "#rf-physics",
        "status": "promoted",
        "mode": "native-react",
        "priority": "P1",
        "promotionScore": 9000,
        "shellScore": 0,
        "canvas": 0,
        "iframe": 0,
        "script": 0,
        "risks": [],
        "target": "domain-runtime",
    },
    {
        "id": "signal-analyzer",
        "title": "Signal Analyzer",
        "category": "fft-dsp-signal",
        "source": "frontend/src/domains/signal-analyzer/SignalAnalyzerDomainP2.tsx",
        "route": "#signal-analyzer",
        "status": "promoted",
        "mode": "native-react",
        "priority": "P1",
        "promotionScore": 9000,
        "shellScore": 0,
        "canvas": 2,
        "iframe": 0,
        "script": 0,
        "risks": [],
        "target": "domain-runtime",
    },
    {
        "id": "antenna-system",
        "title": "Antenna System",
        "category": "antenna-system",
        "source": "frontend/src/domains/antenna-system/AntennaSystemDomainP3.tsx",
        "route": "#antenna-system",
        "status": "promoted",
        "mode": "native-react",
        "priority": "P1",
        "promotionScore": 9000,
        "shellScore": 0,
        "canvas": 1,
        "iframe": 0,
        "script": 0,
        "risks": [],
        "target": "domain-runtime",
    },
]

full_manifest = canonical_modules + manifest_modules

manifest = {
    "operation": "TRFMC_P4C_A_MANIFEST_EXPANSION_READONLY",
    "mutation": False,
    "source": {
        "p4a": str(p4a),
        "p4b": str(p4b),
    },
    "policy": {
        "singleSpa": True,
        "singleReactRoot": True,
        "v63AsVisualReference": True,
        "legacyHtmlAsSource": True,
        "noIframeAsArchitecture": True,
        "promotionRequiresReactRewrite": True,
    },
    "counts": {
        "totalHtmlModules": len(html_class),
        "manifestModulesIncludingPromoted": len(full_manifest),
        "categories": dict(category_counts),
        "statuses": dict(status_counts),
        "risks": dict(risk_counts),
    },
    "modules": full_manifest,
}

manifest_json.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

ts_lines = []
ts_lines.append("export type PortalOSManifestModule = {")
ts_lines.append("  id: string")
ts_lines.append("  title: string")
ts_lines.append("  category: string")
ts_lines.append("  source: string")
ts_lines.append("  route: string")
ts_lines.append("  status: string")
ts_lines.append("  mode: string")
ts_lines.append("  priority: string")
ts_lines.append("  promotionScore: number")
ts_lines.append("  shellScore: number")
ts_lines.append("  canvas: number")
ts_lines.append("  iframe: number")
ts_lines.append("  script: number")
ts_lines.append("  risks: string[]")
ts_lines.append("  target: string")
ts_lines.append("}")
ts_lines.append("")
ts_lines.append("export const portalOSManifestCandidate: PortalOSManifestModule[] = ")
ts_lines.append(json.dumps(full_manifest, indent=2, ensure_ascii=False))
ts_lines.append("")
manifest_ts.write_text("\n".join(ts_lines), encoding="utf-8")

write_tsv(queue_tsv, queue_rows[:120], [
    "rank", "module_id", "title", "category", "status", "target", "promotion_score",
    "canvas", "iframe", "shell_score", "risks", "source"
])
write_tsv(category_tsv, category_rows, ["category", "total", "candidate", "reference", "review", "top_score"])
write_tsv(risk_tsv, risk_summary_rows, ["risk", "count", "interpretation"])
write_tsv(promoted_tsv, promoted_rows, ["label", "marker", "count_files", "files"])

top_queue = queue_rows[:20]

plan = []
plan.append("# P4C Portal OS Manifest Expansion Plan")
plan.append("")
plan.append("## Esito")
plan.append("")
plan.append("Questo step non modifica il codice sorgente. Produce il manifest candidato completo per trasformare il portale in un Portal OS unico.")
plan.append("")
plan.append("## Regola")
plan.append("")
plan.append("- Il manifest governa i moduli.")
plan.append("- Gli HTML legacy restano sorgente o leaf controllata.")
plan.append("- I moduli con dangerous DOM devono essere riscritti in React prima della promozione.")
plan.append("- I moduli con iframe possono essere reference/leaf provvisori, non architettura finale.")
plan.append("- P4B V2.1 resta la baseline root.")
plan.append("")
plan.append("## Priorità promozione consigliata")
plan.append("")
for row in top_queue[:12]:
    plan.append(f"- {row['rank']}. {row['title']} [{row['category']}] -> {row['target']} score={row['promotion_score']} source={row['source']}")
plan.append("")
plan.append("## Prossimo step")
plan.append("")
plan.append("P4C-B deve prendere questo manifest candidato e aggiornare `frontend/src/portal-os/portalManifest.ts` in modo controllato, mantenendo P4B V2.1 come root.")
plan_md.write_text("\n".join(plan) + "\n", encoding="utf-8")

summary = {
    "timestamp": out.name.replace("TRFMC_P4C_A_MANIFEST_EXPANSION_READONLY_", ""),
    "operation": "TRFMC_P4C_A_MANIFEST_EXPANSION_READONLY",
    "mutation": False,
    "build_result": build_result,
    "p4b_baseline": str(p4b),
    "html_modules": len(html_class),
    "manifest_modules_including_promoted": len(full_manifest),
    "category_count": len(category_counts),
    "status_count": dict(status_counts),
    "risk_count": dict(risk_counts),
    "top_candidate": top_queue[0] if top_queue else {},
    "manifest_json": str(manifest_json),
    "manifest_ts_candidate": str(manifest_ts),
    "promotion_queue": str(queue_tsv),
    "category_matrix": str(category_tsv),
    "risk_summary": str(risk_tsv),
    "plan": str(plan_md),
    "result": "P4C_A_MANIFEST_CANDIDATE_READY" if build_result == "PASS" else "REVIEW_BUILD",
}
summary_json.write_text(json.dumps(summary, indent=4, ensure_ascii=False), encoding="utf-8")
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4c_a_manifest_expansion_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== CATEGORY MATRIX ==="
column -t -s $'\t' "$CATEGORY" | sed -n '1,120p'

echo
echo "=== PROMOTION QUEUE TOP 40 ==="
column -t -s $'\t' "$QUEUE" | sed -n '1,42p'

echo
echo "=== RISK SUMMARY ==="
column -t -s $'\t' "$RISK" | sed -n '1,80p'

echo
echo "============================================================"
echo "TRFMC_P4C_A_MANIFEST_EXPANSION_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
