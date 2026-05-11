from datetime import datetime, timezone
from typing import Any, Dict, List

from app.persistence.repositories import PersistenceRepository, CloudEventRepository


class PortalIndexService:
    service_name = "TRFMC_UNIFIED_NAVIGATION_PORTAL_INDEX_V0_19"

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
            "version": "0.19.0",
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
            "version": "0.19.0",
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
