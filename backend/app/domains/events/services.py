from app.shared.cloudevents import CloudEvent, ce_type
class EventFabricService:
    def demo_events(self):
        return [
            CloudEvent(source="urn:trfmc:mission-orchestrator", type=ce_type("mission", "started"), subject="MISSION-FULL-TELCO-BOOT-001", data={"status":"RUNNING"}),
            CloudEvent(source="urn:trfmc:network-fabric", type=ce_type("network", "path_ready"), subject="PATH-REMOTE-UE-NEW-YORK", data={"service":"VoNR","destination":"New York"}),
            CloudEvent(source="urn:trfmc:access-trust", type=ce_type("access_trust", "watch_ready"), subject="DEVICE-TRUST", data={"rat_defense":"READY","wifi_trust":"READY"}),
        ]
