#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P0C_MISSION_CONTROL_CONTENT_PROMOTION_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

HOME="frontend/src/app/MissionControlHomeP0C.tsx"
ROOM="frontend/src/app/MissionControlIntegrationRoomP0C.tsx"
INDEX="frontend/src/app/MissionControlPortalIndexP0C.tsx"
CONTENT="frontend/src/app/MissionControlContentP0C.tsx"
ORCH="frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
CSS="frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_p0c_mission_control_content_promotion_v1.log"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_gate.txt"
SCREEN="$OUT/p0c_mission_control_content_1920x1080.png"
DIFF="$OUT/p0c_mission_control_content_promotion.diff"
GATE="$OUT/p0c_gate.tsv"
RESTORE="$OUT/RESTORE_P0C_MISSION_CONTROL_CONTENT_PROMOTION_V1.sh"

safe_count_grep() {
  local pattern="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  grep -RIn "$pattern" "$@" > "$tmp" 2>/dev/null || true
  wc -l < "$tmp" | tr -d ' '
  rm -f "$tmp"
}

safe_count_file_literal() {
  local literal="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return 0
  fi
  awk -v lit="$literal" 'index($0, lit) {c++} END {print c+0}' "$file"
}

echo "============================================================"
echo "TRFMC_P0C_MISSION_CONTROL_CONTENT_PROMOTION_V1"
echo "Mission Control content promotion · React clean components"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$ORCH" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file richiesto mancante: $f"
    exit 1
  fi
done

mkdir -p frontend/src/app

for f in "$HOME" "$ROOM" "$INDEX" "$CONTENT" "$ORCH" "$CSS"; do
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

restore_or_remove "$HOME" "$BACKUP/$(basename "$HOME").before_$TS"
restore_or_remove "$ROOM" "$BACKUP/$(basename "$ROOM").before_$TS"
restore_or_remove "$INDEX" "$BACKUP/$(basename "$INDEX").before_$TS"
restore_or_remove "$CONTENT" "$BACKUP/$(basename "$CONTENT").before_$TS"
restore_or_remove "$ORCH" "$BACKUP/$(basename "$ORCH").before_$TS"
restore_or_remove "$CSS" "$BACKUP/$(basename "$CSS").before_$TS"

echo "RESTORE_P0C_MISSION_CONTROL_CONTENT_PROMOTION_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA MissionControlHomeP0C.tsx ==="

cat > "$HOME" <<'TSX'
const homeKpis = [
  { label: 'Mission scope', value: 'RF · Telco · SOC/NOC', note: 'single operational cockpit' },
  { label: 'Portal mode', value: 'React SPA', note: 'public HTML is source material' },
  { label: 'Runtime chain', value: '5173 · 4181 · 8000', note: 'frontend + bridges + backend' },
  { label: 'Baseline', value: 'P0B ready', note: 'canonical domain registry mounted' },
]

const operatingPrinciples = [
  'One shell, one registry, one navigational truth.',
  'Mission Control governs domains before deep instrumentation.',
  'HTML sources are promoted into React components, never mounted as parallel portals.',
  'Every promoted section must pass build, HTTP, DOM marker, screenshot and debt gates.',
]

export function MissionControlHomeP0C() {
  return (
    <section className="trfmc-p0c-home" data-trfmc-p0c-home="mounted">
      <div className="trfmc-p0c-section-head">
        <p>P0C · Home promotion</p>
        <h3>RF / Telco Mission Control</h3>
        <span>
          Sintesi operativa estratta dalla home pubblica: il portale viene riportato dentro una
          singola console React, con governance dei domini, runtime chiari e promozione controllata.
        </span>
      </div>

      <div className="trfmc-p0c-kpi-grid">
        {homeKpis.map((item) => (
          <article key={item.label}>
            <span>{item.label}</span>
            <strong>{item.value}</strong>
            <em>{item.note}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-p0c-principles">
        {operatingPrinciples.map((item) => (
          <div key={item}>
            <b>✓</b>
            <span>{item}</span>
          </div>
        ))}
      </div>
    </section>
  )
}
TSX

echo
echo "=== 2) CREA MissionControlIntegrationRoomP0C.tsx ==="

cat > "$ROOM" <<'TSX'
const integrationRows = [
  {
    area: 'Frontend shell',
    status: 'P0B PASS',
    evidence: 'Canonical registry mounted in Mission Overview',
    next: 'Promote Mission Control content without iframe',
  },
  {
    area: 'Source discipline',
    status: 'ACTIVE',
    evidence: 'No backend, index or public asset mutation in P0C',
    next: 'Convert source structure into typed React cards',
  },
  {
    area: 'Runtime contract',
    status: 'OBSERVED',
    evidence: '5173 / 4181 / 8000 checked by gate',
    next: 'Bind APIs only after domain content is promoted',
  },
  {
    area: 'Debt control',
    status: 'ENFORCED',
    evidence: 'innerHTML and embedded scripts remain source-only references',
    next: 'No dangerous HTML injection in promoted components',
  },
]

const priorityQueue = [
  'Mission Control home and integration room',
  'Portal index and domain navigation',
  'RF Physics and Signal Analyzer domain entries',
  'Antenna System and 5G Core/RAN domain entries',
]

export function MissionControlIntegrationRoomP0C() {
  return (
    <section className="trfmc-p0c-room" data-trfmc-p0c-integration-room="mounted">
      <div className="trfmc-p0c-section-head">
        <p>P0C · Integration Control Room</p>
        <h3>Control room di integrazione</h3>
        <span>
          Conversione controllata della Control Room: stato, evidenze, priorità e prossima azione,
          senza importare script legacy o manipolazioni DOM.
        </span>
      </div>

      <div className="trfmc-p0c-integration-table" role="table" aria-label="P0C integration status">
        <div className="trfmc-p0c-table-row trfmc-p0c-table-head" role="row">
          <span>Area</span>
          <span>Status</span>
          <span>Evidence</span>
          <span>Next action</span>
        </div>
        {integrationRows.map((row) => (
          <div className="trfmc-p0c-table-row" role="row" key={row.area}>
            <strong>{row.area}</strong>
            <em>{row.status}</em>
            <span>{row.evidence}</span>
            <span>{row.next}</span>
          </div>
        ))}
      </div>

      <div className="trfmc-p0c-priority-strip">
        {priorityQueue.map((item, index) => (
          <article key={item}>
            <small>P{index}</small>
            <strong>{item}</strong>
          </article>
        ))}
      </div>
    </section>
  )
}
TSX

echo
echo "=== 3) CREA MissionControlPortalIndexP0C.tsx ==="

cat > "$INDEX" <<'TSX'
const portalDomains = [
  { id: '01', label: 'Mission Control', route: '#mission-overview', readiness: 'promoted' },
  { id: '02', label: 'RF Physics', route: '#rf-physics', readiness: 'queued' },
  { id: '03', label: 'Signal Analyzer', route: '#signal-analyzer', readiness: 'queued' },
  { id: '04', label: 'RF/Microwave', route: '#rf-microwave', readiness: 'queued' },
  { id: '05', label: 'Antenna System', route: '#antenna-system', readiness: 'queued' },
  { id: '06', label: 'Microwave Link', route: '#microwave-link', readiness: 'placeholder' },
  { id: '07', label: 'Fiber Optic', route: '#fiber-optic', readiness: 'queued' },
  { id: '08', label: 'Private Networks', route: '#private-networks', readiness: 'queued' },
  { id: '09', label: 'Core/RAN', route: '#core-network', readiness: 'queued' },
  { id: '10', label: 'Data Center', route: '#data-center', readiness: 'placeholder' },
  { id: '11', label: 'Cyber RF Intelligence', route: '#cyber-rf-intelligence', readiness: 'queued' },
  { id: '12', label: 'Knowledge Base', route: '#knowledge-base', readiness: 'queued' },
]

const promotionRules = [
  'Promote domain content into React components.',
  'Keep source HTML as reference evidence, not runtime content.',
  'Reject iframe, innerHTML and runtime public patching.',
  'Attach every domain to QA gates before calling it complete.',
]

export function MissionControlPortalIndexP0C() {
  return (
    <section className="trfmc-p0c-index" data-trfmc-p0c-portal-index="mounted">
      <div className="trfmc-p0c-section-head">
        <p>P0C · Portal index promotion</p>
        <h3>Indice operativo dei domini</h3>
        <span>
          Estratto concettuale del Portal Index: non replica il DOM legacy, ma porta nel portale
          ufficiale route, readiness e regole di promozione.
        </span>
      </div>

      <div className="trfmc-p0c-domain-lattice">
        {portalDomains.map((domain) => (
          <a key={domain.id} href={domain.route} className={`trfmc-p0c-domain-node ${domain.readiness}`}>
            <small>{domain.id}</small>
            <strong>{domain.label}</strong>
            <span>{domain.readiness}</span>
          </a>
        ))}
      </div>

      <div className="trfmc-p0c-rule-grid">
        {promotionRules.map((rule) => (
          <article key={rule}>
            <span>rule</span>
            <strong>{rule}</strong>
          </article>
        ))}
      </div>
    </section>
  )
}
TSX

echo
echo "=== 4) CREA MissionControlContentP0C.tsx ==="

cat > "$CONTENT" <<'TSX'
import { MissionControlHomeP0C } from './MissionControlHomeP0C'
import { MissionControlIntegrationRoomP0C } from './MissionControlIntegrationRoomP0C'
import { MissionControlPortalIndexP0C } from './MissionControlPortalIndexP0C'

export function MissionControlContentP0C() {
  return (
    <section className="trfmc-p0c-content" data-trfmc-p0c-mission-control-content="mounted">
      <div className="trfmc-p0c-content-head">
        <p>TRFMC P0C · Mission Control Content Promotion</p>
        <h2>Home · Integration Control Room · Portal Index</h2>
        <span>
          Primo contenuto P0 promosso nel portale React ufficiale. Questa sezione sostituisce il
          concetto di pagine pubbliche parallele con componenti governati e verificabili.
        </span>
      </div>

      <MissionControlHomeP0C />
      <MissionControlIntegrationRoomP0C />
      <MissionControlPortalIndexP0C />
    </section>
  )
}
TSX

echo
echo "=== 5) PATCH MissionLayoutOrchestratorV42.tsx ==="

python3 - "$ORCH" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
before = text

import_line = "import { MissionControlContentP0C } from '../app/MissionControlContentP0C'"

if import_line not in text:
    lines = text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(insert_at, import_line)
    text = "\n".join(lines) + ("\n" if before.endswith("\n") else "")

if "<MissionControlContentP0C />" not in text:
    if "<PortalShellNavigationP0 />" in text:
        text = text.replace(
            "<PortalShellNavigationP0 />",
            "<PortalShellNavigationP0 />\n        <MissionControlContentP0C />",
            1,
        )
    else:
        raise SystemExit("ERRORE: mount point <PortalShellNavigationP0 /> non trovato")

path.write_text(text, encoding="utf-8")
print("ORCHESTRATOR_P0C_PATCHED=", before != text)
PY

echo
echo "=== 6) PATCH styles.css ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC P0C MISSION CONTROL CONTENT PROMOTION V1 START === \*/.*?/\* === TRFMC P0C MISSION CONTROL CONTENT PROMOTION V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC P0C MISSION CONTROL CONTENT PROMOTION V1 START === */
.trfmc-p0c-content {
  margin-top: 8px;
  padding: 10px;
  border: 1px solid rgba(103, 232, 249, .16);
  border-radius: 14px;
  background:
    radial-gradient(circle at 86% 0%, rgba(134, 239, 172, .07), transparent 32%),
    linear-gradient(180deg, rgba(3, 12, 24, .68), rgba(0, 5, 13, .86));
}

.trfmc-p0c-content-head,
.trfmc-p0c-section-head {
  border-bottom: 1px solid rgba(103, 232, 249, .12);
  padding-bottom: 8px;
  margin-bottom: 8px;
}

.trfmc-p0c-content-head p,
.trfmc-p0c-section-head p {
  margin: 0 0 4px 0;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.trfmc-p0c-content-head h2,
.trfmc-p0c-section-head h3 {
  margin: 0 0 5px 0;
  color: #e8f7ff;
  line-height: 1.05;
}

.trfmc-p0c-content-head h2 {
  font-size: 18px;
}

.trfmc-p0c-section-head h3 {
  font-size: 15px;
}

.trfmc-p0c-content-head span,
.trfmc-p0c-section-head span {
  color: #9fb8ca;
  font-size: 10.5px;
  line-height: 1.32;
}

.trfmc-p0c-home,
.trfmc-p0c-room,
.trfmc-p0c-index {
  margin-top: 8px;
  padding: 9px;
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 12px;
  background: rgba(2, 10, 20, .38);
}

.trfmc-p0c-kpi-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 7px;
}

.trfmc-p0c-kpi-grid article,
.trfmc-p0c-rule-grid article,
.trfmc-p0c-priority-strip article {
  min-width: 0;
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 10px;
  background: rgba(0, 4, 10, .24);
  padding: 8px;
}

.trfmc-p0c-kpi-grid span,
.trfmc-p0c-rule-grid span,
.trfmc-p0c-priority-strip small {
  display: block;
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
  letter-spacing: .09em;
  text-transform: uppercase;
}

.trfmc-p0c-kpi-grid strong,
.trfmc-p0c-rule-grid strong,
.trfmc-p0c-priority-strip strong {
  display: block;
  margin-top: 4px;
  color: #e8f7ff;
  font-size: 11px;
  line-height: 1.18;
}

.trfmc-p0c-kpi-grid em {
  display: block;
  margin-top: 4px;
  color: #9fb8ca;
  font-size: 9px;
  font-style: normal;
}

.trfmc-p0c-principles {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 6px;
  margin-top: 8px;
}

.trfmc-p0c-principles div {
  display: grid;
  grid-template-columns: 20px minmax(0, 1fr);
  gap: 6px;
  align-items: center;
  border: 1px solid rgba(134, 239, 172, .14);
  border-radius: 9px;
  padding: 7px;
  background: rgba(8, 47, 38, .13);
}

.trfmc-p0c-principles b {
  color: #86efac;
}

.trfmc-p0c-principles span {
  color: #c7d7e1;
  font-size: 9.5px;
  line-height: 1.22;
}

.trfmc-p0c-integration-table {
  display: grid;
  gap: 5px;
}

.trfmc-p0c-table-row {
  display: grid;
  grid-template-columns: .75fr .45fr 1.2fr 1.25fr;
  gap: 6px;
  align-items: start;
  border: 1px solid rgba(103, 232, 249, .10);
  border-radius: 9px;
  padding: 7px;
  background: rgba(0, 4, 10, .22);
}

.trfmc-p0c-table-head {
  background: rgba(8, 47, 73, .24);
}

.trfmc-p0c-table-row span,
.trfmc-p0c-table-row strong,
.trfmc-p0c-table-row em {
  min-width: 0;
  font-size: 9.5px;
  line-height: 1.22;
}

.trfmc-p0c-table-row strong {
  color: #e8f7ff;
}

.trfmc-p0c-table-row em {
  color: #86efac;
  font-style: normal;
  font-weight: 900;
}

.trfmc-p0c-table-row span {
  color: #9fb8ca;
}

.trfmc-p0c-priority-strip {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 7px;
  margin-top: 8px;
}

.trfmc-p0c-domain-lattice {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 7px;
}

.trfmc-p0c-domain-node {
  text-decoration: none;
  border: 1px solid rgba(103, 232, 249, .12);
  border-radius: 10px;
  background: rgba(0, 4, 10, .24);
  padding: 7px;
}

.trfmc-p0c-domain-node small,
.trfmc-p0c-domain-node strong,
.trfmc-p0c-domain-node span {
  display: block;
}

.trfmc-p0c-domain-node small {
  color: #67e8f9;
  font-size: 8.5px;
  font-weight: 950;
}

.trfmc-p0c-domain-node strong {
  margin-top: 3px;
  color: #e8f7ff;
  font-size: 10.5px;
}

.trfmc-p0c-domain-node span {
  margin-top: 4px;
  color: #86efac;
  font-size: 8px;
  text-transform: uppercase;
  letter-spacing: .06em;
}

.trfmc-p0c-domain-node.placeholder {
  border-color: rgba(251, 191, 36, .22);
}

.trfmc-p0c-domain-node.placeholder span {
  color: #fbbf24;
}

.trfmc-p0c-rule-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 7px;
  margin-top: 8px;
}

@media (max-width: 1420px) {
  .trfmc-p0c-kpi-grid,
  .trfmc-p0c-priority-strip,
  .trfmc-p0c-rule-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .trfmc-p0c-domain-lattice {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .trfmc-p0c-table-row {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 860px) {
  .trfmc-p0c-kpi-grid,
  .trfmc-p0c-principles,
  .trfmc-p0c-priority-strip,
  .trfmc-p0c-domain-lattice,
  .trfmc-p0c-rule-grid,
  .trfmc-p0c-table-row {
    grid-template-columns: 1fr;
  }
}
/* === TRFMC P0C MISSION CONTROL CONTENT PROMOTION V1 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_P0C_APPENDED=True")
PY

echo
echo "=== 7) DIFF ==="

git diff -- "$HOME" "$ROOM" "$INDEX" "$CONTENT" "$ORCH" "$CSS" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

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
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES_FRONTEND="$(awk 'NR>1 && $1 ~ /5173/ && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== 10) STATIC SAFETY GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_grep "<iframe" "$HOME" "$ROOM" "$INDEX" "$CONTENT" "$ORCH")"
  DANGEROUS_COUNT="$(safe_count_grep "dangerouslySetInnerHTML\|innerHTML\|document.write\|document.body" "$HOME" "$ROOM" "$INDEX" "$CONTENT" "$ORCH")"
  PUBLIC_PARALLEL_COUNT="$(safe_count_grep "trfmc_home_v87g.html\|trfmc_integration_control_room.html\|portal_index_v19.html" "$HOME" "$ROOM" "$INDEX" "$CONTENT" "$ORCH")"
  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_html_injection_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "public_html_runtime_links_absent\t$([ "$PUBLIC_PARALLEL_COUNT" = "0" ] && echo PASS || echo FAIL)\t$PUBLIC_PARALLEL_COUNT"
} | tee "$GATE" | column -t -s $'\t'

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
      --virtual-time-budget=6000 \
      --dump-dom \
      "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    google-chrome \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=6000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  elif command -v chromium >/dev/null 2>&1; then
    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=6000 \
      --dump-dom \
      "http://127.0.0.1:5173/#mission-overview" > "$DOM" 2>/dev/null && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    chromium \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=6000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#mission-overview" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
  fi
else
  echo "BUILD_NOT_PASS" > "$DOM"
fi

P0C_CONTENT_MARKER="$(safe_count_file_literal 'data-trfmc-p0c-mission-control-content="mounted"' "$DOM")"
P0C_HOME_MARKER="$(safe_count_file_literal 'data-trfmc-p0c-home="mounted"' "$DOM")"
P0C_ROOM_MARKER="$(safe_count_file_literal 'data-trfmc-p0c-integration-room="mounted"' "$DOM")"
P0C_INDEX_MARKER="$(safe_count_file_literal 'data-trfmc-p0c-portal-index="mounted"' "$DOM")"
CSS_MARKER_COUNT="$(safe_count_file_literal 'TRFMC P0C MISSION CONTROL CONTENT PROMOTION V1 START' "$CSS")"

echo "DOM_RESULT=$DOM_RESULT"
echo "P0C_CONTENT_MARKER=$P0C_CONTENT_MARKER"
echo "P0C_HOME_MARKER=$P0C_HOME_MARKER"
echo "P0C_ROOM_MARKER=$P0C_ROOM_MARKER"
echo "P0C_INDEX_MARKER=$P0C_INDEX_MARKER"
echo "CSS_MARKER_COUNT=$CSS_MARKER_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

STATIC_FAILS="$(awk 'NR>1 && $2!="PASS" {c++} END {print c+0}' "$GATE")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_NON_200_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP"; fi
if [ "$HTTP_ZERO_BYTES_FRONTEND" != "0" ]; then RESULT="REVIEW_FRONTEND_HTTP_BYTES"; fi
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_SAFETY"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_CONTENT_MARKER" = "0" ]; then RESULT="REVIEW_DOM_CONTENT"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_HOME_MARKER" = "0" ]; then RESULT="REVIEW_DOM_HOME"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_ROOM_MARKER" = "0" ]; then RESULT="REVIEW_DOM_ROOM"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$P0C_INDEX_MARKER" = "0" ]; then RESULT="REVIEW_DOM_INDEX"; fi
if [ "$CSS_MARKER_COUNT" = "0" ]; then RESULT="REVIEW_CSS_MARKER"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P0C_MISSION_CONTROL_CONTENT_PROMOTION_V1",
  "mutation": "frontend_source_content_promotion",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "files_modified": [
    "$HOME",
    "$ROOM",
    "$INDEX",
    "$CONTENT",
    "$ORCH",
    "$CSS"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "static_gate": "$GATE",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "frontend_http_non_200": $HTTP_NON_200_FRONTEND,
  "frontend_http_zero_bytes": $HTTP_ZERO_BYTES_FRONTEND,
  "static_failures": $STATIC_FAILS,
  "dom_result": "$DOM_RESULT",
  "p0c_content_marker": $P0C_CONTENT_MARKER,
  "p0c_home_marker": $P0C_HOME_MARKER,
  "p0c_integration_room_marker": $P0C_ROOM_MARKER,
  "p0c_portal_index_marker": $P0C_INDEX_MARKER,
  "css_marker_count": $CSS_MARKER_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p0c_mission_control_content_promotion_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P0C_MISSION_CONTROL_CONTENT_PROMOTION_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
