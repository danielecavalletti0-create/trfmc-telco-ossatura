from typing import Any, Dict


class CoreNetworkService:
    def __init__(self):
        self.config: Dict[str, Any] = {
            "mode": "mixed",
            "network_slice": "default",
            "active_cores": 1,
        }

    def get_status(self) -> Dict[str, Any]:
        return {
            "system": "5g_core_network",
            "status": "ready",
            "config": self.config,
            "telemetry_channel": "/api/core-network/ws/telemetry",
        }

    def configure(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        self.config.update(payload)
        return self.config

    def get_default_stream_config(self) -> Dict[str, Any]:
        return {
            "frame_rate_hz": 20.0,
            "sample_rate_hz": 12_000_000.0,
            "center_frequency_hz": 3.5e9,
            "bandwidth_hz": 40_000_000.0,
            "channel_count": 2,
        }
