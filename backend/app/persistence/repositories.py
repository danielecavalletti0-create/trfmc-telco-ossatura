import json
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.core.database import get_connection, get_db_path


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def as_json(data: Dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, default=str)


def row_to_dict(row) -> Dict[str, Any]:
    d = dict(row)
    for key in list(d.keys()):
        if key.endswith("_json") and d[key]:
            try:
                d[key.replace("_json", "")] = json.loads(d[key])
            except Exception:
                d[key.replace("_json", "")] = d[key]
    return d


class PersistenceRepository:
    def counts(self) -> Dict[str, int]:
        tables = [
            "missions",
            "cloud_events",
            "assets",
            "evidence",
            "device_trust_events",
            "network_paths",
            "incidents",
        ]
        out = {}
        with get_connection() as conn:
            for table in tables:
                out[table] = conn.execute(f"SELECT COUNT(*) AS c FROM {table}").fetchone()["c"]
        return out

    def status(self) -> Dict[str, Any]:
        path = get_db_path()
        return {
            "db_path": str(path),
            "exists": path.exists(),
            "counts": self.counts(),
        }


class MissionRepository:
    def upsert(self, mission_id: str, name: str, mode: str, status: str, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO missions (mission_id, name, mode, status, data_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(mission_id) DO UPDATE SET
                    name=excluded.name,
                    mode=excluded.mode,
                    status=excluded.status,
                    data_json=excluded.data_json,
                    updated_at=excluded.updated_at;
                """,
                (mission_id, name, mode, status, as_json(data), ts, ts),
            )

    def get(self, mission_id: str) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            row = conn.execute("SELECT * FROM missions WHERE mission_id=?", (mission_id,)).fetchone()
            return row_to_dict(row) if row else None

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute("SELECT * FROM missions ORDER BY created_at DESC").fetchall()
            return [row_to_dict(r) for r in rows]


class CloudEventRepository:
    def append(self, event: Dict[str, Any]) -> None:
        data = event.get("data", {})
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT OR IGNORE INTO cloud_events
                (id, specversion, type, source, subject, time, datacontenttype,
                 mission_id, correlation_id, data_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    event["id"],
                    event.get("specversion", "1.0"),
                    event["type"],
                    event["source"],
                    event.get("subject"),
                    str(event["time"]),
                    event.get("datacontenttype", "application/json"),
                    data.get("mission_id"),
                    data.get("correlation_id"),
                    as_json(data),
                    ts,
                ),
            )

    def list(self, limit: int = 100) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM cloud_events ORDER BY time DESC LIMIT ?",
                (limit,),
            ).fetchall()
            return [row_to_dict(r) for r in rows]


class AssetRepository:
    def upsert(self, asset_id: str, asset_type: str, domain: str, status: str, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO assets (asset_id, asset_type, domain, status, data_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(asset_id) DO UPDATE SET
                    asset_type=excluded.asset_type,
                    domain=excluded.domain,
                    status=excluded.status,
                    data_json=excluded.data_json,
                    updated_at=excluded.updated_at;
                """,
                (asset_id, asset_type, domain, status, as_json(data), ts, ts),
            )

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute("SELECT * FROM assets ORDER BY domain, asset_type, asset_id").fetchall()
            return [row_to_dict(r) for r in rows]


class EvidenceRepository:
    def add(self, evidence_id: str, mission_id: str, evidence_type: str, object_ref: str, data: Dict[str, Any], hash_sha256: Optional[str] = None) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO evidence
                (evidence_id, mission_id, evidence_type, object_ref, hash_sha256, data_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                (evidence_id, mission_id, evidence_type, object_ref, hash_sha256, as_json(data), ts),
            )

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute("SELECT * FROM evidence ORDER BY created_at DESC").fetchall()
            return [row_to_dict(r) for r in rows]


class DeviceTrustRepository:
    def add_event(self, event_id: str, device_id: str, trust_domain: str, classification: str, severity: str, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO device_trust_events
                (id, device_id, trust_domain, classification, severity, data_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                (event_id, device_id, trust_domain, classification, severity, as_json(data), ts),
            )

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute("SELECT * FROM device_trust_events ORDER BY created_at DESC").fetchall()
            return [row_to_dict(r) for r in rows]


class NetworkPathRepository:
    def upsert(self, path_id: str, mission_id: str, service_type: str, source_label: str, destination_label: str, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO network_paths
                (path_id, mission_id, service_type, source_label, destination_label, data_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(path_id) DO UPDATE SET
                    data_json=excluded.data_json,
                    updated_at=excluded.updated_at;
                """,
                (path_id, mission_id, service_type, source_label, destination_label, as_json(data), ts, ts),
            )

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute("SELECT * FROM network_paths ORDER BY updated_at DESC").fetchall()
            return [row_to_dict(r) for r in rows]


class IncidentRepository:
    def upsert(self, incident_id: str, mission_id: str, classification: str, severity: str, status: str, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO incidents
                (incident_id, mission_id, classification, severity, status, data_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(incident_id) DO UPDATE SET
                    severity=excluded.severity,
                    status=excluded.status,
                    data_json=excluded.data_json,
                    updated_at=excluded.updated_at;
                """,
                (incident_id, mission_id, classification, severity, status, as_json(data), ts, ts),
            )

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute("SELECT * FROM incidents ORDER BY updated_at DESC").fetchall()
            return [row_to_dict(r) for r in rows]


class TimeCursorRepository:
    def upsert(self, mission_id: str, cursor_ms: int, data: Dict[str, Any]) -> None:
        ts = now_iso()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO time_cursors
                (mission_id, cursor_ms, data_json, updated_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(mission_id) DO UPDATE SET
                    cursor_ms=excluded.cursor_ms,
                    data_json=excluded.data_json,
                    updated_at=excluded.updated_at;
                """,
                (mission_id, cursor_ms, as_json(data), ts),
            )

    def get(self, mission_id: str) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM time_cursors WHERE mission_id=?",
                (mission_id,),
            ).fetchone()
            return row_to_dict(row) if row else None

    def list(self) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM time_cursors ORDER BY updated_at DESC"
            ).fetchall()
            return [row_to_dict(r) for r in rows]
