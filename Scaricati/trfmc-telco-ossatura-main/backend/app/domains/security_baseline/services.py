from datetime import datetime, timezone
from typing import Any, Dict, List
import os

from app.persistence.repositories import PersistenceRepository, CloudEventRepository


class SecurityBaselineService:
    service_name = "TRFMC_SECURITY_BASELINE_ACCESS_GUARD_V0_18"

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def env_bool(self, name: str, default: str = "false") -> bool:
        return str(os.getenv(name, default)).lower() in ("1", "true", "yes", "on")

    def posture(self) -> Dict[str, Any]:
        operational_mode = os.getenv("TRFMC_OPERATIONAL_MODE", "UNKNOWN")
        restricted_enabled = self.env_bool("TRFMC_RESTRICTED_ENABLED", "false")
        env_name = os.getenv("TRFMC_ENV", "unknown")
        sqlite_path = os.getenv("TRFMC_SQLITE_PATH", "")

        checks = [
            self._check(
                "SIMULATION_ONLY_MODE",
                operational_mode == "SIMULATION_ONLY",
                "Il portale deve restare in SIMULATION_ONLY finché non sono presenti guardrail reali e approvazione operativa.",
                {"TRFMC_OPERATIONAL_MODE": operational_mode},
                severity="CRITICAL",
            ),
            self._check(
                "RESTRICTED_AREA_DISABLED_BY_DEFAULT",
                restricted_enabled is False,
                "L'area riservata deve restare disabilitata finché non sono integrati mTLS/PKI/smartcard/RBAC/audit immutabile.",
                {"TRFMC_RESTRICTED_ENABLED": restricted_enabled},
                severity="HIGH",
            ),
            self._check(
                "SQLITE_PATH_CONFIGURED",
                bool(sqlite_path),
                "Il percorso del database runtime deve essere esplicito.",
                {"TRFMC_SQLITE_PATH": sqlite_path},
                severity="MEDIUM",
            ),
            self._check(
                "DEV_ENV_DECLARED",
                env_name in ("dev", "test", "lab"),
                "L'ambiente deve essere dichiarato e coerente con laboratorio/simulazione.",
                {"TRFMC_ENV": env_name},
                severity="MEDIUM",
            ),
        ]

        failed = [c for c in checks if not c["passed"]]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "overall_status": "PASS" if not failed else "ATTENTION_REQUIRED",
            "environment": env_name,
            "operational_mode": operational_mode,
            "restricted_enabled": restricted_enabled,
            "checks": checks,
            "summary": {
                "total": len(checks),
                "passed": sum(1 for c in checks if c["passed"]),
                "failed": len(failed),
                "max_failed_severity": self._max_severity(failed),
            },
            "privacy_security_position": {
                "data_mode": "LAB_SIMULATION_DATA",
                "expected_binding": "localhost-only during development",
                "restricted_compartment": "planned, not active",
                "red_sigint_ew_area": "placeholder only; requires PKI/smartcard/mTLS/RBAC before activation",
            },
        }

    def access_policy(self) -> Dict[str, Any]:
        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "policy_version": "ACCESS_POLICY_DRAFT_V0_18",
            "current_enforcement": "OBSERVE_ONLY",
            "default_access": {
                "public_lab_dashboard": "localhost dev access",
                "observability": "localhost dev access",
                "timeline": "localhost dev access",
                "mission_graph": "localhost dev access",
                "scenario_runner": "localhost dev access",
                "reports": "localhost dev access",
                "restricted": "DENY_UNTIL_PKI_READY",
            },
            "future_controls": [
                {
                    "control": "mTLS",
                    "purpose": "Autenticazione forte client/server con CA privata del laboratorio.",
                    "status": "PLANNED",
                },
                {
                    "control": "Smartcard / client certificate binding",
                    "purpose": "Accesso personale all'area riservata tramite certificato hardware-backed.",
                    "status": "PLANNED",
                },
                {
                    "control": "RBAC/ABAC",
                    "purpose": "Separazione ruoli: observer, analyst, operator, admin, restricted-owner.",
                    "status": "PLANNED",
                },
                {
                    "control": "Immutable audit trail",
                    "purpose": "Catena eventi non ripudiabile per accessi, scenari, report, export.",
                    "status": "PLANNED",
                },
                {
                    "control": "Restricted action interlocks",
                    "purpose": "Bloccare funzioni EW/SIGINT/RED finché non sono attivati safety boundary e policy.",
                    "status": "PLANNED",
                },
            ],
            "guard_rules": [
                {
                    "rule_id": "GUARD-001",
                    "name": "Simulation-only gate",
                    "decision": "ALLOW only simulation APIs while TRFMC_OPERATIONAL_MODE=SIMULATION_ONLY",
                },
                {
                    "rule_id": "GUARD-002",
                    "name": "Restricted denied by default",
                    "decision": "DENY restricted APIs unless TRFMC_RESTRICTED_ENABLED=true and strong auth is present",
                },
                {
                    "rule_id": "GUARD-003",
                    "name": "Localhost-first development binding",
                    "decision": "Prefer 127.0.0.1 binding until reverse proxy, TLS and auth are configured",
                },
                {
                    "rule_id": "GUARD-004",
                    "name": "Evidence preserving",
                    "decision": "Scenario/report generation must leave CloudEvents and DB evidence",
                },
            ],
        }

    def runtime_checks(self) -> Dict[str, Any]:
        persistence_status = {}
        try:
            persistence_status = PersistenceRepository().status()
        except Exception as exc:
            persistence_status = {"error": str(exc)}

        expected_endpoints = [
            "/api/health",
            "/api/persistence/status",
            "/api/observability/health-matrix",
            "/api/timeline/evidence",
            "/api/correlation/graph",
            "/api/scenarios/catalog",
            "/api/reports/latest",
            "/api/security/posture",
            "/api/security/access-policy",
            "/api/security/runtime-checks",
            "/api/security/audit-log",
            "/api/security/readiness",
        ]

        expected_frontend_pages = [
            "/",
            "/observability_console_v13.html",
            "/timeline_console_v14.html",
            "/mission_graph_console_v15.html",
            "/scenario_runner_console_v16.html",
            "/scenario_report_console_v17.html",
            "/security_console_v18.html",
        ]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "runtime_scope": "application-level checks; host/container checks remain in scripts/trfmc_status.sh",
            "expected_backend_port": 8000,
            "expected_frontend_port": 5173,
            "expected_bind": "127.0.0.1 on host launcher",
            "persistence": persistence_status,
            "expected_endpoints": expected_endpoints,
            "expected_frontend_pages": expected_frontend_pages,
            "operator_commands": [
                "bash scripts/trfmc_start.sh",
                "bash scripts/trfmc_stop.sh",
                "bash scripts/trfmc_restart.sh",
                "bash scripts/trfmc_status.sh",
                "bash scripts/trfmc_verify.sh",
            ],
        }

    def audit_log(self, limit: int = 100) -> Dict[str, Any]:
        events = []
        try:
            raw = CloudEventRepository().list(limit=limit)
            events = [
                ev for ev in raw
                if str(ev.get("type", "")).startswith("trfmc.")
            ]
        except Exception:
            events = []

        security_relevant = []
        for ev in events:
            ev_type = str(ev.get("type", ""))
            if any(token in ev_type for token in ["scenario", "rf", "coverage", "field", "report", "security"]):
                security_relevant.append(ev)

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "mode": "APPLICATION_AUDIT_VIEW",
            "note": "Per audit host/container usare anche logs/trfmc_*_last.log e script trfmc_status.sh.",
            "count": len(security_relevant),
            "events": security_relevant[:limit],
        }

    def readiness(self) -> Dict[str, Any]:
        posture = self.posture()
        policy = self.access_policy()

        checklist = [
            {
                "item": "TLS reverse proxy",
                "required_for_restricted": True,
                "status": "TODO",
                "notes": "Terminazione TLS locale o reverse proxy dedicato.",
            },
            {
                "item": "Private CA",
                "required_for_restricted": True,
                "status": "TODO",
                "notes": "CA laboratorio per certificati client/server.",
            },
            {
                "item": "mTLS client authentication",
                "required_for_restricted": True,
                "status": "TODO",
                "notes": "Autenticazione forte prima di esporre qualsiasi endpoint riservato.",
            },
            {
                "item": "Smartcard / PKCS#11 binding",
                "required_for_restricted": True,
                "status": "TODO",
                "notes": "Associazione certificato utente a dispositivo hardware.",
            },
            {
                "item": "RBAC/ABAC policy engine",
                "required_for_restricted": True,
                "status": "TODO",
                "notes": "Ruoli, attributi, autorizzazioni granulari e deny-by-default.",
            },
            {
                "item": "Immutable audit",
                "required_for_restricted": True,
                "status": "TODO",
                "notes": "Hash chain / append-only trail per eventi critici.",
            },
            {
                "item": "Data classification",
                "required_for_restricted": True,
                "status": "PARTIAL",
                "notes": "La classificazione funzionale è impostata; mancano label e retention policy.",
            },
            {
                "item": "Backup and restore procedure",
                "required_for_restricted": True,
                "status": "PARTIAL",
                "notes": "Backup tar manuali presenti; servono script e verifica restore.",
            },
            {
                "item": "Safety/legal guardrails for RED/EW/SIGINT",
                "required_for_restricted": True,
                "status": "TODO",
                "notes": "Da implementare prima di qualsiasi funzione attiva o potenzialmente sensibile.",
            },
        ]

        ready = all(x["status"] == "DONE" for x in checklist if x["required_for_restricted"])

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "restricted_area_ready": ready,
            "decision": "KEEP_RESTRICTED_DISABLED" if not ready else "READY_FOR_CONTROLLED_ENABLEMENT",
            "posture_summary": posture.get("summary"),
            "policy_mode": policy.get("current_enforcement"),
            "checklist": checklist,
        }

    def _check(self, check_id: str, passed: bool, description: str, evidence: Dict[str, Any], severity: str) -> Dict[str, Any]:
        return {
            "check_id": check_id,
            "passed": passed,
            "severity": severity,
            "description": description,
            "evidence": evidence,
        }

    def _max_severity(self, checks: List[Dict[str, Any]]) -> str:
        if not checks:
            return "NONE"
        order = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}
        return max((c.get("severity", "LOW") for c in checks), key=lambda x: order.get(x, 0))
