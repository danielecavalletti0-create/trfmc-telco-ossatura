from fastapi import APIRouter
from pathlib import Path
from datetime import datetime, timezone
import os
import subprocess
import re

router = APIRouter(prefix="/api/core-live", tags=["TRFMC Core Live"])

# TRFMC_BASE deve puntare all'installazione locale di un laboratorio 5G
# esterno (open5gs/UERANSIM), se presente. Nessun default hardcoded: se non
# configurato, questo modulo riporta onestamente "non configurato" invece di
# puntare silenziosamente al path di una macchina di sviluppo altrui.
_base_env = os.environ.get("TRFMC_BASE")
BASE = Path(_base_env) if _base_env else None
RUNTIME = Path(os.environ.get("TRFMC_RUNTIME", str(BASE / "runtime"))) if BASE else None


def run(args: list[str], timeout: int = 4) -> dict:
    """Esegue un comando esterno con argomenti espliciti (mai shell=True:
    nessuna interpolazione di stringhe puo' raggiungere una shell)."""
    try:
        r = subprocess.run(
            args,
            shell=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        return {"ok": r.returncode == 0, "code": r.returncode, "stdout": r.stdout.strip(), "stderr": r.stderr.strip()}
    except FileNotFoundError as e:
        return {"ok": False, "code": -1, "stdout": "", "stderr": f"comando non trovato: {e}"}
    except Exception as e:
        return {"ok": False, "code": -1, "stdout": "", "stderr": str(e)}


def lines(txt: str) -> list[str]:
    return [x for x in txt.splitlines() if x.strip()]


def grep_lines(txt: str, pattern: str) -> list[str]:
    """Filtra righe per pattern regex, in Python invece che con 'shell | egrep'."""
    rx = re.compile(pattern)
    return [x for x in lines(txt) if rx.search(x)]


def process_probe(pattern: str) -> list[str]:
    r = run(["pgrep", "-af", pattern])
    return lines(r["stdout"])


def port_probe() -> list[str]:
    r = run(["ss", "-ltnup"])
    return grep_lines(r["stdout"], r"(:38412|:8805|:2152|:7777|:8000|:5173)")


def file_exists(path: str) -> dict:
    p = BASE / path
    return {"path": str(p), "exists": p.exists(), "size": p.stat().st_size if p.exists() and p.is_file() else None}


def read_tail(path: str, n: int = 80) -> list[str]:
    p = BASE / path
    if not p.exists():
        return []
    try:
        return p.read_text(errors="ignore").splitlines()[-n:]
    except Exception:
        return []


def cfg_extract() -> dict:
    candidates = [
        "lab/UERANSIM/config/open5gs-gnb.yaml",
        "lab/UERANSIM/config/open5gs-ue.yaml",
        "UERANSIM/config/open5gs-gnb.yaml",
        "UERANSIM/config/open5gs-ue.yaml",
    ]
    out = {}
    for c in candidates:
        p = BASE / c
        if p.exists():
            txt = p.read_text(errors="ignore")
            out[c] = {
                "exists": True,
                "linkIp": re.findall(r"linkIp:\s*'?([^'\n]+)'?", txt),
                "ngapIp": re.findall(r"ngapIp:\s*'?([^'\n]+)'?", txt),
                "gtpIp": re.findall(r"gtpIp:\s*'?([^'\n]+)'?", txt),
                "gnbSearchList": re.findall(r"gnbSearchList:\s*\n\s*-\s*'?([^'\n]+)'?", txt),
                "supi": re.findall(r"supi:\s*'?([^'\n]+)'?", txt),
                "mcc": re.findall(r"mcc:\s*'?([^'\n]+)'?", txt),
                "mnc": re.findall(r"mnc:\s*'?([^'\n]+)'?", txt),
            }
    return out


def ogstun_probe() -> dict:
    r = run(["ip", "addr", "show", "ogstun"])
    return {"present": bool(r["stdout"].strip()), "raw": lines(r["stdout"])}


def route_probe() -> list[str]:
    r = run(["ip", "route"])
    return grep_lines(r["stdout"], r"10\.45|ogstun|uesimtun|default")


def scripts_probe() -> dict:
    scripts = [
        "bin/5g-start.sh",
        "bin/5g-stop.sh",
        "bin/5g-health.sh",
        "bin/5g-capture-start.sh",
        "bin/5g-capture-stop.sh",
        "start_lab.sh",
    ]
    return {s: file_exists(s) for s in scripts}


def core_snapshot() -> dict:
    if BASE is None:
        return {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "base": None,
            "runtime": None,
            "state": "NOT_CONFIGURED",
            "score": 0,
            "score_total": 0,
            "gates": {},
            "processes": {"open5gs": [], "ueransim": []},
            "ports": [],
            "ogstun": {"present": False, "raw": []},
            "routes": [],
            "scripts": {},
            "configs": {},
            "logs": {},
            "note": (
                "TRFMC_BASE non impostata: questo modulo collega TRFMC a un "
                "laboratorio 5G esterno (open5gs/UERANSIM) opzionale. Impostare "
                "TRFMC_BASE al percorso dell'installazione per attivarlo."
            ),
        }

    open5gs = process_probe("open5gs|amfd|smfd|upfd|ausfd|udmd|nrf|scp|bsf|pcfd|nssfd")
    ueransim = process_probe("nr-gnb|nr-ue|UERANSIM")
    ports = port_probe()
    ogstun = ogstun_probe()
    scripts = scripts_probe()
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
    }

    score = sum(1 for v in gates.values() if v)
    total = len(gates)

    if gates["open5gs_process_seen"] and gates["ueransim_process_seen"] and gates["ogstun_present"]:
        state = "LIVE_ATTACHED_OR_READY"
    elif gates["open5gs_process_seen"]:
        state = "CORE_ONLY"
    elif gates["start_script_present"]:
        state = "INSTALLED_BUT_STOPPED"
    else:
        state = "DISCOVERY_REQUIRED"

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "base": str(BASE),
        "runtime": str(RUNTIME),
        "state": state,
        "score": score,
        "score_total": total,
        "gates": gates,
        "processes": {
            "open5gs": open5gs,
            "ueransim": ueransim,
        },
        "ports": ports,
        "ogstun": ogstun,
        "routes": route_probe(),
        "scripts": scripts,
        "configs": configs,
        "logs": {
            "backend_8000_tail": read_tail("runtime/logs/backend_8000.log", 60),
            "open5gs_tail": read_tail("runtime/logs/open5gs.log", 80),
            "ueransim_tail": read_tail("runtime/logs/ueransim.log", 80),
        },
    }


@router.get("/health")
def health():
    snap = core_snapshot()
    return {
        "status": "ok",
        "service": "trfmc-core-live",
        "state": snap["state"],
        "score": snap["score"],
        "score_total": snap["score_total"],
        "timestamp": snap["timestamp"],
    }


@router.get("/status")
def status():
    return core_snapshot()


@router.get("/events")
def events():
    snap = core_snapshot()
    ev = []
    for k, v in snap["gates"].items():
        ev.append({"gate": k, "status": "PASS" if v else "WARN"})
    return {"timestamp": snap["timestamp"], "events": ev, "state": snap["state"]}
