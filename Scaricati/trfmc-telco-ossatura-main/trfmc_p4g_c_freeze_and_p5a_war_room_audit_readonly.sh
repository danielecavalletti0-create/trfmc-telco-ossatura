#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_P4G_C_FREEZE_AND_P5A_WAR_ROOM_AUDIT_READONLY_$TS"
FREEZE="$BASE/_archive/baselines/BASELINE_P4G_B_ROUTE_REGISTRY_RUNTIME_PASS_$TS"

mkdir -p "$OUT" "$FREEZE"
cd "$BASE"

P4G_LATEST="runtime/quality/latest_p4g_b_runtime_route_reprobe_after_vite_recovery"
P4G_SUMMARY="$P4G_LATEST/summary.json"

WAR_ROOM_SRC="frontend/public/trfmc_rf_tm_war_room_v4.html"
SUMMARY="$OUT/summary.json"
BUILDLOG="$OUT/npm_build_p5a_war_room_audit.log"
INVENTORY="$OUT/war_room_static_inventory.tsv"
DANGER="$OUT/war_room_danger_scan.tsv"
PLAN="$OUT/P5A_WAR_ROOM_REACT_PROMOTION_PLAN.md"
DOM="$OUT/dom_war_room_route_current.txt"
SCREEN="$OUT/war_room_route_current_1920x1080.png"
DOMERR="$OUT/chrome_dom.stderr.log"
SCREENERR="$OUT/chrome_screenshot.stderr.log"

echo "============================================================"
echo "TRFMC_P4G_C_FREEZE_AND_P5A_WAR_ROOM_AUDIT_READONLY"
echo "Freeze route registry PASS + audit War Room legacy source"
echo "Timestamp: $TS"
echo "============================================================"

if [ ! -f "$P4G_SUMMARY" ]; then
  echo "ERRORE: summary P4G-B non trovato: $P4G_SUMMARY"
  exit 1
fi

P4G_RESULT="$(python3 - "$P4G_SUMMARY" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["result"])
PY
)"

P4G_ROUTE_FAILS="$(python3 - "$P4G_SUMMARY" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("route_fails", -1))
PY
)"

echo "P4G_RESULT=$P4G_RESULT"
echo "P4G_ROUTE_FAILS=$P4G_ROUTE_FAILS"

if [ "$P4G_RESULT" != "PASS" ] || [ "$P4G_ROUTE_FAILS" != "0" ]; then
  echo "ERRORE: P4G-B non è PASS pulito. Non procedo."
  exit 1
fi

if [ ! -f "$WAR_ROOM_SRC" ]; then
  echo "ERRORE: sorgente War Room non trovato: $WAR_ROOM_SRC"
  echo "Cerco candidati:"
  find frontend/public -maxdepth 1 -type f -iname '*war*room*.html' -print
  exit 1
fi

echo
echo "=== 1) FREEZE BASELINE P4G-B ==="

mkdir -p "$FREEZE"/{src_app,src_portal_os,src_layout,quality,public_refs}

cp -a frontend/src/app "$FREEZE/src_app/"
cp -a frontend/src/portal-os "$FREEZE/src_portal_os/"
cp -a frontend/src/layout_orchestrator "$FREEZE/src_layout/"
cp -a frontend/src/styles.css "$FREEZE/styles.css" 2>/dev/null || true
cp -a "$WAR_ROOM_SRC" "$FREEZE/public_refs/"
cp -a "$P4G_LATEST" "$FREEZE/quality/p4g_b_runtime_route_reprobe"

cat > "$FREEZE/BASELINE_README.md" <<FREEZE_EOF
# BASELINE P4G-B ROUTE REGISTRY RUNTIME PASS

Timestamp: $TS

Status:
- Vite 5173 alive.
- P4G-B route registry runtime reprobe PASS.
- Route pass: 10
- Route fails: 0
- Portal OS count: 1
- P4G registry count: 1
- V42 leak: 0
- War Room route verified: #trfmc-rf-tm-war-room-v4

Frozen before P5A War Room React promotion audit.
FREEZE_EOF

echo "Freeze: $FREEZE"

echo
echo "=== 2) BUILD SAFETY CURRENT SOURCE ==="

BUILD_RESULT="PASS"
(
  cd frontend
  npm run build
) > "$BUILDLOG" 2>&1 || BUILD_RESULT="FAIL"

tail -n 60 "$BUILDLOG" || true

echo
echo "=== 3) WAR ROOM SOURCE INVENTORY ==="

python3 - "$WAR_ROOM_SRC" "$INVENTORY" "$DANGER" "$PLAN" <<'PY'
import hashlib
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
inventory = Path(sys.argv[2])
danger = Path(sys.argv[3])
plan = Path(sys.argv[4])

text = src.read_text(encoding="utf-8", errors="replace")
lower = text.lower()
lines = text.splitlines()

def count(pattern, flags=re.I):
    return len(re.findall(pattern, text, flags))

sha = hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()

metrics = {
    "path": str(src),
    "bytes": len(text.encode("utf-8")),
    "lines": len(lines),
    "sha256": sha,
    "title_tags": count(r"<title\b"),
    "script_tags": count(r"<script\b"),
    "style_tags": count(r"<style\b"),
    "link_tags": count(r"<link\b"),
    "canvas_tags": count(r"<canvas\b"),
    "svg_tags": count(r"<svg\b"),
    "section_tags": count(r"<section\b"),
    "button_tags": count(r"<button\b"),
    "anchor_tags": count(r"<a\b"),
    "div_tags": count(r"<div\b"),
    "form_tags": count(r"<form\b"),
    "iframe_tags": count(r"<iframe\b"),
    "video_tags": count(r"<video\b"),
    "webgl_hits": count(r"webgl|three\.|threejs|babylon|canvas.getcontext\(['\"]webgl"),
    "rf_hits": count(r"\brf\b|radio frequency|spectrum|sinr|rsrp|rsrq|antenna|iq|fft|waterfall|evm|ofdm|qam|gnb|ueransim|open5gs|ngap|pfcp|gtp"),
    "css_var_hits": count(r"--[a-z0-9_-]+\s*:"),
    "data_marker_hits": count(r"data-trfmc|data-"),
    "external_http_refs": count(r"https?://"),
    "cdn_refs": count(r"cdn\.|unpkg|jsdelivr|cdnjs|googleapis|gstatic"),
    "inline_event_handlers": count(r"\son[a-z]+\s*="),
    "dangerous_dom_hits": count(r"innerHTML|outerHTML|document\.write|insertAdjacentHTML|eval\(|new Function"),
    "local_storage_hits": count(r"localStorage|sessionStorage"),
}

with inventory.open("w", encoding="utf-8") as f:
    f.write("metric\tvalue\n")
    for k, v in metrics.items():
        f.write(f"{k}\t{v}\n")

danger_patterns = [
    ("iframe", r"<iframe\b"),
    ("dangerous_dom", r"innerHTML|outerHTML|document\.write|insertAdjacentHTML|eval\(|new Function"),
    ("inline_event_handler", r"\son[a-z]+\s*="),
    ("external_url", r"https?://"),
    ("cdn", r"cdn\.|unpkg|jsdelivr|cdnjs|googleapis|gstatic"),
    ("local_storage", r"localStorage|sessionStorage"),
    ("absolute_public_link", r"frontend/public|\.html"),
]

with danger.open("w", encoding="utf-8") as f:
    f.write("risk\tcount\tfirst_line\tfirst_match\n")
    for risk, pat in danger_patterns:
        matches = []
        for idx, line in enumerate(lines, 1):
            if re.search(pat, line, re.I):
                matches.append((idx, line.strip()[:180]))
        first_line = matches[0][0] if matches else "-"
        first_match = matches[0][1].replace("\t", " ") if matches else "-"
        f.write(f"{risk}\t{len(matches)}\t{first_line}\t{first_match}\n")

# Estrazione titoli/etichette probabili
titles = []
for pat in [r"<h1[^>]*>(.*?)</h1>", r"<h2[^>]*>(.*?)</h2>", r"<h3[^>]*>(.*?)</h3>", r"<title[^>]*>(.*?)</title>"]:
    for m in re.findall(pat, text, re.I | re.S):
        clean = re.sub(r"<[^>]+>", "", m)
        clean = re.sub(r"\s+", " ", clean).strip()
        if clean and clean not in titles:
            titles.append(clean)

plan_lines = []
plan_lines.append("# P5A War Room React Promotion Plan")
plan_lines.append("")
plan_lines.append("## Esito audit")
plan_lines.append("")
plan_lines.append(f"- Source: `{src}`")
plan_lines.append(f"- Lines: {metrics['lines']}")
plan_lines.append(f"- Bytes: {metrics['bytes']}")
plan_lines.append(f"- SHA256: `{sha}`")
plan_lines.append(f"- Canvas tags: {metrics['canvas_tags']}")
plan_lines.append(f"- Script tags: {metrics['script_tags']}")
plan_lines.append(f"- Style tags: {metrics['style_tags']}")
plan_lines.append(f"- RF/Telco keyword hits: {metrics['rf_hits']}")
plan_lines.append(f"- Dangerous DOM hits: {metrics['dangerous_dom_hits']}")
plan_lines.append(f"- Iframe tags: {metrics['iframe_tags']}")
plan_lines.append(f"- External HTTP refs: {metrics['external_http_refs']}")
plan_lines.append("")
plan_lines.append("## Principio di promozione")
plan_lines.append("")
plan_lines.append("La War Room non deve essere montata come HTML legacy, iframe o innerHTML. Deve diventare un componente React nativo governato dal Portal OS.")
plan_lines.append("")
plan_lines.append("## Moduli React target")
plan_lines.append("")
plan_lines.append("- `frontend/src/domains/war-room/WarRoomDomainP5.tsx`")
plan_lines.append("- `frontend/src/domains/war-room/warRoomRegistry.ts`")
plan_lines.append("- `frontend/src/domains/war-room/WarRoomEvidencePanelP5.tsx`")
plan_lines.append("- `frontend/src/domains/war-room/WarRoomScenarioMatrixP5.tsx`")
plan_lines.append("- `frontend/src/domains/war-room/WarRoomRfTelcoTimelineP5.tsx`")
plan_lines.append("")
plan_lines.append("## Contenuti da ricostruire")
plan_lines.append("")
plan_lines.append("- Active mission viewport")
plan_lines.append("- RF/TM event stream")
plan_lines.append("- Evidence/QA matrix")
plan_lines.append("- Core/RAN link to Open5GS/UERANSIM")
plan_lines.append("- RF signal/instrument readiness")
plan_lines.append("- Scenario cards e risk policy")
plan_lines.append("")
plan_lines.append("## Titoli rilevati")
plan_lines.append("")
for t in titles[:25]:
    plan_lines.append(f"- {t}")
plan_lines.append("")
plan_lines.append("## Gate obbligatori per P5B")
plan_lines.append("")
plan_lines.append("- build PASS")
plan_lines.append("- HTTP PASS")
plan_lines.append("- static safety PASS")
plan_lines.append("- DOM marker `data-trfmc-p5-war-room-domain=\"mounted\"`")
plan_lines.append("- route `#trfmc-rf-tm-war-room-v4` renderizzata da React nativo")
plan_lines.append("- no iframe")
plan_lines.append("- no dangerous DOM")
plan_lines.append("- no public HTML runtime mount")
plan_lines.append("- screenshot PASS")

plan.write_text("\n".join(plan_lines) + "\n", encoding="utf-8")
PY

column -t -s $'\t' "$INVENTORY" | sed -n '1,120p'

echo
echo "=== 4) DANGER SCAN ==="
column -t -s $'\t' "$DANGER" | sed -n '1,80p'

echo
echo "=== 5) DOM ROUTE CURRENT ==="

DOM_RESULT="SKIPPED"
SCREENSHOT_RESULT="SKIPPED"

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
else
  CHROME_BIN=""
fi

if [ "$BUILD_RESULT" = "PASS" ] && [ -n "$CHROME_BIN" ]; then
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --dump-dom \
    "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4" > "$DOM" 2> "$DOMERR" && DOM_RESULT="PASS" || DOM_RESULT="FAIL"

  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --window-size=1920,1080 \
    --virtual-time-budget=9000 \
    --screenshot="$SCREEN" \
    "http://127.0.0.1:5173/#trfmc-rf-tm-war-room-v4" >/dev/null 2> "$SCREENERR" && SCREENSHOT_RESULT="PASS" || SCREENSHOT_RESULT="FAIL"
else
  echo "NO_CHROME_OR_BUILD_FAIL" > "$DOM"
fi

PORTAL_OS_COUNT="$(grep -o 'data-trfmc-portal-os-preview="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
P4G_COUNT="$(grep -o 'data-trfmc-p4g-route-registry="mounted"' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
WAR_ROOM_COUNT="$(grep -o 'TRFMC RF/TM War Room V4' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"
V42_COUNT="$(grep -o 'TELCO RF MISSION CONTROL PLATFORM' "$DOM" 2>/dev/null | wc -l | tr -d ' ')"

echo "DOM_RESULT=$DOM_RESULT"
echo "PORTAL_OS_COUNT=$PORTAL_OS_COUNT"
echo "P4G_COUNT=$P4G_COUNT"
echo "WAR_ROOM_COUNT=$WAR_ROOM_COUNT"
echo "V42_COUNT=$V42_COUNT"
echo "SCREENSHOT_RESULT=$SCREENSHOT_RESULT"

RESULT="P5A_WAR_ROOM_AUDIT_READY"
if [ "$BUILD_RESULT" != "PASS" ]; then RESULT="REVIEW_BUILD"; fi
if [ "$DOM_RESULT" != "PASS" ]; then RESULT="REVIEW_DOM"; fi
if [ "$PORTAL_OS_COUNT" = "0" ]; then RESULT="REVIEW_PORTAL_OS_ROUTE"; fi
if [ "$P4G_COUNT" = "0" ]; then RESULT="REVIEW_P4G_ROUTE"; fi
if [ "$WAR_ROOM_COUNT" = "0" ]; then RESULT="REVIEW_WAR_ROOM_ROUTE"; fi
if [ "$V42_COUNT" != "0" ]; then RESULT="REVIEW_V42_LEAK"; fi

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_P4G_C_FREEZE_AND_P5A_WAR_ROOM_AUDIT_READONLY",
  "mutation": false,
  "source_mutation": false,
  "freeze": "$FREEZE",
  "p4g_summary": "$P4G_SUMMARY",
  "war_room_source": "$WAR_ROOM_SRC",
  "inventory": "$INVENTORY",
  "danger_scan": "$DANGER",
  "plan": "$PLAN",
  "build_log": "$BUILDLOG",
  "dom": "$DOM",
  "screenshot": "$SCREEN",
  "build_result": "$BUILD_RESULT",
  "dom_result": "$DOM_RESULT",
  "portal_os_count": $PORTAL_OS_COUNT,
  "p4g_count": $P4G_COUNT,
  "war_room_count": $WAR_ROOM_COUNT,
  "v42_count": $V42_COUNT,
  "screenshot_result": "$SCREENSHOT_RESULT",
  "result": "$RESULT"
}
JSON

ln -sfn "$OUT" "$BASE/runtime/quality/latest_p4g_c_freeze_and_p5a_war_room_audit_readonly"

echo
echo "=== SUMMARY ==="
python3 -m json.tool "$SUMMARY"

echo
echo "=== PLAN ==="
sed -n '1,220p' "$PLAN"

echo
echo "============================================================"
echo "TRFMC_P4G_C_FREEZE_AND_P5A_WAR_ROOM_AUDIT_READONLY COMPLETATO"
echo "Output: $OUT"
echo "============================================================"
