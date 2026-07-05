from __future__ import annotations

import os
import time
from dataclasses import dataclass, field
from typing import Any, Protocol

# Patch 10C — Instrument Provider Backend Skeleton.
#
# Self-contained, no mandatory VISA/SCPI/vendor dependency. This module never
# imports pyvisa/RsInstrument/usb, never opens a LAN/USB/GPIB session, never
# sends a SCPI command, and never probes hardware. It exists only to define
# the shape of a future professional-instrument evidence source (Keysight /
# Rohde & Schwarz / Siglent), disabled by default.
#
# Patch 10D-B — Instrument Read-Only Provider Implementation (additive-only).
#
# Adds a dry-run-only read-only provider (`ProfessionalInstrumentReadOnlyProvider`)
# plus safe environment-variable parsing and an extended (additive) payload
# section. Patch 10D-B still NEVER imports pyvisa/RsInstrument/usb at module
# level, NEVER creates a VISA ResourceManager, NEVER calls list_resources()/
# open_resource()/.query()/.write(), NEVER opens USBTMC/serial/TCP sessions to
# an instrument, and NEVER sends a SCPI command. The only reachable runtime
# states in this patch are: disabled (default), unavailable/blocked, and a
# static "read-only dry-run" snapshot that proves the wiring is correct
# without touching any hardware. Real acquisition is deferred to a future,
# separately authorized activation patch (Patch 10D-C+).
#
# Config (env vars, all optional, safe defaults preserve today's behavior):
#   RF_INSTRUMENT_ENABLE            = 0 | 1        (default: 0)
#   RF_INSTRUMENT_MODE              = disabled     (default: disabled)
#   RF_INSTRUMENT_VENDOR            = none         (default: none)
#   RF_INSTRUMENT_FAMILY            = none         (default: none)
#   RF_INSTRUMENT_RESOURCE          = ""           (default: empty)
#   RF_INSTRUMENT_ALLOWLIST_RESOURCE = ""          (default: empty)
#   RF_INSTRUMENT_READONLY          = 1            (default: 1, informational — policy always enforces readonly)
#   RF_INSTRUMENT_ALLOW_DISCOVERY   = 0            (default: 0, informational in Patch 10D-B — never executed)
#   RF_INSTRUMENT_ALLOW_MEASUREMENTS = 0           (default: 0, informational in Patch 10D-B — never executed)
#   RF_INSTRUMENT_COMMAND_PROFILE   = none         (default: none, informational)
#   RF_INSTRUMENT_CACHE_TTL_MS      = 1000         (default: 1000, informational — no background cache runs yet)
#   RF_INSTRUMENT_TIMEOUT_MS        = 500          (default: 500, informational — no I/O happens yet)
#   RF_INSTRUMENT_DRY_RUN           = 1            (default: 1 — Patch 10D-B refuses to run non-dry-run)
#
# Legacy Patch 10C vars still honored for backward compatibility:
#   RF_INSTRUMENT_TIMEOUT_MS, RF_INSTRUMENT_CACHE_TTL_MS,
#   RF_INSTRUMENT_ALLOW_CONFIGURE, RF_INSTRUMENT_ALLOW_RF_OUTPUT
#   (both remain hardcoded to False-equivalent behavior; nothing in this
#   module ever flips configuration-write or RF-output capability on).


def _env_flag(name: str, default: str = "0") -> bool:
    return os.environ.get(name, default).strip() == "1"


def _env_str(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or not raw.strip():
        return default
    try:
        return int(raw.strip())
    except ValueError:
        return default


def _parse_allowlist(raw: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in raw.split(",") if item.strip())


@dataclass(frozen=True)
class InstrumentSafetyPolicy:
    """Declarative safety posture. Nothing in Patch 10C/10D-B executes any of
    this against a real instrument — it exists only as the contract future
    providers (Patch 10D-C+) must honor."""

    allow_discovery_queries: bool = False
    allow_measurement_queries: bool = False
    allow_configuration_writes: bool = False
    allow_rf_output_control: bool = False
    allow_preset_reset: bool = False
    allow_remote_test_execution: bool = False
    allow_vendor_specific_unsafe_commands: bool = False
    require_command_allowlist: bool = True
    require_resource_allowlist: bool = True
    deny_unsafe_commands: bool = True
    dry_run: bool = True

    denylist: tuple[str, ...] = field(default_factory=lambda: (
        "*RST",
        "*CLS",
        "SYST:PRES",
        "OUTP",
        "OUTP ON",
        "RF:OUTP ON",
        "SOUR",
        "SOUR:POW",
        "SOUR:FREQ",
        "POW",
        "FREQ",
        "CONF",
        "INIT",
        "INIT:IMM",
        "ABOR",
        "TRIG",
        "CAL",
        "MMEM:DEL",
        "FORM",
        ":OUTPUT:STATE ON",
        ":SOURCE:POWER",
        ":SOURCE:FREQUENCY",
    ))

    allowlist: tuple[str, ...] = field(default_factory=lambda: (
        "*IDN?",
        "*OPT?",
        "SYST:ERR?",
        "STAT:OPER:COND?",
        "STAT:QUES:COND?",
        "READONLY:CAPABILITIES?",
    ))

    def as_dict(self) -> dict[str, Any]:
        return {
            "readonly": True,
            "allow_configuration_writes": self.allow_configuration_writes,
            "allow_rf_output_control": self.allow_rf_output_control,
        }


@dataclass
class InstrumentSourceInfo:
    """Identity of a (future) instrument source. Never populated with real
    vendor data by discovery in Patch 10C/10D-B — values here only ever come
    from operator-configured env vars, never from a live probe."""

    vendor: str = "none"
    family: str = "none"
    resource: str | None = None
    transport: str = "none"


@dataclass
class InstrumentSnapshot:
    """Shape of the base `instrument` payload field. Mirrors the additive,
    backward-compatible pattern already used for `rf` (Patch 9C). Unchanged
    since Patch 10C — Patch 10D-B only adds further keys on top via
    `_build_extension()`, it never alters this base shape."""

    enabled: bool
    source_mode: str
    provenance: str
    readonly: bool
    vendor: str
    family: str
    resource: str | None
    transport: str
    device_status: str
    cache_status: str
    snapshot_age_ms: int | None
    metrics: dict[str, Any]
    safety_policy: dict[str, Any]
    limitations: list[str]
    warnings: list[str]

    def to_dict(self) -> dict[str, Any]:
        return {
            "enabled": self.enabled,
            "source_mode": self.source_mode,
            "provenance": self.provenance,
            "readonly": self.readonly,
            "vendor": self.vendor,
            "family": self.family,
            "resource": self.resource,
            "transport": self.transport,
            "device_status": self.device_status,
            "cache_status": self.cache_status,
            "snapshot_age_ms": self.snapshot_age_ms,
            "metrics": self.metrics,
            "safety_policy": self.safety_policy,
            "limitations": self.limitations,
            "warnings": self.warnings,
        }


def _capabilities_none() -> dict[str, bool]:
    """No provider in Patch 10D-B implements any real capability yet."""
    return {
        "identity": False,
        "status": False,
        "spectrum": False,
        "power": False,
        "iq": False,
        "screenshot": False,
    }


def _dependencies_not_checked() -> dict[str, str]:
    """Patch 10D-B never calls `_check_optional_visa_available()` from any
    reachable code path (disabled/unavailable/dry-run all skip it by design),
    so this is always "not_checked" in this patch. A future, separately
    authorized controlled-activation patch may populate this for real."""
    return {"pyvisa": "not_checked", "vendor_backend": "not_checked"}


def _build_extension(
    *,
    provider: str,
    dry_run: bool,
    resource_configured: bool,
    resource_allowed: bool,
    executed_commands: int = 0,
    blocked_commands: int = 0,
) -> dict[str, Any]:
    """Additive-only extension merged on top of `InstrumentSnapshot.to_dict()`.
    Never removes or renames a Patch 10C key — only adds new ones."""
    return {
        "schema_version": "instrument.v10d-b",
        "dry_run": dry_run,
        "provider": provider,
        "capabilities": _capabilities_none(),
        "dependencies": _dependencies_not_checked(),
        "resource_policy": {
            "allowlist_required": True,
            "resource_configured": resource_configured,
            "resource_allowed": resource_allowed,
        },
        "command_policy": {
            "allowlist_required": True,
            "executed_commands": executed_commands,
            "blocked_commands": blocked_commands,
        },
    }


def _check_optional_visa_available() -> dict[str, str]:
    """Lazy, opt-in dependency probe — NOT called anywhere in Patch 10D-B.

    Reserved for a future, separately authorized controlled-activation patch.
    Only ever attempts a plain Python import (no `ResourceManager()`, no
    `list_resources()`, no `open_resource()`, no I/O of any kind). Never
    imported or executed at module load time, never imported when disabled,
    never imported in dry-run, never imported without a valid allowlist —
    it is simply unreachable dead code in this patch, kept here only so the
    shape of the future check is documented and reviewable now.
    """
    result = {"pyvisa": "missing", "vendor_backend": "missing"}
    try:
        import pyvisa  # noqa: F401  (function-local, lazy; never at module import time)
        result["pyvisa"] = "available"
    except ImportError:
        result["pyvisa"] = "missing"
    try:
        import pyvisa_py  # noqa: F401  (function-local, lazy; never at module import time)
        result["vendor_backend"] = "available"
    except ImportError:
        result["vendor_backend"] = "missing"
    return result


class InstrumentSourceProvider(Protocol):
    def read_snapshot(self, tick: int) -> dict[str, Any]: ...
    def close(self) -> None: ...


class DisabledInstrumentProvider:
    """Default provider. Selected whenever RF_INSTRUMENT_ENABLE is not "1".
    Never touches hardware, never imports a vendor library."""

    def __init__(self, policy: InstrumentSafetyPolicy):
        self._policy = policy

    def read_snapshot(self, tick: int) -> dict[str, Any]:
        snap = InstrumentSnapshot(
            enabled=False,
            source_mode="instrument_disabled",
            provenance="NOT_ENABLED",
            readonly=True,
            vendor="none",
            family="none",
            resource=None,
            transport="none",
            device_status="disabled",
            cache_status="not_applicable",
            snapshot_age_ms=None,
            metrics={},
            safety_policy=self._policy.as_dict(),
            limitations=[
                "RF_INSTRUMENT_ENABLE=0: professional instrument provider disabled by default",
                "No VISA/SCPI discovery performed",
                "No instrument measurement performed",
            ],
            warnings=[],
        ).to_dict()
        snap.update(_build_extension(
            provider="disabled",
            dry_run=True,
            resource_configured=False,
            resource_allowed=False,
        ))
        return snap

    def close(self) -> None:
        return None


class UnavailableInstrumentProvider:
    """Used whenever RF_INSTRUMENT_ENABLE=1 but activation is not (yet)
    authorized or the resource/allowlist policy blocks it. No hardware probe
    of any kind happens here."""

    def __init__(
        self,
        policy: InstrumentSafetyPolicy,
        reason: str = "not_implemented",
        dry_run: bool = True,
        resource_configured: bool = False,
        resource_allowed: bool = False,
    ):
        self._policy = policy
        self._reason = reason
        self._dry_run = dry_run
        self._resource_configured = resource_configured
        self._resource_allowed = resource_allowed

    def read_snapshot(self, tick: int) -> dict[str, Any]:
        snap = InstrumentSnapshot(
            enabled=True,
            source_mode="instrument_unavailable",
            provenance="UNAVAILABLE",
            readonly=True,
            vendor="none",
            family="none",
            resource=None,
            transport="none",
            device_status=self._reason,
            cache_status="unavailable",
            snapshot_age_ms=None,
            metrics={},
            safety_policy=self._policy.as_dict(),
            limitations=[
                f"Instrument provider unavailable: {self._reason}",
                "No VISA session opened, no SCPI command sent, no device probed",
            ],
            warnings=[],
        ).to_dict()
        snap.update(_build_extension(
            provider="unavailable",
            dry_run=self._dry_run,
            resource_configured=self._resource_configured,
            resource_allowed=self._resource_allowed,
        ))
        return snap

    def close(self) -> None:
        return None


class InstrumentSkeletonProvider:
    """Structural placeholder from Patch 10C, kept unmodified/unused in
    Patch 10D-B (superseded by `ProfessionalInstrumentReadOnlyProvider` for
    the dry-run path). Does not open a session, does not perform VISA
    discovery, does not send SCPI, does not ping."""

    def __init__(self, policy: InstrumentSafetyPolicy, info: InstrumentSourceInfo | None = None):
        self._policy = policy
        self._info = info or InstrumentSourceInfo()

    def read_snapshot(self, tick: int) -> dict[str, Any]:
        snap = InstrumentSnapshot(
            enabled=True,
            source_mode="instrument_unavailable",
            provenance="UNAVAILABLE",
            readonly=True,
            vendor=self._info.vendor,
            family=self._info.family,
            resource=self._info.resource,
            transport=self._info.transport,
            device_status="not_implemented",
            cache_status="unavailable",
            snapshot_age_ms=None,
            metrics={},
            safety_policy=self._policy.as_dict(),
            limitations=[
                "InstrumentSkeletonProvider is a structural placeholder only",
                "No VISA session opened, no SCPI command sent, no device probed",
            ],
            warnings=[],
        )
        return snap.to_dict()

    def close(self) -> None:
        return None


class ProfessionalInstrumentReadOnlyProvider:
    """Patch 10D-B: structural read-only provider for future professional
    instruments (spectrum analyzer, signal analyzer, oscilloscope, power
    meter, VNA, SDR gateway read-only, any VISA/SCPI-compatible instrument).

    In Patch 10D-B this class NEVER opens a VISA session, NEVER performs
    discovery, NEVER sends a SCPI command, NEVER touches USBTMC/serial/TCP.
    It only reports a safe, static "dry run" snapshot proving the wiring
    (env parsing -> resource allowlist check -> provider selection -> payload
    shape) is correct. Real acquisition is deferred to a future, separately
    authorized activation patch (Patch 10D-C+).
    """

    def __init__(
        self,
        policy: InstrumentSafetyPolicy,
        info: InstrumentSourceInfo,
        resource_allowed: bool,
        dry_run: bool = True,
        cache_ttl_ms: int = 1000,
        timeout_ms: int = 500,
        command_profile: str = "none",
    ):
        self._policy = policy
        self._info = info
        self._resource_allowed = resource_allowed
        self._dry_run = dry_run
        # Parsed for readiness only — no background cache/worker runs yet in
        # Patch 10D-B, so these are not consumed by any operational code path.
        self._cache_ttl_ms = cache_ttl_ms
        self._timeout_ms = timeout_ms
        self._command_profile = command_profile

    def read_snapshot(self, tick: int) -> dict[str, Any]:
        if not self._dry_run:
            # Defense in depth: the factory never constructs this provider
            # with dry_run=False in Patch 10D-B, but if it ever is, degrade
            # safely instead of doing anything — never open a session here.
            snap = InstrumentSnapshot(
                enabled=True,
                source_mode="instrument_unavailable",
                provenance="UNAVAILABLE",
                readonly=True,
                vendor=self._info.vendor,
                family=self._info.family,
                resource=self._info.resource,
                transport=self._info.transport,
                device_status="activation_not_authorized",
                cache_status="unavailable",
                snapshot_age_ms=None,
                metrics={},
                safety_policy=self._policy.as_dict(),
                limitations=["Patch 10D-B: non-dry-run activation is not authorized"],
                warnings=["read_snapshot called with dry_run=False; degraded to safe unavailable state"],
            ).to_dict()
            snap.update(_build_extension(
                provider="unavailable",
                dry_run=False,
                resource_configured=self._info.resource is not None,
                resource_allowed=self._resource_allowed,
            ))
            return snap

        snap = InstrumentSnapshot(
            enabled=True,
            source_mode="instrument_read_only_dry_run",
            provenance="DRY_RUN",
            readonly=True,
            vendor=self._info.vendor,
            family=self._info.family,
            resource=self._info.resource,
            transport=self._info.transport,
            device_status="dry_run_not_connected",
            cache_status="not_applicable",
            snapshot_age_ms=None,
            metrics={},
            safety_policy=self._policy.as_dict(),
            limitations=[
                "Patch 10D-B: read-only dry-run only — no VISA session opened, no SCPI command sent",
                "No discovery performed, no instrument probed, no measurement taken",
            ],
            warnings=[],
        ).to_dict()
        snap.update(_build_extension(
            provider="read_only_dry_run",
            dry_run=True,
            resource_configured=True,
            resource_allowed=self._resource_allowed,
            executed_commands=0,
            blocked_commands=0,
        ))
        return snap

    def close(self) -> None:
        return None


def select_instrument_provider():
    """Selected once at module import time, not per-request.

    Patch 10D-B factory logic (all env vars optional, safe defaults):
      1. RF_INSTRUMENT_ENABLE != "1"                      -> DisabledInstrumentProvider
      2. ENABLE=1, DRY_RUN=0 (any other config)            -> UnavailableInstrumentProvider("activation_not_authorized")
      3. ENABLE=1, DRY_RUN=1, no valid resource+allowlist  -> UnavailableInstrumentProvider("blocked_by_resource_policy")
      4. ENABLE=1, DRY_RUN=1, valid resource+allowlist     -> ProfessionalInstrumentReadOnlyProvider (dry-run only)
      5. Any unexpected/parsing error                      -> UnavailableInstrumentProvider("internal_error_safe_fallback")

    No path in Patch 10D-B opens a VISA session, performs discovery, or
    sends a SCPI command. Never imports pyvisa/RsInstrument/usb at module
    level or anywhere in this function.
    """
    policy = InstrumentSafetyPolicy()

    try:
        enable = _env_flag("RF_INSTRUMENT_ENABLE", "0")
        if not enable:
            return DisabledInstrumentProvider(policy)

        dry_run = _env_flag("RF_INSTRUMENT_DRY_RUN", "1")
        vendor = _env_str("RF_INSTRUMENT_VENDOR", "none") or "none"
        family = _env_str("RF_INSTRUMENT_FAMILY", "none") or "none"
        resource = _env_str("RF_INSTRUMENT_RESOURCE", "") or None
        allowlist = _parse_allowlist(_env_str("RF_INSTRUMENT_ALLOWLIST_RESOURCE", ""))
        # Informational-only in Patch 10D-B — parsed safely, not yet wired
        # into any operational code path (no background cache/worker runs).
        _cache_ttl_ms = _env_int("RF_INSTRUMENT_CACHE_TTL_MS", 1000)
        _timeout_ms = _env_int("RF_INSTRUMENT_TIMEOUT_MS", 500)
        _command_profile = _env_str("RF_INSTRUMENT_COMMAND_PROFILE", "none") or "none"

        resource_configured = resource is not None
        resource_allowed = bool(resource_configured and allowlist and resource in allowlist)

        if not dry_run:
            # Patch 10D-B never authorizes a non-dry-run activation,
            # regardless of resource/allowlist/vendor configuration.
            return UnavailableInstrumentProvider(
                policy,
                reason="activation_not_authorized",
                dry_run=False,
                resource_configured=resource_configured,
                resource_allowed=resource_allowed,
            )

        if not resource_configured or not allowlist or not resource_allowed:
            return UnavailableInstrumentProvider(
                policy,
                reason="blocked_by_resource_policy",
                dry_run=True,
                resource_configured=resource_configured,
                resource_allowed=resource_allowed,
            )

        info = InstrumentSourceInfo(
            vendor=vendor,
            family=family,
            resource=resource,
            transport="visa_tcpip" if resource else "none",
        )
        return ProfessionalInstrumentReadOnlyProvider(
            policy,
            info=info,
            resource_allowed=True,
            dry_run=True,
            cache_ttl_ms=_cache_ttl_ms,
            timeout_ms=_timeout_ms,
            command_profile=_command_profile,
        )
    except Exception:
        # Never crash the backend over instrument-provider configuration.
        return UnavailableInstrumentProvider(policy, reason="internal_error_safe_fallback")
