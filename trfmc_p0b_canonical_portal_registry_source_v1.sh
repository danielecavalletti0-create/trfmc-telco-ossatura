#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

REGISTRY="frontend/src/app/portalRegistry.ts"
NAV="frontend/src/app/PortalShellNavigationP0.tsx"
ORCH="frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_p0b_canonical_portal_registry_source_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/p0b_canonical_portal_registry_1920x1080.png"
DIFF="$OUT/p0b_canonical_portal_registry.diff"
RESTORE="$OUT/RESTORE_P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1.sh"

echo "============================================================"
echo "TRFMC_P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1"
echo "Canonical portal registry + shell navigation · source mutation"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ORCH" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file richiesto mancante: $f"
    exit 1
  fi
done

mkdir -p "$(dirname "$REGISTRY")"

[ -f "$REGISTRY" ] && cp -a "$REGISTRY" "$BACKUP/portalRegistry.ts.before_$TS"
[ -f "$NAV" ] && cp -a "$NAV" "$BACKUP/PortalShellNavigationP0.tsx.before_$TS"
cp -a "$ORCH" "$BACKUP/MissionLayoutOrchestratorV42.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

if [ -f "$BACKUP/portalRegistry.ts.before_$TS" ]; then
  cp -a "$BACKUP/portalRegistry.ts.before_$TS" "$REGISTRY"
else
  rm -f "$REGISTRY"
fi

if [ -f "$BACKUP/PortalShellNavigationP0.tsx.before_$TS" ]; then
  cp -a "$BACKUP/PortalShellNavigationP0.tsx.before_$TS" "$NAV"
else
  rm -f "$NAV"
fi

cp -a "$BACKUP/MissionLayoutOrchestratorV42.tsx.before_$TS" "$ORCH"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"

echo "RESTORE_P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA portalRegistry.ts ==="

cat > "$REGISTRY" <<'TS'
export type TRFMCDomainId =
  | '01_Mission_Control'
  | '02_RF_Physics'
  | '03_Signal_Analyzer'
  | '04_RF_Microwave_Engineering'
  | '05_Antenna_System'
  | '06_Microwave_Link'
  | '07_Fiber_Optic'
  | '08_Private_Networks'
  | '09_Core_Network'
  | '10_Data_Center_Infrastructure'
  | '11_Cyber_RF_Intelligence'
  | '12_Knowledge_Base'

export type TRFMCDomainRegistryEntry = {
  order: string
  domain: TRFMCDomainId
  routeHash: string
  label: string
  purpose: string
  candidateCount: number
  primaryCandidate: string
  nextAction: 'PROMOTE_DOMAIN_ENTRY' | 'CREATE_DOMAIN_PLACEHOLDER'
  status: 'P0_READY' | 'P0_PLACEHOLDER'
}

export type TRFMCP0ShellCandidate = {
  priority: string
  domain: string
  path: string
  recommendedUse: string
  score: number
  debtHits: number
  reason: string
}

export const TRFMC_CANONICAL_DOMAINS: TRFMCDomainRegistryEntry[] = [
  {
    order: '01',
    domain: '01_Mission_Control',
    routeHash: '#mission-overview',
    label: 'Mission Control',
    purpose: 'Portal shell, NOC, command deck, integration control room',
    candidateCount: 13,
    primaryCandidate: 'frontend/public/portal_index_v19.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '02',
    domain: '02_RF_Physics',
    routeHash: '#rf-physics',
    label: 'RF Physics',
    purpose: 'Maxwell, propagation, field models, RF theory engines',
    candidateCount: 8,
    primaryCandidate: 'frontend/public/webgl_rf_physics_engine_v85d_runtime_identity_lock.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '03',
    domain: '03_Signal_Analyzer',
    routeHash: '#signal-analyzer',
    label: 'Signal Analyzer',
    purpose: 'Spectrum, waterfall, I/Q, VSA, RF instruments',
    candidateCount: 14,
    primaryCandidate: 'frontend/public/rf_instrumentation_signal_cockpit_v38.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '04',
    domain: '04_RF_Microwave_Engineering',
    routeHash: '#rf-microwave',
    label: 'RF/Microwave',
    purpose: 'Smith chart, microwave links, filters, RF chain',
    candidateCount: 2,
    primaryCandidate: 'frontend/public/trfmc_rf_microwave_engineering_v1.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '05',
    domain: '05_Antenna_System',
    routeHash: '#antenna-system',
    label: 'Antenna System',
    purpose: 'Antenna explorer, RRU/RET/CPRI, radiation patterns',
    candidateCount: 16,
    primaryCandidate: 'frontend/public/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '06',
    domain: '06_Microwave_Link',
    routeHash: '#microwave-link',
    label: 'Microwave Link',
    purpose: 'Path profile, Fresnel zone, fade margin',
    candidateCount: 0,
    primaryCandidate: '-',
    nextAction: 'CREATE_DOMAIN_PLACEHOLDER',
    status: 'P0_PLACEHOLDER',
  },
  {
    order: '07',
    domain: '07_Fiber_Optic',
    routeHash: '#fiber-optic',
    label: 'Fiber Optic',
    purpose: 'OTDR, fronthaul, fiber diagnostics',
    candidateCount: 1,
    primaryCandidate: 'frontend/public/trfmc_fiber_fronthaul_otdr_workbench_v2.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '08',
    domain: '08_Private_Networks',
    routeHash: '#private-networks',
    label: 'Private Networks',
    purpose: 'Wi-Fi, mesh, private 5G/Wi-Fi integration',
    candidateCount: 1,
    primaryCandidate: 'frontend/public/trfmc_wifi_5_6_7_8_qam_engine_v1.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '09',
    domain: '09_Core_Network',
    routeHash: '#core-network',
    label: 'Core/RAN',
    purpose: 'Open5GS, UERANSIM, AKA, NAS, NGAP, PFCP',
    candidateCount: 2,
    primaryCandidate: 'frontend/public/trfmc_5g_core_ran_identity_aka_engine_v1.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '10',
    domain: '10_Data_Center_Infrastructure',
    routeHash: '#data-center',
    label: 'Data Center',
    purpose: 'Power, PDU, racks, digital twin infrastructure',
    candidateCount: 0,
    primaryCandidate: '-',
    nextAction: 'CREATE_DOMAIN_PLACEHOLDER',
    status: 'P0_PLACEHOLDER',
  },
  {
    order: '11',
    domain: '11_Cyber_RF_Intelligence',
    routeHash: '#cyber-rf-intelligence',
    label: 'Cyber RF Intelligence',
    purpose: 'Evidence, cyber/RF, supervision, reports',
    candidateCount: 2,
    primaryCandidate: 'frontend/public/security_console_v18.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
  {
    order: '12',
    domain: '12_Knowledge_Base',
    routeHash: '#knowledge-base',
    label: 'Knowledge Base',
    purpose: 'Theory, procedures, glossary, doctrine',
    candidateCount: 3,
    primaryCandidate: 'frontend/public/rf_telco_knowledge_os_v60.html',
    nextAction: 'PROMOTE_DOMAIN_ENTRY',
    status: 'P0_READY',
  },
]

export const TRFMC_P0_SHELL_CANDIDATES: TRFMCP0ShellCandidate[] = [
  {
    priority: 'P0.01',
    domain: '00_Unclassified',
    path: 'frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html',
    recommendedUse: 'P0_SHELL_BEHAVIOR_REFERENCE',
    score: 100,
    debtHits: 0,
    reason: 'latest official safe command center, latest version marker',
  },
  {
    priority: 'P0.02',
    domain: '01_Mission_Control',
    path: 'frontend/public/trfmc_home_v87g.html',
    recommendedUse: 'P0_HOME_REFERENCE',
    score: 95,
    debtHits: 0,
    reason: 'home candidate, latest version marker',
  },
  {
    priority: 'P0.05',
    domain: '01_Mission_Control',
    path: 'frontend/public/trfmc_integration_control_room.html',
    recommendedUse: 'P0_CONTROL_ROOM_CONTENT_SOURCE',
    score: 80,
    debtHits: 1,
    reason: 'integration control room, has debt hits',
  },
  {
    priority: 'P0.07',
    domain: '01_Mission_Control',
    path: 'frontend/public/portal_index_v19.html',
    recommendedUse: 'P0_INDEX_STRUCTURE_SOURCE',
    score: 70,
    debtHits: 2,
    reason: 'portal index, has debt hits',
  },
]

export const TRFMC_P0_GOVERNANCE = {
  phase: 'P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1',
  shellRule: 'One React shell, one navigation registry, no public HTML as parallel portal',
  mutationScope: 'frontend source only',
  backendMutation: false,
  iframeAllowed: false,
  runtimePatchAllowed: false,
}
TS

echo
echo "=== 2) CREA PortalShellNavigationP0.tsx ==="

cat > "$NAV" <<'TSX'
import { TRFMC_CANONICAL_DOMAINS, TRFMC_P0_GOVERNANCE, TRFMC_P0_SHELL_CANDIDATES } from './portalRegistry'

function statusLabel(status: string) {
  if (status === 'P0_READY') return 'ready'
  return 'placeholder'
}

export function PortalShellNavigationP0() {
  const ready = TRFMC_CANONICAL_DOMAINS.filter((item) => item.status === 'P0_READY').length
  const placeholders = TRFMC_CANONICAL_DOMAINS.length - ready
  const totalCandidates = TRFMC_CANONICAL_DOMAINS.reduce((sum, item) => sum + item.candidateCount, 0)

  return (
    <section className="trfmc-p0b-shell-nav" data-trfmc-p0b-portal-navigation="mounted">
      <div className="trfmc-p0b-shell-nav-head">
        <div>
          <p>TRFMC P0B · Canonical Portal Registry</p>
          <h2>Portale unico: shell, domini, promozione controllata</h2>
          <span>
            Il portale riparte da un registry sorgente React: gli HTML pubblici sono fonti da promuovere,
            non portali paralleli. Ogni dominio ha route, candidato primario e azione di integrazione.
          </span>
        </div>
        <div className="trfmc-p0b-kpi-strip">
          <strong>{TRFMC_CANONICAL_DOMAINS.length}</strong>
          <span>domains</span>
          <strong>{ready}</strong>
          <span>ready</span>
          <strong>{placeholders}</strong>
          <span>placeholder</span>
        </div>
      </div>

      <div className="trfmc-p0b-domain-grid" aria-label="TRFMC canonical domain registry">
        {TRFMC_CANONICAL_DOMAINS.map((domain) => (
          <a
            key={domain.domain}
            className={`trfmc-p0b-domain-card ${domain.status === 'P0_READY' ? 'ready' : 'placeholder'}`}
            href={domain.routeHash}
            title={domain.primaryCandidate}
          >
            <small>{domain.order} · {statusLabel(domain.status)}</small>
            <strong>{domain.label}</strong>
            <span>{domain.purpose}</span>
            <em>{domain.candidateCount} candidate · {domain.nextAction}</em>
          </a>
        ))}
      </div>

      <div className="trfmc-p0b-governance-row">
        <article>
          <span>Governance</span>
          <strong>{TRFMC_P0_GOVERNANCE.phase}</strong>
          <p>{TRFMC_P0_GOVERNANCE.shellRule}</p>
        </article>
        <article>
          <span>P0 shell sources</span>
          <strong>{TRFMC_P0_SHELL_CANDIDATES.length} selected</strong>
          <p>{TRFMC_P0_SHELL_CANDIDATES.map((candidate) => candidate.priority).join(' · ')}</p>
        </article>
        <article>
          <span>Candidate mass</span>
          <strong>{totalCandidates}</strong>
          <p>Promote by domain, not by random patch.</p>
        </article>
      </div>
    </section>
  )
}
TSX

echo
echo "=== 3) PATCH MissionLayoutOrchestratorV42.tsx ==="

python3 - "$ORCH" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
before = text

import_line = "import { PortalShellNavigationP0 } from '../app/PortalShellNavigationP0'"

if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

if "data-trfmc-p0b-portal-navigation" not in text and "<PortalShellNavigationP0 />" not in text:
    lines = text.splitlines()
    return_idx = None

    for idx, line in enumerate(lines):
        if re.search(r"\breturn\s*\(", line):
            return_idx = idx
            break

    if return_idx is None:
        raise SystemExit("ERRORE: return (...) non trovato in MissionLayoutOrchestratorV42.tsx")

    j = return_idx + 1
    while j < len(lines) and not lines[j].strip():
        j += 1

    if j >= len(lines):
        raise SystemExit("ERRORE: JSX dopo return non trovato")

    stripped = lines[j].strip()

    # Case 1: fragment root
    if stripped.startswith("<>") or stripped.startswith("<React.Fragment"):
        indent = re.match(r"^(\s*)", lines[j]).group(1) + "  "
        lines.insert(j + 1, f"{indent}<PortalShellNavigationP0 />")
    else:
        # Case 2: normal opening root tag. Insert as first child after the opening tag.
        k = j
        while k < len(lines) and ">" not in lines[k]:
            k += 1

        if k >= len(lines):
            raise SystemExit("ERRORE: apertura JSX root non chiusa")

        if "/>" in lines[k]:
            raise SystemExit("ERRORE: root JSX self-closing, patch non sicura")

        indent = re.match(r"^(\s*)", lines[k]).group(1) + "  "
        lines.insert(k + 1, f"{indent}<PortalShellNavigationP0 />")

    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

path.write_text(text, encoding="utf-8")
print("ORCHESTRATOR_PATCHED=", before != text)
PY

echo
echo "=== 4) PATCH styles.css ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC P0B CANONICAL PORTAL REGISTRY SOURCE V1 START === \*/.*?/\* === TRFMC P0B CANONICAL PORTAL REGISTRY SOURCE V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC P0B CANONICAL PORTAL REGISTRY SOURCE V1 START === */
/*
  P0B Portal Registry / Shell Navigation.
  Scope: frontend source only. No iframe, no runtime patch, no public HTML as parallel portal.
*/

.trfmc-p0b-shell-nav {
  margin: 8px 0 10px 0;
  padding: 10px;
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 14px;
  background:
    radial-gradient(circle at 12% 0%, rgba(57, 215, 255, .08), transparent 34%),
    linear-gradient(180deg, rgba(3, 12, 24, .74), rgba(1, 7, 16, .86));
  box-shadow: 0 18px 50px rgba(0, 0, 0, .18);
}

.trfmc-p0b-shell-nav-head {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 184px;
  gap: 10px;
  align-items: stretch;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(103, 232, 249, .13);
}

.trfmc-p0b-shell-nav-head p {
  margin: 0 0 4px 0;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.trfmc-p0b-shell-nav-head h2 {
  margin: 0 0 5px 0;
  color: #e8f7ff;
  font-size: 18px;
  line-height: 1.05;
}

.trfmc-p0b-shell-nav-head span {
  display: block;
  color: #9fb8ca;
  font-size: 11px;
  line-height: 1.32;
}

.trfmc-p0b-kpi-strip {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 4px;
  align-content: center;
  text-align: center;
  border: 1px solid rgba(134, 239, 172, .18);
  border-radius: 12px;
  background: rgba(8, 47, 38, .20);
  padding: 7px;
}

.trfmc-p0b-kpi-strip strong {
  color: #86efac;
  font-size: 19px;
  line-height: 1;
}

.trfmc-p0b-kpi-strip span {
  color: #9fb8ca;
  font-size: 8px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p0b-domain-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 7px;
  margin-top: 8px;
}

.trfmc-p0b-domain-card {
  display: block;
  min-width: 0;
  text-decoration: none;
  border: 1px solid rgba(103, 232, 249, .13);
  border-radius: 11px;
  background: rgba(2, 10, 20, .42);
  padding: 8px;
  transition: transform .16s ease, border-color .16s ease, background .16s ease;
}

.trfmc-p0b-domain-card:hover {
  transform: translateY(-1px);
  border-color: rgba(103, 232, 249, .35);
  background: rgba(8, 47, 73, .22);
}

.trfmc-p0b-domain-card.ready {
  border-color: rgba(103, 232, 249, .16);
}

.trfmc-p0b-domain-card.placeholder {
  border-color: rgba(251, 191, 36, .22);
  background: rgba(120, 53, 15, .12);
}

.trfmc-p0b-domain-card small,
.trfmc-p0b-domain-card strong,
.trfmc-p0b-domain-card span,
.trfmc-p0b-domain-card em {
  display: block;
}

.trfmc-p0b-domain-card small {
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-p0b-domain-card strong {
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 12px;
}

.trfmc-p0b-domain-card span {
  margin-top: 4px;
  color: #9fb8ca;
  font-size: 9.2px;
  line-height: 1.22;
}

.trfmc-p0b-domain-card em {
  margin-top: 6px;
  color: #86efac;
  font-style: normal;
  font-size: 8px;
  text-transform: uppercase;
  letter-spacing: .06em;
}

.trfmc-p0b-governance-row {
  display: grid;
  grid-template-columns: 1.25fr .85fr .65fr;
  gap: 7px;
  margin-top: 8px;
}

.trfmc-p0b-governance-row article {
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 10px;
  background: rgba(0, 4, 10, .24);
  padding: 8px;
}

.trfmc-p0b-governance-row span {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .10em;
  text-transform: uppercase;
}

.trfmc-p0b-governance-row strong {
  display: block;
  margin-top: 3px;
  color: #e8f7ff;
  font-size: 11px;
}

.trfmc-p0b-governance-row p {
  margin: 4px 0 0 0;
  color: #9fb8ca;
  font-size: 9.5px;
  line-height: 1.25;
}

@media (max-width: 1420px) {
  .trfmc-p0b-domain-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}

@media (max-width: 980px) {
  .trfmc-p0b-shell-nav-head,
  .trfmc-p0b-governance-row,
  .trfmc-p0b-domain-grid {
    grid-template-columns: 1fr;
  }
}
/* === TRFMC P0B CANONICAL PORTAL REGISTRY SOURCE V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_P0B_APPENDED=True")
PY

echo
echo "=== 5) DIFF ==="

git diff -- "$REGISTRY" "$NAV" "$ORCH" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

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

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 8) DOM / IFRAME / PUBLIC PATCH GATE ==="

DOM_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=5000 \
      --dump-dom \
      "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=5000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>&1 || true
  elif command -v chromium >/dev/null 2>&1; then
    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=5000 \
      --dump-dom \
      "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=5000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>&1 || true
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
  fi
else
  echo "BUILD_NOT_PASS" > "$DOM"
fi

P0B_MARKER_COUNT="$(awk 'index($0, "data-trfmc-p0b-portal-navigation=\"mounted\"") {c++} END {print c+0}' "$DOM" 2>/dev/null || echo 0)"
IFRAME_COUNT="$(grep -RIn "<iframe" "$REGISTRY" "$NAV" "$ORCH" 2>/dev/null | wc -l | tr -d ' ')"
PUBLIC_RUNTIME_PATCH_REFS="$(grep -RIn "frontend/public\|/assets/trfmc_.*v51\|runtime injection\|innerHTML" "$REGISTRY" "$NAV" "$ORCH" 2>/dev/null | wc -l | tr -d ' ')"
CSS_MARKER_COUNT="$(awk 'index($0, "TRFMC P0B CANONICAL PORTAL REGISTRY SOURCE V1 START") {c++} END {print c+0}' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P0B_MARKER_COUNT=$P0B_MARKER_COUNT"
echo "IFRAME_COUNT=$IFRAME_COUNT"
echo "PUBLIC_RUNTIME_PATCH_REFS=$PUBLIC_RUNTIME_PATCH_REFS"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$HTTP_ZERO_BYTES_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0B_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_DOM_MARKER"; fi
if [ "$IFRAME_COUNT" != "0" ]; then RESULT="REVIEW_IFRAME"; fi
if [ "$PUBLIC_RUNTIME_PATCH_REFS" != "0" ]; then RESULT="REVIEW_PUBLIC_RUNTIME_PATCH"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1",
  "mutation": "frontend_source_registry_navigation",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "files_modified": [
    "$REGISTRY",
    "$NAV",
    "$ORCH",
    "$CSS"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $HTTP_NON_200_FRONTEND,
  "frontend_http_zero_bytes": $HTTP_ZERO_BYTES_FRONTEND,
  "dom_result": "$DOM_RESULT",
  "p0b_marker_count": $P0B_MARKER_COUNT,
  "iframe_count": $IFRAME_COUNT,
  "public_runtime_patch_refs": $PUBLIC_RUNTIME_PATCH_REFS,
  "css_marker_count": $CSS_MARKER_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p0b_canonical_portal_registry_source_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P0B_CANONICAL_PORTAL_REGISTRY_SOURCE_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
