from pathlib import Path
import json
import shutil
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_PROMOTE_STAGED_RENDERS_V43C_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_PROMOTE_STAGED_RENDERS_V43C_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_PROMOTE_STAGED_RENDERS_V43C_{TS}.tar.gz"

STAGING_ROOT = ROOT / "runtime/staging/visual_renders_v43"
PUBLIC_ROOT = ROOT / "frontend/public/trfmc_assets/visual_knowledge"

ACTIVE_REGISTRY = PUBLIC_ROOT / "visual_asset_registry_active.json"
REGISTRY_V43 = PUBLIC_ROOT / "visual_asset_registry_v43.json"
REGISTRY_V43C = PUBLIC_ROOT / "visual_asset_registry_v43c.json"

MAIN = ROOT / "frontend/src/app/main.tsx"
VISUAL_COMPONENT = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC PROMOTE STAGED RENDERS V43C")
print("staging -> public assets · active registry update · build/http gate")
print("=" * 60)

for rel in [
    "runtime/quality/latest_copy_candidate_set_to_staging_v43b2/summary.json",
    "runtime/quality/latest_real_render_visual_qa_v43r1r1/summary.json",
    "runtime/quality/latest_mission_layout_orchestrator_v42/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

b2 = json.loads((ROOT / "runtime/quality/latest_copy_candidate_set_to_staging_v43b2/summary.json").read_text())
if b2.get("ready_for_promotion_count") != 7 or b2.get("ambiguous_count") != 0 or b2.get("missing_count") != 0:
    raise SystemExit("ERRORE: staging V43B2 non pronto per promozione completa")

if not ACTIVE_REGISTRY.exists():
    raise SystemExit("ERRORE: active registry mancante")

if not MAIN.exists() or "RFOperationalDeckV42MissionLayoutOrchestrator" not in MAIN.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: main.tsx non monta V42")

if not VISUAL_COMPONENT.exists() or "visual_asset_registry_active.json" not in VISUAL_COMPONENT.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: VisualAssetRuntimeV41 non usa registry active")

print("OK: V43B2/V43R1R1/V42 PASS, staging pronto, active registry configurato")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_PROMOTE_STAGED_RENDERS_V43C_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/public/trfmc_assets/visual_knowledge",
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

asset_map = [
    {
        "asset_id": "electronics_symbols_basic_concepts",
        "category": "01_electronics_symbols",
        "staging_folder": STAGING_ROOT / "01_electronics_symbols/electronics_symbols_basic_concepts",
        "public_folder": PUBLIC_ROOT / "01_electronics_symbols",
    },
    {
        "asset_id": "microstrip_patch_antenna_5g",
        "category": "02_antennas_microstrip",
        "staging_folder": STAGING_ROOT / "02_antennas_microstrip/microstrip_patch_antenna_5g",
        "public_folder": PUBLIC_ROOT / "02_antennas_microstrip",
    },
    {
        "asset_id": "types_of_telecom_antennas",
        "category": "03_antennas_types",
        "staging_folder": STAGING_ROOT / "03_antennas_types/types_of_telecom_antennas",
        "public_folder": PUBLIC_ROOT / "03_antennas_types",
    },
    {
        "asset_id": "beamwidth_narrow_wide",
        "category": "03_antennas_types",
        "staging_folder": STAGING_ROOT / "03_antennas_types/beamwidth_narrow_wide",
        "public_folder": PUBLIC_ROOT / "03_antennas_types",
    },
    {
        "asset_id": "telecom_towers_arabic_overview",
        "category": "04_telco_infrastructure",
        "staging_folder": STAGING_ROOT / "04_telco_infrastructure/telecom_towers_arabic_overview",
        "public_folder": PUBLIC_ROOT / "04_telco_infrastructure",
    },
    {
        "asset_id": "cellular_satellite_site_photo",
        "category": "04_telco_infrastructure",
        "staging_folder": STAGING_ROOT / "04_telco_infrastructure/cellular_satellite_site_photo",
        "public_folder": PUBLIC_ROOT / "04_telco_infrastructure",
    },
    {
        "asset_id": "falco_xplorer_vs_bayraktar_tb2",
        "category": "06_uav_rf_links",
        "staging_folder": STAGING_ROOT / "06_uav_rf_links/falco_xplorer_vs_bayraktar_tb2",
        "public_folder": PUBLIC_ROOT / "06_uav_rf_links",
    },
]

accepted_ext = {".png", ".jpg", ".jpeg", ".webp"}
promoted = []

for item in asset_map:
    staging_folder = item["staging_folder"]
    if not staging_folder.exists():
        raise SystemExit(f"ERRORE: staging folder mancante: {staging_folder}")

    candidates = [p for p in staging_folder.iterdir() if p.is_file() and p.suffix.lower() in accepted_ext]
    if len(candidates) != 1:
        raise SystemExit(f"ERRORE: atteso esattamente 1 file per {item['asset_id']}, trovati {len(candidates)}")

    src = candidates[0]
    item["public_folder"].mkdir(parents=True, exist_ok=True)

    # Manteniamo l'estensione reale. Il registry punterà al file promosso.
    dst = item["public_folder"] / src.name
    shutil.copy2(src, dst)

    public_path = "/" + str(dst.relative_to(ROOT / "frontend/public"))

    promoted.append({
        "asset_id": item["asset_id"],
        "category": item["category"],
        "source_staging_path": str(src),
        "target_public_path": str(dst),
        "public_path": public_path,
        "size_bytes": dst.stat().st_size,
        "ext": dst.suffix.lower(),
    })

registry = json.loads(ACTIVE_REGISTRY.read_text(encoding="utf-8"))
registry["timestamp"] = TS
registry["operation"] = "TRFMC_PROMOTE_STAGED_RENDERS_V43C"
registry["active_registry"] = "/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"
registry["promotion_policy"] = "promote_exactly_one_valid_staged_render_per_asset_preserve_fallbacks"
registry["promoted_count_v43c"] = len(promoted)

promoted_by_id = {p["asset_id"]: p for p in promoted}

for asset in registry.get("assets", []):
    aid = asset.get("id")
    if aid in promoted_by_id:
        p = promoted_by_id[aid]
        old_fallback = asset.get("fallback_path", "")
        asset["real_render_path"] = p["public_path"]
        asset["public_path"] = p["public_path"]
        asset["source_mode"] = "real-render"
        asset["fallback_path"] = old_fallback
        asset["real_render_imported_at"] = TS
        asset["real_render_source"] = p["source_staging_path"]
        asset["replaceable"] = True
        asset["import_note"] = "Promoted by V43C from validated staging folder."
    elif aid == "rf_microwave_engineering_lab":
        # Già reale da V43R1, ma semanticamente da rivedere: roadmap/tabella.
        asset["source_mode"] = "real-render-review"
        asset["import_note"] = "Existing V43R1 real render is technically valid but should be semantically reviewed/replaced with a true RF lab render."
    else:
        asset.setdefault("real_render_path", "")
        asset["source_mode"] = asset.get("source_mode", "fallback") or "fallback"

REGISTRY_V43C.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")
REGISTRY_V43.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")
ACTIVE_REGISTRY.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")

promoted_json = RDIR / "promoted_renders_v43c.json"
promoted_tsv = RDIR / "promoted_renders_v43c.tsv"

promoted_json.write_text(json.dumps(promoted, indent=2, ensure_ascii=False), encoding="utf-8")

with promoted_tsv.open("w", encoding="utf-8") as f:
    f.write("asset_id\text\tsize_bytes\tpublic_path\ttarget_public_path\tsource_staging_path\n")
    for p in promoted:
        f.write(f"{p['asset_id']}\t{p['ext']}\t{p['size_bytes']}\t{p['public_path']}\t{p['target_public_path']}\t{p['source_staging_path']}\n")

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

ok("seven renders promoted", len(promoted) == 7)
ok("registry V43C exists", REGISTRY_V43C.exists() and REGISTRY_V43C.stat().st_size > 0)
ok("active registry exists", ACTIVE_REGISTRY.exists() and ACTIVE_REGISTRY.stat().st_size > 0)
ok("registry V43 exists", REGISTRY_V43.exists() and REGISTRY_V43.stat().st_size > 0)

registry_now = json.loads(ACTIVE_REGISTRY.read_text(encoding="utf-8"))
assets = registry_now.get("assets", [])
real_count = sum(1 for a in assets if a.get("source_mode") == "real-render")
review_count = sum(1 for a in assets if a.get("source_mode") == "real-render-review")
fallback_count = sum(1 for a in assets if a.get("source_mode") == "fallback")

ok("registry has seven promoted real-render assets", real_count == 7)
ok("registry keeps one review asset", review_count == 1)
ok("registry has zero fallback assets after V43C", fallback_count == 0)

for p in promoted:
    target = Path(p["target_public_path"])
    ok(f"public render exists for {p['asset_id']}", target.exists() and target.stat().st_size > 0)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build gate.
build_log = RDIR / "npm_build_v43c.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)
build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result == "FAIL":
    print(build_log.read_text(errors="ignore")[-6000:])

# HTTP gate.
http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v43c.json",
    "http://127.0.0.1:4181/api/mission/status",
]

for p in promoted:
    urls.append("http://127.0.0.1:5173" + p["public_path"])

lines = ["url\tstatus\tbytes"]
for url in urls:
    pr = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}\t%{size_download}", "--connect-timeout", "2", "--max-time", "8", url],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if pr.returncode != 0:
        code, size = "000", "0"
    else:
        parts = pr.stdout.strip().split()
        code = parts[0] if len(parts) > 0 else "000"
        size = parts[1] if len(parts) > 1 else "0"
    lines.append(f"{url}\t{code}\t{size}")

http_tsv.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(http_tsv.read_text())

http_non_200 = sum(1 for line in lines[1:] if line.split("\t")[1] != "200")
http_zero_bytes = sum(1 for line in lines[1:] if line.split("\t")[2] == "0")

rollback = RDIR / "rollback_v43c_promote_staged_renders.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
tar -xzf "{pre_freeze}" -C /
echo "Rollback V43C completato usando pre-freeze: {pre_freeze}"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "promote_staged_renders_manifest_v43c.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_PROMOTE_STAGED_RENDERS_V43C",
    "strategy": "promote_staged_render_assets_to_public_and_update_active_registry",
    "frontend_mutation": False,
    "static_public_asset_mutation": True,
    "runtime_staging_mutation": False,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "promoted_tsv": str(promoted_tsv),
    "promoted_json": str(promoted_json),
    "registry_active": str(ACTIVE_REGISTRY),
    "registry_v43c": str(REGISTRY_V43C),
    "promoted_count": len(promoted),
    "real_render_count": real_count,
    "real_render_review_count": review_count,
    "fallback_count": fallback_count,
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_PROMOTE_STAGED_RENDERS_V43C",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "promoted_tsv": str(promoted_tsv),
    "promoted_json": str(promoted_json),
    "registry_active": str(ACTIVE_REGISTRY),
    "registry_v43c": str(REGISTRY_V43C),
    "promoted_count": len(promoted),
    "real_render_count": real_count,
    "real_render_review_count": review_count,
    "fallback_count": fallback_count,
    "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/public/trfmc_assets/visual_knowledge",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_promote_staged_renders_v43c"
latest_r = ROOT / "runtime/releases/latest_promote_staged_renders_v43c"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
