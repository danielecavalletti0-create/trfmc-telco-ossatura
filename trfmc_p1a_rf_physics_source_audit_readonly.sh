#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P1A_RF_PHYSICS_SOURCE_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
CANDIDATES="$OUT/p1a_rf_physics_candidates.tsv"
TOP="$OUT/p1a_rf_physics_top_candidates.tsv"
STRUCT="$OUT/p1a_rf_physics_structure.tsv"
FORMULAS="$OUT/p1a_rf_physics_formula_keyword_scan.tsv"
ASSETS="$OUT/p1a_rf_physics_asset_refs.tsv"
DEBT="$OUT/p1a_rf_physics_debt_scan.tsv"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_p1a_rf_physics_audit_readonly.log"
PLAN="$OUT/TRFMC_P1A_RF_PHYSICS_PROMOTION_PLAN.md"

echo "============================================================"
echo "TRFMC_P1A_RF_PHYSICS_SOURCE_AUDIT_READONLY"
echo "Read-only · RF Physics candidate selection · no source mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) RF PHYSICS CANDIDATE DISCOVERY ==="

python3 - "$BASE" "$CANDIDATES" "$TOP" "$STRUCT" "$FORMULAS" "$ASSETS" "$DEBT" "$PLAN" <<'PY'
import csv
import re
import sys
from pathlib import Path
from html.parser import HTMLParser

base = Path(sys.argv[1])
candidates_out = Path(sys.argv[2])
top_out = Path(sys.argv[3])
struct_out = Path(sys.argv[4])
formulas_out = Path(sys.argv[5])
assets_out = Path(sys.argv[6])
debt_out = Path(sys.argv[7])
plan_out = Path(sys.argv[8])

public = base / "frontend" / "public"

positive_name = [
    "rf_physics", "physics", "maxwell", "field", "propagation", "wave",
    "fresnel", "faraday", "gauss", "electromagnetic", "webgl_rf",
    "sapienza", "polarization", "doppler", "pathloss", "link_budget"
]

negative_name = [
    "antenna", "signal_cockpit", "instrument", "spectrum", "analyzer",
    "microwave", "fiber", "otdr", "core", "ran", "security", "wifi",
    "knowledge", "portal_index", "home", "integration_control"
]

positive_content = [
    "maxwell", "electric field", "magnetic field", "electromagnetic",
    "propagation", "wavelength", "frequency", "lambda", "λ", "snr",
    "friis", "free space", "path loss", "dbm", "dbi", "evm",
    "fft", "fourier", "iq", "i/q", "polarization", "fresnel",
    "near field", "far field", "webgl", "three", "canvas"
]

formula_terms = [
    "E", "H", "B", "D", "∇", "curl", "div", "epsilon", "permittivity",
    "mu", "permeability", "c = λf", "lambda", "λ", "friis",
    "20log", "log10", "fspl", "path loss", "snr", "dbm", "dbi",
    "fourier", "fft", "iq", "i/q", "evm", "ber", "shannon"
]

debt_terms = [
    "TODO", "FIXME", "PLACEHOLDER", "mock", "fake", "lorem", "undefined",
    "null", "coming soon", "innerHTML", "dangerouslySetInnerHTML",
    "document.write", "document.body", "<iframe", "http://", "https://",
    "cdn", "unpkg", "jsdelivr"
]

class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tags = {}
        self.ids = []
        self.classes = []
        self.assets = []
        self.inline_handlers = 0
        self.text = []

    def handle_starttag(self, tag, attrs):
        self.tags[tag] = self.tags.get(tag, 0) + 1
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if "class" in attrs:
            self.classes.extend(attrs["class"].split())
        for attr in ("src", "href"):
            if attr in attrs:
                self.assets.append(attrs[attr])
        for k in attrs:
            if k.lower().startswith("on"):
                self.inline_handlers += 1

    def handle_data(self, data):
        s = " ".join(data.split())
        if s:
            self.text.append(s)

def safe_read(path):
    return path.read_text(encoding="utf-8", errors="replace")

def title_h1(html):
    title = "-"
    h1 = "-"
    m = re.search(r"<title[^>]*>(.*?)</title>", html, flags=re.I | re.S)
    if m:
        title = re.sub(r"<.*?>", " ", m.group(1))
        title = " ".join(title.split())[:180]
    m = re.search(r"<h1[^>]*>(.*?)</h1>", html, flags=re.I | re.S)
    if m:
        h1 = re.sub(r"<.*?>", " ", m.group(1))
        h1 = " ".join(h1.split())[:180]
    return title, h1

rows = []
struct_rows = []
formula_rows = []
asset_rows = []
debt_rows = []

for path in sorted(public.glob("*.html")):
    rel = str(path.relative_to(base))
    name = path.name.lower()

    if not any(k in name for k in positive_name):
        # allow content rescue only for html files with RF physics terms in text
        html_probe = safe_read(path)[:120000].lower()
        if not any(k in html_probe for k in positive_content):
            continue

    html = safe_read(path)
    html_l = html.lower()
    parser = Parser()
    try:
        parser.feed(html)
    except Exception:
        pass

    title, h1 = title_h1(html)

    score = 0
    reasons = []

    for k in positive_name:
        if k in name:
            score += 18
            reasons.append(f"name:{k}")

    for k in negative_name:
        if k in name:
            score -= 18
            reasons.append(f"negative_name:{k}")

    content_hits = sum(1 for k in positive_content if k in html_l)
    score += content_hits * 5

    formula_hits = sum(1 for k in formula_terms if k.lower() in html_l)
    score += formula_hits * 4

    if "webgl" in html_l or "three" in html_l:
        score += 25
        reasons.append("webgl/3d")
    if "<canvas" in html_l:
        score += 18
        reasons.append("canvas")
    if "maxwell" in html_l:
        score += 20
        reasons.append("maxwell")
    if "propagation" in html_l:
        score += 15
        reasons.append("propagation")
    if "runtime_identity_lock" in name:
        score += 14
        reasons.append("runtime identity lock")
    if "v85" in name or "v86" in name or "v87" in name:
        score += 10
        reasons.append("latest version family")

    debt_hits = []
    for idx, line in enumerate(html.splitlines(), 1):
        for term in debt_terms:
            if term.lower() in line.lower():
                debt_hits.append((idx, term, line.strip()[:260]))
                break

    if len(debt_hits) > 10:
        score -= 20
        reasons.append("debt-heavy")
    elif debt_hits:
        score -= 8
        reasons.append("minor debt")

    row = {
        "score": score,
        "path": rel,
        "bytes": path.stat().st_size,
        "lines": len(html.splitlines()),
        "title": title,
        "h1": h1,
        "content_hits": content_hits,
        "formula_hits": formula_hits,
        "debt_hits": len(debt_hits),
        "canvas_tags": parser.tags.get("canvas", 0),
        "svg_tags": parser.tags.get("svg", 0),
        "script_tags": parser.tags.get("script", 0),
        "style_tags": parser.tags.get("style", 0),
        "inline_handlers": parser.inline_handlers,
        "reasons": ", ".join(reasons[:12]) if reasons else "-",
    }
    rows.append(row)

    struct_rows.append({
        "path": rel,
        "bytes": path.stat().st_size,
        "lines": len(html.splitlines()),
        "title": title,
        "h1": h1,
        "canvas_tags": parser.tags.get("canvas", 0),
        "svg_tags": parser.tags.get("svg", 0),
        "script_tags": parser.tags.get("script", 0),
        "style_tags": parser.tags.get("style", 0),
        "link_tags": parser.tags.get("link", 0),
        "iframe_tags": parser.tags.get("iframe", 0),
        "inline_handlers": parser.inline_handlers,
    })

    for idx, line in enumerate(html.splitlines(), 1):
        low = line.lower()
        if any(t.lower() in low for t in formula_terms):
            formula_rows.append({
                "path": rel,
                "line": idx,
                "match": line.strip()[:260],
            })

    for asset in parser.assets:
        if asset and not asset.startswith("#"):
            asset_rows.append({
                "path": rel,
                "asset_ref": asset[:240],
            })

    for idx, term, snippet in debt_hits:
        debt_rows.append({
            "path": rel,
            "line": idx,
            "term": term,
            "match": snippet,
        })

rows.sort(key=lambda r: (-r["score"], r["path"]))

with candidates_out.open("w", encoding="utf-8", newline="") as f:
    fields = [
        "score", "path", "bytes", "lines", "title", "h1", "content_hits",
        "formula_hits", "debt_hits", "canvas_tags", "svg_tags", "script_tags",
        "style_tags", "inline_handlers", "reasons"
    ]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(rows)

with top_out.open("w", encoding="utf-8", newline="") as f:
    fields = [
        "rank", "promotion_decision", "score", "path", "bytes", "lines",
        "title", "h1", "formula_hits", "debt_hits", "canvas_tags",
        "script_tags", "reasons"
    ]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    for i, r in enumerate(rows[:12], 1):
        decision = "PRIMARY_PROMOTION_CANDIDATE" if i == 1 else "SECONDARY_REVIEW"
        if r["debt_hits"] > 20:
            decision = "REFERENCE_ONLY_UNTIL_DEBT_REVIEW"
        w.writerow({
            "rank": f"P1A.{i:02d}",
            "promotion_decision": decision,
            "score": r["score"],
            "path": r["path"],
            "bytes": r["bytes"],
            "lines": r["lines"],
            "title": r["title"],
            "h1": r["h1"],
            "formula_hits": r["formula_hits"],
            "debt_hits": r["debt_hits"],
            "canvas_tags": r["canvas_tags"],
            "script_tags": r["script_tags"],
            "reasons": r["reasons"],
        })

with struct_out.open("w", encoding="utf-8", newline="") as f:
    fields = [
        "path", "bytes", "lines", "title", "h1", "canvas_tags", "svg_tags",
        "script_tags", "style_tags", "link_tags", "iframe_tags", "inline_handlers"
    ]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(struct_rows)

with formulas_out.open("w", encoding="utf-8", newline="") as f:
    fields = ["path", "line", "match"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(formula_rows[:600])

with assets_out.open("w", encoding="utf-8", newline="") as f:
    fields = ["path", "asset_ref"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(asset_rows[:800])

with debt_out.open("w", encoding="utf-8", newline="") as f:
    fields = ["path", "line", "term", "match"]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(debt_rows[:800])

primary = rows[0] if rows else None

md = []
md.append("# TRFMC P1A RF Physics Source Audit")
md.append("")
md.append("## Scope")
md.append("")
md.append("Read-only audit for RF Physics promotion. No source mutation, no backend mutation, no CSS patch.")
md.append("")
md.append("## Candidate selection rule")
md.append("")
md.append("- Prefer files with RF physics semantics, Maxwell/propagation/formula density, canvas/WebGL engines and low debt.")
md.append("- Exclude Signal Analyzer, Antenna, Microwave, Core/RAN and Knowledge Base unless they are only references.")
md.append("- Public HTML remains source/reference material until converted into clean React components.")
md.append("")
if primary:
    md.append("## Proposed primary source")
    md.append("")
    md.append(f"- `{primary['path']}`")
    md.append(f"- score: `{primary['score']}`")
    md.append(f"- formula hits: `{primary['formula_hits']}`")
    md.append(f"- canvas tags: `{primary['canvas_tags']}`")
    md.append(f"- debt hits: `{primary['debt_hits']}`")
    md.append(f"- reason: {primary['reasons']}")
    md.append("")
md.append("## Next mutation, if approved")
md.append("")
md.append("`TRFMC_P1B_RF_PHYSICS_REACT_PROMOTION_V1`")
md.append("")
md.append("Required output:")
md.append("")
md.append("- `frontend/src/domains/rf-physics/RFPhysicsDomainP1.tsx`")
md.append("- `frontend/src/domains/rf-physics/rfPhysicsRegistry.ts`")
md.append("- no iframe")
md.append("- no `dangerouslySetInnerHTML`")
md.append("- no public HTML runtime link")
md.append("- DOM marker: `data-trfmc-p1-rf-physics-domain=\"mounted\"`")
md.append("- QA: build, HTTP, DOM, screenshot, static safety gate")
md.append("")

plan_out.write_text("\n".join(md), encoding="utf-8")
PY

column -t -s $'\t' "$TOP" | sed -n '1,80p'

echo
echo "=== 2) STRUCTURE TOP VIEW ==="
column -t -s $'\t' "$STRUCT" | sed -n '1,80p'

echo
echo "=== 3) FORMULA / RF KEYWORD SCAN HEAD ==="
column -t -s $'\t' "$FORMULAS" | sed -n '1,120p'

echo
echo "=== 4) DEBT SCAN HEAD ==="
column -t -s $'\t' "$DEBT" | sed -n '1,120p'

echo
echo "=== 5) BUILD CHECK READONLY ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG" || true

echo
echo "=== 6) HTTP CHECK READONLY ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local cls="OK"

  if [ "$code" = "000" ]; then cls="UNREACHABLE"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  if [ "$code" != "200" ] && [ "$code" != "000" ]; then cls="NON_200_REVIEW"; fi

  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/#mission-overview"
check_url "http://127.0.0.1:5173/#rf-physics"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

awk -F'\t' 'NR>1 && NR<=7 {print $4}' "$TOP" | while read -r p; do
  [ -z "$p" ] && continue
  name="$(basename "$p")"
  check_url "http://127.0.0.1:5173/$name"
done

CANDIDATE_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$CANDIDATES")"
TOP_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$TOP")"
DEBT_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$DEBT")"
FORMULA_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$FORMULAS")"
HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

PRIMARY_PATH="$(awk -F'\t' 'NR==2 {print $4}' "$TOP")"
PRIMARY_SCORE="$(awk -F'\t' 'NR==2 {print $3}' "$TOP")"

RESULT="P1A_RF_PHYSICS_AUDIT_READY"
if [ "$CANDIDATE_COUNT" = "0" ]; then RESULT="REVIEW_NO_RF_PHYSICS_CANDIDATES"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P1A_RF_PHYSICS_SOURCE_AUDIT_READONLY",
  "mutation": false,
  "source_mutation": false,
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "out": "$OUT",
  "candidates": "$CANDIDATES",
  "top_candidates": "$TOP",
  "structure": "$STRUCT",
  "formula_keyword_scan": "$FORMULAS",
  "asset_refs": "$ASSETS",
  "debt_scan": "$DEBT",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "plan": "$PLAN",
  "candidate_count": $CANDIDATE_COUNT,
  "top_count": $TOP_COUNT,
  "formula_scan_rows": $FORMULA_COUNT,
  "debt_scan_rows": $DEBT_COUNT,
  "primary_candidate": "$PRIMARY_PATH",
  "primary_score": "$PRIMARY_SCORE",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p1a_rf_physics_source_audit_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,180p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P1A_RF_PHYSICS_SOURCE_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
