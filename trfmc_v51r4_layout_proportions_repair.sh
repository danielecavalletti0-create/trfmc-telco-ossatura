#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
ASSETS="$PUBLIC/assets"
INDEX="$FRONT/index.html"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V51R4_LAYOUT_PROPORTIONS_REPAIR_$TS"

mkdir -p "$OUT" "$ASSETS"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_v51r4.log"
HTTP="$OUT/http.tsv"
SCREENSHOT="$OUT/v51r4_full_engineering_stack_1920.png"

echo "============================================================"
echo "TRFMC_V51R4_LAYOUT_PROPORTIONS_REPAIR"
echo "Frontend-only layout hardening · sidebar/menu/proportion repair"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$INDEX" ]; then
  echo "ERRORE: index.html non trovato: $INDEX"
  exit 1
fi

cp -a "$INDEX" "$OUT/index.before_v51r4_$TS.html"

cat > "$ASSETS/trfmc_layout_proportions_repair_v51r4.css" <<'CSS'
/*
  TRFMC V51R4 - Layout Proportions Repair
  Scope: frontend visual governance only.
  No backend / nginx / systemd mutation.
*/

:root {
  --trfmc-v51r4-page-max: 1680px;
  --trfmc-v51r4-readable-max: 1320px;
  --trfmc-v51r4-sidebar: clamp(220px, 17vw, 304px);
  --trfmc-v51r4-rail: clamp(68px, 5vw, 92px);
  --trfmc-v51r4-gap: clamp(12px, 1.25vw, 22px);
  --trfmc-v51r4-pad: clamp(14px, 1.7vw, 28px);
  --trfmc-v51r4-radius: 18px;
  --trfmc-v51r4-border: rgba(125, 211, 252, .18);
  --trfmc-v51r4-panel: rgba(6, 14, 28, .82);
  --trfmc-v51r4-panel-strong: rgba(8, 20, 38, .94);
  --trfmc-v51r4-text: #e6f4ff;
  --trfmc-v51r4-muted: #9bb2c7;
  --trfmc-v51r4-cyan: #67e8f9;
}

html,
body,
#root {
  width: 100%;
  min-height: 100%;
  margin: 0;
  overflow-x: hidden !important;
}

html[data-trfmc-v51r4-layout="on"] {
  background: #020617;
}

body.trfmc-v51r4-layout-normalized {
  min-width: 0;
  color: var(--trfmc-v51r4-text);
  background:
    radial-gradient(circle at 20% 0%, rgba(14, 165, 233, .13), transparent 34%),
    radial-gradient(circle at 82% 12%, rgba(124, 58, 237, .12), transparent 32%),
    linear-gradient(180deg, #020617, #030712 54%, #020617);
}

/* Box model hardening */
body.trfmc-v51r4-layout-normalized *,
body.trfmc-v51r4-layout-normalized *::before,
body.trfmc-v51r4-layout-normalized *::after {
  box-sizing: border-box;
}

/* Main shell width: stop huge stretched / broken proportions */
body.trfmc-v51r4-layout-normalized :where(
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
  [class*="layout" i],
  [class*="workspace" i],
  [class*="dashboard" i],
  [class*="orchestrator" i]
) {
  max-width: min(calc(100vw - 32px), var(--trfmc-v51r4-page-max));
  margin-left: auto;
  margin-right: auto;
}

/* Prevent content from exploding horizontally */
body.trfmc-v51r4-layout-normalized :where(section, article, header, footer, div, main, aside, nav) {
  min-width: 0;
}

body.trfmc-v51r4-layout-normalized :where(img, svg, canvas, video) {
  max-width: 100%;
}

body.trfmc-v51r4-layout-normalized :where(pre, code, table) {
  max-width: 100%;
}

body.trfmc-v51r4-layout-normalized :where(pre, table) {
  overflow-x: auto;
}

/* Top navigation/menu repair */
body.trfmc-v51r4-layout-normalized :where(
  header nav,
  .topbar,
  .Topbar,
  .navbar,
  .Navbar,
  .nav,
  .Nav,
  [class*="topbar" i],
  [class*="navbar" i]
) {
  max-width: min(calc(100vw - 32px), var(--trfmc-v51r4-page-max));
  margin-left: auto;
  margin-right: auto;
  min-height: auto;
}

body.trfmc-v51r4-layout-normalized :where(
  nav,
  [role="navigation"],
  [class*="menu" i],
  [class*="nav" i]
) {
  min-width: 0;
}

body.trfmc-v51r4-layout-normalized :where(
  nav a,
  nav button,
  [role="navigation"] a,
  [role="navigation"] button,
  [class*="menu" i] a,
  [class*="menu" i] button
) {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Lateral menu / sidebar repair */
body.trfmc-v51r4-layout-normalized :where(
  aside,
  .sidebar,
  .Sidebar,
  .sideBar,
  .SideBar,
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
  width: var(--trfmc-v51r4-sidebar);
  max-width: var(--trfmc-v51r4-sidebar);
  flex: 0 0 var(--trfmc-v51r4-sidebar);
  min-width: 0 !important;
  overflow-x: hidden;
  overflow-y: auto;
  border-color: var(--trfmc-v51r4-border);
}

/* Side menu links: no giant ugly wrapping */
body.trfmc-v51r4-layout-normalized :where(
  aside a,
  aside button,
  [class*="sidebar" i] a,
  [class*="sidebar" i] button,
  [class*="side-menu" i] a,
  [class*="side-menu" i] button,
  [class*="left-nav" i] a,
  [class*="left-nav" i] button
) {
  width: 100%;
  min-height: 36px;
  line-height: 1.18;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-radius: 10px;
  text-align: left;
  white-space: normal;
  word-break: normal;
  overflow-wrap: anywhere;
}

/* Dashboard/card grids: stable enterprise proportions */
body.trfmc-v51r4-layout-normalized :where(
  .grid,
  .Grid,
  .cards,
  .Cards,
  .panel-grid,
  .PanelGrid,
  [class*="grid" i],
  [class*="cards" i]
) {
  gap: var(--trfmc-v51r4-gap);
}

body.trfmc-v51r4-layout-normalized :where(
  .card,
  .Card,
  .panel,
  .Panel,
  .tile,
  .Tile,
  [class*="card" i],
  [class*="panel" i],
  [class*="tile" i]
) {
  min-width: 0;
  overflow: hidden;
  border-radius: min(var(--trfmc-v51r4-radius), 22px);
}

/* Typography: reduce "screaming oversized" effect */
body.trfmc-v51r4-layout-normalized :where(h1) {
  font-size: clamp(30px, 3.2vw, 58px);
  line-height: .98;
  letter-spacing: -0.045em;
}

body.trfmc-v51r4-layout-normalized :where(h2) {
  font-size: clamp(22px, 2.05vw, 36px);
  line-height: 1.08;
  letter-spacing: -0.028em;
}

body.trfmc-v51r4-layout-normalized :where(h3) {
  font-size: clamp(17px, 1.35vw, 24px);
  line-height: 1.16;
}

body.trfmc-v51r4-layout-normalized :where(p, li, dd, td, th) {
  line-height: 1.48;
}

/* V51R3 matrix repair: it was too intrusive as an appended body block */
body.trfmc-v51r4-layout-normalized #trfmc-v51r3-matrix-host {
  width: min(calc(100vw - 36px), 1500px) !important;
  max-width: min(calc(100vw - 36px), 1500px) !important;
  margin: 22px auto 52px auto !important;
  padding: 0 !important;
}

body.trfmc-v51r4-layout-normalized .trfmc-v51r3-header {
  grid-template-columns: minmax(0, 1.35fr) minmax(260px, .65fr) !important;
  gap: 18px !important;
  padding: 20px 22px 16px 22px !important;
}

body.trfmc-v51r4-layout-normalized .trfmc-v51r3-title {
  font-size: clamp(26px, 2.45vw, 40px) !important;
  line-height: 1.02 !important;
}

body.trfmc-v51r4-layout-normalized .trfmc-v51r3-grid {
  display: grid !important;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 390px), 1fr)) !important;
  gap: 14px !important;
  padding: 18px 22px 22px 22px !important;
}

body.trfmc-v51r4-layout-normalized .trfmc-v51r3-module {
  min-height: 0 !important;
  padding: 14px !important;
}

body.trfmc-v51r4-layout-normalized .trfmc-v51r3-kv {
  grid-template-columns: 112px minmax(0, 1fr) !important;
  gap: 7px 10px !important;
}

/* Suppress the bottom-right V51R3 floating box: visually noisy */
body.trfmc-v51r4-layout-normalized #trfmc-v51r3-mini,
body.trfmc-v51r4-layout-normalized .trfmc-v51r4-suppressed {
  display: none !important;
}

/* Generic overflow clamp added by JS */
body.trfmc-v51r4-layout-normalized .trfmc-v51r4-overflow-clamped {
  max-width: 100% !important;
  overflow-x: hidden !important;
}

body.trfmc-v51r4-layout-normalized .trfmc-v51r4-horizontal-scroll {
  max-width: 100% !important;
  overflow-x: auto !important;
}

/* Large desktop: strong proportions */
@media (min-width: 1280px) {
  body.trfmc-v51r4-layout-normalized :where(
    .grid,
    .Grid,
    .cards,
    .Cards,
    [class*="cards" i]
  ) {
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  }
}

/* Tablet */
@media (max-width: 1100px) {
  :root {
    --trfmc-v51r4-sidebar: min(280px, 34vw);
  }

  body.trfmc-v51r4-layout-normalized .trfmc-v51r3-header {
    grid-template-columns: 1fr !important;
  }
}

/* Mobile/small viewport: no broken sidebars */
@media (max-width: 820px) {
  :root {
    --trfmc-v51r4-sidebar: 100%;
  }

  body.trfmc-v51r4-layout-normalized :where(
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
    max-width: calc(100vw - 20px);
  }

  body.trfmc-v51r4-layout-normalized :where(
    aside,
    .sidebar,
    .Sidebar,
    [class*="sidebar" i],
    [class*="side-menu" i],
    [class*="left-nav" i]
  ) {
    position: relative !important;
    width: 100% !important;
    max-width: 100% !important;
    flex-basis: auto !important;
    max-height: none !important;
  }

  body.trfmc-v51r4-layout-normalized .trfmc-v51r3-kv {
    grid-template-columns: 1fr !important;
  }
}
CSS

cat > "$ASSETS/trfmc_layout_proportions_repair_v51r4.js" <<'JS'
(() => {
  const VERSION = "V51R4";

  function markRuntime() {
    document.documentElement.dataset.trfmcV51r4Layout = "on";
    if (document.body) {
      document.body.classList.add("trfmc-v51r4-layout-normalized");
      document.body.dataset.trfmcLayoutRepair = VERSION;
    }
  }

  function suppressNoisyV51R3Mini() {
    const mini = document.getElementById("trfmc-v51r3-mini");
    if (mini) {
      mini.classList.add("trfmc-v51r4-suppressed");
      mini.setAttribute("aria-hidden", "true");
    }
  }

  function clampDangerousOverflow() {
    const candidates = Array.from(document.querySelectorAll(
      "main, section, article, aside, nav, header, footer, div, table, pre"
    ));

    for (const el of candidates) {
      if (!el || el === document.body || el === document.documentElement) continue;

      const style = window.getComputedStyle(el);
      if (style.position === "fixed" && el.id !== "trfmc-v51r3-mini") continue;

      const client = el.clientWidth || 0;
      const scroll = el.scrollWidth || 0;

      if (client > 0 && scroll > client + 16) {
        const tag = el.tagName.toLowerCase();
        if (tag === "table" || tag === "pre") {
          el.classList.add("trfmc-v51r4-horizontal-scroll");
        } else {
          el.classList.add("trfmc-v51r4-overflow-clamped");
        }
      }
    }
  }

  function normalizeMenuLabels() {
    const links = document.querySelectorAll(
      "aside a, aside button, nav a, nav button, [role='navigation'] a, [role='navigation'] button"
    );

    links.forEach((el) => {
      const txt = (el.textContent || "").trim();
      if (txt.length > 42) {
        el.setAttribute("title", txt);
      }
    });
  }

  function addAuditMarker() {
    let marker = document.getElementById("trfmc-v51r4-layout-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r4-layout-marker";
      marker.name = "trfmc-v51r4-layout-repair";
      marker.content = "active";
      document.head.appendChild(marker);
    }
  }

  function boot() {
    markRuntime();
    suppressNoisyV51R3Mini();
    normalizeMenuLabels();
    clampDangerousOverflow();
    addAuditMarker();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.addEventListener("hashchange", () => setTimeout(boot, 120));
  window.addEventListener("resize", () => setTimeout(boot, 160));

  setTimeout(boot, 500);
  setTimeout(boot, 1400);
})();
JS

python3 - "$INDEX" <<'PY'
from pathlib import Path
import sys

idx = Path(sys.argv[1])
text = idx.read_text(encoding="utf-8", errors="replace")

css = '<link rel="stylesheet" href="/assets/trfmc_layout_proportions_repair_v51r4.css" data-trfmc-v51r4="layout-proportions-repair">'
js = '<script type="module" src="/assets/trfmc_layout_proportions_repair_v51r4.js" data-trfmc-v51r4="layout-proportions-repair"></script>'

changed = False

if "trfmc_layout_proportions_repair_v51r4.css" not in text:
    if "</head>" in text:
        text = text.replace("</head>", f"  {css}\n</head>", 1)
    else:
        text = css + "\n" + text
    changed = True

if "trfmc_layout_proportions_repair_v51r4.js" not in text:
    if "</body>" in text:
        text = text.replace("</body>", f"  {js}\n</body>", 1)
    else:
        text = text + "\n" + js + "\n"
    changed = True

idx.write_text(text, encoding="utf-8")
print("INDEX_CHANGED=" + str(changed))
PY

echo
echo "=== BUILD VALIDATION ==="
BUILD_RESULT="PASS"
(
  cd "$FRONT"
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: ripristino index.html precedente"
  cp -a "$OUT/index.before_v51r4_$TS.html" "$INDEX"
  BUILD_RESULT="FAIL_ROLLBACK_INDEX_RESTORED"
fi

tail -n 80 "$BUILDLOG" || true

echo
echo "=== HTTP GATE ==="
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
check_url "http://127.0.0.1:5173/assets/trfmc_layout_proportions_repair_v51r4.css"
check_url "http://127.0.0.1:5173/assets/trfmc_layout_proportions_repair_v51r4.js"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

echo
echo "=== OPTIONAL SCREENSHOT ==="
SCREENSHOT_RESULT="SKIPPED"
if command -v google-chrome >/dev/null 2>&1; then
  google-chrome \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1600 \
    --screenshot="$SCREENSHOT" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
elif command -v chromium >/dev/null 2>&1; then
  chromium \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1600 \
    --screenshot="$SCREENSHOT" \
    "http://127.0.0.1:5173/#full-engineering-stack" >/dev/null 2>&1 && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
fi
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"
[ -f "$SCREENSHOT" ] && file "$SCREENSHOT" || true

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_V51R4_LAYOUT_PROPORTIONS_REPAIR",
  "frontend_mutation": true,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "index_backup": "$OUT/index.before_v51r4_$TS.html",
  "layout_css": "$ASSETS/trfmc_layout_proportions_repair_v51r4.css",
  "layout_js": "$ASSETS/trfmc_layout_proportions_repair_v51r4.js",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "screenshot": "$SCREENSHOT",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v51r4_layout_proportions_repair"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_V51R4_LAYOUT_PROPORTIONS_REPAIR COMPLETATO"
echo "Output: $OUT"
echo "Apri/refresh: http://127.0.0.1:5173/#full-engineering-stack"
echo "============================================================"
