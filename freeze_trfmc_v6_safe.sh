#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
DEST="/data/LABDATA/TRFMC_FREEZES"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$DEST/TRFMC_SAFE_ENTRYPOINT_V6_$TS.tar.gz"

mkdir -p "$DEST"

cd "$BASE"

tar -czf "$OUT" \
  --exclude='./frontend/node_modules' \
  --exclude='./frontend/dist' \
  --exclude='./.venv' \
  --exclude='./runtime/collaudo' \
  --exclude='./runtime/freezes' \
  --exclude='./runtime/tmp' \
  --exclude='./runtime/logs/*.log' \
  --exclude='./runtime/quality/TRFMC_QUALITY_GATE_V6_*' \
  .

echo "FREEZE=$OUT"
ls -lh "$OUT"
df -h /data/LABDATA
