#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_MASTER_PORTAL_REGISTER_READONLY_$TS"

mkdir -p "$OUT"

SUMMARY="$OUT/summary.json"
GIT_DIRTY="$OUT/git_dirty_tree.tsv"
REACT_COMPONENTS="$OUT/react_components.tsv"
PUBLIC_HTML="$OUT/public_html_inventory.tsv"
PUBLIC_ASSETS="$OUT/public_assets_inventory.tsv"
V51_RESIDUES="$OUT/v51_residue_assets.tsv"
PLACEHOLDERS="$OUT/placeholder_todo_mock_inventory.tsv"
ROUTES="$OUT/route_hash_inventory.tsv"
API_ENDPOINTS="$OUT/api_endpoint_inventory.tsv"
MODULE_MATRIX="$OUT/module_completion_matrix.tsv"
PROMOTE="$OUT/promote_candidates.tsv"
ARCHIVE="$OUT/archive_candidates.tsv"
PLAN="$OUT/TRFMC_MASTER_RECOVERY_AND_COMPLETION_PLAN.md"

cd "$BASE"

echo "============================================================"
echo "TRFMC_MASTER_PORTAL_REGISTER_READONLY"
echo "Read-only inventory · no portal mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) GIT DIRTY TREE ==="
{
  echo -e "status\tpath"
  git status --porcelain=v1 | sed -E 's/^(.{2}) (.*)$/\1\t\2/' || true
} | tee "$GIT_DIRTY"

echo
echo "=== 2) REACT COMPONENTS ==="
{
  echo -e "kind\tpath\tbytes"
  find frontend/src -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" -o -name "*.css" \) \
    -printf "react_source\t%p\t%s\n" 2>/dev/null | sort
} | tee "$REACT_COMPONENTS"

echo
echo "=== 3) PUBLIC HTML INVENTORY ==="
{
  echo -e "kind\tpath\tbytes\tstatus_guess"
  find frontend/public -maxdepth 2 -type f -name "*.html" -printf "%p\t%s\n" 2>/dev/null \
  | sort \
  | awk -F'\t' '
    BEGIN { OFS="\t" }
    {
      path=$1; bytes=$2; status="REVIEW";
      if (path ~ /official_safe_entrypoint|trfmc_home|trfmc\.html|portal_index|integration_control_room/) status="PROMOTE_OR_OFFICIAL_REVIEW";
      if (path ~ /prototype|preview|roadmap|orphan|triage|quarantine/) status="ARCHIVE_REVIEW";
      if (path ~ /v[0-9]+[a-z]?|v[0-9]+r[0-9]+/) status=status"_VERSIONED";
      print "public_html", path, bytes, status;
    }'
} | tee "$PUBLIC_HTML"

echo
echo "=== 4) PUBLIC ASSETS INVENTORY ==="
{
  echo -e "kind\tpath\tbytes\tstatus_guess"
  find frontend/public/assets -type f -printf "%p\t%s\n" 2>/dev/null \
  | sort \
  | awk -F'\t' '
    BEGIN { OFS="\t" }
    {
      path=$1; bytes=$2; status="REVIEW";
      if (path ~ /v51r3|v51r4|v51r5|v51r6|v51r7/) status="ARCHIVE_V51_PATCH_RESIDUE";
      if (path ~ /vendor/) status="VENDOR_REVIEW";
      if (path ~ /design_system|instrument_design_system|visual_asset_engine/) status="PROMOTE_CANDIDATE";
      print "public_asset", path, bytes, status;
    }'
} | tee "$PUBLIC_ASSETS"

echo
echo "=== 5) V51 RESIDUE ASSETS ==="
{
  echo -e "path\tbytes"
  find frontend/public frontend/src -type f \
    | grep -Ei "v51r3|v51r4|v51r5|v51r6|v51r7" \
    | while read -r f; do
        [ -f "$f" ] && printf "%s\t%s\n" "$f" "$(stat -c%s "$f")"
      done
} | tee "$V51_RESIDUES"

echo
echo "=== 6) PLACEHOLDER / TODO / MOCK / STUB INVENTORY ==="
{
  echo -e "class\tpath\tline\ttext"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git \
    -E "TODO|FIXME|placeholder|mock|stub|dummy|fake|Da implementare|da implementare|not implemented|coming soon" \
    frontend/src frontend/public backend 2>/dev/null \
  | awk -F: '
    BEGIN { OFS="\t" }
    {
      path=$1; line=$2;
      text=$0;
      sub(/^[^:]+:[^:]+:/, "", text);
      cls="REVIEW";
      if (path ~ /\.bak|backup/) cls="FALSE_POSITIVE_BACKUP";
      else if (path ~ /vendor/) cls="FALSE_POSITIVE_VENDOR";
      else if (path ~ /frontend\/src/) cls="ACTIVE_REACT_DEBT";
      else if (path ~ /frontend\/public/) cls="PUBLIC_DEBT";
      else if (path ~ /backend/) cls="BACKEND_CONTRACT_DEBT";
      print cls, path, line, substr(text,1,240);
    }'
} | tee "$PLACEHOLDERS"

echo
echo "=== 7) ROUTE / HASH INVENTORY ==="
{
  echo -e "path\tline\tmatch"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "#[a-zA-Z0-9][a-zA-Z0-9_-]+|hash:|id: '[a-zA-Z0-9_-]+'|id: \"[a-zA-Z0-9_-]+\"" \
    frontend/src frontend/public 2>/dev/null \
  | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,220)}'
} | tee "$ROUTES"

echo
echo "=== 8) API ENDPOINT INVENTORY ==="
{
  echo -e "path\tline\tendpoint"
  grep -RIn --exclude-dir=node_modules --exclude-dir=dist \
    -E "(@app\.(get|post|put|delete|patch)|APIRouter|router\.(get|post|put|delete|patch)|/api/)" \
    backend frontend/src frontend/public 2>/dev/null \
  | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,240)}'
} | tee "$API_ENDPOINTS"

echo
echo "=== 9) MODULE COMPLETION MATRIX ==="
cat > "$MODULE_MATRIX" <<MATRIX
module	status	reason	next_action
01_Mission_Control	REVIEW	core present, layout/source governance required	consolidate React shell and official status panels
02_RF_Physics	REVIEW	many public pages/assets exist, not fully promoted into React	promote best RF physics engine into React module
03_Signal_Analyzer	REVIEW	RF instrument components exist, public workbench variants exist	select one official analyzer path
04_RF_Microwave_Engineering	REVIEW	smith/microwave labs exist, likely public-first	migrate to official React route/module
05_Antenna_System	REVIEW	many antenna explorer versions exist	select best version, archive older variants
06_Microwave_Link	REVIEW	public v1/v2 modules exist	verify completeness and promote
07_Fiber_Optic	REVIEW	public workbench v1/v2 exists	verify OTDR workflow and promote
08_Private_Networks	REVIEW	public WiFi/5G mesh page exists	complete theory/simulator/API/QA mapping
09_Core_Network	REVIEW	backend/core/open5gs bridge traces exist	complete Open5GS/UERANSIM console contract
10_Data_Center_Infrastructure	REVIEW	public page exists but likely incomplete	complete power/PDU/infrastructure simulator
11_Cyber_RF_Intelligence	REVIEW	public evidence module exists, restricted areas must stay locked	complete safe readonly evidence workflow
12_Knowledge_Base	REVIEW	theory/procedure pages exist	turn into indexed knowledge module
Design_System	UNSTABLE	many CSS/assets variants exist	define one official design system
Navigation	UNSTABLE	many public pages/hash routes exist	define one navigation registry
Quality_Gates	PARTIAL	build passes but visual/source gates missing	add screenshot/navigation/placeholder gates
MATRIX
cat "$MODULE_MATRIX"

echo
echo "=== 10) PROMOTE CANDIDATES ==="
{
  echo -e "priority\tpath\treason"
  grep -E "PROMOTE|OFFICIAL" "$PUBLIC_HTML" | awk -F'\t' 'BEGIN{OFS="\t"} {print "P1",$2,$4}'
  grep -E "PROMOTE_CANDIDATE" "$PUBLIC_ASSETS" | awk -F'\t' 'BEGIN{OFS="\t"} {print "P2",$2,$4}'
  grep -E "MissionLayoutOrchestratorV42|EngineeringContentEnrichmentV49|main.tsx|styles.css" "$REACT_COMPONENTS" \
    | awk -F'\t' 'BEGIN{OFS="\t"} {print "P0",$2,"official React source candidate"}'
} | tee "$PROMOTE"

echo
echo "=== 11) ARCHIVE CANDIDATES ==="
{
  echo -e "priority\tpath\treason"
  awk -F'\t' 'NR>1 && $4 ~ /ARCHIVE/ {print "A1\t"$2"\t"$4}' "$PUBLIC_HTML"
  awk -F'\t' 'NR>1 && $4 ~ /ARCHIVE/ {print "A1\t"$2"\t"$4}' "$PUBLIC_ASSETS"
  awk -F'\t' 'NR>1 {print "A0\t"$1"\tV51 patch residue not referenced in index"}' "$V51_RESIDUES"
  find . -maxdepth 2 -type f \( -name "*bak*" -o -name "*.bak_*" -o -name "*.before_cleanup_*" \) \
    | sed 's#^\./##' \
    | awk 'BEGIN{OFS="\t"} {print "A2",$0,"backup/archive candidate"}'
} | tee "$ARCHIVE"

GIT_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$GIT_DIRTY")"
REACT_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$REACT_COMPONENTS")"
HTML_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PUBLIC_HTML")"
ASSET_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PUBLIC_ASSETS")"
V51_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$V51_RESIDUES")"
DEBT_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PLACEHOLDERS")"
PROMOTE_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PROMOTE")"
ARCHIVE_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$ARCHIVE")"

cat > "$PLAN" <<MD
# TRFMC Master Recovery and Completion Plan

## Stato
Il portale non va ulteriormente patchato. Va governato.

## Regola principale
Entrypoint ufficiale: \`127.0.0.1:5173\`.

## Sorgente ufficiale candidato
- \`frontend/src/app/main.tsx\`
- \`frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx\`
- \`frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx\`
- \`frontend/src/styles.css\`

## Conteggi
- File Git modificati/non tracciati: $GIT_TOTAL
- Sorgenti React/CSS censiti: $REACT_TOTAL
- HTML pubblici censiti: $HTML_TOTAL
- Asset pubblici censiti: $ASSET_TOTAL
- Residui V51 trovati: $V51_TOTAL
- Placeholder/TODO/mock/stub trovati: $DEBT_TOTAL
- Candidati promozione: $PROMOTE_TOTAL
- Candidati archivio: $ARCHIVE_TOTAL

## Strategia
1. Freeze operativo.
2. Classificazione: OFFICIAL / PROMOTE / REVIEW / ARCHIVE.
3. Archiviazione non distruttiva dei residui e backup.
4. Ricostruzione shell in React.
5. Promozione dei migliori moduli public dentro la SPA.
6. Completamento per domini:
   - Mission Control
   - RF Physics
   - Signal Analyzer
   - RF/Microwave Engineering
   - Antenna System
   - Microwave Link
   - Fiber Optic
   - Private Networks
   - 5G Core/RAN
   - Data Center
   - Cyber RF Intelligence
   - Knowledge Base
7. QA finale: build, HTTP, screenshot, placeholder, navigation, API contract.

## Divieto operativo
Nessuna nuova patch runtime CSS/JS in \`index.html\`.
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_MASTER_PORTAL_REGISTER_READONLY",
  "mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "git_dirty_tree": "$GIT_DIRTY",
  "react_components": "$REACT_COMPONENTS",
  "public_html_inventory": "$PUBLIC_HTML",
  "public_assets_inventory": "$PUBLIC_ASSETS",
  "v51_residue_assets": "$V51_RESIDUES",
  "placeholder_todo_mock_inventory": "$PLACEHOLDERS",
  "route_hash_inventory": "$ROUTES",
  "api_endpoint_inventory": "$API_ENDPOINTS",
  "module_completion_matrix": "$MODULE_MATRIX",
  "promote_candidates": "$PROMOTE",
  "archive_candidates": "$ARCHIVE",
  "plan": "$PLAN",
  "git_dirty_total": $GIT_TOTAL,
  "react_source_total": $REACT_TOTAL,
  "public_html_total": $HTML_TOTAL,
  "public_asset_total": $ASSET_TOTAL,
  "v51_residue_total": $V51_TOTAL,
  "debt_total": $DEBT_TOTAL,
  "promote_candidate_total": $PROMOTE_TOTAL,
  "archive_candidate_total": $ARCHIVE_TOTAL,
  "result": "REGISTER_CREATED"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_master_portal_register"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,220p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_MASTER_PORTAL_REGISTER_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
