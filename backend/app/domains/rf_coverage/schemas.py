from pydantic import BaseModel, Field
from typing import Optional


class RfCoverageRequest(BaseModel):
    mission_id: str = "MISSION-FULL-TELCO-BOOT-001"
    cell_asset_id: str = "CELL-N78-A"
    target_asset_id: Optional[str] = "UE-REMOTE-001"
    frequency_hz: float = Field(3.5e9, gt=0)
    tx_power_dbm: float = 43.0
    tx_gain_dbi: float = 18.0
    rx_gain_dbi: float = 0.0
    bandwidth_hz: float = Field(100e6, gt=0)
    noise_figure_db: float = 7.0
    atmospheric_loss_db_per_km: float = 0.02
    grid_extent_m: float = 600.0
    grid_step_m: float = 100.0
