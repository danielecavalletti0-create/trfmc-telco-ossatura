#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
SCRIPT="$BASE/trfmc_collaudo_portale_5173.sh"
TS="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo "TRFMC PATCH COLLAUDO - NO SELF FALSE POSITIVE"
echo "============================================================"
date
echo "SCRIPT=$SCRIPT"

cd "$BASE"

if [ ! -f "$SCRIPT" ]; then
  echo "ERRORE: non trovo $SCRIPT"
  exit 1
fi

cp -a "$SCRIPT" "$SCRIPT.bak_no_self_false_positive_$TS"

python3 - <<'PY'
from pathlib import Path

p = Path("trfmc_collaudo_portale_5173.sh")
s = p.read_text()

# 1) Prima del censimento, elimina il report pubblico precedente.
needle = 'echo "=== 2) CENSIMENTO FILE HTML ==="'
insert = '''echo "=== 1B) PULIZIA REPORT PUBBLICO PRECEDENTE PER EVITARE AUTO-FALSI-POSITIVI ==="
rm -f "$PUBLIC/trfmc_collaudo_report.html" 2>/dev/null || true
echo "OK: report pubblico precedente rimosso prima della scansione"
echo
'''
if insert not in s:
    s = s.replace(needle, insert + needle, 1)

# 2) Nel parser Python, considera locali i link assoluti verso 127.0.0.1:5173.
old = '''        if parsed.scheme in ("http", "https"):
            external.append((route, tag, attr, ref_s))
            refs_rows.append((route, tag, attr, ref_s, "EXTERNAL", ""))
            continue'''
new = '''        if parsed.scheme in ("http", "https"):
            if parsed.hostname in ("127.0.0.1", "localhost") and (parsed.port in (None, 5173)):
                refs_rows.append((route, tag, attr, ref_s, "LOCAL_PORTAL", ""))
                continue
            external.append((route, tag, attr, ref_s))
            refs_rows.append((route, tag, attr, ref_s, "EXTERNAL", ""))
            continue'''
if old in s:
    s = s.replace(old, new, 1)

p.write_text(s)
print("PATCH OK:", p)
PY

echo
echo "=== TEST SINTASSI SCRIPT ==="
bash -n "$SCRIPT"

echo
echo "PATCH COMPLETATA."
