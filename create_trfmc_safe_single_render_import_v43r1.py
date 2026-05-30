from pathlib import Path
import json
import shutil
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_SAFE_SINGLE_RENDER_IMPORT_V43R1_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_SAFE_SINGLE_RENDER_IMPORT_V43R1_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_SAFE_SINGLE_RENDER_IMPORT_V43R1_{TS}.tar.gz"

PUBLIC = ROOT / "frontend/public"
ASSET_ROOT = PUBLIC / "trfmc_assets/visual_knowledge"
REGISTRY_V41 = ASSET_ROOT / "visual_asset_registry_v41_fallback.json"
REGISTRY_V43 = ASSET_ROOT / "visual_asset_registry_v43.json"
REGISTRY_ACTIVE = ASSET_ROOT / "visual_asset_registry_active.json"

SOURCE_RENDER = Path("/home/sentinel/Scaricati/Roadmap_Economica_Laboratorio_TLC_RF_v2.png")
TARGET_RENDER = ASSET_ROOT / "05_rf_lab_visuals/rf_microwave_engineering_lab.png"

MAIN = ROOT / "frontend/src/app/main.tsx"
STYLES = ROOT / "frontend/src/styles.css"
VISUAL_COMPONENT = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC SAFE SINGLE RENDER IMPORT V43R1")
print("one validated render · registry promotion · fallback preserved")
print("=" * 60)

for rel in [
    "runtime/quality/latest_real_render_import_audit_v43a/summary.json",
    "runtime/quality/latest_runtime_visual_qa_v42r1/summary.json",
    "runtime/quality/latest_mission_layout_orchestrator_v42/summary.json",
    "runtime/quality/latest_visual_asset_runtime_binding_v41r1/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not REGISTRY_V41.exists():
    raise SystemExit("ERRORE: registry V41 fallback mancante")

if not SOURCE_RENDER.exists():
    raise SystemExit(f"ERRORE: render sorgente non trovato: {SOURCE_RENDER}")

if not MAIN.exists() or "RFOperationalDeckV42MissionLayoutOrchestrator" not in MAIN.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: main.tsx non monta V42")

if not VISUAL_COMPONENT.exists():
    raise SystemExit("ERRORE: VisualAssetRuntimeV41.tsx mancante")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0 or "TRFMC_VISUAL_ASSET_SCAFFOLD_V41B" not in probe.stdout:
    raise SystemExit("ERRORE: registry V41 non servito da Vite")

print("OK: V43A/V42/V41 PASS, registry V41 servito, render sorgente presente")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_SAFE_SINGLE_RENDER_IMPORT_V43R1_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/public/trfmc_assets/visual_knowledge",
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Copy real render.
TARGET_RENDER.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(SOURCE_RENDER, TARGET_RENDER)

# Promote registry.
registry = json.loads(REGISTRY_V41.read_text(encoding="utf-8"))
registry_v43 = dict(registry)
registry_v43["timestamp"] = TS
registry_v43["operation"] = "TRFMC_SAFE_SINGLE_RENDER_IMPORT_V43R1"
registry_v43["source_registry"] = "/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json"
registry_v43["active_registry"] = "/trfmc_assets/visual_knowledge/visual_asset_registry_v43.json"
registry_v43["real_render_import_policy"] = "safe_single_validated_candidate_only"
registry_v43["real_render_imported_count"] = 1

for asset in registry_v43.get("assets", []):
    if asset.get("id") == "rf_microwave_engineering_lab":
        asset["real_render_path"] = "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png"
        asset["public_path"] = asset["real_render_path"]
        asset["source_mode"] = "real-render"
        asset["fallback_path"] = "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg"
        asset["real_render_source"] = str(SOURCE_RENDER)
        asset["real_render_imported_at"] = TS
        asset["replaceable"] = True
        asset["import_note"] = "Imported by V43R1 after V43A candidate audit."
    else:
        asset.setdefault("real_render_path", "")
        asset["source_mode"] = asset.get("source_mode", "fallback") or "fallback"
        asset["import_note"] = "No trusted real render imported yet; fallback preserved."

REGISTRY_V43.write_text(json.dumps(registry_v43, indent=2, ensure_ascii=False), encoding="utf-8")
REGISTRY_ACTIVE.write_text(json.dumps(registry_v43, indent=2, ensure_ascii=False), encoding="utf-8")

# Patch component to prefer active/V43 registry and real_render_path.
component_before = VISUAL_COMPONENT.read_text(encoding="utf-8")
(RDIR / f"VisualAssetRuntimeV41.tsx.before_v43r1_{TS}").write_text(component_before, encoding="utf-8")

component_after = component_before

component_after = component_after.replace(
    "const registryUrl = '/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json'",
    "const registryUrl = '/trfmc_assets/visual_knowledge/visual_asset_registry_active.json'",
)

# Extend type if not already present.
component_after = component_after.replace(
    "fallback_path: string\n  source_mode: string",
    "fallback_path: string\n  real_render_path?: string\n  source_mode: string",
)

# Prefer real render.
component_after = component_after.replace(
    '<img src={selected.fallback_path || selected.public_path} alt={selected.title} />',
    '<img src={selected.real_render_path || selected.public_path || selected.fallback_path} alt={selected.title} />',
)

# Show active registry URL text automatically because registryUrl variable is used in loading message.
VISUAL_COMPONENT.write_text(component_after, encoding="utf-8")

# Checks.
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

component_now = VISUAL_COMPONENT.read_text(encoding="utf-8")
registry_v43_now = json.loads(REGISTRY_V43.read_text(encoding="utf-8"))
rf_asset = next((a for a in registry_v43_now.get("assets", []) if a.get("id") == "rf_microwave_engineering_lab"), {})

ok("target real render exists", TARGET_RENDER.exists() and TARGET_RENDER.stat().st_size > 0)
ok("registry V43 exists", REGISTRY_V43.exists() and REGISTRY_V43.stat().st_size > 0)
ok("active registry exists", REGISTRY_ACTIVE.exists() and REGISTRY_ACTIVE.stat().st_size > 0)
ok("rf lab asset source_mode real-render", rf_asset.get("source_mode") == "real-render")
ok("rf lab real_render_path set", rf_asset.get("real_render_path") == "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png")
ok("rf lab fallback preserved", rf_asset.get("fallback_path", "").endswith("rf_microwave_engineering_lab.svg"))
ok("component uses active registry", "visual_asset_registry_active.json" in component_now)
ok("component prefers real_render_path", "selected.real_render_path" in component_now)
ok("V42 still active", "RFOperationalDeckV42MissionLayoutOrchestrator" in MAIN.read_text(encoding="utf-8"))

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())
miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build gate.
build_log = RDIR / "npm_build_v43r1.log"
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
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v43.json",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg",
    "http://127.0.0.1:4181/api/mission/status",
]
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

rollback = RDIR / "rollback_v43r1_safe_single_render_import.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/VisualAssetRuntimeV41.tsx.before_v43r1_{TS}" frontend/src/visual_assets/VisualAssetRuntimeV41.tsx
rm -f frontend/public/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png
rm -f frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_v43.json
rm -f frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json
echo "Rollback V43R1 Safe Single Render Import completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "safe_single_render_import_manifest_v43r1.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_SAFE_SINGLE_RENDER_IMPORT_V43R1",
    "strategy": "single_validated_real_render_import_with_fallback_preservation",
    "frontend_mutation": True,
    "static_public_asset_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "source_render": str(SOURCE_RENDER),
    "target_render": str(TARGET_RENDER),
    "registry_v43": str(REGISTRY_V43),
    "registry_active": str(REGISTRY_ACTIVE),
    "patched": [str(VISUAL_COMPONENT)],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "real_render_imported_count": 1,
    "fallback_preserved": True,
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_SAFE_SINGLE_RENDER_IMPORT_V43R1",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "source_render": str(SOURCE_RENDER),
    "target_render": str(TARGET_RENDER),
    "registry_active": str(REGISTRY_ACTIVE),
    "real_render_imported_count": 1,
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
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_safe_single_render_import_v43r1"
latest_r = ROOT / "runtime/releases/latest_safe_single_render_import_v43r1"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
