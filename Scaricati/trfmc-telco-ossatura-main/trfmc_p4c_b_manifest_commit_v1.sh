#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4C_B_MANIFEST_COMMIT_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE"

P4C_A="runtime/quality/latest_p4c_a_manifest_expansion_readonly"
P4B="runtime/quality/latest_p4b_v21_static_polish_and_freeze"

MANIFEST_JSON="$P4C_A/portal_os_manifest_candidate.json"
TARGET="frontend/src/portal-os/portalManifest.ts"
ROOT="frontend/src/portal-os/PortalOSRoot.tsx"
MAIN="frontend/src/app/main.tsx"

SUMMARY="$OUT/summary.json"
STATIC="$OUT/static_gate.tsv"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_p4c_b_manifest_commit.log"
DOM="$OUT/dom_gate.txt"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREEN="$OUT/portal_os_manifest_commit_1920x1080.png"
SCREENERR="$OUT/chrome_screenshot.stderr.log"
DIFF="$OUT/p4c_b_manifest_commit.diff"
RESTORE="$OUT/RESTORE_P4C_B_MANIFEST_COMMIT_V1.sh"
FREEZE="$BASE/_archive/baselines/BASELINE_P4C_B_MANIFEST_COMMIT_PASS_$TS"

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
echo "TRFMC_P4C_B_MANIFEST_COMMIT_V1"
echo "Commit manifest candidato dentro Portal OS · no V42 mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$MANIFEST_JSON" ]; then
  echo "ERRORE: manifest candidato P4C-A non trovato: $MANIFEST_JSON"
  exit 1
fi

if [ ! -d "$P4B" ]; then
  echo "ERRORE: baseline P4B V2.1 non trovata: $P4B"
  exit 1
fi

if [ ! -f "$TARGET" ]; then
  echo "ERRORE: portalManifest.ts target non trovato: $TARGET"
  exit 1
fi

cp -a "$TARGET" "$BACKUP/portalManifest.ts.before_$TS"
cp -a "$ROOT" "$BACKUP/PortalOSRoot.tsx.before_$TS" 2>/dev/null || true
cp -a "$MAIN" "$BACKUP/main.tsx.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$BASE"

cp -a "$BACKUP/portalManifest.ts.before_$TS" "$TARGET"

if [ -f "$BACKUP/PortalOSRoot.tsx.before_$TS" ]; then
  cp -a "$BACKUP/PortalOSRoot.tsx.before_$TS" "$ROOT"
fi

cp -a "$BACKUP/main.tsx.before_$TS" "$MAIN"

echo "RESTORE_P4C_B_MANIFEST_COMMIT_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 1) GENERO portalManifest.ts COMPATIBILE CON PortalOSRoot ==="

python3 - "$MANIFEST_JSON" "$TARGET" <<'PY'
import json
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

data = json.loads(src.read_text(encoding="utf-8"))
modules = data.get("modules", [])

clean = []
seen = set()

def normalize_module(m):
    item = dict(m)

    if item.get("id") == "portal-os-home":
        item["id"] = "home"
        item["status"] = "preview"
        item["title"] = "Unified Portal OS Home"
        item["route"] = "#portal-os-preview"

    item.setdefault("id", "unknown")
    item.setdefault("title", item["id"])
    item.setdefault("category", "uncategorized")
    item.setdefault("route", "#" + item["id"])
    item.setdefault("status", "candidate")
    item.setdefault("source", "-")
    item.setdefault("description", item.get("mode", "-"))
    item.setdefault("mode", "-")
    item.setdefault("priority", "-")
    item.setdefault("promotionScore", 0)
    item.setdefault("shellScore", 0)
    item.setdefault("canvas", 0)
    item.setdefault("iframe", 0)
    item.setdefault("script", 0)
    item.setdefault("risks", [])
    item.setdefault("target", "-")

    if not isinstance(item["risks"], list):
        item["risks"] = []

    return item

# home sempre primo
home = None
for m in modules:
    item = normalize_module(m)
    if item["id"] == "home":
        home = item
        break

if home is None:
    home = {
        "id": "home",
        "title": "Unified Portal OS Home",
        "category": "portal-os",
        "route": "#portal-os-preview",
        "status": "preview",
        "source": "frontend/src/portal-os/PortalOSRoot.tsx",
        "description": "Home unica: shell, launcher, viewport, evidence panel e data fabric.",
        "mode": "native-react",
        "priority": "P0",
        "promotionScore": 10000,
        "shellScore": 0,
        "canvas": 0,
        "iframe": 0,
        "script": 0,
        "risks": [],
        "target": "core-root",
    }

clean.append(home)
seen.add("home")

for m in modules:
    item = normalize_module(m)
    if item["id"] in seen:
        continue
    clean.append(item)
    seen.add(item["id"])

ts = []
ts.append("export type PortalOSModuleStatus =")
ts.append("  | 'preview'")
ts.append("  | 'promoted'")
ts.append("  | 'reference'")
ts.append("  | 'reference-risk'")
ts.append("  | 'candidate'")
ts.append("  | 'candidate-visual'")
ts.append("  | 'candidate-operational'")
ts.append("  | 'legacy-leaf-review'")
ts.append("  | 'quarantine-review'")
ts.append("")
ts.append("export type PortalOSModule = {")
ts.append("  id: string")
ts.append("  title: string")
ts.append("  category: string")
ts.append("  route: string")
ts.append("  status: PortalOSModuleStatus | string")
ts.append("  source: string")
ts.append("  description: string")
ts.append("  mode?: string")
ts.append("  priority?: string")
ts.append("  promotionScore?: number")
ts.append("  shellScore?: number")
ts.append("  canvas?: number")
ts.append("  iframe?: number")
ts.append("  script?: number")
ts.append("  risks?: string[]")
ts.append("  target?: string")
ts.append("}")
ts.append("")
ts.append("export const portalOSPolicy = {")
ts.append("  singleSpa: true,")
ts.append("  singleReactRoot: true,")
ts.append("  v63AsVisualReference: true,")
ts.append("  legacyHtmlAsSource: true,")
ts.append("  noIframeAsArchitecture: true,")
ts.append("  promotionRequiresReactRewrite: true,")
ts.append("} as const")
ts.append("")
ts.append("export const portalOSModules: PortalOSModule[] = ")
ts.append(json.dumps(clean, indent=2, ensure_ascii=False))
ts.append("")
ts.append("export const promotedPortalOSModules = portalOSModules.filter((module) => module.status === 'promoted')")
ts.append("export const candidatePortalOSModules = portalOSModules.filter((module) => String(module.status).startsWith('candidate'))")
ts.append("export const referencePortalOSModules = portalOSModules.filter((module) => String(module.status).startsWith('reference'))")
ts.append("export const reviewPortalOSModules = portalOSModules.filter((module) => String(module.status).includes('review'))")
ts.append("export const visualPortalOSModules = portalOSModules.filter((module) => module.canvas && module.canvas > 0)")
ts.append("export const riskyPortalOSModules = portalOSModules.filter((module) => module.risks && module.risks.length > 0)")
ts.append("export const portalOSCategories = Array.from(new Set(portalOSModules.map((module) => module.category))).sort()")
ts.append("")

dst.write_text("\n".join(ts), encoding="utf-8")
print(f"WROTE={dst}")
print(f"MODULES={len(clean)}")
PY

echo
echo "=== 2) DIFF ==="
git diff -- "$TARGET" "$ROOT" "$MAIN" > "$DIFF" || true
sed -n '1,220p' "$DIFF"

echo
echo "=== 3) BUILD ==="

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
echo "=== 4) HTTP GATE ==="

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
echo "=== 5) STATIC GATE ==="

{
  echo -e "check\tresult\tcount"
  IFRAME_COUNT="$(safe_count_files "<iframe" frontend/src/portal-os "$MAIN")"
  DANGEROUS_COUNT="$(safe_count_files "dangerouslySetInnerHTML|\\.innerHTML[[:space:]]*=|document\\.write|document\\.body|appendChild" frontend/src/portal-os "$MAIN")"
  EXTRA_ROOT_CALLS="$(safe_count_files "\\bcreateRoot[[:space:]]*\\(" frontend/src/portal-os)"
  V42_P4C_COUNT="$(safe_count_files "P4C|portalOSModules|portalManifest|PortalOSRoot" frontend/src/layout_orchestrator 2>/dev/null || true)"
  MANIFEST_MODULE_COUNT="$(grep -c '"id":' "$TARGET" || true)"
  HOME_ID_COUNT="$(grep -c '"id": "home"' "$TARGET" || true)"
  CANDIDATE_VISUAL_COUNT="$(grep -c "candidate-visual" "$TARGET" || true)"
  QUARANTINE_COUNT="$(grep -c "quarantine-review" "$TARGET" || true)"

  echo -e "iframe_absent\t$([ "$IFRAME_COUNT" = "0" ] && echo PASS || echo FAIL)\t$IFRAME_COUNT"
  echo -e "dangerous_dom_absent\t$([ "$DANGEROUS_COUNT" = "0" ] && echo PASS || echo FAIL)\t$DANGEROUS_COUNT"
  echo -e "no_extra_createroot_call_in_portal_os\t$([ "$EXTRA_ROOT_CALLS" = "0" ] && echo PASS || echo FAIL)\t$EXTRA_ROOT_CALLS"
  echo -e "v42_not_touched_by_p4c\t$([ "$V42_P4C_COUNT" = "0" ] && echo PASS || echo FAIL)\t$V42_P4C_COUNT"
  echo -e "manifest_module_count_gt_100\t$([ "$MANIFEST_MODULE_COUNT" -gt 100 ] && echo PASS || echo FAIL)\t$MANIFEST_MODULE_COUNT"
  echo -e "home_id_present_once\t$([ "$HOME_ID_COUNT" = "1" ] && echo PASS || echo FAIL)\t$HOME_ID_COUNT"
  echo -e "candidate_visual_present\t$([ "$CANDIDATE_VISUAL_COUNT" -gt 0 ] && echo PASS || echo FAIL)\t$CANDIDATE_VISUAL_COUNT"
  echo -e "quarantine_review_present\t$([ "$QUARANTINE_COUNT" -gt 0 ] && echo PASS || echo FAIL)\t$QUARANTINE_COUNT"
} | tee "$STATIC" | column -t -s $'\t'

echo
echo "=== 6) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    CHROME_BIN="google-chrome"
  elif command -v chromium >/dev/null 2>&1; then
    CHROME_BIN="chromium"
  else
    CHROME_BIN=""
  fi

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    "$CHROME_BIN" \
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
WAR_ROOM_COUNT="$(safe_count_literal 'TRFMC RF/TM War Room V4' "$DOM")"
ANTENNA_COUNT="$(safe_count_literal 'Antenna System Explorer' "$DOM")"
TOTAL_MODULE_LABEL_COUNT="$(safe_count_literal 'Operational Modules' "$DOM")"

echo "DOM_RESULT=$DOM_RESULT"
echo "PREVIEW_MARKER_COUNT=$PREVIEW_MARKER_COUNT"
echo "HOME_MARKER_COUNT=$HOME_MARKER_COUNT"
echo "VIEWPORT_MARKER_COUNT=$VIEWPORT_MARKER_COUNT"
echo "LAUNCHER_COUNT=$LAUNCHER_COUNT"
echo "EVIDENCE_COUNT=$EVIDENCE_COUNT"
echo "TITLE_COUNT=$TITLE_COUNT"
echo "V42_TITLE_COUNT=$V42_TITLE_COUNT"
echo "WAR_ROOM_COUNT=$WAR_ROOM_COUNT"
echo "ANTENNA_COUNT=$ANTENNA_COUNT"
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
if [ "$DOM_RESULT" = "PASS" ] && [ "$V42_TITLE_COUNT" != "0" ]; then RESULT="REVIEW_V42_VISIBLE_IN_PORTAL_OS"; fi
if [ "$DOM_RESULT" = "PASS" ] && [ "$WAR_ROOM_COUNT" = "0" ]; then RESULT="REVIEW_MANIFEST_NOT_VISIBLE"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

if [ "$RESULT" = "PASS" ]; then
  mkdir -p "$FREEZE"
  cp -a frontend/src/portal-os "$FREEZE/portal-os"
  cp -a frontend/src/app/main.tsx "$FREEZE/main.tsx"
  cp -a "$OUT" "$FREEZE/quality"
  cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4C-B MANIFEST COMMIT PASS

Timestamp: $TS

Status:
- P4C-A manifest committed into frontend/src/portal-os/portalManifest.ts.
- Portal OS preview still mounted inside existing React root.
- V42 untouched.
- Legacy HTML treated as manifest source, not runtime portal.
- Build PASS.
- HTTP PASS.
- Static safety PASS.
- DOM PASS.
- Screenshot PASS.

Next:
P4D_COMMAND_CENTER_HOME_V63_REACT_GOVERNED_PREVIEW.
FREEZE_EOF
fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4C_B_MANIFEST_COMMIT_V1",
  "mutation": "portal_os_manifest_source_commit",
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "v42_mutation": false,
  "p4a_manifest": "$MANIFEST_JSON",
  "target": "$TARGET",
  "restore_script": "$RESTORE",
  "freeze": "$FREEZE",
  "diff": "$DIFF",
  "static_gate": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "dom_gate": "$DOM",
  "screenshot": "$SCREEN",
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
  "war_room_count": $WAR_ROOM_COUNT,
  "antenna_count": $ANTENNA_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4c_b_manifest_commit_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P4C_B_MANIFEST_COMMIT_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
