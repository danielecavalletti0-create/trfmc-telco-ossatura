from app.shared.cloudevents import CloudEvent, ce_type
from app.persistence.repositories import CloudEventRepository


class EventFabricService:
    def demo_events(self):
        return [
            CloudEvent(
                source="urn:trfmc:mission-orchestrator",
                type=ce_type("mission", "started"),
                subject="MISSION-FULL-TELCO-BOOT-001",
                data={
                    "mission_id": "MISSION-FULL-TELCO-BOOT-001",
                    "correlation_id": "CORR-BOOT-001",
                    "status": "RUNNING",
                    "global_time_cursor_ms": 0,
                },
            ),
            CloudEvent(
                source="urn:trfmc:network-fabric",
                type=ce_type("network", "path_ready"),
                subject="PATH-REMOTE-UE-NEW-YORK",
                data={
                    "mission_id": "MISSION-GLOBAL-SERVICE-JOURNEY-001",
                    "correlation_id": "CORR-GLOBAL-CALL-001",
                    "service": "VoNR",
                    "destination": "New York",
                    "global_time_cursor_ms": 1200,
                },
            ),
            CloudEvent(
                source="urn:trfmc:access-trust",
                type=ce_type("access_trust", "rat_wifi_watch_ready"),
                subject="DEVICE-TRUST",
                data={
                    "mission_id": "MISSION-FULL-TELCO-BOOT-001",
                    "correlation_id": "CORR-ACCESS-TRUST-001",
                    "rat_defense": "READY",
                    "wifi_trust": "READY",
                    "global_time_cursor_ms": 1800,
                },
            ),
        ]

    def persist_demo_events(self):
        repo = CloudEventRepository()
        events = self.demo_events()

        serialized = []
        for event in events:
            event_dict = event.model_dump(mode="json")
            repo.append(event_dict)
            serialized.append(event_dict)

        return serialized
