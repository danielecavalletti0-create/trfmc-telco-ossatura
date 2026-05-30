#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P6F_STATIC_DASHBOARDS_RETURN_NAV_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
HTTP="$OUT/http.tsv"
DOM="$OUT/dom_return_nav.tsv"
RESTORE="$OUT/RESTORE_P6F_STATIC_DASHBOARDS_RETURN_NAV_V1.sh"

TARGETS=(
  "frontend/public/trfmc_working_pages_control_room_v1.html"
  "frontend/public/trfmc_page_review_cockpit_v1.html"
)

echo "============================================================"
echo "TRFMC_P6F_STATIC_DASHBOARDS_RETURN_NAV_V1"
echo "Aggiunge return/navigation bar alle dashboard statiche"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) BACKUP TARGET ==="

for f in "${TARGETS[@]}"; do
  if [ -f "$f" ]; then
    cp -a "$f" "$BACKUP/$(basename "$f").before_$TS"
    echo "BACKUP $f"
  else
    echo "MISSING $f"
  fi
done

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -u
cd "$BASE" || exit 1
for b in "$BACKUP"/*.before_$TS; do
  [ -f "\$b" ] || continue
  name="\$(basename "\$b" ".before_$TS")"
  cp -a "\$b" "frontend/public/\$name"
  echo "RESTORED frontend/public/\$name"
done
echo "RESTORE_P6F_STATIC_DASHBOARDS_RETURN_NAV_V1 completato"
RESTORE_EOF

chmod +x "$RESTORE"

echo
echo "=== 2) PATCH NAV RETURN ==="

python3 - "$TS" "${TARGETS[@]}" <<'PY'
from pathlib import Path
import sys

ts = sys.argv[1]
targets = [Path(x) for x in sys.argv[2:]]

nav_html = """
<nav class="trfmc-return-nav" data-trfmc-return-nav="mounted">
  <button type="button" onclick="history.back()">← Indietro</button>
  <a href="/#portal-os-preview">Portal OS principale</a>
  <a href="/trfmc_working_pages_control_room_v1.html">Working Pages</a>
  <a href="/trfmc_page_review_cockpit_v1.html">Page Review Cockpit</a>
  <a href="/trfmc_rf_tm_war_room_v4.html">War Room</a>
</nav>
"""

css = """
/* TRFMC P6F RETURN NAV START */
.trfmc-return-nav {
  position: sticky;
  top: 0;
  z-index: 50;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
  padding: 10px 22px;
  border-bottom: 1px solid rgba(103, 232, 249, .18);
  background: rgba(2, 8, 18, .94);
  backdrop-filter: blur(18px);
}
.trfmc-return-nav a,
.trfmc-return-nav button {
  border: 1px solid rgba(103, 232, 249, .22);
  border-radius: 999px;
  padding: 8px 11px;
  color: #e8f7ff;
  background: rgba(0, 12, 24, .72);
  text-decoration: none;
  font-size: 12px;
  font-weight: 900;
  cursor: pointer;
}
.trfmc-return-nav a:hover,
.trfmc-return-nav button:hover {
  border-color: rgba(134, 239, 172, .58);
  color: #86efac;
  box-shadow: 0 0 20px rgba(16, 185, 129, .12);
}
/* TRFMC P6F RETURN NAV END */
"""

for path in targets:
    if not path.exists():
        print(f"SKIP_MISSING={path}")
        continue

    text = path.read_text(encoding="utf-8", errors="replace")
    before = text

    if "TRFMC P6F RETURN NAV START" not in text:
        if "</style>" in text:
            text = text.replace("</style>", css + "\n  </style>", 1)
        else:
            text = text.replace("</head>", f"<style>{css}</style>\n</head>", 1)

    if 'data-trfmc-return-nav="mounted"' not in text:
        if "<body" in text:
            idx = text.find(">", text.find("<body"))
            if idx != -1:
                text = text[:idx + 1] + "\n" + nav_html + text[idx + 1:]
            else:
                raise SystemExit(f"BODY_OPEN_NOT_FOUND={path}")
        else:
            raise SystemExit(f"BODY_NOT_FOUND={path}")

    path.write_text(text, encoding="utf-8")
    print(f"PATCHED={path} changed={text != before}")
PY

echo
echo "=== 3) HTTP VERIFY ==="

cat > "$HTTP" <<HDR
url	status	bytes	hint	result
HDR

check_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  local bytes
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  local hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
  local result="OK"
  [ "$code" != "200" ] && result="NON_200"
  [ "$bytes" = "0" ] && result="ZERO_BYTES"
  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$hint" "$result" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/trfmc_working_pages_control_room_v1.html"
check_url "http://127.0.0.1:5173/trfmc_page_review_cockpit_v1.html"
check_url "http://127.0.0.1:5173/#portal-os-preview"

HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

echo
echo "=== 4) DOM VERIFY ==="

cat > "$DOM" <<HDR
page	dom_result	return_nav_count	portal_link_count	working_link_count	review_link_count	result
HDR

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

probe_dom() {
  local label="$1"
  local url="$2"
  local dom_file="$OUT/dom_${label}.txt"
  local dom_result="SKIPPED_NO_CHROME"

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=6000 \
      --dump-dom \
      "$url" > "$dom_file" 2> "$OUT/chrome_${label}.stderr.log" && dom_result="PASS" || dom_result="FAIL"
  else
    echo "NO_CHROME" > "$dom_file"
  fi

  local nav_count
  local portal_count
  local working_count
  local review_count
  nav_count="$(grep -o 'data-trfmc-return-nav="mounted"' "$dom_file" 2>/dev/null | wc -l | tr -d ' ')"
  portal_count="$(grep -o 'href="/#portal-os-preview"' "$dom_file" 2>/dev/null | wc -l | tr -d ' ')"
  working_count="$(grep -o 'href="/trfmc_working_pages_control_room_v1.html"' "$dom_file" 2>/dev/null | wc -l | tr -d ' ')"
  review_count="$(grep -o 'href="/trfmc_page_review_cockpit_v1.html"' "$dom_file" 2>/dev/null | wc -l | tr -d ' ')"

  local result="OK"
  [ "$dom_result" != "PASS" ] && result="DOM_FAIL"
  [ "$nav_count" = "0" ] && result="NAV_MISSING"
  [ "$portal_count" = "0" ] && result="PORTAL_LINK_MISSING"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$label" "$dom_result" "$nav_count" "$portal_count" "$working_count" "$review_count" "$result" | tee -a "$DOM"
}

probe_dom "working_pages" "http://127.0.0.1:5173/trfmc_working_pages_control_room_v1.html"
probe_dom "page_review" "http://127.0.0.1:5173/trfmc_page_review_cockpit_v1.html"

DOM_FAILS="$(awk -F'\t' 'NR>1 && $7!="OK"{c++} END{print c+0}' "$DOM")"

RESULT="PASS"
[ "$HTTP_FAILS" != "0" ] && RESULT="FAIL_HTTP"
[ "$DOM_FAILS" != "0" ] && RESULT="FAIL_DOM_NAV"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P6F_STATIC_DASHBOARDS_RETURN_NAV_V1",
  "mutation": "public_static_dashboard_return_nav",
  "react_mutation": false,
  "backend_mutation": false,
  "targets": [
    "frontend/public/trfmc_working_pages_control_room_v1.html",
    "frontend/public/trfmc_page_review_cockpit_v1.html"
  ],
  "restore_script": "$RESTORE",
  "http_gate": "$HTTP",
  "dom_gate": "$DOM",
  "http_failures": $HTTP_FAILS,
  "dom_failures": $DOM_FAILS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p6f_static_dashboards_return_nav_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_P6F_STATIC_DASHBOARDS_RETURN_NAV_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
