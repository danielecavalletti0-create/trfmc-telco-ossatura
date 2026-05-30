#!/usr/bin/env bash
set -Eeuo pipefail
cd "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4B_V21_STATIC_POLISH_AND_FREEZE_20260530_145738/backup/PortalOSRoot.tsx.before_20260530_145738" "frontend/src/portal-os/PortalOSRoot.tsx"
cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4B_V21_STATIC_POLISH_AND_FREEZE_20260530_145738/backup/main.tsx.before_20260530_145738" "frontend/src/app/main.tsx"
echo "RESTORE_P4B_V21_STATIC_POLISH_AND_FREEZE completato"
