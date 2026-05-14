from datetime import datetime, timezone
from typing import Any, Dict, List

from app.persistence.repositories import PersistenceRepository, CloudEventRepository


class PortalIndexService:
    service_name = "TRFMC_PORTAL_INDEX_DOCS_NAVIGATION_V0_24"

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def pages(self) -> List[Dict[str, Any]]:
        return [
            {
                "id": "main-dashboard",
                "title": "Dashboard principale",
                "version": "current",
                "path": "/",
                "url": "http://127.0.0.1:5173/",
                "category": "mission_control",
                "description": "Vista principale del portale TRFMC.",
                "status": "ACTIVE",
            },
            {
                "id": "observability",
                "title": "Observability & Evidence Console",
                "version": "v0.13",
                "path": "/observability_console_v13.html",
                "url": "http://127.0.0.1:5173/observability_console_v13.html",
                "category": "observability",
                "description": "Health matrix, persistence counters, CloudEvents, RF runs e runtime state.",
                "status": "ACTIVE",
            },
            {
                "id": "timeline",
                "title": "Evidence Timeline & Mission Replay",
                "version": "v0.14",
                "path": "/timeline_console_v14.html",
                "url": "http://127.0.0.1:5173/timeline_console_v14.html",
                "category": "timeline",
                "description": "Timeline unica missione, replay, correlation_id, RF field, coverage e network path.",
                "status": "ACTIVE",
            },
            {
                "id": "mission-graph",
                "title": "Correlation Engine & Mission Graph",
                "version": "v0.15",
                "path": "/mission_graph_console_v15.html",
                "url": "http://127.0.0.1:5173/mission_graph_console_v15.html",
                "category": "correlation",
                "description": "Grafo missione con asset, eventi, RF run, network path, incidenti e correlazioni.",
                "status": "ACTIVE",
            },
            {
                "id": "scenario-runner",
                "title": "Scenario Runner & Mission Playbooks",
                "version": "v0.16",
                "path": "/scenario_runner_console_v16.html",
                "url": "http://127.0.0.1:5173/scenario_runner_console_v16.html",
                "category": "scenarios",
                "description": "Esecuzione playbook: UE remoto, UAV, NLOS urbano, global VoNR, evidence burst.",
                "status": "ACTIVE",
            },
            {
                "id": "scenario-report",
                "title": "Scenario Evidence Dashboard & Report Export",
                "version": "v0.17",
                "path": "/scenario_report_console_v17.html",
                "url": "http://127.0.0.1:5173/scenario_report_console_v17.html",
                "category": "reports",
                "description": "Report scenario con evidenze RF, timeline, correlation graph, CloudEvents ed export HTML.",
                "status": "ACTIVE",
            },
            {
                "id": "security",
                "title": "Security Baseline & Access Guard",
                "version": "v0.18",
                "path": "/security_console_v18.html",
                "url": "http://127.0.0.1:5173/security_console_v18.html",
                "category": "security",
                "description": "Security posture, restricted readiness, access policy, audit view e guardrail.",
                "status": "ACTIVE",
            },
            {
                "id": "portal-index",
                "title": "Unified Navigation & Portal Index",
                "version": "v0.19",
                "path": "/portal_index_v19.html",
                "url": "http://127.0.0.1:5173/portal_index_v19.html",
                "category": "navigation",
                "description": "Indice unico enterprise per tutte le console e gli endpoint operativi.",
                "status": "ACTIVE",
            },
            {
                "id": "evidence-vault",
                "title": "Persistent Report Archive & Evidence Vault",
                "version": "v0.20",
                "path": "/evidence_vault_console_v20.html",
                "url": "http://127.0.0.1:5173/evidence_vault_console_v20.html",
                "category": "vault",
                "description": "Archivio persistente per report scenario, export HTML, timeline snapshot, correlation graph e CloudEvents.",
                "status": "ACTIVE",
            },
            {
                "id": "operational-backup",
                "title": "Operational Backup & Recovery Control",
                "version": "v0.21",
                "path": "/operational_backup_console_v21.html",
                "url": "http://127.0.0.1:5173/operational_backup_console_v21.html",
                "category": "backup",
                "description": "Backup runtime, manifest, hash SHA256, DB/evidence vault e controllo operativo.",
                "status": "ACTIVE",
            },
            {
                "id": "restore-readiness",
                "title": "Restore Readiness & Disaster Recovery Drill",
                "version": "v0.22",
                "path": "/restore_readiness_console_v22.html",
                "url": "http://127.0.0.1:5173/restore_readiness_console_v22.html",
                "category": "recovery",
                "description": "Verifica backup, manifest, SHA256, piano cold restore e drill non distruttivo.",
                "status": "ACTIVE",
            },
            {
                "id": "operator-handbook",
                "title": "Operator Handbook & Documentation Console",
                "version": "v0.23",
                "path": "/operator_handbook_console_v23.html",
                "url": "http://127.0.0.1:5173/operator_handbook_console_v23.html",
                "category": "documentation",
                "description": "Manuale operativo, architettura corrente, backup/restore, security baseline, release chain e command reference.",
                "status": "ACTIVE",
            },
        ]

    def release_chain(self) -> List[Dict[str, Any]]:
        return [
            {"version": "v0.2", "title": "Full Telco Skeleton"},
            {"version": "v0.3", "title": "SQLite Persistence"},
            {"version": "v0.4", "title": "CloudEvents + WebSocket Event Stream"},
            {"version": "v0.5", "title": "Global Time Cursor"},
            {"version": "v0.6", "title": "Asset Digital Twin Registry"},
            {"version": "v0.7", "title": "Network Journey Digital Twin"},
            {"version": "v0.8", "title": "RF Propagation / Urban Coverage Engine"},
            {"version": "v0.9", "title": "RF Field / Antenna / Fresnel Engine"},
            {"version": "v0.10", "title": "RF Visualization / Instrument Panel"},
            {"version": "v0.11", "title": "Mission Control Layout Normalization"},
            {"version": "v0.12", "title": "Hardened Operational Launchers"},
            {"version": "v0.13", "title": "Observability & Evidence Console"},
            {"version": "v0.14", "title": "Evidence Timeline & Mission Replay"},
            {"version": "v0.15", "title": "Correlation Engine & Mission Graph"},
            {"version": "v0.16", "title": "Scenario Runner & Mission Playbooks"},
            {"version": "v0.17", "title": "Scenario Evidence Dashboard & Report Export"},
            {"version": "v0.18", "title": "Security Baseline & Access Guard"},
            {"version": "v0.19", "title": "Unified Navigation & Portal Index"},
            {"version": "v0.20", "title": "Persistent Report Archive & Evidence Vault"},
            {"version": "v0.21", "title": "Operational Backup & Recovery Control"},
            {"version": "v0.22", "title": "Restore Readiness & Disaster Recovery Drill"},
            {"version": "v0.23", "title": "Operator Handbook & Documentation Console"},
            {"version": "v0.24", "title": "Portal Index Docs Navigation"},
        ]

    def api_endpoints(self) -> List[Dict[str, Any]]:
        return [
            {"method": "GET", "path": "/api/health", "domain": "core"},
            {"method": "GET", "path": "/api/persistence/status", "domain": "persistence"},
            {"method": "GET", "path": "/api/observability/health-matrix", "domain": "observability"},
            {"method": "GET", "path": "/api/timeline/evidence", "domain": "timeline"},
            {"method": "GET", "path": "/api/timeline/replay", "domain": "timeline"},
            {"method": "GET", "path": "/api/correlation/graph", "domain": "correlation"},
            {"method": "GET", "path": "/api/scenarios/catalog", "domain": "scenarios"},
            {"method": "POST", "path": "/api/scenarios/run/{scenario_id}", "domain": "scenarios"},
            {"method": "GET", "path": "/api/reports/latest", "domain": "reports"},
            {"method": "GET", "path": "/api/reports/export/html/{run_id}", "domain": "reports"},
            {"method": "GET", "path": "/api/security/posture", "domain": "security"},
            {"method": "GET", "path": "/api/security/readiness", "domain": "security"},
            {"method": "GET", "path": "/api/portal/index", "domain": "portal"},
            {"method": "GET", "path": "/api/portal/pages", "domain": "portal"},
            {"method": "GET", "path": "/api/portal/health-summary", "domain": "portal"},
            {"method": "GET", "path": "/api/vault/status", "domain": "vault"},
            {"method": "POST", "path": "/api/vault/archive/latest", "domain": "vault"},
            {"method": "GET", "path": "/api/vault/reports", "domain": "vault"},
            {"method": "GET", "path": "/api/vault/reports/{run_id}", "domain": "vault"},
            {"method": "GET", "path": "/api/vault/snapshot/latest", "domain": "vault"},
            {"method": "GET", "path": "/api/ops/backup/status", "domain": "ops"},
            {"method": "POST", "path": "/api/ops/backup/create-runtime", "domain": "ops"},
            {"method": "GET", "path": "/api/ops/backup/list", "domain": "ops"},
            {"method": "GET", "path": "/api/ops/backup/latest-manifest", "domain": "ops"},
            {"method": "GET", "path": "/api/restore/readiness", "domain": "restore"},
            {"method": "GET", "path": "/api/restore/plan", "domain": "restore"},
            {"method": "GET", "path": "/api/restore/verify-backup", "domain": "restore"},
            {"method": "GET", "path": "/api/restore/drill", "domain": "restore"},
            {"method": "GET", "path": "/api/docs/index", "domain": "docs"},
            {"method": "GET", "path": "/api/docs/operator-handbook", "domain": "docs"},
            {"method": "GET", "path": "/api/docs/architecture", "domain": "docs"},
            {"method": "GET", "path": "/api/docs/backup-restore", "domain": "docs"},
            {"method": "GET", "path": "/api/docs/release-chain", "domain": "docs"},
            {"method": "GET", "path": "/api/docs/security", "domain": "docs"},
            {"method": "GET", "path": "/api/docs/commands", "domain": "docs"},
        ]

    def operator_commands(self) -> List[Dict[str, str]]:
        return [
            {"name": "start", "command": "bash scripts/trfmc_start.sh"},
            {"name": "stop", "command": "bash scripts/trfmc_stop.sh"},
            {"name": "restart", "command": "bash scripts/trfmc_restart.sh"},
            {"name": "status", "command": "bash scripts/trfmc_status.sh"},
            {"name": "verify", "command": "bash scripts/trfmc_verify.sh"},
        ]

    def index(self) -> Dict[str, Any]:
        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "project": "Telco RF Mission Control Platform",
            "short_name": "TRFMC",
            "version": "0.24.0",
            "operational_mode": "SIMULATION_ONLY",
            "frontend_base": "http://127.0.0.1:5173",
            "backend_base": "http://127.0.0.1:8000",
            "pages": self.pages(),
            "api_endpoints": self.api_endpoints(),
            "release_chain": self.release_chain(),
            "operator_commands": self.operator_commands(),
            "security_position": {
                "restricted_area": "disabled by default",
                "network_binding": "localhost development binding",
                "future": ["mTLS", "private CA", "smartcard", "RBAC/ABAC", "immutable audit"],
            },
        }

    def health_summary(self) -> Dict[str, Any]:
        persistence = {}
        event_count = None

        try:
            persistence = PersistenceRepository().status()
        except Exception as exc:
            persistence = {"error": str(exc)}

        try:
            event_count = len(CloudEventRepository().list(limit=500))
        except Exception:
            event_count = None

        counts = persistence.get("counts", {}) if isinstance(persistence, dict) else {}

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "overall_status": "OK" if persistence.get("exists") else "ATTENTION_REQUIRED",
            "version": "0.24.0",
            "persistence": persistence,
            "event_count_sample": event_count,
            "high_value_counts": {
                "assets": counts.get("assets"),
                "cloud_events": counts.get("cloud_events"),
                "network_paths": counts.get("network_paths"),
                "rf_coverage_runs": counts.get("rf_coverage_runs"),
                "rf_field_runs": counts.get("rf_field_runs"),
                "incidents": counts.get("incidents"),
            },
            "pages_active": len(self.pages()),
            "api_endpoints_indexed": len(self.api_endpoints()),
        }
