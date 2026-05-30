#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
COPY_OUT="$BASE/runtime/quality/latest_quarantine_plan_copy_only"
COPY_Q="$BASE/_archive/quarantine/latest_copy_only"

OUT="$BASE/runtime/quality/TRFMC_QUARANTINE_MOVE_APPROVED_$TS"
MOVE_Q="$BASE/_archive/quarantine/TRFMC_QUARANTINE_MOVED_$TS"

mkdir -p "$OUT" "$MOVE_Q/files"

SUMMARY="$OUT/summary.json"
MOVEPLAN="$OUT/move_plan.tsv"
MOVED="$OUT/moved_files.tsv"
REFS="$OUT/reference_check_before_move.tsv"
BUILDLOG="$OUT/npm_build_after_move.log"
RESTORE="$OUT/RESTORE_MOVED_FILES.sh"

cd "$BASE"

echo "============================================================"
echo "TRFMC_QUARANTINE_MOVE_APPROVED"
echo "Move-only approved quarantine · source-safe"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$COPY_OUT/summary.json" ]; then
  echo "ERRORE: summary copy-only non trovato: $COPY_OUT/summary.json"
  exit 1
fi

COPY_READY="$(python3 - <<PY
import json
from pathlib import Path
s=json.loads(Path("$COPY_OUT/summary.json").read_text())
print(s.get("result",""))
PY
)"

REF_TOTAL="$(python3 - <<PY
import json
from pathlib import Path
s=json.loads(Path("$COPY_OUT/summary.json").read_text())
print(s.get("referenced_total",-1))
PY
)"

BUILD_PREV="$(python3 - <<PY
import json
from pathlib import Path
s=json.loads(Path("$COPY_OUT/summary.json").read_text())
print(s.get("build_result",""))
PY
)"

if [ "$COPY_READY" != "COPY_ONLY_READY" ] || [ "$REF_TOTAL" != "0" ] || [ "$BUILD_PREV" != "PASS" ]; then
  echo "ERRORE: copy-only non idoneo al move."
  echo "COPY_READY=$COPY_READY REF_TOTAL=$REF_TOTAL BUILD_PREV=$BUILD_PREV"
  exit 1
fi

echo
echo "=== 1) MOVE PLAN DA COPY-ONLY ==="

{
  echo -e "source\tdestination\taction"
  awk -F'\t' 'NR>1 && $3=="COPIED" {
    src=$1
    dest="'$MOVE_Q'/files/" src
    print src "\t" dest "\tMOVE_TO_QUARANTINE"
  }' "$COPY_OUT/copied_files.tsv"
} | tee "$MOVEPLAN"

echo
echo "=== 2) REFERENCE CHECK PRIMA DEL MOVE ==="

{
  echo -e "path\treferenced_in_official_sources"

  awk -F'\t' 'NR>1 {print $1}' "$MOVEPLAN" | while IFS= read -r p; do
    base="$(basename "$p")"
    refs="$(
      {
        grep -RIl --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git \
          "$base" frontend/index.html frontend/src backend 2>/dev/null || true
      } | tr '\n' ',' | sed 's/,$//'
    )"
    [ -z "$refs" ] && refs="NONE"
    printf "%s\t%s\n" "$p" "$refs"
  done
} | tee "$REFS"

REF_NOW="$(awk 'NR>1 && $2!="NONE" {c++} END{print c+0}' "$REFS")"

if [ "$REF_NOW" != "0" ]; then
  echo "ERRORE: alcuni file risultano ancora referenziati. Move annullato."
  column -t -s $'\t' "$REFS"
  exit 1
fi

echo
echo "=== 3) MOVE IN QUARANTENA ==="

{
  echo -e "source\tdestination\tresult"
  awk -F'\t' 'NR>1 {print $1 "\t" $2}' "$MOVEPLAN" | while IFS=$'\t' read -r src dest; do
    if [ -f "$src" ]; then
      mkdir -p "$(dirname "$dest")"
      mv "$src" "$dest"
      printf "%s\t%s\tMOVED\n" "$src" "$dest"
    else
      printf "%s\t%s\tMISSING_SOURCE\n" "$src" "$dest"
    fi
  done
} | tee "$MOVED"

echo
echo "=== 4) RESTORE SCRIPT ==="

cat > "$RESTORE" <<'REST'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

REST

awk -F'\t' 'NR>1 && $3=="MOVED" {
  print "mkdir -p \"$(dirname \047" $1 "\047)\""
  print "mv \047" $2 "\047 \047" $1 "\047"
}' "$MOVED" >> "$RESTORE"

chmod +x "$RESTORE"

echo "Restore script: $RESTORE"

echo
echo "=== 5) BUILD CHECK DOPO MOVE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "ERRORE: build fallita dopo move. Eseguo restore automatico."
  "$RESTORE"
  BUILD_RESULT="FAIL_RESTORED"
fi

PLANNED_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$MOVEPLAN")"
MOVED_TOTAL="$(awk 'NR>1 && $3=="MOVED" {c++} END{print c+0}' "$MOVED")"
MISSING_TOTAL="$(awk 'NR>1 && $3=="MISSING_SOURCE" {c++} END{print c+0}' "$MOVED")"

cat > "$MOVE_Q/README_QUARANTINE_MOVED.md" <<MD
# TRFMC Quarantine Moved

Timestamp: $TS

## Policy
- Only files already copied and verified by copy-only quarantine were moved.
- No React source modified.
- No backend modified.
- No nginx/systemd modified.
- Reference check before move: $REF_NOW referenced files.
- Build result after move: $BUILD_RESULT

## Counts
- Planned: $PLANNED_TOTAL
- Moved: $MOVED_TOTAL
- Missing: $MISSING_TOTAL

## Restore
Run:
\`$RESTORE\`
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_QUARANTINE_MOVE_APPROVED",
  "mutation": "move_quarantine_only",
  "delete": false,
  "source_mutation": false,
  "backend_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "quarantine": "$MOVE_Q",
  "move_plan": "$MOVEPLAN",
  "moved_files": "$MOVED",
  "reference_check_before_move": "$REFS",
  "restore_script": "$RESTORE",
  "build_log": "$BUILDLOG",
  "planned_total": $PLANNED_TOTAL,
  "moved_total": $MOVED_TOTAL,
  "missing_total": $MISSING_TOTAL,
  "referenced_before_move": $REF_NOW,
  "build_result": "$BUILD_RESULT",
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && echo MOVE_READY_COMPLETE || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_quarantine_move_approved"
ln -sfn "$MOVE_Q" "$BASE/_archive/quarantine/latest_moved"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_QUARANTINE_MOVE_APPROVED COMPLETATO"
echo "Output: $OUT"
echo "Moved quarantine: $MOVE_Q"
echo "============================================================"
