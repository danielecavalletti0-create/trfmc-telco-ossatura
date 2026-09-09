from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_DEEPLINK_SECTION_AUTOOPEN_V45_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_DEEPLINK_SECTION_AUTOOPEN_V45_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_DEEPLINK_SECTION_AUTOOPEN_V45_{TS}.tar.gz"

ORCH = ROOT / "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
VISUAL = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"
STYLES = ROOT / "frontend/src/styles.css"
MAIN = ROOT / "frontend/src/app/main.tsx"
ACTIVE_REGISTRY = ROOT / "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC DEEPLINK SECTION AUTOOPEN V45")
print("hash routing · visual-assets auto-open · asset preselect · QA ready")
print("=" * 60)

for rel in [
    "runtime/quality/latest_visual_asset_zoom_autofit_v44/summary.json",
    "runtime/quality/latest_mission_layout_orchestrator_v42/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

for p, name in [(ORCH, "MissionLayoutOrchestratorV42"), (VISUAL, "VisualAssetRuntimeV41"), (STYLES, "styles.css"), (MAIN, "main.tsx")]:
    if not p.exists():
        raise SystemExit(f"ERRORE: {name} mancante: {p}")

if "RFOperationalDeckV42MissionLayoutOrchestrator" not in MAIN.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: main.tsx non monta V42")

if "VisualZoomViewer" not in VISUAL.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: V44 viewer non presente in VisualAssetRuntimeV41")

if not ACTIVE_REGISTRY.exists():
    raise SystemExit("ERRORE: active registry mancante")

print("OK: V44/V42 PASS, componenti presenti")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_DEEPLINK_SECTION_AUTOOPEN_V45_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
    "frontend/src/styles.css",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

orch_before = ORCH.read_text(encoding="utf-8")
visual_before = VISUAL.read_text(encoding="utf-8")
styles_before = STYLES.read_text(encoding="utf-8")

(RDIR / f"MissionLayoutOrchestratorV42.tsx.before_v45_{TS}").write_text(orch_before, encoding="utf-8")
(RDIR / f"VisualAssetRuntimeV41.tsx.before_v45_{TS}").write_text(visual_before, encoding="utf-8")
(RDIR / f"styles.css.before_v45_{TS}").write_text(styles_before, encoding="utf-8")

# Patch MissionLayoutOrchestratorV42: hash-to-section + URL update on button click.
orch = orch_before

if "function sectionFromHashV45" not in orch:
    insert_after = "const sections: SectionV42[] = ["
    helper = r"""
function sectionFromHashV45(hashValue = window.location.hash): SectionIdV42 {
  const clean = hashValue.replace(/^#\/?/, '').trim()
  const first = clean.split('/')[0]

  if (first === 'visual-assets') return 'visual-assets'
  if (first === 'scenario-knowledge' || first === 'knowledge') return 'knowledge'
  if (first === 'navigation' || first === 'navigation-architecture') return 'navigation'
  if (first === 'command' || first === 'command-center') return 'command'
  if (first === 'scenarios' || first === 'dynamic-scenarios') return 'scenarios'
  if (first === 'full-engineering' || first === 'engineering') return 'full-engineering'
  if (first === 'mission' || first === 'mission-control') return 'mission'

  return 'mission'
}

function hashForSectionV45(sectionId: SectionIdV42) {
  if (sectionId === 'knowledge') return '#scenario-knowledge'
  if (sectionId === 'navigation') return '#navigation'
  if (sectionId === 'command') return '#command-center'
  if (sectionId === 'scenarios') return '#dynamic-scenarios'
  if (sectionId === 'full-engineering') return '#full-engineering'
  if (sectionId === 'visual-assets') return '#visual-assets'
  return '#mission'
}

"""
    orch = orch.replace(insert_after, helper + insert_after, 1)

orch = orch.replace(
    "const [active, setActive] = useState<SectionIdV42>('mission')",
    "const [active, setActive] = useState<SectionIdV42>(() => sectionFromHashV45())",
)

if "window.addEventListener('hashchange', onHashChangeV45)" not in orch:
    marker = """  const activeSection = useMemo(() => {
    return sections.find((section) => section.id === active) ?? sections[0]
  }, [active])
"""
    hook = r"""
  useEffect(() => {
    const onHashChangeV45 = () => {
      setActive(sectionFromHashV45())
    }

    window.addEventListener('hashchange', onHashChangeV45)
    onHashChangeV45()

    return () => window.removeEventListener('hashchange', onHashChangeV45)
  }, [])

"""
    orch = orch.replace(marker, hook + marker, 1)

orch = orch.replace(
    "onClick={() => setActive(section.id)}",
    "onClick={() => {\n                setActive(section.id)\n                window.location.hash = hashForSectionV45(section.id)\n              }}",
)

# Need useEffect imported in ORCH if missing.
orch = orch.replace(
    "import { useMemo, useState } from 'react'",
    "import { useEffect, useMemo, useState } from 'react'",
)

ORCH.write_text(orch, encoding="utf-8")

# Patch VisualAssetRuntimeV41: optional asset preselection from hash path after visual-assets/<asset_id>.
visual = visual_before

if "function assetIdFromHashV45" not in visual:
    helper = r"""
function assetIdFromHashV45(hashValue = window.location.hash) {
  const clean = hashValue.replace(/^#\/?/, '').trim()
  const parts = clean.split('/').filter(Boolean)

  if (parts[0] === 'visual-assets' && parts[1]) {
    return parts[1]
  }

  return ''
}

"""
    visual = visual.replace("const registryUrl = '/trfmc_assets/visual_knowledge/visual_asset_registry_active.json'\n", "const registryUrl = '/trfmc_assets/visual_knowledge/visual_asset_registry_active.json'\n\n" + helper, 1)

visual = visual.replace(
    "setSelectedId(data.assets?.[0]?.id ?? '')",
    "setSelectedId(assetIdFromHashV45() || data.assets?.[0]?.id ?? '')",
)

if "window.addEventListener('hashchange', onHashChangeV45)" not in visual:
    marker = """  const assets = registry?.assets ?? []
"""
    hook = r"""
  useEffect(() => {
    const onHashChangeV45 = () => {
      const hashAsset = assetIdFromHashV45()
      if (hashAsset) setSelectedId(hashAsset)
    }

    window.addEventListener('hashchange', onHashChangeV45)
    onHashChangeV45()

    return () => window.removeEventListener('hashchange', onHashChangeV45)
  }, [])

"""
    visual = visual.replace(marker, hook + marker, 1)

# Fix precedence safely if patch created risky expression
visual = visual.replace(
    "setSelectedId(assetIdFromHashV45() || data.assets?.[0]?.id ?? '')",
    "setSelectedId(assetIdFromHashV45() || data.assets?.[0]?.id || '')",
)

VISUAL.write_text(visual, encoding="utf-8")

# Add CSS target highlight.
styles = STYLES.read_text(encoding="utf-8")
if "TRFMC V45 DEEPLINK SECTION AUTOOPEN" not in styles:
    STYLES.write_text(styles + r"""

/* === TRFMC V45 DEEPLINK SECTION AUTOOPEN === */
.v42-section-rail button.v42-section-active{
  position:relative;
}

.v42-section-rail button.v42-section-active::after{
  content:"HASH ACTIVE";
  position:absolute;
  top:8px;
  right:8px;
  padding:2px 6px;
  border-radius:999px;
  color:#8dffbd;
  background:rgba(141,255,189,.11);
  border:1px solid rgba(141,255,189,.24);
  font-size:8px;
  font-weight:900;
  letter-spacing:.08em;
}
""", encoding="utf-8")

# Checks.
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

orch_now = ORCH.read_text(encoding="utf-8")
visual_now = VISUAL.read_text(encoding="utf-8")
styles_now = STYLES.read_text(encoding="utf-8")

ok("ORCH has sectionFromHashV45", "sectionFromHashV45" in orch_now)
ok("ORCH listens hashchange", "hashchange" in orch_now)
ok("ORCH initializes active from hash", "useState<SectionIdV42>(() => sectionFromHashV45())" in orch_now)
ok("ORCH updates URL hash on click", "window.location.hash = hashForSectionV45(section.id)" in orch_now)
ok("VISUAL has assetIdFromHashV45", "assetIdFromHashV45" in visual_now)
ok("VISUAL preselects hash asset", "assetIdFromHashV45() || data.assets?.[0]?.id || ''" in visual_now)
ok("VISUAL listens hashchange", "hashchange" in visual_now)
ok("V45 CSS present", "TRFMC V45 DEEPLINK SECTION AUTOOPEN" in styles_now)
ok("V42 still active", "RFOperationalDeckV42MissionLayoutOrchestrator" in MAIN.read_text(encoding="utf-8"))
ok("V44 viewer preserved", "VisualZoomViewer" in visual_now)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

build_log = RDIR / "npm_build_v45.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)
build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result == "FAIL":
    print(build_log.read_text(errors="ignore")[-8000:])

http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/#visual-assets",
    "http://127.0.0.1:5173/#visual-assets/rf_microwave_engineering_lab",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json",
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

rollback = RDIR / "rollback_v45_deeplink_section_autoopen.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/MissionLayoutOrchestratorV42.tsx.before_v45_{TS}" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx
cp "{RDIR}/VisualAssetRuntimeV41.tsx.before_v45_{TS}" frontend/src/visual_assets/VisualAssetRuntimeV41.tsx
cp "{RDIR}/styles.css.before_v45_{TS}" frontend/src/styles.css
echo "Rollback V45 Deep Link / Section Auto-Open completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "deeplink_section_autoopen_manifest_v45.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_DEEPLINK_SECTION_AUTOOPEN_V45",
    "strategy": "hash_based_section_autoopen_and_visual_asset_preselection",
    "frontend_mutation": True,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "patched": [str(ORCH), str(VISUAL), str(STYLES)],
    "deep_links": [
        "http://127.0.0.1:5173/#visual-assets",
        "http://127.0.0.1:5173/#visual-assets/rf_microwave_engineering_lab",
    ],
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_DEEPLINK_SECTION_AUTOOPEN_V45",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
    "deep_link_visual_assets": "http://127.0.0.1:5173/#visual-assets",
    "deep_link_rf_lab": "http://127.0.0.1:5173/#visual-assets/rf_microwave_engineering_lab",
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
    "frontend/src/styles.css",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_deeplink_section_autoopen_v45"
latest_r = ROOT / "runtime/releases/latest_deeplink_section_autoopen_v45"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
