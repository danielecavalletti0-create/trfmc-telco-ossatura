import asyncio
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from app.core.event_bus import EventBus
from app.hardware.adapters.SDRAdapter import SDRAdapter
from app.hardware.adapters.KeysightUXMAdapter import KeysightUXMAdapter


@dataclass
class StreamConfig:
    sample_rate_hz: float = 10_000_000.0
    frame_rate_hz: float = 30.0
    center_frequency_hz: float = 2.4e9
    bandwidth_hz: float = 20_000_000.0
    channel_count: int = 1
    max_queue_size: int = 8
    adapter_type: str = "sdr"
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class StreamFrame:
    timestamp: float
    sample_rate_hz: float
    frame_rate_hz: float
    center_frequency_hz: float
    iq_payload: bytes
    metadata: Dict[str, Any] = field(default_factory=dict)


class StreamingBridge:
    MIN_FRAME_RATE_HZ = 1.0
    MAX_FRAME_RATE_HZ = 120.0
    MIN_SAMPLE_RATE_HZ = 1_000_000.0
    MAX_SAMPLE_RATE_HZ = 60_000_000.0

    def __init__(self, name: str, config: Optional[StreamConfig] = None):
        self.name = name
        self.config = config or StreamConfig()
        self.event_bus = EventBus()
        self.frame_queue: asyncio.Queue[StreamFrame] = asyncio.Queue(maxsize=self.config.max_queue_size)
        self.backpressure_drops = 0
        self.adapter: Optional[Any] = None
        self.adapter_type = self.config.adapter_type
        self._publisher_task: Optional[asyncio.Task] = None
        self._ensure_publisher()

    def _ensure_publisher(self):
        if self._publisher_task is None or self._publisher_task.done():
            self._publisher_task = asyncio.create_task(self._publisher_loop())

    async def _publisher_loop(self):
        while True:
            frame = await self.frame_queue.get()
            await self.event_bus.broadcast({
                "type": "iq_frame",
                "source": self.name,
                "timestamp": frame.timestamp,
                "sample_rate_hz": frame.sample_rate_hz,
                "frame_rate_hz": frame.frame_rate_hz,
                "center_frequency_hz": frame.center_frequency_hz,
                "payload_size": len(frame.iq_payload),
                "metadata": frame.metadata,
            })
            self.frame_queue.task_done()

    def negotiate(self, requested: Dict[str, Any]) -> Dict[str, Any]:
        frame_rate_hz = float(requested.get("frame_rate_hz", self.config.frame_rate_hz))
        sample_rate_hz = float(requested.get("sample_rate_hz", self.config.sample_rate_hz))
        center_frequency_hz = float(requested.get("center_frequency_hz", self.config.center_frequency_hz))

        self.config.frame_rate_hz = max(self.MIN_FRAME_RATE_HZ, min(self.MAX_FRAME_RATE_HZ, frame_rate_hz))
        self.config.sample_rate_hz = max(self.MIN_SAMPLE_RATE_HZ, min(self.MAX_SAMPLE_RATE_HZ, sample_rate_hz))
        self.config.center_frequency_hz = center_frequency_hz
        self.config.bandwidth_hz = float(requested.get("bandwidth_hz", self.config.bandwidth_hz))
        self.config.channel_count = int(requested.get("channel_count", self.config.channel_count))
        self.config.metadata.update(requested.get("metadata", {}))

        return {
            "source": self.name,
            "negotiated": {
                "frame_rate_hz": self.config.frame_rate_hz,
                "sample_rate_hz": self.config.sample_rate_hz,
                "center_frequency_hz": self.config.center_frequency_hz,
                "bandwidth_hz": self.config.bandwidth_hz,
                "channel_count": self.config.channel_count,
            },
            "backpressure": {
                "queue_depth": self.frame_queue.qsize(),
                "queue_capacity": self.config.max_queue_size,
                "drops": self.backpressure_drops,
            },
        }

    async def publish_frame(self, iq_payload: bytes, metadata: Optional[Dict[str, Any]] = None) -> bool:
        self._ensure_publisher()
        frame = StreamFrame(
            timestamp=time.time(),
            sample_rate_hz=self.config.sample_rate_hz,
            frame_rate_hz=self.config.frame_rate_hz,
            center_frequency_hz=self.config.center_frequency_hz,
            iq_payload=iq_payload,
            metadata=metadata or {},
        )

        if self.frame_queue.full():
            self.backpressure_drops += 1
            try:
                self.frame_queue.get_nowait()
                self.frame_queue.task_done()
            except asyncio.QueueEmpty:
                pass

        await self.frame_queue.put(frame)
        return True

    async def handle_websocket(self, websocket: Any) -> None:
        await self.event_bus.connect(websocket)
        try:
            while True:
                await websocket.receive_text()
        except Exception:
            await self.event_bus.disconnect(websocket)

    def attach_adapter(self, adapter: Any) -> None:
        self.adapter = adapter

    def status(self) -> Dict[str, Any]:
        status: Dict[str, Any] = {
            "name": self.name,
            "config": self.config.__dict__,
            "queue_depth": self.frame_queue.qsize(),
            "backpressure_drops": self.backpressure_drops,
            "adapter_type": self.adapter_type,
        }
        if self.adapter is not None and hasattr(self.adapter, "get_status"):
            status["adapter_status"] = self.adapter.get_status()
        return status


uav_stream_bridge = StreamingBridge("uav")
core_network_stream_bridge = StreamingBridge("core_network")
autonomous_vehicles_stream_bridge = StreamingBridge("autonomous_vehicles")
