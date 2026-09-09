"""
Supervised asyncio pipeline that couples a hardware adapter to a StreamingBridge.

StreamingPipeline wraps adapter.stream() in a background asyncio.Task with:
* Exponential-backoff restart on AdapterError
* CancelledError propagation (never swallowed)
* Fail-fast re-raise on any unexpected exception (no restart)
* PipelineHealth snapshot via dataclasses.replace()
"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, replace

from app.hardware.protocols import (
    AdapterError,
    IHardwareAdapter,
    RxConfig,
)
from app.hardware.streaming import StreamingBridge

logger = logging.getLogger(__name__)

_BASE_BACKOFF_S: float = 1.0
_MAX_BACKOFF_S: float = 30.0
_BACKOFF_MULTIPLIER: float = 2.0


# ---------------------------------------------------------------------------
# Health tracking
# ---------------------------------------------------------------------------


@dataclass
class PipelineHealth:
    """
    Point-in-time counters for a running StreamingPipeline.

    Instances returned by StreamingPipeline.health are shallow copies
    (dataclasses.replace) — callers cannot mutate internal pipeline state.
    """

    frames_produced: int = 0
    adapter_errors: int = 0
    restart_count: int = 0
    consecutive_errors: int = 0
    last_error_message: str | None = None
    running: bool = False


# ---------------------------------------------------------------------------
# StreamingPipeline
# ---------------------------------------------------------------------------


class StreamingPipeline:
    """
    Supervised loop that drives adapter.stream() and routes frames to a bridge.

    Lifecycle
    ---------
    pipeline = StreamingPipeline(adapter, bridge)
    await pipeline.start()    # spawns background asyncio.Task
    ...
    await pipeline.stop()     # cancels task; waits for clean exit

    Restart policy
    --------------
    AdapterError → exponential backoff, then reconnect and restart:

        backoff = min(_BASE_BACKOFF_S * _BACKOFF_MULTIPLIER^(consecutive-1),
                      _MAX_BACKOFF_S)

    consecutive_errors resets to 0 on the first successful frame so a
    transient blip does not permanently inflate the backoff window.

    asyncio.CancelledError → re-raised immediately, no restart.

    Any other unexpected exception → logger.exception, running=False, re-raised.
    This preserves fail-fast behaviour during P1 validation and avoids
    masking software bugs behind a restart loop.

    Adapter reconfiguration
    -----------------------
    Before each (re)start, configure_rx() is called with bridge.to_rx_config()
    so the adapter always reflects the most recent negotiated parameters.
    """

    def __init__(
        self,
        adapter: IHardwareAdapter,
        bridge: StreamingBridge,
    ) -> None:
        self._adapter: IHardwareAdapter = adapter
        self._bridge: StreamingBridge = bridge
        self._health: PipelineHealth = PipelineHealth()
        self._task: asyncio.Task[None] | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def start(self) -> None:
        """
        Spawn the background supervised loop.

        Idempotent: calling start() when a non-done task is already running
        is a no-op — safe to call from a FastAPI lifespan handler.
        """
        if self._task is not None and not self._task.done():
            logger.debug(
                "[Pipeline:%s] start() called on already-running pipeline — no-op",
                self._bridge.name,
            )
            return
        self._health.running = True
        self._task = asyncio.create_task(
            self._supervised_loop(),
            name=f"pipeline:{self._bridge.name}",
        )
        logger.info("[Pipeline:%s] pipeline task started", self._bridge.name)

    async def stop(self) -> None:
        """
        Cancel the background task and wait for it to exit cleanly.

        Calls adapter.stop() first so the stream() generator exits its
        while-loop via the _streaming flag rather than relying solely on
        CancelledError inside asyncio.sleep().

        Idempotent — safe to call even if start() was never invoked.
        """
        self._adapter.stop()
        if self._task is not None and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        self._task = None
        self._health.running = False
        logger.info("[Pipeline:%s] pipeline stopped", self._bridge.name)

    @property
    def health(self) -> PipelineHealth:
        """
        Return an immutable snapshot of the current pipeline health counters.

        dataclasses.replace() produces a shallow copy — callers cannot
        mutate internal pipeline state through the returned object.
        """
        return replace(self._health)

    # ------------------------------------------------------------------
    # Supervised loop (background task body)
    # ------------------------------------------------------------------

    async def _supervised_loop(self) -> None:
        """
        Outer restart loop — only AdapterError triggers a restart.

            while True:
                try:
                    _connect_and_stream()
                except asyncio.CancelledError:
                    raise                      # always propagate
                except AdapterError:
                    backoff; restart
                except Exception:
                    log; running=False; raise  # fail-fast, no restart
        """
        while True:
            try:
                await self._connect_and_stream()
                logger.info(
                    "[Pipeline:%s] stream ended cleanly — pipeline exiting",
                    self._bridge.name,
                )
                break
            except asyncio.CancelledError:
                raise  # never restart after cancel
            except AdapterError as exc:
                self._health.adapter_errors += 1
                self._health.consecutive_errors += 1
                self._health.last_error_message = str(exc)
                backoff = min(
                    _BASE_BACKOFF_S
                    * (_BACKOFF_MULTIPLIER ** (self._health.consecutive_errors - 1)),
                    _MAX_BACKOFF_S,
                )
                logger.warning(
                    "[Pipeline:%s] AdapterError (#%d total, %d consecutive) — "
                    "restart in %.1fs: %s",
                    self._bridge.name,
                    self._health.adapter_errors,
                    self._health.consecutive_errors,
                    backoff,
                    exc,
                )
                self._health.restart_count += 1
                await asyncio.sleep(backoff)
            except Exception as exc:
                # Unexpected error (software bug, not hardware fault) —
                # log, mark halted, and propagate. No restart.
                self._health.last_error_message = f"{type(exc).__name__}: {exc}"
                self._health.running = False
                logger.exception(
                    "[Pipeline:%s] unexpected error — pipeline halting (no restart)",
                    self._bridge.name,
                )
                raise
        self._health.running = False

    async def _connect_and_stream(self) -> None:
        """
        Single streaming session: discover → connect → configure → stream.

        Raises AdapterError on hardware failure (triggers backoff + restart).
        Propagates CancelledError and all other exceptions unchanged.
        """
        devices = self._adapter.discover()
        if not devices:
            raise AdapterError(
                f"[Pipeline:{self._bridge.name}] no devices discovered"
            )
        device = devices[0]
        logger.info(
            "[Pipeline:%s] connecting to device '%s' (%s)",
            self._bridge.name,
            device.device_id,
            device.label,
        )
        self._adapter.connect(device)

        rx_config: RxConfig = self._bridge.to_rx_config()
        effective_config = self._adapter.configure_rx(rx_config)
        logger.info(
            "[Pipeline:%s] configured — sr=%.1f Hz, cf=%.1f Hz, bw=%.1f Hz",
            self._bridge.name,
            effective_config.sample_rate_hz,
            effective_config.center_frequency_hz,
            effective_config.bandwidth_hz,
        )

        # Attach after configure so bridge.status() reflects the active adapter.
        self._bridge.attach_adapter(self._adapter)

        async for frame in self._adapter.stream():
            await self._bridge.publish_iq_frame(frame)
            self._health.frames_produced += 1
            if self._health.consecutive_errors:
                self._health.consecutive_errors = 0
