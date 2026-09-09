from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from app.domains.autonomous_vehicles.services import AutonomousVehicleService
from app.hardware.streaming import autonomous_vehicles_stream_bridge

router = APIRouter(prefix="/api/autonomous-vehicles", tags=["AutonomousVehicles"])
service = AutonomousVehicleService()


class AutonomousVehiclesStreamRequest(BaseModel):
    sample_rate_hz: float = 14_000_000.0
    frame_rate_hz: float = 25.0
    center_frequency_hz: float = 5.8e9
    bandwidth_hz: float = 50_000_000.0
    channel_count: int = 2
    metadata: dict = {}


@router.get("/status")
def status():
    return service.get_status()


@router.post("/configure")
def configure(payload: dict):
    return {"ok": True, "config": service.configure(payload)}


@router.post("/stream/negotiate")
def negotiate_stream(request: AutonomousVehiclesStreamRequest):
    negotiated = autonomous_vehicles_stream_bridge.negotiate(request.dict())
    return {"ok": True, "negotiated": negotiated}


@router.websocket("/ws/telemetry")
async def tcp_telemetry(websocket: WebSocket):
    await websocket.accept()
    try:
        await autonomous_vehicles_stream_bridge.event_bus.connect(websocket)
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await autonomous_vehicles_stream_bridge.event_bus.disconnect(websocket)
