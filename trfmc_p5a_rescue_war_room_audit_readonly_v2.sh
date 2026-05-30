#!/usr/bin/env bash
set -u
set +e
set +o pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P5A_RESCUE_WAR_ROOM_AUDIT_READONLY_V2_$TS"

mkdir -p "$OUT"
cd "$BASE" || exit 1

WAR_ROOM_SRC="frontend/public/trfmc_rf_tm_war_room_v4.html"
SUMMARY="$OUT/summary.json"
INVENTORY="$OUT/war_room_inventory.tsv"
DANGER="$OUT/war_room_danger_scan.tsv"
CURRENT_ROUTE_DOM="$OUT/current_route_dom.txt"
CURRENT_ROUTE_SCREEN="$OUT/current_route_1920x1080.png"
REALITY="$OUT/reality_check.tsv"
PLAN="$OUT/P5A_REALITY_AND_P5B_PLAN.md"

echo "============================================================"
echo "TRFMC_P5A_RESCUE_WAR_ROOM_AUDIT_READONLY_V2"
echo "No mutation · chiude il P5A fallito · distingue route da pagina reale"
echo "Timestamp: $TS"
echo "============================================================"

echo
echo "=== 1) CERCO ULTIMO P4G-C FALLITO / INCOMPLETO ==="
LAST_P4GC="$(find runtime/quality -maxdepth 1 -type d -name 'TRFMC_P4G_C_FREEZE_AND_P5A_WAR_ROOM_AUDIT_READONLY_*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)"
echo "LAST_P4GC=${LAST_P4GC:-NONE}"

echo
echo "=== 2) CHECK P4G-B BASELINE ==="
P4GB="runtime/quality/latest_p4g_b_runtime_route_reprobe_after_vite_recovery/summary.json"
if [ -f "$P4GB" ]; then
  python3 -m json.tool "$P4GB" | sed -n '1,120p'
else
  echo "P4G-B summary non trovato"
fi

echo
echo "=== 3) INVENTORY WAR ROOM LEGACY ==="

python3 - "$WAR_ROOM_SRC" "$INVENTORY" "$DANGER" "$CURRENT_ROUTE_DOM" "$CURRENT_ROUTE_SCREEN" "$REALITY" "$PLAN" "$SUMMARY" "$LAST_P4GC" <<'PY'
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

src = Path(sys.argv[1])
inventory = Path(sys.argv[2])
danger = Path(sys.argv[3])
dom_out = Path(sys.argv[4])
screen_out = Path(sys.argv[5])
reality = Path(sys.argv[6])
plan = Path(sys.argv[7])
summary = Path(sys.argv[8])
last_p4gc = sys.argv[9]

base = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")

def safe_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")

text = safe_text(src)
lines = text.splitlines()
sha = hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest() if text else "-"

def count(pattern, flags=re.I):
    return len(re.findall(pattern, text, flags)) if text else 0

metrics = {
    "source_exists": "YES" if src.exists() else "NO",
    "path": str(src),
    "bytes": len(text.encode("utf-8")),
    "lines": len(lines),
    "sha256": sha,
    "title_tags": count(r"<title\b"),
    "script_tags": count(r"<script\b"),
    "style_tags": count(r"<style\b"),
    "link_tags": count(r"<link\b"),
    "canvas_tags": count(r"<canvas\b"),
    "section_tags": count(r"<section\b"),
    "button_tags": count(r"<button\b"),
    "anchor_tags": count(r"<a\b"),
    "absolute_html_links": count(r'href="/[^"]+\.html|href=\'/[^\']+\.html'),
    "iframe_tags": count(r"<iframe\b"),
    "dangerous_dom_hits": count(r"innerHTML|outerHTML|document\.write|insertAdjacentHTML|eval\(|new Function"),
    "inline_event_handlers": count(r"\son[a-z]+\s*="),
    "external_http_refs": count(r"https?://"),
    "cdn_refs": count(r"cdn\.|unpkg|jsdelivr|cdnjs|googleapis|gstatic"),
    "rf_telco_hits": count(r"\brf\b|spectrum|sinr|rsrp|rsrq|antenna|iq|fft|waterfall|evm|ofdm|qam|gnb|ueransim|open5gs|ngap|pfcp|gtp|war room|evidence"),
}

with inventory.open("w", encoding="utf-8") as f:
    f.write("metric\tvalue\n")
    for k, v in metrics.items():
        f.write(f"{k}\t{v}\n")

danger_patterns = {
    "iframe": r"<iframe\b",
    "dangerous_dom": r"innerHTML|outerHTML|document\.write|insertAdjacentHTML|eval\(|new Function",
    "inline_event_handler": r"\son[a-z]+\s*=",
    "external_url": r"https?://",
    "cdn": r"cdn\.|unpkg|jsdelivr|cdnjs|googleapis|gstatic",
    "absolute_html_link": r'href="/[^"]+\.html|href=\'/[^\']+\.html',
}

with danger.open("w", encoding="utf-8") as f:
    f.write("risk\tcount\tfirst_line\tfirst_match\n")
    for name, pattern in danger_patterns.items():
        found = []
        for idx, line in enumerate(lines, 1):
            if re.search(pattern, line, re.I):
                found.append((idx, re.sub(r"\s+", " ", line.strip())[:180]))
        f.write(f"{name}\t{len(found)}\t{found[0][0] if found else '-'}\t{found[0][1] if found else '-'}\n")

# DOM probe current route, senza far fallire lo script.
chrome = None
for candidate in ["google-chrome", "chromium"]:
    try:
        subprocess.run([candidate, "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        chrome = candidate
        break
    except FileNotFoundError:
        pass

dom_text = ""
dom_status = "SKIPPED_NO_CHROME"
shot_status = "SKIPPED_NO_CHROME"

if chrome:
    url = "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4"
    dom_cmd = [
        chrome, "--headless=new", "--disable-gpu", "--no-sandbox",
        "--window-size=1920,1080", "--virtual-time-budget=9000",
        "--dump-dom", url
    ]
    dom_proc = subprocess.run(dom_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
    dom_text = dom_proc.stdout or ""
    dom_out.write_text(dom_text, encoding="utf-8")
    dom_status = "PASS" if dom_proc.returncode == 0 and dom_text else f"FAIL_RC_{dom_proc.returncode}"

    shot_cmd = [
        chrome, "--headless=new", "--disable-gpu", "--no-sandbox",
        "--window-size=1920,1080", "--virtual-time-budget=9000",
        f"--screenshot={screen_out}", url
    ]
    shot_proc = subprocess.run(shot_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
    shot_status = "PASS" if shot_proc.returncode == 0 and screen_out.exists() else f"FAIL_RC_{shot_proc.returncode}"
else:
    dom_out.write_text("NO_CHROME_AVAILABLE", encoding="utf-8")

def dcount(needle: str) -> int:
    return dom_text.count(needle)

portal_os_count = dcount('data-trfmc-portal-os-preview="mounted"')
p4g_count = dcount('data-trfmc-p4g-route-registry="mounted"')
war_room_title_count = dcount("TRFMC RF/TM War Room V4")
legacy_canvas_runtime_count = dcount("<canvas")
legacy_source_runtime_count = dcount("frontend/public/trfmc_rf_tm_war_room_v4.html")
v42_count = dcount("TELCO RF MISSION CONTROL PLATFORM")

# La verità funzionale:
# route OK se PortalOS/P4G/title sono presenti.
# page real NOT OK finché non vedo canvas/struttura War Room nativa o componente P5.
route_ok = portal_os_count > 0 and p4g_count > 0 and war_room_title_count > 0 and v42_count == 0
real_page_ok = dcount('data-trfmc-p5-war-room-domain="mounted"') > 0

with reality.open("w", encoding="utf-8") as f:
    f.write("check\tresult\tdetail\n")
    f.write(f"hash_route_governed\t{'PASS' if route_ok else 'FAIL'}\tPortalOS={portal_os_count}; P4G={p4g_count}; title={war_room_title_count}; V42={v42_count}\n")
    f.write(f"legacy_html_source_exists\t{'PASS' if src.exists() else 'FAIL'}\t{src}\n")
    f.write(f"war_room_real_component_active\t{'PASS' if real_page_ok else 'FAIL'}\tdata-trfmc-p5-war-room-domain not mounted yet\n")
    f.write(f"legacy_runtime_canvas_visible\t{'PASS' if legacy_canvas_runtime_count > 0 else 'FAIL'}\tcanvas_in_current_route_dom={legacy_canvas_runtime_count}\n")
    f.write(f"unsafe_html_in_source\t{'FAIL' if metrics['dangerous_dom_hits'] else 'PASS'}\tdangerous_dom_hits={metrics['dangerous_dom_hits']}\n")
    f.write(f"absolute_html_links_need_conversion\t{'REVIEW' if metrics['absolute_html_links'] else 'PASS'}\tabs_html_links={metrics['absolute_html_links']}\n")

plan_lines = [
    "# P5A Reality Check + P5B Plan",
    "",
    "## Verità operativa",
    "",
    "Il routing P4G aggancia la route `#trfmc-rf-tm-war-room-v4` al Portal OS, ma la pagina War Room completa non è ancora stata promossa in React.",
    "",
    "Quindi:",
    "",
    "- `hash_route_governed`: deve essere PASS.",
    "- `war_room_real_component_active`: oggi è FAIL finché non creiamo `WarRoomDomainP5`.",
    "- `legacy_runtime_canvas_visible`: oggi è FAIL perché il contenuto HTML legacy non viene montato, ed è corretto non montarlo via iframe/innerHTML.",
    "",
    "## Audit sorgente legacy",
    "",
    f"- Source: `{src}`",
    f"- Lines: {metrics['lines']}",
    f"- Canvas tags: {metrics['canvas_tags']}",
    f"- Script tags: {metrics['script_tags']}",
    f"- RF/Telco hits: {metrics['rf_telco_hits']}",
    f"- Dangerous DOM hits: {metrics['dangerous_dom_hits']}",
    f"- Iframe tags: {metrics['iframe_tags']}",
    f"- Absolute HTML links: {metrics['absolute_html_links']}",
    "",
    "## Decisione corretta",
    "",
    "Non dobbiamo più fingere che il link sia la pagina completa. Il prossimo passo deve creare un componente React nativo:",
    "",
    "- `frontend/src/domains/war-room/WarRoomDomainP5.tsx`",
    "- `frontend/src/domains/war-room/warRoomRegistry.ts`",
    "",
    "e poi `PortalOSRoot` deve montare quel componente quando il modulo attivo è `trfmc-rf-tm-war-room-v4`.",
    "",
    "## Gate P5B",
    "",
    "- `data-trfmc-p5-war-room-domain=\"mounted\"` presente.",
    "- Route `#trfmc-rf-tm-war-room-v4` mostra il componente React War Room, non solo il contract.",
    "- No iframe.",
    "- No `dangerouslySetInnerHTML`.",
    "- No `document.body`, no `appendChild`, no root secondario.",
    "- Build PASS, DOM PASS, screenshot PASS.",
]
plan.write_text("\n".join(plan_lines) + "\n", encoding="utf-8")

result = "P5A_REALITY_READY_P5B_REQUIRED"
if not route_ok:
    result = "REVIEW_ROUTE_NOT_GOVERNED"
elif real_page_ok:
    result = "P5_WAR_ROOM_ALREADY_ACTIVE"

summary_data = {
    "timestamp": Path(summary).parent.name.replace("TRFMC_P5A_RESCUE_WAR_ROOM_AUDIT_READONLY_V2_", ""),
    "operation": "TRFMC_P5A_RESCUE_WAR_ROOM_AUDIT_READONLY_V2",
    "mutation": False,
    "source_mutation": False,
    "last_incomplete_p4gc": last_p4gc or "NONE",
    "war_room_source": str(src),
    "inventory": str(inventory),
    "danger_scan": str(danger),
    "reality_check": str(reality),
    "plan": str(plan),
    "dom": str(dom_out),
    "screenshot": str(screen_out),
    "dom_status": dom_status,
    "screenshot_status": shot_status,
    "portal_os_count": portal_os_count,
    "p4g_count": p4g_count,
    "war_room_title_count": war_room_title_count,
    "v42_count": v42_count,
    "legacy_canvas_runtime_count": legacy_canvas_runtime_count,
    "real_p5_component_active": real_page_ok,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=4, ensure_ascii=False), encoding="utf-8")
PY

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p5a_rescue_war_room_audit_readonly_v2"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== REALITY CHECK ==="
column -t -s $'\t' "$REALITY"

echo
echo "=== INVENTORY ==="
column -t -s $'\t' "$INVENTORY" | sed -n '1,120p'

echo
echo "=== DANGER ==="
column -t -s $'\t' "$DANGER"

echo
echo "=== PLAN ==="
sed -n '1,220p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P5A_RESCUE_WAR_ROOM_AUDIT_READONLY_V2 COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
