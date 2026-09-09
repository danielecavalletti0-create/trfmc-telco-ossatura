#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RUNTIME_RECOVER_VITE_5173_AFTER_P4G_$TS"
LOG="$OUT/vite_5173_runtime.log"
HTTP="$OUT/http_after_vite_recover.tsv"
SUMMARY="$OUT/summary.json"

mkdir -p "$OUT"
cd "$BASE"

echo "============================================================"
echo "TRFMC_RUNTIME_RECOVER_VITE_5173_AFTER_P4G"
echo "No source mutation · restart/check Vite on 127.0.0.1:5173"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) CHECK ATTUALE PORTA 5173 ==="
ss -ltnp 2>/dev/null | grep ':5173' || true

PID_5173="$(ss -ltnp 2>/dev/null | awk '/:5173/ {print $NF}' | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | head -n 1 || true)"
echo "PID_5173=${PID_5173:-NONE}"

echo
echo "=== 2) SE 5173 NON ASCOLTA, AVVIO VITE ==="

if [ -z "${PID_5173:-}" ]; then
  echo "Vite non ascolta su 5173: avvio dev server"
  cd "$BASE/frontend"

  nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$LOG" 2>&1 &
  VITE_PID="$!"
  echo "VITE_PID=$VITE_PID"

  cd "$BASE"
else
  echo "5173 già occupata da PID=$PID_5173, non avvio un secondo Vite"
  VITE_PID="$PID_5173"
fi

echo
echo "=== 3) WAIT FINO A 20s PER 5173 ==="

UP="NO"
for i in $(seq 1 20); do
  if curl -sS --max-time 2 -o /tmp/trfmc_vite_check.html -w "%{http_code}" http://127.0.0.1:5173/ | grep -q '^200$'; then
    UP="YES"
    break
  fi
  sleep 1
done

echo "VITE_UP=$UP"

echo
echo "=== 4) LOG VITE HEAD/TAIL ==="
if [ -f "$LOG" ]; then
  echo "--- LOG HEAD ---"
  sed -n '1,80p' "$LOG"
  echo "--- LOG TAIL ---"
  tail -n 80 "$LOG"
else
  echo "LOG non creato perché Vite era già attivo oppure avvio non partito"
fi

echo
echo "=== 5) HTTP ROUTE GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4"
check_url "http://127.0.0.1:5173/#signal-analyzer"
check_url "http://127.0.0.1:5173/#antenna-system"
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

RESULT="PASS"
if [ "$UP" != "YES" ]; then RESULT="VITE_5173_NOT_RUNNING"; fi
if [ "$HTTP_NON_200" != "0" ]; then RESULT="REVIEW_HTTP_NON_200"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_ZERO_BYTES"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RUNTIME_RECOVER_VITE_5173_AFTER_P4G",
  "mutation": false,
  "source_mutation": false,
  "vite_pid": "$VITE_PID",
  "vite_up": "$UP",
  "vite_log": "$LOG",
  "http_tsv": "$HTTP",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_runtime_recover_vite_5173_after_p4g"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_RUNTIME_RECOVER_VITE_5173_AFTER_P4G COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
