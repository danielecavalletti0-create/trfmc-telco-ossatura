from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.domains.events.services import EventFabricService
from app.core.event_bus import event_bus

router = APIRouter(prefix="/api/events", tags=["event-fabric"])
service = EventFabricService()


@router.get("/demo")
def demo_events():
    return service.demo_events()


@router.post("/publish-demo")
async def publish_demo_events():
    events = service.persist_demo_events()

    for event in events:
        await event_bus.broadcast(event)

    return {
        "published": len(events),
        "events": events,
    }


@router.websocket("/stream")
async def event_stream(websocket: WebSocket):
    await event_bus.connect(websocket)

    try:
        await websocket.send_json({
            "specversion": "1.0",
            "id": "WS-CONNECTED",
            "source": "urn:trfmc:event-fabric",
            "type": "trfmc.websocket.connected",
            "datacontenttype": "application/json",
            "data": {
                "status": "CONNECTED",
                "message": "TRFMC Event Stream connected"
            }
        })

        while True:
            await websocket.receive_text()

    except WebSocketDisconnect:
        await event_bus.disconnect(websocket)
    except Exception:
        await event_bus.disconnect(websocket)
