from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
from datetime import datetime, timezone
import subprocess
import os
import re
import shutil
import time

BASE = Path(os.environ.get("TRFMC_BASE", "/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2")).resolve()
RUNTIME = Path(os.environ.get("TRFMC_RUNTIME", str(BASE / "runtime"))).resolve()

app = FastAPI(title="TRFMC Core Live Standalone Backend", version="3.0-bounded-probe")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5173",
        "http://localhost:5173",
        "http://127.0.0.1:8080",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

CACHE = {
    "ts": 0.0,
    "data": None,
}

def now_iso():
    return datetime.now(timezone.utc).isoformat()

def run(cmd: str, timeout: float = 2.0):
    try:
        r = subprocess.run(
            cmd,
            shell=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        return {
            "ok": r.returncode == 0,
            "code": r.returncode,
            "stdout": r.stdout.strip(),
            "stderr": r.stderr.strip(),
            "timeout": False,
        }
    except subprocess.TimeoutExpired:
        return {"ok": False, "code": -2, "stdout": "", "stderr": f"TIMEOUT after {timeout}s: {cmd}", "timeout": True}
    except Exception as e:
        return {"ok": False, "code": -1, "stdout": "", "stderr": str(e), "timeout": False}

def lines(txt: str):
    return [x for x in txt.splitlines() if x.strip()]

def process_probe(kind: str):
    """
    Strict truth:
    - usa ps, non pgrep -af;
    - esclude uvicorn/backend/bash/grep/pgrep;
    - accetta solo nomi processo/binari coerenti.
    """
    r = run("ps -eo pid=,comm=,args= 2>/dev/null || true", timeout=1.5)
    found = []

    if kind == "open5gs":
        rx = re.compile(r"(^|[/\s])(open5gs-(amfd|smfd|upfd|ausfd|udmd|nrfd|scp[d]?|bsfd|pcfd|nssfd|mmed|sgwcd|sgwud|hssd|pcrfd))(\s|$)")
    elif kind == "ueransim":
        rx = re.compile(r"(^|[/\s])(nr-gnb|nr-ue|nr-cli)(\s|$)")
    else:
        rx = re.compile(r"$^")

    for line in lines(r["stdout"]):
        low = line.lower()
        if any(x in low for x in [
            "grep ",
            "egrep ",
            "pgrep ",
            "core_live_standalone_server",
            "uvicorn ",
            "backend.core_live",
            "/bin/sh -c",
            "bash -lc",
            "python ",
        ]):
            continue
        if rx.search(line):
            found.append(line)
    return found

def check_command(name):
    p = shutil.which(name)
    if not p:
        return None
    pp = Path(p)
    return {
        "path": str(pp),
        "name": pp.name,
        "exists": True,
        "executable": os.access(pp, os.X_OK),
        "source": "PATH",
    }

def direct_file(path: Path):
    try:
        return {
            "path": str(path),
            "name": path.name,
            "exists": path.exists(),
            "is_file": path.is_file(),
            "is_dir": path.is_dir(),
            "size": path.stat().st_size if path.exists() and path.is_file() else None,
            "executable": os.access(path, os.X_OK) if path.exists() else False,
        }
    except Exception as e:
        return {"path": str(path), "name": path.name, "exists": False, "error": str(e)}

def unique(items):
    out = []
    seen = set()
    for item in items:
        if not item:
            continue
        p = item.get("path")
        if not p or p in seen:
            continue
        seen.add(p)
        out.append(item)
    return out

def bounded_find(root: Path, patterns, maxdepth=7, max_hits=40, timeout=2.0):
    """
    Discovery controllata:
    - maxdepth;
    - timeout;
    - niente scansione illimitata;
    - non blocca l'API live.
    """
    if not root.exists() or not root.is_dir():
        return []

    expr_parts = []
    for pat in patterns:
        expr_parts.append(f"-iname '{pat}'")
    expr = " -o ".join(expr_parts)

    cmd = f"find '{root}' -maxdepth {maxdepth} \\( {expr} \\) -print 2>/dev/null | head -n {max_hits}"
    r = run(cmd, timeout=timeout)
    hits = []
    for line in lines(r["stdout"]):
        hits.append(direct_file(Path(line)))
    return hits

def discover_binaries():
    open5gs_names = [
        "open5gs-amfd", "open5gs-smfd", "open5gs-upfd", "open5gs-ausfd",
        "open5gs-udmd", "open5gs-nrfd", "open5gs-scpd", "open5gs-bsfd",
        "open5gs-pcfd", "open5gs-nssfd", "open5gs-mmed", "open5gs-sgwcd",
        "open5gs-sgwud", "open5gs-hssd", "open5gs-pcrfd",
    ]
    uer_names = ["nr-gnb", "nr-ue", "nr-cli"]

    ogs = [check_command(x) for x in open5gs_names]
    uer = [check_command(x) for x in uer_names]

    likely_roots = [
        BASE / "lab",
        BASE / "open5gs",
        BASE / "UERANSIM",
        BASE.parent / "lab",
        Path("/home/sentinel/lab"),
        Path("/home/sentinel/Scaricati"),
    ]

    for root in likely_roots:
        ogs += bounded_find(root, ["open5gs-*"], maxdepth=8, max_hits=60, timeout=1.8)
        uer += bounded_find(root, ["nr-gnb", "nr-ue", "nr-cli"], maxdepth=8, max_hits=30, timeout=1.8)

    return {
        "open5gs": unique(ogs),
        "ueransim": unique(uer),
    }

def discover_scripts():
    patterns = [
        "5g-start.sh", "5g-stop.sh", "5g-health.sh",
        "5g-capture-start.sh", "5g-capture-stop.sh",
        "start_lab.sh", "status_super_portale_5g.sh",
        "*5g*.sh", "*open5gs*.sh", "*ueransim*.sh",
    ]

    hits = []
    for root in [BASE, BASE.parent, Path("/home/sentinel/Scaricati"), Path("/home/sentinel/lab")]:
        hits += bounded_find(root, patterns, maxdepth=7, max_hits=80, timeout=2.0)

    hits = unique(hits)
    return {
        "discovered": hits,
        "any_start": any(("5g-start.sh" in x.get("name","")) or ("start_lab.sh" in x.get("name","")) for x in hits),
        "any_health": any(("5g-health.sh" in x.get("name","")) or ("status" in x.get("name","").lower()) for x in hits),
    }

def cfg_extract():
    hits = []
    for root in [BASE, BASE.parent, Path("/home/sentinel/Scaricati"), Path("/home/sentinel/lab"), Path("/etc/open5gs")]:
        hits += bounded_find(root, ["open5gs-gnb.yaml", "open5gs-ue.yaml", "amf.yaml", "smf.yaml", "upf.yaml", "*gnb*.yaml", "*ue*.yaml"], maxdepth=8, max_hits=80, timeout=2.0)

    out = {}
    for h in unique(hits):
        p = Path(h["path"])
        if not p.exists() or not p.is_file():
            continue
        try:
            txt = p.read_text(errors="ignore")
        except Exception:
            continue
        out[str(p)] = {
            "exists": True,
            "size": p.stat().st_size,
            "linkIp": re.findall(r"linkIp:\s*'?([^'\n]+)'?", txt),
            "ngapIp": re.findall(r"ngapIp:\s*'?([^'\n]+)'?", txt),
            "gtpIp": re.findall(r"gtpIp:\s*'?([^'\n]+)'?", txt),
            "gnbSearchList": re.findall(r"gnbSearchList:\s*\n\s*-\s*'?([^'\n]+)'?", txt),
            "supi": re.findall(r"supi:\s*'?([^'\n]+)'?", txt),
            "mcc": re.findall(r"mcc:\s*'?([^'\n]+)'?", txt),
            "mnc": re.findall(r"mnc:\s*'?([^'\n]+)'?", txt),
        }
    return out

def port_probe():
    r = run("ss -ltnup 2>/dev/null | egrep '(:38412|:8805|:2152|:7777|:8000|:5173)' || true", timeout=1.5)
    return lines(r["stdout"])

def ogstun_probe():
    r = run("ip addr show ogstun 2>/dev/null || true", timeout=1.2)
    return {"present": bool(r["stdout"].strip()), "raw": lines(r["stdout"])}

def route_probe():
    r = run("ip route 2>/dev/null | egrep '10\\.45|ogstun|uesimtun|default' || true", timeout=1.2)
    return lines(r["stdout"])

def read_tail(rel, n=60):
    p = BASE / rel
    if not p.exists():
        return []
    try:
        return p.read_text(errors="ignore").splitlines()[-n:]
    except Exception as e:
        return [f"READ_ERROR: {e}"]

def snapshot(force=False):
    now = time.time()
    if not force and CACHE["data"] is not None and now - CACHE["ts"] < 4.0:
        return CACHE["data"]

    started = time.time()

    open5gs_proc = process_probe("open5gs")
    uer_proc = process_probe("ueransim")
    ports = port_probe()
    ogstun = ogstun_probe()
    routes = route_probe()

    binaries = discover_binaries()
    scripts = discover_scripts()
    configs = cfg_extract()

    gates = {
        "backend_api": True,
        "open5gs_process_seen": len(open5gs_proc) > 0,
        "ueransim_process_seen": len(uer_proc) > 0,
        "ngap_38412_seen": any(":38412" in x for x in ports),
        "pfcp_8805_seen": any(":8805" in x for x in ports),
        "gtpu_2152_seen": any(":2152" in x for x in ports),
        "ogstun_present": ogstun["present"],
        "open5gs_binaries_found": len(binaries["open5gs"]) > 0,
        "ueransim_binaries_found": len(binaries["ueransim"]) > 0,
        "start_script_present": bool(scripts["any_start"]),
        "health_script_present": bool(scripts["any_health"]),
        "configs_found": len(configs) > 0,
    }

    score = sum(1 for v in gates.values() if v)
    total = len(gates)

    if gates["open5gs_process_seen"] and gates["ueransim_process_seen"] and gates["ogstun_present"] and gates["ngap_38412_seen"] and gates["gtpu_2152_seen"]:
        state = "LIVE_ATTACHED_OR_READY"
    elif gates["open5gs_process_seen"] and gates["ngap_38412_seen"]:
        state = "CORE_SIGNALING_LISTENING"
    elif gates["open5gs_process_seen"]:
        state = "CORE_PROCESS_ONLY"
    elif gates["open5gs_binaries_found"] or gates["ueransim_binaries_found"] or gates["start_script_present"] or gates["configs_found"]:
        state = "INSTALLED_BUT_STOPPED"
    else:
        state = "DISCOVERY_REQUIRED"

    data = {
        "timestamp": now_iso(),
        "service": "trfmc-core-live-standalone",
        "version": "3.0-bounded-probe",
        "base": str(BASE),
        "runtime": str(RUNTIME),
        "state": state,
        "score": score,
        "score_total": total,
        "elapsed_ms": int((time.time() - started) * 1000),
        "gates": gates,
        "processes": {
            "open5gs": open5gs_proc,
            "ueransim": uer_proc,
        },
        "ports": ports,
        "ogstun": ogstun,
        "routes": routes,
        "scripts": scripts,
        "configs": configs,
        "discovery": {
            "open5gs": {"binaries": binaries["open5gs"]},
            "ueransim": {"binaries": binaries["ueransim"]},
        },
        "diagnostic_notes": [
            "V3 bounded probe: no unbounded rglob in request path",
            "Strict process truth: grep/pgrep/bash/uvicorn self-matches excluded",
            "Health endpoint is lightweight and does not execute full discovery",
        ],
        "logs": {
            "backend_8000_tail": read_tail("runtime/logs/backend_8000.log", 40),
            "open5gs_tail": read_tail("runtime/logs/open5gs.log", 60),
            "ueransim_tail": read_tail("runtime/logs/ueransim.log", 60),
        },
    }

    CACHE["ts"] = now
    CACHE["data"] = data
    return data

@app.get("/api/health")
def api_health():
    return {
        "status": "ok",
        "service": "trfmc-core-live-standalone",
        "version": "3.0-bounded-probe",
        "port": 8000,
        "timestamp": now_iso(),
    }

@app.get("/api/trfmc-backend-ready")
def backend_ready():
    return {
        "status": "ok",
        "service": "trfmc-backend",
        "mode": "standalone-core-live-v3-bounded",
        "core_live": True,
        "timestamp": now_iso(),
    }

@app.get("/api/core-live/health")
def core_live_health():
    return {
        "status": "ok",
        "service": "trfmc-core-live",
        "version": "3.0-bounded-probe",
        "message": "lightweight health endpoint; use /api/core-live/status for bounded discovery",
        "timestamp": now_iso(),
    }

@app.get("/api/core-live/status")
def core_live_status():
    return snapshot(force=False)

@app.get("/api/core-live/events")
def core_live_events():
    snap = snapshot(force=False)
    events = []
    for k, v in snap["gates"].items():
        events.append({"gate": k, "status": "PASS" if v else "WARN"})
    return {"timestamp": snap["timestamp"], "state": snap["state"], "events": events}
