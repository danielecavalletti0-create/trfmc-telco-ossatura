from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from app.domains.core_network.services import CoreNetworkService
from app.hardware.streaming import core_network_stream_bridge

router = APIRouter(prefix="/api/core-network", tags=["CoreNetwork"])
service = CoreNetworkService()


class CoreNetworkStreamRequest(BaseModel):
    sample_rate_hz: float = 12_000_000.0
    frame_rate_hz: float = 20.0
    center_frequency_hz: float = 3.5e9
    bandwidth_hz: float = 40_000_000.0
    channel_count: int = 2
    metadata: dict = {}


@router.get("/status")
def status():
    return service.get_status()


@router.post("/configure")
def configure(payload: dict):
    return {"ok": True, "config": service.configure(payload)}


@router.post("/stream/negotiate")
def negotiate_stream(request: CoreNetworkStreamRequest):
    negotiated = core_network_stream_bridge.negotiate(request.dict())
    return {"ok": True, "negotiated": negotiated}


@router.websocket("/ws/telemetry")
async def tcp_telemetry(websocket: WebSocket):
    await websocket.accept()
    try:
        await core_network_stream_bridge.event_bus.connect(websocket)
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await core_network_stream_bridge.event_bus.disconnect(websocket)
