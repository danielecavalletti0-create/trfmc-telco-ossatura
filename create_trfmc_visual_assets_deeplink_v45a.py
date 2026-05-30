from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_VISUAL_ASSETS_DEEPLINK_V45A_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_VISUAL_ASSETS_DEEPLINK_V45A_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_VISUAL_ASSETS_DEEPLINK_V45A_{TS}.tar.gz"

V42 = ROOT / "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
VISUAL = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"
MAIN = ROOT / "frontend/src/app/main.tsx"
STYLES = ROOT / "frontend/src/styles.css"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC VISUAL ASSETS DEEPLINK V45A")
print("hash-driven visual-assets activation · V44 runtime visibility")
print("=" * 60)

for p in [V42, VISUAL, MAIN, STYLES]:
    if not p.exists():
        raise SystemExit(f"ERRORE: file mancante: {p}")

v42_before = V42.read_text(encoding="utf-8")
visual_src = VISUAL.read_text(encoding="utf-8")

if "VisualAssetRuntimeV41" not in v42_before:
    raise SystemExit("ERRORE: V42 non importa/monta VisualAssetRuntimeV41")

if "active === 'visual-assets'" not in v42_before:
    raise SystemExit("ERRORE: V42 non contiene tab visual-assets condizionale")

if "VisualZoomViewer" not in visual_src:
    raise SystemExit("ERRORE: V44 VisualZoomViewer non presente")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_VISUAL_ASSETS_DEEPLINK_V45A_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

(RDIR / f"MissionLayoutOrchestratorV42.tsx.before_v45a_{TS}").write_text(v42_before, encoding="utf-8")

s = v42_before

# Assicura che useEffect sia importato insieme a useState.
if "from 'react'" in s:
    s = s.replace("import { useState } from 'react'", "import { useEffect, useState } from 'react'")
    s = s.replace('import { useState } from "react"', 'import { useEffect, useState } from "react"')

# Se esiste già useEffect import, evita doppioni banali.
s = s.replace("import { useEffect, useEffect, useState } from 'react'", "import { useEffect, useState } from 'react'")
s = s.replace('import { useEffect, useEffect, useState } from "react"', 'import { useEffect, useState } from "react"')

# Inserisci funzione hash -> tab se non presente.
helper = r"""
const resolveV42InitialSectionFromHash = () => {
  if (typeof window === 'undefined') return 'mission-overview'
  const hash = window.location.hash.replace(/^#\/?/, '').trim().toLowerCase()
  if (hash === 'visual-assets' || hash.startsWith('visual-assets/')) return 'visual-assets'
  if (hash === 'scenario-knowledge') return 'scenario-knowledge'
  if (hash === 'navigation-architecture') return 'navigation-architecture'
  if (hash === 'command-center') return 'command-center'
  if (hash === 'dynamic-scenarios') return 'dynamic-scenarios'
  if (hash === 'full-engineering-stack') return 'full-engineering-stack'
  return 'mission-overview'
}
"""

if "resolveV42InitialSectionFromHash" not in s:
    # Inserisce dopo gli import, prima del primo export/function.
    lines = s.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, helper)
    s = "\n".join(lines) + "\n"

# Sostituisci inizializzazione state più probabile.
s = s.replace("useState('mission-overview')", "useState(resolveV42InitialSectionFromHash)")
s = s.replace('useState("mission-overview")', 'useState(resolveV42InitialSectionFromHash)')

# Se lo state ha un nome diverso ma contiene mission-control, proviamo pattern più comune.
s = s.replace("useState('mission-control')", "useState(resolveV42InitialSectionFromHash)")
s = s.replace('useState("mission-control")', 'useState(resolveV42InitialSectionFromHash)')

# Aggiungi listener hashchange dopo la dichiarazione dello state active/setActive.
if "TRFMC_V45A_HASHCHANGE_BINDING" not in s:
    marker = "const [active, setActive]"
    pos = s.find(marker)
    if pos != -1:
        line_end = s.find("\n", pos)
        injection = r"""
  // TRFMC_V45A_HASHCHANGE_BINDING
  useEffect(() => {
    const applyHash = () => {
      const next = resolveV42InitialSectionFromHash()
      setActive(next)
    }

    applyHash()
    window.addEventListener('hashchange', applyHash)
    return () => window.removeEventListener('hashchange', applyHash)
  }, [])
"""
        s = s[:line_end + 1] + injection + s[line_end + 1:]
    else:
        raise SystemExit("ERRORE: non trovo const [active, setActive] in V42")

# Aggiungi marker data-section vicino al mount visual-assets.
if "data-trfmc-v45a-visual-assets-active" not in s:
    s = s.replace(
        "{active === 'visual-assets' ? <VisualAssetRuntimeV41 /> : null}",
        "{active === 'visual-assets' ? <div data-trfmc-v45a-visual-assets-active=\"true\"><VisualAssetRuntimeV41 /></div> : null}",
    )

V42.write_text(s, encoding="utf-8")

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

v42_now = V42.read_text(encoding="utf-8")
ok("V42 imports useEffect", "useEffect" in v42_now)
ok("V42 has hash resolver", "resolveV42InitialSectionFromHash" in v42_now)
ok("V42 handles visual-assets hash", "visual-assets" in v42_now and "startsWith('visual-assets/')" in v42_now)
ok("V42 has hashchange binding", "TRFMC_V45A_HASHCHANGE_BINDING" in v42_now)
ok("V42 has visual assets active DOM marker", "data-trfmc-v45a-visual-assets-active" in v42_now)
ok("V44 viewer source preserved", "VisualZoomViewer" in visual_src)
ok("V44 title source preserved", "TRFMC V44 Visual Asset Zoom/Autofit" in visual_src)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

build_log = RDIR / "npm_build_v45a.log"
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

rollback = RDIR / "rollback_v45a_visual_assets_deeplink.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/MissionLayoutOrchestratorV42.tsx.before_v45a_{TS}" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx
echo "Rollback V45A visual-assets deeplink completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result != "PASS" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "visual_assets_deeplink_manifest_v45a.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSETS_DEEPLINK_V45A",
    "strategy": "hash_deeplink_auto_activates_visual_assets_tab_for_v44_runtime_dom_visibility",
    "frontend_mutation": True,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "patched": [str(V42)],
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
    "operation": "TRFMC_VISUAL_ASSETS_DEEPLINK_V45A",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "active_deeplink": "http://127.0.0.1:5173/#visual-assets",
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
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_visual_assets_deeplink_v45a"
latest_r = ROOT / "runtime/releases/latest_visual_assets_deeplink_v45a"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
