#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
ASSETS="$PUBLIC/assets"
INDEX="$FRONT/index.html"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V51R6_BALANCED_LAYOUT_CALIBRATION_$TS"

mkdir -p "$OUT" "$ASSETS"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_v51r6.log"
HTTP="$OUT/http.tsv"

echo "============================================================"
echo "TRFMC_V51R6_BALANCED_LAYOUT_CALIBRATION"
echo "Balanced cockpit sizing · remove V51R5 emergency overscale"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$INDEX" ]; then
  echo "ERRORE: index.html non trovato: $INDEX"
  exit 1
fi

cp -a "$INDEX" "$OUT/index.before_v51r6_$TS.html"

echo
echo "=== 1) RIMOZIONE PATCH TROPPO AGGRESSIVE ==="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

idx = Path(sys.argv[1])
text = idx.read_text(encoding="utf-8", errors="replace")
before = text

patterns = [
    r'\s*<link[^>]+trfmc_emergency_layout_rescue_v51r5\.css[^>]*>\s*',
    r'\s*<script[^>]+trfmc_emergency_layout_rescue_v51r5\.js[^>]*></script>\s*',
    r'\s*<link[^>]+trfmc_layout_proportions_repair_v51r4\.css[^>]*>\s*',
    r'\s*<script[^>]+trfmc_layout_proportions_repair_v51r4\.js[^>]*></script>\s*',
    r'\s*<link[^>]+trfmc_engineering_completeness_matrix_v51r3\.css[^>]*>\s*',
    r'\s*<script[^>]+trfmc_engineering_completeness_matrix_v51r3\.js[^>]*></script>\s*',
]

for pat in patterns:
    text = re.sub(pat, "\n", text, flags=re.I)

idx.write_text(text, encoding="utf-8")
print("REMOVED_OLD_LAYOUT_PATCHES=" + str(before != text))
PY

cat > "$ASSETS/trfmc_balanced_layout_calibration_v51r6.css" <<'CSS'
/*
  TRFMC V51R6 - Balanced Layout Calibration
  Obiettivo: dimensionamento corretto, non miniaturizzato e non sovradimensionato.
*/

:root {
  --v51r6-page-max: 1560px;
  --v51r6-page-min: 1180px;
  --v51r6-page-pad: clamp(26px, 3vw, 58px);
  --v51r6-gap: 18px;
  --v51r6-sidebar: 276px;
  --v51r6-radius: 18px;

  --v51r6-h1: clamp(38px, 2.55vw, 52px);
  --v51r6-h2: clamp(26px, 1.9vw, 38px);
  --v51r6-h3: clamp(17px, 1.08vw, 22px);
  --v51r6-body: clamp(13px, .74vw, 15px);
  --v51r6-small: clamp(11px, .62vw, 13px);

  --v51r6-border: rgba(103, 232, 249, .25);
  --v51r6-border-soft: rgba(103, 232, 249, .16);
  --v51r6-panel: rgba(5, 16, 31, .86);
  --v51r6-panel-strong: rgba(8, 22, 40, .92);
  --v51r6-text: #e8f7ff;
  --v51r6-muted: #9fb8ca;
  --v51r6-cyan: #67e8f9;
  --v51r6-green: #86efac;
}

html,
body,
#root {
  width: 100%;
  min-height: 100%;
  margin: 0;
  overflow-x: hidden !important;
}

body.trfmc-v51r6-balanced {
  background:
    radial-gradient(circle at 18% 0%, rgba(8, 145, 178, .13), transparent 31%),
    radial-gradient(circle at 82% 12%, rgba(14, 116, 144, .10), transparent 32%),
    linear-gradient(180deg, #020812 0%, #020617 52%, #00040a 100%) !important;
  color: var(--v51r6-text);
  font-size: var(--v51r6-body);
}

body.trfmc-v51r6-balanced *,
body.trfmc-v51r6-balanced *::before,
body.trfmc-v51r6-balanced *::after {
  box-sizing: border-box;
}

/* Reset delle patch precedenti */
body.trfmc-v51r6-balanced {
  --v51r5-page-max: var(--v51r6-page-max);
  --v51r5-sidebar: var(--v51r6-sidebar);
}

body.trfmc-v51r6-balanced #trfmc-v51r3-matrix-host,
body.trfmc-v51r6-balanced #trfmc-v51r3-mini {
  display: none !important;
  visibility: hidden !important;
}

/* Shell principale: misura corretta su 1920px */
body.trfmc-v51r6-balanced :where(
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
  width: min(var(--v51r6-page-max), calc(100vw - 2 * var(--v51r6-page-pad))) !important;
  max-width: min(var(--v51r6-page-max), calc(100vw - 2 * var(--v51r6-page-pad))) !important;
  margin-left: auto !important;
  margin-right: auto !important;
}

/* Evita che JS vecchi abbiano lasciato width mostruose inline */
body.trfmc-v51r6-balanced [style*="1900px"],
body.trfmc-v51r6-balanced [style*="1836px"],
body.trfmc-v51r6-balanced [style*="1800px"] {
  width: min(var(--v51r6-page-max), calc(100vw - 2 * var(--v51r6-page-pad))) !important;
  max-width: min(var(--v51r6-page-max), calc(100vw - 2 * var(--v51r6-page-pad))) !important;
}

/* Sidebar corretta */
body.trfmc-v51r6-balanced :where(
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
  width: var(--v51r6-sidebar) !important;
  max-width: var(--v51r6-sidebar) !important;
  min-width: var(--v51r6-sidebar) !important;
  flex: 0 0 var(--v51r6-sidebar) !important;
  overflow-x: hidden !important;
  overflow-y: auto !important;
}

/* Menu laterali leggibili ma non enormi */
body.trfmc-v51r6-balanced :where(
  aside a,
  aside button,
  [class*="sidebar" i] a,
  [class*="sidebar" i] button,
  [class*="side-menu" i] a,
  [class*="side-menu" i] button,
  [class*="left-nav" i] a,
  [class*="left-nav" i] button
) {
  min-height: 36px !important;
  padding: 8px 10px !important;
  border-radius: 10px !important;
  font-size: var(--v51r6-small) !important;
  line-height: 1.18 !important;
  white-space: normal !important;
  overflow-wrap: anywhere !important;
}

/* Hero/header: titolo forte ma non invasivo */
body.trfmc-v51r6-balanced h1 {
  font-size: var(--v51r6-h1) !important;
  line-height: .98 !important;
  letter-spacing: -.048em !important;
}

body.trfmc-v51r6-balanced h2 {
  font-size: var(--v51r6-h2) !important;
  line-height: 1.06 !important;
  letter-spacing: -.034em !important;
}

body.trfmc-v51r6-balanced h3 {
  font-size: var(--v51r6-h3) !important;
  line-height: 1.16 !important;
}

/* Elementi di testo */
body.trfmc-v51r6-balanced p,
body.trfmc-v51r6-balanced li,
body.trfmc-v51r6-balanced dd,
body.trfmc-v51r6-balanced td,
body.trfmc-v51r6-balanced th,
body.trfmc-v51r6-balanced label,
body.trfmc-v51r6-balanced input,
body.trfmc-v51r6-balanced button {
  line-height: 1.42 !important;
}

/* Card/panel: proporzioni meno gonfie */
body.trfmc-v51r6-balanced :where(
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
  min-width: 0 !important;
  overflow: hidden;
  border-radius: var(--v51r6-radius) !important;
}

/* Grid: spazio corretto */
body.trfmc-v51r6-balanced :where(
  .grid,
  .Grid,
  .cards,
  .Cards,
  [class*="grid" i],
  [class*="cards" i]
) {
  gap: var(--v51r6-gap) !important;
}

/* Header principale meno alto */
body.trfmc-v51r6-balanced :where(
  header,
  [class*="header" i],
  [class*="hero" i]
) {
  min-width: 0;
}

/* Non far esplodere tabelle, canvas, SVG */
body.trfmc-v51r6-balanced img,
body.trfmc-v51r6-balanced svg,
body.trfmc-v51r6-balanced canvas,
body.trfmc-v51r6-balanced video {
  max-width: 100%;
}

body.trfmc-v51r6-balanced table,
body.trfmc-v51r6-balanced pre {
  max-width: 100%;
  overflow-x: auto;
}

/* Responsive */
@media (max-width: 1280px) {
  :root {
    --v51r6-page-max: 1180px;
    --v51r6-sidebar: 250px;
  }
}

@media (max-width: 980px) {
  :root {
    --v51r6-page-pad: 16px;
    --v51r6-sidebar: 100%;
  }

  body.trfmc-v51r6-balanced :where(
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
    width: calc(100vw - 32px) !important;
    max-width: calc(100vw - 32px) !important;
  }

  body.trfmc-v51r6-balanced :where(
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

cat > "$ASSETS/trfmc_balanced_layout_calibration_v51r6.js" <<'JS'
(() => {
  const VERSION = "V51R6";

  function boot() {
    document.documentElement.dataset.trfmcV51r6 = "balanced-layout-calibration";
    if (!document.body) return;

    document.body.classList.remove("trfmc-v51r5-rescue-active");
    document.body.classList.add("trfmc-v51r6-balanced");
    document.body.dataset.trfmcLayoutCalibration = VERSION;

    removeOldBlocks();
    removeOldInlineOverscale();
    setBalancedWidths();
    markMenuTitles();
    markReady();
  }

  function removeOldBlocks() {
    ["trfmc-v51r3-matrix-host", "trfmc-v51r3-mini"].forEach((id) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.style.display = "none";
      el.style.visibility = "hidden";
      el.style.pointerEvents = "none";
      el.setAttribute("aria-hidden", "true");
    });
  }

  function balancedWidth() {
    const vw = window.innerWidth || 1920;
    if (vw >= 1800) return 1560;
    if (vw >= 1600) return 1480;
    if (vw >= 1400) return 1320;
    return Math.max(980, vw - 64);
  }

  function removeOldInlineOverscale() {
    document.querySelectorAll("[style]").forEach((el) => {
      const s = el.getAttribute("style") || "";
      if (/width\s*:\s*(18|19)\d\dpx/i.test(s) || /max-width\s*:\s*(18|19)\d\dpx/i.test(s)) {
        el.style.width = "";
        el.style.maxWidth = "";
      }
      if (/transform\s*:\s*scale/i.test(s)) {
        el.style.transform = "";
      }
    });
  }

  function setBalancedWidths() {
    const w = balancedWidth();

    const selectors = [
      "#root",
      "main",
      ".app",
      ".App",
      ".shell",
      ".Shell",
      ".layout",
      ".Layout",
      ".workspace",
      ".Workspace",
      ".dashboard",
      ".Dashboard",
      ".orchestrator",
      ".Orchestrator",
      "[class*='layout' i]",
      "[class*='workspace' i]",
      "[class*='dashboard' i]",
      "[class*='orchestrator' i]",
      "[class*='mission' i]",
      "[class*='control' i]"
    ].join(",");

    document.querySelectorAll(selectors).forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (!rect.width) return;

      if (window.innerWidth >= 1400) {
        if (rect.width < 1120 || rect.width > w + 80) {
          el.style.width = w + "px";
          el.style.maxWidth = w + "px";
          el.style.marginLeft = "auto";
          el.style.marginRight = "auto";
        }
      }
    });
  }

  function markMenuTitles() {
    document.querySelectorAll("aside a, aside button, nav a, nav button, [role='navigation'] a, [role='navigation'] button").forEach((el) => {
      const text = (el.textContent || "").trim();
      if (text.length > 32) el.title = text;
    });
  }

  function markReady() {
    let marker = document.getElementById("trfmc-v51r6-balanced-layout-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r6-balanced-layout-marker";
      marker.name = "trfmc-v51r6-balanced-layout";
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
  window.addEventListener("resize", () => setTimeout(boot, 160));

  setTimeout(boot, 400);
  setTimeout(boot, 1200);
})();
JS

echo
echo "=== 2) INIEZIONE V51R6 ==="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import sys

idx = Path(sys.argv[1])
text = idx.read_text(encoding="utf-8", errors="replace")

css = '<link rel="stylesheet" href="/assets/trfmc_balanced_layout_calibration_v51r6.css" data-trfmc-v51r6="balanced-layout-calibration">'
js = '<script type="module" src="/assets/trfmc_balanced_layout_calibration_v51r6.js" data-trfmc-v51r6="balanced-layout-calibration"></script>'

changed = False

if "trfmc_balanced_layout_calibration_v51r6.css" not in text:
    if "</head>" in text:
        text = text.replace("</head>", f"  {css}\n</head>", 1)
    else:
        text = css + "\n" + text
    changed = True

if "trfmc_balanced_layout_calibration_v51r6.js" not in text:
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
  cp -a "$OUT/index.before_v51r6_$TS.html" "$INDEX"
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
check_url "http://127.0.0.1:5173/assets/trfmc_balanced_layout_calibration_v51r6.css"
check_url "http://127.0.0.1:5173/assets/trfmc_balanced_layout_calibration_v51r6.js"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_V51R6_BALANCED_LAYOUT_CALIBRATION",
  "frontend_mutation": true,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "removed_v51r5_overscale": true,
  "target_width_1920": "1560px",
  "target_sidebar": "276px",
  "target_h1": "38-52px",
  "base": "$BASE",
  "out": "$OUT",
  "index_backup": "$OUT/index.before_v51r6_$TS.html",
  "layout_css": "$ASSETS/trfmc_balanced_layout_calibration_v51r6.css",
  "layout_js": "$ASSETS/trfmc_balanced_layout_calibration_v51r6.js",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v51r6_balanced_layout_calibration"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_V51R6_BALANCED_LAYOUT_CALIBRATION COMPLETATO"
echo "Output: $OUT"
echo "Apri/refresh: http://127.0.0.1:5173/#full-engineering-stack"
echo "============================================================"
