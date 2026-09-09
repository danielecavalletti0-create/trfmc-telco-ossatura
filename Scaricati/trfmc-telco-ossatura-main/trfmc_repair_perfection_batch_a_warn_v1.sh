#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
SRC="$BASE/runtime/quality/latest_perfection_surgical_batch_a_v1"
OUT="$BASE/runtime/quality/TRFMC_REPAIR_PERFECTION_BATCH_A_WARN_V1_$TS"
LATEST="$BASE/runtime/quality/latest_repair_perfection_batch_a_warn_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

mkdir -p "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC REPAIR PERFECTION BATCH A WARN V1"
echo "Fix external refs · remove iframes · recover missing patched leaf"
echo "============================================================"

if [ ! -d "$SRC" ]; then
  echo "ERRORE: manca $SRC"
  exit 1
fi

echo
echo "[1/7] Snapshot e hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_REPAIR_PERFECTION_BATCH_A_WARN_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_perfection_surgical_batch_a_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/7] Diagnostica sorgente WARN"

cp "$SRC/summary.json" "$OUT/source_batch_a_summary.json" 2>/dev/null || true
cp "$SRC/patched_pages.tsv" "$OUT/source_patched_pages.tsv" 2>/dev/null || true
cp "$SRC/failed_pages.tsv" "$OUT/source_failed_pages.tsv" 2>/dev/null || true
cp "$SRC/external_refs.txt" "$OUT/source_external_refs.txt" 2>/dev/null || true
cp "$SRC/iframe_refs.txt" "$OUT/source_iframe_refs.txt" 2>/dev/null || true

echo
echo "[3/7] Bonifica iframe/ref esterni sulle pagine patchate"

python3 - "$PUBLIC" "$SRC" "$OUT" <<'PY'
from pathlib import Path
import re, sys, html, json

public = Path(sys.argv[1])
src = Path(sys.argv[2])
out = Path(sys.argv[3])

patched_file = src / "patched_pages.tsv"
failed_file = src / "failed_pages.tsv"

protected_terms = [
    "trfmc_official_safe_entrypoint_v6r3_command_center",
    "trfmc_integration_control_room",
    "trfmc_perfection_authority",
    "trfmc_portal_registry_unified"
]

def is_protected(url: str) -> bool:
    return any(t in url for t in protected_terms)

def read_urls_from_tsv(path):
    if not path.exists():
        return []
    lines = path.read_text(errors="ignore").splitlines()
    urls = []
    for line in lines[1:]:
        if not line.strip():
            continue
        urls.append(line.split("\t")[0].strip())
    return urls

patched_urls = read_urls_from_tsv(patched_file)

failed = []
if failed_file.exists():
    for line in failed_file.read_text(errors="ignore").splitlines()[1:]:
        if not line.strip():
            continue
        p = line.split("\t")
        failed.append((p[0], p[1] if len(p) > 1 else "unknown"))

iframe_re = re.compile(r"<iframe\b[^>]*>.*?</iframe\s*>", re.I | re.S)
iframe_self_re = re.compile(r"<iframe\b[^>]*/\s*>", re.I | re.S)

external_script_re = re.compile(
    r"<script\b[^>]*\bsrc\s*=\s*(['\"])(https?:\/\/|\/\/)[^'\"]+\1[^>]*>\s*</script\s*>",
    re.I | re.S
)
external_link_re = re.compile(
    r"<link\b[^>]*\bhref\s*=\s*(['\"])(https?:\/\/|\/\/)[^'\"]+\1[^>]*>",
    re.I | re.S
)
external_attr_re = re.compile(
    r"\b(href|src|action|poster)\s*=\s*(['\"])((?:https?:\/\/|\/\/)[^'\"]+)\2",
    re.I
)
srcset_re = re.compile(
    r"\bsrcset\s*=\s*(['\"])[^'\"]*(?:https?:\/\/|\/\/)[^'\"]*\1",
    re.I
)
css_url_re = re.compile(
    r"url\(\s*(['\"]?)(?:https?:\/\/|\/\/)[^)'\"]+\1\s*\)",
    re.I
)

def placeholder_iframe(match):
    raw = match.group(0)
    m = re.search(r"\bsrc\s*=\s*(['\"])(.*?)\1", raw, re.I)
    src_val = m.group(2) if m else "unknown"
    src_safe = html.escape(src_val)
    return (
        '<div class="trfmc-perfection-card" data-trfmc-iframe-removed="true">'
        '<h3>Iframe rimosso dal gate di perfezione</h3>'
        '<div class="trfmc-perfection-formulas">'
        f'Embedded frame quarantinato. Origine precedente: {src_safe}'
        '</div></div>'
    )

def sanitize_external_attr(match):
    attr = match.group(1).lower()
    quote = match.group(2)
    val = match.group(3)
    val_safe = html.escape(val, quote=True)

    if attr == "href":
        return f'href="#trfmc-external-ref-blocked" data-trfmc-blocked-href={quote}{val_safe}{quote}'
    if attr == "src":
        return f'data-trfmc-blocked-src={quote}{val_safe}{quote}'
    return f'data-trfmc-blocked-{attr}={quote}{val_safe}{quote}'

def sanitize_text(s):
    before_iframes = len(iframe_re.findall(s)) + len(iframe_self_re.findall(s))
    before_external_script = len(external_script_re.findall(s))
    before_external_link = len(external_link_re.findall(s))
    before_external_attr = len(external_attr_re.findall(s))
    before_srcset = len(srcset_re.findall(s))
    before_css_url = len(css_url_re.findall(s))

    s = external_script_re.sub("<!-- TRFMC external script removed by perfection repair -->", s)
    s = external_link_re.sub("<!-- TRFMC external stylesheet/link removed by perfection repair -->", s)
    s = iframe_re.sub(placeholder_iframe, s)
    s = iframe_self_re.sub(placeholder_iframe, s)
    s = srcset_re.sub('data-trfmc-blocked-srcset="external-srcset-removed"', s)
    s = css_url_re.sub("none", s)
    s = external_attr_re.sub(sanitize_external_attr, s)

    return s, {
        "iframes_removed": before_iframes,
        "external_script_removed": before_external_script,
        "external_link_removed": before_external_link,
        "external_attr_sanitized": before_external_attr,
        "srcset_sanitized": before_srcset,
        "css_url_sanitized": before_css_url,
    }

def ensure_recovery_page(url, reason):
    if is_protected(url):
        return None

    f = public / url.lstrip("/")
    if f.exists():
        return None

    title = url.strip("/").replace(".html", "").replace("_", " ").title()
    domain = "core" if any(x in url.lower() for x in ["core","ran","identity","signal","mission","operator"]) else "microwave"
    kind = "core-map" if domain == "core" else "microwave-dish"

    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · Recovered Leaf</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<link rel="stylesheet" href="/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.css">
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<section class="trfmc-perfection-bridge" data-domain="{domain}" data-trfmc-recovered-leaf="true">
  <div class="trfmc-perfection-head">
    <div>
      <div class="trfmc-perfection-title">TRFMC Recovered Leaf · {domain.upper()}</div>
      <div class="trfmc-perfection-sub">{html.escape(url)}<br>Recovered because previous Batch A reported: {html.escape(reason)}</div>
    </div>
    <div class="trfmc-perfection-kpis">
      <div class="trfmc-perfection-kpi"><small>Status</small><b>RECOVERED</b></div>
      <div class="trfmc-perfection-kpi"><small>Iframe</small><b>ZERO</b></div>
      <div class="trfmc-perfection-kpi"><small>External</small><b>ZERO</b></div>
      <div class="trfmc-perfection-kpi"><small>Asset</small><b>{kind}</b></div>
    </div>
  </div>
  <div class="trfmc-perfection-grid">
    <div class="trfmc-perfection-asset">
      <trfmc-visual-asset kind="{kind}" data-size="medium" title="Recovered TRFMC Leaf"></trfmc-visual-asset>
    </div>
    <div>
      <div class="trfmc-perfection-card">
        <h3>Recovery doctrine</h3>
        <div class="trfmc-perfection-formulas formulaLive">Recovered page placeholder.
No CDN.
No iframe.
No external references.
Ready for future full engineering rebuild.</div>
      </div>
      <div class="trfmc-perfection-card">
        <h3>Live scope</h3>
        <canvas class="trfmc-bridge-scope" data-domain="{domain}"></canvas>
      </div>
    </div>
  </div>
</section>
<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
<script src="/assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.js"></script>
</body>
</html>
''', encoding="utf-8")
    return str(url)

results = []
changed_urls = []

for url in patched_urls:
    if not url or is_protected(url):
        continue

    f = public / url.lstrip("/")
    if not f.exists():
        results.append({"url": url, "status": "missing_in_patched_list"})
        continue

    old = f.read_text(errors="ignore")
    new, stats = sanitize_text(old)

    if new != old:
        f.write_text(new, encoding="utf-8")
        changed_urls.append(url)
        status = "changed"
    else:
        status = "unchanged"

    results.append({"url": url, "status": status, **stats})

recovered = []
for url, reason in failed:
    rec = ensure_recovery_page(url, reason)
    if rec:
        recovered.append(rec)
        changed_urls.append(rec)

(out / "repair_results.json").write_text(json.dumps({
    "patched_urls_seen": len(patched_urls),
    "changed_urls": changed_urls,
    "changed_count": len(changed_urls),
    "recovered": recovered,
    "results": results,
}, indent=2, ensure_ascii=False), encoding="utf-8")

(out / "changed_pages.tsv").write_text(
    "url\n" + "\n".join(changed_urls) + "\n",
    encoding="utf-8"
)

print(json.dumps({
    "patched_urls_seen": len(patched_urls),
    "changed_count": len(changed_urls),
    "recovered_count": len(recovered),
}, indent=2))
PY

echo
echo "[4/7] Rilettura reale post-riparazione"

python3 - "$PUBLIC" "$OUT" <<'PY'
from pathlib import Path
import re, json, sys

public = Path(sys.argv[1])
out = Path(sys.argv[2])

changed = []
p = out / "changed_pages.tsv"
if p.exists():
    for line in p.read_text(errors="ignore").splitlines()[1:]:
        if line.strip():
            changed.append(line.strip())

external_patterns = [
    re.compile(r"<script\b[^>]*\bsrc\s*=\s*(['\"])(https?:\/\/|\/\/)", re.I),
    re.compile(r"<link\b[^>]*\bhref\s*=\s*(['\"])(https?:\/\/|\/\/)", re.I),
    re.compile(r"\b(?:href|src|action|poster)\s*=\s*(['\"])(https?:\/\/|\/\/)", re.I),
    re.compile(r"\bsrcset\s*=\s*(['\"])[^'\"]*(?:https?:\/\/|\/\/)", re.I),
    re.compile(r"url\(\s*(['\"]?)(?:https?:\/\/|\/\/)", re.I),
]
iframe_re = re.compile(r"<iframe\b", re.I)

ext_lines = []
iframe_lines = []

for url in changed:
    f = public / url.lstrip("/")
    if not f.exists():
        continue
    lines = f.read_text(errors="ignore").splitlines()
    for i, line in enumerate(lines, start=1):
        if any(rx.search(line) for rx in external_patterns):
            ext_lines.append(f"{url}:{i}:{line[:220]}")
        if iframe_re.search(line):
            iframe_lines.append(f"{url}:{i}:{line[:220]}")

(out / "external_refs_after.txt").write_text("\n".join(ext_lines) + ("\n" if ext_lines else ""), encoding="utf-8")
(out / "iframe_refs_after.txt").write_text("\n".join(iframe_lines) + ("\n" if iframe_lines else ""), encoding="utf-8")

print(json.dumps({
    "changed_pages": len(changed),
    "external_refs_after": len(ext_lines),
    "iframe_refs_after": len(iframe_lines)
}, indent=2))
PY

echo
echo "[5/7] HTTP gate"

{
  printf "url\tstatus\tbytes\n"

  for u in \
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.css \
    /assets/trfmc_perfection_bridge/trfmc_perfection_bridge_v1.js \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_portal_registry_unified.json
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done

  tail -n +2 "$OUT/changed_pages.tsv" | while read -r u; do
    [ -n "$u" ] || continue
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

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

http_rows = []
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    parts = line.split("\t")
    if len(parts) >= 3:
        http_rows.append({"url": parts[0], "status": parts[1], "bytes": parts[2]})

non200 = sum(1 for r in http_rows if r["status"] != "200")
external_after = sum(1 for x in (out / "external_refs_after.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe_after = sum(1 for x in (out / "iframe_refs_after.txt").read_text(errors="ignore").splitlines() if x.strip())

repair = json.loads((out / "repair_results.json").read_text(errors="ignore"))
changed = repair.get("changed_count", 0)
recovered = len(repair.get("recovered", []))

sha = {}
for line in (out / "sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        sha[k] = v

protected_ok = (
    sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
)
registry_unchanged = sha.get("REG_SHA_BEFORE") == sha.get("REG_SHA_AFTER")
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "repair": "TRFMC_REPAIR_PERFECTION_BATCH_A_WARN_V1",
    "changed_pages": changed,
    "recovered_missing_pages": recovered,
    "http_non_200": non200,
    "external_refs_after": external_after,
    "iframe_refs_after": iframe_after,
    "protected_v6r3_and_control_unchanged": protected_ok,
    "registry_unchanged": registry_unchanged,
    "registry_total_html": reg.get("counts", {}).get("total_html"),
    "result": "PASS" if changed >= 1 and non200 == 0 and external_after == 0 and iframe_after == 0 and protected_ok and registry_unchanged else "WARN",
    "policy": "Repair Batch A warnings before continuing. No V6R3, Control Room or registry mutation."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[7/7] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_REPAIR_PERFECTION_BATCH_A_WARN_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public \
    runtime/quality/latest_repair_perfection_batch_a_warn_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv" | sed -n '1,140p'
echo
echo "=== EXTERNAL AFTER ==="
cat "$OUT/external_refs_after.txt" || true
echo
echo "=== IFRAME AFTER ==="
cat "$OUT/iframe_refs_after.txt" || true
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Ora rilancia:"
echo "./trfmc_create_perfection_authority_v1.sh"
echo "============================================================"
