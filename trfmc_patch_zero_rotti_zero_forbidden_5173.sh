#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONTEND="$BASE/frontend"
PUBLIC="$FRONTEND/public"
RUNTIME="$BASE/runtime"
TS="$(date +%Y%m%d_%H%M%S)"
PATCHDIR="$RUNTIME/patches/TRFMC_ZERO_ROTTI_ZERO_FORBIDDEN_5173_$TS"

mkdir -p "$PATCHDIR"

echo "============================================================"
echo "TRFMC PATCH ZERO ROTTI / ZERO FORBIDDEN - SOLO 5173"
echo "============================================================"
date
echo "BASE=$BASE"
echo "PATCHDIR=$PATCHDIR"
echo

cd "$BASE"

echo "=== 1) BACKUP SICURO PRE-PATCH ==="
tar -czf "$PATCHDIR/frontend_pre_patch_$TS.tar.gz" \
  --exclude='frontend/node_modules' \
  --exclude='frontend/dist' \
  -C "$BASE" frontend

ls -lh "$PATCHDIR/frontend_pre_patch_$TS.tar.gz"

echo
echo "=== 2) CREO ENDPOINT STATICI MANCANTI /api/docs/index e /api/portal/index ==="
mkdir -p "$PUBLIC/api/docs" "$PUBLIC/api/portal"

cat > "$PUBLIC/api/docs/index" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>TRFMC API Docs Index</title>
<style>
body{margin:0;background:#050812;color:#eaf2ff;font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:32px}
.card{max-width:980px;background:rgba(255,255,255,.06);border:1px solid rgba(130,180,255,.24);border-radius:18px;padding:24px;box-shadow:0 0 32px rgba(0,120,255,.10)}
h1{margin-top:0;color:#9ed0ff}
code{background:rgba(255,255,255,.09);padding:3px 6px;border-radius:6px}
a{color:#9ed0ff}
</style>
</head>
<body>
<div class="card">
<h1>TRFMC — API Docs Index</h1>
<p>Indice locale di servizio del portale TRFMC. Porta ufficiale: <code>5173</code>.</p>
<ul>
<li><a href="/api/health">/api/health</a></li>
<li><a href="/trfmc_collaudo_report.html">Report collaudo portale</a></li>
<li><a href="/trfmc_home_v87g.html">TRFMC Home</a></li>
<li><a href="/rf_physics_sapienza_console_v86a.html">RF Physics Console</a></li>
<li><a href="/webgl_rf_physics_engine_v85e_viewport_discipline.html">WebGL RF Physics Engine</a></li>
</ul>
</div>
</body>
</html>
HTML

cat > "$PUBLIC/api/portal/index" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>TRFMC Portal Index</title>
<style>
body{margin:0;background:#050812;color:#eaf2ff;font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:32px}
.card{max-width:980px;background:rgba(255,255,255,.06);border:1px solid rgba(130,180,255,.24);border-radius:18px;padding:24px;box-shadow:0 0 32px rgba(0,120,255,.10)}
h1{margin-top:0;color:#9ed0ff}
code{background:rgba(255,255,255,.09);padding:3px 6px;border-radius:6px}
a{color:#9ed0ff}
</style>
</head>
<body>
<div class="card">
<h1>TRFMC — Portal Index</h1>
<p>Indice operativo locale del portale. Porta ufficiale: <code>5173</code>.</p>
<ul>
<li><a href="/trfmc_home_v87g.html">Home v87g</a></li>
<li><a href="/trfmc_home.html">Home</a></li>
<li><a href="/trfmc.html">TRFMC</a></li>
<li><a href="/operator_handbook_console_v23.html">Operator Handbook Console</a></li>
<li><a href="/runtime_golden_check_console_v29.html">Runtime Golden Check Console</a></li>
<li><a href="/observability_console_v13.html">Observability Console</a></li>
<li><a href="/trfmc_collaudo_report.html">Report Collaudo</a></li>
</ul>
</div>
</body>
</html>
HTML

echo "OK: endpoint statici creati."

echo
echo "=== 3) BONIFICO RIFERIMENTI HARD-CODED A 8000 E 5174 ==="

python3 - <<'PY'
from pathlib import Path
import re

files = [
    Path("frontend/public/assets/trfmc_enterprise_shell_v34.js"),
    Path("frontend/public/observability_console_v13.html"),
    Path("frontend/src/app/main.tsx"),
    Path("frontend/public/runtime_golden_check_snapshot.json"),
]

for p in files:
    if not p.exists():
        print(f"SKIP non trovato: {p}")
        continue

    original = p.read_text(errors="ignore")
    s = original

    # Testo dashboard/shell: la porta ufficiale è 5173.
    s = s.replace("127.0.0.1:8000", "127.0.0.1:5173")
    s = s.replace("localhost:8000", "localhost:5173")

    # Snapshot: niente path assoluti /runtime dentro public.
    s = s.replace('"/runtime/trfmc.db"', '"runtime/trfmc.db"')
    s = s.replace("'/runtime/trfmc.db'", "'runtime/trfmc.db'")

    # WebSocket: da hardcoded 8000 a stesso host del portale.
    s = s.replace(
        "new WebSocket('ws://127.0.0.1:5173/api/events/stream')",
        "new WebSocket(`${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}/api/events/stream`)"
    )
    s = s.replace(
        'new WebSocket("ws://127.0.0.1:5173/api/events/stream")',
        "new WebSocket(`${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}/api/events/stream`)"
    )

    if s != original:
        backup = p.with_suffix(p.suffix + f".bak_zero_forbidden")
        backup.write_text(original)
        p.write_text(s)
        print(f"PATCHED: {p}")
    else:
        print(f"UNCHANGED: {p}")
PY

echo
echo "=== 4) RISCRIVO vite.config.js IN MODALITÀ PORTALE PURO 5173, SENZA PROXY 5174 ==="

CFG="$FRONTEND/vite.config.js"

if [ -f "$CFG" ]; then
  cp -a "$CFG" "$PATCHDIR/vite.config.js.pre_patch_$TS"
fi

cat > "$CFG" <<'JS'
import { defineConfig } from 'vite'

const trfmcHealthPlugin = {
  name: 'trfmc-health-5173',
  configureServer(server) {
    server.middlewares.use((req, res, next) => {
      if (req.url === '/api/health') {
        res.statusCode = 200
        res.setHeader('Content-Type', 'application/json; charset=utf-8')
        res.end(JSON.stringify({
          ok: true,
          status: 'online',
          service: 'trfmc-portal',
          mode: 'vite-middleware-health',
          portal_port: 5173,
          portal_url: 'http://127.0.0.1:5173',
          architecture: 'single-port-portal',
          message: 'TRFMC portal is alive on port 5173'
        }, null, 2))
        return
      }
      next()
    })
  }
}

export default defineConfig({
  plugins: [trfmcHealthPlugin],
  server: {
    host: '127.0.0.1',
    port: 5173,
    strictPort: true
  }
})
JS

echo "OK: vite.config.js riportato a portale puro 5173."

echo
echo "=== 5) CONTROLLO STATICO POST-PATCH ==="
echo
echo "--- riferimenti a 8000 / 5174 / /runtime ---"
grep -RniE "127\.0\.0\.1:8000|localhost:8000|127\.0\.0\.1:5174|localhost:5174|['\"]?/runtime/" "$FRONTEND" \
  --exclude-dir=node_modules \
  --exclude-dir=dist \
  || true

echo
echo "=== 6) RIAVVIO SOLO VITE 5173 ==="
kill $(lsof -ti tcp:5173) 2>/dev/null || true
sleep 2

cd "$FRONTEND"

nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort \
  > "$BASE/runtime/logs/frontend_5173.log" 2>&1 &

sleep 5

echo
echo "=== 7) TEST FUNZIONALE POST-PATCH ==="
for url in \
  http://127.0.0.1:5173/trfmc_home_v87g.html \
  http://127.0.0.1:5173/rf_physics_sapienza_console_v86a.html \
  http://127.0.0.1:5173/webgl_rf_physics_engine_v85e_viewport_discipline.html \
  http://127.0.0.1:5173/api/health \
  http://127.0.0.1:5173/api/docs/index \
  http://127.0.0.1:5173/api/portal/index
do
  echo
  echo "----- $url -----"
  curl -i --max-time 5 "$url" | head -n 25
done

echo
echo "=== 8) HEALTH JSON ==="
curl -s --max-time 5 http://127.0.0.1:5173/api/health | python3 -m json.tool

echo
echo "PATCH COMPLETATA."
echo "BACKUP PATCHDIR=$PATCHDIR"
