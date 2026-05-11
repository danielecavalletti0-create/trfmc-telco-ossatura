from datetime import datetime, timezone
from typing import Any, Dict

from app.persistence.repositories import (
    PersistenceRepository,
    CloudEventRepository,
    AssetRepository,
    AssetLinkRepository,
    EvidenceRepository,
    NetworkPathRepository,
    IncidentRepository,
    RfCoverageRunRepository,
    RfFieldRunRepository,
)


class ObservabilityService:
    service_name = "TRFMC_OBSERVABILITY_EVIDENCE_CONSOLE_V0_13"

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def safe(self, name: str, fn):
        try:
            return {"ok": True, "name": name, "data": fn()}
        except Exception as exc:
            return {"ok": False, "name": name, "error": str(exc)}

    def health_matrix(self) -> Dict[str, Any]:
        persistence = self.safe("persistence", lambda: PersistenceRepository().status())
        events = self.safe("cloud_events", lambda: CloudEventRepository().list(limit=10))
        assets = self.safe("assets", lambda: AssetRepository().list())
        network = self.safe("network_paths", lambda: NetworkPathRepository().list())
        rf_cov = self.safe("rf_coverage_runs", lambda: RfCoverageRunRepository().list(limit=5))
        rf_field = self.safe("rf_field_runs", lambda: RfFieldRunRepository().list(limit=5))

        checks = [persistence, events, assets, network, rf_cov, rf_field]
        degraded = [c for c in checks if not c["ok"]]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "overall_status": "DEGRADED" if degraded else "OK",
            "checks": checks,
            "summary": {
                "total_checks": len(checks),
                "ok": sum(1 for c in checks if c["ok"]),
                "failed": len(degraded),
            },
        }

    def evidence_console(self) -> Dict[str, Any]:
        persistence = PersistenceRepository().status()
        counts = persistence.get("counts", {})

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "persistence": persistence,
            "events": CloudEventRepository().list(limit=50),
            "assets": AssetRepository().list(),
            "asset_links": AssetLinkRepository().list(),
            "evidence": EvidenceRepository().list(),
            "incidents": IncidentRepository().list(),
            "network_paths": NetworkPathRepository().list(),
            "rf_coverage_runs": RfCoverageRunRepository().list(limit=20),
            "rf_field_runs": RfFieldRunRepository().list(limit=20),
            "mission_evidence_index": {
                "cloud_events": counts.get("cloud_events", 0),
                "assets": counts.get("assets", 0),
                "asset_links": counts.get("asset_links", 0),
                "network_paths": counts.get("network_paths", 0),
                "rf_coverage_runs": counts.get("rf_coverage_runs", 0),
                "rf_field_runs": counts.get("rf_field_runs", 0),
                "evidence": counts.get("evidence", 0),
                "incidents": counts.get("incidents", 0),
            },
        }

    def runtime_matrix(self) -> Dict[str, Any]:
        status = PersistenceRepository().status()
        counts = status.get("counts", {})

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "database": {
                "path": status.get("db_path"),
                "exists": status.get("exists"),
                "counts": counts,
            },
            "api_domains": [
                "mission",
                "events",
                "persistence",
                "time-cursor",
                "assets",
                "network-fabric",
                "rf-coverage",
                "rf-field",
                "access-trust",
                "soc-noc",
                "restricted",
                "observability",
            ],
            "operational_notes": [
                "Host Docker status is intentionally handled by shell launcher scripts.",
                "Backend observability reports application-level state and persisted evidence.",
                "Use scripts/trfmc_status.sh for host/container/port diagnostics.",
            ],
        }
