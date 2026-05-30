#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
REG="$BASE/runtime/quality/latest_master_portal_register"
FREEZE="$BASE/_archive/TRFMC_CONTROL_FREEZE_$TS"

mkdir -p "$FREEZE"/{master_register,manifests,snapshots}

cd "$BASE"

echo "============================================================"
echo "TRFMC CONTROL FREEZE"
echo "Non-destructive freeze · no portal mutation"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -d "$REG" ]; then
  echo "ERRORE: registro maestro non trovato: $REG"
  exit 1
fi

echo
echo "=== 1) COPIA REGISTRO MAESTRO ==="
cp -a "$REG"/. "$FREEZE/master_register/"

echo
echo "=== 2) MANIFEST PRINCIPALI ==="
cp -a "$REG/git_dirty_tree.tsv" "$FREEZE/manifests/git_dirty_tree.tsv"
cp -a "$REG/promote_candidates.tsv" "$FREEZE/manifests/promote_candidates.tsv"
cp -a "$REG/archive_candidates.tsv" "$FREEZE/manifests/archive_candidates.tsv"
cp -a "$REG/v51_residue_assets.tsv" "$FREEZE/manifests/v51_residue_assets.tsv"
cp -a "$REG/module_completion_matrix.tsv" "$FREEZE/manifests/module_completion_matrix.tsv"

echo
echo "=== 3) SNAPSHOT FILE CRITICI ==="
mkdir -p "$FREEZE/snapshots/frontend/src/app"
mkdir -p "$FREEZE/snapshots/frontend/src/layout_orchestrator"
mkdir -p "$FREEZE/snapshots/frontend/src"
mkdir -p "$FREEZE/snapshots/frontend"

cp -a frontend/index.html "$FREEZE/snapshots/frontend/index.html" 2>/dev/null || true
cp -a frontend/src/app/main.tsx "$FREEZE/snapshots/frontend/src/app/main.tsx" 2>/dev/null || true
cp -a frontend/src/styles.css "$FREEZE/snapshots/frontend/src/styles.css" 2>/dev/null || true
cp -a frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx "$FREEZE/snapshots/frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx" 2>/dev/null || true
cp -a frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx "$FREEZE/snapshots/frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx" 2>/dev/null || true

echo
echo "=== 4) STATO GIT ATTUALE ==="
git status --porcelain=v1 > "$FREEZE/git_status_porcelain_at_freeze.txt" || true
git status > "$FREEZE/git_status_human_at_freeze.txt" || true

echo
echo "=== 5) BUILD CHECK, SENZA MODIFICHE ==="
BUILD_LOG="$FREEZE/npm_build_at_freeze.log"
BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILD_LOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILD_LOG" || true

GIT_DIRTY_TOTAL="$(awk 'NF {c++} END {print c+0}' "$FREEZE/git_status_porcelain_at_freeze.txt")"
PROMOTE_TOTAL="$(awk 'NR>1 {c++} END {print c+0}' "$FREEZE/manifests/promote_candidates.tsv")"
ARCHIVE_TOTAL="$(awk 'NR>1 {c++} END {print c+0}' "$FREEZE/manifests/archive_candidates.tsv")"
V51_TOTAL="$(awk 'NR>1 {c++} END {print c+0}' "$FREEZE/manifests/v51_residue_assets.tsv")"

cat > "$FREEZE/README_CONTROL_FREEZE.md" <<MD
# TRFMC Control Freeze

Timestamp: $TS

## Purpose
This freeze captures the current state before any further recovery, cleanup, promotion, or source-level refactor.

## Rules
- No deletion performed.
- No React/source mutation performed.
- No backend mutation performed.
- No nginx/systemd mutation performed.
- No runtime CSS/JS injection added.

## Current Counts
- Git dirty/untracked entries: $GIT_DIRTY_TOTAL
- Promote candidates: $PROMOTE_TOTAL
- Archive candidates: $ARCHIVE_TOTAL
- V51 residue assets: $V51_TOTAL
- Build result: $BUILD_RESULT

## Next Controlled Phase
1. Review promote candidates.
2. Review archive candidates.
3. Create source-of-truth map.
4. Then modify only official React source files.
MD

cat > "$FREEZE/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_CONTROL_FREEZE",
  "mutation": false,
  "base": "$BASE",
  "freeze": "$FREEZE",
  "master_register": "$REG",
  "git_dirty_total": $GIT_DIRTY_TOTAL,
  "promote_total": $PROMOTE_TOTAL,
  "archive_total": $ARCHIVE_TOTAL,
  "v51_residue_total": $V51_TOTAL,
  "build_result": "$BUILD_RESULT",
  "result": "FREEZE_CREATED"
}
JSON

ln -sfn "$FREEZE" "$BASE/_archive/latest_control_freeze"

echo
echo "=== FREEZE SUMMARY ==="
python3 -m json.tool "$FREEZE/summary.json"

echo
echo "============================================================"
echo "TRFMC CONTROL FREEZE COMPLETATO"
echo "Output: $FREEZE"
echo "============================================================"
