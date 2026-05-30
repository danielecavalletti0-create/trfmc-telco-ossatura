#!/usr/bin/env bash
set -u
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
V6R4="$PUBLIC/trfmc_signal_intelligence_center_v1.html"
FFT="$PUBLIC/trfmc_realtime_fft_gapless_receiver_lab_v1.html"

OUT="$BASE/runtime/quality/TRFMC_PROMOTE_FFT_GAPLESS_INTO_V6R3_$TS"
BK="$BASE/runtime/backups/PROMOTE_FFT_GAPLESS_INTO_V6R3_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC - PROMOTE FFT GAPLESS RECEIVER LAB INTO V6R3"
echo "SAFE / RECOVERY / PATCH / GATE / FREEZE"
echo "============================================================"

http_probe() {
  local u="$1"
  local r code bytes
  r="$(curl -s -o /dev/null -w "%{response_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
  code="$(echo "$r" | awk '{print $1}')"
  bytes="$(echo "$r" | awk '{print $2}')"
  [ -n "$code" ] || code="000"
  [ -n "$bytes" ] || bytes="0"
  echo -e "$u\t$code\t$bytes"
}

echo
echo "[1/8] Verifico file principali"
ls -lh "$V6R3" || { echo "ERRORE: V6R3 mancante"; exit 1; }
ls -lh "$V6R4" || { echo "ERRORE: V6R4 mancante"; exit 1; }
ls -lh "$FFT"  || { echo "ERRORE: FFT Gapless Lab mancante"; exit 1; }

echo
echo "[2/8] Backup V6R3"
cp -av "$V6R3" "$BK/" || true

echo
echo "[3/8] Quality gate preliminare pagina FFT"
cat > "$OUT/http_fft_pre.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_realtime_fft_gapless_receiver_lab_v1.html \
  /trfmc_official_safe_entrypoint_v6r3_command_center.html \
  /trfmc_signal_intelligence_center_v1.html \
  /api/health
do
  http_probe "$u" >> "$OUT/http_fft_pre.tsv"
done

grep -nEi '<iframe|src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  "$FFT" > "$OUT/fft_iframe_refs.txt" 2>/dev/null || true

grep -nEi 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$FFT" > "$OUT/fft_external_refs.txt" 2>/dev/null || true

echo
echo "[4/8] Patch V6R3: aggiungo FFT Gapless come modulo foglia"
python3 - <<'PY'
from pathlib import Path

v6r3 = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html")
s = v6r3.read_text(errors="ignore")

module_key = "fftgapless"
module_url = "/trfmc_realtime_fft_gapless_receiver_lab_v1.html"

module = ''' fftgapless:{icon:"FFT",name:"FFT Gapless Receiver Lab",desc:"IF bandwidth · RBW · DNL · overlap FFT · waterfall · POI · pulse capture",url:"/trfmc_realtime_fft_gapless_receiver_lab_v1.html"},
'''

quick_button = '''        <button onclick="load('fftgapless')">FFT Gapless</button>
'''

changed = False

if module_url not in s:
    if "const M={\n" in s:
        s = s.replace("const M={\n", "const M={\n" + module, 1)
        changed = True
    elif "const M={" in s:
        s = s.replace("const M={", "const M={\n" + module, 1)
        changed = True
    else:
        raise SystemExit("ERRORE: const M non trovato in V6R3")
else:
    print("INFO: URL FFT già presente in V6R3")

if "load('fftgapless')" not in s:
    marker = '''        <button onclick="load('sigintel')">Signal Intel</button>'''
    if marker in s:
        s = s.replace(marker, marker + "\n" + quick_button.rstrip(), 1)
        changed = True
    else:
        marker2 = '''        <button onclick="load('rfwall')">RF/Antenna</button>'''
        if marker2 in s:
            s = s.replace(marker2, quick_button + marker2, 1)
            changed = True
        else:
            print("WARN: quick button marker non trovato; modulo comunque presente nel pannello sinistro")
else:
    print("INFO: quick button FFT già presente")

s = s.replace(
    "RF/Telco/Cyber command console · Signal Intelligence leaf module · no shell nesting",
    "RF/Telco/Cyber command console · Signal Intelligence + FFT Gapless leaf modules · no shell nesting"
)

s = s.replace(
    "RF/Telco/Cyber command console · leaf modules only · no shell nesting",
    "RF/Telco/Cyber command console · Signal Intelligence + FFT Gapless leaf modules · no shell nesting"
)

v6r3.write_text(s)

if changed:
    print("PATCH_OK: FFT Gapless aggiunto come modulo foglia in V6R3")
else:
    print("NO_CHANGE: FFT Gapless era già presente o non richiedeva patch")
PY

echo
echo "[5/8] Gate completo post-promozione"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  /trfmc_official_safe_entrypoint_v6r3_command_center.html \
  /trfmc_signal_intelligence_center_v1.html \
  /trfmc_realtime_fft_gapless_receiver_lab_v1.html \
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
  http_probe "$u" >> "$OUT/http.tsv"
done

grep -nEi '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  "$V6R3" "$V6R4" "$FFT" > "$OUT/nested_shell_iframe_refs.txt" 2>/dev/null || true

grep -nEi '<iframe' \
  "$FFT" > "$OUT/fft_iframe_refs_post.txt" 2>/dev/null || true

grep -nEi 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$V6R3" "$V6R4" "$FFT" > "$OUT/external_refs.txt" 2>/dev/null || true

{
  echo "=== V6R3 MODULE CHECK ==="
  grep -n "sigintel" "$V6R3" || true
  grep -n "fftgapless" "$V6R3" || true
  grep -n "/trfmc_signal_intelligence_center_v1.html" "$V6R3" || true
  grep -n "/trfmc_realtime_fft_gapless_receiver_lab_v1.html" "$V6R3" || true
  grep -n "load('sigintel')" "$V6R3" || true
  grep -n "load('fftgapless')" "$V6R3" || true
} > "$OUT/integration_check.txt"

echo
echo "[6/8] Summary JSON"
export OUT
python3 - <<'PY'
import json
import os
from pathlib import Path
from datetime import datetime, timezone

out = Path(os.environ["OUT"])

def count_non_200(path):
    n = 0
    for line in path.read_text(errors="ignore").splitlines()[1:]:
        p = line.split("\t")
        if len(p) >= 2 and p[1].strip() != "200":
            n += 1
    return n

http_non_200 = count_non_200(out / "http.tsv")
nested = sum(1 for x in (out / "nested_shell_iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fft_iframes = sum(1 for x in (out / "fft_iframe_refs_post.txt").read_text(errors="ignore").splitlines() if x.strip())
external = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

integration = (out / "integration_check.txt").read_text(errors="ignore")
has_sigintel = "sigintel" in integration and "/trfmc_signal_intelligence_center_v1.html" in integration
has_fft = "fftgapless" in integration and "/trfmc_realtime_fft_gapless_receiver_lab_v1.html" in integration

result = "PASS" if (
    http_non_200 == 0
    and nested == 0
    and fft_iframes == 0
    and external == 0
    and has_sigintel
    and has_fft
) else "WARN"

data = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "v6r3_command_center": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "v6r4_signal_intelligence_leaf": "http://127.0.0.1:5173/trfmc_signal_intelligence_center_v1.html",
    "fft_gapless_receiver_leaf": "http://127.0.0.1:5173/trfmc_realtime_fft_gapless_receiver_lab_v1.html",
    "http_non_200": http_non_200,
    "nested_shell_iframe_refs": nested,
    "fft_iframe_refs": fft_iframes,
    "external_refs": external,
    "v6r3_has_sigintel_module": has_sigintel,
    "v6r3_has_fftgapless_module": has_fft,
    "result": result
}

(out / "summary.json").write_text(json.dumps(data, indent=4) + "\n")
(out / "result.flag").write_text(result + "\n")
print(json.dumps(data, indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_promote_fft_gapless_into_v6r3"

echo
echo "[7/8] Report"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== NESTED SHELL IFRAME ==="
cat "$OUT/nested_shell_iframe_refs.txt"

echo
echo "=== FFT IFRAME ==="
cat "$OUT/fft_iframe_refs_post.txt"

echo
echo "=== EXTERNAL ==="
cat "$OUT/external_refs.txt"

echo
echo "=== INTEGRATION CHECK ==="
cat "$OUT/integration_check.txt"

echo
echo "[8/8] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_FFT_GAPLESS_AS_V6R3_LEAF_$TS.tar.gz"

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
  echo "PROMOZIONE VALIDATA: FFT GAPLESS È MODULO FOGLIA UFFICIALE IN V6R3"
  echo "Apri V6R3:"
  echo "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
  echo
  echo "Modulo diretto FFT:"
  echo "http://127.0.0.1:5173/trfmc_realtime_fft_gapless_receiver_lab_v1.html"
  echo
  echo "Modulo diretto Signal Intelligence:"
  echo "http://127.0.0.1:5173/trfmc_signal_intelligence_center_v1.html"
  echo
  echo "Freeze:"
  echo "$FREEZE"
  echo "============================================================"
else
  echo
  echo "============================================================"
  echo "WARN: promozione non validata. Nessun freeze creato."
  echo "Backup V6R3:"
  echo "$BK"
  echo "Report:"
  echo "$OUT"
  echo "============================================================"
fi
