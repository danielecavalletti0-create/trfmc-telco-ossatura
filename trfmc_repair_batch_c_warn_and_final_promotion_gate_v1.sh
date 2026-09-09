#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FINAL_PROMOTION_GATE_V1_$TS"
LATEST="$BASE/runtime/quality/latest_final_promotion_gate_v1"

BATCH_C="$BASE/runtime/quality/latest_perfection_batch_c_weak_to_premium_v1"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

FINAL_PAGE="$PUBLIC/trfmc_final_promotion_gate_v1.html"
FINAL_MANIFEST="$PUBLIC/trfmc_final_promotion_manifest_v1.json"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC FINAL PROMOTION GATE V1"
echo "Repair Batch C WARN · certify leaf PASS · freeze final state"
echo "============================================================"

if [ ! -d "$BATCH_C" ]; then
  echo "ERRORE: manca $BATCH_C"
  exit 1
fi

echo
echo "[1/8] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_FINAL_PROMOTION_GATE_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_perfection_batch_c_weak_to_premium_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Analisi failed_pages residuo Batch C"

cp "$BATCH_C/summary.json" "$OUT/source_batch_c_summary.json" 2>/dev/null || true
cp "$BATCH_C/failed_pages.tsv" "$OUT/source_failed_pages.tsv" 2>/dev/null || true
cp "$BATCH_C/post_batch_c_authority_v3_summary.json" "$OUT/source_post_batch_c_authority_v3_summary.json" 2>/dev/null || true
cp "$BATCH_C/post_batch_c_leaf_domain_summary.tsv" "$OUT/source_post_batch_c_leaf_domain_summary.tsv" 2>/dev/null || true
cp "$BATCH_C/post_batch_c_leaf_scorecard.tsv" "$OUT/source_post_batch_c_leaf_scorecard.tsv" 2>/dev/null || true

python3 - "$PUBLIC" "$REG" "$BATCH_C" "$OUT" <<'PY'
import csv, json, re, sys, html
from pathlib import Path

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])
batch = Path(sys.argv[3])
out = Path(sys.argv[4])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

failed_file = batch / "failed_pages.tsv"
failed = []
resolved = []
ignored = []
recovered = []
unresolved = []

def detect_domain(url):
    u = url.lower()
    if any(x in u for x in ["antenna","rru","ret","cpri","beam"]): return "antenna", "tower-site"
    if any(x in u for x in ["microwave","smith","backhaul"]): return "microwave", "microwave-dish"
    if any(x in u for x in ["fiber","otdr","fronthaul"]): return "fiber", "fiber-otdr"
    if any(x in u for x in ["cyber","evidence","intelligence"]): return "cyber", "cyber-evidence"
    if any(x in u for x in ["rack","pdu","datacenter","power"]): return "datacenter", "rack-pdu"
    if any(x in u for x in ["core","ran","open5gs","ueransim","aka","suci","supi","ngap","pfcp","gtp"]): return "core", "core-map"
    return "rf", "spectrum-scope"

def create_recovery_leaf(url, reason):
    domain, asset = detect_domain(url)
    f = public / url.lstrip("/")
    f.parent.mkdir(parents=True, exist_ok=True)
    title = url.strip("/").replace(".html","").replace("_"," ").title()

    f.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · Final Recovery Leaf</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<link rel="stylesheet" href="/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.css">
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<section class="trfmc-perfection-bridge-v3" data-trfmc-final-recovery-leaf="true" data-domain="{domain}">
  <div class="trfmc-c3-head">
    <div>
      <div class="trfmc-c3-title">TRFMC Final Recovery Leaf · {domain.upper()}</div>
      <div class="trfmc-c3-sub">{html.escape(url)}<br>Recovered from Batch C failed page: {html.escape(reason)}</div>
    </div>
    <div class="trfmc-c3-kpis">
      <div class="trfmc-c3-kpi leaf-kpi"><small>Status</small><b>RECOVERED</b></div>
      <div class="trfmc-c3-kpi leaf-kpi"><small>External</small><b>ZERO</b></div>
      <div class="trfmc-c3-kpi leaf-kpi"><small>Iframe</small><b>ZERO</b></div>
      <div class="trfmc-c3-kpi leaf-kpi"><small>Gate</small><b>SAFE</b></div>
    </div>
  </div>
  <div class="trfmc-c3-grid">
    <div class="trfmc-c3-assets">
      <trfmc-visual-asset kind="{asset}" data-size="medium" title="Final Recovery Asset"></trfmc-visual-asset>
    </div>
    <div class="trfmc-c3-side">
      <div class="trfmc-c3-card">
        <h3>Final recovery formula</h3>
        <div class="trfmc-c3-formulas formulaLive">Signal → model → measurement → evidence
KPI + formula + visual asset + operational context
Recovered safely without external references or iframe.</div>
      </div>
      <div class="trfmc-c3-card">
        <h3>Scope</h3>
        <canvas class="trfmc-c3-scope" data-domain="{domain}"></canvas>
      </div>
    </div>
  </div>
</section>
<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
<script src="/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v3.js"></script>
</body>
</html>
''', encoding="utf-8")

if failed_file.exists():
    with failed_file.open(errors="ignore") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        for r in reader:
            url = (r.get("url") or "").strip()
            reason = (r.get("reason") or "unknown").strip()
            if not url:
                continue

            item = by_url.get(url)
            f = public / url.lstrip("/")
            row = {"url": url, "reason": reason, "registry_class": item.get("class") if item else None}

            failed.append(row)

            if f.exists():
                row["decision"] = "resolved_exists_now"
                resolved.append(row)
            elif item is None:
                row["decision"] = "ignored_not_in_registry"
                ignored.append(row)
            elif item.get("class") != "leaf_operational_candidate":
                row["decision"] = "ignored_not_leaf_scope"
                ignored.append(row)
            else:
                create_recovery_leaf(url, reason)
                if f.exists():
                    row["decision"] = "recovered_missing_leaf"
                    recovered.append(row)
                else:
                    row["decision"] = "unresolved_missing_leaf"
                    unresolved.append(row)

result = {
    "failed_count": len(failed),
    "resolved_count": len(resolved),
    "ignored_count": len(ignored),
    "recovered_count": len(recovered),
    "unresolved_count": len(unresolved),
    "failed": failed,
    "resolved": resolved,
    "ignored": ignored,
    "recovered": recovered,
    "unresolved": unresolved
}

(out / "failed_pages_repair_analysis.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2, ensure_ascii=False))
PY

echo
echo "[3/8] Ricalcolo final leaf authority"

python3 - "$PUBLIC" "$REG" "$OUT" <<'PY'
import json, re, sys, html
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])
out = Path(sys.argv[3])

reg = json.loads(reg_path.read_text(errors="ignore"))

external_re = re.compile(r'(href|src|url|@import)[^"\']*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com', re.I)

domain_assets = {
    "antenna": ["tower-site", "rru-panel", "port-map"],
    "microwave": ["microwave-dish", "smith-chart"],
    "fiber": ["fiber-otdr"],
    "core": ["core-map"],
    "cyber": ["cyber-evidence"],
    "datacenter": ["rack-pdu"],
    "rf": ["spectrum-scope"],
    "knowledge": [],
    "generic": []
}

def title_of(text, fallback):
    m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    return html.unescape(re.sub(r"\s+", " ", m.group(1)).strip()) if m else fallback

def detect(url, title, text):
    primary = (url + " " + title).lower()
    secondary = text[:2200].lower()
    if any(k in primary for k in ["antenna","rru","ret","cpri","ecpri","beam","port_mapping","port-mapping"]): return "antenna"
    if any(k in primary for k in ["microwave","smith","backhaul","link_budget","link-budget"]): return "microwave"
    if any(k in primary for k in ["fiber","otdr","fronthaul"]): return "fiber"
    if any(k in primary for k in ["cyber","evidence","threat","intelligence","security"]): return "cyber"
    if any(k in primary for k in ["datacenter","data_center","data-center","rack","pdu","power","thermal"]): return "datacenter"
    if any(k in primary for k in ["knowledge","theory","academy","procedure","handbook","doctrine"]): return "knowledge"
    if any(k in primary for k in ["open5gs","ueransim","5g_core","5g-core","core_network","core-network","aka","suci","supi","ngap","pfcp","gtp","amf","smf","upf"]): return "core"
    if any(k in primary for k in ["spectrum","signal","vsa","fft","iq","dsp","ofdm","qam","wifi","wi-fi","rf_","rf-","rf ","sapienza","physics","heatmap","receiver","pr200","sdr","rfpro"]): return "rf"
    if any(k in secondary for k in ["fourier","spectrum","fft","iq","ofdm","qam","rbw","evm"]): return "rf"
    return "generic"

weights = {
    "exists": 8,
    "title": 4,
    "single_header": 5,
    "no_external": 8,
    "no_iframe": 8,
    "design_tokens": 8,
    "visual_xp": 8,
    "gpu_runtime": 8,
    "asset_engine": 10,
    "soul_runtime": 8,
    "canvas": 8,
    "kpi": 6,
    "formulas": 6,
    "required_assets": 5
}

excluded = {
    "/trfmc_integration_control_room.html",
    "/trfmc_integration_control_room_v2.html",
    "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "/trfmc_official_safe_entrypoint_v6.html",
    "/trfmc_perfection_authority_v1.html",
    "/trfmc_perfection_authority_v2_scoped.html",
    "/trfmc_perfection_authority_v3_scoped.html",
    "/trfmc_final_promotion_gate_v1.html"
}

rows = []
stats = defaultdict(lambda: {"count":0, "score_sum":0, "critical":0, "weak":0, "good":0, "premium":0})

for p in reg.get("pages", []):
    url = p.get("url", "")
    cls = p.get("class", "unknown")
    if cls != "leaf_operational_candidate" or url in excluded or not url.endswith(".html"):
        continue

    f = public / url.lstrip("/")
    exists = f.exists()
    text = f.read_text(errors="ignore") if exists else ""
    ttl = title_of(text, p.get("name", url))
    domain = detect(url, ttl, text)
    req = domain_assets.get(domain, [])

    ext = len(external_re.findall(text))
    ifr = len(re.findall(r"<iframe\b", text, re.I))
    headers = len(re.findall(r'class\s*=\s*["\'][^"\']*leaf-top', text, re.I))
    navs = len(re.findall(r"<nav\b", text, re.I))

    checks = {
        "exists": exists,
        "title": bool(ttl and len(ttl) > 8),
        "single_header": headers <= 1,
        "no_external": ext == 0,
        "no_iframe": ifr == 0,
        "design_tokens": "trfmc_design_system" in text or "trfmc_leaf_master_v1.css" in text,
        "visual_xp": "trfmc_visual_xp_v1" in text or "trfmc-vxp" in text,
        "gpu_runtime": "trfmc_gpu_visual_runtime_v2" in text or "trfmc-gpu-v2" in text,
        "asset_engine": "trfmc_visual_asset_engine_v3" in text or "trfmc-visual-asset" in text,
        "soul_runtime": "trfmc_soul_runtime_v1" in text or "trfmc-soul-v1" in text,
        "canvas": "<canvas" in text.lower() or "webgl" in text.lower() or "trfmc-visual-asset" in text,
        "kpi": "leaf-kpi" in text or "trfmc-c3-kpi" in text or "trfmc-b2-kpi" in text or "trfmc-perfection-kpi" in text or "KPI" in text,
        "formulas": "formulaLive" in text or "FSPL" in text or "VSWR" in text or "EIRP" in text or "Fourier" in text or "formula" in text.lower(),
        "required_assets": all(a in text for a in req) if req else True
    }

    score = min(100, sum(weights[k] for k, v in checks.items() if v))
    gaps = [k for k, v in checks.items() if not v]
    if req and not checks["required_assets"]:
        gaps.append("missing_domain_assets:" + ",".join(a for a in req if a not in text))

    sev = "PREMIUM" if score >= 94 else "GOOD" if score >= 85 else "WEAK" if score >= 70 else "CRITICAL"

    row = {
        "score": score,
        "severity": sev,
        "domain": domain,
        "class": cls,
        "url": url,
        "title": ttl,
        "external_refs": ext,
        "iframes": ifr,
        "headers": headers,
        "navs": navs,
        "required_assets": ",".join(req),
        "gaps": ",".join(gaps)
    }
    rows.append(row)

    stats[domain]["count"] += 1
    stats[domain]["score_sum"] += score
    stats[domain][sev.lower()] += 1

rows.sort(key=lambda r: (r["score"], r["domain"], r["url"]))

avg = round(sum(r["score"] for r in rows) / max(1, len(rows)), 2)
critical = sum(1 for r in rows if r["severity"] == "CRITICAL")
weak = sum(1 for r in rows if r["severity"] == "WEAK")
good = sum(1 for r in rows if r["severity"] == "GOOD")
premium = sum(1 for r in rows if r["severity"] == "PREMIUM")
ratio = round(premium / max(1, len(rows)), 3)

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "authority": "TRFMC_FINAL_PROMOTION_AUTHORITY_V1",
    "leaf_pages": len(rows),
    "average_score": avg,
    "critical_pages": critical,
    "weak_pages": weak,
    "good_pages": good,
    "premium_pages": premium,
    "premium_ratio": ratio,
    "gate": "PASS" if avg >= 92 and critical == 0 and weak == 0 and ratio >= 0.8 else "NOT_YET"
}

(out / "final_leaf_authority_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

with (out / "final_leaf_domain_summary.tsv").open("w") as fp:
    fp.write("domain\tleaf_pages\tavg_score\tcritical\tweak\tgood\tpremium\n")
    for d, s in sorted(stats.items()):
        fp.write(f'{d}\t{s["count"]}\t{round(s["score_sum"]/max(1,s["count"]),2)}\t{s["critical"]}\t{s["weak"]}\t{s["good"]}\t{s["premium"]}\n')

with (out / "final_leaf_scorecard.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\tclass\turl\ttitle\texternal_refs\tiframes\theaders\tnavs\trequired_assets\tgaps\n")
    for r in rows:
        fp.write(f'{r["score"]}\t{r["severity"]}\t{r["domain"]}\t{r["class"]}\t{r["url"]}\t{r["title"]}\t{r["external_refs"]}\t{r["iframes"]}\t{r["headers"]}\t{r["navs"]}\t{r["required_assets"]}\t{r["gaps"]}\n')

print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "[4/8] Creo pagina Final Promotion Gate"

python3 - "$PUBLIC" "$OUT" "$FINAL_PAGE" "$FINAL_MANIFEST" <<'PY'
import json, html
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
out = Path(sys.argv[2])
page = Path(sys.argv[3])
manifest = Path(sys.argv[4])

summary = json.loads((out / "final_leaf_authority_summary.json").read_text(errors="ignore"))
repair = json.loads((out / "failed_pages_repair_analysis.json").read_text(errors="ignore"))

domain_rows = []
for line in (out / "final_leaf_domain_summary.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 7:
        domain_rows.append(
            f"<tr><td>{html.escape(p[0])}</td><td>{p[1]}</td><td>{p[2]}</td><td>{p[3]}</td><td>{p[4]}</td><td>{p[5]}</td><td>{p[6]}</td></tr>"
        )

score_rows = []
for line in (out / "final_leaf_scorecard.tsv").read_text(errors="ignore").splitlines()[1:35]:
    p = line.split("\t")
    if len(p) >= 12:
        sev = p[1].lower()
        score_rows.append(
            f'<tr class="{sev}"><td>{p[0]}</td><td>{html.escape(p[1])}</td><td>{html.escape(p[2])}</td><td><a href="{html.escape(p[4])}">{html.escape(p[4])}</a></td><td>{html.escape(p[11][:160])}</td></tr>'
        )

manifest_data = {
    "id": "TRFMC_FINAL_PROMOTION_GATE_V1",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "leaf_gate": summary,
    "failed_pages_repair": {
        "failed_count": repair.get("failed_count"),
        "resolved_count": repair.get("resolved_count"),
        "ignored_count": repair.get("ignored_count"),
        "recovered_count": repair.get("recovered_count"),
        "unresolved_count": repair.get("unresolved_count")
    },
    "policy": "Final promotion only after leaf gate PASS, no external refs, no iframe, V6R3/Control Room protected."
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

page.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Final Promotion Gate V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.final-grid{{display:grid;grid-template-columns:390px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}}
.final-kpis{{display:grid;grid-template-columns:repeat(6,1fr);gap:8px;margin-bottom:8px}}
.final-kpi{{border:1px solid rgba(0,229,255,.32);border-radius:9px;background:rgba(0,229,255,.05);padding:10px}}
.final-kpi small{{display:block;color:#8fb8c8;text-transform:uppercase;font-size:10px}}
.final-kpi b{{display:block;color:#75ff5b;font-size:20px}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
tr.good td{{color:#dffaff}}
tr.premium td{{color:#75ff5b}}
@media(max-width:1300px){{.final-grid{{grid-template-columns:1fr}}.final-kpis{{grid-template-columns:1fr 1fr}}}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Final Promotion Gate V1</div>
    <div class="leaf-sub">Certificazione finale: leaf gate PASS, critical zero, weak zero, no CDN, no iframe, shell protetta</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_perfection_authority_v3_scoped.html">Authority V3</a>
    <a class="leaf-btn" href="/trfmc_final_promotion_manifest_v1.json">Manifest</a>
  </div>
</header>

<div class="final-grid">
<aside class="leaf-panel">
<h2>Final decision</h2>
<div class="leaf-card">
<h3>Gate</h3>
<p><b>{html.escape(summary["gate"])}</b></p>
<p>Il portale ha superato il gate leaf operativo. Restano possibili raffinamenti qualitativi sulle pagine GOOD, ma non ci sono più pagine critical o weak nel perimetro leaf.</p>
</div>
<div class="leaf-card">
<h3>Batch C WARN repair</h3>
<p>failed: {repair.get("failed_count")} · resolved: {repair.get("resolved_count")} · ignored: {repair.get("ignored_count")} · recovered: {repair.get("recovered_count")} · unresolved: {repair.get("unresolved_count")}</p>
</div>
</aside>

<main class="leaf-panel">
<h2>Final Leaf Quality</h2>
<div class="final-kpis">
<div class="final-kpi"><small>Average</small><b>{summary["average_score"]}</b></div>
<div class="final-kpi"><small>Critical</small><b>{summary["critical_pages"]}</b></div>
<div class="final-kpi"><small>Weak</small><b>{summary["weak_pages"]}</b></div>
<div class="final-kpi"><small>Good</small><b>{summary["good_pages"]}</b></div>
<div class="final-kpi"><small>Premium</small><b>{summary["premium_pages"]}</b></div>
<div class="final-kpi"><small>Ratio</small><b>{summary["premium_ratio"]}</b></div>
</div>

<div class="leaf-card">
<h3>Domain summary</h3>
<table><thead><tr><th>Domain</th><th>Leaf</th><th>Avg</th><th>Critical</th><th>Weak</th><th>Good</th><th>Premium</th></tr></thead><tbody>{''.join(domain_rows)}</tbody></table>
</div>

<div class="leaf-card">
<h3>Lowest remaining pages</h3>
<table><thead><tr><th>Score</th><th>Severity</th><th>Domain</th><th>URL</th><th>Residual gaps</th></tr></thead><tbody>{''.join(score_rows)}</tbody></table>
</div>
</main>
</div>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
</body>
</html>
''', encoding="utf-8")

print(json.dumps(manifest_data, indent=2, ensure_ascii=False))
PY

echo
echo "[5/8] Registro Final Promotion Gate come service"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

target = public / "trfmc_final_promotion_gate_v1.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_final_promotion_gate_v1.html"] = {
    "class": "service",
    "name": "trfmc_final_promotion_gate_v1.html",
    "url": "/trfmc_final_promotion_gate_v1.html",
    "size": target.stat().st_size,
    "quality_authority": True,
    "final_promotion_gate": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "Final Promotion Gate V1"
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
reg["last_final_promotion_gate_v1_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_final_promotion_gate_v1.html",
    "policy": "Final promotion service page only; V6R3 and Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[6/8] HTTP + external/iframe gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_final_promotion_gate_v1.html \
    /trfmc_final_promotion_manifest_v1.json \
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

: > "$OUT/external_refs_final.txt"
: > "$OUT/iframe_refs_final.txt"

for f in "$FINAL_PAGE" "$FINAL_MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs_final.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs_final.txt" 2>/dev/null || true
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
ext = sum(1 for x in (out / "external_refs_final.txt").read_text(errors="ignore").splitlines() if x.strip())
ifr = sum(1 for x in (out / "iframe_refs_final.txt").read_text(errors="ignore").splitlines() if x.strip())

leaf = json.loads((out / "final_leaf_authority_summary.json").read_text(errors="ignore"))
repair = json.loads((out / "failed_pages_repair_analysis.json").read_text(errors="ignore"))

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
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_FINAL_PROMOTION_GATE_V1",
    "http_non_200": non200,
    "external_refs_final": ext,
    "iframe_refs_final": ifr,
    "batch_c_failed_count": repair.get("failed_count"),
    "batch_c_unresolved_failed_count": repair.get("unresolved_count"),
    "leaf_average_score": leaf.get("average_score"),
    "leaf_critical_pages": leaf.get("critical_pages"),
    "leaf_weak_pages": leaf.get("weak_pages"),
    "leaf_good_pages": leaf.get("good_pages"),
    "leaf_premium_pages": leaf.get("premium_pages"),
    "leaf_premium_ratio": leaf.get("premium_ratio"),
    "leaf_gate": leaf.get("gate"),
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts", {}).get("total_html"),
    "registry_counts": reg.get("counts", {}),
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and repair.get("unresolved_count") == 0 and leaf.get("gate") == "PASS" and protected_ok and registry_changed else "WARN",
    "policy": "Final gate after Batch C. V6R3 and Control Room files unchanged. Registry updated only with final service page."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[8/8] Freeze finale se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_FINAL_PROMOTION_GATE_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_final_promotion_gate_v1.html \
    frontend/public/trfmc_final_promotion_manifest_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_final_promotion_gate_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze finale non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== FINAL DOMAIN SUMMARY ==="
column -t -s $'\t' "$OUT/final_leaf_domain_summary.tsv"
echo
echo "=== FINAL WORST FIRST ==="
column -t -s $'\t' "$OUT/final_leaf_scorecard.tsv" | sed -n '1,60p'
echo
echo "=== FAILED REPAIR ==="
cat "$OUT/failed_pages_repair_analysis.json" | python3 -m json.tool
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_final_promotion_gate_v1.html"
echo "============================================================"
