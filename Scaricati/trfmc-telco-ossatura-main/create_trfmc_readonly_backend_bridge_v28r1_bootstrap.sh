#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"
TS="$(date +%Y%m%d_%H%M%S)"
VENV="$ROOT/.venv_trfmc_backend_v28"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_READONLY_BACKEND_BRIDGE_V28R1_BOOTSTRAP_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_READONLY_BACKEND_BRIDGE_V28R1_BOOTSTRAP_$TS"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/logs"

echo "============================================================"
echo "TRFMC READ-ONLY BACKEND BRIDGE V28R1 BOOTSTRAP"
echo "Fix missing fastapi/uvicorn · project venv · rerun V28"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f "$ROOT/create_trfmc_readonly_backend_bridge_v28.sh" || {
  echo "ERRORE: create_trfmc_readonly_backend_bridge_v28.sh mancante"
  exit 1
}

test -f "$ROOT/runtime/quality/latest_portal_contract_audit_v27/summary.json" || {
  echo "ERRORE: V27 summary mancante"
  exit 1
}

echo "OK: script V28 e V27 presenti"

echo
echo "=== CREA / VERIFICA VENV ==="

if [ ! -x "$VENV/bin/python" ]; then
  if ! python3 -m venv "$VENV"; then
    echo
    echo "ERRORE: python3 -m venv non disponibile."
    echo "Installa il supporto venv e rilancia:"
    echo "sudo apt update && sudo apt install -y python3-venv python3-pip"
    exit 1
  fi
fi

"$VENV/bin/python" -m pip install --upgrade pip setuptools wheel

echo
echo "=== INSTALL FASTAPI + UVICORN NELLA VENV ==="

"$VENV/bin/python" -m pip install "fastapi[standard-no-fastapi-cloud-cli]"

echo
echo "=== VERIFY MODULES ==="

"$VENV/bin/python" - <<'PY'
import fastapi
import uvicorn
print("OK: fastapi", fastapi.__version__)
print("OK: uvicorn", uvicorn.__version__)
PY

echo
echo "=== STOP EVENTUALE BACKEND 8000 PARZIALE ==="

pkill -f "backend.readonly_bridge_v28.app:app" 2>/dev/null || true
sleep 1

echo
echo "=== RILANCIO V28 CON PATH VENV ==="

(
  export PATH="$VENV/bin:$PATH"
  ./create_trfmc_readonly_backend_bridge_v28.sh
) | tee "$RELEASE_DIR/v28_rerun_output.txt"

echo
echo "=== PATCH START SCRIPT PER USARE SEMPRE LA VENV ==="

if [ -f "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh" ]; then
  cp "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh" \
     "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh.bak_v28r1_$TS"

  sed -i \
    's#nohup python3 -m uvicorn#nohup "$ROOT/.venv_trfmc_backend_v28/bin/python" -m uvicorn#' \
    "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh"

  chmod +x "$ROOT/runtime/bin/trfmc_readonly_backend_v28_start_8000.sh"
else
  echo "WARN: start script V28 non trovato dopo rerun"
fi

echo
echo "=== TEST DIRECT 8000 / PROXY 4181 ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

for base in http://127.0.0.1:8000 http://127.0.0.1:4181
do
  probe "$base/api/health"
  probe "$base/api/mission/status"
  probe "$base/api/core/open5gs/status"
  probe "$base/api/ran/ueransim/status"
  probe "$base/api/network-fabric/overview"
  probe "$base/api/rf-coverage/demo"
  probe "$base/api/rf-field/demo"
  probe "$base/api/telco-mns/status"
  probe "$base/api/evidence/index"
  probe "$base/api/restricted/status"
done

column -t -s $'\t' "$HTTP_TSV"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_READONLY_BACKEND_BRIDGE_V28R1_BOOTSTRAP",
  "venv": "$VENV",
  "backend_url": "http://127.0.0.1:8000/",
  "proxy_url": "http://127.0.0.1:4181/",
  "http_tsv": "$HTTP_TSV",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_readonly_backend_bridge_v28r1_bootstrap"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_readonly_backend_bridge_v28r1_bootstrap"

echo
echo "=== SUMMARY V28R1 ==="
cat "$QUALITY_DIR/summary.json" | python3 -m json.tool

echo
echo "============================================================"
echo "V28R1 BOOTSTRAP COMPLETATO"
echo "============================================================"
