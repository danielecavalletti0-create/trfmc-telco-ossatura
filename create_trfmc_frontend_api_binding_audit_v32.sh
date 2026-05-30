#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_FRONTEND_API_BINDING_AUDIT_V32_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_FRONTEND_API_BINDING_AUDIT_V32_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_FRONTEND_API_BINDING_AUDIT_V32_$TS.tar.gz"

echo "============================================================"
echo "TRFMC FRONTEND/API BINDING AUDIT V32"
echo "read-only scan · React/API binding plan · no mutation"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -d "$ROOT/frontend/src" || { echo "ERRORE: frontend/src mancante"; exit 1; }
test -f "$ROOT/frontend/src/app/main.tsx" || { echo "ERRORE: frontend/src/app/main.tsx mancante"; exit 1; }
test -f "$ROOT/backend/readonly_bridge_v28/app.py" || { echo "ERRORE: backend app.py mancante"; exit 1; }
test -f "$ROOT/runtime/quality/latest_contract_semantics_hygiene_v31r1/summary.json" || {
  echo "ERRORE: V31R1 summary mancante"
  exit 1
}

V31R1_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_contract_semantics_hygiene_v31r1/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V31R1_RESULT" = "PASS" ] || {
  echo "ERRORE: V31R1 non PASS: $V31R1_RESULT"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: proxy 4181 non sta passando al backend"
  exit 1
}

echo "OK: V31R1 PASS, frontend presente, backend reale raggiungibile"

echo
echo "=== RUN AUDIT ==="

python3 - "$ROOT" "$RELEASE_DIR" "$TS" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from collections import Counter

root = Path(sys.argv[1]).resolve()
release = Path(sys.argv[2]).resolve()
ts = sys.argv[3]

release.mkdir(parents=True, exist_ok=True)

frontend = root / "frontend" / "src"
backend_app = root / "backend" / "readonly_bridge_v28" / "app.py"

TS_EXTS = {".tsx", ".ts", ".jsx", ".js"}

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")

def iter_src():
    for p in frontend.rglob("*"):
        if p.is_file() and p.suffix in TS_EXTS:
            yield p

api_literal_re = re.compile(r'["\'`](/api/[A-Za-z0-9_\-./{}:?=&%]+)["\'`]')
fetch_re = re.compile(r'\b(fetch|axios\.|new\s+WebSocket|EventSource)\b')
react_hook_re = re.compile(r'\b(useEffect|useMemo|useState|useRef)\b')
placeholder_re = re.compile(r'\b(mock|demo|placeholder|synthetic|fallback|offline|sample|random|contract_only|future_live|not_connected)\b', re.I)
local_data_re = re.compile(r'\b(const\s+\w+\s*=\s*\[|const\s+\w+\s*=\s*\{|Math\.random|setInterval|requestAnimationFrame)\b')
component_re = re.compile(r'(?:export\s+)?(?:function|const)\s+([A-Z][A-Za-z0-9_]+)')

# Backend routes from app.py.
backend_txt = read(backend_app)
route_re = re.compile(r'@app\.(?:get|post|api_route)\(\s*["\']([^"\']+)["\']')
backend_routes = sorted(set(route_re.findall(backend_txt)))

v31_endpoints = [
    "/api/mission/status",
    "/api/core/open5gs/status",
    "/api/ran/ueransim/status",
    "/api/rfpro/bandplan",
    "/api/rfpro/spectrum/sweep",
    "/api/rfpro/iq/capture",
    "/api/rfpro/bridges/soapy/probe",
    "/api/rfpro/uav/fhss",
    "/api/rfpro/uav/profiles",
    "/api/v585/ws/spectrum",
    "/api/access-trust/rat/demo",
    "/api/access-trust/wifi/demo",
    "/api/soc-noc/correlation/demo",
    "/api/evidence/index",
    "/api/runtime/services",
    "/api/network-fabric/overview",
]

module_rows = []
api_rows = []
placeholder_rows = []
candidate_rows = []
component_rows = []
domain_counter = Counter()

for path in iter_src():
    rel = path.relative_to(root).as_posix()
    txt = read(path)
    lines = txt.splitlines()

    comps = component_re.findall(txt)
    apis = sorted(set(m.group(1).split("?")[0] for m in api_literal_re.finditer(txt)))
    has_fetch = bool(fetch_re.search(txt))
    hooks = sorted(set(react_hook_re.findall(txt)))
    placeholder_hits = []
    local_hits = []
    for i, line in enumerate(lines, start=1):
        if placeholder_re.search(line):
            placeholder_hits.append((i, line.strip()[:260]))
        if local_data_re.search(line):
            local_hits.append((i, line.strip()[:260]))
        if fetch_re.search(line) or api_literal_re.search(line):
            api_rows.append((rel, i, ",".join(api_literal_re.findall(line)), line.strip()[:300]))

    lower_rel = rel.lower()
    lower_txt = txt.lower()
    domains = []
    if "rf_instruments" in lower_rel or "rfpro" in lower_txt or "spectrum" in lower_txt or "iq" in lower_txt:
        domains.append("rfpro")
    if "open5gs" in lower_txt or "core" in lower_txt:
        domains.append("5g-core")
    if "ueransim" in lower_txt or "ran" in lower_txt:
        domains.append("5g-ran")
    if "soc" in lower_txt or "noc" in lower_txt or "correlation" in lower_txt:
        domains.append("soc-noc")
    if "access-trust" in lower_txt or "wifi" in lower_txt:
        domains.append("access-trust")
    if not domains:
        domains.append("general")

    for d in domains:
        domain_counter[d] += 1

    # Candidate binding score.
    score = 0
    reasons = []
    recommended = []

    if has_fetch or apis:
        score += 3
        reasons.append("already_has_api_call")
    if placeholder_hits:
        score += 2
        reasons.append("placeholder_or_demo_terms")
    if local_hits:
        score += 1
        reasons.append("local_static_or_runtime_data")
    if "rfpro" in domains:
        score += 3
        recommended += ["/api/rfpro/bandplan", "/api/rfpro/spectrum/sweep", "/api/rfpro/iq/capture"]
    if "5g-core" in domains:
        score += 3
        recommended += ["/api/core/open5gs/status"]
    if "5g-ran" in domains:
        score += 3
        recommended += ["/api/ran/ueransim/status"]
    if "soc-noc" in domains:
        score += 3
        recommended += ["/api/soc-noc/correlation/demo"]
    if "access-trust" in domains:
        score += 3
        recommended += ["/api/access-trust/rat/demo", "/api/access-trust/wifi/demo"]
    if "general" in domains and ("mission" in lower_txt or "status" in lower_txt):
        score += 2
        recommended += ["/api/mission/status", "/api/runtime/services"]

    recommended = sorted(set(recommended))

    module_rows.append((
        rel,
        ",".join(comps) if comps else "-",
        ",".join(domains),
        "yes" if has_fetch else "no",
        ",".join(hooks) if hooks else "-",
        len(apis),
        len(placeholder_hits),
        len(local_hits),
        score,
        ",".join(reasons) if reasons else "-",
        ",".join(recommended) if recommended else "-",
    ))

    for comp in comps:
        component_rows.append((comp, rel, ",".join(domains), score, ",".join(recommended) if recommended else "-"))

    for i, snippet in placeholder_hits[:12]:
        placeholder_rows.append((rel, i, "placeholder", snippet))
    for i, snippet in local_hits[:12]:
        placeholder_rows.append((rel, i, "local_data", snippet))

    if score >= 5:
        priority = "P1" if any(d in domains for d in ["rfpro", "5g-core", "5g-ran"]) else "P2"
        candidate_rows.append((
            priority,
            score,
            rel,
            ",".join(comps) if comps else "-",
            ",".join(domains),
            ",".join(recommended) if recommended else "-",
            ",".join(reasons) if reasons else "-",
        ))

# Write reports.
def tsv(path: Path, header: list[str], rows):
    with path.open("w", encoding="utf-8") as f:
        f.write("\t".join(header) + "\n")
        for row in rows:
            f.write("\t".join(str(x).replace("\t", " ").replace("\n", " ") for x in row) + "\n")

tsv(
    release / "frontend_module_binding_matrix.tsv",
    ["module","components","domain_hint","has_fetch","react_hooks","api_literal_count","placeholder_hits","local_data_hits","binding_score","reasons","recommended_v31_endpoints"],
    sorted(module_rows, key=lambda r: (-int(r[8]), r[0])),
)

tsv(
    release / "frontend_api_literals.tsv",
    ["module","line","api_literals","statement"],
    api_rows,
)

tsv(
    release / "frontend_placeholder_localdata_hits.tsv",
    ["module","line","kind","statement"],
    placeholder_rows,
)

tsv(
    release / "binding_candidates_v32.tsv",
    ["priority","score","module","components","domain_hint","recommended_v31_endpoints","reasons"],
    sorted(candidate_rows, key=lambda r: (r[0], -int(r[1]), r[2])),
)

tsv(
    release / "component_index_v32.tsv",
    ["component","module","domain_hint","binding_score","recommended_v31_endpoints"],
    sorted(component_rows, key=lambda r: (-int(r[3]), r[0])),
)

tsv(
    release / "backend_v31_endpoint_inventory.tsv",
    ["endpoint","covered_in_v31_target_set"],
    [(ep, "yes" if ep in v31_endpoints else "backend_route") for ep in backend_routes],
)

# Markdown plan.
plan = release / "frontend_api_binding_patch_plan_v32.md"
with plan.open("w", encoding="utf-8") as f:
    f.write("# TRFMC V32 Frontend/API Binding Audit\n\n")
    f.write("## Executive verdict\n\n")
    f.write("V31R1 è PASS. Il prossimo lavoro deve collegare pochi pannelli React ai contratti read-only esposti da `4181`, evitando mutazioni massive del frontend.\n\n")
    f.write("## Binding candidates prioritari\n\n")
    for row in sorted(candidate_rows, key=lambda r: (r[0], -int(r[1]), r[2]))[:30]:
        priority, score, module, comps, domains, endpoints, reasons = row
        f.write(f"- **{priority} score {score}** `{module}` — components `{comps}` — domains `{domains}` → `{endpoints}` — reasons `{reasons}`\n")
    f.write("\n## Endpoint V31 consigliati per il primo binding V32R1\n\n")
    first = [
        "/api/mission/status",
        "/api/core/open5gs/status",
        "/api/ran/ueransim/status",
        "/api/rfpro/bandplan",
        "/api/rfpro/spectrum/sweep",
        "/api/soc-noc/correlation/demo",
    ]
    for ep in first:
        f.write(f"- `{ep}`\n")
    f.write("\n## Policy di patch V32R1\n\n")
    f.write("- Patch minima: creare un client API centrale, non duplicare fetch ovunque.\n")
    f.write("- Usare `4181` come base API per coerenza dev/prod locale.\n")
    f.write("- Mantenere fallback UI locale solo come fallback visuale, non come fonte primaria.\n")
    f.write("- Nessuna azione operativa: solo GET/read-only.\n")
    f.write("- Nessun comando SDR, nessun start/stop Open5GS/UERANSIM.\n")

summary = {
    "timestamp": ts,
    "operation": "TRFMC_FRONTEND_API_BINDING_AUDIT_V32",
    "source_mutation": False,
    "frontend_mutation": False,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "counts": {
        "modules_scanned": len(module_rows),
        "api_literal_rows": len(api_rows),
        "placeholder_localdata_rows": len(placeholder_rows),
        "binding_candidates": len(candidate_rows),
        "components_indexed": len(component_rows),
        "backend_routes": len(backend_routes),
        "domain_counter": dict(domain_counter),
    },
    "outputs": {
        "frontend_module_binding_matrix": str(release / "frontend_module_binding_matrix.tsv"),
        "frontend_api_literals": str(release / "frontend_api_literals.tsv"),
        "frontend_placeholder_localdata_hits": str(release / "frontend_placeholder_localdata_hits.tsv"),
        "binding_candidates": str(release / "binding_candidates_v32.tsv"),
        "component_index": str(release / "component_index_v32.tsv"),
        "backend_v31_endpoint_inventory": str(release / "backend_v31_endpoint_inventory.tsv"),
        "patch_plan": str(plan),
    },
    "recommended_next": "TRFMC_FRONTEND_API_BINDING_V32R1",
    "result": "PASS",
}

(release / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "=== QUALITY SUMMARY ==="

cp "$RELEASE_DIR/summary.json" "$QUALITY_DIR/summary.json"

tar -czf "$FREEZE" \
  "$RELEASE_DIR" \
  "$QUALITY_DIR/summary.json" \
  create_trfmc_frontend_api_binding_audit_v32.sh \
  2>/dev/null || true

python3 - "$QUALITY_DIR/summary.json" "$FREEZE" <<'PY'
import json, sys
from pathlib import Path
p=Path(sys.argv[1])
d=json.loads(p.read_text())
d["freeze"]=sys.argv[2]
p.write_text(json.dumps(d, indent=2, ensure_ascii=False))
print(json.dumps(d, indent=2, ensure_ascii=False))
PY

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_frontend_api_binding_audit_v32"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_frontend_api_binding_audit_v32"

echo
echo "=== TOP BINDING CANDIDATES ==="
column -t -s $'\t' "$RELEASE_DIR/binding_candidates_v32.tsv" | sed -n '1,80p'

echo
echo "=== PATCH PLAN ==="
sed -n '1,220p' "$RELEASE_DIR/frontend_api_binding_patch_plan_v32.md"

echo
echo "============================================================"
echo "V32 FRONTEND/API BINDING AUDIT COMPLETATO"
echo "Summary: runtime/quality/latest_frontend_api_binding_audit_v32/summary.json"
echo "Plan   : runtime/releases/latest_frontend_api_binding_audit_v32/frontend_api_binding_patch_plan_v32.md"
echo "============================================================"
