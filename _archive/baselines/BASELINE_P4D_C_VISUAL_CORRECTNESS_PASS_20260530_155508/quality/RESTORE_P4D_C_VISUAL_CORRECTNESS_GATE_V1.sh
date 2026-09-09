#!/usr/bin/env bash
set -Eeuo pipefail
cd "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"

cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4D_C_VISUAL_CORRECTNESS_GATE_V1_20260530_155508/backup/PortalOSRoot.tsx.before_20260530_155508" "frontend/src/portal-os/PortalOSRoot.tsx"
cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4D_C_VISUAL_CORRECTNESS_GATE_V1_20260530_155508/backup/portal-os.css.before_20260530_155508" "frontend/src/portal-os/portal-os.css"
cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P4D_C_VISUAL_CORRECTNESS_GATE_V1_20260530_155508/backup/main.tsx.before_20260530_155508" "frontend/src/app/main.tsx"

echo "RESTORE_P4D_C_VISUAL_CORRECTNESS_GATE_V1 completato"
