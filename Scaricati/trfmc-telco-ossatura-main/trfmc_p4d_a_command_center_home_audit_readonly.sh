#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4D_A_COMMAND_CENTER_HOME_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

MANIFEST="frontend/src/portal-os/portalManifest.ts"
SUMMARY="$OUT/summary.json"
CATEGORY="$OUT/category_home_matrix.tsv"
LANES="$OUT/command_center_lanes.tsv"
TOP="$OUT/top_operational_modules.tsv"
RISK="$OUT/home_risk_policy.tsv"
PLAN="$OUT/P4D_COMMAND_CENTER_HOME_PLAN.md"
BUILDLOG="$OUT/npm_build_p4d_a_readonly.log"
DOM="$OUT/dom_portal_os_current.txt"
SCREEN="$OUT/portal_os_current_before_p4d_1920x1080.png"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREENERR="$OUT/chrome_screenshot.stderr.log"

echo "============================================================"
echo "TRFMC_P4D_A_COMMAND_CENTER_HOME_AUDIT_READONLY"
echo "No mutation · prepara la vera home Command Center governata dal manifest"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$MANIFEST" ]; then
  echo "ERRORE: manifest non trovato: $MANIFEST"
  exit 1
fi

echo
echo "=== 1) BUILD SAFETY ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 50 "$BUILDLOG" || true

echo
echo "=== 2) ANALISI MANIFEST PER HOME COMMAND CENTER ==="

python3 - "$BASE" "$OUT" "$MANIFEST" "$CATEGORY" "$LANES" "$TOP" "$RISK" "$PLAN" "$SUMMARY" "$BUILD_RESULT" <<'PY'
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

base = Path(sys.argv[1])
out = Path(sys.argv[2])
manifest_path = Path(sys.argv[3])
category_tsv = Path(sys.argv[4])
lanes_tsv = Path(sys.argv[5])
top_tsv = Path(sys.argv[6])
risk_tsv = Path(sys.argv[7])
plan_md = Path(sys.argv[8])
summary_json = Path(sys.argv[9])
build_result = sys.argv[10]

text = manifest_path.read_text(encoding="utf-8", errors="replace")

m = re.search(
    r"export const portalOSModules: PortalOSModule\[\] =\s*(\[.*?\])\s*\n\s*export const promotedPortalOSModules",
    text,
    re.S,
)
if not m:
    raise SystemExit("ERRORE: array portalOSModules non trovato nel manifest")

modules = json.loads(m.group(1))

def write_tsv(path, rows, fields):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, delimiter="\t", fieldnames=fields)
        w.writeheader()
        for row in rows:
            w.writerow(row)

def score(m):
    return int(m.get("promotionScore") or 0)

categories = Counter(m.get("category", "unknown") for m in modules)
statuses = Counter(str(m.get("status", "unknown")) for m in modules)
risks = Counter()
for m in modules:
    for r in m.get("risks") or []:
        risks[r] += 1

category_rows = []
for category, total in sorted(categories.items()):
    catmods = [m for m in modules if m.get("category") == category]
    category_rows.append({
        "category": category,
        "total": total,
        "promoted": sum(1 for m in catmods if m.get("status") == "promoted"),
        "candidate": sum(1 for m in catmods if str(m.get("status")).startswith("candidate")),
        "reference": sum(1 for m in catmods if str(m.get("status")).startswith("reference")),
        "quarantine": sum(1 for m in catmods if "quarantine" in str(m.get("status"))),
        "visual": sum(1 for m in catmods if int(m.get("canvas") or 0) > 0),
        "top_score": max([score(m) for m in catmods] or [0]),
        "home_lane": {
            "5g-core-ran": "CORE/RAN + NOC",
            "fft-dsp-signal": "DSP / SIGNAL",
            "antenna-system": "RF / ANTENNA",
            "3d-rf-visual-twin": "3D DIGITAL TWIN",
            "war-room": "WAR ROOM / EVIDENCE",
            "knowledge-academy": "KNOWLEDGE",
            "fiber-optic": "FIBER / FRONTHAUL",
            "microwave-link": "MICROWAVE",
            "rf-metrology": "METROLOGY",
            "wifi-qam": "WIFI/QAM",
            "noc-operations": "OPS",
            "signal-intelligence": "SIGINT",
        }.get(category, "REFERENCE"),
    })

lane_rules = [
    ("3D RF Visual Twin WebGL", "3d-rf-visual-twin", "center-viewport", "3D renderer, asset twin, RF spatial context"),
    ("RF / Antenna System", "antenna-system", "left-module + center-viewport", "Antenna explorer, RRU/RET/CPRI/AISG, pattern/downtilt"),
    ("FFT / DSP / Signal Analyzer", "fft-dsp-signal", "left-module + center-viewport", "Spectrum, waterfall, IQ, VSA, DSP chain"),
    ("5G Core / RAN / Identity", "5g-core-ran", "left-module + right-evidence", "Open5GS, UERANSIM, NAS, NGAP, PFCP, GTP-U"),
    ("War Room / Evidence", "war-room", "right-evidence", "Event stream, QA, scenario evidence, controlled operations"),
    ("Knowledge / Academy", "knowledge-academy", "bottom-knowledge", "Theory, formulas, procedures, glossary"),
    ("Fiber / Fronthaul", "fiber-optic", "module-leaf", "OTDR, ODF, attenuation, splice/loss budget"),
    ("Microwave Link", "microwave-link", "module-leaf", "Smith chart, link budget, Fresnel, fade margin"),
    ("RF Metrology", "rf-metrology", "module-leaf", "Calibration, uncertainty, RBW/VBW, attenuation, power"),
    ("Wi-Fi / QAM / OFDM", "wifi-qam", "module-leaf", "Wi-Fi 6/7/8, OFDM/QAM analysis"),
    ("NOC / Operations", "noc-operations", "right-evidence", "Health, status, uptime, alarms"),
    ("Signal Intelligence", "signal-intelligence", "right-evidence", "Classification, evidence, restricted workflows"),
]

lane_rows = []
for name, category, region, meaning in lane_rules:
    catmods = [m for m in modules if m.get("category") == category]
    lane_rows.append({
        "lane": name,
        "category": category,
        "home_region": region,
        "modules": len(catmods),
        "promoted": sum(1 for m in catmods if m.get("status") == "promoted"),
        "candidate": sum(1 for m in catmods if str(m.get("status")).startswith("candidate")),
        "quarantine": sum(1 for m in catmods if "quarantine" in str(m.get("status"))),
        "meaning": meaning,
    })

top_candidates = [
    m for m in modules
    if str(m.get("status")).startswith("candidate") or m.get("status") == "promoted"
]
top_candidates = sorted(top_candidates, key=lambda m: (-score(m), m.get("category", ""), m.get("title", "")))

top_rows = []
for idx, m in enumerate(top_candidates[:40], 1):
    top_rows.append({
        "rank": idx,
        "id": m.get("id", "-"),
        "title": m.get("title", "-"),
        "category": m.get("category", "-"),
        "status": m.get("status", "-"),
        "score": score(m),
        "canvas": m.get("canvas", 0),
        "target": m.get("target", "-"),
        "source": m.get("source", "-"),
    })

risk_rows = [
    {
        "risk": "dangerous_dom",
        "count": risks.get("dangerous_dom", 0),
        "home_policy": "mai montare direttamente; solo reference o rewrite React",
    },
    {
        "risk": "html_runtime_link",
        "count": risks.get("html_runtime_link", 0),
        "home_policy": "non deve diventare navigazione primaria; va governato dal manifest",
    },
    {
        "risk": "cdn",
        "count": risks.get("cdn", 0),
        "home_policy": "localizzare asset prima della modalità enterprise/offline",
    },
    {
        "risk": "iframe",
        "count": risks.get("iframe", 0),
        "home_policy": "non usare come architettura; al massimo leaf temporaneo controllato",
    },
    {
        "risk": "external_url",
        "count": risks.get("external_url", 0),
        "home_policy": "review per modalità air-gapped",
    },
]

write_tsv(category_tsv, category_rows, [
    "category", "total", "promoted", "candidate", "reference", "quarantine", "visual", "top_score", "home_lane"
])
write_tsv(lanes_tsv, lane_rows, [
    "lane", "category", "home_region", "modules", "promoted", "candidate", "quarantine", "meaning"
])
write_tsv(top_tsv, top_rows, [
    "rank", "id", "title", "category", "status", "score", "canvas", "target", "source"
])
write_tsv(risk_tsv, risk_rows, ["risk", "count", "home_policy"])

plan = []
plan.append("# P4D Command Center Home Plan")
plan.append("")
plan.append("## Obiettivo")
plan.append("")
plan.append("Sostituire la home minimale del Portal OS con una Command Center Home stile V63, ma governata da React e dal manifest P4C-B.")
plan.append("")
plan.append("## Layout previsto")
plan.append("")
plan.append("```text")
plan.append("TRFMC Unified Portal OS")
plan.append("├── top status bar: port, gate, backend, bridge, mode, clock")
plan.append("├── left launcher: operational modules raggruppati per lane")
plan.append("├── center viewport: selected module preview / active mission / 3D/RF/DSP placeholder")
plan.append("├── right evidence: active module, runtime health, risk policy, event stream")
plan.append("└── bottom strip: QA baseline, build, HTTP, screenshot, freeze")
plan.append("```")
plan.append("")
plan.append("## Regole di P4D-B")
plan.append("")
plan.append("- Nessuna modifica a V42.")
plan.append("- Nessun iframe.")
plan.append("- Nessun `dangerouslySetInnerHTML`.")
plan.append("- Nessun `document.body`, `appendChild`, root secondario.")
plan.append("- Usa solo `portalOSModules` come source of truth.")
plan.append("- La vecchia `#mission-overview` resta intatta.")
plan.append("- `#portal-os-preview` diventa Command Center Home, non ancora home di default.")
plan.append("")
plan.append("## Lanes principali")
plan.append("")
for row in lane_rows:
    plan.append(f"- {row['lane']} -> {row['home_region']} | modules={row['modules']} | meaning={row['meaning']}")
plan.append("")
plan.append("## Top moduli da evidenziare nella Command Center Home")
plan.append("")
for row in top_rows[:12]:
    plan.append(f"- {row['rank']}. {row['title']} [{row['category']}] status={row['status']} score={row['score']}")
plan.append("")
plan.append("## Prossimo step")
plan.append("")
plan.append("P4D-B_COMMAND_CENTER_HOME_V63_REACT_PREVIEW_V1: mutation controllata su `PortalOSRoot.tsx` e `portal-os.css` soltanto.")
plan_md.write_text("\n".join(plan) + "\n", encoding="utf-8")

summary = {
    "timestamp": out.name.replace("TRFMC_P4D_A_COMMAND_CENTER_HOME_AUDIT_READONLY_", ""),
    "operation": "TRFMC_P4D_A_COMMAND_CENTER_HOME_AUDIT_READONLY",
    "mutation": False,
    "build_result": build_result,
    "manifest": str(manifest_path),
    "modules": len(modules),
    "categories": len(categories),
    "statuses": dict(statuses),
    "risks": dict(risks),
    "category_matrix": str(category_tsv),
    "command_center_lanes": str(lanes_tsv),
    "top_operational_modules": str(top_tsv),
    "home_risk_policy": str(risk_tsv),
    "plan": str(plan_md),
    "result": "P4D_A_COMMAND_CENTER_HOME_PLAN_READY" if build_result == "PASS" else "REVIEW_BUILD",
}
summary_json.write_text(json.dumps(summary, indent=4, ensure_ascii=False), encoding="utf-8")
PY

echo
echo "=== 3) DOM / SCREENSHOT CURRENT PORTAL OS ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    CHROME_BIN="google-chrome"
  elif command -v chromium >/dev/null 2>&1; then
    CHROME_BIN="chromium"
  else
    CHROME_BIN=""
  fi

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  fi
fi

python3 - "$SUMMARY" "$DOM_RESULT" "$SCREENSHOT_RESULT" "$DOM" "$SCREEN" <<'PY'
import json
import sys
from pathlib import Path

summary = Path(sys.argv[1])
data = json.loads(summary.read_text(encoding="utf-8"))
data["dom_result"] = sys.argv[2]
data["screenshot_result"] = sys.argv[3]
data["dom_gate"] = sys.argv[4]
data["screenshot"] = sys.argv[5]
summary.write_text(json.dumps(data, indent=4, ensure_ascii=False), encoding="utf-8")
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4d_a_command_center_home_audit_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== LANES ==="
column -t -s $'\t' "$LANES" | sed -n '1,80p'

echo
echo "=== TOP MODULES ==="
column -t -s $'\t' "$TOP" | sed -n '1,45p'

echo
echo "=== RISK POLICY ==="
column -t -s $'\t' "$RISK" | sed -n '1,40p'

echo
echo "=== PLAN ==="
sed -n '1,180p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P4D_A_COMMAND_CENTER_HOME_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
