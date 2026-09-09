#!/usr/bin/env bash
set -Eeuo pipefail

FILE="frontend/src/app/main.tsx"
TS="$(date +%Y%m%d_%H%M%S)"
BAK="${FILE}.bak_true_spectrum_${TS}"

cp "$FILE" "$BAK"

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/src/app/main.tsx")
s = p.read_text()

imp = "import { TrueSpectrumAnalyzer } from '../rf_instruments/instruments/TrueSpectrumAnalyzer'\n"

if imp not in s:
    marker = "import '../styles.css'\n"
    if marker in s:
        s = s.replace(marker, marker + imp, 1)
    else:
        raise SystemExit("ERRORE: import '../styles.css' non trovato")

panel = """\n\n              <Panel\n                title="TRFMC True Spectrum Analyzer"\n                icon={<Radio />}\n                className="mc-span-2"\n              >\n                <TrueSpectrumAnalyzer />\n              </Panel>\n"""

if "<TrueSpectrumAnalyzer />" not in s:
    target = """              <Panel title="Link Budget" icon={<Gauge/>}>"""
    start = s.find(target)
    if start == -1:
        raise SystemExit("ERRORE: Panel Link Budget non trovato")

    end = s.find("</Panel>", start)
    if end == -1:
        raise SystemExit("ERRORE: chiusura </Panel> Link Budget non trovata")

    end += len("</Panel>")
    s = s[:end] + panel + s[end:]

p.write_text(s)
print("PATCH OK:", p)
PY

echo "Backup: $BAK"
echo
grep -n "TrueSpectrumAnalyzer\|TRFMC True Spectrum Analyzer" "$FILE"
