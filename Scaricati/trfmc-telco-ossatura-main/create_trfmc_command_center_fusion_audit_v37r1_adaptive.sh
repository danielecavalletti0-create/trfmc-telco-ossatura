#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"

QDIR="$ROOT/runtime/quality/TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37R1_ADAPTIVE_$TS"
RDIR="$ROOT/runtime/releases/TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37R1_ADAPTIVE_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37R1_ADAPTIVE_$TS.tar.gz"

MAIN="$ROOT/frontend/src/app/main.tsx"

mkdir -p "$QDIR" "$RDIR" runtime/freezes

echo "============================================================"
echo "TRFMC COMMAND CENTER FUSION AUDIT V37R1 ADAPTIVE"
echo "legacy V6R3 HTML audit · accepts V35/V36 active branch · read-only"
echo "============================================================"

echo
echo "=== PREFLIGHT ==="

test -f "$MAIN" || {
  echo "ERRORE: main.tsx mancante"
  exit 1
}

ACTIVE_BRANCH="unknown"

if grep -q "RFOperationalDeckV36VisualScenarioRuntime" "$MAIN"; then
  ACTIVE_BRANCH="V36"
elif grep -q "RFOperationalDeckV35DynamicScenarios" "$MAIN"; then
  ACTIVE_BRANCH="V35"
elif grep -q "RFOperationalDeckV34R1NativeBridgeVisible" "$MAIN"; then
  ACTIVE_BRANCH="V34R1R2"
else
  echo "ERRORE: ramo attivo non riconosciuto in main.tsx"
  grep -n "RFOperationalDeck" "$MAIN" || true
  exit 1
fi

echo "OK: ramo attivo rilevato: $ACTIVE_BRANCH"

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: API 4181 non operative"
  exit 1
}

echo "OK: API 4181 live"

echo
echo "=== SEARCH LEGACY COMMAND CENTER FILES ==="

python3 - "$ROOT" "$RDIR" "$TS" "$ACTIVE_BRANCH" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from html.parser import HTMLParser

root = Path(sys.argv[1]).resolve()
rdir = Path(sys.argv[2]).resolve()
ts = sys.argv[3]
active_branch = sys.argv[4]

candidate_names = [
    "trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "trfmc_official_safe_entrypoint_v6r3.html",
    "trfmc_v6r3_command_center.html",
    "trfmc_official_safe_entrypoint_v6r3_command_center.htm",
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
        if any(k in low for k in [
            "mission", "command", "control", "rf", "spectrum", "scenario",
            "dashboard", "telemetry", "signal", "core", "ran", "noc",
            "antenna", "microwave", "fiber", "private", "knowledge"
        ]):
            section_like.append((line_no, line.strip()[:260]))

    all_refs = parser.links + parser.scripts + parser.styles + parser.imgs + parser.iframes
    external_refs = [
        value for value in all_refs
        if re.search(r'https?://|//cdn\.|cdnjs|unpkg|jsdelivr|fonts\.googleapis', value or "", re.I)
    ]

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
        "ids_sample": parser.ids[:100],
        "classes_sample": sorted(set(parser.classes))[:160],
        "text_sample": parser.text_chunks[:120],
        "section_like_lines": section_like[:220],
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

def add_candidate(path: Path, reason: str):
    rp = path.resolve()
    if rp in seen:
        return
    seen.add(rp)

    text = path.read_text(encoding="utf-8", errors="ignore")
    analysis = analyze_html(path)

    candidates.append({
        "path": str(path),
        "relative": str(path.relative_to(root)) if path.is_relative_to(root) else str(path),
        "size_bytes": path.stat().st_size,
        "title_guess": analysis.get("title", ""),
        "reason": reason,
        "contains_command_center": "command" in text.lower() and "center" in text.lower(),
        "contains_iframe": len(analysis.get("iframes", [])) > 0,
        "contains_external_refs": len(analysis.get("external_refs", [])) > 0,
        "analysis": analysis,
    })

for base in search_roots:
    if not base.exists():
        continue

    for name in candidate_names:
        for p in base.rglob(name):
            if p.is_file():
                add_candidate(p, "exact_name")

# fallback semantic search by filename
if not candidates:
    for base in search_roots:
        if not base.exists():
            continue
        for p in base.rglob("*.html"):
            name = p.name.lower()
            if "command" in name or "v6r3" in name or "safe_entrypoint" in name or "command_center" in name:
                add_candidate(p, "filename_semantic")

# fallback content search, bounded
if not candidates:
    checked = 0
    for base in [root / "frontend", root]:
        if not base.exists():
            continue
        for p in base.rglob("*.html"):
            checked += 1
            if checked > 600:
                break
            try:
                text = p.read_text(encoding="utf-8", errors="ignore").lower()
            except Exception:
                continue
            if "command center" in text or ("mission" in text and "control" in text and "rf" in text):
                add_candidate(p, "content_semantic")

analyses = [c["analysis"] for c in candidates]

# Write JSON outputs
(rdir / "command_center_candidates.json").write_text(
    json.dumps([{k: v for k, v in c.items() if k != "analysis"} for c in candidates], indent=2, ensure_ascii=False),
    encoding="utf-8"
)
(rdir / "command_center_html_analysis.json").write_text(
    json.dumps(analyses, indent=2, ensure_ascii=False),
    encoding="utf-8"
)

# TSV
with (rdir / "command_center_candidates.tsv").open("w", encoding="utf-8") as f:
    f.write("relative_path\tsize_bytes\ttitle_guess\treason\tcontains_iframe\tcontains_external_refs\n")
    for c in candidates:
        f.write(
            f"{c['relative']}\t{c['size_bytes']}\t{c.get('title_guess','')}\t"
            f"{c['reason']}\t{c['contains_iframe']}\t{c['contains_external_refs']}\n"
        )

# Extract section map TSV
with (rdir / "command_center_section_like_lines.tsv").open("w", encoding="utf-8") as f:
    f.write("relative_path\tline\ttext\n")
    for c in candidates:
        rel = c["relative"]
        for line_no, line in c["analysis"].get("section_like_lines", [])[:120]:
            f.write(f"{rel}\t{line_no}\t{line.replace(chr(9),' ')}\n")

plan = rdir / "command_center_fusion_plan_v37r1.md"
with plan.open("w", encoding="utf-8") as f:
    f.write("# TRFMC V37R1 Adaptive Command Center Fusion Audit\n\n")
    f.write(f"Active branch detected: **{active_branch}**.\n\n")
    f.write("## Obiettivo\n\n")
    f.write(
        "Integrare il V6R3 Command Center come layer React superiore, non come iframe e non come pagina isolata. "
        "La pagina HTML legacy resta fallback/reference.\n\n"
    )

    f.write("## File candidati trovati\n\n")
    if candidates:
        for c in candidates:
            f.write(
                f"- `{c['relative']}` — `{c['size_bytes']}` bytes — title `{c.get('title_guess','')}` — "
                f"reason `{c['reason']}` — iframe `{c['contains_iframe']}` — external refs `{c['contains_external_refs']}`\n"
            )
    else:
        f.write("- Nessun candidato trovato. Servirà specificare path esatto o verificare `frontend/public` e `frontend/dist`.\n")

    f.write("\n## Strategia V37R2 consigliata\n\n")
    f.write("1. Creare `frontend/src/command_center/commandCenterDataV37.ts`.\n")
    f.write("2. Creare `frontend/src/command_center/CommandCenterFusionV37.tsx`.\n")
    f.write("3. Creare wrapper `RFOperationalDeckV37CommandCenterFusion.tsx`.\n")
    f.write("4. Montare V37 sopra il ramo attivo attuale.\n")
    f.write("5. Se il ramo è V36, preservare `RFOperationalDeckV36VisualScenarioRuntime` sotto V37.\n")
    f.write("6. Se il ramo è V35, preservare `RFOperationalDeckV35DynamicScenarios` sotto V37.\n")
    f.write("7. Collegare live contracts tramite `frontend/src/shared/liveContractsV32R1.ts`.\n")
    f.write("8. Niente iframe, niente CDN, niente mutazione backend, nginx o systemd.\n\n")

    f.write("## Endpoint live da usare\n\n")
    for ep in [
        "/api/mission/status",
        "/api/core/open5gs/status",
        "/api/ran/ueransim/status",
        "/api/rfpro/spectrum/sweep",
        "/api/rfpro/bandplan",
        "/api/soc-noc/correlation/demo",
    ]:
        f.write(f"- `{ep}`\n")

result = "PASS" if candidates else "WARN"

summary = {
    "timestamp": ts,
    "operation": "TRFMC_COMMAND_CENTER_FUSION_AUDIT_V37R1_ADAPTIVE",
    "active_branch": active_branch,
    "frontend_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "candidate_count": len(candidates),
    "analysis_count": len(analyses),
    "candidates_tsv": str(rdir / "command_center_candidates.tsv"),
    "candidates_json": str(rdir / "command_center_candidates.json"),
    "analysis_json": str(rdir / "command_center_html_analysis.json"),
    "section_lines_tsv": str(rdir / "command_center_section_like_lines.tsv"),
    "plan": str(plan),
    "result": result
}

(rdir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

cp "$RDIR/summary.json" "$QDIR/summary.json"

tar -czf "$FREEZE" \
  "$RDIR" \
  "$QDIR/summary.json" \
  create_trfmc_command_center_fusion_audit_v37r1_adaptive.sh \
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
echo "=== SECTION-LIKE LINES SAMPLE ==="
column -t -s $'\t' "$RDIR/command_center_section_like_lines.tsv" | sed -n '1,100p' || true

echo
echo "=== PLAN ==="
sed -n '1,240p' "$RDIR/command_center_fusion_plan_v37r1.md"

echo
echo "============================================================"
echo "V37R1 ADAPTIVE COMMAND CENTER FUSION AUDIT COMPLETATO"
echo "============================================================"
