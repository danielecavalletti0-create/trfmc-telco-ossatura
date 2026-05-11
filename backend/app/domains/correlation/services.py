from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

from app.domains.timeline.services import TimelineService
from app.persistence.repositories import (
    AssetRepository,
    AssetLinkRepository,
    IncidentRepository,
    NetworkPathRepository,
    PersistenceRepository,
)


class CorrelationService:
    service_name = "TRFMC_CORRELATION_ENGINE_MISSION_GRAPH_V0_15"

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def severity_rank(self, sev: Optional[str]) -> int:
        order = {
            "INFO": 1,
            "NOTICE": 2,
            "LOW": 2,
            "MEDIUM": 3,
            "WARNING": 3,
            "HIGH": 4,
            "CRITICAL": 5,
        }
        return order.get(str(sev or "INFO").upper(), 1)

    def merge_severity(self, a: Optional[str], b: Optional[str]) -> str:
        aa = str(a or "INFO").upper()
        bb = str(b or "INFO").upper()
        return aa if self.severity_rank(aa) >= self.severity_rank(bb) else bb

    def node(
        self,
        node_id: str,
        label: str,
        node_type: str,
        domain: str,
        severity: str = "INFO",
        status: str = "NOMINAL",
        data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        return {
            "id": node_id,
            "label": label,
            "type": node_type,
            "domain": domain,
            "severity": severity,
            "status": status,
            "data": data or {},
        }

    def edge(
        self,
        source: str,
        target: str,
        relation: str,
        severity: str = "INFO",
        data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        return {
            "id": f"{source}::{relation}::{target}",
            "source": source,
            "target": target,
            "relation": relation,
            "severity": severity,
            "data": data or {},
        }

    def add_node(self, nodes: Dict[str, Dict[str, Any]], new_node: Dict[str, Any]) -> None:
        node_id = new_node["id"]
        if node_id not in nodes:
            nodes[node_id] = new_node
            return

        existing = nodes[node_id]
        existing["severity"] = self.merge_severity(existing.get("severity"), new_node.get("severity"))
        existing["data"].update(new_node.get("data", {}))

    def add_edge(self, edges: Dict[str, Dict[str, Any]], new_edge: Dict[str, Any]) -> None:
        edge_id = new_edge["id"]
        if edge_id not in edges:
            edges[edge_id] = new_edge
            return

        existing = edges[edge_id]
        existing["severity"] = self.merge_severity(existing.get("severity"), new_edge.get("severity"))
        existing["data"].update(new_edge.get("data", {}))

    def build_graph(self, mission_id: str = "MISSION-FULL-TELCO-BOOT-001", limit: int = 500) -> Dict[str, Any]:
        timeline = TimelineService().timeline(mission_id=mission_id, limit=limit)
        persistence = PersistenceRepository().status()

        nodes: Dict[str, Dict[str, Any]] = {}
        edges: Dict[str, Dict[str, Any]] = {}

        mission_node_id = f"MISSION::{mission_id}"
        self.add_node(nodes, self.node(
            node_id=mission_node_id,
            label=mission_id,
            node_type="MISSION",
            domain="mission",
            severity="INFO",
            status="ACTIVE",
            data={"mission_id": mission_id},
        ))

        # Asset nodes
        assets = []
        try:
            assets = AssetRepository().list()
        except Exception:
            assets = []

        for asset in assets:
            asset_id = asset.get("asset_id")
            if not asset_id:
                continue
            self.add_node(nodes, self.node(
                node_id=f"ASSET::{asset_id}",
                label=asset_id,
                node_type=asset.get("asset_type", "ASSET"),
                domain=asset.get("domain", "asset"),
                severity="INFO",
                status=asset.get("status", "UNKNOWN"),
                data=asset,
            ))
            self.add_edge(edges, self.edge(
                source=mission_node_id,
                target=f"ASSET::{asset_id}",
                relation="HAS_ASSET",
                severity="INFO",
            ))

        # Asset topology links
        links = []
        try:
            links = AssetLinkRepository().list()
        except Exception:
            links = []

        for link in links:
            src = link.get("source_asset_id")
            dst = link.get("target_asset_id")
            if src and dst:
                self.add_edge(edges, self.edge(
                    source=f"ASSET::{src}",
                    target=f"ASSET::{dst}",
                    relation=link.get("relation_type", "LINKED_TO"),
                    severity="INFO",
                    data=link,
                ))

        # Timeline evidence nodes
        previous_entry_node_id = None
        for entry in reversed(timeline.get("entries", [])):
            entry_id = self._entry_node_id(entry)
            severity = str(entry.get("severity", "INFO")).upper()
            entry_type = entry.get("entry_type", "EVIDENCE")

            self.add_node(nodes, self.node(
                node_id=entry_id,
                label=entry.get("title", entry_type),
                node_type=entry_type,
                domain=self._domain_for_entry(entry_type),
                severity=severity,
                status="OBSERVED",
                data={
                    "timestamp": entry.get("timestamp"),
                    "correlation_id": entry.get("correlation_id"),
                    "asset_refs": entry.get("asset_refs", []),
                    "source": entry.get("source"),
                    "summary": entry.get("data", {}),
                },
            ))

            self.add_edge(edges, self.edge(
                source=mission_node_id,
                target=entry_id,
                relation="HAS_EVIDENCE",
                severity=severity,
                data={"timestamp": entry.get("timestamp")},
            ))

            if previous_entry_node_id:
                self.add_edge(edges, self.edge(
                    source=previous_entry_node_id,
                    target=entry_id,
                    relation="NEXT_IN_TIMELINE",
                    severity="INFO",
                    data={"mission_id": mission_id},
                ))
            previous_entry_node_id = entry_id

            corr = entry.get("correlation_id")
            if corr:
                corr_id = f"CORRELATION::{corr}"
                self.add_node(nodes, self.node(
                    node_id=corr_id,
                    label=corr,
                    node_type="CORRELATION_ID",
                    domain="correlation",
                    severity=severity,
                    status="ACTIVE",
                    data={"correlation_id": corr},
                ))
                self.add_edge(edges, self.edge(
                    source=corr_id,
                    target=entry_id,
                    relation="CORRELATES",
                    severity=severity,
                ))
                self.add_edge(edges, self.edge(
                    source=mission_node_id,
                    target=corr_id,
                    relation="HAS_CORRELATION",
                    severity=severity,
                ))

            for asset_ref in entry.get("asset_refs", []):
                asset_node_id = f"ASSET::{asset_ref}"
                if asset_node_id not in nodes:
                    self.add_node(nodes, self.node(
                        node_id=asset_node_id,
                        label=asset_ref,
                        node_type="ASSET_REF",
                        domain="asset",
                        severity=severity,
                        status="REFERENCED",
                        data={"asset_id": asset_ref, "inferred": True},
                    ))
                self.add_edge(edges, self.edge(
                    source=entry_id,
                    target=asset_node_id,
                    relation="INVOLVES_ASSET",
                    severity=severity,
                ))

        # Network path summary nodes
        network_paths = []
        try:
            network_paths = NetworkPathRepository().list()
        except Exception:
            network_paths = []

        for path in network_paths:
            path_id = path.get("path_id")
            if not path_id:
                continue
            node_id = f"NETWORK_PATH::{path_id}"
            self.add_node(nodes, self.node(
                node_id=node_id,
                label=path.get("destination_label", path_id),
                node_type="NETWORK_PATH",
                domain="network",
                severity="INFO",
                status="OBSERVED",
                data=path,
            ))
            self.add_edge(edges, self.edge(
                source=mission_node_id,
                target=node_id,
                relation="HAS_NETWORK_PATH",
                severity="INFO",
            ))

        graph = {
            "service": self.service_name,
            "timestamp": self.now(),
            "mission_id": mission_id,
            "persistence": persistence,
            "summary": {
                "nodes": len(nodes),
                "edges": len(edges),
                "timeline_entries": timeline.get("count", 0),
                "asset_nodes": sum(1 for n in nodes.values() if str(n.get("id", "")).startswith("ASSET::")),
                "correlation_nodes": sum(1 for n in nodes.values() if str(n.get("id", "")).startswith("CORRELATION::")),
                "critical_or_warning": sum(1 for n in nodes.values() if self.severity_rank(n.get("severity")) >= 3),
            },
            "nodes": list(nodes.values()),
            "edges": list(edges.values()),
        }
        return graph

    def asset_view(self, asset_id: str, mission_id: str = "MISSION-FULL-TELCO-BOOT-001") -> Dict[str, Any]:
        graph = self.build_graph(mission_id=mission_id, limit=1000)
        node_id = f"ASSET::{asset_id}"

        related_edges = [
            e for e in graph["edges"]
            if e.get("source") == node_id or e.get("target") == node_id
        ]

        related_node_ids: Set[str] = {node_id}
        for e in related_edges:
            related_node_ids.add(e["source"])
            related_node_ids.add(e["target"])

        related_nodes = [n for n in graph["nodes"] if n.get("id") in related_node_ids]

        evidence_edges = [
            e for e in graph["edges"]
            if e.get("target") == node_id and e.get("relation") == "INVOLVES_ASSET"
        ]
        evidence_node_ids = {e["source"] for e in evidence_edges}
        evidence_nodes = [n for n in graph["nodes"] if n.get("id") in evidence_node_ids]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "mission_id": mission_id,
            "asset_id": asset_id,
            "asset_node": next((n for n in graph["nodes"] if n.get("id") == node_id), None),
            "related_nodes": related_nodes,
            "related_edges": related_edges,
            "evidence_nodes": evidence_nodes,
            "summary": {
                "related_nodes": len(related_nodes),
                "related_edges": len(related_edges),
                "evidence_nodes": len(evidence_nodes),
            },
        }

    def incidents(self, mission_id: str = "MISSION-FULL-TELCO-BOOT-001") -> Dict[str, Any]:
        graph = self.build_graph(mission_id=mission_id, limit=1000)
        incident_nodes = [
            n for n in graph["nodes"]
            if n.get("type") == "INCIDENT" or "INCIDENT" in str(n.get("id", ""))
        ]

        high_severity = [
            n for n in graph["nodes"]
            if self.severity_rank(n.get("severity")) >= 3
        ]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "mission_id": mission_id,
            "incident_nodes": incident_nodes,
            "high_severity_nodes": high_severity,
            "summary": {
                "incident_nodes": len(incident_nodes),
                "high_severity_nodes": len(high_severity),
            },
        }

    def _entry_node_id(self, entry: Dict[str, Any]) -> str:
        entry_type = entry.get("entry_type", "EVIDENCE")
        data = entry.get("data", {}) or {}

        run_id = data.get("run_id")
        if run_id:
            return f"{entry_type}::{run_id}"

        corr = entry.get("correlation_id")
        ts = entry.get("timestamp", self.now())
        title = entry.get("title", entry_type)
        return f"{entry_type}::{corr or title}::{ts}"

    def _domain_for_entry(self, entry_type: str) -> str:
        if entry_type.startswith("RF_"):
            return "rf"
        if entry_type == "NETWORK_PATH":
            return "network"
        if entry_type == "INCIDENT":
            return "soc"
        if entry_type == "CLOUDEVENT":
            return "events"
        return "evidence"
