#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_NAVIGATION_INVENTORY_AUDIT_V39A_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_NAVIGATION_INVENTORY_AUDIT_V39A_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_NAVIGATION_INVENTORY_AUDIT_V39A_$TS.tar.gz"

mkdir -p "$QDIR" "$RDIR" runtime/freezes

echo "============================================================"
echo "TRFMC NAVIGATION INVENTORY AUDIT V39A"
echo "read-only · HTML/React/asset inventory · navigation map plan"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f frontend/src/app/main.tsx || {
  echo "ERRORE: frontend/src/app/main.tsx mancante"
  exit 1
}

test -f runtime/quality/latest_unified_design_system_v38/summary.json || {
  echo "ERRORE: V38 summary mancante"
  exit 1
}

V38_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_unified_design_system_v38/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V38_RESULT" = "PASS" ] || {
  echo "ERRORE: V38 non PASS: $V38_RESULT"
  exit 1
}

grep -q "RFOperationalDeckV37CommandCenterFusion" frontend/src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V37"
  grep -n "RFOperationalDeck" frontend/src/app/main.tsx || true
  exit 1
}

echo "OK: V38 PASS e ramo attivo V37"

echo
echo "=== RUN INVENTORY ==="

python3 - "$ROOT" "$RDIR" "$TS" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from html.parser import HTMLParser

root = Path(sys.argv[1]).resolve()
rdir = Path(sys.argv[2]).resolve()
ts = sys.argv[3]

frontend = root / "frontend"
src = frontend / "src"
public = frontend / "public"
dist = frontend / "dist"

class SimpleHTMLParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title = ""
        self._title = False
        self.links = []
        self.scripts = []
        self.styles = []
        self.iframes = []
        self.images = []
        self.ids = []
        self.classes = []
        self.text = []

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag == "title":
            self._title = True
        if tag == "a":
            self.links.append(d.get("href", ""))
        elif tag == "script":
            self.scripts.append(d.get("src", "__inline__"))
        elif tag == "link":
            self.styles.append(d.get("href", ""))
        elif tag == "iframe":
            self.iframes.append(d.get("src", ""))
        elif tag == "img":
            self.images.append(d.get("src", ""))
        if "id" in d:
            self.ids.append(d["id"])
        if "class" in d:
            self.classes.extend(str(d["class"]).split())

    def handle_endtag(self, tag):
        if tag == "title":
            self._title = False

    def handle_data(self, data):
        clean = " ".join(data.split())
        if self._title:
            self.title += clean
        if clean:
            self.text.append(clean)

def rel(p: Path) -> str:
    try:
        return str(p.relative_to(root))
    except Exception:
        return str(p)

def analyze_html(p: Path):
    text = p.read_text(encoding="utf-8", errors="ignore")
    parser = SimpleHTMLParser()
    parser.feed(text)

    keywords = []
    low = text.lower()
    for k in [
        "mission", "command", "control", "rf", "spectrum", "signal", "antenna",
        "microwave", "fiber", "private", "core", "open5gs", "ueransim",
        "ran", "soc", "noc", "cyber", "knowledge", "dashboard", "protocol",
        "waterfall", "iq", "constellation", "uav", "hackrf", "sdr", "5g"
    ]:
        if k in low:
            keywords.append(k)

    external_refs = []
    for item in parser.links + parser.scripts + parser.styles + parser.iframes + parser.images:
        if re.search(r"https?://|//cdn\.|cdnjs|unpkg|jsdelivr|fonts\.googleapis", item or "", re.I):
            external_refs.append(item)

    return {
        "path": rel(p),
        "name": p.name,
        "size_bytes": p.stat().st_size,
        "title": parser.title,
        "keywords": keywords,
        "link_count": len(parser.links),
        "script_count": len(parser.scripts),
        "style_count": len(parser.styles),
        "iframe_count": len(parser.iframes),
        "image_count": len(parser.images),
        "external_ref_count": len(set(external_refs)),
        "links_sample": parser.links[:40],
        "iframes": parser.iframes,
        "ids_sample": parser.ids[:40],
        "classes_sample": sorted(set(parser.classes))[:40],
    }

html_pages = []
for base in [public, dist, frontend]:
    if not base.exists():
        continue
    for p in base.rglob("*.html"):
        if "node_modules" in p.parts:
            continue
        try:
            html_pages.append(analyze_html(p))
        except Exception as e:
            html_pages.append({"path": rel(p), "error": str(e)})

# De-duplicate by path
html_pages = sorted({h["path"]: h for h in html_pages}.values(), key=lambda x: x.get("path",""))

react_files = []
component_rx = re.compile(r"export\s+(?:function|const)\s+([A-Z][A-Za-z0-9_]+)")
import_rx = re.compile(r"import\s+.*?from\s+['\"]([^'\"]+)['\"]")
endpoint_rx = re.compile(r"['\"](/api/[A-Za-z0-9_\-./{}:?=&%]+)['\"]")
route_rx = re.compile(r"(?:path|href|to)\s*=\s*['\"]([^'\"]+)['\"]")

for p in src.rglob("*"):
    if p.suffix not in {".tsx", ".ts", ".jsx", ".js"}:
        continue
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue

    components = component_rx.findall(text)
    imports = import_rx.findall(text)
    endpoints = endpoint_rx.findall(text)
    has_react = "react" in text.lower() or p.suffix in {".tsx", ".jsx"}

    signals = []
    for k in [
        "RFOperationalDeck", "CommandCenter", "RFDynamicScenario", "LiveContract",
        "RFInstrument", "Spectrum", "Waterfall", "IQ", "BridgeReadiness",
        "Open5GS", "UERANSIM", "Mission", "Knowledge", "Navigation"
    ]:
        if k.lower() in text.lower():
            signals.append(k)

    react_files.append({
        "path": rel(p),
        "size_bytes": p.stat().st_size,
        "components": sorted(set(components)),
        "component_count": len(set(components)),
        "imports_count": len(imports),
        "endpoints": sorted(set(endpoints)),
        "endpoint_count": len(set(endpoints)),
        "signals": signals,
        "has_react": has_react,
    })

react_files = sorted(react_files, key=lambda x: (-x["component_count"], x["path"]))

# Extract current active chain
main = (src / "app/main.tsx").read_text(encoding="utf-8", errors="ignore")
active_imports = []
for line_no, line in enumerate(main.splitlines(), start=1):
    if "RFOperationalDeck" in line or "CommandCenter" in line:
        active_imports.append({"line": line_no, "text": line.strip()})

# Public assets inventory
asset_ext = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".json", ".glb", ".gltf"}
assets = []
if public.exists():
    for p in public.rglob("*"):
        if p.is_file() and p.suffix.lower() in asset_ext:
            assets.append({
                "path": rel(p),
                "size_bytes": p.stat().st_size,
                "ext": p.suffix.lower(),
            })
assets = sorted(assets, key=lambda x: (x["ext"], x["path"]))

official_domains = [
    {
        "id": "mission-control",
        "title": "Mission Control",
        "source_candidates": ["CommandCenterFusionV37", "mission/status", "command center"],
        "priority": 1,
    },
    {
        "id": "rf-physics",
        "title": "RF Physics",
        "source_candidates": ["rfScenariosV35", "RF Physics", "Maxwell", "beamwidth"],
        "priority": 2,
    },
    {
        "id": "signal-analyzer",
        "title": "Signal Analyzer",
        "source_candidates": ["Spectrum", "Waterfall", "IQ", "RFInstrument"],
        "priority": 2,
    },
    {
        "id": "rf-microwave-engineering",
        "title": "RF / Microwave Engineering",
        "source_candidates": ["microwave", "VNA", "S-parameters", "Smith"],
        "priority": 3,
    },
    {
        "id": "antenna-system",
        "title": "Antenna System",
        "source_candidates": ["Antenna", "microstrip", "beamwidth", "tower"],
        "priority": 2,
    },
    {
        "id": "microwave-link",
        "title": "Microwave Link",
        "source_candidates": ["backhaul", "link budget", "dish", "microwave"],
        "priority": 4,
    },
    {
        "id": "fiber-optic",
        "title": "Fiber Optic",
        "source_candidates": ["fiber", "optical", "transport"],
        "priority": 4,
    },
    {
        "id": "private-networks",
        "title": "Private Networks",
        "source_candidates": ["private", "5g", "network"],
        "priority": 3,
    },
    {
        "id": "core-network",
        "title": "Core Network",
        "source_candidates": ["Open5GS", "core/open5gs", "AMF", "SMF", "UPF"],
        "priority": 2,
    },
    {
        "id": "data-center-infrastructure",
        "title": "Data Center Infrastructure",
        "source_candidates": ["data center", "infrastructure", "compute"],
        "priority": 4,
    },
    {
        "id": "cyber-rf-intelligence",
        "title": "Cyber RF Intelligence",
        "source_candidates": ["SOC", "NOC", "correlation", "cyber"],
        "priority": 3,
    },
    {
        "id": "knowledge-base",
        "title": "Knowledge Base",
        "source_candidates": ["Knowledge", "glossary", "visual_knowledge"],
        "priority": 3,
    },
]

# Score domains against html/react/assets
all_text = json.dumps(html_pages + react_files + assets, ensure_ascii=False).lower()
domain_plan = []
for d in official_domains:
    score = 0
    hits = []
    for candidate in d["source_candidates"]:
        if candidate.lower() in all_text:
            score += 1
            hits.append(candidate)
    status = "ready" if score >= 2 else "partial" if score == 1 else "missing"
    domain_plan.append({
        **d,
        "match_score": score,
        "hits": hits,
        "status": status,
    })

# Outputs
(rdir / "html_pages_inventory.json").write_text(json.dumps(html_pages, indent=2, ensure_ascii=False), encoding="utf-8")
(rdir / "react_components_inventory.json").write_text(json.dumps(react_files, indent=2, ensure_ascii=False), encoding="utf-8")
(rdir / "public_assets_inventory.json").write_text(json.dumps(assets, indent=2, ensure_ascii=False), encoding="utf-8")
(rdir / "active_main_chain.json").write_text(json.dumps(active_imports, indent=2, ensure_ascii=False), encoding="utf-8")
(rdir / "navigation_domain_plan_v39a.json").write_text(json.dumps(domain_plan, indent=2, ensure_ascii=False), encoding="utf-8")

with (rdir / "html_pages_inventory.tsv").open("w", encoding="utf-8") as f:
    f.write("path\tsize_bytes\ttitle\tiframe_count\texternal_ref_count\tkeywords\n")
    for h in html_pages:
        f.write(f"{h.get('path','')}\t{h.get('size_bytes',0)}\t{h.get('title','')}\t{h.get('iframe_count',0)}\t{h.get('external_ref_count',0)}\t{','.join(h.get('keywords',[]))}\n")

with (rdir / "react_components_inventory.tsv").open("w", encoding="utf-8") as f:
    f.write("path\tsize_bytes\tcomponent_count\tendpoint_count\tsignals\tcomponents\n")
    for r in react_files:
        f.write(f"{r['path']}\t{r['size_bytes']}\t{r['component_count']}\t{r['endpoint_count']}\t{','.join(r['signals'])}\t{','.join(r['components'][:12])}\n")

with (rdir / "navigation_domain_plan_v39a.tsv").open("w", encoding="utf-8") as f:
    f.write("id\ttitle\tstatus\tmatch_score\thits\tpriority\n")
    for d in domain_plan:
        f.write(f"{d['id']}\t{d['title']}\t{d['status']}\t{d['match_score']}\t{','.join(d['hits'])}\t{d['priority']}\n")

plan = rdir / "navigation_architecture_plan_v39a.md"
with plan.open("w", encoding="utf-8") as f:
    f.write("# TRFMC V39A Navigation Inventory Audit\n\n")
    f.write("## Obiettivo\n\n")
    f.write("Preparare la navigazione ufficiale del portale sopra V37/V38, senza modificare codice in questa fase.\n\n")
    f.write("## Active chain rilevata\n\n")
    for item in active_imports:
        f.write(f"- line {item['line']}: `{item['text']}`\n")
    f.write("\n## Inventario sintetico\n\n")
    f.write(f"- HTML pages: `{len(html_pages)}`\n")
    f.write(f"- React/TS source files: `{len(react_files)}`\n")
    f.write(f"- Public assets: `{len(assets)}`\n\n")
    f.write("## Domini navigazione proposti\n\n")
    for d in domain_plan:
        f.write(f"- **{d['title']}** (`{d['id']}`): status `{d['status']}`, score `{d['match_score']}`, hits `{', '.join(d['hits']) or '-'}`\n")
    f.write("\n## Strategia V39R1\n\n")
    f.write("1. Creare `frontend/src/navigation/navigationDataV39.ts`.\n")
    f.write("2. Creare `frontend/src/navigation/NavigationMapV39.tsx`.\n")
    f.write("3. Creare wrapper `RFOperationalDeckV39NavigationFusion.tsx`.\n")
    f.write("4. Montare V39 sopra `RFOperationalDeckV37CommandCenterFusion`.\n")
    f.write("5. Nessun iframe. Nessun backend/nginx/systemd mutation.\n")
    f.write("6. Le sezioni con status `ready` vanno abilitate come card primarie; `partial` come future-live; `missing` come planned.\n")
    f.write("7. Build gate + HTTP gate, Chrome escluso salvo fix host headless.\n")

summary = {
    "timestamp": ts,
    "operation": "TRFMC_NAVIGATION_INVENTORY_AUDIT_V39A",
    "frontend_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "html_pages_count": len(html_pages),
    "react_files_count": len(react_files),
    "public_assets_count": len(assets),
    "active_chain": active_imports,
    "domain_ready_count": sum(1 for d in domain_plan if d["status"] == "ready"),
    "domain_partial_count": sum(1 for d in domain_plan if d["status"] == "partial"),
    "domain_missing_count": sum(1 for d in domain_plan if d["status"] == "missing"),
    "html_inventory": str(rdir / "html_pages_inventory.tsv"),
    "react_inventory": str(rdir / "react_components_inventory.tsv"),
    "assets_inventory": str(rdir / "public_assets_inventory.json"),
    "domain_plan": str(rdir / "navigation_domain_plan_v39a.tsv"),
    "plan": str(plan),
    "result": "PASS",
}

(rdir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

cp "$RDIR/summary.json" "$QDIR/summary.json"

tar -czf "$FREEZE" \
  "$RDIR" \
  "$QDIR/summary.json" \
  create_trfmc_navigation_inventory_audit_v39a.sh \
  2>/dev/null || true

python3 - "$QDIR/summary.json" "$FREEZE" <<'PY'
import json, sys
from pathlib import Path
p=Path(sys.argv[1])
d=json.loads(p.read_text())
d["freeze"]=sys.argv[2]
p.write_text(json.dumps(d, indent=2, ensure_ascii=False))
print(json.dumps(d, indent=2, ensure_ascii=False))
PY

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_navigation_inventory_audit_v39a"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_navigation_inventory_audit_v39a"

echo
echo "=== DOMAIN PLAN ==="
column -t -s $'\t' "$RDIR/navigation_domain_plan_v39a.tsv"

echo
echo "=== HTML INVENTORY SAMPLE ==="
column -t -s $'\t' "$RDIR/html_pages_inventory.tsv" | sed -n '1,80p'

echo
echo "=== REACT INVENTORY SAMPLE ==="
column -t -s $'\t' "$RDIR/react_components_inventory.tsv" | sed -n '1,80p'

echo
echo "=== PLAN ==="
sed -n '1,220p' "$RDIR/navigation_architecture_plan_v39a.md"

echo
echo "============================================================"
echo "V39A NAVIGATION INVENTORY AUDIT COMPLETATO"
echo "============================================================"
