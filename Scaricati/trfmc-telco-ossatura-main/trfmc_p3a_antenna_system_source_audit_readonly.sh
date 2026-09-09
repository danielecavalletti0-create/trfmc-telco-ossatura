#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P3A_ANTENNA_SYSTEM_SOURCE_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
CANDIDATES="$OUT/p3a_antenna_system_candidates.tsv"
TOP="$OUT/p3a_antenna_system_top_candidates.tsv"
STRUCT="$OUT/p3a_antenna_system_structure.tsv"
KEYWORDS="$OUT/p3a_antenna_system_keyword_scan.tsv"
ASSETS="$OUT/p3a_antenna_system_asset_refs.tsv"
DEBT="$OUT/p3a_antenna_system_debt_scan.tsv"
HTTP="$OUT/http.tsv"
BUILDLOG="$OUT/npm_build_p3a_antenna_system_audit_readonly.log"
PLAN="$OUT/TRFMC_P3A_ANTENNA_SYSTEM_PROMOTION_PLAN.md"

echo "============================================================"
echo "TRFMC_P3A_ANTENNA_SYSTEM_SOURCE_AUDIT_READONLY"
echo "Read-only · Antenna System candidate selection · no mutation"
echo "Timestamp: $TS"
echo "============================================================"

python3 - "$BASE" "$CANDIDATES" "$TOP" "$STRUCT" "$KEYWORDS" "$ASSETS" "$DEBT" "$PLAN" <<'PY'
import csv
import re
import sys
from pathlib import Path
from html.parser import HTMLParser

base = Path(sys.argv[1])
candidates_out = Path(sys.argv[2])
top_out = Path(sys.argv[3])
struct_out = Path(sys.argv[4])
keywords_out = Path(sys.argv[5])
assets_out = Path(sys.argv[6])
debt_out = Path(sys.argv[7])
plan_out = Path(sys.argv[8])

public = base / "frontend" / "public"

positive_name = [
    "antenna", "rru", "ret", "cpri", "aisg", "radiation", "pattern",
    "beam", "array", "mimo", "massive", "polarization", "azimuth",
    "elevation", "tilt", "downtilt", "sector", "explorer"
]

negative_name = [
    "signal", "spectrum", "analyzer", "fiber", "otdr", "core", "ran",
    "open5gs", "ueransim", "knowledge", "home", "portal_index",
    "integration_control", "rf_physics", "microwave"
]

positive_content = [
    "antenna", "radiation pattern", "azimuth", "elevation", "gain",
    "dbi", "beamwidth", "downtilt", "electrical tilt", "mechanical tilt",
    "ret", "rru", "cpri", "aisg", "mimo", "massive mimo", "array",
    "polarization", "sector", "3d", "webgl", "canvas", "pattern",
    "side lobe", "front-to-back", "beamforming", "panel", "port mapping"
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
        self.assets = []
        self.inline_handlers = 0

    def handle_starttag(self, tag, attrs):
        self.tags[tag] = self.tags.get(tag, 0) + 1
        attrs = dict(attrs)
        for attr in ("src", "href"):
            if attr in attrs:
                self.assets.append(attrs[attr])
        for k in attrs:
            if k.lower().startswith("on"):
                self.inline_handlers += 1

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
keyword_rows = []
asset_rows = []
debt_rows = []

for path in sorted(public.glob("*.html")):
    rel = str(path.relative_to(base))
    name = path.name.lower()
    html = safe_read(path)
    html_l = html.lower()

    name_match = any(k in name for k in positive_name)
    content_match = any(k in html_l for k in positive_content)

    if not name_match and not content_match:
        continue

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

    if "<canvas" in html_l:
        score += 22
        reasons.append("canvas")
    if "webgl" in html_l or "three" in html_l:
        score += 20
        reasons.append("webgl/3d")
    if "radiation pattern" in html_l or "pattern" in html_l:
        score += 16
        reasons.append("pattern")
    if "ret" in html_l or "downtilt" in html_l:
        score += 16
        reasons.append("ret/downtilt")
    if "cpri" in html_l or "rru" in html_l:
        score += 16
        reasons.append("rru/cpri")
    if "v17" in name or "v18" in name or "v20" in name:
        score += 8
        reasons.append("versioned candidate")

    debt_hits = []
    for idx, line in enumerate(html.splitlines(), 1):
        for term in debt_terms:
            if term.lower() in line.lower():
                debt_hits.append((idx, term, line.strip()[:260]))
                break

    if len(debt_hits) > 25:
        score -= 22
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
        "debt_hits": len(debt_hits),
        "canvas_tags": parser.tags.get("canvas", 0),
        "svg_tags": parser.tags.get("svg", 0),
        "script_tags": parser.tags.get("script", 0),
        "style_tags": parser.tags.get("style", 0),
        "inline_handlers": parser.inline_handlers,
        "reasons": ", ".join(reasons[:14]) if reasons else "-",
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
        if any(t in low for t in positive_content):
            keyword_rows.append({
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
        "debt_hits", "canvas_tags", "svg_tags", "script_tags",
        "style_tags", "inline_handlers", "reasons"
    ]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(rows)

with top_out.open("w", encoding="utf-8", newline="") as f:
    fields = [
        "rank", "promotion_decision", "score", "path", "bytes", "lines",
        "title", "h1", "content_hits", "debt_hits", "canvas_tags",
        "script_tags", "reasons"
    ]
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    for i, r in enumerate(rows[:15], 1):
        decision = "PRIMARY_PROMOTION_CANDIDATE" if i == 1 else "SECONDARY_REVIEW"
        if r["debt_hits"] > 25:
            decision = "REFERENCE_ONLY_UNTIL_DEBT_REVIEW"
        w.writerow({
            "rank": f"P3A.{i:02d}",
            "promotion_decision": decision,
            "score": r["score"],
            "path": r["path"],
            "bytes": r["bytes"],
            "lines": r["lines"],
            "title": r["title"],
            "h1": r["h1"],
            "content_hits": r["content_hits"],
            "debt_hits": r["debt_hits"],
            "canvas_tags": r["canvas_tags"],
            "script_tags": r["script_tags"],
            "reasons": r["reasons"],
        })

for out, data, fields in [
    (struct_out, struct_rows, ["path","bytes","lines","title","h1","canvas_tags","svg_tags","script_tags","style_tags","link_tags","iframe_tags","inline_handlers"]),
    (keywords_out, keyword_rows[:800], ["path","line","match"]),
    (assets_out, asset_rows[:800], ["path","asset_ref"]),
    (debt_out, debt_rows[:800], ["path","line","term","match"]),
]:
    with out.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
        w.writeheader()
        w.writerows(data)

primary = rows[0] if rows else None

md = []
md.append("# TRFMC P3A Antenna System Source Audit")
md.append("")
md.append("## Scope")
md.append("")
md.append("Read-only audit for Antenna System promotion. No source mutation, no backend mutation, no CSS patch.")
md.append("")
md.append("## Selection rule")
md.append("")
md.append("- Prefer antenna explorer, radiation pattern, RRU/RET/CPRI/AISG, MIMO, beam/array and 3D/canvas content.")
md.append("- Exclude RF Physics, Signal Analyzer, Fiber, Core/RAN and Mission Control unless only used as reference.")
md.append("- Public HTML remains reference material until converted into clean React components.")
md.append("")
if primary:
    md.append("## Proposed primary source")
    md.append("")
    md.append(f"- `{primary['path']}`")
    md.append(f"- score: `{primary['score']}`")
    md.append(f"- content hits: `{primary['content_hits']}`")
    md.append(f"- canvas tags: `{primary['canvas_tags']}`")
    md.append(f"- debt hits: `{primary['debt_hits']}`")
    md.append(f"- reason: {primary['reasons']}")
    md.append("")
md.append("## Next mutation, if approved")
md.append("")
md.append("`TRFMC_P3B_ANTENNA_SYSTEM_REACT_PROMOTION_V1`")
md.append("")
md.append("Required output:")
md.append("- `frontend/src/domains/antenna-system/AntennaSystemDomainP3.tsx`")
md.append("- `frontend/src/domains/antenna-system/antennaSystemRegistry.ts`")
md.append("- canvas/radiation pattern placeholder governed by React")
md.append("- RRU/RET/CPRI/AISG port mapping cards")
md.append("- no iframe")
md.append("- no unsafe HTML injection")
md.append("- no public HTML runtime link")
md.append("- DOM marker: `data-trfmc-p3-antenna-system-domain=\"mounted\"`")
md.append("- QA: build, HTTP, DOM, screenshot, static safety gate")
md.append("")

plan_out.write_text("\n".join(md), encoding="utf-8")
PY

echo
echo "=== TOP ANTENNA SYSTEM CANDIDATES ==="
column -t -s $'\t' "$TOP" | sed -n '1,90p'

echo
echo "=== DEBT SCAN HEAD ==="
column -t -s $'\t' "$DEBT" | sed -n '1,120p'

echo
echo "=== BUILD CHECK READONLY ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

echo
echo "=== HTTP CHECK READONLY ==="

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
check_url "http://127.0.0.1:5173/#antenna-system"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

awk -F'\t' 'NR>1 && NR<=8 {print $4}' "$TOP" | while read -r p; do
  [ -z "$p" ] && continue
  name="$(basename "$p")"
  check_url "http://127.0.0.1:5173/$name"
done

CANDIDATE_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$CANDIDATES")"
TOP_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$TOP")"
DEBT_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$DEBT")"
KEYWORD_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$KEYWORDS")"
HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

PRIMARY_PATH="$(awk -F'\t' 'NR==2 {print $4}' "$TOP")"
PRIMARY_SCORE="$(awk -F'\t' 'NR==2 {print $3}' "$TOP")"

RESULT="P3A_ANTENNA_SYSTEM_AUDIT_READY"
if [ "$CANDIDATE_COUNT" = "0" ]; then RESULT="REVIEW_NO_ANTENNA_SYSTEM_CANDIDATES"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P3A_ANTENNA_SYSTEM_SOURCE_AUDIT_READONLY",
  "mutation": false,
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "out": "$OUT",
  "candidates": "$CANDIDATES",
  "top_candidates": "$TOP",
  "structure": "$STRUCT",
  "keyword_scan": "$KEYWORDS",
  "asset_refs": "$ASSETS",
  "debt_scan": "$DEBT",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "plan": "$PLAN",
  "candidate_count": $CANDIDATE_COUNT,
  "top_count": $TOP_COUNT,
  "keyword_scan_rows": $KEYWORD_COUNT,
  "debt_scan_rows": $DEBT_COUNT,
  "primary_candidate": "$PRIMARY_PATH",
  "primary_score": "$PRIMARY_SCORE",
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p3a_antenna_system_source_audit_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,180p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P3A_ANTENNA_SYSTEM_SOURCE_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
