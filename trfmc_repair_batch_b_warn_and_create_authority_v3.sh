#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_REPAIR_BATCH_B_WARN_AUTHORITY_V3_$TS"
LATEST="$BASE/runtime/quality/latest_repair_batch_b_warn_authority_v3"

BATCH_B="$BASE/runtime/quality/latest_perfection_surgical_batch_b_leaf_only_v1"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

AUTH_PAGE="$PUBLIC/trfmc_perfection_authority_v3_scoped.html"
AUTH_MANIFEST="$PUBLIC/trfmc_perfection_authority_v3_manifest.json"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC REPAIR BATCH B WARN + AUTHORITY V3 SCOPED"
echo "Fix scope pollution · classify protected service pages · domain override"
echo "============================================================"

if [ ! -d "$BATCH_B" ]; then
  echo "ERRORE: manca $BATCH_B"
  exit 1
fi

echo
echo "[1/8] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_REPAIR_BATCH_B_AUTHORITY_V3_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_perfection_surgical_batch_b_leaf_only_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Analizzo il failed_pages di Batch B"

cp "$BATCH_B/summary.json" "$OUT/source_batch_b_summary.json" 2>/dev/null || true
cp "$BATCH_B/failed_pages.tsv" "$OUT/source_failed_pages.tsv" 2>/dev/null || true
cp "$BATCH_B/post_batch_b_leaf_scorecard.tsv" "$OUT/source_post_batch_b_leaf_scorecard.tsv" 2>/dev/null || true

python3 - "$PUBLIC" "$BATCH_B" "$OUT" <<'PY'
import csv, json, sys
from pathlib import Path

public = Path(sys.argv[1])
batch = Path(sys.argv[2])
out = Path(sys.argv[3])

failed_file = batch / "failed_pages.tsv"

protected_terms = [
    "trfmc_integration_control_room",
    "trfmc_official_safe_entrypoint",
    "trfmc_perfection_authority",
    "trfmc_portal_registry",
    "trfmc_gpu_visual_runtime_lab",
    "trfmc_visual_asset_engine_lab",
    "trfmc_soul_runtime_lab"
]

failed = []
ignored = []
unresolved = []

if failed_file.exists():
    with failed_file.open(errors="ignore") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        for r in reader:
            url = (r.get("url") or "").strip()
            reason = (r.get("reason") or "unknown").strip()
            if not url:
                continue
            row = {"url": url, "reason": reason}
            failed.append(row)

            if any(t in url for t in protected_terms):
                row["decision"] = "ignored_protected_or_service"
                ignored.append(row)
            else:
                f = public / url.lstrip("/")
                if f.exists():
                    row["decision"] = "exists_now_no_action"
                    ignored.append(row)
                else:
                    row["decision"] = "unresolved_missing_leaf"
                    unresolved.append(row)

(out / "failed_pages_analysis.json").write_text(json.dumps({
    "failed_count": len(failed),
    "ignored_count": len(ignored),
    "unresolved_count": len(unresolved),
    "failed": failed,
    "ignored": ignored,
    "unresolved": unresolved
}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

(out / "unresolved_failed_pages.tsv").write_text(
    "url\treason\tdecision\n" + "\n".join(f'{x["url"]}\t{x["reason"]}\t{x["decision"]}' for x in unresolved) + "\n",
    encoding="utf-8"
)

print(json.dumps({
    "failed_count": len(failed),
    "ignored_count": len(ignored),
    "unresolved_count": len(unresolved)
}, indent=2))
PY

echo
echo "[3/8] Correggo solo registry/classificazione, non i file protetti"

python3 - "$PUBLIC" "$REG" "$OUT" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])
out = Path(sys.argv[3])

reg = json.loads(reg_path.read_text(errors="ignore"))
pages = reg.get("pages", [])
by_url = {p.get("url"): p for p in pages if p.get("url")}

service_urls = {
    "/trfmc_integration_control_room.html",
    "/trfmc_integration_control_room_v2.html",
    "/trfmc_perfection_authority_v1.html",
    "/trfmc_perfection_authority_v2_scoped.html",
    "/trfmc_gpu_visual_runtime_manifest_v2.json",
    "/trfmc_visual_asset_engine_manifest_v3.json",
    "/trfmc_soul_runtime_manifest_v1.html",
}

official_shell_urls = {
    "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "/trfmc_official_safe_entrypoint_v6.html",
}

changed = []

for url in sorted(service_urls):
    if not url.endswith(".html"):
        continue
    f = public / url.lstrip("/")
    if not f.exists():
        continue
    item = by_url.get(url, {"url": url, "name": f.name})
    old = item.get("class")
    item.update({
        "class": "service",
        "name": f.name,
        "url": url,
        "size": f.stat().st_size,
        "protected_service": True,
        "has_iframe": False,
        "external_refs": 0,
        "quality_scope": "service_hardening_not_leaf_perfection"
    })
    by_url[url] = item
    if old != "service":
        changed.append({"url": url, "from": old, "to": "service"})

for url in sorted(official_shell_urls):
    f = public / url.lstrip("/")
    if not f.exists():
        continue
    item = by_url.get(url, {"url": url, "name": f.name})
    old = item.get("class")
    item.update({
        "class": "official_shell",
        "name": f.name,
        "url": url,
        "size": f.stat().st_size,
        "official_shell": True,
        "protected": True,
        "quality_scope": "official_shell_not_leaf_perfection"
    })
    by_url[url] = item
    if old != "official_shell":
        changed.append({"url": url, "from": old, "to": "official_shell"})

reg["pages"] = list(by_url.values())

counts = {}
for p in reg["pages"]:
    c = p.get("class", "unknown")
    counts[c] = counts.get(c, 0) + 1

counts["total_html"] = len([p for p in reg["pages"] if str(p.get("url","")).endswith(".html")])
for k in ["official_shell", "service", "leaf_operational_candidate", "shell_or_legacy_container", "orphan_or_legacy_candidate"]:
    counts.setdefault(k, 0)

reg["counts"] = counts
reg["last_repair_batch_b_authority_v3_scope_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "policy": "Control Room and official entrypoints are protected scopes, not leaf perfection targets.",
    "changed_classifications": changed
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

(out / "registry_scope_changes.json").write_text(json.dumps({
    "changed": changed,
    "counts": counts
}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

print(json.dumps({
    "changed_classifications": len(changed),
    "counts": counts
}, indent=2, ensure_ascii=False))
PY

echo
echo "[4/8] Creo Authority V3 scoped con dominio deterministico URL/title-first"

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

def title_of(text, fallback):
    m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    if m:
        return html.unescape(re.sub(r"\s+", " ", m.group(1)).strip())
    return fallback

def detect_domain(url, title, text):
    # Deterministic URL/title-first classifier. Body is only a secondary hint,
    # because injected bridge formulas can contaminate older pages.
    primary = (url + " " + title).lower()
    secondary = text[:2200].lower()

    if any(k in primary for k in ["antenna", "rru", "ret", "cpri", "ecpri", "beam", "port_mapping", "port-mapping"]):
        return "antenna"
    if any(k in primary for k in ["microwave", "smith", "backhaul", "link_budget", "link-budget"]):
        return "microwave"
    if any(k in primary for k in ["fiber", "otdr", "fronthaul"]):
        return "fiber"
    if any(k in primary for k in ["cyber", "evidence", "threat", "intelligence", "security"]):
        return "cyber"
    if any(k in primary for k in ["datacenter", "data_center", "data-center", "rack", "pdu", "power", "thermal"]):
        return "datacenter"
    if any(k in primary for k in ["spectrum", "signal", "vsa", "fft", "iq", "dsp", "ofdm", "qam", "wifi", "wi-fi", "rf_", "rf-", "rf ", "sapienza", "physics", "heatmap", "receiver", "pr200", "sdr", "rfpro"]):
        return "rf"
    if any(k in primary for k in ["knowledge", "theory", "academy", "procedure", "handbook", "doctrine"]):
        return "knowledge"
    if any(k in primary for k in ["open5gs", "ueransim", "5g_core", "5g-core", "core_network", "core-network", "aka", "suci", "supi", "ngap", "pfcp", "gtp", "amf", "smf", "upf"]):
        return "core"

    # Secondary body-based detection, used only after URL/title failed.
    if any(k in secondary for k in ["open5gs", "ueransim", "5g-aka", "suci", "supi", "ngap", "pfcp", "gtp-u", "amf", "smf", "upf"]):
        return "core"
    if any(k in secondary for k in ["fourier", "spectrum", "fft", "iq", "ofdm", "qam", "rbw", "evm"]):
        return "rf"

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

leaf_rows = []
all_rows = []
scope_stats = defaultdict(lambda: {"count":0, "score_sum":0, "critical":0, "weak":0, "good":0, "premium":0})
domain_stats = defaultdict(lambda: {"count":0, "score_sum":0, "critical":0, "weak":0, "good":0, "premium":0})

protected_exclusions = {
    "/trfmc_integration_control_room.html",
    "/trfmc_integration_control_room_v2.html",
    "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "/trfmc_official_safe_entrypoint_v6.html",
    "/trfmc_perfection_authority_v1.html",
    "/trfmc_perfection_authority_v2_scoped.html",
    "/trfmc_perfection_authority_v3_scoped.html",
}

for p in pages:
    url = p.get("url", "")
    cls = p.get("class", "unknown")
    if not url.endswith(".html"):
        continue

    f = public / url.lstrip("/")
    exists = f.exists()
    text = f.read_text(errors="ignore") if exists else ""
    title = title_of(text, p.get("name", url))
    domain = detect_domain(url, title, text)
    required = domain_assets.get(domain, [])

    ext = len(external_re.findall(text))
    ifr = len(re.findall(r"<iframe\b", text, re.I))
    headers = len(re.findall(r'class\s*=\s*["\'][^"\']*leaf-top', text, re.I))
    navs = len(re.findall(r"<nav\b", text, re.I))

    checks = {
        "exists": exists,
        "title": bool(title and len(title) > 8),
        "single_header": headers <= 1,
        "no_external": ext == 0,
        "no_iframe": ifr == 0,
        "design_tokens": "trfmc_design_system" in text or "trfmc_leaf_master_v1.css" in text,
        "visual_xp": "trfmc_visual_xp_v1" in text or "trfmc-vxp" in text,
        "gpu_runtime": "trfmc_gpu_visual_runtime_v2" in text or "trfmc-gpu-v2" in text,
        "asset_engine": "trfmc_visual_asset_engine_v3" in text or "trfmc-visual-asset" in text,
        "soul_runtime": "trfmc_soul_runtime_v1" in text or "trfmc-soul-v1" in text,
        "canvas": "<canvas" in text.lower() or "webgl" in text.lower() or "trfmc-visual-asset" in text,
        "kpi": "leaf-kpi" in text or "trfmc-b2-kpi" in text or "trfmc-perfection-kpi" in text or "KPI" in text,
        "formulas": "formulaLive" in text or "FSPL" in text or "VSWR" in text or "EIRP" in text or "Fourier" in text or "formula" in text.lower(),
        "required_assets": all(a in text for a in required) if required else True
    }

    score = min(100, sum(weights[k] for k, v in checks.items() if v))
    gaps = [k for k, v in checks.items() if not v]
    if required and not checks["required_assets"]:
        gaps.append("missing_domain_assets:" + ",".join(a for a in required if a not in text))

    severity = "PREMIUM" if score >= 94 else "GOOD" if score >= 85 else "WEAK" if score >= 70 else "CRITICAL"

    row = {
        "score": score,
        "severity": severity,
        "domain": domain,
        "class": cls,
        "url": url,
        "title": title,
        "external_refs": ext,
        "iframes": ifr,
        "headers": headers,
        "navs": navs,
        "required_assets": ",".join(required),
        "gaps": ",".join(gaps),
        "excluded_from_leaf_gate": url in protected_exclusions or cls in ("service", "official_shell", "orphan_or_legacy_candidate")
    }

    all_rows.append(row)

    scope_stats[cls]["count"] += 1
    scope_stats[cls]["score_sum"] += score
    scope_stats[cls][severity.lower()] += 1

    if cls == "leaf_operational_candidate" and not row["excluded_from_leaf_gate"]:
        leaf_rows.append(row)
        domain_stats[domain]["count"] += 1
        domain_stats[domain]["score_sum"] += score
        domain_stats[domain][severity.lower()] += 1

leaf_rows.sort(key=lambda r: (r["score"], r["domain"], r["url"]))

avg = round(sum(r["score"] for r in leaf_rows) / max(1, len(leaf_rows)), 2)
critical = sum(1 for r in leaf_rows if r["severity"] == "CRITICAL")
weak = sum(1 for r in leaf_rows if r["severity"] == "WEAK")
good = sum(1 for r in leaf_rows if r["severity"] == "GOOD")
premium = sum(1 for r in leaf_rows if r["severity"] == "PREMIUM")
ratio = round(premium / max(1, len(leaf_rows)), 3)

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "authority": "TRFMC_PERFECTION_AUTHORITY_V3_SCOPED",
    "total_html_seen": len(all_rows),
    "leaf_gate_scope": {
        "pages": len(leaf_rows),
        "average_score": avg,
        "critical_pages": critical,
        "weak_pages": weak,
        "good_pages": good,
        "premium_pages": premium,
        "premium_ratio": ratio,
        "gate": "PASS" if avg >= 92 and critical == 0 and ratio >= 0.8 else "NOT_YET"
    },
    "rules": {
        "domain_classifier": "URL/title first; injected bridge body only secondary",
        "protected_exclusions": sorted(protected_exclusions),
        "leaf_target_only": True
    }
}

(out / "authority_v3_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

with (out / "authority_v3_leaf_scorecard.tsv").open("w") as fp:
    fp.write("score\tseverity\tdomain\tclass\turl\ttitle\texternal_refs\tiframes\theaders\tnavs\trequired_assets\tgaps\n")
    for r in leaf_rows:
        fp.write(f'{r["score"]}\t{r["severity"]}\t{r["domain"]}\t{r["class"]}\t{r["url"]}\t{r["title"]}\t{r["external_refs"]}\t{r["iframes"]}\t{r["headers"]}\t{r["navs"]}\t{r["required_assets"]}\t{r["gaps"]}\n')

with (out / "authority_v3_leaf_domain_summary.tsv").open("w") as fp:
    fp.write("domain\tleaf_pages\tavg_score\tcritical\tweak\tgood\tpremium\n")
    for d, s in sorted(domain_stats.items()):
        fp.write(f'{d}\t{s["count"]}\t{round(s["score_sum"]/max(1,s["count"]),2)}\t{s["critical"]}\t{s["weak"]}\t{s["good"]}\t{s["premium"]}\n')

with (out / "authority_v3_scope_summary.tsv").open("w") as fp:
    fp.write("scope\tpages\tavg_score\tcritical\tweak\tgood\tpremium\n")
    for sname, s in sorted(scope_stats.items()):
        fp.write(f'{sname}\t{s["count"]}\t{round(s["score_sum"]/max(1,s["count"]),2)}\t{s["critical"]}\t{s["weak"]}\t{s["good"]}\t{s["premium"]}\n')

manifest = {
    "id": "TRFMC_PERFECTION_AUTHORITY_V3_SCOPED",
    "generated": summary["timestamp"],
    "purpose": "Clean leaf-only score after Batch B; protected pages excluded; URL/title-first domain classification.",
    "reports": {
        "summary": "runtime/quality/latest_repair_batch_b_warn_authority_v3/authority_v3_summary.json",
        "leaf_scorecard": "runtime/quality/latest_repair_batch_b_warn_authority_v3/authority_v3_leaf_scorecard.tsv",
        "leaf_domain_summary": "runtime/quality/latest_repair_batch_b_warn_authority_v3/authority_v3_leaf_domain_summary.tsv",
        "scope_summary": "runtime/quality/latest_repair_batch_b_warn_authority_v3/authority_v3_scope_summary.tsv"
    }
}
manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

def esc(x):
    return html.escape(str(x))

scope_rows = []
for line in (out / "authority_v3_scope_summary.tsv").read_text().splitlines()[1:]:
    p = line.split("\t")
    scope_rows.append(f"<tr><td>{esc(p[0])}</td><td>{p[1]}</td><td>{p[2]}</td><td>{p[3]}</td><td>{p[4]}</td><td>{p[5]}</td><td>{p[6]}</td></tr>")

domain_rows = []
for line in (out / "authority_v3_leaf_domain_summary.tsv").read_text().splitlines()[1:]:
    p = line.split("\t")
    domain_rows.append(f"<tr><td>{esc(p[0])}</td><td>{p[1]}</td><td>{p[2]}</td><td>{p[3]}</td><td>{p[4]}</td><td>{p[5]}</td><td>{p[6]}</td></tr>")

score_rows = []
for r in leaf_rows[:120]:
    score_rows.append(
        f'<tr class="{r["severity"].lower()}"><td>{r["score"]}</td><td>{esc(r["severity"])}</td><td>{esc(r["domain"])}</td><td><a href="{esc(r["url"])}">{esc(r["url"])}</a></td><td>{esc(r["gaps"][:180])}</td></tr>'
    )

page_path.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Perfection Authority V3 Scoped</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.v3-grid{{display:grid;grid-template-columns:380px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}}
.v3-kpis{{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin-bottom:8px}}
.v3-kpi{{border:1px solid rgba(0,229,255,.32);border-radius:8px;background:rgba(0,229,255,.05);padding:10px}}
.v3-kpi small{{display:block;color:#8fb8c8;text-transform:uppercase;font-size:10px}}
.v3-kpi b{{display:block;color:#75ff5b;font-size:20px}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
tr.critical td{{color:#ff9abc}}
tr.weak td{{color:#ffd84d}}
tr.good td{{color:#dffaff}}
tr.premium td{{color:#75ff5b}}
@media(max-width:1300px){{.v3-grid{{grid-template-columns:1fr}}.v3-kpis{{grid-template-columns:1fr 1fr}}}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Perfection Authority V3 Scoped</div>
    <div class="leaf-sub">Leaf-only score pulito: protected/service/orphan esclusi; domini determinati da URL/title</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_perfection_authority_v2_scoped.html">Authority V2</a>
    <a class="leaf-btn" href="/trfmc_official_safe_entrypoint_v6r3_command_center.html">V6R3</a>
    <a class="leaf-btn" href="/trfmc_integration_control_room.html">Control Room</a>
    <a class="leaf-btn" href="/trfmc_portal_registry_unified.json">Registry</a>
  </div>
</header>
<div class="v3-grid">
<aside class="leaf-panel">
<h2>Gate V3</h2>
<div class="leaf-card">
<h3>Leaf-only gate</h3>
<p><b>{esc(summary["leaf_gate_scope"]["gate"])}</b></p>
<p>Control Room, V6R3, Authority, service e orphan sono fuori dalla metrica leaf.</p>
</div>
<div class="leaf-card">
<h3>Metodo</h3>
<p>Dominio da URL/title. Il body viene usato solo come hint secondario per evitare contaminazioni da bridge già iniettati.</p>
</div>
</aside>
<main class="leaf-panel">
<h2>Authority V3 Dashboard</h2>
<div class="v3-kpis">
<div class="v3-kpi"><small>Leaf pages</small><b>{summary["leaf_gate_scope"]["pages"]}</b></div>
<div class="v3-kpi"><small>Average</small><b>{summary["leaf_gate_scope"]["average_score"]}</b></div>
<div class="v3-kpi"><small>Critical</small><b>{summary["leaf_gate_scope"]["critical_pages"]}</b></div>
<div class="v3-kpi"><small>Weak</small><b>{summary["leaf_gate_scope"]["weak_pages"]}</b></div>
<div class="v3-kpi"><small>Premium</small><b>{summary["leaf_gate_scope"]["premium_pages"]}</b></div>
</div>
<div class="leaf-card">
<h3>Scope summary</h3>
<table><thead><tr><th>Scope</th><th>Pages</th><th>Avg</th><th>Critical</th><th>Weak</th><th>Good</th><th>Premium</th></tr></thead><tbody>{''.join(scope_rows)}</tbody></table>
</div>
<div class="leaf-card">
<h3>Leaf domain summary</h3>
<table><thead><tr><th>Domain</th><th>Leaf pages</th><th>Avg</th><th>Critical</th><th>Weak</th><th>Good</th><th>Premium</th></tr></thead><tbody>{''.join(domain_rows)}</tbody></table>
</div>
<div class="leaf-card">
<h3>Worst-first leaf scorecard</h3>
<table><thead><tr><th>Score</th><th>Severity</th><th>Domain</th><th>URL</th><th>Gaps</th></tr></thead><tbody>{''.join(score_rows)}</tbody></table>
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
echo "[5/8] Registro Authority V3 come service"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
pages = reg.get("pages", [])
by_url = {p.get("url"): p for p in pages if p.get("url")}

target = public / "trfmc_perfection_authority_v3_scoped.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_perfection_authority_v3_scoped.html"] = {
    "class": "service",
    "name": "trfmc_perfection_authority_v3_scoped.html",
    "url": "/trfmc_perfection_authority_v3_scoped.html",
    "size": target.stat().st_size,
    "quality_authority": True,
    "scoped": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "Perfection Authority V3 scoped"
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
reg["last_perfection_authority_v3_scoped_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_perfection_authority_v3_scoped.html",
    "policy": "Authority V3 service page only; V6R3 and Control Room files unchanged."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[6/8] HTTP + contenuto gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_perfection_authority_v3_scoped.html \
    /trfmc_perfection_authority_v3_manifest.json \
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

: > "$OUT/external_refs_authority_v3.txt"
: > "$OUT/iframe_refs_authority_v3.txt"

for f in "$AUTH_PAGE" "$AUTH_MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs_authority_v3.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs_authority_v3.txt" 2>/dev/null || true
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
ext = sum(1 for x in (out / "external_refs_authority_v3.txt").read_text(errors="ignore").splitlines() if x.strip())
ifr = sum(1 for x in (out / "iframe_refs_authority_v3.txt").read_text(errors="ignore").splitlines() if x.strip())

failed_analysis = json.loads((out / "failed_pages_analysis.json").read_text(errors="ignore"))
auth = json.loads((out / "authority_v3_summary.json").read_text(errors="ignore"))

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
    "operation": "TRFMC_REPAIR_BATCH_B_WARN_AUTHORITY_V3",
    "source_batch_b_failed_count": failed_analysis.get("failed_count"),
    "source_batch_b_ignored_failed_count": failed_analysis.get("ignored_count"),
    "source_batch_b_unresolved_failed_count": failed_analysis.get("unresolved_count"),
    "http_non_200": non200,
    "authority_v3_external_refs": ext,
    "authority_v3_iframe_refs": ifr,
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts", {}).get("total_html"),
    "registry_counts": reg.get("counts", {}),
    "authority_v3_leaf_average": auth.get("leaf_gate_scope", {}).get("average_score"),
    "authority_v3_leaf_critical": auth.get("leaf_gate_scope", {}).get("critical_pages"),
    "authority_v3_leaf_weak": auth.get("leaf_gate_scope", {}).get("weak_pages"),
    "authority_v3_leaf_premium": auth.get("leaf_gate_scope", {}).get("premium_pages"),
    "authority_v3_leaf_gate": auth.get("leaf_gate_scope", {}).get("gate"),
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and protected_ok and registry_changed and failed_analysis.get("unresolved_count") == 0 else "WARN",
    "policy": "Batch B WARN repaired by scope correction. Control Room and V6R3 files unchanged."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_REPAIR_BATCH_B_WARN_AUTHORITY_V3_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_perfection_authority_v3_scoped.html \
    frontend/public/trfmc_perfection_authority_v3_manifest.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_repair_batch_b_warn_authority_v3 \
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
echo "=== AUTHORITY V3 DOMAIN SUMMARY ==="
column -t -s $'\t' "$OUT/authority_v3_leaf_domain_summary.tsv"
echo
echo "=== AUTHORITY V3 WORST FIRST ==="
column -t -s $'\t' "$OUT/authority_v3_leaf_scorecard.tsv" | sed -n '1,90p'
echo
echo "=== FAILED ANALYSIS ==="
cat "$OUT/failed_pages_analysis.json" | python3 -m json.tool
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_perfection_authority_v3_scoped.html"
echo "============================================================"
