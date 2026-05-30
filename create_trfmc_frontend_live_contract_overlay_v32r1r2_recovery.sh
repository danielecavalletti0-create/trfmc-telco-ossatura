#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1R2_RECOVERY_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1R2_RECOVERY_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1R2_RECOVERY_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"
STYLES="$ROOT/frontend/src/styles.css"
CLIENT="$ROOT/frontend/src/shared/liveContractsV32R1.ts"
PANEL="$ROOT/frontend/src/rf_instruments/telemetry/RFLiveContractStatusV32R1.tsx"
WRAPPER="$ROOT/frontend/src/rf_instruments/instruments/RFOperationalDeckV32R1LiveContracts.tsx"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes"

echo "============================================================"
echo "TRFMC V32R1R2 FRONTEND LIVE CONTRACT OVERLAY RECOVERY"
echo "evidence recovery · build validation · no backend/nginx/systemd mutation"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || { echo "ERRORE: main.tsx mancante"; exit 1; }
test -f "$STYLES" || { echo "ERRORE: styles.css mancante"; exit 1; }
test -f "$CLIENT" || { echo "ERRORE: liveContractsV32R1.ts mancante"; exit 1; }
test -f "$PANEL" || { echo "ERRORE: RFLiveContractStatusV32R1.tsx mancante"; exit 1; }
test -f "$WRAPPER" || { echo "ERRORE: RFOperationalDeckV32R1LiveContracts.tsx mancante"; exit 1; }

grep -q "RFOperationalDeckV32R1LiveContracts" "$MAIN" || {
  echo "ERRORE: main.tsx non monta V32R1 wrapper"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/bandplan | grep -q "TRFMC_CONTRACT_COVERAGE_V31" || {
  echo "ERRORE: API V31 non raggiungibile via 4181"
  exit 1
}

echo "OK: patch V32R1 presente e API live raggiungibile"

echo
echo "=== BACKUP CURRENT FRONTEND STATE ==="

cp "$MAIN" "$RELEASE_DIR/main.tsx.before_v32r1r2_$TS"
cp "$STYLES" "$RELEASE_DIR/styles.css.before_v32r1r2_$TS"
cp "$PANEL" "$RELEASE_DIR/RFLiveContractStatusV32R1.tsx.before_v32r1r2_$TS"
cp "$WRAPPER" "$RELEASE_DIR/RFOperationalDeckV32R1LiveContracts.tsx.before_v32r1r2_$TS"
cp "$CLIENT" "$RELEASE_DIR/liveContractsV32R1.ts.before_v32r1r2_$TS"

echo
echo "=== TYPESCRIPT HYGIENE: REMOVE UNUSED DEFAULT REACT IMPORTS ==="

python3 - "$PANEL" "$WRAPPER" <<'PY'
from pathlib import Path
import sys

for raw in sys.argv[1:]:
    p = Path(raw)
    txt = p.read_text(encoding="utf-8")

    original = txt

    txt = txt.replace(
        "import React, { useEffect, useMemo, useState } from 'react'",
        "import { useEffect, useMemo, useState } from 'react'",
    )

    txt = txt.replace(
        'import React, { useEffect, useMemo, useState } from "react"',
        'import { useEffect, useMemo, useState } from "react"',
    )

    txt = txt.replace("import React from 'react'\n", "")
    txt = txt.replace('import React from "react"\n', "")

    if txt != original:
        p.write_text(txt, encoding="utf-8")
        print(f"OK: cleaned {p}")
    else:
        print(f"OK: no cleanup needed {p}")
PY

echo
echo "=== STATIC CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

{
  test -f "$CLIENT" && echo "OK: live contract client exists" || echo "MISS: live contract client exists"
  test -f "$PANEL" && echo "OK: live contract panel exists" || echo "MISS: live contract panel exists"
  test -f "$WRAPPER" && echo "OK: V32R1 wrapper exists" || echo "MISS: V32R1 wrapper exists"

  grep -q "RFOperationalDeckV32R1LiveContracts" "$MAIN" && echo "OK: main imports/mounts V32R1" || echo "MISS: main imports/mounts V32R1"
  grep -q "<RFOperationalDeckV32R1LiveContracts />" "$MAIN" && echo "OK: main JSX mount V32R1" || echo "MISS: main JSX mount V32R1"

  grep -q "http://127.0.0.1:4181" "$CLIENT" && echo "OK: dev API base 4181" || echo "MISS: dev API base 4181"
  grep -q "/api/mission/status" "$CLIENT" && echo "OK: mission endpoint bound" || echo "MISS: mission endpoint bound"
  grep -q "/api/core/open5gs/status" "$CLIENT" && echo "OK: open5gs endpoint bound" || echo "MISS: open5gs endpoint bound"
  grep -q "/api/ran/ueransim/status" "$CLIENT" && echo "OK: ueransim endpoint bound" || echo "MISS: ueransim endpoint bound"
  grep -q "/api/rfpro/bandplan" "$CLIENT" && echo "OK: bandplan endpoint bound" || echo "MISS: bandplan endpoint bound"
  grep -q "/api/rfpro/spectrum/sweep" "$CLIENT" && echo "OK: spectrum endpoint bound" || echo "MISS: spectrum endpoint bound"
  grep -q "/api/soc-noc/correlation/demo" "$CLIENT" && echo "OK: soc/noc endpoint bound" || echo "MISS: soc/noc endpoint bound"

  grep -q "v32r1-live-contract-shell" "$STYLES" && echo "OK: V32R1 CSS present" || echo "MISS: V32R1 CSS present"

  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" && echo "OK: live mission API reachable" || echo "MISS: live mission API reachable"
  curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/rfpro/spectrum/sweep | grep -q "TRFMC_CONTRACT_COVERAGE_V31" && echo "OK: live spectrum contract reachable" || echo "MISS: live spectrum contract reachable"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

echo
echo "=== BUILD CHECK ==="

BUILD_LOG="$RELEASE_DIR/npm_build_v32r1r2.log"
BUILD_RESULT="SKIPPED"

if [ -f "$ROOT/frontend/package.json" ]; then
  (
    cd "$ROOT/frontend"
    npm run build > "$BUILD_LOG" 2>&1
  ) && BUILD_RESULT="PASS" || BUILD_RESULT="FAIL"
else
  BUILD_RESULT="NO_PACKAGE_JSON"
  echo "NO_PACKAGE_JSON" > "$BUILD_LOG"
fi

echo "Build result: $BUILD_RESULT"

if [ "$BUILD_RESULT" = "FAIL" ]; then
  echo
  echo "=== BUILD LOG TAIL ==="
  tail -n 160 "$BUILD_LOG" || true
fi

echo
echo "=== LIVE API SAMPLE CAPTURE ==="

mkdir -p "$RELEASE_DIR/samples"

for ep in \
  /api/mission/status \
  /api/core/open5gs/status \
  /api/ran/ueransim/status \
  /api/rfpro/bandplan \
  /api/rfpro/spectrum/sweep \
  /api/soc-noc/correlation/demo
do
  safe="$(echo "$ep" | sed 's#/#_#g' | sed 's/^_//')"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181$ep" \
    | python3 -m json.tool > "$RELEASE_DIR/samples/${safe}.json"
done

RESULT="PASS"
if [ "$MISS_COUNT" -ne 0 ] || [ "$BUILD_RESULT" = "FAIL" ]; then
  RESULT="FAIL"
fi

echo
echo "=== CREATE ROLLBACK ==="

ROLLBACK="$RELEASE_DIR/rollback_v32r1r2_recovery.sh"

cat > "$ROLLBACK" <<ROLLBACK_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"

cp "$RELEASE_DIR/main.tsx.before_v32r1r2_$TS" frontend/src/app/main.tsx
cp "$RELEASE_DIR/styles.css.before_v32r1r2_$TS" frontend/src/styles.css
cp "$RELEASE_DIR/RFLiveContractStatusV32R1.tsx.before_v32r1r2_$TS" frontend/src/rf_instruments/telemetry/RFLiveContractStatusV32R1.tsx
cp "$RELEASE_DIR/RFOperationalDeckV32R1LiveContracts.tsx.before_v32r1r2_$TS" frontend/src/rf_instruments/instruments/RFOperationalDeckV32R1LiveContracts.tsx
cp "$RELEASE_DIR/liveContractsV32R1.ts.before_v32r1r2_$TS" frontend/src/shared/liveContractsV32R1.ts

echo "Rollback V32R1R2 completato"
ROLLBACK_EOF

chmod +x "$ROLLBACK"

echo
echo "=== MANIFEST / SUMMARY ==="

MANIFEST="$RELEASE_DIR/frontend_live_contract_overlay_recovery_manifest_v32r1r2.json"
SUMMARY="$QUALITY_DIR/summary.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1R2_RECOVERY",
  "reason": "V32R1 frontend patch existed but latest quality summary symlink was missing.",
  "frontend_mutation": true,
  "backend_mutation": false,
  "dist_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "typescript_hygiene": "removed unused default React imports when present",
  "api_binding": {
    "dev_base": "http://127.0.0.1:4181",
    "endpoints": [
      "/api/mission/status",
      "/api/core/open5gs/status",
      "/api/ran/ueransim/status",
      "/api/rfpro/bandplan",
      "/api/rfpro/spectrum/sweep",
      "/api/soc-noc/correlation/demo"
    ]
  },
  "files": {
    "client": "$CLIENT",
    "panel": "$PANEL",
    "wrapper": "$WRAPPER",
    "main": "$MAIN",
    "styles": "$STYLES"
  },
  "rollback": "$ROLLBACK",
  "miss_count": $MISS_COUNT,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FRONTEND_LIVE_CONTRACT_OVERLAY_V32R1R2_RECOVERY",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "content_checks": "$CONTENT_CHECK",
  "build_log": "$BUILD_LOG",
  "rollback": "$ROLLBACK",
  "miss_count": $MISS_COUNT,
  "build_result": "$BUILD_RESULT",
  "result": "$RESULT"
}
JSON

tar -czf "$FREEZE" \
  frontend/src/app/main.tsx \
  frontend/src/styles.css \
  frontend/src/shared/liveContractsV32R1.ts \
  frontend/src/rf_instruments/telemetry/RFLiveContractStatusV32R1.tsx \
  frontend/src/rf_instruments/instruments/RFOperationalDeckV32R1LiveContracts.tsx \
  "$RELEASE_DIR" \
  "$SUMMARY" \
  2>/dev/null || true

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_frontend_live_contract_overlay_v32r1"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_frontend_live_contract_overlay_v32r1"

cat "$SUMMARY" | python3 -m json.tool

if [ "$RESULT" != "PASS" ]; then
  echo
  echo "ATTENZIONE: risultato $RESULT"
  echo "Rollback disponibile:"
  echo "$ROLLBACK"
  exit 1
fi

echo
echo "============================================================"
echo "V32R1R2 RECOVERY COMPLETATO IN PASS"
echo "============================================================"
