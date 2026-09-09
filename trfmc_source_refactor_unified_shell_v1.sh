#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_SOURCE_REFACTOR_UNIFIED_SHELL_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"

V42="$BASE/frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
V49="$BASE/frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx"
CSS="$BASE/frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_source_refactor_v1.log"
HTTP="$OUT/http.tsv"
DIFF="$OUT/source_refactor_v1.diff"
RESTORE="$OUT/RESTORE_SOURCE_REFACTOR_V1.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_SOURCE_REFACTOR_UNIFIED_SHELL_V1"
echo "Source-level React/CSS refactor · no runtime injection"
echo "Timestamp: $TS"
echo "============================================================"

for f in "$V42" "$V49" "$CSS"; do
  if [ ! -f "$f" ]; then
    echo "ERRORE: file mancante: $f"
    exit 1
  fi
done

echo
echo "=== 1) BACKUP FILE SORGENTE ==="

cp -a "$V42" "$BACKUP/MissionLayoutOrchestratorV42.tsx.before_$TS"
cp -a "$V49" "$BACKUP/EngineeringContentEnrichmentV49.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$BASE"
cp -a "$BACKUP/MissionLayoutOrchestratorV42.tsx.before_$TS" "\$BASE/frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
cp -a "$BACKUP/EngineeringContentEnrichmentV49.tsx.before_$TS" "\$BASE/frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx"
cp -a "$BACKUP/styles.css.before_$TS" "\$BASE/frontend/src/styles.css"
echo "RESTORE_SOURCE_REFACTOR_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo "Restore script: $RESTORE"

echo
echo "=== 2) PATCH SORGENTE TSX MINIMA ==="

python3 - "$V42" "$V49" <<'PY'
from pathlib import Path
import sys
import re

v42 = Path(sys.argv[1])
v49 = Path(sys.argv[2])

text = v42.read_text(encoding="utf-8", errors="replace")
before = text

# Rende il blocco V42 una sezione nativa, non un secondo portale.
text = text.replace(
    'className="v42-orchestrator-shell"',
    'className="v42-orchestrator-shell trfmc-native-orchestrator-shell"'
)

text = text.replace(
    'className="v42-orchestrator-header"',
    'className="v42-orchestrator-header trfmc-native-orchestrator-header"'
)

text = text.replace(
    'className="v42-layout"',
    'className="v42-layout trfmc-native-orchestrator-layout"'
)

text = text.replace(
    'className="v42-section-rail"',
    'className="v42-section-rail trfmc-native-section-rail"'
)

text = text.replace(
    'className="v42-section-stage"',
    'className="v42-section-stage trfmc-native-section-stage"'
)

# Riduce il secondo titolo da "home page" a titolo tecnico di sottosistema.
text = text.replace(
    'TRFMC Mission Control Layout',
    'Engineering Orchestrator'
)

# Non elimina contenuti, ma cambia la gerarchia percettiva.
text = text.replace(
    'Mission layout objective',
    'Integration objective'
)

v42.write_text(text, encoding="utf-8")
print("V42_CHANGED=", before != text)

text = v49.read_text(encoding="utf-8", errors="replace")
before = text

text = text.replace(
    'className="v49-engineering-enrichment"',
    'className="v49-engineering-enrichment trfmc-native-engineering-enrichment"'
)

text = text.replace(
    'className="v49-enrichment-header"',
    'className="v49-enrichment-header trfmc-native-enrichment-header"'
)

text = text.replace(
    'className="v49-enrichment-grid"',
    'className="v49-enrichment-grid trfmc-native-enrichment-grid"'
)

v49.write_text(text, encoding="utf-8")
print("V49_CHANGED=", before != text)
PY

echo
echo "=== 3) PATCH SORGENTE CSS UFFICIALE ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import sys
import re

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

# Idempotenza: rimuove eventuale sezione precedente dello stesso refactor.
text = re.sub(
    r"\n/\* === TRFMC SOURCE REFACTOR UNIFIED SHELL V1 START === \*/.*?/\* === TRFMC SOURCE REFACTOR UNIFIED SHELL V1 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC SOURCE REFACTOR UNIFIED SHELL V1 START === */
/*
  Source-level layout correction.
  Scope:
  - no public asset injection;
  - no index.html runtime patch;
  - integrate V42/V49 as native mission-control sections;
  - prevent "two portals in one page" visual split.
*/

:root {
  --trfmc-source-shell-max: 1560px;
  --trfmc-source-shell-pad: clamp(18px, 2vw, 32px);
  --trfmc-source-gap: clamp(14px, 1.15vw, 20px);
  --trfmc-source-sidebar: clamp(238px, 17vw, 284px);
  --trfmc-source-radius-xl: 26px;
  --trfmc-source-radius-lg: 18px;
  --trfmc-source-border: rgba(103, 232, 249, .24);
  --trfmc-source-border-soft: rgba(103, 232, 249, .14);
  --trfmc-source-bg: rgba(3, 12, 24, .92);
  --trfmc-source-panel: rgba(5, 16, 31, .78);
  --trfmc-source-panel-soft: rgba(5, 16, 31, .54);
  --trfmc-source-cyan: #67e8f9;
  --trfmc-source-muted: #9fb8ca;
}

/* Plancia principale: dimensione controllata, non miniaturizzata e non esplosa */
.mc-shell {
  width: min(var(--trfmc-source-shell-max), calc(100vw - 56px));
  max-width: min(var(--trfmc-source-shell-max), calc(100vw - 56px));
  margin: 20px auto 48px auto;
  padding: var(--trfmc-source-shell-pad);
  border-radius: var(--trfmc-source-radius-xl);
  border: 1px solid var(--trfmc-source-border);
  background:
    radial-gradient(circle at 18% 0%, rgba(103, 232, 249, .12), transparent 34%),
    radial-gradient(circle at 86% 12%, rgba(134, 239, 172, .06), transparent 34%),
    linear-gradient(180deg, rgba(3, 12, 24, .96), rgba(2, 8, 17, .98));
  box-shadow:
    0 32px 90px rgba(0, 0, 0, .42),
    inset 0 0 70px rgba(103, 232, 249, .035);
}

/* Header missione: resta il vero titolo del portale */
.mc-header {
  margin-bottom: 14px;
  border-radius: calc(var(--trfmc-source-radius-xl) - 6px);
}

.mc-layout {
  gap: var(--trfmc-source-gap);
  grid-template-columns: var(--trfmc-source-sidebar) minmax(0, 1fr);
}

.mc-sidebar {
  width: var(--trfmc-source-sidebar);
  max-width: var(--trfmc-source-sidebar);
  min-width: 0;
}

.mc-content {
  min-width: 0;
}

.mc-footer {
  margin-top: 16px;
}

/* V42: da secondo portale a sezione tecnica nativa della stessa plancia */
.trfmc-native-orchestrator-shell,
.v42-orchestrator-shell {
  width: 100%;
  max-width: 100%;
  margin: 16px 0 0 0;
  padding: 0;
  border-radius: calc(var(--trfmc-source-radius-xl) - 8px);
  border: 1px solid var(--trfmc-source-border-soft);
  background:
    linear-gradient(180deg, rgba(5, 16, 31, .64), rgba(2, 8, 17, .78));
  box-shadow: none;
  overflow: hidden;
}

/* Il V42 non deve aprire una seconda homepage */
.trfmc-native-orchestrator-header,
.v42-orchestrator-header {
  padding: 16px 18px;
  border-bottom: 1px solid var(--trfmc-source-border-soft);
  background:
    linear-gradient(90deg, rgba(103, 232, 249, .08), transparent 58%);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
}

.trfmc-native-orchestrator-header h1,
.trfmc-native-orchestrator-header h2,
.v42-orchestrator-header h1,
.v42-orchestrator-header h2 {
  font-size: clamp(22px, 1.55vw, 32px);
  line-height: 1.04;
  letter-spacing: -.035em;
  margin: 0;
}

.trfmc-native-orchestrator-header p,
.v42-orchestrator-header p {
  max-width: 880px;
  margin: 6px 0 0 0;
  color: var(--trfmc-source-muted);
  font-size: clamp(12px, .78vw, 14px);
  line-height: 1.45;
}

/* Layout interno V42 coerente con Mission Control */
.trfmc-native-orchestrator-layout,
.v42-layout {
  display: grid;
  grid-template-columns: minmax(220px, 272px) minmax(0, 1fr);
  gap: var(--trfmc-source-gap);
  padding: 16px;
  align-items: start;
}

.trfmc-native-section-rail,
.v42-section-rail {
  width: 100%;
  min-width: 0;
  border-radius: var(--trfmc-source-radius-lg);
  border: 1px solid var(--trfmc-source-border-soft);
  background: rgba(2, 10, 20, .42);
  padding: 10px;
  position: sticky;
  top: 14px;
  max-height: calc(100vh - 120px);
  overflow: auto;
}

.v42-section-rail button,
.v42-section-rail a,
.v46-deeplink-index a,
.v46-deeplink-index button {
  min-height: 34px;
  line-height: 1.18;
  border-radius: 10px;
  overflow-wrap: anywhere;
}

.trfmc-native-section-stage,
.v42-section-stage {
  min-width: 0;
  border-radius: var(--trfmc-source-radius-lg);
  border: 1px solid var(--trfmc-source-border-soft);
  background: rgba(2, 10, 20, .30);
  padding: 14px;
}

.v42-stage-heading {
  margin-bottom: 12px;
}

.v42-stage-heading h1,
.v42-stage-heading h2,
.v42-stage-heading h3 {
  font-size: clamp(20px, 1.35vw, 28px);
  line-height: 1.08;
  margin: 0 0 6px 0;
}

/* Deep-link index: diventa barra tecnica, non menu di un secondo sito */
.v46-deeplink-index {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: 12px 0 0 0;
  padding: 10px;
  border-radius: var(--trfmc-source-radius-lg);
  border: 1px solid var(--trfmc-source-border-soft);
  background: rgba(2, 10, 20, .26);
}

/* V49: contenuto engineering nativo dentro lo stage */
.trfmc-native-engineering-enrichment,
.v49-engineering-enrichment {
  margin-top: 14px;
  border-radius: var(--trfmc-source-radius-lg);
  border: 1px solid var(--trfmc-source-border-soft);
  background:
    linear-gradient(180deg, rgba(5, 16, 31, .54), rgba(2, 8, 17, .62));
  padding: 14px;
  box-shadow: none;
}

.trfmc-native-enrichment-header,
.v49-enrichment-header {
  margin-bottom: 12px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--trfmc-source-border-soft);
}

.trfmc-native-enrichment-header h1,
.trfmc-native-enrichment-header h2,
.trfmc-native-enrichment-header h3,
.v49-enrichment-header h1,
.v49-enrichment-header h2,
.v49-enrichment-header h3 {
  font-size: clamp(19px, 1.2vw, 25px);
  margin: 0 0 6px 0;
}

.trfmc-native-enrichment-grid,
.v49-enrichment-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr));
  gap: 12px;
}

.v49-enrichment-card,
.v49-kpi-card {
  border-radius: 14px;
  border-color: var(--trfmc-source-border-soft);
  background: rgba(5, 16, 31, .48);
}

/* Evita overflow e sensazione di portale spezzato */
.v42-orchestrator-shell *,
.v49-engineering-enrichment *,
.mc-shell * {
  box-sizing: border-box;
}

.v42-orchestrator-shell,
.v42-section-stage,
.v49-engineering-enrichment {
  min-width: 0;
}

/* Responsive pulito */
@media (max-width: 1100px) {
  .mc-shell {
    width: calc(100vw - 28px);
    max-width: calc(100vw - 28px);
    padding: 14px;
  }

  .mc-layout,
  .trfmc-native-orchestrator-layout,
  .v42-layout {
    grid-template-columns: 1fr;
  }

  .mc-sidebar,
  .trfmc-native-section-rail,
  .v42-section-rail {
    width: 100%;
    max-width: 100%;
    position: relative;
    top: auto;
    max-height: none;
  }

  .trfmc-native-orchestrator-header,
  .v42-orchestrator-header {
    flex-direction: column;
    align-items: flex-start;
  }
}

@media (max-width: 720px) {
  .mc-shell {
    width: calc(100vw - 18px);
    max-width: calc(100vw - 18px);
    margin-top: 8px;
  }

  .trfmc-native-orchestrator-layout,
  .v42-layout {
    padding: 10px;
  }
}
/* === TRFMC SOURCE REFACTOR UNIFIED SHELL V1 END === */
'''

text = text.rstrip() + "\n\n" + patch + "\n"
css.write_text(text, encoding="utf-8")
print("CSS_PATCH_APPENDED=True")
PY

echo
echo "=== 4) DIFF ==="
git diff -- frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx \
           frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx \
           frontend/src/styles.css > "$DIFF" || true

sed -n '1,220p' "$DIFF"

echo
echo "=== 5) BUILD VALIDATION ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "ERRORE: build fallita. Eseguo restore automatico."
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
check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_SOURCE_REFACTOR_UNIFIED_SHELL_V1",
  "mutation": "source_refactor",
  "runtime_injection": false,
  "public_asset_mutation": false,
  "index_mutation": false,
  "backend_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "backup": "$BACKUP",
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

ln -sfn "$OUT" "$BASE/runtime/quality/latest_source_refactor_unified_shell_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_SOURCE_REFACTOR_UNIFIED_SHELL_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
