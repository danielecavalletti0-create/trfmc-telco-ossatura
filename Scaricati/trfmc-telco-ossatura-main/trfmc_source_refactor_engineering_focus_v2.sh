#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_SOURCE_REFACTOR_ENGINEERING_FOCUS_V2_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"

MAIN="$BASE/frontend/src/app/main.tsx"
CSS="$BASE/frontend/src/styles.css"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_engineering_focus_v2.log"
HTTP="$OUT/http.tsv"
DIFF="$OUT/engineering_focus_v2.diff"
RESTORE="$OUT/RESTORE_ENGINEERING_FOCUS_V2.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_SOURCE_REFACTOR_ENGINEERING_FOCUS_V2"
echo "Hash-aware Engineering Focus · no runtime injection · source only"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$MAIN" ] || [ ! -f "$CSS" ]; then
  echo "ERRORE: main.tsx o styles.css non trovato"
  exit 1
fi

cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"
cp -a "$CSS" "$BACKUP/styles.css.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"
cp -a "$BACKUP/styles.css.before_$TS" "$CSS"
echo "RESTORE_ENGINEERING_FOCUS_V2 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) PATCH main.tsx: engineering focus hash-aware ==="

python3 - "$MAIN" <<'PY'
from pathlib import Path
import re
import sys

main = Path(sys.argv[1])
text = main.read_text(encoding="utf-8", errors="replace")
before = text

if "trfmcEngineeringFocus" not in text:
    text = text.replace(
        "function App() {",
        """function App() {
  const [trfmcActiveHash, setTrfmcActiveHash] = React.useState(() =>
    typeof window !== 'undefined' ? window.location.hash || '' : ''
  );

  React.useEffect(() => {
    if (typeof window === 'undefined') return;
    const syncHash = () => setTrfmcActiveHash(window.location.hash || '');
    syncHash();
    window.addEventListener('hashchange', syncHash);
    return () => window.removeEventListener('hashchange', syncHash);
  }, []);

  const trfmcEngineeringFocus =
    trfmcActiveHash === '#full-engineering-stack' ||
    trfmcActiveHash === '#full-engineering';
""",
        1
    )

# Trasforma la shell principale in hash-aware.
text = text.replace(
    '<main className="mc-shell">',
    '<main className={`mc-shell ${trfmcEngineeringFocus ? "mc-shell-engineering-focus" : ""}`}>',
    1
)

main.write_text(text, encoding="utf-8")

print("MAIN_CHANGED=", before != text)
PY

echo
echo "=== 2) PATCH styles.css: focus mode + scale down ==="

python3 - "$CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1])
text = css.read_text(encoding="utf-8", errors="replace")

text = re.sub(
    r"\n/\* === TRFMC ENGINEERING FOCUS V2 START === \*/.*?/\* === TRFMC ENGINEERING FOCUS V2 END === \*/\n?",
    "\n",
    text,
    flags=re.S,
)

patch = r'''
/* === TRFMC ENGINEERING FOCUS V2 START === */
/*
  Objective:
  - When hash is #full-engineering-stack, avoid rendering the page as two portals.
  - Hide the normal Mission Control dashboard blocks.
  - Keep a compact global header.
  - Show Engineering Orchestrator as the primary content.
  - Reduce oversized titles/widgets.
*/

.mc-shell-engineering-focus {
  width: min(1480px, calc(100vw - 72px)) !important;
  max-width: min(1480px, calc(100vw - 72px)) !important;
  padding: 18px !important;
}

/* In engineering mode, the mission dashboard is not shown above the orchestrator */
.mc-shell-engineering-focus > .mc-statusbar,
.mc-shell-engineering-focus > .mc-layout,
.mc-shell-engineering-focus > .mc-footer {
  display: none !important;
}

/* Compact portal header: it remains the single global identity */
.mc-shell-engineering-focus .mc-header {
  padding: 16px 20px !important;
  min-height: 0 !important;
  margin-bottom: 12px !important;
  border-radius: 18px !important;
}

.mc-shell-engineering-focus .mc-header h1 {
  font-size: clamp(28px, 2.05vw, 38px) !important;
  letter-spacing: .07em !important;
  line-height: 1 !important;
}

.mc-shell-engineering-focus .mc-header p {
  font-size: 13px !important;
  margin-top: 8px !important;
}

.mc-shell-engineering-focus .mc-header-status {
  min-width: 260px !important;
  max-width: 320px !important;
  gap: 8px !important;
}

.mc-shell-engineering-focus .mc-header-status > * {
  min-height: 32px !important;
  padding: 7px 10px !important;
  font-size: 12px !important;
}

/* Engineering orchestrator becomes the native main page, not a second portal */
.mc-shell-engineering-focus .v42-orchestrator-shell {
  margin-top: 12px !important;
  border-radius: 18px !important;
  background:
    linear-gradient(180deg, rgba(5,16,31,.68), rgba(2,8,17,.82)) !important;
}

.mc-shell-engineering-focus .v42-orchestrator-header {
  padding: 12px 14px !important;
  min-height: 0 !important;
}

.mc-shell-engineering-focus .v42-orchestrator-header h1,
.mc-shell-engineering-focus .v42-orchestrator-header h2 {
  font-size: clamp(18px, 1.18vw, 24px) !important;
  letter-spacing: -.025em !important;
}

.mc-shell-engineering-focus .v42-orchestrator-header p {
  font-size: 12px !important;
}

/* Smaller, denser technical widgets */
.mc-shell-engineering-focus .v42-layout {
  grid-template-columns: 240px minmax(0, 1fr) !important;
  gap: 12px !important;
  padding: 12px !important;
}

.mc-shell-engineering-focus .v42-section-rail {
  padding: 8px !important;
  border-radius: 14px !important;
}

.mc-shell-engineering-focus .v42-section-rail button {
  min-height: 32px !important;
  padding: 7px 9px !important;
  font-size: 12px !important;
}

.mc-shell-engineering-focus .v42-section-stage {
  padding: 12px !important;
  border-radius: 14px !important;
}

/* Overview / flow no longer look like huge widgets */
.mc-shell-engineering-focus .v42-compact-overview,
.mc-shell-engineering-focus .v42-flow,
.mc-shell-engineering-focus .v42-executive-note,
.mc-shell-engineering-focus .v46-deeplink-index {
  padding: 10px !important;
  margin-top: 10px !important;
  border-radius: 14px !important;
}

.mc-shell-engineering-focus .v42-compact-overview h2,
.mc-shell-engineering-focus .v42-compact-overview h3,
.mc-shell-engineering-focus .v42-executive-note h2,
.mc-shell-engineering-focus .v42-executive-note h3 {
  font-size: clamp(16px, .95vw, 20px) !important;
}

.mc-shell-engineering-focus .v42-overview-grid {
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)) !important;
  gap: 10px !important;
}

.mc-shell-engineering-focus .v42-flow {
  gap: 10px !important;
}

.mc-shell-engineering-focus .v42-flow > * {
  min-width: 96px !important;
  max-width: 146px !important;
  padding: 8px 10px !important;
}

/* V49 content: title and cards must be instrument-panel sized, not landing-page sized */
.mc-shell-engineering-focus .v49-engineering-enrichment {
  margin-top: 12px !important;
  padding: 12px !important;
  border-radius: 14px !important;
}

.mc-shell-engineering-focus .v49-enrichment-header h1,
.mc-shell-engineering-focus .v49-enrichment-header h2,
.mc-shell-engineering-focus .v49-enrichment-header h3,
.mc-shell-engineering-focus .v49-engineering-enrichment h1,
.mc-shell-engineering-focus .v49-engineering-enrichment h2 {
  font-size: clamp(18px, 1.15vw, 24px) !important;
  line-height: 1.08 !important;
}

.mc-shell-engineering-focus .v49-enrichment-header p,
.mc-shell-engineering-focus .v49-engineering-enrichment p {
  font-size: 13px !important;
  line-height: 1.42 !important;
}

.mc-shell-engineering-focus .v49-enrichment-grid {
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)) !important;
  gap: 10px !important;
}

.mc-shell-engineering-focus .v49-enrichment-card,
.mc-shell-engineering-focus .v49-kpi-card {
  padding: 10px 12px !important;
  border-radius: 12px !important;
  min-height: 0 !important;
}

.mc-shell-engineering-focus .v49-chip-list {
  gap: 6px !important;
}

.mc-shell-engineering-focus .v49-chip-list > *,
.mc-shell-engineering-focus .v49-operator-actions > * {
  font-size: 11px !important;
  padding: 5px 8px !important;
}

/* General heading clamp inside engineering focus */
.mc-shell-engineering-focus h1 {
  font-size: clamp(24px, 1.7vw, 34px) !important;
}

.mc-shell-engineering-focus h2 {
  font-size: clamp(18px, 1.2vw, 25px) !important;
}

.mc-shell-engineering-focus h3 {
  font-size: clamp(15px, .95vw, 20px) !important;
}

/* Responsive */
@media (max-width: 1100px) {
  .mc-shell-engineering-focus {
    width: calc(100vw - 24px) !important;
    max-width: calc(100vw - 24px) !important;
  }

  .mc-shell-engineering-focus .v42-layout {
    grid-template-columns: 1fr !important;
  }

  .mc-shell-engineering-focus .mc-header {
    flex-direction: column !important;
  }

  .mc-shell-engineering-focus .mc-header-status {
    width: 100% !important;
    max-width: 100% !important;
  }
}
/* === TRFMC ENGINEERING FOCUS V2 END === */
'''

css.write_text(text.rstrip() + "\n\n" + patch + "\n", encoding="utf-8")
print("CSS_ENGINEERING_FOCUS_V2_APPENDED=True")
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
  "operation": "TRFMC_SOURCE_REFACTOR_ENGINEERING_FOCUS_V2",
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

ln -sfn "$OUT" "$BASE/runtime/quality/latest_source_refactor_engineering_focus_v2"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_SOURCE_REFACTOR_ENGINEERING_FOCUS_V2 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
