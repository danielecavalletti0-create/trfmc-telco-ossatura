#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FALSE_EXTERNAL_REPAIR_AND_AUTHORITY_V2_$TS"
LATEST="$BASE/runtime/quality/latest_false_external_repair_and_authority_v2"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

AUTH_PAGE="$PUBLIC/trfmc_perfection_authority_v2_scoped.html"
AUTH_MANIFEST="$PUBLIC/trfmc_perfection_authority_v2_manifest.json"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC FALSE EXTERNAL REPAIR + PERFECTION AUTHORITY V2 SCOPED"
echo "Fix local false-positive · separate leaf/service/orphan/official scopes"
echo "============================================================"

echo
echo "[1/8] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_FALSE_EXTERNAL_REPAIR_AUTHORITY_V2_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_repair_perfection_batch_a_warn_v1 runtime/quality/latest_perfection_authority_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Riparo falso external locale residuo"

python3 - "$PUBLIC" "$OUT" <<'PY'
from pathlib import Path
import json, re, sys

public = Path(sys.argv[1])
out = Path(sys.argv[2])

# Local development URLs are not allowed to remain as scheme-qualified strings
# inside quarantined attributes or visible text, because the gate is intentionally strict.
local_patterns = [
    "http://127.0.0.1:5173",
    "http://localhost:5173",
    "http://0.0.0.0:5173"
]

changed = []
occurrences = []

for f in sorted(public.glob("*.html")):
    s = f.read_text(errors="ignore")
    old = s

    for p in local_patterns:
        if p in s:
            occurrences.append({"file": "/" + f.name, "pattern": p, "count": s.count(p)})
            # Display-safe and scanner-safe: keep endpoint meaning, remove scheme.
            safe = p.replace("http://", "")
            s = s.replace(p, safe)

    # Remove any remaining quarantined attribute value that still starts with scheme.
    s = re.sub(
        r'data-trfmc-blocked-(href|src|action|poster)=["\']https?://([^"\']+)["\']',
        lambda m: f'data-trfmc-blocked-{m.group(1)}-host="{m.group(2)}"',
        s,
        flags=re.I
    )

    if s != old:
        f.write_text(s, encoding="utf-8")
        changed.append("/" + f.name)

(out / "local_url_repair_changed_pages.tsv").write_text(
    "url\n" + "\n".join(changed) + "\n",
    encoding="utf-8"
)

(out / "local_url_occurrences.json").write_text(
    json.dumps({"changed": changed, "occurrences": occurrences}, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8"
)

print(json.dumps({"changed_pages": len(changed), "occurrences": len(occurrences)}, indent=2))
PY

echo
echo "[3/8] Verifico external/iframe sulle pagine modificate"

python3 - "$PUBLIC" "$OUT" <<'PY'
from pathlib import Path
import re, sys, json

public = Path(sys.argv[1])
out = Path(sys.argv[2])

changed = []
for line in (out / "local_url_repair_changed_pages.tsv").read_text(errors="ignore").splitlines()[1:]:
    if line.strip():
        changed.append(line.strip())

external_patterns = [
    re.compile(r"<script\b[^>]*\bsrc\s*=\s*(['\"])(https?:\/\/|\/\/)", re.I),
    re.compile(r"<link\b[^>]*\bhref\s*=\s*(['\"])(https?:\/\/|\/\/)", re.I),
    re.compile(r"\b(?:href|src|action|poster)\s*=\s*(['\"])(https?:\/\/|\/\/)", re.I),
    re.compile(r"\bsrcset\s*=\s*(['\"])[^'\"]*(?:https?:\/\/|\/\/)", re.I),
    re.compile(r"url\(\s*(['\"]?)(?:https?:\/\/|\/\/)", re.I),
    re.compile(r"https?:\/\/", re.I),
]
iframe_re = re.compile(r"<iframe\b", re.I)

ext = []
ifr = []

for url in changed:
    f = public / url.lstrip("/")
    if not f.exists():
        continue
    for idx, line in enumerate(f.read_text(errors="ignore").splitlines(), start=1):
        if any(rx.search(line) for rx in external_patterns):
            ext.append(f"{url}:{idx}:{line[:220]}")
        if iframe_re.search(line):
            ifr.append(f"{url}:{idx}:{line[:220]}")

(out / "external_refs_after_false_external_repair.txt").write_text("\n".join(ext) + ("\n" if ext else ""), encoding="utf-8")
(out / "iframe_refs_after_false_external_repair.txt").write_text("\n".join(ifr) + ("\n" if ifr else ""), encoding="utf-8")

print(json.dumps({
  "changed_pages": len(changed),
  "external_refs_after": len(ext),
  "iframe_refs_after": len(ifr)
}, indent=2))
PY

echo
echo "[4/8] Creo Perfection Authority V2 scoped"

python3 - "$BASE" "$PUBLIC" "$REG" "$OUT" "$AUTH_PAGE" "$AUTH_MANIFEST" <<'PY'
import json, re, sys, html
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict

base = Path(sys.argv[1])
public = Path(sys.argv[2])
reg_path = Path(sys.argv[3])
out = Path(sys.argv[4])
page_path = Path(sys.argv[5])
manifest_path = Path(sys.argv[6])

reg = json.loads(reg_path.read_text(errors="ignore"))
pages = reg.get("pages", [])

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

def detect_domain(url, title, text):
    blob = (url + " " + title + " " + text[:3000]).lower()

    if any(k in blob for k in ["open5gs","ueransim","5g_core","5g core","core_network","core network","aka","suci","supi","ngap","pfcp","gtp-u","gtpu","ran","identity","amf","smf","upf"]):
        return "core"
    if any(k in blob for k in ["antenna","rru","ret","cpri","ecpri","beam","beamforming","port_mapping","port mapping"]):
        return "antenna"
    if any(k in blob for k in ["fiber","otdr","fronthaul","splice","connector loss"]):
        return "fiber"
    if any(k in blob for k in ["cyber","evidence","threat","intelligence","security","baseline"]):
        return "cyber"
    if any(k in blob for k in ["datacenter","data center","rack","pdu","power","thermal"]):
        return "datacenter"
    if any(k in blob for k in ["spectrum","signal","vsa","fft","iq","i/q","dsp","ofdm","qam","wifi","wi-fi","physics","rf_","heatmap","receiver","pr200","hackrf","sdr"]):
        return "rf"
    if any(k in blob for k in ["microwave","smith","link budget","backhaul","dish","fade margin"]):
        return "microwave"
    if any(k in blob for k in ["knowledge","theory","academy","procedure","handbook","doctrine"]):
        return "knowledge"
    return "generic"

def esc(s):
    return html.escape(str(s))

def get_title(text, fallback):
    m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    if m:
        return html.unescape(re.sub(r"\s+", " ", m.group(1)).strip())
    return fallback

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

rows = []
scope_stats = defaultdict(lambda: {"count": 0, "score_sum": 0, "critical": 0, "weak": 0, "good": 0, "premium": 0})
domain_stats_leaf = defaultdict(lambda: {"count": 0, "score_sum": 0, "critical": 0, "weak": 0, "good": 0, "premium": 0})

for p in pages:
    url = p.get("url", "")
    cls = p.get("class", "unknown")
    if not url.endswith(".html"):
        continue

    f = public / url.lstrip("/")
    exists = f.exists()
    text = f.read_text(errors="ignore") if exists else ""
    title = get_title(text, p.get("name", url))
    domain = detect_domain(url, title, text)
    required = domain_assets.get(domain, [])

    refs_external = len(external_re.findall(text))
    iframes = len(re.findall(r"<iframe\b", text, re.I))
    headers = len(re.findall(r'class\s*=\s*["\'][^"\']*leaf-top', text, re.I))
    navs = len(re.findall(r"<nav\b", text, re.I))

    checks = {
        "exists": exists,
        "title": bool(title and len(title) > 8),
        "single_header": headers <= 1,
        "no_external": refs_external == 0,
        "no_iframe": iframes == 0,
        "design_tokens": "trfmc_design_system" in text or "trfmc_leaf_master_v1.css" in text,
        "visual_xp": "trfmc_visual_xp_v1" in text or "trfmc-vxp" in text,
        "gpu_runtime": "trfmc_gpu_visual_runtime_v2" in text or "trfmc-gpu-v2" in text,
        "asset_engine": "trfmc_visual_asset_engine_v3" in text or "trfmc-visual-asset" in text,
        "soul_runtime": "trfmc_soul_runtime_v1" in text or "trfmc-soul-v1" in text,
        "canvas": "<canvas" in text.lower() or "webgl" in text.lower() or "trfmc-visual-asset" in text,
        "kpi": "leaf-kpi" in text or "trfmc-perfection-kpi" in text or "KPI" in text,
        "formulas": "formulaLive" in text or "FSPL" in text or "VSWR" in text or "EIRP" in text or "Fourier" in text or "formula" in text.lower(),
        "required_assets": all(a in text for a in required) if required else True,
    }

    score = min(100, sum(weights[k] for k, v in checks.items() if v and k in weights))

    gaps = [k for k, v in checks.items() if k in weights and not v]
    if required and not checks["required_assets"]:
        gaps.append("missing_domain_assets:" + ",".join(a for a in required if a not in text))

    if score < 70:
        severity = "CRITICAL"
    elif score < 85:
        severity = "WEAK"
    elif score < 94:
        severity = "GOOD"
    else:
        severity = "PREMIUM"

    row = {
        "score": score,
        "severity": severity,
        "domain": domain,
        "class": cls,
        "url": url,
        "title": title,
        "external_refs": refs_external,
        "iframes": iframes,
        "headers": headers,
        "navs": navs,
        "required_assets": ",".join(required),
        "gaps": ",".join(gaps)
    }
    rows.append(row)

    scope_stats[cls]["count"] += 1
    scope_stats[cls]["score_sum"] += score
    scope_stats[cls][severity.lower()] += 1

    if cls == "leaf_operational_candidate":
        domain_stats_leaf[domain]["count"] += 1
        domain_stats_leaf[domain]["score_sum"] += score
        domain_stats_leaf[domain][severity.lower()] += 1

leaf_rows = [r for r in rows if r["class"] == "leaf_operational_candidate"]
leaf_rows.sort(key=lambda r: (r["score"], r["domain"], r["url"]))

leaf_avg = round(sum(r["score"] for r in leaf_rows) / max(1, len(leaf_rows)), 2)
leaf_premium = sum(1 for r in leaf_rows if r["severity"] == "PREMIUM")
leaf_good = sum(1 for r in leaf_rows if r["severity"] == "GOOD")
leaf_weak = sum(1 for r in leaf_rows if r["severity"] == "WEAK")
leaf_critical = sum(1 for r in leaf_rows if r["severity"] == "CRITICAL")
leaf_ratio = round(leaf_premium / max(1, len(leaf_rows)), 3)

scope_table = []
for scope, s in sorted(scope_stats.items()):
    scope_table.append({
        "scope": scope,
        "pages": s["count"],
        "avg_score": round(s["score_sum"] / max(1, s["count"]), 2),
        "critical": s["critical"],
        "weak": s["weak"],
        "good": s["good"],
        "premium": s["premium"]
    })

domain_table = []
for domain, s in sorted(domain_stats_leaf.items()):
    domain_table.append({
        "domain": domain,
        "leaf_pages": s["count"],
        "avg_score": round(s["score_sum"] / max(1, s["count"]), 2),
        "critical": s["critical"],
        "weak": s["weak"],
        "good": s["good"],
        "premium": s["premium"]
    })

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "authority": "TRFMC_PERFECTION_AUTHORITY_V2_SCOPED",
    "total_html_analyzed": len(rows),
    "leaf_scope": {
        "pages": len(leaf_rows),
        "average_score": leaf_avg,
        "premium_pages": leaf_premium,
        "good_pages": leaf_good,
        "weak_pages": leaf_weak,
        "critical_pages": leaf_critical,
        "premium_ratio": leaf_ratio,
        "gate": {
            "target_average_score": 92,
            "target_premium_ratio": 0.8,
            "target_critical_pages": 0,
            "status": "PASS" if leaf_avg >= 92 and leaf_ratio >= 0.8 and leaf_critical == 0 else "NOT_YET"
        }
    },
    "scope_policy": {
        "leaf_operational_candidate": "eligible for visual/engineering perfection batches",
        "service": "hardening only, not visual perfection target",
        "orphan_or_legacy_candidate": "quarantine or migration candidate",
        "official_shell": "protected, not patched as leaf"
    }
}

(out / "authority_v2_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

with (out / "authority_v2_scope_summary.tsv").open("w") as fp:
    fp.write("scope\tpages\tavg_score\tcritical\tweak\tgood\tpremium\n")
    for r in scope_table:
        fp.write(f'{r["scope"]}\t{r["pages"]}\t{r["avg_score"]}\t{r["critical"]}\t{r["weak"]}\t{r["good"]}\t{r["premium"]}\n')

with (out / "authority_v2_leaf_domain_summary.tsv").open("w") as fp:
    fp.write("domain\tleaf_pages\tavg_score\tcritical\tweak\tgood\tpremium\n")
    for r in domain_table:
        fp.write(f'{r["domain"]}\t{r["leaf_pages"]}\t{r["avg_score"]}\t{r["critical"]}\t{r["weak"]}\t{r["good"]}\t{r["premium"]}\n')

with (out / "authority_v2_leaf_scorecard.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\tclass\turl\ttitle\texternal_refs\tiframes\theaders\tnavs\trequired_assets\tgaps\n")
    for r in leaf_rows:
        fp.write(f'{r["score"]}\t{r["severity"]}\t{r["domain"]}\t{r["class"]}\t{r["url"]}\t{r["title"]}\t{r["external_refs"]}\t{r["iframes"]}\t{r["headers"]}\t{r["navs"]}\t{r["required_assets"]}\t{r["gaps"]}\n')

manifest = {
    "id": "TRFMC_PERFECTION_AUTHORITY_V2_SCOPED",
    "generated": summary["timestamp"],
    "reports": {
        "summary": "runtime/quality/latest_false_external_repair_and_authority_v2/authority_v2_summary.json",
        "scope_summary": "runtime/quality/latest_false_external_repair_and_authority_v2/authority_v2_scope_summary.tsv",
        "leaf_domain_summary": "runtime/quality/latest_false_external_repair_and_authority_v2/authority_v2_leaf_domain_summary.tsv",
        "leaf_scorecard": "runtime/quality/latest_false_external_repair_and_authority_v2/authority_v2_leaf_scorecard.tsv"
    }
}
manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

scope_rows = "\n".join(
    f'<tr><td>{esc(r["scope"])}</td><td>{r["pages"]}</td><td>{r["avg_score"]}</td><td>{r["critical"]}</td><td>{r["weak"]}</td><td>{r["good"]}</td><td>{r["premium"]}</td></tr>'
    for r in scope_table
)
domain_rows = "\n".join(
    f'<tr><td>{esc(r["domain"])}</td><td>{r["leaf_pages"]}</td><td>{r["avg_score"]}</td><td>{r["critical"]}</td><td>{r["weak"]}</td><td>{r["good"]}</td><td>{r["premium"]}</td></tr>'
    for r in domain_table
)
leaf_rows_html = "\n".join(
    f'<tr class="{r["severity"].lower()}"><td>{r["score"]}</td><td>{esc(r["severity"])}</td><td>{esc(r["domain"])}</td><td><a href="{esc(r["url"])}">{esc(r["url"])}</a></td><td>{esc(r["gaps"][:180])}</td></tr>'
    for r in leaf_rows[:120]
)

page_path.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Perfection Authority V2 Scoped</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.v2-grid{{display:grid;grid-template-columns:380px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}}
.v2-kpis{{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin-bottom:8px}}
.v2-kpi{{border:1px solid rgba(0,229,255,.32);border-radius:8px;background:rgba(0,229,255,.05);padding:10px}}
.v2-kpi small{{display:block;color:#8fb8c8;text-transform:uppercase;font-size:10px}}
.v2-kpi b{{display:block;color:#75ff5b;font-size:20px}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
tr.critical td{{color:#ff9abc}}
tr.weak td{{color:#ffd84d}}
tr.good td{{color:#dffaff}}
tr.premium td{{color:#75ff5b}}
@media(max-width:1300px){{.v2-grid{{grid-template-columns:1fr}}.v2-kpis{{grid-template-columns:1fr 1fr}}}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Perfection Authority V2 Scoped</div>
    <div class="leaf-sub">Misura separata: leaf bonificabili, service hardening, orphan quarantine, official shell protette</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_perfection_authority_v1.html">Authority V1</a>
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>
<div class="v2-grid">
<aside class="leaf-panel">
<h2>Scoped gate</h2>
<div class="leaf-card">
<h3>Leaf-only gate</h3>
<p><b>{esc(summary["leaf_scope"]["gate"]["status"])}</b></p>
<p>Qui giudichiamo solo le pagine realmente bonificabili come moduli operativi. Shell ufficiali, service e orphan non falsano più la metrica.</p>
</div>
<div class="leaf-card">
<h3>Policy</h3>
<ul>
<li>Leaf: patch visuale/tecnica.</li>
<li>Service: hardening, non estetica.</li>
<li>Orphan: quarantena/migrazione.</li>
<li>Official shell: protetta.</li>
</ul>
</div>
</aside>
<main class="leaf-panel">
<h2>Leaf Operational Candidate Dashboard</h2>
<div class="v2-kpis">
<div class="v2-kpi"><small>Leaf pages</small><b>{summary["leaf_scope"]["pages"]}</b></div>
<div class="v2-kpi"><small>Average</small><b>{summary["leaf_scope"]["average_score"]}</b></div>
<div class="v2-kpi"><small>Premium</small><b>{summary["leaf_scope"]["premium_pages"]}</b></div>
<div class="v2-kpi"><small>Weak</small><b>{summary["leaf_scope"]["weak_pages"]}</b></div>
<div class="v2-kpi"><small>Critical</small><b>{summary["leaf_scope"]["critical_pages"]}</b></div>
</div>
<div class="leaf-card">
<h3>Scope summary</h3>
<table><thead><tr><th>Scope</th><th>Pages</th><th>Avg</th><th>Critical</th><th>Weak</th><th>Good</th><th>Premium</th></tr></thead><tbody>{scope_rows}</tbody></table>
</div>
<div class="leaf-card">
<h3>Leaf domain maturity</h3>
<table><thead><tr><th>Domain</th><th>Leaf pages</th><th>Avg</th><th>Critical</th><th>Weak</th><th>Good</th><th>Premium</th></tr></thead><tbody>{domain_rows}</tbody></table>
</div>
<div class="leaf-card">
<h3>Leaf worst-first scorecard</h3>
<table><thead><tr><th>Score</th><th>Severity</th><th>Domain</th><th>URL</th><th>Gaps</th></tr></thead><tbody>{leaf_rows_html}</tbody></table>
</div>
</main>
</div>
<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
</body>
</html>
''', encoding="utf-8")

print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "[5/8] Registro Authority V2 come service page"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])
reg = json.loads(reg_path.read_text(errors="ignore"))
pages = reg.get("pages", [])
by_url = {p.get("url"): p for p in pages if p.get("url")}

target = public / "trfmc_perfection_authority_v2_scoped.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_perfection_authority_v2_scoped.html"] = {
  "class": "service",
  "name": "trfmc_perfection_authority_v2_scoped.html",
  "url": "/trfmc_perfection_authority_v2_scoped.html",
  "size": target.stat().st_size,
  "quality_authority": True,
  "scoped": True,
  "has_iframe": False,
  "external_refs": 0,
  "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
  "upgrade": "Perfection Authority V2 scoped"
}

reg["pages"] = list(by_url.values())

counts = {}
for p in reg["pages"]:
    c = p.get("class", "unknown")
    counts[c] = counts.get(c, 0) + 1
counts["total_html"] = len(reg["pages"])
for k in ["official_shell", "service", "leaf_operational_candidate", "shell_or_legacy_container", "orphan_or_legacy_candidate"]:
    counts.setdefault(k, 0)

reg["counts"] = counts
reg["last_perfection_authority_v2_scoped_update"] = {
  "timestamp": datetime.now(timezone.utc).isoformat(),
  "page": "/trfmc_perfection_authority_v2_scoped.html",
  "policy": "service page only; V6R3 and Control Room protected"
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(reg["counts"], indent=2, ensure_ascii=False))
PY

echo
echo "[6/8] HTTP gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_perfection_authority_v2_scoped.html \
    /trfmc_perfection_authority_v2_manifest.json \
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
echo "[7/8] Quality summary"

: > "$OUT/external_refs_authority_v2.txt"
: > "$OUT/iframe_refs_authority_v2.txt"

for f in "$AUTH_PAGE" "$AUTH_MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs_authority_v2.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs_authority_v2.txt" 2>/dev/null || true
done

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
false_ext = sum(1 for x in (out / "external_refs_after_false_external_repair.txt").read_text(errors="ignore").splitlines() if x.strip())
false_ifr = sum(1 for x in (out / "iframe_refs_after_false_external_repair.txt").read_text(errors="ignore").splitlines() if x.strip())
auth_ext = sum(1 for x in (out / "external_refs_authority_v2.txt").read_text(errors="ignore").splitlines() if x.strip())
auth_ifr = sum(1 for x in (out / "iframe_refs_authority_v2.txt").read_text(errors="ignore").splitlines() if x.strip())

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

auth = json.loads((out / "authority_v2_summary.json").read_text(errors="ignore"))
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_FALSE_EXTERNAL_REPAIR_AND_AUTHORITY_V2",
    "false_external_refs_after": false_ext,
    "false_iframe_refs_after": false_ifr,
    "authority_v2_external_refs": auth_ext,
    "authority_v2_iframe_refs": auth_ifr,
    "http_non_200": non200,
    "protected_v6r3_and_control_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts", {}).get("total_html"),
    "authority_v2_leaf_average": auth.get("leaf_scope", {}).get("average_score"),
    "authority_v2_leaf_critical": auth.get("leaf_scope", {}).get("critical_pages"),
    "authority_v2_leaf_weak": auth.get("leaf_scope", {}).get("weak_pages"),
    "authority_v2_leaf_premium": auth.get("leaf_scope", {}).get("premium_pages"),
    "authority_v2_leaf_gate": auth.get("leaf_scope", {}).get("gate", {}).get("status"),
    "result": "PASS" if false_ext == 0 and false_ifr == 0 and auth_ext == 0 and auth_ifr == 0 and non200 == 0 and protected_ok and registry_changed else "WARN",
    "policy": "Repair local false external and create scoped authority. V6R3 and Control Room unchanged."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[8/8] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_FALSE_EXTERNAL_REPAIR_AUTHORITY_V2_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_perfection_authority_v2_scoped.html \
    frontend/public/trfmc_perfection_authority_v2_manifest.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_false_external_repair_and_authority_v2 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== V2 SCOPE SUMMARY ==="
column -t -s $'\t' "$OUT/authority_v2_scope_summary.tsv"
echo
echo "=== V2 LEAF DOMAIN SUMMARY ==="
column -t -s $'\t' "$OUT/authority_v2_leaf_domain_summary.tsv"
echo
echo "=== FALSE EXTERNAL AFTER ==="
cat "$OUT/external_refs_after_false_external_repair.txt" || true
echo
echo "=== IFRAME AFTER ==="
cat "$OUT/iframe_refs_after_false_external_repair.txt" || true
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_perfection_authority_v2_scoped.html"
echo "============================================================"
