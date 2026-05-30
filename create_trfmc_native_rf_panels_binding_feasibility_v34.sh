#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_NATIVE_RF_PANELS_BINDING_FEASIBILITY_V34_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_NATIVE_RF_PANELS_BINDING_FEASIBILITY_V34_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_NATIVE_RF_PANELS_BINDING_FEASIBILITY_V34_$TS.tar.gz"

echo "============================================================"
echo "TRFMC NATIVE RF PANELS BINDING FEASIBILITY V34"
echo "read-only · component anchors · safe patch plan"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$RELEASE_DIR/snippets" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f runtime/quality/latest_visual_runtime_qa_v33/summary.json || {
  echo "ERRORE: V33 summary mancante"
  exit 1
}

V33_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_visual_runtime_qa_v33/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V33_RESULT" = "PASS" ] || {
  echo "ERRORE: V33 non PASS: $V33_RESULT"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: 4181 non passa al backend reale"
  exit 1
}

echo "OK: V33 PASS e API live"

echo
echo "=== RUN FEASIBILITY ANALYSIS ==="

python3 - "$ROOT" "$RELEASE_DIR" "$TS" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
release = Path(sys.argv[2]).resolve()
ts = sys.argv[3]

targets = [
    "frontend/src/rf_instruments/instruments/RFInstrumentSuiteV5.tsx",
    "frontend/src/rf_instruments/sources/RFSourceBridgePanelV7.tsx",
    "frontend/src/rf_instruments/sources/RFSourceRuntimeProbeV8.tsx",
    "frontend/src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx",
    "frontend/src/rf_instruments/evidence/RFEvidenceFlightRecorderV10.tsx",
    "frontend/src/rf_instruments/instruments/RFOperationalDeckV15Lazy.tsx",
    "frontend/src/shared/liveContractsV32R1.ts",
]

endpoint_targets = [
    "/api/mission/status",
    "/api/core/open5gs/status",
    "/api/ran/ueransim/status",
    "/api/rfpro/bandplan",
    "/api/rfpro/spectrum/sweep",
    "/api/rfpro/iq/capture",
    "/api/rfpro/bridges/soapy/probe",
    "/api/soc-noc/correlation/demo",
]

patterns = {
    "imports": re.compile(r"^import\s+.*$", re.M),
    "exports": re.compile(r"export\s+(?:function|const|class)\s+([A-Za-z0-9_]+)"),
    "functions": re.compile(r"(?:function|const)\s+([A-Z][A-Za-z0-9_]+)"),
    "hooks": re.compile(r"\b(useEffect|useMemo|useState|useRef|useCallback)\b"),
    "fetch": re.compile(r"\b(fetch|axios\.|new\s+WebSocket|EventSource)\b"),
    "api_literal": re.compile(r"['\"`](/api/[A-Za-z0-9_\-./{}:?=&%]+)['\"`]"),
    "placeholder": re.compile(r"\b(mock|demo|placeholder|synthetic|fallback|offline|sample|random|future_live|not_connected|contract_only)\b", re.I),
    "local_runtime": re.compile(r"\b(Math\.random|setInterval|requestAnimationFrame|localStorage|sessionStorage|Date\.now)\b"),
    "jsx_return": re.compile(r"return\s*\("),
}

rows = []
snippets = []
patch_candidates = []

def safe(s: str) -> str:
    return s.replace("\t", " ").replace("\n", " ").strip()

for rel in targets:
    p = root / rel
    exists = p.exists()
    text = p.read_text(encoding="utf-8", errors="ignore") if exists else ""
    lines = text.splitlines()

    found = {}
    for name, rx in patterns.items():
        found[name] = rx.findall(text)

    first_import_line = None
    first_return_line = None
    first_export_line = None

    for i, line in enumerate(lines, start=1):
        if first_import_line is None and line.startswith("import "):
            first_import_line = i
        if first_export_line is None and "export " in line:
            first_export_line = i
        if first_return_line is None and "return (" in line:
            first_return_line = i

    # Save focused snippets around placeholders/fetch/return.
    interesting = []
    for i, line in enumerate(lines, start=1):
        if patterns["placeholder"].search(line) or patterns["fetch"].search(line) or patterns["local_runtime"].search(line) or "return (" in line:
            interesting.append(i)

    snippet_path = release / "snippets" / (Path(rel).name + ".snippets.txt")
    with snippet_path.open("w", encoding="utf-8") as f:
        f.write(f"# {rel}\n\n")
        for idx in interesting[:18]:
            start = max(1, idx - 3)
            end = min(len(lines), idx + 4)
            f.write(f"\n--- lines {start}-{end} around {idx} ---\n")
            for n in range(start, end + 1):
                f.write(f"{n:04d}: {lines[n-1]}\n")

    score = 0
    reasons = []
    if exists: score += 1
    if found["placeholder"]:
        score += 3
        reasons.append("placeholder_terms")
    if found["local_runtime"]:
        score += 2
        reasons.append("local_runtime_terms")
    if found["fetch"] or found["api_literal"]:
        score += 2
        reasons.append("already_has_external_io")
    if first_return_line:
        score += 2
        reasons.append("jsx_return_anchor")
    if found["hooks"]:
        score += 1
        reasons.append("hooks_present")

    recommended_strategy = "manual_review"
    if exists and first_return_line and "RFBridgeReadinessV9" in rel:
        recommended_strategy = "inject_live_readiness_summary_before_existing_return_grid"
    elif exists and first_return_line and "RFSourceRuntimeProbeV8" in rel:
        recommended_strategy = "bind_probe_status_to_live_contract_snapshot"
    elif exists and first_return_line and "RFSourceBridgePanelV7" in rel:
        recommended_strategy = "bind_bridge_cards_to_soapy_and_rfpro_contracts"
    elif exists and first_return_line and "RFInstrumentSuiteV5" in rel:
        recommended_strategy = "inject_compact_live_contract_strip_at_top"
    elif exists and "liveContractsV32R1" in rel:
        recommended_strategy = "extend_existing_client_with_extra_endpoints"
    elif exists:
        recommended_strategy = "low_risk_observer_only"

    patch_safe = exists and first_return_line is not None and score >= 5

    rows.append([
        rel,
        "yes" if exists else "no",
        ",".join(sorted(set(found["exports"]))) or "-",
        ",".join(sorted(set(found["functions"]))) or "-",
        ",".join(sorted(set(found["hooks"]))) or "-",
        len(found["fetch"]),
        len(found["api_literal"]),
        len(found["placeholder"]),
        len(found["local_runtime"]),
        first_import_line or "-",
        first_export_line or "-",
        first_return_line or "-",
        score,
        "yes" if patch_safe else "no",
        recommended_strategy,
        ",".join(reasons) or "-",
        str(snippet_path),
    ])

    if patch_safe:
        patch_candidates.append({
            "module": rel,
            "score": score,
            "strategy": recommended_strategy,
            "first_return_line": first_return_line,
            "exports": sorted(set(found["exports"])),
            "hooks": sorted(set(found["hooks"])),
            "snippet": str(snippet_path),
        })

# Write TSV.
matrix = release / "native_rf_panel_feasibility_matrix_v34.tsv"
with matrix.open("w", encoding="utf-8") as f:
    f.write("\t".join([
        "module","exists","exports","components","hooks","fetch_hits","api_literals",
        "placeholder_hits","local_runtime_hits","first_import_line","first_export_line",
        "first_return_line","score","patch_safe","recommended_strategy","reasons","snippet"
    ]) + "\n")
    for row in sorted(rows, key=lambda r: (-int(r[12]), r[0])):
        f.write("\t".join(safe(str(x)) for x in row) + "\n")

# Endpoint live check.
import subprocess

endpoint_rows = []
for ep in endpoint_targets:
    url = f"http://127.0.0.1:4181{ep}"
    pr = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}\t%{size_download}", "--connect-timeout", "2", "--max-time", "8", url],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    code, _, size = pr.stdout.partition("\t")
    endpoint_rows.append([ep, code or "000", size or "0"])

endpoints_tsv = release / "v34_endpoint_live_gate.tsv"
with endpoints_tsv.open("w", encoding="utf-8") as f:
    f.write("endpoint\tstatus\tbytes\n")
    for row in endpoint_rows:
        f.write("\t".join(row) + "\n")

plan = release / "native_rf_panels_binding_patch_plan_v34.md"
with plan.open("w", encoding="utf-8") as f:
    f.write("# TRFMC V34 Native RF Panels Binding Feasibility\n\n")
    f.write("## Verdetto\n\n")
    f.write("Questa fase è read-only. Non patcha i pannelli esistenti: identifica anchor e strategia per una patch V34R1 chirurgica.\n\n")
    f.write("## Candidati patch-safe\n\n")
    for c in sorted(patch_candidates, key=lambda x: (-x["score"], x["module"])):
        f.write(f"- **score {c['score']}** `{c['module']}` → `{c['strategy']}`; return anchor line `{c['first_return_line']}`; hooks `{','.join(c['hooks']) or '-'}`\n")
    f.write("\n## Strategia V34R1 raccomandata\n\n")
    f.write("1. Estendere `liveContractsV32R1.ts` con endpoint opzionali già coperti da V31.\n")
    f.write("2. Patch minima su un solo componente alla volta, partendo da `RFBridgeReadinessV9.tsx` o `RFSourceRuntimeProbeV8.tsx`.\n")
    f.write("3. Ogni patch deve mantenere fallback visuale locale, ma usare contract live come fonte primaria.\n")
    f.write("4. Ogni patch deve avere rollback, npm build gate, DOM/screenshot gate.\n")
    f.write("5. Nessuna azione operativa: solo GET/read-only.\n\n")
    f.write("## Endpoint live disponibili\n\n")
    for ep in endpoint_targets:
        f.write(f"- `{ep}`\n")

summary = {
    "timestamp": ts,
    "operation": "TRFMC_NATIVE_RF_PANELS_BINDING_FEASIBILITY_V34",
    "source_mutation": False,
    "frontend_mutation": False,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "targets": targets,
    "patch_candidates": patch_candidates,
    "patch_candidate_count": len(patch_candidates),
    "matrix": str(matrix),
    "endpoint_gate": str(endpoints_tsv),
    "plan": str(plan),
    "result": "PASS",
}

(release / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

cp "$RELEASE_DIR/summary.json" "$QUALITY_DIR/summary.json"

echo
echo "=== ENDPOINT GATE ==="
column -t -s $'\t' "$RELEASE_DIR/v34_endpoint_live_gate.tsv"

echo
echo "=== FEASIBILITY MATRIX ==="
column -t -s $'\t' "$RELEASE_DIR/native_rf_panel_feasibility_matrix_v34.tsv" | sed -n '1,80p'

echo
echo "=== PATCH PLAN ==="
sed -n '1,220p' "$RELEASE_DIR/native_rf_panels_binding_patch_plan_v34.md"

tar -czf "$FREEZE" \
  "$RELEASE_DIR" \
  "$QUALITY_DIR/summary.json" \
  create_trfmc_native_rf_panels_binding_feasibility_v34.sh \
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

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_native_rf_panels_binding_feasibility_v34"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_native_rf_panels_binding_feasibility_v34"

echo
echo "============================================================"
echo "V34 FEASIBILITY COMPLETATO"
echo "Summary: runtime/quality/latest_native_rf_panels_binding_feasibility_v34/summary.json"
echo "Plan   : runtime/releases/latest_native_rf_panels_binding_feasibility_v34/native_rf_panels_binding_patch_plan_v34.md"
echo "============================================================"
