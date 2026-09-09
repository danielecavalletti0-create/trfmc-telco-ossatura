from typing import Any, Dict, List, Optional

try:
    import pyvisa
except ImportError:
    pyvisa = None


class KeysightUXMAdapter:
    def __init__(self, resource_name: Optional[str] = None, config: Optional[Dict[str, Any]] = None):
        self.resource_name = resource_name
        self.config = config or {}
        self.instrument = None
        self.status = "idle"

    @staticmethod
    def list_instruments() -> List[Dict[str, Any]]:
        instruments: List[Dict[str, Any]] = []
        if pyvisa is not None:
            try:
                rm = pyvisa.ResourceManager()
                for resource in rm.list_resources():
                    instruments.append({"resource_name": resource})
            except Exception:
                instruments.append({"resource_name": "unknown", "status": "probe-failed"})
        else:
            instruments.append({"resource_name": "mock", "status": "pyvisa-missing"})
        return instruments

    def connect(self, resource_name: str) -> bool:
        self.resource_name = resource_name
        self.status = "connected"
        return True

    def configure_stream(self, center_frequency_hz: float, sample_rate_hz: float, bandwidth_hz: float) -> Dict[str, Any]:
        self.config.update({
            "center_frequency_hz": center_frequency_hz,
            "sample_rate_hz": sample_rate_hz,
            "bandwidth_hz": bandwidth_hz,
        })
        self.status = "configured"
        return {
            "status": self.status,
            "resource_name": self.resource_name,
            "center_frequency_hz": center_frequency_hz,
            "sample_rate_hz": sample_rate_hz,
            "bandwidth_hz": bandwidth_hz,
            "supports_pyvisa": pyvisa is not None,
        }

    def acquire_iq(self, sample_count: int = 1024) -> bytes:
        self.status = "acquiring"
        return bytes([0] * sample_count * 2)

    def stop(self) -> Dict[str, Any]:
        self.status = "stopped"
        return {"status": self.status}

    def get_status(self) -> Dict[str, Any]:
        return {
            "status": self.status,
            "resource_name": self.resource_name,
            "config": self.config,
            "supports_pyvisa": pyvisa is not None,
        }
