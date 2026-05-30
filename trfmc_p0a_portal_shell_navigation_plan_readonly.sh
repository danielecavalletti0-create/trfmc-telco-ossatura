#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P0A_PORTAL_SHELL_NAVIGATION_PLAN_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

BOARD_DIR="$(readlink -f runtime/quality/latest_master_recovery_board_v1_readonly 2>/dev/null || true)"
BOARD="$BOARD_DIR/master_recovery_board.tsv"

SUMMARY="$OUT/summary.json"
SOURCE_GATE="$OUT/source_gate.tsv"
P0_CANDIDATES="$OUT/p0_shell_candidates.tsv"
DOMAIN_REGISTRY="$OUT/canonical_domain_registry_v1.tsv"
PROMOTION_WAVE="$OUT/p0_promotion_wave_v1.tsv"
APP_SCAN="$OUT/react_shell_scan.tsv"
PLAN="$OUT/TRFMC_P0A_PORTAL_SHELL_NAVIGATION_PLAN_V1.md"
BUILDLOG="$OUT/npm_build_p0a_readonly.log"
HTTP="$OUT/http.tsv"

echo "============================================================"
echo "TRFMC_P0A_PORTAL_SHELL_NAVIGATION_PLAN_READONLY"
echo "Read-only · no source mutation · no backend mutation · no CSS patch"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$BOARD" ]; then
  echo "ERRORE: Recovery Board non trovato: $BOARD"
  exit 1
fi

echo
echo "=== 1) SOURCE GATE ==="

{
  echo -e "path\texists\tbytes\tlines\trole"
  for f in \
    "frontend/src/app/main.tsx" \
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx" \
    "frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx" \
    "frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx" \
    "frontend/src/styles.css" \
    "frontend/package.json" \
    "frontend/vite.config.ts" \
    "backend/readonly_bridge_v28/app.py"
  do
    if [ -f "$f" ]; then
      echo -e "$f\tYES\t$(stat -c%s "$f")\t$(wc -l < "$f" | tr -d ' ')\tcore_candidate"
    else
      echo -e "$f\tNO\t0\t0\tmissing"
    fi
  done
} | tee "$SOURCE_GATE" | column -t -s $'\t'

echo
echo "=== 2) REACT SHELL SCAN ==="

{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "full-engineering-stack|mission-overview|MissionLayoutOrchestrator|EngineeringContentEnrichment|EngineeringConsoleExpansion|hash|window.location|routes|activeSection|nav|navigation" \
    frontend/src/app/main.tsx frontend/src/layout_orchestrator frontend/src/styles.css 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,260)}'
} | tee "$APP_SCAN" | sed -n '1,140p'

echo
echo "=== 3) COSTRUISCO P0 CANDIDATES / REGISTRY / WAVE ==="

python3 - "$BOARD" "$P0_CANDIDATES" "$DOMAIN_REGISTRY" "$PROMOTION_WAVE" "$PLAN" <<'PY'
import csv
import sys
from pathlib import Path

board = Path(sys.argv[1])
p0_out = Path(sys.argv[2])
registry_out = Path(sys.argv[3])
wave_out = Path(sys.argv[4])
plan_out = Path(sys.argv[5])

rows = list(csv.DictReader(board.open(encoding="utf-8"), delimiter="\t"))

def get(domain=None, action=None):
    out = []
    for r in rows:
        if domain and r["domain"] != domain:
            continue
        if action and r["action"] != action:
            continue
        out.append(r)
    return out

p0 = [r for r in rows if r["action"] == "P0_PROMOTE_REVIEW"]
mission = [r for r in rows if r["domain"] == "01_Mission_Control"]
unclassified_p0 = [r for r in p0 if r["domain"] == "00_Unclassified"]

def score_candidate(r):
    p = r["path"].lower()
    score = 0
    reason = []

    if "integration_control_room" in p:
        score += 100
        reason.append("integration control room")
    if "portal_index" in p:
        score += 90
        reason.append("portal index")
    if "official_safe_entrypoint_v6r3" in p:
        score += 85
        reason.append("latest official safe command center")
    if "trfmc_home" in p:
        score += 80
        reason.append("home candidate")
    if p.endswith("/trfmc.html") or p.endswith("trfmc.html"):
        score += 70
        reason.append("root public entry candidate")
    if "v87g" in p or "v6r3" in p:
        score += 15
        reason.append("latest version marker")
    if int(r.get("debt_hits") or 0) > 0:
        score -= 20
        reason.append("has debt hits")

    return score, ", ".join(reason) if reason else "candidate"

p0_sorted = sorted(p0, key=lambda r: (-score_candidate(r)[0], r["path"]))

with p0_out.open("w", encoding="utf-8", newline="") as f:
    fields = ["priority","domain","path","bytes","debt_hits","status_guess","recommended_use","score","reason"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()

    for i, r in enumerate(p0_sorted, 1):
        score, reason = score_candidate(r)
        use = "REFERENCE_FOR_REACT_PROMOTION"
        if "integration_control_room" in r["path"]:
            use = "P0_CONTROL_ROOM_CONTENT_SOURCE"
        elif "portal_index" in r["path"]:
            use = "P0_INDEX_STRUCTURE_SOURCE"
        elif "official_safe_entrypoint_v6r3" in r["path"]:
            use = "P0_SHELL_BEHAVIOR_REFERENCE"
        elif "trfmc_home" in r["path"]:
            use = "P0_HOME_REFERENCE"
        elif r["path"].endswith("trfmc.html"):
            use = "P0_PUBLIC_ROOT_REFERENCE"

        w.writerow({
            "priority": f"P0.{i:02d}",
            "domain": r["domain"],
            "path": r["path"],
            "bytes": r["bytes"],
            "debt_hits": r["debt_hits"],
            "status_guess": r["status_guess"],
            "recommended_use": use,
            "score": score,
            "reason": reason,
        })

domains = [
    ("01_Mission_Control", "#mission-overview", "Mission Control", "portal shell, NOC, command deck, control room"),
    ("02_RF_Physics", "#rf-physics", "RF Physics", "Maxwell, propagation, field models, RF theory engines"),
    ("03_Signal_Analyzer", "#signal-analyzer", "Signal Analyzer", "spectrum, waterfall, I/Q, VSA, RF instruments"),
    ("04_RF_Microwave_Engineering", "#rf-microwave", "RF/Microwave", "Smith chart, microwave links, filters, RF chain"),
    ("05_Antenna_System", "#antenna-system", "Antenna System", "antenna explorer, RRU/RET/CPRI, patterns"),
    ("06_Microwave_Link", "#microwave-link", "Microwave Link", "path profile, Fresnel, fade margin"),
    ("07_Fiber_Optic", "#fiber-optic", "Fiber Optic", "OTDR, fronthaul, fiber diagnostics"),
    ("08_Private_Networks", "#private-networks", "Private Networks", "Wi-Fi, mesh, private 5G/Wi-Fi integration"),
    ("09_Core_Network", "#core-network", "Core/RAN", "Open5GS, UERANSIM, AKA, NAS, NGAP, PFCP"),
    ("10_Data_Center_Infrastructure", "#data-center", "Data Center", "power, PDU, racks, digital twin infrastructure"),
    ("11_Cyber_RF_Intelligence", "#cyber-rf-intelligence", "Cyber RF Intelligence", "evidence, cyber/RF, supervision, reports"),
    ("12_Knowledge_Base", "#knowledge-base", "Knowledge Base", "theory, procedures, glossary, doctrine"),
]

with registry_out.open("w", encoding="utf-8", newline="") as f:
    fields = ["order","domain","route_hash","label","purpose","candidate_count","primary_candidate","next_action"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()

    for idx, (domain, route, label, purpose) in enumerate(domains, 1):
        candidates = [r for r in rows if r["domain"] == domain and r["action"] in {
            "P0_PROMOTE_REVIEW",
            "PROMOTE_CANDIDATE_DEEP_REVIEW",
            "PROMOTE_CANDIDATE_REVIEW",
            "MERGE_AND_COMPLETE"
        }]
        candidates = sorted(candidates, key=lambda r: (
            0 if r["action"] == "P0_PROMOTE_REVIEW" else
            1 if r["action"] == "PROMOTE_CANDIDATE_DEEP_REVIEW" else
            2 if r["action"] == "MERGE_AND_COMPLETE" else 3,
            -int(r.get("bytes") or 0)
        ))
        primary = candidates[0]["path"] if candidates else "-"
        action = "PROMOTE_DOMAIN_ENTRY" if candidates else "CREATE_DOMAIN_PLACEHOLDER"
        w.writerow({
            "order": f"{idx:02d}",
            "domain": domain,
            "route_hash": route,
            "label": label,
            "purpose": purpose,
            "candidate_count": len(candidates),
            "primary_candidate": primary,
            "next_action": action,
        })

wave = []
wave.append(("P0A", "NO_MUTATION", "Governance", "Validate shell source, domain registry, candidate queue"))
wave.append(("P0B", "SOURCE_MUTATION", "Portal Shell", "Create canonical React registry and route map"))
wave.append(("P0C", "SOURCE_MUTATION", "Mission Control", "Promote Home / Integration Control Room / Portal Index content into React"))
wave.append(("P0D", "SOURCE_MUTATION", "Navigation", "Create single domain navigation, no iframe, no public parallel pages"))
wave.append(("P0E", "QA", "Quality Gate", "Build, HTTP, DOM marker, screenshot, placeholder/debt gate"))

with wave_out.open("w", encoding="utf-8", newline="") as f:
    fields = ["phase","type","area","objective"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    for row in wave:
        w.writerow(dict(zip(fields,row)))

action_counts = {}
domain_counts = {}
for r in rows:
    action_counts[r["action"]] = action_counts.get(r["action"], 0) + 1
    domain_counts[r["domain"]] = domain_counts.get(r["domain"], 0) + 1

md = []
md.append("# TRFMC P0A Portal Shell / Navigation Plan V1")
md.append("")
md.append("## Decisione")
md.append("")
md.append("Il prossimo sviluppo reale non deve aggiungere nuovi strumenti o endpoint. Deve promuovere il telaio ufficiale del portale.")
md.append("")
md.append("## Shell ufficiale proposta")
md.append("")
md.append("- React source shell: `frontend/src/app/main.tsx`")
md.append("- Orchestrator: `frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx`")
md.append("- Current engineering content: `EngineeringContentEnrichmentV49.tsx` + `EngineeringConsoleExpansionV4.tsx`")
md.append("- Style baseline: `frontend/src/styles.css`")
md.append("")
md.append("## Regola operativa")
md.append("")
md.append("- Gli HTML in `frontend/public` non diventano portali paralleli.")
md.append("- Gli HTML P0 diventano fonti di contenuto, layout e logica da promuovere in React.")
md.append("- Nessun iframe.")
md.append("- Nessuna patch runtime.")
md.append("- Nessun backend prima del registry frontend.")
md.append("")
md.append("## P0 candidates principali")
md.append("")
for r in p0_sorted[:12]:
    score, reason = score_candidate(r)
    md.append(f"- `{r['path']}` — score {score}; {reason}")
md.append("")
md.append("## Prossima mutazione ammessa")
md.append("")
md.append("`TRFMC_P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1`")
md.append("")
md.append("Deve creare:")
md.append("")
md.append("- `frontend/src/app/portalRegistry.ts`")
md.append("- `frontend/src/app/PortalShellNavigationP0.tsx`")
md.append("- collegamento sorgente controllato in `main.tsx` o orchestrator")
md.append("- QA: build, HTTP, DOM marker, screenshot, no iframe, no public runtime patch")
md.append("")
md.append("## Action counts")
md.append("")
for k in sorted(action_counts):
    md.append(f"- {k}: {action_counts[k]}")
md.append("")
md.append("## Domain counts")
md.append("")
for k in sorted(domain_counts):
    md.append(f"- {k}: {domain_counts[k]}")
md.append("")

plan_out.write_text("\n".join(md), encoding="utf-8")
PY

echo
echo "=== P0 SHELL CANDIDATES ==="
column -t -s $'\t' "$P0_CANDIDATES" | sed -n '1,80p'

echo
echo "=== CANONICAL DOMAIN REGISTRY ==="
column -t -s $'\t' "$DOMAIN_REGISTRY"

echo
echo "=== PROMOTION WAVE ==="
column -t -s $'\t' "$PROMOTION_WAVE"

echo
echo "=== 4) BUILD CHECK READ-ONLY ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

echo
echo "=== 5) HTTP CHECK READ-ONLY ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

SOURCE_FAILS="$(awk 'NR>1 && $2!="YES" {c++} END {print c+0}' "$SOURCE_GATE")"
P0_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$P0_CANDIDATES")"
DOMAIN_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$DOMAIN_REGISTRY")"

RESULT="P0A_READY"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi
if [ "$SOURCE_FAILS" != "0" ]; then RESULT="REVIEW_SOURCE_GATE"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P0A_PORTAL_SHELL_NAVIGATION_PLAN_READONLY",
  "mutation": false,
  "base": "$BASE",
  "board": "$BOARD",
  "source_gate": "$SOURCE_GATE",
  "react_shell_scan": "$APP_SCAN",
  "p0_shell_candidates": "$P0_CANDIDATES",
  "canonical_domain_registry": "$DOMAIN_REGISTRY",
  "promotion_wave": "$PROMOTION_WAVE",
  "plan": "$PLAN",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "source_failures": $SOURCE_FAILS,
  "p0_candidate_count": $P0_COUNT,
  "domain_count": $DOMAIN_COUNT,
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p0a_portal_shell_navigation_plan_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,180p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P0A_PORTAL_SHELL_NAVIGATION_PLAN_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
