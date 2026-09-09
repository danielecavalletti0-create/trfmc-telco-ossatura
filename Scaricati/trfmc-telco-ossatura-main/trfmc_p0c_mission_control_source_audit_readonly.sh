#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P0C_MISSION_CONTROL_SOURCE_AUDIT_READONLY_$TS"

mkdir -p "$OUT"
cd "$BASE"

SUMMARY="$OUT/summary.json"
FILES="$OUT/p0c_source_file_gate.tsv"
STRUCT="$OUT/p0c_html_structure.tsv"
TOKENS="$OUT/p0c_content_tokens.tsv"
DEBT="$OUT/p0c_debt_scan.tsv"
PLAN="$OUT/TRFMC_P0C_MISSION_CONTROL_PROMOTION_PLAN.md"
BUILDLOG="$OUT/npm_build_p0c_audit_readonly.log"
HTTP="$OUT/http.tsv"

SOURCES=(
  "frontend/public/trfmc_home_v87g.html"
  "frontend/public/trfmc_integration_control_room.html"
  "frontend/public/portal_index_v19.html"
)

echo "============================================================"
echo "TRFMC_P0C_MISSION_CONTROL_SOURCE_AUDIT_READONLY"
echo "Read-only · inspect P0 Mission Control sources · no mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) FILE GATE ==="

{
  echo -e "path\texists\tbytes\tlines\tsha256"
  for f in "${SOURCES[@]}"; do
    if [ -f "$f" ]; then
      printf "%s\tYES\t%s\t%s\t%s\n" \
        "$f" \
        "$(stat -c%s "$f")" \
        "$(wc -l < "$f" | tr -d ' ')" \
        "$(sha256sum "$f" | awk '{print $1}')"
    else
      printf "%s\tNO\t0\t0\tMISSING\n" "$f"
    fi
  done
} | tee "$FILES" | column -t -s $'\t'

echo
echo "=== 2) HTML STRUCTURE SCAN ==="

python3 - "$STRUCT" "${SOURCES[@]}" <<'PY'
import re
import sys
from pathlib import Path
from html.parser import HTMLParser

out = Path(sys.argv[1])
sources = [Path(p) for p in sys.argv[2:]]

class ScanParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tags = {}
        self.ids = []
        self.classes = []
        self.scripts = 0
        self.styles = 0
        self.links = 0
        self.iframes = 0
        self.inline_handlers = 0
        self.text = []

    def handle_starttag(self, tag, attrs):
        self.tags[tag] = self.tags.get(tag, 0) + 1
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if "class" in attrs:
            self.classes.extend(attrs["class"].split())
        if tag == "script":
            self.scripts += 1
        if tag == "style":
            self.styles += 1
        if tag == "link":
            self.links += 1
        if tag == "iframe":
            self.iframes += 1
        for k in attrs:
            if k.lower().startswith("on"):
                self.inline_handlers += 1

    def handle_data(self, data):
        s = " ".join(data.split())
        if s:
            self.text.append(s)

rows = []
for src in sources:
    if not src.exists():
        rows.append([str(src), "NO", "0", "0", "0", "0", "0", "0", "-", "-"])
        continue

    html = src.read_text(encoding="utf-8", errors="replace")
    p = ScanParser()
    p.feed(html)

    title = "-"
    m = re.search(r"<title[^>]*>(.*?)</title>", html, flags=re.I | re.S)
    if m:
        title = " ".join(m.group(1).split())[:160]

    h1 = "-"
    m = re.search(r"<h1[^>]*>(.*?)</h1>", html, flags=re.I | re.S)
    if m:
        h1 = re.sub(r"<.*?>", " ", m.group(1))
        h1 = " ".join(h1.split())[:160]

    rows.append([
        str(src),
        "YES",
        str(len(html)),
        str(p.scripts),
        str(p.styles),
        str(p.links),
        str(p.iframes),
        str(p.inline_handlers),
        title,
        h1,
    ])

out.write_text(
    "path\texists\tbytes\tscript_tags\tstyle_tags\tlink_tags\tiframe_tags\tinline_handlers\ttitle\th1\n"
    + "\n".join("\t".join(r) for r in rows) + "\n",
    encoding="utf-8",
)
PY

column -t -s $'\t' "$STRUCT"

echo
echo "=== 3) CONTENT TOKEN SCAN ==="

{
  echo -e "path\tline\tmatch"
  grep -RIn \
    -E "Mission|Control|Integration|Portal|Index|NOC|SOC|RF|Telco|Domain|Navigation|Registry|Open5GS|UERANSIM|Antenna|Signal|Knowledge|Command|Evidence|Dashboard|Scenario|Digital Twin" \
    "${SOURCES[@]}" 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,280)}'
} | tee "$TOKENS" | sed -n '1,180p'

echo
echo "=== 4) DEBT / RISK SCAN ==="

{
  echo -e "path\tline\tmatch"
  grep -RIn \
    -E "TODO|FIXME|PLACEHOLDER|mock|fake|lorem|undefined|null|iframe|dangerouslySetInnerHTML|document.write|innerHTML|cdn|http://|https://|TODO|coming soon" \
    "${SOURCES[@]}" 2>/dev/null \
    | awk -F: 'BEGIN{OFS="\t"} {text=$0; sub(/^[^:]+:[^:]+:/,"",text); print $1,$2,substr(text,1,280)}' \
    || true
} | tee "$DEBT" | sed -n '1,180p'

echo
echo "=== 5) BUILD CHECK READ-ONLY ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

echo
echo "=== 6) HTTP CHECK READ-ONLY ==="

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
check_url "http://127.0.0.1:5173/trfmc_home_v87g.html"
check_url "http://127.0.0.1:5173/trfmc_integration_control_room.html"
check_url "http://127.0.0.1:5173/portal_index_v19.html"
check_url "http://127.0.0.1:8000/api/health"
check_url "http://127.0.0.1:4181/api/health"

SOURCE_FAILS="$(awk 'NR>1 && $2!="YES" {c++} END {print c+0}' "$FILES")"
DEBT_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$DEBT")"
TOKEN_COUNT="$(awk 'NR>1 {c++} END {print c+0}' "$TOKENS")"
HTTP_NON_200="$(awk 'NR>1 && $2 != 200 {c++} END {print c+0}' "$HTTP")"
HTTP_ZERO_BYTES="$(awk 'NR>1 && $3 == 0 {c++} END {print c+0}' "$HTTP")"

cat > "$PLAN" <<MD
# TRFMC P0C Mission Control Promotion Plan

## Scope
Promote Mission Control content into React, without iframe and without using public HTML as a parallel portal.

## Source priority
1. \`frontend/public/trfmc_home_v87g.html\` — home / mission overview reference.
2. \`frontend/public/trfmc_integration_control_room.html\` — integration control room content source.
3. \`frontend/public/portal_index_v19.html\` — portal index / domain structure source.

## Required output for next mutation
\`TRFMC_P0C_MISSION_CONTROL_CONTENT_PROMOTION_V1\` must create or update:
- \`frontend/src/app/MissionControlHomeP0C.tsx\`
- \`frontend/src/app/MissionControlIntegrationRoomP0C.tsx\`
- optional \`frontend/src/app/MissionControlPortalIndexP0C.tsx\`
- controlled mount below P0B registry, not above the global shell
- QA: build, HTTP, DOM marker, screenshot, no iframe, no dangerous innerHTML

## Hard rules
- No backend mutation.
- No public asset mutation.
- No index mutation.
- No iframe.
- No \`dangerouslySetInnerHTML\`.
- No copy/paste of full HTML into React.
- Extract structure, labels, cards, domain references and operational logic only.
MD

RESULT="P0C_AUDIT_READY"
if [ "$SOURCE_FAILS" != "0" ]; then RESULT="REVIEW_SOURCE_FILES"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$HTTP_ZERO_BYTES" != "0" ]; then RESULT="REVIEW_HTTP_BYTES"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P0C_MISSION_CONTROL_SOURCE_AUDIT_READONLY",
  "mutation": false,
  "source_mutation": false,
  "backend_mutation": false,
  "index_mutation": false,
  "public_asset_mutation": false,
  "out": "$OUT",
  "file_gate": "$FILES",
  "html_structure": "$STRUCT",
  "content_tokens": "$TOKENS",
  "debt_scan": "$DEBT",
  "plan": "$PLAN",
  "build_log": "$BUILDLOG",
  "http_tsv": "$HTTP",
  "source_failures": $SOURCE_FAILS,
  "token_count": $TOKEN_COUNT,
  "debt_count": $DEBT_COUNT,
  "build_result": "$BUILD_RESULT",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p0c_mission_control_source_audit_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,160p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P0C_MISSION_CONTROL_SOURCE_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
