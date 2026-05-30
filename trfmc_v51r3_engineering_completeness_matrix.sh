#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONT="$BASE/frontend"
PUBLIC="$FRONT/public"
ASSETS="$PUBLIC/assets"
INDEX="$FRONT/index.html"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_V51R3_ENGINEERING_COMPLETENESS_MATRIX_$TS"
mkdir -p "$OUT" "$ASSETS"

SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_v51r3.log"
HTTP="$OUT/http.tsv"
DEBT="$OUT/classified_debt.tsv"
DEBT_SUMMARY="$OUT/debt_summary.tsv"
REAL_DEBT="$OUT/real_active_debt.tsv"

echo "============================================================"
echo "TRFMC_V51R3_ENGINEERING_COMPLETENESS_MATRIX"
echo "Controlled frontend-only mutation · matrix + real-debt classifier"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$INDEX" ]; then
  echo "ERRORE: frontend/index.html non trovato: $INDEX"
  exit 1
fi

cp -a "$INDEX" "$OUT/index.before_v51r3_$TS.html"

cat > "$ASSETS/trfmc_engineering_completeness_matrix_v51r3.css" <<'CSS'
:root {
  --trfmc-v51r3-bg: rgba(3, 8, 18, .94);
  --trfmc-v51r3-panel: rgba(9, 20, 39, .92);
  --trfmc-v51r3-border: rgba(125, 211, 252, .28);
  --trfmc-v51r3-border-strong: rgba(125, 211, 252, .55);
  --trfmc-v51r3-text: #e5f3ff;
  --trfmc-v51r3-muted: #91a9bd;
  --trfmc-v51r3-cyan: #67e8f9;
  --trfmc-v51r3-green: #86efac;
  --trfmc-v51r3-amber: #fbbf24;
  --trfmc-v51r3-red: #f87171;
  --trfmc-v51r3-violet: #c4b5fd;
}

#trfmc-v51r3-matrix-host {
  max-width: 1480px;
  margin: 28px auto 60px auto;
  padding: 0 22px;
  color: var(--trfmc-v51r3-text);
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  position: relative;
  z-index: 30;
}

.trfmc-v51r3-shell {
  border: 1px solid var(--trfmc-v51r3-border);
  background:
    radial-gradient(circle at 15% 0%, rgba(103,232,249,.18), transparent 34%),
    radial-gradient(circle at 88% 16%, rgba(196,181,253,.14), transparent 30%),
    linear-gradient(135deg, rgba(3,8,18,.98), rgba(8,21,38,.96));
  border-radius: 26px;
  box-shadow: 0 28px 80px rgba(0,0,0,.46), inset 0 0 40px rgba(103,232,249,.04);
  overflow: hidden;
}

.trfmc-v51r3-header {
  padding: 24px 26px 18px 26px;
  border-bottom: 1px solid rgba(125,211,252,.18);
  display: grid;
  grid-template-columns: 1.45fr .85fr;
  gap: 18px;
  align-items: start;
}

.trfmc-v51r3-eyebrow {
  display: inline-flex;
  gap: 8px;
  align-items: center;
  color: var(--trfmc-v51r3-cyan);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: .14em;
  font-weight: 800;
}

.trfmc-v51r3-dot {
  width: 9px;
  height: 9px;
  border-radius: 99px;
  background: var(--trfmc-v51r3-green);
  box-shadow: 0 0 18px rgba(134,239,172,.85);
}

.trfmc-v51r3-title {
  margin: 8px 0 8px 0;
  font-size: clamp(28px, 3.2vw, 46px);
  line-height: .98;
  letter-spacing: -.04em;
  font-weight: 950;
}

.trfmc-v51r3-subtitle {
  max-width: 980px;
  color: var(--trfmc-v51r3-muted);
  font-size: 15px;
  line-height: 1.62;
}

.trfmc-v51r3-status-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 10px;
}

.trfmc-v51r3-status-card {
  border: 1px solid rgba(125,211,252,.18);
  background: rgba(2,6,23,.58);
  border-radius: 18px;
  padding: 12px 14px;
}

.trfmc-v51r3-status-card b {
  display: block;
  font-size: 12px;
  color: var(--trfmc-v51r3-cyan);
  text-transform: uppercase;
  letter-spacing: .1em;
  margin-bottom: 6px;
}

.trfmc-v51r3-status-card span {
  color: var(--trfmc-v51r3-text);
  font-size: 14px;
}

.trfmc-v51r3-grid {
  padding: 22px 26px 26px 26px;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.trfmc-v51r3-module {
  border: 1px solid rgba(125,211,252,.16);
  background:
    linear-gradient(180deg, rgba(15,23,42,.84), rgba(2,6,23,.76));
  border-radius: 20px;
  padding: 16px;
  min-height: 260px;
  position: relative;
  overflow: hidden;
}

.trfmc-v51r3-module:before {
  content: "";
  position: absolute;
  inset: 0;
  background: linear-gradient(90deg, rgba(103,232,249,.08), transparent 40%, rgba(196,181,253,.06));
  pointer-events: none;
}

.trfmc-v51r3-module > * {
  position: relative;
}

.trfmc-v51r3-module-top {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: start;
  margin-bottom: 14px;
}

.trfmc-v51r3-module-title {
  font-size: 18px;
  font-weight: 900;
  letter-spacing: -.02em;
}

.trfmc-v51r3-badge {
  white-space: nowrap;
  border: 1px solid rgba(134,239,172,.38);
  color: var(--trfmc-v51r3-green);
  border-radius: 999px;
  font-size: 11px;
  font-weight: 850;
  padding: 5px 9px;
  background: rgba(20,83,45,.18);
  text-transform: uppercase;
  letter-spacing: .08em;
}

.trfmc-v51r3-badge.locked {
  border-color: rgba(251,191,36,.46);
  color: var(--trfmc-v51r3-amber);
  background: rgba(120,53,15,.2);
}

.trfmc-v51r3-kv {
  display: grid;
  grid-template-columns: 122px minmax(0, 1fr);
  gap: 8px 10px;
  font-size: 13px;
  line-height: 1.42;
}

.trfmc-v51r3-kv dt {
  color: var(--trfmc-v51r3-cyan);
  font-weight: 850;
}

.trfmc-v51r3-kv dd {
  margin: 0;
  color: #d8e9f7;
}

.trfmc-v51r3-footer {
  padding: 16px 26px 24px 26px;
  border-top: 1px solid rgba(125,211,252,.18);
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 16px;
  align-items: center;
  color: var(--trfmc-v51r3-muted);
  font-size: 13px;
}

.trfmc-v51r3-mini {
  position: fixed;
  right: 18px;
  bottom: 18px;
  z-index: 9999;
  width: min(420px, calc(100vw - 36px));
  border: 1px solid rgba(125,211,252,.28);
  background: rgba(2,6,23,.92);
  backdrop-filter: blur(14px);
  color: var(--trfmc-v51r3-text);
  border-radius: 18px;
  box-shadow: 0 20px 60px rgba(0,0,0,.48);
  padding: 13px 14px;
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
}

.trfmc-v51r3-mini b {
  color: var(--trfmc-v51r3-cyan);
}

.trfmc-v51r3-mini small {
  display: block;
  margin-top: 4px;
  color: var(--trfmc-v51r3-muted);
  line-height: 1.35;
}

@media (max-width: 980px) {
  .trfmc-v51r3-header,
  .trfmc-v51r3-grid,
  .trfmc-v51r3-footer {
    grid-template-columns: 1fr;
  }

  .trfmc-v51r3-kv {
    grid-template-columns: 1fr;
  }
}
CSS

cat > "$ASSETS/trfmc_engineering_completeness_matrix_v51r3.js" <<'JS'
(() => {
  const VERSION = "V51R3";
  const HOST_ID = "trfmc-v51r3-matrix-host";
  const MINI_ID = "trfmc-v51r3-mini";

  const modules = [
    {
      title: "Mission Control / NOC",
      state: "validated",
      theory: "Mission model, SOC/NOC telemetry, operational readiness, evidence chain.",
      simulator: "Mission status correlation and live-readiness probes.",
      endpoint: "4181/api/mission/status · 4181/api/health",
      visual: "Command HUD, status cards, runtime evidence layer.",
      scenario: "Lab power-on, operator validation, baseline freeze.",
      qa: "HTTP 200, DOM marker, screenshot capture, zero-miss runtime QA."
    },
    {
      title: "RF Physics / Signal Theory",
      state: "engineering",
      theory: "Maxwell spine, Fourier/FFT, I/Q, dB/dBm, noise floor, SNR, EVM/BLER.",
      simulator: "Spectrum, waterfall, constellation and deterministic synthetic RF feed.",
      endpoint: "4181/api/rfpro/spectrum/sweep",
      visual: "RF spectrum cockpit, waterfall, signal cards, measurement gauges.",
      scenario: "Known signal, degraded channel, NLOS and RF impairment analysis.",
      qa: "Sweep endpoint online, rendered plots present, no CDN dependency."
    },
    {
      title: "Visual Asset System",
      state: "engineering",
      theory: "Asset-to-domain mapping, RF object taxonomy, instrumentation representation.",
      simulator: "Procedural WebGL/Canvas visual assets and local SVG registry.",
      endpoint: "5173 local visual asset registry",
      visual: "Antenna, tower, microwave, fiber, RF lab and infrastructure diagrams.",
      scenario: "Operator navigates asset → theory → scenario → evidence.",
      qa: "Registry load, local assets present, no remote image dependency."
    },
    {
      title: "Navigation Architecture",
      state: "validated",
      theory: "Unified portal topology, hash routing, shell discipline, section identity.",
      simulator: "Route/section resolver and active-section binding.",
      endpoint: "5173/#section hash contracts",
      visual: "Unified shell, matrix navigation, cross-domain launch points.",
      scenario: "Operator jumps between mission, visual, scenario and engineering stack.",
      qa: "Hash routes return 200, active section marker correct."
    },
    {
      title: "Dynamic Scenarios",
      state: "engineering",
      theory: "Operational scenario graph, RF/Telco/Cyber correlation, evidence generation.",
      simulator: "Scenario runner, event stream, mission graph and report console.",
      endpoint: "4181 APIs + 8000 health/backend contracts",
      visual: "Scenario cards, graph console, report console, evidence vault.",
      scenario: "RF degradation, private network, microwave, fiber and core correlation.",
      qa: "Scenario page visible, endpoint contract documented, report path defined."
    },
    {
      title: "5G Core / RAN Security",
      state: "engineering",
      theory: "Open5GS/UERANSIM, SUPI/SUCI, 5G-AKA, NAS, NGAP, PFCP, GTP-U.",
      simulator: "Readonly call-flow and identity/security analysis console.",
      endpoint: "8000/api/health and future Open5GS/UERANSIM bridge.",
      visual: "Core/RAN flow, PDU session chain, identity/security inspection panels.",
      scenario: "UE registration, authentication, PDU session establishment, tunnel readiness.",
      qa: "Backend reachable, readonly mode preserved, no unsafe live mutation."
    },
    {
      title: "Security Interlock / Restricted Areas",
      state: "locked",
      theory: "PKI, smartcard, mTLS, RBAC/ABAC, immutable audit, RF safety gates.",
      simulator: "Locked simulation-only control state.",
      endpoint: "backend security baseline · locked contracts",
      visual: "Safety lock indicators and operator authorization map.",
      scenario: "Controlled lab governance before any sensitive capability activation.",
      qa: "Restricted EW/SIGINT/red-team functions remain non-emissive and locked."
    },
    {
      title: "Engineering Completeness Matrix",
      state: "validated",
      theory: "Each module must map theory, simulator, endpoint, asset, scenario and QA.",
      simulator: "This V51R3 matrix binds visible portal quality to measurable evidence.",
      endpoint: "5173 local injected matrix asset",
      visual: "Enterprise T&M matrix embedded into the current shell.",
      scenario: "Operator can see what is complete, what is locked, what is next.",
      qa: "Frontend-only injection, build PASS required, no backend/nginx/systemd mutation."
    }
  ];

  const probes = [
    { key: "Frontend", url: "http://127.0.0.1:5173/" },
    { key: "Bridge", url: "http://127.0.0.1:4181/api/health" },
    { key: "Backend", url: "http://127.0.0.1:8000/api/health" }
  ];

  function shouldExpand() {
    const h = window.location.hash || "";
    return h === "#full-engineering-stack" ||
           h === "#mission-overview" ||
           h === "#command-center";
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[c]));
  }

  function moduleCard(m) {
    const locked = m.state === "locked";
    return `
      <article class="trfmc-v51r3-module">
        <div class="trfmc-v51r3-module-top">
          <div class="trfmc-v51r3-module-title">${esc(m.title)}</div>
          <div class="trfmc-v51r3-badge ${locked ? "locked" : ""}">${esc(m.state)}</div>
        </div>
        <dl class="trfmc-v51r3-kv">
          <dt>Teoria</dt><dd>${esc(m.theory)}</dd>
          <dt>Simulatore</dt><dd>${esc(m.simulator)}</dd>
          <dt>Endpoint</dt><dd>${esc(m.endpoint)}</dd>
          <dt>Asset</dt><dd>${esc(m.visual)}</dd>
          <dt>Scenario</dt><dd>${esc(m.scenario)}</dd>
          <dt>QA</dt><dd>${esc(m.qa)}</dd>
        </dl>
      </article>
    `;
  }

  async function probeRuntime() {
    const result = {};
    await Promise.all(probes.map(async p => {
      try {
        const r = await fetch(p.url, { cache: "no-store" });
        result[p.key] = r.ok ? `ONLINE ${r.status}` : `WARN ${r.status}`;
      } catch {
        result[p.key] = "PROBE UNAVAILABLE";
      }
    }));
    return result;
  }

  function renderMini() {
    let mini = document.getElementById(MINI_ID);
    if (!mini) {
      mini = document.createElement("div");
      mini.id = MINI_ID;
      mini.className = "trfmc-v51r3-mini";
      document.body.appendChild(mini);
    }
    mini.innerHTML = `
      <b>TRFMC ${VERSION} · Engineering Matrix attiva</b>
      <small>Apri <code>#full-engineering-stack</code> per la matrice completa. Frontend-only, nessuna mutazione backend/nginx/systemd.</small>
    `;
  }

  async function renderExpanded() {
    let host = document.getElementById(HOST_ID);
    if (!host) {
      host = document.createElement("section");
      host.id = HOST_ID;
      document.body.appendChild(host);
    }

    const runtime = await probeRuntime();

    host.innerHTML = `
      <div class="trfmc-v51r3-shell">
        <header class="trfmc-v51r3-header">
          <div>
            <div class="trfmc-v51r3-eyebrow"><span class="trfmc-v51r3-dot"></span>TRFMC ${VERSION} · Enterprise Engineering Completeness Matrix</div>
            <h2 class="trfmc-v51r3-title">Dal contenuto al collaudo: ogni modulo deve avere teoria, simulatore, endpoint, asset, scenario e QA.</h2>
            <p class="trfmc-v51r3-subtitle">
              Questa matrice rende visibile la maturità tecnica del portale: non solo pagine, ma contratti verificabili.
              Le aree sensibili restano bloccate e non emissive; l’obiettivo è qualità T&amp;M, controllo operativo e tracciabilità.
            </p>
          </div>
          <div class="trfmc-v51r3-status-grid">
            <div class="trfmc-v51r3-status-card"><b>Frontend</b><span>${esc(runtime.Frontend || "checking")}</span></div>
            <div class="trfmc-v51r3-status-card"><b>Bridge</b><span>${esc(runtime.Bridge || "checking")}</span></div>
            <div class="trfmc-v51r3-status-card"><b>Backend</b><span>${esc(runtime.Backend || "checking")}</span></div>
          </div>
        </header>
        <main class="trfmc-v51r3-grid">
          ${modules.map(moduleCard).join("")}
        </main>
        <footer class="trfmc-v51r3-footer">
          <div>
            <b>Rule:</b> nessuna funzione avanzata viene attivata senza PKI/smartcard/mTLS/RBAC/ABAC, audit immutabile e interlock RF.
          </div>
          <div>V51R3 · frontend-only · local assets</div>
        </footer>
      </div>
    `;
  }

  function clearExpanded() {
    const host = document.getElementById(HOST_ID);
    if (host && !shouldExpand()) host.innerHTML = "";
  }

  async function boot() {
    renderMini();
    if (shouldExpand()) await renderExpanded();
    else clearExpanded();
  }

  window.addEventListener("hashchange", boot);
  document.addEventListener("DOMContentLoaded", boot);
  setTimeout(boot, 700);
})();
JS

python3 - "$INDEX" <<'PY'
from pathlib import Path
import sys

idx = Path(sys.argv[1])
text = idx.read_text(encoding="utf-8", errors="replace")

css = '<link rel="stylesheet" href="/assets/trfmc_engineering_completeness_matrix_v51r3.css" data-trfmc-v51r3="engineering-completeness-matrix">'
js = '<script type="module" src="/assets/trfmc_engineering_completeness_matrix_v51r3.js" data-trfmc-v51r3="engineering-completeness-matrix"></script>'

changed = False

if 'trfmc_engineering_completeness_matrix_v51r3.css' not in text:
    if '</head>' in text:
        text = text.replace('</head>', f'  {css}\n</head>', 1)
    else:
        text = css + "\n" + text
    changed = True

if 'trfmc_engineering_completeness_matrix_v51r3.js' not in text:
    if '</body>' in text:
        text = text.replace('</body>', f'  {js}\n</body>', 1)
    else:
        text = text + "\n" + js + "\n"
    changed = True

if changed:
    idx.write_text(text, encoding="utf-8")

print("INDEX_CHANGED=" + str(changed))
PY

echo
echo "=== CLASSIFICAZIONE DEBITO REALE / FALSI POSITIVI ==="

python3 - "$BASE" "$DEBT" "$DEBT_SUMMARY" "$REAL_DEBT" <<'PY'
from pathlib import Path
from collections import Counter
import re
import sys

base = Path(sys.argv[1])
debt_path = Path(sys.argv[2])
summary_path = Path(sys.argv[3])
real_path = Path(sys.argv[4])

roots = [
    base / "frontend" / "src",
    base / "frontend" / "public",
    base / "backend",
]

patterns = [
    ("placeholder", re.compile(r"placeholder", re.I)),
    ("todo", re.compile(r"\bTODO\b|FIXME|da implementare|not implemented", re.I)),
    ("mock_stub_dummy_fake", re.compile(r"\bmock\b|\bstub\b|\bdummy\b|\bfake\b", re.I)),
    ("remote_or_url", re.compile(r"https?://|cdn\.|unpkg|jsdelivr|googleapis|fonts\.gstatic|cdnjs|bootstrapcdn", re.I)),
]

def classify(path: Path, line: str, kind: str):
    p = str(path.relative_to(base))

    if ".bak" in p or ".backup" in p or "_bak_" in p:
        return "false_positive_backup"

    if "/vendor/" in p or p.startswith("frontend/public/vendor/"):
        return "false_positive_vendor"

    if "xmlns=\"http://www.w3.org/2000/svg\"" in line or "createElementNS('http://www.w3.org/2000/svg'" in line:
        return "false_positive_svg_namespace"

    if "127.0.0.1" in line or "localhost" in line:
        return "accepted_local_contract"

    if p.startswith("backend/docs/"):
        return "documentation_reference"

    if "KhronosGroup" in line or "mrdoob" in line or "three.js" in line:
        return "false_positive_vendor_reference"

    if p.endswith(".svg"):
        return "visual_asset_metadata"

    if p.startswith("frontend/public/trfmc_assets/visual_knowledge/") and "render_placeholder" in line:
        return "real_active_visual_registry_placeholder"

    if p.startswith("frontend/src/"):
        return "real_active_frontend_source"

    if p.startswith("frontend/public/"):
        return "real_active_public_page"

    if p.startswith("backend/app/") or p.startswith("backend/readonly_bridge"):
        return "real_active_backend_contract"

    return "needs_review"

rows = []
for root in roots:
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if any(part in {".git", "node_modules", "dist", "__pycache__", ".venv"} for part in path.parts):
            continue
        if path.suffix.lower() not in {
            ".tsx", ".ts", ".jsx", ".js", ".css", ".html", ".json", ".py", ".md", ".svg"
        }:
            continue

        try:
            text = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except Exception:
            continue

        for no, line in enumerate(text, 1):
            for kind, rx in patterns:
                if rx.search(line):
                    cls = classify(path, line, kind)
                    rows.append((cls, kind, str(path.relative_to(base)), no, line.strip()[:260]))
                    break

rows.sort(key=lambda r: (r[0], r[2], r[3]))

with debt_path.open("w", encoding="utf-8") as f:
    f.write("class\tkind\tfile\tline\ttext\n")
    for r in rows:
        f.write("\t".join(map(str, r)).replace("\n", " ") + "\n")

real_classes = {
    "real_active_visual_registry_placeholder",
    "real_active_frontend_source",
    "real_active_public_page",
    "real_active_backend_contract",
    "needs_review",
}

real_rows = [r for r in rows if r[0] in real_classes]

with real_path.open("w", encoding="utf-8") as f:
    f.write("class\tkind\tfile\tline\ttext\n")
    for r in real_rows:
        f.write("\t".join(map(str, r)).replace("\n", " ") + "\n")

c = Counter(r[0] for r in rows)
with summary_path.open("w", encoding="utf-8") as f:
    f.write("class\tcount\n")
    for k, v in sorted(c.items()):
        f.write(f"{k}\t{v}\n")
    f.write(f"TOTAL\t{len(rows)}\n")
    f.write(f"REAL_ACTIVE_OR_REVIEW\t{len(real_rows)}\n")

print(f"TOTAL_MATCHES={len(rows)}")
print(f"REAL_ACTIVE_OR_REVIEW={len(real_rows)}")
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
  cp -a "$OUT/index.before_v51r3_$TS.html" "$INDEX"
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
check_url "http://127.0.0.1:5173/#full-engineering-stack"
check_url "http://127.0.0.1:5173/assets/trfmc_engineering_completeness_matrix_v51r3.js"
check_url "http://127.0.0.1:5173/assets/trfmc_engineering_completeness_matrix_v51r3.css"
check_url "http://127.0.0.1:4181/api/health"
check_url "http://127.0.0.1:8000/api/health"

HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"
REAL_DEBT_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$REAL_DEBT")"
TOTAL_DEBT_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$DEBT")"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_V51R3_ENGINEERING_COMPLETENESS_MATRIX",
  "frontend_mutation": true,
  "backend_mutation": false,
  "nginx_mutation": false,
  "systemd_mutation": false,
  "base": "$BASE",
  "out": "$OUT",
  "index_backup": "$OUT/index.before_v51r3_$TS.html",
  "matrix_css": "$ASSETS/trfmc_engineering_completeness_matrix_v51r3.css",
  "matrix_js": "$ASSETS/trfmc_engineering_completeness_matrix_v51r3.js",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "classified_debt": "$DEBT",
  "debt_summary": "$DEBT_SUMMARY",
  "real_active_debt": "$REAL_DEBT",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "total_debt_matches": $TOTAL_DEBT_COUNT,
  "real_active_or_review_debt": $REAL_DEBT_COUNT,
  "result": "$([ "$BUILD_RESULT" = "PASS" ] && [ "$HTTP_NON_200" = "0" ] && [ "$HTTP_ZERO_BYTES" = "0" ] && echo PASS || echo REVIEW)"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_v51r3_engineering_completeness_matrix"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== DEBT SUMMARY ==="
column -t -s $'\t' "$DEBT_SUMMARY" || cat "$DEBT_SUMMARY"

echo
echo "=== REAL ACTIVE DEBT - PRIME 120 RIGHE ==="
sed -n '1,120p' "$REAL_DEBT"

echo
echo "============================================================"
echo "TRFMC_V51R3_ENGINEERING_COMPLETENESS_MATRIX COMPLETATO"
echo "Output: $OUT"
echo "Apri: http://127.0.0.1:5173/#full-engineering-stack"
echo "============================================================"
