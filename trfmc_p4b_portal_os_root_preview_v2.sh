#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4B_PORTAL_OS_ROOT_PREVIEW_V2_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

MAIN="frontend/src/app/main.tsx"
PORTAL_DIR="frontend/src/portal-os"
MANIFEST="$PORTAL_DIR/portalManifest.ts"
ROOT="$PORTAL_DIR/PortalOSRoot.tsx"
CSS="$PORTAL_DIR/portal-os.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_p4b_portal_os_root_preview_v2.log"
HTTP="$OUT/http.tsv"
STATIC="$OUT/static_gate.tsv"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/portal_os_root_preview_v2_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4b_portal_os_root_preview_v2.diff"
RESTORE="$OUT/RESTORE_P4B_PORTAL_OS_ROOT_PREVIEW_V2.sh"

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
echo "TRFMC_P4B_PORTAL_OS_ROOT_PREVIEW_V2"
echo "Existing React root · conditional render inside App · no overlay"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$MAIN" ]; then
  echo "ERRORE: main.tsx non trovato"
  exit 1
fi

mkdir -p "$PORTAL_DIR"

for f in "$MAIN" "$MANIFEST" "$ROOT" "$CSS"; do
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
restore_or_remove "$ROOT" "$BACKUP/$(basename "$ROOT").before_$TS"
restore_or_remove "$CSS" "$BACKUP/$(basename "$CSS").before_$TS"

echo "RESTORE_P4B_PORTAL_OS_ROOT_PREVIEW_V2 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA portalManifest.ts ==="

cat > "$MANIFEST" <<'TS'
export type PortalOSModuleStatus = 'preview' | 'promoted' | 'reference' | 'candidate'

export type PortalOSModule = {
  id: string
  title: string
  category: string
  route: string
  status: PortalOSModuleStatus
  source: string
  description: string
}

export const portalOSModules: PortalOSModule[] = [
  {
    id: 'home',
    title: 'Unified Portal OS Home',
    category: 'portal-os',
    route: '#portal-os-preview',
    status: 'preview',
    source: 'frontend/src/portal-os',
    description: 'Home unica: shell, launcher, viewport, evidence panel e data fabric.'
  },
  {
    id: 'v63-command-center',
    title: 'V63 Command Center Reference',
    category: 'command-center-shell',
    route: '#command-center',
    status: 'reference',
    source: 'frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html',
    description: 'Riferimento visuale e operativo per la nuova architettura.'
  },
  {
    id: 'rf-physics',
    title: 'RF Physics',
    category: 'rf-physics',
    route: '#rf-physics',
    status: 'promoted',
    source: 'frontend/src/domains/rf-physics/RFPhysicsDomainP1.tsx',
    description: 'Dominio React promosso: teoria, formule e base RF.'
  },
  {
    id: 'signal-analyzer',
    title: 'Signal Analyzer',
    category: 'fft-dsp-signal',
    route: '#signal-analyzer',
    status: 'promoted',
    source: 'frontend/src/domains/signal-analyzer/SignalAnalyzerDomainP2.tsx',
    description: 'Dominio React promosso: spectrum, waterfall, IQ, FFT, EVM.'
  },
  {
    id: 'antenna-system',
    title: 'Antenna System',
    category: 'antenna-system',
    route: '#antenna-system',
    status: 'promoted',
    source: 'frontend/src/domains/antenna-system/AntennaSystemDomainP3.tsx',
    description: 'Dominio React promosso: antenna, RRU, RET, CPRI, AISG.'
  },
  {
    id: 'core-ran',
    title: '5G Core/RAN Identity',
    category: '5g-core-ran',
    route: '#core-ran',
    status: 'candidate',
    source: 'frontend/public / backend APIs',
    description: 'Open5GS, UERANSIM, SUPI/SUCI, AKA, NGAP, PFCP, GTP-U.'
  },
  {
    id: 'war-room',
    title: 'RF/TM War Room',
    category: 'war-room',
    route: '#war-room',
    status: 'candidate',
    source: 'frontend/public war-room references',
    description: 'Scenario, evidence, RF/cyber correlation and operational console.'
  },
  {
    id: 'knowledge-base',
    title: 'Knowledge Base',
    category: 'knowledge-academy',
    route: '#knowledge-base',
    status: 'candidate',
    source: 'frontend/public knowledge references',
    description: 'Formule, teoria, procedure, glossary and teaching content.'
  }
]

export const promotedPortalOSModules = portalOSModules.filter((module) => module.status === 'promoted')
export const candidatePortalOSModules = portalOSModules.filter((module) => module.status === 'candidate')
export const referencePortalOSModules = portalOSModules.filter((module) => module.status === 'reference')
TS

echo
echo "=== 2) CREA PortalOSRoot.tsx ==="

cat > "$ROOT" <<'TSX'
import React from 'react'
import {
  candidatePortalOSModules,
  portalOSModules,
  promotedPortalOSModules,
  referencePortalOSModules,
  type PortalOSModule,
} from './portalManifest'
import './portal-os.css'

type EndpointState = {
  id: string
  label: string
  url: string
  state: 'pending' | 'online' | 'offline'
  detail: string
}

const initialEndpoints: EndpointState[] = [
  { id: 'frontend', label: 'Vite frontend', url: '/', state: 'pending', detail: 'SPA shell' },
  { id: 'backend', label: 'Backend 8000', url: 'http://127.0.0.1:8000/api/health', state: 'pending', detail: 'health API' },
  { id: 'bridge', label: 'Bridge 4181', url: 'http://127.0.0.1:4181/api/health', state: 'pending', detail: 'RF bridge' },
]

function statusLabel(value: string) {
  return value.toUpperCase()
}

export function PortalOSRoot() {
  const [activeModuleId, setActiveModuleId] = React.useState('home')
  const [endpoints, setEndpoints] = React.useState<EndpointState[]>(initialEndpoints)
  const [tick, setTick] = React.useState(0)

  React.useEffect(() => {
    let alive = true

    async function probe() {
      const next = await Promise.all(
        initialEndpoints.map(async (endpoint) => {
          try {
            const response = await fetch(endpoint.url, { cache: 'no-store' })
            return {
              ...endpoint,
              state: response.ok ? 'online' : 'offline',
              detail: `${response.status} ${response.statusText}`.trim(),
            } satisfies EndpointState
          } catch (error) {
            return {
              ...endpoint,
              state: endpoint.id === 'frontend' ? 'online' : 'offline',
              detail: error instanceof Error ? error.message.slice(0, 90) : 'probe failed',
            } satisfies EndpointState
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

  const activeModule = React.useMemo<PortalOSModule>(() => {
    return portalOSModules.find((module) => module.id === activeModuleId) ?? portalOSModules[0]
  }, [activeModuleId])

  const onlineCount = endpoints.filter((endpoint) => endpoint.state === 'online').length

  return (
    <section className="trfmc-pos-root-v2" data-trfmc-portal-os-preview="mounted">
      <header className="trfmc-pos-v2-status">
        <div>
          <strong>TRFMC Unified Portal OS</strong>
          <span>Preview V2 · existing React root · no overlay · no second createRoot</span>
        </div>
        <div>
          <span>{onlineCount}/{endpoints.length} endpoints online</span>
          <span>{activeModule.title}</span>
        </div>
      </header>

      <div className="trfmc-pos-v2-layout">
        <aside className="trfmc-pos-v2-launcher">
          <div className="trfmc-pos-v2-panel-title">
            <span>Operational Modules</span>
            <strong>{portalOSModules.length}</strong>
          </div>
          <div className="trfmc-pos-v2-module-list">
            {portalOSModules.map((module) => (
              <button
                key={module.id}
                type="button"
                className={activeModule.id === module.id ? 'is-active' : ''}
                onClick={() => setActiveModuleId(module.id)}
              >
                <span>{statusLabel(module.status)}</span>
                <strong>{module.title}</strong>
                <em>{module.category}</em>
              </button>
            ))}
          </div>
        </aside>

        <main className="trfmc-pos-v2-viewport" data-trfmc-portal-os-viewport="mounted">
          {activeModule.id === 'home' ? (
            <section className="trfmc-pos-v2-home" data-trfmc-portal-os-home="mounted">
              <div className="trfmc-pos-v2-hero">
                <p>Unified Home · Command Center</p>
                <h1>Una sola shell. Un solo manifest. Un solo viewport.</h1>
                <span>
                  Questa preview non sostituisce ancora il portale attuale: dimostra la nuova radice
                  architetturale che governerà V63, domini React, sorgenti legacy, API, evidenze e QA.
                </span>
              </div>

              <div className="trfmc-pos-v2-metrics">
                <article>
                  <span>Promoted React</span>
                  <strong>{promotedPortalOSModules.length}</strong>
                  <em>RF Physics · Signal Analyzer · Antenna</em>
                </article>
                <article>
                  <span>V63 references</span>
                  <strong>{referencePortalOSModules.length}</strong>
                  <em>Command Center model</em>
                </article>
                <article>
                  <span>Candidate domains</span>
                  <strong>{candidatePortalOSModules.length}</strong>
                  <em>Core/RAN · War Room · Knowledge</em>
                </article>
              </div>

              <div className="trfmc-pos-v2-domain-grid">
                {portalOSModules.slice(1).map((module) => (
                  <button key={module.id} type="button" onClick={() => setActiveModuleId(module.id)}>
                    <span>{statusLabel(module.status)}</span>
                    <strong>{module.title}</strong>
                    <em>{module.description}</em>
                  </button>
                ))}
              </div>
            </section>
          ) : (
            <section className="trfmc-pos-v2-module">
              <div className="trfmc-pos-v2-hero">
                <p>{activeModule.category} · {activeModule.status}</p>
                <h1>{activeModule.title}</h1>
                <span>{activeModule.description}</span>
              </div>

              <div className="trfmc-pos-v2-module-grid">
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
                  <span>Mode</span>
                  <strong>{activeModule.status}</strong>
                  <em>governance state</em>
                </article>
              </div>

              <section className="trfmc-pos-v2-contract">
                <span>Viewport contract</span>
                <strong>
                  Il modulo viene trattato come leaf governato dal Portal OS: non come home parallela,
                  non come iframe strutturale, non come shell duplicata.
                </strong>
              </section>
            </section>
          )}
        </main>

        <aside className="trfmc-pos-v2-evidence">
          <div className="trfmc-pos-v2-panel-title">
            <span>Command / Evidence</span>
            <strong>P4B V2</strong>
          </div>

          <section>
            <h3>Active module</h3>
            <p>{activeModule.title}</p>
            <code>{activeModule.source}</code>
          </section>

          <section>
            <h3>Runtime endpoints</h3>
            {endpoints.map((endpoint) => (
              <div key={endpoint.id} className={`trfmc-pos-v2-endpoint is-${endpoint.state}`}>
                <span>{endpoint.label}</span>
                <strong>{endpoint.state}</strong>
                <em>{endpoint.detail}</em>
              </div>
            ))}
          </section>

          <section>
            <h3>Event stream</h3>
            <p>tick #{tick}</p>
            <p>Preview mounted inside existing App root.</p>
          </section>
        </aside>
      </div>
    </section>
  )
}
TSX

echo
echo "=== 3) CREA portal-os.css ==="

cat > "$CSS" <<'CSS'
.trfmc-pos-root-v2 {
  min-height: 100vh;
  background:
    radial-gradient(circle at 18% 0%, rgba(103, 232, 249, .11), transparent 30%),
    radial-gradient(circle at 88% 16%, rgba(134, 239, 172, .09), transparent 30%),
    linear-gradient(135deg, #020814 0%, #04101f 55%, #01040b 100%);
  color: #e8f7ff;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

.trfmc-pos-v2-status {
  min-height: 56px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 18px;
  padding: 0 18px;
  border-bottom: 1px solid rgba(103, 232, 249, .18);
  background: rgba(0, 6, 16, .90);
}

.trfmc-pos-v2-status strong {
  display: block;
  color: #e8f7ff;
  font-size: 13px;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.trfmc-pos-v2-status span {
  color: #9fb8ca;
  font-size: 11px;
}

.trfmc-pos-v2-status > div:last-child {
  display: flex;
  gap: 10px;
  align-items: center;
}

.trfmc-pos-v2-status > div:last-child span {
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 999px;
  padding: 6px 10px;
  background: rgba(103, 232, 249, .06);
  color: #67e8f9;
}

.trfmc-pos-v2-layout {
  height: calc(100vh - 56px);
  display: grid;
  grid-template-columns: 310px minmax(0, 1fr) 340px;
  gap: 10px;
  padding: 10px;
}

.trfmc-pos-v2-launcher,
.trfmc-pos-v2-viewport,
.trfmc-pos-v2-evidence {
  min-height: 0;
  border: 1px solid rgba(103, 232, 249, .16);
  border-radius: 18px;
  background: rgba(2, 12, 24, .72);
  box-shadow: 0 24px 90px rgba(0, 0, 0, .32);
}

.trfmc-pos-v2-launcher,
.trfmc-pos-v2-evidence {
  overflow: hidden;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
}

.trfmc-pos-v2-panel-title {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px;
  border-bottom: 1px solid rgba(103, 232, 249, .14);
}

.trfmc-pos-v2-panel-title span {
  color: #67e8f9;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-pos-v2-panel-title strong {
  color: #86efac;
  font-size: 14px;
}

.trfmc-pos-v2-module-list {
  overflow: auto;
  padding: 10px;
  display: grid;
  gap: 8px;
}

.trfmc-pos-v2-module-list button,
.trfmc-pos-v2-domain-grid button {
  text-align: left;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 14px;
  background: rgba(0, 6, 16, .45);
  color: inherit;
  padding: 10px;
  cursor: pointer;
}

.trfmc-pos-v2-module-list button.is-active,
.trfmc-pos-v2-module-list button:hover,
.trfmc-pos-v2-domain-grid button:hover {
  border-color: rgba(134, 239, 172, .42);
  background: rgba(8, 47, 38, .22);
}

.trfmc-pos-v2-module-list span,
.trfmc-pos-v2-domain-grid span,
.trfmc-pos-v2-metrics span,
.trfmc-pos-v2-module-grid span,
.trfmc-pos-v2-contract span {
  display: block;
  color: #67e8f9;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.trfmc-pos-v2-module-list strong,
.trfmc-pos-v2-domain-grid strong {
  display: block;
  margin-top: 5px;
  color: #e8f7ff;
  font-size: 12px;
}

.trfmc-pos-v2-module-list em,
.trfmc-pos-v2-domain-grid em {
  display: block;
  margin-top: 5px;
  color: #9fb8ca;
  font-size: 10px;
  font-style: normal;
  line-height: 1.25;
}

.trfmc-pos-v2-viewport {
  overflow: auto;
  padding: 14px;
}

.trfmc-pos-v2-hero {
  border: 1px solid rgba(103, 232, 249, .14);
  border-radius: 18px;
  padding: 18px;
  background:
    radial-gradient(circle at 15% 0%, rgba(103, 232, 249, .12), transparent 35%),
    linear-gradient(180deg, rgba(2, 18, 34, .75), rgba(0, 6, 16, .52));
}

.trfmc-pos-v2-hero p {
  margin: 0 0 8px;
  color: #67e8f9;
  font-size: 11px;
  font-weight: 900;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-pos-v2-hero h1 {
  margin: 0 0 8px;
  color: #e8f7ff;
  font-size: 32px;
  line-height: .98;
}

.trfmc-pos-v2-hero span {
  color: #9fb8ca;
  font-size: 13px;
  line-height: 1.45;
}

.trfmc-pos-v2-metrics,
.trfmc-pos-v2-module-grid {
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.trfmc-pos-v2-metrics article,
.trfmc-pos-v2-module-grid article,
.trfmc-pos-v2-contract {
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 16px;
  padding: 14px;
  background: rgba(0, 6, 16, .34);
}

.trfmc-pos-v2-metrics strong,
.trfmc-pos-v2-module-grid strong {
  display: block;
  margin-top: 8px;
  color: #86efac;
  font-size: 23px;
  line-height: 1;
  word-break: break-word;
}

.trfmc-pos-v2-module-grid strong {
  color: #e8f7ff;
  font-size: 13px;
}

.trfmc-pos-v2-metrics em,
.trfmc-pos-v2-module-grid em {
  display: block;
  margin-top: 8px;
  color: #9fb8ca;
  font-size: 10px;
  font-style: normal;
}

.trfmc-pos-v2-domain-grid {
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.trfmc-pos-v2-contract {
  margin-top: 10px;
}

.trfmc-pos-v2-contract strong {
  display: block;
  margin-top: 8px;
  color: #e8f7ff;
  font-size: 13px;
  line-height: 1.45;
}

.trfmc-pos-v2-evidence section {
  margin: 10px;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 14px;
  padding: 10px;
  background: rgba(0, 6, 16, .34);
}

.trfmc-pos-v2-evidence h3 {
  margin: 0 0 8px;
  color: #67e8f9;
  font-size: 10px;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.trfmc-pos-v2-evidence p,
.trfmc-pos-v2-evidence code {
  color: #9fb8ca;
  font-size: 11px;
  line-height: 1.35;
  word-break: break-word;
}

.trfmc-pos-v2-endpoint {
  display: grid;
  gap: 3px;
  padding: 8px 0;
  border-top: 1px solid rgba(103, 232, 249, .10);
}

.trfmc-pos-v2-endpoint span {
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-pos-v2-endpoint strong {
  color: #fbbf24;
  font-size: 10px;
  text-transform: uppercase;
}

.trfmc-pos-v2-endpoint.is-online strong {
  color: #86efac;
}

.trfmc-pos-v2-endpoint.is-offline strong {
  color: #f87171;
}

.trfmc-pos-v2-endpoint em {
  color: #9fb8ca;
  font-size: 9px;
  font-style: normal;
}

@media (max-width: 1280px) {
  .trfmc-pos-v2-layout {
    grid-template-columns: 260px minmax(0, 1fr);
  }

  .trfmc-pos-v2-evidence {
    display: none;
  }

  .trfmc-pos-v2-domain-grid,
  .trfmc-pos-v2-metrics,
  .trfmc-pos-v2-module-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
CSS

echo
echo "=== 4) PATCH main.tsx: conditional render dentro App, dopo gli hook esistenti ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
before = text

# Remove stale P4B V2 blocks if rerun.
text = re.sub(
    r"\n?/\* TRFMC P4B PORTAL OS ROOT PREVIEW V2 START \*/.*?/\* TRFMC P4B PORTAL OS ROOT PREVIEW V2 END \*/\n?",
    "\n",
    text,
    flags=re.S,
)

import_line = "import { PortalOSRoot } from '../portal-os/PortalOSRoot'"

if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

if "const trfmcPortalOsPreview =" not in text:
    needle = "  const trfmcEngineeringFocus =\n    trfmcActiveHash === '#full-engineering-stack' ||\n    trfmcActiveHash === '#full-engineering';"
    replacement = needle + "\n\n  const trfmcPortalOsPreview = trfmcActiveHash === '#portal-os-preview';"
    if needle not in text:
        raise SystemExit("ERRORE: blocco trfmcEngineeringFocus non trovato")
    text = text.replace(needle, replacement, 1)

return_block = """  /* TRFMC P4B PORTAL OS ROOT PREVIEW V2 START */
  if (trfmcPortalOsPreview) {
    return <PortalOSRoot />
  }
  /* TRFMC P4B PORTAL OS ROOT PREVIEW V2 END */

"""

needle_if = "  if (trfmcEngineeringFocus) {"
if needle_if not in text:
    raise SystemExit("ERRORE: if trfmcEngineeringFocus non trovato")

text = text.replace(needle_if, return_block + needle_if, 1)

path.write_text(text, encoding="utf-8")
print("MAIN_PATCHED=", text != before)
PY

echo
echo "=== 5) DIFF ==="
git diff -- "$MAIN" "$PORTAL_DIR" > "$DIFF" || true
sed -n '1,240p' "$DIFF"

echo
echo "=== 6) BUILD ==="

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
echo "=== 7) HTTP GATE ==="

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
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

FRONTEND_HTTP_NON_200="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
FRONTEND_HTTP_ZERO_BYTES="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 8) STATIC SAFETY GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" "$PORTAL_DIR" "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" "$PORTAL_DIR" "$MAIN")"
  EXTRA_ROOT_COUNT="$(safe_count_files "createRoot" "$PORTAL_DIR")"
  V42_P4B_COUNT="$(safe_count_files "P4B PORTAL OS|PortalOSRoot|portal-os-preview" frontend/src/layout_orchestrator 2>/dev/null || true)"
  MAIN_PREVIEW_COUNT="$(safe_count_files "trfmcPortalOsPreview|PortalOSRoot" "$MAIN")"
  PREVIEW_MARKER_SOURCE="$(safe_count_files "data-trfmc-portal-os-preview" "$PORTAL_DIR")"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_in_portal_os\t$([ "$EXTRA_ROOT_COUNT" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_COUNT"
  echo -e "v42_not_touched_by_p4b_v2\t$([ "$V42_P4B_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4B_COUNT"
  echo -e "main_conditional_preview_present\t$([ "$MAIN_PREVIEW_COUNT" -gt 0 ] && echo PASS || echo FAIL)\t$MAIN_PREVIEW_COUNT"
  echo -e "preview_marker_source_present\t$([ "$PREVIEW_MARKER_SOURCE" -gt 0 ] && echo PASS || echo FAIL)\t$PREVIEW_MARKER_SOURCE"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 9) DOM / SCREENSHOT GATE ==="

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
V42_TITLE_COUNT="$(safe_count_literal 'TELCO RF MISSION CONTROL PLATFORM' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "PREVIEW_MARKER_COUNT=$PREVIEW_MARKER_COUNT"
echo "HOME_MARKER_COUNT=$HOME_MARKER_COUNT"
echo "VIEWPORT_MARKER_COUNT=$VIEWPORT_MARKER_COUNT"
echo "LAUNCHER_COUNT=$LAUNCHER_COUNT"
echo "EVIDENCE_COUNT=$EVIDENCE_COUNT"
echo "TITLE_COUNT=$TITLE_COUNT"
echo "V42_TITLE_COUNT=$V42_TITLE_COUNT"
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
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_STILL_VISIBLE_IN_PREVIEW"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4B_PORTAL_OS_ROOT_PREVIEW_V2",
  "mutation": "frontend_source_existing_root_conditional_preview",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "preview_route": "#portal-os-preview",
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
  "v42_title_count": $V42_TITLE_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4b_portal_os_root_preview_v2"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4B_PORTAL_OS_ROOT_PREVIEW_V2 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
