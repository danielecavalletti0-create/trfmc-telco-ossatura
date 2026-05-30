#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONTEND="$BASE/frontend"
LOGDIR="$BASE/runtime/logs"

echo "============================================================"
echo "ACCENSIONE SICURA TRFMC / PORTALE 5173"
echo "============================================================"
date
echo "BASE=$BASE"
echo

cd "$BASE"

mkdir -p "$LOGDIR" runtime/readiness runtime/evidence/pcap runtime/evidence/iq runtime/evidence/logs runtime/evidence/reports

echo "[1/8] Disk guard..."
FREE_GB="$(df -BG "$BASE" | awk 'NR==2 {gsub("G","",$4); print $4}')"
df -h "$BASE"

if [ "${FREE_GB:-0}" -lt 2 ]; then
  echo "ERRORE: spazio libero sotto 2GB. Non accendo il portale per evitare blocchi."
  exit 1
fi

echo
echo "[2/8] Verifico porta 5173..."
if lsof -ti tcp:5173 >/dev/null 2>&1; then
  echo "Porta 5173 già occupata:"
  lsof -nP -iTCP:5173 -sTCP:LISTEN || true
  echo

  if curl -s --max-time 3 http://127.0.0.1:5173/api/health | grep -q '"service": "trfmc-portal"'; then
    echo "OK: TRFMC sembra già acceso correttamente su 5173. Non riavvio."
  else
    echo "ATTENZIONE: 5173 occupata ma non riconosco health TRFMC."
    echo "Non forzo kill automatico. Spegni il processo anomalo prima di riaccendere."
    exit 1
  fi
else
  echo "OK: porta 5173 libera."
  echo
  echo "[3/8] Avvio Vite TRFMC su 127.0.0.1:5173 con strictPort..."
  cd "$FRONTEND"
  nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort \
    > "$LOGDIR/frontend_5173.log" 2>&1 &
  echo "PID avvio: $!"
  cd "$BASE"
  sleep 5
fi

echo
echo "[4/8] Health check portale..."
curl -s --max-time 5 http://127.0.0.1:5173/api/health | python3 -m json.tool

echo
echo "[5/8] Rigenero readiness snapshot se lo script esiste..."
if [ -x "$BASE/trfmc_runtime_readiness_check_v1.sh" ]; then
  "$BASE/trfmc_runtime_readiness_check_v1.sh" || true
else
  echo "WARN: trfmc_runtime_readiness_check_v1.sh non trovato/eseguibile."
fi

echo
echo "[6/8] HTTP light check pagine principali..."
for url in \
  http://127.0.0.1:5173/ \
  http://127.0.0.1:5173/trfmc_enterprise_prime_portal_v1.html \
  http://127.0.0.1:5173/trfmc_runtime_hook_layer_v1.html \
  http://127.0.0.1:5173/trfmc_safe_runtime_action_console_v1.html \
  http://127.0.0.1:5173/trfmc_converged_rf_5g_noc_v1.html \
  http://127.0.0.1:5173/trfmc_5g_core_ran_identity_aka_engine_v1.html \
  http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html \
  http://127.0.0.1:5173/api/health
do
  echo -n "$url -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "$url"
done

echo
echo "[7/8] Stato porta 5173..."
lsof -nP -iTCP:5173 -sTCP:LISTEN || true

echo
echo "[8/8] Stato disco/runtime..."
df -h "$BASE"
du -h --max-depth=2 "$BASE/runtime" 2>/dev/null | sort -h | tail -n 40

echo
echo "============================================================"
echo "ACCENSIONE COMPLETATA"
echo "URL PRINCIPALE:"
echo "http://127.0.0.1:5173/"
echo "============================================================"
