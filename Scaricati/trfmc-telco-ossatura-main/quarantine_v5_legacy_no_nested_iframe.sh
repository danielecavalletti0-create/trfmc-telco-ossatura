#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
BK="$BASE/runtime/backups/QUARANTINE_V5_LEGACY_$TS"
OUT="$BASE/runtime/quality/TRFMC_V5_LEGACY_NO_NESTED_$TS"

mkdir -p "$BK" "$OUT"

echo "============================================================"
echo "TRFMC - QUARANTINE V5 LEGACY / NO NESTED IFRAME"
echo "============================================================"

echo
echo "[1/5] Backup V5 originale"
cp -av "$PUBLIC/trfmc_supervisor_mission_control_v5.html" "$BK/" 2>/dev/null || true

echo
echo "[2/5] Riscrivo V5 come pagina LEGACY/SERVICE senza iframe annidati"
cat > "$PUBLIC/trfmc_supervisor_mission_control_v5.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC V5 Legacy Supervisor - Service Only</title>
<style>
:root{
  --bg:#01060d;--p:#061120;--p2:#081522;--line:#1d6f9f;
  --text:#eaf3ff;--muted:#86a7c6;--cyan:#00d9ff;--green:#7dff4f;
  --yellow:#ffd500;--red:#ff3366;
}
*{box-sizing:border-box}
html,body{margin:0;min-height:100%;background:radial-gradient(circle at 50% 0,rgba(0,217,255,.14),transparent 36%),#01060d;color:var(--text);font:12px Segoe UI,system-ui,sans-serif}
header{height:62px;background:#050b13;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;padding:0 16px}
h1{margin:0;font-size:18px;letter-spacing:.08em;text-transform:uppercase;color:var(--cyan)}
.sub{color:var(--muted);font-size:11px}
main{padding:18px;display:grid;grid-template-columns:1fr 1fr;gap:14px}
.card{border:1px solid #245b7d;background:linear-gradient(180deg,#061321,#02070f);border-radius:9px;padding:16px}
.card h2{margin:0 0 10px;color:var(--green);text-transform:uppercase;font-size:16px}
.card p{color:#cde7ff;line-height:1.45}
.badge{display:inline-block;border:1px solid rgba(125,255,79,.45);color:var(--green);padding:4px 7px;border-radius:5px;font:11px Consolas,monospace;margin:3px}
a.btn{display:inline-block;background:#10233a;color:var(--text);border:1px solid #285d82;border-radius:5px;padding:9px 12px;text-decoration:none;margin:5px 5px 5px 0}
a.btn:hover{border-color:var(--cyan);background:#145078;box-shadow:inset 3px 0 0 var(--yellow)}
.warn{border-color:#7a5b13;background:#181204}
.warn h2{color:var(--yellow)}
.ok h2{color:var(--green)}
code{color:var(--yellow)}
@media(max-width:900px){main{grid-template-columns:1fr}}
</style>
</head>
<body>
<header>
  <div>
    <h1>TRFMC V5 Legacy Supervisor</h1>
    <div class="sub">Pagina storica di servizio. Nessun iframe annidato. Le console si aprono in nuova scheda.</div>
  </div>
  <div>
    <span class="badge">LEGACY</span>
    <span class="badge">SERVICE ONLY</span>
    <span class="badge">NO NESTED IFRAME</span>
  </div>
</header>

<main>
  <section class="card warn">
    <h2>V5 messa in modalità legacy</h2>
    <p>
      Questa pagina non è più un ingresso operativo principale. In precedenza caricava
      <code>trfmc_unified_evidence_supervisor_v4.html</code> dentro iframe, creando una catena shell→shell.
    </p>
    <p>
      Da ora V5 resta solo come pagina storica/servizio. Le console collegate si aprono in nuova scheda.
    </p>
  </section>

  <section class="card ok">
    <h2>Ingressi consigliati</h2>
    <a class="btn" href="/trfmc_official_safe_entrypoint_v6r2_premium_console.html">Apri V6R2 Premium Console</a>
    <a class="btn" href="/trfmc_portal_link_graph_v1.html">Apri Portal Link Graph</a>
    <a class="btn" href="/trfmc_official_safe_entrypoint_v6r1_flat.html">Apri V6R1 Fallback</a>
  </section>

  <section class="card">
    <h2>Console legacy apribili</h2>
    <a class="btn" href="/trfmc_unified_evidence_supervisor_v4.html" target="_blank">Apri V4 Evidence Supervisor</a>
    <a class="btn" href="/trfmc_unified_matrix_room_v3.html" target="_blank">Apri V3 Matrix Room</a>
    <a class="btn" href="/trfmc_unified_instrument_shell_lab_v2.html" target="_blank">Apri V2 Instrument Shell</a>
  </section>

  <section class="card">
    <h2>Regola architetturale</h2>
    <p>
      Consentito: V6R2/V6R1 caricano moduli foglia.
      Non consentito come entrypoint: shell dentro shell dentro iframe.
    </p>
    <p>
      Moduli foglia: RF/Antenna Wall, Antenna Explorer, DSP Chain, Wi-Fi/QAM, 5G Core/RAN, NOC, War Room, Master.
    </p>
  </section>
</main>
</body>
</html>
HTML

echo
echo "[3/5] Rilancio audit iframe globale"
grep -RIn '<iframe' "$PUBLIC" --include='*.html' > "$OUT/all_iframes_raw.txt" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
import re, csv, json

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
public = base / "frontend/public"
out = sorted((base / "runtime/quality").glob("TRFMC_V5_LEGACY_NO_NESTED_*"))[-1]

rows = []
for html in sorted(public.rglob("*.html")):
    text = html.read_text(errors="ignore")
    if "<iframe" not in text.lower():
        continue
    rel = "/" + str(html.relative_to(public))
    for iframe in re.findall(r"<iframe\b[^>]*>", text, flags=re.I|re.S):
        src_match = re.search(r'\bsrc=["\']([^"\']+)["\']', iframe, flags=re.I)
        src = src_match.group(1) if src_match else ""
        rows.append({"page": rel, "src": src, "iframe_tag": " ".join(iframe.split())[:240]})

shell_words = ["supervisor","unified","matrix","shell","mission_control","official_safe_entrypoint","entrypoint"]
service, operational, suspicious = [], [], []

for r in rows:
    page = r["page"].lower()
    src = r["src"].lower()
    page_is_shell = any(x in page for x in shell_words)
    src_is_shell = any(x in src for x in shell_words)

    if src_is_shell:
        suspicious.append({**r, "reason": "iframe carica una shell/supervisor/entrypoint"})
    elif page_is_shell:
        service.append({**r, "reason": "pagina servizio/shell con iframe verso modulo foglia"})
    else:
        operational.append({**r, "reason": "pagina operativa con iframe: da verificare"})

def write(name, data):
    with (out / name).open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["page","src","reason","iframe_tag"], delimiter="\t")
        w.writeheader()
        w.writerows(data)

with (out / "iframe_edges.tsv").open("w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["page","src","iframe_tag"], delimiter="\t")
    w.writeheader()
    w.writerows(rows)

write("service_shell_iframes.tsv", service)
write("leaf_or_operational_iframes.tsv", operational)
write("suspicious_nested_shell_iframes.tsv", suspicious)

summary = {
    "total_iframe_edges": len(rows),
    "service_shell_iframes": len(service),
    "leaf_or_operational_iframes": len(operational),
    "suspicious_nested_shell_iframes": len(suspicious),
    "result": "PASS" if len(suspicious) == 0 and len(operational) == 0 else "WARN"
}
(out / "summary.json").write_text(json.dumps(summary, indent=4) + "\n")
print(json.dumps(summary, indent=4))
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_iframe_topology_audit"

echo
echo "[4/5] HTTP check V5 e ingressi principali"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_supervisor_mission_control_v5.html \
    /trfmc_official_safe_entrypoint_v6r2_premium_console.html \
    /trfmc_portal_link_graph_v1.html \
    /trfmc_official_safe_entrypoint_v6r1_flat.html \
    /api/health
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u")
    echo -e "$u\t$code\t$bytes"
  done
} > "$OUT/http.tsv"

echo
echo "[5/5] Report finale"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== SOSPETTI ==="
column -t -s $'\t' "$OUT/suspicious_nested_shell_iframes.tsv"

echo
echo "=== PAGINE OPERATIVE CON IFRAME ==="
column -t -s $'\t' "$OUT/leaf_or_operational_iframes.tsv"

echo
echo "============================================================"
echo "V5 QUARANTINATA COME LEGACY/SERVICE"
echo "Backup: $BK"
echo "Report: $OUT"
echo "============================================================"
