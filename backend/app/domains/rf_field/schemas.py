from pydantic import BaseModel, Field
from typing import Optional


class RfFieldRequest(BaseModel):
    mission_id: str = "MISSION-FULL-TELCO-BOOT-001"
    cell_asset_id: str = "CELL-N78-A"
    target_asset_id: Optional[str] = "UE-REMOTE-001"

    frequency_hz: float = Field(3.5e9, gt=0)
    tx_power_dbm: float = 43.0
    tx_gain_dbi: float = 18.0
    antenna_max_dimension_m: float = 0.8

    azimuth_deg: float = 120.0
    mechanical_tilt_deg: float = 4.0
    electrical_tilt_deg: float = 2.0

    horizontal_hpbw_deg: float = 65.0
    vertical_hpbw_deg: float = 10.0
    front_back_ratio_db: float = 30.0
    max_gain_dbi: float = 18.0

    tx_height_m: float = 35.0
    rx_height_m: float = 1.5
    distance_m: float = 293.125
