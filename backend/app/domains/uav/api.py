from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from app.domains.uav.services import UAVService
from app.hardware.streaming import uav_stream_bridge

router = APIRouter(prefix="/api/uav", tags=["UAV"])
service = UAVService()


class UAVStreamRequest(BaseModel):
    sample_rate_hz: float = 10_000_000.0
    frame_rate_hz: float = 15.0
    center_frequency_hz: float = 2.4e9
    bandwidth_hz: float = 20_000_000.0
    channel_count: int = 1
    metadata: dict = {}


@router.get("/status")
def status():
    return service.get_status()


@router.post("/configure")
def configure(payload: dict):
    return {"ok": True, "config": service.configure(payload)}


@router.post("/stream/negotiate")
def negotiate_stream(request: UAVStreamRequest):
    negotiated = uav_stream_bridge.negotiate(request.dict())
    return {"ok": True, "negotiated": negotiated}


@router.websocket("/ws/telemetry")
async def tcp_telemetry(websocket: WebSocket):
    await websocket.accept()
    try:
        await uav_stream_bridge.event_bus.connect(websocket)
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await uav_stream_bridge.event_bus.disconnect(websocket)
