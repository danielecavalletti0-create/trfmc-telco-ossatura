#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RESTART_VITE_5173_AND_RETRY_RUNTIME_AUDIT_V1_$TS"
DOMDIR="$OUT/dom"
SCREENDIR="$OUT/screens"

mkdir -p "$OUT" "$DOMDIR" "$SCREENDIR"
cd "$BASE" || exit 1

SUMMARY="$OUT/summary.json"
VITELOG="$OUT/vite_5173_restart.log"
PORTS="$OUT/ports_after_restart.tsv"
HTTP="$OUT/http_runtime_retry.tsv"
API="$OUT/api_runtime_retry.tsv"
DOMGATE="$OUT/dom_runtime_retry.tsv"
PUBLIC_AUDIT="$OUT/public_pages_runtime_retry.tsv"
REGRESSION="$OUT/runtime_retry_regression.tsv"

echo "============================================================"
echo "TRFMC_RESTART_VITE_5173_AND_RETRY_RUNTIME_AUDIT_V1"
echo "Restart Vite 5173 + runtime audit, no source mutation"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) STOP EVENTUALE PROCESSO SU 5173 ==="

OLD_PID="$(ss -ltnp 2>/dev/null | awk '/:5173/ {print $NF}' | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | head -n 1)"
echo "OLD_PID_5173=${OLD_PID:-NONE}"

if [ -n "$OLD_PID" ]; then
  echo "Fermo processo su 5173: PID=$OLD_PID"
  kill "$OLD_PID"
  sleep 2
fi

echo
echo "=== 2) START VITE 5173 STRICT ==="

cd "$BASE/frontend"
nohup npm run dev -- --host 127.0.0.1 --port 5173 --strictPort > "$VITELOG" 2>&1 &
VITE_PID="$!"
cd "$BASE"

echo "VITE_PID=$VITE_PID"

echo
echo "=== 3) WAIT VITE READY ==="

VITE_UP="NO"
for i in $(seq 1 30); do
  CODE="$(curl -sS --max-time 2 -o "$OUT/vite_wait.html" -w "%{http_code}" http://127.0.0.1:5173/ 2>/dev/null || echo 000)"
  if [ "$CODE" = "200" ]; then
    VITE_UP="YES"
    break
  fi
  sleep 1
done

echo "VITE_UP=$VITE_UP"

echo
echo "=== 4) PORT MAP ==="

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
echo "=== 5) HTTP GATE ==="

cat > "$HTTP" <<HDR
url	status	bytes	content_hint	classification
HDR

check_http() {
  url="$1"
  slug="$(echo "$url" | tr -cd 'A-Za-z0-9_' | head -c 90)"
  tmp="$OUT/http_${slug}.body"
  code="$(curl -sS -L --max-time 8 -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
  bytes="$(wc -c < "$tmp" 2>/dev/null | tr -d ' ')"
  [ -z "$bytes" ] && bytes=0

  hint="TEXT"
  grep -qi '<html\|<!doctype' "$tmp" 2>/dev/null && hint="HTML"
  python3 - "$tmp" <<'PY' > "$OUT/json_hint.tmp" 2>/dev/null
import json, sys
try:
    json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    print("JSON")
except Exception:
    print("")
PY
  jh="$(cat "$OUT/json_hint.tmp" 2>/dev/null)"
  [ "$jh" = "JSON" ] && hint="JSON"

  cls="OK"
  [ "$code" != "200" ] && cls="NON_200"
  [ "$bytes" = "0" ] && cls="ZERO_BYTES"

  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "$bytes" "$hint" "$cls" | tee -a "$HTTP"
}

check_http "http://127.0.0.1:5173/"
check_http "http://127.0.0.1:5173/#portal-os-preview"
check_http "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4"
check_http "http://127.0.0.1:5173/#signal-analyzer"
check_http "http://127.0.0.1:5173/#antenna-system"
check_http "http://127.0.0.1:5173/trfmc_rf_tm_war_room_v4.html"
check_http "http://127.0.0.1:5173/trfmc_domain_registry_v1.html"
check_http "http://127.0.0.1:8000/api/health"
check_http "http://127.0.0.1:8000/openapi.json"
check_http "http://127.0.0.1:4181/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/backend/api/health"
check_http "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

HTTP_FAILS="$(awk -F'\t' 'NR>1 && $5!="OK"{c++} END{print c+0}' "$HTTP")"

echo
echo "=== 6) API JSON GATE ==="

cat > "$API" <<HDR
endpoint	status	json	parse_note
HDR

api_probe() {
  name="$1"
  url="$2"
  raw="$OUT/api_${name}.json"
  code="$(curl -sS -L --max-time 8 -o "$raw" -w "%{http_code}" "$url" 2>/dev/null || echo 000)"

  parse="$(python3 - "$raw" <<'PY' 2>/dev/null
import json, sys
try:
    obj=json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
    if isinstance(obj, dict):
        print("YES\tkeys=" + ",".join(list(obj.keys())[:8]))
    else:
        print("YES\ttype=" + type(obj).__name__)
except Exception as e:
    print("NO\t" + str(e)[:100])
PY
)"
  printf "%s\t%s\t%s\n" "$name" "$code" "$parse" >> "$API"
}

api_probe "backend_health" "http://127.0.0.1:8000/api/health"
api_probe "backend_openapi" "http://127.0.0.1:8000/openapi.json"
api_probe "bridge_health" "http://127.0.0.1:4181/api/health"
api_probe "proxy_backend_health" "http://127.0.0.1:5173/trfmc-api/backend/api/health"
api_probe "proxy_bridge_health" "http://127.0.0.1:5173/trfmc-api/bridge/api/health"

column -t -s $'\t' "$API"

API_FAILS="$(awk -F'\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$API")"

echo
echo "=== 7) DOM GATE ==="

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
  route="$1"
  label="$2"
  url="http://127.0.0.1:5173/${route}"
  dom="$DOMDIR/${label}.dom.txt"
  screen="$SCREENDIR/${label}.png"
  status="SKIPPED_NO_CHROME"

  if [ -n "$CHROME_BIN" ]; then
    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --dump-dom \
      "$url" > "$dom" 2> "$OUT/chrome_${label}.stderr.log"
    rc="$?"
    [ "$rc" = "0" ] && status="PASS" || status="FAIL_RC_$rc"

    "$CHROME_BIN" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --window-size=1920,1080 \
      --virtual-time-budget=9000 \
      --screenshot="$screen" \
      "$url" >/dev/null 2>/dev/null
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
  if [ "$route" != "trfmc_rf_tm_war_room_v4.html" ] && [ "$route" != "trfmc_domain_registry_v1.html" ]; then
    [ "$portal" = "0" ] && res="FAIL_PORTAL_MISSING"
  fi
  [ "$v42" != "0" ] && res="FAIL_V42_LEAK"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$route" "$status" "${bytes:-0}" "$portal" "$p4g" "$p6a" "$p6b" "$v42" "$wr" "$ws" "$wl" "$canvas" "$res" >> "$DOMGATE"
}

dom_probe "#portal-os-preview" "portal_os_preview"
dom_probe "#trfmc-rf-tm-war-room-v4" "hash_war_room"
dom_probe "#signal-analyzer" "hash_signal"
dom_probe "#antenna-system" "hash_antenna"
dom_probe "trfmc_rf_tm_war_room_v4.html" "real_war_room_html"
dom_probe "trfmc_domain_registry_v1.html" "real_domain_registry_html"

column -t -s $'\t' "$DOMGATE"

DOM_FAILS="$(awk -F'\t' 'NR>1 && $13!="PASS"{c++} END{print c+0}' "$DOMGATE")"

echo
echo "=== 8) PUBLIC PAGES QUICK RETRY ==="

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
        proc=subprocess.run(
            ["curl","-sS","-L","--max-time","5","-o",str(tmp),"-w","%{http_code}",f"http://127.0.0.1:5173{url}"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
        )
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

echo
echo "=== 9) REGRESSION RETRY ==="

cat > "$REGRESSION" <<HDR
area	status	evidence	interpretation
HDR

reg() {
  printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" >> "$REGRESSION"
}

[ "$VITE_UP" = "YES" ] && reg "vite_5173" "OK" "vite_up=YES pid=$VITE_PID" "frontend dev server is alive on 5173" || reg "vite_5173" "BLOCKER" "vite_up=$VITE_UP" "cannot validate portal runtime"
[ "$HTTP_FAILS" = "0" ] && reg "http_runtime" "OK" "http_failures=0" "all checked URLs respond" || reg "http_runtime" "REVIEW" "http_failures=$HTTP_FAILS" "some runtime URLs failed"
[ "$API_FAILS" = "0" ] && reg "api_runtime" "OK" "api_failures=0" "direct backend/bridge and Vite proxies respond" || reg "api_runtime" "REVIEW" "api_failures=$API_FAILS" "proxy or direct API issue"
[ "$DOM_FAILS" = "0" ] && reg "dom_runtime" "OK" "dom_failures=0" "Portal OS and real pages render" || reg "dom_runtime" "REVIEW" "dom_failures=$DOM_FAILS" "inspect DOM gate"
reg "public_pages" "INFO" "active=$ACTIVE_PUBLIC review=$REVIEW_PUBLIC" "runtime public page availability after Vite restart"

P6A_DOM="$(awk -F'\t' '$1=="#portal-os-preview"{print $6}' "$DOMGATE")"
P6B_DOM="$(awk -F'\t' '$1=="#portal-os-preview"{print $7}' "$DOMGATE")"
WORKING_LINKS="$(awk -F'\t' '$1=="#portal-os-preview"{print $11}' "$DOMGATE")"

[ "${P6A_DOM:-0}" != "0" ] && reg "p6a_dashboard" "OK" "p6a_dom=$P6A_DOM working_links=$WORKING_LINKS" "P6A working pages dashboard visible" || reg "p6a_dashboard" "REVIEW" "p6a_dom=$P6A_DOM" "P6A not visible"
[ "${P6B_DOM:-0}" = "0" ] && reg "p6b_rollback" "OK" "p6b_dom=0" "failed P6B not active" || reg "p6b_rollback" "REVIEW" "p6b_dom=$P6B_DOM" "P6B residue visible"

column -t -s $'\t' "$REGRESSION"

OVERALL="PASS"
[ "$VITE_UP" != "YES" ] && OVERALL="FAIL_VITE_5173"
[ "$HTTP_FAILS" != "0" ] && OVERALL="REVIEW_HTTP"
[ "$API_FAILS" != "0" ] && OVERALL="REVIEW_API"
[ "$DOM_FAILS" != "0" ] && OVERALL="REVIEW_DOM"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_RESTART_VITE_5173_AND_RETRY_RUNTIME_AUDIT_V1",
  "mutation": false,
  "source_mutation": false,
  "vite_pid": "$VITE_PID",
  "vite_up": "$VITE_UP",
  "vite_log": "$VITELOG",
  "ports": "$PORTS",
  "http_gate": "$HTTP",
  "api_gate": "$API",
  "dom_gate": "$DOMGATE",
  "public_pages_audit": "$PUBLIC_AUDIT",
  "regression": "$REGRESSION",
  "http_failures": $HTTP_FAILS,
  "api_failures": $API_FAILS,
  "dom_failures": $DOM_FAILS,
  "public_active": $ACTIVE_PUBLIC,
  "public_review": $REVIEW_PUBLIC,
  "p6a_dom": ${P6A_DOM:-0},
  "p6b_dom": ${P6B_DOM:-0},
  "working_links": ${WORKING_LINKS:-0},
  "overall": "$OVERALL"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_restart_vite_5173_and_retry_runtime_audit_v1"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "============================================================"
echo "TRFMC_RESTART_VITE_5173_AND_RETRY_RUNTIME_AUDIT_V1 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
