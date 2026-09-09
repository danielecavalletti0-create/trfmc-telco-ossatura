#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P8A_MASTER_PORTAL_AUDIT_READONLY_V1_$TS"

mkdir -p "$OUT"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
PORTAL_STATE="$OUT/portal_current_state.tsv"
HTTP_GATE="$OUT/http_gate.tsv"

echo "============================================================"
echo "TRFMC_P8A_MASTER_PORTAL_AUDIT_READONLY_V1"
echo "Audit master read-only: inventory, taxonomy, visual gaps, implementation plan"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) RUNTIME HTTP STATE ==="

cat > "$HTTP_GATE" <<HDR
name	url	status	bytes	hint	result
HDR

probe_url() {
  local name="$1"
  local url="$2"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
  grep -qi '^{\|^\[' "$tmp" && hint="JSON"
  local result="OK"
  [ "$code" != "200" ] && result="NON_200"
  [ "$bytes" = "0" ] && result="ZERO_BYTES"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$url" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP_GATE"
  rm -f "$tmp"
}

probe_url "vite_root" "http://127.0.0.1:5173/"
probe_url "portal_os_preview" "http://127.0.0.1:5173/#portal-os-preview"
probe_url "backend_direct" "http://127.0.0.1:8000/api/health"
probe_url "bridge_direct" "http://127.0.0.1:4181/api/health"
probe_url "proxy_backend" "http://127.0.0.1:5173/trfmc-api/backend/api/health"
probe_url "proxy_bridge" "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

cat > "$PORTAL_STATE" <<HDR
metric	value
HDR

printf "timestamp\t%s\n" "$TS" >> "$PORTAL_STATE"
printf "base\t%s\n" "$BASE" >> "$PORTAL_STATE"
printf "git_branch\t%s\n" "$(git branch --show-current 2>/dev/null || echo NO_GIT)" >> "$PORTAL_STATE"
printf "git_head\t%s\n" "$(git rev-parse --short HEAD 2>/dev/null || echo NO_GIT)" >> "$PORTAL_STATE"
printf "node\t%s\n" "$(node -v 2>/dev/null || echo MISSING)" >> "$PORTAL_STATE"
printf "npm\t%s\n" "$(npm -v 2>/dev/null || echo MISSING)" >> "$PORTAL_STATE"
printf "vite_process\t%s\n" "$(ss -ltnp 2>/dev/null | grep -c ':5173 ' || true)" >> "$PORTAL_STATE"
printf "backend_8000_process\t%s\n" "$(ss -ltnp 2>/dev/null | grep -c ':8000 ' || true)" >> "$PORTAL_STATE"
printf "bridge_4181_process\t%s\n" "$(ss -ltnp 2>/dev/null | grep -c ':4181 ' || true)" >> "$PORTAL_STATE"

echo
echo "=== 2) STATIC MASTER AUDIT ==="

python3 - "$BASE" "$OUT" "$TS" <<'PY'
import json
import os
import re
import hashlib
from pathlib import Path
from collections import Counter, defaultdict
import sys

BASE = Path(sys.argv[1])
OUT = Path(sys.argv[2])
TS = sys.argv[3]

FRONTEND = BASE / "frontend"
PUBLIC = FRONTEND / "public"
SRC = FRONTEND / "src"
BACKEND = BASE / "backend"
RUNTIME_QUALITY = BASE / "runtime" / "quality"

FILES = {
    "summary": OUT / "summary.json",
    "domain_taxonomy": OUT / "domain_taxonomy.json",
    "public_pages": OUT / "public_pages_inventory.tsv",
    "react_components": OUT / "react_components_inventory.tsv",
    "backend_api": OUT / "backend_api_inventory.tsv",
    "page_matrix": OUT / "page_to_domain_matrix.tsv",
    "visual_gap": OUT / "visual_gap_analysis.md",
    "blueprint": OUT / "enterprise_portal_blueprint.md",
    "plan": OUT / "next_implementation_plan.md",
    "source_risk": OUT / "source_risk_register.tsv",
    "candidate_backlog": OUT / "candidate_backlog.tsv",
}

TAXONOMY = {
    "mission_command": {
        "label": "Mission Command / Portal OS",
        "tier": "operational",
        "keywords": [
            "mission", "command", "portal", "dashboard", "overview", "registry",
            "executive", "readiness", "nexus", "control room", "control_room"
        ],
        "required_capabilities": [
            "global runtime health", "domain navigation", "evidence chain",
            "entrypoint governance", "source promotion policy"
        ],
    },
    "oss_assurance_inventory": {
        "label": "OSS / Assurance / Inventory",
        "tier": "telco_enterprise",
        "keywords": [
            "assurance", "inventory", "alarm", "alarms", "noc", "observability",
            "health", "event", "events", "evidence", "flight recorder", "sla", "topology"
        ],
        "required_capabilities": [
            "alarms", "inventory", "topology", "service health", "evidence vault"
        ],
    },
    "rf_microwave_engineering": {
        "label": "RF / Microwave Engineering",
        "tier": "engineering",
        "keywords": [
            "microwave", "smith", "fresnel", "propagation", "link budget",
            "maxwell", "wave", "s-parameter", "sparam", "rf physics",
            "rf_physics", "path loss", "eirp", "vswr"
        ],
        "required_capabilities": [
            "RF formulas", "link budget", "Smith chart", "propagation models",
            "microwave path"
        ],
    },
    "antenna_rru_ret_cpri": {
        "label": "Antenna / RRU / RET / CPRI / AISG",
        "tier": "engineering",
        "keywords": [
            "antenna", "rru", "bbu", "ret", "cpri", "aisg", "mimo",
            "beam", "beamforming", "array", "pattern", "downtilt", "sector"
        ],
        "required_capabilities": [
            "radiation pattern", "RRU/BBU mapping", "RET/AISG", "MIMO array",
            "coverage/beam explorer"
        ],
    },
    "signal_dsp_measurement": {
        "label": "Signal / DSP / Measurement",
        "tier": "instrumentation",
        "keywords": [
            "signal", "dsp", "fft", "iq", "waterfall", "spectrum", "vsa",
            "measurement", "analyzer", "trace", "receiver", "demod", "constellation"
        ],
        "required_capabilities": [
            "FFT", "waterfall", "IQ", "spectrum analyzer", "measurement chain"
        ],
    },
    "cellular_2g_3g_4g_epc": {
        "label": "2G / 3G / 4G / EPC",
        "tier": "telco_network",
        "keywords": [
            "2g", "3g", "4g", "lte", "epc", "mme", "hss", "sgw", "pgw",
            "gsm", "umts", "gprs", "edge", "enodeb", "e-utran", "volte"
        ],
        "required_capabilities": [
            "legacy cellular theory", "EPC architecture", "LTE attach",
            "MME/HSS/SGW/PGW call flows"
        ],
    },
    "nr_5gc_open5gs": {
        "label": "5G NR / 5GC / Open5GS / UERANSIM",
        "tier": "telco_core",
        "keywords": [
            "5g", "5gc", "5g core", "nr", "open5gs", "ueransim", "gnb",
            "amf", "smf", "upf", "ausf", "udm", "udr", "nrf", "nssf",
            "ngap", "pfcp", "gtp", "pdu session", "supi", "suci", "aka"
        ],
        "required_capabilities": [
            "5GC SBA", "Open5GS runtime", "UERANSIM", "NGAP/PFCP/GTP-U",
            "identity/security flow"
        ],
    },
    "oran_ric_smo": {
        "label": "O-RAN / SMO / RIC / xApps / rApps",
        "tier": "telco_ran_automation",
        "keywords": [
            "o-ran", "oran", "smo", "ric", "near-rt", "non-rt",
            "xapp", "xapps", "rapp", "rapps", "e2", "a1", "o1",
            "fronthaul", "open ran"
        ],
        "required_capabilities": [
            "SMO", "Non-RT RIC/rApps", "Near-RT RIC/xApps",
            "A1/O1/E2 interfaces", "RAN automation"
        ],
    },
    "satellite_ntn_space": {
        "label": "Satellite / NTN / LEO / MEO / GEO",
        "tier": "space_telco",
        "keywords": [
            "satellite", "ntn", "leo", "meo", "geo", "gnss", "gps",
            "vsat", "space", "orbital", "doppler", "satcom"
        ],
        "required_capabilities": [
            "NTN architecture", "LEO/MEO/GEO", "satellite link budget",
            "Doppler", "timing"
        ],
    },
    "uav_drone_rf": {
        "label": "UAV / Drone Systems / Datalink",
        "tier": "airborne_rf",
        "keywords": [
            "uav", "drone", "drones", "mavlink", "uas", "payload",
            "datalink", "c2 link", "remote id", "autopilot"
        ],
        "required_capabilities": [
            "UAV RF links", "MAVLink overview", "payload/datalink model",
            "controlled lab scenarios"
        ],
    },
    "sigint_intelligence": {
        "label": "SIGINT / Spectrum Intelligence",
        "tier": "intelligence",
        "keywords": [
            "sigint", "intelligence", "spectrum intelligence", "direction finding",
            "df", "classification", "intercept", "monitoring", "oscor", "emissions"
        ],
        "required_capabilities": [
            "spectrum intelligence", "signal classification", "DF/SIGINT workflow",
            "evidence handling"
        ],
    },
    "red_blue_purple_team": {
        "label": "Red / Blue / Purple Team / Cyber Range",
        "tier": "cyber_operations",
        "keywords": [
            "red team", "blueteam", "blue team", "purple team", "soc",
            "cyber", "attack", "defense", "incident", "threat", "mitre",
            "kill chain", "adversary", "detection", "response"
        ],
        "required_capabilities": [
            "SOC/NOC integration", "attack/defense scenarios", "incident timeline",
            "purple team evidence"
        ],
    },
    "electronics_instrumentation": {
        "label": "Electronics / Instrumentation / Lab",
        "tier": "lab_engineering",
        "keywords": [
            "electronics", "instrument", "instrumentation", "oscilloscope",
            "vna", "spectrum analyzer", "signal generator", "sdr", "hackrf",
            "keysight", "rohde", "tek", "anritsu", "lab", "bench"
        ],
        "required_capabilities": [
            "instrument inventory", "measurement setups", "SCPI/VISA",
            "RF lab workflow"
        ],
    },
    "academy_theory_simulation": {
        "label": "Academy / Theory / Simulations",
        "tier": "academic",
        "keywords": [
            "academy", "theory", "knowledge", "glossary", "lesson", "training",
            "simulation", "simulator", "formula", "handbook", "course", "tutorial"
        ],
        "required_capabilities": [
            "theory wall", "formula registry", "lesson plan", "simulation cockpit",
            "student workflow"
        ],
    },
}

DANGEROUS_PATTERNS = [
    "dangerouslySetInnerHTML",
    "innerHTML",
    "outerHTML",
    "insertAdjacentHTML",
    "document.write",
    "eval(",
    "new Function",
    "<iframe",
    "onload=",
    "onclick=",
    "onerror=",
    "localStorage",
]

VISUAL_KEYWORDS = [
    "canvas", "webgl", "svg", "chart", "spectrum", "waterfall", "3d",
    "radar", "map", "globe", "beam", "antenna", "tower", "dashboard",
    "cockpit", "control room", "matrix", "timeline", "topology"
]

def sha256_path(path: Path) -> str:
    try:
        h = hashlib.sha256()
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return "ERROR"

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""

def clean_cell(s):
    return str(s).replace("\t", " ").replace("\n", " ").replace("\r", " ").strip()

def extract_title(text, fallback):
    m = re.search(r"<title[^>]*>(.*?)</title>", text, flags=re.I | re.S)
    if m:
        return re.sub(r"\s+", " ", m.group(1)).strip()
    h = re.search(r"<h1[^>]*>(.*?)</h1>", text, flags=re.I | re.S)
    if h:
        return re.sub(r"<.*?>", "", re.sub(r"\s+", " ", h.group(1))).strip()
    return fallback

def score_domains(text):
    low = text.lower()
    scores = {}
    hits = {}
    for key, meta in TAXONOMY.items():
        score = 0
        found = []
        for kw in meta["keywords"]:
            k = kw.lower()
            if k in low:
                add = 10
                if len(k) <= 3:
                    add = 2
                if " " in k or "-" in k or "_" in k:
                    add += 6
                score += add
                found.append(kw)
        scores[key] = score
        hits[key] = found[:8]
    ordered = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    primary = ordered[0][0] if ordered and ordered[0][1] > 0 else "academy_theory_simulation"
    secondary = ordered[1][0] if len(ordered) > 1 and ordered[1][1] > 0 else ""
    return primary, secondary, scores, hits

def visual_score(text, path):
    low = text.lower()
    score = 0
    for kw in VISUAL_KEYWORDS:
        if kw in low:
            score += 4
    score += min(30, len(re.findall(r"<canvas\b", text, flags=re.I)) * 8)
    score += min(20, len(re.findall(r"<svg\b", text, flags=re.I)) * 5)
    score += min(15, len(re.findall(r"<section\b", text, flags=re.I)) * 2)
    score += min(10, len(re.findall(r"<button\b", text, flags=re.I)))
    if path.stat().st_size > 30000:
        score += 10
    if path.stat().st_size > 70000:
        score += 10
    return min(100, score)

def classify_role(text):
    low = text.lower()
    if any(x in low for x in ["control room", "dashboard", "command center", "mission control", "cockpit"]):
        return "operational_dashboard"
    if any(x in low for x in ["simulator", "simulation", "canvas", "webgl", "engine"]):
        return "simulator_or_visual_engine"
    if any(x in low for x in ["academy", "theory", "formula", "glossary", "lesson", "handbook"]):
        return "academy_theory"
    if any(x in low for x in ["evidence", "report", "audit", "qa", "quality"]):
        return "evidence_or_report"
    return "reference_or_legacy"

def maturity_for_html(text, path, vs):
    low = text.lower()
    danger_count = sum(low.count(p.lower()) for p in DANGEROUS_PATTERNS)
    if danger_count > 0:
        return "RISK_REVIEW"
    if "placeholder" in low or "lorem ipsum" in low:
        return "PLACEHOLDER_REVIEW"
    if vs >= 70 and path.stat().st_size >= 30000:
        return "REACT_READY_CANDIDATE"
    if vs >= 45:
        return "INTEGRATE_CANDIDATE"
    if path.stat().st_size < 6000:
        return "LOW_VALUE_REVIEW"
    return "REFERENCE_ONLY"

def recommendation_for(maturity, role, domain, vs):
    if maturity == "RISK_REVIEW":
        return "exclude_until_sanitized"
    if maturity == "REACT_READY_CANDIDATE":
        return "convert_to_react_domain_module"
    if maturity == "INTEGRATE_CANDIDATE":
        return "link_as_governed_source_then_improve"
    if maturity == "PLACEHOLDER_REVIEW":
        return "replace_or_expand_content"
    if maturity == "LOW_VALUE_REVIEW":
        return "do_not_promote_without_redesign"
    if role == "academy_theory":
        return "keep_as_academic_reference"
    return "keep_as_reference_evidence"

def write_tsv(path, header, rows):
    with path.open("w", encoding="utf-8") as f:
        f.write("\t".join(header) + "\n")
        for row in rows:
            f.write("\t".join(clean_cell(x) for x in row) + "\n")

public_rows = []
matrix_rows = []
risk_rows = []
candidate_rows = []
domain_counter = Counter()
maturity_counter = Counter()
role_counter = Counter()

html_files = sorted(PUBLIC.rglob("*.html")) if PUBLIC.exists() else []

for path in html_files:
    text = read_text(path)
    rel = path.relative_to(BASE)
    url = "/" + str(path.relative_to(PUBLIC))
    title = extract_title(text, path.stem)
    size = path.stat().st_size
    sha = sha256_path(path)
    canvas = len(re.findall(r"<canvas\b", text, flags=re.I))
    svg = len(re.findall(r"<svg\b", text, flags=re.I))
    script = len(re.findall(r"<script\b", text, flags=re.I))
    style = len(re.findall(r"<style\b", text, flags=re.I))
    links = len(re.findall(r"<a\b", text, flags=re.I))
    buttons = len(re.findall(r"<button\b", text, flags=re.I))
    sections = len(re.findall(r"<section\b", text, flags=re.I))
    iframe = len(re.findall(r"<iframe\b", text, flags=re.I))
    dangerous = sum(text.lower().count(p.lower()) for p in DANGEROUS_PATTERNS)
    external = len(re.findall(r"https?://", text, flags=re.I))
    cdn = len(re.findall(r"cdn\.|unpkg|jsdelivr|cdnjs", text, flags=re.I))
    return_nav = 1 if ("/#portal-os-preview" in text or "data-trfmc-return-nav" in text) else 0
    primary, secondary, scores, hits = score_domains(" ".join([title, url, str(rel), text[:200000]]))
    vs = visual_score(text, path)
    role = classify_role(text)
    maturity = maturity_for_html(text, path, vs)
    rec = recommendation_for(maturity, role, primary, vs)

    domain_counter[primary] += 1
    maturity_counter[maturity] += 1
    role_counter[role] += 1

    public_rows.append([
        rel, url, title, size, sha[:16], primary, secondary, role, maturity,
        vs, canvas, svg, script, style, links, buttons, sections,
        iframe, dangerous, external, cdn, return_nav, rec
    ])

    top_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)[:5]
    top_score_text = ";".join(f"{k}:{v}" for k, v in top_scores if v > 0)
    reason = ",".join(hits.get(primary, [])[:8])

    matrix_rows.append([
        url, title, primary, secondary, role, maturity, vs,
        canvas, script, dangerous, return_nav, top_score_text, reason, rec
    ])

    if dangerous or iframe or cdn or external:
        risk_rows.append([
            rel, url, title, primary, maturity, iframe, dangerous, external, cdn,
            "sanitize_before_promotion"
        ])

    if maturity in ("REACT_READY_CANDIDATE", "INTEGRATE_CANDIDATE"):
        candidate_rows.append([
            rel, url, title, primary, role, maturity, vs, canvas, script, rec
        ])

write_tsv(
    FILES["public_pages"],
    [
        "path", "url", "title", "bytes", "sha16", "primary_domain", "secondary_domain",
        "role", "maturity", "visual_score", "canvas", "svg", "script", "style",
        "links", "buttons", "sections", "iframe", "dangerous_dom", "external_refs",
        "cdn_refs", "return_nav", "recommendation"
    ],
    public_rows
)

write_tsv(
    FILES["page_matrix"],
    [
        "url", "title", "primary_domain", "secondary_domain", "role", "maturity",
        "visual_score", "canvas", "script", "dangerous_dom", "return_nav",
        "top_scores", "reason_hits", "recommendation"
    ],
    matrix_rows
)

write_tsv(
    FILES["source_risk"],
    [
        "path", "url", "title", "primary_domain", "maturity", "iframe",
        "dangerous_dom", "external_refs", "cdn_refs", "action"
    ],
    risk_rows
)

write_tsv(
    FILES["candidate_backlog"],
    [
        "path", "url", "title", "primary_domain", "role", "maturity",
        "visual_score", "canvas", "script", "next_action"
    ],
    sorted(candidate_rows, key=lambda r: (-int(r[6]), r[3], r[2]))
)

component_rows = []
component_counter = Counter()
risk_component_count = 0

component_files = []
if SRC.exists():
    component_files = sorted(list(SRC.rglob("*.tsx")) + list(SRC.rglob("*.jsx")))

for path in component_files:
    text = read_text(path)
    rel = path.relative_to(BASE)
    exports = len(re.findall(r"\bexport\s+default\b|\bexport\s+function\b|\bexport\s+const\b", text))
    imports = len(re.findall(r"^\s*import\s+", text, flags=re.M))
    markers = len(re.findall(r"data-trfmc-[a-zA-Z0-9_-]+", text))
    canvas = text.lower().count("<canvas")
    dangerous = sum(text.lower().count(p.lower()) for p in DANGEROUS_PATTERNS)
    primary, secondary, scores, hits = score_domains(" ".join([str(rel), text[:150000]]))
    role = classify_role(text)
    component_counter[primary] += 1
    if dangerous:
        risk_component_count += 1
    component_rows.append([
        rel, primary, secondary, role, exports, imports, markers,
        canvas, dangerous, ",".join(hits.get(primary, [])[:8])
    ])

write_tsv(
    FILES["react_components"],
    [
        "path", "primary_domain", "secondary_domain", "role", "exports",
        "imports", "trfmc_markers", "canvas_refs", "dangerous_dom", "reason_hits"
    ],
    component_rows
)

backend_rows = []
api_counter = Counter()
backend_files = sorted(BACKEND.rglob("*.py")) if BACKEND.exists() else []

route_regexes = [
    re.compile(r"@(?:app|router|api)\.(get|post|put|patch|delete)\(\s*['\"]([^'\"]+)['\"]", re.I),
    re.compile(r"\b(?:app|router|api)\.add_api_route\(\s*['\"]([^'\"]+)['\"]", re.I),
]

for path in backend_files:
    text = read_text(path)
    rel = path.relative_to(BASE)
    routes = []
    for m in route_regexes[0].finditer(text):
        routes.append((m.group(1).upper(), m.group(2)))
    for m in route_regexes[1].finditer(text):
        routes.append(("ROUTE", m.group(1)))

    websocket_routes = re.findall(r"@(?:app|router|api)\.websocket\(\s*['\"]([^'\"]+)['\"]", text, flags=re.I)
    for r in websocket_routes:
        routes.append(("WS", r))

    for method, route in routes:
        primary, secondary, scores, hits = score_domains(" ".join([str(rel), route, text[:5000]]))
        api_counter[primary] += 1
        backend_rows.append([rel, method, route, primary, secondary, ",".join(hits.get(primary, [])[:8])])

write_tsv(
    FILES["backend_api"],
    ["path", "method", "route", "primary_domain", "secondary_domain", "reason_hits"],
    backend_rows
)

taxonomy_export = {
    "timestamp": TS,
    "principle": "single_master_portal_os_with_domain_drilldown_not_page_sprawl",
    "domains": TAXONOMY,
    "promotion_states": [
        "REFERENCE_ONLY",
        "LOW_VALUE_REVIEW",
        "PLACEHOLDER_REVIEW",
        "INTEGRATE_CANDIDATE",
        "REACT_READY_CANDIDATE",
        "RISK_REVIEW"
    ],
    "mandatory_home_axes": [
        "geographic",
        "technology",
        "operations",
        "academy",
        "instrumentation",
        "evidence"
    ]
}
FILES["domain_taxonomy"].write_text(json.dumps(taxonomy_export, indent=2, ensure_ascii=False), encoding="utf-8")

missing_domains = [k for k in TAXONOMY if domain_counter[k] == 0]
weak_domains = [k for k in TAXONOMY if 0 < domain_counter[k] <= 2]
strong_domains = [k for k in TAXONOMY if domain_counter[k] >= 5]

avg_visual = 0
if public_rows:
    avg_visual = round(sum(int(r[9]) for r in public_rows) / len(public_rows), 2)

pages_without_return = sum(1 for r in public_rows if str(r[21]) == "0")
risk_pages = len(risk_rows)
react_candidates = sum(1 for r in public_rows if r[8] == "REACT_READY_CANDIDATE")
integrate_candidates = sum(1 for r in public_rows if r[8] == "INTEGRATE_CANDIDATE")

visual_md = []
visual_md.append("# TRFMC P8A Visual Gap Analysis\n")
visual_md.append("## Sintesi dura\n")
visual_md.append(f"- Pagine HTML pubbliche inventariate: **{len(public_rows)}**\n")
visual_md.append(f"- Componenti React inventariati: **{len(component_rows)}**\n")
visual_md.append(f"- API/route backend rilevate: **{len(backend_rows)}**\n")
visual_md.append(f"- Visual score medio: **{avg_visual}/100**\n")
visual_md.append(f"- Pagine senza return/nav verso Portal OS: **{pages_without_return}**\n")
visual_md.append(f"- Pagine con rischio DOM/iframe/external/CDN: **{risk_pages}**\n")
visual_md.append(f"- Candidate React-ready: **{react_candidates}**\n")
visual_md.append(f"- Candidate da integrare ma non ancora convertire: **{integrate_candidates}**\n\n")

visual_md.append("## Distribuzione domini\n")
for key, meta in TAXONOMY.items():
    visual_md.append(f"- **{meta['label']}**: HTML={domain_counter[key]}, React={component_counter[key]}, API={api_counter[key]}\n")

visual_md.append("\n## Domini mancanti o deboli\n")
if missing_domains:
    visual_md.append("### Mancanti\n")
    for key in missing_domains:
        visual_md.append(f"- {TAXONOMY[key]['label']}\n")
else:
    visual_md.append("- Nessun dominio completamente vuoto a livello HTML.\n")

if weak_domains:
    visual_md.append("\n### Deboli\n")
    for key in weak_domains:
        visual_md.append(f"- {TAXONOMY[key]['label']} — poche sorgenti: {domain_counter[key]}\n")

visual_md.append("\n## Problemi strutturali da correggere\n")
visual_md.append("- Non promuovere più pagine solo perché hanno HTTP 200.\n")
visual_md.append("- Non creare ulteriori pagine per area: serve una sola home madre con drill-down interno.\n")
visual_md.append("- Ogni sorgente legacy deve avere stato: reference, improve, integrate, React-ready, broken.\n")
visual_md.append("- Le pagine prive di return/nav vanno corrette prima della promozione.\n")
visual_md.append("- Le pagine con DOM injection, iframe, CDN o link esterni vanno escluse dalla promozione fino a sanificazione.\n")
visual_md.append("- La grafica finale deve mostrare subito RF, Telco, Cyber, Intelligence, Academy e Instrumentation.\n")

FILES["visual_gap"].write_text("".join(visual_md), encoding="utf-8")

blueprint = f"""# TRFMC Enterprise Portal Blueprint

## Decisione architetturale

Il portale non deve essere una raccolta di pagine. Deve diventare un sistema operativo accademico-operativo con una home madre e drill-down interni.

## Nome operativo

TRFMC Academy / Operations Center

## Assi obbligatori della home

1. Geographic Layer
   - Lab / Olginate
   - Europe / Mediterranean
   - Americas
   - APAC / Indo-Pacific
   - Africa / Middle East
   - NTN / Space

2. Technology Layer
   - RF / Microwave
   - Antenna / RRU / RET / CPRI / AISG
   - Signal / DSP / Measurement
   - 2G / 3G / 4G / EPC
   - 5G NR / 5GC / Open5GS / UERANSIM
   - O-RAN / SMO / RIC / xApps / rApps
   - Satellite / NTN
   - UAV / Drone Systems
   - Electronics / Instrumentation

3. Operations Layer
   - NOC
   - SOC
   - SIGINT
   - Red Team
   - Blue Team
   - Purple Team
   - Evidence
   - Incident timeline

4. Academy Layer
   - Theory
   - Formulas
   - Protocols
   - Simulations
   - Lesson plan
   - Practical labs

5. Instrumentation Layer
   - SDR
   - Spectrum analyzer
   - VNA
   - Oscilloscope
   - Signal generator
   - Open5GS / UERANSIM
   - API / logs / captures

## Layout corretto primo viewport

- Top Command Bar:
  backend, bridge, proxy, build, evidence, readiness, runtime.

- Central Operational Theater:
  telco site, RF beam, spectrum, satellite, UAV, 5G core, cyber/SIGINT overlay.

- Domain Matrix:
  tutte le macro-aree, con stato: missing / weak / reference / integrate / React-ready.

- Right Operations Wall:
  event stream, incident posture, Red/Blue/Purple state, evidence queue.

- Bottom Academy Wall:
  formule, teoria, protocolli, simulatori, strumenti.

## Regola di promozione

Una pagina legacy non entra nella home se non ha:
- dominio tecnico chiaro;
- valore visivo o didattico;
- return/nav;
- assenza di DOM pericoloso;
- stato QA;
- ruolo definito: evidence, reference, simulator, dashboard, module.

## Regola React

React deve ricevere solo moduli maturi:
- War Room / NOC
- Signal / DSP
- Antenna / RRU / RET / CPRI
- 5G Core / Open5GS / UERANSIM
- RF / Microwave Engineering
- SIGINT / Intelligence
- Red/Blue/Purple Team

## Output P8A

Questo audit produce la mappa reale da cui partire, non una nuova dashboard.
"""

FILES["blueprint"].write_text(blueprint, encoding="utf-8")

plan = f"""# TRFMC P8 Next Implementation Plan

## P8A — Master audit read-only

Stato: generato da questo script.

Output principali:
- summary.json
- public_pages_inventory.tsv
- react_components_inventory.tsv
- backend_api_inventory.tsv
- page_to_domain_matrix.tsv
- visual_gap_analysis.md
- enterprise_portal_blueprint.md
- next_implementation_plan.md

## P8B — Decision Gate

Leggere:
1. visual_gap_analysis.md
2. candidate_backlog.tsv
3. source_risk_register.tsv
4. page_to_domain_matrix.tsv

Decisione:
- quali domini sono forti;
- quali sono vuoti;
- quali pagine sono solo reference;
- quali sono candidate React;
- quali pagine vanno escluse.

## P8C — Master Home Design, non codice

Prima di scrivere HTML/React:
- wireframe definitivo;
- palette;
- primo viewport;
- domain matrix;
- operational theater;
- academy wall;
- instrumentation wall.

## P8D — Una sola home madre

Creare una sola entry:
- /trfmc_academy_operations_center_v1.html oppure componente React equivalente.

Non creare altre pagine area.

## P8E — Collegamento controllato al Portal OS

Aggiungere un solo entrypoint:
- Academy Operations Center

## P8F — Bonifica pagina per pagina

Per ogni pagina:
- OK
- IMPROVE
- INTEGRATE
- REACT_READY
- BROKEN

## P8G — Conversione React

Solo dopo P8F.
"""

FILES["plan"].write_text(plan, encoding="utf-8")

summary = {
    "timestamp": TS,
    "operation": "TRFMC_P8A_MASTER_PORTAL_AUDIT_READONLY_V1",
    "mutation": False,
    "source_mutation": False,
    "backend_mutation": False,
    "react_mutation": False,
    "public_html_count": len(public_rows),
    "react_component_count": len(component_rows),
    "backend_route_count": len(backend_rows),
    "domain_counts_html": dict(domain_counter),
    "domain_counts_react": dict(component_counter),
    "domain_counts_api": dict(api_counter),
    "maturity_counts": dict(maturity_counter),
    "role_counts": dict(role_counter),
    "visual_score_avg": avg_visual,
    "pages_without_return_nav": pages_without_return,
    "risk_pages": risk_pages,
    "risk_components": risk_component_count,
    "react_ready_candidates": react_candidates,
    "integrate_candidates": integrate_candidates,
    "missing_domains": missing_domains,
    "weak_domains": weak_domains,
    "strong_domains": strong_domains,
    "outputs": {k: str(v) for k, v in FILES.items()},
    "result": "PASS_READONLY_AUDIT"
}

FILES["summary"].write_text(json.dumps(summary, indent=4, ensure_ascii=False), encoding="utf-8")

print(json.dumps(summary, indent=4, ensure_ascii=False))
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p8a_master_portal_audit_readonly_v1"

echo
echo "============================================================"
echo "TRFMC_P8A_MASTER_PORTAL_AUDIT_READONLY_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
