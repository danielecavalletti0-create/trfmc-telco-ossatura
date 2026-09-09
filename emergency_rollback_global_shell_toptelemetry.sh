#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets"
TS="$(date +%Y%m%d_%H%M%S)"
RB="$BASE/runtime/rollback/EMERGENCY_ROLLBACK_GLOBAL_SHELL_$TS"

mkdir -p "$RB"

echo "============================================================"
echo "EMERGENCY ROLLBACK GLOBAL SHELL / TOP TELEMETRY"
echo "============================================================"
echo "BASE=$BASE"
echo "ROLLBACK=$RB"
echo

echo "[1/6] Backup pagine HTML interessate"
mkdir -p "$RB/html_before"

find "$PUBLIC" -maxdepth 1 -type f -name '*.html' \
  \( -name 'trfmc_*.html' -o -name 'index.html' \) \
  -exec cp -a {} "$RB/html_before/" \;

if [ -f "$PUBLIC/api/portal/index" ]; then
  mkdir -p "$RB/api_portal_before"
  cp -a "$PUBLIC/api/portal/index" "$RB/api_portal_before/index"
fi

echo
echo "[2/6] Rimuovo riferimenti agli asset globali iniettati"
python3 - <<'PY'
from pathlib import Path

public = Path("frontend/public")

patterns = [
    "trfmc_global_instrument_shell_v1.css",
    "trfmc_global_instrument_shell_v1.js",
    "trfmc_global_top_telemetry_v2.css",
    "trfmc_global_top_telemetry_v2.js",
]

targets = list(public.glob("trfmc_*.html"))
idx = public / "index.html"
if idx.exists():
    targets.append(idx)

api_idx = public / "api/portal/index"
if api_idx.exists():
    targets.append(api_idx)

for p in targets:
    s = p.read_text(errors="ignore")
    orig = s

    lines = []
    for line in s.splitlines():
      if any(x in line for x in patterns):
        continue
      lines.append(line)

    s = "\n".join(lines) + ("\n" if orig.endswith("\n") else "")

    if s != orig:
        p.write_text(s)
        print("CLEANED", p)
PY

echo
echo "[3/6] Quarantena asset globali rotti"
mkdir -p "$RB/assets_quarantine"

for f in \
  "$ASSETS/trfmc_global_instrument_shell_v1.css" \
  "$ASSETS/trfmc_global_instrument_shell_v1.js" \
  "$ASSETS/trfmc_global_top_telemetry_v2.css" \
  "$ASSETS/trfmc_global_top_telemetry_v2.js"
do
  if [ -f "$f" ]; then
    mv -v "$f" "$RB/assets_quarantine/"
  fi
done

echo
echo "[4/6] Creo pagina reset localStorage layout"
cat > "$PUBLIC/trfmc_emergency_reset_layout_state.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>TRFMC Emergency Reset Layout State</title>
<style>
body{margin:0;background:#02070f;color:#eaf3ff;font-family:Segoe UI,system-ui,sans-serif;display:grid;place-items:center;height:100vh}
.box{border:1px solid #1d6f9f;background:#061120;border-radius:10px;padding:26px;max-width:760px}
h1{color:#00d9ff;margin-top:0}
code{color:#7dff4f}
a{color:#ffd500}
</style>
</head>
<body>
<div class="box">
<h1>TRFMC Emergency Layout Reset</h1>
<p>Rimuovo solo le chiavi layout/UI sperimentali da <code>localStorage</code>.</p>
<pre id="out"></pre>
<p>Tra pochi secondi apro la pagina stabile V1.6R2 Clean Dock.</p>
<p><a href="/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html">Apri manualmente V1.6R2 Clean Dock</a></p>
</div>
<script>
const keys = [
  "trfmc_global_instrument_shell_v1",
  "trfmc_global_top_telemetry_v2",
  "trfmc_v17_layout_mode",
  "trfmc_antenna_v17_layout_mode"
];

let out = [];
for (const k of keys) {
  try {
    localStorage.removeItem(k);
    out.push("REMOVED: " + k);
  } catch(e) {
    out.push("ERROR: " + k + " " + e);
  }
}

document.getElementById("out").textContent = out.join("\n");

setTimeout(() => {
  location.href = "/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html";
}, 1800);
</script>
</body>
</html>
HTML

echo
echo "[5/6] Creo pagina antenna stabile recuperata senza Global Shell"
cp -a "$PUBLIC/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html" \
      "$PUBLIC/trfmc_antenna_system_explorer_STABLE_CLEAN_RECOVERY.html"

python3 - <<'PY'
from pathlib import Path
p = Path("frontend/public/trfmc_antenna_system_explorer_STABLE_CLEAN_RECOVERY.html")
s = p.read_text(errors="ignore")
s = s.replace(
    "TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout",
    "TRFMC Antenna System Explorer STABLE CLEAN RECOVERY"
)
s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout</title>",
    "<title>TRFMC Antenna STABLE CLEAN RECOVERY</title>"
)
p.write_text(s)
print("CREATED", p)
PY

echo
echo "[6/6] Verifica assenza riferimenti globali"
echo "=== GREP GLOBAL ASSETS ==="
grep -RIn \
  "trfmc_global_instrument_shell_v1\|trfmc_global_top_telemetry_v2" \
  "$PUBLIC" 2>/dev/null || true

echo
echo "=== HTTP CHECK ==="
for url in \
  http://127.0.0.1:5173/trfmc_emergency_reset_layout_state.html \
  http://127.0.0.1:5173/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html \
  http://127.0.0.1:5173/trfmc_antenna_system_explorer_STABLE_CLEAN_RECOVERY.html \
  http://127.0.0.1:5173/trfmc_master_console_v4.html \
  http://127.0.0.1:5173/api/health
do
  echo -n "$url -> "
  curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" --max-time 5 "$url"
done

echo
echo "============================================================"
echo "ROLLBACK COMPLETATO"
echo "Apri prima:"
echo "http://127.0.0.1:5173/trfmc_emergency_reset_layout_state.html"
echo
echo "Poi:"
echo "http://127.0.0.1:5173/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
echo "oppure:"
echo "http://127.0.0.1:5173/trfmc_antenna_system_explorer_STABLE_CLEAN_RECOVERY.html"
echo "============================================================"
