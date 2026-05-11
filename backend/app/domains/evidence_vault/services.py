from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
import json

from app.domains.reports.services import ScenarioReportService
from app.domains.timeline.services import TimelineService
from app.domains.correlation.services import CorrelationService
from app.persistence.repositories import PersistenceRepository, CloudEventRepository


class EvidenceVaultService:
    service_name = "TRFMC_PERSISTENT_REPORT_ARCHIVE_EVIDENCE_VAULT_V0_20"

    def __init__(self):
        self.root = Path("/runtime/evidence_vault")
        self.reports_dir = self.root / "reports"
        self.html_dir = self.root / "html"
        self.snapshots_dir = self.root / "snapshots"
        self.index_file = self.root / "vault_index.json"

        self.reports_dir.mkdir(parents=True, exist_ok=True)
        self.html_dir.mkdir(parents=True, exist_ok=True)
        self.snapshots_dir.mkdir(parents=True, exist_ok=True)

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def status(self) -> Dict[str, Any]:
        reports = self.list_reports()
        latest = self.latest_snapshot()

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "vault_root": str(self.root),
            "exists": self.root.exists(),
            "reports_dir": str(self.reports_dir),
            "html_dir": str(self.html_dir),
            "snapshots_dir": str(self.snapshots_dir),
            "report_count": len(reports.get("reports", [])),
            "latest_snapshot": latest,
            "persistence": self._safe_persistence(),
        }

    def archive_latest(self) -> Dict[str, Any]:
        report = ScenarioReportService().latest_report()

        if report.get("status") == "NO_SCENARIO_RUN_FOUND":
            return {
                "service": self.service_name,
                "timestamp": self.now(),
                "status": "NO_SCENARIO_RUN_FOUND",
                "message": "Nessun run scenario disponibile da archiviare.",
                "report": report,
            }

        return self.archive_report(report)

    def archive_report(self, report: Dict[str, Any]) -> Dict[str, Any]:
        run_id = report.get("run_id")
        if not run_id:
            raise ValueError("Report senza run_id: impossibile archiviare.")

        ts = self.now().replace(":", "").replace("+", "Z")
        safe_run = "".join(c for c in run_id if c.isalnum() or c in ("-", "_"))

        report_path = self.reports_dir / f"{safe_run}.json"
        html_path = self.html_dir / f"{safe_run}.html"
        snapshot_path = self.snapshots_dir / f"{safe_run}_snapshot.json"

        timeline = []
        graph_summary = {}
        graph = None
        events = []

        mission_id = report.get("mission_id") or "MISSION-FULL-TELCO-BOOT-001"

        try:
            timeline = TimelineService().timeline(mission_id=mission_id, limit=1000).get("entries", [])
        except Exception as exc:
            timeline = [{"error": str(exc)}]

        try:
            graph = CorrelationService().build_graph(mission_id=mission_id, limit=1000)
            graph_summary = graph.get("summary", {})
        except Exception as exc:
            graph_summary = {"error": str(exc)}

        try:
            events = CloudEventRepository().list(limit=1000)
        except Exception:
            events = []

        snapshot = {
            "service": self.service_name,
            "timestamp": self.now(),
            "run_id": run_id,
            "scenario_id": report.get("scenario_id"),
            "mission_id": mission_id,
            "correlation_id": report.get("correlation_id"),
            "report": report,
            "timeline_snapshot": timeline,
            "correlation_graph_summary": graph_summary,
            "correlation_graph": graph,
            "cloud_events_snapshot": events,
            "persistence": self._safe_persistence(),
        }

        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False, default=str), encoding="utf-8")

        try:
            html = ScenarioReportService().export_html(run_id)
        except Exception:
            html = self._fallback_html(report)
        html_path.write_text(html, encoding="utf-8")

        snapshot_path.write_text(json.dumps(snapshot, indent=2, ensure_ascii=False, default=str), encoding="utf-8")

        index = self._load_index()
        record = {
            "run_id": run_id,
            "scenario_id": report.get("scenario_id"),
            "mission_id": mission_id,
            "correlation_id": report.get("correlation_id"),
            "title": report.get("title"),
            "category": report.get("category"),
            "status": report.get("status"),
            "archived_at": self.now(),
            "report_json": str(report_path),
            "report_html": str(html_path),
            "snapshot_json": str(snapshot_path),
            "html_url": f"/api/vault/reports/{run_id}/html",
        }

        index["reports"] = [r for r in index.get("reports", []) if r.get("run_id") != run_id]
        index["reports"].insert(0, record)
        index["latest_run_id"] = run_id
        index["updated_at"] = self.now()

        self._save_index(index)

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "status": "ARCHIVED",
            "record": record,
            "summary": {
                "timeline_entries": len(timeline),
                "cloud_events": len(events),
                "graph_nodes": graph_summary.get("nodes"),
                "graph_edges": graph_summary.get("edges"),
            },
        }

    def list_reports(self) -> Dict[str, Any]:
        index = self._load_index()
        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "vault_root": str(self.root),
            "count": len(index.get("reports", [])),
            "latest_run_id": index.get("latest_run_id"),
            "reports": index.get("reports", []),
        }

    def get_report(self, run_id: str) -> Dict[str, Any]:
        path = self.reports_dir / f"{self._safe(run_id)}.json"
        if not path.exists():
            raise ValueError(f"Report non trovato nel vault: {run_id}")
        return json.loads(path.read_text(encoding="utf-8"))

    def get_report_html(self, run_id: str) -> str:
        path = self.html_dir / f"{self._safe(run_id)}.html"
        if not path.exists():
            raise ValueError(f"HTML report non trovato nel vault: {run_id}")
        return path.read_text(encoding="utf-8")

    def latest_snapshot(self) -> Dict[str, Any]:
        index = self._load_index()
        latest = index.get("latest_run_id")
        if not latest:
            return {
                "status": "EMPTY",
                "message": "Vault vuoto: archivia prima un report scenario.",
            }

        path = self.snapshots_dir / f"{self._safe(latest)}_snapshot.json"
        if not path.exists():
            return {
                "status": "MISSING_SNAPSHOT",
                "latest_run_id": latest,
                "path": str(path),
            }

        data = json.loads(path.read_text(encoding="utf-8"))
        return {
            "status": "OK",
            "latest_run_id": latest,
            "snapshot_path": str(path),
            "snapshot": data,
        }

    def _load_index(self) -> Dict[str, Any]:
        if not self.index_file.exists():
            return {
                "service": self.service_name,
                "created_at": self.now(),
                "updated_at": self.now(),
                "latest_run_id": None,
                "reports": [],
            }
        try:
            return json.loads(self.index_file.read_text(encoding="utf-8"))
        except Exception:
            return {
                "service": self.service_name,
                "created_at": self.now(),
                "updated_at": self.now(),
                "latest_run_id": None,
                "reports": [],
                "warning": "Previous index was unreadable and has been ignored.",
            }

    def _save_index(self, index: Dict[str, Any]) -> None:
        self.index_file.write_text(json.dumps(index, indent=2, ensure_ascii=False, default=str), encoding="utf-8")

    def _safe(self, value: str) -> str:
        return "".join(c for c in str(value) if c.isalnum() or c in ("-", "_"))

    def _safe_persistence(self) -> Dict[str, Any]:
        try:
            return PersistenceRepository().status()
        except Exception as exc:
            return {"error": str(exc)}

    def _fallback_html(self, report: Dict[str, Any]) -> str:
        return f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8"/>
<title>TRFMC Evidence Vault Report</title>
<style>
body {{
  background:#020711;
  color:#edf8ff;
  font-family:Consolas,monospace;
  padding:28px;
}}
pre {{
  white-space:pre-wrap;
  background:rgba(255,255,255,.05);
  border:1px solid rgba(88,214,249,.25);
  border-radius:12px;
  padding:14px;
}}
h1 {{ color:#58d6f9; }}
</style>
</head>
<body>
<h1>TRFMC Evidence Vault Report</h1>
<pre>{json.dumps(report, indent=2, ensure_ascii=False, default=str)}</pre>
</body>
</html>"""
