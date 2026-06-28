"""
Hardware adapter contracts for the TRFMC streaming pipeline.

All hardware integrations — SDR, vector signal analyzers, and deterministic
simulators — must satisfy IHardwareAdapter via structural subtyping.  The
protocol is @runtime_checkable so adapters can be validated at construction
time with isinstance() without requiring inheritance.

Design constraints
------------------
* IQFrame is a frozen value object: i_samples / q_samples are stored as
  immutable tuples; callers must not expect to mutate a delivered frame.
* Timestamps use monotonic_ns() to avoid wall-clock discontinuities from
  NTP slew or DST transitions.
* All exceptions are rooted at AdapterError to allow a single except clause
  in the pipeline layer while still enabling fine-grained catch in tests.
"""
from __future__ import annotations

import time
from collections.abc import AsyncIterator, Mapping
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Protocol, runtime_checkable


# ---------------------------------------------------------------------------
# Lifecycle state
# ---------------------------------------------------------------------------


class AdapterState(StrEnum):
    """Ordered lifecycle states of a hardware or simulation adapter."""

    IDLE = "idle"
    CONNECTED = "connected"
    CONFIGURED = "configured"
    STREAMING = "streaming"
    ERROR = "error"
    STOPPED = "stopped"


# ---------------------------------------------------------------------------
# Value objects (all frozen — treat as immutable after construction)
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class RxConfig:
    """
    Immutable snapshot of receiver parameters negotiated with an adapter.

    The adapter's configure_rx() may clamp values to hardware limits and
    return a new RxConfig reflecting the effective settings.
    """

    center_frequency_hz: float
    sample_rate_hz: float
    bandwidth_hz: float
    gain_db: float = 20.0

    def __post_init__(self) -> None:
        if self.sample_rate_hz <= 0:
            raise ValueError(
                f"sample_rate_hz must be positive, got {self.sample_rate_hz}"
            )
        if self.bandwidth_hz <= 0:
            raise ValueError(
                f"bandwidth_hz must be positive, got {self.bandwidth_hz}"
            )
        if self.center_frequency_hz < 0:
            raise ValueError(
                f"center_frequency_hz must be non-negative, "
                f"got {self.center_frequency_hz}"
            )

    @property
    def nyquist_hz(self) -> float:
        """Nyquist frequency for this configuration."""
        return self.sample_rate_hz / 2.0


@dataclass(frozen=True)
class AdapterDevice:
    """
    Immutable descriptor for a hardware device returned by discover().

    metadata carries driver-specific key/value pairs (USB vendor IDs,
    VISA resource strings, etc.) without forcing a shared schema.
    """

    device_id: str
    driver: str
    label: str
    metadata: Mapping[str, object] = field(default_factory=dict)


@dataclass(frozen=True)
class AdapterStatus:
    """Point-in-time health snapshot of a hardware adapter."""

    state: AdapterState
    driver: str
    config: RxConfig | None = None
    error_message: str | None = None
    frames_produced: int = 0
    frames_dropped: int = 0


@dataclass(frozen=True)
class IQFrame:
    """
    Immutable value object representing one captured I/Q frame.

    Invariants
    ----------
    * len(i_samples) == len(q_samples) > 0  (enforced in __post_init__)
    * timestamp_ns is monotonic — do NOT compare across process restarts.
    * metadata is structurally immutable from the frame's perspective; callers
      should pass a types.MappingProxyType or a plain dict they do not retain.
    """

    seq: int
    timestamp_ns: int
    config: RxConfig
    i_samples: tuple[float, ...]
    q_samples: tuple[float, ...]
    metadata: Mapping[str, object] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.i_samples:
            raise ValueError("IQFrame must contain at least one sample")
        if len(self.i_samples) != len(self.q_samples):
            raise ValueError(
                f"i_samples and q_samples must have equal length; "
                f"got {len(self.i_samples)} vs {len(self.q_samples)}"
            )

    @property
    def frame_size(self) -> int:
        """Number of complex samples in this frame."""
        return len(self.i_samples)

    @property
    def duration_s(self) -> float:
        """Theoretical frame duration in seconds at the configured sample rate."""
        return self.frame_size / self.config.sample_rate_hz


# ---------------------------------------------------------------------------
# Monotonic timestamp utility
# ---------------------------------------------------------------------------


def monotonic_frame_ns() -> int:
    """Return the current monotonic clock value in nanoseconds.

    Use this function — never time.time() — when stamping IQFrame objects so
    that NTP adjustments do not cause apparent time reversals in the pipeline.
    """
    return time.monotonic_ns()


# ---------------------------------------------------------------------------
# Protocol
# ---------------------------------------------------------------------------


@runtime_checkable
class IHardwareAdapter(Protocol):
    """
    Structural protocol that every TRFMC hardware or simulation adapter must
    satisfy.  Conformance is checked at construction time via isinstance().

    Lifecycle
    ---------
    1. discover()     — enumerate available devices
    2. connect()      — open a connection to one device
    3. configure_rx() — negotiate receiver parameters
    4. stream()       — iterate IQFrame objects; yields until stop()
    5. stop()         — idempotent shutdown (safe from any state)

    Exception policy
    ----------------
    All hardware failures raise a subclass of AdapterError.  The pipeline
    layer catches AdapterError and applies exponential-backoff restart logic;
    it does NOT swallow asyncio.CancelledError.

    Implementations
    ---------------
    * SimulatedIQDriver  — deterministic seed-based synthetic source
    * SDRAdapter         — SoapySDR / USB RTL-SDR (optional native deps)
    * KeysightUXMAdapter — pyvisa / GPIB / LAN (optional native deps)
    """

    def discover(self) -> list[AdapterDevice]:
        """
        Enumerate hardware or virtual devices visible to this adapter.

        Returns an empty list (never raises) if no devices are found.
        """
        ...

    def connect(self, device: AdapterDevice) -> None:
        """
        Open a connection to the given device.

        Raises
        ------
        AdapterNotFoundError
            The device_id is not currently visible.
        AdapterConnectionError
            The device exists but cannot be opened (permissions, locked
            by another process, firmware mismatch, etc.).
        """
        ...

    def configure_rx(self, config: RxConfig) -> RxConfig:
        """
        Apply receiver parameters and return the effective (hardware-clamped)
        configuration that will be embedded in each IQFrame.

        Implementations must not mutate the input config object.

        Raises
        ------
        AdapterConfigurationError
            One or more parameters fall outside the hardware's supported range
            and cannot be clamped to a safe value.
        """
        ...

    def stream(self) -> AsyncIterator[IQFrame]:
        """
        Return an async iterator that yields IQFrame objects continuously.

        The iterator terminates cleanly when stop() is called.  It must not
        suppress asyncio.CancelledError — callers may cancel the consuming
        task at any time.

        Raises
        ------
        AdapterNotConfiguredError
            configure_rx() has not been called successfully.
        AdapterStreamError
            An unrecoverable hardware error occurred during streaming.
        """
        ...

    def stop(self) -> None:
        """
        Signal the adapter to stop streaming and release hardware resources.

        Idempotent: calling stop() from IDLE, STOPPED, or ERROR states
        must not raise.
        """
        ...

    def get_status(self) -> AdapterStatus:
        """Return a point-in-time snapshot of the adapter's health."""
        ...


# ---------------------------------------------------------------------------
# Exception hierarchy
# ---------------------------------------------------------------------------


class AdapterError(Exception):
    """Base class for all IHardwareAdapter exceptions."""


class AdapterNotFoundError(AdapterError):
    """Raised when the requested device_id is not visible to the adapter."""


class AdapterConnectionError(AdapterError):
    """Raised when a device exists but cannot be opened or the link is lost."""


class AdapterConfigurationError(AdapterError):
    """Raised when the requested RxConfig is rejected by the hardware."""


class AdapterNotConfiguredError(AdapterError):
    """Raised when stream() is called before a successful configure_rx()."""


class AdapterStreamError(AdapterError):
    """Raised on an unrecoverable error during I/Q frame streaming."""
