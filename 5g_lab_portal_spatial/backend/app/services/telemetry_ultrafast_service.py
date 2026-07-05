from __future__ import annotations

import math
import re
import time
from pathlib import Path
from typing import Any

from app.services.rf_source_provider import select_rf_provider
from app.services.instrument_source_provider import select_instrument_provider

OPEN5GS_LOG_DIR = Path.home() / "lab/open5gs-d12-curl77/install/var/log/open5gs"

NF_FILES = {
    "amf": "amf.log",
    "smf": "smf.log",
    "upf": "upf.log",
    "ausf": "ausf.log",
    "udm": "udm.log",
    "udr": "udr.log",
    "nrf": "nrf.log",
    "pcf": "pcf.log",
}

POSITIVE_TOKENS = {
    "amf": [
        "Registration complete",
        "InitialUEMessage",
        "Number of AMF-Sessions is now",
        "Configuration update command",
        "Setup NF EndPoint",
        "NF registered",
    ],
    "smf": [
        "Number of SMF-Sessions is now",
        "UE SUPI",
        "gtp_connect",
        "Setup NF EndPoint",
        "NF registered",
    ],
    "upf": [
        "PFCP associated",
        "Number of UPF-Sessions is now",
        "UE F-SEID",
        "gtp_connect",
        "UPF initialize...done",
    ],
    "ausf": [
        "AUSF initialize...done",
        "NF registered",
        "Setup NF EndPoint",
        "nausf-auth",
    ],
    "udm": [
        "UDM initialize...done",
        "NF registered",
        "Setup NF EndPoint",
        "nudm-ueau",
        "nudm-sdm",
    ],
    "udr": [
        "UDR initialize...done",
        "NF registered",
        "Setup NF EndPoint",
        "nudr-dr",
    ],
    "nrf": [
        "NRF initialize...done",
        "NF registered",
        "NF Profile updated",
        "Subscription created",
    ],
    "pcf": [
        "PCF initialize...done",
        "NF registered",
        "Setup NF EndPoint",
        "npcf-smpolicycontrol",
    ],
}

ATTENTION_TOKENS = [
    "ERROR",
    "FATAL",
    "failed",
    "Registration reject",
    "Cannot receive SBI message",
    "SBI transaction has already been removed",
]

BENIGN_STOP_TOKENS = [
    "epoll failed (4:Interrupted system call)",
    "SIGTERM received",
    "daemon terminating",
    "NF de-registered",
]


def tail_file_fast(path: Path, lines: int = 80, max_bytes: int = 65536) -> list[str]:
    if not path.exists() or not path.is_file():
        return []

    try:
        with path.open("rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - max_bytes))
            data = f.read(max_bytes)

        return data.decode("utf-8", errors="replace").splitlines()[-lines:]
    except Exception as exc:
        return [f"[read-error] {path}: {exc}"]


def extract_log_time(line: str) -> str | None:
    m = re.search(r"(\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})", line)
    return m.group(1) if m else None


def last_matching(lines: list[str], tokens: list[str]) -> dict[str, Any] | None:
    tokens_l = [x.lower() for x in tokens]
    for idx in range(len(lines) - 1, -1, -1):
        low = lines[idx].lower()
        if any(t.lower() in low for t in tokens_l):
            return {
                "index": idx,
                "time": extract_log_time(lines[idx]),
                "line": lines[idx],
            }
    return None


def count_tokens(lines: list[str], tokens: list[str]) -> int:
    tokens_l = [x.lower() for x in tokens]
    total = 0

    for line in lines:
        low = line.lower()
        if any(t in low for t in tokens_l):
            total += 1

    return total


def classify_smart(nf: str, lines: list[str]) -> dict[str, Any]:
    if not lines:
        return {
            "state": "missing",
            "score": 0,
            "last_positive": None,
            "last_attention": None,
            "last_benign_stop": None,
            "positive_count": 0,
            "attention_count": 0,
            "benign_stop_count": 0,
            "reason": "no log lines",
        }

    positives = POSITIVE_TOKENS.get(nf, ["NF registered", "Setup NF EndPoint", "initialize...done"])
    last_pos = last_matching(lines, positives)
    last_att = last_matching(lines, ATTENTION_TOKENS)
    last_stop = last_matching(lines, BENIGN_STOP_TOKENS)

    pos_count = count_tokens(lines, positives)
    att_count = count_tokens(lines, ATTENTION_TOKENS)
    stop_count = count_tokens(lines, BENIGN_STOP_TOKENS)

    score = 0
    score += min(70, pos_count * 14)
    score -= min(45, att_count * 8)
    score -= min(20, stop_count * 5)

    # Se l'ultimo evento significativo è positivo, alza lo stato operativo.
    if last_pos and (not last_att or last_pos["index"] > last_att["index"]):
        score += 25

    # Se gli unici errori recenti sono stop/epoll dopo una sessione riuscita, è "stale-positive" invece di failure.
    if last_stop and last_pos and last_stop["index"] > last_pos["index"]:
        score += 8

    score = max(0, min(100, score))

    if score >= 70:
        state = "active"
    elif score >= 45:
        state = "degraded"
    elif score >= 20:
        state = "attention"
    else:
        state = "critical"

    return {
        "state": state,
        "score": score,
        "last_positive": last_pos,
        "last_attention": last_att,
        "last_benign_stop": last_stop,
        "positive_count": pos_count,
        "attention_count": att_count,
        "benign_stop_count": stop_count,
        "reason": f"score={score} pos={pos_count} attention={att_count} benign_stop={stop_count}",
    }


def ultrafast_core_snapshot() -> dict[str, Any]:
    nfs = {}

    for nf, filename in NF_FILES.items():
        path = OPEN5GS_LOG_DIR / filename
        tail = tail_file_fast(path, 80)
        smart = classify_smart(nf, tail)
        nfs[nf] = {
            "nf": nf,
            "exists": path.exists(),
            "state": smart["state"],
            "score": smart["score"],
            "reason": smart["reason"],
            "last_positive": smart["last_positive"],
            "last_attention": smart["last_attention"],
            "last_benign_stop": smart["last_benign_stop"],
            "positive_count": smart["positive_count"],
            "attention_count": smart["attention_count"],
            "benign_stop_count": smart["benign_stop_count"],
            "line_count": len(tail),
            "tail": tail[-8:],
        }

    present = sum(1 for item in nfs.values() if item["exists"])
    active = sum(1 for item in nfs.values() if item["state"] == "active")
    degraded = sum(1 for item in nfs.values() if item["state"] == "degraded")
    attention = sum(1 for item in nfs.values() if item["state"] == "attention")
    critical = sum(1 for item in nfs.values() if item["state"] == "critical")

    amf_tail = nfs["amf"]["tail"]
    smf_tail = nfs["smf"]["tail"]
    upf_tail = nfs["upf"]["tail"]
    all_tail = [line for item in nfs.values() for line in item["tail"]]

    return {
        "mode": "v16g-smart-open5gs-classifier",
        "source": "smart-tail-score-no-rglob",
        "log_dir": str(OPEN5GS_LOG_DIR),
        "present_logs": present,
        "active_nfs": active,
        "degraded_nfs": degraded,
        "attention_nfs": attention,
        "critical_nfs": critical,
        "nfs": nfs,
        "fivegc": {
            "amf": nfs["amf"]["state"],
            "smf": nfs["smf"]["state"],
            "upf": nfs["upf"]["state"],
            "ausf": nfs["ausf"]["state"],
            "udm": nfs["udm"]["state"],
            "udr": nfs["udr"]["state"],
            "nrf": nfs["nrf"]["state"],
            "pcf": nfs["pcf"]["state"],
            "registeredUes": count_tokens(amf_tail, ["Registration", "Registration complete", "AMF-UE", "SUCI", "SUPI"]),
            "pduSessions": count_tokens(smf_tail, ["PDU", "Session", "SMF-Sessions"]),
            "n3Tunnels": count_tokens(upf_tail, ["GTP", "TEID", "UPF-Sessions", "gtp_connect"]),
            "sbiCallsPerMin": count_tokens(all_tail, ["sbi", "nrf", "http", "nf registered", "service", "endpoint"]),
        },
        "security": {
            "supiExposure": "not-detected-in-smart-tail",
            "suciProtection": "observed-or-expected",
            "akaState": "observability-only",
            "nasCiphering": "observability-only",
            "nasIntegrity": "observability-only",
            "userPlaneCiphering": "observability-only",
        },
    }


def ultrafast_rf(tick: int) -> dict[str, Any]:
    phase = abs(math.sin(tick / 7))

    return {
        "rsrp": round(-92 + phase * 5, 1),
        "rsrq": round(-11 + math.cos(tick / 6) * 1.4, 1),
        "sinr": round(22 + phase * 9, 1),
        "bler": round(0.3 + abs(math.cos(tick / 5)) * 1.2, 2),
        "throughputMbps": round(1800 + phase * 2300),
        "activeUes": round(1200 + phase * 520),
    }


_rf_provider = select_rf_provider(legacy_rf_fn=ultrafast_rf)
_instrument_provider = select_instrument_provider()


def ultrafast_pcap() -> dict[str, Any]:
    rows = [
        ["RRC", "RRC Setup Request", "UE → gNB", "radio access"],
        ["NAS-5GS", "Registration Request", "UE → AMF", "SUCI protected"],
        ["NGAP", "Initial UE Message", "gNB → AMF", "AMF selection"],
        ["AUSF", "Authentication Request", "AMF → AUSF", "5G-AKA"],
        ["UDM", "Generate Auth Data", "AUSF → UDM", "auth vector"],
        ["NAS-5GS", "Security Mode Complete", "UE → AMF", "cipher/integrity"],
        ["PFCP", "Session Establishment", "SMF → UPF", "N4"],
        ["GTP-U", "Tunnel Active", "gNB ↔ UPF", "N3 user plane"],
        ["HTTP/2", "SBI GET/POST/PUT", "NF ↔ NF", "service based API"],
    ]

    return {
        "mode": "v16g-smart-pcap-synthetic",
        "timeline": [
            {
                "id": idx + 1,
                "time": f"00.{idx * 37:03d}",
                "protocol": row[0],
                "message": row[1],
                "path": row[2],
                "note": row[3],
                "severity": "key" if row[0] in {"NAS-5GS", "NGAP", "PFCP", "GTP-U"} else "normal",
            }
            for idx, row in enumerate(rows)
        ],
    }


def ultrafast_global_snapshot(tick: int = 0) -> dict[str, Any]:
    return {
        "timestamp": time.time(),
        "version": "V16G-SMART-LOG-CLASSIFIER",
        "mode": "backend-smart-live-readonly",
        "tick": tick,
        "core": ultrafast_core_snapshot(),
        "ueransim": {
            "mode": "not-scanned-in-websocket",
            "reason": "kept out of realtime loop for stability",
            "logs": [],
        },
        "rf": _rf_provider.read_snapshot(tick),
        "pcap": ultrafast_pcap(),
        "instrument": _instrument_provider.read_snapshot(tick),
        "security_boundary": {
            "real_jamming": False,
            "rogue_cell_operation": False,
            "ue_compromise": False,
            "mode": "defensive-observability",
        },
    }
