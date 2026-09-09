#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

OUT="$BASE/runtime/quality/TRFMC_CONSOLIDATION_REGISTRY_$TS"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
ROOM="$PUBLIC/trfmc_integration_control_room.html"
LATEST="$BASE/runtime/quality/latest_consolidation_registry"

mkdir -p "$OUT" "$BASE/runtime/quality" "$BASE/runtime/freezes" "$BASE/runtime/backups"

echo "============================================================"
echo "TRFMC PORTAL CONSOLIDATION REGISTRY V1"
echo "registry unico · control room · no nuove pagine sparse"
echo "============================================================"

cd "$BASE"

echo
echo "[1/6] Backup stato corrente"
cp -av "$REG" "$BASE/runtime/backups/trfmc_portal_registry_unified_$TS.json.bak" 2>/dev/null || true
cp -av "$ROOM" "$BASE/runtime/backups/trfmc_integration_control_room_$TS.html.bak" 2>/dev/null || true

echo
echo "[2/6] Scansione pagine HTML"
find "$PUBLIC" -maxdepth 1 -type f -name '*.html' -printf '%f\t%s\n' | sort > "$OUT/html_pages.tsv"

echo
echo "[3/6] Creo registry JSON"
python3 - <<'PY'
import json, re
from pathlib import Path
from datetime import datetime, timezone

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")
public = base / "frontend/public"
out = base / "runtime/quality"
pages = []

official_names = {
    "trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "trfmc_portal_link_graph_v1.html",
}
service_patterns = ["reset", "safe_entrypoint_v6r1", "safe_entrypoint_v6r2"]
high_value_keywords = [
    "webgl", "signal_intelligence", "core_network", "metrology",
    "fft", "antenna", "microwave", "wifi", "5g_core",
    "converged", "war_room", "master_console", "rf"
]

for p in sorted(public.glob("*.html")):
    name = p.name
    txt = p.read_text(errors="ignore")
    hrefs = re.findall(r'href=["\']([^"\']+\.html)["\']', txt)
    srcs = re.findall(r'src=["\']([^"\']+\.html)["\']', txt)
    refs = sorted(set(hrefs + srcs))
    has_iframe = "<iframe" in txt.lower()
    external = bool(re.search(r'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs', txt, re.I))
    webgl = "WebGLRenderer" in txt or "three.module.js" in txt or "OrbitControls" in txt
    core_api = "core-live" in txt or "/api/" in txt
    size = p.stat().st_size

    if name in official_names or "v6r3_command_center" in name:
        klass = "official_shell"
    elif any(x in name for x in service_patterns):
        klass = "service"
    elif webgl or any(k in name for k in high_value_keywords):
        klass = "leaf_operational_candidate"
    elif has_iframe:
        klass = "shell_or_legacy_container"
    else:
        klass = "orphan_or_legacy_candidate"

    pages.append({
        "name": name,
        "url": "/" + name,
        "size": size,
        "class": klass,
        "webgl": webgl,
        "core_api": core_api,
        "has_iframe": has_iframe,
        "external_refs": external,
        "refs_count": len(refs),
        "refs": refs[:50],
    })

registry = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "policy": {
        "rule_1": "Non creare nuove pagine isolate.",
        "rule_2": "Ogni nuova pagina deve entrare nel registry.",
        "rule_3": "Ogni modulo promosso deve avere HTTP 200, zero external CDN, zero nested shell iframe.",
        "rule_4": "V6R3 rimane entrypoint ufficiale finché non viene promosso un nuovo shell PASS.",
    },
    "official_entrypoint": "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "integration_control_room": "/trfmc_integration_control_room.html",
    "counts": {
        "total_html": len(pages),
        "official_shell": sum(1 for x in pages if x["class"] == "official_shell"),
        "service": sum(1 for x in pages if x["class"] == "service"),
        "leaf_operational_candidate": sum(1 for x in pages if x["class"] == "leaf_operational_candidate"),
        "shell_or_legacy_container": sum(1 for x in pages if x["class"] == "shell_or_legacy_container"),
        "orphan_or_legacy_candidate": sum(1 for x in pages if x["class"] == "orphan_or_legacy_candidate"),
    },
    "pages": pages,
}

(public / "trfmc_portal_registry_unified.json").write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(registry["counts"], indent=2))
PY

echo
echo "[4/6] Creo Integration Control Room"
cat > "$ROOM" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Integration Control Room</title>
<style>
body{margin:0;background:#02070d;color:#e8f9ff;font-family:Inter,Segoe UI,Arial,sans-serif}
header{padding:18px;border-bottom:1px solid #0b75a8;background:#061827}
h1{margin:0;color:#00e5ff;letter-spacing:2px}
main{padding:14px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:10px}
.card{border:1px solid #0b75a8;background:#071827;padding:12px;border-radius:6px}
.card h3{margin:0 0 8px;color:#ffd400}
a{color:#00e5ff;text-decoration:none}
.badge{display:inline-block;padding:2px 6px;border:1px solid #0b75a8;border-radius:4px;margin:2px;font-size:11px}
.ok{color:#75ff5b}.warn{color:#ffd84d}.bad{color:#ff3d7f}
pre{white-space:pre-wrap;color:#bcecff}
</style>
</head>
<body>
<header>
<h1>TRFMC INTEGRATION CONTROL ROOM</h1>
<div>Registry unico del portale · controllo moduli · anti-frammentazione</div>
</header>
<main>
<div class="card">
<h3>Policy</h3>
<pre>
1. Nessuna nuova pagina isolata.
2. Ogni modulo deve essere nel registry.
3. Ogni promozione richiede HTTP 200, zero CDN esterne, zero nested shell iframe.
4. V6R3 resta entrypoint ufficiale.
</pre>
</div>
<div id="summary" class="grid"></div>
<h2>Moduli</h2>
<div id="pages" class="grid"></div>
</main>
<script>
async function loadRegistry(){
 const r=await fetch('/trfmc_portal_registry_unified.json',{cache:'no-store'});
 const reg=await r.json();
 const s=document.getElementById('summary');
 s.innerHTML=Object.entries(reg.counts).map(([k,v])=>`
 <div class="card"><h3>${k}</h3><div style="font-size:28px">${v}</div></div>`).join('');
 const p=document.getElementById('pages');
 p.innerHTML=reg.pages.map(x=>`
 <div class="card">
  <h3>${x.name}</h3>
  <div><span class="badge">${x.class}</span>${x.webgl?'<span class="badge ok">WEBGL</span>':''}${x.core_api?'<span class="badge warn">API</span>':''}${x.has_iframe?'<span class="badge warn">IFRAME</span>':''}${x.external_refs?'<span class="badge bad">EXT</span>':''}</div>
  <p>size: ${x.size} bytes · refs: ${x.refs_count}</p>
  <a href="${x.url}" target="_blank">Apri modulo</a>
 </div>`).join('');
}
loadRegistry().catch(e=>document.body.innerHTML+='<pre>'+e+'</pre>');
</script>
</body>
</html>
HTML

echo
echo "[5/6] Quality gate"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /trfmc_portal_registry_unified.json \
    /trfmc_integration_control_room.html \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" || echo "000 0")
    echo -e "$u\t$code\t$bytes"
  done
} | tee "$OUT/http.tsv"

grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' "$ROOM" > "$OUT/external_refs.txt" 2>/dev/null || true
grep -nEi '<iframe' "$ROOM" > "$OUT/iframe_refs.txt" 2>/dev/null || true

export OUT
python3 - <<'PY'
import json, os
from pathlib import Path
from datetime import datetime, timezone

out=Path(os.environ["OUT"])
non200=0
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=2 and p[1]!="200":
        non200+=1
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "registry":"http://127.0.0.1:5173/trfmc_portal_registry_unified.json",
 "control_room":"http://127.0.0.1:5173/trfmc_integration_control_room.html",
 "http_non_200":non200,
 "external_refs":external,
 "iframe_refs":iframe,
 "result":"PASS" if non200==0 and external==0 and iframe==0 else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$OUT" "$LATEST"

echo
echo "[6/6] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_CONSOLIDATION_REGISTRY_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .
  ls -lh "$FREEZE"
fi

echo
echo "=== SUMMARY ==="
cat "$OUT/summary.json" | python3 -m json.tool
echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_integration_control_room.html"
