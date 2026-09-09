#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_POST_PROMOTION_GOVERNANCE_V1_$TS"
LATEST="$BASE/runtime/quality/latest_post_promotion_governance_v1"

FINAL="$BASE/runtime/quality/latest_final_promotion_gate_v1"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

GOV_PAGE="$PUBLIC/trfmc_post_promotion_control_center_v1.html"
NAV_PAGE="$PUBLIC/trfmc_canonical_navigation_map_v1.html"
ORPHAN_PAGE="$PUBLIC/trfmc_orphan_quarantine_room_v1.html"
CHANGE_PAGE="$PUBLIC/trfmc_change_control_policy_v1.html"
MANIFEST="$PUBLIC/trfmc_post_promotion_governance_manifest_v1.json"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC POST-PROMOTION GOVERNANCE V1"
echo "Canonical map · orphan quarantine · change control · no mass patch"
echo "============================================================"

if [ ! -f "$FINAL/summary.json" ]; then
  echo "ERRORE: manca Final Promotion Gate summary:"
  echo "$FINAL/summary.json"
  exit 10
fi

FINAL_RESULT="$(python3 - <<PY
import json
from pathlib import Path
j=json.loads(Path("$FINAL/summary.json").read_text())
print(j.get("result",""))
PY
)"

if [ "$FINAL_RESULT" != "PASS" ]; then
  echo "ERRORE: Final Promotion Gate non è PASS: $FINAL_RESULT"
  exit 11
fi

echo
echo "[1/8] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_POST_PROMOTION_GOVERNANCE_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_final_promotion_gate_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo PROMOTION_CERTIFIED_STATE.md"

python3 - "$FINAL" "$OUT" "$BASE" <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

final = Path(__import__("sys").argv[1])
out = Path(__import__("sys").argv[2])
base = Path(__import__("sys").argv[3])

s = json.loads((final / "summary.json").read_text(errors="ignore"))

text = f"""# TRFMC / Portale Telco - Promotion Certified State

Timestamp documento: {datetime.now(timezone.utc).isoformat()}

## Stato finale certificato

- Final Promotion Gate: {s.get("result")}
- HTTP non-200: {s.get("http_non_200")}
- External refs finali: {s.get("external_refs_final")}
- Iframe finali: {s.get("iframe_refs_final")}
- Leaf average score: {s.get("leaf_average_score")}
- Leaf critical pages: {s.get("leaf_critical_pages")}
- Leaf weak pages: {s.get("leaf_weak_pages")}
- Leaf good pages: {s.get("leaf_good_pages")}
- Leaf premium pages: {s.get("leaf_premium_pages")}
- Leaf premium ratio: {s.get("leaf_premium_ratio")}
- V6R3 official shell: invariata
- Control Room: invariata

## Entry point ufficiale

/trfmc_official_safe_entrypoint_v6r3_command_center.html

## Certificazione finale

/trfmc_final_promotion_gate_v1.html

## Policy operativa

Da questo stato in poi sono vietate patch massive non governate.

Ammesso solo:

1. micro-refinement su singole pagine leaf;
2. hardening delle service page;
3. quarantena o migrazione controllata degli orphan;
4. aggiornamento documentale;
5. nuovo freeze dopo ogni modifica significativa;
6. nessuna modifica diretta a V6R3 e Control Room senza change control.
"""

(base / "PROMOTION_CERTIFIED_STATE.md").write_text(text, encoding="utf-8")
(out / "PROMOTION_CERTIFIED_STATE.md").write_text(text, encoding="utf-8")
print(text)
PY

sha256sum \
  PROMOTION_CERTIFIED_STATE.md \
  frontend/public/trfmc_final_promotion_gate_v1.html \
  frontend/public/trfmc_final_promotion_manifest_v1.json \
  frontend/public/trfmc_portal_registry_unified.json \
  frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html \
  frontend/public/trfmc_integration_control_room.html \
  > "$OUT/PROMOTION_CERTIFIED_SHA256.txt"

cat "$OUT/PROMOTION_CERTIFIED_SHA256.txt"

echo
echo "[3/8] Analisi registry e creazione tabelle canoniche"

python3 - "$PUBLIC" "$REG" "$FINAL" "$OUT" <<'PY'
import json, csv, re, html, sys
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])
final = Path(sys.argv[3])
out = Path(sys.argv[4])

reg = json.loads(reg_path.read_text(errors="ignore"))
summary = json.loads((final / "summary.json").read_text(errors="ignore"))

score_by_url = {}
scorecard = final / "final_leaf_scorecard.tsv"
if scorecard.exists():
    with scorecard.open(errors="ignore") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        for r in reader:
            score_by_url[r.get("url","")] = r

def esc(x):
    return html.escape(str(x or ""))

def title_of(path, fallback):
    try:
        text = path.read_text(errors="ignore")
        m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
        if m:
            return html.unescape(re.sub(r"\s+", " ", m.group(1)).strip())
    except Exception:
        pass
    return fallback

def domain_of(url, title):
    s = (url + " " + title).lower()
    if any(k in s for k in ["antenna","rru","ret","cpri","beam"]): return "antenna"
    if any(k in s for k in ["microwave","smith","backhaul"]): return "microwave"
    if any(k in s for k in ["fiber","otdr","fronthaul"]): return "fiber"
    if any(k in s for k in ["cyber","evidence","intelligence","security"]): return "cyber"
    if any(k in s for k in ["datacenter","rack","pdu","power","thermal"]): return "datacenter"
    if any(k in s for k in ["knowledge","theory","academy","procedure"]): return "knowledge"
    if any(k in s for k in ["open5gs","ueransim","core","ran","aka","suci","supi","ngap","pfcp","gtp"]): return "core"
    if any(k in s for k in ["rf","spectrum","signal","fft","iq","vsa","dsp","ofdm","qam","sdr","physics"]): return "rf"
    return "generic"

rows = []
for p in reg.get("pages", []):
    url = p.get("url","")
    cls = p.get("class","unknown")
    if not url.endswith(".html"):
        continue
    f = public / url.lstrip("/")
    title = title_of(f, p.get("name", url))
    domain = score_by_url.get(url, {}).get("domain") or domain_of(url, title)
    score = score_by_url.get(url, {}).get("score", "")
    severity = score_by_url.get(url, {}).get("severity", "")
    rows.append({
        "class": cls,
        "domain": domain,
        "url": url,
        "title": title,
        "score": score,
        "severity": severity,
        "exists": f.exists(),
        "size": f.stat().st_size if f.exists() else 0
    })

canonical = [r for r in rows if r["class"] == "leaf_operational_candidate"]
services = [r for r in rows if r["class"] == "service"]
official = [r for r in rows if r["class"] == "official_shell"]
orphans = [r for r in rows if r["class"] == "orphan_or_legacy_candidate"]

canonical.sort(key=lambda x: (x["domain"], -(int(x["score"]) if str(x["score"]).isdigit() else 0), x["url"]))
services.sort(key=lambda x: x["url"])
official.sort(key=lambda x: x["url"])
orphans.sort(key=lambda x: x["url"])

def write_tsv(name, data):
    with (out / name).open("w", encoding="utf-8") as fp:
        fp.write("class\tdomain\tscore\tseverity\texists\tsize\turl\ttitle\n")
        for r in data:
            fp.write(f'{r["class"]}\t{r["domain"]}\t{r["score"]}\t{r["severity"]}\t{r["exists"]}\t{r["size"]}\t{r["url"]}\t{r["title"]}\n')

write_tsv("canonical_leaf_pages.tsv", canonical)
write_tsv("service_pages.tsv", services)
write_tsv("official_shell_pages.tsv", official)
write_tsv("orphan_quarantine_pages.tsv", orphans)

domain_counts = defaultdict(int)
domain_premium = defaultdict(int)
for r in canonical:
    domain_counts[r["domain"]] += 1
    if r["severity"] == "PREMIUM":
        domain_premium[r["domain"]] += 1

governance = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "source": "TRFMC_POST_PROMOTION_GOVERNANCE_V1",
    "final_result": summary.get("result"),
    "leaf_average_score": summary.get("leaf_average_score"),
    "leaf_critical_pages": summary.get("leaf_critical_pages"),
    "leaf_weak_pages": summary.get("leaf_weak_pages"),
    "leaf_good_pages": summary.get("leaf_good_pages"),
    "leaf_premium_pages": summary.get("leaf_premium_pages"),
    "leaf_premium_ratio": summary.get("leaf_premium_ratio"),
    "counts": {
        "canonical_leaf": len(canonical),
        "service": len(services),
        "official_shell": len(official),
        "orphan_quarantine": len(orphans),
        "total_html": len(rows)
    },
    "domain_counts": dict(sorted(domain_counts.items())),
    "domain_premium": dict(sorted(domain_premium.items())),
    "policy": "Promotion certified. No mass patch. Only controlled change."
}

(out / "governance_summary.json").write_text(json.dumps(governance, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(governance, indent=2, ensure_ascii=False))
PY

echo
echo "[4/8] Creo pagine governance HTML"

python3 - "$PUBLIC" "$OUT" "$GOV_PAGE" "$NAV_PAGE" "$ORPHAN_PAGE" "$CHANGE_PAGE" "$MANIFEST" <<'PY'
import json, csv, html, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
out = Path(sys.argv[2])
gov_page = Path(sys.argv[3])
nav_page = Path(sys.argv[4])
orphan_page = Path(sys.argv[5])
change_page = Path(sys.argv[6])
manifest = Path(sys.argv[7])

summary = json.loads((out / "governance_summary.json").read_text(errors="ignore"))

def esc(x): return html.escape(str(x or ""))

def read_tsv(name):
    p = out / name
    if not p.exists():
        return []
    with p.open(errors="ignore") as fp:
        return list(csv.DictReader(fp, delimiter="\t"))

canonical = read_tsv("canonical_leaf_pages.tsv")
services = read_tsv("service_pages.tsv")
official = read_tsv("official_shell_pages.tsv")
orphans = read_tsv("orphan_quarantine_pages.tsv")

def layout(title, subtitle, body):
    return f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.gov-grid{{display:grid;grid-template-columns:390px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}}
.gov-kpis{{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:8px}}
.gov-kpi{{border:1px solid rgba(0,229,255,.32);border-radius:9px;background:rgba(0,229,255,.05);padding:10px}}
.gov-kpi small{{display:block;color:#8fb8c8;text-transform:uppercase;font-size:10px}}
.gov-kpi b{{display:block;color:#75ff5b;font-size:20px}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
.badge{{display:inline-block;border:1px solid rgba(117,255,91,.35);background:rgba(117,255,91,.07);color:#75ff5b;border-radius:6px;padding:2px 6px;font-size:9px}}
.warn{{color:#ffd84d}}
.danger{{color:#ff3d7f}}
@media(max-width:1300px){{.gov-grid{{grid-template-columns:1fr}}.gov-kpis{{grid-template-columns:1fr 1fr}}}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">{esc(title)}</div>
    <div class="leaf-sub">{esc(subtitle)}</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_final_promotion_gate_v1.html">Final Gate</a>
    <a class="leaf-btn" href="/trfmc_canonical_navigation_map_v1.html">Canonical Map</a>
    <a class="leaf-btn" href="/trfmc_orphan_quarantine_room_v1.html">Orphan Room</a>
    <a class="leaf-btn" href="/trfmc_change_control_policy_v1.html">Change Policy</a>
  </div>
</header>
{body}
<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
</body>
</html>
'''

def table_rows(rows, include_score=True):
    out_rows = []
    for r in rows:
        score = f"<td>{esc(r.get('score'))}</td><td>{esc(r.get('severity'))}</td>" if include_score else ""
        out_rows.append(
            f'<tr><td>{esc(r.get("domain"))}</td>{score}<td><a href="{esc(r.get("url"))}">{esc(r.get("url"))}</a></td><td>{esc(r.get("title"))}</td></tr>'
        )
    return "\n".join(out_rows)

gov_body = f'''
<div class="gov-grid">
<aside class="leaf-panel">
<h2>Promotion Certified</h2>
<div class="leaf-card">
<h3>Decisione</h3>
<p><b>BASELINE CERTIFICATA</b></p>
<p>Da questo momento sono vietate patch massive non governate.</p>
</div>
<div class="leaf-card">
<h3>Governance</h3>
<p><span class="badge">Canonical map</span> <span class="badge">Orphan quarantine</span> <span class="badge">Change control</span></p>
</div>
</aside>
<main class="leaf-panel">
<h2>Post-Promotion Control Center</h2>
<div class="gov-kpis">
<div class="gov-kpi"><small>Leaf</small><b>{summary["counts"]["canonical_leaf"]}</b></div>
<div class="gov-kpi"><small>Service</small><b>{summary["counts"]["service"]}</b></div>
<div class="gov-kpi"><small>Orphan</small><b>{summary["counts"]["orphan_quarantine"]}</b></div>
<div class="gov-kpi"><small>Official</small><b>{summary["counts"]["official_shell"]}</b></div>
</div>
<div class="leaf-card">
<h3>Quality baseline</h3>
<p>Average: <b>{summary["leaf_average_score"]}</b> · Critical: <b>{summary["leaf_critical_pages"]}</b> · Weak: <b>{summary["leaf_weak_pages"]}</b> · Premium: <b>{summary["leaf_premium_pages"]}</b> · Ratio: <b>{summary["leaf_premium_ratio"]}</b></p>
</div>
<div class="leaf-card">
<h3>Domain counts</h3>
<pre>{esc(json.dumps(summary["domain_counts"], indent=2, ensure_ascii=False))}</pre>
</div>
</main>
</div>
'''
gov_page.write_text(layout("TRFMC Post-Promotion Control Center V1", "Baseline certificata, governance e change-control", gov_body), encoding="utf-8")

nav_body = f'''
<div class="gov-grid">
<aside class="leaf-panel">
<h2>Canonical Navigation</h2>
<div class="leaf-card">
<h3>Regola</h3>
<p>Questa è la mappa canonica delle leaf operative. È il perimetro sano del portale.</p>
</div>
</aside>
<main class="leaf-panel">
<h2>Canonical Leaf Pages</h2>
<table>
<thead><tr><th>Domain</th><th>Score</th><th>Severity</th><th>URL</th><th>Title</th></tr></thead>
<tbody>{table_rows(canonical, True)}</tbody>
</table>
</main>
</div>
'''
nav_page.write_text(layout("TRFMC Canonical Navigation Map V1", "Indice canonico delle leaf operative certificate", nav_body), encoding="utf-8")

orphan_body = f'''
<div class="gov-grid">
<aside class="leaf-panel">
<h2>Orphan Quarantine</h2>
<div class="leaf-card">
<h3>Policy</h3>
<p>Queste pagine non sono cancellate. Sono congelate in quarantena: si migrano solo con procedura controllata.</p>
</div>
<div class="leaf-card">
<h3>Azioni consentite</h3>
<p>Analisi, merge, sostituzione, archiviazione. Nessuna promozione diretta.</p>
</div>
</aside>
<main class="leaf-panel">
<h2>Orphan / Legacy Candidates</h2>
<table>
<thead><tr><th>Domain</th><th>URL</th><th>Title</th></tr></thead>
<tbody>{table_rows(orphans, False)}</tbody>
</table>
</main>
</div>
'''
orphan_page.write_text(layout("TRFMC Orphan Quarantine Room V1", "Quarantena controllata delle pagine legacy/orphan", orphan_body), encoding="utf-8")

change_body = '''
<div class="gov-grid">
<aside class="leaf-panel">
<h2>Change Control</h2>
<div class="leaf-card">
<h3>Blocco operativo</h3>
<p><b>NO MASS PATCH</b></p>
<p>Ogni modifica deve avere snapshot, hash, quality gate, rollback path.</p>
</div>
</aside>
<main class="leaf-panel">
<h2>Policy operativa</h2>
<div class="leaf-card">
<h3>Procedura ammessa</h3>
<ol>
<li>Definire una sola pagina o un solo dominio.</li>
<li>Snapshot prima della modifica.</li>
<li>Modifica scoped.</li>
<li>HTTP gate.</li>
<li>External/iframe gate.</li>
<li>Hash V6R3 e Control Room invariati.</li>
<li>Nuovo freeze se PASS.</li>
</ol>
</div>
<div class="leaf-card">
<h3>Divieti</h3>
<p class="danger">Vietati iframe, CDN, patch massive, doppie barre, shell parallele, modifica diretta di V6R3 senza change request.</p>
</div>
</main>
</div>
'''
change_page.write_text(layout("TRFMC Change Control Policy V1", "Regole per modificare il portale dopo la certificazione", change_body), encoding="utf-8")

manifest_data = {
    "id": "TRFMC_POST_PROMOTION_GOVERNANCE_V1",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "pages": {
        "control_center": "/trfmc_post_promotion_control_center_v1.html",
        "canonical_navigation": "/trfmc_canonical_navigation_map_v1.html",
        "orphan_quarantine": "/trfmc_orphan_quarantine_room_v1.html",
        "change_control": "/trfmc_change_control_policy_v1.html"
    },
    "source": "/trfmc_final_promotion_gate_v1.html",
    "policy": "Post-promotion governance. No mass patch. Service pages only."
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(manifest_data, indent=2, ensure_ascii=False))
PY

echo
echo "[5/8] Registro pagine governance come service"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

service_pages = [
    "/trfmc_post_promotion_control_center_v1.html",
    "/trfmc_canonical_navigation_map_v1.html",
    "/trfmc_orphan_quarantine_room_v1.html",
    "/trfmc_change_control_policy_v1.html",
]

for url in service_pages:
    f = public / url.lstrip("/")
    txt = f.read_text(errors="ignore")
    by_url[url] = {
        "class": "service",
        "name": f.name,
        "url": url,
        "size": f.stat().st_size,
        "post_promotion_governance": True,
        "has_iframe": False,
        "external_refs": 0,
        "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
        "upgrade": "Post Promotion Governance V1"
    }

reg["pages"] = list(by_url.values())

counts = {}
for p in reg["pages"]:
    c = p.get("class", "unknown")
    counts[c] = counts.get(c, 0) + 1

counts["total_html"] = len([p for p in reg["pages"] if str(p.get("url","")).endswith(".html")])
for k in ["official_shell", "service", "leaf_operational_candidate", "shell_or_legacy_container", "orphan_or_legacy_candidate"]:
    counts.setdefault(k, 0)

reg["counts"] = counts
reg["last_post_promotion_governance_v1_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "pages": service_pages,
    "policy": "Governance service pages only. V6R3 and Control Room files unchanged."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[6/8] HTTP + external/iframe gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_post_promotion_control_center_v1.html \
    /trfmc_canonical_navigation_map_v1.html \
    /trfmc_orphan_quarantine_room_v1.html \
    /trfmc_change_control_policy_v1.html \
    /trfmc_post_promotion_governance_manifest_v1.json \
    /trfmc_final_promotion_gate_v1.html \
    /trfmc_portal_registry_unified.json \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"

for f in "$GOV_PAGE" "$NAV_PAGE" "$ORPHAN_PAGE" "$CHANGE_PAGE" "$MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

echo
echo "[7/8] Summary finale"

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

python3 - "$OUT" "$REG" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

http = []
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 3:
        http.append({"url": p[0], "status": p[1], "bytes": p[2]})

non200 = sum(1 for r in http if r["status"] != "200")
ext = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
ifr = sum(1 for x in (out / "iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

sha = {}
for line in (out / "sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        sha[k] = v

protected_ok = (
    sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
)
registry_changed = sha.get("REG_SHA_BEFORE") != sha.get("REG_SHA_AFTER")

gov = json.loads((out / "governance_summary.json").read_text(errors="ignore"))
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_POST_PROMOTION_GOVERNANCE_V1",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts", {}).get("total_html"),
    "registry_counts": reg.get("counts", {}),
    "governance_counts": gov.get("counts"),
    "final_result_source": gov.get("final_result"),
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and protected_ok and registry_changed and gov.get("final_result") == "PASS" else "WARN",
    "policy": "Post-promotion governance service pages created. No mass patch."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[8/8] Freeze governance se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_POST_PROMOTION_GOVERNANCE_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    PROMOTION_CERTIFIED_STATE.md \
    frontend/public/trfmc_post_promotion_control_center_v1.html \
    frontend/public/trfmc_canonical_navigation_map_v1.html \
    frontend/public/trfmc_orphan_quarantine_room_v1.html \
    frontend/public/trfmc_change_control_policy_v1.html \
    frontend/public/trfmc_post_promotion_governance_manifest_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_post_promotion_governance_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze governance non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== GOVERNANCE SUMMARY ==="
cat "$OUT/governance_summary.json" | python3 -m json.tool
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "/trfmc_post_promotion_control_center_v1.html"
echo "/trfmc_canonical_navigation_map_v1.html"
echo "/trfmc_orphan_quarantine_room_v1.html"
echo "/trfmc_change_control_policy_v1.html"
echo "============================================================"
