"""
Simulated I/Q driver for the TRFMC streaming pipeline.

Produces deterministic synthetic I/Q frames from a seeded PRNG.  No
hardware, SoapySDR, USB, or external dependency is required.

Determinism contract
--------------------
The I and Q sample values are generated exclusively by self._prng, a
dedicated random.Random instance seeded at construction time.  Given the
same seed and modulation scheme, the *sample sequences* are numerically
identical across process restarts and Python versions (CPython's Mersenne
Twister implementation is stable).

However, a complete IQFrame is NOT byte-identical across different process
invocations because the `timestamp_ns` field is sourced from
time.monotonic_ns() at the moment each frame is yielded.  The monotonic
clock produces different values on every run.

For regression tests that require exact frame comparison:
* Compare i_samples and q_samples individually (deterministic).
* Exclude timestamp_ns from golden-file comparisons (non-deterministic).
* Optionally pass a fake clock via dependency injection if full-frame
  determinism is required.
"""
from __future__ import annotations

import asyncio
import math
import random
from collections.abc import AsyncGenerator
from enum import StrEnum
from typing import final

from app.hardware.protocols import (
    AdapterDevice,
    AdapterNotConfiguredError,
    AdapterNotFoundError,
    AdapterState,
    AdapterStatus,
    IHardwareAdapter,
    IQFrame,
    RxConfig,
    monotonic_frame_ns,
)


# ---------------------------------------------------------------------------
# Modulation scheme selector
# ---------------------------------------------------------------------------


class ModulationScheme(StrEnum):
    """Selects the synthetic waveform produced by SimulatedIQDriver.stream()."""

    SINE_DUAL = "sine_dual"
    """Two phase-continuous carriers with additive AWGN — ideal for FFT/Waterfall."""

    AWGN_ONLY = "awgn_only"
    """Unit-variance white Gaussian noise on both I and Q channels."""


# ---------------------------------------------------------------------------
# Module-level constants
# ---------------------------------------------------------------------------

_DEVICE_ID: str = "simulated-iq-0"

_VIRTUAL_DEVICE: AdapterDevice = AdapterDevice(
    device_id=_DEVICE_ID,
    driver="SimulatedIQDriver",
    label="Simulated I/Q Source (no hardware required)",
    metadata={
        "driver_version": "1.0.0",
        "requires_hardware": False,
    },
)


# ---------------------------------------------------------------------------
# SimulatedIQDriver
# ---------------------------------------------------------------------------


@final
class SimulatedIQDriver:
    """
    Deterministic synthetic I/Q source conforming to IHardwareAdapter.

    PRNG isolation
    --------------
    self._prng is a dedicated random.Random instance seeded at construction.
    It is completely isolated from Python's global random state — calling
    random.seed() elsewhere in the process does not affect frame output.

    Sample determinism vs frame determinism
    ----------------------------------------
    Given the same `seed` and `modulation`, the I/Q *sample sequences* are
    numerically identical across process restarts: CPython's Mersenne Twister
    is stable and self._prng is the exclusive noise source.

    However, complete IQFrame objects are NOT byte-identical between distinct
    process runs because the `timestamp_ns` field is stamped by
    time.monotonic_ns() at yield time.  The monotonic clock advances
    independently of the PRNG seed and produces a different value on every run.

    For regression tests:
    * Assert i_samples / q_samples equality (deterministic).
    * Exclude timestamp_ns from golden-file comparisons (non-deterministic).

    Modulation schemes
    ------------------
    SINE_DUAL  — Dual phase-continuous carriers at fs/8 and fs/4, amplitudes
                 0.70 and 0.45, with additive σ=0.05 AWGN from self._prng.
                 Phase is derived from the cumulative sample index — no
                 discontinuity between consecutive frames.
    AWGN_ONLY  — I and Q channels are independent N(0, 1) Gaussian streams.

    Lifecycle
    ---------
    discover() → connect() → configure_rx() → stream() [loop] → stop()
    stop() is idempotent and safe from any lifecycle state.
    """

    DEFAULT_SEED: int = 20240601
    DEFAULT_FRAME_SIZE: int = 256
    _NOISE_SIGMA: float = 0.05

    def __init__(
        self,
        seed: int = DEFAULT_SEED,
        modulation: ModulationScheme = ModulationScheme.SINE_DUAL,
        frame_size: int = DEFAULT_FRAME_SIZE,
    ) -> None:
        if frame_size <= 0:
            raise ValueError(
                f"frame_size must be a positive integer, got {frame_size}"
            )
        self._seed: int = seed
        self._modulation: ModulationScheme = modulation
        self._frame_size: int = frame_size

        # Seeded instance — NOT the global random module.
        self._prng: random.Random = random.Random(seed)

        self._state: AdapterState = AdapterState.IDLE
        self._device: AdapterDevice | None = None
        self._config: RxConfig | None = None
        self._streaming: bool = False
        self._seq: int = 0
        self._frames_produced: int = 0

        # Validate structural conformance at construction time.
        # If any IHardwareAdapter method is accidentally removed or renamed,
        # this assert fires at startup rather than at the first pipeline call.
        assert isinstance(self, IHardwareAdapter), (
            "SimulatedIQDriver does not satisfy IHardwareAdapter — "
            "check for missing or renamed protocol methods"
        )

    # ------------------------------------------------------------------
    # IHardwareAdapter — lifecycle
    # ------------------------------------------------------------------

    def discover(self) -> list[AdapterDevice]:
        """Return the single virtual device provided by this driver."""
        return [_VIRTUAL_DEVICE]

    def connect(self, device: AdapterDevice) -> None:
        """
        Accept a virtual connection to the simulated device.

        Raises
        ------
        AdapterNotFoundError
            device.device_id does not match the simulated device ID.
        """
        if device.device_id != _DEVICE_ID:
            raise AdapterNotFoundError(
                f"Device '{device.device_id}' not recognised by "
                f"SimulatedIQDriver; only '{_DEVICE_ID}' is available"
            )
        self._device = device
        self._state = AdapterState.CONNECTED

    def configure_rx(self, config: RxConfig) -> RxConfig:
        """
        Apply receiver configuration.

        The simulator accepts any valid RxConfig without hardware clamping.
        The returned config is identical to the requested config.
        """
        self._config = config
        self._state = AdapterState.CONFIGURED
        return config

    async def stream(self) -> AsyncGenerator[IQFrame, None]:
        """
        Yield IQFrame objects continuously at the configured sample rate.

        Paces output via asyncio.sleep(frame_size / sample_rate_hz) so the
        caller receives frames at the nominal real-time rate.

        Phase is continuous across frames: time is derived from the
        cumulative sample index, not wall-clock time.

        asyncio.CancelledError is never suppressed — the generator is safe
        to cancel from any task context.

        Raises
        ------
        AdapterNotConfiguredError
            configure_rx() has not been called before stream().
        """
        if self._config is None:
            raise AdapterNotConfiguredError(
                "configure_rx() must be called before stream()"
            )
        config = self._config  # snapshot — immune to concurrent configure_rx()
        frame_duration_s: float = self._frame_size / config.sample_rate_hz
        self._state = AdapterState.STREAMING
        self._streaming = True
        try:
            while self._streaming:
                i_s, q_s = self._generate_frame(config)
                frame_meta: dict[str, object] = {
                    "modulation": str(self._modulation),
                    "seed": self._seed,
                }
                frame = IQFrame(
                    seq=self._seq,
                    timestamp_ns=monotonic_frame_ns(),
                    config=config,
                    i_samples=i_s,
                    q_samples=q_s,
                    metadata=frame_meta,
                )
                self._seq += 1
                self._frames_produced += 1
                yield frame
                await asyncio.sleep(frame_duration_s)
        except asyncio.CancelledError:
            raise  # never suppress CancelledError
        finally:
            if self._state == AdapterState.STREAMING:
                self._state = AdapterState.CONFIGURED

    def stop(self) -> None:
        """
        Signal the stream generator to exit cleanly.
        Idempotent — safe to call from any lifecycle state.
        """
        self._streaming = False
        self._state = AdapterState.STOPPED

    def get_status(self) -> AdapterStatus:
        """Return a point-in-time snapshot of the driver's state."""
        return AdapterStatus(
            state=self._state,
            driver="SimulatedIQDriver",
            config=self._config,
            frames_produced=self._frames_produced,
            frames_dropped=0,  # simulator never drops frames
        )

    # ------------------------------------------------------------------
    # Frame generation (private)
    # ------------------------------------------------------------------

    def _generate_frame(
        self,
        config: RxConfig,
    ) -> tuple[tuple[float, ...], tuple[float, ...]]:
        """Dispatch to the active modulation scheme."""
        if self._modulation == ModulationScheme.SINE_DUAL:
            return self._sine_dual(config)
        return self._awgn_only()

    def _sine_dual(
        self,
        config: RxConfig,
    ) -> tuple[tuple[float, ...], tuple[float, ...]]:
        """
        Dual-carrier IQ frame with additive AWGN.

        Carrier layout
        --------------
        C1: amplitude 0.70, frequency offset = sample_rate / 8  (fs/8)
        C2: amplitude 0.45, frequency offset = sample_rate / 4  (fs/4)

        Both frequencies are comfortably within the Nyquist band (< fs/2).

        Phase continuity
        ----------------
        t[n] = (seq * frame_size + n) / sample_rate_hz

        Using the cumulative sample index rather than wall-clock time ensures
        that carrier phase is continuous across consecutive frames even when
        asyncio.sleep introduces jitter.

        Noise
        -----
        Gaussian, σ = _NOISE_SIGMA, sourced exclusively from self._prng.
        """
        sr: float = config.sample_rate_hz
        f1: float = sr * 0.125
        f2: float = sr * 0.25
        two_pi: float = 2.0 * math.pi
        n_sigma: float = self._NOISE_SIGMA
        frame_size: int = self._frame_size
        base_sample: int = self._seq * frame_size

        i_list: list[float] = []
        q_list: list[float] = []
        for n in range(frame_size):
            t = (base_sample + n) / sr
            phi1 = two_pi * f1 * t
            phi2 = two_pi * f2 * t
            i = (
                0.70 * math.cos(phi1)
                + 0.45 * math.cos(phi2)
                + self._prng.gauss(0.0, n_sigma)
            )
            q = (
                0.70 * math.sin(phi1)
                + 0.45 * math.sin(phi2)
                + self._prng.gauss(0.0, n_sigma)
            )
            i_list.append(i)
            q_list.append(q)
        return tuple(i_list), tuple(q_list)

    def _awgn_only(self) -> tuple[tuple[float, ...], tuple[float, ...]]:
        """
        Pure white Gaussian noise frame.

        I and Q channels are drawn independently from N(0, 1) via self._prng.
        The sample sequence is deterministic: re-instantiating the driver
        with the same seed reproduces the identical noise sequence from frame 0.
        Note: full IQFrame objects differ across runs due to timestamp_ns entropy
        (see class docstring for the sample-vs-frame determinism distinction).
        """
        frame_size: int = self._frame_size
        i_samples = tuple(self._prng.gauss(0.0, 1.0) for _ in range(frame_size))
        q_samples = tuple(self._prng.gauss(0.0, 1.0) for _ in range(frame_size))
        return i_samples, q_samples
