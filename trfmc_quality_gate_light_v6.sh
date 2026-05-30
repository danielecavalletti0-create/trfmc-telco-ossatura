#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_QUALITY_GATE_V6_$TS"
mkdir -p "$OUT"

URLS=(
"/trfmc_official_safe_entrypoint_v6.html"
"/trfmc_supervisor_mission_control_v5.html"
"/trfmc_unified_evidence_supervisor_v4.html"
"/trfmc_unified_matrix_room_v3.html"
"/trfmc_unified_instrument_shell_lab_v2.html"
"/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
"/trfmc_measurement_chain_dsp_engine_v3.html"
"/trfmc_wifi_5_6_7_8_qam_engine_v1.html"
"/trfmc_5g_core_ran_identity_aka_engine_v1.html"
"/trfmc_converged_rf_5g_noc_v1.html"
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

STABLE_FILES=(
"$PUBLIC/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"
"$PUBLIC/trfmc_measurement_chain_dsp_engine_v3.html"
"$PUBLIC/trfmc_wifi_5_6_7_8_qam_engine_v1.html"
"$PUBLIC/trfmc_5g_core_ran_identity_aka_engine_v1.html"
"$PUBLIC/trfmc_converged_rf_5g_noc_v1.html"
"$PUBLIC/trfmc_master_console_v4.html"
)

{
  echo -e "file\tline\tcontent"
  grep -Hn "trfmc_global_instrument_shell_v1\|trfmc_global_top_telemetry_v2" "${STABLE_FILES[@]}" 2>/dev/null || true
} > "$OUT/forbidden_stable_refs.tsv"

NON200="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$OUT/http.tsv")"
FORBIDDEN="$(awk 'NR>1{c++} END{print c+0}' "$OUT/forbidden_stable_refs.tsv")"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "official_entrypoint": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6.html",
  "http_non_200": $NON200,
  "forbidden_stable_refs": $FORBIDDEN,
  "result": "$([ "$NON200" = "0" ] && [ "$FORBIDDEN" = "0" ] && echo PASS || echo WARN)"
}
JSON

cat > "$OUT/report.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><title>TRFMC Quality Gate V6</title>
<style>body{background:#07111f;color:#eaf3ff;font-family:Segoe UI,Arial;padding:24px}h1{color:#00d9ff}pre,table{background:#02070f;border:1px solid #245b7d;padding:12px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #245b7d;padding:7px;text-align:left}th{background:#0a1b2e;color:#00d9ff}</style>
</head><body>
<h1>TRFMC Quality Gate V6</h1>
<pre>$(python3 -m json.tool "$OUT/summary.json")</pre>
<h2>HTTP</h2><table>
$(awk -F'\t' 'NR==1{print "<tr><th>"$1"</th><th>"$2"</th><th>"$3"</th></tr>";next}{print "<tr><td>"$1"</td><td>"$2"</td><td>"$3"</td></tr>"}' "$OUT/http.tsv")
</table>
<h2>Forbidden stable refs</h2><pre>$(cat "$OUT/forbidden_stable_refs.tsv")</pre>
</body></html>
HTML

cp -f "$OUT/report.html" "$PUBLIC/trfmc_quality_gate_v6_report.html"
ln -sfn "$OUT" "$BASE/runtime/quality/latest_v6"

echo "REPORT_DIR=$OUT"
cat "$OUT/summary.json" | python3 -m json.tool
echo "REPORT_URL=http://127.0.0.1:5173/trfmc_quality_gate_v6_report.html"
