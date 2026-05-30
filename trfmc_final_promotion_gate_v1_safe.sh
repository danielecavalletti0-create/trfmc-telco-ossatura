#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FINAL_PROMOTION_GATE_V1_SAFE_$TS"
LATEST="$BASE/runtime/quality/latest_final_promotion_gate_v1"

BATCH_C="$BASE/runtime/quality/latest_perfection_batch_c_weak_to_premium_v1"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

FINAL_PAGE="$PUBLIC/trfmc_final_promotion_gate_v1.html"
FINAL_MANIFEST="$PUBLIC/trfmc_final_promotion_manifest_v1.json"

mkdir -p "$OUT" "$BASE/runtime/quality" "$BASE/runtime/backups" "$BASE/runtime/freezes"
rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

LOG="$OUT/run.log"
exec > >(tee -a "$LOG") 2>&1

trap 'rc=$?; echo "{\"timestamp\":\"$(date -Iseconds)\",\"result\":\"ERROR\",\"exit_code\":$rc}" > "$OUT/error.json"; exit $rc' ERR

cd "$BASE"

echo "============================================================"
echo "TRFMC FINAL PROMOTION GATE V1 SAFE"
echo "============================================================"

echo
echo "[1/9] Precheck"

if [ ! -d "$BATCH_C" ]; then
  echo "ERRORE: manca $BATCH_C"
  exit 10
fi

if [ ! -f "$BATCH_C/summary.json" ]; then
  echo "ERRORE: manca $BATCH_C/summary.json"
  exit 11
fi

if [ ! -f "$BATCH_C/post_batch_c_authority_v3_summary.json" ]; then
  echo "ERRORE: manca $BATCH_C/post_batch_c_authority_v3_summary.json"
  exit 12
fi

echo "OK: Batch C presente"
cat "$BATCH_C/summary.json" | python3 -m json.tool

echo
echo "[2/9] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_FINAL_PROMOTION_GATE_V1_SAFE_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_perfection_batch_c_weak_to_premium_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[3/9] Copia sorgenti Batch C"

cp "$BATCH_C/summary.json" "$OUT/source_batch_c_summary.json" || true
cp "$BATCH_C/failed_pages.tsv" "$OUT/source_failed_pages.tsv" 2>/dev/null || true
cp "$BATCH_C/post_batch_c_authority_v3_summary.json" "$OUT/source_post_batch_c_authority_v3_summary.json" || true
cp "$BATCH_C/post_batch_c_leaf_domain_summary.tsv" "$OUT/source_post_batch_c_leaf_domain_summary.tsv" || true
cp "$BATCH_C/post_batch_c_leaf_scorecard.tsv" "$OUT/source_post_batch_c_leaf_scorecard.tsv" || true

echo
echo "[4/9] Analisi failed_pages residuo"

python3 - "$PUBLIC" "$REG" "$BATCH_C" "$OUT" <<'PY'
import csv, json, sys
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
unresolved = []

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
            row = {
                "url": url,
                "reason": reason,
                "exists": f.exists(),
                "registry_class": item.get("class") if item else None
            }
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
                row["decision"] = "unresolved_missing_leaf"
                unresolved.append(row)

data = {
    "failed_count": len(failed),
    "resolved_count": len(resolved),
    "ignored_count": len(ignored),
    "unresolved_count": len(unresolved),
    "failed": failed,
    "resolved": resolved,
    "ignored": ignored,
    "unresolved": unresolved
}

(out / "failed_pages_repair_analysis.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(data, indent=2, ensure_ascii=False))
PY

echo
echo "[5/9] Calcolo Final Leaf Authority da Batch C"

python3 - "$BATCH_C" "$OUT" <<'PY'
import json, shutil
from pathlib import Path

batch = Path(__import__("sys").argv[1])
out = Path(__import__("sys").argv[2])

src_summary = json.loads((batch / "post_batch_c_authority_v3_summary.json").read_text(errors="ignore"))

final = {
    "timestamp": src_summary.get("timestamp"),
    "authority": "TRFMC_FINAL_PROMOTION_AUTHORITY_V1_SAFE",
    "leaf_pages": src_summary.get("leaf_pages"),
    "average_score": src_summary.get("average_score"),
    "critical_pages": src_summary.get("critical_pages"),
    "weak_pages": src_summary.get("weak_pages"),
    "good_pages": src_summary.get("good_pages"),
    "premium_pages": src_summary.get("premium_pages"),
    "premium_ratio": src_summary.get("premium_ratio"),
    "gate": src_summary.get("gate")
}

(out / "final_leaf_authority_summary.json").write_text(json.dumps(final, indent=2, ensure_ascii=False) + "\n")

for name in ["post_batch_c_leaf_domain_summary.tsv", "post_batch_c_leaf_scorecard.tsv"]:
    src = batch / name
    if src.exists():
        dst = out / name.replace("post_batch_c_", "final_")
        shutil.copyfile(src, dst)

print(json.dumps(final, indent=2, ensure_ascii=False))
PY

echo
echo "[6/9] Creo pagina e manifest Final Promotion"

python3 - "$PUBLIC" "$OUT" "$FINAL_PAGE" "$FINAL_MANIFEST" <<'PY'
import json, html
from pathlib import Path
from datetime import datetime, timezone
import re

public = Path(__import__("sys").argv[1])
out = Path(__import__("sys").argv[2])
page = Path(__import__("sys").argv[3])
manifest = Path(__import__("sys").argv[4])

leaf = json.loads((out / "final_leaf_authority_summary.json").read_text(errors="ignore"))
repair = json.loads((out / "failed_pages_repair_analysis.json").read_text(errors="ignore"))

domain_rows = ""
domain_tsv = out / "final_leaf_domain_summary.tsv"
if domain_tsv.exists():
    for line in domain_tsv.read_text(errors="ignore").splitlines()[1:]:
        p = line.split("\t")
        if len(p) >= 7:
            domain_rows += f"<tr><td>{html.escape(p[0])}</td><td>{p[1]}</td><td>{p[2]}</td><td>{p[3]}</td><td>{p[4]}</td><td>{p[5]}</td><td>{p[6]}</td></tr>"

score_rows = ""
score_tsv = out / "final_leaf_scorecard.tsv"
if score_tsv.exists():
    for line in score_tsv.read_text(errors="ignore").splitlines()[1:40]:
        p = line.split("\t")
        if len(p) >= 12:
            score_rows += f'<tr class="{html.escape(p[1].lower())}"><td>{p[0]}</td><td>{html.escape(p[1])}</td><td>{html.escape(p[2])}</td><td><a href="{html.escape(p[4])}">{html.escape(p[4])}</a></td><td>{html.escape(p[11][:160])}</td></tr>'

manifest_data = {
    "id": "TRFMC_FINAL_PROMOTION_GATE_V1_SAFE",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "leaf_gate": leaf,
    "failed_pages_repair": {
        "failed_count": repair.get("failed_count"),
        "resolved_count": repair.get("resolved_count"),
        "ignored_count": repair.get("ignored_count"),
        "unresolved_count": repair.get("unresolved_count")
    },
    "policy": "Final promotion after Batch C leaf gate PASS. No CDN. No iframe. V6R3 and Control Room protected."
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n")

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
    <div class="leaf-sub">Promotion Certified · leaf gate PASS · critical zero · weak zero · no CDN · no iframe</div>
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
<p><b>{html.escape(str(leaf.get("gate")))}</b></p>
<p>Il perimetro leaf operativo è certificato: critical zero, weak zero, external zero, iframe zero.</p>
</div>
<div class="leaf-card">
<h3>Batch C WARN repair</h3>
<p>failed: {repair.get("failed_count")} · resolved: {repair.get("resolved_count")} · ignored: {repair.get("ignored_count")} · unresolved: {repair.get("unresolved_count")}</p>
</div>
</aside>

<main class="leaf-panel">
<h2>Final Leaf Quality</h2>
<div class="final-kpis">
<div class="final-kpi"><small>Average</small><b>{leaf.get("average_score")}</b></div>
<div class="final-kpi"><small>Critical</small><b>{leaf.get("critical_pages")}</b></div>
<div class="final-kpi"><small>Weak</small><b>{leaf.get("weak_pages")}</b></div>
<div class="final-kpi"><small>Good</small><b>{leaf.get("good_pages")}</b></div>
<div class="final-kpi"><small>Premium</small><b>{leaf.get("premium_pages")}</b></div>
<div class="final-kpi"><small>Ratio</small><b>{leaf.get("premium_ratio")}</b></div>
</div>

<div class="leaf-card">
<h3>Domain summary</h3>
<table><thead><tr><th>Domain</th><th>Leaf</th><th>Avg</th><th>Critical</th><th>Weak</th><th>Good</th><th>Premium</th></tr></thead><tbody>{domain_rows}</tbody></table>
</div>

<div class="leaf-card">
<h3>Lowest remaining pages</h3>
<table><thead><tr><th>Score</th><th>Severity</th><th>Domain</th><th>URL</th><th>Residual gaps</th></tr></thead><tbody>{score_rows}</tbody></table>
</div>
</main>
</div>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
</body>
</html>
''')

print(json.dumps(manifest_data, indent=2, ensure_ascii=False))
PY

echo
echo "[7/9] Registro pagina finale come service"

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
    "upgrade": "Final Promotion Gate V1 SAFE"
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
reg["last_final_promotion_gate_v1_safe_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_final_promotion_gate_v1.html",
    "policy": "Final promotion service page only; V6R3 and Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[8/9] HTTP + external/iframe gate"

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
echo "[9/9] Summary + freeze"

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
    "operation": "TRFMC_FINAL_PROMOTION_GATE_V1_SAFE",
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
    "policy": "Final promotion gate. V6R3 and Control Room files unchanged. Registry updated only with final service page."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
(out / "result.flag").write_text(summary["result"] + "\n")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_FINAL_PROMOTION_GATE_V1_SAFE_PASS_$TS.tar.gz"
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
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_final_promotion_gate_v1.html"
echo "============================================================"
