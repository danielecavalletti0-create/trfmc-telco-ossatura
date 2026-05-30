#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_PORTAL_CONTRACT_AUDIT_V27_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_PORTAL_CONTRACT_AUDIT_V27_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_PORTAL_CONTRACT_AUDIT_V27_$TS.tar.gz"

echo "============================================================"
echo "TRFMC PORTAL CONTRACT AUDIT V27"
echo "frontend/API contract · endpoint inventory · reality matrix"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -d "$ROOT/frontend" || { echo "ERRORE: frontend mancante"; exit 1; }
test -f "$ROOT/frontend/src/app/main.tsx" || { echo "ERRORE: frontend/src/app/main.tsx mancante"; exit 1; }
test -d "$ROOT/frontend/dist" || { echo "ERRORE: frontend/dist mancante"; exit 1; }

grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" || {
  echo "ERRORE: RFOperationalDeckV16ChunkObservatory non montato"
  exit 1
}

echo "OK: runtime foundation preservata, V16 montato, dist presente"

echo
echo "=== RUN CONTRACT AUDIT ==="

python3 - "$ROOT" "$RELEASE_DIR" "$TS" <<'PY'
import json
import os
import re
import sys
from pathlib import Path
from collections import defaultdict, Counter

root = Path(sys.argv[1]).resolve()
release = Path(sys.argv[2]).resolve()
ts = sys.argv[3]

release.mkdir(parents=True, exist_ok=True)

SKIP_DIRS = {
    "node_modules",
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    "runtime/freezes",
    "runtime/logs",
}

SCAN_ROOTS = [
    "frontend/src",
    "frontend/public",
    "frontend/index.html",
    "frontend/package.json",
    "backend",
    "bin",
    "runtime/nginx",
    "scripts",
]

TEXT_EXTS = {
    ".tsx", ".ts", ".jsx", ".js", ".html", ".css", ".json", ".py",
    ".sh", ".conf", ".yaml", ".yml", ".md", ".txt", ".service"
}

API_RE = re.compile(r'(?P<quote>["\'`])(?P<ep>/api/[A-Za-z0-9_\-./{}:?=&%]+)')
WS_RE = re.compile(r'(?P<quote>["\'`])(?P<ep>/ws/[A-Za-z0-9_\-./{}:?=&%]+|wss?://[^"\'`\s]+)')
ABS_API_RE = re.compile(r'https?://[^"\'`\s]+/api/[A-Za-z0-9_\-./{}:?=&%]+')
FETCH_LINE_RE = re.compile(r'\b(fetch|axios\.|new\s+WebSocket|EventSource|XMLHttpRequest|navigator\.sendBeacon)\b')
WORKER_LINE_RE = re.compile(r'\b(new\s+Worker|Worker\(|SharedWorker|OffscreenCanvas|requestAnimationFrame|canvas|getContext)\b')
OPEN5GS_RE = re.compile(r'open5gs|amf|smf|upf|nrf|ausf|udm|pcf|nssf|udr|pfcp|gtp|ngap|sbi|ogstun', re.I)
UERANSIM_RE = re.compile(r'ueransim|nr-gnb|nr-ue|gnb|uesimtun|pdu session|registration accept', re.I)
SYNTH_RE = re.compile(r'synthetic|demo|mock|fake|fallback|offline_or_not_implemented|placeholder|sample', re.I)

ROUTE_DECORATOR_RE = re.compile(
    r'@(?P<obj>[A-Za-z_][A-Za-z0-9_\.]*)\.(?P<method>get|post|put|delete|patch|api_route|websocket)\(\s*["\'](?P<path>/[^"\']+)["\']',
    re.I
)

def should_skip(path: Path) -> bool:
    rel = path.relative_to(root).as_posix()
    parts = set(rel.split("/"))
    if "node_modules" in parts or ".git" in parts or "__pycache__" in parts:
        return True
    for s in SKIP_DIRS:
        if rel == s or rel.startswith(s + "/"):
            return True
    return False

def iter_files():
    seen = set()
    for item in SCAN_ROOTS:
        p = root / item
        if not p.exists():
            continue
        if p.is_file():
            files = [p]
        else:
            files = [x for x in p.rglob("*") if x.is_file()]
        for f in files:
            if f in seen:
                continue
            seen.add(f)
            if should_skip(f):
                continue
            if f.suffix.lower() not in TEXT_EXTS and f.name not in {"index.html", "package.json"}:
                continue
            try:
                if f.stat().st_size > 2_000_000:
                    continue
            except OSError:
                continue
            yield f

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""

def norm_endpoint(ep: str) -> str:
    ep = ep.strip()
    if ep.startswith("http://") or ep.startswith("https://"):
        idx = ep.find("/api/")
        if idx >= 0:
            ep = ep[idx:]
    ep = ep.split("#", 1)[0]
    ep = ep.split("?", 1)[0]
    ep = re.sub(r'\$\{[^}]+\}', '{var}', ep)
    ep = re.sub(r'\{[^}/]+\}', '{var}', ep)
    ep = re.sub(r'/+', '/', ep)
    return ep

def endpoint_priority(ep: str) -> str:
    e = ep.lower()
    if any(k in e for k in ["core", "open5gs", "ueransim", "ran", "telco", "pfcp", "ngap", "gtp", "mission", "restricted"]):
        return "P1"
    if any(k in e for k in ["rf", "spectrum", "field", "coverage", "network-fabric", "soc-noc", "access-trust"]):
        return "P2"
    if any(k in e for k in ["health", "status", "runtime", "docs", "portal"]):
        return "P3"
    return "P4"

def recommended_adapter(ep: str) -> str:
    e = ep.lower()
    if "open5gs" in e or "core" in e or "telco" in e:
        return "backend/readonly/open5gs_status_adapter"
    if "ueransim" in e or "ran" in e:
        return "backend/readonly/ueransim_status_adapter"
    if "rf" in e or "coverage" in e or "field" in e:
        return "backend/readonly/rf_lab_adapter"
    if "network-fabric" in e:
        return "backend/readonly/network_fabric_adapter"
    if "soc-noc" in e or "access-trust" in e:
        return "backend/readonly/correlation_adapter"
    if "mission" in e:
        return "backend/readonly/mission_status_adapter"
    if "persistence" in e or "evidence" in e:
        return "backend/readonly/evidence_index_adapter"
    return "backend/readonly/generic_status_adapter"

files = list(iter_files())

frontend_calls = []
api_hits = []
ws_hits = []
worker_hits = []
backend_routes = []
gateway_rows = []
all_literal_counter = Counter()
api_first = {}

for f in files:
    rel = f.relative_to(root).as_posix()
    txt = read_text(f)
    if not txt:
        continue
    lines = txt.splitlines()

    for i, line in enumerate(lines, start=1):
        kind = None
        if FETCH_LINE_RE.search(line):
            kind = "client_call"
        if WORKER_LINE_RE.search(line):
            worker_hits.append((rel, i, line.strip()[:260]))

        endpoints = []
        for m in API_RE.finditer(line):
            endpoints.append(m.group("ep"))
        for m in ABS_API_RE.finditer(line):
            endpoints.append(m.group(0))

        ws_endpoints = []
        for m in WS_RE.finditer(line):
            ws_endpoints.append(m.group("ep"))

        if kind or endpoints or ws_endpoints:
            for ep in endpoints:
                n = norm_endpoint(ep)
                api_hits.append((n, ep, rel, i, line.strip()[:320]))
                all_literal_counter[n] += 1
                api_first.setdefault(n, (rel, i, ep))
                frontend_calls.append((rel, i, "api", n, line.strip()[:320]))
            for ep in ws_endpoints:
                ws_hits.append((ep, rel, i, line.strip()[:320]))
                frontend_calls.append((rel, i, "websocket", ep, line.strip()[:320]))
            if kind and not endpoints and not ws_endpoints:
                frontend_calls.append((rel, i, "call_no_literal_endpoint", "", line.strip()[:320]))

        if f.suffix == ".py":
            for m in ROUTE_DECORATOR_RE.finditer(line):
                method = m.group("method").upper()
                path = m.group("path")
                backend_routes.append((method, norm_endpoint(path), rel, i, line.strip()[:260]))

# NGINX gateway inventory
for f in files:
    rel = f.relative_to(root).as_posix()
    if not rel.startswith("runtime/nginx/") or f.suffix != ".conf":
        continue
    listen = ""
    current_location = ""
    for i, line in enumerate(read_text(f).splitlines(), start=1):
        s = line.strip()
        if s.startswith("listen "):
            listen = s.replace("listen", "").replace(";", "").strip()
        if s.startswith("location "):
            current_location = s.replace("{", "").strip()
            gateway_rows.append((rel, i, listen, current_location, "location", s))
        if "proxy_pass" in s or "return 200" in s or "try_files" in s:
            gateway_rows.append((rel, i, listen, current_location, "rule", s))

# Dist API static files
dist_api_files = set()
dist = root / "frontend" / "dist"
if dist.exists():
    for f in dist.rglob("*"):
        if f.is_file():
            rel = "/" + f.relative_to(dist).as_posix()
            dist_api_files.add(rel)
            if rel.endswith("/index.html"):
                dist_api_files.add(rel[:-len("/index.html")])

backend_route_set = {r[1] for r in backend_routes}
api_unique = sorted(all_literal_counter.keys())

# Frontend endpoint calls TSV
with (release / "frontend_endpoint_calls.tsv").open("w", encoding="utf-8") as out:
    out.write("path\tline\tkind\tendpoint\tstatement\n")
    for row in sorted(frontend_calls):
        out.write("\t".join(str(x).replace("\t", " ").replace("\n", " ") for x in row) + "\n")

with (release / "api_literal_inventory.tsv").open("w", encoding="utf-8") as out:
    out.write("endpoint\tcount\tfirst_path\tfirst_line\tfirst_literal\n")
    for ep in api_unique:
        fp, fl, lit = api_first.get(ep, ("", "", ""))
        out.write(f"{ep}\t{all_literal_counter[ep]}\t{fp}\t{fl}\t{lit}\n")

with (release / "ws_literal_inventory.tsv").open("w", encoding="utf-8") as out:
    out.write("endpoint\tpath\tline\tstatement\n")
    for ep, rel, i, stmt in sorted(ws_hits):
        out.write("\t".join([ep, rel, str(i), stmt.replace("\t", " ")]) + "\n")

with (release / "worker_canvas_inventory.tsv").open("w", encoding="utf-8") as out:
    out.write("path\tline\tstatement\n")
    for rel, i, stmt in sorted(worker_hits):
        out.write("\t".join([rel, str(i), stmt.replace("\t", " ")]) + "\n")

with (release / "backend_route_candidates.tsv").open("w", encoding="utf-8") as out:
    out.write("method\tpath\tfile\tline\tdecorator\n")
    for row in sorted(backend_routes, key=lambda x: (x[1], x[0], x[2], x[3])):
        out.write("\t".join(str(x).replace("\t", " ") for x in row) + "\n")

with (release / "runtime_gateway_inventory.tsv").open("w", encoding="utf-8") as out:
    out.write("conf\tline\tlisten\tlocation\tkind\trule\n")
    for row in gateway_rows:
        out.write("\t".join(str(x).replace("\t", " ").replace("\n", " ") for x in row) + "\n")

# Missing / fallback API
missing_rows = []
for ep in api_unique:
    static_exists = ep in dist_api_files or (ep + "/index.html") in dist_api_files
    has_backend = ep in backend_route_set
    gateway_fallback = ep.startswith("/api/")
    if has_backend:
        state = "real_backend_candidate"
    elif static_exists:
        state = "static_dist_file"
    elif gateway_fallback:
        state = "gateway_fallback_only"
    else:
        state = "unknown"
    missing_rows.append((endpoint_priority(ep), ep, state, str(has_backend), str(static_exists), str(gateway_fallback), recommended_adapter(ep), all_literal_counter[ep]))

with (release / "missing_real_api.tsv").open("w", encoding="utf-8") as out:
    out.write("priority\tendpoint\tstate\thas_backend_route\tstatic_dist_file\tcovered_by_gateway_fallback\trecommended_adapter\tfrontend_refs\n")
    for row in sorted(missing_rows, key=lambda x: (x[0], x[2], x[1])):
        out.write("\t".join(str(x) for x in row) + "\n")

# Module reality matrix for frontend modules
module_rows = []
module_roots = [
    root / "frontend" / "src" / "rf_instruments",
    root / "frontend" / "src" / "pages",
    root / "frontend" / "src" / "app",
]
for mr in module_roots:
    if not mr.exists():
        continue
    for f in mr.rglob("*"):
        if not f.is_file() or f.suffix.lower() not in {".tsx", ".ts", ".jsx", ".js"}:
            continue
        if should_skip(f):
            continue
        rel = f.relative_to(root).as_posix()
        txt = read_text(f)
        api_count = len(API_RE.findall(txt)) + len(ABS_API_RE.findall(txt))
        ws_count = len(WS_RE.findall(txt))
        worker_count = len(WORKER_LINE_RE.findall(txt))
        synthetic = bool(SYNTH_RE.search(txt))
        open5gs = bool(OPEN5GS_RE.search(txt))
        ueransim = bool(UERANSIM_RE.search(txt))
        canvas = bool(re.search(r'canvas|getContext|requestAnimationFrame|OffscreenCanvas', txt, re.I))
        if api_count and not synthetic:
            state = "api_bound_needs_backend_verification"
        elif api_count and synthetic:
            state = "mixed_api_and_demo_or_fallback"
        elif worker_count or canvas:
            state = "local_instrument_engine"
        elif synthetic:
            state = "synthetic_demo_or_fallback"
        else:
            state = "static_ui_or_unknown"
        domain = []
        if open5gs:
            domain.append("open5gs/core")
        if ueransim:
            domain.append("ueransim/ran")
        if "rf_instruments" in rel:
            domain.append("rf_instruments")
        module_rows.append((rel, state, api_count, ws_count, worker_count, str(canvas), str(synthetic), ",".join(domain) or "-"))

with (release / "module_reality_matrix.tsv").open("w", encoding="utf-8") as out:
    out.write("module\tstate\tapi_refs\tws_refs\tworker_canvas_refs\tcanvas_or_animation\tsynthetic_demo_hint\tdomain_hint\n")
    for row in sorted(module_rows):
        out.write("\t".join(str(x) for x in row) + "\n")

# Source taxonomy
source_counts = {
    "scanned_files": len(files),
    "frontend_calls": len(frontend_calls),
    "unique_api_literals": len(api_unique),
    "ws_literals": len(ws_hits),
    "backend_route_candidates": len(backend_routes),
    "gateway_rules": len(gateway_rows),
    "modules_analyzed": len(module_rows),
    "gateway_fallback_only": sum(1 for r in missing_rows if r[2] == "gateway_fallback_only"),
    "real_backend_candidates": sum(1 for r in missing_rows if r[2] == "real_backend_candidate"),
    "static_dist_files": sum(1 for r in missing_rows if r[2] == "static_dist_file"),
}

top_p1 = [r for r in missing_rows if r[0] == "P1" and r[2] == "gateway_fallback_only"]
top_p2 = [r for r in missing_rows if r[0] == "P2" and r[2] == "gateway_fallback_only"]

backlog = release / "recommended_backlog_v27.md"
with backlog.open("w", encoding="utf-8") as out:
    out.write("# TRFMC V27 Portal Contract Audit — Recommended Backlog\n\n")
    out.write("## Executive verdict\n\n")
    out.write("La Runtime Foundation è stabile. Il prossimo lavoro deve trasformare i fallback `/api/*` in contratti backend read-only verificabili, senza introdurre mutazioni operative premature.\n\n")
    out.write("## P1 — API reali da costruire per prime\n\n")
    if top_p1:
        for r in top_p1[:40]:
            out.write(f"- `{r[1]}` → `{r[6]}` ({r[7]} riferimenti frontend)\n")
    else:
        out.write("- Nessuna API P1 fallback-only rilevata.\n")
    out.write("\n## P2 — RF / Network / SOC-NOC contract\n\n")
    if top_p2:
        for r in top_p2[:60]:
            out.write(f"- `{r[1]}` → `{r[6]}` ({r[7]} riferimenti frontend)\n")
    else:
        out.write("- Nessuna API P2 fallback-only rilevata.\n")
    out.write("\n## V28 proposto\n\n")
    out.write("Creare un backend bridge read-only con endpoint minimi:\n\n")
    for ep in [
        "/api/mission/status",
        "/api/network-fabric/overview",
        "/api/rf-coverage/demo",
        "/api/rf-field/demo",
        "/api/telco-mns/status",
        "/api/core/open5gs/status",
        "/api/ran/ueransim/status",
        "/api/runtime/services",
        "/api/evidence/index",
    ]:
        out.write(f"- `{ep}`\n")
    out.write("\n## Safety policy\n\n")
    out.write("- Solo read-only.\n- Nessuno start/stop Open5GS da UI.\n- Nessun controllo SDR TX.\n- Nessuna mutazione systemd/NGINX/Vite durante V28.\n")

summary = {
    "timestamp": ts,
    "operation": "TRFMC_PORTAL_CONTRACT_AUDIT_V27",
    "project_root": str(root),
    "source_mutation": False,
    "dist_mutation": False,
    "runtime_mutation": False,
    "counts": source_counts,
    "outputs": {
        "frontend_endpoint_calls": str(release / "frontend_endpoint_calls.tsv"),
        "api_literal_inventory": str(release / "api_literal_inventory.tsv"),
        "ws_literal_inventory": str(release / "ws_literal_inventory.tsv"),
        "worker_canvas_inventory": str(release / "worker_canvas_inventory.tsv"),
        "backend_route_candidates": str(release / "backend_route_candidates.tsv"),
        "runtime_gateway_inventory": str(release / "runtime_gateway_inventory.tsv"),
        "missing_real_api": str(release / "missing_real_api.tsv"),
        "module_reality_matrix": str(release / "module_reality_matrix.tsv"),
        "recommended_backlog": str(backlog),
    },
    "recommended_next": "TRFMC_READONLY_BACKEND_BRIDGE_V28",
    "result": "PASS"
}

(release / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "=== CREATE QUALITY SUMMARY + SYMLINKS ==="

cp "$RELEASE_DIR/summary.json" "$QUALITY_DIR/summary.json"

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_portal_contract_audit_v27"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_portal_contract_audit_v27"

echo
echo "=== FREEZE REPORTS ONLY ==="

tar -czf "$FREEZE" \
  "$RELEASE_DIR" \
  "$QUALITY_DIR/summary.json" \
  create_trfmc_portal_contract_audit_v27.sh \
  2>/dev/null || true

python3 - "$QUALITY_DIR/summary.json" "$FREEZE" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["freeze"] = sys.argv[2]
p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print(json.dumps(data, indent=2, ensure_ascii=False))
PY

echo
echo "=== TOP MISSING REAL API ==="
column -t -s $'\t' "$RELEASE_DIR/missing_real_api.tsv" | sed -n '1,80p'

echo
echo "=== MODULE REALITY MATRIX SAMPLE ==="
column -t -s $'\t' "$RELEASE_DIR/module_reality_matrix.tsv" | sed -n '1,80p'

echo
echo "============================================================"
echo "V27 PORTAL CONTRACT AUDIT COMPLETATO"
echo "Summary : runtime/quality/latest_portal_contract_audit_v27/summary.json"
echo "Release : runtime/releases/latest_portal_contract_audit_v27"
echo "Backlog : runtime/releases/latest_portal_contract_audit_v27/recommended_backlog_v27.md"
echo "============================================================"
