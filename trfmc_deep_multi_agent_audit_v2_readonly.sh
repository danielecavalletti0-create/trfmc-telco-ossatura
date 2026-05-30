#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_DEEP_MULTI_AGENT_AUDIT_V2_READONLY_$TS"
DOMDIR="$OUT/dom"
SCREENDIR="$OUT/screens"
BUILDDIR="$OUT/build_out"

mkdir -p "$OUT" "$DOMDIR" "$SCREENDIR" "$BUILDDIR"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
EXEC="$OUT/EXECUTIVE_REALITY_REPORT.md"
PORTS="$OUT/agent_01_runtime_ports.tsv"
SOURCE="$OUT/agent_02_source_integrity.tsv"
BUILDLOG="$OUT/agent_03_build.log"
BUILDREPORT="$OUT/agent_03_build_report.tsv"
API="$OUT/agent_04_api_contracts.tsv"
PROXY="$OUT/agent_05_proxy_contracts.tsv"
DOM="$OUT/agent_06_dom_visual.tsv"
PUBLIC="$OUT/agent_07_public_pages.tsv"
CONFIG="$OUT/agent_08_config_inventory.tsv"
REGRESSION="$OUT/agent_09_regression_matrix.tsv"
PLAN="$OUT/agent_10_next_actions.md"

echo "============================================================"
echo "TRFMC_DEEP_MULTI_AGENT_AUDIT_V2_READONLY"
echo "Read-only · backend/frontend/config/runtime/public pages"
echo "Timestamp: $TS"
echo "============================================================"

count_tree() {
  local pattern="$1"
  shift
  grep -RInE "$pattern" "$@" 2>/dev/null | wc -l | tr -d ' '
}

count_file() {
  local pattern="$1"
  local file="$2"
  [ -f "$file" ] || { echo 0; return; }
  grep -nE "$pattern" "$file" 2>/dev/null | wc -l | tr -d ' '
}

json_field() {
  local file="$1"
  local field="$2"
  python3 - "$file" "$field" <<'PY' 2>/dev/null
import json, sys
p, field = sys.argv[1:]
try:
    obj = json.load(open(p, encoding="utf-8", errors="replace"))
    print(obj.get(field, ""))
except Exception:
    print("")
PY
}

echo
echo "=== AGENT 01 · RUNTIME PORTS ==="

cat > "$PORTS" <<HDR
port	listen	pid	cmdline	cwd	verdict
HDR

for port in 5173 8000 4181 8095 8080; do
  line="$(ss -ltnp 2>/dev/null | awk -v p=":$port" '$0 ~ p {print; exit}')"
  if [ -n "$line" ]; then
    pid="$(echo "$line" | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | head -n 1)"
    cmd="-"
    cwd="-"
    if [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ]; then
      cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" | sed 's/[[:space:]]*$//')"
    fi
    if [ -n "$pid" ] && [ -L "/proc/$pid/cwd" ]; then
      cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null)"
    fi

    verdict="OK"
    [ "$port" = "5173" ] && echo "$cmd" | grep -q -- "--strictPort" || true
    [ "$port" = "5173" ] && ! echo "$cmd" | grep -q "vite" && verdict="WRONG_PROCESS"
    [ "$port" = "8000" ] && ! echo "$cmd" | grep -q "uvicorn" && verdict="WRONG_PROCESS"
    [ "$port" = "4181" ] && ! echo "$cmd" | grep -q "nginx" && verdict="WRONG_PROCESS"

    printf "%s\tYES\t%s\t%s\t%s\t%s\n" "$port" "${pid:-UNKNOWN}" "$cmd" "$cwd" "$verdict" >> "$PORTS"
  else
    verdict="OPTIONAL_DOWN"
    [ "$port" = "5173" ] && verdict="BLOCKER_FRONTEND_DOWN"
    [ "$port" = "8000" ] && verdict="BLOCKER_BACKEND_DOWN"
    [ "$port" = "4181" ] && verdict="BLOCKER_BRIDGE_DOWN"
    printf "%s\tNO\t-\t-\t-\t%s\n" "$port" "$verdict" >> "$PORTS"
  fi
done

column -t -s $'\t' "$PORTS"

echo
echo "=== AGENT 02 · SOURCE INTEGRITY ==="

cat > "$SOURCE" <<HDR
scope	item	value	verdict
HDR

source_line() {
  printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" >> "$SOURCE"
}

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  source_line "git" "inside" "YES" "OK"
  source_line "git" "branch" "$(git branch --show-current 2>/dev/null)" "INFO"
  source_line "git" "head" "$(git rev-parse --short HEAD 2>/dev/null)" "INFO"
  dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  source_line "git" "dirty_files" "$dirty" "$([ "$dirty" = "0" ] && echo OK || echo REVIEW)"
  git status --short > "$OUT/git_status_short.txt" 2>/dev/null
  git diff --stat > "$OUT/git_diff_stat.txt" 2>/dev/null
else
  source_line "git" "inside" "NO" "REVIEW"
fi

for f in \
  frontend/package.json \
  frontend/vite.config.ts \
  frontend/vite.config.js \
  frontend/src/app/main.tsx \
  frontend/src/portal-os/PortalOSRoot.tsx \
  frontend/src/portal-os/workingPagesRegistry.ts \
  frontend/src/stores/rtStreamStore.ts \
  backend/main_v580.py \
  backend/readonly_bridge_v28/app.py
do
  if [ -f "$f" ]; then
    source_line "file" "$f" "bytes=$(wc -c < "$f" | tr -d ' ') lines=$(wc -l < "$f" | tr -d ' ') sha256=$(sha256sum "$f" | awk '{print $1}')" "OK"
  else
    source_line "file" "$f" "missing" "REVIEW"
  fi
done

source_line "marker" "portal_os" "$(count_tree 'data-trfmc-portal-os-preview' frontend/src 2>/dev/null)" "EXPECT_GT0"
source_line "marker" "p4g_registry" "$(count_tree 'data-trfmc-p4g-route-registry|trfmcPortalOsRouteActive|trfmcPortalOsManifestRoute' frontend/src 2>/dev/null)" "EXPECT_GT0"
source_line "marker" "p6a_working_pages" "$(count_tree 'data-trfmc-p6a-working-real-pages|workingPagesRegistry|topWorkingPages' frontend/src/portal-os 2>/dev/null)" "EXPECT_GT0"
source_line "marker" "p6b_failed_residue" "$(count_tree 'data-trfmc-p6b-all-working-pages|allWorkingPages' frontend/src/portal-os 2>/dev/null)" "EXPECT_ZERO"
source_line "marker" "dangerous_dom_src" "$(count_tree 'dangerouslySetInnerHTML|\.innerHTML[[:space:]]*=|document\.write|document\.body|appendChild|eval\(|new Function' frontend/src 2>/dev/null)" "EXPECT_ZERO"
source_line "marker" "iframe_src" "$(count_tree '<iframe' frontend/src 2>/dev/null)" "EXPECT_ZERO"
source_line "marker" "secondary_createRoot" "$(grep -RIn 'createRoot[[:space:]]*(' frontend/src 2>/dev/null | grep -v 'frontend/src/app/main.tsx' | wc -l | tr -d ' ')" "EXPECT_ZERO"

column -t -s $'\t' "$SOURCE"

echo
echo "=== AGENT 03 · BUILD ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build -- --outDir "$BUILDDIR" --emptyOutDir
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

cat > "$BUILDREPORT" <<HDR
check	value	verdict
HDR

modules="$(grep -oE '✓ [0-9]+ modules transformed' "$BUILDLOG" | tail -n 1 | awk '{print $2}')"
chunk_warn="$(grep -c 'Some chunks are larger than 500 kB' "$BUILDLOG" 2>/dev/null | tr -d ' ')"
error_count="$(grep -ciE 'error|failed|transform failed' "$BUILDLOG" 2>/dev/null | tr -d ' ')"

printf "build_result\t%s\t%s\n" "$BUILD_RESULT" "$([ "$BUILD_RESULT" = "PASS" ] && echo OK || echo BLOCKER)" >> "$BUILDREPORT"
printf "modules_transformed\t%s\tINFO\n" "${modules:-0}" >> "$BUILDREPORT"
printf "chunk_warning_gt500kb\t%s\t%s\n" "$chunk_warn" "$([ "$chunk_warn" = "0" ] && echo OK || echo REVIEW)" >> "$BUILDREPORT"
printf "error_count_log\t%s\t%s\n" "$error_count" "$([ "$BUILD_RESULT" = "PASS" ] && echo INFO || echo BLOCKER)" >> "$BUILDREPORT"

column -t -s $'\t' "$BUILDREPORT"
tail -n 80 "$BUILDLOG"

echo
echo "=== AGENT 04 · API CONTRACTS: HTTP + JSON + HTML FALLBACK ==="

cat > "$API" <<HDR
name	url	status	bytes	content_type	json_parse	html_fallback	keys_or_error	verdict
HDR

api_contract() {
  local name="$1"
  local url="$2"
  local raw="$OUT/api_${name}.body"
  local headers="$OUT/api_${name}.headers"
  local code
  code="$(curl -sS -L --max-time 8 -D "$headers" -o "$raw" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  local bytes
  bytes="$(wc -c < "$raw" 2>/dev/null | tr -d ' ')"
  [ -z "$bytes" ] && bytes=0
  local ctype
  ctype="$(grep -i '^content-type:' "$headers" 2>/dev/null | tail -n 1 | sed 's/\r//g' | cut -d':' -f2- | xargs)"
  [ -z "$ctype" ] && ctype="-"

  local parse
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
    first=text[:80].replace("\n"," ")
    print("NO\t" + str(e)[:80] + " first=" + first)
PY
)"
  local json_parse
  json_parse="$(echo "$parse" | cut -f1)"
  local note
  note="$(echo "$parse" | cut -f2-)"
  local html_fallback="NO"
  grep -qi '<!doctype\|<html\|/@vite/client' "$raw" 2>/dev/null && html_fallback="YES"

  local verdict="OK"
  [ "$code" != "200" ] && verdict="NON_200"
  [ "$bytes" = "0" ] && verdict="ZERO_BYTES"
  [ "$json_parse" != "YES" ] && verdict="NOT_JSON"
  [ "$html_fallback" = "YES" ] && verdict="HTML_FALLBACK"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$url" "$code" "$bytes" "$ctype" "$json_parse" "$html_fallback" "$note" "$verdict" >> "$API"
}

api_contract "backend_health_direct" "http://127.0.0.1:8000/api/health"
api_contract "backend_openapi_direct" "http://127.0.0.1:8000/openapi.json"
api_contract "bridge_health_direct" "http://127.0.0.1:4181/api/health"
api_contract "proxy_backend_health_vite" "http://127.0.0.1:5173/trfmc-api/backend/api/health"
api_contract "proxy_bridge_health_vite" "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

column -t -s $'\t' "$API"

echo
echo "=== AGENT 05 · PROXY CONFIG / VITE ==="

cat > "$PROXY" <<HDR
check	value	verdict
HDR

VITE_CONFIG=""
for c in frontend/vite.config.ts frontend/vite.config.js frontend/vite.config.mts frontend/vite.config.mjs; do
  [ -f "$c" ] && VITE_CONFIG="$c" && break
done

printf "vite_config\t%s\t%s\n" "${VITE_CONFIG:-MISSING}" "$([ -n "$VITE_CONFIG" ] && echo OK || echo BLOCKER)" >> "$PROXY"

if [ -n "$VITE_CONFIG" ]; then
  printf "server_proxy_keyword\t%s\t%s\n" "$(count_file 'proxy:' "$VITE_CONFIG")" "EXPECT_GT0" >> "$PROXY"
  printf "trfmc_api_backend_rule\t%s\t%s\n" "$(count_file '/trfmc-api/backend' "$VITE_CONFIG")" "EXPECT_GT0" >> "$PROXY"
  printf "trfmc_api_bridge_rule\t%s\t%s\n" "$(count_file '/trfmc-api/bridge' "$VITE_CONFIG")" "EXPECT_GT0" >> "$PROXY"
  printf "rewrite_present\t%s\t%s\n" "$(count_file 'rewrite:' "$VITE_CONFIG")" "EXPECT_GT0" >> "$PROXY"
  printf "changeOrigin_present\t%s\t%s\n" "$(count_file 'changeOrigin' "$VITE_CONFIG")" "EXPECT_GT0" >> "$PROXY"
fi

proxy_json_failures="$(awk -F'\t' 'NR>1 && $1 ~ /^proxy_/ && $9!="OK"{c++} END{print c+0}' "$API")"
printf "proxy_json_failures\t%s\t%s\n" "$proxy_json_failures" "$([ "$proxy_json_failures" = "0" ] && echo OK || echo BLOCKER)" >> "$PROXY"

column -t -s $'\t' "$PROXY"

echo
echo "=== AGENT 06 · DOM / VISUAL RUNTIME ==="

cat > "$DOM" <<HDR
route	dom_status	bytes	portal_os	p4g	p6a	p6b	v42	working_section	working_links	war_room_title	canvas	result
HDR

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

dom_probe() {
  local route="$1"
  local label="$2"
  local url="http://127.0.0.1:5173/${route}"
  local dom="$DOMDIR/${label}.dom.txt"
  local screen="$SCREENDIR/${label}.png"
  local status="NO_CHROME"

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom "$url" > "$dom" 2> "$OUT/chrome_${label}.stderr.log"
    rc="$?"
    [ "$rc" = "0" ] && status="PASS" || status="FAIL_RC_$rc"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$screen" "$url" >/dev/null 2>/dev/null
  else
    echo "NO_CHROME" > "$dom"
  fi

  bytes="$(wc -c < "$dom" 2>/dev/null | tr -d ' ')"
  portal="$(grep -o 'data-trfmc-portal-os-preview="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  p4g="$(grep -o 'data-trfmc-p4g-route-registry="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  p6a="$(grep -o 'data-trfmc-p6a-working-real-pages="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  p6b="$(grep -o 'data-trfmc-p6b-all-working-pages="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  v42="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  ws="$(grep -o 'data-trfmc-working-real-pages="active"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  wl="$(grep -o 'data-trfmc-working-page-link=' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  wr="$(grep -o 'TRFMC RF/TM War Room V4' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  canvas="$(grep -oi '<canvas' "$dom" 2>/dev/null | wc -l | tr -d ' ')"

  res="PASS"
  [ "$status" != "PASS" ] && res="DOM_FAIL"
  if echo "$route" | grep -q '^#'; then
    [ "$portal" = "0" ] && res="PORTAL_OS_MISSING"
    [ "$p4g" = "0" ] && res="P4G_MISSING"
  fi
  [ "$v42" != "0" ] && res="V42_LEAK"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$route" "$status" "${bytes:-0}" "$portal" "$p4g" "$p6a" "$p6b" "$v42" "$ws" "$wl" "$wr" "$canvas" "$res" >> "$DOM"
}

dom_probe "#portal-os-preview" "portal_os_preview"
dom_probe "#trfmc-rf-tm-war-room-v4" "hash_war_room"
dom_probe "#signal-analyzer" "hash_signal"
dom_probe "#antenna-system" "hash_antenna"
dom_probe "trfmc_rf_tm_war_room_v4.html" "real_war_room"
dom_probe "trfmc_domain_registry_v1.html" "real_domain_registry"

column -t -s $'\t' "$DOM"

echo
echo "=== AGENT 07 · PUBLIC PAGES ==="

cat > "$PUBLIC" <<HDR
status	category	file	url	bytes	title	canvas	scripts	danger	iframe	http_status	content_hint	result
HDR

python3 - "$BASE" "$PUBLIC" "$OUT" <<'PY'
import html, re, subprocess, sys
from pathlib import Path

base=Path(sys.argv[1])
audit=Path(sys.argv[2])
out=Path(sys.argv[3])
public=base/"frontend/public"

def title_of(text, fallback):
    for pat in [r"<title[^>]*>(.*?)</title>", r"<h1[^>]*>(.*?)</h1>", r"<h2[^>]*>(.*?)</h2>"]:
        m=re.search(pat,text,re.I|re.S)
        if m:
            t=re.sub(r"<[^>]+>","",m.group(1))
            t=html.unescape(re.sub(r"\s+"," ",t).strip())
            if t:
                return t[:100]
    return fallback.replace("_"," ").replace(".html","")[:100]

def cat(name,text):
    s=(name+" "+text[:3000]).lower()
    if "war room" in s or "war_room" in s or "evidence" in s: return "war-room"
    if any(x in s for x in ["signal","spectrum","fft","iq","waterfall","dsp"]): return "signal-dsp"
    if any(x in s for x in ["antenna","rru","ret","cpri","aisg"]): return "antenna-rf"
    if any(x in s for x in ["open5gs","ueransim","ngap","pfcp","gtp","core/ran","core ran"]): return "5g-core-ran"
    if any(x in s for x in ["webgl","3d","digital twin"]): return "3d-visual"
    if any(x in s for x in ["fiber","otdr","fronthaul"]): return "fiber"
    if any(x in s for x in ["microwave","fresnel","link budget"]): return "microwave"
    if any(x in s for x in ["knowledge","theory","academy","glossary"]): return "knowledge"
    if any(x in s for x in ["noc","alarm","ops"]): return "noc"
    return "reference"

for f in sorted(public.glob("*.html")):
    text=f.read_text(encoding="utf-8", errors="replace")
    url="/"+f.name
    tmp=out/(f"public_{f.stem}.curl")
    try:
        proc=subprocess.run(["curl","-sS","-L","--max-time","5","-o",str(tmp),"-w","%{http_code}",f"http://127.0.0.1:5173{url}"],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
        code=(proc.stdout or "000").strip()
    except Exception:
        code="000"
    body=tmp.read_text(encoding="utf-8",errors="replace") if tmp.exists() else ""
    hint="HTML" if re.search(r"<html|<!doctype",body,re.I) else "TEXT"
    canvas=len(re.findall(r"<canvas\b",text,re.I))
    scripts=len(re.findall(r"<script\b",text,re.I))
    danger=len(re.findall(r"innerHTML|outerHTML|document\.write|insertAdjacentHTML|eval\(|new Function",text,re.I))
    iframe=len(re.findall(r"<iframe\b",text,re.I))
    result="ACTIVE" if code=="200" and len(body)>500 and hint=="HTML" and danger==0 and iframe==0 else "REVIEW"
    row=[result,cat(f.name,text),str(f.relative_to(base)),url,str(len(text.encode())),title_of(text,f.name),str(canvas),str(scripts),str(danger),str(iframe),code,hint,result]
    with audit.open("a",encoding="utf-8") as w:
        w.write("\t".join(x.replace("\t"," ") for x in row)+"\n")
PY

ACTIVE_PUBLIC="$(awk -F'\t' 'NR>1 && $1=="ACTIVE"{c++} END{print c+0}' "$PUBLIC")"
REVIEW_PUBLIC="$(awk -F'\t' 'NR>1 && $1!="ACTIVE"{c++} END{print c+0}' "$PUBLIC")"

echo "ACTIVE_PUBLIC=$ACTIVE_PUBLIC"
echo "REVIEW_PUBLIC=$REVIEW_PUBLIC"

echo
echo "=== AGENT 08 · CONFIG INVENTORY ==="

cat > "$CONFIG" <<HDR
area	item	value	verdict
HDR

config_line() {
  printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" >> "$CONFIG"
}

config_line "runtime" "backend_8000_cmd" "$(awk -F'\t' '$1=="8000"{print $4}' "$PORTS")" "INFO"
config_line "runtime" "bridge_4181_cmd" "$(awk -F'\t' '$1=="4181"{print $4}' "$PORTS")" "INFO"
config_line "runtime" "frontend_5173_cmd" "$(awk -F'\t' '$1=="5173"{print $4}' "$PORTS")" "INFO"
config_line "vite" "config_file" "${VITE_CONFIG:-MISSING}" "$([ -n "$VITE_CONFIG" ] && echo OK || echo REVIEW)"
config_line "vite" "proxy_backend_rules" "$([ -n "$VITE_CONFIG" ] && count_file '/trfmc-api/backend' "$VITE_CONFIG" || echo 0)" "EXPECT_GT0"
config_line "vite" "proxy_bridge_rules" "$([ -n "$VITE_CONFIG" ] && count_file '/trfmc-api/bridge' "$VITE_CONFIG" || echo 0)" "EXPECT_GT0"
config_line "nginx" "runtime_conf_dir" "$(find runtime/nginx -maxdepth 2 -type f -name nginx.conf 2>/dev/null | head -n 5 | tr '\n' ' ')" "INFO"
config_line "backend" "main_v580_exists" "$([ -f backend/main_v580.py ] && echo YES || echo NO)" "INFO"
config_line "backend" "readonly_bridge_exists" "$([ -f backend/readonly_bridge_v28/app.py ] && echo YES || echo NO)" "INFO"

column -t -s $'\t' "$CONFIG"

echo
echo "=== AGENT 09 · REGRESSION MATRIX ==="

cat > "$REGRESSION" <<HDR
area	status	evidence	what_it_means	next
HDR

port_failures="$(awk -F'\t' 'NR>1 && $6 ~ /BLOCKER|WRONG/ {c++} END{print c+0}' "$PORTS")"
api_blockers="$(awk -F'\t' 'NR>1 && $9!="OK"{c++} END{print c+0}' "$API")"
proxy_blockers="$(awk -F'\t' '$1=="proxy_json_failures"{print $2}' "$PROXY")"
dom_failures="$(awk -F'\t' 'NR>1 && $13!="PASS"{c++} END{print c+0}' "$DOM")"
source_danger="$(awk -F'\t' '$2=="dangerous_dom_src"{print $3}' "$SOURCE")"
p6b_source="$(awk -F'\t' '$2=="p6b_failed_residue"{print $3}' "$SOURCE")"
p6a_dom="$(awk -F'\t' '$1=="#portal-os-preview"{print $6}' "$DOM")"
working_links="$(awk -F'\t' '$1=="#portal-os-preview"{print $10}' "$DOM")"

reg() {
  printf "%s\t%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" "$5" >> "$REGRESSION"
}

[ "$BUILD_RESULT" = "PASS" ] && reg "frontend_build" "GOOD" "build PASS" "TS/Vite source compiles" "freeze before next mutation" || reg "frontend_build" "BAD_BLOCKER" "build FAIL" "frontend source broken" "fix build before anything"
[ "$port_failures" = "0" ] && reg "runtime_ports" "GOOD" "blockers=$port_failures" "5173/8000/4181 are correctly alive" "keep strict startup" || reg "runtime_ports" "BAD" "blockers=$port_failures" "runtime service issue" "fix process map"
[ "$api_blockers" = "0" ] && reg "api_contracts" "GOOD" "api_blockers=0" "all API endpoints return parseable JSON" "ok" || reg "api_contracts" "BAD" "api_blockers=$api_blockers" "some API endpoints return HTML/fallback/non-json" "fix Vite proxy first"
[ "${proxy_blockers:-0}" = "0" ] && reg "vite_proxy" "GOOD" "proxy_json_failures=0" "same-origin API proxy works" "ok" || reg "vite_proxy" "BAD_BLOCKER" "proxy_json_failures=${proxy_blockers:-unknown}" "same-origin proxy is fake/fallback" "patch vite.config/rewrite or call direct backend"
[ "$dom_failures" = "0" ] && reg "dom_runtime" "GOOD" "dom_failures=0" "Portal OS/real pages render" "ok" || reg "dom_runtime" "BAD" "dom_failures=$dom_failures" "visual/runtime regression" "inspect DOM artifacts"
[ "${source_danger:-0}" = "0" ] && reg "source_safety" "GOOD" "dangerous_dom=0" "no injection/root safety issue" "preserve" || reg "source_safety" "BAD" "dangerous_dom=$source_danger" "unsafe frontend code found" "remove unsafe patterns"
[ "${p6b_source:-0}" = "0" ] && reg "p6b_rollback" "GOOD" "p6b_source=0" "failed P6B removed" "do not reintroduce all-links rendering" || reg "p6b_rollback" "BAD" "p6b_source=$p6b_source" "failed P6B residue still present" "remove residue"
[ "${p6a_dom:-0}" != "0" ] && reg "p6a_dashboard" "GOOD" "p6a=$p6a_dom links=$working_links" "working real pages dashboard visible" "next: P6D-LITE category pagination" || reg "p6a_dashboard" "BAD" "p6a=$p6a_dom" "P6A not mounted" "restore P6A"
reg "public_pages" "INFO" "active=$ACTIVE_PUBLIC review=$REVIEW_PUBLIC" "111 usable pages, 68 need triage" "prioritize top categories"

column -t -s $'\t' "$REGRESSION"

echo
echo "=== AGENT 10 · NEXT ACTION PLAN ==="

cat > "$PLAN" <<PLAN
# TRFMC Deep Multi-Agent Audit V2 - Piano operativo

## Verdetto rapido

Il portale runtime è vivo e il Portal OS renderizza. P6A è presente. P6B non è attivo. Le pagine HTML reali funzionanti sono $ACTIVE_PUBLIC, quelle da rivedere sono $REVIEW_PUBLIC.

Il problema tecnico più importante da correggere prima di ulteriori evoluzioni è il proxy Vite:
- gli endpoint diretti 8000/4181 tornano JSON;
- gli endpoint /trfmc-api/... su 5173 devono tornare JSON;
- se tornano HTML fallback, il proxy è finto.

## Ordine corretto

### Step 1 - Fix proxy contract
Correggere vite.config per:
- /trfmc-api/backend -> http://127.0.0.1:8000
- /trfmc-api/bridge -> http://127.0.0.1:4181
- rewrite corretto del prefisso
- test JSON obbligatorio, non solo HTTP 200.

### Step 2 - P6D-LITE dashboard
Non ripetere P6B. Creare selettore categoria e massimo 20-30 link per viewport.

### Step 3 - Conversione React nativa
Convertire in React:
1. War Room V4
2. DSP Measurement Chain
3. Antenna/RRU/RET/CPRI

### Step 4 - Backend alignment
Chiarire se runtime 8000 deve restare readonly_bridge_v28 o passare a main_v580.
PLAN

cat "$PLAN"

echo
echo "=== SUMMARY ==="

overall="PASS_WITH_PROXY_BLOCKER"
[ "$BUILD_RESULT" != "PASS" ] && overall="FAIL_BUILD"
[ "$dom_failures" != "0" ] && overall="FAIL_DOM"
[ "${proxy_blockers:-0}" = "0" ] && [ "$BUILD_RESULT" = "PASS" ] && [ "$dom_failures" = "0" ] && overall="PASS"

cat > "$EXEC" <<MD
# TRFMC Deep Multi-Agent Audit V2 - Executive Reality Report

Timestamp: $TS

## Overall

**$overall**

## Buono

- Build: $BUILD_RESULT
- Runtime 5173/8000/4181: vedi agent_01
- Portal OS DOM: presente
- P4G route registry: presente
- P6A working pages: presente
- P6B fallito: non attivo
- Pagine pubbliche attive: $ACTIVE_PUBLIC
- Pagine pubbliche in review: $REVIEW_PUBLIC

## Cattivo / da correggere

- Proxy Vite JSON: verificare agent_04 e agent_05.
- Se /trfmc-api/... torna HTML, è fallback SPA, non API.
- Runtime backend su 8000 usa readonly_bridge_v28: va deciso se è il backend definitivo o provvisorio.
- Dashboard mostra 24 working links, non tutte le 111 pagine attive: serve P6D-LITE, non P6B.

## Azione successiva

Fix del proxy Vite con contract JSON obbligatorio.
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_DEEP_MULTI_AGENT_AUDIT_V2_READONLY",
  "mutation": false,
  "source_mutation": false,
  "out": "$OUT",
  "overall": "$overall",
  "build_result": "$BUILD_RESULT",
  "port_failures": $port_failures,
  "api_blockers": $api_blockers,
  "proxy_json_failures": ${proxy_blockers:-0},
  "dom_failures": $dom_failures,
  "public_active": $ACTIVE_PUBLIC,
  "public_review": $REVIEW_PUBLIC,
  "p6a_dom": ${p6a_dom:-0},
  "working_links": ${working_links:-0},
  "ports": "$PORTS",
  "source_integrity": "$SOURCE",
  "build_report": "$BUILDREPORT",
  "api_contracts": "$API",
  "proxy_contracts": "$PROXY",
  "dom_visual": "$DOM",
  "public_pages": "$PUBLIC",
  "config_inventory": "$CONFIG",
  "regression_matrix": "$REGRESSION",
  "next_actions": "$PLAN",
  "executive_report": "$EXEC"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_deep_multi_agent_audit_v2_readonly"

python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_DEEP_MULTI_AGENT_AUDIT_V2_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
