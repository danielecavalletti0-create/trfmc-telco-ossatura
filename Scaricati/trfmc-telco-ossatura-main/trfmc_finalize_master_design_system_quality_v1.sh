#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
ASSETS="$PUBLIC/assets/trfmc_design_system"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_MASTER_DESIGN_SYSTEM_FINAL_$TS"
LATEST="$BASE/runtime/quality/latest_master_design_system"

mkdir -p "$OUT" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC FINALIZE MASTER DESIGN SYSTEM QUALITY V1"
echo "Solo quality report · V6R3 non toccata"
echo "============================================================"

echo
echo "[1/5] Verifica file locali"
{
  for f in \
    "$ASSETS/trfmc_design_tokens.css" \
    "$PUBLIC/trfmc_integration_control_room_v2.html" \
    "$PUBLIC/trfmc_integration_control_room.html" \
    "$PUBLIC/trfmc_portal_registry_unified.json" \
    "$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
  do
    if [ -f "$f" ]; then
      echo -e "OK\t$f"
    else
      echo -e "MISSING\t$f"
    fi
  done
} | tee "$OUT/local_files.tsv"

echo
echo "[2/5] HTTP test robusto"
{
  printf "url\tstatus\tbytes\n"
  for u in \
    /assets/trfmc_design_system/trfmc_design_tokens.css \
    /trfmc_integration_control_room_v2.html \
    /trfmc_integration_control_room.html \
    /trfmc_portal_registry_unified.json \
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
echo "[3/5] Controllo no CDN / no iframe sulla preview"
grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$PUBLIC/trfmc_integration_control_room_v2.html" \
  > "$OUT/external_refs_control_room_v2.txt" 2>/dev/null || true

grep -nEi '<iframe' \
  "$PUBLIC/trfmc_integration_control_room_v2.html" \
  > "$OUT/iframe_refs_control_room_v2.txt" 2>/dev/null || true

grep -nEi 'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs' \
  "$ASSETS/trfmc_design_tokens.css" \
  > "$OUT/external_refs_design_tokens.txt" 2>/dev/null || true

echo
echo "[4/5] Creo summary.json"
python3 - "$BASE" "$OUT" <<'PY'
import json, sys, hashlib
from pathlib import Path
from datetime import datetime, timezone

base = Path(sys.argv[1])
out = Path(sys.argv[2])
public = base / "frontend/public"

def sha(p):
    p = Path(p)
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

http_rows = []
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 3:
        http_rows.append({"url": p[0], "status": p[1], "bytes": p[2]})

non200 = [x for x in http_rows if x["status"] != "200"]

external_v2 = [x for x in (out / "external_refs_control_room_v2.txt").read_text(errors="ignore").splitlines() if x.strip()]
iframe_v2 = [x for x in (out / "iframe_refs_control_room_v2.txt").read_text(errors="ignore").splitlines() if x.strip()]
external_css = [x for x in (out / "external_refs_design_tokens.txt").read_text(errors="ignore").splitlines() if x.strip()]

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "base": str(base),
    "design_tokens": "/assets/trfmc_design_system/trfmc_design_tokens.css",
    "control_room_v2": "/trfmc_integration_control_room_v2.html",
    "control_room_official_current": "/trfmc_integration_control_room.html",
    "official_v6r3": "/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "http_rows": http_rows,
    "http_non_200": len(non200),
    "control_room_v2_external_refs": len(external_v2),
    "control_room_v2_iframe_refs": len(iframe_v2),
    "design_tokens_external_refs": len(external_css),
    "sha256": {
        "design_tokens": sha(public / "assets/trfmc_design_system/trfmc_design_tokens.css"),
        "control_room_v2": sha(public / "trfmc_integration_control_room_v2.html"),
        "control_room_current": sha(public / "trfmc_integration_control_room.html"),
        "official_v6r3": sha(public / "trfmc_official_safe_entrypoint_v6r3_command_center.html"),
        "registry": sha(public / "trfmc_portal_registry_unified.json"),
    },
    "result": "PASS" if len(non200) == 0 and len(external_v2) == 0 and len(iframe_v2) == 0 and len(external_css) == 0 else "WARN",
    "policy": "Master Design System is a preview layer. V6R3 remains untouched. No promotion without quality gate."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
(out / "result.flag").write_text(summary["result"] + "\n")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "[5/5] Aggiorno latest e freeze se PASS"
rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_MASTER_DESIGN_SYSTEM_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/assets/trfmc_design_system/trfmc_design_tokens.css \
    frontend/public/trfmc_integration_control_room_v2.html \
    frontend/public/trfmc_integration_control_room.html \
    frontend/public/trfmc_portal_registry_unified.json \
    frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html \
    runtime/quality/latest_master_design_system \
    2>/dev/null || true

  echo "Freeze:"
  ls -lh "$FREEZE" 2>/dev/null || true
fi

echo
echo "============================================================"
echo "COMPLETATO"
echo "Latest: $LATEST"
echo "Result: $(cat "$OUT/result.flag")"
echo "============================================================"
