#!/usr/bin/env bash
set -Eeuo pipefail
cd "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"

cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4C_B_MANIFEST_COMMIT_V1_20260530_150640/backup/portalManifest.ts.before_20260530_150640" "frontend/src/portal-os/portalManifest.ts"

if [ -f "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4C_B_MANIFEST_COMMIT_V1_20260530_150640/backup/PortalOSRoot.tsx.before_20260530_150640" ]; then
  cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4C_B_MANIFEST_COMMIT_V1_20260530_150640/backup/PortalOSRoot.tsx.before_20260530_150640" "frontend/src/portal-os/PortalOSRoot.tsx"
fi

cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4C_B_MANIFEST_COMMIT_V1_20260530_150640/backup/main.tsx.before_20260530_150640" "frontend/src/app/main.tsx"

echo "RESTORE_P4C_B_MANIFEST_COMMIT_V1 completato"
