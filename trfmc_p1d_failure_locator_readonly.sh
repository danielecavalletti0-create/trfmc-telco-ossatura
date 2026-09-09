#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

echo "============================================================"
echo "TRFMC_P1D_FAILURE_LOCATOR_READONLY"
echo "No mutation · trova output incompleto e stato sorgenti"
echo "============================================================"

echo
echo "=== 1) P1D DIRECTORIES ==="
find runtime/quality -maxdepth 1 -type d -name 'TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_V1_*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 10 || true

LATEST_DIR="$(find runtime/quality -maxdepth 1 -type d -name 'TRFMC_P1D_RF_PHYSICS_ROUTE_ISOLATION_V1_*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2- || true)"

echo
echo "LATEST_DIR=${LATEST_DIR:-NONE}"

if [ -n "${LATEST_DIR:-}" ] && [ -d "$LATEST_DIR" ]; then
  echo
  echo "=== 2) LATEST_DIR CONTENT ==="
  find "$LATEST_DIR" -maxdepth 2 -type f -printf '%p\t%s bytes\n' | sort | sed -n '1,160p'

  echo
  echo "=== 3) SUMMARY IF PRESENT ==="
  if [ -f "$LATEST_DIR/summary.json" ]; then
    cat "$LATEST_DIR/summary.json" | python3 -m json.tool
  else
    echo "summary.json NON PRESENTE"
  fi

  echo
  echo "=== 4) BUILD LOG TAIL IF PRESENT ==="
  if [ -f "$LATEST_DIR/npm_build_p1d_rf_physics_route_isolation_v1.log" ]; then
    tail -n 120 "$LATEST_DIR/npm_build_p1d_rf_physics_route_isolation_v1.log"
  else
    echo "build log NON PRESENTE"
  fi

  echo
  echo "=== 5) DIFF IF PRESENT ==="
  if [ -f "$LATEST_DIR/p1d_rf_physics_route_isolation.diff" ]; then
    sed -n '1,220p' "$LATEST_DIR/p1d_rf_physics_route_isolation.diff"
  else
    echo "diff NON PRESENTE"
  fi
fi

echo
echo "=== 6) SOURCE MARKER CHECK ==="
grep -RIn \
  "TRFMC P1D RF PHYSICS ROUTE ISOLATION V1 START\|data-trfmc-p1d-route-isolation\|RFPhysicsDomainP1" \
  frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx frontend/src/styles.css 2>/dev/null || true

echo
echo "=== 7) BUILD CURRENT SOURCE ==="
(
  cd frontend
  npm run build
) > /tmp/trfmc_p1d_locator_build.log 2>&1 && echo "BUILD_CURRENT=PASS" || echo "BUILD_CURRENT=FAIL"
tail -n 100 /tmp/trfmc_p1d_locator_build.log

echo
echo "============================================================"
echo "TRFMC_P1D_FAILURE_LOCATOR_READONLY COMPLETATO"
echo "============================================================"
