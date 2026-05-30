#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$BASE"

TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p runtime/shutdown runtime/freezes runtime/logs

echo "============================================================"
echo "TRFMC SAFE SHUTDOWN - $TS"
echo "============================================================"

echo
echo "[1] Snapshot leggero"
sudo ss -ltnp | grep -E ':5173|:5174|:8000|:8080|:8081|:8090|:8095' > "runtime/shutdown/pre_shutdown_ports_$TS.txt" 2>/dev/null || true
ps aux | grep -Ei 'vite|node|uvicorn|python3 -m http.server|trfmc|open5gs|nr-gnb|nr-ue|UERANSIM' | grep -v grep > "runtime/shutdown/pre_shutdown_processes_$TS.txt" 2>/dev/null || true

tar -czf "runtime/freezes/TRFMC_PRE_SHUTDOWN_LIGHT_$TS.tar.gz" \
  frontend/public/trfmc_portal_registry_unified.json \
  runtime/quality \
  runtime/logs \
  2>/dev/null || true

echo
echo "[2] Stop systemd user services"
systemctl --user stop 5g-portal-frontend.service 2>/dev/null || true
systemctl --user stop 5g-portal-backend.service 2>/dev/null || true
systemctl --user stop 5g-lab.service 2>/dev/null || true
systemctl --user stop trfmc-portal-frontend.service 2>/dev/null || true
systemctl --user stop trfmc-portal-backend.service 2>/dev/null || true

echo
echo "[3] Stop 5G/Open5GS/UERANSIM se presente"
if [ -x ./bin/5g-stop.sh ]; then
  ./bin/5g-stop.sh || true
fi

pkill -f 'nr-gnb' 2>/dev/null || true
pkill -f 'nr-ue' 2>/dev/null || true
pkill -f 'UERANSIM' 2>/dev/null || true
pkill -f 'open5gs-' 2>/dev/null || true

echo
echo "[4] Stop porte principali"
for PORT in 5173 5174 8000 8080 8081 8090 8095; do
  PIDS="$(sudo ss -ltnp | grep -E ":$PORT[[:space:]]" | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | sort -u || true)"
  for PID in $PIDS; do
    echo "SIGTERM porta $PORT PID $PID"
    kill "$PID" 2>/dev/null || true
  done
done

sleep 3

for PORT in 5173 5174 8000 8080 8081 8090 8095; do
  PIDS="$(sudo ss -ltnp | grep -E ":$PORT[[:space:]]" | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | sort -u || true)"
  for PID in $PIDS; do
    echo "SIGKILL porta $PORT PID $PID"
    kill -9 "$PID" 2>/dev/null || true
  done
done

echo
echo "[5] Verifica finale"
sudo ss -ltnp | grep -E ':5173|:5174|:8000|:8080|:8081|:8090|:8095' || echo "OK: porte principali spente"
curl -I --max-time 3 http://127.0.0.1:5173 2>/dev/null || echo "OK: HTTP 5173 non risponde"

echo
echo "Snapshot:"
ls -lh "runtime/freezes/TRFMC_PRE_SHUTDOWN_LIGHT_$TS.tar.gz" 2>/dev/null || true

echo
echo "============================================================"
echo "TRFMC SAFE SHUTDOWN COMPLETATO"
echo "Domani ripartiamo da V6R3 + Control Room + registry."
echo "============================================================"
