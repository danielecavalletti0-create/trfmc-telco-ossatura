#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
LOCKDIR="$BASE/runtime/locks/TRFMC_GOOD_STATE_$TS"
FREEZE="$BASE/runtime/freezes/TRFMC_GOOD_STATE_V6R3_CONTROLROOM_DESIGN_PASS_$TS.tar.gz"

mkdir -p "$LOCKDIR" "$BASE/runtime/locks" "$BASE/runtime/freezes" "$BASE/runtime/deprecated_scripts"

echo "============================================================"
echo "TRFMC GOOD STATE LOCK V1"
echo "V6R3 + Registry + Control Room + Design System PASS"
echo "============================================================"

cd "$BASE"

echo
echo "[1/5] Verifica HTTP dei pilastri"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_integration_control_room_v2.html \
    /trfmc_portal_registry_unified.json \
    /assets/trfmc_design_system/trfmc_design_tokens.css
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$LOCKDIR/http.tsv"

echo
echo "[2/5] Copio report qualità attuali"
cp -av runtime/quality/latest_consolidation_registry "$LOCKDIR/latest_consolidation_registry" 2>/dev/null || true
cp -av runtime/quality/latest_master_design_system "$LOCKDIR/latest_master_design_system" 2>/dev/null || true

LATEST_DECISION="$(find runtime/reports -maxdepth 1 -type f -name 'TRFMC_VISUAL_MASTER_DECISION_*.md' | sort | tail -n 1)"
if [ -n "$LATEST_DECISION" ]; then
  cp -av "$LATEST_DECISION" "$LOCKDIR/"
fi

echo
echo "[3/5] Metto in quarantena script con quality gate fragile"
for s in \
  trfmc_consolidate_portal_registry_v1.sh \
  trfmc_create_master_design_system_v1.sh
do
  if [ -f "$s" ]; then
    cp -av "$s" "runtime/deprecated_scripts/${s%.sh}_DEPRECATED_$TS.sh"
    chmod -x "$s" || true
  fi
done

cat > runtime/deprecated_scripts/README_DO_NOT_RUN_FRAGILE_QUALITY_GATE.txt <<EOF2
Script deprecati / da non rilanciare senza patch:
- trfmc_consolidate_portal_registry_v1.sh
- trfmc_create_master_design_system_v1.sh

Motivo:
usano read con process substitution su curl -w e set -e; possono fermarsi durante il quality gate senza creare summary/http/latest.

Usare invece:
- trfmc_finalize_consolidation_quality_v1.sh
- trfmc_finalize_master_design_system_quality_v1.sh

Data: $(date)
EOF2

echo
echo "[4/5] Creo freeze minimale dello stato buono"
tar -czf "$FREEZE" \
  frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html \
  frontend/public/trfmc_integration_control_room.html \
  frontend/public/trfmc_integration_control_room_v2.html \
  frontend/public/trfmc_portal_registry_unified.json \
  frontend/public/assets/trfmc_design_system/trfmc_design_tokens.css \
  runtime/quality/latest_consolidation_registry \
  runtime/quality/latest_master_design_system \
  runtime/deprecated_scripts \
  runtime/reports/TRFMC_VISUAL_MASTER_DECISION_*.md \
  trfmc_finalize_consolidation_quality_v1.sh \
  trfmc_finalize_master_design_system_quality_v1.sh \
  2>/dev/null || true

ls -lh "$FREEZE" | tee "$LOCKDIR/freeze.txt"

echo
echo "[5/5] Scrivo decisione lock"
cat > "$LOCKDIR/GOOD_STATE_DECISION.txt" <<EOF2
TRFMC GOOD STATE LOCK
created_at=$(date)

PILASTRI:
- V6R3 official shell: /trfmc_official_safe_entrypoint_v6r3_command_center.html
- Registry unified: /trfmc_portal_registry_unified.json
- Control Room official: /trfmc_integration_control_room.html
- Control Room V2 preview: /trfmc_integration_control_room_v2.html
- Design tokens: /assets/trfmc_design_system/trfmc_design_tokens.css

REGOLE:
- Non modificare V6R3 direttamente.
- Non aggiungere doppie/triple barre.
- Non usare iframe come integrazione strutturale.
- Non usare CDN.
- Non rilanciare gli script deprecati.
- Ogni nuova modifica deve passare da preview, registry e quality gate.

FREEZE:
$FREEZE
EOF2

cat "$LOCKDIR/GOOD_STATE_DECISION.txt"

echo
echo "============================================================"
echo "LOCK COMPLETATO"
echo "Lockdir: $LOCKDIR"
echo "Freeze:  $FREEZE"
echo "============================================================"
