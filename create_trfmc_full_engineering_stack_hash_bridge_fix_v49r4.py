from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")
OP = "TRFMC_FULL_ENGINEERING_STACK_HASH_BRIDGE_FIX_V49R4"

QDIR = ROOT / f"runtime/quality/{OP}_{TS}"
RDIR = ROOT / f"runtime/releases/{OP}_{TS}"
FREEZE = ROOT / f"runtime/freezes/{OP}_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
V42 = ROOT / "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
ENRICH = ROOT / "frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print(OP)
print("fix full-engineering-stack hash bridge into V49 section marker · no main.tsx mutation")
print("=" * 60)

for p in [MAIN, V42, ENRICH]:
    if not p.exists():
        raise SystemExit(f"ERRORE: file mancante: {p}")

main_src = MAIN.read_text(encoding="utf-8")
v42_before = V42.read_text(encoding="utf-8")
enrich_src = ENRICH.read_text(encoding="utf-8")

if "<MissionLayoutOrchestratorV42 />" not in main_src:
    raise SystemExit("ERRORE: main.tsx non monta MissionLayoutOrchestratorV42")

if "EngineeringContentEnrichmentV49" not in v42_before:
    raise SystemExit("ERRORE: V42 non monta EngineeringContentEnrichmentV49")

if "V49_SECTION_FULL_ENGINEERING_STACK" not in enrich_src:
    raise SystemExit("ERRORE: V49 full stack marker non presente")

(RDIR / f"MissionLayoutOrchestratorV42.tsx.before_v49r4_{TS}").write_text(v42_before, encoding="utf-8")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_FULL_ENGINEERING_STACK_HASH_BRIDGE_FIX_V49R4_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

s = v42_before

bridge = r"""
const trfmcV49ResolveEnrichmentSectionFromHash = (activeSection: string) => {
  if (typeof window !== 'undefined') {
    const raw = window.location.hash.replace(/^#\/?/, '').trim().toLowerCase()
    const first = raw.split('/')[0]

    if (first === 'full-engineering-stack' || first === 'full-engineering' || first === 'engineering-stack') {
      return 'full-engineering-stack'
    }

    if (first === 'mission-overview' || first === 'mission' || first === 'mission-control' || first === 'overview') {
      return 'mission-overview'
    }

    if (first === 'visual-assets' || first === 'visual' || first === 'assets') {
      return 'visual-assets'
    }

    if (first === 'scenario-knowledge' || first === 'scenario' || first === 'knowledge') {
      return 'scenario-knowledge'
    }

    if (first === 'navigation-architecture' || first === 'navigation' || first === 'architecture') {
      return 'navigation-architecture'
    }

    if (first === 'command-center' || first === 'command') {
      return 'command-center'
    }

    if (first === 'dynamic-scenarios' || first === 'dynamic' || first === 'scenarios') {
      return 'dynamic-scenarios'
    }
  }

  if (activeSection === 'full-engineering' || activeSection === 'full-engineering-stack') return 'full-engineering-stack'
  return activeSection || 'mission-overview'
}
"""

if "trfmcV49ResolveEnrichmentSectionFromHash" not in s:
    lines = s.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, bridge)
    s = "\n".join(lines) + "\n"

# Replace V49 mount prop only. Do not touch main.tsx or branch rendering.
s = s.replace(
    "<EngineeringContentEnrichmentV49 activeSection={active} />",
    "<EngineeringContentEnrichmentV49 activeSection={trfmcV49ResolveEnrichmentSectionFromHash(active)} />"
)

# Safety: ensure V46 aliases recognize both IDs if helper is present.
s = s.replace("'full-engineering': 'full-engineering-stack',", "'full-engineering': 'full-engineering-stack',\n  'engineering-stack': 'full-engineering-stack',")
s = s.replace('"full-engineering": "full-engineering-stack",', '"full-engineering": "full-engineering-stack",\n  "engineering-stack": "full-engineering-stack",')

V42.write_text(s, encoding="utf-8")

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

v42_now = V42.read_text(encoding="utf-8")
main_now = MAIN.read_text(encoding="utf-8")

ok("main.tsx still mounts V42", "<MissionLayoutOrchestratorV42 />" in main_now)
ok("V49 hash bridge resolver present", "trfmcV49ResolveEnrichmentSectionFromHash" in v42_now)
ok("V49 mount uses hash bridge resolver", "activeSection={trfmcV49ResolveEnrichmentSectionFromHash(active)}" in v42_now)
ok("full-engineering-stack handled in bridge", "first === 'full-engineering-stack'" in v42_now)
ok("full-engineering legacy handled in bridge", "first === 'full-engineering'" in v42_now)
ok("V46 deeplink index preserved", "data-trfmc-v46-deeplink-index" in v42_now)
ok("V49 component still mounted", "EngineeringContentEnrichmentV49" in v42_now)
ok("V49 full stack marker source preserved", "V49_SECTION_FULL_ENGINEERING_STACK" in enrich_src)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

print("\n=== BUILD GATE ===")

build_log = RDIR / "npm_build_v49r4.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)

build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result != "PASS":
    print(build_log.read_text(errors="ignore")[-12000:])

print("\n=== HTTP GATE ===")

http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/#full-engineering-stack",
    "http://127.0.0.1:5173/#full-engineering",
    "http://127.0.0.1:5173/#command-center",
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

rollback = RDIR / "rollback_v49r4_full_engineering_stack_hash_bridge.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/MissionLayoutOrchestratorV42.tsx.before_v49r4_{TS}" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx
echo "Rollback V49R4 completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result != "PASS" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "full_engineering_stack_hash_bridge_manifest_v49r4.json"
summary = QDIR / "summary.json"

summary_data = {
    "timestamp": TS,
    "operation": OP,
    "frontend_mutation": True,
    "main_tsx_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "patched": [str(V42)],
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}

manifest.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_full_engineering_stack_hash_bridge_fix_v49r4"
latest_r = ROOT / "runtime/releases/latest_full_engineering_stack_hash_bridge_fix_v49r4"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print("\n=== SUMMARY ===")
print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
