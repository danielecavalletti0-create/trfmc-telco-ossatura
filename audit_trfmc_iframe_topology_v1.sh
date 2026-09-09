#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_IFRAME_TOPOLOGY_AUDIT_$TS"

mkdir -p "$OUT"

echo "============================================================"
echo "TRFMC IFRAME TOPOLOGY AUDIT V1"
echo "============================================================"

echo
echo "[1/5] Cerco tutte le pagine con iframe"
grep -RIn '<iframe' "$PUBLIC" --include='*.html' > "$OUT/all_iframes_raw.txt" 2>/dev/null || true

echo
echo "[2/5] Estraggo iframe src"
python3 - <<'PY'
from pathlib import Path
import re
import csv

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
public = base / "frontend/public"
out = sorted((base / "runtime/quality").glob("TRFMC_IFRAME_TOPOLOGY_AUDIT_*"))[-1]

rows = []
for html in sorted(public.rglob("*.html")):
    text = html.read_text(errors="ignore")
    if "<iframe" not in text.lower():
        continue

    rel = "/" + str(html.relative_to(public))
    iframes = re.findall(r"<iframe\b[^>]*>", text, flags=re.I|re.S)

    for iframe in iframes:
        src_match = re.search(r'\bsrc=["\']([^"\']+)["\']', iframe, flags=re.I)
        src = src_match.group(1) if src_match else ""
        rows.append({
            "page": rel,
            "src": src,
            "iframe_tag": " ".join(iframe.split())[:240]
        })

with (out / "iframe_edges.tsv").open("w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["page","src","iframe_tag"], delimiter="\t")
    w.writeheader()
    w.writerows(rows)

# classificazione
shell_words = [
    "supervisor",
    "unified",
    "matrix",
    "shell",
    "mission_control",
    "official_safe_entrypoint",
    "entrypoint"
]

service_pages = []
leaf_pages = []
suspicious = []

for r in rows:
    page = r["page"].lower()
    src = r["src"].lower()

    page_is_shell = any(x in page for x in shell_words)
    src_is_shell = any(x in src for x in shell_words)

    if src_is_shell:
        suspicious.append({**r, "reason": "iframe carica una shell/supervisor/entrypoint"})
    elif page_is_shell:
        service_pages.append({**r, "reason": "pagina servizio/shell con iframe verso modulo foglia"})
    else:
        leaf_pages.append({**r, "reason": "pagina operativa con iframe: da verificare"})

def write_tsv(name, data):
    with (out / name).open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["page","src","reason","iframe_tag"], delimiter="\t")
        w.writeheader()
        w.writerows(data)

write_tsv("service_shell_iframes.tsv", service_pages)
write_tsv("leaf_or_operational_iframes.tsv", leaf_pages)
write_tsv("suspicious_nested_shell_iframes.tsv", suspicious)

summary = {
    "total_iframe_edges": len(rows),
    "service_shell_iframes": len(service_pages),
    "leaf_or_operational_iframes": len(leaf_pages),
    "suspicious_nested_shell_iframes": len(suspicious),
}

import json
(out / "summary.json").write_text(json.dumps(summary, indent=4) + "\n")
print(json.dumps(summary, indent=4))
PY

echo
echo "[3/5] Creo report leggibile"
cat > "$OUT/report.txt" <<REPORT
TRFMC IFRAME TOPOLOGY AUDIT V1
timestamp=$TS

SUMMARY:
$(cat "$OUT/summary.json")

FILES:
- $OUT/iframe_edges.tsv
- $OUT/service_shell_iframes.tsv
- $OUT/leaf_or_operational_iframes.tsv
- $OUT/suspicious_nested_shell_iframes.tsv
REPORT

echo
echo "[4/5] Link latest"
ln -sfn "$OUT" "$BASE/runtime/quality/latest_iframe_topology_audit"

echo
echo "[5/5] Output sintetico"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== TUTTI GLI IFRAME ==="
column -t -s $'\t' "$OUT/iframe_edges.tsv" | sed -n '1,120p'

echo
echo "=== SOSPETTI: SHELL DENTRO IFRAME ==="
column -t -s $'\t' "$OUT/suspicious_nested_shell_iframes.tsv" | sed -n '1,120p'

echo
echo "=== PAGINE SERVIZIO / SHELL ==="
column -t -s $'\t' "$OUT/service_shell_iframes.tsv" | sed -n '1,120p'

echo
echo "============================================================"
echo "AUDIT COMPLETATO"
echo "REPORT_DIR=$OUT"
echo "============================================================"
