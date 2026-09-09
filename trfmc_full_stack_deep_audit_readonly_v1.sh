#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_FULL_STACK_DEEP_AUDIT_READONLY_V1_$TS"
DOMDIR="$OUT/dom"
SCREENDIR="$OUT/screens"
BUILDDIR="$OUT/frontend_build_out"

mkdir -p "$OUT" "$DOMDIR" "$SCREENDIR" "$BUILDDIR"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
EXEC="$OUT/executive_findings.md"
PORTS="$OUT/ports_processes.tsv"
RUNTIME="$OUT/runtime_identity.tsv"
SRC="$OUT/source_state.tsv"
MARKERS="$OUT/source_markers.tsv"
STATIC="$OUT/static_safety.tsv"
BUILDLOG="$OUT/frontend_build_audit.log"
HTTP="$OUT/http_gate.tsv"
API="$OUT/api_gate.tsv"
DOMGATE="$OUT/dom_gate.tsv"
PUBLIC_AUDIT="$OUT/public_pages_audit.tsv"
P6A_COMPARE="$OUT/p6a_compare.tsv"
REGRESSION="$OUT/regression_matrix.tsv"
NEXTPLAN="$OUT/next_actions_plan.md"

echo "============================================================"
echo "TRFMC_FULL_STACK_DEEP_AUDIT_READONLY_V1"
echo "Audit completo backend/frontend/runtime/public pages"
echo "Timestamp: $TS"
echo "============================================================"

count_file_pattern() {
  local pattern="$1"
  local file="$2"
  if [ ! -f "$file" ]; then echo 0; return; fi
  grep -nE "$pattern" "$file" 2>/dev/null | wc -l | tr -d ' '
}

count_tree_pattern() {
  local pattern="$1"
  shift
  grep -RInE "$pattern" "$@" 2>/dev/null | wc -l | tr -d ' '
}

json_get() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY' 2>/dev/null
import json, sys
p,k=sys.argv[1:]
try:
    obj=json.load(open(p))
    print(obj.get(k, ""))
except Exception:
    print("")
PY
}

echo
echo "=== 1) RUNTIME / PORTS / PROCESSI ==="

cat > "$PORTS" <<HDR
port	listen	pid	cmdline	cwd
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
    printf "%s\tYES\t%s\t%s\t%s\n" "$port" "${pid:-UNKNOWN}" "$cmd" "$cwd" >> "$PORTS"
  else
    printf "%s\tNO\t-\t-\t-\n" "$port" >> "$PORTS"
  fi
done

column -t -s $'\t' "$PORTS"

echo
echo "=== 2) SOURCE STATE / GIT / BASELINE ==="

cat > "$SRC" <<HDR
check	value
HDR

printf "base\t%s\n" "$BASE" >> "$SRC"
printf "timestamp\t%s\n" "$TS" >> "$SRC"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf "git_inside\tYES\n" >> "$SRC"
  printf "git_branch\t%s\n" "$(git branch --show-current 2>/dev/null)" >> "$SRC"
  printf "git_head\t%s\n" "$(git rev-parse --short HEAD 2>/dev/null)" >> "$SRC"
  printf "git_dirty_files\t%s\n" "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')" >> "$SRC"
  git status --short > "$OUT/git_status_short.txt" 2>/dev/null
  git diff --stat > "$OUT/git_diff_stat.txt" 2>/dev/null
else
  printf "git_inside\tNO\n" >> "$SRC"
fi

printf "node_version\t%s\n" "$(node -v 2>/dev/null || echo MISSING)" >> "$SRC"
printf "npm_version\t%s\n" "$(npm -v 2>/dev/null || echo MISSING)" >> "$SRC"
printf "python_version\t%s\n" "$(python3 --version 2>/dev/null || echo MISSING)" >> "$SRC"

for f in \
  frontend/src/app/main.tsx \
  frontend/src/portal-os/PortalOSRoot.tsx \
  frontend/src/portal-os/workingPagesRegistry.ts \
  frontend/src/stores/rtStreamStore.ts \
  backend/main_v580.py \
  backend/readonly_bridge_v28/app.py
do
  if [ -f "$f" ]; then
    printf "file:%s\tYES bytes=%s lines=%s sha256=%s\n" "$f" "$(wc -c < "$f" | tr -d ' ')" "$(wc -l < "$f" | tr -d ' ')" "$(sha256sum "$f" | awk '{print $1}')" >> "$SRC"
  else
    printf "file:%s\tNO\n" "$f" >> "$SRC"
  fi
done

column -t -s $'\t' "$SRC"

echo
echo "=== 3) SOURCE MARKERS / ARCHITETTURA ==="

cat > "$MARKERS" <<HDR
area	marker	count	expected	note
HDR

m() {
  local area="$1"
  local marker="$2"
  local count="$3"
  local expected="$4"
  local note="$5"
  printf "%s\t%s\t%s\t%s\t%s\n" "$area" "$marker" "$count" "$expected" "$note" >> "$MARKERS"
}

m "portal-os" "data-trfmc-portal-os-preview" "$(count_tree_pattern 'data-trfmc-portal-os-preview' frontend/src/portal-os frontend/src/app 2>/dev/null)" ">0" "Portal OS root marker"
m "portal-os" "data-trfmc-p4g-route-registry" "$(count_tree_pattern 'data-trfmc-p4g-route-registry|trfmcPortalOsRouteActive|trfmcPortalOsManifestRoute' frontend/src/portal-os frontend/src/app 2>/dev/null)" ">0" "Manifest route gate"
m "portal-os" "data-trfmc-p6a-working-real-pages" "$(count_tree_pattern 'data-trfmc-p6a-working-real-pages|workingPagesRegistry|topWorkingPages' frontend/src/portal-os 2>/dev/null)" ">0" "Working pages P6A"
m "portal-os" "data-trfmc-p6b-all-working-pages" "$(count_tree_pattern 'data-trfmc-p6b-all-working-pages|allWorkingPages' frontend/src/portal-os 2>/dev/null)" "0" "P6B should be absent after rollback"
m "store" "rtStreamStore_nextId_syntax" "$(count_file_pattern '_nextId: 0' frontend/src/stores/rtStreamStore.ts)" ">0" "rtStreamStore exists and parsed by build"
m "domain" "rf_physics" "$(count_tree_pattern 'data-trfmc-p1-rf-physics-domain|RFPhysicsDomainP1' frontend/src 2>/dev/null)" ">0" "RF Physics promoted"
m "domain" "signal_analyzer" "$(count_tree_pattern 'data-trfmc-p2b-signal-analyzer|SignalAnalyzerDomain|signal-analyzer' frontend/src 2>/dev/null)" ">0" "Signal analyzer domain"
m "domain" "antenna" "$(count_tree_pattern 'data-trfmc-p3-antenna-system-domain|AntennaSystemDomain|antenna-system' frontend/src 2>/dev/null)" "review" "Antenna promotion status"
m "legacy" "public_html_count" "$(find frontend/public -maxdepth 1 -type f -name '*.html' 2>/dev/null | wc -l | tr -d ' ')" ">0" "Real HTML pages available"

column -t -s $'\t' "$MARKERS"

echo
echo "=== 4) STATIC SAFETY GATE ==="

cat > "$STATIC" <<HDR
check	result	count	scope
HDR

safety_line() {
  local check="$1"
  local count="$2"
  local pass_cond="$3"
  local scope="$4"
  local result="FAIL"
  case "$pass_cond" in
    zero) [ "$count" = "0" ] && result="PASS" ;;
    gt0) [ "$count" -gt 0 ] && result="PASS" ;;
    any) result="INFO" ;;
  esac
  printf "%s\t%s\t%s\t%s\n" "$check" "$result" "$count" "$scope" >> "$STATIC"
}

safety_line "dangerous_dom_frontend_src" "$(count_tree_pattern 'dangerouslySetInnerHTML|\.innerHTML[[:space:]]*=|document\.write|document\.body|appendChild|eval\(|new Function' frontend/src 2>/dev/null)" "zero" "frontend/src"
safety_line "iframe_frontend_src" "$(count_tree_pattern '<iframe' frontend/src 2>/dev/null)" "zero" "frontend/src"
safety_line "secondary_createRoot_outside_main" "$(grep -RIn 'createRoot[[:space:]]*(' frontend/src 2>/dev/null | grep -v 'frontend/src/app/main.tsx' | wc -l | tr -d ' ')" "zero" "frontend/src"
safety_line "absolute_public_html_links_in_src" "$(count_tree_pattern 'href=["'\'']/[^"'\'']+\.html|\.html["'\'']' frontend/src 2>/dev/null)" "any" "frontend/src"
safety_line "direct_4181_fetch_in_src" "$(count_tree_pattern '127\.0\.0\.1:4181|localhost:4181' frontend/src 2>/dev/null)" "any" "frontend/src"
safety_line "p6b_residue" "$(count_tree_pattern 'P6B|data-trfmc-p6b-all-working-pages|allWorkingPages' frontend/src/portal-os 2>/dev/null)" "zero" "frontend/src/portal-os"

column -t -s $'\t' "$STATIC"

echo
echo "=== 5) FRONTEND BUILD AUDIT OUT-OF-TREE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build -- --outDir "$BUILDDIR" --emptyOutDir
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 100 "$BUILDLOG"

echo
echo "=== 6) HTTP/API GATES ==="

cat > "$HTTP" <<HDR
url	status	bytes	content_hint	classification
HDR

check_http() {
  local url="$1"
  local tmp="$OUT/tmp_http_$(echo "$url" | tr -cd 'A-Za-z0-9_' | head -c 80)"
  local code
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" || echo "000")"
  local bytes
  bytes="$(wc -c < "$tmp" 2>/dev/null | tr -d ' ')"
  local hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" 2>/dev/null && hint="HTML"
  python3 - "$tmp" <<'PY' >/tmp/trfmc_json_hint.$$ 2>/dev/null
import json,sys
try:
    json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    print("JSON")
except Exception:
    print("")
PY
  jh="$(cat /tmp/trfmc_json_hint.$$ 2>/dev/null)"
  rm -f /tmp/trfmc_json_hint.$$
  [ "$jh" = "JSON" ] && hint="JSON"
  local cls="OK"
  [ "$code" != "200" ] && cls="NON_200"
  [ "${bytes:-0}" = "0" ] && cls="ZERO_BYTES"
  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "${bytes:-0}" "$hint" "$cls" | tee -a "$HTTP"
  rm -f "$tmp"
}

check_http "http://127.0.0.1:5173/"
check_http "http://127.0.0.1:5173/#portal-os-preview"
check_http "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4"
check_http "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html"
check_http "http://127.0.0.1:5173/trfmc_domain_registry_v1.html"
check_http "http://127.0.0.1:8000/api/health"
check_http "http://127.0.0.1:8000/openapi.json"
check_http "http://127.0.0.1:4181/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/backend/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

cat > "$API" <<HDR
endpoint	status	json	parse_note
HDR

api_probe() {
  local name="$1"
  local url="$2"
  local raw="$OUT/api_${name}.json"
  local code
  code="$(curl -sS -L --max-time 8 -o "$raw" -w "%{http_code}" "$url" || echo "000")"
  python3 - "$raw" <<'PY' > "$OUT/api_parse.tmp" 2>/dev/null
import json,sys
try:
    obj=json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    if isinstance(obj, dict):
        print("YES\tkeys=" + ",".join(list(obj.keys())[:8]))
    else:
        print("YES\ttype=" + type(obj).__name__)
except Exception as e:
    print("NO\t" + str(e)[:80])
PY
  parse="$(cat "$OUT/api_parse.tmp")"
  printf "%s\t%s\t%s\n" "$name" "$code" "$parse" >> "$API"
}

api_probe "backend_health" "http://127.0.0.1:8000/api/health"
api_probe "backend_openapi" "http://127.0.0.1:8000/openapi.json"
api_probe "bridge_health" "http://127.0.0.1:4181/api/health"
api_probe "proxy_backend_health" "http://127.0.0.1:5173/trfmc-api/backend/api/health"
api_probe "proxy_bridge_health" "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

column -t -s $'\t' "$API"

echo
echo "=== 7) DOM RUNTIME GATE ==="

cat > "$DOMGATE" <<HDR
route	dom_status	bytes	portal_os	p4g	p6a	p6b	v42	war_room_title	working_section	working_links	canvas_count	result
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
  local status="SKIPPED_NO_CHROME"
  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 --dump-dom "$url" > "$dom" 2> "$OUT/chrome_${label}.stderr.log"
    rc="$?"
    [ "$rc" = "0" ] && status="PASS" || status="FAIL_RC_$rc"
    "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --window-size=1920,1080 --virtual-time-budget=9000 --screenshot="$screen" "$url" >/dev/null 2>/dev/null
  else
    echo "NO_CHROME" > "$dom"
  fi
  bytes="$(wc -c < "$dom" 2>/dev/null | tr -d ' ')"
  portal="$(grep -o 'data-trfmc-portal-os-preview="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  p4g="$(grep -o 'data-trfmc-p4g-route-registry="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  p6a="$(grep -o 'data-trfmc-p6a-working-real-pages="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  p6b="$(grep -o 'data-trfmc-p6b-all-working-pages="mounted"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  v42="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  wr="$(grep -o 'TRFMC RF/TM War Room V4' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  ws="$(grep -o 'data-trfmc-working-real-pages="active"' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  wl="$(grep -o 'data-trfmc-working-page-link=' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  canvas="$(grep -oi '<canvas' "$dom" 2>/dev/null | wc -l | tr -d ' ')"
  res="PASS"
  [ "$status" != "PASS" ] && res="FAIL_DOM"
  [ "$route" != "trfmc_rf_tm_war_room_v4.html" ] && [ "$portal" = "0" ] && res="FAIL_PORTAL_MISSING"
  [ "$v42" != "0" ] && res="FAIL_V42_LEAK"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$route" "$status" "${bytes:-0}" "$portal" "$p4g" "$p6a" "$p6b" "$v42" "$wr" "$ws" "$wl" "$canvas" "$res" >> "$DOMGATE"
}

dom_probe "#portal-os-preview" "portal_os_preview"
dom_probe "#trfmc-rf-tm-war-room-v4" "hash_war_room"
dom_probe "#signal-analyzer" "hash_signal"
dom_probe "#antenna-system" "hash_antenna"
dom_probe "trfmc_rf_tm_war_room_v4.html" "real_war_room_html"
dom_probe "trfmc_domain_registry_v1.html" "real_domain_registry_html"

column -t -s $'\t' "$DOMGATE"

echo
echo "=== 8) PUBLIC HTML PAGES AUDIT LIGHT ==="

cat > "$PUBLIC_AUDIT" <<HDR
status	category	file	url	bytes	title	canvas	scripts	danger	iframe	http_status	content_hint	result
HDR

python3 - "$BASE" "$PUBLIC_AUDIT" "$OUT" <<'PY'
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
            if t: return t[:100]
    return fallback.replace("_"," ").replace(".html","")[:100]

def cat(name,text):
    s=(name+" "+text[:3000]).lower()
    if "war room" in s or "war_room" in s or "evidence" in s: return "war-room"
    if any(x in s for x in ["signal","spectrum","fft","iq","waterfall","dsp"]): return "signal-dsp"
    if any(x in s for x in ["antenna","rru","ret","cpri","aisg"]): return "antenna"
    if any(x in s for x in ["open5gs","ueransim","ngap","pfcp","gtp","core/ran","core ran"]): return "5g-core-ran"
    if any(x in s for x in ["webgl","3d","digital twin"]): return "3d"
    if any(x in s for x in ["fiber","otdr","fronthaul"]): return "fiber"
    if any(x in s for x in ["microwave","fresnel","link budget"]): return "microwave"
    if any(x in s for x in ["knowledge","theory","academy","glossary"]): return "knowledge"
    if any(x in s for x in ["noc","alarm","ops"]): return "noc"
    return "reference"

rows=[]
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
    rows.append([result,cat(f.name,text),str(f.relative_to(base)),url,str(len(text.encode())),title_of(text,f.name),str(canvas),str(scripts),str(danger),str(iframe),code,hint,result])

with audit.open("a",encoding="utf-8") as w:
    for r in rows:
        w.write("\t".join(x.replace("\t"," ") for x in r)+"\n")
PY

ACTIVE_PUBLIC="$(awk -F'\t' 'NR>1 && $1=="ACTIVE"{c++} END{print c+0}' "$PUBLIC_AUDIT")"
REVIEW_PUBLIC="$(awk -F'\t' 'NR>1 && $1!="ACTIVE"{c++} END{print c+0}' "$PUBLIC_AUDIT")"
echo "PUBLIC_ACTIVE=$ACTIVE_PUBLIC"
echo "PUBLIC_REVIEW=$REVIEW_PUBLIC"
awk -F'\t' 'NR==1 || $1=="ACTIVE"' "$PUBLIC_AUDIT" | column -t -s $'\t' | sed -n '1,80p'

echo
echo "=== 9) P6A / BASELINE COMPARISON ==="

cat > "$P6A_COMPARE" <<HDR
source	metric	value
HDR

for latest in \
  latest_fix_rtstreamstore_syntax_error_v1 \
  latest_p6a_activate_working_real_pages_dashboard_v1 \
  latest_p6b_expose_all_working_pages_dashboard_v1 \
  latest_p4g_b_runtime_route_reprobe_after_vite_recovery \
  latest_emergency_restore_after_p6b_white_page_v1
do
  s="runtime/quality/$latest/summary.json"
  if [ -f "$s" ]; then
    printf "%s\tresult\t%s\n" "$latest" "$(json_get "$s" result)" >> "$P6A_COMPARE"
    printf "%s\tbuild_result\t%s\n" "$latest" "$(json_get "$s" build_result)" >> "$P6A_COMPARE"
    printf "%s\tportal_os_count\t%s\n" "$latest" "$(json_get "$s" portal_os_count)" >> "$P6A_COMPARE"
    printf "%s\tp6a_count\t%s\n" "$latest" "$(json_get "$s" p6a_count)" >> "$P6A_COMPARE"
    printf "%s\tp6b_count\t%s\n" "$latest" "$(json_get "$s" p6b_count)" >> "$P6A_COMPARE"
    printf "%s\tv42_count\t%s\n" "$latest" "$(json_get "$s" v42_count)" >> "$P6A_COMPARE"
    printf "%s\tactive_pages\t%s\n" "$latest" "$(json_get "$s" active_pages)" >> "$P6A_COMPARE"
    printf "%s\treview_pages\t%s\n" "$latest" "$(json_get "$s" review_pages)" >> "$P6A_COMPARE"
  else
    printf "%s\tmissing\tYES\n" "$latest" >> "$P6A_COMPARE"
  fi
done

column -t -s $'\t' "$P6A_COMPARE"

echo
echo "=== 10) REGRESSION MATRIX ==="

cat > "$REGRESSION" <<HDR
area	status	evidence	interpretation
HDR

BUILD_STATUS="$BUILD_RESULT"
HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"
API_FAILS="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$API")"
DOM_FAILS="$(awk -F'\t' 'NR>1 && $13!="PASS"{c++} END{print c+0}' "$DOMGATE")"
STATIC_FAILS="$(awk -F'\t' 'NR>1 && $2=="FAIL"{c++} END{print c+0}' "$STATIC")"
P6B_SRC="$(awk -F'\t' '$2=="data-trfmc-p6b-all-working-pages"{print $3}' "$MARKERS")"
P6A_DOM="$(awk -F'\t' '$1=="#portal-os-preview"{print $6}' "$DOMGATE")"
P6B_DOM="$(awk -F'\t' '$1=="#portal-os-preview"{print $7}' "$DOMGATE")"
WORKING_LINKS="$(awk -F'\t' '$1=="#portal-os-preview"{print $11}' "$DOMGATE")"

reg() { printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" >> "$REGRESSION"; }

[ "$BUILD_STATUS" = "PASS" ] && reg "frontend_build" "IMPROVED_OK" "build PASS out-of-tree" "rtStreamStore syntax error resolved" || reg "frontend_build" "WORSE_BLOCKER" "build FAIL" "frontend cannot be considered stable"
[ "$HTTP_FAILS" = "0" ] && reg "http_runtime" "OK" "http_failures=0" "ports/pages respond" || reg "http_runtime" "REVIEW" "http_failures=$HTTP_FAILS" "some endpoints/pages not reachable"
[ "$API_FAILS" = "0" ] && reg "backend_api" "OK" "api_failures=0" "health/openapi/proxy endpoints respond" || reg "backend_api" "REVIEW" "api_failures=$API_FAILS" "backend or proxy endpoints need review"
[ "$DOM_FAILS" = "0" ] && reg "dom_rendering" "OK" "dom_failures=0" "SPA and real pages render in Chrome" || reg "dom_rendering" "REVIEW" "dom_failures=$DOM_FAILS" "rendering mismatch, inspect DOM gate"
[ "$STATIC_FAILS" = "0" ] && reg "static_safety" "OK" "static_failures=0" "no unsafe DOM/iframe/root issues found in scanned scope" || reg "static_safety" "REVIEW" "static_failures=$STATIC_FAILS" "unsafe/static residues detected"
[ "${P6A_DOM:-0}" != "0" ] && reg "p6a_dashboard" "IMPROVED_OK" "p6a_dom=$P6A_DOM working_links=$WORKING_LINKS" "working real pages section still present" || reg "p6a_dashboard" "WORSE" "p6a_dom=$P6A_DOM" "P6A not visible"
[ "${P6B_DOM:-0}" = "0" ] && reg "p6b_rollback" "IMPROVED_OK" "p6b_dom=0" "failed P6B not active in runtime" || reg "p6b_rollback" "WORSE" "p6b_dom=$P6B_DOM" "P6B residue still active"
reg "public_pages" "INFO" "active=$ACTIVE_PUBLIC review=$REVIEW_PUBLIC" "real HTML pages inventory for next recovery/conversion"
reg "chunk_size" "REVIEW" "$(grep -c 'Some chunks are larger than 500 kB' "$BUILDLOG" 2>/dev/null | tr -d ' ')" "if >0, later code-splitting/dynamic import should be considered"

column -t -s $'\t' "$REGRESSION"

echo
echo "=== 11) NEXT ACTION PLAN ==="

cat > "$NEXTPLAN" <<PLAN
# TRFMC Full Stack Deep Audit - Next Actions

## Stato da rispettare

1. Non ripetere P6B "all links in DOM".
2. Non patchare V42, main.tsx o routing globale senza audit dedicato.
3. Non chiamare funzionante una hash-route se non monta contenuto reale verificabile.
4. Le pagine HTML reali funzionanti restano link root: /nome_file.html.
5. La dashboard React deve correlare, non inglobare tutte le pagine legacy insieme.

## Priorità immediata

### P0 - Stabilità
- Mantieni la baseline dopo fix rtStreamStore.
- Se build o DOM falliscono, stop sviluppo e correggere solo blocker.

### P1 - Audit pagine
- Usare public_pages_audit.tsv come sorgente di verità.
- Separare ACTIVE da REVIEW.
- Non attivare pagine REVIEW nella dashboard.

### P2 - Dashboard corretta
- Creare P6D-LITE: selettore categoria + 20/30 link visibili per volta.
- Non renderizzare 111 cards contemporaneamente.
- Link reali sempre target /file.html.

### P3 - Conversione React nativa
- Primo modulo: War Room V4.
- Secondo: DSP Measurement Chain.
- Terzo: Antenna/RRU/RET/CPRI.
- Ogni conversione deve avere marker, build, DOM, screenshot, no iframe, no dangerous DOM.

## Output principali di questo audit

- Executive findings: $EXEC
- Regression matrix: $REGRESSION
- Source markers: $MARKERS
- Static safety: $STATIC
- HTTP gate: $HTTP
- API gate: $API
- DOM gate: $DOMGATE
- Public pages audit: $PUBLIC_AUDIT
PLAN

cat "$NEXTPLAN"

echo
echo "=== 12) SUMMARY JSON ==="

BUILD_OK="$([ "$BUILD_RESULT" = "PASS" ] && echo true || echo false)"
HTTP_OK="$([ "$HTTP_FAILS" = "0" ] && echo true || echo false)"
API_OK="$([ "$API_FAILS" = "0" ] && echo true || echo false)"
DOM_OK="$([ "$DOM_FAILS" = "0" ] && echo true || echo false)"
STATIC_OK="$([ "$STATIC_FAILS" = "0" ] && echo true || echo false)"

OVERALL="PASS_WITH_REVIEW"
if [ "$BUILD_RESULT" != "PASS" ]; then OVERALL="FAIL_BUILD_BLOCKER"; fi
if [ "$BUILD_RESULT" = "PASS" ] && [ "$DOM_FAILS" != "0" ]; then OVERALL="REVIEW_DOM"; fi
if [ "$BUILD_RESULT" = "PASS" ] && [ "$STATIC_FAILS" != "0" ]; then OVERALL="REVIEW_STATIC"; fi

cat > "$EXEC" <<MD
# TRFMC Full Stack Deep Audit - Executive Findings

Timestamp: $TS

## Risultato complessivo

**$OVERALL**

## Migliorato

- Build frontend audit: $BUILD_RESULT
- Fix rtStreamStore: verificato tramite build.
- P6B non risulta attivo nel runtime se p6b_dom=0.
- Pagine HTML reali raggiungibili: ACTIVE=$ACTIVE_PUBLIC.

## Peggiorato / fragile

- Se static_safety mostra FAIL, ci sono residui da rimuovere prima di nuove patch.
- Se DOM gate mostra FAIL, non considerare valido il solo HTTP 200.
- Le pagine REVIEW non vanno collegate come funzionanti.

## Prossima mossa raccomandata

Procedere con **P6D-LITE**, non P6B: dashboard paginata/categorizzata, massimo 20-30 link renderizzati per volta.
MD

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_FULL_STACK_DEEP_AUDIT_READONLY_V1",
  "mutation": false,
  "source_mutation": false,
  "out": "$OUT",
  "build_result": "$BUILD_RESULT",
  "http_failures": $HTTP_FAILS,
  "api_failures": $API_FAILS,
  "dom_failures": $DOM_FAILS,
  "static_failures": $STATIC_FAILS,
  "public_active": $ACTIVE_PUBLIC,
  "public_review": $REVIEW_PUBLIC,
  "overall": "$OVERALL",
  "ports": "$PORTS",
  "runtime": "$RUNTIME",
  "source_state": "$SRC",
  "source_markers": "$MARKERS",
  "static_safety": "$STATIC",
  "build_log": "$BUILDLOG",
  "http_gate": "$HTTP",
  "api_gate": "$API",
  "dom_gate": "$DOMGATE",
  "public_pages_audit": "$PUBLIC_AUDIT",
  "p6a_compare": "$P6A_COMPARE",
  "regression_matrix": "$REGRESSION",
  "executive_findings": "$EXEC",
  "next_actions_plan": "$NEXTPLAN"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_full_stack_deep_audit_readonly_v1"

python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_FULL_STACK_DEEP_AUDIT_READONLY_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
