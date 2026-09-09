#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_NO_NESTED_IFRAME_V6R1_$TS"
mkdir -p "$OUT"

URLS=(
"/trfmc_official_safe_entrypoint_v6r1_flat.html"
"/trfmc_official_safe_entrypoint_v6.html"
"/trfmc_reset_browser_state_v6r1.html"
"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
"/trfmc_measurement_chain_dsp_engine_v3.html"
"/trfmc_wifi_5_6_7_8_qam_engine_v1.html"
"/trfmc_5g_core_ran_identity_aka_engine_v1.html"
"/trfmc_converged_rf_5g_noc_v1.html"
"/trfmc_rf_tm_war_room_v4.html"
"/trfmc_master_console_v4.html"
"/api/health"
)

{
  echo -e "url\tstatus\tbytes"
  for u in "${URLS[@]}"; do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u")
    echo -e "$u\t$code\t$bytes"
  done
} > "$OUT/http.tsv"

grep -nE '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" > "$OUT/nested_iframe_refs.txt" 2>/dev/null || true

grep -nE 'trfmc_global_instrument_shell_v1|trfmc_global_top_telemetry_v2' \
 "$PUBLIC/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html" \
 "$PUBLIC/trfmc_measurement_chain_dsp_engine_v3.html" \
 "$PUBLIC/trfmc_wifi_5_6_7_8_qam_engine_v1.html" \
 "$PUBLIC/trfmc_5g_core_ran_identity_aka_engine_v1.html" \
 "$PUBLIC/trfmc_converged_rf_5g_noc_v1.html" \
 "$PUBLIC/trfmc_master_console_v4.html" > "$OUT/forbidden_stable_refs.txt" 2>/dev/null || true

NON200="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$OUT/http.tsv")"
NESTED="$(wc -l < "$OUT/nested_iframe_refs.txt" | tr -d ' ')"
FORBIDDEN="$(wc -l < "$OUT/forbidden_stable_refs.txt" | tr -d ' ')"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "official_entrypoint": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r1_flat.html",
  "http_non_200": $NON200,
  "nested_supervisor_iframes": $NESTED,
  "forbidden_stable_refs": $FORBIDDEN,
  "result": "$([ "$NON200" = "0" ] && [ "$NESTED" = "0" ] && [ "$FORBIDDEN" = "0" ] && echo PASS || echo WARN)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_no_nested_v6r1"
cat "$OUT/summary.json" | python3 -m json.tool
