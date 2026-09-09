#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
APP="$ROOT/backend/readonly_bridge_v28/app.py"
QUALITY_DIR="$ROOT/runtime/quality/TRFMC_BACKEND_PROBE_HYGIENE_V30_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_BACKEND_PROBE_HYGIENE_V30_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_BACKEND_PROBE_HYGIENE_V30_$TS.tar.gz"

echo "============================================================"
echo "TRFMC BACKEND PROBE HYGIENE V30"
echo "fix process false positives · truthful Open5GS/UERANSIM readiness"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f "$APP" || { echo "ERRORE: app.py V28 mancante"; exit 1; }
test -f "$ROOT/runtime/quality/latest_readonly_backend_systemd_pack_v29/summary.json" || {
  echo "ERRORE: V29 summary mancante"
  exit 1
}

cp "$APP" "$RELEASE_DIR/app.py.bak_before_v30_$TS"

echo "OK: app.py e V29 presenti"

echo
echo "=== PATCH process_probe ==="

python3 - "$APP" <<'PY'
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])
txt = app.read_text(encoding="utf-8")

new_func = r'''def process_probe(pattern: str) -> dict[str, Any]:
    """
    Robust read-only process probe.

    V30 hygiene:
    - avoid pgrep self/curl false positives;
    - inspect process table directly;
    - for open5gs, match real open5gs daemon names only;
    - for UERANSIM, match real nr-gnb/nr-ue processes only.
    """
    out = run_cmd(["ps", "-eo", "pid=,comm=,args="], timeout=2)
    lines: list[str] = []

    excluded_comms = {
        "curl", "grep", "pgrep", "awk", "sed", "head", "tail",
        "python3", "python", "uvicorn", "nginx", "bash", "sh",
    }

    raw_pattern = pattern
    lower_pattern = pattern.lower()

    for raw in out["stdout"].splitlines():
        raw = raw.strip()
        if not raw:
            continue

        parts = raw.split(None, 2)
        if len(parts) < 2:
            continue

        pid = parts[0]
        comm = parts[1]
        args = parts[2] if len(parts) > 2 else ""

        comm_l = comm.lower()
        args_l = args.lower()

        if comm_l in excluded_comms:
            continue

        # Specific Open5GS daemon hygiene.
        if lower_pattern == "open5gs":
            if comm_l.startswith("open5gs-") or re.search(r'(^|/|\\s)open5gs-[a-z0-9_-]+d?(\\s|$)', args_l):
                lines.append(raw)
            continue

        # Specific UERANSIM hygiene.
        if "nr-gnb" in lower_pattern or "nr-ue" in lower_pattern or "ueransim" in lower_pattern:
            if comm_l in {"nr-gnb", "nr-ue"} or re.search(r'(^|/|\\s)(nr-gnb|nr-ue)(\\s|$)', args_l) or "ueransim/build/nr-" in args_l:
                lines.append(raw)
            continue

        # Generic safe regex mode, excluding pure probe commands.
        try:
            if re.search(raw_pattern, comm, re.I) or re.search(raw_pattern, args, re.I):
                lines.append(raw)
        except re.error:
            if raw_pattern.lower() in comm_l or raw_pattern.lower() in args_l:
                lines.append(raw)

    return {
        "pattern": pattern,
        "count": len(lines),
        "lines": lines[:20],
        "running": len(lines) > 0,
        "probe_hygiene": "v30_no_curl_no_pgrep_no_self_match",
    }


'''

pattern = re.compile(r'def process_probe\(pattern: str\) -> dict\[str, Any\]:\n.*?\n\ndef ss_probe\(\) -> list\[dict\[str, Any\]\]:', re.S)
m = pattern.search(txt)
if not m:
    raise SystemExit("ERRORE: funzione process_probe non trovata o formato inatteso")

txt2 = txt[:m.start()] + new_func + "\ndef ss_probe() -> list[dict[str, Any]]:" + txt[m.end():]

if txt2 == txt:
    raise SystemExit("ERRORE: patch non applicata")

app.write_text(txt2, encoding="utf-8")
print("OK: process_probe patched")
PY

echo
echo "=== SYNTAX CHECK ==="

python3 -m py_compile "$APP"

echo
echo "=== RESTART BACKEND SYSTEMD V29 ==="

systemctl --user restart trfmc-readonly-backend-8000.service
sleep 3

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
done

column -t -s $'\t' "$HTTP_TSV"

echo
echo "=== PAYLOAD TRUTH CHECKS ==="

OPEN5GS_JSON="$RELEASE_DIR/open5gs_status_4181.json"
UERANSIM_JSON="$RELEASE_DIR/ueransim_status_4181.json"
RUNTIME_JSON="$RELEASE_DIR/runtime_services_4181.json"

curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/core/open5gs/status | python3 -m json.tool > "$OPEN5GS_JSON"
curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/ran/ueransim/status | python3 -m json.tool > "$UERANSIM_JSON"
curl -sS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/runtime/services | python3 -m json.tool > "$RUNTIME_JSON"

echo
echo "--- Open5GS readiness"
python3 - "$OPEN5GS_JSON" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print("readiness=", d.get("open5gs",{}).get("readiness"))
print("process_count=", d.get("open5gs",{}).get("process_probe",{}).get("count"))
print("probe_hygiene=", d.get("open5gs",{}).get("process_probe",{}).get("probe_hygiene"))
print("lines=", d.get("open5gs",{}).get("process_probe",{}).get("lines"))
PY

echo
echo "--- UERANSIM readiness"
python3 - "$UERANSIM_JSON" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print("readiness=", d.get("ueransim",{}).get("readiness"))
print("process_count=", d.get("ueransim",{}).get("process_probe",{}).get("count"))
print("probe_hygiene=", d.get("ueransim",{}).get("process_probe",{}).get("probe_hygiene"))
print("lines=", d.get("ueransim",{}).get("process_probe",{}).get("lines"))
PY

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

OPEN5GS_HYGIENE="$(python3 - "$OPEN5GS_JSON" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print(d.get("open5gs",{}).get("process_probe",{}).get("probe_hygiene",""))
PY
)"

UERANSIM_HYGIENE="$(python3 - "$UERANSIM_JSON" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
print(d.get("ueransim",{}).get("process_probe",{}).get("probe_hygiene",""))
PY
)"

OPEN5GS_LINES_HAVE_CURL="$(python3 - "$OPEN5GS_JSON" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
lines=d.get("open5gs",{}).get("process_probe",{}).get("lines",[])
print("yes" if any("curl" in x.lower() for x in lines) else "no")
PY
)"

UERANSIM_LINES_HAVE_CURL="$(python3 - "$UERANSIM_JSON" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
lines=d.get("ueransim",{}).get("process_probe",{}).get("lines",[])
print("yes" if any("curl" in x.lower() for x in lines) else "no")
PY
)"

{
  grep -q "probe_hygiene" "$APP" && echo "OK: probe hygiene marker in app" || echo "MISS: probe hygiene marker in app"
  [ "$OPEN5GS_HYGIENE" = "v30_no_curl_no_pgrep_no_self_match" ] && echo "OK: open5gs hygiene marker" || echo "MISS: open5gs hygiene marker"
  [ "$UERANSIM_HYGIENE" = "v30_no_curl_no_pgrep_no_self_match" ] && echo "OK: ueransim hygiene marker" || echo "MISS: ueransim hygiene marker"
  [ "$OPEN5GS_LINES_HAVE_CURL" = "no" ] && echo "OK: open5gs no curl false positive" || echo "MISS: open5gs curl false positive"
  [ "$UERANSIM_LINES_HAVE_CURL" = "no" ] && echo "OK: ueransim no curl false positive" || echo "MISS: ueransim curl false positive"
  systemctl --user is-active --quiet trfmc-readonly-backend-8000.service && echo "OK: backend service active" || echo "MISS: backend service active"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/api/core/open5gs/status >/dev/null && echo "OK: proxy open5gs status" || echo "MISS: proxy open5gs status"
  curl -fsS --connect-timeout 2 --max-time 6 http://127.0.0.1:4181/api/ran/ueransim/status >/dev/null && echo "OK: proxy ueransim status" || echo "MISS: proxy ueransim status"
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
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/backend_probe_hygiene_manifest_v30.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_BACKEND_PROBE_HYGIENE_V30",
  "app": "$APP",
  "backend_url": "http://127.0.0.1:8000/",
  "proxy_url": "http://127.0.0.1:4181/",
  "fixes": [
    "exclude curl/pgrep/grep/python/nginx/bash from process probes",
    "match Open5GS only by real open5gs daemon names",
    "match UERANSIM only by real nr-gnb/nr-ue processes",
    "preserve read-only safety model"
  ],
  "samples": {
    "open5gs": "$OPEN5GS_JSON",
    "ueransim": "$UERANSIM_JSON",
    "runtime": "$RUNTIME_JSON"
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
  "operation": "TRFMC_BACKEND_PROBE_HYGIENE_V30",
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

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_backend_probe_hygiene_v30"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_backend_probe_hygiene_v30"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V30 BACKEND PROBE HYGIENE COMPLETATO"
echo "Summary: runtime/quality/latest_backend_probe_hygiene_v30/summary.json"
echo "============================================================"
