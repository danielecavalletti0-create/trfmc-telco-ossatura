from pathlib import Path
import json
import subprocess
import time
import re

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_RESTORE_V42_ACTIVE_MOUNT_V45B_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_RESTORE_V42_ACTIVE_MOUNT_V45B_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_RESTORE_V42_ACTIVE_MOUNT_V45B_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
V42 = ROOT / "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
VISUAL = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC RESTORE V42 ACTIVE MOUNT V45B")
print("safe root mount switch · no inner JSX injection · build/http gate")
print("=" * 60)

for p in [MAIN, V42, VISUAL]:
    if not p.exists():
        raise SystemExit(f"ERRORE: file mancante: {p}")

main_before = MAIN.read_text(encoding="utf-8")
v42_src = V42.read_text(encoding="utf-8")
visual_src = VISUAL.read_text(encoding="utf-8")

if "export function MissionLayoutOrchestratorV42" not in v42_src:
    raise SystemExit("ERRORE: MissionLayoutOrchestratorV42 non esportato")

if "VisualAssetRuntimeV41" not in v42_src:
    raise SystemExit("ERRORE: V42 non monta VisualAssetRuntimeV41")

if "VisualZoomViewer" not in visual_src:
    raise SystemExit("ERRORE: V44 VisualZoomViewer non presente")

(RDIR / f"main.tsx.before_v45b_{TS}").write_text(main_before, encoding="utf-8")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_RESTORE_V42_ACTIVE_MOUNT_V45B_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/app/main.tsx",
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

s = main_before

import_line = "import { MissionLayoutOrchestratorV42 } from '../layout_orchestrator/MissionLayoutOrchestratorV42'"
if "MissionLayoutOrchestratorV42" not in s:
    lines = s.splitlines()
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import_idx = i
    if last_import_idx < 0:
        raise SystemExit("ERRORE: nessun import trovato in main.tsx")
    lines.insert(last_import_idx + 1, import_line)
    s = "\n".join(lines) + "\n"

# Sostituzione chirurgica del solo mount root attivo.
candidates = [
    "<RFOperationalDeckV16ChunkObservatory />",
    "<RFOperationalDeckV37CommandCenterFusion />",
    "<RFOperationalDeckV39NavigationFusion />",
    "<RFOperationalDeckV40ScenarioKnowledgeFusion />",
    "<RFOperationalDeckV41VisualAssetFusion />",
    "<RFOperationalDeckV42MissionLayoutOrchestrator />",
    "<RFOperationalDeckV44VisualAssetZoomAutofit />",
]

changed = False
for old in candidates:
    if old in s:
        s = s.replace(old, "<MissionLayoutOrchestratorV42 />", 1)
        changed = True
        break

if not changed:
    pattern = re.compile(r"<RFOperationalDeckV[0-9A-Za-z_]+ />")
    m = pattern.search(s)
    if m:
        s = s[:m.start()] + "<MissionLayoutOrchestratorV42 />" + s[m.end():]
        changed = True

if not changed:
    raise SystemExit("ERRORE: non trovo un mount root RFOperationalDeckV... self-closing da sostituire")

MAIN.write_text(s, encoding="utf-8")

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

main_now = MAIN.read_text(encoding="utf-8")
ok("main imports MissionLayoutOrchestratorV42", "import { MissionLayoutOrchestratorV42 }" in main_now)
ok("main mounts MissionLayoutOrchestratorV42", "<MissionLayoutOrchestratorV42 />" in main_now)
ok("main no longer mounts V16 as active root", "<RFOperationalDeckV16ChunkObservatory />" not in main_now)
ok("V42 exports component", "export function MissionLayoutOrchestratorV42" in v42_src)
ok("V42 mounts VisualAssetRuntimeV41", "VisualAssetRuntimeV41" in v42_src)
ok("V44 viewer preserved", "VisualZoomViewer" in visual_src)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

build_log = RDIR / "npm_build_v45b.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)

build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result != "PASS":
    print(build_log.read_text(errors="ignore")[-8000:])

http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/#visual-assets",
    "http://127.0.0.1:4181/api/health",
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

rollback = RDIR / "rollback_v45b_restore_v42_active_mount.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/main.tsx.before_v45b_{TS}" frontend/src/app/main.tsx
echo "Rollback V45B main.tsx completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result != "PASS" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "restore_v42_active_mount_manifest_v45b.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_RESTORE_V42_ACTIVE_MOUNT_V45B",
    "strategy": "replace_only_root_mount_in_main_tsx_with_MissionLayoutOrchestratorV42",
    "frontend_mutation": True,
    "main_tsx_mutation": True,
    "inner_jsx_injection": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_RESTORE_V42_ACTIVE_MOUNT_V45B",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_mount": "MissionLayoutOrchestratorV42",
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/src/app/main.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_restore_v42_active_mount_v45b"
latest_r = ROOT / "runtime/releases/latest_restore_v42_active_mount_v45b"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
