#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FIX_VITE_PROXY_CONTRACT_V2_CORRECT_ROOT_$TS"
BACKUP="$OUT/backup"

mkdir -p "$OUT" "$BACKUP"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
VITE_CONFIG=""

for c in frontend/vite.config.ts frontend/vite.config.js frontend/vite.config.mts frontend/vite.config.mjs; do
  [ -f "$c" ] && VITE_CONFIG="$c" && break
done

DIFF="$OUT/vite_proxy_contract_v2.diff"
BUILDLOG="$OUT/npm_build_after_proxy_v2.log"
VITELOG="$OUT/vite_restart_after_proxy_v2.log"
API="$OUT/proxy_api_contract_after_v2.tsv"
HTTP="$OUT/http_after_proxy_v2.tsv"
STATIC="$OUT/proxy_static_gate_v2.tsv"
RESTORE="$OUT/RESTORE_VITE_PROXY_CONTRACT_V2_CORRECT_ROOT.sh"

echo "============================================================"
echo "TRFMC_FIX_VITE_PROXY_CONTRACT_V2_CORRECT_ROOT"
echo "Corregge errore V1: server.proxy deve stare dentro defineConfig root"
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
echo "RESTORE_VITE_PROXY_CONTRACT_V2_CORRECT_ROOT completato"
RESTORE_EOF
chmod +x "$RESTORE"

echo
echo "=== 1) CONFIG PRIMA ==="
sed -n '1,260p' "$VITE_CONFIG" | tee "$OUT/vite_config_before_v2.txt"

echo
echo "=== 2) PATCH CORRETTA ==="

python3 - "$VITE_CONFIG" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
before = text

backend_entry = """      '/trfmc-api/backend': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/backend/, ''),
      },"""

bridge_entry = """      '/trfmc-api/bridge': {
        target: 'http://127.0.0.1:4181',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\\/trfmc-api\\/bridge/, ''),
      },"""

proxy_block_inside_server = f"""
    proxy: {{
{backend_entry}
{bridge_entry}
    }},"""

server_block = f"""
  server: {{
    proxy: {{
{backend_entry}
{bridge_entry}
    }},
  }},"""

def matching_brace(s: str, open_idx: int) -> int:
    depth = 0
    quote = None
    escape = False
    line_comment = False
    block_comment = False

    i = open_idx
    while i < len(s):
        ch = s[i]
        nxt = s[i + 1] if i + 1 < len(s) else ""

        if line_comment:
            if ch == "\n":
                line_comment = False
            i += 1
            continue

        if block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 2
                continue
            i += 1
            continue

        if quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            i += 1
            continue

        if ch == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue

        if ch in ("'", '"', "`"):
            quote = ch
            i += 1
            continue

        if ch == "{":
            depth += 1

        if ch == "}":
            depth -= 1
            if depth == 0:
                return i

        i += 1

    return -1

def find_export_define_config_object(s: str):
    # Importante: NON usare il primo "defineConfig", perché compare nell'import:
    # import { defineConfig } from 'vite'
    m = re.search(r"export\s+default\s+defineConfig\s*\(", s)
    if not m:
        raise SystemExit("export default defineConfig(...) non trovato")

    open_idx = s.find("{", m.end())
    if open_idx == -1:
        raise SystemExit("oggetto defineConfig non trovato")

    close_idx = matching_brace(s, open_idx)
    if close_idx == -1:
        raise SystemExit("chiusura oggetto defineConfig non trovata")

    return open_idx, close_idx

def find_top_level_property(s: str, obj_open: int, obj_close: int, prop: str):
    depth = 0
    quote = None
    escape = False
    line_comment = False
    block_comment = False
    i = obj_open + 1

    while i < obj_close:
        ch = s[i]
        nxt = s[i + 1] if i + 1 < len(s) else ""

        if line_comment:
            if ch == "\n":
                line_comment = False
            i += 1
            continue

        if block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 2
                continue
            i += 1
            continue

        if quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            i += 1
            continue

        if ch == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue

        if ch in ("'", '"', "`"):
            quote = ch
            i += 1
            continue

        if ch == "{":
            depth += 1
            i += 1
            continue

        if ch == "}":
            depth -= 1
            i += 1
            continue

        if depth == 0 and s.startswith(prop, i):
            j = i + len(prop)
            while j < obj_close and s[j].isspace():
                j += 1
            if j < obj_close and s[j] == ":":
                return i, j

        i += 1

    return None

def remove_wrong_server_from_trfmc_health_plugin(s: str) -> str:
    m = re.search(r"const\s+trfmcHealthPlugin\s*=\s*\{", s)
    if not m:
        return s

    plugin_open = s.find("{", m.start())
    plugin_close = matching_brace(s, plugin_open)
    if plugin_close == -1:
        return s

    plugin_text = s[plugin_open:plugin_close + 1]
    if "/trfmc-api/backend" not in plugin_text and "/trfmc-api/bridge" not in plugin_text:
        return s

    # Trova property server: top-level del plugin.
    prop = find_top_level_property(s, plugin_open, plugin_close, "server")
    if not prop:
        return s

    prop_start, colon_pos = prop
    obj_open = s.find("{", colon_pos, plugin_close)
    if obj_open == -1:
        return s

    obj_close = matching_brace(s, obj_open)
    if obj_close == -1:
        return s

    # Rimuove anche la virgola seguente e spazi/newline.
    remove_start = prop_start
    while remove_start > 0 and s[remove_start - 1] in " \t":
        remove_start -= 1

    # Se la riga inizia subito prima, prendi anche newline precedente.
    if remove_start > 0 and s[remove_start - 1] == "\n":
        remove_start -= 0

    remove_end = obj_close + 1
    while remove_end < len(s) and s[remove_end].isspace():
        remove_end += 1
    if remove_end < len(s) and s[remove_end] == ",":
        remove_end += 1
    while remove_end < len(s) and s[remove_end] in " \t":
        remove_end += 1
    if remove_end < len(s) and s[remove_end] == "\n":
        remove_end += 1

    return s[:remove_start] + s[remove_end:]

def add_proxy_to_define_config_root(s: str) -> str:
    cfg_open, cfg_close = find_export_define_config_object(s)

    cfg_body = s[cfg_open:cfg_close + 1]
    if "/trfmc-api/backend" in cfg_body and "/trfmc-api/bridge" in cfg_body:
        return s

    server_prop = find_top_level_property(s, cfg_open, cfg_close, "server")

    if not server_prop:
        return s[:cfg_open + 1] + server_block + s[cfg_open + 1:]

    _, server_colon = server_prop
    server_open = s.find("{", server_colon, cfg_close)
    if server_open == -1:
        raise SystemExit("server presente ma oggetto server non trovato")

    server_close = matching_brace(s, server_open)
    if server_close == -1:
        raise SystemExit("chiusura server object non trovata")

    server_body = s[server_open:server_close + 1]
    proxy_prop = find_top_level_property(s, server_open, server_close, "proxy")

    if not proxy_prop:
        return s[:server_open + 1] + proxy_block_inside_server + s[server_open + 1:]

    _, proxy_colon = proxy_prop
    proxy_open = s.find("{", proxy_colon, server_close)
    if proxy_open == -1:
        raise SystemExit("proxy presente ma oggetto proxy non trovato")

    proxy_close = matching_brace(s, proxy_open)
    if proxy_close == -1:
        raise SystemExit("chiusura proxy object non trovata")

    proxy_body = s[proxy_open:proxy_close + 1]

    insert = ""
    if "/trfmc-api/backend" not in proxy_body:
        insert += "\n" + backend_entry
    if "/trfmc-api/bridge" not in proxy_body:
        insert += "\n" + bridge_entry

    if not insert:
        return s

    return s[:proxy_open + 1] + insert + s[proxy_open + 1:]

text = remove_wrong_server_from_trfmc_health_plugin(text)
text = add_proxy_to_define_config_root(text)

# Validazioni testuali post-patch.
cfg_open, cfg_close = find_export_define_config_object(text)
cfg_body = text[cfg_open:cfg_close + 1]

plugin_m = re.search(r"const\s+trfmcHealthPlugin\s*=\s*\{", text)
plugin_has_proxy = False
if plugin_m:
    po = text.find("{", plugin_m.start())
    pc = matching_brace(text, po)
    if pc != -1:
        plugin_has_proxy = "/trfmc-api/backend" in text[po:pc+1] or "/trfmc-api/bridge" in text[po:pc+1]

root_has_proxy = "/trfmc-api/backend" in cfg_body and "/trfmc-api/bridge" in cfg_body and "proxy:" in cfg_body

if plugin_has_proxy:
    raise SystemExit("ERRORE: proxy ancora dentro trfmcHealthPlugin")

if not root_has_proxy:
    raise SystemExit("ERRORE: proxy non presente nel defineConfig root")

p.write_text(text, encoding="utf-8")

print("PATCH_APPLIED=", text != before)
print("PLUGIN_HAS_PROXY=", plugin_has_proxy)
print("ROOT_HAS_PROXY=", root_has_proxy)
PY

PATCH_RC="$?"

if [ "$PATCH_RC" != "0" ]; then
  echo "ERRORE: patch V2 fallita. Non proseguo."
  cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FIX_VITE_PROXY_CONTRACT_V2_CORRECT_ROOT",
  "result": "PATCH_FAILED",
  "vite_config": "$VITE_CONFIG",
  "restore_script": "$RESTORE"
}
JSON
  python3 -m json.tool "$SUMMARY"
  exit 1
fi

echo
echo "=== 3) CONFIG DOPO ==="
sed -n '1,280p' "$VITE_CONFIG" | tee "$OUT/vite_config_after_v2.txt"

echo
echo "=== 4) STATIC GATE VITE CONFIG ==="

cat > "$STATIC" <<HDR
check	result	count
HDR

plugin_proxy_count="$(python3 - "$VITE_CONFIG" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
m = re.search(r"const\s+trfmcHealthPlugin\s*=\s*\{", text)
print(0 if not m else int("/trfmc-api/backend" in text[m.start():text.find("export default", m.start())]))
PY
)"

root_proxy_count="$(grep -n "/trfmc-api/backend\|/trfmc-api/bridge" "$VITE_CONFIG" | wc -l | tr -d ' ')"
server_proxy_count="$(grep -n "proxy:" "$VITE_CONFIG" | wc -l | tr -d ' ')"
rewrite_count="$(grep -n "rewrite:" "$VITE_CONFIG" | wc -l | tr -d ' ')"
change_origin_count="$(grep -n "changeOrigin" "$VITE_CONFIG" | wc -l | tr -d ' ')"

printf "plugin_proxy_absent\t%s\t%s\n" "$([ "$plugin_proxy_count" = "0" ] && echo PASS || echo FAIL)" "$plugin_proxy_count" >> "$STATIC"
printf "root_proxy_entries_present\t%s\t%s\n" "$([ "$root_proxy_count" -ge 2 ] && echo PASS || echo FAIL)" "$root_proxy_count" >> "$STATIC"
printf "server_proxy_present\t%s\t%s\n" "$([ "$server_proxy_count" -ge 1 ] && echo PASS || echo FAIL)" "$server_proxy_count" >> "$STATIC"
printf "rewrite_present\t%s\t%s\n" "$([ "$rewrite_count" -ge 2 ] && echo PASS || echo FAIL)" "$rewrite_count" >> "$STATIC"
printf "changeOrigin_present\t%s\t%s\n" "$([ "$change_origin_count" -ge 2 ] && echo PASS || echo FAIL)" "$change_origin_count" >> "$STATIC"

column -t -s $'\t' "$STATIC"

STATIC_FAILS="$(awk -F'\t' 'NR>1 && $2!="PASS"{c++} END{print c+0}' "$STATIC")"

echo
echo "=== 5) DIFF ==="
git diff -- "$VITE_CONFIG" > "$DIFF" 2>/dev/null || true
cat "$DIFF"

echo
echo "=== 6) BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 100 "$BUILDLOG"

if [ "$BUILD_RESULT" != "PASS" ]; then
  echo "BUILD FALLITA: restore automatico"
  bash "$RESTORE"
fi

echo
echo "=== 7) RESTART VITE 5173 ==="

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
echo "=== 8) HTTP GATE ==="

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

  python3 - "$tmp" <<'PY' >/tmp/trfmc_json_hint_proxy_v2.$$ 2>/dev/null
import json, sys
try:
    json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    print("JSON")
except Exception:
    print("")
PY
  jh="$(cat /tmp/trfmc_json_hint_proxy_v2.$$ 2>/dev/null)"
  rm -f /tmp/trfmc_json_hint_proxy_v2.$$
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
echo "=== 9) API CONTRACT JSON GATE ==="

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
        print("YES\t" + ",".join(list(obj.keys())[:12]))
    else:
        print("YES\ttype=" + type(obj).__name__)
except Exception as e:
    first=text[:100].replace("\n"," ")
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
if [ "$STATIC_FAILS" != "0" ]; then RESULT="REVIEW_STATIC_GATE"; fi
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$API_BLOCKERS" != "0" ]; then RESULT="REVIEW_API_CONTRACT"; fi
if [ "$PROXY_BLOCKERS" != "0" ]; then RESULT="REVIEW_PROXY_STILL_BROKEN"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FIX_VITE_PROXY_CONTRACT_V2_CORRECT_ROOT",
  "mutation": "vite_config_server_proxy_root_fix",
  "vite_config": "$VITE_CONFIG",
  "restore_script": "$RESTORE",
  "static_gate": "$STATIC",
  "diff": "$DIFF",
  "build_log": "$BUILDLOG",
  "vite_log": "$VITELOG",
  "http_gate": "$HTTP",
  "api_contracts": "$API",
  "vite_pid": "$VITE_PID",
  "static_failures": $STATIC_FAILS,
  "build_result": "$BUILD_RESULT",
  "api_blockers": $API_BLOCKERS,
  "proxy_blockers": $PROXY_BLOCKERS,
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_fix_vite_proxy_contract_v2_correct_root"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_FIX_VITE_PROXY_CONTRACT_V2_CORRECT_ROOT COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
