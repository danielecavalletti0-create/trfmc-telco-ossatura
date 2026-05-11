#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/runtime"
BACKUPS="$RUNTIME/backups"
DRILL="$ROOT/runtime_restore_drill_$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC RESTORE DRILL v0.22 - NON DESTRUCTIVE"
echo "Root: $ROOT"
echo "Runtime: $RUNTIME"
echo "Backups: $BACKUPS"
echo "Drill dir: $DRILL"
echo "============================================================"

echo
echo "=== 1. Git state ==="
cd "$ROOT"
git branch --show-current
git status --short

echo
echo "=== 2. Runtime presence ==="
ls -lah "$RUNTIME" || true
ls -lah "$BACKUPS" || true

LATEST="$(find "$BACKUPS" -maxdepth 1 -type f -name 'trfmc_runtime_backup_v21_*.tar.gz' -o -name 'trfmc_runtime_backup_v22_*.tar.gz' 2>/dev/null | sort | tail -n 1 || true)"

if [ -z "$LATEST" ]; then
  echo "ERRORE: nessun backup runtime trovato in $BACKUPS"
  exit 1
fi

BASE="$(basename "$LATEST" .tar.gz)"
MANIFEST="$BACKUPS/${BASE}_manifest.json"

echo
echo "=== 3. Selected backup ==="
echo "ARCHIVE=$LATEST"
echo "MANIFEST=$MANIFEST"
ls -lh "$LATEST" "$MANIFEST" 2>/dev/null || true

echo
echo "=== 4. SHA256 ==="
ACTUAL_SHA="$(sha256sum "$LATEST" | awk '{print $1}')"
echo "actual_sha256=$ACTUAL_SHA"

EXPECTED_SHA=""
if [ -f "$MANIFEST" ]; then
  EXPECTED_SHA="$(python3 - <<PY
import json
from pathlib import Path
p=Path("$MANIFEST")
try:
    print(json.loads(p.read_text()).get("archive_sha256",""))
except Exception:
    print("")
PY
)"
fi

echo "expected_sha256=$EXPECTED_SHA"

if [ -n "$EXPECTED_SHA" ] && [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "ERRORE: SHA256 non coincide."
  exit 2
fi

echo
echo "=== 5. Tar listing ==="
tar -tzf "$LATEST" | sed -n '1,120p'

echo
echo "=== 6. Extract in staging only ==="
mkdir -p "$DRILL"
tar -xzf "$LATEST" -C "$DRILL"

echo
echo "=== 7. Staging validation ==="
find "$DRILL" -maxdepth 3 -type f | sed -n '1,120p'

test -f "$DRILL/trfmc.db" || { echo "ERRORE: trfmc.db non trovato nello staging."; exit 3; }
test -d "$DRILL/evidence_vault" || { echo "ERRORE: evidence_vault non trovato nello staging."; exit 4; }

echo
echo "DB staging:"
ls -lh "$DRILL/trfmc.db"
sha256sum "$DRILL/trfmc.db"

echo
echo "Evidence vault staging:"
find "$DRILL/evidence_vault" -type f | wc -l
du -sh "$DRILL/evidence_vault"

echo
echo "============================================================"
echo "RESTORE DRILL PASS - nessun file live è stato modificato"
echo "Staging dir: $DRILL"
echo "============================================================"
