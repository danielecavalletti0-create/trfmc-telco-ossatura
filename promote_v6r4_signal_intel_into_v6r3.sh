#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
V6R4="$PUBLIC/trfmc_signal_intelligence_center_v1.html"

OUT="$BASE/runtime/quality/TRFMC_PROMOTE_V6R4_INTO_V6R3_$TS"
BK="$BASE/runtime/backups/PROMOTE_V6R4_INTO_V6R3_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC - PROMOTE V6R4 SIGNAL INTELLIGENCE INTO V6R3"
echo "============================================================"

echo
echo "[1/6] Verifico pagine sorgente"
ls -lh "$V6R3"
ls -lh "$V6R4"

echo
echo "[2/6] Backup V6R3"
cp -av "$V6R3" "$BK/"

echo
echo "[3/6] Patch V6R3: aggiungo Signal Intelligence come modulo foglia"
python3 - <<'PY'
from pathlib import Path

v6r3 = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html")
s = v6r3.read_text(errors="ignore")

url = "/trfmc_signal_intelligence_center_v1.html"

module = ''' sigintel:{icon:"SI",name:"Signal Intelligence Center",desc:"wideband FFT · DDC · classifier · IQ evidence · DF · metrology",url:"/trfmc_signal_intelligence_center_v1.html"},
'''

quick_button = '''        <button onclick="load('sigintel')">Signal Intel</button>
'''

changed = False

if url not in s:
    if "const M={\n" in s:
        s = s.replace("const M={\n", "const M={\n" + module, 1)
        changed = True
    elif "const M={" in s:
        s = s.replace("const M={", "const M={\n" + module, 1)
        changed = True
    else:
        raise SystemExit("ERRORE: oggetto const M non trovato in V6R3")

if "load('sigintel')" not in s:
    marker = '''        <button onclick="load('rfwall')">RF/Antenna</button>'''
    if marker in s:
        s = s.replace(marker, quick_button + marker, 1)
        changed = True
    else:
        # fallback non distruttivo: il modulo sarà comunque presente nel pannello sinistro generato da render()
        changed = True

# Aggiorno descrizione header solo se presente
s = s.replace(
    "RF/Telco/Cyber command console · leaf modules only · no shell nesting",
    "RF/Telco/Cyber command console · Signal Intelligence leaf module · no shell nesting"
)

v6r3.write_text(s)

if changed:
    print("PATCH_OK: V6R4 aggiunta come modulo foglia in V6R3")
else:
    print("NO_CHANGE: V6R4 era già presente in V6R3")
PY

echo
echo "[4/6] Quality gate HTTP / nested / external / integrazione"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_official_safe_entrypoint_v6r3_command_center.html \
  /trfmc_signal_intelligence_center_v1.html \
  /trfmc_official_safe_entrypoint_v6r2_premium_console.html \
  /trfmc_portal_link_graph_v1.html \
  /trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html \
  /trfmc_measurement_chain_dsp_engine_v3.html \
  /trfmc_wifi_5_6_7_8_qam_engine_v1.html \
  /trfmc_5g_core_ran_identity_aka_engine_v1.html \
  /trfmc_converged_rf_5g_noc_v1.html \
  /trfmc_rf_tm_war_room_v4.html \
  /trfmc_master_console_v4.html \
  /api/health
do
  read -r code bytes < <(curl -s -o /dev/null -w "%{response_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" || echo "000 0")
  echo -e "$u\t$code\t$bytes" >> "$OUT/http.tsv"
done

# Deve rimanere zero: niente iframe verso supervisor/unified/entrypoint.
grep -nEi '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  "$V6R3" "$V6R4" > "$OUT/nested_shell_iframe_refs.txt" 2>/dev/null || true

# V6R4 deve essere completamente autonoma: niente iframe.
grep -nEi '<iframe' "$V6R4" > "$OUT/v6r4_iframe_refs.txt" 2>/dev/null || true

# Nessun CDN / riferimento esterno in V6R3 e V6R4.
grep -nEi 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$V6R3" "$V6R4" > "$OUT/external_refs.txt" 2>/dev/null || true

{
  echo "=== V6R3 MODULE CHECK ==="
  grep -n 'sigintel' "$V6R3" || true
  grep -n '/trfmc_signal_intelligence_center_v1.html' "$V6R3" || true
  grep -n "load('sigintel')" "$V6R3" || true
} > "$OUT/integration_check.txt"

export OUT
python3 - <<'PY'
import json
import os
from pathlib import Path
from datetime import datetime, timezone

out = Path(os.environ["OUT"])

http_non_200 = 0
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 2 and p[1].strip() != "200":
        http_non_200 += 1

nested = sum(1 for x in (out / "nested_shell_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
v6r4_iframes = sum(1 for x in (out / "v6r4_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
external = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

integration_text = (out / "integration_check.txt").read_text(errors="ignore")
has_module = "sigintel" in integration_text and "/trfmc_signal_intelligence_center_v1.html" in integration_text

result = "PASS" if (
    http_non_200 == 0
    and nested == 0
    and v6r4_iframes == 0
    and external == 0
    and has_module
) else "WARN"

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "v6r3_command_center": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "v6r4_signal_intelligence_leaf": "http://127.0.0.1:5173/trfmc_signal_intelligence_center_v1.html",
    "http_non_200": http_non_200,
    "nested_shell_iframe_refs": nested,
    "v6r4_iframe_refs": v6r4_iframes,
    "external_refs": external,
    "v6r3_has_v6r4_module": has_module,
    "result": result
}

(out / "summary.json").write_text(json.dumps(data, indent=4) + "\n")
(out / "result.flag").write_text(result + "\n")
print(json.dumps(data, indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_promote_v6r4_into_v6r3"

echo
echo "[5/6] Report"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== NESTED SHELL IFRAME ==="
cat "$OUT/nested_shell_iframe_refs.txt"

echo
echo "=== V6R4 IFRAME ==="
cat "$OUT/v6r4_iframe_refs.txt"

echo
echo "=== EXTERNAL ==="
cat "$OUT/external_refs.txt"

echo
echo "=== INTEGRATION CHECK ==="
cat "$OUT/integration_check.txt"

echo
echo "[6/6] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_V6R4_AS_V6R3_LEAF_$TS.tar.gz"

  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .

  echo
  echo "=== FREEZE CREATO ==="
  ls -lh "$FREEZE"

  echo
  echo "============================================================"
  echo "PROMOZIONE COMPLETATA: V6R4 È MODULO FOGLIA UFFICIALE IN V6R3"
  echo "Apri:"
  echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
  echo
  echo "Modulo diretto:"
  echo "http://127.0.0.1:5173/trfmc_signal_intelligence_center_v1.html"
  echo
  echo "Freeze:"
  echo "$FREEZE"
  echo "============================================================"
else
  echo
  echo "============================================================"
  echo "WARN: nessun freeze creato."
  echo "Backup V6R3 disponibile in:"
  echo "$BK"
  echo "Report:"
  echo "$OUT"
  echo "============================================================"
fi
