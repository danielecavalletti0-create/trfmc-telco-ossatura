#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSET_DIR="$PUBLIC/assets/trfmc_visual_xp"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_GLOBAL_VISUAL_XP_V1_$TS"
LATEST="$BASE/runtime/quality/latest_global_visual_xp_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"
CSS="$ASSET_DIR/trfmc_visual_xp_v1.css"
JS="$ASSET_DIR/trfmc_visual_xp_v1.js"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"

cd "$BASE"

echo "============================================================"
echo "TRFMC GLOBAL VISUAL EXPERIENCE LAYER V1"
echo "Cinematic skin · no new bars · no iframe · no CDN · safe patch"
echo "============================================================"

echo
echo "[1/8] Snapshot HTML + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_GLOBAL_VISUAL_XP_V1_$TS.tar.gz"
find frontend/public -maxdepth 1 -type f -name '*.html' -print0 | tar --null -czf "$BACKUP" --files-from - 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/8] Creo Visual Experience CSS"

cat > "$CSS" <<'CSS'
/*
 TRFMC Visual Experience Layer V1
 Safe global skin: no navigation, no iframe, no CDN.
*/

:root{
  --trfmc-vxp-x:50%;
  --trfmc-vxp-y:35%;
  --trfmc-vxp-cyan:#00e5ff;
  --trfmc-vxp-green:#75ff5b;
  --trfmc-vxp-gold:#ffd84d;
  --trfmc-vxp-bg0:#010409;
  --trfmc-vxp-bg1:#03101a;
  --trfmc-vxp-bg2:#061a2a;
  --trfmc-vxp-panel:rgba(2,18,30,.82);
  --trfmc-vxp-border:rgba(0,229,255,.32);
  --trfmc-vxp-soft:rgba(0,229,255,.10);
  --trfmc-vxp-glow:0 0 28px rgba(0,229,255,.18), inset 0 0 18px rgba(0,229,255,.045);
}

html{
  background:#010409;
}

body.trfmc-vxp{
  background:
    radial-gradient(circle at var(--trfmc-vxp-x) var(--trfmc-vxp-y), rgba(0,229,255,.105), transparent 28vw),
    radial-gradient(circle at 78% 16%, rgba(117,255,91,.050), transparent 24vw),
    linear-gradient(135deg,#010409 0%,#020b12 35%,#031827 100%) !important;
  color:#e9fbff;
  overflow-x:hidden;
}

body.trfmc-vxp::before{
  content:"";
  position:fixed;
  inset:0;
  pointer-events:none;
  z-index:0;
  background:
    linear-gradient(rgba(0,229,255,.050) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0,229,255,.040) 1px, transparent 1px);
  background-size:64px 64px;
  mask-image:radial-gradient(circle at var(--trfmc-vxp-x) var(--trfmc-vxp-y), black, transparent 78%);
  opacity:.72;
}

body.trfmc-vxp::after{
  content:"";
  position:fixed;
  inset:0;
  pointer-events:none;
  z-index:999999;
  background:
    linear-gradient(transparent 0%, rgba(255,255,255,.025) 50%, transparent 100%),
    radial-gradient(circle at center, transparent 55%, rgba(0,0,0,.40) 100%);
  background-size:100% 3px, 100% 100%;
  mix-blend-mode:screen;
  opacity:.24;
}

body.trfmc-vxp .leaf-top,
body.trfmc-vxp header.leaf-top{
  background:
    linear-gradient(90deg, rgba(1,9,16,.96), rgba(4,30,48,.94) 52%, rgba(1,9,16,.96)) !important;
  border-bottom:1px solid rgba(0,229,255,.42) !important;
  box-shadow:0 10px 35px rgba(0,0,0,.42), 0 0 35px rgba(0,229,255,.075) !important;
  backdrop-filter:blur(14px) saturate(125%);
}

body.trfmc-vxp .leaf-title,
body.trfmc-vxp h1,
body.trfmc-vxp h2{
  letter-spacing:.08em;
  text-shadow:0 0 16px rgba(0,229,255,.32);
}

body.trfmc-vxp .leaf-panel,
body.trfmc-vxp .leaf-card,
body.trfmc-vxp .plotBox,
body.trfmc-vxp .leaf-kpi,
body.trfmc-vxp .leaf-btn,
body.trfmc-vxp .control input,
body.trfmc-vxp .control select,
body.trfmc-vxp table,
body.trfmc-vxp .formulaLive{
  border-color:var(--trfmc-vxp-border) !important;
  box-shadow:var(--trfmc-vxp-glow) !important;
}

body.trfmc-vxp .leaf-panel,
body.trfmc-vxp .leaf-card,
body.trfmc-vxp .plotBox{
  background:
    linear-gradient(145deg, rgba(2,18,30,.90), rgba(1,7,13,.88)),
    radial-gradient(circle at 80% 12%, rgba(0,229,255,.115), transparent 28%) !important;
  backdrop-filter:blur(12px) saturate(122%);
  position:relative;
}

body.trfmc-vxp .leaf-panel::before,
body.trfmc-vxp .leaf-card::before,
body.trfmc-vxp .plotBox::before{
  content:"";
  position:absolute;
  inset:0;
  pointer-events:none;
  border-radius:inherit;
  background:
    linear-gradient(120deg, rgba(255,255,255,.08), transparent 22%, transparent 75%, rgba(0,229,255,.055));
  opacity:.55;
}

body.trfmc-vxp canvas{
  filter:drop-shadow(0 0 22px rgba(0,229,255,.20)) contrast(1.05) saturate(1.08);
}

body.trfmc-vxp .leaf-kpi b,
body.trfmc-vxp .leaf-ok,
body.trfmc-vxp .value,
body.trfmc-vxp .good{
  text-shadow:0 0 14px rgba(117,255,91,.42);
}

body.trfmc-vxp .leaf-btn{
  background:
    linear-gradient(180deg, rgba(0,229,255,.15), rgba(0,94,130,.13)) !important;
  transition:transform .16s ease, box-shadow .16s ease, border-color .16s ease;
}

body.trfmc-vxp .leaf-btn:hover{
  transform:translateY(-1px);
  border-color:rgba(117,255,91,.60) !important;
  box-shadow:0 0 24px rgba(117,255,91,.20), inset 0 0 18px rgba(0,229,255,.08) !important;
}

body.trfmc-vxp input[type="range"]{
  accent-color:#00e5ff;
}

body.trfmc-vxp ::selection{
  background:rgba(0,229,255,.32);
  color:#ffffff;
}

body.trfmc-vxp ::-webkit-scrollbar{
  width:10px;
  height:10px;
}

body.trfmc-vxp ::-webkit-scrollbar-track{
  background:#010409;
}

body.trfmc-vxp ::-webkit-scrollbar-thumb{
  background:linear-gradient(#00e5ff,#064f68);
  border-radius:8px;
  border:2px solid #010409;
}

.trfmc-vxp-aurora{
  position:fixed;
  inset:-20%;
  z-index:0;
  pointer-events:none;
  background:
    conic-gradient(from 180deg at 50% 50%, transparent, rgba(0,229,255,.10), transparent, rgba(117,255,91,.055), transparent);
  filter:blur(52px);
  opacity:.34;
  animation:trfmcVxpDrift 18s linear infinite;
}

.trfmc-vxp-depth{
  position:fixed;
  inset:0;
  z-index:0;
  pointer-events:none;
  background:
    radial-gradient(circle at 20% 80%, rgba(0,229,255,.08), transparent 26%),
    radial-gradient(circle at 86% 30%, rgba(255,216,77,.055), transparent 21%);
  opacity:.75;
}

@keyframes trfmcVxpDrift{
  0%{transform:rotate(0deg) scale(1);}
  50%{transform:rotate(180deg) scale(1.08);}
  100%{transform:rotate(360deg) scale(1);}
}

@media (prefers-reduced-motion: reduce){
  .trfmc-vxp-aurora{animation:none;}
  body.trfmc-vxp .leaf-btn{transition:none;}
}
CSS

echo
echo "[3/8] Creo Visual Experience JS"

cat > "$JS" <<'JS'
/*
 TRFMC Visual Experience Layer V1
 Adds only ambience layers and interaction variables.
 No navbar, no iframe, no CDN.
*/
(function(){
  "use strict";

  if (window.localStorage && localStorage.getItem("TRFMC_VXP") === "off") return;

  document.addEventListener("DOMContentLoaded", function(){
    document.body.classList.add("trfmc-vxp");

    if (!document.querySelector(".trfmc-vxp-aurora")) {
      const aurora = document.createElement("div");
      aurora.className = "trfmc-vxp-aurora";
      document.body.prepend(aurora);
    }

    if (!document.querySelector(".trfmc-vxp-depth")) {
      const depth = document.createElement("div");
      depth.className = "trfmc-vxp-depth";
      document.body.prepend(depth);
    }

    const reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!reduce) {
      let tx = 50, ty = 35, cx = 50, cy = 35;

      window.addEventListener("pointermove", function(ev){
        tx = (ev.clientX / Math.max(1, window.innerWidth)) * 100;
        ty = (ev.clientY / Math.max(1, window.innerHeight)) * 100;
      }, {passive:true});

      function frame(){
        cx += (tx - cx) * 0.045;
        cy += (ty - cy) * 0.045;
        document.documentElement.style.setProperty("--trfmc-vxp-x", cx.toFixed(2) + "%");
        document.documentElement.style.setProperty("--trfmc-vxp-y", cy.toFixed(2) + "%");
        requestAnimationFrame(frame);
      }
      requestAnimationFrame(frame);
    }

    document.querySelectorAll(".leaf-panel,.leaf-card,.plotBox,.leaf-kpi").forEach(function(el){
      el.setAttribute("data-trfmc-vxp", "active");
    });
  });
})();
JS

echo
echo "[4/8] Patch pagine leaf operative da registry, senza toccare shell ufficiali"

python3 - "$BASE" "$PUBLIC" "$REG" "$OUT" <<'PY'
import json, re, sys
from pathlib import Path

base=Path(sys.argv[1])
public=Path(sys.argv[2])
reg_path=Path(sys.argv[3])
out=Path(sys.argv[4])

css_href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css"
js_src="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.js"

protected={
    "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "/trfmc_integration_control_room.html",
    "/trfmc_portal_registry_unified.json",
}

reg=json.loads(reg_path.read_text(errors="ignore"))
pages=reg.get("pages",[])
patched=[]
skipped=[]
missing=[]

def inject_body_class(s):
    m=re.search(r"<body\b([^>]*)>", s, flags=re.I)
    if not m:
        return s
    body=m.group(0)
    attrs=m.group(1)
    if "trfmc-vxp" in body:
        return s
    if re.search(r'\bclass\s*=', body, flags=re.I):
        new_body=re.sub(r'class\s*=\s*["\']([^"\']*)["\']',
                        lambda mm: 'class="' + mm.group(1).strip() + ' trfmc-vxp"',
                        body, count=1, flags=re.I)
    else:
        new_body="<body class=\"trfmc-vxp\"" + attrs + ">"
    return s[:m.start()] + new_body + s[m.end():]

for p in pages:
    url=p.get("url","")
    cls=p.get("class","")
    if cls!="leaf_operational_candidate":
        skipped.append((url,"not_leaf"))
        continue
    if url in protected:
        skipped.append((url,"protected"))
        continue
    if not url.endswith(".html"):
        skipped.append((url,"not_html"))
        continue

    f=public/url.lstrip("/")
    if not f.exists():
        missing.append(url)
        continue

    s=f.read_text(errors="ignore")
    original=s

    if css_href not in s:
        if re.search(r"</head>", s, flags=re.I):
            s=re.sub(r"</head>", f'<link rel="stylesheet" href="{css_href}">\n</head>', s, count=1, flags=re.I)
        else:
            skipped.append((url,"no_head"))
            continue

    if js_src not in s:
        if re.search(r"</body>", s, flags=re.I):
            s=re.sub(r"</body>", f'<script src="{js_src}"></script>\n</body>', s, count=1, flags=re.I)
        else:
            s += f'\n<script src="{js_src}"></script>\n'

    s=inject_body_class(s)

    if s != original:
        f.write_text(s)
        patched.append(url)

(out/"patched_pages.tsv").write_text("url\n" + "\n".join(patched) + "\n")
(out/"skipped_pages.tsv").write_text("url\treason\n" + "\n".join(f"{u}\t{r}" for u,r in skipped) + "\n")
(out/"missing_pages.txt").write_text("\n".join(missing) + "\n")

print(json.dumps({
    "patched": len(patched),
    "skipped": len(skipped),
    "missing": len(missing)
}, indent=2))
PY

echo
echo "[5/8] HTTP quality gate completo su asset + pagine patchate"

{
  printf "url\tstatus\tbytes\n"

  for u in \
    /assets/trfmc_visual_xp/trfmc_visual_xp_v1.css \
    /assets/trfmc_visual_xp/trfmc_visual_xp_v1.js \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html \
    /trfmc_expansion_hub_v1.html \
    /trfmc_portal_registry_unified.json
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done

  tail -n +2 "$OUT/patched_pages.tsv" | while read -r u; do
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
echo "[6/8] Controllo no CDN/no iframe introdotti negli asset"

: > "$OUT/external_refs_assets.txt"
: > "$OUT/iframe_refs_assets.txt"
: > "$OUT/fused_forbidden_refs_assets.txt"

for f in "$CSS" "$JS"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs_assets.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs_assets.txt" 2>/dev/null || true
  grep -nEi 'MASTER FUSED|trfmc_master_fused|fallback shell' "$f" >> "$OUT/fused_forbidden_refs_assets.txt" 2>/dev/null || true
done

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

echo
echo "[7/8] Summary"

python3 - "$BASE" "$OUT" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

base=Path(sys.argv[1])
out=Path(sys.argv[2])

http=[]
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=3:
        http.append({"url":p[0],"status":p[1],"bytes":p[2]})

non200=sum(1 for x in http if x["status"]!="200")
external=sum(1 for x in (out/"external_refs_assets.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs_assets.txt").read_text(errors="ignore").splitlines() if x.strip())
fused=sum(1 for x in (out/"fused_forbidden_refs_assets.txt").read_text(errors="ignore").splitlines() if x.strip())

patched=max(0, len((out/"patched_pages.tsv").read_text(errors="ignore").splitlines())-1)
missing=sum(1 for x in (out/"missing_pages.txt").read_text(errors="ignore").splitlines() if x.strip())

sha={}
for line in (out/"sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k,v=line.strip().split("=",1)
        sha[k]=v

protected_ok=(
    sha.get("V6R3_SHA_BEFORE")==sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE")==sha.get("CONTROL_SHA_AFTER")
)
registry_unchanged=sha.get("REG_SHA_BEFORE")==sha.get("REG_SHA_AFTER")

data={
  "timestamp": datetime.now(timezone.utc).isoformat(),
  "visual_layer": "TRFMC_GLOBAL_VISUAL_XP_V1",
  "patched_leaf_pages": patched,
  "http_non_200": non200,
  "external_refs_assets": external,
  "iframe_refs_assets": iframe,
  "fused_forbidden_refs_assets": fused,
  "missing_pages": missing,
  "protected_v6r3_and_control_unchanged": protected_ok,
  "registry_unchanged": registry_unchanged,
  "injection_mode": "css_js_only_no_new_nav_no_iframe",
  "disable_switch": "localStorage.TRFMC_VXP='off'",
  "result": "PASS" if patched>0 and non200==0 and external==0 and iframe==0 and fused==0 and missing==0 and protected_ok and registry_unchanged else "WARN",
  "policy": "Global visual layer applied only to leaf pages. V6R3, Control Room and registry unchanged."
}

(out/"summary.json").write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=2,ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[8/8] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_GLOBAL_VISUAL_XP_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_visual_xp \
    frontend/public \
    runtime/quality/latest_global_visual_xp_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv" | sed -n '1,80p'
echo
echo "Pagine patchate:"
cat "$OUT/patched_pages.tsv" | sed -n '1,80p'
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_expansion_hub_v1.html"
echo "http://127.0.0.1:5173/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html"
echo "============================================================"
