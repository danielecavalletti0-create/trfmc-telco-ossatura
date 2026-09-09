from typing import Any, Dict, List, Optional

try:
    import SoapySDR
    from SoapySDR import Device
except ImportError:
    SoapySDR = None

try:
    import usb
except ImportError:
    usb = None


class SDRAdapter:
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self.device = None
        self.driver = None
        self.status = "idle"
        self.sample_rate_hz = float(self.config.get("sample_rate_hz", 10_000_000))
        self.center_frequency_hz = float(self.config.get("center_frequency_hz", 2.4e9))
        self.bandwidth_hz = float(self.config.get("bandwidth_hz", 20_000_000))

    @staticmethod
    def discover_devices() -> List[Dict[str, Any]]:
        probes: List[Dict[str, Any]] = []
        if SoapySDR is not None:
            try:
                results = SoapySDR.Device.enumerate()
                for descriptor in results:
                    probes.append({"driver": descriptor.get("driver", "unknown"), "args": descriptor})
            except Exception:
                probes.append({"driver": "soapysdr", "status": "probe-failed"})
        if usb is not None:
            try:
                devices = usb.core.find(find_all=True)
                for dev in devices:
                    probes.append({"driver": "usb", "idVendor": hex(dev.idVendor), "idProduct": hex(dev.idProduct)})
            except Exception:
                probes.append({"driver": "usb", "status": "probe-failed"})
        if not probes:
            probes.append({"driver": "mock", "status": "no-hardware-found"})
        return probes

    def open_device(self, driver: Optional[str] = None, args: Optional[Dict[str, Any]] = None) -> bool:
        self.driver = driver or self.config.get("driver", "mock")
        self.status = "opened"
        return True

    def configure_rx(self, center_frequency_hz: float, sample_rate_hz: float, bandwidth_hz: float, gain_db: float = 20.0) -> Dict[str, Any]:
        self.center_frequency_hz = center_frequency_hz
        self.sample_rate_hz = sample_rate_hz
        self.bandwidth_hz = bandwidth_hz
        self.config.update({
            "center_frequency_hz": center_frequency_hz,
            "sample_rate_hz": sample_rate_hz,
            "bandwidth_hz": bandwidth_hz,
            "gain_db": gain_db,
        })
        self.status = "configured"
        return {
            "status": self.status,
            "driver": self.driver,
            "center_frequency_hz": self.center_frequency_hz,
            "sample_rate_hz": self.sample_rate_hz,
            "bandwidth_hz": self.bandwidth_hz,
            "gain_db": gain_db,
            "supports_soapy": SoapySDR is not None,
            "supports_usb": usb is not None,
        }

    def capture_iq(self, samples: int = 1024) -> bytes:
        self.status = "capturing"
        return bytes([0] * samples * 2)

    def stop(self) -> Dict[str, Any]:
        self.status = "stopped"
        return {"status": self.status}

    def get_status(self) -> Dict[str, Any]:
        return {
            "status": self.status,
            "driver": self.driver,
            "sample_rate_hz": self.sample_rate_hz,
            "center_frequency_hz": self.center_frequency_hz,
            "bandwidth_hz": self.bandwidth_hz,
            "supports_soapy": SoapySDR is not None,
            "supports_usb": usb is not None,
        }
