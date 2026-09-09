#!/usr/bin/env bash
set -u
cd "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2" || exit 1

cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1_20260530_164754/backup/PortalOSRoot.tsx.before_20260530_164754" "frontend/src/portal-os/PortalOSRoot.tsx"
cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1_20260530_164754/backup/portal-os.css.before_20260530_164754" "frontend/src/portal-os/portal-os.css"

if [ -f "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1_20260530_164754/backup/workingPagesRegistry.ts.before_20260530_164754" ]; then
  cp -a "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/runtime/quality/TRFMC_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1_20260530_164754/backup/workingPagesRegistry.ts.before_20260530_164754" "frontend/src/portal-os/workingPagesRegistry.ts"
else
  rm -f "frontend/src/portal-os/workingPagesRegistry.ts"
fi

echo "RESTORE_P6A_ACTIVATE_WORKING_REAL_PAGES_DASHBOARD_V1 completato"
