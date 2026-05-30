#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
SRCMAP="$BASE/runtime/quality/latest_source_of_truth_map"
FREEZE="$BASE/_archive/latest_control_freeze"
OUT="$BASE/runtime/quality/TRFMC_QUARANTINE_PLAN_COPY_ONLY_$TS"
Q="$BASE/_archive/quarantine/TRFMC_QUARANTINE_COPY_ONLY_$TS"

mkdir -p "$OUT" "$Q/files"

PLAN="$OUT/quarantine_plan.tsv"
COPIED="$OUT/copied_files.tsv"
SHA="$OUT/sha256_manifest.tsv"
REFS="$OUT/reference_check.tsv"
BUILDLOG="$OUT/npm_build_after_copy_only.log"
SUMMARY="$OUT/summary.json"

cd "$BASE"

echo "============================================================"
echo "TRFMC_QUARANTINE_PLAN_COPY_ONLY"
echo "Copy-only quarantine · no delete · no move · no source mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -d "$SRCMAP" ]; then
  echo "ERRORE: source-of-truth map non trovata: $SRCMAP"
  exit 1
fi

echo
echo "=== 1) GENERAZIONE PIANO QUARANTENA ==="

{
  echo -e "class\tpath\treason\taction"
  awk -F'\t' 'NR>1 && ($3 ~ /V51 patch residue|V51 patch residue not referenced/) {
    print "V51_RESIDUE\t"$2"\t"$3"\tCOPY_ONLY_QUARANTINE"
  }' "$SRCMAP/archive_backlog.tsv"

  awk -F'\t' 'NR>1 && ($2 ~ /\.bak|before_cleanup|bak_before/) {
    print "BACKUP_FILE\t"$2"\t"$3"\tCOPY_ONLY_QUARANTINE"
  }' "$SRCMAP/archive_backlog.tsv"
} | awk -F'\t' '!seen[$2]++' > "$PLAN"

column -t -s $'\t' "$PLAN"

echo
echo "=== 2) REFERENCE CHECK NEL SORGENTE UFFICIALE ==="

{
  echo -e "path\treferenced_in_official_sources"
  awk -F'\t' 'NR>1 {print $2}' "$PLAN" | while read -r p; do
    base="$(basename "$p")"
    refs="$(grep -RIl --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git "$base" frontend/index.html frontend/src backend 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
    [ -z "$refs" ] && refs="NONE"
    printf "%s\t%s\n" "$p" "$refs"
  done
} | tee "$REFS"

echo
echo "=== 3) COPY-ONLY IN QUARANTENA ==="

{
  echo -e "source\tcopy_path\tresult"
  awk -F'\t' 'NR>1 {print $2}' "$PLAN" | while read -r p; do
    if [ -f "$p" ]; then
      dest="$Q/files/$p"
      mkdir -p "$(dirname "$dest")"
      cp -a "$p" "$dest"
      printf "%s\t%s\tCOPIED\n" "$p" "$dest"
    else
      printf "%s\t-\tMISSING_SOURCE\n" "$p"
    fi
  done
} | tee "$COPIED"

echo
echo "=== 4) SHA256 MANIFEST ==="

{
  echo -e "sha256\tpath"
  awk -F'\t' 'NR>1 && $3=="COPIED" {print $2}' "$COPIED" | while read -r copied; do
    sha256sum "$copied"
  done
} | tee "$SHA"

echo
echo "=== 5) BUILD CHECK DOPO COPY-ONLY ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

PLAN_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PLAN")"
COPIED_TOTAL="$(awk 'NR>1 && $3=="COPIED" {c++} END{print c+0}' "$COPIED")"
MISSING_TOTAL="$(awk 'NR>1 && $3=="MISSING_SOURCE" {c++} END{print c+0}' "$COPIED")"
REF_TOTAL="$(awk 'NR>1 && $2!="NONE" {c++} END{print c+0}' "$REFS")"

cat > "$Q/README_QUARANTINE_COPY_ONLY.md" <<MD
# TRFMC Quarantine Copy-Only

Timestamp: $TS

## Policy
- No files deleted.
- No files moved.
- No React/source files modified.
- No backend files modified.
- No index injection added.
- This is a safety copy before any future archive/move operation.

## Counts
- Planned files: $PLAN_TOTAL
- Copied files: $COPIED_TOTAL
- Missing sources: $MISSING_TOTAL
- Referenced in official sources: $REF_TOTAL
- Build result after copy-only: $BUILD_RESULT

## Source
- Source-of-truth map: $SRCMAP
- Control freeze: $FREEZE
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_QUARANTINE_PLAN_COPY_ONLY",
  "mutation": "copy_only",
  "delete": false,
  "move": false,
  "source_mutation": false,
  "backend_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "quarantine": "$Q",
  "plan": "$PLAN",
  "copied_files": "$COPIED",
  "sha256_manifest": "$SHA",
  "reference_check": "$REFS",
  "build_log": "$BUILDLOG",
  "planned_total": $PLAN_TOTAL,
  "copied_total": $COPIED_TOTAL,
  "missing_total": $MISSING_TOTAL,
  "referenced_total": $REF_TOTAL,
  "build_result": "$BUILD_RESULT",
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && echo COPY_ONLY_READY || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_quarantine_plan_copy_only"
ln -sfn "$Q" "$BASE/_archive/quarantine/latest_copy_only"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_QUARANTINE_PLAN_COPY_ONLY COMPLETATO"
echo "Output: $OUT"
echo "Quarantine copy: $Q"
echo "============================================================"
