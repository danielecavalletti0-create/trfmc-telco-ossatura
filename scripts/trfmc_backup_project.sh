#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT="$(dirname "$ROOT")"
NAME="$(basename "$ROOT")"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$PARENT/trfmc_full_project_backup_v24_${TS}.tar.gz"
MANIFEST="$PARENT/trfmc_full_project_backup_v24_${TS}_manifest.txt"

echo "============================================================"
echo "TRFMC FULL PROJECT BACKUP v0.24"
echo "Root: $ROOT"
echo "Output: $OUT"
echo "============================================================"

cd "$PARENT"

tar \
  --exclude="$NAME/frontend/node_modules" \
  --exclude="$NAME/.git/objects/pack/tmp_pack_*" \
  -czf "$OUT" "$NAME"

{
  echo "TRFMC FULL PROJECT BACKUP v0.24"
  echo "date=$(date -Is)"
  echo "root=$ROOT"
  echo "archive=$OUT"
  echo "size=$(stat -c%s "$OUT")"
  echo "sha256=$(sha256sum "$OUT" | awk '{print $1}')"
  echo
  echo "git_branch=$(cd "$ROOT" && git branch --show-current)"
  echo "git_head=$(cd "$ROOT" && git rev-parse --short HEAD)"
  echo
  echo "git_status:"
  cd "$ROOT" && git status --short
} > "$MANIFEST"

echo
echo "Backup creato:"
ls -lh "$OUT" "$MANIFEST"
echo
echo "SHA256:"
sha256sum "$OUT"
