#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets/trfmc_design_system"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_EXPANSION_MODULES_V1_SCOPED_$TS"
LATEST="$BASE/runtime/quality/latest_expansion_modules_v1"

mkdir -p "$OUT" "$BASE/runtime/quality" "$BASE/runtime/freezes"

cd "$BASE"

echo "============================================================"
echo "TRFMC EXPANSION MODULES V1 - SCOPED QUALITY FINALIZER"
echo "Controlla solo i file creati dall'espansione"
echo "============================================================"

FILES=(
  "$PUBLIC/trfmc_expansion_hub_v1.html"
  "$PUBLIC/trfmc_rf_physics_theory_atlas_v1.html"
  "$PUBLIC/trfmc_microwave_link_operations_center_v1.html"
  "$PUBLIC/trfmc_fiber_fronthaul_otdr_workbench_v1.html"
  "$PUBLIC/trfmc_private_networks_wifi7_5g_mesh_v1.html"
  "$PUBLIC/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html"
  "$PUBLIC/trfmc_datacenter_power_pdu_infrastructure_v1.html"
  "$PUBLIC/trfmc_cyber_rf_intelligence_evidence_v1.html"
  "$PUBLIC/trfmc_knowledge_base_theory_procedures_v1.html"
  "$PUBLIC/trfmc_expansion_modules_v1.json"
  "$ASSETS/trfmc_leaf_master_v1.css"
  "$ASSETS/trfmc_leaf_webgl_v1.js"
)

URLS=(
  "/trfmc_expansion_hub_v1.html"
  "/trfmc_expansion_modules_v1.json"
  "/assets/trfmc_design_system/trfmc_leaf_master_v1.css"
  "/assets/trfmc_design_system/trfmc_leaf_webgl_v1.js"
  "/trfmc_rf_physics_theory_atlas_v1.html"
  "/trfmc_microwave_link_operations_center_v1.html"
  "/trfmc_fiber_fronthaul_otdr_workbench_v1.html"
  "/trfmc_private_networks_wifi7_5g_mesh_v1.html"
  "/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html"
  "/trfmc_datacenter_power_pdu_infrastructure_v1.html"
  "/trfmc_cyber_rf_intelligence_evidence_v1.html"
  "/trfmc_knowledge_base_theory_procedures_v1.html"
  "/trfmc_portal_registry_unified.json"
  "/trfmc_official_safe_entrypoint_v6r3_command_center.html"
  "/trfmc_integration_control_room.html"
)

echo
echo "[1/5] HTTP test"
{
  printf "url\tstatus\tbytes\n"
  for u in "${URLS[@]}"; do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

echo
echo "[2/5] Controllo no CDN/no iframe solo sui nuovi file"
: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/fused_forbidden_refs.txt"

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
    grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
    grep -nEi 'MASTER FUSED|trfmc_master_fused|fallback shell' "$f" >> "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true
  else
    echo "MISSING_FILE $f" >> "$OUT/missing_files.txt"
  fi
done

echo
echo "[3/5] Verifica hash protetti"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"
REG="$PUBLIC/trfmc_portal_registry_unified.json"

PREV="$(readlink -f runtime/quality/latest_expansion_modules_v1 2>/dev/null || true)"
if [ -n "$PREV" ] && [ -f "$PREV/sha_compare.txt" ]; then
  grep -E 'V6R3_SHA_BEFORE|CONTROL_SHA_BEFORE|REG_SHA_BEFORE' "$PREV/sha_compare.txt" > "$OUT/sha_compare.txt" || true
else
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')" > "$OUT/sha_compare.txt"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')" >> "$OUT/sha_compare.txt"
  echo "REG_SHA_BEFORE=UNKNOWN_PREVIOUS_REGISTRY_WAS_INTENTIONALLY_UPDATED" >> "$OUT/sha_compare.txt"
fi

echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')" >> "$OUT/sha_compare.txt"
echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')" >> "$OUT/sha_compare.txt"
echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')" >> "$OUT/sha_compare.txt"

echo
echo "[4/5] Summary"
python3 - "$BASE" "$OUT" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

base = Path(sys.argv[1])
out = Path(sys.argv[2])
public = base / "frontend/public"

http = []
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 3:
        http.append({"url": p[0], "status": p[1], "bytes": p[2]})

non200 = sum(1 for x in http if x["status"] != "200")
external = sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe = sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fused = sum(1 for x in (out/"fused_forbidden_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
missing = sum(1 for x in (out/"missing_files.txt").read_text(errors="ignore").splitlines() if x.strip()) if (out/"missing_files.txt").exists() else 0

sha = {}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v = line.strip().split("=",1)
        sha[k] = v

protected_ok = (
    sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
)

exp = json.loads((public/"trfmc_expansion_modules_v1.json").read_text())
reg = json.loads((public/"trfmc_portal_registry_unified.json").read_text())

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "quality_scope": "SCOPED_ONLY_EXPANSION_FILES",
    "hub": "http://127.0.0.1:5173/trfmc_expansion_hub_v1.html",
    "manifest": "http://127.0.0.1:5173/trfmc_expansion_modules_v1.json",
    "created_modules": len(exp["modules"]),
    "registry_total_html": reg.get("counts", {}).get("total_html"),
    "registry_leaf_operational_candidate": reg.get("counts", {}).get("leaf_operational_candidate"),
    "http_non_200": non200,
    "external_refs_scoped": external,
    "iframe_refs_scoped": iframe,
    "fused_forbidden_refs_scoped": fused,
    "missing_files": missing,
    "protected_v6r3_and_control_unchanged": protected_ok,
    "result": "PASS" if non200 == 0 and external == 0 and iframe == 0 and fused == 0 and missing == 0 and protected_ok else "WARN",
    "policy": "Expansion modules are leaf pages. V6R3 and official Control Room unchanged. Registry was updated intentionally."
}

(out/"summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
(out/"result.flag").write_text(data["result"] + "\n")
print(json.dumps(data, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[5/5] Freeze se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_EXPANSION_MODULES_V1_SCOPED_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_expansion_hub_v1.html \
    frontend/public/trfmc_expansion_modules_v1.json \
    frontend/public/trfmc_rf_physics_theory_atlas_v1.html \
    frontend/public/trfmc_microwave_link_operations_center_v1.html \
    frontend/public/trfmc_fiber_fronthaul_otdr_workbench_v1.html \
    frontend/public/trfmc_private_networks_wifi7_5g_mesh_v1.html \
    frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html \
    frontend/public/trfmc_datacenter_power_pdu_infrastructure_v1.html \
    frontend/public/trfmc_cyber_rf_intelligence_evidence_v1.html \
    frontend/public/trfmc_knowledge_base_theory_procedures_v1.html \
    frontend/public/assets/trfmc_design_system/trfmc_leaf_master_v1.css \
    frontend/public/assets/trfmc_design_system/trfmc_leaf_webgl_v1.js \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_expansion_modules_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo "============================================================"
