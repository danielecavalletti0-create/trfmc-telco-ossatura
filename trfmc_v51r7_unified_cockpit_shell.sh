#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
ASSETS="$PUBLIC/assets"
INDEX="$FRONT/index.html"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V51R7_UNIFIED_COCKPIT_SHELL_$TS"

mkdir -p "$OUT" "$ASSETS"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_v51r7.log"
HTTP="$OUT/http.tsv"

echo "============================================================"
echo "TRFMC_V51R7_UNIFIED_COCKPIT_SHELL"
echo "Unifica cockpit superiore + orchestrator V42/V49 in una sola shell"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$INDEX" ]; then
  echo "ERRORE: index.html non trovato: $INDEX"
  exit 1
fi

cp -a "$INDEX" "$OUT/index.before_v51r7_$TS.html"

cat > "$ASSETS/trfmc_unified_cockpit_shell_v51r7.css" <<'CSS'
/*
  TRFMC V51R7 - Unified Cockpit Shell
  Obiettivo: eliminare l'effetto "due portali separati nella stessa pagina".
*/

:root {
  --v51r7-shell-max: 1560px;
  --v51r7-shell-pad-x: clamp(24px, 3vw, 56px);
  --v51r7-cyan: #67e8f9;
  --v51r7-green: #86efac;
  --v51r7-text: #e8f7ff;
  --v51r7-muted: #9fb8ca;
  --v51r7-border: rgba(103,232,249,.24);
  --v51r7-border-soft: rgba(103,232,249,.13);
  --v51r7-panel: rgba(5,16,31,.86);
  --v51r7-panel-soft: rgba(5,16,31,.55);
  --v51r7-bg: rgba(2,9,18,.94);
}

html,
body,
#root {
  width: 100%;
  min-height: 100%;
  margin: 0;
  overflow-x: hidden !important;
}

body.trfmc-v51r7-unified {
  background:
    radial-gradient(circle at 22% 0%, rgba(8,145,178,.14), transparent 32%),
    radial-gradient(circle at 82% 15%, rgba(34,211,238,.08), transparent 35%),
    linear-gradient(180deg, #020812 0%, #020617 48%, #00040a 100%) !important;
}

/* Mantiene la calibrazione buona della V51R6 */
body.trfmc-v51r7-unified :where(
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
  width: min(var(--v51r7-shell-max), calc(100vw - 2 * var(--v51r7-shell-pad-x))) !important;
  max-width: min(var(--v51r7-shell-max), calc(100vw - 2 * var(--v51r7-shell-pad-x))) !important;
  margin-left: auto !important;
  margin-right: auto !important;
}

/* Wrapper creato via JS: la pagina diventa una plancia unica */
body.trfmc-v51r7-unified #trfmc-v51r7-single-cockpit {
  width: min(var(--v51r7-shell-max), calc(100vw - 2 * var(--v51r7-shell-pad-x)));
  max-width: min(var(--v51r7-shell-max), calc(100vw - 2 * var(--v51r7-shell-pad-x)));
  margin: 18px auto 42px auto;
  border: 1px solid var(--v51r7-border);
  border-radius: 26px;
  overflow: hidden;
  background:
    linear-gradient(180deg, rgba(5,16,31,.94), rgba(2,8,17,.96) 48%, rgba(1,6,13,.98));
  box-shadow:
    0 30px 90px rgba(0,0,0,.48),
    inset 0 0 70px rgba(103,232,249,.035);
}

/* I figli principali non devono più sembrare portali autonomi */
body.trfmc-v51r7-unified #trfmc-v51r7-single-cockpit > * {
  width: 100% !important;
  max-width: 100% !important;
  margin-left: 0 !important;
  margin-right: 0 !important;
}

/* Primo cockpit: diventa header operativo della shell unica */
body.trfmc-v51r7-unified .trfmc-v51r7-primary-cockpit {
  border-radius: 0 !important;
  border-left: 0 !important;
  border-right: 0 !important;
  border-top: 0 !important;
  margin-top: 0 !important;
  margin-bottom: 0 !important;
  background:
    radial-gradient(circle at 15% 0%, rgba(103,232,249,.12), transparent 34%),
    linear-gradient(180deg, rgba(8,24,44,.94), rgba(3,12,24,.88)) !important;
}

/* Secondo blocco/orchestrator: non è più un altro portale */
body.trfmc-v51r7-unified .trfmc-v51r7-orchestrator {
  border-radius: 0 !important;
  border-left: 0 !important;
  border-right: 0 !important;
  margin-top: 0 !important;
  margin-bottom: 0 !important;
  background:
    linear-gradient(180deg, rgba(2,12,23,.78), rgba(2,8,17,.92)) !important;
  border-top: 1px solid var(--v51r7-border-soft) !important;
}

/* Riduce l'effetto "secondo titolo home page" */
body.trfmc-v51r7-unified .trfmc-v51r7-orchestrator h1,
body.trfmc-v51r7-unified .trfmc-v51r7-orchestrator h2:first-of-type {
  font-size: clamp(24px, 1.65vw, 34px) !important;
  line-height: 1.06 !important;
  letter-spacing: -.035em !important;
  margin-bottom: 8px !important;
}

/* Label V42 più piccola: da titolo portale a sezione tecnica */
body.trfmc-v51r7-unified .trfmc-v51r7-orchestrator :where(
  [class*="eyebrow" i],
  [class*="kicker" i],
  [class*="label" i]
) {
  font-size: 11px !important;
  letter-spacing: .16em !important;
}

/* Separatore unico tra cockpit e orchestrator */
body.trfmc-v51r7-unified .trfmc-v51r7-shell-divider {
  height: 1px;
  width: 100%;
  background:
    linear-gradient(90deg, transparent, rgba(103,232,249,.34), rgba(134,239,172,.20), transparent);
}

/* Rende i blocchi interni coerenti */
body.trfmc-v51r7-unified :where(
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
  border-color: var(--v51r7-border) !important;
  background-color: rgba(5,16,31,.72);
}

/* Sidebar interna: integrata, non come menu di un secondo sito */
body.trfmc-v51r7-unified :where(
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
  background: rgba(2,10,20,.38) !important;
  border-color: var(--v51r7-border-soft) !important;
}

/* Evita grandi vuoti verticali tra i due blocchi */
body.trfmc-v51r7-unified .trfmc-v51r7-orchestrator {
  padding-top: 0 !important;
}

body.trfmc-v51r7-unified .trfmc-v51r7-orchestrator > *:first-child {
  margin-top: 0 !important;
}

/* Nasconde ancora appendici non volute */
body.trfmc-v51r7-unified #trfmc-v51r3-matrix-host,
body.trfmc-v51r7-unified #trfmc-v51r3-mini {
  display: none !important;
  visibility: hidden !important;
  pointer-events: none !important;
}

/* Mobile/tablet */
@media (max-width: 980px) {
  :root {
    --v51r7-shell-pad-x: 16px;
  }

  body.trfmc-v51r7-unified #trfmc-v51r7-single-cockpit {
    border-radius: 18px;
  }
}
CSS

cat > "$ASSETS/trfmc_unified_cockpit_shell_v51r7.js" <<'JS'
(() => {
  const VERSION = "V51R7";
  const WRAP_ID = "trfmc-v51r7-single-cockpit";

  function textOf(el) {
    return (el && el.textContent ? el.textContent : "").replace(/\s+/g, " ").trim();
  }

  function findBlockContainingText(patterns) {
    const candidates = Array.from(document.body.querySelectorAll("section, main, article, div, header"));
    let best = null;

    for (const el of candidates) {
      const t = textOf(el);
      if (!t) continue;

      const matched = patterns.some((p) => p.test(t));
      if (!matched) continue;

      const rect = el.getBoundingClientRect();
      if (!rect.width || !rect.height) continue;

      if (!best) {
        best = el;
        continue;
      }

      const area = rect.width * rect.height;
      const bestRect = best.getBoundingClientRect();
      const bestArea = bestRect.width * bestRect.height;

      /*
        Preferiamo un contenitore abbastanza grande ma non body/root.
        Serve catturare il blocco visivo, non il singolo titolo.
      */
      if (area > bestArea && area < window.innerWidth * window.innerHeight * 1.8) {
        best = el;
      }
    }

    return best;
  }

  function nearestDirectRootChild(el) {
    if (!el) return null;

    const root = document.getElementById("root") || document.body;
    let cur = el;
    let prev = el;

    while (cur && cur !== document.body && cur !== root) {
      prev = cur;
      cur = cur.parentElement;
    }

    return prev || el;
  }

  function buildUnifiedShell() {
    if (!document.body) return;

    document.body.classList.add("trfmc-v51r7-unified");
    document.body.dataset.trfmcUnifiedCockpit = VERSION;

    const existing = document.getElementById(WRAP_ID);
    if (existing) {
      markReady();
      return;
    }

    const primaryInner = findBlockContainingText([
      /TELCO RF MISSION CONTROL PLATFORM/i
    ]);

    const orchInner = findBlockContainingText([
      /TRFMC Mission Control Layout/i,
      /Full Engineering Stack - Integration View/i
    ]);

    const primary = nearestDirectRootChild(primaryInner);
    const orchestrator = nearestDirectRootChild(orchInner);

    if (!primary || !orchestrator || primary === orchestrator) {
      markReady("partial");
      return;
    }

    primary.classList.add("trfmc-v51r7-primary-cockpit");
    orchestrator.classList.add("trfmc-v51r7-orchestrator");

    const wrapper = document.createElement("div");
    wrapper.id = WRAP_ID;
    wrapper.dataset.trfmcV51r7 = "single-cockpit-shell";

    const divider = document.createElement("div");
    divider.className = "trfmc-v51r7-shell-divider";
    divider.setAttribute("aria-hidden", "true");

    const parent = primary.parentElement;
    parent.insertBefore(wrapper, primary);

    wrapper.appendChild(primary);
    wrapper.appendChild(divider);
    wrapper.appendChild(orchestrator);

    removeLegacyFloatingBlocks();
    markReady("unified");
  }

  function removeLegacyFloatingBlocks() {
    ["trfmc-v51r3-matrix-host", "trfmc-v51r3-mini"].forEach((id) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.style.display = "none";
      el.style.visibility = "hidden";
      el.style.pointerEvents = "none";
      el.setAttribute("aria-hidden", "true");
    });
  }

  function markReady(mode = "active") {
    let marker = document.getElementById("trfmc-v51r7-unified-cockpit-marker");
    if (!marker) {
      marker = document.createElement("meta");
      marker.id = "trfmc-v51r7-unified-cockpit-marker";
      marker.name = "trfmc-v51r7-unified-cockpit";
      document.head.appendChild(marker);
    }
    marker.content = mode;
  }

  function boot() {
    buildUnifiedShell();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.addEventListener("hashchange", () => setTimeout(boot, 120));
  setTimeout(boot, 500);
  setTimeout(boot, 1200);
})();
JS

echo
echo "=== INIEZIONE V51R7 ==="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import sys

idx = Path(sys.argv[1])
text = idx.read_text(encoding="utf-8", errors="replace")

css = '<link rel="stylesheet" href="/assets/trfmc_unified_cockpit_shell_v51r7.css" data-trfmc-v51r7="unified-cockpit-shell">'
js = '<script type="module" src="/assets/trfmc_unified_cockpit_shell_v51r7.js" data-trfmc-v51r7="unified-cockpit-shell"></script>'

changed = False

if "trfmc_unified_cockpit_shell_v51r7.css" not in text:
    if "</head>" in text:
        text = text.replace("</head>", f"  {css}\n</head>", 1)
    else:
        text = css + "\n" + text
    changed = True

if "trfmc_unified_cockpit_shell_v51r7.js" not in text:
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
  cp -a "$OUT/index.before_v51r7_$TS.html" "$INDEX"
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
check_url "http://127.0.0.1:5173/assets/trfmc_unified_cockpit_shell_v51r7.css"
check_url "http://127.0.0.1:5173/assets/trfmc_unified_cockpit_shell_v51r7.js"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_V51R7_UNIFIED_COCKPIT_SHELL",
  "frontend_mutation": true,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "purpose": "merge visual cockpit and V42/V49 orchestrator into one single shell",
  "base": "$BASE",
  "out": "$OUT",
  "index_backup": "$OUT/index.before_v51r7_$TS.html",
  "layout_css": "$ASSETS/trfmc_unified_cockpit_shell_v51r7.css",
  "layout_js": "$ASSETS/trfmc_unified_cockpit_shell_v51r7.js",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v51r7_unified_cockpit_shell"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_V51R7_UNIFIED_COCKPIT_SHELL COMPLETATO"
echo "Output: $OUT"
echo "Apri/refresh: http://127.0.0.1:5173/#full-engineering-stack"
echo "============================================================"
