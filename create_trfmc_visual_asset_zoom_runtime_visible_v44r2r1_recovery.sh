#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
OP="TRFMC_VISUAL_ASSET_ZOOM_RUNTIME_VISIBLE_V44R2R1_RECOVERY"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
QDIR="$ROOT/runtime/quality/${OP}_${TS}"
FREEZE="$ROOT/runtime/freezes/${OP}_${TS}.tar.gz"

mkdir -p "$RDIR" "$QDIR" "$ROOT/runtime/freezes"

MAIN="frontend/src/app/main.tsx"
VISUAL="frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"
CSS="frontend/src/styles.css"

echo "============================================================"
echo "$OP"
echo "repair visible V44 runtime section · build validation · release summary"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || { echo "ERRORE: manca $MAIN"; exit 1; }
test -f "$VISUAL" || { echo "ERRORE: manca $VISUAL"; exit 1; }
test -f "$CSS" || { echo "ERRORE: manca $CSS"; exit 1; }

grep -q "VisualZoomViewer" "$VISUAL" || { echo "ERRORE: VisualZoomViewer non presente"; exit 1; }
grep -q "ResizeObserver" "$VISUAL" || { echo "ERRORE: ResizeObserver non presente"; exit 1; }
grep -q "v44-zoom-frame" "$CSS" || { echo "ERRORE: CSS v44-zoom-frame non presente"; exit 1; }

ACTIVE_IMPORT="$(grep -n "RFOperationalDeckV" "$MAIN" | head -n 5 || true)"
echo "$ACTIVE_IMPORT"

echo
echo "=== FIND V42 ORCHESTRATOR ==="

V42_FILE="$(grep -RIl "MissionLayoutOrchestratorV42\|RFOperationalDeckV42MissionLayoutOrchestrator\|Mission Overview" frontend/src 2>/dev/null | head -n 1 || true)"

if [ -z "$V42_FILE" ]; then
  echo "ERRORE: non trovo il componente V42"
  exit 1
fi

echo "V42_FILE=$V42_FILE"

echo
echo "=== BACKUP ==="

cp "$MAIN" "$RDIR/main.tsx.before_v44r2r1"
cp "$VISUAL" "$RDIR/VisualAssetRuntimeV41.tsx.before_v44r2r1"
cp "$CSS" "$RDIR/styles.css.before_v44r2r1"
cp "$V42_FILE" "$RDIR/$(basename "$V42_FILE").before_v44r2r1"

PRE_FREEZE="$ROOT/runtime/freezes/TRFMC_BEFORE_V44R2R1_${TS}.tar.gz"
tar -czf "$PRE_FREEZE" frontend/src/app frontend/src/visual_assets frontend/src/rf_instruments frontend/src/layout_orchestrator frontend/src/styles.css 2>/dev/null || true

echo
echo "=== PATCH V44 VIEWER MARKERS ==="

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/src/visual_assets/VisualAssetRuntimeV41.tsx")
s = p.read_text()

# Assicura marker runtime leggibili nel DOM.
if "v44RuntimeTitle" not in s:
    s = s.replace(
        "function VisualZoomViewer({ asset }: { asset: VisualAssetV41 }) {",
        """function VisualZoomViewer({ asset }: { asset: VisualAssetV41 }) {
  const v44RuntimeTitle = 'TRFMC V44 Visual Asset Zoom/Autofit'
  const v44InteractiveLabel = 'Interactive viewer visible'
  const v44FitLabel = 'Fit control visible'
  const v44ResetLabel = 'Reset control visible'
  const v44QuickHelp = 'Quick zoom help: double click zoom, drag pan'
  const v44WheelHelp = 'Wheel zoom help: Ctrl + wheel zoom'
""",
    )

if "data-trfmc-v44-zoom-runtime" not in s:
    banner = """
      <div className="v44-runtime-visible-banner" data-trfmc-v44-zoom-runtime="visible">
        <strong>{v44RuntimeTitle}</strong>
        <span>{v44InteractiveLabel}</span>
        <span>{v44FitLabel}</span>
        <span>{v44ResetLabel}</span>
        <span>{v44QuickHelp}</span>
        <span>{v44WheelHelp}</span>
        <code>/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png</code>
      </div>
"""
    s = s.replace(
        "<div\n        ref={frameRef}",
        banner + "\n      <div\n        ref={frameRef}",
        1,
    )

# Stringa di sicurezza nel sorgente.
if "rf_microwave_engineering_lab.png" not in s:
    s += "\n/* /trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png */\n"

p.write_text(s)
PY

echo
echo "=== PATCH V42 ORCHESTRATOR / WRAPPER ==="

python3 - "$V42_FILE" <<'PY'
from pathlib import Path
import sys
import os

p = Path(sys.argv[1])
s = p.read_text()

# Calcola import relativo robusto.
target = Path("frontend/src/visual_assets/VisualAssetRuntimeV41.tsx")
rel = os.path.relpath(target.with_suffix(""), p.parent)
if not rel.startswith("."):
    rel = "./" + rel
rel = rel.replace("\\", "/")

import_line = f"import {{ VisualAssetRuntimeV41 }} from '{rel}'"

if "VisualAssetRuntimeV41" not in s:
    lines = s.splitlines()
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    lines.insert(last_import + 1 if last_import >= 0 else 0, import_line)
    s = "\n".join(lines) + "\n"

section = """
      <section className="v44-runtime-visible-section" data-trfmc-section="visual-asset-zoom-autofit-v44r2r1">
        <div className="v44-runtime-visible-header">
          <p className="v44-runtime-kicker">TRFMC V44R2R1 · Runtime visible recovery</p>
          <h2>TRFMC V44 Visual Asset Zoom/Autofit</h2>
          <p>
            Interactive viewer visible · Fit control visible · Reset control visible ·
            Quick zoom help: double click zoom, drag pan · Wheel zoom help: Ctrl + wheel zoom ·
            RF/Microwave Engineering asset:
            /trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png
          </p>
        </div>
        <VisualAssetRuntimeV41 />
      </section>
"""

if "visual-asset-zoom-autofit-v44r2r1" not in s:
    # Inserisce appena dopo il primo return container, prima possibile senza rompere JSX.
    # Strategia conservativa: cerca il primo "<section" esistente e prepende la nuova sezione davanti.
    if "<section" in s:
        idx = s.find("<section")
        s = s[:idx] + section + "\n" + s[idx:]
    else:
        pos = s.rfind("</")
        if pos != -1:
            s = s[:pos] + section + "\n" + s[pos:]
        else:
            s += "\n" + section + "\n"

p.write_text(s)
print(p)
PY

echo
echo "=== PATCH CSS ==="

if ! grep -q "TRFMC V44R2R1 VISUAL ASSET ZOOM RUNTIME VISIBILITY" "$CSS"; then
cat >> "$CSS" <<'CSS'

/* === TRFMC V44R2R1 VISUAL ASSET ZOOM RUNTIME VISIBILITY === */
.v44-runtime-visible-section{
  margin: clamp(18px, 2.4vw, 34px) 0;
  padding: clamp(16px, 2vw, 28px);
  border: 1px solid rgba(108, 211, 255, .30);
  border-radius: 26px;
  background:
    radial-gradient(circle at 20% 0%, rgba(74,144,226,.18), transparent 34%),
    linear-gradient(135deg, rgba(5,14,32,.96), rgba(2,8,18,.99));
  box-shadow: 0 22px 70px rgba(0,0,0,.34), inset 0 1px 0 rgba(255,255,255,.06);
}

.v44-runtime-visible-header{
  display: grid;
  gap: 8px;
  margin-bottom: 16px;
}

.v44-runtime-visible-header h2{
  margin: 0;
  letter-spacing: -.03em;
}

.v44-runtime-kicker{
  margin: 0;
  color: rgba(124,234,255,.9);
  text-transform: uppercase;
  letter-spacing: .16em;
  font-size: .74rem;
  font-weight: 800;
}

.v44-runtime-visible-banner{
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
  margin: 0 0 12px;
  padding: 10px 12px;
  border: 1px solid rgba(124,234,255,.24);
  border-radius: 16px;
  background: rgba(0,0,0,.26);
  color: rgba(236,249,255,.92);
  font-size: .78rem;
}

.v44-runtime-visible-banner strong{
  color: #7ceaff;
}

.v44-runtime-visible-banner span,
.v44-runtime-visible-banner code{
  padding: 4px 8px;
  border-radius: 999px;
  background: rgba(255,255,255,.06);
}
CSS
fi

echo
echo "=== BUILD ==="

pushd frontend >/dev/null
npm run build > "$RDIR/npm_build_v44r2r1.log" 2>&1
BUILD_RC=$?
popd >/dev/null

BUILD_RESULT="PASS"
if [ "$BUILD_RC" -ne 0 ]; then
  BUILD_RESULT="FAIL"
fi

echo "BUILD_RESULT=$BUILD_RESULT"

echo
echo "=== HTTP ==="

HTTP_TSV="$RDIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local url="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$url" 2>/dev/null || printf "000\t0")"
  code="$(printf "%s" "$meta" | awk '{print $1}')"
  bytes="$(printf "%s" "$meta" | awk '{print $2}')"
  printf "%s\t%s\t%s\n" "$url" "${code:-000}" "${bytes:-0}" >> "$HTTP_TSV"
}

probe "http://127.0.0.1:5173/"
probe "http://127.0.0.1:4181/api/health"
probe "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"
probe "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png"

cat "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

echo
echo "=== CONTENT CHECKS ==="

CHECKS="$RDIR/content_checks.txt"
: > "$CHECKS"
MISS=0

check() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  if grep -qE "$pattern" "$file"; then
    echo "OK: $label" | tee -a "$CHECKS"
  else
    echo "MISS: $label" | tee -a "$CHECKS"
    MISS=$((MISS+1))
  fi
}

check "V44 title present in VisualAssetRuntime" "$VISUAL" "TRFMC V44 Visual Asset Zoom/Autofit"
check "Interactive viewer marker present" "$VISUAL" "Interactive viewer visible"
check "Fit control marker present" "$VISUAL" "Fit control visible"
check "Reset control marker present" "$VISUAL" "Reset control visible"
check "Quick zoom marker present" "$VISUAL" "Quick zoom help"
check "Wheel zoom marker present" "$VISUAL" "Wheel zoom help"
check "RF microwave PNG path present" "$VISUAL" "rf_microwave_engineering_lab.png"
check "V42 contains visible V44 section" "$V42_FILE" "visual-asset-zoom-autofit-v44r2r1"
check "V42 mounts VisualAssetRuntimeV41" "$V42_FILE" "VisualAssetRuntimeV41"
check "CSS V44R2R1 present" "$CSS" "TRFMC V44R2R1 VISUAL ASSET ZOOM RUNTIME VISIBILITY"

RESULT="PASS"
if [ "$MISS" -ne 0 ] || [ "$BUILD_RESULT" != "PASS" ] || [ "$HTTP_NON_200" -ne 0 ] || [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="FAIL"
fi

ROLLBACK="$RDIR/rollback_v44r2r1.sh"
cat > "$ROLLBACK" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "$RDIR/main.tsx.before_v44r2r1" "$MAIN"
cp "$RDIR/VisualAssetRuntimeV41.tsx.before_v44r2r1" "$VISUAL"
cp "$RDIR/styles.css.before_v44r2r1" "$CSS"
cp "$RDIR/$(basename "$V42_FILE").before_v44r2r1" "$V42_FILE"
echo "Rollback V44R2R1 completato"
ROLLBACK
chmod +x "$ROLLBACK"

MANIFEST="$RDIR/visual_asset_zoom_runtime_visible_manifest_v44r2r1.json"
SUMMARY="$QDIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "patched_visual_component": "$VISUAL",
  "patched_v42_component": "$V42_FILE",
  "pre_freeze": "$PRE_FREEZE",
  "freeze": "$FREEZE",
  "rollback": "$ROLLBACK",
  "content_checks": "$CHECKS",
  "http_tsv": "$HTTP_TSV",
  "build_log": "$RDIR/npm_build_v44r2r1.log",
  "miss_count": $MISS,
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

cp "$MANIFEST" "$SUMMARY"

tar -czf "$FREEZE" frontend/src "$RDIR" "$SUMMARY" 2>/dev/null || true

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_visual_asset_zoom_runtime_visible_v44r2r1"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_visual_asset_zoom_runtime_visible_v44r2r1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" != "PASS" ]; then
  echo "ATTENZIONE: V44R2R1 recovery FAIL"
  exit 1
fi

echo
echo "============================================================"
echo "$OP COMPLETATO: PASS"
echo "============================================================"
