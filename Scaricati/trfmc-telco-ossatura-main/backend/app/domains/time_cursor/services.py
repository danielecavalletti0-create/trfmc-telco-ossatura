from app.persistence.repositories import TimeCursorRepository, CloudEventRepository
from app.shared.cloudevents import CloudEvent, ce_type
from app.core.event_bus import event_bus


class TimeCursorService:
    def __init__(self):
        self.repo = TimeCursorRepository()
        self.events = CloudEventRepository()

    def status(self, mission_id: str = "MISSION-FULL-TELCO-BOOT-001"):
        current = self.repo.get(mission_id)

        if not current:
            self.repo.upsert(
                mission_id=mission_id,
                cursor_ms=0,
                data={"reason": "initial_cursor"},
            )
            current = self.repo.get(mission_id)

        return {
            "mission_id": mission_id,
            "cursor_ms": current["cursor_ms"],
            "status": "LOCKED_TO_MISSION_TIMELINE",
            "data": current.get("data", {}),
        }

    async def set_cursor(self, mission_id: str, cursor_ms: int, reason: str):
        self.repo.upsert(
            mission_id=mission_id,
            cursor_ms=cursor_ms,
            data={
                "reason": reason,
                "source": "time_cursor_service",
            },
        )

        event = CloudEvent(
            source="urn:trfmc:global-time-cursor",
            type=ce_type("time_cursor", "updated"),
            subject=mission_id,
            data={
                "mission_id": mission_id,
                "correlation_id": "CORR-GLOBAL-TIME-CURSOR",
                "global_time_cursor_ms": cursor_ms,
                "reason": reason,
            },
        )

        event_dict = event.model_dump(mode="json")
        self.events.append(event_dict)
        await event_bus.broadcast(event_dict)

        return {
            "updated": True,
            "mission_id": mission_id,
            "cursor_ms": cursor_ms,
            "event": event_dict,
        }

    def timeline(self, limit: int = 100):
        return self.events.list(limit=limit)
