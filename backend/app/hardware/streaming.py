"""
TRFMC hardware streaming bridge.

StreamingBridge couples an IHardwareAdapter to WebSocket subscribers via a
domain-scoped NamespacedBus and a shared system EventBus.

Architecture — two-bus design
------------------------------
* _system_bus  — injected global EventBus; reserved for system-wide events.
* event_bus    — NamespacedBus; per-bridge subscriber registry providing
                 strict domain isolation.  UAV clients cannot receive
                 core_network frames even when bridges share the same
                 underlying system bus.

WebSocket accept() ownership
-----------------------------
NamespacedBus.connect() is a PURE REGISTRATION operation.  It does NOT call
websocket.accept().  Starlette's WebSocket state machine raises RuntimeError
if accept() is called on an already-accepted connection.  Ownership belongs
exclusively to the router or to handle_websocket() when that helper is used.
"""
from __future__ import annotations

import asyncio
import logging
import math
import warnings
from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Protocol, runtime_checkable

from app.core.event_bus import EventBus, event_bus as _global_event_bus
from app.hardware.protocols import (
    AdapterStatus,
    IHardwareAdapter,
    IQFrame,
    RxConfig,
    monotonic_frame_ns,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Input-coercion helpers — used exclusively by negotiate()
# ---------------------------------------------------------------------------


def _coerce_float(
    raw: object,
    default: float,
    label: str,
    bridge_name: str,
) -> float:
    """
    Safely coerce *raw* to a finite float for use in negotiate().

    Returns *default* silently when *raw* is None (key absent from request).
    Returns *default* with a structured warning for:
    * bool values (bool is an int subclass — reject to avoid silent 0/1)
    * types other than int / float / str
    * strings that cannot be parsed as float
    * NaN or ±Inf results
    """
    if raw is None:
        return default
    if isinstance(raw, bool):
        logger.warning(
            "[Bridge:%s] negotiate() '%s': bool not accepted — "
            "use int/float/str; keeping %.6g",
            bridge_name, label, default,
        )
        return default
    result: float
    if isinstance(raw, float):
        result = raw
    elif isinstance(raw, int):
        result = float(raw)
    elif isinstance(raw, str):
        try:
            result = float(raw)
        except ValueError:
            logger.warning(
                "[Bridge:%s] negotiate() '%s': cannot parse %r as float — "
                "keeping %.6g",
                bridge_name, label, raw, default,
            )
            return default
    else:
        logger.warning(
            "[Bridge:%s] negotiate() '%s': expected int/float/str, got %s — "
            "keeping %.6g",
            bridge_name, label, type(raw).__qualname__, default,
        )
        return default
    if not math.isfinite(result):
        logger.warning(
            "[Bridge:%s] negotiate() '%s': value %r is not finite — "
            "keeping %.6g",
            bridge_name, label, result, default,
        )
        return default
    return result


def _coerce_int(
    raw: object,
    default: int,
    label: str,
    bridge_name: str,
) -> int:
    """
    Safely coerce *raw* to int for use in negotiate().

    Returns *default* silently when *raw* is None (key absent from request).
    Returns *default* with a structured warning for:
    * bool values
    * types other than int / float / str
    * floats that are non-finite or not whole numbers
    * strings that cannot be parsed as an integer value
    """
    if raw is None:
        return default
    if isinstance(raw, bool):
        logger.warning(
            "[Bridge:%s] negotiate() '%s': bool not accepted — "
            "use int/float/str; keeping %d",
            bridge_name, label, default,
        )
        return default
    if isinstance(raw, int):
        return raw
    if isinstance(raw, float):
        if not math.isfinite(raw):
            logger.warning(
                "[Bridge:%s] negotiate() '%s': float %r is not finite — "
                "keeping %d",
                bridge_name, label, raw, default,
            )
            return default
        if raw != int(raw):
            logger.warning(
                "[Bridge:%s] negotiate() '%s': float %r is not a whole number — "
                "keeping %d",
                bridge_name, label, raw, default,
            )
            return default
        return int(raw)
    if isinstance(raw, str):
        try:
            return int(raw)
        except ValueError:
            pass
        try:
            parsed = float(raw)
            if not math.isfinite(parsed) or parsed != int(parsed):
                raise ValueError("not a whole number")
            return int(parsed)
        except ValueError:
            logger.warning(
                "[Bridge:%s] negotiate() '%s': cannot parse %r as int — "
                "keeping %d",
                bridge_name, label, raw, default,
            )
            return default
    logger.warning(
        "[Bridge:%s] negotiate() '%s': expected int/float/str, got %s — "
        "keeping %d",
        bridge_name, label, type(raw).__qualname__, default,
    )
    return default


# ---------------------------------------------------------------------------
# Structural Protocols — decouple bridge from FastAPI
# ---------------------------------------------------------------------------


@runtime_checkable
class IWebSocketConnection(Protocol):
    """
    Minimal structural interface for a WebSocket connection.

    fastapi.WebSocket satisfies this Protocol structurally, keeping the
    hardware layer independent of any web framework.
    """

    async def accept(self) -> None: ...
    async def receive_text(self) -> str: ...
    async def send_json(self, data: object) -> None: ...
    async def close(self, code: int = 1000) -> None: ...


# ---------------------------------------------------------------------------
# Domain-scoped subscriber registry
# ---------------------------------------------------------------------------


class NamespacedBus:
    """
    Per-bridge subscriber registry providing cross-domain isolation.

    connect() is a PURE REGISTRATION operation — it does NOT call
    websocket.accept().  Starlette's WebSocket state machine raises
    RuntimeError if accept() is called on an already-accepted connection.
    Ownership of the handshake belongs exclusively to the caller.

    Existing domain routers follow this pattern and require no changes:

        # in uav/api.py — router owns the handshake
        await websocket.accept()
        await uav_stream_bridge.event_bus.connect(websocket)  # register only

    Dead connections are pruned automatically during broadcast().
    """

    def __init__(self, namespace: str) -> None:
        self.namespace = namespace
        self._subscribers: set[IWebSocketConnection] = set()
        self._lock: asyncio.Lock = asyncio.Lock()

    async def connect(self, websocket: IWebSocketConnection) -> None:
        """
        Register an already-accepted WebSocket as a domain subscriber.

        PURE REGISTRATION — does NOT call websocket.accept().
        The caller must have accepted the connection before invoking this.
        """
        async with self._lock:
            self._subscribers.add(websocket)

    async def disconnect(self, websocket: IWebSocketConnection) -> None:
        """Unregister a subscriber.  Idempotent."""
        async with self._lock:
            self._subscribers.discard(websocket)

    async def broadcast(self, message: dict[str, object]) -> None:
        """
        Deliver *message* to all subscribers in this namespace only.
        Subscribers on other bridges are never reached.
        Dead connections are silently pruned.
        """
        async with self._lock:
            current = frozenset(self._subscribers)
        dead: set[IWebSocketConnection] = set()
        for ws in current:
            try:
                await ws.send_json(message)
            except Exception:
                dead.add(ws)
        if dead:
            async with self._lock:
                self._subscribers -= dead

    @property
    def subscriber_count(self) -> int:
        """Current number of registered subscribers."""
        return len(self._subscribers)


# ---------------------------------------------------------------------------
# REST-negotiable stream parameters
# ---------------------------------------------------------------------------


@dataclass
class StreamConfig:
    """
    Mutable stream parameters exposed through the REST negotiate endpoint.

    Decoupled from RxConfig: a REST client may request frame_rate_hz or
    channel_count that the underlying adapter does not natively model.
    Use to_rx_config() to project into a hardware-compatible RxConfig.
    """

    sample_rate_hz: float = 10_000_000.0
    frame_rate_hz: float = 30.0
    center_frequency_hz: float = 2.4e9
    bandwidth_hz: float = 20_000_000.0
    channel_count: int = 1
    max_queue_size: int = 8
    adapter_type: str = "simulated"
    metadata: dict[str, object] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# StreamingBridge
# ---------------------------------------------------------------------------


class StreamingBridge:
    """
    Couples an IHardwareAdapter to WebSocket subscribers.

    Responsibilities
    ----------------
    * Queue-based backpressure between the pipeline producer and broadcaster
    * Frame serialisation to a typed dict for WebSocket transport
    * Adapter lifecycle surface (attach, detach, status, to_rx_config)
    * Publisher task lifecycle (start, graceful shutdown)

    Non-responsibilities
    --------------------
    * Starting the adapter stream loop  → StreamingPipeline (pipeline.py)
    * Reconnect / retry logic           → StreamingPipeline
    * WebSocket accept() handshake      → caller (router or handle_websocket)
    """

    MIN_FRAME_RATE_HZ: float = 1.0
    MAX_FRAME_RATE_HZ: float = 120.0
    MIN_SAMPLE_RATE_HZ: float = 1_000_000.0
    MAX_SAMPLE_RATE_HZ: float = 60_000_000.0

    def __init__(
        self,
        name: str,
        event_bus: EventBus,
        config: StreamConfig | None = None,
    ) -> None:
        self.name = name
        # Global system bus for system-wide events.
        # NOT used for IQ frame delivery — use self.event_bus for that.
        self._system_bus: EventBus = event_bus
        # Domain-scoped registry — enforces cross-domain isolation.
        self.event_bus: NamespacedBus = NamespacedBus(name)
        self.config: StreamConfig = config or StreamConfig()
        self.frame_queue: asyncio.Queue[IQFrame] = asyncio.Queue(
            maxsize=self.config.max_queue_size
        )
        self.backpressure_drops: int = 0
        self._adapter: IHardwareAdapter | None = None
        self._publisher_task: asyncio.Task[None] | None = None
        self._compat_seq: int = 0

    # ------------------------------------------------------------------
    # Adapter lifecycle
    # ------------------------------------------------------------------

    def attach_adapter(self, adapter: IHardwareAdapter) -> None:
        """
        Bind an IHardwareAdapter implementation to this bridge.

        Validates Protocol conformance at runtime via isinstance().  Replaces
        any previously attached adapter; callers must stop the StreamingPipeline
        before swapping adapters to avoid a frame-queue race.

        Raises
        ------
        TypeError
            The object does not satisfy the IHardwareAdapter Protocol.
        """
        if not isinstance(adapter, IHardwareAdapter):
            raise TypeError(
                f"adapter must implement IHardwareAdapter; "
                f"got {type(adapter).__qualname__}"
            )
        self._adapter = adapter
        logger.info(
            "[Bridge:%s] adapter attached — %s",
            self.name,
            type(adapter).__qualname__,
        )

    def detach_adapter(self) -> None:
        """Unbind the current adapter.  Idempotent."""
        if self._adapter is not None:
            logger.info(
                "[Bridge:%s] adapter detached — %s",
                self.name,
                type(self._adapter).__qualname__,
            )
        self._adapter = None

    @property
    def adapter(self) -> IHardwareAdapter | None:
        """Read-only access to the currently attached adapter."""
        return self._adapter

    # ------------------------------------------------------------------
    # REST stream negotiation
    # ------------------------------------------------------------------

    def negotiate(self, requested: Mapping[str, object]) -> dict[str, object]:
        """
        Validate and clamp client-requested stream parameters, returning
        the negotiated result for the REST response body.

        Each numeric field is coerced via _coerce_float / _coerce_int:
        absent keys silently keep the current value; invalid types, NaN,
        and ±Inf are rejected with a warning and the current value is kept.

        The 'metadata' key is merged only when its value is a Mapping.
        Any other type is logged and ignored.
        """
        self.config.frame_rate_hz = max(
            self.MIN_FRAME_RATE_HZ,
            min(
                self.MAX_FRAME_RATE_HZ,
                _coerce_float(
                    requested.get("frame_rate_hz"),
                    self.config.frame_rate_hz,
                    "frame_rate_hz",
                    self.name,
                ),
            ),
        )
        self.config.sample_rate_hz = max(
            self.MIN_SAMPLE_RATE_HZ,
            min(
                self.MAX_SAMPLE_RATE_HZ,
                _coerce_float(
                    requested.get("sample_rate_hz"),
                    self.config.sample_rate_hz,
                    "sample_rate_hz",
                    self.name,
                ),
            ),
        )
        self.config.center_frequency_hz = _coerce_float(
            requested.get("center_frequency_hz"),
            self.config.center_frequency_hz,
            "center_frequency_hz",
            self.name,
        )
        self.config.bandwidth_hz = _coerce_float(
            requested.get("bandwidth_hz"),
            self.config.bandwidth_hz,
            "bandwidth_hz",
            self.name,
        )
        self.config.channel_count = _coerce_int(
            requested.get("channel_count"),
            self.config.channel_count,
            "channel_count",
            self.name,
        )

        raw_meta = requested.get("metadata")
        if raw_meta is None:
            pass  # key absent — nothing to merge
        elif isinstance(raw_meta, Mapping):
            self.config.metadata.update(raw_meta)
        else:
            logger.warning(
                "[Bridge:%s] negotiate() 'metadata' must be a Mapping, "
                "got %s — ignoring",
                self.name,
                type(raw_meta).__qualname__,
            )

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

    def to_rx_config(self) -> RxConfig:
        """
        Project the current StreamConfig into a hardware-compatible RxConfig.
        Used by StreamingPipeline to configure the attached adapter before
        starting the stream loop.
        """
        return RxConfig(
            center_frequency_hz=self.config.center_frequency_hz,
            sample_rate_hz=self.config.sample_rate_hz,
            bandwidth_hz=self.config.bandwidth_hz,
        )

    # ------------------------------------------------------------------
    # Frame publication — primary API (called by StreamingPipeline)
    # ------------------------------------------------------------------

    async def publish_iq_frame(self, frame: IQFrame) -> bool:
        """
        Enqueue an IQFrame for broadcast to all domain subscribers.

        Applies head-drop backpressure: when the queue is full, the oldest
        undelivered frame is discarded and the incoming frame is accepted.
        Returns True on success (always, under the current head-drop policy).

        Starts the internal publisher task on first call.
        """
        await self._ensure_publisher()
        if self.frame_queue.full():
            self.backpressure_drops += 1
            try:
                self.frame_queue.get_nowait()
                self.frame_queue.task_done()
            except asyncio.QueueEmpty:
                pass
        await self.frame_queue.put(frame)
        return True

    # ------------------------------------------------------------------
    # Frame publication — compatibility shim (deprecated)
    # ------------------------------------------------------------------

    async def publish_frame(
        self,
        iq_payload: bytes | None = None,
        iq_samples: list[dict[str, float]] | None = None,
        metadata: Mapping[str, object] | None = None,
    ) -> bool:
        """
        Deprecated: use publish_iq_frame() with a typed IQFrame.

        Compatibility shim mapping the legacy (bytes | list-of-dicts) API
        to IQFrame and delegating to publish_iq_frame().

        Decoding rules
        --------------
        * iq_samples  — each dict must carry 'i' and 'q' float keys.
        * iq_payload  — interleaved signed int8 (I₀ Q₀ I₁ Q₁ …),
                        normalised to [-1.0, 1.0].
        * neither     — synthesises a single zero-value sample.
        """
        warnings.warn(
            "publish_frame() is deprecated; "
            "use publish_iq_frame(frame: IQFrame) instead.",
            DeprecationWarning,
            stacklevel=2,
        )
        i_samps: tuple[float, ...]
        q_samps: tuple[float, ...]

        if iq_samples:
            i_samps = tuple(float(s.get("i", 0.0)) for s in iq_samples)
            q_samps = tuple(float(s.get("q", 0.0)) for s in iq_samples)
        elif iq_payload and len(iq_payload) >= 2:
            pairs = len(iq_payload) // 2
            raw_bytes = list(iq_payload)
            i_raw = [v if v < 128 else v - 256 for v in raw_bytes[0::2]][:pairs]
            q_raw = [v if v < 128 else v - 256 for v in raw_bytes[1::2]][:pairs]
            i_samps = tuple(v / 128.0 for v in i_raw)
            q_samps = tuple(v / 128.0 for v in q_raw)
        else:
            i_samps = (0.0,)
            q_samps = (0.0,)

        frame = IQFrame(
            seq=self._compat_seq,
            timestamp_ns=monotonic_frame_ns(),
            config=self.to_rx_config(),
            i_samples=i_samps,
            q_samples=q_samps,
            metadata=dict(metadata) if metadata is not None else {},
        )
        self._compat_seq += 1
        return await self.publish_iq_frame(frame)

    # ------------------------------------------------------------------
    # Publisher task internals
    # ------------------------------------------------------------------

    async def _ensure_publisher(self) -> None:
        if self._publisher_task is None or self._publisher_task.done():
            self._publisher_task = asyncio.create_task(
                self._publisher_loop(),
                name=f"bridge-publisher:{self.name}",
            )

    async def _publisher_loop(self) -> None:
        logger.debug("[Bridge:%s] publisher loop started", self.name)
        try:
            while True:
                frame: IQFrame = await self.frame_queue.get()
                event: dict[str, object] = {
                    "type": "iq_frame",
                    "source": self.name,
                    "seq": frame.seq,
                    "timestamp_ns": frame.timestamp_ns,
                    "sample_rate_hz": frame.config.sample_rate_hz,
                    "center_frequency_hz": frame.config.center_frequency_hz,
                    "bandwidth_hz": frame.config.bandwidth_hz,
                    "frame_size": frame.frame_size,
                    "i": list(frame.i_samples),
                    "q": list(frame.q_samples),
                    "metadata": dict(frame.metadata),
                }
                await self.event_bus.broadcast(event)
                self.frame_queue.task_done()
        except asyncio.CancelledError:
            logger.info(
                "[Bridge:%s] publisher cancelled — draining %d queued frame(s)",
                self.name,
                self.frame_queue.qsize(),
            )
            while not self.frame_queue.empty():
                try:
                    self.frame_queue.get_nowait()
                    self.frame_queue.task_done()
                except asyncio.QueueEmpty:
                    break
            raise  # never suppress CancelledError

    async def shutdown(self) -> None:
        """
        Cancel the publisher task and wait for it to terminate cleanly.

        Idempotent: safe to call from any state including before the first
        publish.  Must be called from within the running event loop (e.g.,
        a FastAPI shutdown lifespan handler).
        """
        if self._publisher_task is not None and not self._publisher_task.done():
            self._publisher_task.cancel()
            try:
                await self._publisher_task
            except asyncio.CancelledError:
                pass
        self._publisher_task = None
        logger.info("[Bridge:%s] shutdown complete", self.name)

    # ------------------------------------------------------------------
    # WebSocket subscription helper (for future routers)
    # ------------------------------------------------------------------

    async def handle_websocket(self, websocket: IWebSocketConnection) -> None:
        """
        Full-lifecycle helper for future WebSocket routers that have not
        yet accepted the connection.

        Calls websocket.accept() exactly once, then registers the connection
        via self.event_bus.connect() (register-only, no second accept).

        Do NOT use from routers that already call websocket.accept() — they
        must call self.event_bus.connect(websocket) directly after accepting.
        """
        await websocket.accept()
        await self.event_bus.connect(websocket)
        try:
            while True:
                await websocket.receive_text()
        except Exception:
            await self.event_bus.disconnect(websocket)

    # ------------------------------------------------------------------
    # Status
    # ------------------------------------------------------------------

    def status(self) -> dict[str, object]:
        """Return a fully-typed status dict for /status REST endpoints."""
        result: dict[str, object] = {
            "name": self.name,
            "config": {
                "sample_rate_hz": self.config.sample_rate_hz,
                "frame_rate_hz": self.config.frame_rate_hz,
                "center_frequency_hz": self.config.center_frequency_hz,
                "bandwidth_hz": self.config.bandwidth_hz,
                "channel_count": self.config.channel_count,
                "max_queue_size": self.config.max_queue_size,
                "adapter_type": self.config.adapter_type,
                "metadata": dict(self.config.metadata),
            },
            "queue_depth": self.frame_queue.qsize(),
            "backpressure_drops": self.backpressure_drops,
            "adapter_attached": self._adapter is not None,
            "subscriber_count": self.event_bus.subscriber_count,
        }
        if self._adapter is not None:
            s: AdapterStatus = self._adapter.get_status()
            result["adapter"] = {
                "state": s.state,
                "driver": s.driver,
                "frames_produced": s.frames_produced,
                "frames_dropped": s.frames_dropped,
                "error_message": s.error_message,
            }
        return result


# ---------------------------------------------------------------------------
# Module-level singletons
#
# Each bridge injects the GLOBAL system bus for system-level visibility but
# delivers IQ frames on its own NamespacedBus — UAV clients never receive
# core_network frames and vice versa.
# ---------------------------------------------------------------------------

uav_stream_bridge = StreamingBridge("uav", event_bus=_global_event_bus)
core_network_stream_bridge = StreamingBridge(
    "core_network", event_bus=_global_event_bus
)
autonomous_vehicles_stream_bridge = StreamingBridge(
    "autonomous_vehicles", event_bus=_global_event_bus
)
