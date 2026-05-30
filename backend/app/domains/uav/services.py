from typing import Any, Dict


class UAVService:
    def __init__(self):
        self.config: Dict[str, Any] = {
            "mode": "simulation",
            "vehicle_count": 0,
            "flight_pattern": "loiter",
        }

    def get_status(self) -> Dict[str, Any]:
        return {
            "system": "uav",
            "status": "standby",
            "config": self.config,
            "telemetry_channel": "/api/uav/ws/telemetry",
        }

    def configure(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        self.config.update(payload)
        return self.config

    def get_default_stream_config(self) -> Dict[str, Any]:
        return {
            "frame_rate_hz": 15.0,
            "sample_rate_hz": 10_000_000.0,
            "center_frequency_hz": 2.4e9,
            "bandwidth_hz": 20_000_000.0,
            "channel_count": 1,
        }
