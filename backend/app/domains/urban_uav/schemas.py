from typing import List, Optional, Literal
from pydantic import BaseModel, Field


class Building(BaseModel):
    building_id: str
    x_m: float = Field(..., description="Centro edificio, coordinata X, metri")
    y_m: float = Field(..., description="Centro edificio, coordinata Y, metri")
    width_m: float = Field(..., gt=0)
    depth_m: float = Field(..., gt=0)
    height_m: float = Field(..., gt=0)
    material_loss_db: float = Field(15.0, description="Perdita aggiuntiva per attraversamento materiale (se applicabile), dB")


class GroundStation(BaseModel):
    x_m: float
    y_m: float
    z_m: float = Field(10.0, description="Altezza antenna stazione di terra, metri")
    tx_power_dbw: float = Field(-10.0, description="Potenza TX (tipico C2 link UAV), dBW")
    antenna_gain_dbi: float = Field(6.0)


class UavWaypoint(BaseModel):
    x_m: float
    y_m: float
    z_m: float = Field(..., description="Altitudine UAV, metri")


class JammerSpec(BaseModel):
    enabled: bool = False
    jammer_type: Literal["spot", "barrage", "sweep"] = "barrage"
    x_m: float = 0.0
    y_m: float = 0.0
    eirp_dbw: float = 30.0
    bandwidth_hz: float = 5e6


class CorridorScenarioRequest(BaseModel):
    frequency_hz: float = Field(2.44e9, description="Frequenza link C2 UAV, Hz (2.44GHz tipico ISM)")
    bandwidth_hz: float = Field(1e6, description="Larghezza di banda del link, Hz")
    rx_noise_temp_k: float = Field(400.0, description="Temperatura di rumore ricevitore UAV (tipico, non criogenico)")
    uav_antenna_gain_dbi: float = Field(2.0)
    required_cn_db: float = Field(10.0, description="Soglia C/N minima per link utilizzabile")

    buildings: List[Building]
    ground_station: GroundStation
    path: List[UavWaypoint] = Field(..., min_length=1, description="Traiettoria del drone, almeno 1 waypoint")
    jammer: Optional[JammerSpec] = None
    hopping_bandwidth_hz: Optional[float] = Field(None, description="Se il link C2 usa FHSS: banda totale di hopping, Hz")
