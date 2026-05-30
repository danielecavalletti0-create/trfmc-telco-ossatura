#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_SOURCE_REFACTOR_ENGINEERING_ONLY_V3_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"

MAIN="$BASE/frontend/src/app/main.tsx"
CSS="$BASE/frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_engineering_only_v3.log"
HTTP="$OUT/http.tsv"
DIFF="$OUT/engineering_only_v3.diff"
RESTORE="$OUT/RESTORE_ENGINEERING_ONLY_V3.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_SOURCE_REFACTOR_ENGINEERING_ONLY_V3"
echo "Engineering-only route rendering · no two-portals page"
echo "Timestamp: $TS"
echo "============================================================"

cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
echo "RESTORE_ENGINEERING_ONLY_V3 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH main.tsx: return dedicato per Engineering Focus ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import re
import sys

main = Path(sys.argv[1])
text = main.read_text(encoding="utf-8", errors="replace")
before = text

if "mc-shell-engineering-only" not in text:
    # Inserisce un early return subito prima del return principale.
    pattern = r"(\n\s*return\s*\(\s*\n\s*<main className=\{`mc-shell \$\{trfmcEngineeringFocus \? \"mc-shell-engineering-focus\" : \"\"\}`\}>)"
    replacement = r'''
  if (trfmcEngineeringFocus) {
    return (
      <main className="mc-shell mc-shell-engineering-focus mc-shell-engineering-only">
        <MissionLayoutOrchestratorV42 />
      </main>
    )
  }
\1'''
    text, n = re.subn(pattern, replacement, text, count=1)

    if n == 0:
        raise SystemExit("ERRORE: punto di inserimento early-return non trovato in main.tsx")

main.write_text(text, encoding="utf-8")
print("MAIN_CHANGED=", before != text)
PY

echo
echo "=== 2) PATCH styles.css: engineering-only true console ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC ENGINEERING ONLY V3 START === \*/.*?/\* === TRFMC ENGINEERING ONLY V3 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC ENGINEERING ONLY V3 START === */
/*
  Engineering-only page:
  - no TELCO RF header above it;
  - no normal Mission Control dashboard;
  - no Mission Overview duplicated before V49;
  - V49 becomes the primary engineering page.
*/

.mc-shell-engineering-only {
  width: min(1360px, calc(100vw - 96px)) !important;
  max-width: min(1360px, calc(100vw - 96px)) !important;
  min-height: auto !important;
  margin: 22px auto 44px auto !important;
  padding: 14px !important;
  border-radius: 20px !important;
  background:
    radial-gradient(circle at 20% 0%, rgba(57,215,255,.08), transparent 32%),
    linear-gradient(180deg, rgba(3,12,24,.96), rgba(1,6,13,.98)) !important;
}

/* In engineering-only, the orchestrator shell is the page, not a child portal */
.mc-shell-engineering-only .v42-orchestrator-shell {
  margin: 0 !important;
  border-radius: 16px !important;
  border: 1px solid rgba(103,232,249,.18) !important;
  background: rgba(2,9,18,.72) !important;
  box-shadow: none !important;
}

/* Compact engineering title bar */
.mc-shell-engineering-only .v42-orchestrator-header {
  padding: 10px 12px !important;
  border-bottom: 1px solid rgba(103,232,249,.14) !important;
  background: linear-gradient(90deg, rgba(57,215,255,.055), transparent 58%) !important;
}

.mc-shell-engineering-only .v42-orchestrator-header h1,
.mc-shell-engineering-only .v42-orchestrator-header h2 {
  font-size: clamp(18px, 1vw, 22px) !important;
  line-height: 1.05 !important;
  letter-spacing: -.02em !important;
}

.mc-shell-engineering-only .v42-orchestrator-header p {
  font-size: 11px !important;
  margin-top: 4px !important;
}

.mc-shell-engineering-only .v42-orchestrator-score {
  transform: scale(.82) !important;
  transform-origin: right center !important;
}

/* Engineering stack route: hide non-primary Mission Overview/stage content */
.mc-shell-engineering-only .v42-section-rail,
.mc-shell-engineering-only .v42-section-stage,
.mc-shell-engineering-only .v42-compact-overview,
.mc-shell-engineering-only .v42-flow,
.mc-shell-engineering-only .v42-executive-note,
.mc-shell-engineering-only .v46-deeplink-index {
  display: none !important;
}

/* V42 layout becomes simple single-column container around V49 */
.mc-shell-engineering-only .v42-layout,
.mc-shell-engineering-only .trfmc-native-orchestrator-layout {
  display: block !important;
  padding: 10px !important;
}

/* V49 as primary content */
.mc-shell-engineering-only .v49-engineering-enrichment {
  display: block !important;
  margin: 0 !important;
  padding: 12px !important;
  border-radius: 14px !important;
  border: 1px solid rgba(103,232,249,.18) !important;
  background:
    linear-gradient(180deg, rgba(5,16,31,.60), rgba(2,8,17,.72)) !important;
  box-shadow: none !important;
}

.mc-shell-engineering-only .v49-section-machine-marker {
  font-size: 10px !important;
  padding: 4px 8px !important;
  margin-bottom: 8px !important;
}

.mc-shell-engineering-only .v49-enrichment-header {
  padding-bottom: 8px !important;
  margin-bottom: 10px !important;
}

.mc-shell-engineering-only .v49-enrichment-header h1,
.mc-shell-engineering-only .v49-enrichment-header h2,
.mc-shell-engineering-only .v49-engineering-enrichment h1,
.mc-shell-engineering-only .v49-engineering-enrichment h2 {
  font-size: clamp(18px, 1.05vw, 23px) !important;
  line-height: 1.06 !important;
  margin: 0 0 5px 0 !important;
}

.mc-shell-engineering-only .v49-enrichment-header p,
.mc-shell-engineering-only .v49-engineering-enrichment p {
  font-size: 12px !important;
  line-height: 1.38 !important;
}

.mc-shell-engineering-only .v49-enrichment-grid {
  grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
  gap: 9px !important;
}

.mc-shell-engineering-only .v49-enrichment-card,
.mc-shell-engineering-only .v49-kpi-card {
  padding: 9px 10px !important;
  min-height: 0 !important;
  border-radius: 11px !important;
}

.mc-shell-engineering-only .v49-enrichment-card h3,
.mc-shell-engineering-only .v49-kpi-card h3 {
  font-size: 13px !important;
  margin-bottom: 5px !important;
}

.mc-shell-engineering-only .v49-chip-list,
.mc-shell-engineering-only .v49-operator-actions {
  gap: 5px !important;
}

.mc-shell-engineering-only .v49-chip-list > *,
.mc-shell-engineering-only .v49-operator-actions > * {
  font-size: 10px !important;
  padding: 4px 7px !important;
  border-radius: 999px !important;
}

/* Global compact clamp for this route */
.mc-shell-engineering-only h1 {
  font-size: clamp(20px, 1.15vw, 24px) !important;
}

.mc-shell-engineering-only h2 {
  font-size: clamp(17px, .95vw, 21px) !important;
}

.mc-shell-engineering-only h3 {
  font-size: clamp(13px, .78vw, 16px) !important;
}

.mc-shell-engineering-only p,
.mc-shell-engineering-only li,
.mc-shell-engineering-only dd,
.mc-shell-engineering-only td,
.mc-shell-engineering-only th {
  font-size: 12px !important;
  line-height: 1.38 !important;
}

/* Responsive */
@media (max-width: 1100px) {
  .mc-shell-engineering-only {
    width: calc(100vw - 24px) !important;
    max-width: calc(100vw - 24px) !important;
  }

  .mc-shell-engineering-only .v49-enrichment-grid {
    grid-template-columns: 1fr !important;
  }
}
/* === TRFMC ENGINEERING ONLY V3 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_ENGINEERING_ONLY_V3_APPENDED=True")
PY

echo
echo "=== 3) DIFF ==="
git diff -- frontend/src/app/main.tsx frontend/src/styles.css > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 4) BUILD ==="
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
echo "=== 5) HTTP GATE ==="
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
  "operation": "TRFMC_SOURCE_REFACTOR_ENGINEERING_ONLY_V3",
  "mutation": "source_refactor",
  "runtime_injection": false,
  "public_asset_mutation": false,
  "index_mutation": false,
  "backend_mutation": false,
  "files_modified": [
    "frontend/src/app/main.tsx",
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

ln -sfn "$OUT" "$BASE/runtime/quality/latest_source_refactor_engineering_only_v3"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_SOURCE_REFACTOR_ENGINEERING_ONLY_V3 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
