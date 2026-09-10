from typing import Literal, Optional
from pydantic import BaseModel, Field


class JammerScenarioRequest(BaseModel):
    """Scenario didattico: un jammer e un link legittimo (segnale) che
    condividono lo stesso ricevitore vittima. Nessun parametro qui controlla
    hardware: sono tutti input a un calcolatore di formule EW standard."""

    jammer_type: Literal["spot", "barrage", "sweep"] = Field(..., description="Tipo di jamming simulato")
    jammer_eirp_dbw: float = Field(..., description="EIRP del jammer, in dBW")
    jammer_distance_km: float = Field(..., gt=0, description="Distanza jammer-vittima, in km")
    jammer_freq_hz: float = Field(..., gt=0, description="Frequenza centrale del jammer, in Hz")
    jammer_bandwidth_hz: float = Field(..., gt=0, description="Larghezza di banda occupata dal jammer, in Hz")

    signal_received_power_dbw: float = Field(..., description="Potenza del segnale legittimo al ricevitore vittima, in dBW")
    victim_bandwidth_hz: float = Field(..., gt=0, description="Larghezza di banda del ricevitore vittima, in Hz")
    victim_noise_power_dbw: float = Field(..., description="Potenza di rumore termico al ricevitore vittima, in dBW")

    js_threshold_db: float = Field(6.0, description="Soglia J/S oltre la quale il link vittima e' considerato disturbato, in dB")

    hopping_bandwidth_hz: Optional[float] = Field(
        None, description="Se il segnale vittima usa frequency hopping: larghezza totale di banda di hopping, in Hz"
    )
