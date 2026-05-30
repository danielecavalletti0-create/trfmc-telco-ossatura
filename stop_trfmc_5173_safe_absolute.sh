#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONTEND="$BASE/frontend"

echo "============================================================"
echo "CHIUSURA SICURA ASSOLUTA TRFMC / PORTALE 5173"
echo "============================================================"
date
echo "BASE=$BASE"
echo

cd "$BASE"

echo "[1/8] Snapshot leggero stato disco/runtime, senza freeze pesanti..."
mkdir -p runtime/logs runtime/readiness runtime/evidence/pcap runtime/evidence/iq runtime/evidence/logs runtime/evidence/reports

{
  echo "timestamp=$(date -Iseconds)"
  echo "base=$BASE"
  echo
  echo "=== DISK ==="
  df -h .
  echo
  echo "=== RUNTIME SIZE ==="
  du -h --max-depth=2 runtime 2>/dev/null | sort -h | tail -n 80 || true
  echo
  echo "=== PORTS BEFORE STOP ==="
  ss -ltnp 2>/dev/null | grep -E ':(5173|8000|8008|8090|8095)\b' || true
  echo
  echo "=== PROCESSES BEFORE STOP ==="
  ps aux | grep -E 'vite|npm run dev|node .*vite|uvicorn|fastapi|open5gs|nr-gnb|nr-ue|hackrf|tcpdump|tshark' | grep -v grep || true
} > runtime/logs/trfmc_shutdown_precheck_$(date +%Y%m%d_%H%M%S).log

echo "OK: snapshot leggero creato in runtime/logs/"
echo

echo "[2/8] Fermo Vite / npm dev server su porta 5173 con SIGTERM..."
PIDS_5173="$(lsof -ti tcp:5173 2>/dev/null || true)"

if [ -n "$PIDS_5173" ]; then
  echo "$PIDS_5173" | xargs -r kill -TERM
  sleep 3
else
  echo "Nessun processo trovato su porta 5173"
fi

echo

echo "[3/8] Fermo eventuali processi Vite/NPM rimasti nel progetto TRFMC..."
ps -eo pid,ppid,cmd | grep "$BASE" | grep -E 'npm run dev|vite|node .*vite' | grep -v grep | awk '{print $1}' | sort -u | while read -r pid; do
  [ -n "$pid" ] || continue
  echo "SIGTERM project vite/npm PID=$pid"
  kill -TERM "$pid" 2>/dev/null || true
done

sleep 2
echo

echo "[4/8] Fermo eventuali FastAPI/Uvicorn del progetto solo se legati a TRFMC..."
ps -eo pid,ppid,cmd | grep "$BASE" | grep -E 'uvicorn|fastapi|main_engine|backend' | grep -v grep | awk '{print $1}' | sort -u | while read -r pid; do
  [ -n "$pid" ] || continue
  echo "SIGTERM project backend PID=$pid"
  kill -TERM "$pid" 2>/dev/null || true
done

sleep 2
echo

echo "[5/8] Stop controllato 5G lab se esiste uno script locale di stop..."
if [ -x "$BASE/bin/5g-stop.sh" ]; then
  echo "Eseguo: $BASE/bin/5g-stop.sh"
  "$BASE/bin/5g-stop.sh" || true
elif [ -x "$HOME/bin/5g-stop.sh" ]; then
  echo "Eseguo: $HOME/bin/5g-stop.sh"
  "$HOME/bin/5g-stop.sh" || true
else
  echo "Nessuno script 5g-stop.sh trovato/eseguibile. Non forzo Open5GS/UERANSIM globali."
fi

echo

echo "[6/8] Fermo eventuali acquisizioni residue legate al lab: hackrf/tcpdump/tshark..."
ps -eo pid,ppid,cmd | grep -E 'hackrf_transfer|hackrf_sweep|tcpdump|tshark' | grep -E 'trfmc|runtime/evidence|hackrf_lab_portal|5173|8008' | grep -v grep | awk '{print $1}' | sort -u | while read -r pid; do
  [ -n "$pid" ] || continue
  echo "SIGTERM capture/tool PID=$pid"
  kill -TERM "$pid" 2>/dev/null || true
done

sleep 2
echo

echo "[7/8] Verifica porte principali..."
for port in 5173 8000 8008 8090 8095; do
  if lsof -ti tcp:$port >/dev/null 2>&1; then
    echo "ATTENZIONE: porta $port ancora occupata da:"
    lsof -nP -iTCP:$port -sTCP:LISTEN || true
  else
    echo "OK: porta $port libera"
  fi
done

echo

echo "[8/8] Verifica residui critici..."
RESIDUAL="$(ps aux | grep -E 'vite|npm run dev|node .*vite|uvicorn|fastapi|hackrf_transfer|hackrf_sweep|tcpdump|tshark' | grep -E 'trfmc|5173|8008|runtime/evidence|hackrf_lab_portal' | grep -v grep || true)"

if [ -n "$RESIDUAL" ]; then
  echo "ATTENZIONE: residui trovati:"
  echo "$RESIDUAL"
  echo
  echo "Non uso kill -9 automaticamente. Se vuoi forzare, esegui il blocco di emergenza separato."
else
  echo "OK: nessun processo residuo critico TRFMC/HackRF trovato"
fi

echo
echo "=== STATO DISCO FINALE ==="
df -h .
echo
du -h --max-depth=2 runtime 2>/dev/null | sort -h | tail -n 40 || true

echo
echo "============================================================"
echo "CHIUSURA SICURA TRFMC COMPLETATA"
echo "============================================================"
