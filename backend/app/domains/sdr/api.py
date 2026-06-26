"""
SDR I/Q stream router.

The I/Q pipeline is driven by SimulatedIQDriver coupled to sdr_stream_bridge
via StreamingPipeline.  The pipeline starts and stops with the router's
lifespan; register via app.include_router(router) in main.py.

LegacyPayloadWSAdapter translates the bridge's flat event format to the
nested payload schema expected by the existing frontend contract.
"""
from __future__ import annotations

import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import APIRouter, WebSocket

from app.core.event_bus import event_bus as _global_event_bus
from app.hardware.adapters.SimulatedIQDriver import ModulationScheme, SimulatedIQDriver
from app.hardware.pipeline import StreamingPipeline
from app.hardware.streaming import IWebSocketConnection, StreamConfig, StreamingBridge

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Legacy payload adapter
# ---------------------------------------------------------------------------


class LegacyPayloadWSAdapter:
    """
    Translates the bridge's flat IQ event to the legacy nested payload format
    expected by the existing frontend contract.

    Bridge flat (NamespacedBus.broadcast output):
        {"type": "iq_frame", "source": "sdr", "seq": <int>,
         "timestamp_ns": <int>, "sample_rate_hz": <float>,
         "frame_size": <int>, "i": [...], "q": [...], ...}

    Legacy nested (preserved for frontend):
        {"type": "iq_frame",
         "payload": {"seq": <int>, "time": <float>,
                     "sample_rate": <float>, "frame_size": <int>,
                     "i": [...], "q": [...]}}

    All non-iq_frame messages are forwarded unchanged.
    """

    def __init__(self, websocket: WebSocket) -> None:
        self._ws: WebSocket = websocket

    async def accept(self) -> None:
        await self._ws.accept()

    async def receive_text(self) -> str:
        return await self._ws.receive_text()

    async def send_json(self, data: object) -> None:
        if isinstance(data, dict) and data.get("type") == "iq_frame":
            timestamp_ns_raw = data.get("timestamp_ns")
            time_s: float
            if isinstance(timestamp_ns_raw, (int, float)) and not isinstance(
                timestamp_ns_raw, bool
            ):
                time_s = float(timestamp_ns_raw) / 1_000_000_000.0
            else:
                time_s = 0.0

            inner: dict[str, object] = {
                "seq": data.get("seq"),
                "time": time_s,
                "sample_rate": data.get("sample_rate_hz"),
                "frame_size": data.get("frame_size"),
                "i": data.get("i"),
                "q": data.get("q"),
            }
            legacy: dict[str, object] = {"type": "iq_frame", "payload": inner}
            await self._ws.send_json(legacy)
        else:
            await self._ws.send_json(data)

    async def close(self, code: int = 1000) -> None:
        await self._ws.close(code)


# ---------------------------------------------------------------------------
# Module-level singletons
# ---------------------------------------------------------------------------

sdr_stream_bridge: StreamingBridge = StreamingBridge(
    "sdr",
    event_bus=_global_event_bus,
    config=StreamConfig(
        sample_rate_hz=48_000.0,
        frame_rate_hz=187.5,
        center_frequency_hz=0.0,
        bandwidth_hz=24_000.0,
        channel_count=1,
        max_queue_size=8,
        adapter_type="simulated",
        metadata={"compatibility": "legacy_sdr_api_48khz"},
    ),
)

_sdr_pipeline: StreamingPipeline = StreamingPipeline(
    adapter=SimulatedIQDriver(
        frame_size=256,
        modulation=ModulationScheme.SINE_DUAL,
    ),
    bridge=sdr_stream_bridge,
)


# ---------------------------------------------------------------------------
# Router lifespan
# ---------------------------------------------------------------------------


@asynccontextmanager
async def sdr_lifespan(_: object) -> AsyncGenerator[None, None]:
    logger.info("[SDR] pipeline starting")
    await _sdr_pipeline.start()
    try:
        yield
    finally:
        logger.info("[SDR] pipeline stopping")
        await _sdr_pipeline.stop()          # cancels pipeline task + adapter.stop()
        await sdr_stream_bridge.shutdown()  # drains publisher queue, cancels _publisher_loop


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------

router = APIRouter(
    prefix="/api/iq",
    tags=["SDR I/Q Stream"],
    lifespan=sdr_lifespan,
)


@router.websocket("/ws")
async def ws_iq(websocket: WebSocket) -> None:
    """
    WebSocket /api/iq/ws — live I/Q frames from SimulatedIQDriver.

    LegacyPayloadWSAdapter wraps the connection so the bridge's flat event
    format is translated to the nested payload schema the frontend expects.
    """
    adapter: IWebSocketConnection = LegacyPayloadWSAdapter(websocket)
    await sdr_stream_bridge.handle_websocket(adapter)
