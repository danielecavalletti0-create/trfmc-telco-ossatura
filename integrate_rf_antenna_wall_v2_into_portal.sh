#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
BK="$BASE/runtime/backups/INTEGRATE_RF_ANTENNA_WALL_V2_$TS"

mkdir -p "$PUBLIC" "$BASE/runtime/backups" "$BASE/runtime/quality" "$BK"

echo "============================================================"
echo "TRFMC - INTEGRA RF/ANTENNA WALL V2 NEL PORTALE"
echo "============================================================"

echo
echo "[1/6] Verifico pagina sorgente"
test -f "$PUBLIC/trfmc_rf_antenna_academy_wall_v2_premium.html" || {
  echo "ERRORE: manca frontend/public/trfmc_rf_antenna_academy_wall_v2_premium.html"
  echo "Prima crea la pagina premium, poi rilancia questo script."
  exit 1
}

echo
echo "[2/6] Backup file principali"
cp -av "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" "$BK/" 2>/dev/null || true
cp -av "$PUBLIC/trfmc_official_safe_entrypoint_v6.html" "$BK/" 2>/dev/null || true
cp -av "$PUBLIC/trfmc_master_console_v4.html" "$BK/" 2>/dev/null || true

echo
echo "[3/6] Creo pagina Link Graph / concatenazione controllata"
cat > "$PUBLIC/trfmc_portal_link_graph_v1.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Portal Link Graph V1</title>
<style>
:root{--bg:#01060d;--p:#061120;--p2:#081522;--line:#1d6f9f;--text:#eaf3ff;--muted:#86a7c6;--cyan:#00d9ff;--green:#7dff4f;--yellow:#ffd500}
*{box-sizing:border-box}
html,body{margin:0;min-height:100%;background:radial-gradient(circle at 50% 0,rgba(0,217,255,.14),transparent 35%),#01060d;color:var(--text);font:12px Segoe UI,system-ui,sans-serif}
header{height:58px;background:#050b13;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;padding:0 14px;position:sticky;top:0;z-index:10}
h1{margin:0;font-size:18px;letter-spacing:.08em;text-transform:uppercase}
.sub{color:var(--muted);font-size:11px}
button,a.btn{background:#10233a;color:var(--text);border:1px solid #285d82;border-radius:4px;padding:7px 10px;text-decoration:none;cursor:pointer}
button:hover,a.btn:hover{border-color:var(--cyan);background:#145078;box-shadow:inset 3px 0 0 var(--yellow)}
main{display:grid;grid-template-columns:260px 1fr;gap:8px;padding:8px}
aside,.stage{border:1px solid var(--line);background:linear-gradient(180deg,#061321,#02070f);border-radius:8px;overflow:hidden}
.title{background:#0a1b2e;border-bottom:1px solid #1d5e86;color:var(--cyan);font-weight:700;padding:8px;text-transform:uppercase}
.body{padding:8px}
.kv{display:grid;grid-template-columns:1fr auto;gap:8px;border-bottom:1px solid rgba(255,255,255,.06);padding:6px 0;font:11px Consolas,monospace}
.kv b{color:var(--green)}
.grid{display:grid;grid-template-columns:repeat(4,minmax(220px,1fr));gap:8px}
.card{border:1px solid #214a68;background:#081522;border-radius:7px;padding:10px;min-height:130px;position:relative}
.card:hover{border-color:var(--yellow);box-shadow:inset 4px 0 0 var(--yellow);background:#10233a}
.card h2{margin:0 0 6px;color:var(--green);font-size:15px;text-transform:uppercase}
.card p{margin:0;color:var(--muted);font-size:11px;line-height:1.35}
.card code{display:block;margin:8px 0;color:#cde7ff;font-size:10px;word-break:break-all}
.card .open{position:absolute;left:10px;right:10px;bottom:10px}
.badge{display:inline-block;border:1px solid rgba(125,255,79,.4);color:var(--green);padding:3px 6px;border-radius:4px;font:10px Consolas,monospace;margin-bottom:6px}
.section{margin-bottom:14px}
@media(max-width:1500px){.grid{grid-template-columns:repeat(3,minmax(220px,1fr))}}
@media(max-width:1100px){main{grid-template-columns:1fr}.grid{grid-template-columns:1fr}}
</style>
</head>
<body>
<header>
  <div>
    <h1>TRFMC Portal Link Graph V1</h1>
    <div class="sub">Concatenazione controllata delle pagine: link, breadcrumb e moduli foglia. Nessuna matrioska iframe.</div>
  </div>
  <nav>
    <a class="btn" href="/trfmc_official_safe_entrypoint_v6r1_flat.html">V6R1 Flat</a>
    <a class="btn" href="/trfmc_master_console_v4.html">Master</a>
    <a class="btn" href="/trfmc_rf_antenna_academy_wall_v2_premium.html">RF/Antenna Wall</a>
  </nav>
</header>

<main>
  <aside>
    <div class="title">Regola di architettura</div>
    <div class="body">
      <div class="kv"><span>Iframe</span><b>solo moduli foglia</b></div>
      <div class="kv"><span>Shell V2/V3/V4/V5</span><b>open only</b></div>
      <div class="kv"><span>Porta ufficiale</span><b>5173</b></div>
      <div class="kv"><span>External refs</span><b>0</b></div>
      <div class="kv"><span>Policy</span><b>no nested shell</b></div>
    </div>

    <div class="title">Sequenza consigliata</div>
    <div class="body">
      <p>1. Master Console</p>
      <p>2. V6R1 Flat</p>
      <p>3. RF/Antenna Wall</p>
      <p>4. Antenna Explorer</p>
      <p>5. DSP Chain</p>
      <p>6. Wi-Fi/QAM</p>
      <p>7. 5G Core/RAN</p>
    </div>
  </aside>

  <section class="stage">
    <div class="title">Moduli portale</div>
    <div class="body">
      <div class="section">
        <span class="badge">LEAF MODULES - iframe allowed</span>
        <div class="grid" id="leaf"></div>
      </div>

      <div class="section">
        <span class="badge">SUPERVISOR / SHELL - open only</span>
        <div class="grid" id="shells"></div>
      </div>
    </div>
  </section>
</main>

<script>
const leaf=[
 ["RF/Antenna Academy Wall V2","Thermal noise, antenna gain, RFID, Vivaldi, metasurface, Wi-Fi/QAM, site twin.","/trfmc_rf_antenna_academy_wall_v2_premium.html"],
 ["Antenna System Explorer","Antenna, MIMO, RET/AISG, port mapping, VSWR, EIRP, coverage.","/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html"],
 ["DSP Measurement Chain","Receiver, filters, RBW/VBW, detector, averaging, peak/min/max, FFT.","/trfmc_measurement_chain_dsp_engine_v3.html"],
 ["Wi-Fi/QAM Engine","Wi-Fi 5/6/6E/7/8, OFDMA, MLO, 4096-QAM, PHY matrix.","/trfmc_wifi_5_6_7_8_qam_engine_v1.html"],
 ["5G Core/RAN Identity","Open5GS, UERANSIM, SUPI/SUCI, IMSI, PKI, AKA, NAS, NGAP/PFCP/GTP-U.","/trfmc_5g_core_ran_identity_aka_engine_v1.html"],
 ["Converged RF/5G NOC","NOC RF/SDR/Core/evidence operational center.","/trfmc_converged_rf_5g_noc_v1.html"],
 ["RF/TM War Room","Signal universe, RF/TM, cyber RF intelligence and evidence.","/trfmc_rf_tm_war_room_v4.html"],
 ["Master Console","Master portal entry, supervisor links and core navigation.","/trfmc_master_console_v4.html"]
];

const shells=[
 ["V6R1 Flat Official","Entry point flat. Carica solo moduli foglia.","/trfmc_official_safe_entrypoint_v6r1_flat.html"],
 ["Supervisor Mission Control V5","Mission control/supervisor. Da aprire in nuova scheda.","/trfmc_supervisor_mission_control_v5.html"],
 ["Unified Evidence Supervisor V4","Evidence/runbook/report supervisor. Da aprire in nuova scheda.","/trfmc_unified_evidence_supervisor_v4.html"],
 ["Unified Matrix Room V3","Matrix workspace. Da aprire in nuova scheda.","/trfmc_unified_matrix_room_v3.html"],
 ["Unified Instrument Shell V2","Legacy shell. Da aprire in nuova scheda.","/trfmc_unified_instrument_shell_lab_v2.html"]
];

function card(x){
  return `<div class="card">
    <h2>${x[0]}</h2>
    <p>${x[1]}</p>
    <code>${x[2]}</code>
    <a class="btn open" href="${x[2]}">Apri pagina</a>
  </div>`;
}
document.getElementById("leaf").innerHTML=leaf.map(card).join("");
document.getElementById("shells").innerHTML=shells.map(card).join("");
</script>
</body>
</html>
HTML

echo
echo "[4/6] Aggancio RF/Antenna Wall alla V6R1 FLAT se presente"
if [ -f "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" ]; then
python3 - <<'PY'
from pathlib import Path
p = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_official_safe_entrypoint_v6r1_flat.html")
s = p.read_text()

entry = 'academy:{name:"RF/Antenna Academy Wall V2",url:"/trfmc_rf_antenna_academy_wall_v2_premium.html"}'

if "trfmc_rf_antenna_academy_wall_v2_premium.html" not in s:
    # Caso minimale: const LEAF={ ... antenna:{...}
    if "const LEAF={" in s:
        s = s.replace("const LEAF={", "const LEAF={\n " + entry + ",\n ", 1)
    # Caso full: LEAF = { ... oppure altro spacing
    elif "const LEAF = {" in s:
        s = s.replace("const LEAF = {", "const LEAF = {\n " + entry + ",\n ", 1)

# aggiungo pulsante rapido se esiste la griglia dei pulsanti
if "load('academy')" not in s:
    s = s.replace('<button onclick="load(\'antenna\')">Antenna</button>',
                  '<button onclick="load(\'academy\')">RF/Antenna</button>\\n        <button onclick="load(\'antenna\')">Antenna</button>',
                  1)

# aggiorno descrizione se presente
s = s.replace("Iframe solo verso moduli foglia. Le shell V2/V3/V4/V5 si aprono solo in nuova scheda.",
              "Iframe solo verso moduli foglia. RF/Antenna Wall V2 integrata. Le shell V2/V3/V4/V5 si aprono solo in nuova scheda.")

p.write_text(s)
PY
else
  echo "WARN: V6R1 flat non presente. Creo solo link graph e non patcho V6R1."
fi

echo
echo "[5/6] Creo guard integrazione"
cat > "$BASE/trfmc_guard_integrated_portal_v1.sh" <<'GUARD'
#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_INTEGRATED_PORTAL_$TS"
mkdir -p "$OUT"

URLS=(
"/trfmc_portal_link_graph_v1.html"
"/trfmc_rf_antenna_academy_wall_v2_premium.html"
"/trfmc_official_safe_entrypoint_v6r1_flat.html"
"/trfmc_official_safe_entrypoint_v6.html"
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

grep -nE '<iframe[^>]+src="/trfmc_(supervisor|unified|official_safe_entrypoint)' \
  "$PUBLIC/trfmc_official_safe_entrypoint_v6r1_flat.html" \
  > "$OUT/nested_iframe_refs.txt" 2>/dev/null || true

grep -nE 'http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$PUBLIC/trfmc_rf_antenna_academy_wall_v2_premium.html" \
  "$PUBLIC/trfmc_portal_link_graph_v1.html" \
  > "$OUT/external_refs.txt" 2>/dev/null || true

NON200="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$OUT/http.tsv")"
NESTED="$(wc -l < "$OUT/nested_iframe_refs.txt" | tr -d ' ')"
EXTERNAL="$(wc -l < "$OUT/external_refs.txt" | tr -d ' ')"

cat > "$OUT/summary.json" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "portal_link_graph": "http://127.0.0.1:5173/trfmc_portal_link_graph_v1.html",
  "rf_antenna_wall": "http://127.0.0.1:5173/trfmc_rf_antenna_academy_wall_v2_premium.html",
  "v6r1_flat": "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r1_flat.html",
  "http_non_200": $NON200,
  "nested_supervisor_iframes": $NESTED,
  "external_refs": $EXTERNAL,
  "result": "$([ "$NON200" = "0" ] && [ "$NESTED" = "0" ] && [ "$EXTERNAL" = "0" ] && echo PASS || echo WARN)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_integrated_portal"

cat "$OUT/summary.json" | python3 -m json.tool
echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== NESTED IFRAME REFS ==="
cat "$OUT/nested_iframe_refs.txt"
echo
echo "=== EXTERNAL REFS ==="
cat "$OUT/external_refs.txt"
GUARD

chmod +x "$BASE/trfmc_guard_integrated_portal_v1.sh"

echo
echo "[6/6] Lancio guard"
"$BASE/trfmc_guard_integrated_portal_v1.sh"

echo
echo "============================================================"
echo "INTEGRAZIONE COMPLETATA"
echo "Apri:"
echo "1) http://127.0.0.1:5173/trfmc_portal_link_graph_v1.html"
echo "2) http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r1_flat.html"
echo "3) http://127.0.0.1:5173/trfmc_rf_antenna_academy_wall_v2_premium.html"
echo "============================================================"
