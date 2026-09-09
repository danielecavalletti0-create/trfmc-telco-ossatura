#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
BACKEND="$BASE/backend"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"

SERVER="$BACKEND/core_live_standalone_server.py"
PAGE="$PUBLIC/trfmc_core_network_live_ops_bridge_v1.html"

OUT="$BASE/runtime/quality/TRFMC_CORE_LIVE_PROBE_V2_STRICT_TRUTH_$TS"
BK="$BASE/runtime/backups/CORE_LIVE_PROBE_V2_STRICT_TRUTH_$TS"

mkdir -p "$OUT" "$BK" "$BASE/runtime/logs" "$BASE/runtime/quality" "$BASE/runtime/freezes"

echo "============================================================"
echo "TRFMC CORE LIVE PROBE V2 - STRICT TRUTH"
echo "fix false PASS pgrep · discover real Open5GS/UERANSIM · locate scripts/configs"
echo "============================================================"

http_probe() {
  local url="$1"
  local r code bytes
  r="$(curl -s -o /dev/null -w "%{response_code} %{size_download}" --max-time 5 "$url" 2>/dev/null || true)"
  code="$(echo "$r" | awk '{print $1}')"
  bytes="$(echo "$r" | awk '{print $2}')"
  [ -n "$code" ] || code="000"
  [ -n "$bytes" ] || bytes="0"
  echo -e "$url\t$code\t$bytes"
}

echo
echo "[1/8] Backup"
cp -av "$SERVER" "$BK/$(basename "$SERVER").bak"
cp -av "$PAGE" "$BK/$(basename "$PAGE").bak"

echo
echo "[2/8] Patch backend standalone: processo reale, discovery, scripts, config"
python3 - <<'PY'
from pathlib import Path
import re

server = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/backend/core_live_standalone_server.py")
s = server.read_text(errors="ignore")

old = r'''def process_probe(pattern: str):
    r = run(f"pgrep -af '{pattern}' || true")
    return lines(r["stdout"])'''

new = r'''def process_probe(pattern: str):
    """
    Probe rigoroso: non conta grep/pgrep/bash/sh/curl/python probe.
    Il precedente detector vedeva il proprio comando pgrep e produceva falsi PASS.
    """
    r = run("ps -eo pid=,comm=,args= 2>/dev/null || true")
    found = []
    rx = re.compile(pattern)
    for line in lines(r["stdout"]):
        low = line.lower()
        if any(x in low for x in [
            "pgrep -af",
            "grep ",
            "egrep ",
            "core_live_standalone_server.py",
            "uvicorn backend.core_live_standalone_server",
            "/bin/sh -c",
            "bash -lc",
        ]):
            continue
        if rx.search(line):
            found.append(line)
    return found

def find_paths(patterns, roots=None, max_hits=80):
    if roots is None:
        roots = [
            BASE,
            BASE.parent,
            Path("/home/sentinel"),
            Path("/home/sentinel/lab"),
            Path("/home/sentinel/Scaricati"),
            Path("/opt"),
            Path("/usr/local/bin"),
            Path("/usr/bin"),
            Path("/etc/open5gs"),
            Path("/var/log/open5gs"),
        ]

    hits = []
    seen = set()

    for root in roots:
        try:
            if not root.exists():
                continue
            for pat in patterns:
                for p in root.rglob(pat) if root.is_dir() and str(root) not in ["/usr/bin", "/usr/local/bin"] else root.glob(pat):
                    sp = str(p)
                    if sp in seen:
                        continue
                    seen.add(sp)
                    try:
                        st = p.stat()
                        hits.append({
                            "path": sp,
                            "name": p.name,
                            "is_file": p.is_file(),
                            "is_dir": p.is_dir(),
                            "size": st.st_size if p.is_file() else None,
                            "executable": os.access(p, os.X_OK),
                        })
                    except Exception:
                        hits.append({"path": sp, "name": p.name})
                    if len(hits) >= max_hits:
                        return hits
        except Exception:
            continue
    return hits

def discover_open5gs():
    return {
        "binaries": find_paths([
            "open5gs-amfd",
            "open5gs-smfd",
            "open5gs-upfd",
            "open5gs-ausfd",
            "open5gs-udmd",
            "open5gs-nrfd",
            "open5gs-scpd",
            "open5gs-bsfd",
            "open5gs-pcfd",
            "open5gs-nssfd",
            "open5gs-*",
        ], max_hits=120),
        "configs": find_paths(["amf.yaml", "smf.yaml", "upf.yaml", "nrf.yaml", "ausf.yaml", "udm.yaml", "*.yaml"], roots=[BASE, Path("/etc/open5gs")], max_hits=120),
        "logs": find_paths(["*.log"], roots=[BASE / "runtime", Path("/var/log/open5gs")], max_hits=120),
    }

def discover_ueransim():
    return {
        "binaries": find_paths(["nr-gnb", "nr-ue", "nr-cli"], max_hits=80),
        "configs": find_paths(["open5gs-gnb.yaml", "open5gs-ue.yaml", "*gnb*.yaml", "*ue*.yaml"], roots=[BASE, BASE.parent, Path("/home/sentinel"), Path("/home/sentinel/Scaricati")], max_hits=120),
        "logs": find_paths(["*gnb*.log", "*ue*.log", "*ueransim*.log"], roots=[BASE / "runtime", BASE, BASE.parent], max_hits=80),
    }

def discover_scripts():
    return find_paths([
        "5g-start.sh",
        "5g-stop.sh",
        "5g-health.sh",
        "5g-capture-start.sh",
        "5g-capture-stop.sh",
        "start_lab.sh",
        "status_super_portale_5g.sh",
        "*5g*.sh",
        "*open5gs*.sh",
        "*ueransim*.sh",
    ], roots=[BASE, BASE.parent, Path("/home/sentinel"), Path("/home/sentinel/Scaricati")], max_hits=160)'''

if old not in s:
    raise SystemExit("ERRORE: process_probe originale non trovato")
s = s.replace(old, new)

# Sostituisco scripts_probe per usare la discovery reale e mantenere compatibilità.
old_scripts = r'''def scripts_probe():
    scripts = [
        "bin/5g-start.sh",
        "bin/5g-stop.sh",
        "bin/5g-health.sh",
        "bin/5g-capture-start.sh",
        "bin/5g-capture-stop.sh",
        "start_lab.sh",
        "status_super_portale_5g.sh",
    ]
    return {s: file_exists(s) for s in scripts}'''

new_scripts = r'''def scripts_probe():
    expected = [
        "bin/5g-start.sh",
        "bin/5g-stop.sh",
        "bin/5g-health.sh",
        "bin/5g-capture-start.sh",
        "bin/5g-capture-stop.sh",
        "start_lab.sh",
        "status_super_portale_5g.sh",
    ]
    direct = {s: file_exists(s) for s in expected}
    discovered = discover_scripts()
    return {
        "direct": direct,
        "discovered": discovered,
        "any_start": any("5g-start.sh" in x.get("path","") or "start_lab.sh" in x.get("path","") for x in discovered),
        "any_health": any("5g-health.sh" in x.get("path","") or "status" in x.get("name","").lower() for x in discovered),
    }'''

if old_scripts not in s:
    raise SystemExit("ERRORE: scripts_probe originale non trovato")
s = s.replace(old_scripts, new_scripts)

# Aggiorno gates/scripts/config discovery.
s = s.replace(
    '''    scripts = scripts_probe()
    configs = cfg_extract()

    gates = {
        "backend_api": True,
        "open5gs_process_seen": len(open5gs) > 0,
        "ueransim_process_seen": len(ueransim) > 0,
        "ngap_38412_seen": any(":38412" in x for x in ports),
        "pfcp_8805_seen": any(":8805" in x for x in ports),
        "gtpu_2152_seen": any(":2152" in x for x in ports),
        "ogstun_present": ogstun["present"],
        "start_script_present": scripts.get("bin/5g-start.sh", {}).get("exists", False),
        "health_script_present": scripts.get("bin/5g-health.sh", {}).get("exists", False),
    }''',
    '''    scripts = scripts_probe()
    configs = cfg_extract()
    open5gs_discovery = discover_open5gs()
    ueransim_discovery = discover_ueransim()

    gates = {
        "backend_api": True,
        "open5gs_process_seen": len(open5gs) > 0,
        "ueransim_process_seen": len(ueransim) > 0,
        "ngap_38412_seen": any(":38412" in x for x in ports),
        "pfcp_8805_seen": any(":8805" in x for x in ports),
        "gtpu_2152_seen": any(":2152" in x for x in ports),
        "ogstun_present": ogstun["present"],
        "open5gs_binaries_found": len(open5gs_discovery.get("binaries", [])) > 0,
        "ueransim_binaries_found": len(ueransim_discovery.get("binaries", [])) > 0,
        "start_script_present": bool(scripts.get("any_start")),
        "health_script_present": bool(scripts.get("any_health")),
    }'''
)

s = s.replace(
    '''    if gates["open5gs_process_seen"] and gates["ueransim_process_seen"] and gates["ogstun_present"]:
        state = "LIVE_ATTACHED_OR_READY"
    elif gates["open5gs_process_seen"]:
        state = "CORE_ONLY"
    elif gates["start_script_present"]:
        state = "INSTALLED_BUT_STOPPED"
    else:
        state = "DISCOVERY_REQUIRED"''',
    '''    if gates["open5gs_process_seen"] and gates["ueransim_process_seen"] and gates["ogstun_present"] and gates["ngap_38412_seen"] and gates["gtpu_2152_seen"]:
        state = "LIVE_ATTACHED_OR_READY"
    elif gates["open5gs_process_seen"] and gates["ngap_38412_seen"]:
        state = "CORE_SIGNALING_LISTENING"
    elif gates["open5gs_process_seen"]:
        state = "CORE_PROCESS_ONLY"
    elif gates["open5gs_binaries_found"] or gates["ueransim_binaries_found"] or gates["start_script_present"]:
        state = "INSTALLED_BUT_STOPPED"
    else:
        state = "DISCOVERY_REQUIRED"'''
)

s = s.replace(
    '''        "scripts": scripts,
        "configs": configs,
        "logs": {''',
    '''        "scripts": scripts,
        "configs": configs,
        "discovery": {
            "open5gs": open5gs_discovery,
            "ueransim": ueransim_discovery,
        },
        "diagnostic_notes": [
            "V2 strict mode: pgrep self-matches are excluded",
            "PASS now means real process/port/config discovery, not probe command visibility"
        ],
        "logs": {'''
)

server.write_text(s)
print("PATCH_OK: core_live_standalone_server.py aggiornato a strict truth v2")
PY

echo
echo "[3/8] Patch pagina: KPI discovery e stato più onesto"
python3 - <<'PY'
from pathlib import Path

page = Path("/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2/frontend/public/trfmc_core_network_live_ops_bridge_v1.html")
s = page.read_text(errors="ignore")

s = s.replace(
    '<div class="sub">Open5GS · UERANSIM · NGAP · PFCP · GTP-U · ogstun · SUPI/SUCI/AKA evidence path · live operational bridge</div>',
    '<div class="sub">Open5GS · UERANSIM · NGAP · PFCP · GTP-U · ogstun · strict process truth · discovery · SUPI/SUCI/AKA evidence path</div>'
)

# Estendo output processi con discovery reale.
old = '''    $("procOut").innerHTML=
      `Open5GS processes: ${(last.processes.open5gs||[]).length}<br>`+
      `UERANSIM processes: ${(last.processes.ueransim||[]).length}<br>`+
      `Ports observed: ${(last.ports||[]).length}<br>`+
      `Routes: ${(last.routes||[]).length}<br>`;'''

new = '''    const d=last.discovery||{};
    const ogs=(d.open5gs&&d.open5gs.binaries)||[];
    const uer=(d.ueransim&&d.ueransim.binaries)||[];
    const scr=last.scripts||{};
    $("procOut").innerHTML=
      `Open5GS real processes: ${(last.processes.open5gs||[]).length}<br>`+
      `UERANSIM real processes: ${(last.processes.ueransim||[]).length}<br>`+
      `Open5GS binaries found: ${ogs.length}<br>`+
      `UERANSIM binaries found: ${uer.length}<br>`+
      `Scripts discovered: ${((scr.discovered)||[]).length}<br>`+
      `Ports observed: ${(last.ports||[]).length}<br>`+
      `Routes: ${(last.routes||[]).length}<br>`;'''

if old not in s:
    raise SystemExit("ERRORE: procOut block non trovato")
s = s.replace(old, new)

s = s.replace(
    '`Core state ${data.state} · score ${data.score}/${data.score_total} · Open5GS ${ok(gates.open5gs_process_seen)} · UERANSIM ${ok(gates.ueransim_process_seen)}`',
    '`Core state ${data.state} · score ${data.score}/${data.score_total} · OGS proc ${ok(gates.open5gs_process_seen)} · UERANSIM proc ${ok(gates.ueransim_process_seen)} · OGS bin ${ok(gates.open5gs_binaries_found)} · UERANSIM bin ${ok(gates.ueransim_binaries_found)}`'
)

page.write_text(s)
print("PATCH_OK: pagina aggiornata con discovery/probe strict")
PY

echo
echo "[4/8] Riavvio backend 8000"
PIDS="$(lsof -ti tcp:8000 2>/dev/null || true)"
if [ -n "$PIDS" ]; then
  echo "Kill porta 8000: $PIDS"
  kill $PIDS 2>/dev/null || true
  sleep 2
fi

source "$BASE/.venv/bin/activate"

nohup bash -lc "
cd '$BASE'
source .venv/bin/activate
export TRFMC_BASE='$BASE'
export TRFMC_RUNTIME='$BASE/runtime'
exec uvicorn backend.core_live_standalone_server:app --host 127.0.0.1 --port 8000
" > "$BASE/runtime/logs/backend_8000.log" 2>&1 &

sleep 5

echo
echo "[5/8] Gate HTTP + strict status"
cat > "$OUT/http.tsv" <<'EOFHTTP'
url	status	bytes
EOFHTTP

for u in \
  "http://127.0.0.1:8000/api/health" \
  "http://127.0.0.1:8000/api/core-live/health" \
  "http://127.0.0.1:8000/api/core-live/status" \
  "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html" \
  "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html"
do
  http_probe "$u" >> "$OUT/http.tsv"
done

curl -s --max-time 10 "http://127.0.0.1:8000/api/core-live/status" > "$OUT/core_live_status_v2.json" || true

grep -nEi '<iframe|http://|https://|cdn\.|unpkg|jsdelivr|cdnjs' "$PAGE" > "$OUT/page_refs.txt" 2>/dev/null || true
grep -nEi 'strict process truth|Open5GS real processes|UERANSIM real processes|binaries found|coreApiBase|fetchCore' "$PAGE" > "$OUT/page_markers.txt" 2>/dev/null || true

echo
echo "[6/8] Summary"
export OUT
python3 - <<'PY'
import json, os
from pathlib import Path
from datetime import datetime, timezone

out=Path(os.environ["OUT"])

http_non_200=0
for line in (out/"http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p=line.split("\t")
    if len(p)>=2 and p[1]!="200":
        http_non_200 += 1

page_refs=sum(1 for x in (out/"page_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
page_markers=(out/"page_markers.txt").read_text(errors="ignore")
page_ok=all(x in page_markers for x in ["strict process truth","Open5GS real processes","UERANSIM real processes","binaries found"])

status_ok=False
state="UNKNOWN"
score=0
score_total=0
false_positive_fixed=False
open5gs_proc_count=0
ueransim_proc_count=0
open5gs_bin_count=0
ueransim_bin_count=0
script_count=0

try:
    st=json.loads((out/"core_live_status_v2.json").read_text(errors="ignore"))
    status_ok=st.get("service")=="trfmc-core-live-standalone"
    state=st.get("state","UNKNOWN")
    score=st.get("score",0)
    score_total=st.get("score_total",0)

    open5gs_proc=st.get("processes",{}).get("open5gs",[])
    uer_proc=st.get("processes",{}).get("ueransim",[])
    open5gs_proc_count=len(open5gs_proc)
    ueransim_proc_count=len(uer_proc)

    text=json.dumps(st)
    false_positive_fixed=("pgrep -af" not in text and "/bin/sh -c" not in text)

    open5gs_bin_count=len(st.get("discovery",{}).get("open5gs",{}).get("binaries",[]))
    ueransim_bin_count=len(st.get("discovery",{}).get("ueransim",{}).get("binaries",[]))
    script_count=len(st.get("scripts",{}).get("discovered",[]))
except Exception:
    pass

data={
  "timestamp": datetime.now(timezone.utc).isoformat(),
  "page": "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html",
  "api": "http://127.0.0.1:8000/api/core-live/status",
  "http_non_200": http_non_200,
  "page_refs_count": page_refs,
  "page_markers_ok": page_ok,
  "core_live_status_ok": status_ok,
  "false_positive_pgrep_fixed": false_positive_fixed,
  "core_state": state,
  "score": score,
  "score_total": score_total,
  "open5gs_real_processes": open5gs_proc_count,
  "ueransim_real_processes": ueransim_proc_count,
  "open5gs_binaries_found": open5gs_bin_count,
  "ueransim_binaries_found": ueransim_bin_count,
  "scripts_discovered": script_count,
  "result": "PASS" if http_non_200==0 and page_refs==0 and page_ok and status_ok and false_positive_fixed else "WARN"
}

(out/"summary.json").write_text(json.dumps(data,indent=4)+"\n")
(out/"result.flag").write_text(data["result"]+"\n")
print(json.dumps(data,indent=4))
PY

ln -sfn "$(basename "$OUT")" "$BASE/runtime/quality/latest_core_live_probe_v2_strict_truth"

echo
echo "[7/8] Report"
cat "$OUT/summary.json" | python3 -m json.tool

echo
echo "=== HTTP ==="
column -t -s $'\t' "$OUT/http.tsv"

echo
echo "=== CORE LIVE STATUS V2 ==="
cat "$OUT/core_live_status_v2.json" | python3 -m json.tool || cat "$OUT/core_live_status_v2.json"

echo
echo "=== PAGE REFS ==="
cat "$OUT/page_refs.txt"

echo
echo "=== BACKEND LOG ==="
tail -n 80 "$BASE/runtime/logs/backend_8000.log" || true

echo
echo "[8/8] Freeze solo se PASS"
if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_PORTAL_PASS_CORE_LIVE_PROBE_V2_STRICT_TRUTH_$TS.tar.gz"

  tar -czf "$FREEZE" \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='.venv' \
    --exclude='runtime/freezes' \
    --exclude='runtime/collaudo' \
    -C "$BASE" .

  echo
  echo "=== FREEZE CREATO ==="
  ls -lh "$FREEZE"
fi

echo
echo "============================================================"
echo "APRI:"
echo "http://127.0.0.1:5173/trfmc_core_network_live_ops_bridge_v1.html"
echo
echo "API:"
echo "http://127.0.0.1:8000/api/core-live/status"
echo "============================================================"
