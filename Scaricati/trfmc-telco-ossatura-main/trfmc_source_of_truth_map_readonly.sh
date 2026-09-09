#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
REG="$BASE/runtime/quality/latest_master_portal_register"
FREEZE="$BASE/_archive/latest_control_freeze"
OUT="$BASE/runtime/quality/TRFMC_SOURCE_OF_TRUTH_MAP_READONLY_$TS"

mkdir -p "$OUT"

SUMMARY="$OUT/summary.json"
SOURCE_MAP="$OUT/source_of_truth_map.tsv"
OFFICIAL="$OUT/official_react_sources.tsv"
PROMOTE="$OUT/promotion_backlog.tsv"
ARCHIVE="$OUT/archive_backlog.tsv"
REVIEW="$OUT/review_backlog.tsv"
DOMAIN="$OUT/domain_completion_backlog.tsv"
ORDER="$OUT/FIRST_EXECUTION_ORDER.md"

cd "$BASE"

echo "============================================================"
echo "TRFMC_SOURCE_OF_TRUTH_MAP_READONLY"
echo "Classificazione ufficiale · nessuna modifica al portale"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -d "$REG" ]; then
  echo "ERRORE: registro maestro non trovato: $REG"
  exit 1
fi

if [ ! -d "$FREEZE" ]; then
  echo "ERRORE: control freeze non trovato: $FREEZE"
  exit 1
fi

echo
echo "=== 1) OFFICIAL REACT SOURCES ==="
cat > "$OFFICIAL" <<OFF
role	path	decision	reason
ENTRYPOINT	frontend/index.html	OFFICIAL_KEEP	entrypoint Vite pulito, nessuna injection V51 attiva
APP_ROOT	frontend/src/app/main.tsx	OFFICIAL_KEEP	root React principale, importa MissionLayoutOrchestratorV42
GLOBAL_STYLE	frontend/src/styles.css	OFFICIAL_KEEP	stile sorgente da consolidare, non patch runtime
MISSION_LAYOUT	frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx	OFFICIAL_REFACTOR	layout principale da correggere alla radice
ENGINEERING_CONTENT	frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx	OFFICIAL_REFACTOR	contenuto engineering da integrare nella shell unica
API_CLIENT	frontend/src/shared/api.ts	OFFICIAL_REVIEW	client API da verificare rispetto a 4181/8000
LIVE_CONTRACTS	frontend/src/shared/liveContractsV32R1.ts	OFFICIAL_REVIEW	contratti runtime/live bridge da verificare
OFF

column -t -s $'\t' "$OFFICIAL"

echo
echo "=== 2) SOURCE OF TRUTH MAP ==="
cat > "$SOURCE_MAP" <<MAP
area	official_source	current_problem	decision	next_action
Portal Entrypoint	frontend/index.html	V51 injection rimosse, resta da proteggere	OFFICIAL_KEEP	non aggiungere più runtime patch CSS/JS
React Root	frontend/src/app/main.tsx	root modificato e centrale	OFFICIAL_REVIEW	stabilizzare import, layout e sezioni
Mission Shell	frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx	layout origine dei problemi visuali	OFFICIAL_REFACTOR	unificare shell/sidebar/griglia nel sorgente
Engineering Stack	frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx	contenuto valido ma innestato male	OFFICIAL_REFACTOR	integrarlo come sezione nativa
Global CSS	frontend/src/styles.css	possibile accumulo regole	OFFICIAL_REFACTOR	creare design token e layout system unico
Public HTML	frontend/public/*.html	179 pagine, molte parallele	REVIEW_PROMOTE_ARCHIVE	classificare per dominio e promozione
Public Assets	frontend/public/assets/*	224 asset, varianti e patch residue	REVIEW_PROMOTE_ARCHIVE	tenere solo design system e engine utili
V51 Residues	frontend/public/assets/*v51r*	10 residui patch non referenziati	ARCHIVE_NON_DESTRUCTIVE	spostare in archivio solo dopo approvazione
Backend API	backend/app/main.py + routers	modifiche e nuovi router da verificare	REVIEW	creare API contract ufficiale
Quality Gates	runtime/quality/*	build passa ma visual governance mancante	OFFICIAL_EXPAND	aggiungere screenshot/nav/placeholder gate
MAP

column -t -s $'\t' "$SOURCE_MAP"

echo
echo "=== 3) PROMOTION BACKLOG ==="
{
  echo -e "priority\tpath\tdomain\tdecision\taction"
  awk -F'\t' 'NR>1 {
    path=$2
    domain="GENERAL"
    if (path ~ /official_safe_entrypoint|trfmc_home|trfmc\.html/) domain="MISSION_CONTROL"
    else if (path ~ /portal_index|integration_control_room/) domain="NAVIGATION_GOVERNANCE"
    else if (path ~ /design_system|instrument_design_system/) domain="DESIGN_SYSTEM"
    else if (path ~ /visual_asset_engine/) domain="VISUAL_ASSET_ENGINE"
    print $1 "\t" path "\t" domain "\tPROMOTE_REVIEW\tvalutare migrazione dentro React o consolidamento come asset ufficiale"
  }' "$REG/promote_candidates.tsv"
} | tee "$PROMOTE"

echo
echo "=== 4) ARCHIVE BACKLOG ==="
{
  echo -e "priority\tpath\tdecision\taction"
  awk -F'\t' 'NR>1 {
    print $1 "\t" $2 "\tARCHIVE_REVIEW\tnon cancellare; spostare in _archive solo dopo validazione"
  }' "$REG/archive_candidates.tsv"
} | tee "$ARCHIVE"

echo
echo "=== 5) REVIEW BACKLOG ==="
{
  echo -e "class\tpath\tline\tdecision\taction"
  awk -F'\t' 'NR>1 {
    decision="REVIEW"
    action="valutare se falso positivo, debito reale o contenuto da completare"
    if ($1 ~ /ACTIVE_REACT_DEBT/) { decision="FIX_IN_SOURCE"; action="correggere nel componente React ufficiale" }
    if ($1 ~ /PUBLIC_DEBT/) { decision="PROMOTE_OR_ARCHIVE"; action="se utile promuovere, altrimenti archiviare" }
    if ($1 ~ /BACKEND_CONTRACT_DEBT/) { decision="BACKEND_CONTRACT_REVIEW"; action="documentare contratto o completare endpoint" }
    print $1 "\t" $2 "\t" $3 "\t" decision "\t" action
  }' "$REG/placeholder_todo_mock_inventory.tsv"
} | tee "$REVIEW"

echo
echo "=== 6) DOMAIN COMPLETION BACKLOG ==="
cat > "$DOMAIN" <<DOM
priority	domain	status	source_focus	next_action
P0	Design_System	UNSTABLE	frontend/src/styles.css + promoted design assets	definire un solo token system e rimuovere dipendenza da patch pubbliche
P0	Navigation	UNSTABLE	MissionLayoutOrchestratorV42 + portal_index + integration_control_room	creare navigation registry unico
P0	Mission_Control	REVIEW	main.tsx + MissionLayoutOrchestratorV42	correggere shell unica e dashboard iniziale
P1	RF_Physics	REVIEW	webgl/rf physics pages + React modules	promuovere motore migliore dentro React
P1	Signal_Analyzer	REVIEW	RFInstrumentSuite + signal workbench variants	selezionare analyzer ufficiale
P1	RF_Microwave	REVIEW	smith chart/microwave lab	migrare come modulo React ufficiale
P1	Antenna_System	REVIEW	antenna explorer versions	selezionare versione migliore, archiviare varianti
P2	Microwave_Link	REVIEW	public v1/v2	completare simulatore e QA
P2	Fiber_Optic	REVIEW	OTDR workbench v1/v2	completare flusso OTDR
P2	Private_Networks	REVIEW	WiFi/5G mesh page	completare teoria/simulatore/API
P2	Core_Network	REVIEW	backend/core/open5gs traces	completare console Open5GS/UERANSIM readonly
P3	Data_Center	REVIEW	power/PDU page	completare infrastruttura e simulatori
P3	Cyber_RF_Intelligence	REVIEW	evidence page + locked sensitive areas	mantenere safe/readonly e completare evidence workflow
P3	Knowledge_Base	REVIEW	theory/procedure pages	indicizzare formule, procedure, scenari
DOM

column -t -s $'\t' "$DOMAIN"

echo
echo "=== 7) FIRST EXECUTION ORDER ==="
cat > "$ORDER" <<MD
# TRFMC First Execution Order

## Regola
Nessuna nuova patch runtime. Da ora si modifica solo sorgente ufficiale o si archivia in modo non distruttivo.

## Ordine corretto

### Step 1 — Source cleanup approval
Usare:
- \`archive_backlog.tsv\`
- \`promotion_backlog.tsv\`
- \`review_backlog.tsv\`

Output atteso:
- lista approvata ARCHIVE
- lista approvata PROMOTE
- lista approvata OFFICIAL

### Step 2 — Archive non distruttivo
Spostare solo residui V51 e backup evidenti in:
\`_archive/quarantine/\`

Non cancellare nulla.

### Step 3 — Refactor sorgente minimo
Modificare solo:
- \`frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx\`
- \`frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx\`
- \`frontend/src/styles.css\`

Obiettivo:
- shell unica
- sidebar unica
- proporzioni corrette
- contenuto V49 integrato, non incollato

### Step 4 — Promotion per dominio
Promuovere un dominio alla volta:
1. Mission Control
2. Navigation
3. RF Physics
4. Signal Analyzer
5. RF/Microwave
6. Antenna
7. Core Network

### Step 5 — Quality gates
Ogni step deve produrre:
- build PASS
- HTTP PASS
- screenshot 1920px
- placeholder report
- route/hash report
- API contract report
MD

sed -n '1,220p' "$ORDER"

OFFICIAL_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$OFFICIAL")"
PROMOTE_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$PROMOTE")"
ARCHIVE_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$ARCHIVE")"
REVIEW_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$REVIEW")"
DOMAIN_TOTAL="$(awk 'NR>1 {c++} END{print c+0}' "$DOMAIN")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_SOURCE_OF_TRUTH_MAP_READONLY",
  "mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "source_map": "$SOURCE_MAP",
  "official_react_sources": "$OFFICIAL",
  "promotion_backlog": "$PROMOTE",
  "archive_backlog": "$ARCHIVE",
  "review_backlog": "$REVIEW",
  "domain_completion_backlog": "$DOMAIN",
  "first_execution_order": "$ORDER",
  "official_total": $OFFICIAL_TOTAL,
  "promote_total": $PROMOTE_TOTAL,
  "archive_total": $ARCHIVE_TOTAL,
  "review_total": $REVIEW_TOTAL,
  "domain_total": $DOMAIN_TOTAL,
  "result": "SOURCE_OF_TRUTH_MAP_CREATED"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_source_of_truth_map"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_SOURCE_OF_TRUTH_MAP_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
