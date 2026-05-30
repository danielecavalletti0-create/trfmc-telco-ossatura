#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4B_PORTAL_OS_SKELETON_PREVIEW_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

PORTAL_DIR="frontend/src/portal-os"
MAIN="frontend/src/app/main.tsx"

MANIFEST="$PORTAL_DIR/portalManifest.ts"
DATA="$PORTAL_DIR/PortalOSDataFabric.tsx"
ROOT="$PORTAL_DIR/PortalOSRoot.tsx"
FRAME="$PORTAL_DIR/PortalOSFrame.tsx"
HOME="$PORTAL_DIR/PortalOSHome.tsx"
ROUTER="$PORTAL_DIR/PortalOSRouter.tsx"
LAUNCHER="$PORTAL_DIR/PortalOSModuleLauncher.tsx"
VIEWPORT="$PORTAL_DIR/PortalOSModuleViewport.tsx"
EVIDENCE="$PORTAL_DIR/PortalOSEvidencePanel.tsx"
STATUS="$PORTAL_DIR/PortalOSStatusBar.tsx"
MODEL="$PORTAL_DIR/PortalOSCommandCenterModel.ts"
MOUNT="$PORTAL_DIR/PortalOSPreviewMountP4B.tsx"
CSS="$PORTAL_DIR/portal-os.css"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_p4b_portal_os_preview.log"
DOM="$OUT/dom_portal_os_preview.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/portal_os_preview_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4b_portal_os_skeleton_preview.diff"
RESTORE="$OUT/RESTORE_P4B_PORTAL_OS_SKELETON_PREVIEW_V1.sh"

safe_count_files() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn -E "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

safe_count_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then echo 0; return 0; fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_P4B_PORTAL_OS_SKELETON_PREVIEW_V1"
echo "Portal OS preview · no V42 mutation · no home replacement"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$MAIN" ]; then
  echo "ERRORE: main.tsx non trovato: $MAIN"
  exit 1
fi

mkdir -p "$PORTAL_DIR"

for f in "$MAIN" "$MANIFEST" "$DATA" "$ROOT" "$FRAME" "$HOME" "$ROUTER" "$LAUNCHER" "$VIEWPORT" "$EVIDENCE" "$STATUS" "$MODEL" "$MOUNT" "$CSS"; do
  if [ -f "$f" ]; then
    cp -a "$f" "$BACKUP/$(basename "$f").before_$TS"
  fi
done

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

restore_or_remove() {
  local file="\$1"
  local backup="\$2"
  if [ -f "\$backup" ]; then
    cp -a "\$backup" "\$file"
  else
    rm -f "\$file"
  fi
}

restore_or_remove "$MAIN" "$BACKUP/$(basename "$MAIN").before_$TS"
restore_or_remove "$MANIFEST" "$BACKUP/$(basename "$MANIFEST").before_$TS"
restore_or_remove "$DATA" "$BACKUP/$(basename "$DATA").before_$TS"
restore_or_remove "$ROOT" "$BACKUP/$(basename "$ROOT").before_$TS"
restore_or_remove "$FRAME" "$BACKUP/$(basename "$FRAME").before_$TS"
restore_or_remove "$HOME" "$BACKUP/$(basename "$HOME").before_$TS"
restore_or_remove "$ROUTER" "$BACKUP/$(basename "$ROUTER").before_$TS"
restore_or_remove "$LAUNCHER" "$BACKUP/$(basename "$LAUNCHER").before_$TS"
restore_or_remove "$VIEWPORT" "$BACKUP/$(basename "$VIEWPORT").before_$TS"
restore_or_remove "$EVIDENCE" "$BACKUP/$(basename "$EVIDENCE").before_$TS"
restore_or_remove "$STATUS" "$BACKUP/$(basename "$STATUS").before_$TS"
restore_or_remove "$MODEL" "$BACKUP/$(basename "$MODEL").before_$TS"
restore_or_remove "$MOUNT" "$BACKUP/$(basename "$MOUNT").before_$TS"
restore_or_remove "$CSS" "$BACKUP/$(basename "$CSS").before_$TS"

echo "RESTORE_P4B_PORTAL_OS_SKELETON_PREVIEW_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) GENERA portalManifest.ts DA P4A ==="

python3 - "$BASE" "$MANIFEST" <<'PY'
import json
import re
import sys
from pathlib import Path

base = Path(sys.argv[1])
out = Path(sys.argv[2])

latest = base / "runtime" / "quality" / "latest_p4a_safe_v2_total_audit_readonly" / "portal_manifest_draft.json"

modules = []
if latest.exists():
    data = json.loads(latest.read_text(encoding="utf-8"))
    modules = data.get("modules", [])

def norm_id(s):
    return re.sub(r"[^a-z0-9]+", "-", str(s).lower()).strip("-")

def pick_modules(mods):
    picked = []

    def add_virtual(item):
        if item["id"] not in {x["id"] for x in picked}:
            picked.append(item)

    add_virtual({
        "id": "home",
        "title": "Unified Portal OS Home",
        "category": "portal-os",
        "mode": "native-react",
        "source": "frontend/src/portal-os",
        "route": "#portal-os-preview",
        "status": "preview",
        "priority": "P0",
        "shellScore": 10,
        "description": "Home unica con manifest, data fabric, evidence panel e viewport moduli."
    })

    add_virtual({
        "id": "rf-physics",
        "title": "RF Physics Domain",
        "category": "rf-physics",
        "mode": "promoted-react",
        "source": "frontend/src/domains/rf-physics/RFPhysicsDomainP1.tsx",
        "route": "#rf-physics",
        "status": "promoted",
        "priority": "P1",
        "shellScore": 0,
        "description": "Dominio già promosso in React: teoria, formule e base RF."
    })

    add_virtual({
        "id": "signal-analyzer",
        "title": "Signal Analyzer Domain",
        "category": "fft-dsp-signal",
        "mode": "promoted-react",
        "source": "frontend/src/domains/signal-analyzer/SignalAnalyzerDomainP2.tsx",
        "route": "#signal-analyzer",
        "status": "promoted",
        "priority": "P1",
        "shellScore": 0,
        "description": "Dominio già promosso in React: spectrum, waterfall, IQ, FFT, EVM."
    })

    add_virtual({
        "id": "antenna-system",
        "title": "Antenna System Domain",
        "category": "antenna-system",
        "mode": "promoted-react",
        "source": "frontend/src/domains/antenna-system/AntennaSystemDomainP3.tsx",
        "route": "#antenna-system",
        "status": "promoted",
        "priority": "P1",
        "shellScore": 0,
        "description": "Dominio già promosso in React: antenna, RRU, RET, CPRI, AISG."
    })

    sorted_mods = sorted(
        mods,
        key=lambda m: (
            not bool(m.get("isV63Candidate")),
            -int(m.get("shellScore", 0) or 0),
            str(m.get("category", "")),
            str(m.get("source", "")),
        )
    )

    allowed_categories = {
        "command-center-shell",
        "3d-rf-visual-twin",
        "rf-metrology",
        "fft-dsp-signal",
        "signal-intelligence",
        "antenna-system",
        "wifi-qam",
        "5g-core-ran",
        "noc-operations",
        "war-room",
        "knowledge-academy",
        "fiber-optic",
        "microwave-link",
    }

    for m in sorted_mods:
        category = m.get("category", "legacy-generic")
        if category not in allowed_categories:
            continue

        source = m.get("source", "")
        title = m.get("title") or Path(source).stem
        mid = norm_id(source.replace("frontend/public/", "").replace(".html", ""))

        if not mid:
            continue

        priority = "P0" if m.get("isV63Candidate") or int(m.get("shellScore", 0) or 0) >= 6 else "P2"
        status = "reference" if priority == "P0" else "candidate"

        item = {
            "id": mid,
            "title": title,
            "category": category,
            "mode": m.get("mode", "reference-or-promote"),
            "source": source,
            "route": m.get("routeGuess") or m.get("route") or "#" + mid,
            "status": status,
            "priority": priority,
            "shellScore": int(m.get("shellScore", 0) or 0),
            "description": f"{category} · {m.get('mode', 'reference')}",
        }

        add_virtual(item)

        if len(picked) >= 32:
            break

    return picked

picked = pick_modules(modules)

ts = []
ts.append("export type PortalOSModuleStatus = 'preview' | 'promoted' | 'reference' | 'candidate' | 'deprecated'")
ts.append("export type PortalOSModule = {")
ts.append("  id: string")
ts.append("  title: string")
ts.append("  category: string")
ts.append("  mode: string")
ts.append("  source: string")
ts.append("  route: string")
ts.append("  status: PortalOSModuleStatus")
ts.append("  priority: string")
ts.append("  shellScore: number")
ts.append("  description: string")
ts.append("}")
ts.append("")
ts.append("export const portalOSPolicy = {")
ts.append("  singleSpa: true,")
ts.append("  v63VisualModel: true,")
ts.append("  noV42AsFinalRoot: true,")
ts.append("  noIframeAsArchitecture: true,")
ts.append("  previewRoute: '#portal-os-preview',")
ts.append("} as const")
ts.append("")
ts.append("export const portalOSModules: PortalOSModule[] = ")
ts.append(json.dumps(picked, indent=2, ensure_ascii=False))
ts.append("")
ts.append("export const portalOSCategories = Array.from(new Set(portalOSModules.map((module) => module.category)))")
ts.append("export const portalOSPrimaryCommandCenter = portalOSModules.find((module) => module.id.includes('command-center')) ?? portalOSModules[0]")
ts.append("export const portalOSPromotedDomains = portalOSModules.filter((module) => module.status === 'promoted')")
ts.append("")

out.write_text("\n".join(ts), encoding="utf-8")
PY

echo
echo "=== 2) CREA PortalOSCommandCenterModel.ts ==="

cat > "$MODEL" <<'TS'
export const portalOSCommandCenterModel = {
  version: 'P4B_PREVIEW_V1',
  visualReference: 'trfmc_official_safe_entrypoint_v6r3_command_center.html',
  rule: 'A single shell governs modules through a central viewport. Legacy HTML is reference or controlled leaf, not a parallel portal.',
  zones: [
    'top-status-bar',
    'left-module-launcher',
    'central-module-viewport',
    'right-evidence-panel',
    'bottom-runtime-strip',
  ],
  blockedPatterns: [
    'nested-shell',
    'iframe-as-architecture',
    'v42-as-final-root',
    'public-html-as-home',
    'route-isolation-text-patch',
  ],
} as const
TS

echo
echo "=== 3) CREA PortalOSDataFabric.tsx ==="

cat > "$DATA" <<'TSX'
import { useEffect, useMemo, useState } from 'react'
import { portalOSModules } from './portalManifest'

export type PortalOSEndpointStatus = {
  id: string
  label: string
  url: string
  state: 'pending' | 'online' | 'offline'
  detail: string
}

export function usePortalOSDataFabric() {
  const [tick, setTick] = useState(0)
  const [endpoints, setEndpoints] = useState<PortalOSEndpointStatus[]>([
    { id: 'frontend', label: 'Vite Frontend', url: 'http://127.0.0.1:5173/', state: 'pending', detail: 'preview shell' },
    { id: 'backend', label: 'Backend API', url: 'http://127.0.0.1:8000/api/health', state: 'pending', detail: 'health probe' },
    { id: 'bridge', label: 'RF Bridge', url: 'http://127.0.0.1:4181/api/health', state: 'pending', detail: 'bridge probe' },
  ])

  useEffect(() => {
    let alive = true

    const probe = async () => {
      const next = await Promise.all(
        endpoints.map(async (endpoint) => {
          try {
            const res = await fetch(endpoint.url, { cache: 'no-store', mode: 'cors' })
            return {
              ...endpoint,
              state: res.ok ? 'online' : 'offline',
              detail: `${res.status} ${res.statusText}`.trim(),
            } satisfies PortalOSEndpointStatus
          } catch (error) {
            return {
              ...endpoint,
              state: endpoint.id === 'frontend' ? 'online' : 'offline',
              detail: error instanceof Error ? error.message.slice(0, 80) : 'probe failed',
            } satisfies PortalOSEndpointStatus
          }
        })
      )

      if (alive) {
        setEndpoints(next)
        setTick((value) => value + 1)
      }
    }

    probe()
    const timer = window.setInterval(probe, 15000)

    return () => {
      alive = false
      window.clearInterval(timer)
    }
  }, [])

  return useMemo(() => {
    const promoted = portalOSModules.filter((module) => module.status === 'promoted')
    const references = portalOSModules.filter((module) => module.status === 'reference')
    const candidates = portalOSModules.filter((module) => module.status === 'candidate')

    return {
      tick,
      endpoints,
      modules: portalOSModules,
      promoted,
      references,
      candidates,
      onlineCount: endpoints.filter((endpoint) => endpoint.state === 'online').length,
      offlineCount: endpoints.filter((endpoint) => endpoint.state === 'offline').length,
    }
  }, [tick, endpoints])
}
TSX

echo
echo "=== 4) CREA Portal OS COMPONENTS ==="

cat > "$STATUS" <<'TSX'
import type { PortalOSEndpointStatus } from './PortalOSDataFabric'

export function PortalOSStatusBar({
  endpoints,
  activeModuleTitle,
}: {
  endpoints: PortalOSEndpointStatus[]
  activeModuleTitle: string
}) {
  const online = endpoints.filter((endpoint) => endpoint.state === 'online').length

  return (
    <header className="trfmc-pos-statusbar">
      <div>
        <strong>TRFMC Portal OS Preview</strong>
        <span>V63 command-center model · single shell · single viewport</span>
      </div>
      <div className="trfmc-pos-statusbar__right">
        <span>{online}/{endpoints.length} endpoints</span>
        <span>{activeModuleTitle}</span>
      </div>
    </header>
  )
}
TSX

cat > "$LAUNCHER" <<'TSX'
import type { PortalOSModule } from './portalManifest'

export function PortalOSModuleLauncher({
  modules,
  activeModuleId,
  onSelect,
}: {
  modules: PortalOSModule[]
  activeModuleId: string
  onSelect: (id: string) => void
}) {
  return (
    <aside className="trfmc-pos-launcher">
      <div className="trfmc-pos-panel-title">
        <span>Operational Modules</span>
        <strong>{modules.length}</strong>
      </div>
      <div className="trfmc-pos-launcher__list">
        {modules.map((module) => (
          <button
            key={module.id}
            type="button"
            className={module.id === activeModuleId ? 'is-active' : ''}
            onClick={() => onSelect(module.id)}
          >
            <span>{module.priority}</span>
            <strong>{module.title}</strong>
            <em>{module.category}</em>
          </button>
        ))}
      </div>
    </aside>
  )
}
TSX

cat > "$HOME" <<'TSX'
import type { PortalOSModule } from './portalManifest'

export function PortalOSHome({
  modules,
  onSelect,
}: {
  modules: PortalOSModule[]
  onSelect: (id: string) => void
}) {
  const promoted = modules.filter((module) => module.status === 'promoted')
  const references = modules.filter((module) => module.status === 'reference')
  const candidates = modules.filter((module) => module.status === 'candidate')

  return (
    <section className="trfmc-pos-home" data-trfmc-portal-os-home="mounted">
      <div className="trfmc-pos-hero">
        <p>Unified Home · Command Center</p>
        <h1>TRFMC Unified Portal OS</h1>
        <span>
          Preview parallela: una sola shell, un solo manifest, un solo data fabric,
          un solo viewport moduli. V42 resta intatto: questa è la nuova architettura candidata.
        </span>
      </div>

      <div className="trfmc-pos-metrics">
        <article>
          <span>Promoted React</span>
          <strong>{promoted.length}</strong>
          <em>RF Physics · Signal Analyzer · Antenna</em>
        </article>
        <article>
          <span>V63 / Shell refs</span>
          <strong>{references.length}</strong>
          <em>Command Center / Visual model</em>
        </article>
        <article>
          <span>Candidate leaves</span>
          <strong>{candidates.length}</strong>
          <em>legacy sources to promote</em>
        </article>
      </div>

      <div className="trfmc-pos-domain-grid">
        {modules.slice(0, 12).map((module) => (
          <button key={module.id} type="button" onClick={() => onSelect(module.id)}>
            <span>{module.status}</span>
            <strong>{module.title}</strong>
            <em>{module.description}</em>
          </button>
        ))}
      </div>
    </section>
  )
}
TSX

cat > "$VIEWPORT" <<'TSX'
import type { PortalOSModule } from './portalManifest'
import { PortalOSHome } from './PortalOSHome'

export function PortalOSModuleViewport({
  activeModule,
  modules,
  onSelect,
}: {
  activeModule: PortalOSModule
  modules: PortalOSModule[]
  onSelect: (id: string) => void
}) {
  if (activeModule.id === 'home') {
    return <PortalOSHome modules={modules} onSelect={onSelect} />
  }

  return (
    <main className="trfmc-pos-viewport" data-trfmc-portal-os-viewport="mounted">
      <section className="trfmc-pos-module-hero">
        <p>{activeModule.category} · {activeModule.mode}</p>
        <h1>{activeModule.title}</h1>
        <span>{activeModule.description}</span>
      </section>

      <section className="trfmc-pos-module-grid">
        <article>
          <span>Status</span>
          <strong>{activeModule.status}</strong>
          <em>module governance state</em>
        </article>
        <article>
          <span>Source</span>
          <strong>{activeModule.source}</strong>
          <em>reference/promoted origin</em>
        </article>
        <article>
          <span>Route</span>
          <strong>{activeModule.route}</strong>
          <em>future module route</em>
        </article>
        <article>
          <span>Shell score</span>
          <strong>{activeModule.shellScore}</strong>
          <em>legacy shell/reference weight</em>
        </article>
      </section>

      <section className="trfmc-pos-module-contract">
        <span>Viewport rule</span>
        <strong>
          Questo modulo è mostrato come leaf governato dal Portal OS. Nessuna shell duplicata,
          nessun iframe architetturale, nessuna pagina HTML legacy come portale parallelo.
        </strong>
      </section>
    </main>
  )
}
TSX

cat > "$EVIDENCE" <<'TSX'
import type { PortalOSEndpointStatus } from './PortalOSDataFabric'
import type { PortalOSModule } from './portalManifest'

export function PortalOSEvidencePanel({
  endpoints,
  activeModule,
  tick,
}: {
  endpoints: PortalOSEndpointStatus[]
  activeModule: PortalOSModule
  tick: number
}) {
  return (
    <aside className="trfmc-pos-evidence">
      <div className="trfmc-pos-panel-title">
        <span>Command / Evidence</span>
        <strong>P4B</strong>
      </div>

      <section>
        <h3>Active module</h3>
        <p>{activeModule.title}</p>
        <code>{activeModule.source}</code>
      </section>

      <section>
        <h3>Runtime endpoints</h3>
        {endpoints.map((endpoint) => (
          <div key={endpoint.id} className={`trfmc-pos-endpoint is-${endpoint.state}`}>
            <span>{endpoint.label}</span>
            <strong>{endpoint.state}</strong>
            <em>{endpoint.detail}</em>
          </div>
        ))}
      </section>

      <section>
        <h3>Event stream</h3>
        <p>tick #{tick}</p>
        <p>Portal OS preview mounted. Existing portal remains untouched.</p>
      </section>
    </aside>
  )
}
TSX

cat > "$ROUTER" <<'TSX'
import type { PortalOSModule } from './portalManifest'

export function resolvePortalOSModule(modules: PortalOSModule[], activeModuleId: string) {
  return modules.find((module) => module.id === activeModuleId) ?? modules[0]
}
TSX

cat > "$FRAME" <<'TSX'
import { PortalOSEvidencePanel } from './PortalOSEvidencePanel'
import { PortalOSModuleLauncher } from './PortalOSModuleLauncher'
import { PortalOSModuleViewport } from './PortalOSModuleViewport'
import { PortalOSStatusBar } from './PortalOSStatusBar'
import type { PortalOSEndpointStatus } from './PortalOSDataFabric'
import type { PortalOSModule } from './portalManifest'

export function PortalOSFrame({
  modules,
  activeModule,
  endpoints,
  tick,
  onSelect,
}: {
  modules: PortalOSModule[]
  activeModule: PortalOSModule
  endpoints: PortalOSEndpointStatus[]
  tick: number
  onSelect: (id: string) => void
}) {
  return (
    <section className="trfmc-pos-frame">
      <PortalOSStatusBar endpoints={endpoints} activeModuleTitle={activeModule.title} />
      <div className="trfmc-pos-body">
        <PortalOSModuleLauncher modules={modules} activeModuleId={activeModule.id} onSelect={onSelect} />
        <PortalOSModuleViewport activeModule={activeModule} modules={modules} onSelect={onSelect} />
        <PortalOSEvidencePanel endpoints={endpoints} activeModule={activeModule} tick={tick} />
      </div>
    </section>
  )
}
TSX

cat > "$ROOT" <<'TSX'
import { useMemo, useState } from 'react'
import { usePortalOSDataFabric } from './PortalOSDataFabric'
import { PortalOSFrame } from './PortalOSFrame'
import { portalOSModules } from './portalManifest'
import { resolvePortalOSModule } from './PortalOSRouter'

export function PortalOSRoot() {
  const [activeModuleId, setActiveModuleId] = useState('home')
  const dataFabric = usePortalOSDataFabric()

  const activeModule = useMemo(
    () => resolvePortalOSModule(portalOSModules, activeModuleId),
    [activeModuleId]
  )

  return (
    <div className="trfmc-pos-root" data-trfmc-portal-os-preview="mounted">
      <PortalOSFrame
        modules={dataFabric.modules}
        activeModule={activeModule}
        endpoints={dataFabric.endpoints}
        tick={dataFabric.tick}
        onSelect={setActiveModuleId}
      />
    </div>
  )
}
TSX

cat > "$MOUNT" <<'TSX'
import { createRoot, type Root } from 'react-dom/client'
import { PortalOSRoot } from './PortalOSRoot'
import './portal-os.css'

declare global {
  interface Window {
    __trfmcPortalOSPreviewP4BInstalled?: boolean
  }
}

let root: Root | null = null

function ensureHost() {
  let host = document.getElementById('trfmc-portal-os-preview-root')

  if (!host) {
    host = document.createElement('div')
    host.id = 'trfmc-portal-os-preview-root'
    document.body.appendChild(host)
  }

  return host
}

function renderPortalOSPreview() {
  const host = ensureHost()
  const active = window.location.hash === '#portal-os-preview'

  host.style.display = active ? 'block' : 'none'

  if (!active) return

  if (!root) {
    root = createRoot(host)
  }

  root.render(<PortalOSRoot />)
}

export function installPortalOSPreviewP4B() {
  if (typeof window === 'undefined') return
  if (window.__trfmcPortalOSPreviewP4BInstalled) return

  window.__trfmcPortalOSPreviewP4BInstalled = true
  renderPortalOSPreview()
  window.addEventListener('hashchange', renderPortalOSPreview)
}
TSX

echo
echo "=== 5) CREA portal-os.css ==="

cat > "$CSS" <<'CSS'
#trfmc-portal-os-preview-root {
  position: fixed;
  inset: 0;
  z-index: 2147483000;
  background: #020814;
}

.trfmc-pos-root {
  min-height: 100vh;
  background:
    radial-gradient(circle at 20% 0%, rgba(103, 232, 249, .10), transparent 30%),
    radial-gradient(circle at 88% 20%, rgba(134, 239, 172, .08), transparent 28%),
    linear-gradient(135deg, #020814 0%, #04101f 55%, #01040b 100%);
  color: #e8f7ff;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

.trfmc-pos-frame {
  height: 100vh;
  display: grid;
  grid-template-rows: 54px minmax(0, 1fr);
}

.trfmc-pos-statusbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 18px;
  padding: 0 18px;
  border-bottom: 1px solid rgba(103, 232, 249, .18);
  background: rgba(0, 6, 16, .88);
  box-shadow: 0 18px 50px rgba(0, 0, 0, .28);
}

.trfmc-pos-statusbar strong {
  display: block;
  color: #e8f7ff;
  font-size: 13px;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.trfmc-pos-statusbar span {
  color: #9fb8ca;
  font-size: 11px;
}

.trfmc-pos-statusbar__right {
  display: flex;
  gap: 10px;
  align-items: center;
}

.trfmc-pos-statusbar__right span {
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 999px;
  padding: 6px 10px;
  background: rgba(103, 232, 249, .06);
  color: #67e8f9;
}

.trfmc-pos-body {
  min-height: 0;
  display: grid;
  grid-template-columns: 310px minmax(0, 1fr) 340px;
  gap: 10px;
  padding: 10px;
}

.trfmc-pos-launcher,
.trfmc-pos-evidence,
.trfmc-pos-viewport,
.trfmc-pos-home {
  min-height: 0;
  border: 1px solid rgba(103, 232, 249, .16);
  border-radius: 18px;
  background: rgba(2, 12, 24, .70);
  box-shadow: 0 24px 90px rgba(0, 0, 0, .32);
}

.trfmc-pos-launcher,
.trfmc-pos-evidence {
  overflow: hidden;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
}

.trfmc-pos-panel-title {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px;
  border-bottom: 1px solid rgba(103, 232, 249, .14);
}

.trfmc-pos-panel-title span {
  color: #67e8f9;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-pos-panel-title strong {
  color: #86efac;
  font-size: 14px;
}

.trfmc-pos-launcher__list {
  overflow: auto;
  padding: 10px;
  display: grid;
  gap: 8px;
}

.trfmc-pos-launcher button,
.trfmc-pos-domain-grid button {
  text-align: left;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 14px;
  background: rgba(0, 6, 16, .45);
  color: inherit;
  padding: 10px;
  cursor: pointer;
}

.trfmc-pos-launcher button.is-active,
.trfmc-pos-domain-grid button:hover,
.trfmc-pos-launcher button:hover {
  border-color: rgba(134, 239, 172, .42);
  background: rgba(8, 47, 38, .22);
}

.trfmc-pos-launcher button span,
.trfmc-pos-domain-grid button span,
.trfmc-pos-module-grid span,
.trfmc-pos-metrics span {
  display: block;
  color: #67e8f9;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.trfmc-pos-launcher button strong,
.trfmc-pos-domain-grid button strong {
  display: block;
  margin-top: 5px;
  color: #e8f7ff;
  font-size: 12px;
}

.trfmc-pos-launcher button em,
.trfmc-pos-domain-grid button em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 10px;
  font-style: normal;
  line-height: 1.25;
}

.trfmc-pos-viewport,
.trfmc-pos-home {
  overflow: auto;
  padding: 14px;
}

.trfmc-pos-hero,
.trfmc-pos-module-hero {
  border: 1px solid rgba(103, 232, 249, .14);
  border-radius: 18px;
  padding: 18px;
  background:
    radial-gradient(circle at 15% 0%, rgba(103, 232, 249, .12), transparent 35%),
    linear-gradient(180deg, rgba(2, 18, 34, .75), rgba(0, 6, 16, .52));
}

.trfmc-pos-hero p,
.trfmc-pos-module-hero p {
  margin: 0 0 8px;
  color: #67e8f9;
  font-size: 11px;
  font-weight: 900;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-pos-hero h1,
.trfmc-pos-module-hero h1 {
  margin: 0 0 8px;
  color: #e8f7ff;
  font-size: 32px;
  line-height: .98;
}

.trfmc-pos-hero span,
.trfmc-pos-module-hero span {
  color: #9fb8ca;
  font-size: 13px;
  line-height: 1.45;
}

.trfmc-pos-metrics,
.trfmc-pos-module-grid {
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.trfmc-pos-module-grid {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.trfmc-pos-metrics article,
.trfmc-pos-module-grid article,
.trfmc-pos-module-contract {
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 16px;
  padding: 14px;
  background: rgba(0, 6, 16, .34);
}

.trfmc-pos-metrics strong,
.trfmc-pos-module-grid strong {
  display: block;
  margin-top: 8px;
  color: #86efac;
  font-size: 23px;
  line-height: 1;
  word-break: break-word;
}

.trfmc-pos-module-grid strong {
  font-size: 13px;
  color: #e8f7ff;
}

.trfmc-pos-metrics em,
.trfmc-pos-module-grid em {
  display: block;
  margin-top: 8px;
  color: #9fb8ca;
  font-size: 10px;
  font-style: normal;
}

.trfmc-pos-domain-grid {
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.trfmc-pos-module-contract {
  margin-top: 10px;
}

.trfmc-pos-module-contract span {
  display: block;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.trfmc-pos-module-contract strong {
  display: block;
  margin-top: 8px;
  color: #e8f7ff;
  font-size: 13px;
  line-height: 1.45;
}

.trfmc-pos-evidence {
  padding-bottom: 10px;
}

.trfmc-pos-evidence section {
  margin: 10px;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 14px;
  padding: 10px;
  background: rgba(0, 6, 16, .34);
}

.trfmc-pos-evidence h3 {
  margin: 0 0 8px;
  color: #67e8f9;
  font-size: 10px;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.trfmc-pos-evidence p,
.trfmc-pos-evidence code {
  color: #9fb8ca;
  font-size: 11px;
  line-height: 1.35;
  word-break: break-word;
}

.trfmc-pos-endpoint {
  display: grid;
  gap: 3px;
  padding: 8px 0;
  border-top: 1px solid rgba(103, 232, 249, .10);
}

.trfmc-pos-endpoint span {
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-pos-endpoint strong {
  color: #fbbf24;
  font-size: 10px;
  text-transform: uppercase;
}

.trfmc-pos-endpoint.is-online strong {
  color: #86efac;
}

.trfmc-pos-endpoint.is-offline strong {
  color: #f87171;
}

.trfmc-pos-endpoint em {
  color: #9fb8ca;
  font-size: 9px;
  font-style: normal;
}

@media (max-width: 1280px) {
  .trfmc-pos-body {
    grid-template-columns: 250px minmax(0, 1fr);
  }

  .trfmc-pos-evidence {
    display: none;
  }

  .trfmc-pos-domain-grid,
  .trfmc-pos-metrics,
  .trfmc-pos-module-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
CSS

echo
echo "=== 6) PATCH main.tsx SOLO INSTALL PREVIEW, NON V42 ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
before = text

text = re.sub(
    r"\n?/\* TRFMC P4B PORTAL OS PREVIEW INSTALL START \*/.*?/\* TRFMC P4B PORTAL OS PREVIEW INSTALL END \*/\n?",
    "\n",
    text,
    flags=re.S,
)

import_line = "import { installPortalOSPreviewP4B } from '../portal-os/PortalOSPreviewMountP4B'"

if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

install_block = """
/* TRFMC P4B PORTAL OS PREVIEW INSTALL START */
installPortalOSPreviewP4B()
/* TRFMC P4B PORTAL OS PREVIEW INSTALL END */
"""

if "installPortalOSPreviewP4B()" not in text:
    text = text.rstrip() + "\n\n" + install_block + "\n"
else:
    if "TRFMC P4B PORTAL OS PREVIEW INSTALL START" not in text:
        text = text.rstrip() + "\n\n" + install_block + "\n"

path.write_text(text, encoding="utf-8")
print("MAIN_PATCHED=", text != before)
PY

echo
echo "=== 7) DIFF ==="
git diff -- "$MAIN" "$PORTAL_DIR" > "$DIFF" || true
sed -n '1,260p' "$DIFF"

echo
echo "=== 8) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  "$RESTORE"
  BUILD_RESULT="FAIL_RESTORED"
fi

echo
echo "=== 9) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

FRONTEND_HTTP_NON_200="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
FRONTEND_HTTP_ZERO_BYTES="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 10) STATIC SAFETY GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" "$PORTAL_DIR" "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body" "$PORTAL_DIR" "$MAIN")"
  V42_PATCH_COUNT="$(safe_count_files "PortalOSPreview|installPortalOSPreviewP4B|P4B" frontend/src/layout_orchestrator 2>/dev/null || true)"
  PREVIEW_MARKER_SOURCE="$(safe_count_files "data-trfmc-portal-os-preview" "$PORTAL_DIR")"
  INSTALL_COUNT="$(safe_count_files "installPortalOSPreviewP4B" "$MAIN")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "v42_not_touched_by_p4b\t$([ "$V42_PATCH_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_PATCH_COUNT"
  echo -e "preview_marker_source_present\t$([ "$PREVIEW_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$PREVIEW_MARKER_SOURCE"
  echo -e "main_preview_install_present\t$([ "$INSTALL_COUNT" -gt 0 ] && echo PASS || echo FAIL)\t$INSTALL_COUNT"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 11) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  elif command -v chromium >/dev/null 2>&1; then
    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
    echo "NO_CHROME_AVAILABLE" > "$DOMERR"
    echo "NO_CHROME_AVAILABLE" > "$SCREENERR"
  fi
else
  echo "BUILD_NOT_PASS" > "$DOM"
  echo "BUILD_NOT_PASS" > "$DOMERR"
  echo "BUILD_NOT_PASS" > "$SCREENERR"
fi

PREVIEW_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-preview="mounted"' "$DOM")"
HOME_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-home="mounted"' "$DOM")"
VIEWPORT_MARKER_COUNT="$(safe_count_literal 'data-trfmc-portal-os-viewport="mounted"' "$DOM")"
LAUNCHER_COUNT="$(safe_count_literal 'Operational Modules' "$DOM")"
EVIDENCE_COUNT="$(safe_count_literal 'Command / Evidence' "$DOM")"
TITLE_COUNT="$(safe_count_literal 'TRFMC Unified Portal OS' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "PREVIEW_MARKER_COUNT=$PREVIEW_MARKER_COUNT"
echo "HOME_MARKER_COUNT=$HOME_MARKER_COUNT"
echo "VIEWPORT_MARKER_COUNT=$VIEWPORT_MARKER_COUNT"
echo "LAUNCHER_COUNT=$LAUNCHER_COUNT"
echo "EVIDENCE_COUNT=$EVIDENCE_COUNT"
echo "TITLE_COUNT=$TITLE_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$STATIC")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$FRONTEND_HTTP_NON_200" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$FRONTEND_HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$PREVIEW_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_PREVIEW_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$HOME_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_HOME_MARKER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$LAUNCHER_COUNT" = "0" ]; then RESULT="REVIEW_LAUNCHER"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$EVIDENCE_COUNT" = "0" ]; then RESULT="REVIEW_EVIDENCE"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$TITLE_COUNT" = "0" ]; then RESULT="REVIEW_TITLE"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4B_PORTAL_OS_SKELETON_PREVIEW_V1",
  "mutation": "frontend_source_preview_mount_only",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "preview_route": "#portal-os-preview",
  "files_modified": [
    "$MAIN",
    "$PORTAL_DIR"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "dom_stderr": "$DOMERR",
  "screenshot": "$SCREEN",
  "screenshot_stderr": "$SCREENERR",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $FRONTEND_HTTP_NON_200,
  "frontend_http_zero_bytes": $FRONTEND_HTTP_ZERO_BYTES,
  "static_failures": $STATIC_FAILS,
  "dom_result": "$DOM_RESULT",
  "preview_marker_count": $PREVIEW_MARKER_COUNT,
  "home_marker_count": $HOME_MARKER_COUNT,
  "viewport_marker_count": $VIEWPORT_MARKER_COUNT,
  "launcher_count": $LAUNCHER_COUNT,
  "evidence_count": $EVIDENCE_COUNT,
  "title_count": $TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4b_portal_os_skeleton_preview_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4B_PORTAL_OS_SKELETON_PREVIEW_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
