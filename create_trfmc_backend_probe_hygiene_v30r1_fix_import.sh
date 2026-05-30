#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
APP="$ROOT/backend/readonly_bridge_v28/app.py"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_BACKEND_PROBE_HYGIENE_V30R1_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_BACKEND_PROBE_HYGIENE_V30R1_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_BACKEND_PROBE_HYGIENE_V30R1_$TS.tar.gz"

echo "============================================================"
echo "TRFMC BACKEND PROBE HYGIENE V30R1"
echo "fix missing import re · restore backend truth · prevent proxy fallback"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f "$APP" || { echo "ERRORE: app.py mancante"; exit 1; }
test -f "$ROOT/runtime/quality/latest_readonly_backend_systemd_pack_v29/summary.json" || {
  echo "ERRORE: V29 summary mancante"
  exit 1
}

cp "$APP" "$RELEASE_DIR/app.py.bak_before_v30r1_$TS"

echo "OK: app.py e V29 presenti"

echo
echo "=== PATCH IMPORT RE ==="

python3 - "$APP" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

if "import re\n" not in txt:
    if "import platform\n" in txt:
        txt = txt.replace("import platform\n", "import platform\nimport re\n", 1)
    elif "import json\n" in txt:
        txt = txt.replace("import json\n", "import json\nimport re\n", 1)
    else:
        txt = "import re\n" + txt
    p.write_text(txt, encoding="utf-8")
    print("OK: aggiunto import re")
else:
    print("OK: import re già presente")
PY

echo
echo "=== SYNTAX CHECK ==="

python3 -m py_compile "$APP"

echo
echo "=== RESTART BACKEND SYSTEMD ==="

systemctl --user restart trfmc-readonly-backend-8000.service
sleep 3

echo
echo "=== SERVICE STATUS COMPACT ==="

systemctl --user is-active trfmc-readonly-backend-8000.service || true
ss -ltnp | grep ':8000' || true

echo
echo "=== DIRECT 8000 TRUTH CHECK ==="

DIRECT_OPEN5GS="$RELEASE_DIR/direct_open5gs_8000.json"
DIRECT_UERANSIM="$RELEASE_DIR/direct_ueransim_8000.json"
PROXY_OPEN5GS="$RELEASE_DIR/proxy_open5gs_4181.json"
PROXY_UERANSIM="$RELEASE_DIR/proxy_ueransim_4181.json"
RUNTIME_SERVICES="$RELEASE_DIR/runtime_services_4181.json"

curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:8000/api/core/open5gs/status | python3 -m json.tool > "$DIRECT_OPEN5GS"
curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:8000/api/ran/ueransim/status | python3 -m json.tool > "$DIRECT_UERANSIM"
curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/core/open5gs/status | python3 -m json.tool > "$PROXY_OPEN5GS"
curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/ran/ueransim/status | python3 -m json.tool > "$PROXY_UERANSIM"
curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/runtime/services | python3 -m json.tool > "$RUNTIME_SERVICES"

echo
echo "--- DIRECT OPEN5GS"
python3 - "$DIRECT_OPEN5GS" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print("status=", d.get("status"))
print("source=", d.get("source"))
print("readiness=", d.get("open5gs",{}).get("readiness"))
print("process_count=", d.get("open5gs",{}).get("process_probe",{}).get("count"))
print("probe_hygiene=", d.get("open5gs",{}).get("process_probe",{}).get("probe_hygiene"))
print("lines=", d.get("open5gs",{}).get("process_probe",{}).get("lines"))
PY

echo
echo "--- DIRECT UERANSIM"
python3 - "$DIRECT_UERANSIM" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print("status=", d.get("status"))
print("source=", d.get("source"))
print("readiness=", d.get("ueransim",{}).get("readiness"))
print("process_count=", d.get("ueransim",{}).get("process_probe",{}).get("count"))
print("probe_hygiene=", d.get("ueransim",{}).get("process_probe",{}).get("probe_hygiene"))
print("lines=", d.get("ueransim",{}).get("process_probe",{}).get("lines"))
PY

echo
echo "--- PROXY OPEN5GS SOURCE"
python3 - "$PROXY_OPEN5GS" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print("status=", d.get("status"))
print("source=", d.get("source"))
print("readiness=", d.get("open5gs",{}).get("readiness"))
PY

echo
echo "--- PROXY UERANSIM SOURCE"
python3 - "$PROXY_UERANSIM" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print("status=", d.get("status"))
print("source=", d.get("source"))
print("readiness=", d.get("ueransim",{}).get("readiness"))
PY

echo
echo "=== HTTP GATE ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

for base in http://127.0.0.1:8000 http://127.0.0.1:4181
do
  probe "$base/api/health"
  probe "$base/api/mission/status"
  probe "$base/api/core/open5gs/status"
  probe "$base/api/ran/ueransim/status"
  probe "$base/api/runtime/services"
  probe "$base/api/network-fabric/overview"
done

column -t -s $'\t' "$HTTP_TSV"

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

DIRECT_OPEN5GS_SOURCE="$(python3 - "$DIRECT_OPEN5GS" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("source",""))
PY
)"

DIRECT_UERANSIM_SOURCE="$(python3 - "$DIRECT_UERANSIM" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("source",""))
PY
)"

PROXY_OPEN5GS_SOURCE="$(python3 - "$PROXY_OPEN5GS" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("source",""))
PY
)"

PROXY_UERANSIM_SOURCE="$(python3 - "$PROXY_UERANSIM" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("source",""))
PY
)"

OPEN5GS_LINES_HAVE_CURL="$(python3 - "$DIRECT_OPEN5GS" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
lines=d.get("open5gs",{}).get("process_probe",{}).get("lines",[])
print("yes" if any("curl" in x.lower() for x in lines) else "no")
PY
)"

{
  grep -q '^import re$' "$APP" && echo "OK: import re present" || echo "MISS: import re present"
  systemctl --user is-active --quiet trfmc-readonly-backend-8000.service && echo "OK: backend service active" || echo "MISS: backend service active"

  [ "$DIRECT_OPEN5GS_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: direct open5gs backend source" || echo "MISS: direct open5gs backend source"
  [ "$DIRECT_UERANSIM_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: direct ueransim backend source" || echo "MISS: direct ueransim backend source"

  [ "$PROXY_OPEN5GS_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: proxy open5gs backend source" || echo "MISS: proxy open5gs backend source"
  [ "$PROXY_UERANSIM_SOURCE" = "TRFMC_READONLY_BACKEND_BRIDGE_V28" ] && echo "OK: proxy ueransim backend source" || echo "MISS: proxy ueransim backend source"

  [ "$OPEN5GS_LINES_HAVE_CURL" = "no" ] && echo "OK: open5gs no curl false positive" || echo "MISS: open5gs curl false positive"

  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:8000/api/core/open5gs/status >/dev/null && echo "OK: direct open5gs HTTP" || echo "MISS: direct open5gs HTTP"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/api/core/open5gs/status >/dev/null && echo "OK: proxy open5gs HTTP" || echo "MISS: proxy open5gs HTTP"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/api/ran/ueransim/status >/dev/null && echo "OK: proxy ueransim HTTP" || echo "MISS: proxy ueransim HTTP"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== JOURNAL RECENT ==="

JOURNAL_TXT="$RELEASE_DIR/journal_recent_v30r1.txt"
journalctl --user -u trfmc-readonly-backend-8000.service --since "2 minutes ago" --no-pager > "$JOURNAL_TXT" 2>/dev/null || true
tail -n 80 "$JOURNAL_TXT" || true

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/backend_probe_hygiene_v30r1_manifest.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BACKEND_PROBE_HYGIENE_V30R1",
  "app": "$APP",
  "backend_url": "http://127.0.0.1:8000/",
  "proxy_url": "http://127.0.0.1:4181/",
  "fix": "added missing import re required by V30 process_probe hygiene",
  "samples": {
    "direct_open5gs": "$DIRECT_OPEN5GS",
    "direct_ueransim": "$DIRECT_UERANSIM",
    "proxy_open5gs": "$PROXY_OPEN5GS",
    "proxy_ueransim": "$PROXY_UERANSIM",
    "runtime_services": "$RUNTIME_SERVICES"
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  backend/readonly_bridge_v28/app.py \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BACKEND_PROBE_HYGIENE_V30R1",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_backend_probe_hygiene_v30r1"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_backend_probe_hygiene_v30r1"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V30R1 BACKEND PROBE HYGIENE COMPLETATO"
echo "Summary: runtime/quality/latest_backend_probe_hygiene_v30r1/summary.json"
echo "============================================================"
