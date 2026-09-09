#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRFMC STOP PORTALE - SOLO PORTA 5173"
echo "============================================================"
date

PIDS="$(lsof -ti tcp:5173 2>/dev/null || true)"
if [ -n "$PIDS" ]; then
  echo "Fermo processo/i su 5173: $PIDS"
  kill $PIDS 2>/dev/null || true
  sleep 2
else
  echo "Nessun processo attivo su 5173"
fi

echo
echo "=== VERIFICA ==="
ss -ltnp | grep ':5173' || echo "OK: porta 5173 libera"
