#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_PROMOTE_V6R2_$TS"
BK="$BASE/runtime/backups/PROMOTE_V6R2_$TS"

mkdir -p "$OUT" "$BK"

echo "============================================================"
echo "TRFMC - PROMOTE V6R2 PREMIUM CONSOLE"
echo "============================================================"

echo
echo "[1/5] Backup Portal Link Graph"
cp -av "$PUBLIC/trfmc_portal_link_graph_v1.html" "$BK/" 2>/dev/null || true

echo
echo "[2/5] Verifico V6R2"
test -f "$PUBLIC/trfmc_official_safe_entrypoint_v6r2_premium_console.html"

echo
echo "[3/5] Patch Portal Link Graph: V6R2 consigliata, V6R1 fallback"
python3 - <<'PY'
from pathlib import Path

p = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_portal_link_graph_v1.html")

if not p.exists():
    raise SystemExit("MISSING trfmc_portal_link_graph_v1.html")

s = p.read_text(errors="ignore")

# Aggiorno bottoni top se presenti.
s = s.replace(
    '<a class="btn" href="/trfmc_official_safe_entrypoint_v6r1_flat.html">V6R1 Flat</a>',
    '<a class="btn" href="/trfmc_official_safe_entrypoint_v6r2_premium_console.html">V6R2 Premium</a>\n    <a class="btn" href="/trfmc_official_safe_entrypoint_v6r1_flat.html">V6R1 Fallback</a>'
)

# Inserisco V6R2 nella lista shells/entrypoint se non c'è.
needle = 'const shells=['
entry = ' ["V6R2 Premium Console","Ingresso operativo principale consigliato: console premium con moduli foglia RF/Telco/Cyber.","/trfmc_official_safe_entrypoint_v6r2_premium_console.html"],\n'

if "/trfmc_official_safe_entrypoint_v6r2_premium_console.html" not in s and needle in s:
    s = s.replace(needle, needle + "\n" + entry, 1)

# Aggiorno sequenza consigliata se presente.
s = s.replace(
    "<p>1. Master Console</p>\n      <p>2. V6R1 Flat</p>",
    "<p>1. V6R2 Premium Console</p>\n      <p>2. V6R1 Flat fallback</p>\n      <p>3. Master Console</p>"
)

# Aggiorno descrizione header.
s = s.replace(
    "Concatenazione controllata delle pagine: link, breadcrumb e moduli foglia. Nessuna matrioska iframe.",
    "Concatenazione controllata: V6R2 Premium come ingresso consigliato, V6R1 come fallback, moduli foglia senza matrioska iframe."
)

p.write_text(s)
PY

echo
echo "[4/5] Quality gate promozione V6R2"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_portal_link_graph_v1.html \
    /trfmc_official_safe_entrypoint_v6r2_premium_console.html \
    /trfmc_official_safe_entrypoint_v6r1_flat.html \
    /trfmc_rf_antenna_academy_wall_v2_premium.html \
    /trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html \
    /trfmc_measurement_chain_dsp_engine_v3.html \
    /trfmc_wifi_5_6_7_8_qam_engine_v1.html \
    /trfmc_5g_core_ran_identity_aka_engine_v1.html \
    /trfmc_converged_rf_5g_noc_v1.html \
    /trfmc_rf_tm_war_room_v4.html \
    /trfmc_master_console_v4.html \
    /api/health
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u")
    echo -e "$u\t$code\t$bytes"
  done
} > "$OUT/http.tsv"

grep -nE '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  "$PUBLIC/trfmc_official_safe_entrypoint_v6r2_premium_console.html" \
  "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" \
  > "$OUT/nested_iframe_refs.txt" 2>/dev/null || true

grep -nE 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$PUBLIC/trfmc_portal_link_graph_v1.html" \
  "$PUBLIC/trfmc_official_safe_entrypoint_v6r2_premium_console.html" \
  > "$OUT/external_refs.txt" 2>/dev/null || true

python3 - <<PY
import json
from pathlib import Path
from datetime import datetime, timezone

out = Path("$OUT")
http_non_200 = 0

for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    parts = line.split("\t")
    if len(parts) >= 2 and parts[1].strip() != "200":
        http_non_200 += 1

nested = sum(1 for x in (out / "nested_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
external = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

result = "PASS" if http_non_200 == 0 and nested == 0 and external == 0 else "WARN"

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "portal_link_graph": "http://127.0.0.1:5173/trfmc_portal_link_graph_v1.html",
    "v6r2_premium": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r2_premium_console.html",
    "v6r1_fallback": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r1_flat.html",
    "http_non_200": http_non_200,
    "nested_supervisor_iframes": nested,
    "external_refs": external,
    "result": result
}

(out / "summary.json").write_text(json.dumps(data, indent=4) + "\n")
print(json.dumps(data, indent=4))
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_promote_v6r2"

echo
echo "[5/5] Report"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== NESTED ==="
cat "$OUT/nested_iframe_refs.txt"

echo
echo "=== EXTERNAL ==="
cat "$OUT/external_refs.txt"

echo
echo "============================================================"
echo "PROMOZIONE V6R2 COMPLETATA"
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_portal_link_graph_v1.html"
echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r2_premium_console.html"
echo "============================================================"
