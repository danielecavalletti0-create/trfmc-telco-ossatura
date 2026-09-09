#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONTEND="$BASE/frontend"
TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC PROMOTE UNIFIED SHELL AS ROOT ENTRYPOINT - 5173"
echo "============================================================"
date
echo "BASE=$BASE"

cd "$BASE"

INDEX="$FRONTEND/index.html"

if [ -f "$INDEX" ]; then
  cp -a "$INDEX" "$INDEX.bak_before_unified_shell_$TS"
fi

cat > "$INDEX" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Portal Entrypoint</title>
<meta http-equiv="refresh" content="0; url=/trfmc_unified_navigation_shell_v1.html">
<style>
body{
  margin:0;
  min-height:100vh;
  display:grid;
  place-items:center;
  background:
    radial-gradient(circle at 20% 0%,rgba(50,130,255,.22),transparent 30%),
    radial-gradient(circle at 100% 10%,rgba(0,255,190,.11),transparent 26%),
    linear-gradient(180deg,#030711,#07111f 48%,#030711);
  color:#eaf3ff;
  font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}
.card{
  max-width:760px;
  padding:32px;
  border:1px solid rgba(125,190,255,.28);
  border-radius:22px;
  background:rgba(8,18,36,.88);
  box-shadow:0 18px 60px rgba(0,0,0,.34);
}
h1{margin:0 0 12px;font-size:30px}
p{color:#a9bad2;line-height:1.55}
a{
  display:inline-block;
  margin-top:12px;
  color:#eaf3ff;
  text-decoration:none;
  border:1px solid rgba(134,215,255,.6);
  border-radius:999px;
  padding:10px 14px;
}
</style>
</head>
<body>
<div class="card">
  <h1>TRFMC Portal</h1>
  <p>Reindirizzamento alla Unified Navigation Shell ufficiale del portale RF/Telco/Cyber su porta 5173.</p>
  <a href="/trfmc_unified_navigation_shell_v1.html">Apri Unified Navigation Shell</a>
</div>
</body>
</html>
HTML

echo
echo "=== TEST ROOT ENTRYPOINT ==="
curl -I --max-time 5 http://127.0.0.1:5173/
curl -I --max-time 5 http://127.0.0.1:5173/trfmc_unified_navigation_shell_v1.html

echo
echo "ENTRYPOINT PROMOSSO:"
echo "http://127.0.0.1:5173/"
