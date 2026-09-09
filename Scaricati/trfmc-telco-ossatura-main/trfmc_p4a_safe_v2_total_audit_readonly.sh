#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4A_SAFE_V2_TOTAL_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
HTML_INV="$OUT/html_inventory.tsv"
HTML_CLASS="$OUT/html_classification.tsv"
REACT_INV="$OUT/react_inventory.tsv"
ROUTES="$OUT/route_inventory.tsv"
SHELL="$OUT/shell_duplication_scan.tsv"
BACKEND="$OUT/backend_api_inventory.tsv"
PROMOTED="$OUT/promoted_domains.tsv"
V63="$OUT/v63_reference_scan.tsv"
RISK="$OUT/runtime_risk_scan.tsv"
MANIFEST="$OUT/portal_manifest_draft.json"
PLAN="$OUT/PORTAL_OS_TARGET_PLAN.md"
TREE="$OUT/project_tree_relevant.txt"

echo "============================================================"
echo "TRFMC_P4A_SAFE_V2_TOTAL_AUDIT_READONLY"
echo "Read-only total architecture audit - no mutation"
echo "Timestamp: $TS"
echo "============================================================"

find frontend backend runtime -maxdepth 6 \
  \( -name '*.html' -o -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' -o -name '*.py' -o -name '*.json' -o -name '*.css' \) \
  2>/dev/null | sort > "$TREE" || true

python3 - "$BASE" "$OUT" "$HTML_INV" "$HTML_CLASS" "$REACT_INV" "$ROUTES" "$SHELL" "$BACKEND" "$PROMOTED" "$V63" "$RISK" "$MANIFEST" "$PLAN" "$SUMMARY" <<'PY'
import csv
import json
import re
import sys
from pathlib import Path
from html.parser import HTMLParser

base = Path(sys.argv[1])
out = Path(sys.argv[2])
html_inv = Path(sys.argv[3])
html_class = Path(sys.argv[4])
react_inv = Path(sys.argv[5])
routes_out = Path(sys.argv[6])
shell_out = Path(sys.argv[7])
backend_out = Path(sys.argv[8])
promoted_out = Path(sys.argv[9])
v63_out = Path(sys.argv[10])
risk_out = Path(sys.argv[11])
manifest_out = Path(sys.argv[12])
plan_out = Path(sys.argv[13])
summary_out = Path(sys.argv[14])

def rel(p):
    try:
        return str(p.relative_to(base))
    except Exception:
        return str(p)

def read_text(p):
    return p.read_text(encoding="utf-8", errors="replace")

class H(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tags = {}
        self.assets = []
        self.inline_handlers = 0

    def handle_starttag(self, tag, attrs):
        self.tags[tag] = self.tags.get(tag, 0) + 1
        attrs = dict(attrs)
        for k in ("src", "href"):
            if k in attrs:
                self.assets.append(attrs[k])
        for k in attrs:
            if k.lower().startswith("on"):
                self.inline_handlers += 1

def title_h1(s):
    title = "-"
    h1 = "-"
    mt = re.search(r"<title[^>]*>(.*?)</title>", s, re.I | re.S)
    if mt:
        title = " ".join(re.sub(r"<.*?>", " ", mt.group(1)).split())[:160]
    mh = re.search(r"<h1[^>]*>(.*?)</h1>", s, re.I | re.S)
    if mh:
        h1 = " ".join(re.sub(r"<.*?>", " ", mh.group(1)).split())[:160]
    return title, h1

rules = [
    ("command-center-shell", ["command center", "safe entrypoint", "master console", "operational modules", "quick load", "event stream"]),
    ("3d-rf-visual-twin", ["3d", "webgl", "visual twin", "asset renderer", "tower site", "gltf", "glb"]),
    ("rf-metrology", ["metrology", "calibration", "uncertainty", "phase noise", "attenuator"]),
    ("fft-dsp-signal", ["fft", "gapless", "dsp", "spectrum", "waterfall", "iq", "constellation", "evm"]),
    ("signal-intelligence", ["signal intelligence", "sigint", "classifier", "wideband", "df"]),
    ("antenna-system", ["antenna", "rru", "ret", "cpri", "aisg", "mimo", "beam", "radiation", "downtilt"]),
    ("wifi-qam", ["wifi", "wi-fi", "qam", "ofdm", "802.11", "mlo"]),
    ("5g-core-ran", ["5g core", "open5gs", "ueransim", "supi", "suci", "imsi", "aka", "ngap", "pfcp", "gtp-u", "ran"]),
    ("noc-operations", ["noc", "alarm", "health", "operations", "topology"]),
    ("war-room", ["war room", "cyber rf", "attack", "scenario", "evidence"]),
    ("knowledge-academy", ["academy", "knowledge", "theory", "formula", "training", "glossary"]),
    ("fiber-optic", ["fiber", "otdr", "odf", "splice", "optical"]),
    ("microwave-link", ["microwave", "link budget", "dish", "waveguide", "fresnel"]),
]

def classify(name, text):
    low = (name + "\n" + text[:250000]).lower()
    best = ("legacy-generic", 0)
    for cat, terms in rules:
        score = sum(1 for t in terms if t in low)
        if score > best[1]:
            best = (cat, score)
    return best

def mode_for(html, category):
    low = html.lower()
    if "safe entrypoint" in low or "command center" in low or "master console" in low:
        return "core-shell-reference"
    if "<iframe" in low:
        return "legacy-leaf-review"
    if "innerhtml" in low or "document.write" in low or "document.body" in low:
        return "reference-only-risk"
    if "<canvas" in low or "webgl" in low or "three" in low:
        return "promote-to-react-visual-leaf"
    if category in ("5g-core-ran", "noc-operations", "war-room"):
        return "promote-to-react-operational-leaf"
    return "reference-or-promote"

def write_tsv(path, rows, fields):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
        w.writeheader()
        for r in rows:
            w.writerow(r)

html_rows = []
class_rows = []
manifest_modules = []

public_dir = base / "frontend" / "public"
for p in sorted(public_dir.glob("*.html")) if public_dir.exists() else []:
    s = read_text(p)
    hp = H()
    try:
        hp.feed(s)
    except Exception:
        pass

    title, h1 = title_h1(s)
    category, score = classify(p.name, s)
    mode = mode_for(s, category)
    low = s.lower()
    shell_score = sum(1 for t in [
        "command center", "operational modules", "quick load", "event stream",
        "command / evidence", "health", "reload", "graph", "master console"
    ] if t in low)
    is_v63 = "v63" in p.name.lower() or "v63" in low or "safe entrypoint" in low

    item = {
        "path": rel(p),
        "bytes": p.stat().st_size,
        "lines": len(s.splitlines()),
        "title": title,
        "h1": h1,
        "canvas": hp.tags.get("canvas", 0),
        "iframe": hp.tags.get("iframe", 0),
        "script": hp.tags.get("script", 0),
        "style": hp.tags.get("style", 0),
        "inline_handlers": hp.inline_handlers,
        "asset_refs": len(hp.assets),
        "category": category,
        "category_score": score,
        "mode": mode,
        "shell_score": shell_score,
        "is_v63": "YES" if is_v63 else "NO",
    }
    html_rows.append(item)

    priority = "P0_CORE_REFERENCE" if is_v63 or shell_score >= 6 else ("P1_VISUAL_LEAF" if "visual" in mode else "P2_REVIEW")
    route = "#" + re.sub(r"[^a-z0-9]+", "-", p.stem.lower()).strip("-")

    class_rows.append({
        "path": rel(p),
        "category": category,
        "score": score,
        "mode": mode,
        "route_guess": route,
        "shell_score": shell_score,
        "priority": priority,
        "title": title,
    })

    manifest_modules.append({
        "id": re.sub(r"[^a-z0-9]+", "-", p.stem.lower()).strip("-"),
        "title": title if title != "-" else p.stem,
        "source": rel(p),
        "category": category,
        "mode": mode,
        "routeGuess": route,
        "shellScore": shell_score,
        "isV63Candidate": bool(is_v63),
        "canvas": hp.tags.get("canvas", 0),
        "iframe": hp.tags.get("iframe", 0),
    })

src_dir = base / "frontend" / "src"
react_rows = []
route_rows = []
shell_rows = []
risk_rows = []

source_files = []
if src_dir.exists():
    for ext in ("*.tsx", "*.ts", "*.jsx", "*.js", "*.css"):
        source_files.extend(src_dir.rglob(ext))

for p in sorted(source_files):
    s = read_text(p)
    category, score = classify(p.name, s)
    react_rows.append({
        "path": rel(p),
        "bytes": p.stat().st_size,
        "lines": len(s.splitlines()),
        "imports": len(re.findall(r"^\s*import\s+", s, re.M)),
        "exports": len(re.findall(r"\bexport\s+", s)),
        "hooks": len(re.findall(r"\buse[A-Z][A-Za-z0-9_]*\s*\(", s)),
        "data_markers": len(re.findall(r"data-trfmc-[A-Za-z0-9_-]+", s)),
        "hash_refs": len(re.findall(r"#[A-Za-z0-9][A-Za-z0-9_-]+", s)),
        "category": category,
        "score": score,
    })

    for m in re.finditer(r"#[A-Za-z0-9][A-Za-z0-9_-]+", s):
        route_rows.append({
            "route": m.group(0),
            "path": rel(p),
            "line": s[:m.start()].count("\n") + 1,
            "context": s[max(0, m.start()-70):m.end()+70].replace("\n", " ")[:220],
        })

scan_files = list(source_files)
if public_dir.exists():
    scan_files += list(public_dir.glob("*.html"))

shell_terms = [
    "TELCO RF MISSION CONTROL PLATFORM",
    "TRFMC V63 COMMAND CENTER",
    "Operational Modules",
    "Command / Evidence",
    "Event Stream",
    "Quick Load",
    "Mission Layout Orchestrator",
    "Engineering Orchestrator",
    "mc-shell",
    "statusbar",
    "sidebar",
    "portal shell",
]

for p in sorted(scan_files):
    s = read_text(p)
    low = s.lower()

    for term in shell_terms:
        c = low.count(term.lower())
        if c:
            shell_rows.append({
                "term": term,
                "count": c,
                "path": rel(p),
                "interpretation": "DUPLICATE_SHELL_REVIEW",
            })

    for idx, line in enumerate(s.splitlines(), 1):
        checks = [
            ("iframe", r"<iframe"),
            ("dangerous_dom", r"dangerouslySetInnerHTML|\.innerHTML\s*=|document\.write|document\.body"),
            ("external_url", r"https?://"),
            ("cdn", r"unpkg|jsdelivr|cdnjs|cdn\."),
            ("html_runtime_link", r"\.html['\"]|\.html#|href=['\"][^'\"]+\.html"),
        ]
        for label, pat in checks:
            if re.search(pat, line, re.I):
                risk_rows.append({
                    "risk": label,
                    "path": rel(p),
                    "line": idx,
                    "match": line.strip()[:240],
                })

backend_rows = []
backend_dir = base / "backend"
if backend_dir.exists():
    for p in sorted(backend_dir.rglob("*.py")):
        s = read_text(p)
        for idx, line in enumerate(s.splitlines(), 1):
            if re.search(r"@(app|router)\.(get|post|put|delete|websocket)\s*\(", line) or "APIRouter" in line:
                m = re.search(r"['\"](/[^'\"]*)['\"]", line)
                backend_rows.append({
                    "path": rel(p),
                    "line": idx,
                    "api_path": m.group(1) if m else "-",
                    "code": line.strip()[:240],
                })

promoted_markers = [
    ("P0B", "data-trfmc-p0b-portal-navigation"),
    ("P0C", "data-trfmc-p0c-mission-control-content"),
    ("P1B_RF_PHYSICS", "data-trfmc-p1-rf-physics-domain"),
    ("P2B_SIGNAL_ANALYZER", "data-trfmc-p2-signal-analyzer-domain"),
    ("P3B_ANTENNA_SYSTEM", "data-trfmc-p3-antenna-system-domain"),
    ("P1D_BAD_ROUTE_ISOLATION", "data-trfmc-p1d-route-isolation"),
]

promoted_rows = []
for label, marker in promoted_markers:
    files = []
    for p in sorted(source_files):
        if marker in read_text(p):
            files.append(rel(p))
    promoted_rows.append({
        "label": label,
        "marker": marker,
        "count_files": len(files),
        "files": " | ".join(files[:10]) if files else "-",
    })

v63_rows = []
for r in html_rows:
    if r["is_v63"] == "YES" or int(r["shell_score"]) >= 5:
        decision = "PRIMARY_PORTAL_OS_VISUAL_REFERENCE" if r["is_v63"] == "YES" or int(r["shell_score"]) >= 6 else "SECONDARY_SHELL_REFERENCE"
        v63_rows.append({
            "path": r["path"],
            "title": r["title"],
            "category": r["category"],
            "mode": r["mode"],
            "shell_score": r["shell_score"],
            "canvas": r["canvas"],
            "iframe": r["iframe"],
            "decision": decision,
        })

write_tsv(html_inv, html_rows, ["path","bytes","lines","title","h1","canvas","iframe","script","style","inline_handlers","asset_refs","category","category_score","mode","shell_score","is_v63"])
write_tsv(html_class, class_rows, ["path","category","score","mode","route_guess","shell_score","priority","title"])
write_tsv(react_inv, react_rows, ["path","bytes","lines","imports","exports","hooks","data_markers","hash_refs","category","score"])
write_tsv(routes_out, route_rows, ["route","path","line","context"])
write_tsv(shell_out, shell_rows, ["term","count","path","interpretation"])
write_tsv(backend_out, backend_rows, ["path","line","api_path","code"])
write_tsv(promoted_out, promoted_rows, ["label","marker","count_files","files"])
write_tsv(v63_out, v63_rows, ["path","title","category","mode","shell_score","canvas","iframe","decision"])
write_tsv(risk_out, risk_rows, ["risk","path","line","match"])

manifest_modules.sort(key=lambda x: (not x["isV63Candidate"], -x["shellScore"], x["category"], x["source"]))

manifest = {
    "operation": "TRFMC_P4A_SAFE_V2_TOTAL_AUDIT_READONLY",
    "policy": {
        "singleSpa": True,
        "v63VisualModel": True,
        "noV42AsFinalRoot": True,
        "legacyHtmlAsSourceNotPortal": True,
        "noIframeAsArchitecture": True
    },
    "targetPortalOS": {
        "root": "frontend/src/portal-os",
        "previewRoute": "#portal-os-preview",
        "finalRoot": "PortalOSRoot",
        "frame": "PortalOSFrame",
        "home": "PortalOSHome",
        "viewport": "PortalOSModuleViewport",
        "dataFabric": "PortalOSDataFabric"
    },
    "modules": manifest_modules
}
manifest_out.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

plan_lines = [
    "# TRFMC P4A SAFE V2 - Portal OS Target Plan",
    "",
    "## Esito operativo",
    "",
    "Il progetto deve essere rifondato su un Portal OS unico, usando V63 Command Center come riferimento visuale e operativo.",
    "",
    "## Problema da correggere",
    "",
    "I domini React promossi sono validi come componenti, ma oggi vivono dentro shell/orchestrator esistenti. Questo genera effetto portali dentro portali.",
    "",
    "## Regole",
    "",
    "- V42 non deve essere il root finale.",
    "- V63 e Command Center sono il modello operativo.",
    "- frontend/public/*.html resta sorgente/reference/leaf, non home definitiva.",
    "- Una sola shell, un solo manifest, un solo data fabric, un solo viewport moduli.",
    "- Nessuna route isolation testuale dentro V42.",
    "",
    "## Struttura target",
    "",
    "frontend/src/portal-os/",
    "  portalManifest.ts",
    "  PortalOSRoot.tsx",
    "  PortalOSFrame.tsx",
    "  PortalOSHome.tsx",
    "  PortalOSRouter.tsx",
    "  PortalOSDataFabric.tsx",
    "  PortalOSModuleLauncher.tsx",
    "  PortalOSModuleViewport.tsx",
    "  PortalOSEvidencePanel.tsx",
    "  PortalOSStatusBar.tsx",
    "  PortalOSCommandCenterModel.ts",
    "",
    "## Prossimo step",
    "",
    "P4B_PORTAL_OS_SKELETON_PREVIEW_V1: creare preview su #portal-os-preview senza sostituire la home attuale.",
]
plan_out.write_text("\n".join(plan_lines) + "\n", encoding="utf-8")

summary = {
    "timestamp": out.name.replace("TRFMC_P4A_SAFE_V2_TOTAL_AUDIT_READONLY_", ""),
    "operation": "TRFMC_P4A_SAFE_V2_TOTAL_AUDIT_READONLY",
    "mutation": False,
    "out": str(out),
    "html_count": len(html_rows),
    "react_source_count": len(react_rows),
    "route_occurrences": len(route_rows),
    "shell_duplication_hits": len(shell_rows),
    "backend_api_rows": len(backend_rows),
    "runtime_risk_rows": len(risk_rows),
    "v63_reference_rows": len(v63_rows),
    "primary_v63_reference": v63_rows[0]["path"] if v63_rows else "-",
    "manifest": str(manifest_out),
    "plan": str(plan_out),
    "result": "P4A_SAFE_V2_AUDIT_READY"
}
summary_out.write_text(json.dumps(summary, indent=4, ensure_ascii=False), encoding="utf-8")
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4a_safe_v2_total_audit_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== V63 REFERENCE ==="
column -t -s $'\t' "$V63" | sed -n '1,80p'

echo
echo "=== HTML CLASSIFICATION HEAD ==="
column -t -s $'\t' "$HTML_CLASS" | sed -n '1,120p'

echo
echo "=== PROMOTED DOMAINS ==="
column -t -s $'\t' "$PROMOTED"

echo
echo "============================================================"
echo "TRFMC_P4A_SAFE_V2_TOTAL_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
