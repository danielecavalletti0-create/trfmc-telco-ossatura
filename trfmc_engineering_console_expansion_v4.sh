#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ENGINEERING_CONSOLE_EXPANSION_V4_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"

MAIN="$BASE/frontend/src/app/main.tsx"
CSS="$BASE/frontend/src/styles.css"
COMP="$BASE/frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_engineering_console_expansion_v4.log"
HTTP="$OUT/http.tsv"
DIFF="$OUT/engineering_console_expansion_v4.diff"
RESTORE="$OUT/RESTORE_ENGINEERING_CONSOLE_EXPANSION_V4.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_ENGINEERING_CONSOLE_EXPANSION_V4"
echo "Engineering content expansion · source-only React component"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$MAIN" ] || [ ! -f "$CSS" ]; then
  echo "ERRORE: main.tsx o styles.css non trovato"
  exit 1
fi

cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

if [ -f "$COMP" ]; then
  cp -a "$COMP" "$BACKUP/EngineeringConsoleExpansionV4.tsx.before_$TS"
fi

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
if [ -f "$BACKUP/EngineeringConsoleExpansionV4.tsx.before_$TS" ]; then
  cp -a "$BACKUP/EngineeringConsoleExpansionV4.tsx.before_$TS" "$COMP"
else
  rm -f "$COMP"
fi
echo "RESTORE_ENGINEERING_CONSOLE_EXPANSION_V4 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) CREA COMPONENTE REACT V4 ==="

cat > "$COMP" <<'TSX'
const contractRows = [
  { label: 'Frontend route', value: '127.0.0.1:5173', state: 'PASS' },
  { label: 'Bridge API', value: '127.0.0.1:4181', state: 'PASS' },
  { label: 'Backend API', value: '127.0.0.1:8000', state: 'PASS' },
  { label: 'Runtime mode', value: 'readonly / no backend mutation', state: 'LOCKED' },
]

const domains = [
  { id: '01', title: 'Mission Control', status: 'baseline', focus: 'operator state, readiness, evidence' },
  { id: '02', title: 'RF Physics', status: 'to promote', focus: 'Maxwell, FFT, I/Q, dB, SNR, EVM' },
  { id: '03', title: 'Signal Analyzer', status: 'to promote', focus: 'spectrum, waterfall, IQ, constellation' },
  { id: '04', title: 'RF / Microwave', status: 'to promote', focus: 'Smith chart, link budget, waveguide, filters' },
  { id: '05', title: 'Antenna System', status: 'to promote', focus: 'array, pattern, gain, RET/AISG, CPRI mapping' },
  { id: '06', title: 'Fiber Optic', status: 'to promote', focus: 'OTDR, ODF, attenuation, splice loss' },
  { id: '07', title: '5G Core / RAN', status: 'critical', focus: 'Open5GS, UERANSIM, NAS, NGAP, PFCP, GTP-U' },
  { id: '08', title: 'Cyber RF Intelligence', status: 'locked', focus: 'evidence, restricted areas, safe readonly workflows' },
]

const matrix = [
  ['Theory', 'partial', 'RF/Telco formulas must be indexed per module'],
  ['Simulator', 'partial', 'visual engines must bind to operational scenarios'],
  ['Endpoint', 'partial', '4181/8000 contracts must be mapped per module'],
  ['Visual Asset', 'review', 'promote real interactive assets, archive duplicates'],
  ['Scenario', 'review', 'scenario cards must drive evidence and QA'],
  ['QA Gate', 'active', 'build, HTTP, screenshot gate already present'],
]

const qa = [
  { k: 'Build', v: 'PASS' },
  { k: 'HTTP', v: '0 non-200' },
  { k: 'Screenshot', v: 'PASS' },
  { k: 'V51 residues', v: 'quarantined' },
  { k: 'Runtime injection', v: 'none' },
  { k: 'Source mode', v: 'React/Vite' },
]

export function EngineeringConsoleExpansionV4() {
  return (
    <section className="trfmc-eng-v4" aria-label="TRFMC Engineering Console Expansion">
      <div className="trfmc-eng-v4-top">
        <div>
          <p className="trfmc-eng-v4-kicker">TRFMC V4 · Engineering Console Expansion</p>
          <h2>Completion cockpit: domini, contratti, QA, promozione moduli</h2>
          <p>
            Questa sezione trasforma la vista Engineering da semplice scheda V49 a console di governo:
            ogni dominio deve convergere su teoria, simulatore, endpoint, asset, scenario e collaudo.
          </p>
        </div>
        <div className="trfmc-eng-v4-score">
          <strong>12</strong>
          <span>target domains</span>
        </div>
      </div>

      <div className="trfmc-eng-v4-grid trfmc-eng-v4-grid-contracts">
        {contractRows.map((row) => (
          <article className="trfmc-eng-v4-card trfmc-eng-v4-contract" key={row.label}>
            <span>{row.label}</span>
            <strong>{row.value}</strong>
            <em data-state={row.state}>{row.state}</em>
          </article>
        ))}
      </div>

      <div className="trfmc-eng-v4-split">
        <section className="trfmc-eng-v4-panel">
          <div className="trfmc-eng-v4-panel-head">
            <span>Domain promotion board</span>
            <b>React source of truth</b>
          </div>
          <div className="trfmc-eng-v4-domain-grid">
            {domains.map((domain) => (
              <article className="trfmc-eng-v4-domain" key={domain.id}>
                <div>
                  <span>{domain.id}</span>
                  <h3>{domain.title}</h3>
                </div>
                <em data-status={domain.status}>{domain.status}</em>
                <p>{domain.focus}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="trfmc-eng-v4-panel">
          <div className="trfmc-eng-v4-panel-head">
            <span>Engineering completeness matrix</span>
            <b>module acceptance rule</b>
          </div>
          <div className="trfmc-eng-v4-matrix">
            {matrix.map(([name, state, note]) => (
              <div className="trfmc-eng-v4-matrix-row" key={name}>
                <strong>{name}</strong>
                <em data-state={state}>{state}</em>
                <span>{note}</span>
              </div>
            ))}
          </div>
        </section>
      </div>

      <section className="trfmc-eng-v4-panel trfmc-eng-v4-qa">
        <div className="trfmc-eng-v4-panel-head">
          <span>Evidence and quality strip</span>
          <b>current baseline: Engineering Only V3</b>
        </div>
        <div className="trfmc-eng-v4-qa-grid">
          {qa.map((item) => (
            <div className="trfmc-eng-v4-qa-item" key={item.k}>
              <span>{item.k}</span>
              <strong>{item.v}</strong>
            </div>
          ))}
        </div>
      </section>
    </section>
  )
}
TSX

echo
echo "=== 2) PATCH main.tsx: monta componente solo in Engineering-only ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import sys

main = Path(sys.argv[1])
text = main.read_text(encoding="utf-8", errors="replace")
before = text

import_line = "import { EngineeringConsoleExpansionV4 } from '../layout_orchestrator/EngineeringConsoleExpansionV4'"
if import_line not in text:
    anchor = "import { MissionLayoutOrchestratorV42 } from '../layout_orchestrator/MissionLayoutOrchestratorV42'"
    if anchor not in text:
        raise SystemExit("ERRORE: import MissionLayoutOrchestratorV42 non trovato")
    text = text.replace(anchor, anchor + "\n" + import_line, 1)

if "<EngineeringConsoleExpansionV4 />" not in text:
    anchor = "<MissionLayoutOrchestratorV42 />"
    if anchor not in text:
      raise SystemExit("ERRORE: MissionLayoutOrchestratorV42 render non trovato")
    text = text.replace(anchor, anchor + "\n        <EngineeringConsoleExpansionV4 />", 1)

main.write_text(text, encoding="utf-8")
print("MAIN_CHANGED=", before != text)
PY

echo
echo "=== 3) PATCH styles.css: styling sorgente V4 ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC ENGINEERING CONSOLE EXPANSION V4 START === \*/.*?/\* === TRFMC ENGINEERING CONSOLE EXPANSION V4 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC ENGINEERING CONSOLE EXPANSION V4 START === */
/*
  Source-only content expansion for #full-engineering-stack.
  This is not a runtime patch and not a public asset layer.
*/

.trfmc-eng-v4 {
  margin-top: 12px;
  border: 1px solid rgba(103, 232, 249, .18);
  border-radius: 14px;
  background:
    radial-gradient(circle at 12% 0%, rgba(57,215,255,.07), transparent 35%),
    linear-gradient(180deg, rgba(5,16,31,.64), rgba(2,8,17,.78));
  padding: 12px;
}

.trfmc-eng-v4-top {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 112px;
  gap: 12px;
  align-items: stretch;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(103, 232, 249, .14);
}

.trfmc-eng-v4-kicker {
  margin: 0 0 4px 0;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.trfmc-eng-v4 h2 {
  margin: 0 0 5px 0;
  font-size: clamp(18px, 1.05vw, 23px);
  line-height: 1.05;
  letter-spacing: -.025em;
}

.trfmc-eng-v4 p {
  margin: 0;
  color: #a9c6d8;
  font-size: 12px;
  line-height: 1.38;
}

.trfmc-eng-v4-score {
  display: grid;
  place-items: center;
  border: 1px solid rgba(134,239,172,.24);
  border-radius: 12px;
  background: rgba(8, 47, 38, .30);
}

.trfmc-eng-v4-score strong {
  color: #86efac;
  font-size: 28px;
  line-height: 1;
}

.trfmc-eng-v4-score span {
  color: #9fb8ca;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-eng-v4-grid {
  display: grid;
  gap: 9px;
}

.trfmc-eng-v4-grid-contracts {
  grid-template-columns: repeat(4, minmax(0, 1fr));
  margin-top: 10px;
}

.trfmc-eng-v4-card,
.trfmc-eng-v4-panel,
.trfmc-eng-v4-domain,
.trfmc-eng-v4-qa-item {
  border: 1px solid rgba(103,232,249,.14);
  border-radius: 11px;
  background: rgba(2, 10, 20, .42);
}

.trfmc-eng-v4-contract {
  padding: 9px 10px;
  min-width: 0;
}

.trfmc-eng-v4-contract span,
.trfmc-eng-v4-qa-item span {
  display: block;
  color: #67e8f9;
  font-size: 10px;
  font-weight: 850;
  letter-spacing: .10em;
  text-transform: uppercase;
  margin-bottom: 5px;
}

.trfmc-eng-v4-contract strong,
.trfmc-eng-v4-qa-item strong {
  display: block;
  color: #e8f7ff;
  font-size: 12px;
  overflow-wrap: anywhere;
}

.trfmc-eng-v4-contract em,
.trfmc-eng-v4-domain em,
.trfmc-eng-v4-matrix-row em {
  display: inline-flex;
  width: fit-content;
  margin-top: 6px;
  padding: 3px 7px;
  border-radius: 999px;
  font-style: normal;
  font-size: 9px;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: #86efac;
  background: rgba(22, 101, 52, .22);
  border: 1px solid rgba(134,239,172,.24);
}

.trfmc-eng-v4-split {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(320px, .65fr);
  gap: 10px;
  margin-top: 10px;
}

.trfmc-eng-v4-panel {
  padding: 10px;
}

.trfmc-eng-v4-panel-head {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  align-items: center;
  margin-bottom: 9px;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(103,232,249,.12);
}

.trfmc-eng-v4-panel-head span {
  color: #67e8f9;
  font-size: 11px;
  font-weight: 900;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.trfmc-eng-v4-panel-head b {
  color: #86efac;
  font-size: 10px;
  font-weight: 850;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-eng-v4-domain-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.trfmc-eng-v4-domain {
  padding: 9px;
}

.trfmc-eng-v4-domain > div {
  display: flex;
  align-items: baseline;
  gap: 7px;
}

.trfmc-eng-v4-domain div span {
  color: #86efac;
  font-size: 11px;
  font-weight: 950;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}

.trfmc-eng-v4-domain h3 {
  margin: 0;
  font-size: 13px;
  line-height: 1.1;
}

.trfmc-eng-v4-domain p {
  margin-top: 6px;
  font-size: 11px;
  line-height: 1.32;
}

.trfmc-eng-v4-domain em[data-status="critical"] {
  color: #fbbf24;
  border-color: rgba(251,191,36,.30);
  background: rgba(120,53,15,.20);
}

.trfmc-eng-v4-domain em[data-status="locked"] {
  color: #fca5a5;
  border-color: rgba(248,113,113,.30);
  background: rgba(127,29,29,.20);
}

.trfmc-eng-v4-matrix {
  display: grid;
  gap: 7px;
}

.trfmc-eng-v4-matrix-row {
  display: grid;
  grid-template-columns: 88px 72px minmax(0, 1fr);
  gap: 8px;
  align-items: center;
  padding: 7px 8px;
  border: 1px solid rgba(103,232,249,.12);
  border-radius: 9px;
  background: rgba(2, 10, 20, .35);
}

.trfmc-eng-v4-matrix-row strong {
  font-size: 11px;
  color: #e8f7ff;
}

.trfmc-eng-v4-matrix-row em {
  margin-top: 0;
  justify-self: start;
}

.trfmc-eng-v4-matrix-row span {
  color: #a9c6d8;
  font-size: 11px;
  line-height: 1.25;
}

.trfmc-eng-v4-qa {
  margin-top: 10px;
}

.trfmc-eng-v4-qa-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 8px;
}

.trfmc-eng-v4-qa-item {
  padding: 8px 9px;
}

@media (max-width: 1200px) {
  .trfmc-eng-v4-grid-contracts,
  .trfmc-eng-v4-domain-grid,
  .trfmc-eng-v4-qa-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .trfmc-eng-v4-split {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .trfmc-eng-v4-top,
  .trfmc-eng-v4-grid-contracts,
  .trfmc-eng-v4-domain-grid,
  .trfmc-eng-v4-qa-grid,
  .trfmc-eng-v4-matrix-row {
    grid-template-columns: 1fr;
  }
}
/* === TRFMC ENGINEERING CONSOLE EXPANSION V4 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_V4_APPENDED=True")
PY

echo
echo "=== 4) DIFF ==="
git diff -- frontend/src/app/main.tsx frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx frontend/src/styles.css > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 5) BUILD ==="
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
echo "=== 6) HTTP GATE ==="
cat > "$HTTP" <<HTTPHDR
url	status	bytes
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 5 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  rm -f "$tmp"
  printf "%s\t%s\t%s\n" "$url" "$code" "$bytes" | tee -a "$HTTP"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_ENGINEERING_CONSOLE_EXPANSION_V4",
  "mutation": "source_react_component",
  "runtime_injection": false,
  "public_asset_mutation": false,
  "index_mutation": false,
  "backend_mutation": false,
  "files_modified": [
    "frontend/src/app/main.tsx",
    "frontend/src/layout_orchestrator/EngineeringConsoleExpansionV4.tsx",
    "frontend/src/styles.css"
  ],
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_engineering_console_expansion_v4"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_ENGINEERING_CONSOLE_EXPANSION_V4 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
