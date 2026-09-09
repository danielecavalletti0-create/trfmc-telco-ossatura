#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets/trfmc_design_system"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_MASTER_DESIGN_SYSTEM_$TS"
LATEST="$BASE/runtime/quality/latest_master_design_system"

mkdir -p "$ASSETS" "$OUT" "$BASE/runtime/backups" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC MASTER DESIGN SYSTEM V1"
echo "tokens · style master · anti-fragmentation baseline"
echo "============================================================"

cd "$BASE"

echo "[1/6] Backup eventuali file esistenti"
cp -av "$ASSETS/trfmc_design_tokens.css" "$BASE/runtime/backups/trfmc_design_tokens_$TS.css.bak" 2>/dev/null || true
cp -av "$PUBLIC/trfmc_integration_control_room.html" "$BASE/runtime/backups/trfmc_integration_control_room_before_design_$TS.html.bak" 2>/dev/null || true

echo "[2/6] Creo design tokens master"
cat > "$ASSETS/trfmc_design_tokens.css" <<'CSS'
:root{
  --trfmc-bg:#02070d;
  --trfmc-bg-2:#061827;
  --trfmc-panel:#071827;
  --trfmc-panel-2:#092033;
  --trfmc-line:#0b75a8;
  --trfmc-line-soft:#0b3f5f;
  --trfmc-cyan:#00e5ff;
  --trfmc-green:#75ff5b;
  --trfmc-yellow:#ffd84d;
  --trfmc-red:#ff3d7f;
  --trfmc-blue:#1e9cff;
  --trfmc-text:#e8f9ff;
  --trfmc-muted:#8bb7c9;
  --trfmc-shadow:0 0 22px rgba(0,229,255,.18);
  --trfmc-font:Inter,Segoe UI,Arial,sans-serif;
}

*{box-sizing:border-box}
body{
  margin:0;
  background:
    radial-gradient(circle at 30% 0%,rgba(0,229,255,.08),transparent 28%),
    linear-gradient(180deg,#02070d,#010409 70%);
  color:var(--trfmc-text);
  font-family:var(--trfmc-font);
}

.trfmc-shell-header{
  padding:12px 16px;
  border-bottom:1px solid var(--trfmc-line);
  background:linear-gradient(90deg,#04101b,#06243a);
  box-shadow:var(--trfmc-shadow);
}

.trfmc-title{
  margin:0;
  color:var(--trfmc-cyan);
  letter-spacing:2px;
  font-size:18px;
  text-transform:uppercase;
}

.trfmc-subtitle{
  color:var(--trfmc-muted);
  font-size:12px;
}

.trfmc-grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(300px,1fr));
  gap:10px;
}

.trfmc-card{
  border:1px solid var(--trfmc-line);
  background:linear-gradient(180deg,rgba(7,24,39,.98),rgba(3,12,20,.98));
  border-radius:6px;
  padding:12px;
  box-shadow:inset 0 0 0 1px rgba(0,229,255,.04);
}

.trfmc-card h3{
  margin:0 0 8px;
  color:var(--trfmc-yellow);
  font-size:13px;
  text-transform:uppercase;
}

.trfmc-badge{
  display:inline-block;
  padding:2px 7px;
  border:1px solid var(--trfmc-line);
  border-radius:4px;
  margin:2px;
  font-size:10px;
  color:var(--trfmc-cyan);
  background:#03101a;
}

.trfmc-ok{color:var(--trfmc-green)}
.trfmc-warn{color:var(--trfmc-yellow)}
.trfmc-bad{color:var(--trfmc-red)}

.trfmc-btn{
  display:inline-block;
  border:1px solid var(--trfmc-line);
  background:#06243a;
  color:var(--trfmc-cyan);
  padding:7px 10px;
  border-radius:4px;
  text-decoration:none;
  font-size:12px;
}
.trfmc-btn:hover{background:#08324f}

.trfmc-kpi{
  font-size:28px;
  color:var(--trfmc-green);
  font-weight:700;
}

.trfmc-note{
  color:var(--trfmc-muted);
  font-size:12px;
  line-height:1.45;
}
CSS

echo "[3/6] Creo Control Room V2 con filtri"
cat > "$PUBLIC/trfmc_integration_control_room_v2.html" <<'HTML'
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Integration Control Room V2</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_design_tokens.css">
<style>
main{padding:12px}
.toolbar{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}
input,select{background:#03101a;color:#e8f9ff;border:1px solid #0b75a8;border-radius:4px;padding:7px}
.small{font-size:11px;color:#8bb7c9}
</style>
</head>
<body>
<header class="trfmc-shell-header">
  <h1 class="trfmc-title">TRFMC Integration Control Room V2</h1>
  <div class="trfmc-subtitle">registry unico · design system master · anti-frammentazione · moduli leaf controllati</div>
</header>

<main>
  <section class="trfmc-card">
    <h3>Policy operativa</h3>
    <div class="trfmc-note">
      V6R3 resta shell ufficiale. Nessuna promozione diretta di pagine con MULTIPLE_NAV_OR_TOOLBAR, fixed layer e molte z-index.
      Le pagine WebGL premium diventano moduli leaf o sorgenti da cui estrarre stile, non portali paralleli.
    </div>
  </section>

  <div class="toolbar">
    <input id="q" placeholder="cerca modulo, dominio, nome file..." size="42">
    <select id="klass">
      <option value="">tutte le classi</option>
    </select>
    <select id="webgl">
      <option value="">WebGL: tutti</option>
      <option value="true">solo WebGL</option>
      <option value="false">no WebGL</option>
    </select>
  </div>

  <section id="summary" class="trfmc-grid"></section>

  <h2 class="trfmc-title" style="font-size:15px;margin-top:18px">Moduli censiti</h2>
  <section id="pages" class="trfmc-grid"></section>
</main>

<script>
let REG=null;

function badge(txt,cls=""){return `<span class="trfmc-badge ${cls}">${txt}</span>`}

function render(){
 const q=document.getElementById('q').value.toLowerCase();
 const klass=document.getElementById('klass').value;
 const webgl=document.getElementById('webgl').value;

 let pages=REG.pages.filter(x=>{
   const blob=(x.name+" "+x.class+" "+(x.url||"")).toLowerCase();
   if(q && !blob.includes(q)) return false;
   if(klass && x.class!==klass) return false;
   if(webgl && String(x.webgl)!==webgl) return false;
   return true;
 });

 document.getElementById('summary').innerHTML=`
  <div class="trfmc-card"><h3>Total HTML</h3><div class="trfmc-kpi">${REG.counts.total_html}</div></div>
  <div class="trfmc-card"><h3>Leaf candidate</h3><div class="trfmc-kpi">${REG.counts.leaf_operational_candidate}</div></div>
  <div class="trfmc-card"><h3>Orphan / legacy</h3><div class="trfmc-kpi trfmc-warn">${REG.counts.orphan_or_legacy_candidate}</div></div>
  <div class="trfmc-card"><h3>Filtro attuale</h3><div class="trfmc-kpi">${pages.length}</div></div>
 `;

 document.getElementById('pages').innerHTML=pages.map(x=>`
  <article class="trfmc-card">
    <h3>${x.name}</h3>
    <div>
      ${badge(x.class)}
      ${x.webgl?badge('WEBGL','trfmc-ok'):''}
      ${x.core_api?badge('API','trfmc-warn'):''}
      ${x.has_iframe?badge('IFRAME','trfmc-warn'):''}
      ${x.external_refs?badge('EXT','trfmc-bad'):''}
    </div>
    <p class="small">size: ${x.size} bytes · refs: ${x.refs_count}</p>
    <a class="trfmc-btn" href="${x.url}" target="_blank">Apri modulo</a>
  </article>
 `).join('');
}

async function boot(){
 const r=await fetch('/trfmc_portal_registry_unified.json',{cache:'no-store'});
 REG=await r.json();

 const classes=[...new Set(REG.pages.map(x=>x.class))].sort();
 const sel=document.getElementById('klass');
 classes.forEach(c=>{
   const o=document.createElement('option');
   o.value=c; o.textContent=c;
   sel.appendChild(o);
 });

 ['q','klass','webgl'].forEach(id=>document.getElementById(id).addEventListener('input',render));
 render();
}

boot().catch(e=>document.body.innerHTML+='<pre>'+e+'</pre>');
</script>
</body>
</html>
HTML

echo "[4/6] Quality gate"
{
  echo -e "url\tstatus\tbytes"
  for u in \
    /assets/trfmc_design_system/trfmc_design_tokens.css \
    /trfmc_integration_control_room_v2.html \
    /trfmc_portal_registry_unified.json \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html
  do
    read -r code bytes < <(curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 5 "http://127.0.0.1:5173$u" || echo "000 0")
    echo -e "$u\t$code\t$bytes"
  done
} > "$OUT/http.tsv"

grep -nEi 'https://|cdn\.|unpkg|jsdelivr|cdnjs' "$PUBLIC/trfmc_integration_control_room_v2.html" > "$OUT/external_refs.txt" 2>/dev/null || true
grep -nEi '<iframe' "$PUBLIC/trfmc_integration_control_room_v2.html" > "$OUT/iframe_refs.txt" 2>/dev/null || true

export OUT
python3 - <<'PY'
import json, os
from pathlib import Path
from datetime import datetime, timezone

out=Path(os.environ["OUT"])
non200=0
for line in (out/"http.tsv").read_text().splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=2 and p[1]!="200":
        non200+=1
external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "design_tokens":"http://127.0.0.1:5173/assets/trfmc_design_system/trfmc_design_tokens.css",
 "control_room_v2":"http://127.0.0.1:5173/trfmc_integration_control_room_v2.html",
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

echo "[5/6] Freeze se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_MASTER_DESIGN_SYSTEM_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .
  ls -lh "$FREEZE"
fi

echo "[6/6] Report"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_integration_control_room_v2.html"
