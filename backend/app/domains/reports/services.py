from datetime import datetime, timezone
from html import escape
from typing import Any, Dict, List, Optional
import json

from app.domains.timeline.services import TimelineService
from app.domains.correlation.services import CorrelationService
from app.persistence.repositories import (
    PersistenceRepository,
    CloudEventRepository,
    RfCoverageRunRepository,
    RfFieldRunRepository,
    NetworkPathRepository,
    AssetRepository,
)


class ScenarioReportService:
    service_name = "TRFMC_SCENARIO_EVIDENCE_REPORT_EXPORT_V0_17"

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _events(self, limit: int = 1000) -> List[Dict[str, Any]]:
        try:
            return CloudEventRepository().list(limit=limit)
        except Exception:
            return []

    def _data(self, row: Dict[str, Any]) -> Dict[str, Any]:
        data = row.get("data")
        if isinstance(data, dict):
            return data
        raw = row.get("data_json")
        if isinstance(raw, str):
            try:
                return json.loads(raw)
            except Exception:
                return {}
        return {}

    def _scenario_events(self, run_id: Optional[str] = None) -> List[Dict[str, Any]]:
        out = []
        for ev in self._events():
            ev_type = str(ev.get("type", ""))
            data = self._data(ev)
            if not ev_type.startswith("trfmc.scenario."):
                continue
            if run_id and data.get("run_id") != run_id and ev.get("subject") != run_id:
                continue
            ev["data"] = data
            out.append(ev)
        return out

    def latest_run_id(self) -> Optional[str]:
        events = self._scenario_events()
        completed = [
            e for e in events
            if str(e.get("type", "")).endswith("run.completed")
            or str(e.get("type", "")).endswith("run_completed")
        ]
        candidates = completed or events
        if not candidates:
            return None
        latest = candidates[0]
        return self._data(latest).get("run_id") or latest.get("subject")

    def report(self, run_id: str) -> Dict[str, Any]:
        scenario_events = self._scenario_events(run_id=run_id)
        if not scenario_events:
            raise ValueError(f"Scenario run non trovato: {run_id}")

        started = next((e for e in scenario_events if "started" in str(e.get("type", ""))), None)
        completed = next((e for e in scenario_events if "completed" in str(e.get("type", ""))), None)
        primary = completed or started or scenario_events[0]
        pdata = self._data(primary)

        scenario_id = pdata.get("scenario_id")
        correlation_id = pdata.get("correlation_id")
        mission_id = pdata.get("mission_id", "MISSION-FULL-TELCO-BOOT-001")
        rf_field_run_id = pdata.get("rf_field_run_id")
        rf_coverage_run_id = pdata.get("rf_coverage_run_id")

        rf_field = self._find_rf_field(rf_field_run_id)
        rf_coverage = self._find_rf_coverage(rf_coverage_run_id)
        network_paths = self._network_paths()
        timeline = self._timeline_for_report(mission_id, correlation_id, run_id, rf_field_run_id, rf_coverage_run_id)
        graph_summary = self._graph_summary(mission_id)
        related_events = self._related_events(run_id, correlation_id, rf_field_run_id, rf_coverage_run_id)

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "report_type": "SCENARIO_EVIDENCE_REPORT",
            "run_id": run_id,
            "scenario_id": scenario_id,
            "mission_id": mission_id,
            "correlation_id": correlation_id,
            "title": pdata.get("title") or scenario_id or run_id,
            "category": pdata.get("category"),
            "status": "COMPLETED" if completed else "STARTED_OR_PARTIAL",
            "scenario_events": scenario_events,
            "evidence": {
                "rf_field_run_id": rf_field_run_id,
                "rf_field": rf_field,
                "rf_coverage_run_id": rf_coverage_run_id,
                "rf_coverage": rf_coverage,
                "network_paths": network_paths,
                "cloud_events": related_events,
                "timeline_entries": timeline,
                "mission_graph_summary": graph_summary,
            },
            "persistence": PersistenceRepository().status(),
            "asset_index": self._asset_index(),
            "executive_summary": self._summary_text(
                run_id=run_id,
                scenario_id=scenario_id,
                rf_field=rf_field,
                rf_coverage=rf_coverage,
                graph_summary=graph_summary,
                related_events=related_events,
                timeline=timeline,
            ),
        }

    def latest_report(self) -> Dict[str, Any]:
        run_id = self.latest_run_id()
        if not run_id:
            return {
                "service": self.service_name,
                "timestamp": self.now(),
                "status": "NO_SCENARIO_RUN_FOUND",
                "message": "Nessun run scenario trovato. Esegui prima uno scenario dal runner v0.16.",
            }
        return self.report(run_id)

    def _find_rf_field(self, run_id: Optional[str]) -> Optional[Dict[str, Any]]:
        if not run_id:
            return None
        try:
            for row in RfFieldRunRepository().list(limit=500):
                if row.get("run_id") == run_id:
                    return row
        except Exception:
            return None
        return None

    def _find_rf_coverage(self, run_id: Optional[str]) -> Optional[Dict[str, Any]]:
        if not run_id:
            return None
        try:
            for row in RfCoverageRunRepository().list(limit=500):
                if row.get("run_id") == run_id:
                    return row
        except Exception:
            return None
        return None

    def _network_paths(self) -> List[Dict[str, Any]]:
        try:
            return NetworkPathRepository().list()
        except Exception:
            return []

    def _asset_index(self) -> Dict[str, Any]:
        try:
            assets = AssetRepository().list()
        except Exception:
            assets = []
        return {
            "count": len(assets),
            "assets": assets,
        }

    def _timeline_for_report(
        self,
        mission_id: str,
        correlation_id: Optional[str],
        run_id: str,
        rf_field_run_id: Optional[str],
        rf_coverage_run_id: Optional[str],
    ) -> List[Dict[str, Any]]:
        try:
            timeline = TimelineService().timeline(mission_id=mission_id, limit=1000).get("entries", [])
        except Exception:
            return []

        tokens = set(x for x in [correlation_id, run_id, rf_field_run_id, rf_coverage_run_id] if x)
        out = []
        for entry in timeline:
            blob = json.dumps(entry, default=str)
            if any(t in blob for t in tokens):
                out.append(entry)
        return out

    def _graph_summary(self, mission_id: str) -> Dict[str, Any]:
        try:
            graph = CorrelationService().build_graph(mission_id=mission_id, limit=1000)
            return graph.get("summary", {})
        except Exception as exc:
            return {"error": str(exc)}

    def _related_events(
        self,
        run_id: str,
        correlation_id: Optional[str],
        rf_field_run_id: Optional[str],
        rf_coverage_run_id: Optional[str],
    ) -> List[Dict[str, Any]]:
        tokens = set(x for x in [run_id, correlation_id, rf_field_run_id, rf_coverage_run_id] if x)
        out = []
        for ev in self._events(limit=1000):
            data = self._data(ev)
            ev["data"] = data
            blob = json.dumps(ev, default=str)
            if any(t in blob for t in tokens):
                out.append(ev)
        return out

    def _summary_text(
        self,
        run_id: str,
        scenario_id: Optional[str],
        rf_field: Optional[Dict[str, Any]],
        rf_coverage: Optional[Dict[str, Any]],
        graph_summary: Dict[str, Any],
        related_events: List[Dict[str, Any]],
        timeline: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        field_region = None
        field_gain = None
        if rf_field:
            fdata = rf_field.get("data") or {}
            field_region = (fdata.get("field_at_target") or {}).get("field_region")
            field_gain = (fdata.get("antenna") or {}).get("gain_to_target_dbi")

        coverage_class = None
        los_state = None
        snr_db = None
        if rf_coverage:
            cdata = rf_coverage.get("data") or {}
            link = cdata.get("target_link") or {}
            coverage_class = link.get("classification")
            los_state = link.get("los_state")
            snr_db = link.get("snr_db")

        return {
            "run_id": run_id,
            "scenario_id": scenario_id,
            "rf_field_region": field_region,
            "antenna_gain_to_target_dbi": field_gain,
            "coverage_classification": coverage_class,
            "los_state": los_state,
            "snr_db": snr_db,
            "related_cloud_events": len(related_events),
            "related_timeline_entries": len(timeline),
            "mission_graph_nodes": graph_summary.get("nodes"),
            "mission_graph_edges": graph_summary.get("edges"),
            "assessment": self._assessment(coverage_class, los_state, field_region),
        }

    def _assessment(self, coverage_class: Optional[str], los_state: Optional[str], field_region: Optional[str]) -> str:
        parts = []
        if field_region:
            parts.append(f"RF field region: {field_region}")
        if coverage_class:
            parts.append(f"Coverage: {coverage_class}")
        if los_state:
            parts.append(f"LOS/NLOS: {los_state}")
        if not parts:
            return "Scenario evidence generated; no RF detail available in this report."
        return "; ".join(parts)

    def export_html(self, run_id: str) -> str:
        report = self.report(run_id)
        title = f"TRFMC Scenario Evidence Report - {run_id}"

        def section(name: str, data: Any) -> str:
            return f"""
            <section>
              <h2>{escape(name)}</h2>
              <pre>{escape(json.dumps(data, indent=2, ensure_ascii=False, default=str))}</pre>
            </section>
            """

        summary = report.get("executive_summary", {})
        html = f"""<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8"/>
  <title>{escape(title)}</title>
  <style>
    body {{
      margin: 0;
      padding: 28px;
      color: #edf8ff;
      background: #020711;
      font-family: Consolas, monospace;
    }}
    header, section {{
      border: 1px solid rgba(88,214,249,.25);
      background: rgba(5,18,31,.85);
      border-radius: 16px;
      padding: 18px;
      margin-bottom: 16px;
    }}
    h1, h2 {{ color: #58d6f9; }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 10px;
      margin-top: 12px;
    }}
    .kpi {{
      border: 1px solid rgba(255,255,255,.10);
      border-radius: 12px;
      padding: 12px;
      background: rgba(255,255,255,.035);
    }}
    .kpi span {{
      display:block;
      color:#8da4b3;
      font-size:11px;
      text-transform:uppercase;
    }}
    .kpi b {{
      display:block;
      margin-top:8px;
      color:#fff;
      font-size:16px;
    }}
    pre {{
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      background: rgba(0,0,0,.32);
      border: 1px solid rgba(255,255,255,.10);
      border-radius: 12px;
      padding: 12px;
      font-size: 11px;
    }}
  </style>
</head>
<body>
  <header>
    <h1>{escape(title)}</h1>
    <p>Generated: {escape(report.get("timestamp", ""))}</p>
    <div class="grid">
      <div class="kpi"><span>Scenario</span><b>{escape(str(report.get("scenario_id")))}</b></div>
      <div class="kpi"><span>Run ID</span><b>{escape(str(report.get("run_id")))}</b></div>
      <div class="kpi"><span>Correlation ID</span><b>{escape(str(report.get("correlation_id")))}</b></div>
      <div class="kpi"><span>Status</span><b>{escape(str(report.get("status")))}</b></div>
      <div class="kpi"><span>Coverage</span><b>{escape(str(summary.get("coverage_classification")))}</b></div>
      <div class="kpi"><span>LOS State</span><b>{escape(str(summary.get("los_state")))}</b></div>
    </div>
  </header>
  {section("Executive Summary", summary)}
  {section("Scenario Events", report.get("scenario_events"))}
  {section("RF Field Evidence", report.get("evidence", {}).get("rf_field"))}
  {section("RF Coverage Evidence", report.get("evidence", {}).get("rf_coverage"))}
  {section("Network Paths", report.get("evidence", {}).get("network_paths"))}
  {section("CloudEvents", report.get("evidence", {}).get("cloud_events"))}
  {section("Timeline Entries", report.get("evidence", {}).get("timeline_entries"))}
  {section("Mission Graph Summary", report.get("evidence", {}).get("mission_graph_summary"))}
  {section("Persistence", report.get("persistence"))}
</body>
</html>"""
        return html
