#!/usr/bin/env bash
set -u
set +e
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
OUT="$BASE/runtime/quality/TRFMC_CONSOLIDATION_GATE_FIXED_$(date +%Y%m%d_%H%M%S)"
LATEST="$BASE/runtime/quality/latest_consolidation_registry"

mkdir -p "$OUT"

probe() {
  local u="$1"
  local r code bytes
  r="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --connect-timeout 2 --max-time 5 "http://127.0.0.1:5173$u" 2>/dev/null)"
  code="$(echo "$r" | awk '{print $1}')"
  bytes="$(echo "$r" | awk '{print $2}')"
  [ -n "$code" ] || code="000"
  [ -n "$bytes" ] || bytes="0"
  echo -e "$u\t$code\t$bytes"
}

{
  echo -e "url\tstatus\tbytes"
  probe /trfmc_portal_registry_unified.json
  probe /trfmc_integration_control_room.html
  probe /trfmc_official_safe_entrypoint_v6r3_command_center.html
} | tee "$OUT/http.tsv"

grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' \
  frontend/public/trfmc_integration_control_room.html \
  > "$OUT/external_refs.txt" 2>/dev/null || true

grep -nEi '<iframe' \
  frontend/public/trfmc_integration_control_room.html \
  > "$OUT/iframe_refs.txt" 2>/dev/null || true

export OUT
python3 - <<'PY'
import json, os
from pathlib import Path
from datetime import datetime, timezone

out=Path(os.environ["OUT"])
non200=0
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=2 and p[1]!="200":
        non200+=1

external=sum(1 for x in (out/"external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
iframe=sum(1 for x in (out/"iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())

data={
 "timestamp":datetime.now(timezone.utc).isoformat(),
 "registry":"http://127.0.0.1:5173/trfmc_portal_registry_unified.json",
 "control_room":"http://127.0.0.1:5173/trfmc_integration_control_room.html",
 "http_non_200":non200,
 "external_refs":external,
 "iframe_refs":iframe,
 "result":"PASS" if non200==0 and external==0 and iframe==0 else "WARN"
}
(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$OUT" "$LATEST"

echo
echo "=== SUMMARY ==="
cat "$LATEST/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$LATEST/http.tsv"
