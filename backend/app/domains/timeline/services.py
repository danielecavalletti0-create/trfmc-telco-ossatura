from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.persistence.repositories import (
    PersistenceRepository,
    CloudEventRepository,
    RfCoverageRunRepository,
    RfFieldRunRepository,
    NetworkPathRepository,
    IncidentRepository,
    AssetRepository,
    TimeCursorRepository,
)


class TimelineService:
    service_name = "TRFMC_EVIDENCE_TIMELINE_MISSION_REPLAY_V0_14"

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def safe_list(self, fn):
        try:
            return fn()
        except Exception:
            return []

    def _entry(
        self,
        ts: str,
        entry_type: str,
        title: str,
        source: str,
        mission_id: Optional[str],
        correlation_id: Optional[str],
        asset_refs: List[str],
        severity: str,
        data: Dict[str, Any],
    ) -> Dict[str, Any]:
        return {
            "timestamp": ts,
            "entry_type": entry_type,
            "title": title,
            "source": source,
            "mission_id": mission_id,
            "correlation_id": correlation_id,
            "asset_refs": sorted(list(set([x for x in asset_refs if x]))),
            "severity": severity,
            "data": data,
        }

    def _ts(self, row: Dict[str, Any]) -> str:
        return (
            row.get("time")
            or row.get("created_at")
            or row.get("updated_at")
            or self.now()
        )

    def _event_entries(self) -> List[Dict[str, Any]]:
        rows = self.safe_list(lambda: CloudEventRepository().list(limit=500))
        out = []

        for ev in rows:
            data = ev.get("data") or {}
            refs = [
                ev.get("subject"),
                data.get("cell_asset_id"),
                data.get("target_asset_id"),
                data.get("asset_id"),
                data.get("source_asset_id"),
                data.get("target_asset_id"),
            ]

            out.append(self._entry(
                ts=self._ts(ev),
                entry_type="CLOUDEVENT",
                title=ev.get("type", "cloud_event"),
                source=ev.get("source", "unknown"),
                mission_id=ev.get("mission_id") or data.get("mission_id"),
                correlation_id=ev.get("correlation_id") or data.get("correlation_id"),
                asset_refs=refs,
                severity="INFO",
                data=ev,
            ))

        return out

    def _rf_field_entries(self) -> List[Dict[str, Any]]:
        rows = self.safe_list(lambda: RfFieldRunRepository().list(limit=200))
        out = []

        for row in rows:
            data = row.get("data") or {}
            field = data.get("field_at_target", {})
            ant = data.get("antenna", {})

            out.append(self._entry(
                ts=self._ts(row),
                entry_type="RF_FIELD_RUN",
                title=f"RF Field {row.get('run_id')}",
                source="urn:trfmc:rf-field",
                mission_id=row.get("mission_id") or data.get("mission_id"),
                correlation_id=f"CORR-{row.get('run_id')}",
                asset_refs=[
                    row.get("cell_asset_id"),
                    row.get("target_asset_id"),
                    data.get("cell_asset_id"),
                    data.get("target_asset_id"),
                ],
                severity="INFO" if field.get("field_region") == "FAR_FIELD" else "NOTICE",
                data={
                    "run_id": row.get("run_id"),
                    "model_name": row.get("model_name"),
                    "frequency_hz": row.get("frequency_hz"),
                    "field_region": field.get("field_region"),
                    "distance_m": field.get("distance_m"),
                    "electric_field_v_m": field.get("electric_field_v_m"),
                    "magnetic_field_a_m": field.get("magnetic_field_a_m"),
                    "poynting_w_m2": field.get("poynting_w_m2"),
                    "gain_to_target_dbi": ant.get("gain_to_target_dbi"),
                    "full": row,
                },
            ))

        return out

    def _rf_coverage_entries(self) -> List[Dict[str, Any]]:
        rows = self.safe_list(lambda: RfCoverageRunRepository().list(limit=200))
        out = []

        for row in rows:
            data = row.get("data") or {}
            link = data.get("target_link", {})
            summary = data.get("summary", {})

            severity = "INFO"
            classification = link.get("classification") or summary.get("target_classification")
            if classification in ("CRITICAL", "DEGRADED"):
                severity = "WARNING"

            out.append(self._entry(
                ts=self._ts(row),
                entry_type="RF_COVERAGE_RUN",
                title=f"RF Coverage {row.get('run_id')}",
                source="urn:trfmc:rf-coverage",
                mission_id=row.get("mission_id") or data.get("mission_id"),
                correlation_id=f"CORR-{row.get('run_id')}",
                asset_refs=[
                    row.get("cell_asset_id"),
                    row.get("target_asset_id"),
                    data.get("cell_asset_id"),
                    link.get("target_asset_id"),
                ],
                severity=severity,
                data={
                    "run_id": row.get("run_id"),
                    "model_name": row.get("model_name"),
                    "frequency_hz": row.get("frequency_hz"),
                    "target_classification": classification,
                    "los_state": link.get("los_state") or summary.get("target_los_state"),
                    "snr_db": link.get("snr_db"),
                    "rx_power_dbm": link.get("rx_power_dbm"),
                    "obstacle_hits": link.get("obstacle_hits"),
                    "nlos_points": summary.get("nlos_points"),
                    "full": row,
                },
            ))

        return out

    def _network_entries(self) -> List[Dict[str, Any]]:
        rows = self.safe_list(lambda: NetworkPathRepository().list())
        out = []

        for row in rows:
            data = row.get("data") or {}
            out.append(self._entry(
                ts=self._ts(row),
                entry_type="NETWORK_PATH",
                title=f"Network path {row.get('destination_label')}",
                source="urn:trfmc:network-fabric",
                mission_id=row.get("mission_id") or data.get("mission_id"),
                correlation_id=data.get("correlation_id"),
                asset_refs=[
                    data.get("source_asset_id"),
                    data.get("target_asset_id"),
                    data.get("cell_asset_id"),
                    data.get("core_asset_id"),
                ],
                severity="INFO",
                data={
                    "path_id": row.get("path_id"),
                    "service_type": row.get("service_type"),
                    "source_label": row.get("source_label"),
                    "destination_label": row.get("destination_label"),
                    "estimated_rtt_ms": data.get("estimated_rtt_ms"),
                    "mos_estimate": data.get("mos_estimate"),
                    "dominant_latency_segment": data.get("dominant_latency_segment"),
                    "full": row,
                },
            ))

        return out

    def _incident_entries(self) -> List[Dict[str, Any]]:
        rows = self.safe_list(lambda: IncidentRepository().list())
        out = []

        for row in rows:
            data = row.get("data") or {}
            out.append(self._entry(
                ts=self._ts(row),
                entry_type="INCIDENT",
                title=f"Incident {row.get('incident_id')}",
                source="urn:trfmc:soc-noc",
                mission_id=row.get("mission_id") or data.get("mission_id"),
                correlation_id=data.get("correlation_id"),
                asset_refs=data.get("asset_refs", []) if isinstance(data.get("asset_refs"), list) else [],
                severity=row.get("severity", "INFO"),
                data=row,
            ))

        return out

    def timeline(self, mission_id: Optional[str] = None, limit: int = 300) -> Dict[str, Any]:
        entries = []
        entries.extend(self._event_entries())
        entries.extend(self._rf_field_entries())
        entries.extend(self._rf_coverage_entries())
        entries.extend(self._network_entries())
        entries.extend(self._incident_entries())

        if mission_id:
            entries = [e for e in entries if e.get("mission_id") == mission_id]

        entries.sort(key=lambda x: x.get("timestamp") or "", reverse=True)
        entries = entries[:limit]

        counts = {}
        for e in entries:
            counts[e["entry_type"]] = counts.get(e["entry_type"], 0) + 1

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "mission_id": mission_id,
            "count": len(entries),
            "entry_type_counts": counts,
            "entries": entries,
        }

    def correlation(self, correlation_id: str) -> Dict[str, Any]:
        tl = self.timeline(limit=1000)
        entries = [e for e in tl["entries"] if e.get("correlation_id") == correlation_id]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "correlation_id": correlation_id,
            "count": len(entries),
            "entries": entries,
        }

    def replay(self, mission_id: str = "MISSION-FULL-TELCO-BOOT-001") -> Dict[str, Any]:
        tl = self.timeline(mission_id=mission_id, limit=1000)
        entries = list(reversed(tl["entries"]))

        time_cursor = None
        try:
            time_cursor = TimeCursorRepository().get(mission_id)
        except Exception:
            time_cursor = None

        assets = self.safe_list(lambda: AssetRepository().list())
        persistence = PersistenceRepository().status()

        replay_steps = []
        for idx, e in enumerate(entries, start=1):
            replay_steps.append({
                "step": idx,
                "timestamp": e["timestamp"],
                "entry_type": e["entry_type"],
                "title": e["title"],
                "correlation_id": e.get("correlation_id"),
                "asset_refs": e.get("asset_refs", []),
                "severity": e.get("severity"),
                "action": self._suggested_action(e),
            })

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "mission_id": mission_id,
            "time_cursor": time_cursor,
            "persistence": persistence,
            "asset_count": len(assets),
            "replay_count": len(replay_steps),
            "replay_steps": replay_steps,
        }

    def _suggested_action(self, entry: Dict[str, Any]) -> str:
        t = entry.get("entry_type")
        if t == "RF_FIELD_RUN":
            return "Render E/H/Poynting and antenna/fresnel state at this timestamp."
        if t == "RF_COVERAGE_RUN":
            return "Render coverage grid, LOS/NLOS and link budget at this timestamp."
        if t == "NETWORK_PATH":
            return "Render network path and transport/service latency context."
        if t == "INCIDENT":
            return "Render SOC/NOC incident card and affected assets."
        if t == "CLOUDEVENT":
            return "Replay event payload and correlation context."
        return "Replay evidence entry."
