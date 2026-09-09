#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
ASSETS="$PUBLIC/assets"
INDEX="$FRONT/index.html"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V51R5_EMERGENCY_LAYOUT_RESCUE_$TS"

mkdir -p "$OUT" "$ASSETS"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_v51r5.log"
HTTP="$OUT/http.tsv"

echo "============================================================"
echo "TRFMC_V51R5_EMERGENCY_LAYOUT_RESCUE"
echo "Emergency visual/layout rescue · removes bad overlays · frontend only"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$INDEX" ]; then
  echo "ERRORE: index.html non trovato: $INDEX"
  exit 1
fi

cp -a "$INDEX" "$OUT/index.before_v51r5_$TS.html"

echo
echo "=== 1) RIMOZIONE INNESTI V51R3 / V51R4 DA index.html ==="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

idx = Path(sys.argv[1])
text = idx.read_text(encoding="utf-8", errors="replace")

before = text

remove_patterns = [
    r'\s*<link[^>]+trfmc_engineering_completeness_matrix_v51r3\.css[^>]*>\s*',
    r'\s*<script[^>]+trfmc_engineering_completeness_matrix_v51r3\.js[^>]*></script>\s*',
    r'\s*<link[^>]+trfmc_layout_proportions_repair_v51r4\.css[^>]*>\s*',
    r'\s*<script[^>]+trfmc_layout_proportions_repair_v51r4\.js[^>]*></script>\s*',
]

for pat in remove_patterns:
    text = re.sub(pat, "\n", text, flags=re.I)

idx.write_text(text, encoding="utf-8")

print("REMOVED_BAD_OVERLAYS=" + str(before != text))
PY

cat > "$ASSETS/trfmc_emergency_layout_rescue_v51r5.css" <<'CSS'
/*
  TRFMC V51R5 - Emergency Layout Rescue
  Obiettivo:
  - eliminare effetto pagina miniaturizzata;
  - usare davvero il monitor largo;
  - correggere sidebar/menu laterali;
  - impedire blocchi appendice sotto il portale;
  - mantenere entrypoint 127.0.0.1:5173.
*/

:root {
  --v51r5-page-max: 1900px;
  --v51r5-page-pad: clamp(18px, 2.2vw, 42px);
  --v51r5-gap: clamp(14px, 1.4vw, 26px);
  --v51r5-sidebar: clamp(260px, 18vw, 340px);
  --v51r5-panel: rgba(5, 16, 31, .88);
  --v51r5-panel-2: rgba(8, 24, 44, .92);
  --v51r5-border: rgba(103, 232, 249, .26);
  --v51r5-border-strong: rgba(103, 232, 249, .52);
  --v51r5-cyan: #67e8f9;
  --v51r5-green: #86efac;
  --v51r5-text: #e8f7ff;
  --v51r5-muted: #9db6c9;
}

html,
body,
#root {
  width: 100%;
  min-height: 100%;
  margin: 0;
  overflow-x: hidden !important;
}

body {
  background:
    radial-gradient(circle at 18% 0%, rgba(8, 145, 178, .18), transparent 32%),
    radial-gradient(circle at 86% 12%, rgba(14, 116, 144, .14), transparent 34%),
    linear-gradient(180deg, #020812 0%, #020617 48%, #00040a 100%) !important;
  color: var(--v51r5-text);
}

body *,
body *::before,
body *::after {
  box-sizing: border-box;
}

body.trfmc-v51r5-rescue-active {
  font-size: clamp(14px, .78vw, 17px);
}

/* 1. Il portale non deve più sembrare una striscia stretta al centro */
body.trfmc-v51r5-rescue-active :where(
  #root,
  main,
  .app,
  .App,
  .shell,
  .Shell,
  .layout,
  .Layout,
  .workspace,
  .Workspace,
  .dashboard,
  .Dashboard,
  .orchestrator,
  .Orchestrator,
  [class*="shell" i],
  [class*="layout" i],
  [class*="workspace" i],
  [class*="dashboard" i],
  [class*="orchestrator" i],
  [class*="mission" i],
  [class*="control" i]
) {
  max-width: min(var(--v51r5-page-max), calc(100vw - 2 * var(--v51r5-page-pad))) !important;
  width: min(var(--v51r5-page-max), calc(100vw - 2 * var(--v51r5-page-pad))) !important;
  margin-left: auto !important;
  margin-right: auto !important;
}

/* 2. Se qualche componente aveva width hardcoded ridicola, lo forziamo */
body.trfmc-v51r5-rescue-active :where(
  [style*="width: 900px"],
  [style*="width:900px"],
  [style*="width: 960px"],
  [style*="width:960px"],
  [style*="width: 1000px"],
  [style*="width:1000px"],
  [style*="max-width: 900px"],
  [style*="max-width:900px"],
  [style*="max-width: 960px"],
  [style*="max-width:960px"],
  [style*="max-width: 1000px"],
  [style*="max-width:1000px"]
) {
  width: 100% !important;
  max-width: 100% !important;
}

/* 3. Shell principale: più larga, meno giocattolo */
body.trfmc-v51r5-rescue-active :where(
  section,
  article,
  header,
  footer,
  div,
  aside,
  nav
) {
  min-width: 0;
}

body.trfmc-v51r5-rescue-active :where(
  .panel,
  .Panel,
  .card,
  .Card,
  .tile,
  .Tile,
  [class*="panel" i],
  [class*="card" i],
  [class*="tile" i]
) {
  border-color: var(--v51r5-border) !important;
  min-width: 0 !important;
  overflow: hidden;
}

/* 4. Side menu: larghezza reale, non colonnina compressa */
body.trfmc-v51r5-rescue-active :where(
  aside,
  .sidebar,
  .Sidebar,
  .side-menu,
  .SideMenu,
  .left-menu,
  .LeftMenu,
  .left-nav,
  .LeftNav,
  [class*="sidebar" i],
  [class*="side-menu" i],
  [class*="left-nav" i]
) {
  width: var(--v51r5-sidebar) !important;
  max-width: var(--v51r5-sidebar) !important;
  min-width: var(--v51r5-sidebar) !important;
  flex: 0 0 var(--v51r5-sidebar) !important;
  overflow-x: hidden !important;
  overflow-y: auto !important;
}

/* 5. Link menu leggibili */
body.trfmc-v51r5-rescue-active :where(
  aside a,
  aside button,
  nav a,
  nav button,
  [class*="sidebar" i] a,
  [class*="sidebar" i] button,
  [class*="side-menu" i] a,
  [class*="side-menu" i] button,
  [class*="left-nav" i] a,
  [class*="left-nav" i] button
) {
  min-height: 38px !important;
  padding: 9px 11px !important;
  border-radius: 10px !important;
  line-height: 1.18 !important;
  white-space: normal !important;
  overflow-wrap: anywhere !important;
}

/* 6. Se esiste un layout con sidebar + contenuto, gli diamo proporzioni serie */
body.trfmc-v51r5-rescue-active :where(
  [class*="layout" i],
  [class*="workspace" i],
  [class*="orchestrator" i]
) {
  gap: var(--v51r5-gap) !important;
}

/* 7. Griglie più professionali */
body.trfmc-v51r5-rescue-active :where(
  .grid,
  .Grid,
  .cards,
  .Cards,
  [class*="grid" i],
  [class*="cards" i]
) {
  gap: var(--v51r5-gap) !important;
}

/* 8. Tipografia: basta microscopica */
body.trfmc-v51r5-rescue-active h1 {
  font-size: clamp(34px, 3.4vw, 72px) !important;
  line-height: .96 !important;
  letter-spacing: -.055em !important;
}

body.trfmc-v51r5-rescue-active h2 {
  font-size: clamp(24px, 2.2vw, 44px) !important;
  line-height: 1.04 !important;
  letter-spacing: -.038em !important;
}

body.trfmc-v51r5-rescue-active h3 {
  font-size: clamp(18px, 1.28vw, 28px) !important;
  line-height: 1.14 !important;
}

body.trfmc-v51r5-rescue-active p,
body.trfmc-v51r5-rescue-active li,
body.trfmc-v51r5-rescue-active dd,
body.trfmc-v51r5-rescue-active td,
body.trfmc-v51r5-rescue-active th {
  line-height: 1.48 !important;
}

/* 9. Rimozione completa appendici grafiche sbagliate V51R3 */
body.trfmc-v51r5-rescue-active #trfmc-v51r3-matrix-host,
body.trfmc-v51r5-rescue-active #trfmc-v51r3-mini {
  display: none !important;
  visibility: hidden !important;
  pointer-events: none !important;
}

/* 10. Immagini/canvas/tabelle non devono rompere la pagina */
body.trfmc-v51r5-rescue-active img,
body.trfmc-v51r5-rescue-active svg,
body.trfmc-v51r5-rescue-active canvas,
body.trfmc-v51r5-rescue-active video {
  max-width: 100%;
}

body.trfmc-v51r5-rescue-active table,
body.trfmc-v51r5-rescue-active pre {
  max-width: 100%;
  overflow-x: auto;
}

/* 11. Top block: più respiro */
body.trfmc-v51r5-rescue-active :where(
  header,
  [class*="header" i],
  [class*="hero" i],
  [class*="top" i]
) {
  min-width: 0;
}

/* 12. Anti-miniatura: se la UI è stata scalata internamente */
body.trfmc-v51r5-rescue-active [style*="transform: scale"] {
  transform: none !important;
}

/* 13. Mobile/tablet */
@media (max-width: 1100px) {
  :root {
    --v51r5-sidebar: 100%;
  }

  body.trfmc-v51r5-rescue-active :where(
    #root,
    main,
    .app,
    .App,
    .shell,
    .Shell,
    .layout,
    .Layout,
    .workspace,
    .Workspace,
    .dashboard,
    .Dashboard,
    [class*="layout" i],
    [class*="workspace" i],
    [class*="dashboard" i]
  ) {
    width: calc(100vw - 24px) !important;
    max-width: calc(100vw - 24px) !important;
  }

  body.trfmc-v51r5-rescue-active :where(
    aside,
    .sidebar,
    .Sidebar,
    [class*="sidebar" i],
    [class*="side-menu" i],
    [class*="left-nav" i]
  ) {
    width: 100% !important;
    min-width: 0 !important;
    max-width: 100% !important;
    flex-basis: auto !important;
    position: relative !important;
  }
}
CSS

cat > "$ASSETS/trfmc_emergency_layout_rescue_v51r5.js" <<'JS'
(() => {
  const VERSION = "V51R5";

  function boot() {
    document.documentElement.dataset.trfmcV51r5 = "emergency-layout-rescue";

    if (!document.body) return;

    document.body.classList.add("trfmc-v51r5-rescue-active");
    document.body.dataset.trfmcLayoutRescue = VERSION;

    removeBadInjectedBlocks();
    removeInlineScale();
    widenHardcodedShells();
    tagLongMenuItems();
    markReady();
  }

  function removeBadInjectedBlocks() {
    const bad = [
      document.getElementById("trfmc-v51r3-matrix-host"),
      document.getElementById("trfmc-v51r3-mini")
    ];

    bad.forEach((el) => {
      if (!el) return;
      el.setAttribute("aria-hidden", "true");
      el.style.display = "none";
      el.style.visibility = "hidden";
      el.style.pointerEvents = "none";
    });
  }

  function removeInlineScale() {
    document.querySelectorAll("[style]").forEach((el) => {
      const s = el.getAttribute("style") || "";
      if (/transform\s*:\s*scale/i.test(s)) {
        el.style.transform = "none";
      }
    });
  }

  function widenHardcodedShells() {
    const vw = window.innerWidth || 1920;
    const target = Math.min(1900, Math.max(1320, vw - 84));

    const candidates = document.querySelectorAll(
      "main, .app, .App, .shell, .Shell, .layout, .Layout, .workspace, .Workspace, .dashboard, .Dashboard, [class*='layout' i], [class*='workspace' i], [class*='dashboard' i], [class*='mission' i], [class*='control' i]"
    );

    candidates.forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (!rect.width) return;

      if (vw >= 1400 && rect.width < 1150) {
        el.style.maxWidth = target + "px";
        el.style.width = target + "px";
        el.style.marginLeft = "auto";
        el.style.marginRight = "auto";
      }
    });
  }

  function tagLongMenuItems() {
    const items = document.querySelectorAll("aside a, aside button, nav a, nav button, [role='navigation'] a, [role='navigation'] button");
    items.forEach((el) => {
      const t = (el.textContent || "").trim();
      if (t.length > 34) el.title = t;
    });
  }

  function markReady() {
    let marker = document.getElementById("trfmc-v51r5-layout-rescue-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r5-layout-rescue-marker";
      marker.name = "trfmc-v51r5-layout-rescue";
      marker.content = "active";
      document.head.appendChild(marker);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.addEventListener("hashchange", () => setTimeout(boot, 100));
  window.addEventListener("resize", () => setTimeout(boot, 150));

  setTimeout(boot, 400);
  setTimeout(boot, 1200);
  setTimeout(boot, 2200);
})();
JS

echo
echo "=== 2) INIEZIONE V51R5 IN index.html ==="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import sys

idx = Path(sys.argv[1])
text = idx.read_text(encoding="utf-8", errors="replace")

css = '<link rel="stylesheet" href="/assets/trfmc_emergency_layout_rescue_v51r5.css" data-trfmc-v51r5="emergency-layout-rescue">'
js = '<script type="module" src="/assets/trfmc_emergency_layout_rescue_v51r5.js" data-trfmc-v51r5="emergency-layout-rescue"></script>'

changed = False

if "trfmc_emergency_layout_rescue_v51r5.css" not in text:
    if "</head>" in text:
        text = text.replace("</head>", f"  {css}\n</head>", 1)
    else:
        text = css + "\n" + text
    changed = True

if "trfmc_emergency_layout_rescue_v51r5.js" not in text:
    if "</body>" in text:
        text = text.replace("</body>", f"  {js}\n</body>", 1)
    else:
        text = text + "\n" + js + "\n"
    changed = True

idx.write_text(text, encoding="utf-8")
print("INDEX_CHANGED=" + str(changed))
PY

echo
echo "=== 3) BUILD VALIDATION ==="

BUILD_RESULT="PASS"
(
  cd "$FRONT"
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: ripristino index.html precedente"
  cp -a "$OUT/index.before_v51r5_$TS.html" "$INDEX"
  BUILD_RESULT="FAIL_ROLLBACK_INDEX_RESTORED"
fi

tail -n 80 "$BUILDLOG" || true

echo
echo "=== 4) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 5 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  rm -f "$tmp"
  printf "%s\t%s\t%s\n" "$url" "$code" "$bytes" | tee -a "$HTTP"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#command-center"
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:5173/assets/trfmc_emergency_layout_rescue_v51r5.css"
check_url "http://127.0.0.1:5173/assets/trfmc_emergency_layout_rescue_v51r5.js"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_V51R5_EMERGENCY_LAYOUT_RESCUE",
  "frontend_mutation": true,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "removed_v51r3_v51r4_overlays": true,
  "base": "$BASE",
  "out": "$OUT",
  "index_backup": "$OUT/index.before_v51r5_$TS.html",
  "layout_css": "$ASSETS/trfmc_emergency_layout_rescue_v51r5.css",
  "layout_js": "$ASSETS/trfmc_emergency_layout_rescue_v51r5.js",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v51r5_emergency_layout_rescue"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_V51R5_EMERGENCY_LAYOUT_RESCUE COMPLETATO"
echo "Output: $OUT"
echo "Apri/refresh: http://127.0.0.1:5173/#full-engineering-stack"
echo "============================================================"
