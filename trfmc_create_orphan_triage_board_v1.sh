#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ORPHAN_TRIAGE_BOARD_V1_$TS"
LATEST="$BASE/runtime/quality/latest_orphan_triage_board_v1"

GOV="$BASE/runtime/quality/latest_post_promotion_governance_v1"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

BOARD="$PUBLIC/trfmc_orphan_triage_board_v1.html"
MANIFEST="$PUBLIC/trfmc_orphan_triage_manifest_v1.json"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC ORPHAN TRIAGE BOARD V1"
echo "Read-only triage · no orphan patch · no mass promotion"
echo "============================================================"

if [ ! -f "$GOV/summary.json" ]; then
  echo "ERRORE: manca governance PASS: $GOV/summary.json"
  exit 10
fi

GOV_RESULT="$(python3 - <<PY
import json
from pathlib import Path
print(json.loads(Path("$GOV/summary.json").read_text()).get("result",""))
PY
)"

if [ "$GOV_RESULT" != "PASS" ]; then
  echo "ERRORE: governance non PASS: $GOV_RESULT"
  exit 11
fi

echo
echo "[1/7] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_ORPHAN_TRIAGE_BOARD_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_post_promotion_governance_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/7] Creo piano triage orphan"

python3 - "$PUBLIC" "$GOV" "$OUT" <<'PY'
import csv, json, re, html, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
gov = Path(sys.argv[2])
out = Path(sys.argv[3])

orphans_tsv = gov / "orphan_quarantine_pages.tsv"
canonical_tsv = gov / "canonical_leaf_pages.tsv"

def read_tsv(path):
    if not path.exists():
        return []
    with path.open(errors="ignore") as fp:
        return list(csv.DictReader(fp, delimiter="\t"))

orphans = read_tsv(orphans_tsv)
canonical = read_tsv(canonical_tsv)

canonical_by_url = {r["url"]: r for r in canonical if r.get("url")}

def pick_target(url, title):
    s = (url + " " + title).lower()

    if any(k in s for k in ["evidence", "timeline", "scenario_report", "observability", "security"]):
        return "MERGE", "/trfmc_unified_evidence_supervisor_v4.html", "Convergere nel dominio Cyber Evidence / timeline / reportistica."
    if any(k in s for k in ["signal_workbench", "signal_demod", "uav_fhss", "iq", "demod", "fhss", "burst"]):
        return "REBUILD_AS_LEAF", "/trfmc_rf_spectrum_lab_v1.html", "Recuperare contenuto RF PRO utile dentro RF Spectrum / FFT / IQ pipeline."
    if any(k in s for k in ["executive", "mission_dashboard", "global_mission", "mission_graph", "network_journey"]):
        return "MERGE", "/trfmc_master_digital_twin_console_v1.html", "Integrare come scenario/mission layer nel Digital Twin principale."
    if any(k in s for k in ["backup", "restore", "runtime_golden", "operator_handbook", "portal_index"]):
        return "MERGE", "/trfmc_change_control_policy_v1.html", "Portare procedure operative dentro Change Control / governance."
    if any(k in s for k in ["infrastructure", "digital_twin"]):
        return "MERGE", "/trfmc_datacenter_power_pdu_infrastructure_v1.html", "Valutare fusione con Data Center / infrastruttura."
    if any(k in s for k in ["sapienza", "doctrine"]):
        return "MERGE", "/trfmc_theory_spine_v86e.html", "Consolidare come knowledge/theory doctrine."
    return "KEEP_QUARANTINED", "", "Tenere congelata fino ad analisi contenuto manuale."

rows = []
for r in orphans:
    url = r.get("url","")
    title = r.get("title","")
    domain = r.get("domain","generic")
    size = int(r.get("size") or 0)
    f = public / url.lstrip("/")
    sha = ""
    if f.exists():
        import hashlib
        sha = hashlib.sha256(f.read_bytes()).hexdigest()
    action, target, reason = pick_target(url, title)
    rows.append({
        "class": r.get("class","orphan_or_legacy_candidate"),
        "domain": domain,
        "exists": r.get("exists",""),
        "size": size,
        "url": url,
        "title": title,
        "action": action,
        "target": target,
        "reason": reason,
        "sha256": sha
    })

with (out / "orphan_triage_plan.tsv").open("w", encoding="utf-8") as fp:
    fp.write("class\tdomain\texists\tsize\taction\ttarget\turl\ttitle\treason\tsha256\n")
    for r in rows:
        fp.write(f'{r["class"]}\t{r["domain"]}\t{r["exists"]}\t{r["size"]}\t{r["action"]}\t{r["target"]}\t{r["url"]}\t{r["title"]}\t{r["reason"]}\t{r["sha256"]}\n')

counts = {}
for r in rows:
    counts[r["action"]] = counts.get(r["action"], 0) + 1

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_ORPHAN_TRIAGE_BOARD_V1",
    "orphan_pages": len(rows),
    "actions": counts,
    "policy": "Read-only triage. No orphan file changed. No orphan promoted."
}

(out / "orphan_triage_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "[3/7] Creo HTML Orphan Triage Board"

python3 - "$OUT" "$BOARD" "$MANIFEST" <<'PY'
import csv, json, html, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
board = Path(sys.argv[2])
manifest = Path(sys.argv[3])

summary = json.loads((out / "orphan_triage_summary.json").read_text(errors="ignore"))

rows = []
with (out / "orphan_triage_plan.tsv").open(errors="ignore") as fp:
    reader = csv.DictReader(fp, delimiter="\t")
    for r in reader:
        rows.append(r)

def esc(x): return html.escape(str(x or ""))

table = ""
for r in rows:
    action = r.get("action","")
    cls = "danger" if action == "REBUILD_AS_LEAF" else "warn" if action == "KEEP_QUARANTINED" else "ok"
    target = r.get("target","")
    target_html = f'<a href="{esc(target)}">{esc(target)}</a>' if target else "—"
    table += f'''
<tr>
<td>{esc(r.get("domain"))}</td>
<td><span class="{cls}">{esc(action)}</span></td>
<td>{target_html}</td>
<td><a href="{esc(r.get("url"))}">{esc(r.get("url"))}</a></td>
<td>{esc(r.get("title"))}</td>
<td>{esc(r.get("reason"))}</td>
</tr>
'''

manifest_data = {
    "id": "TRFMC_ORPHAN_TRIAGE_BOARD_V1",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "board": "/trfmc_orphan_triage_board_v1.html",
    "policy": "Read-only orphan triage. No orphan file changed."
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

board.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Orphan Triage Board V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.triage-grid{{display:grid;grid-template-columns:390px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}}
.triage-kpis{{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:8px}}
.triage-kpi{{border:1px solid rgba(0,229,255,.32);border-radius:9px;background:rgba(0,229,255,.05);padding:10px}}
.triage-kpi small{{display:block;color:#8fb8c8;text-transform:uppercase;font-size:10px}}
.triage-kpi b{{display:block;color:#75ff5b;font-size:20px}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
.ok{{color:#75ff5b}} .warn{{color:#ffd84d}} .danger{{color:#ff3d7f}}
@media(max-width:1300px){{.triage-grid{{grid-template-columns:1fr}}.triage-kpis{{grid-template-columns:1fr 1fr}}}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Orphan Triage Board V1</div>
    <div class="leaf-sub">Piano di triage read-only: nessun orphan modificato, nessuna promozione diretta</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_post_promotion_control_center_v1.html">Governance</a>
    <a class="leaf-btn" href="/trfmc_orphan_quarantine_room_v1.html">Quarantine</a>
    <a class="leaf-btn" href="/trfmc_canonical_navigation_map_v1.html">Canonical Map</a>
    <a class="leaf-btn" href="/trfmc_change_control_policy_v1.html">Change Policy</a>
  </div>
</header>

<div class="triage-grid">
<aside class="leaf-panel">
<h2>Triage policy</h2>
<div class="leaf-card">
<h3>Decisione</h3>
<p><b>READ-ONLY</b></p>
<p>Questa board decide il destino delle 23 pagine orphan senza modificarle.</p>
</div>
<div class="leaf-card">
<h3>Action counts</h3>
<pre>{esc(json.dumps(summary.get("actions",{}), indent=2, ensure_ascii=False))}</pre>
</div>
</aside>

<main class="leaf-panel">
<h2>Orphan triage plan</h2>
<div class="triage-kpis">
<div class="triage-kpi"><small>Orphan</small><b>{summary.get("orphan_pages")}</b></div>
<div class="triage-kpi"><small>Merge</small><b>{summary.get("actions",{}).get("MERGE",0)}</b></div>
<div class="triage-kpi"><small>Rebuild</small><b>{summary.get("actions",{}).get("REBUILD_AS_LEAF",0)}</b></div>
<div class="triage-kpi"><small>Keep</small><b>{summary.get("actions",{}).get("KEEP_QUARANTINED",0)}</b></div>
</div>
<table>
<thead><tr><th>Domain</th><th>Action</th><th>Target</th><th>URL</th><th>Title</th><th>Reason</th></tr></thead>
<tbody>{table}</tbody>
</table>
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
echo "[4/7] Registro Orphan Triage Board come service"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

target = public / "trfmc_orphan_triage_board_v1.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_orphan_triage_board_v1.html"] = {
    "class": "service",
    "name": "trfmc_orphan_triage_board_v1.html",
    "url": "/trfmc_orphan_triage_board_v1.html",
    "size": target.stat().st_size,
    "orphan_triage": True,
    "post_promotion_governance": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "Orphan Triage Board V1"
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
reg["last_orphan_triage_board_v1_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_orphan_triage_board_v1.html",
    "policy": "Service page only. Orphan files unchanged."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[5/7] HTTP + external/iframe gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_orphan_triage_board_v1.html \
    /trfmc_orphan_triage_manifest_v1.json \
    /trfmc_orphan_quarantine_room_v1.html \
    /trfmc_post_promotion_control_center_v1.html \
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

for f in "$BOARD" "$MANIFEST"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

echo
echo "[6/7] Summary"

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

triage = json.loads((out / "orphan_triage_summary.json").read_text(errors="ignore"))
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_ORPHAN_TRIAGE_BOARD_V1",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "orphan_pages": triage.get("orphan_pages"),
    "actions": triage.get("actions"),
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and protected_ok and registry_changed else "WARN",
    "policy": "Read-only orphan triage service page. No orphan file changed."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
(out / "result.flag").write_text(summary["result"] + "\n")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[7/7] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_ORPHAN_TRIAGE_BOARD_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_orphan_triage_board_v1.html \
    frontend/public/trfmc_orphan_triage_manifest_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_orphan_triage_board_v1 \
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
echo "=== TRIAGE PLAN ==="
column -t -s $'\t' "$OUT/orphan_triage_plan.tsv"
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_orphan_triage_board_v1.html"
echo "============================================================"
