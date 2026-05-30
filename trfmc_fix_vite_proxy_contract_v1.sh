#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FIX_VITE_PROXY_CONTRACT_V1_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
VITE_CONFIG=""
for c in frontend/vite.config.ts frontend/vite.config.js frontend/vite.config.mts frontend/vite.config.mjs; do
  [ -f "$c" ] && VITE_CONFIG="$c" && break
done

DIFF="$OUT/vite_proxy_contract.diff"
BUILDLOG="$OUT/npm_build_after_proxy_fix.log"
VITELOG="$OUT/vite_restart_after_proxy_fix.log"
API="$OUT/proxy_api_contract_after_fix.tsv"
HTTP="$OUT/http_after_proxy_fix.tsv"
RESTORE="$OUT/RESTORE_VITE_PROXY_CONTRACT_V1.sh"

echo "============================================================"
echo "TRFMC_FIX_VITE_PROXY_CONTRACT_V1"
echo "Fix mirato vite.config: /trfmc-api/backend + /trfmc-api/bridge"
echo "Timestamp: $TS"
echo "============================================================"

if [ -z "$VITE_CONFIG" ] || [ ! -f "$VITE_CONFIG" ]; then
  echo "ERRORE: vite.config non trovato"
  exit 1
fi

cp -a "$VITE_CONFIG" "$BACKUP/$(basename "$VITE_CONFIG").before_$TS"

cat > "$RESTORE" <<RESTORE_EOF
#!/usr/bin/env bash
set -u
cd "$BASE" || exit 1
cp -a "$BACKUP/$(basename "$VITE_CONFIG").before_$TS" "$VITE_CONFIG"
echo "RESTORE_VITE_PROXY_CONTRACT_V1 completato"
RESTORE_EOF
chmod +x "$RESTORE"

echo
echo "=== 1) VITE CONFIG PRIMA ==="
sed -n '1,220p' "$VITE_CONFIG" | tee "$OUT/vite_config_before.txt"

echo
echo "=== 2) PATCH VITE CONFIG ==="

python3 - "$VITE_CONFIG" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

proxy_entries = """      '/trfmc-api/backend': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/backend/, ''),
      },
      '/trfmc-api/bridge': {
        target: 'http://127.0.0.1:4181',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/bridge/, ''),
      },"""

server_block = """  server: {
    proxy: {
      '/trfmc-api/backend': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/backend/, ''),
      },
      '/trfmc-api/bridge': {
        target: 'http://127.0.0.1:4181',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/bridge/, ''),
      },
    },
  },"""

def find_matching_brace(s, open_idx):
    depth = 0
    quote = None
    escape = False
    line_comment = False
    block_comment = False
    template = False

    i = open_idx
    while i < len(s):
        ch = s[i]
        nxt = s[i + 1] if i + 1 < len(s) else ''

        if line_comment:
            if ch == '\n':
                line_comment = False
            i += 1
            continue

        if block_comment:
            if ch == '*' and nxt == '/':
                block_comment = False
                i += 2
                continue
            i += 1
            continue

        if quote:
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == quote:
                quote = None
            i += 1
            continue

        if ch == '/' and nxt == '/':
            line_comment = True
            i += 2
            continue

        if ch == '/' and nxt == '*':
            block_comment = True
            i += 2
            continue

        if ch in ("'", '"', '`'):
            quote = ch
            i += 1
            continue

        if ch == '{':
            depth += 1

        if ch == '}':
            depth -= 1
            if depth == 0:
                return i

        i += 1

    return -1

if "/trfmc-api/backend" in text and "/trfmc-api/bridge" in text:
    print("PATCH_APPLIED=NO_ALREADY_PRESENT")
    p.write_text(text, encoding="utf-8")
    sys.exit(0)

idx = text.find("defineConfig")
if idx == -1:
    idx = text.find("export default")
if idx == -1:
    raise SystemExit("defineConfig/export default non trovato")

root_open = text.find("{", idx)
if root_open == -1:
    raise SystemExit("oggetto config non trovato")

root_close = find_matching_brace(text, root_open)
if root_close == -1:
    raise SystemExit("chiusura oggetto config non trovata")

root_body = text[root_open + 1:root_close]

# Se non c'è server:, inserisco un blocco server completo all'inizio dell'oggetto.
if "server:" not in root_body:
    text = text[:root_open + 1] + "\n" + server_block + text[root_open + 1:]
    p.write_text(text, encoding="utf-8")
    print("PATCH_APPLIED=YES_INSERTED_SERVER_BLOCK")
    sys.exit(0)

# C'è server:. Trovo il blocco server e inserisco proxy se manca.
server_pos = text.find("server:", root_open, root_close)
server_obj_open = text.find("{", server_pos)
if server_obj_open == -1 or server_obj_open > root_close:
    raise SystemExit("server presente ma oggetto server non trovato")

server_obj_close = find_matching_brace(text, server_obj_open)
if server_obj_close == -1:
    raise SystemExit("chiusura server object non trovata")

server_body = text[server_obj_open + 1:server_obj_close]

if "proxy:" not in server_body:
    proxy_block = """\n    proxy: {\n""" + proxy_entries + """\n    },"""
    text = text[:server_obj_open + 1] + proxy_block + text[server_obj_open + 1:]
    p.write_text(text, encoding="utf-8")
    print("PATCH_APPLIED=YES_INSERTED_PROXY_IN_SERVER")
    sys.exit(0)

# C'è già proxy:, inserisco solo le entry mancanti nel blocco proxy.
proxy_pos = text.find("proxy:", server_obj_open, server_obj_close)
proxy_obj_open = text.find("{", proxy_pos)
if proxy_obj_open == -1 or proxy_obj_open > server_obj_close:
    raise SystemExit("proxy presente ma oggetto proxy non trovato")

proxy_obj_close = find_matching_brace(text, proxy_obj_open)
if proxy_obj_close == -1:
    raise SystemExit("chiusura proxy object non trovata")

insert = ""
if "/trfmc-api/backend" not in text[proxy_obj_open:proxy_obj_close]:
    insert += """\n""" + """      '/trfmc-api/backend': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/backend/, ''),
      },"""
if "/trfmc-api/bridge" not in text[proxy_obj_open:proxy_obj_close]:
    insert += """\n""" + """      '/trfmc-api/bridge': {
        target: 'http://127.0.0.1:4181',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/bridge/, ''),
      },"""

if not insert:
    print("PATCH_APPLIED=NO_PROXY_ENTRIES_ALREADY_PRESENT")
else:
    text = text[:proxy_obj_open + 1] + insert + text[proxy_obj_open + 1:]
    p.write_text(text, encoding="utf-8")
    print("PATCH_APPLIED=YES_INSERTED_PROXY_ENTRIES")
PY

PATCH_RC="$?"

if [ "$PATCH_RC" != "0" ]; then
  echo "ERRORE: patch vite.config fallita. Non proseguo."
  exit 1
fi

echo
echo "=== 3) VITE CONFIG DOPO ==="
sed -n '1,260p' "$VITE_CONFIG" | tee "$OUT/vite_config_after.txt"

echo
echo "=== 4) DIFF ==="
git diff -- "$VITE_CONFIG" > "$DIFF" 2>/dev/null || true
cat "$DIFF"

echo
echo "=== 5) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 80 "$BUILDLOG"

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  bash "$RESTORE"
fi

echo
echo "=== 6) RESTART VITE 5173 ==="

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
fi

echo
echo "=== 7) HTTP GATE ==="

cat > "$HTTP" <<HDR
url	status	bytes	content_hint	classification
HDR

check_http() {
  url="$1"
  tmp="$(mktemp)"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  bytes="$(wc -c < "$tmp" | tr -d ' ')"
  hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" && hint="HTML"
  python3 - "$tmp" <<'PY' >/tmp/trfmc_json_hint_proxy.$$ 2>/dev/null
import json,sys
try:
    json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    print("JSON")
except Exception:
    print("")
PY
  jh="$(cat /tmp/trfmc_json_hint_proxy.$$ 2>/dev/null)"
  rm -f /tmp/trfmc_json_hint_proxy.$$
  [ "$jh" = "JSON" ] && hint="JSON"
  cls="OK"
  [ "$code" != "200" ] && cls="NON_200"
  [ "$bytes" = "0" ] && cls="ZERO_BYTES"
  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$hint" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_http "http://127.0.0.1:5173/"
check_http "http://127.0.0.1:5173/#portal-os-preview"
check_http "http://127.0.0.1:8000/api/health"
check_http "http://127.0.0.1:4181/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/backend/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

echo
echo "=== 8) API CONTRACT JSON GATE ==="

cat > "$API" <<HDR
name	url	status	bytes	content_type	json_parse	html_fallback	keys_or_error	verdict
HDR

api_contract() {
  name="$1"
  url="$2"
  raw="$OUT/api_${name}.body"
  headers="$OUT/api_${name}.headers"
  code="$(curl -sS -L --max-time 8 -D "$headers" -o "$raw" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  bytes="$(wc -c < "$raw" 2>/dev/null | tr -d ' ')"
  ctype="$(grep -i '^content-type:' "$headers" 2>/dev/null | tail -n 1 | sed 's/\r//g' | cut -d':' -f2- | xargs)"
  [ -z "$ctype" ] && ctype="-"

  parse="$(python3 - "$raw" <<'PY' 2>/dev/null
import json, sys
text=open(sys.argv[1], encoding="utf-8", errors="replace").read()
try:
    obj=json.loads(text)
    if isinstance(obj, dict):
        print("YES\t" + ",".join(list(obj.keys())[:10]))
    else:
        print("YES\ttype=" + type(obj).__name__)
except Exception as e:
    first=text[:90].replace("\n"," ")
    print("NO\t" + str(e)[:80] + " first=" + first)
PY
)"
  json_parse="$(echo "$parse" | cut -f1)"
  note="$(echo "$parse" | cut -f2-)"
  html_fallback="NO"
  grep -qi '<!doctype\|<html\|/@vite/client' "$raw" && html_fallback="YES"

  verdict="OK"
  [ "$code" != "200" ] && verdict="NON_200"
  [ "$json_parse" != "YES" ] && verdict="NOT_JSON"
  [ "$html_fallback" = "YES" ] && verdict="HTML_FALLBACK"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$url" "$code" "$bytes" "$ctype" "$json_parse" "$html_fallback" "$note" "$verdict" >> "$API"
}

api_contract "backend_health_direct" "http://127.0.0.1:8000/api/health"
api_contract "bridge_health_direct" "http://127.0.0.1:4181/api/health"
api_contract "proxy_backend_health_vite" "http://127.0.0.1:5173/trfmc-api/backend/api/health"
api_contract "proxy_bridge_health_vite" "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

column -t -s $'\t' "$API"

API_BLOCKERS="$(awk -F'\t' 'NR>1 && $9!="OK"{c++} END{print c+0}' "$API")"
PROXY_BLOCKERS="$(awk -F'\t' 'NR>1 && $1 ~ /^proxy_/ && $9!="OK"{c++} END{print c+0}' "$API")"

RESULT="PASS"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$API_BLOCKERS" != "0" ]; then RESULT="REVIEW_API_CONTRACT"; fi
if [ "$PROXY_BLOCKERS" != "0" ]; then RESULT="REVIEW_PROXY_STILL_BROKEN"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FIX_VITE_PROXY_CONTRACT_V1",
  "mutation": "vite_config_server_proxy",
  "vite_config": "$VITE_CONFIG",
  "restore_script": "$RESTORE",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "vite_log": "$VITELOG",
  "http_gate": "$HTTP",
  "api_contracts": "$API",
  "vite_pid": "$VITE_PID",
  "build_result": "$BUILD_RESULT",
  "api_blockers": $API_BLOCKERS,
  "proxy_blockers": $PROXY_BLOCKERS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_fix_vite_proxy_contract_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_FIX_VITE_PROXY_CONTRACT_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
