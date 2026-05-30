#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/recovery/POST_CRASH_SAFE_$TS"

mkdir -p "$OUT" "$BASE/runtime/logs" "$BASE/runtime/recovery" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC POST-CRASH RECOVERY SAFE V1"
echo "nessuna discovery pesante · nessun find massivo · nessun avvio 5G automatico"
echo "============================================================"

cd "$BASE"

echo
echo "[1/9] Stato macchina"
{
  echo "=== DATE ==="
  date
  echo
  echo "=== UPTIME ==="
  uptime
  echo
  echo "=== FREE ==="
  free -h
  echo
  echo "=== DISK ==="
  df -h
  echo
  echo "=== LOAD / CPU ==="
  nproc
  cat /proc/loadavg
} | tee "$OUT/system_status.txt"

echo
echo "[2/9] Kernel crash/OOM/GPU/filesystem hints"
{
  echo "=== DMESG CRITICAL ==="
  dmesg -T 2>/dev/null | egrep -i 'oom|killed process|segfault|panic|watchdog|gpu|nvidia|i915|amdgpu|ext4|btrfs|nvme|i/o error|thermal|overheat|reset' || true
} | tee "$OUT/dmesg_critical.txt"

echo
echo "[3/9] Journal boot precedente e boot corrente"
{
  echo "=== JOURNAL PREVIOUS BOOT WARNINGS ==="
  journalctl -b -1 -p warning..alert --no-pager 2>/dev/null | tail -n 300 || true
  echo
  echo "=== JOURNAL CURRENT BOOT WARNINGS ==="
  journalctl -b 0 -p warning..alert --no-pager 2>/dev/null | tail -n 300 || true
} | tee "$OUT/journal_boot_warnings.txt"

echo
echo "[4/9] Processi e porte TRFMC residue"
{
  echo "=== PROCESSES ==="
  ps -eo pid,ppid,comm,args --sort=start_time | egrep 'vite|node|uvicorn|python|open5gs|nr-gnb|nr-ue|UERANSIM|trfmc|5g' | grep -v egrep || true
  echo
  echo "=== PORTS ==="
  ss -ltnup 2>/dev/null | egrep '(:5173|:8000|:8080|:38412|:8805|:2152|:7777)' || true
} | tee "$OUT/process_ports_before.txt"

echo
echo "[5/9] Stop controllato solo dei servizi portale, non del sistema"
for P in 5173 8000 8080; do
  PIDS="$(lsof -ti tcp:$P 2>/dev/null || true)"
  if [ -n "$PIDS" ]; then
    echo "Porta $P occupata da: $PIDS"
    kill $PIDS 2>/dev/null || true
  else
    echo "Porta $P libera"
  fi
done

sleep 2

echo
echo "[6/9] Verifico file chiave e freeze disponibili"
{
  echo "=== FILE CHIAVE ==="
  ls -lh frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html 2>/dev/null || true
  ls -lh frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html 2>/dev/null || true
  ls -lh frontend/public/trfmc_core_network_live_ops_bridge_v1.html 2>/dev/null || true
  ls -lh backend/core_live_standalone_server.py 2>/dev/null || true
  echo
  echo "=== ULTIMI FREEZE ==="
  find runtime/freezes -maxdepth 1 -type f -name '*.tar.gz' -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -n 20 || true
  echo
  echo "=== ULTIMI QUALITY REPORT ==="
  find runtime/quality -maxdepth 1 -type l -o -type d 2>/dev/null | sort | tail -n 30 || true
} | tee "$OUT/project_files_freezes.txt"

echo
echo "[7/9] Creo snapshot leggero post-crash"
FREEZE="$BASE/runtime/freezes/TRFMC_POST_CRASH_SAFE_SNAPSHOT_$TS.tar.gz"

tar -czf "$FREEZE" \
  --exclude='frontend/node_modules' \
  --exclude='frontend/dist' \
  --exclude='.venv' \
  --exclude='runtime/freezes' \
  --exclude='runtime/collaudo' \
  --exclude='runtime/recovery' \
  -C "$BASE" . 2>"$OUT/tar_errors.txt" || true

ls -lh "$FREEZE" | tee "$OUT/snapshot_created.txt"

echo
echo "[8/9] Riavvio SOLO frontend Vite 5173"
if [ -d "$BASE/frontend" ]; then
  nohup bash -lc "
    cd '$BASE/frontend'
    npm run dev -- --host 127.0.0.1 --port 5173
  " > "$BASE/runtime/logs/frontend_5173_post_crash.log" 2>&1 &
else
  echo "WARN: frontend directory non trovata"
fi

sleep 6

echo
echo "[9/9] HTTP gate minimo, senza backend Core Live"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html \
    /trfmc_core_network_live_ops_bridge_v1.html \
    /vendor/three/build/three.module.js
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" || echo "000 0")
    echo -e "$u\t$code\t$bytes"
  done
} | tee "$OUT/http_frontend_gate.tsv"

echo
echo "============================================================"
echo "RECOVERY SAFE COMPLETATO"
echo "Report:"
echo "$OUT"
echo
echo "Snapshot:"
echo "$FREEZE"
echo
echo "Apri SOLO dopo aver letto il gate:"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
echo "============================================================"
