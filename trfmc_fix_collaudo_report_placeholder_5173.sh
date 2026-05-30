#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
SCRIPT="$BASE/trfmc_collaudo_portale_5173.sh"
TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC FIX COLLAUDO REPORT PLACEHOLDER - 5173"
echo "============================================================"
date
echo "SCRIPT=$SCRIPT"

cd "$BASE"

if [ ! -f "$SCRIPT" ]; then
  echo "ERRORE: non trovo $SCRIPT"
  exit 1
fi

cp -a "$SCRIPT" "$SCRIPT.bak_report_placeholder_$TS"

python3 - <<'PY'
from pathlib import Path

p = Path("trfmc_collaudo_portale_5173.sh")
s = p.read_text()

old = '''echo "=== 1B) PULIZIA REPORT PUBBLICO PRECEDENTE PER EVITARE AUTO-FALSI-POSITIVI ==="
rm -f "$PUBLIC/trfmc_collaudo_report.html" 2>/dev/null || true
echo "OK: report pubblico precedente rimosso prima della scansione"
echo
'''

new = '''echo "=== 1B) PULIZIA REPORT PUBBLICO PRECEDENTE + PLACEHOLDER PULITO ==="
rm -f "$PUBLIC/trfmc_collaudo_report.html" 2>/dev/null || true
cat > "$PUBLIC/trfmc_collaudo_report.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>TRFMC Collaudo Report</title>
</head>
<body>
<h1>TRFMC Collaudo Report</h1>
<p>Report in rigenerazione. Il file definitivo viene sovrascritto al termine del collaudo.</p>
<p><a href="/api/health">Health 5173</a></p>
</body>
</html>
HTML
echo "OK: placeholder pubblico pulito creato prima della scansione"
echo
'''

if old not in s:
    print("ATTENZIONE: blocco esatto non trovato. Provo inserimento conservativo.")
    marker = 'echo "=== 2) CENSIMENTO FILE HTML ==="'
    if marker not in s:
        raise SystemExit("ERRORE: marker censimento non trovato")
    if "PLACEHOLDER PULITO" not in s:
        s = s.replace(marker, new + marker, 1)
else:
    s = s.replace(old, new, 1)

p.write_text(s)
print("PATCH OK:", p)
PY

bash -n "$SCRIPT"

echo
echo "PATCH COMPLETATA."
