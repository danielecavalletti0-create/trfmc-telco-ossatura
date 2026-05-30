from pathlib import Path
import json
import re
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_VISUAL_ASSET_BINDING_AUDIT_V41A_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_VISUAL_ASSET_BINDING_AUDIT_V41A_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_VISUAL_ASSET_BINDING_AUDIT_V41A_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
PUBLIC = ROOT / "frontend/public"
ASSET_ROOT = PUBLIC / "trfmc_assets/visual_knowledge"
REGISTRY = ASSET_ROOT / "visual_asset_registry_v35.json"

V36_ENGINE = ROOT / "frontend/src/rf_scenarios/RFDynamicScenarioDeckV36.tsx"
V40_DATA = ROOT / "frontend/src/knowledge_binding/scenarioKnowledgeBindingDataV40.ts"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC VISUAL ASSET BINDING AUDIT V41A")
print("read-only · asset registry · scenario/binding path verification")
print("=" * 60)

# Preconditions
required_summaries = [
    "runtime/quality/latest_scenario_knowledge_binding_v40/summary.json",
    "runtime/quality/latest_navigation_map_v39r1/summary.json",
    "runtime/quality/latest_unified_design_system_v38/summary.json",
]

for rel in required_summaries:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not MAIN.exists():
    raise SystemExit("ERRORE: main.tsx mancante")

main_txt = MAIN.read_text(encoding="utf-8")
if "RFOperationalDeckV40ScenarioKnowledgeFusion" not in main_txt:
    raise SystemExit("ERRORE: main.tsx non monta V40")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:4181/api/mission/status"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0 or "TRFMC_READONLY_BACKEND_BRIDGE_V28" not in probe.stdout:
    raise SystemExit("ERRORE: API 4181 non operative")

print("OK: V40 PASS, active mount V40, API 4181 live")

image_ext = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif"}
model_ext = {".glb", ".gltf", ".obj"}
registry_data = None

if REGISTRY.exists():
    try:
        registry_data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except Exception as exc:
        registry_data = {"error": str(exc)}

asset_files = []
if ASSET_ROOT.exists():
    for p in sorted(ASSET_ROOT.rglob("*")):
        if p.is_file() and p.suffix.lower() in image_ext | model_ext | {".json"}:
            asset_files.append({
                "path": str(p.relative_to(ROOT)),
                "public_path": "/" + str(p.relative_to(PUBLIC)),
                "size_bytes": p.stat().st_size,
                "ext": p.suffix.lower(),
            })

def extract_public_paths(path: Path):
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8", errors="ignore")
    # public paths usually written as /trfmc_assets/...
    found = sorted(set(re.findall(r"['\"](/trfmc_assets/[^'\"]+)['\"]", text)))
    return found

v36_paths = extract_public_paths(V36_ENGINE)
v40_paths = extract_public_paths(V40_DATA)

def public_path_to_file(public_path: str) -> Path:
    # /trfmc_assets/... maps to frontend/public/trfmc_assets/...
    return PUBLIC / public_path.lstrip("/")

binding_checks = []
for source_name, paths in [("V36_ENGINE", v36_paths), ("V40_BINDING_DATA", v40_paths)]:
    for item in paths:
        fs_path = public_path_to_file(item)
        binding_checks.append({
            "source": source_name,
            "public_path": item,
            "filesystem_path": str(fs_path.relative_to(ROOT)),
            "exists": fs_path.exists(),
            "size_bytes": fs_path.stat().st_size if fs_path.exists() and fs_path.is_file() else 0,
            "kind": "registry" if item.endswith(".json") else "asset",
        })

expected_assets = [
    "/trfmc_assets/visual_knowledge/01_electronics_symbols/electronics_symbols_basic_concepts.jpg",
    "/trfmc_assets/visual_knowledge/02_antennas_microstrip/microstrip_patch_antenna_5g.jpg",
    "/trfmc_assets/visual_knowledge/03_antennas_types/types_of_telecom_antennas.jpg",
    "/trfmc_assets/visual_knowledge/03_antennas_types/beamwidth_narrow_wide.jpg",
    "/trfmc_assets/visual_knowledge/04_telco_infrastructure/cellular_satellite_site_photo.jpg",
    "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.jpg",
    "/trfmc_assets/visual_knowledge/06_uav_rf_links/falco_xplorer_vs_bayraktar_tb2.jpg",
    "/trfmc_assets/visual_knowledge/visual_asset_registry_v35.json",
]

expected_checks = []
for item in expected_assets:
    fs_path = public_path_to_file(item)
    expected_checks.append({
        "public_path": item,
        "filesystem_path": str(fs_path.relative_to(ROOT)),
        "exists": fs_path.exists(),
        "size_bytes": fs_path.stat().st_size if fs_path.exists() and fs_path.is_file() else 0,
    })

existing_expected = sum(1 for x in expected_checks if x["exists"])
missing_expected = len(expected_checks) - existing_expected
missing_binding_paths = sum(1 for x in binding_checks if not x["exists"])

image_count = sum(1 for a in asset_files if a["ext"] in image_ext)
model_count = sum(1 for a in asset_files if a["ext"] in model_ext)
json_count = sum(1 for a in asset_files if a["ext"] == ".json")

asset_status = "ready" if missing_expected == 0 else "partial" if existing_expected > 0 else "missing"

# TSV outputs
asset_inventory_tsv = RDIR / "visual_asset_inventory_v41a.tsv"
with asset_inventory_tsv.open("w", encoding="utf-8") as f:
    f.write("public_path\text\tsize_bytes\n")
    for a in asset_files:
        f.write(f"{a['public_path']}\t{a['ext']}\t{a['size_bytes']}\n")

binding_tsv = RDIR / "visual_asset_binding_checks_v41a.tsv"
with binding_tsv.open("w", encoding="utf-8") as f:
    f.write("source\tpublic_path\texists\tsize_bytes\tfilesystem_path\n")
    for b in binding_checks:
        f.write(f"{b['source']}\t{b['public_path']}\t{b['exists']}\t{b['size_bytes']}\t{b['filesystem_path']}\n")

expected_tsv = RDIR / "visual_asset_expected_matrix_v41a.tsv"
with expected_tsv.open("w", encoding="utf-8") as f:
    f.write("public_path\texists\tsize_bytes\tfilesystem_path\n")
    for e in expected_checks:
        f.write(f"{e['public_path']}\t{e['exists']}\t{e['size_bytes']}\t{e['filesystem_path']}\n")

(RDIR / "visual_asset_registry_v35_snapshot.json").write_text(
    json.dumps(registry_data, indent=2, ensure_ascii=False) if registry_data is not None else "{}",
    encoding="utf-8"
)

audit_json = RDIR / "visual_asset_binding_audit_v41a.json"
audit_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_BINDING_AUDIT_V41A",
    "frontend_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "asset_root": str(ASSET_ROOT),
    "asset_root_exists": ASSET_ROOT.exists(),
    "registry": str(REGISTRY),
    "registry_exists": REGISTRY.exists(),
    "asset_status": asset_status,
    "asset_files_count": len(asset_files),
    "image_count": image_count,
    "model_count": model_count,
    "json_count": json_count,
    "expected_count": len(expected_checks),
    "expected_existing": existing_expected,
    "expected_missing": missing_expected,
    "v36_referenced_paths": v36_paths,
    "v40_referenced_paths": v40_paths,
    "binding_checks": binding_checks,
    "missing_binding_paths": missing_binding_paths,
    "expected_checks": expected_checks,
}
audit_json.write_text(json.dumps(audit_data, indent=2, ensure_ascii=False), encoding="utf-8")

plan = RDIR / "visual_asset_binding_plan_v41a.md"
with plan.open("w", encoding="utf-8") as f:
    f.write("# TRFMC V41A Visual Asset Binding Audit\n\n")
    f.write("## Obiettivo\n\n")
    f.write("Verificare se gli asset visuali/render-ready esistono realmente e se i riferimenti V36/V40 puntano a file servibili da Vite.\n\n")
    f.write("## Stato asset\n\n")
    f.write(f"- Asset root exists: `{ASSET_ROOT.exists()}`\n")
    f.write(f"- Registry exists: `{REGISTRY.exists()}`\n")
    f.write(f"- Asset status: `{asset_status}`\n")
    f.write(f"- Asset files: `{len(asset_files)}`\n")
    f.write(f"- Images: `{image_count}`\n")
    f.write(f"- 3D models: `{model_count}`\n")
    f.write(f"- Expected existing/missing: `{existing_expected}/{missing_expected}`\n")
    f.write(f"- Missing binding paths: `{missing_binding_paths}`\n\n")

    f.write("## Interpretazione\n\n")
    if asset_status == "ready":
        f.write("Gli asset attesi risultano presenti. La fase V41R1 può creare il binding runtime visuale.\n\n")
    elif asset_status == "partial":
        f.write("Sono presenti alcuni asset, ma non tutti. V41R1 può procedere in modalità tolerant/fallback, oppure conviene completare l’import asset prima.\n\n")
    else:
        f.write("Gli asset attesi non sono presenti. Prima di V41R1 conviene creare/importare `frontend/public/trfmc_assets/visual_knowledge` oppure usare fallback procedurali.\n\n")

    f.write("## Strategia V41R1 consigliata\n\n")
    f.write("1. Creare un layer `VisualAssetRuntimeV41` che legge asset esistenti e mostra fallback se mancanti.\n")
    f.write("2. Non hardcodare immagini non presenti.\n")
    f.write("3. Collegare asset a V40 binding con source mode: live/contract/synthetic/future-live.\n")
    f.write("4. Preservare V40 sotto il nuovo wrapper.\n")
    f.write("5. Build gate + HTTP gate; Chrome escluso.\n")

result = "PASS"

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_BINDING_AUDIT_V41A",
    "release_dir": str(RDIR),
    "freeze": str(FREEZE),
    "asset_root": str(ASSET_ROOT),
    "asset_root_exists": ASSET_ROOT.exists(),
    "registry_exists": REGISTRY.exists(),
    "asset_status": asset_status,
    "asset_files_count": len(asset_files),
    "image_count": image_count,
    "model_count": model_count,
    "json_count": json_count,
    "expected_count": len(expected_checks),
    "expected_existing": existing_expected,
    "expected_missing": missing_expected,
    "missing_binding_paths": missing_binding_paths,
    "asset_inventory": str(asset_inventory_tsv),
    "binding_checks": str(binding_tsv),
    "expected_matrix": str(expected_tsv),
    "audit_json": str(audit_json),
    "plan": str(plan),
    "result": result,
}

summary = QDIR / "summary.json"
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_visual_asset_binding_audit_v41a"
latest_r = ROOT / "runtime/releases/latest_visual_asset_binding_audit_v41a"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))
