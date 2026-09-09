from app.domains.network_fabric.schemas import NetworkPath, NetworkSegment
from app.persistence.repositories import NetworkPathRepository, CloudEventRepository
from app.shared.cloudevents import CloudEvent, ce_type
from app.core.event_bus import event_bus


class GlobalNetworkFabricService:
    destinations = {
        "New York": ("USA", 65.0, "IPX/peering + transatlantic submarine path"),
        "Sydney": ("Australia", 210.0, "Asia-Pacific long-haul / submarine path"),
        "Pechino": ("China", 145.0, "Eurasia / international carrier path"),
        "Mumbai": ("India", 110.0, "Middle-East / India transit path"),
        "Jakarta": ("Indonesia", 155.0, "South-East Asia transit path"),
        "Beirut": ("Lebanon", 75.0, "Mediterranean / Middle-East transit path"),
        "Il Cairo": ("Egypt", 60.0, "Mediterranean / North Africa path"),
        "Stoccolma": ("Sweden", 45.0, "European backbone path"),
        "Buenos Aires": ("Argentina", 180.0, "South Atlantic / Americas transit path"),
    }

    def build_path(self, destination_city: str = "New York") -> NetworkPath:
        country, gwan_latency, gwan_notes = self.destinations.get(
            destination_city,
            ("UNKNOWN", 120.0, "generic international path"),
        )

        segments = [
            NetworkSegment(
                segment_id="SEG-001-RAN",
                sequence=1,
                type="RADIO_ACCESS",
                source="UE_REMOTE",
                destination="CELL-N78-A",
                source_asset_id="UE-REMOTE-001",
                target_asset_id="CELL-N78-A",
                latency_ms=8,
                jitter_ms=1,
                packet_loss_percent=0.02,
                qos_class="5QI_1_VOICE",
                status="NOMINAL",
                notes="UE attached to simulated 5G NR n78 cell.",
            ),
            NetworkSegment(
                segment_id="SEG-002-GNB-SITE",
                sequence=2,
                type="RAN_SITE",
                source="CELL-N78-A",
                destination="GNB-REMOTE-001",
                source_asset_id="CELL-N78-A",
                target_asset_id="GNB-REMOTE-001",
                latency_ms=4,
                jitter_ms=1,
                packet_loss_percent=0.01,
                qos_class="5QI_1_VOICE",
                status="NOMINAL",
                notes="Cell to gNB processing and site handoff.",
            ),
            NetworkSegment(
                segment_id="SEG-003-BACKHAUL",
                sequence=3,
                type="MICROWAVE_OR_SAT_BACKHAUL",
                source="SITE-REMOTE-001",
                destination="POP-REGIONAL-001",
                source_asset_id="MW-LINK-REMOTE-REGIONAL",
                target_asset_id="POP-REGIONAL-001",
                latency_ms=18,
                jitter_ms=4,
                packet_loss_percent=0.05,
                capacity_mbps=300,
                utilization_percent=44,
                qos_class="EXPEDITED_FORWARDING",
                status="NOMINAL",
                notes="Remote site backhaul toward regional PoP.",
            ),
            NetworkSegment(
                segment_id="SEG-004-REGIONAL",
                sequence=4,
                type="REGIONAL_AGGREGATION",
                source="POP-REGIONAL-001",
                destination="CORE-5GC-001",
                source_asset_id="POP-REGIONAL-001",
                target_asset_id="CORE-5GC-001",
                latency_ms=10,
                jitter_ms=1,
                packet_loss_percent=0.01,
                capacity_mbps=10000,
                utilization_percent=38,
                qos_class="MPLS_TC_VOICE",
                status="NOMINAL",
                notes="Regional IP/MPLS/SRv6-ready aggregation.",
            ),
            NetworkSegment(
                segment_id="SEG-005-CORE-IMS",
                sequence=5,
                type="NATIONAL_5GC_IMS",
                source="CORE-5GC-001",
                destination="IMS-SBC-001",
                source_asset_id="CORE-5GC-001",
                target_asset_id="IMS-SBC-001",
                latency_ms=12,
                jitter_ms=1,
                packet_loss_percent=0.01,
                qos_class="IMS_VOICE",
                status="NOMINAL",
                notes="5GC to IMS/SBC voice service boundary.",
            ),
            NetworkSegment(
                segment_id="SEG-006-GWAN",
                sequence=6,
                type="GWAN_IPX_PEERING_SUBMARINE_OR_SAT",
                source="IMS-SBC-001",
                destination=f"REMOTE_OPERATOR_{destination_city.upper().replace(' ', '_')}",
                source_asset_id="IMS-SBC-001",
                target_asset_id="GWAN-TRANSATLANTIC-001",
                latency_ms=gwan_latency,
                jitter_ms=max(4, gwan_latency * 0.08),
                packet_loss_percent=0.08,
                capacity_mbps=None,
                utilization_percent=None,
                qos_class="INTERCONNECT_QOS_DEPENDENT",
                status="NOMINAL" if gwan_latency < 180 else "DEGRADED",
                notes=gwan_notes,
            ),
        ]

        one_way = sum(s.latency_ms for s in segments)
        rtt = 2 * one_way
        mos = 4.3 if rtt < 180 else 3.7 if rtt < 350 else 3.1
        dominant = max(segments, key=lambda s: s.latency_ms).segment_id

        return NetworkPath(
            path_id=f"PATH-REMOTE-UE-{destination_city.upper().replace(' ', '-')}",
            mission_id="MISSION-GLOBAL-SERVICE-JOURNEY-001",
            service_type="VoNR",
            source="Remote UE / desert or rural site",
            destination_city=destination_city,
            destination_country=country,
            destination_label=f"{destination_city}, {country}",
            path_layers=[
                "device",
                "radio_access",
                "site",
                "backhaul",
                "regional_transport",
                "5gc",
                "ims_sbc",
                "gwan",
                "remote_operator",
            ],
            segments=segments,
            estimated_rtt_ms=rtt,
            mos_estimate=mos,
            dominant_latency_segment=dominant,
            security_context={
                "sbc_boundary": "IMS-SBC-001",
                "restricted": False,
                "privacy_relevance": "voice metadata and service path",
                "notes": "Security context placeholder for SBC, IPX/GRX, peering, route leak and DDoS correlation.",
            },
            qos_context={
                "service_class": "VOICE",
                "five_qi": 1,
                "dscp": "EF",
                "mapping": "5QI/QCI → DSCP → MPLS/SRv6 TC → interconnect policy",
            },
        )

    def overview(self):
        return {
            "mission_id": "MISSION-GLOBAL-SERVICE-JOURNEY-001",
            "paths": [
                self.build_path(destination).model_dump(mode="json")
                for destination in self.destinations.keys()
            ],
        }

    def list_persisted_paths(self):
        return NetworkPathRepository().list()

    async def persist_path(self, destination_city: str = "New York"):
        path = self.build_path(destination_city)
        payload = path.model_dump(mode="json")

        NetworkPathRepository().upsert(
            path_id=path.path_id,
            mission_id=path.mission_id,
            service_type=path.service_type,
            source_label=path.source,
            destination_label=path.destination_label,
            data=payload,
        )

        event = CloudEvent(
            source="urn:trfmc:network-fabric",
            type=ce_type("network_fabric", "journey_persisted"),
            subject=path.path_id,
            data={
                "mission_id": path.mission_id,
                "correlation_id": f"CORR-{path.path_id}",
                "path_id": path.path_id,
                "destination": path.destination_label,
                "estimated_rtt_ms": path.estimated_rtt_ms,
                "mos_estimate": path.mos_estimate,
                "dominant_latency_segment": path.dominant_latency_segment,
                "global_time_cursor_ms": 0,
            },
        )

        event_dict = event.model_dump(mode="json")
        CloudEventRepository().append(event_dict)
        await event_bus.broadcast(event_dict)

        return {
            "persisted": True,
            "path": payload,
            "event": event_dict,
        }

    async def persist_all_demo_paths(self):
        out = []
        for destination in self.destinations.keys():
            out.append(await self.persist_path(destination))
        return {
            "persisted": len(out),
            "items": out,
        }
