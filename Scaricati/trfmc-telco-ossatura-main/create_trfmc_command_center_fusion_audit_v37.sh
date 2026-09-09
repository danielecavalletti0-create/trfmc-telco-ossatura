#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37_$TS.tar.gz"

mkdir -p "$QDIR" "$RDIR" runtime/freezes

echo "============================================================"
echo "TRFMC COMMAND CENTER FUSION AUDIT V37"
echo "legacy V6R3 HTML audit · React fusion plan · read-only"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f runtime/quality/latest_dynamic_rf_telco_scenarios_v35/summary.json || {
  echo "ERRORE: V35 summary mancante"
  exit 1
}

V35_RESULT="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("runtime/quality/latest_dynamic_rf_telco_scenarios_v35/summary.json").read_text())
print(d.get("result",""))
PY
)"

[ "$V35_RESULT" = "PASS" ] || {
  echo "ERRORE: V35 non PASS: $V35_RESULT"
  exit 1
}

grep -q "RFOperationalDeckV35DynamicScenarios" frontend/src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V35"
  exit 1
}

echo "OK: V35 PASS e ramo attivo corretto"

echo
echo "=== SEARCH LEGACY COMMAND CENTER FILES ==="

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

candidate_names = [
    "trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "trfmc_official_safe_entrypoint_v6r3.html",
    "trfmc_v6r3_command_center.html",
]

search_roots = [
    root / "frontend",
    root / "frontend" / "public",
    root / "frontend" / "dist",
    root / "runtime",
    root,
]

seen = set()
candidates = []

for base in search_roots:
    if not base.exists():
        continue
    for name in candidate_names:
        for p in base.rglob(name):
            rp = p.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            try:
                text = p.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                text = ""
            candidates.append({
                "path": str(p),
                "size_bytes": p.stat().st_size,
                "relative": str(p.relative_to(root)) if p.is_relative_to(root) else str(p),
                "title_guess": "",
                "contains_command_center": "command" in text.lower() and "center" in text.lower(),
                "contains_iframe": "<iframe" in text.lower(),
                "contains_external_refs": bool(re.search(r'https?://|//cdn\.|cdnjs|unpkg|jsdelivr|fonts\.googleapis', text, re.I)),
            })

class AuditParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tags = []
        self.links = []
        self.scripts = []
        self.styles = []
        self.imgs = []
        self.iframes = []
        self.ids = []
        self.classes = []
        self.text_chunks = []
        self._capture_title = False
        self.title = ""

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        self.tags.append(tag)
        if "id" in d:
            self.ids.append(d["id"])
        if "class" in d:
            self.classes.extend(str(d["class"]).split())
        if tag == "a":
            self.links.append(d.get("href", ""))
        elif tag == "script":
            self.scripts.append(d.get("src", "__inline__"))
        elif tag == "link":
            self.styles.append(d.get("href", ""))
        elif tag == "img":
            self.imgs.append(d.get("src", ""))
        elif tag == "iframe":
            self.iframes.append(d.get("src", ""))
        elif tag == "title":
            self._capture_title = True

    def handle_endtag(self, tag):
        if tag == "title":
            self._capture_title = False

    def handle_data(self, data):
        clean = " ".join(data.split())
        if self._capture_title:
            self.title += clean
        if clean and len(clean) > 2:
            self.text_chunks.append(clean)

def analyze_html(path: Path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    parser = AuditParser()
    parser.feed(text)

    section_like = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        low = line.lower()
        if any(k in low for k in ["mission", "command", "control", "rf", "spectrum", "scenario", "dashboard", "telemetry", "signal", "core", "ran", "noc"]):
            section_like.append((line_no, line.strip()[:240]))

    external_refs = []
    for value in parser.links + parser.scripts + parser.styles + parser.imgs + parser.iframes:
        if re.search(r'https?://|//cdn\.|cdnjs|unpkg|jsdelivr|fonts\.googleapis', value or "", re.I):
            external_refs.append(value)

    return {
        "path": str(path),
        "size_bytes": path.stat().st_size,
        "title": parser.title,
        "tag_count": len(parser.tags),
        "unique_tags": sorted(set(parser.tags)),
        "links": parser.links,
        "scripts": parser.scripts,
        "styles": parser.styles,
        "images": parser.imgs,
        "iframes": parser.iframes,
        "ids_sample": parser.ids[:80],
        "classes_sample": sorted(set(parser.classes))[:120],
        "text_sample": parser.text_chunks[:80],
        "section_like_lines": section_like[:160],
        "external_refs": sorted(set(external_refs)),
        "counts": {
            "links": len(parser.links),
            "scripts": len(parser.scripts),
            "styles": len(parser.styles),
            "images": len(parser.imgs),
            "iframes": len(parser.iframes),
            "ids": len(parser.ids),
            "classes": len(parser.classes),
            "section_like_lines": len(section_like),
            "external_refs": len(external_refs),
        }
    }

analyses = []
for c in candidates:
    p = Path(c["path"])
    try:
        a = analyze_html(p)
        c["title_guess"] = a["title"]
        analyses.append(a)
    except Exception as e:
        analyses.append({"path": str(p), "error": str(e)})

# Se non trovato per nome esatto, cerchiamo pagine command center simili.
if not candidates:
    for p in (root / "frontend").rglob("*.html"):
        name = p.name.lower()
        if "command" in name or "v6r3" in name or "safe_entrypoint" in name:
            try:
                a = analyze_html(p)
                candidates.append({
                    "path": str(p),
                    "size_bytes": p.stat().st_size,
                    "relative": str(p.relative_to(root)),
                    "title_guess": a.get("title",""),
                    "contains_command_center": True,
                    "contains_iframe": len(a.get("iframes",[])) > 0,
                    "contains_external_refs": len(a.get("external_refs",[])) > 0,
                })
                analyses.append(a)
            except Exception:
                pass

(rdir / "command_center_candidates.json").write_text(json.dumps(candidates, indent=2, ensure_ascii=False), encoding="utf-8")
(rdir / "command_center_html_analysis.json").write_text(json.dumps(analyses, indent=2, ensure_ascii=False), encoding="utf-8")

# TSV summaries.
with (rdir / "command_center_candidates.tsv").open("w", encoding="utf-8") as f:
    f.write("path\tsize_bytes\ttitle_guess\tcontains_iframe\tcontains_external_refs\n")
    for c in candidates:
        f.write(f"{c['relative']}\t{c['size_bytes']}\t{c.get('title_guess','')}\t{c['contains_iframe']}\t{c['contains_external_refs']}\n")

# Conversion plan.
plan = rdir / "command_center_fusion_plan_v37.md"
with plan.open("w", encoding="utf-8") as f:
    f.write("# TRFMC V37 Command Center Fusion Audit\n\n")
    f.write("## Obiettivo\n\n")
    f.write("Convertire la pagina legacy V6R3 Command Center in un layer React integrato sopra V36, senza iframe e senza lasciare la pagina come entrypoint operativo separato.\n\n")
    f.write("## File candidati\n\n")
    if candidates:
        for c in candidates:
            f.write(f"- `{c['relative']}` — size `{c['size_bytes']}` bytes — title `{c.get('title_guess','')}` — iframe `{c['contains_iframe']}` — external refs `{c['contains_external_refs']}`\n")
    else:
        f.write("- Nessun candidato HTML trovato con nome previsto.\n")
    f.write("\n## Strategia V37R1\n\n")
    f.write("1. Creare `frontend/src/command_center/commandCenterDataV37.ts`.\n")
    f.write("2. Creare `frontend/src/command_center/CommandCenterFusionV37.tsx`.\n")
    f.write("3. Creare wrapper `RFOperationalDeckV37CommandCenterFusion.tsx`.\n")
    f.write("4. Montare V37 sopra `RFOperationalDeckV36VisualScenarioRuntime`.\n")
    f.write("5. Usare i contratti live già disponibili via `liveContractsV32R1.ts`.\n")
    f.write("6. Preservare la pagina HTML legacy come fallback/reference, non come iframe.\n")
    f.write("7. Build gate + HTTP gate + no Chrome mandatory, perché Chrome headless è instabile su host.\n\n")
    f.write("## Endpoint live da collegare\n\n")
    for ep in [
        "/api/mission/status",
        "/api/core/open5gs/status",
        "/api/ran/ueransim/status",
        "/api/rfpro/spectrum/sweep",
        "/api/rfpro/bandplan",
        "/api/soc-noc/correlation/demo",
    ]:
        f.write(f"- `{ep}`\n")

summary = {
    "timestamp": ts,
    "operation": "TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37",
    "frontend_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "candidate_count": len(candidates),
    "analysis_count": len(analyses),
    "candidates_tsv": str(rdir / "command_center_candidates.tsv"),
    "candidates_json": str(rdir / "command_center_candidates.json"),
    "analysis_json": str(rdir / "command_center_html_analysis.json"),
    "plan": str(plan),
    "result": "PASS" if candidates else "WARN"
}

(rdir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

cp "$RDIR/summary.json" "$QDIR/summary.json"

tar -czf "$FREEZE" \
  "$RDIR" \
  "$QDIR/summary.json" \
  create_trfmc_command_center_fusion_audit_v37.sh \
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

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_command_center_fusion_audit_v37"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_command_center_fusion_audit_v37"

echo
echo "=== CANDIDATES ==="
column -t -s $'\t' "$RDIR/command_center_candidates.tsv" || true

echo
echo "=== PLAN ==="
sed -n '1,220p' "$RDIR/command_center_fusion_plan_v37.md"

echo
echo "============================================================"
echo "V37 COMMAND CENTER FUSION AUDIT COMPLETATO"
echo "============================================================"
