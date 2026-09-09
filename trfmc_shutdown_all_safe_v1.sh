#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/shutdown/TRFMC_SHUTDOWN_$TS"

mkdir -p "$OUT" "$BASE/runtime/shutdown" "$BASE/runtime/logs"

echo "============================================================"
echo "TRFMC SHUTDOWN ALL SAFE V1"
echo "chiusura frontend/backend/5G lab senza cancellare dati"
echo "============================================================"

cd "$BASE"

echo
echo "[1/8] Stato PRIMA della chiusura"
{
  echo "=== DATE ==="
  date
  echo
  echo "=== PORTS ==="
  ss -ltnup 2>/dev/null | egrep '(:5173|:8000|:8080|:38412|:8805|:2152|:7777)' || true
  echo
  echo "=== PROCESSES ==="
  ps -eo pid,ppid,comm,args --sort=start_time | egrep 'vite|node|uvicorn|python3 -m http.server|python -m http.server|open5gs|nr-gnb|nr-ue|UERANSIM|trfmc|5g' | grep -v egrep || true
} | tee "$OUT/before.txt"

echo
echo "[2/8] Stop eventuali systemd user services TRFMC/5G"
if command -v systemctl >/dev/null 2>&1; then
  for SVC in \
    trfmc.service \
    trfmc-frontend.service \
    trfmc-backend.service \
    5g-portal-frontend.service \
    5g-portal-backend.service \
    5g-lab.service
  do
    if systemctl --user list-unit-files "$SVC" >/dev/null 2>&1; then
      echo "Stop user service: $SVC"
      systemctl --user stop "$SVC" 2>/dev/null || true
    fi
  done
else
  echo "systemctl non disponibile"
fi

echo
echo "[3/8] Stop porte principali: 5173, 8000, 8080"
for P in 5173 8000 8080; do
  PIDS="$(lsof -ti tcp:$P 2>/dev/null || true)"
  if [ -n "$PIDS" ]; then
    echo "TERM porta $P: $PIDS"
    kill $PIDS 2>/dev/null || true
  else
    echo "Porta $P già libera"
  fi
done

sleep 3

echo
echo "[4/8] Stop processi portale residui"
PATTERNS=(
  "vite --host 127.0.0.1 --port 5173"
  "node.*vite"
  "uvicorn.*8000"
  "core_live_standalone_server"
  "python3 -m http.server 5173"
  "python3 -m http.server 8080"
)

for PAT in "${PATTERNS[@]}"; do
  PIDS="$(pgrep -af "$PAT" | awk '{print $1}' | tr '\n' ' ' || true)"
  if [ -n "$PIDS" ]; then
    echo "TERM pattern [$PAT]: $PIDS"
    kill $PIDS 2>/dev/null || true
  fi
done

sleep 3

echo
echo "[5/8] Stop 5G lab opzionale: Open5GS / UERANSIM / script"
# Prima usa eventuale script ufficiale se presente.
if [ -x "$BASE/bin/5g-stop.sh" ]; then
  echo "Eseguo bin/5g-stop.sh"
  "$BASE/bin/5g-stop.sh" > "$OUT/5g-stop.log" 2>&1 || true
else
  echo "bin/5g-stop.sh non presente/eseguibile, procedo con stop processi 5G eventuali"
fi

# Stop processi 5G se ancora presenti.
for PAT in \
  "open5gs-" \
  "nr-gnb" \
  "nr-ue" \
  "nr-cli"
do
  PIDS="$(pgrep -af "$PAT" | awk '{print $1}' | tr '\n' ' ' || true)"
  if [ -n "$PIDS" ]; then
    echo "TERM 5G pattern [$PAT]: $PIDS"
    kill $PIDS 2>/dev/null || true
  fi
done

sleep 3

echo
echo "[6/8] Kill forzato SOLO se qualcosa è rimasto sulle porte critiche"
for P in 5173 8000 8080; do
  PIDS="$(lsof -ti tcp:$P 2>/dev/null || true)"
  if [ -n "$PIDS" ]; then
    echo "KILL porta $P ancora occupata: $PIDS"
    kill -9 $PIDS 2>/dev/null || true
  else
    echo "Porta $P libera dopo TERM"
  fi
done

echo
echo "[7/8] Stato DOPO la chiusura"
{
  echo "=== PORTS AFTER ==="
  ss -ltnup 2>/dev/null | egrep '(:5173|:8000|:8080|:38412|:8805|:2152|:7777)' || true
  echo
  echo "=== PROCESSES AFTER ==="
  ps -eo pid,ppid,comm,args --sort=start_time | egrep 'vite|node|uvicorn|python3 -m http.server|python -m http.server|open5gs|nr-gnb|nr-ue|UERANSIM|trfmc|5g' | grep -v egrep || true
  echo
  echo "=== MEMORY ==="
  free -h
  echo
  echo "=== DISK ==="
  df -h "$BASE" 2>/dev/null || df -h
} | tee "$OUT/after.txt"

echo
echo "[8/8] Summary"
python3 - <<PY
import json
from pathlib import Path
from datetime import datetime, timezone

out = Path("$OUT")
after = (out / "after.txt").read_text(errors="ignore")

critical_ports = [":5173", ":8000", ":8080"]
still_ports = [p for p in critical_ports if p in after]

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "report": str(out),
    "frontend_5173_closed": ":5173" not in after,
    "backend_8000_closed": ":8000" not in after,
    "static_8080_closed": ":8080" not in after,
    "critical_ports_still_open": still_ports,
    "result": "PASS" if not still_ports else "WARN"
}

(out / "summary.json").write_text(json.dumps(data, indent=4) + "\n")
print(json.dumps(data, indent=4))
PY

echo
echo "============================================================"
echo "CHIUSURA COMPLETATA"
echo "Report:"
echo "$OUT"
echo
echo "Summary:"
cat "$OUT/summary.json" | python3 -m json.tool
echo "============================================================"
