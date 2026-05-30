#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_PERFECTION_AUTHORITY_V1_$TS"
LATEST="$BASE/runtime/quality/latest_perfection_authority_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"
PAGE="$PUBLIC/trfmc_perfection_authority_v1.html"
MANIFEST="$PUBLIC/trfmc_perfection_authority_manifest_v1.json"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC PERFECTION AUTHORITY V1"
echo "Read, score, classify, expose the abyss before fixing it"
echo "============================================================"

echo
echo "[1/7] Snapshot e hash protetti"
BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_PERFECTION_AUTHORITY_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/7] Analisi maturità pagina per pagina"
python3 - "$BASE" "$PUBLIC" "$REG" "$OUT" "$PAGE" "$MANIFEST" <<'PY'
import json, re, sys, html
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict

base=Path(sys.argv[1])
public=Path(sys.argv[2])
reg_path=Path(sys.argv[3])
out=Path(sys.argv[4])
page_path=Path(sys.argv[5])
manifest_path=Path(sys.argv[6])

reg=json.loads(reg_path.read_text(errors="ignore"))
pages=reg.get("pages",[])

external_re=re.compile(r'(href|src|url|@import)[^"\']*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com',re.I)

domain_rules=[
    ("antenna", ["antenna","rru","ret","cpri","port_mapping"], ["tower-site","rru-panel","port-map"]),
    ("microwave", ["microwave","smith","mw_","link"], ["microwave-dish","smith-chart"]),
    ("fiber", ["fiber","otdr","fronthaul"], ["fiber-otdr"]),
    ("core", ["core","ran","open5gs","ueransim","identity","aka","ngap","pfcp","gtp"], ["core-map"]),
    ("cyber", ["cyber","intelligence","evidence","war_room","threat"], ["cyber-evidence"]),
    ("datacenter", ["data_center","datacenter","rack","pdu","power"], ["rack-pdu"]),
    ("rf", ["rf_","spectrum","signal","vsa","fft","physics"], ["spectrum-scope"]),
    ("knowledge", ["knowledge","theory","procedures","academy"], [])
]

def detect_domain(url, text):
    s=(url+" "+text[:5000]).lower()
    for domain, keys, assets in domain_rules:
        if any(k in s for k in keys):
            return domain, assets
    return "generic", []

def has_any(text, terms):
    tl=text.lower()
    return any(t.lower() in tl for t in terms)

rows=[]
domain_stats=defaultdict(lambda: {"count":0,"score_sum":0,"critical":0,"weak":0,"good":0})
backlog=[]

for p in pages:
    url=p.get("url","")
    cls=p.get("class","unknown")
    if not url.endswith(".html"):
        continue

    f=public/url.lstrip("/")
    exists=f.exists()
    text=f.read_text(errors="ignore") if exists else ""

    title_match=re.search(r"<title[^>]*>(.*?)</title>", text, re.I|re.S)
    title=html.unescape(re.sub(r"\s+"," ",title_match.group(1)).strip()) if title_match else p.get("name",url)

    domain, required_assets=detect_domain(url, text)
    refs_external=len(external_re.findall(text))
    iframes=len(re.findall(r"<iframe\b", text, re.I))
    headers=len(re.findall(r'class\s*=\s*["\'][^"\']*leaf-top', text, re.I))
    navs=len(re.findall(r"<nav\b", text, re.I))

    checks={
        "exists": exists,
        "official_leaf": cls=="leaf_operational_candidate",
        "title": bool(title and len(title)>8),
        "single_header": headers<=1,
        "no_external": refs_external==0,
        "no_iframe": iframes==0,
        "design_tokens": "trfmc_design_system" in text or "trfmc_leaf_master_v1.css" in text,
        "visual_xp": "trfmc_visual_xp_v1" in text or "trfmc-vxp" in text,
        "gpu_runtime": "trfmc_gpu_visual_runtime_v2" in text or "trfmc-gpu-v2" in text,
        "asset_engine": "trfmc_visual_asset_engine_v3" in text or "trfmc-visual-asset" in text,
        "soul_runtime": "trfmc_soul_runtime_v1" in text or "trfmc-soul-v1" in text,
        "canvas": "<canvas" in text.lower() or "webgl" in text.lower(),
        "kpi": "leaf-kpi" in text or "KPI" in text,
        "formulas": "formulaLive" in text or "FSPL" in text or "VSWR" in text or "EIRP" in text or "Fourier" in text,
        "required_assets": all(a in text for a in required_assets) if required_assets else True,
    }

    weights={
        "exists":8,
        "title":4,
        "single_header":5,
        "no_external":8,
        "no_iframe":8,
        "design_tokens":8,
        "visual_xp":8,
        "gpu_runtime":8,
        "asset_engine":10,
        "soul_runtime":8,
        "canvas":8,
        "kpi":6,
        "formulas":6,
        "required_assets":5,
    }

    score=sum(weights[k] for k,v in checks.items() if v and k in weights)
    score=min(score,100)

    gaps=[]
    for k,v in checks.items():
        if k in weights and not v:
            gaps.append(k)
    if required_assets and not checks["required_assets"]:
        missing=[a for a in required_assets if a not in text]
        gaps.append("missing_domain_assets:"+",".join(missing))

    if score < 70:
        severity="CRITICAL"
    elif score < 85:
        severity="WEAK"
    elif score < 94:
        severity="GOOD"
    else:
        severity="PREMIUM"

    domain_stats[domain]["count"]+=1
    domain_stats[domain]["score_sum"]+=score
    if severity=="CRITICAL": domain_stats[domain]["critical"]+=1
    if severity=="WEAK": domain_stats[domain]["weak"]+=1
    if severity in ("GOOD","PREMIUM"): domain_stats[domain]["good"]+=1

    if severity in ("CRITICAL","WEAK"):
        backlog.append({
            "url":url,
            "title":title,
            "domain":domain,
            "score":score,
            "severity":severity,
            "gaps":gaps[:12]
        })

    rows.append({
        "url":url,
        "title":title,
        "class":cls,
        "domain":domain,
        "score":score,
        "severity":severity,
        "external_refs":refs_external,
        "iframes":iframes,
        "headers":headers,
        "navs":navs,
        "required_assets": ",".join(required_assets),
        "gaps": ",".join(gaps)
    })

rows.sort(key=lambda r:(r["score"], r["domain"], r["url"]))
backlog.sort(key=lambda r:(r["score"], r["url"]))

premium=sum(1 for r in rows if r["score"]>=94)
good=sum(1 for r in rows if 85<=r["score"]<94)
weak=sum(1 for r in rows if 70<=r["score"]<85)
critical=sum(1 for r in rows if r["score"]<70)
avg=round(sum(r["score"] for r in rows)/max(1,len(rows)),2)

domain_table=[]
for d,s in sorted(domain_stats.items()):
    domain_table.append({
        "domain":d,
        "pages":s["count"],
        "avg_score":round(s["score_sum"]/max(1,s["count"]),2),
        "critical":s["critical"],
        "weak":s["weak"],
        "good_or_premium":s["good"]
    })

summary={
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "authority":"TRFMC_PERFECTION_AUTHORITY_V1",
    "analyzed_html":len(rows),
    "average_score":avg,
    "premium_pages":premium,
    "good_pages":good,
    "weak_pages":weak,
    "critical_pages":critical,
    "perfection_gate": {
        "target_average_score":92,
        "target_premium_ratio":0.80,
        "target_critical_pages":0,
        "current_premium_ratio":round(premium/max(1,len(rows)),3),
        "status":"PASS" if avg>=92 and critical==0 and premium/max(1,len(rows))>=0.80 else "NOT_YET"
    },
    "top_debts": backlog[:25],
    "policy":"Measure before patching. V6R3 and Control Room protected."
}

(out/"summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False)+"\n")

with (out/"page_scorecard.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\tclass\turl\ttitle\texternal_refs\tiframes\theaders\tnavs\trequired_assets\tgaps\n")
    for r in rows:
        fp.write(f'{r["score"]}\t{r["severity"]}\t{r["domain"]}\t{r["class"]}\t{r["url"]}\t{r["title"]}\t{r["external_refs"]}\t{r["iframes"]}\t{r["headers"]}\t{r["navs"]}\t{r["required_assets"]}\t{r["gaps"]}\n')

with (out/"domain_summary.tsv").open("w") as fp:
    fp.write("domain\tpages\tavg_score\tcritical\tweak\tgood_or_premium\n")
    for r in domain_table:
        fp.write(f'{r["domain"]}\t{r["pages"]}\t{r["avg_score"]}\t{r["critical"]}\t{r["weak"]}\t{r["good_or_premium"]}\n')

md=["# TRFMC Perfection Backlog V1\n"]
md.append(f"- Average score: {avg}/100")
md.append(f"- Premium: {premium}")
md.append(f"- Good: {good}")
md.append(f"- Weak: {weak}")
md.append(f"- Critical: {critical}")
md.append("")
md.append("## Prime 25 pagine da correggere")
for item in backlog[:25]:
    md.append(f'### {item["severity"]} · {item["score"]}/100 · {item["url"]}')
    md.append(f'- Dominio: {item["domain"]}')
    md.append(f'- Titolo: {item["title"]}')
    md.append(f'- Gap: {", ".join(item["gaps"])}')
    md.append("")
(out/"PERFECTION_BACKLOG.md").write_text("\n".join(md),encoding="utf-8")

manifest={
    "id":"TRFMC_PERFECTION_AUTHORITY_V1",
    "generated":summary["timestamp"],
    "score_model":{
        "external_refs":"must be zero",
        "iframe_refs":"must be zero",
        "design_tokens":"mandatory for premium",
        "gpu_runtime":"mandatory for premium",
        "asset_engine":"mandatory for domain reality",
        "soul_runtime":"mandatory for mission continuity",
        "formulas_kpi":"mandatory for engineering credibility",
        "domain_assets":"mandatory for visual consistency"
    },
    "reports":{
        "summary":"runtime/quality/latest_perfection_authority_v1/summary.json",
        "scorecard":"runtime/quality/latest_perfection_authority_v1/page_scorecard.tsv",
        "domain_summary":"runtime/quality/latest_perfection_authority_v1/domain_summary.tsv",
        "backlog":"runtime/quality/latest_perfection_authority_v1/PERFECTION_BACKLOG.md"
    }
}
manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n")

def esc(s): return html.escape(str(s))

score_rows="\n".join(
    f'<tr class="{r["severity"].lower()}"><td>{r["score"]}</td><td>{esc(r["severity"])}</td><td>{esc(r["domain"])}</td><td><a href="{esc(r["url"])}">{esc(r["url"])}</a></td><td>{esc(r["gaps"][:160])}</td></tr>'
    for r in rows[:120]
)

domain_rows="\n".join(
    f'<tr><td>{esc(r["domain"])}</td><td>{r["pages"]}</td><td>{r["avg_score"]}</td><td>{r["critical"]}</td><td>{r["weak"]}</td><td>{r["good_or_premium"]}</td></tr>'
    for r in domain_table
)

debt_cards="\n".join(
    f'<div class="debt"><b>{esc(item["severity"])} · {item["score"]}/100</b><br><a href="{esc(item["url"])}">{esc(item["url"])}</a><br><span>{esc(", ".join(item["gaps"][:8]))}</span></div>'
    for item in backlog[:18]
)

page_html=f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Perfection Authority V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.pa-grid{{display:grid;grid-template-columns:390px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}}
.pa-kpis{{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin-bottom:8px}}
.pa-kpi{{border:1px solid rgba(0,229,255,.32);border-radius:8px;background:rgba(0,229,255,.05);padding:10px;box-shadow:0 0 22px rgba(0,229,255,.10)}}
.pa-kpi small{{display:block;color:#8fb8c8;text-transform:uppercase;font-size:10px}}
.pa-kpi b{{display:block;color:#75ff5b;font-size:20px;margin-top:4px}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
tr.critical td{{color:#ff9abc}}
tr.weak td{{color:#ffd84d}}
tr.good td{{color:#dffaff}}
tr.premium td{{color:#75ff5b}}
.debt{{border:1px solid rgba(255,216,77,.28);border-radius:8px;margin:6px 0;padding:8px;background:rgba(255,216,77,.035);font-family:ui-monospace,Consolas,monospace;font-size:10px}}
.debt b{{color:#ffd84d}} .debt span{{color:#8fb8c8}}
@media(max-width:1300px){{.pa-grid{{grid-template-columns:1fr}}.pa-kpis{{grid-template-columns:1fr 1fr}}}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Perfection Authority V1</div>
    <div class="leaf-sub">Misura l’abisso: score, gap, dominio, asset mancanti, debiti visuali e tecnico-ingegneristici</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_visual_asset_engine_lab_v3.html">Asset Engine</a>
    <a class="leaf-btn" href="/trfmc_soul_runtime_lab_v1.html">Soul Lab</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>

<div class="pa-grid">
  <aside class="leaf-panel">
    <h2>Perfection Gate</h2>
    <div class="leaf-card">
      <h3>Stato</h3>
      <p><b>{esc(summary["perfection_gate"]["status"])}</b></p>
      <p>Obiettivo: average ≥ 92, critical = 0, premium ratio ≥ 80%.</p>
      <p>Questo è il punto di verità: finché non passa, il portale è potente ma non perfetto.</p>
    </div>
    <div class="leaf-card">
      <h3>Top debt</h3>
      {debt_cards}
    </div>
  </aside>

  <main class="leaf-panel">
    <h2>Perfection Dashboard</h2>
    <div class="pa-kpis">
      <div class="pa-kpi"><small>Average</small><b>{avg}</b></div>
      <div class="pa-kpi"><small>Premium</small><b>{premium}</b></div>
      <div class="pa-kpi"><small>Good</small><b>{good}</b></div>
      <div class="pa-kpi"><small>Weak</small><b>{weak}</b></div>
      <div class="pa-kpi"><small>Critical</small><b>{critical}</b></div>
    </div>

    <div class="leaf-card">
      <h3>Domain maturity</h3>
      <table>
        <thead><tr><th>Domain</th><th>Pages</th><th>Avg</th><th>Critical</th><th>Weak</th><th>Good/Premium</th></tr></thead>
        <tbody>{domain_rows}</tbody>
      </table>
    </div>

    <div class="leaf-card">
      <h3>Worst-first scorecard</h3>
      <table>
        <thead><tr><th>Score</th><th>Severity</th><th>Domain</th><th>URL</th><th>Gaps</th></tr></thead>
        <tbody>{score_rows}</tbody>
      </table>
    </div>
  </main>
</div>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
</body>
</html>
'''
page_path.write_text(page_html,encoding="utf-8")
print(json.dumps(summary,indent=2,ensure_ascii=False))
PY

echo
echo "[3/7] Registro Perfection Authority nel registry"
python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public=Path(sys.argv[1])
reg_path=Path(sys.argv[2])
reg=json.loads(reg_path.read_text(errors="ignore"))
pages=reg.get("pages",[])
by_url={p.get("url"):p for p in pages if p.get("url")}

target=public/"trfmc_perfection_authority_v1.html"
txt=target.read_text(errors="ignore")

by_url["/trfmc_perfection_authority_v1.html"]={
  "class":"service",
  "name":"trfmc_perfection_authority_v1.html",
  "url":"/trfmc_perfection_authority_v1.html",
  "size":target.stat().st_size,
  "canvas":False,
  "quality_authority":True,
  "core_api":False,
  "has_iframe":False,
  "external_refs":0,
  "refs_count":len(re.findall(r'href=|src=',txt,re.I)),
  "upgrade":"Perfection Authority V1 scorecard and debt control tower"
}

reg["pages"]=list(by_url.values())
counts={}
for p in reg["pages"]:
    c=p.get("class","unknown")
    counts[c]=counts.get(c,0)+1
counts["total_html"]=len(reg["pages"])
for k in ["official_shell","service","leaf_operational_candidate","shell_or_legacy_container","orphan_or_legacy_candidate"]:
    counts.setdefault(k,0)

reg["counts"]=counts
reg["last_perfection_authority_v1_update"]={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "page":"/trfmc_perfection_authority_v1.html",
  "policy":"authority page only; V6R3 and Control Room protected"
}
reg_path.write_text(json.dumps(reg,indent=2,ensure_ascii=False)+"\n")
print(json.dumps(reg["counts"],indent=2,ensure_ascii=False))
PY

echo
echo "[4/7] HTTP gate"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_perfection_authority_v1.html \
    /trfmc_perfection_authority_manifest_v1.json \
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

echo
echo "[5/7] Controlli sicurezza contenuto"
: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/fused_forbidden_refs.txt"
: > "$OUT/content_checks.txt"

for f in "$PAGE" "$MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
  grep -nEi 'MASTER FUSED|trfmc_master_fused|fallback shell' "$f" >> "$OUT/fused_forbidden_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC Perfection Authority V1" \
  "Perfection Gate" \
  "Worst-first scorecard" \
  "Domain maturity" \
  "TRFMC_PERFECTION_AUTHORITY_V1"
do
  if grep -Rqs "$token" "$PAGE" "$MANIFEST" "$OUT"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

echo
echo "[6/7] Summary finale"
python3 - "$OUT" "$REG" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

out=Path(sys.argv[1])
reg_path=Path(sys.argv[2])

authority=json.loads((out/"summary.json").read_text(errors="ignore"))

http=[]
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=3:
        http.append({"url":p[0],"status":p[1],"bytes":p[2]})

non200=sum(1 for x in http if x["status"]!="200")
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
fused=sum(1 for x in (out/"fused_forbidden_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
miss=sum(1 for x in (out/"content_checks.txt").read_text(errors="ignore").splitlines() if x.startswith("MISS:"))

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.strip().split("=",1)
        sha[k]=v

protected_ok=(
    sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER")
)
registry_changed=sha.get("REG_SHA_BEFORE")!=sha.get("REG_SHA_AFTER")
reg=json.loads(reg_path.read_text(errors="ignore"))

final={
  "timestamp":datetime.now(timezone.utc).isoformat(),
  "authority":"TRFMC_PERFECTION_AUTHORITY_V1",
  "page":"/trfmc_perfection_authority_v1.html",
  "http_non_200":non200,
  "external_refs":external,
  "iframe_refs":iframe,
  "fused_forbidden_refs":fused,
  "content_check_miss":miss,
  "protected_v6r3_and_control_unchanged":protected_ok,
  "registry_changed_intentionally":registry_changed,
  "registry_total_html":reg.get("counts",{}).get("total_html"),
  "registry_service":reg.get("counts",{}).get("service"),
  "measured_average_score":authority.get("average_score"),
  "measured_critical_pages":authority.get("critical_pages"),
  "measured_weak_pages":authority.get("weak_pages"),
  "measured_premium_pages":authority.get("premium_pages"),
  "perfection_gate_status":authority.get("perfection_gate",{}).get("status"),
  "result":"PASS" if non200==0 and external==0 and iframe==0 and fused==0 and miss==0 and protected_ok and registry_changed else "WARN",
  "policy":"Perfection Authority measures the portal before more visual patches. V6R3 and Control Room unchanged."
}
(out/"quality_gate_summary.json").write_text(json.dumps(final,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(final["result"]+"\n")
print(json.dumps(final,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[7/7] Freeze se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PERFECTION_AUTHORITY_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_perfection_authority_v1.html \
    frontend/public/trfmc_perfection_authority_manifest_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_perfection_authority_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/quality_gate_summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== DOMAIN SUMMARY ==="
column -t -s $'\t' "$OUT/domain_summary.tsv" | sed -n '1,80p'
echo
echo "=== WORST FIRST ==="
column -t -s $'\t' "$OUT/page_scorecard.tsv" | sed -n '1,80p'
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_perfection_authority_v1.html"
echo "============================================================"
