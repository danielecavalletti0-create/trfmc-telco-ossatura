#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
REG="$PUBLIC/trfmc_portal_registry_unified.json"
ROOM="$PUBLIC/trfmc_integration_control_room.html"
OFFICIAL="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_CONSOLIDATION_REGISTRY_FINAL_$TS"
LATEST="$BASE/runtime/quality/latest_consolidation_registry"

mkdir -p "$OUT" "$BASE/runtime/quality"

echo "============================================================"
echo "TRFMC FINALIZE CONSOLIDATION QUALITY V1"
echo "Solo report qualità · nessuna modifica a V6R3/control room"
echo "============================================================"

echo
echo "[1/4] Verifica file locali"
for f in "$REG" "$ROOM" "$OFFICIAL"; do
  if [ -f "$f" ]; then
    echo "OK: $f"
  else
    echo "MISSING: $f"
  fi
done | tee "$OUT/local_files.txt"

echo
echo "[2/4] HTTP test robusto"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_portal_registry_unified.json \
    /trfmc_integration_control_room.html \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

echo
echo "[3/4] Analisi registry e policy"
python3 - "$BASE" "$OUT" <<'PY'
import json, sys, re, hashlib
from pathlib import Path
from datetime import datetime, timezone

base = Path(sys.argv[1])
out = Path(sys.argv[2])
public = base / "frontend/public"
reg_path = public / "trfmc_portal_registry_unified.json"
room = public / "trfmc_integration_control_room.html"
official = public / "trfmc_official_safe_entrypoint_v6r3_command_center.html"

def sha(p):
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def read(p):
    return p.read_text(errors="ignore") if p.exists() else ""

reg = json.loads(read(reg_path)) if reg_path.exists() else {}
http_rows = []
http_file = out / "http.tsv"
if http_file.exists():
    for line in http_file.read_text(errors="ignore").splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) >= 3:
            http_rows.append({"url": parts[0], "status": parts[1], "bytes": parts[2]})

non200 = [x for x in http_rows if x["status"] != "200"]

room_txt = read(room)
official_txt = read(official)

external_room = re.findall(r"https://|http://|cdn\.|unpkg|jsdelivr|cdnjs", room_txt, re.I)
iframe_room = re.findall(r"<iframe", room_txt, re.I)

counts = reg.get("counts", {})
pages = reg.get("pages", [])

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "base": str(base),
    "official_entrypoint": "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "integration_control_room": "/trfmc_integration_control_room.html",
    "registry": "/trfmc_portal_registry_unified.json",
    "registry_counts": counts,
    "registered_pages": len(pages),
    "http_rows": http_rows,
    "http_non_200": len(non200),
    "control_room_external_refs": len(external_room),
    "control_room_iframe_refs": len(iframe_room),
    "sha256": {
        "registry": sha(reg_path),
        "control_room": sha(room),
        "official_v6r3": sha(official),
    },
    "result": "PASS" if len(non200) == 0 and len(external_room) == 0 and len(iframe_room) == 0 else "WARN",
    "policy": "V6R3 is the official shell. Registry governs integration. No standalone module promotion without quality report."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

with (out / "registry_pages.tsv").open("w", encoding="utf-8") as f:
    f.write("class\tname\turl\tsize\twebgl\tcore_api\thas_iframe\texternal_refs\trefs_count\n")
    for p in pages:
        f.write(
            f"{p.get('class','')}\t{p.get('name','')}\t{p.get('url','')}\t{p.get('size','')}\t"
            f"{p.get('webgl','')}\t{p.get('core_api','')}\t{p.get('has_iframe','')}\t"
            f"{p.get('external_refs','')}\t{p.get('refs_count','')}\n"
        )

(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "[4/4] Aggiorno latest_consolidation_registry"
rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "============================================================"
echo "COMPLETATO"
echo "Latest: $LATEST"
echo "Result: $(cat "$OUT/result.flag")"
echo "============================================================"
