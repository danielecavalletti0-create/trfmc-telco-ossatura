#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/reports/TRFMC_VISUAL_MASTER_DECISION_$TS.md"
LATEST_VISUAL="$(find "$BASE/runtime/reports" -maxdepth 1 -type d -name 'TRFMC_VISUAL_STYLE_FORENSIC_AUDIT_*' | sort | tail -n 1)"
QUALITY="$BASE/runtime/quality/latest_consolidation_registry/summary.json"

mkdir -p "$BASE/runtime/reports"

cat > "$OUT" <<MD
# TRFMC VISUAL MASTER DECISION V1

Data: $(date)

## 1. Baseline ufficiale

La shell ufficiale del portale resta:

\`\`\`text
/trfmc_official_safe_entrypoint_v6r3_command_center.html
\`\`\`

La V6R3 non deve essere sovrascritta, duplicata, sporcata o trasformata in una nuova shell parallela.

## 2. Stato qualità attuale

Quality gate corrente:

\`\`\`json
$(cat "$QUALITY" 2>/dev/null || echo "{}")
\`\`\`

Risultato operativo: il registry, la Control Room e la V6R3 rispondono correttamente via HTTP.

## 3. Regola anti-frammentazione

Da questo momento ogni nuovo modulo deve rispettare questa catena:

\`\`\`text
snapshot pre-modifica
→ registry entry
→ pagina leaf / preview
→ HTTP test
→ content test
→ no CDN
→ no iframe
→ no doppia/tripla barra
→ quality report
→ eventuale promozione controllata
\`\`\`

## 4. Gerarchia corretta del portale

\`\`\`text
V6R3 Command Center
= shell ufficiale

Integration Control Room
= governance, registry, classificazione, qualità

Visual Master System
= tokens, stile 3D/GPU, HUD, pannelli, disciplina grafica

Leaf Modules
= RF, SDR, WebGL, Smith, Antenna, Core, Cyber, Fiber, Microwave

Backup / Legacy
= sorgenti selettive, non runtime diretto
\`\`\`

## 5. Visual donor principale

Il candidato principale da usare come sorgente grafica, non come shell, è:

\`\`\`text
/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html
\`\`\`

Ruolo: visual donor 3D/GPU.

Da estrarre:
- palette;
- profondità;
- glow;
- HUD;
- pannelli tecnici;
- stile WebGL;
- asset rendering;
- look T&M / cyber-physical.

Da non importare direttamente:
- fixed layer non governati;
- body style multipli;
- shell autonome;
- barre proprie.

## 6. Pagine da non promuovere direttamente

Le pagine con molte navbar/header/fixed layer devono essere considerate solo reference estetiche.

Esempi:

\`\`\`text
015__6g-omni-nexus.html
054__geo-spatial-fresnel.html
091__sovereign-spatial.html
093__sovereign-swarm.html
094__spatial-lab.html
\`\`\`

Motivo:
- troppe barre/header;
- molti z-index;
- fixed layer;
- rischio portale parallelo;
- rischio collisione con shell V6R3.

## 7. Moduli recuperabili come leaf

Moduli da mantenere e normalizzare come leaf module:

\`\`\`text
rfpro_unified_console.html
trfmc_signal_intelligence_center_v1.html
trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html
trfmc_core_network_live_ops_bridge_v1.html
trfmc_rf_metrology_calibration_lab_v1.html
trfmc_antenna_system_explorer_STABLE_CLEAN_RECOVERY.html
trfmc_rf_microwave_engineering_v1.html
webgl_rf_physics_engine_v85e_viewport_discipline.html
\`\`\`

## 8. Regole grafiche obbligatorie

Vietato:
- aggiungere una seconda navbar;
- aggiungere una terza barra;
- inserire iframe di pagine interne come soluzione strutturale;
- caricare CDN esterne;
- copiare shell dai backup dentro V6R3;
- promuovere pagine con molte fixed layer senza bonifica;
- usare backup come runtime diretto.

Consentito:
- creare preview isolate;
- estrarre CSS/token;
- usare WebGL come modulo;
- costruire componenti HUD comuni;
- normalizzare palette e layout;
- registrare ogni modulo nel registry;
- promuovere solo dopo quality PASS.

## 9. Prossima fase ammessa

La prossima modifica ammessa è solo questa:

\`\`\`text
creazione di un Visual Master CSS V1 in preview
\`\`\`

File previsto:

\`\`\`text
/frontend/public/assets/trfmc_visual_master_v1.css
/frontend/public/trfmc_visual_master_preview_v1.html
\`\`\`

La preview non deve modificare V6R3.

## 10. Decisione finale

Il portale non va ricostruito.  
Il portale non va duplicato.  
Il portale non va sporcato.  

Va consolidato con:

\`\`\`text
V6R3 ufficiale
+ registry unico
+ control room
+ visual master system
+ moduli leaf normalizzati
\`\`\`
MD

echo "Creato:"
echo "$OUT"
echo
echo "Ultimo audit visuale:"
echo "$LATEST_VISUAL"
echo
echo "Anteprima:"
sed -n '1,220p' "$OUT"
