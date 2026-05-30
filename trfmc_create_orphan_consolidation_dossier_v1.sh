#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_ORPHAN_CONSOLIDATION_DOSSIER_V1_$TS"
LATEST="$BASE/runtime/quality/latest_orphan_consolidation_dossier_v1"

TRIAGE="$BASE/runtime/quality/latest_orphan_triage_board_v1"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

PAGE="$PUBLIC/trfmc_orphan_consolidation_dossier_v1.html"
MANIFEST="$PUBLIC/trfmc_orphan_consolidation_manifest_v1.json"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC ORPHAN CONSOLIDATION DOSSIER V1"
echo "Read-only consolidation dossiers · no orphan patch · no target patch"
echo "============================================================"

if [ ! -f "$TRIAGE/summary.json" ]; then
  echo "ERRORE: manca triage board summary: $TRIAGE/summary.json"
  exit 10
fi

TRIAGE_RESULT="$(python3 - <<PY
import json
from pathlib import Path
print(json.loads(Path("$TRIAGE/summary.json").read_text()).get("result",""))
PY
)"

if [ "$TRIAGE_RESULT" != "PASS" ]; then
  echo "ERRORE: triage non PASS: $TRIAGE_RESULT"
  exit 11
fi

echo
echo "[1/7] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_ORPHAN_CONSOLIDATION_DOSSIER_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_orphan_triage_board_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/7] Creo dossier per target"

python3 - "$PUBLIC" "$TRIAGE" "$OUT" <<'PY'
import csv, json, re, html, hashlib, sys
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone

public = Path(sys.argv[1])
triage = Path(sys.argv[2])
out = Path(sys.argv[3])

plan = triage / "orphan_triage_plan.tsv"
rows = []

with plan.open(errors="ignore") as fp:
    reader = csv.DictReader(fp, delimiter="\t")
    for r in reader:
        rows.append(r)

def extract_hints(path):
    if not path.exists():
        return {"title": "", "h1": [], "h2": [], "words": 0}
    txt = path.read_text(errors="ignore")
    title = ""
    m = re.search(r"<title[^>]*>(.*?)</title>", txt, re.I | re.S)
    if m:
        title = html.unescape(re.sub(r"\s+", " ", m.group(1)).strip())
    h1 = [html.unescape(re.sub(r"<[^>]+>", "", x)).strip() for x in re.findall(r"<h1[^>]*>(.*?)</h1>", txt, re.I | re.S)]
    h2 = [html.unescape(re.sub(r"<[^>]+>", "", x)).strip() for x in re.findall(r"<h2[^>]*>(.*?)</h2>", txt, re.I | re.S)]
    words = len(re.findall(r"\w+", re.sub(r"<[^>]+>", " ", txt)))
    return {"title": title, "h1": h1[:8], "h2": h2[:12], "words": words}

groups = defaultdict(list)
for r in rows:
    key = r.get("target") or "__KEEP_QUARANTINED__"
    groups[key].append(r)

dossiers = []
for target, items in sorted(groups.items()):
    action_counts = defaultdict(int)
    total_size = 0
    total_words = 0
    entries = []

    target_path = public / target.lstrip("/") if target != "__KEEP_QUARANTINED__" else None
    target_hints = extract_hints(target_path) if target_path else {}

    for r in items:
        url = r["url"]
        f = public / url.lstrip("/")
        hints = extract_hints(f)
        action_counts[r["action"]] += 1
        total_size += int(r.get("size") or 0)
        total_words += hints["words"]
        entries.append({
            "url": url,
            "title": r.get("title",""),
            "domain": r.get("domain",""),
            "action": r.get("action",""),
            "reason": r.get("reason",""),
            "size": int(r.get("size") or 0),
            "sha256": r.get("sha256",""),
            "h1": hints["h1"],
            "h2": hints["h2"],
            "word_estimate": hints["words"]
        })

    dossiers.append({
        "target": target,
        "target_exists": bool(target_path and target_path.exists()),
        "target_title": target_hints.get("title","") if target_hints else "",
        "orphan_count": len(items),
        "total_size": total_size,
        "word_estimate": total_words,
        "actions": dict(action_counts),
        "entries": entries,
        "recommendation": (
            "Manual merge dossier: review sections, extract unique operational/theory material, then apply change-control."
            if target != "__KEEP_QUARANTINED__"
            else "Keep quarantined until manual content inspection."
        )
    })

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_ORPHAN_CONSOLIDATION_DOSSIER_V1",
    "target_groups": len(dossiers),
    "orphan_pages": len(rows),
    "read_only": True,
    "policy": "Dossier only. No orphan file changed. No target file changed."
}

(out / "orphan_consolidation_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
(out / "orphan_consolidation_dossiers.json").write_text(json.dumps(dossiers, indent=2, ensure_ascii=False) + "\n")

with (out / "orphan_consolidation_matrix.tsv").open("w", encoding="utf-8") as fp:
    fp.write("target\ttarget_exists\torphan_count\ttotal_size\tword_estimate\tactions\trecommendation\n")
    for d in dossiers:
        fp.write(f'{d["target"]}\t{d["target_exists"]}\t{d["orphan_count"]}\t{d["total_size"]}\t{d["word_estimate"]}\t{json.dumps(d["actions"], ensure_ascii=False)}\t{d["recommendation"]}\n')

print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "[3/7] Creo dashboard HTML dossier"

python3 - "$OUT" "$PAGE" "$MANIFEST" <<'PY'
import json, html, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
page = Path(sys.argv[2])
manifest = Path(sys.argv[3])

summary = json.loads((out / "orphan_consolidation_summary.json").read_text(errors="ignore"))
dossiers = json.loads((out / "orphan_consolidation_dossiers.json").read_text(errors="ignore"))

def esc(x): return html.escape(str(x or ""))

cards = ""
for d in dossiers:
    target = d["target"]
    target_html = "KEEP QUARANTINED" if target == "__KEEP_QUARANTINED__" else f'<a href="{esc(target)}">{esc(target)}</a>'
    entries = ""
    for e in d["entries"]:
        entries += f'''
<tr>
<td>{esc(e["action"])}</td>
<td><a href="{esc(e["url"])}">{esc(e["url"])}</a></td>
<td>{esc(e["title"])}</td>
<td>{esc(e["word_estimate"])}</td>
<td>{esc(e["reason"])}</td>
</tr>
'''
    cards += f'''
<div class="leaf-card">
<h3>{target_html}</h3>
<p>Orphan: <b>{d["orphan_count"]}</b> · Size: <b>{d["total_size"]}</b> · Words estimate: <b>{d["word_estimate"]}</b> · Target exists: <b>{d["target_exists"]}</b></p>
<p>{esc(d["recommendation"])}</p>
<table>
<thead><tr><th>Action</th><th>Orphan URL</th><th>Title</th><th>Words</th><th>Reason</th></tr></thead>
<tbody>{entries}</tbody>
</table>
</div>
'''

manifest_data = {
    "id": "TRFMC_ORPHAN_CONSOLIDATION_DOSSIER_V1",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_orphan_consolidation_dossier_v1.html",
    "summary": summary,
    "policy": "Read-only dossier. No orphan and no target mutation."
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

page.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Orphan Consolidation Dossier V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<style>
.dossier-grid{{display:grid;grid-template-columns:390px 1fr;gap:8px;min-height:calc(100vh - 78px);padding:8px;position:relative;z-index:1}}
.dossier-kpis{{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:8px}}
.dossier-kpi{{border:1px solid rgba(0,229,255,.32);border-radius:9px;background:rgba(0,229,255,.05);padding:10px}}
.dossier-kpi small{{display:block;color:#8fb8c8;text-transform:uppercase;font-size:10px}}
.dossier-kpi b{{display:block;color:#75ff5b;font-size:20px}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
@media(max-width:1300px){{.dossier-grid{{grid-template-columns:1fr}}.dossier-kpis{{grid-template-columns:1fr}}}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC Orphan Consolidation Dossier V1</div>
    <div class="leaf-sub">Dossier read-only per fusione controllata del debito storico</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_orphan_triage_board_v1.html">Triage Board</a>
    <a class="leaf-btn" href="/trfmc_orphan_quarantine_room_v1.html">Quarantine</a>
    <a class="leaf-btn" href="/trfmc_change_control_policy_v1.html">Change Policy</a>
    <a class="leaf-btn" href="/trfmc_post_promotion_control_center_v1.html">Governance</a>
  </div>
</header>

<div class="dossier-grid">
<aside class="leaf-panel">
<h2>Consolidation</h2>
<div class="leaf-card">
<h3>Decisione</h3>
<p><b>READ-ONLY DOSSIER</b></p>
<p>Non modifica gli orphan e non modifica i target. Prepara solo il lavoro di fusione manuale.</p>
</div>
<div class="dossier-kpis">
<div class="dossier-kpi"><small>Groups</small><b>{summary["target_groups"]}</b></div>
<div class="dossier-kpi"><small>Orphan</small><b>{summary["orphan_pages"]}</b></div>
<div class="dossier-kpi"><small>Mode</small><b>RO</b></div>
</div>
</aside>

<main class="leaf-panel">
<h2>Target dossiers</h2>
{cards}
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
echo "[4/7] Registro dossier come service"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

target = public / "trfmc_orphan_consolidation_dossier_v1.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_orphan_consolidation_dossier_v1.html"] = {
    "class": "service",
    "name": "trfmc_orphan_consolidation_dossier_v1.html",
    "url": "/trfmc_orphan_consolidation_dossier_v1.html",
    "size": target.stat().st_size,
    "orphan_consolidation": True,
    "post_promotion_governance": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "Orphan Consolidation Dossier V1"
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
reg["last_orphan_consolidation_dossier_v1_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_orphan_consolidation_dossier_v1.html",
    "policy": "Service page only. No orphan or target file changed."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[5/7] HTTP + external/iframe gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_orphan_consolidation_dossier_v1.html \
    /trfmc_orphan_consolidation_manifest_v1.json \
    /trfmc_orphan_triage_board_v1.html \
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

for f in "$PAGE" "$MANIFEST"; do
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

dossier = json.loads((out / "orphan_consolidation_summary.json").read_text(errors="ignore"))
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_ORPHAN_CONSOLIDATION_DOSSIER_V1",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "target_groups": dossier.get("target_groups"),
    "orphan_pages": dossier.get("orphan_pages"),
    "read_only": dossier.get("read_only"),
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and protected_ok and registry_changed and dossier.get("read_only") is True else "WARN",
    "policy": "Read-only orphan consolidation dossier. No orphan or target file changed."
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
  FREEZE="$BASE/runtime/freezes/TRFMC_ORPHAN_CONSOLIDATION_DOSSIER_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_orphan_consolidation_dossier_v1.html \
    frontend/public/trfmc_orphan_consolidation_manifest_v1.json \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_orphan_consolidation_dossier_v1 \
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
echo "=== CONSOLIDATION MATRIX ==="
column -t -s $'\t' "$OUT/orphan_consolidation_matrix.tsv"
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_orphan_consolidation_dossier_v1.html"
echo "============================================================"
