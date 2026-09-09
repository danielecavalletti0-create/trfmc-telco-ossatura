#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FIX_RTSTREAMSTORE_SYNTAX_ERROR_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE" || exit 1

FILE="frontend/src/stores/rtStreamStore.ts"
SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_after_rtstream_fix.log"
HTTP="$OUT/http_after_rtstream_fix.tsv"
DOM="$OUT/dom_after_rtstream_fix.txt"
SCREEN="$OUT/screen_after_rtstream_fix_1920x1080.png"
VITELOG="$OUT/vite_restart_after_rtstream_fix.log"
DIFF="$OUT/rtstreamstore_fix.diff"
RESTORE="$OUT/RESTORE_RTSTREAMSTORE_SYNTAX_FIX_V1.sh"

echo "============================================================"
echo "TRFMC_FIX_RTSTREAMSTORE_SYNTAX_ERROR_V1"
echo "Fix mirato: frontend/src/stores/rtStreamStore.ts linee 358-360"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$FILE" ]; then
  echo "ERRORE: file non trovato: $FILE"
  exit 1
fi

cp -a "$FILE" "$BACKUP/rtStreamStore.ts.before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -u
cd "$BASE" || exit 1
cp -a "$BACKUP/rtStreamStore.ts.before_$TS" "$FILE"
echo "RESTORE_RTSTREAMSTORE_SYNTAX_FIX_V1 completato"
RESTORE_EOF
chmod +x "$RESTORE"

echo
echo "=== 1) CONTESTO PRIMA DEL FIX ==="
nl -ba "$FILE" | sed -n '330,375p' | tee "$OUT/context_before.txt"

echo
echo "=== 2) PATCH MIRATA ==="

python3 - "$FILE" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

# Caso specifico visto da Vite:
#   _nextId: 0
# }))
#
# Dentro questo store il blocco è un set({ ... }), quindi la chiusura corretta è:
# })
#
# La sostituzione è limitata all'area con _nextId: 0 per evitare modifiche cieche altrove.
patterns = [
    (
        r"(_nextId:\s*0\s*\n)([ \t]*)\}\)\)",
        r"\1\2})",
        "extra_closing_paren_after_nextId"
    ),
]

applied = []
for pat, repl, name in patterns:
    text2, n = re.subn(pat, repl, text, count=1)
    if n:
        text = text2
        applied.append(name)

if not applied:
    print("PATCH_APPLIED=NO")
    print("Motivo: pattern esatto non trovato. Stampo area sospetta.")
    lines = before.splitlines()
    for i in range(max(0, 340-1), min(len(lines), 370)):
        print(f"{i+1:04d}: {lines[i]}")
    sys.exit(2)

p.write_text(text, encoding="utf-8")
print("PATCH_APPLIED=YES")
print("PATCH_NAMES=" + ",".join(applied))
PY

PATCH_RC="$?"

if [ "$PATCH_RC" != "0" ]; then
  echo "PATCH fallita: non proseguo."
  cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FIX_RTSTREAMSTORE_SYNTAX_ERROR_V1",
  "mutation": "none",
  "patch_result": "FAILED_PATTERN_NOT_FOUND",
  "restore_script": "$RESTORE",
  "result": "REVIEW_PATTERN_NOT_FOUND"
}
JSON
  python3 -m json.tool "$SUMMARY"
  exit 1
fi

echo
echo "=== 3) CONTESTO DOPO IL FIX ==="
nl -ba "$FILE" | sed -n '330,375p' | tee "$OUT/context_after.txt"

echo
echo "=== 4) DIFF ==="
git diff -- "$FILE" > "$DIFF" 2>/dev/null || true
cat "$DIFF"

echo
echo "=== 5) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 100 "$BUILDLOG"

echo
echo "=== 6) RIAVVIO VITE SOLO SE BUILD PASS ==="

VITE_PID="NONE"

if [ "$BUILD_RESULT" = "PASS" ]; then
  OLD_PID="$(ss -ltnp 2>/dev/null | awk '/:5173/ {print $NF}' | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | head -n 1)"
  echo "OLD_PID_5173=${OLD_PID:-NONE}"

  if [ -n "$OLD_PID" ]; then
    kill "$OLD_PID"
    sleep 2
  fi

  cd "$BASE/frontend"
  nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$VITELOG" 2>&1 &
  VITE_PID="$!"
  cd "$BASE"

  sleep 5
else
  echo "Build ancora fallita: non riavvio Vite."
fi

echo
echo "=== 7) HTTP GATE ==="

cat > "$HTTP" <<HTTPHDR
url	status	bytes	classification
HTTPHDR

check_url() {
  url="$1"
  tmp="$(mktemp)"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  cls="OK"
  if [ "$code" != "200" ]; then cls="NON_200"; fi
  if [ "$bytes" = "0" ]; then cls="ZERO_BYTES"; fi
  printf "%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_url "http://127.0.0.1:5173/"
check_url "http://127.0.0.1:5173/#portal-os-preview"
check_url "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html"

HTTP_FAILS="$(awk -F'\t' 'NR>1 && $4!="OK"{c++} END{print c+0}' "$HTTP")"

echo
echo "=== 8) DOM / SCREENSHOT GATE ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if [ "$BUILD_RESULT" = "PASS" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    CHROME_BIN="google-chrome"
  elif command -v chromium >/dev/null 2>&1; then
    CHROME_BIN="chromium"
  else
    CHROME_BIN=""
  fi

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "http://127.0.0.1:5173/#portal-os-preview" > "$DOM" 2> "$OUT/chrome_dom.stderr.log" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$SCREEN" \
      "http://127.0.0.1:5173/#portal-os-preview" >/dev/null 2> "$OUT/chrome_screenshot.stderr.log" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
  else
    echo "NO_CHROME_AVAILABLE" > "$DOM"
  fi
else
  echo "BUILD_FAIL" > "$DOM"
fi

PORTAL_OS_COUNT="$(grep -o 'data-trfmc-portal-os-preview="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
P6A_COUNT="$(grep -o 'data-trfmc-p6a-working-real-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
P6B_COUNT="$(grep -o 'data-trfmc-p6b-all-working-pages="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
V42_COUNT="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD_STILL_FAILS"; fi
if [ "$HTTP_FAILS" != "0" ]; then RESULT="REVIEW_HTTP"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$PORTAL_OS_COUNT" = "0" ]; then RESULT="REVIEW_PORTAL_OS_NOT_RENDERED"; fi
if [ "$V42_COUNT" != "0" ]; then RESULT="REVIEW_V42_LEAK"; fi
if [ "$SCREENSHOT_RESULT" != "PASS" ]; then RESULT="REVIEW_SCREENSHOT"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FIX_RTSTREAMSTORE_SYNTAX_ERROR_V1",
  "mutation": "frontend_src_stores_rtStreamStore_syntax_fix",
  "file": "$FILE",
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "vite_log": "$VITELOG",
  "http_gate": "$HTTP",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "vite_pid": "$VITE_PID",
  "build_result": "$BUILD_RESULT",
  "http_failures": $HTTP_FAILS,
  "dom_result": "$DOM_RESULT",
  "screenshot_result": "$SCREENSHOT_RESULT",
  "portal_os_count": $PORTAL_OS_COUNT,
  "p6a_count": $P6A_COUNT,
  "p6b_count": $P6B_COUNT,
  "v42_count": $V42_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_fix_rtstreamstore_syntax_error_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_FIX_RTSTREAMSTORE_SYNTAX_ERROR_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
