from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_NAVIGATION_HARDENING_DEEPLINK_INDEX_V46_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_NAVIGATION_HARDENING_DEEPLINK_INDEX_V46_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_NAVIGATION_HARDENING_DEEPLINK_INDEX_V46_{TS}.tar.gz"

MAIN = ROOT / "frontend/src/app/main.tsx"
V42 = ROOT / "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS = ROOT / "frontend/src/styles.css"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC NAVIGATION HARDENING / DEEPLINK INDEX V46")
print("V42 hash navigation · bookmarkable sections · no main.tsx mutation")
print("=" * 60)

for p in [MAIN, V42, CSS]:
    if not p.exists():
        raise SystemExit(f"ERRORE: file mancante: {p}")

main_before = MAIN.read_text(encoding="utf-8")
v42_before = V42.read_text(encoding="utf-8")
css_before = CSS.read_text(encoding="utf-8")

if "<MissionLayoutOrchestratorV42 />" not in main_before:
    raise SystemExit("ERRORE: main.tsx non monta MissionLayoutOrchestratorV42")

if "VisualAssetRuntimeV41" not in v42_before:
    raise SystemExit("ERRORE: V42 non contiene VisualAssetRuntimeV41")

if "active === 'visual-assets'" not in v42_before:
    raise SystemExit("ERRORE: V42 non contiene branch visual-assets")

(RDIR / f"MissionLayoutOrchestratorV42.tsx.before_v46_{TS}").write_text(v42_before, encoding="utf-8")
(RDIR / f"styles.css.before_v46_{TS}").write_text(css_before, encoding="utf-8")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_NAVIGATION_HARDENING_DEEPLINK_INDEX_V46_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx",
    "frontend/src/styles.css",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

s = v42_before

# 1) Ensure useEffect import if the file uses useState import.
if "from 'react'" in s:
    s = s.replace("import { useState } from 'react'", "import { useEffect, useState } from 'react'")
    s = s.replace("import { useEffect, useEffect, useState } from 'react'", "import { useEffect, useState } from 'react'")
if 'from "react"' in s:
    s = s.replace('import { useState } from "react"', 'import { useEffect, useState } from "react"')
    s = s.replace('import { useEffect, useEffect, useState } from "react"', 'import { useEffect, useState } from "react"')

# If the file uses React.useState style and no import from react, leave it untouched.
# 2) Add robust section helpers.
helper = r"""
const trfmcV46SectionAliases: Record<string, string> = {
  'mission': 'mission-overview',
  'mission-control': 'mission-overview',
  'mission-overview': 'mission-overview',
  'overview': 'mission-overview',
  'visual': 'visual-assets',
  'visual-assets': 'visual-assets',
  'assets': 'visual-assets',
  'scenario': 'scenario-knowledge',
  'scenarios': 'dynamic-scenarios',
  'scenario-knowledge': 'scenario-knowledge',
  'knowledge': 'scenario-knowledge',
  'navigation': 'navigation-architecture',
  'navigation-architecture': 'navigation-architecture',
  'command': 'command-center',
  'command-center': 'command-center',
  'dynamic': 'dynamic-scenarios',
  'dynamic-scenarios': 'dynamic-scenarios',
  'engineering': 'full-engineering-stack',
  'full-engineering': 'full-engineering-stack',
  'full-engineering-stack': 'full-engineering-stack',
}

const trfmcV46NavigationIndex = [
  { id: 'mission-overview', label: 'Mission Overview', hash: '#mission-overview' },
  { id: 'visual-assets', label: 'Visual Assets', hash: '#visual-assets' },
  { id: 'scenario-knowledge', label: 'Scenario Knowledge', hash: '#scenario-knowledge' },
  { id: 'navigation-architecture', label: 'Navigation Architecture', hash: '#navigation-architecture' },
  { id: 'command-center', label: 'Command Center', hash: '#command-center' },
  { id: 'dynamic-scenarios', label: 'Dynamic Scenarios', hash: '#dynamic-scenarios' },
  { id: 'full-engineering-stack', label: 'Full Engineering Stack', hash: '#full-engineering-stack' },
]

const trfmcV46NormalizeHashToSection = () => {
  if (typeof window === 'undefined') return 'mission-overview'
  const raw = window.location.hash.replace(/^#\/?/, '').trim().toLowerCase()
  const first = raw.split('/')[0]
  return trfmcV46SectionAliases[first] ?? 'mission-overview'
}

const trfmcV46WriteHashForSection = (sectionId: string) => {
  if (typeof window === 'undefined') return
  const normalized = trfmcV46SectionAliases[sectionId] ?? sectionId
  const nextHash = `#${normalized}`
  if (window.location.hash !== nextHash) {
    window.history.replaceState(null, '', nextHash)
  }
}
"""

if "trfmcV46NavigationIndex" not in s:
    lines = s.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, helper)
    s = "\n".join(lines) + "\n"

# 3) Initialize active from hash.
# Preserve existing V45 resolver if present but switch to V46 resolver where obvious.
s = s.replace("useState(resolveV42InitialSectionFromHash)", "useState(trfmcV46NormalizeHashToSection)")
s = s.replace("useState('mission-overview')", "useState(trfmcV46NormalizeHashToSection)")
s = s.replace('useState("mission-overview")', 'useState(trfmcV46NormalizeHashToSection)')
s = s.replace("useState('mission-control')", "useState(trfmcV46NormalizeHashToSection)")
s = s.replace('useState("mission-control")', 'useState(trfmcV46NormalizeHashToSection)')

# 4) Add hashchange binding if not already V46.
if "TRFMC_V46_HASHCHANGE_BINDING" not in s:
    marker = "const [active, setActive]"
    pos = s.find(marker)
    if pos == -1:
        raise SystemExit("ERRORE: non trovo const [active, setActive] in V42")
    line_end = s.find("\n", pos)
    injection = r"""
  // TRFMC_V46_HASHCHANGE_BINDING
  useEffect(() => {
    const applyHash = () => {
      setActive(trfmcV46NormalizeHashToSection())
    }

    applyHash()
    window.addEventListener('hashchange', applyHash)
    return () => window.removeEventListener('hashchange', applyHash)
  }, [])
"""
    s = s[:line_end + 1] + injection + s[line_end + 1:]

# 5) Add a bookmarkable navigation index rendered in DOM near header/after opening main shell.
nav_block = r"""
      <nav className="v46-deeplink-index" data-trfmc-v46-deeplink-index="true" aria-label="TRFMC deep link navigation">
        {trfmcV46NavigationIndex.map((entry) => (
          <a
            key={entry.id}
            href={entry.hash}
            className={active === entry.id ? 'v46-deeplink-active' : ''}
            onClick={(event) => {
              event.preventDefault()
              setActive(entry.id)
              trfmcV46WriteHashForSection(entry.id)
            }}
          >
            {entry.label}
          </a>
        ))}
      </nav>
"""

if "data-trfmc-v46-deeplink-index" not in s:
    # Best insertion: after the header marker if present; otherwise before visual content block.
    if "data-trfmc-v45a-visual-assets-active" in s:
        idx = s.find("data-trfmc-v45a-visual-assets-active")
        insert_at = s.rfind("\n", 0, idx)
        s = s[:insert_at] + "\n" + nav_block + s[insert_at:]
    elif "return (" in s:
        pos = s.find("return (")
        next_newline = s.find("\n", pos)
        s = s[:next_newline + 1] + nav_block + s[next_newline + 1:]
    else:
        raise SystemExit("ERRORE: non riesco a inserire nav_block V46")

# 6) Add data-section wrappers for branches when possible, without touching main.tsx.
branch_replacements = {
    "{active === 'visual-assets' ? <div data-trfmc-v45a-visual-assets-active=\"true\"><VisualAssetRuntimeV41 /></div> : null}":
    "{active === 'visual-assets' ? <div data-trfmc-v45a-visual-assets-active=\"true\" data-trfmc-section-active=\"visual-assets\"><VisualAssetRuntimeV41 /></div> : null}",
    "{active === 'visual-assets' ? <VisualAssetRuntimeV41 /> : null}":
    "{active === 'visual-assets' ? <div data-trfmc-section-active=\"visual-assets\"><VisualAssetRuntimeV41 /></div> : null}",
}

for old, new in branch_replacements.items():
    if old in s:
        s = s.replace(old, new)

V42.write_text(s, encoding="utf-8")

# CSS patch.
css = css_before
if "TRFMC V46 NAVIGATION HARDENING DEEPLINK INDEX" not in css:
    css += r"""

/* === TRFMC V46 NAVIGATION HARDENING DEEPLINK INDEX === */
.v46-deeplink-index{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  align-items:center;
  margin: 16px 0 22px;
  padding: 10px;
  border:1px solid rgba(117,234,255,.20);
  border-radius:18px;
  background:
    radial-gradient(circle at 10% 0%, rgba(117,234,255,.12), transparent 32%),
    rgba(2,8,18,.58);
}

.v46-deeplink-index a{
  display:inline-flex;
  align-items:center;
  gap:6px;
  padding:8px 11px;
  border:1px solid rgba(117,234,255,.16);
  border-radius:999px;
  background:rgba(255,255,255,.045);
  color:var(--trfmc-muted, #9ab5c9);
  font-size:11px;
  font-weight:900;
  letter-spacing:.035em;
  text-transform:uppercase;
  text-decoration:none;
}

.v46-deeplink-index a:hover{
  border-color:rgba(117,234,255,.38);
  color:var(--trfmc-text, #f1fbff);
  transform:translateY(-1px);
}

.v46-deeplink-index a.v46-deeplink-active{
  border-color:rgba(117,234,255,.62);
  color:var(--trfmc-cyan, #75eaff);
  background:rgba(117,234,255,.12);
  box-shadow:0 0 24px rgba(117,234,255,.12);
}
"""
CSS.write_text(css, encoding="utf-8")

# Static checks.
v42_now = V42.read_text(encoding="utf-8")
css_now = CSS.read_text(encoding="utf-8")
main_now = MAIN.read_text(encoding="utf-8")

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

ok("main untouched still mounts V42", "<MissionLayoutOrchestratorV42 />" in main_now)
ok("V46 navigation index data marker present", "data-trfmc-v46-deeplink-index" in v42_now)
ok("V46 navigation index array present", "trfmcV46NavigationIndex" in v42_now)
ok("V46 hash normalizer present", "trfmcV46NormalizeHashToSection" in v42_now)
ok("V46 hashchange binding present", "TRFMC_V46_HASHCHANGE_BINDING" in v42_now)
ok("V46 write hash function present", "trfmcV46WriteHashForSection" in v42_now)
ok("visual-assets branch preserved", "VisualAssetRuntimeV41" in v42_now)
ok("visual-assets DOM marker preserved", "data-trfmc-v45a-visual-assets-active" in v42_now)
ok("V46 CSS present", "TRFMC V46 NAVIGATION HARDENING DEEPLINK INDEX" in css_now)
ok("V44 viewer source still present", "VisualZoomViewer" in (ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx").read_text(encoding="utf-8"))

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

build_log = RDIR / "npm_build_v46.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)

build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result != "PASS":
    print(build_log.read_text(errors="ignore")[-10000:])

http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/#mission-overview",
    "http://127.0.0.1:5173/#visual-assets",
    "http://127.0.0.1:5173/#scenario-knowledge",
    "http://127.0.0.1:5173/#navigation-architecture",
    "http://127.0.0.1:5173/#command-center",
    "http://127.0.0.1:5173/#dynamic-scenarios",
    "http://127.0.0.1:5173/#full-engineering-stack",
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

rollback = RDIR / "rollback_v46_navigation_hardening.sh"
rollback.write_text(f"""#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
cp "{RDIR}/MissionLayoutOrchestratorV42.tsx.before_v46_{TS}" frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx
cp "{RDIR}/styles.css.before_v46_{TS}" frontend/src/styles.css
echo "Rollback V46 Navigation Hardening completato"
""", encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result != "PASS" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "navigation_hardening_deeplink_index_manifest_v46.json"
summary = QDIR / "summary.json"

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_NAVIGATION_HARDENING_DEEPLINK_INDEX_V46",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "main_tsx_mutation": False,
    "patched": [str(V42), str(CSS)],
    "deeplinks": [u for u in urls if "#/" not in u and "#" in u],
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
    "frontend/src/styles.css",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_navigation_hardening_deeplink_index_v46"
latest_r = ROOT / "runtime/releases/latest_navigation_hardening_deeplink_index_v46"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
